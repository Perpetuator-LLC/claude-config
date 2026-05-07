# 02 — Request Processing Pipeline

## Overview

When a user sends a message in the chat panel, the request flows through:

```
VS Code Chat API → getChatParticipantHandler → ChatParticipantRequestHandler → Intent Selection → DefaultIntentRequestHandler → ToolCallingLoop
```

---

## Step 1: VS Code Chat API Entry

**File:** `src/extension/conversation/vscode-node/chatParticipants.ts`

### `getChatParticipantHandler(id, name, defaultIntentIdOrGetter)`

This is the `vscode.ChatExtendedRequestHandler` registered with each chat participant. It receives:

- `request: ChatRequest` — The user's message, references, tool references, model
- `context: ChatContext` — History of the conversation
- `stream: ChatResponseStream` — For streaming response back to UI
- `token: CancellationToken`

**Processing steps:**

```typescript
async (request, context, stream, token) => {
    // 1. Model switching (base model fallback if quota exhausted)
    request = await this.switchToBaseModel(request, stream);
    
    // 2. Handle rate limit confirmation buttons
    if (getSwitchToAutoOnRateLimitConfirmation(request)) {
        request = await this.switchToAutoModel(request, stream, alwaysSwitchToAuto);
    }
    
    // 3. Start interaction tracking
    this.interactionService.startInteraction();
    
    // 4. Categorize prompt (fire-and-forget telemetry)
    this.promptCategorizerService.categorizePrompt(request, context, telemetryMessageId);
    
    // 5. Determine intent from command or default
    const intentId = request.command && commandsForAgent 
        ? commandsForAgent[request.command] 
        : defaultIntentId;
    
    // 6. Create handler and get result
    const handler = new ChatParticipantRequestHandler(
        context.history, request, stream, token,
        { agentName: name, agentId: id, intentId },
        () => context.yieldRequested,
        telemetryMessageId
    );
    let result = await handler.getResult();
    
    // 7. Auto-retry with Auto model on rate limit
    if (result.metadata?.shouldAutoSwitchToAuto) {
        request = await this.switchToAutoModel(request, stream, false);
        const retryHandler = new ChatParticipantRequestHandler(...);
        result = await retryHandler.getResult();
    }
    
    return result;
}
```

---

## Step 2: ChatParticipantRequestHandler

**File:** `src/extension/prompt/node/chatParticipantRequestHandler.ts`

### Constructor

Sets up the request context:

1. **Determines location** — Panel, Editor, Terminal, Notebook, or Other
2. **Creates IntentDetector** — For intent classification
3. **Builds conversation history** — Reconstructs `Turn[]` from `ChatRequestTurn | ChatResponseTurn`
4. **Infers document context** — Active editor, selection, language
5. **Creates ChatTelemetryBuilder** — For performance/usage tracking
6. **Creates Turn** — New turn from the current request

```typescript
class ChatParticipantRequestHandler {
    constructor(rawHistory, request, stream, token, chatAgentArgs, ...) {
        this.location = this.getLocation(request);
        this.intentDetector = new IntentDetector();
        
        // Build conversation from history
        const { turns, sessionId } = addHistoryToConversation(rawHistory);
        const latestTurn = Turn.fromRequest(telemetryMessageId, request);
        this.conversation = new Conversation(sessionId, turns.concat(latestTurn));
    }
}
```

### `getResult()` — Main Processing Method

```typescript
async getResult(): Promise<ICopilotChatResult> {
    // 1. Check if auth upgrade needed
    if (await this._shouldAskForPermissiveAuth()) return earlyResult;
    
    // 2. Sanitize variables (filter .copilotignore'd files)
    this.request = await this.sanitizeVariables();
    
    // 3. Look up the command for this intent
    const command = this._commandService.getCommand(intentId, location);
    
    // 4. Validate command usage
    let result = this.checkCommandUsage(command);
    
    if (!result) {
        // 5. Select intent
        const intent = await this.selectIntent(command, history);
        
        // 6. Execute via intent's handler OR DefaultIntentRequestHandler
        if (typeof intent.handleRequest === 'function') {
            chatResult = intent.handleRequest(conversation, request, stream, ...);
        } else {
            const intentHandler = new DefaultIntentRequestHandler(
                intent, conversation, request, stream, token, 
                documentContext, location, chatTelemetry
            );
            chatResult = intentHandler.getResult();
        }
        
        // 7. Collect intent detection context (for improving detection)
        this.intentDetector.collectIntentDetectionContextInternal(...);
        
        // 8. Get endpoint details for result
        const endpoint = await endpointProvider.getChatEndpoint(request);
        result.details = `${endpoint.name} • ${endpoint.multiplier}x`;
    }
    
    // 9. Store conversation
    this._conversationStore.addConversation(turn.id, conversation);
    
    // 10. Mixin metadata
    mixin(result, { metadata: { modelMessageId, responseId, sessionId, agentId, command } });
    
    return result;
}
```

### Intent Selection

```typescript
private async selectIntent(command, history): Promise<IIntent> {
    // Editor-specific logic: infer Generate vs Edit from selection
    if (location === ChatLocation.Editor) {
        if (emptyLine && noHistory) return Intent.Generate;
        if (multiLineSelection) return Intent.Edit;
    }
    
    // Otherwise use the command's intent or UnknownIntent
    return command?.intent ?? unknownIntent;
}
```

---

## Step 3: DefaultIntentRequestHandler

**File:** `src/extension/prompt/node/defaultIntentRequestHandler.ts`

### `getResult()` — Intent Execution

```typescript
async getResult(): Promise<ChatResult> {
    // 1. Invoke the intent to get invocation params
    const intentInvocation = await this.intent.invoke({
        location, documentContext, request
    });
    
    // 2. Handle confirmations if needed
    const confirmationResult = await this.handleConfirmationsIfNeeded();
    
    // 3. Set up request logging/capturing
    const capturingToken = new CapturingToken(
        request.prompt, 'comment',
        request.subAgentInvocationId, request.subAgentName,
        isSubagent ? request.subAgentInvocationId : request.sessionId,
        isSubagent ? request.sessionId : undefined
    );
    
    // 4. Run the tool calling loop
    const resultDetails = await this._requestLogger.captureInvocation(
        capturingToken, 
        () => this.runWithToolCalling(intentInvocation)
    );
    
    // 5. Process result (error handling, streaming, telemetry)
    chatResult = await this.processResult(
        resultDetails.response, responseMessage, chatResult, metadata
    );
    
    return chatResult;
}
```

---

## Step 4: AgentIntent (Agent Mode Specific)

**File:** `src/extension/intents/node/agentIntent.ts`

`AgentIntent` extends `EditCodeIntent` and:

1. **Gets available tools** via `getAgentTools()` — determines which tools are enabled based on model, config, experiments
2. **Resolves prompt customizations** via `PromptRegistry.resolveAllCustomizations()`
3. **Builds the prompt** using `AgentPrompt` (prompt-tsx component)
4. **Handles background summarization** for long conversations

### Tool Selection (`getAgentTools`)

```typescript
export const getAgentTools = async (accessor, request) => {
    const model = await endpointProvider.getChatEndpoint(request);
    
    // Determine which edit tools to enable based on model capabilities
    allowTools[ToolName.ReplaceString] = modelSupportsReplaceString(model);
    allowTools[ToolName.ApplyPatch] = modelSupportsApplyPatch(model);
    allowTools[ToolName.MultiReplaceString] = modelSupportsMultiReplaceString(model);
    
    // Subagent tools (GPT and Anthropic only)
    allowTools[ToolName.SearchSubagent] = isGptOrAnthropic && searchSubagentEnabled;
    allowTools[ToolName.ExecutionSubagent] = isGptOrAnthropic && executionSubagentEnabled;
    
    // Test/task tools based on workspace
    allowTools[ToolName.CoreRunTest] = await testService.hasAnyTests();
    allowTools[ToolName.CoreRunTask] = tasksService.getTasks().length > 0;
    
    // Task complete for autopilot
    allowTools['task_complete'] = request.permissionLevel === 'autopilot';
    
    // Custom tool search for Anthropic
    allowTools[CUSTOM_TOOL_SEARCH_NAME] = isAnthropicCustomToolSearchEnabled(model);
    
    return toolsService.getEnabledTools(request, model, filter);
};
```

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/conversation/vscode-node/chatParticipants.ts` | Entry point, agent registration, model switching |
| `src/extension/prompt/node/chatParticipantRequestHandler.ts` | Request handling, intent selection, conversation building |
| `src/extension/prompt/node/defaultIntentRequestHandler.ts` | Intent execution, tool calling orchestration |
| `src/extension/intents/node/agentIntent.ts` | Agent mode intent, tool selection, prompt building |
| `src/extension/intents/node/editCodeIntent.ts` | Base class for editing intents |
| `src/extension/prompt/node/intentDetector.ts` | Intent detection logic |

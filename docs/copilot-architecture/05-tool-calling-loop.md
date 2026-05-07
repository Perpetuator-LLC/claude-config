# 05 — The Tool Calling Loop

## Overview

The `ToolCallingLoop` is the heart of agent mode. It implements the iterative cycle of: build prompt → call LLM → parse tool calls → execute tools → loop until done.

**File:** `src/extension/intents/node/toolCallingLoop.ts`

---

## The Loop Architecture

```
┌─── ToolCallingLoop._runLoop() ───────────────────────────────────────────┐
│                                                                           │
│  while (true) {                                                          │
│    ┌─── runOne() ─────────────────────────────────────────────────────┐  │
│    │  1. getAvailableTools()     → Get enabled tools for this model   │  │
│    │  2. createPromptContext()   → Build IBuildPromptContext           │  │
│    │  3. buildPrompt()           → Render prompt-tsx → messages[]     │  │
│    │  4. fetch()                 → Send to LLM, get streaming response│  │
│    │  5. Parse response          → Extract tool calls + text          │  │
│    │  6. Execute tool calls      → Invoke each tool, collect results  │  │
│    │  7. Record round            → Store in toolCallRounds[]          │  │
│    └──────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│    if (no tool calls || error) {                                         │
│       Run stop hooks → maybe continue                                    │
│       Check autopilot → maybe continue                                   │
│       break                                                              │
│    }                                                                      │
│                                                                           │
│    if (tool call limit reached) {                                        │
│       Confirm or stop                                                    │
│       break                                                              │
│    }                                                                      │
│  }                                                                        │
│                                                                           │
│  return { toolCallRounds, toolCallResults, response, availableTools }    │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## `ToolCallingLoop` — Abstract Base Class

```typescript
abstract class ToolCallingLoop<TOptions extends IToolCallingLoopOptions> extends Disposable {
    
    // State accumulated across iterations
    private toolCallResults: Record<string, LanguageModelToolResult2> = {};
    private toolCallRounds: IToolCallRound[] = [];
    private stopHookReason: string | undefined;
    private additionalHookContext: string | undefined;
    
    // Abstract methods — implemented by AgentIntent
    protected abstract buildPrompt(context, progress, token): Promise<IBuildPromptResult>;
    protected abstract getAvailableTools(outputStream, token): Promise<LanguageModelToolInformation[]>;
    protected abstract fetch(options, token): Promise<ChatResponse>;
}
```

---

## `run()` — Entry Point

### OTel Instrumentation

The loop is wrapped in an OpenTelemetry span:

```typescript
public async run(outputStream, token): Promise<IToolCallLoopResult> {
    return this._otelService.startActiveSpan(
        `invoke_agent ${agentName}`,
        { kind: SpanKind.INTERNAL, attributes: {
            [GenAiAttr.OPERATION_NAME]: 'invoke_agent',
            [GenAiAttr.PROVIDER_NAME]: 'github',
            [GenAiAttr.AGENT_NAME]: agentName,
            [GenAiAttr.CONVERSATION_ID]: conversationId,
        }},
        async (span) => {
            // Track token usage across all LLM turns
            let totalInputTokens = 0, totalOutputTokens = 0;
            
            const tokenListener = this.onDidReceiveResponse(({ response }) => {
                totalInputTokens += response.usage?.prompt_tokens || 0;
                totalOutputTokens += response.usage?.completion_tokens || 0;
            });
            
            const result = await this._runLoop(outputStream, token, span);
            
            span.setAttributes({
                [CopilotChatAttr.TURN_COUNT]: result.toolCallRounds.length,
                [GenAiAttr.USAGE_INPUT_TOKENS]: totalInputTokens,
                [GenAiAttr.USAGE_OUTPUT_TOKENS]: totalOutputTokens,
            });
            
            return result;
        }
    );
}
```

---

## `_runLoop()` — The Main Loop

```typescript
private async _runLoop(outputStream, token, agentSpan): Promise<IToolCallLoopResult> {
    let i = 0;
    let lastResult;
    let stopHookActive = false;
    
    while (true) {
        // 1. CHECK TOOL CALL LIMIT
        if (lastResult && i++ >= this.options.toolCallLimit) {
            // Autopilot: silently increase limit (up to 200)
            if (permLevel === 'autopilot' && limit < 200) {
                this.options.toolCallLimit = Math.min(Math.round(limit * 3/2), 200);
            } else {
                lastResult = this.hitToolCallLimit(outputStream, lastResult);
                break;
            }
        }
        
        // 2. CHECK YIELD REQUEST
        if (lastResult && this.options.yieldRequested?.()) {
            if (permLevel !== 'autopilot' || this.taskCompleted) break;
        }
        
        // 3. RUN ONE ITERATION
        const result = await this.runOne(outputStream, i, token);
        lastResult = result;
        this.toolCallRounds.push(result.round);
        
        // 4. HANDLE INLINE SUMMARIZATION
        if (result.inlineSummarizationRequested && !result.round.toolCalls.length) {
            // Extract summary, store on round, continue loop
            const summaryText = extractInlineSummary(result.round.response);
            if (summaryText) {
                this.applySummaryToRound(summaryText);
                this.toolCallRounds.pop();  // Remove the summarization round
                continue;
            }
        }
        
        // 5. CHECK IF LOOP SHOULD CONTINUE
        if (!result.round.toolCalls.length || response.type !== Success) {
            
            // 5a. Auto-retry on transient errors (autopilot/auto-approve)
            if (this.shouldAutoRetry(response)) {
                await timeout(1000, token);
                continue;
            }
            
            // 5b. Execute stop hooks
            const stopResult = await this.executeStopHook({ stop_hook_active: stopHookActive }, ...);
            if (stopResult.shouldContinue && stopResult.reasons?.length) {
                this.stopHookReason = joinedReasons;
                stopHookActive = true;
                continue;
            }
            
            // 5c. Autopilot: check task_complete
            if (permLevel === 'autopilot') {
                const autopilotContinue = this.shouldAutopilotContinue(result);
                if (autopilotContinue) {
                    this.stopHookReason = autopilotContinue;
                    continue;
                }
            }
            
            break;
        }
    }
    
    return { toolCallRounds, toolCallResults, response, availableTools, hadIgnoredFiles };
}
```

---

## `runOne()` — Single Iteration

Each iteration performs:

### 1. Get Available Tools

```typescript
const availableTools = await this.getAvailableTools(outputStream, token);
// Ensure task_complete is present for autopilot
availableTools = this.ensureAutopilotTools(availableTools);
```

### 2. Create Prompt Context

```typescript
const promptContext = this.createPromptContext(availableTools, outputStream);
// Includes: query, history, toolCallResults, toolCallRounds, 
//           chatVariables, tools, editedFileEvents, modeInstructions
```

Key: If a stop hook blocked the previous stop, the query becomes the hook's reason text:
```typescript
if (this.stopHookReason) {
    query = formatHookContext([this.stopHookReason]);
} else if (isContinuation) {
    query = 'Please continue';
} else {
    query = this.turn.request.message;
}
```

### 3. Build Prompt

Renders the prompt-tsx tree into `Raw.ChatMessage[]`:

```typescript
const result = await this.buildPrompt(promptContext, progress, token);
// Returns: { messages: Raw.ChatMessage[], tools: OpenAiFunctionDef[] }
```

### 4. Fetch from LLM

```typescript
const response = await this.fetch({
    messages: result.messages,
    requestOptions: { tools, temperature },
    userInitiatedRequest: isFirstIteration,
    turnId: turn.id,
}, token);
```

### 5. Parse Response & Execute Tools

The response contains interleaved text and tool call blocks. For each tool call:

```typescript
for (const toolCall of response.toolCalls) {
    // Validate tool input against JSON schema
    const validation = toolsService.validateToolInput(toolCall.name, toolCall.arguments);
    
    // Invoke the tool
    const result = await toolsService.invokeToolWithEndpoint(
        toolCall.name, 
        { input: validatedInput, toolInvocationToken, ... },
        endpoint,
        token
    );
    
    // Store result for next iteration
    this.toolCallResults[toolCall.id] = result;
}
```

### 6. Record the Round

```typescript
const round: IToolCallRound = {
    response: responseText,
    toolCalls: parsedToolCalls,
    thinking: thinkingData,
    summary: undefined,
    hookContext: undefined,
    timestamp: Date.now(),
};
this.toolCallRounds.push(round);
```

---

## Tool Call Limit Management

Default limits from `getAgentMaxRequests()`:

| Permission Level | Default Limit | Auto-Expansion |
|-----------------|---------------|----------------|
| Normal | Configurable (~25) | Confirm dialog |
| Auto-Approve | Configurable | Confirm dialog |
| Autopilot | Configurable | Auto-expand ×1.5 up to 200 |

When limit is hit with `ToolCallLimitBehavior.Confirm`:
- Shows a confirmation dialog asking to continue
- User can approve, increase limit, or cancel

---

## Autopilot Mode

When `request.permissionLevel === 'autopilot'`:

1. **Task completion** — Model must call `task_complete` tool to signal done
2. **Internal stop hook** — If model stops without `task_complete`, a nudge message is injected
3. **Auto-retry** — Transient errors are retried up to 3 times
4. **Silent limit expansion** — Tool call limit auto-expands (×1.5 up to 200)
5. **Max iterations** — Hard cap of 5 continuation nudges

### Autopilot Nudge Message

```
You have not yet marked the task as complete using the task_complete tool. 
You must call task_complete when done — whether the task involved code changes, 
answering a question, or any other interaction.

Do NOT repeat or restate your previous response. Pick up where you left off.

If you were planning, stop planning and start implementing. 
You are not done until you have fully completed the task.

IMPORTANT: Do NOT call task_complete if:
- You have open questions or ambiguities — make good decisions and keep working
- You encountered an error — try to resolve it or find an alternative approach
- There are remaining steps — complete them first

When you ARE done, first provide a brief text summary of what was accomplished, 
then call task_complete. Both the summary message and the tool call are required.
```

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/intents/node/toolCallingLoop.ts` | Abstract tool calling loop |
| `src/extension/intents/node/agentIntent.ts` | Agent-specific loop implementation |
| `src/extension/intents/node/editCodeIntent.ts` | Base intent with edit processing |
| `src/extension/tools/common/toolsService.ts` | Tool invocation service |
| `src/extension/prompt/common/intents.ts` | `IBuildPromptContext`, `IToolCallRound` types |

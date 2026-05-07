# 09 — Hooks, Lifecycle & Special Modes

## Overview

The hook system allows external extensions to inject context and control the agent lifecycle. Combined with special modes (autopilot, custom agent modes), hooks enable powerful customization of the agent's behavior.

---

## Hook System

**File:** `src/platform/chat/common/chatHookService.ts`

### Hook Types

| Hook | When It Runs | What It Can Do |
|------|-------------|----------------|
| `SessionStart` | Before first tool calling iteration (first turn only) | Provide additional context |
| `Stop` | When the agent tries to stop (no more tool calls) | Block stopping with a reason |
| `SubagentStart` | Before a subagent starts executing | Provide context for subagent |
| `SubagentStop` | When a subagent tries to stop | Block subagent stopping |
| `UserPromptSubmit` | Before processing user message | Modify or block the request |

### Hook Execution Flow

```typescript
// In ToolCallingLoop:

// 1. Before the loop starts
public async runStartHooks(outputStream, token) {
    if (request.subAgentInvocationId) {
        // Execute SubagentStart hook
        const result = await this.executeSubagentStartHook({
            agent_id: invocationId,
            agent_type: agentName,
        }, sessionId, outputStream, token);
        
        if (result.additionalContext) {
            this.additionalHookContext = result.additionalContext;
        }
    } else if (isFirstTurn) {
        // Execute SessionStart hook
        const result = await this.executeSessionStartHook({
            source: 'new',
        }, sessionId, outputStream, token);
        
        if (result.additionalContext) {
            this.additionalHookContext = result.additionalContext;
        }
    }
}

// 2. When the loop tries to stop
const stopHookResult = await this.executeStopHook({
    stop_hook_active: stopHookActive,
}, sessionId, outputStream, token);

if (stopHookResult.shouldContinue && stopHookResult.reasons?.length) {
    // Block stopping — inject reasons as user message
    this.stopHookReason = joinedReasons;
    result.round.hookContext = formatHookContext(stopHookResult.reasons);
    stopHookActive = true;
    continue;  // Loop continues
}
```

### Hook Result Processing

```typescript
function processHookResults({hookType, results, outputStream, logService, onSuccess, onError}) {
    for (const result of results) {
        if (result.error) {
            onError?.(result.error);
        } else {
            onSuccess(result.output);
        }
    }
}
```

### Hook Context Injection

When a stop hook blocks stopping, its reasons are formatted and injected:

```typescript
function formatHookContext(reasons: readonly string[]): string {
    return reasons.map((r, i) => `${i + 1}. ${r}`).join('\n');
}
```

On the next iteration, this becomes the user's "query":

```typescript
if (this.stopHookReason) {
    query = formatHookContext([this.stopHookReason]);
} else if (isContinuation) {
    query = 'Please continue';
} else {
    query = this.turn.request.message;
}
```

### HookAbortError

Hooks can abort the entire request:

```typescript
class HookAbortError extends Error {
    constructor(
        readonly hookType: string,
        readonly stopReason: string,
    ) { super(`Hook ${hookType} aborted: ${stopReason}`); }
}
```

---

## Session Transcript Service

**File:** `src/platform/chat/common/sessionTranscriptService.ts`

Logs the complete agent session for debugging and replay:

```typescript
interface ISessionTranscriptService {
    startSession(sessionId, options, history?): Promise<void>;
    logUserMessage(sessionId, message): void;
    logAssistantTurnStart(sessionId, turnId): void;
    logAssistantTurnEnd(sessionId, turnId): void;
    logToolCall(sessionId, toolRequest: ToolRequest): void;
}
```

---

## Custom Agent Modes

**File:** `src/extension/prompts/node/agent/agentPrompt.tsx`

Custom modes (defined in `.vscode/agents/` or mode configuration) inject additional instructions:

```tsx
// In AgentPrompt.getAgentCustomInstructions():
if (this.props.promptContext.modeInstructions) {
    const { name, content, toolReferences } = modeInstructions;
    
    customInstructionsBodyParts.push(
        <Tag name='modeInstructions'>
            You are currently running in "{name}" mode. 
            Below are your instructions for this mode, they must take precedence 
            over any instructions above.
            
            {resolvedContent}
        </Tag>
    );
}
```

### Mode Instructions Placement

Custom instructions can go in either system or user messages based on config:

```typescript
const putInSystem = config.CustomInstructionsInSystemMessage;
return putInSystem 
    ? <SystemMessage>{parts}</SystemMessage> 
    : <UserMessage>{parts}</UserMessage>;
```

---

## Autopilot Mode

### Entry

Activated when `request.permissionLevel === 'autopilot'`.

### Key Behaviors

1. **Task Completion Requirement**
   - The `task_complete` tool is always available
   - The system prompt includes: "When you have fully completed the task, call the task_complete tool"
   
2. **Internal Stop Hook**
   - If the model stops without calling `task_complete`, a nudge message is injected
   - Up to 5 nudge iterations
   
3. **Auto-Retry**
   - Transient errors are retried (up to 3 times)
   - 1 second delay between retries
   
4. **Silent Limit Expansion**
   - Tool call limit auto-expands by 1.5× up to 200
   
5. **No Yield on Incomplete**
   - If VS Code requests yield but task isn't complete, keep going

### Progress Indicators

```typescript
// Shows a progress spinner during continuation
outputStream?.progress(
    'Continuing with Autopilot: Task not yet complete',
    async () => {
        await deferred.p;
        return 'Continued with Autopilot: Task not yet complete';
    }
);
```

---

## Subagent System

### How Subagents Work

When the model calls `runSubagent`, a new `ToolCallingLoop` is created:

1. Parent stores trace context: `otelService.storeTraceContext('subagent:invocation:{id}', ...)`
2. Subagent gets its own `CapturingToken` for logging
3. SubagentStart hooks execute
4. Subagent runs its own tool calling loop
5. SubagentStop hooks execute before completion
6. Result is returned to parent as tool result

### Search Subagent vs Execution Subagent

| Feature | Search Subagent | Execution Subagent |
|---------|----------------|-------------------|
| Purpose | Codebase exploration | Command execution |
| Tools | Read-only (search, read) | Terminal, commands |
| Prompt | Exploration-focused instructions | Execution-focused |
| When used | "prefer for codebase exploration" | "for most terminal commands" |

---

## OTel (OpenTelemetry) Instrumentation

### Agent Span

```typescript
_otelService.startActiveSpan(
    `invoke_agent ${agentName}`,
    {
        kind: SpanKind.INTERNAL,
        attributes: {
            'gen_ai.operation.name': 'invoke_agent',
            'gen_ai.provider.name': 'github',
            'gen_ai.agent.name': agentName,
            'gen_ai.conversation.id': sessionId,
            'copilot_chat.session_id': sessionId,
        }
    },
    async (span) => {
        // Per-turn events
        span.addEvent('turn_start', { turnId });
        span.addEvent('turn_end', { turnId });
        
        // User message event
        span.addEvent('user_message', { content: userMessage });
        
        // Final attributes
        span.setAttributes({
            'copilot_chat.turn_count': rounds.length,
            'gen_ai.usage.input_tokens': totalInputTokens,
            'gen_ai.usage.output_tokens': totalOutputTokens,
            'gen_ai.response.model': resolvedModel,
        });
    }
);
```

### Metrics

```typescript
GenAiMetrics.incrementSessionCount(otelService);
GenAiMetrics.recordAgentDuration(otelService, agentName, durationSec);
GenAiMetrics.recordAgentTurnCount(otelService, agentName, turnCount);
GenAiMetrics.incrementAgentSummarizationCount(otelService, outcome);
```

---

## Permission Levels

| Level | Description | Tool Approval | Auto-Retry | Task Complete |
|-------|------------|---------------|------------|---------------|
| `normal` | Default interactive | Per-tool confirmation | No | No |
| `autoApprove` | Auto-approve all tools | Automatic | Yes (3 retries) | No |
| `autopilot` | Fully autonomous | Automatic | Yes (3 retries) | Required |

---

## Key Source Files

| File | Role |
|------|------|
| `src/platform/chat/common/chatHookService.ts` | Hook service interface |
| `src/extension/intents/node/hookResultProcessor.ts` | Hook result processing |
| `src/platform/chat/common/sessionTranscriptService.ts` | Session transcript |
| `src/extension/intents/node/toolCallingLoop.ts` | Hook execution in loop |
| `src/extension/prompts/node/agent/agentPrompt.tsx` | Mode instructions |
| `src/platform/otel/common/` | OpenTelemetry instrumentation |

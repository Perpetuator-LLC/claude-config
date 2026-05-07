# 07 — Context, History & Summarization

## Overview

The prompt includes conversation history, tool call results, and workspace context. For long conversations, the system uses summarization and cache breakpoints to manage the context window.

---

## Conversation Model

**File:** `src/extension/prompt/common/conversation.ts`

### `Conversation`

```typescript
class Conversation {
    readonly sessionId: string;
    readonly turns: Turn[];
}
```

### `Turn`

Each turn represents one user request → assistant response cycle:

```typescript
class Turn {
    readonly id: string;
    readonly request: { message: string; type: 'user' };
    readonly chatVariables: ChatVariablesCollection;
    readonly toolReferences: InternalToolReference[];
    
    // Accumulated during processing
    rounds: IToolCallRound[];          // Tool calling iterations within this turn
    responseStatus: TurnStatus;
    responseId?: string;
    metadata: Map<string, any>;
    
    // Continuations
    isContinuation: boolean;
    pendingSummaries: Map<string, string>;
}
```

### `IToolCallRound`

```typescript
interface IToolCallRound {
    response: string;                  // Assistant's text response
    toolCalls: IToolCall[];            // Tool calls made in this round
    thinking?: ThinkingDataItem;       // Extended thinking (if enabled)
    summary?: string;                  // Summarized version (if compacted)
    hookContext?: string;              // Stop hook reasons
    timestamp: number;
}
```

---

## Conversation History Rendering

### Standard History (`AgentConversationHistory`)

**File:** `src/extension/prompts/node/agent/agentConversationHistory.tsx`

Renders prior turns as alternating user/assistant messages:

```
UserMessage: [Turn 1 query]
AssistantMessage: [Turn 1 response with tool calls]
ToolMessage: [Tool results]
UserMessage: [Turn 2 query]
AssistantMessage: [Turn 2 response]
...
```

### Summarized History (`SummarizedConversationHistory`)

**File:** `src/extension/prompts/node/agent/summarizedConversationHistory.tsx`

For long conversations, older rounds are summarized to save tokens:

```
[System] <conversation-summary>
  Summarized content of rounds 1-15
</conversation-summary>

[Detailed rounds 16-20 with full tool calls and results]

[Current user message]
```

---

## Summarization System

### Background Summarization

**File:** `src/extension/prompts/node/agent/backgroundSummarizer.ts`

After each tool calling round, a background summarization may be triggered:

```typescript
class BackgroundSummarizer {
    // Runs a separate LLM call to summarize older rounds
    async summarize(conversation, endpoint): Promise<IBackgroundSummarizationResult> {
        // Uses a summarization-specific prompt
        const prompt = "You are a helpful AI assistant tasked with summarizing conversations...";
        
        // Generates a concise summary of the conversation so far
        const summary = await this.callLLM(prompt, conversation);
        
        return { summary, roundId: targetRound };
    }
}
```

### Inline Summarization

For Claude 4.6+ with context compaction enabled, summarization happens inline:

1. When context is getting full, the system sends a summarization request as part of the normal loop
2. The model responds with ONLY summary text (no tool calls)
3. The summary is extracted and stored on the appropriate round
4. The summarization round is removed from the round list
5. The loop continues with compacted history

```typescript
// Detection in the loop:
if (result.inlineSummarizationRequested && !result.round.toolCalls.length) {
    const summaryText = extractInlineSummary(result.round.response);
    this.applySummaryToRound(summaryText);
    this.toolCallRounds.pop();  // Remove summarization round
    continue;  // Continue with compacted history
}
```

---

## Cache Breakpoints

### Purpose

Cache breakpoints allow the LLM provider to cache portions of the prompt, reducing latency and cost on subsequent calls within the same conversation.

### How They Work

When `enableCacheBreakpoints` is true:

1. The prompt is divided into segments
2. Breakpoints are placed at strategic positions (after system prompt, after history, etc.)
3. The LLM provider can cache everything before the last breakpoint
4. On the next iteration, only content after the breakpoint needs processing

### Implementation

The `SummarizedConversationHistory` component handles cache breakpoints:

```tsx
<SummarizedConversationHistory
    enableCacheBreakpoints={true}
    triggerSummarize={this.props.triggerSummarize}
    inlineSummarization={this.props.inlineSummarization}
    ...
/>
```

---

## Global Agent Context

Provides workspace awareness. Cached per conversation:

### Components

1. **Operating System** — `macOS`, `Windows`, `Linux`
2. **Workspace Info**
   - Folder paths
   - File tree structure (depth-limited)
   - `.vscode/tasks.json` definitions
3. **Active State**
   - Terminal names and recent output
   - Open editors and selections
   - Running tasks
4. **Memory**
   - Repository memory (`/memories/repo/`)
   - Session memory file list (`/memories/session/`)
   - User memory (first 200 lines auto-loaded)

### Cache Key

```typescript
function getGlobalContextCacheKey(): string {
    // Combines workspace folders, active editors, terminals, tasks
    // If key matches previous turn's cache key, reuse rendered context
}
```

---

## Context Compaction (Anthropic)

**Enabled via:** `isAnthropicContextEditingEnabled()`

When context compaction is enabled for Claude models:

1. The system tracks token usage across iterations
2. When approaching the context window limit, it triggers inline summarization
3. Older rounds are replaced with their summaries
4. The model is instructed not to discuss context management with the user:

```
Your conversation history is automatically compressed as context fills, 
enabling you to work persistently without hitting limits.
Never discuss context limits, memory protocols, or your internal state with the user.
```

---

## OpenAI Responses API Context Management

For OpenAI models using the Responses API:

```typescript
function isResponsesCompactionContextManagementEnabled(endpoint, config, experiments): boolean {
    return endpoint.apiType === 'responses'
        && config.ResponsesApiContextManagementEnabled
        && !modelsWithoutResponsesContextManagement.has(endpoint.family);
}
```

This uses OpenAI's built-in context management instead of client-side summarization.

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/prompt/common/conversation.ts` | Conversation, Turn, IToolCallRound |
| `src/extension/prompts/node/agent/agentConversationHistory.tsx` | History rendering |
| `src/extension/prompts/node/agent/summarizedConversationHistory.tsx` | Summarized history with cache breakpoints |
| `src/extension/prompts/node/agent/backgroundSummarizer.ts` | Background summarization |
| `src/extension/prompts/node/agent/agentPrompt.tsx` | Global context rendering |
| `src/extension/tools/node/memoryContextPrompt.tsx` | Memory instructions |

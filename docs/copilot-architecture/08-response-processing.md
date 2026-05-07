# 08 — Response Processing

## Overview

After the LLM responds, the output is processed through several layers: streaming, code block detection, linkification, error handling, and result assembly.

---

## Streaming Pipeline

### Response Flow

```
LLM Provider
    │
    ▼
ChatResponse (streaming SSE events)
    │
    ▼
Protocol Adapter (Anthropic/OpenAI format → internal format)
    │
    ▼
ResponseProcessorContext
    │
    ├─→ CodeBlockTrackingChatResponseStream  (code block detection)
    ├─→ ResponseStreamWithLinkification       (file path linking)
    └─→ ChatResponseStreamImpl                (VS Code API)
         │
         ▼
    VS Code Chat UI (renders markdown, code blocks, references)
```

### Response Types

```typescript
enum ChatFetchResponseType {
    Success,        // Normal response
    Error,          // Provider error
    RateLimited,    // Rate limit hit
    QuotaExceeded,  // Quota exhausted
    Canceled,       // User cancelled
    OffTopic,       // Content filtered
    PromptFiltered, // Input blocked
}
```

---

## Response Stream Processing

### `ChatResponseStreamImpl`

**File:** `src/util/common/chatResponseStreamImpl.ts`

Wraps the VS Code `ChatResponseStream` with filtering and transformation:

```typescript
class ChatResponseStreamImpl {
    // Filter parts before sending to VS Code
    static filter(stream, predicate) {
        // e.g., filter out references that point to the current editor document
    }
    
    // Stream markdown text
    markdown(text: string): void;
    
    // Stream a code block
    codeblock(code: string, language: string): void;
    
    // Stream a file reference
    reference(uri: URI, location?: Range): void;
    
    // Stream progress indicator
    progress(message: string): void;
}
```

### Code Block Processing

**File:** `src/extension/codeBlocks/node/codeBlockProcessor.ts`

The `CodeBlockTrackingChatResponseStream` wraps the response stream to track code blocks:

```typescript
class CodeBlockTrackingChatResponseStream {
    // Detects when the model outputs fenced code blocks
    // Tracks metadata: language, file path context, line ranges
    // Enables "Apply", "Copy", "Insert" actions on code blocks
}
```

### Linkification

**File:** `src/extension/linkify/common/responseStreamWithLinkification.ts`

`ResponseStreamWithLinkification` transforms file paths in markdown to clickable links:

```typescript
class ResponseStreamWithLinkification {
    // Converts: `src/utils/helpers.ts` → [src/utils/helpers.ts](file:///path/to/src/utils/helpers.ts)
    // Handles line number references: `file.ts:42` → link with line 42
}
```

---

## Result Processing

### `DefaultIntentRequestHandler.processResult()`

After the tool calling loop completes:

```typescript
private async processResult(response, responseMessage, chatResult, metadata, telemetry, toolCallRounds) {
    
    switch (response.type) {
        case ChatFetchResponseType.Success:
            // Record success telemetry
            // Track token usage
            // Track edit survival
            break;
            
        case ChatFetchResponseType.RateLimited:
            // Show rate limit message with model switching options
            // "You've been rate limited. Switch to Auto model?"
            chatResult.metadata.shouldAutoSwitchToAuto = true;
            break;
            
        case ChatFetchResponseType.QuotaExceeded:
            // Show quota exceeded message
            break;
            
        case ChatFetchResponseType.OffTopic:
            // Content was filtered
            chatResult.errorDetails = { responseIsFiltered: true };
            break;
            
        case ChatFetchResponseType.PromptFiltered:
            // Input was blocked
            break;
            
        case ChatFetchResponseType.Error:
            // Show error details
            break;
    }
    
    // Apply intent-specific modifications
    if (chatResult.errorDetails && intentInvocation.modifyErrorDetails) {
        chatResult.errorDetails = intentInvocation.modifyErrorDetails(chatResult.errorDetails, response);
    }
    
    // Show ignored files warning
    if (hadIgnoredFiles) {
        stream.markdown(HAS_IGNORED_FILES_MESSAGE);
    }
    
    return chatResult;
}
```

---

## Result Metadata

The chat result carries metadata used by the UI and subsequent turns:

```typescript
interface IResultMetadata {
    // Identity
    modelMessageId: string;
    responseId: string;
    sessionId: string;
    agentId: string;
    command?: string;
    
    // Tool calling state
    toolCallRounds: IToolCallRound[];
    toolCallResults: Record<string, LanguageModelToolResult2>;
    resolvedModel?: string;
    
    // Rate limiting
    shouldAutoSwitchToAuto?: boolean;
}
```

---

## Telemetry

### Per-Request Telemetry

```typescript
class ChatTelemetryBuilder {
    // Tracks:
    // - Request timing (time to first token, total time)
    // - Token counts (prompt, completion, cached)
    // - Model used
    // - Intent detected
    // - Tool calls made
    // - Error type (if any)
    // - Conversation length
}
```

### Model Message Telemetry

```typescript
function sendModelMessageTelemetry(telemetryService, data) {
    telemetryService.sendMSFTTelemetryEvent('modelMessage', {
        model, intent, location, numTokens, numToolCalls, responseTime, ...
    });
}
```

---

## Error Handling

### Error Types & Recovery

| Error Type | Handling |
|-----------|---------|
| `ToolCallCancelledError` | Set turn status to Cancelled, return empty result |
| `CancellationError` | Return `CanceledResult` |
| `EmptyPromptError` | Return empty result |
| `HookAbortError` | Log abort, return empty result |
| Rate limit | Show switch-to-auto option |
| Quota exceeded | Show upgrade option |
| Content filter | Show filtered message |
| Network error | Show error details |

### Auto-Retry (Autopilot/Auto-Approve)

```typescript
private shouldAutoRetry(response): boolean {
    if (permLevel !== 'autoApprove' && permLevel !== 'autopilot') return false;
    if (this.autopilotRetryCount >= MAX_AUTOPILOT_RETRIES) return false;
    
    // Don't retry these:
    if (response.type === RateLimited || QuotaExceeded || Canceled || OffTopic) return false;
    
    return response.type !== Success;
}
```

---

## Token Usage Tracking

### Anthropic Token Usage Metadata

```typescript
class AnthropicTokenUsageMetadata {
    prompt_tokens: number;
    completion_tokens: number;
    prompt_tokens_details?: {
        cached_tokens?: number;
    };
}
```

### Context Window Adjustment (Anthropic Adapter)

The Anthropic adapter adjusts reported token usage to make the agent think it has a 200k context window, even if the actual window is smaller:

```typescript
private adjustTokenUsageForContextWindow(context, usage) {
    // Scales usage numbers to match a 200k window
    // This prevents the model from self-limiting on smaller contexts
}
```

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/prompt/node/defaultIntentRequestHandler.ts` | Result processing |
| `src/extension/codeBlocks/node/codeBlockProcessor.ts` | Code block tracking |
| `src/extension/linkify/common/responseStreamWithLinkification.ts` | File linkification |
| `src/util/common/chatResponseStreamImpl.ts` | Stream implementation |
| `src/extension/prompt/node/chatParticipantTelemetry.ts` | Telemetry builder |
| `src/extension/agents/node/adapters/anthropicAdapter.ts` | Anthropic protocol handling |

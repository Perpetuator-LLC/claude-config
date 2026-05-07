# GitHub Copilot Chat — Complete Execution Flow

> Comprehensive documentation of the end-to-end request lifecycle in the GitHub Copilot Chat VS Code extension, with emphasis on Claude Opus 4.6/4.5 model-specific pathways.

## Documents

| File | Description |
|------|-------------|
| [01-activation-and-registration.md](01-activation-and-registration.md) | Extension activation, service registration, chat participant setup |
| [02-request-pipeline.md](02-request-pipeline.md) | How user input flows from VS Code → chat participant → intent → handler |
| [03-prompt-construction.md](03-prompt-construction.md) | Prompt-TSX system, model-specific prompts, system message assembly |
| [04-claude-model-specific.md](04-claude-model-specific.md) | Claude Opus 4.6/4.5 specific prompts, adapter, and routing |
| [05-tool-calling-loop.md](05-tool-calling-loop.md) | The agentic tool calling loop — iteration, invocation, result handling |
| [06-tool-definitions.md](06-tool-definitions.md) | Complete tool catalog, naming, schemas, and selection logic |
| [07-context-and-history.md](07-context-and-history.md) | Conversation history, summarization, cache breakpoints, context compaction |
| [08-response-processing.md](08-response-processing.md) | Post-LLM response handling, streaming, code blocks, linkification |
| [09-hooks-and-lifecycle.md](09-hooks-and-lifecycle.md) | Hook system (SessionStart, Stop, SubagentStart/Stop), autopilot mode |

## Quick Architecture Diagram

```
User Input (VS Code Chat Panel)
       │
       ▼
┌─────────────────────────────────────┐
│  ChatAgents.getChatParticipantHandler │  ← Registered per agent type
│  (chatParticipants.ts)               │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  ChatParticipantRequestHandler      │  ← Selects intent, builds conversation
│  (chatParticipantRequestHandler.ts) │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  DefaultIntentRequestHandler        │  ← Runs tool calling with intent
│  (defaultIntentRequestHandler.ts)   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  ToolCallingLoop._runLoop()         │  ← Main agentic loop
│  (toolCallingLoop.ts)               │
│                                     │
│  for each iteration:                │
│    1. buildPrompt()                 │
│    2. getAvailableTools()           │
│    3. fetch() → LLM                 │
│    4. Parse tool calls              │
│    5. Execute tools                 │
│    6. Loop or stop                  │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  Prompt Construction (prompt-tsx)    │
│                                     │
│  AgentPrompt renders:               │
│   ┌─ SystemMessage                  │
│   │   ├─ CopilotIdentityRules      │
│   │   ├─ SafetyRules               │
│   │   └─ Model-Specific Instructions│
│   │       (via PromptRegistry)      │
│   ├─ CustomInstructions             │
│   ├─ GlobalAgentContext             │
│   ├─ ConversationHistory            │
│   ├─ ToolCallResults                │
│   └─ UserMessage + ReminderInstr.   │
└─────────────────────────────────────┘
```

# 03 — Prompt Construction System

## Overview

Prompts are built using the `@vscode/prompt-tsx` library — a React-like JSX system for composing LLM prompts with automatic token budget management.

---

## Prompt-TSX Fundamentals

- **`PromptElement<Props>`** — Base class for prompt components (like React components)
- **`render(state, sizing)`** — Returns JSX that represents prompt content
- **`<SystemMessage>`** — Maps to `role: system`
- **`<UserMessage>`** — Maps to `role: user`
- **Priority system** — Higher `priority` components survive token trimming first
- **`flexGrow`** — Components can expand into available token budget
- **`<Tag name="...">`** — Wraps content in XML-like tags for structure

---

## The Main Agent Prompt

**File:** `src/extension/prompts/node/agent/agentPrompt.tsx`

### `AgentPrompt` — Top-Level Prompt Component

This is the root component rendered on each agent mode request:

```tsx
class AgentPrompt extends PromptElement<AgentPromptProps> {
    async render(state, sizing) {
        const customizations = this.props.customizations;
        const CopilotIdentityRules = customizations.CopilotIdentityRulesClass;
        const SafetyRules = customizations.SafetyRulesClass;
        
        return <>
            {/* BASE AGENT INSTRUCTIONS */}
            <SystemMessage>
                You are an expert AI programming assistant, working with a user in the VS Code editor.
                <CopilotIdentityRules />    {/* "Your name is GitHub Copilot. Using {model}." */}
                <SafetyRules />             {/* Microsoft content policies */}
            </SystemMessage>
            
            {/* MODEL-SPECIFIC SYSTEM PROMPT */}
            {instructions}                  {/* Via PromptRegistry — see section below */}
            
            {/* MEMORY INSTRUCTIONS */}
            <SystemMessage>
                <MemoryInstructionsPrompt />
            </SystemMessage>
            
            {/* CUSTOM INSTRUCTIONS (.github/copilot-instructions.md, mode instructions) */}
            {customInstructions}
            
            {/* AUTOPILOT TASK COMPLETE INSTRUCTIONS */}
            {isAutopilot && <SystemMessage>
                When you have fully completed the task, call the task_complete tool...
            </SystemMessage>}
            
            {/* TEMPLATE VARIABLES */}
            {templateVariablesContext}
            
            {/* GLOBAL AGENT CONTEXT (workspace, OS, terminals, editors, tasks) */}
            <UserMessage>
                {globalAgentContext}
            </UserMessage>
            
            {/* CONVERSATION HISTORY + TOOL RESULTS + USER MESSAGE */}
            {enableCacheBreakpoints 
                ? <SummarizedConversationHistory ... />   {/* With cache breakpoints */}
                : <>
                    <AgentConversationHistory ... />      {/* Prior turns */}
                    <AgentUserMessage ... />               {/* Current user message */}
                    <ChatToolCalls ... />                   {/* Tool call results */}
                  </>
            }
        </>;
    }
}
```

### Message Assembly Order

The final prompt sent to the LLM follows this structure:

```
┌─────────────── System Messages ───────────────┐
│ 1. Identity + Safety Rules                     │
│ 2. Model-Specific Instructions                 │
│    (from PromptRegistry)                       │
│ 3. Memory Instructions                         │
│ 4. Custom Instructions                         │
│    (.github/copilot-instructions.md)           │
│ 5. Mode Instructions                           │
│    (custom agent modes)                        │
│ 6. Autopilot instructions (if applicable)      │
└────────────────────────────────────────────────┘
┌─────────────── User Messages ─────────────────┐
│ 7. Global Context                              │
│    - OS, workspace folders, structure          │
│    - Active terminals, editors, tasks          │
│    - Repository memory                         │
│ 8. Conversation History (prior turns)          │
│ 9. Current User Message                        │
│    - User query (in <userRequest> tags)        │
│    - Reminder instructions                     │
│    - Tool references hint                      │
│ 10. Tool Call Results (current turn rounds)    │
└────────────────────────────────────────────────┘
```

---

## The Prompt Registry

**File:** `src/extension/prompts/node/agent/promptRegistry.ts`

### How It Works

The `PromptRegistry` is a singleton that matches model endpoints to prompt configurations:

```typescript
export const PromptRegistry = new class {
    private promptsWithMatcher: PromptWithMatcher[] = [];
    private familyPrefixList: { prefix: string; prompt: IAgentPromptCtor }[] = [];
    
    registerPrompt(prompt: IAgentPromptCtor) {
        if (prompt.matchesModel) {
            this.promptsWithMatcher.push(prompt);
        }
        for (const prefix of prompt.familyPrefixes) {
            this.familyPrefixList.push({ prefix, prompt });
        }
    }
    
    async resolveAllCustomizations(instantiationService, endpoint) {
        const resolver = await this.getPromptResolver(endpoint);
        const agentPrompt = resolver ? instantiationService.createInstance(resolver) : undefined;
        
        return {
            SystemPrompt: agentPrompt?.resolveSystemPrompt(endpoint) ?? DefaultAgentPrompt,
            ReminderInstructionsClass: agentPrompt?.resolveReminderInstructions(endpoint) ?? DefaultReminderInstructions,
            ToolReferencesHintClass: agentPrompt?.resolveToolReferencesHint(endpoint) ?? DefaultToolReferencesHint,
            CopilotIdentityRulesClass: agentPrompt?.resolveCopilotIdentityRules(endpoint) ?? CopilotIdentityRules,
            SafetyRulesClass: agentPrompt?.resolveSafetyRules(endpoint) ?? SafetyRules,
            userQueryTagName: agentPrompt?.resolveUserQueryTagName(endpoint) ?? 'userRequest',
        };
    }
}
```

### Resolution Priority

1. **`matchesModel(endpoint)`** — First check custom matchers (e.g., specific model IDs)
2. **Family prefix match** — Then check if `endpoint.family.startsWith(prefix)`
3. **Default fallback** — `DefaultAgentPrompt` if no match

### Customization Points Per Model

Each registered prompt can customize:

| Property | What It Controls |
|----------|-----------------|
| `SystemPrompt` | The main agent instructions component |
| `ReminderInstructionsClass` | Editing reminders appended to user messages |
| `ToolReferencesHintClass` | How tool references are presented |
| `CopilotIdentityRulesClass` | Identity statement ("I am GitHub Copilot using...") |
| `SafetyRulesClass` | Content policy rules |
| `userQueryTagName` | XML tag wrapping user query (default: `userRequest`) |

### Registered Prompt Resolvers

**File:** `src/extension/prompts/node/agent/allAgentPrompts.ts`

All model-specific prompts are imported via side-effect imports:

```typescript
import './anthropicPrompts';      // Claude family
import './familyHPrompts';        // Family H models
import './geminiPrompts';         // Gemini family
import './minimaxPrompts';        // MiniMax models
import './vscModelPrompts';       // VS Code special models
import './openai/defaultOpenAIPrompt';
import './openai/gpt5Prompt';
import './openai/gpt51Prompt';
import './openai/gpt52Prompt';
// ... more OpenAI variants
import './xAIPrompts';            // Grok family
import './zaiPrompts';            // ZAI models
```

---

## CopilotIdentityRules

**File:** `src/extension/prompts/node/base/copilotIdentity.tsx`

```tsx
class CopilotIdentityRules extends PromptElement {
    render() {
        return <>
            When asked for your name, you must respond with "GitHub Copilot". 
            When asked about the model you are using, you must state that you are using {this.promptEndpoint.name}.
            Follow the user's requirements carefully & to the letter.
        </>;
    }
}
```

## SafetyRules

**File:** `src/extension/prompts/node/base/safetyRules.tsx`

```tsx
class SafetyRules extends PromptElement {
    render() {
        return <>
            Follow Microsoft content policies.
            Avoid content that violates copyrights.
            If you are asked to generate content that is harmful, hateful, racist, sexist, 
            lewd, or violent, only respond with "Sorry, I can't assist with that."
            Keep your answers short and impersonal.
        </>;
    }
}
```

---

## Global Agent Context

The `GlobalAgentContext` component provides workspace awareness:

- **OS information** — Operating system type
- **Workspace folders** — Root directories
- **Workspace structure** — File tree (trimmed to fit token budget)
- **Active terminals** — Terminal names and recent commands
- **Active editors** — Open files and selections
- **Available tasks** — VS Code task definitions
- **Repository memory** — Contents of `/memories/repo/`
- **Session memory** — File listing of `/memories/session/`

This context is cached per conversation and only regenerated when the cache key changes.

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/prompts/node/agent/agentPrompt.tsx` | Top-level agent prompt assembly |
| `src/extension/prompts/node/agent/promptRegistry.ts` | Model-specific prompt resolution |
| `src/extension/prompts/node/agent/allAgentPrompts.ts` | Side-effect imports for all models |
| `src/extension/prompts/node/agent/defaultAgentInstructions.tsx` | Default system prompt |
| `src/extension/prompts/node/base/copilotIdentity.tsx` | Identity rules |
| `src/extension/prompts/node/base/safetyRules.tsx` | Safety rules |
| `src/extension/prompts/node/agent/agentConversationHistory.tsx` | Conversation history rendering |
| `src/extension/prompts/node/panel/chatVariables.tsx` | User message + context variables |
| `src/extension/prompts/node/panel/customInstructions.tsx` | Custom instructions (.md files) |

# 01 — Extension Activation & Chat Participant Registration

## Extension Entry Point

**File:** `src/extension/extension/vscode/extension.ts`

### `baseActivate(configuration)`

The extension activates through `baseActivate()`, which:

1. **Version check** — Validates VS Code version compatibility, blocks pre-release on stable.
2. **L10n setup** — Configures localization bundles.
3. **Dev config** — Loads `.env` keys in non-production mode.
4. **Service instantiation** — Creates the DI container via `InstantiationServiceBuilder`.
5. **Experimentation** — Awaits the experimentation service to ensure A/B test cache is fresh.
6. **Contribution loading** — Creates `ContributionCollection` from all registered `IExtensionContributionFactory[]`, then awaits activation blockers.
7. **API export** — Returns `CopilotExtensionApi` for other extensions to consume.

```typescript
// Simplified activation flow
export async function baseActivate(configuration) {
    const instantiationService = createInstantiationService(configuration);
    
    await instantiationService.invokeFunction(async accessor => {
        await accessor.get(IExperimentationService).hasTreatments();
        const contributions = new ContributionCollection(configuration.contributions);
        await contributions.waitForActivationBlockers();
    });
    
    return { getAPI(version) { ... } };
}
```

### Service Registration (`createInstantiationService`)

Builds the dependency injection container. Services are registered in the configuration callback and include:

- **Platform services:** `IFileSystemService`, `ILogService`, `IWorkspaceService`, `IGitService`
- **Networking:** `IEndpointProvider`, `IChatEndpoint`
- **Tools:** `IToolsService`, `IToolGroupingService`
- **Authentication:** `IAuthenticationService`
- **Telemetry:** `ITelemetryService`, `IExperimentationService`
- **Chat:** `IChatSessionService`, `IConversationStore`, `IChatHookService`

The `IIgnoreService.init()` call runs (non-blocking) to read `.copilotignore` files.

---

## Chat Participant Registration

**File:** `src/extension/conversation/vscode-node/chatParticipants.ts`

### `ChatAgentService.register()`

Creates and registers all chat participants with VS Code:

| Participant | Agent Name | Default Intent | Icon |
|------------|-----------|---------------|------|
| Default | `'copilot'` | `Intent.Unknown` / `Intent.AskAgent` | `copilot` |
| Agent Mode | `'copilot-agent'` (editsAgentName) | `Intent.Agent` | `tools` |
| Edit Mode | `'copilot-editor'` | `Intent.Edit` | `copilot` |
| Editor Editing | `'copilot-editor-editor'` | `Intent.InlineChat` | `copilot` |
| VS Code | `'@vscode'` | `Intent.VSCode` | `vscode`/`vscode-insiders` |
| Terminal | `'@terminal'` | `Intent.Terminal` | `terminal` |
| Notebook | `'notebook'` | `Intent.Editor` | `copilot` |

### `createAgent(name, defaultIntentIdOrGetter)`

```typescript
private createAgent(name, defaultIntentIdOrGetter, options?) {
    const id = getChatParticipantIdFromName(name);
    const agent = vscode.chat.createChatParticipant(id, 
        this.getChatParticipantHandler(id, name, defaultIntentIdOrGetter)
    );
    agent.onDidReceiveFeedback(e => this.userFeedbackService.handleFeedback(e, id));
    agent.onDidPerformAction(e => this.userFeedbackService.handleUserAction(e, id));
    return agent;
}
```

Each agent gets:
- A **request handler** (the core processing function)
- A **feedback handler** (thumbs up/down)
- An **action handler** (copy, insert, etc.)
- Optional: **titleProvider**, **summarizer**, **additionalWelcomeMessage**

### Default Agent Special Logic

The default agent dynamically selects its intent based on configuration:

```typescript
const intentGetter = (request) => {
    if (config.AskAgent && request.model.capabilities.supportsToolCalling && config.chatAgentEnabled) {
        return Intent.AskAgent;  // Agentic Ask mode
    }
    return Intent.Unknown;  // Classic chat mode
};
```

---

## Key Intents (Agent Modes)

**File:** `src/extension/common/constants.ts` (Intent enum)

| Intent | Description |
|--------|-------------|
| `Intent.Agent` | Full agent mode with tool calling |
| `Intent.AskAgent` | Agentic ask mode (read-only tools) |
| `Intent.Edit` | Edit mode for code modifications |
| `Intent.InlineChat` | Inline chat (Ctrl+I) |
| `Intent.Generate` | Code generation |
| `Intent.Terminal` | Terminal-specific assistance |
| `Intent.VSCode` | VS Code-specific questions |
| `Intent.Unknown` | Classic conversational chat |

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/extension/vscode/extension.ts` | Main activation entry point |
| `src/extension/conversation/vscode-node/chatParticipants.ts` | Chat participant registration |
| `src/extension/common/constants.ts` | Intent definitions |
| `src/extension/common/contributions.ts` | Contribution loading system |
| `src/util/common/services.ts` | Service DI infrastructure |

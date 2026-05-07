# 06 — Tool Definitions & Selection

## Overview

Tools are the actions the model can take. They're registered as VS Code `LanguageModelTool` instances and presented to the LLM as function definitions. The tool ecosystem includes both Copilot-internal tools and MCP (Model Context Protocol) tools.

---

## Tool Name Mapping

**File:** `src/extension/tools/common/toolNames.ts`

Every tool has two names:
- **Display name** (sent to LLM): e.g., `read_file`, `replace_string_in_file`
- **Contributed name** (VS Code registration): e.g., `copilot_readFile`, `copilot_replaceString`

```typescript
export enum ToolName {
    // File operations
    ReadFile = 'read_file',
    CreateFile = 'create_file',
    EditFile = 'insert_edit_into_file',
    ReplaceString = 'replace_string_in_file',
    MultiReplaceString = 'multi_replace_string_in_file',
    ApplyPatch = 'apply_patch',
    ListDirectory = 'list_dir',
    CreateDirectory = 'create_directory',
    ViewImage = 'view_image',
    
    // Search
    Codebase = 'semantic_search',
    FindFiles = 'file_search',
    FindTextInFiles = 'grep_search',
    
    // Terminal
    CoreRunInTerminal = 'run_in_terminal',
    CoreGetTerminalOutput = 'get_terminal_output',
    CoreTerminalSelection = 'terminal_selection',
    CoreTerminalLastCommand = 'terminal_last_command',
    
    // Tasks
    CoreCreateAndRunTask = 'create_and_run_task',
    CoreRunTask = 'run_task',
    CoreGetTaskOutput = 'get_task_output',
    
    // Notebook
    EditNotebook = 'edit_notebook_file',
    RunNotebookCell = 'run_notebook_cell',
    GetNotebookSummary = 'copilot_getNotebookSummary',
    ReadCellOutput = 'read_notebook_cell_output',
    
    // Git & GitHub
    GetScmChanges = 'get_changed_files',
    GithubRepo = 'github_repo',
    
    // VS Code integration
    GetErrors = 'get_errors',
    InstallExtension = 'install_extension',
    RunVscodeCmd = 'run_vscode_command',
    VSCodeAPI = 'get_vscode_api',
    CreateNewWorkspace = 'create_new_workspace',
    CreateNewJupyterNotebook = 'create_new_jupyter_notebook',
    GetProjectSetupInfo = 'get_project_setup_info',
    
    // Web
    FetchWebPage = 'fetch_webpage',
    
    // Agent tools
    Memory = 'memory',
    CoreManageTodoList = 'manage_todo_list',
    CoreAskQuestions = 'vscode_askQuestions',
    CoreRunSubagent = 'runSubagent',
    SearchSubagent = 'search_subagent',
    ExecutionSubagent = 'execution_subagent',
    
    // Meta tools
    ToolSearch = 'tool_search',
    ResolveMemoryFileUri = 'resolve_memory_file_uri',
    SwitchAgent = 'switch_agent',
}
```

---

## Tool Selection Logic

**File:** `src/extension/intents/node/agentIntent.ts` — `getAgentTools()`

### Model-Based Tool Selection

```typescript
// Edit tool selection based on model capabilities
allowTools[ToolName.EditFile] = true;  // Always allowed by default
allowTools[ToolName.ReplaceString] = modelSupportsReplaceString(model);
allowTools[ToolName.ApplyPatch] = modelSupportsApplyPatch(model);
allowTools[ToolName.MultiReplaceString] = modelSupportsMultiReplaceString(model);

// If model excels at apply_patch, disable insert_edit
if (modelCanUseApplyPatchExclusively(model)) {
    allowTools[ToolName.EditFile] = false;
}
// If model excels at replace_string, disable insert_edit
if (modelCanUseReplaceStringExclusively(model)) {
    allowTools[ToolName.ReplaceString] = true;
    allowTools[ToolName.EditFile] = false;
}
```

### Subagent Tools (GPT & Anthropic Only)

```typescript
const isGptOrAnthropic = isGptFamily(model) || isAnthropicFamily(model);
allowTools[ToolName.SearchSubagent] = isGptOrAnthropic && searchSubagentEnabled;
allowTools[ToolName.ExecutionSubagent] = isGptOrAnthropic && executionSubagentEnabled;
```

### Workspace-Dependent Tools

```typescript
allowTools[ToolName.CoreRunTest] = await testService.hasAnyTests();
allowTools[ToolName.CoreRunTask] = tasksService.getTasks().length > 0;
```

### Anthropic Tool Search (Deferred Tools)

When enabled, tools are split into:
- **Non-deferred** — Always sent to the LLM (core tools like `read_file`, `replace_string_in_file`)
- **Deferred** — Only loaded when the model calls `tool_search` first

This reduces the initial prompt token cost on Anthropic models.

```typescript
allowTools[CUSTOM_TOOL_SEARCH_NAME] = isAnthropicCustomToolSearchEnabled(model);
```

---

## Tool Registry

**File:** `src/extension/tools/common/toolsRegistry.ts`

### `ICopilotTool<T>` Interface

```typescript
export interface ICopilotTool<T> {
    // Standard tool interface
    invoke?(input: T, options): Promise<LanguageModelToolResult2>;
    prepareInvocation?(input: T, options): Promise<PreparedToolInvocation>;
    
    // Copilot extensions
    filterEdits?(resource: URI): Promise<IEditFilterData | undefined>;
    provideInput?(promptContext): Promise<T | undefined>;
    resolveInput?(input: T, promptContext, mode): Promise<T>;
    alternativeDefinition?(tool, endpoint?): LanguageModelToolInformation;
}
```

### Tool Registration

Tools are registered with:
- `toolName: ToolName` — The display name
- `nonDeferred?: boolean` — Whether to always include (vs defer for tool search)

---

## Tool Categories

**File:** `src/extension/tools/common/toolNames.ts`

```typescript
export enum ToolCategory {
    JupyterNotebook = 'Jupyter Notebook Tools',
    WebInteraction = 'Web Interaction',
    VSCodeInteraction = 'VS Code Interaction',
    Testing = 'Testing',
    RedundantButSpecific = 'Redundant but Specific',
    Core = 'Core'
}
```

Virtual tools can group multiple tools into a single "category tool" that the model calls. When the model calls the category tool, it gets expanded into the actual tool calls.

---

## Tool Invocation Flow

### 1. Tool Call Parsing

The LLM response contains tool calls in model-specific format:
- **OpenAI/GPT:** `tool_calls` array in the response
- **Anthropic/Claude:** `content_block_start(tool_use)` + `input_json_delta` stream events

### 2. Input Validation

```typescript
const validation = toolsService.validateToolInput(toolCall.name, toolCall.arguments);
if (isToolValidationError(validation)) {
    // Return error as tool result
}
```

### 3. Tool Invocation

```typescript
const result = await toolsService.invokeToolWithEndpoint(
    toolCall.name,
    {
        input: validatedInput,
        toolInvocationToken: request.toolInvocationToken,
        requestedContentTypes: ['text/plain'],
    },
    endpoint,
    token
);
```

### 4. Result Storage

Tool results are stored in `toolCallResults[callId]` and fed back into the next prompt iteration as tool messages.

---

## MCP Tool Integration

MCP (Model Context Protocol) tools from external servers are integrated through:

1. **Discovery** — MCP servers are configured and connected
2. **Registration** — Tools are registered as `vscode.lm.tools`
3. **Naming** — MCP tools are prefixed with `mcp_<server>_` (e.g., `mcp_github_create_issue`)
4. **Instructions** — Special `<mcpToolInstructions>` section is added to the prompt:

```tsx
class McpToolInstructions extends PromptElement {
    render() {
        // Groups MCP tools by server and adds activation instructions
        return <Tag name='mcpToolInstructions'>
            Call this tool when you need access to a new category of tools.
            The category of tools is described as follows: {description}
        </Tag>;
    }
}
```

---

## Key Source Files

| File | Role |
|------|------|
| `src/extension/tools/common/toolNames.ts` | Tool name enums and mapping |
| `src/extension/tools/common/toolsService.ts` | Tool invocation service |
| `src/extension/tools/common/toolsRegistry.ts` | Tool registration interfaces |
| `src/extension/intents/node/agentIntent.ts` | `getAgentTools()` selection logic |
| `src/extension/tools/node/` | Individual tool implementations |
| `src/extension/mcp/` | MCP server integration |

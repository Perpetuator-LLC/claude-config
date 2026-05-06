# Global Preferences

## Identity
- Developer working on Capital Copilot (Angular frontend + Django/Python backend)
- Stack: Angular, TypeScript, Python, Docker, GraphQL, PostgreSQL

## Workflow (ALL projects)

For any task touching more than 2 files:
1. Read all relevant files first — do not guess at structure
2. Present a numbered implementation plan before making changes
3. Wait for approval before executing
4. After changes: run lint/build/test and read the log file output
5. Never assume a command succeeded from truncated output

## Code Principles

- Write compliant code first — don't iterate on linter violations
- Use inject() not constructor injection in Angular (ESLint rule)
- Handle undefined/null at system boundaries only
- No over-engineering: only change what was asked, no unsolicited refactors
- No docstrings/comments on unchanged code

## Safety Rules

- NEVER `git push --force` or `git reset --hard` without explicit confirmation
- NEVER delete files without confirmation
- NEVER `rm -rf` without explicit instruction
- NEVER commit secrets, tokens, or credentials
- Always dry-run destructive operations first

## Communication Style

- Brief responses — no unnecessary preamble
- After completing file changes: confirm briefly, don't re-explain what was done
- When blocked: propose alternative approach, don't retry the same thing twice
- Flag security issues immediately

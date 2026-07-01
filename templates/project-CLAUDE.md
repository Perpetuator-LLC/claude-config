# Project: __PROJECT_NAME__

> **Governance.** This repo inherits my Core governance + C-Suite role domains from `~/.claude/governance/` (auto-loaded via `~/.claude/CLAUDE.md`). This file holds **__PROJECT_NAME__-specific** conventions that extend/override it (more-local wins for this repo). **If this is a client engagement,** name the client's governance overlay here so it layers per the precedence ladder: human in-session > client (their deliverable's shape) > my governance > core.

## Stack
- Runtime: __RUNTIME__
- Framework: __FRAMEWORK__
- Test: `__TEST_CMD__`
- Lint: `__LINT_CMD__`
- Build: `__BUILD_CMD__`

## Architecture
<!-- 2-3 sentences describing the key architectural pattern -->

## Key Conventions
<!-- List naming conventions, file organization rules, import restrictions -->

## Never Do
<!-- List destructive actions, forbidden patterns, files to never touch -->

## Before Committing
1. Run `__TEST_CMD__`
2. Run `__LINT_CMD__`
3. Confirm no TODO comments left in changed files

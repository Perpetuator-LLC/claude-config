# GitHub Token Setup for Claude Code

Claude Code uses the `gh` CLI (under the hood, via `Bash` tool calls) to read pull requests, view code-review comments, comment back, push branches, and check CI status. For any of that to work on a **private repo**, the `gh` CLI needs a token with the right permissions.

This guide walks through creating a **fine-grained personal access token (PAT)** scoped to a single org so Claude can do PR review work, using `Perpetuator-LLC` as the example. Substitute your own org name wherever it appears.

> [!NOTE]
> If you don't care about per-repo scoping, a classic PAT with `repo` scope also works and is faster to set up — see [Alternative: Classic PAT](#alternative-classic-pat) at the bottom. The fine-grained version below is the recommended path because it limits blast radius.

---

## Prerequisites

### 1. Org must allow fine-grained PATs

If the target org hasn't enabled fine-grained PATs, your token will be created but `gh api repos/<org>/<repo>` will return `404 Not Found` exactly as if the repo doesn't exist. Symptom looks like a token problem; root cause is org policy.

As an org owner:

1. Go to `https://github.com/organizations/<ORG>/settings/personal-access-tokens-policy` (e.g. `Perpetuator-LLC`).
2. Under **Fine-grained personal access tokens**, set "Allow access via fine-grained personal access tokens" to **Allow**.
3. Decide whether new tokens require admin approval or are auto-approved. For agent automation, auto-approve is convenient but riskier; for one-off setup, requiring approval is fine.

If you're not an org owner, ask one to enable this.

### 2. Approval flow (if enabled)

After you create the token, the org owner sees a "Pending request" under the same Personal Access Tokens settings page. Click Approve before the token will work.

---

## Create the token

1. Go to **https://github.com/settings/personal-access-tokens/new** (or *user profile → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token*).

2. **Token name**: something descriptive like `claude-code-perpetuator` so you can revoke it later without guessing.

3. **Resource owner**: pick the **org** (e.g. `Perpetuator-LLC`), not your personal user. This is what scopes the token to the org's repos.

4. **Expiration**: pick a value you're comfortable with (max 366 days). Calendar a renewal — expired tokens fail silently with the same 404.

5. **Repository access**:
   - "All repositories" if Claude should be able to touch every repo in the org.
   - "Only selected repositories" + pick e.g. `cc-fe` if you want to scope tightly.

6. **Permissions** — set the table below.

### Repository permissions

Read-only set (covers "let Claude see everything in the codebase"):

| Permission | Access | Why |
|---|---|---|
| **Metadata** | Read | Always required. Auto-checked once you grant any other repo perm. |
| **Contents** | Read | Clone the repo, view files, list branches. Required by `gh pr checkout`, `gh pr diff`, `git fetch`. |
| **Commit statuses** | Read | See CI pass/fail on commits. |
| **Actions** | Read | Read workflow runs, list jobs, get logs (`gh run view`). |
| **Pages** | Read | Read GitHub Pages config if the repo uses it. |
| **Deployments** | Read | View deployment history. |
| **Environments** | Read | View environment configurations. |
| **Variables** | Read | Read repository-level variables (not secret values). |
| **Webhooks** | Read | View webhook config. |
| **Dependabot alerts** | Read | List vulnerability alerts. |
| **Code scanning alerts** | Read | List CodeQL/SAST findings. |
| **Secret scanning alerts** | Read | List leaked-secret alerts. |
| **Discussions** | Read | View GitHub Discussions if the repo has them. |

Write set (needed for **code reviews + PR work**):

| Permission | Access | Why |
|---|---|---|
| **Pull requests** | Read & write | Read PR bodies and review comments, post comments, request changes, approve, push commits to PR branches. **This is the key permission for code-review work.** |
| **Issues** | Read & write | Create / close / comment on issues; needed because GitHub treats PR comments as issue comments under the hood (`gh api repos/.../issues/<n>/comments`). |
| **Contents** | Read & write *(upgrade from read above)* | Push commits to branches Claude creates. Skip if you'll handle all pushes yourself. |
| **Workflows** | Read & write | Only if Claude needs to edit files under `.github/workflows/`. Skip otherwise — GitHub refuses to push workflow-file changes if this is missing, even with `Contents: write`. |

> [!TIP]
> If you're not sure whether Claude will need to push code or edit workflows, start with read-only `Contents` and `Workflows: read`, and add write later. You can edit a token's permissions after creation without revoking it.

### Organization permissions

These are *optional* but let `gh org`, project lookups, and member queries work:

| Permission | Access | Why |
|---|---|---|
| Members | Read | List org members (`gh api orgs/<org>/members`). |
| Administration | Read | Read org-level settings. |
| Custom repository roles | Read | View role definitions. |
| Plan | Read | View org's GitHub plan. |
| Projects | Read | View GitHub Projects (the next-gen board). |
| Self-hosted runners | Read | View self-hosted runner config. |

### Account permissions

You can leave all account permissions at "No access" — Claude doesn't need to touch your personal account settings.

---

## Install the token

Once GitHub shows you the `github_pat_...` value, install it somewhere `gh` (and therefore Claude Code) can find it.

### Option A: Persistent env var — keychain-backed ONLY

Never put the token literal in a dotfile (at-rest plaintext + history risk —
see global CLAUDE.md, Secrets in Code). Store it in the macOS Keychain once
(hidden prompt, zsh form), then have `~/.zshrc` read it at shell start:

```bash
# One-time (zsh): hidden prompt → Keychain; the literal never touches a file
read -s 'GHT?GitHub PAT (from github.com/settings/tokens, for gh CLI): '; echo
security add-generic-password -a "$USER" -s "gh-token-perpetuator" -w "$GHT"
unset GHT
```

```bash
# In .zshrc:
export GH_TOKEN="$(security find-generic-password -a "$USER" -s "gh-token-perpetuator" -w 2>/dev/null)"
```

> [!WARNING]
> This puts a long-lived secret in a plaintext dotfile. If your dotfiles are in a git repo, **make sure they're either private or you're using a secrets manager**. Better: store the token in macOS Keychain / 1Password / pass and have your shell init read it on startup.

**Better persistent setup using `pass` or `op` (1Password CLI):**

```bash
# .zshrc
export GH_TOKEN="$(op read 'op://Personal/GitHub PAT Perpetuator/credential' 2>/dev/null)"
```

Or with macOS Keychain:

```bash
# One-time setup (hidden prompt — never the literal on argv):
read -s 'GHT?GitHub PAT: '; echo
security add-generic-password -a "$USER" -s "gh-token-perpetuator" -w "$GHT"; unset GHT

# In .zshrc:
export GH_TOKEN="$(security find-generic-password -a "$USER" -s "gh-token-perpetuator" -w 2>/dev/null)"
```

### Option B: `gh auth login` (multi-account, no env var)

If you have **two or more orgs**, each with their own token, this is the cleanest path:

```bash
# Make sure GH_TOKEN is NOT set — it overrides stored auth.
unset GH_TOKEN

# Log in to org A (Perpetuator-LLC token)
gh auth login --hostname github.com --git-protocol ssh
# When prompted: "Authenticate Git with your GitHub credentials? Yes"
# When prompted for auth method: "Paste an authentication token"
# Paste the token.

# Log in to org B with a different token (creates a second stored account)
gh auth login --hostname github.com --git-protocol ssh
# Paste the second token.

# See both accounts
gh auth status

# Switch between them
gh auth switch                  # interactive picker
gh auth switch -u <username>    # direct
```

`gh` stores both tokens in `~/.config/gh/hosts.yml` under separate `users:` entries. `gh auth switch` flips which one is active. The active token is what every `gh` command — and every Claude Code Bash call — will use until you switch again.

> [!IMPORTANT]
> **If `GH_TOKEN` is exported anywhere in your shell init, `gh auth switch` will appear to work but silently keep using the env-var token.** Audit `.zshrc`, `.bashrc`, `.envrc`, `.profile`, and any `direnv` files before relying on Option B. The fastest check is `gh auth status` — if it says "Token: gho_..." with no account name, env-var override is active.

### Option C: Per-command (good for shell aliases and CI)

```bash
GH_TOKEN="$TOKEN_PERPETUATOR" gh pr view 17 -R Perpetuator-LLC/cc-fe
GH_TOKEN="$TOKEN_OTHERORG"   gh pr list -R OtherOrg/repo
```

Or aliases — keychain-backed, never a token literal in the alias (a literal in
`.zshrc` is at-rest plaintext, the exact thing the one-time Keychain setup above
avoids; store each org's token under its own service name first):

```bash
alias gh-perpetuator='GH_TOKEN="$(security find-generic-password -a "$USER" -s gh-token-perpetuator -w)" gh'
alias gh-otherorg='GH_TOKEN="$(security find-generic-password -a "$USER" -s gh-token-otherorg -w)" gh'
```

Claude Code doesn't pick up shell aliases (they don't exist inside its Bash tool's non-interactive subshell), so this option is for **your** terminal, not for Claude. If you want Claude to use a specific token per call, you have to inline the env var in the command itself.

---

## Verify

After installing the token by whichever route, verify it works **in a fresh shell** (this matters — Claude Code's Bash tool always spawns a fresh subshell, so anything that only lives in your current interactive terminal won't be visible to it):

```bash
# Open a new terminal, then:
gh auth status
gh api user | jq .login
gh api 'repos/Perpetuator-LLC/cc-fe' | jq .full_name
gh pr view 17 -R Perpetuator-LLC/cc-fe --json title,state
```

Expected: each command returns data, no 404. If you get `404 Not Found` on the org repo while `gh api user` works, you're hitting one of:

- Token wasn't granted access to that org's repos (recreate with correct Resource Owner).
- Org hasn't enabled fine-grained PATs.
- Token is pending org-owner approval.
- Token expired.

The error message is identical for all of these — GitHub deliberately doesn't disclose *why* you can't see a repo. Walk through the list above in order.

---

## Use from Claude Code

Once the token is exported in your shell when you launch Claude Code, every Bash tool call inherits it. You can confirm by asking Claude to run:

```bash
gh auth status
```

If Claude reports the right account, you're set. Claude can then:

- Read review comments: `gh api repos/<org>/<repo>/pulls/<n>/comments`
- View PR diff: `gh pr diff <n> -R <org>/<repo>`
- Post a review comment: `gh pr review <n> -R <org>/<repo> --comment -b "..."`
- Check CI: `gh pr checks <n> -R <org>/<repo>`
- Approve or request changes: `gh pr review <n> --approve` / `--request-changes`

---

## Renew or revoke

- **Renew**: tokens approaching expiry can be regenerated under the same Personal Access Tokens page. The token *value* changes; you'll need to update wherever it's installed (env var, Keychain, 1Password, etc.).
- **Revoke**: delete the token immediately if it leaks. Compromised tokens won't auto-revoke when the next one rotates — old and new are independent until you explicitly delete the old one.

---

## Alternative: Classic PAT

If you don't need per-repo scoping and want a 30-second setup:

1. Go to **https://github.com/settings/tokens** → "Generate new token (classic)".
2. Check the **`repo`** scope (covers all read/write on every repo you have access to). Add **`workflow`** if Claude will edit workflow files.
3. Install it the same way as above — the one-time Keychain capture (hidden
   `read -s` prompt → `security add-generic-password`), or pipe it straight into
   `gh auth login --with-token` at a hidden prompt. Never `export GH_TOKEN=<literal>`
   in a dotfile or terminal (history + at-rest risk).

Trade-off: classic tokens are visible across every repo your GitHub user can access — including personal repos and other orgs. Fine-grained tokens are scoped to one org's selected repos, which is meaningfully safer if the token leaks.

---

## Troubleshooting cheat sheet

| Symptom | Likely cause | Fix |
|---|---|---|
| `gh auth status` shows "Token: gho_..." with no account name | `GH_TOKEN` env var is overriding stored auth | Unset `GH_TOKEN` in your shell init, restart shell |
| `404 Not Found` on org repo, but `gh api user` works | Token doesn't include the org, or org hasn't enabled fine-grained PATs, or token pending approval | Check org settings + recreate token if scoping is wrong |
| `gh` works in your terminal but not when Claude calls it | `GH_TOKEN` was set in your *current* shell but isn't in shell init, so Claude's subshell doesn't see it | Add the `export` to `~/.zshrc` / `~/.bashrc` |
| `gh pr review --approve` returns "You can't approve your own pull request" | Token's account is the PR author | Use a different account's token, or just leave a `--comment` instead of `--approve` |
| `gh api` works but `gh pr view` fails on a public repo | `gh` is using SSH for git operations but HTTPS for API; check that token is loaded for HTTPS too | `gh auth setup-git` to refresh credentials |
| Token suddenly stops working ~7 days after creation | Token wasn't approved by org owner — GitHub auto-rejects unapproved fine-grained PATs after a grace period | Org owner approves under *Org Settings → Personal access tokens → Pending requests* |

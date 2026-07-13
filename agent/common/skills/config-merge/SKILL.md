---
name: config-merge
description: >-
  Reconcile the live Codex config at ~/.codex/config.toml with the portable
  dotfiles config at ~/.dotfiles/agent/codex/config.toml. Use when Codex
  settings changed locally, dotfiles brought settings from another machine,
  or the user asks to merge, synchronize, promote, or distribute Codex config
  without losing machine-local state.
---

# config-merge

Synchronize Codex configuration by meaning, not by blindly combining TOML.
Keep portable intent in dotfiles and runtime or machine-specific state only in
the live config.

## Files

- Shared: `$HOME/.dotfiles/agent/codex/config.toml`
- Live: `$HOME/.codex/config.toml`

Treat a live symlink resolving to the shared file as a migration blocker. Do
not attempt a self-merge; report that `bin/install` must migrate the legacy
symlink first.

## 1. Inspect both sides

1. Confirm both files exist and are distinct regular files.
2. Parse both as TOML before editing. Stop without changes if either is invalid.
3. Inspect the dotfiles working tree, the complete config diff, and recent
   config history:

   ```text
   git -C "$HOME/.dotfiles" status --short
   git -C "$HOME/.dotfiles" diff -- agent/codex/config.toml
   git -C "$HOME/.dotfiles" log -p -5 -- agent/codex/config.toml
   ```

4. Preserve unrelated dotfiles changes and any pre-staged work.
5. Save a temporary backup of the live config before editing it.

## 2. Classify settings

Keep these local unless the user explicitly requests portability:

- `projects.*`
- `tui.model_availability_nux.*`
- `hooks.state.*`
- authentication, credentials, tokens, session state, and history
- machine paths, device-specific commands, or host-specific endpoints

Treat these as portable candidates when they contain no secrets or host-only
values:

- behavioral defaults such as model, personality, approvals, and sandbox
- `features.*`
- `agents.*`
- reusable `mcp_servers.*` definitions
- durable TUI and notification preferences
- reusable hooks and sandbox settings

Classify mixed tables field by field. Never promote static authorization
headers, bearer tokens, credentials, private keys, or secret environment
values. Environment variable names are not secrets by themselves.

## 3. Reconcile

Build a ledger before editing:

- **promote**: portable setting present only in live config -> add to shared
- **import**: portable setting present only in shared config -> add to live
- **local**: machine/runtime setting -> retain only in live
- **aligned**: equivalent on both sides -> leave unchanged
- **conflict**: different portable values on both sides -> resolve from user
  intent, config history, and surrounding changes

For conflicts, prefer the value with clear evidence of a newer intentional
change. If evidence is insufficient and behavior would materially change, keep
both files unchanged for that key and report the conflict. Do not ask about
independent entries that can be reconciled safely.

Apply precise edits while preserving comments, ordering, and formatting. Do
not serialize and replace an entire file merely to change a few values. Remove
local-only state found in shared config after preserving it in live config.

After reconciliation, every portable setting should agree across both files.
Local-only settings should remain in the live file and be absent from shared.

## 4. Verify

1. Parse both files as TOML again.
2. Run `codex --strict-config --version` against the live configuration.
3. Run `git -C "$HOME/.dotfiles" diff --check` and inspect the complete shared
   config diff.
4. Check that no secrets or local-only tables entered the shared diff.
5. Confirm the live file is not a symlink and still contains retained local
   state.

Do not commit, pull, push, reset, restore, or discard changes. Those operations
require separate explicit user intent.

## Output

Report:

```text
promoted: <portable settings moved to dotfiles>
imported: <portable settings moved to live config>
local: <settings retained only on this machine>
conflicts: <unresolved keys or none>
verification: <checks performed>
```

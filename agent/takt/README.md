# TAKT (https://github.com/nrslib/takt)

TAKT is the **enforcement layer** outside Cursor / Claude Code.
Skills and agents under `agent/` remain the knowledge; TAKT owns phase
transitions so agents cannot silently skip review and declare "done".

## Setup (this machine)

Already done during adoption:

```bash
npm install -g takt          # CLI on PATH via fnm/npm
# ~/.takt/config.yaml        # provider: cursor, language: ja
# ~/.takt/workflows/*-mini.yaml  # ejected builtins for customization
```

```yaml
# ~/.takt/config.yaml (summary)
language: ja
provider: cursor
model: grok-4.5-fast-xhigh
cursor_cli_path: /home/miyabi/.local/bin/cursor-agent
```

Override per run: `takt --provider claude ...` when you want Claude Code as worker.

## Quick try

From any git repo with at least one commit:

```bash
takt                         # interactive: clarify → /go → queue
takt run                     # execute queued tasks in worktrees

# or one-shot (writes into current tree — careful)
takt --pipeline -w backend-mini -t "短いタスク説明"
```

Validate YAML:

```bash
takt workflow doctor backend-mini
```

## Mapping: our agent assets → TAKT

| Our asset (`agent/`) | TAKT concept |
|---|---|
| `common/skills/dev-cycle` | Top workflow (or `dual` / custom YAML) |
| `common/skills/backend-team` | `backend` / `backend-mini` workflow |
| `common/skills/frontend-team` | `frontend` / `frontend-mini` workflow |
| `common/agents/strategist` | persona + instruction (test-first / contract) |
| `common/agents/strategy-rev` | review step / testing-reviewer facet |
| `common/agents/dev` | `coder` persona |
| `common/agents/rev` | review personas |
| `common/agents/ui-checker` | QA step + e2e knowledge |
| `common/agents/committer` | post-success git / PR step (TAKT + `gh`) |
| `common/designs/*` | design-system templates for frontend workflows |

Builtin workflows already include plan → implement → parallel review → fix loops.
Customize by editing `~/.takt/workflows/*.yaml` or project `.takt/workflows/`.

Export TAKT → Claude skills (optional): `takt export-cc`

## What TAKT does / does not

- **Does**: force step order, fix loops, worktree isolation, logs/reports, Cursor as provider
- **Does not**: replace Cursor's missing "waiting" notification hook; that stays a product gap

## Dotfiles note

`~/.takt/` is **user-global config** (not symlinked from this repo yet).
Project-local `.takt/` (tasks, runs) is gitignored when it appears in a repo.

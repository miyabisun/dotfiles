# Agent Configuration Layer

All AI agent tooling lives under `agent/`.

```
agent/
├── common/          # Shared across tools
│   ├── agents/      # Subagent role defs (dev, rev, strategist, …)
│   ├── bin/         # emit-turn-end.sh → ~/.local/bin
│   ├── designs/     # DESIGN.md templates (Sumi, Kinari, …)
│   ├── rules/       # GLOBAL.md
│   └── skills/      # Agent Skills (SKILL.md)
├── claude/          # Claude Code only
│   ├── hooks/
│   ├── workflows/
│   ├── settings.json
│   ├── CLAUDE.md → ../common/rules/GLOBAL.md
│   ├── agents → ../common/agents
│   ├── designs → ../common/designs
│   └── skills → ../common/skills
├── cursor/          # Cursor only
│   ├── rules/       # .mdc alwaysApply rules
│   ├── hooks/ + hooks.json
│   └── agents → ../common/agents
└── takt/            # TAKT adoption notes (enforcement outside the IDE)
```

`bin/install` symlinks:

| Home | Source |
|------|--------|
| `~/.claude/skills`, `~/.cursor/skills` | `agent/common/skills` |
| `~/.claude/agents`, `~/.cursor/agents` | `agent/common/agents` |
| `~/.claude/designs`, `~/.cursor/designs` | `agent/common/designs` |
| `~/.claude/*` (hooks, workflows, …) | `agent/claude/*` |
| `~/.cursor/*` (rules, hooks, …) | `agent/cursor/*` |

## Agents (`common/agents`)

Role definitions shared by Claude Code and Cursor. Frontmatter keeps only
`name` / `description` so Cursor inherits the parent chat model (`model`
defaults to `inherit`). Claude-specific `model` / `effort` / `tools` are
intentionally omitted — assign those in Claude workflows/settings if needed.

Google-style `DESIGN.md` templates live once here. Projects only keep a thin
`docs/DESIGN.md` that declares which template they follow plus project-specific
tokens. Do not copy the full template into every app.

## Adding a new skill

1. Create `agent/common/skills/<name>/SKILL.md`
2. Existing symlinks pick it up for both tools

Notable skills:

- `bump-tag` — semver bump, tag, push
- `backend-team` — strategist → strategy-rev → dev → rev → fix → simplify → sec
- `frontend-team` — same plus QA (`ui-checker` evidence) and UI re-verify
- `dev-cycle` — leader → designer? → backend-team and/or frontend-team → committer

Agent split (producer ≠ approver):

- `strategist` / `strategy-rev` — contracts & tests; strategy-rev holds the gate
- `dev` / `rev` — implement; rev holds the gate (no self-approval)
- `ui-checker` — measure with evidence only (does not write strategy/tests)

## Adding a new agent tool

1. Create `agent/<tool>/` with tool-specific config
2. Symlink `agent/common/skills` (and adapt rules format if needed)
3. Add install steps to `bin/install`

## TAKT (external enforcement)

Skills cannot force phase order. For that, use [TAKT](https://github.com/nrslib/takt)
as an outer orchestrator (Cursor/Claude as workers). See [takt/README.md](takt/README.md).

# Agent Configuration Layer

All AI agent tooling lives under `agent/`.

```
agent/
├── common/          # Shared across tools
│   ├── agents/      # Subagent role defs (dev, rev, strategist, …)
│   ├── bin/         # Shared notification helpers → ~/.local/bin
│   ├── designs/     # DESIGN.md templates (Sumi, Kinari, …)
│   ├── rules/       # GLOBAL.md
│   └── skills/      # Agent Skills (SKILL.md)
├── claude/          # Claude Code only
│   ├── hooks/
│   ├── settings.json
│   ├── CLAUDE.md → ../common/rules/GLOBAL.md
│   ├── agents → ../common/agents
│   ├── designs → ../common/designs
│   └── skills → ../common/skills
├── cursor/          # Cursor only
│   ├── rules/       # .mdc alwaysApply rules
│   ├── hooks/ + hooks.json
│   └── agents → ../common/agents
└── codex/           # Codex CLI only
    ├── agents/      # Codex subagent TOML role adapters
    ├── hooks/ + hooks.json
    └── config.toml
```

`bin/install` symlinks:

| Home | Source |
|------|--------|
| `~/.claude/skills`, `~/.cursor/skills` | `agent/common/skills` |
| `~/.claude/agents`, `~/.cursor/agents` | `agent/common/agents` |
| `~/.claude/designs`, `~/.cursor/designs` | `agent/common/designs` |
| `~/.claude/*` (hooks, settings, …) | `agent/claude/*` |
| `~/.cursor/*` (rules, hooks, …) | `agent/cursor/*` |
| `~/.codex/config.toml`, `~/.codex/hooks.json` | `agent/codex/*` |
| `~/.codex/AGENTS.md` | `agent/common/rules/GLOBAL.md` |
| `~/.agents/skills`, `~/.agents/agents`, `~/.agents/designs` | `agent/common/*` |

Agent completion events call `~/.local/bin/emit-turn-end.sh`. In tmux this
raises a silent `@agent_bell` session/window marker;
when `MOCA_URL` is set, it also asks MOCA to announce the event. The full
session/agent name is used in the background; the currently viewed session gets
a short announcement such as `完了しました`. Codex uses `notify` for completion.
Its notification wrapper identifies subagent rollout threads and suppresses
their completion announcements, including automatic approval reviewers.

Agent-to-agent messages use the Rust `agent-talk` CLI from
[`miyabi-sunny-side/agent-talkd`](https://github.com/miyabi-sunny-side/agent-talkd).
`bin/install-apps` installs the latest release binary, while the TPM entry in
`config/tmux/tmux.conf` starts its per-tmux-server daemon. Claude hooks and the
Codex/Cursor shell wrappers register each interactive pane automatically.
Cursor's prompt and stop hooks mirror the same busy/turn-end lifecycle, while
`@agent_talkd_skill_syntax=cursor=slash` enables skill-prefixed delivery.
Cursor CLI also imports Claude-compatible lifecycle hooks, so Claude's
lifecycle adapters ignore payloads containing `cursor_version` and leave
registration and turn state to the Cursor wrapper/hooks.

Peer `who`, `read`, safe send, and `reply` calls are standing-authority
conversation operations. They use the `~/.local/bin/agent-talk-peer` dispatcher, whose send
path rejects `--skill` and `--from` before calling the broker; direct
`agent-talk send` is not promptless. Claude allows the dispatcher explicitly,
while Codex loads the
narrow rules in `agent/codex/rules/agent-talk.rules`; other broker maintenance
commands remain outside that allow list. The installer copies this
installer-owned policy and dispatcher into machine-local runtime state rather
than linking either back to the writable repository. The dispatcher calls only
the adjacent regular `agent-talk` executable, never a PATH-resolved substitute.
Peer messages never carry user authority for workspace changes.
When a change needs direct approval,
`~/.local/bin/notify-file-permission.sh` rings the pane, emits one sanitized MOCA notice when
configured, and leaves the agent waiting without blocking the normal
turn-end/idle lifecycle.

## Agents (`common/agents`)

Role definitions shared by Claude Code and Cursor. Frontmatter keeps only
`name` / `description` so Cursor inherits the parent chat model (`model`
defaults to `inherit`). Claude-specific `model` / `effort` / `tools` are
intentionally omitted.

Google-style `DESIGN.md` templates live once here. Projects only keep a thin
`docs/DESIGN.md` that declares which template they follow plus project-specific
tokens. Do not copy the full template into every app.

## Adding a new skill

1. Create `agent/common/skills/<name>/SKILL.md`
2. Existing symlinks pick it up for Claude Code, Cursor, and Codex

Notable skills:

- `deliver` — outcome-driven implementation, evidence gates, local commit
- `consolidate` — semantic DRY inventory, safe unification, verified commit
- `commit` — atomic staging and concise Conventional Commit messages
- `bump-tag` — semver bump, tag, push

`deliver` selects only the capabilities justified by risk. Agent split
(producer ≠ approver):

- `strategist` / `strategy-rev` — contracts & tests; strategy-rev holds the gate
- `dev` / `rev` — implement and semantic review (no self-approval)
- `formatter` — applicability, format correction, and lint evidence for eligible source before commit
- `ui-checker` — measure with evidence only (does not write strategy/tests)
- `knowledge-inventory` — inventory durable delivery knowledge after commit and route one sanitized batch to the librarian

## Adding a new agent tool

1. Create `agent/<tool>/` with tool-specific config
2. Symlink `agent/common/skills` (and adapt rules format if needed)
3. Add install steps to `bin/install`

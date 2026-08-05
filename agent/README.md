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
├── codex/           # Codex CLI only
│   ├── agents/      # Codex subagent TOML role adapters
│   ├── hooks/ + hooks.json
│   └── config.toml
└── grok/            # Grok CLI only
    ├── hooks/       # lifecycle + guards (JSON + shell adapters)
    └── config.toml  # portable template → seed ~/.grok/config.toml
```

`bin/install` symlinks:

| Home | Source |
|------|--------|
| `~/.claude/skills`, `~/.cursor/skills`, `~/.grok/skills` | `agent/common/skills` |
| `~/.claude/agents`, `~/.cursor/agents`, `~/.grok/agents` | `agent/common/agents` |
| `~/.claude/designs`, `~/.cursor/designs`, `~/.grok/designs` | `agent/common/designs` |
| `~/.claude/*` (hooks, settings, …) | `agent/claude/*` |
| `~/.cursor/*` (rules, hooks, …) | `agent/cursor/*` |
| `~/.codex/config.toml`, `~/.codex/hooks.json` | `agent/codex/*` |
| `~/.codex/AGENTS.md`, `~/.grok/AGENTS.md` | `agent/common/rules/GLOBAL.md` |
| `~/.grok/hooks` | `agent/grok/hooks` |
| `~/.grok/config.toml` | seeded copy of `agent/grok/config.toml` (not a symlink) |
| `~/.agents/skills`, `~/.agents/agents`, `~/.agents/designs` | `agent/common/*` |

Agent completion events call `~/.local/bin/emit-turn-end.sh`. In tmux this
raises a silent `@agent_bell` session/window marker;
when `MOCA_URL` is set, it also asks MOCA to announce the event. The full
session/agent name is used in the background; the currently viewed session gets
a short announcement such as `完了しました`. Codex uses `notify` for completion.
Its notification wrapper identifies subagent rollout threads and suppresses
their completion announcements, including automatic approval reviewers.

Agent-to-agent messages go through the Rust broker from
[`miyabi-sunny-side/agent-talkd`](https://github.com/miyabi-sunny-side/agent-talkd).
One systemd-managed daemon serves both multiplexers (see *Where the broker
itself comes from* below); the TPM entry in `config/tmux/tmux.conf` supplies the
tmux-side integration. Claude hooks and the
Codex/Cursor shell wrappers register each interactive pane automatically.
Cursor's prompt and stop hooks mirror the same busy/turn-end lifecycle, while
`@agent_talkd_skill_syntax=cursor=slash` enables skill-prefixed delivery.
Cursor CLI also imports Claude-compatible lifecycle hooks, so Claude's
lifecycle adapters ignore payloads containing `cursor_version` and leave
registration and turn state to the Cursor wrapper/hooks.

Peer conversation is a standing-authority operation carried entirely by the
`agent-talk` MCP server (`list_peers`, `send_message`, `read_message`,
`ack_message`). The server runs in-process from each runtime's own MCP config,
so no shell command and no allow rule is involved, and Codex's sandbox never
sees the multiplexer socket. The `agent-talk-peer` dispatcher that used to
carry this traffic is retired: it exposed no `ack` subcommand, so a shell-only
agent could read a message but never report receipt. The broker binary's
`register` / `unregister` / `busy` / `run` subcommands stay with the session
hooks and zsh wrappers; other broker maintenance commands remain outside every
allow list. Peer messages never carry user authority for workspace changes.
When a change needs direct approval,
`~/.local/bin/notify-file-permission.sh` rings the pane, emits one sanitized MOCA notice when
configured, and leaves the agent waiting without blocking the normal
turn-end/idle lifecycle.

### Where the broker itself comes from

`bin/install-apps` no longer installs the broker, and nothing here writes
`~/.local/bin/agent-talk`. The broker is a resident service, so it follows the
home-server layout: immutable `~/.local/share/agent-talk/releases/vX.Y.Z/` with
an atomically switched `current` symlink. `~/.local/bin/<service>` is the
retired layout that `moca-server` and `shoebox` already migrated away from; the
only thing that ever put a copy there was this repository's deleted
`install_agent_talk`.

Every caller in this repository — the Claude, Cursor, and Grok lifecycle hooks,
the Codex busy hook, `emit-turn-end.sh`, and the zsh wrappers — therefore invokes
`~/.local/share/agent-talk/current/agent-talk` by absolute path. The broker is
not on `PATH`. `emit-turn-end.sh` keeps its non-symlink trust check: `current`
is a symlink but the binary leaf under it is a regular file, so the check still
holds without being relaxed.

The `agent-talk.service` user unit runs that binary as a daemon and
`agent-talk-update.timer` fetches new releases; both units, plus
`agent-talk-update.sh` and `agent-talk-takeover.sh`, are installed from the
home-server repository (`make -C systemd install-agent-talk`), not from here.
Do not run `agent-talk update` on such a host: self-update rewrites the release
directory in place, which desynchronizes the timer's recorded version.

Since v0.8.0 the release tarball carries `agent-talk-mcp` alongside the
`agent-talk` binary and its LICENSE, and the updater refuses to switch `current`
for an archive that lacks the adapter. Claude, Codex, and Grok therefore point their MCP
config at `~/.local/share/agent-talk/current/agent-talk-mcp`, so the daemon and
the adapter always come from one release and advance together. Do not reinstate
a hand-built copy under `~/.local/bin`: the timer would keep upgrading the
daemon while that copy stood still, which is the version skew this layout
removes.

Grok owns lifecycle under `agent/grok/hooks` and turns off Claude/Cursor
compat for skills, rules, agents, mcps, and hooks so it does not register as
`claude` or double-fire busy/turn-end. Claude Code plugins under
`~/.claude/plugins` may still appear in `grok inspect` (Grok has no separate
compat cell for plugins); their skills are disabled when `compat.claude.skills`
is off, and Grok's own hooks remain the lifecycle source of truth.

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
2. Existing symlinks pick it up for Claude Code, Cursor, Codex, and Grok

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

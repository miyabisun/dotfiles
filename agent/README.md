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
│   ├── CLAUDE.md    # Claude-only rules + @~/.claude/GLOBAL.md import
│   ├── agents → ../common/agents
│   ├── designs → ../common/designs
│   └── skills → ../common/skills
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
| `~/.claude/skills`, `~/.grok/skills` | `agent/common/skills` |
| `~/.claude/agents`, `~/.grok/agents` | `agent/common/agents` |
| `~/.claude/designs`, `~/.grok/designs` | `agent/common/designs` |
| `~/.claude/*` (hooks, settings, …) | `agent/claude/*` |
| `~/.codex/config.toml`, `~/.codex/hooks.json` | `agent/codex/*` |
| `~/.codex/AGENTS.md`, `~/.grok/AGENTS.md`, `~/.claude/GLOBAL.md` | `agent/common/rules/GLOBAL.md` |
| `~/.grok/hooks` | `agent/grok/hooks` |
| `~/.grok/config.toml` | seeded copy of `agent/grok/config.toml` (not a symlink) |
| `~/.agents/skills`, `~/.agents/agents`, `~/.agents/designs` | `agent/common/*` |

Agent completion events call `~/.local/bin/emit-turn-end.sh`. When
`MOCA_URL` is set it asks MOCA to announce the event; a successful turn is
announced only when every other agent in the same herdr workspace has
settled to done/idle (so a claude↔codex review round produces one
completion notice at the end instead of one per turn). This script does not
report lifecycle state to agent-talk; the broker reads it directly from herdr.
Codex uses `notify` for completion. Its notification wrapper identifies
subagent rollout threads and suppresses their completion announcements,
including automatic approval reviewers.

Agent-to-agent messages go through Claude Code's built-in cross-session
channel (`ListAgents` / `SendMessage`). The Rust broker from
[`miyabi-sunny-side/agent-talkd`](https://github.com/miyabi-sunny-side/agent-talkd),
a systemd-managed daemon (see *Where the broker itself comes from* below), keeps
only two jobs: draining a legacy `[agent-talk]` doorbell, and carrying one
bounded `agent-talk reply` to a human's letter that arrived from an external
mailbox. Registration is the daemon's pull sync over herdr's native agent
detection — an interactive agent in a herdr pane is addressable without any
wrapper. The daemon refreshes the successful herdr snapshot on message RPCs and
every two seconds while work is queued, so lifecycle hooks do not push register,
unregister, busy, idle, or turn-end state.

Peer conversation is a standing-authority operation, but the broker's MCP
tools no longer carry it: of `list_peers`, `send_message`, `read_message`,
and `ack_message`, only `read_message` is still used, and only for that
drain. The server runs in-process from each runtime's own MCP config, so no
shell command and no allow rule is involved, and Codex's sandbox never
sees the multiplexer socket. The `agent-talk-peer` dispatcher that used to
carry this traffic is retired: it exposed no `ack` subcommand, so a shell-only
agent could read a message but never report receipt. The removed `busy`, `idle`,
and `turn-end` commands are not restored through hooks or wrappers. Remaining
`register`, `unregister`, and `run` commands are likewise not hook or agent
interfaces; broker maintenance commands remain outside every allow list.
Authority travels with the speaker, not the wire: an instruction from the user
keeps its full weight whether it arrives from a phone or through a relay, and a
peer handing that instruction on delivers it undiminished. What a peer says on
its own account is input, not permission to change the workspace.
When a change needs direct approval,
`~/.local/bin/notify-file-permission.sh` rings the pane, emits one sanitized MOCA notice when
configured, and leaves the agent waiting without affecting agent-talk's herdr
state sync.

### Where the broker itself comes from

`bin/install-apps` no longer installs the broker, and nothing here writes
`~/.local/bin/agent-talk`. The broker is a resident service, so it follows the
home-server layout: immutable `~/.local/share/agent-talk/releases/vX.Y.Z/` with
an atomically switched `current` symlink. `~/.local/bin/<service>` is the
retired layout that `moca-server` and `shoebox` already migrated away from; the
only thing that ever put a copy there was this repository's deleted
`install_agent_talk`.

Runtime MCP configs invoke
`~/.local/share/agent-talk/current/agent-talk-mcp` from the same release as the
daemon. Hooks and notification scripts do not invoke the broker binary.

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

Grok owns its general completion notification under `agent/grok/hooks` and
turns off Claude/Cursor compat for skills, rules, agents, mcps, and hooks so
a leftover `~/.cursor` does not fire compatibility hooks twice. Claude Code plugins under
`~/.claude/plugins` may still appear in `grok inspect` (Grok has no separate
compat cell for plugins); their skills are disabled when `compat.claude.skills`
is off, and Grok's own hooks remain the general notification source.

## Agents (`common/agents`)

Role definitions shared by Claude Code and Grok. Frontmatter keeps only
`name` / `description` so the parent chat model is inherited (`model`
defaults to `inherit`). Claude-specific `model` / `effort` / `tools` are
intentionally omitted.

Google-style `DESIGN.md` templates live here as bootstrap inputs. Each project
owns a self-contained root `DESIGN.md` after adopting and adapting a template;
shared templates do not remain an external authority. Existing projects that
only have `docs/DESIGN.md` may read it as a legacy fallback until an explicit
migration, but root and docs are never merged implicitly.

## Adding a new skill

1. Create `agent/common/skills/<name>/SKILL.md`
2. Existing symlinks pick it up for Claude Code, Codex, and Grok

Notable skills:

- `deliver` — outcome-driven implementation, evidence gates, local commit
- `consolidate` — semantic DRY inventory, safe unification, verified commit
- `git` — house rules for commit messages and branch flow
- `bump-tag` — semver bump, tag, push
- `knowledge-deposit` — deposit reusable knowledge: write the entry, lint it,
  stage only what you wrote, review the staged diff with one `review` summon,
  and commit locally

`deliver` selects only the capabilities justified by risk. Agent split
(producer ≠ approver):

- `strategist` / `strategy-rev` — contracts & tests; strategy-rev holds the gate
- `dev` / `rev` — implement and semantic review (no self-approval)
- `formatter` — applicability, format correction, and lint evidence for eligible source before commit
- `ui-checker` — measure with evidence only (does not write strategy/tests)
- `knowledge-inventory` — inventory durable delivery knowledge after commit and hand one sanitized batch to `knowledge-deposit`

## Adding a new agent tool

1. Create `agent/<tool>/` with tool-specific config
2. Symlink `agent/common/skills` (and adapt rules format if needed)
3. Add install steps to `bin/install`

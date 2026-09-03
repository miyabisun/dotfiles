# Overview

This repository manages my dotfiles.
Instead of copying files directly, the installation script creates symbolic links from this repository to your home directory. This keeps your configuration files organized in one place and easy to update.

# Installation

To install the dotfiles, run the following command. This will clone the repository and execute the `bin/install` script.

```bash
curl -L https://raw.github.com/miyabisun/dotfiles/master/install | bash
```

## What the installer does

The `bin/install` script sets up symbolic links for the following configuration files and directories:

### Root Directory
- `~/.editorconfig` -> `.editorconfig`
- Sets repo-local `core.hooksPath` to `hooks/`. After that, every commit or merge in the main checkout re-runs `bin/install` via `hooks/run-install`. Linked worktrees are skipped.


### SSH Directory
- `~/.ssh/config` -> `ssh/config`
- Creates `~/.ssh/conf.d` directory

### Config Directory (`~/.config`)
- `~/.config/git` -> `config/git`
- `~/.config/nvim` -> `config/nvim`
- `~/.config/tmux` -> `config/tmux`

### Agent Tools

All agent config lives under `agent/`:

```
agent/
├── common/   # shared: agents, designs, skills, rules, bin
├── claude/   # Claude Code only (hooks, workflows, settings)
├── codex/    # Codex CLI only (hooks, config)
└── grok/     # Grok CLI only (hooks, config)
```

See `agent/README.md` for details.

#### Claude Code (`~/.claude`)
- `~/.claude/skills` -> `agent/common/skills`
- `~/.claude/agents` -> `agent/common/agents`
- `~/.claude/designs` -> `agent/common/designs`
- `~/.claude/CLAUDE.md` -> `agent/claude/CLAUDE.md` -> `agent/common/rules/GLOBAL.md`
- `~/.claude/workflows`, `hooks`, `settings.json` -> `agent/claude/*`

#### Codex (`~/.codex`)
- `~/.codex/AGENTS.md` -> `agent/common/rules/GLOBAL.md`
- `~/.codex/agents`, `hooks.json` -> `agent/codex/*`
- `~/.codex/config.toml` — machine-local copy seeded from `agent/codex/config.toml`

#### Grok (`~/.grok`)
- `~/.grok/skills` -> `agent/common/skills`
- `~/.grok/agents` -> `agent/common/agents`
- `~/.grok/designs` -> `agent/common/designs`
- `~/.grok/AGENTS.md` -> `agent/common/rules/GLOBAL.md`
- `~/.grok/hooks` -> `agent/grok/hooks`
- `~/.grok/config.toml` — machine-local copy seeded from `agent/grok/config.toml`

#### `~/.local/bin`
- `emit-turn-end.sh` -> `agent/common/bin/emit-turn-end.sh`
- `review` -> `agent/common/bin/review` — the shared `codex exec` launch form used by every review summon
- `tmux-session-picker` -> `config/tmux/bin/tmux-session-picker`
- `tmux-mux` -> `config/tmux/bin/tmux-mux`

# Utilities

This repository includes several utility scripts in the `bin/` directory to help manage specific configurations.

## Bitwarden Integration

Commands in `bin/bw/` integrate with Bitwarden CLI (`bw`) to manage secrets and keys.
Each command is grouped by domain and takes a subcommand; run it with no arguments to see usage.

| Command | Bitwarden folder | Subcommands |
|---|---|---|
| `bw-secret` | CLI | `save <name> <value>` / `load` / `list` / `remove <name>` |
| `bw-ssh-key` | SSH Keys | `generate <name>` / `save <name> [filename]` / `load <name> [filename]` / `public <name>` / `private <name>` / `list` / `remove <name>` |
| `bw-ssh-config` | SSH Config | `save [name]` / `load <name>` / `load-all` / `cat <name>` / `list` / `remove <name>` |
| `bw-age` | Age Keys | `create [name]` / `save [name] [file]` / `identity [name]` / `recipient [name]` / `list` / `remove <name>` |
| `bw-env` | Env Files | `save <name> [file]` / `load <name> [file]` / `diff <name> [file]` / `get <name> <var>` / `keys <name>` / `list` / `remove <name>` |

- `bw-secret load` writes all secrets to `~/.config/.secrets` as `export KEY="VALUE"` lines; `save`/`remove` refresh the file automatically.
- `bw-age create` generates a key with `age-keygen` and stores it directly in Bitwarden without touching disk. Decrypt without leaving the key on disk: `age -d -i <(bw-age identity <name>) file.age`.
- `bw-env` backs up a project's whole `.env` file as one secure note. Unlike `bw-secret`, nothing is exported to the shell environment; `load` restores the file (0600) and `get` prints a single variable for scripting.
- `bw-env diff` checks a local `.env` against the stored copy before `load` overwrites it. It is read-only and prints keys without values: `-` exists only in Bitwarden, `+` only in the local file, `~` exists in both with different values, and a trailing `#` line summarises the counts. Pass `--values` (`-v`) to print the values too. It exits `0` when they match, `1` when they differ, and `2` on error, so scripts can gate a `load` on it. Multi-line values (quoted, or a bare PEM block) are compared whole, and a repeated key resolves to its first occurrence (like `bw-env get`). A line it cannot read as `KEY=value` — such as `KEY = value` with spaces around `=` — is an error reported with its line number, never a silent skip, so `diff` cannot claim a match it did not verify. A value wrapped over several lines without quotes is indistinguishable from separate assignments, so each line is compared as its own key; names that look like a base64 chunk are counted but withheld from the default output, since the name itself would be part of the value. Values are compared byte for byte, so a CRLF file against an LF one reports every key as different.
- Shared plumbing (unlock check, folder lookup, upsert) lives in `bin/bw/lib.sh`.

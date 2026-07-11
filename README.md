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
├── cursor/   # Cursor only (rules, hooks)
└── takt/     # TAKT adoption notes
```

See `agent/README.md` for details.

#### Claude Code (`~/.claude`)
- `~/.claude/skills` -> `agent/common/skills`
- `~/.claude/agents` -> `agent/common/agents`
- `~/.claude/designs` -> `agent/common/designs`
- `~/.claude/CLAUDE.md` -> `agent/claude/CLAUDE.md` -> `agent/common/rules/GLOBAL.md`
- `~/.claude/workflows`, `hooks`, `settings.json` -> `agent/claude/*`

#### Cursor (`~/.cursor`)
- `~/.cursor/skills` -> `agent/common/skills`
- `~/.cursor/agents` -> `agent/common/agents`
- `~/.cursor/designs` -> `agent/common/designs`
- `~/.cursor/rules` -> `agent/cursor/rules`
- `~/.cursor/hooks`, `hooks.json` -> `agent/cursor/hooks*`

#### `~/.local/bin`
- `emit-turn-end.sh` -> `agent/common/bin/emit-turn-end.sh`
- `tmux-session-picker` -> `config/tmux/bin/tmux-session-picker`

# Utilities

This repository includes several utility scripts in the `bin/` directory to help manage specific configurations.

## Bitwarden Integration

Commands in `bin/bw/` integrate with Bitwarden CLI (`bw`) to manage secrets and keys.
Each command is grouped by domain and takes a subcommand; run it with no arguments to see usage.

| Command | Bitwarden folder | Subcommands |
|---|---|---|
| `bw-secret` | CLI | `save <name> <value>` / `load` / `list` / `remove <name>` |
| `bw-ssh-key` | SSH Keys | `save [name] [filename]` / `load [name] [filename]` / `list` / `remove <name>` |
| `bw-ssh-config` | SSH Config | `save [name]` / `load` / `list` / `remove <name>` |
| `bw-age` | Age Keys | `create [name]` / `save [name] [file]` / `identity [name]` / `recipient [name]` / `list` / `remove <name>` |
| `bw-env` | Env Files | `save <name> [file]` / `load <name> [file]` / `get <name> <var>` / `list` / `remove <name>` |

- `bw-secret load` writes all secrets to `~/.config/.secrets` as `export KEY="VALUE"` lines; `save`/`remove` refresh the file automatically.
- `bw-age create` generates a key with `age-keygen` and stores it directly in Bitwarden without touching disk. Decrypt without leaving the key on disk: `age -d -i <(bw-age identity <name>) file.age`.
- `bw-env` backs up a project's whole `.env` file as one secure note. Unlike `bw-secret`, nothing is exported to the shell environment; `load` restores the file (0600) and `get` prints a single variable for scripting.
- Shared plumbing (unlock check, folder lookup, upsert) lives in `bin/bw/lib.sh`.



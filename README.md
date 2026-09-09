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
- `review` -> `agent/common/bin/review` — cross-model review.
- `agent-test` -> `agent/common/bin/agent-test` — user-level test gate for Codex and Claude Code.
  Set the caller with `--from codex|claude`.
- `tmux-session-picker` -> `config/tmux/bin/tmux-session-picker`
- `tmux-mux` -> `config/tmux/bin/tmux-mux`

## Neovim bookmark spaces

[tabspaces.nvim v0.1.0](https://github.com/miyabisun/tabspaces.nvim/releases/tag/v0.1.0)
groups live tabs by directory. Neovim 0.10+, fzf-lua and `fzf` are required.
The normal installer links this configuration; lazy.nvim installs the public tag
on the next Neovim startup.

Use `:TabspacesAdd Name` to bookmark or rename the current directory.
For any other directory, including non-Git locations:

```vim
:lua require('tabspaces').add('Shared data', '~/.local/share')
```

Press **Ctrl+n twice in normal mode** to search by name or path and switch.
Live spaces appear first with their tab counts. `:tabe` adds a tab to the space.
`gt` / `gT` wrap through its tabs; `g1`–`g9` select its visible tab numbers.
Absent numbers do nothing. Switching back restores the last selected live tab.
Existing `ze`, `zp` and split bindings remain available; `zp` uses the space cwd.
Insert-mode Ctrl+n keeps its completion behavior.

`:TabspacesRemove` removes the current bookmark without closing its tabs.
Native `:tabnext` can still reach all tabs, including initial unassigned tabs.
`:qa` keeps normal unsaved warnings. Restarting starts fresh tabs and buffers.
Only bookmark names and paths persist under Neovim's data directory, outside Git.
See the plugin README or `:help tabspaces` for the full API and limitations.

## pen CLI updates

Run `bash bin/install-apps --run-step install_pen` from this checkout to install
or update only pen. An already installed current version is left in place.
Downloads must pass the published checksum and report the selected release version.

Banner-only releases v0.1.0/v0.1.1 are no longer accepted as download artifacts.
An existing executable with the legacy pen help banner is still recognized for a
one-time migration: the same command replaces it with the latest verified release.
If download or validation fails, the existing binary stays in place; retry the
command after the release or connection is fixed. Unrecognized targets are refused.

As of 2026-09-08, [v0.1.0 still has public Linux/macOS release assets](https://github.com/miyabi-sunny-side/pen-cli/releases/tag/v0.1.0),
and [v0.1.1 source also lacks `--version`](https://github.com/miyabi-sunny-side/pen-cli/blob/v0.1.1/src/lib.rs)
although it has no published release assets. Other machines may still run these
versions; retaining target recognition avoids requiring manual removal first.

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

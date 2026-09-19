# dotfiles

Miyabi's personal dotfiles for shells, editors, terminal tools, and coding agents.
Review Git identity, SSH hosts, and agent rules before adopting these settings.
You can copy individual settings or install the managed configuration described below.

## Install

Use Linux or macOS with Git, Bash, and the usual Unix command-line tools available.
Clone into a permanent location: installed links point back to this checkout.

```bash
git clone https://github.com/miyabisun/dotfiles.git
cd dotfiles
```

Review [bin/install](bin/install) and back up existing configuration at the target paths.
The installer has no general backup or rollback mechanism.
Files at symbolic-link targets can be replaced; existing directories can cause failures.
Earlier changes remain if a later step fails.

When ready, install the configuration:

```bash
bash bin/install
```

Open a new Bash or Zsh session to load the shell settings.
The installer updates existing `.bashrc` and `.zshrc` files; it does not create missing ones.
Keep the checkout in place while using its linked settings.

## What changes

| Area | Installed configuration |
|---|---|
| Editor defaults | `~/.editorconfig` links to [.editorconfig](.editorconfig) |
| SSH | `~/.ssh/config` links to [ssh/config](ssh/config); `~/.ssh/conf.d` is created |
| Git, Neovim, tmux | `~/.config/{git,nvim,tmux}` link to the matching [config](config) directories |
| Herdr | `~/.config/herdr/config.toml` links to [config/herdr/config.toml](config/herdr/config.toml) |
| Zsh plugins | `~/.config/sheldon/plugins.toml` links to [config/zsh/plugins.toml](config/zsh/plugins.toml) |
| Bash and Zsh | A `DOTFILES_START` / `DOTFILES_END` block loads settings from this checkout |
| Coding agents | Shared skills, rules, roles, and hooks; see [agent configuration](agent/README.md) |
| Local commands | Helpers are installed under `~/.local/bin`; see below |

Claude's `settings.json`, Codex's `config.toml`, and Grok's `config.toml` are local copies.
They are seeded from `agent/` only when absent.
A legacy link to the matching template is converted to a copy with its contents preserved.
Existing local settings are kept. Retired agent-talk peer MCP tables are removed.
Use the [config-merge skill](agent/common/skills/config-merge/SKILL.md) to sync later template changes.

Shell settings outside the managed block are preserved.
Broken or duplicate block markers stop shell-file updates; correct them before retrying.
Other installation steps may already have run when that error is reported.

The installer also creates local agent runtime helpers and Herdr integration scripts.
Herdr is optional; if present, its integration generator must succeed.
If Sheldon is installed, the installer runs `sheldon lock`.
It does not install applications or retrieve secrets.

## Update

```bash
git pull --ff-only
bash bin/install
```

The installer sets this repository's `core.hooksPath` to `hooks/`.
Commits and merges in the main checkout rerun it automatically.
Linked worktrees skip automatic installation. Live links stay with the main checkout.
If an update fails, keep existing data and inspect the reported conflict before rerunning.

## Included tools

| Purpose | Entry point |
|---|---|
| Coding-agent setup and skills | [agent/README.md](agent/README.md) |
| Neovim bookmark spaces and navigation | [config/nvim/README.md](config/nvim/README.md) |
| Optional CLI installers, including pen | [Tools and secrets](docs/utilities.md) |
| Bitwarden-backed secrets, SSH keys, and env files | [Bitwarden commands](docs/utilities.md#bitwarden-commands) |
| TypeSafe credentials on another machine | [TypeSafe setup](docs/utilities.md#typesafe-credentials) |

Local helpers include `review`, `agent-test`, `meiseki-lint`, and tmux launchers.
Some use separately installed applications; their source and setup are linked above.
`bin/install-apps` installs optional CLIs.
`bin/install-envs` restores TypeSafe credentials.
Review each script before running it.

## Verify changes

The checks use temporary environments for installers, hooks, and utilities:

```bash
bin/check
```

Agent workflow checks and tool requirements are described in [agent/README.md](agent/README.md).

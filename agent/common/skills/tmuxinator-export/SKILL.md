---
name: tmuxinator-export
description: >-
  Inspect the current tmux session and turn its windows, panes, working
  directories, layouts, and clearly identifiable long-running commands into a
  safe tmuxinator YAML project. Use when the user wants to save, snapshot,
  recreate, reduce, or migrate a live tmux session, or asks for a tmuxinator
  config based on the session they are currently using.
---

# Tmuxinator export

Export only the current tmux session. Preserve its structure while treating
every command as untrusted input that must be safe to store and replay.

## Workflow

1. Require `tmux` and `$TMUX_PANE`. Treat tmuxinator as optional: when it is
   missing, continue through inspection and YAML creation, and report that
   validation and launch are unavailable. Do not install software as part of
   this skill.
2. Run `scripts/inspect-session.sh` from this skill. It validates every field
   before emitting anything and stops on explicit URLs, assignment-like metadata,
   or malformed metadata. Host-like local directory names are paths, not
   network endpoints. Do
   not save its output to the repository or send it to another agent.
3. Classify each pane only from the reported cwd, window name, and
   `pane_current_command`. Do not inspect scrollback, process arguments,
   environment values, `.env` files, or secret stores.
4. Build a proposed YAML document using the rules below and show the user a
   compact table of pane IDs, classifications, and proposed restart commands.
   Explicitly call out commands that will start paid or networked agents.
5. Resolve the config directory as
   `${TMUXINATOR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/tmuxinator}`. Use the
   session name as the project name when it contains only letters, digits,
   `_`, and `-`; otherwise replace each run of other characters with `-` and
   show the normalized name. Append `.yml` for the destination.
   Stop if it already exists. Never overwrite or invent a force option.
6. After approval, start `scripts/write-project.py <absolute-destination>` and
   provide the exact shown YAML on standard input. This writer opens every
   config path component without following symlinks and uses exclusive creation,
   so a destination created
   during approval causes a safe stop without reading or changing it. Request
   permission if the destination is outside the environment's writable roots.
7. When tmuxinator is available, run `tmuxinator debug <project>`. On success,
   report the path and that the existing `mux` zsh command can select it. On
   failure, leave the file in place, report the validation error, and do not
   start a session. When tmuxinator is unavailable, mark validation as skipped
   and state that `mux` launch requires a compatible runtime.

## YAML rules

- Set `name` to the resolved safe project name.
- Set the top-level `root` to the active pane cwd.
- Keep windows and panes in reported index order. Preserve every window name,
  exact `window_layout`, active window, and active pane via `startup_window`,
  `startup_pane`, and per-window `focused_pane`.
- Add a window-level `root` when its first pane differs from the top-level root.
  For another cwd within the same window, make that pane's first command
  `cd -- <shell-quoted-path>`.
- Quote YAML scalars whenever punctuation or YAML implicit types could change
  their meaning.
- Use an empty string for shell panes and every unsafe or uncertain command.

## Command safety

Replay only a stable command whose exact safe invocation is known. Bare
`claude`, `codex`, `cursor-agent`, and `nvim` are acceptable when the current
command matches and no arguments need reconstruction. An empty shell is safer
than a guess.

Always emit an empty string for:

- shells and transient commands such as `git`, pagers, tests, and installers;
- commands inferred only from titles or information outside the inspection
  report;
- SSH, database, deployment, destructive, or privileged commands;
- anything containing credentials, tokens, keys, environment assignments,
  network endpoints, or unclear arguments.

Do not include explicit URLs, assignment-like metadata, or network endpoint
commands in the YAML, response, logs, or peer messages. Do not mistake a local
path segment such as `node_modules`, `next.js`, or `project-server` for a host.

Use this shape; quote the actual scalar values:

```yaml
name: 'settings'
root: '/home/user/project'
startup_window: 'agent'
startup_pane: 1
windows:
  - 'agent':
      layout: '66d1,146x37,0,0{73x37,0,0,24,72x37,74,0,25}'
      focused_pane: 1
      panes:
        - 'claude'
        - 'codex'
  - 'editor':
      root: '/home/user/other-project'
      panes:
        - 'nvim'
        - ''
```

## Output

Before writing, show:

```text
destination: <absolute path>
session: <name>
panes:
  <pane-id> <cwd> <classification> -> <command or empty shell>
validation: pending
```

After writing, replace `validation` with either the exact `tmuxinator debug`
result or `skipped (tmuxinator not available)`.

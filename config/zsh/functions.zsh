# ==================================================
# Shell functions (recognized as commands, version-controlled)
# ==================================================

# tmuxinator: pick a project with fzf, then start it
mux() {
  local project
  project="$(ls ~/.config/tmuxinator/ | sed 's/\.yml$//' | fzf)" || return
  [[ -n "$project" ]] && tmuxinator start "$project"
}

# tmux attach (outside) / switch (inside): pick a session with fzf, or pass a name
a() {
  command -v tmux > /dev/null 2>&1 || { echo "tmux not found" >&2; return 1; }
  local target="$1"
  if [[ -z "$target" ]]; then
    local sessions
    sessions="$(tmux list-sessions -F '#S' 2> /dev/null)" || { echo "no tmux sessions" >&2; return 1; }
    [[ -n "$TMUX" ]] && sessions="$(grep -vxF "$(tmux display-message -p '#S')" <<< "$sessions")"
    target="$(fzf --reverse --prompt="session> " \
      --preview 'tmux list-windows -t {} -F "#I: #W (#{pane_current_command})"; echo; tmux capture-pane -ep -t {}' \
      --preview-window=right,65% <<< "$sessions")" || return
  fi
  [[ -z "$target" ]] && return
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "=$target"
  else
    tmux attach -t "=$target"
  fi
}

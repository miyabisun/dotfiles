# ==================================================
# Shell functions (recognized as commands, version-controlled)
# ==================================================

# tmuxinator: pick a project with fzf, then start it
mux() {
  local project
  project="$(ls ~/.config/tmuxinator/ | sed 's/\.yml$//' | fzf)" || return
  [[ -n "$project" ]] && tmuxinator start "$project"
}

# Clipboard copy: read stdin and send to the system clipboard.
# Picks an OS-appropriate backend: pbcopy / wl-copy / xclip / xsel.
copy() {
  if [[ "$OSTYPE" == darwin* ]]; then
    pbcopy
  elif [[ -n "$WAYLAND_DISPLAY" ]] && command -v wl-copy > /dev/null 2>&1; then
    wl-copy
  elif command -v xclip > /dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel > /dev/null 2>&1; then
    xsel --clipboard --input
  else
    echo "copy: no clipboard tool found (install xclip / xsel / wl-clipboard)" >&2
    return 1
  fi
}

# MFA TOTP: pick a pass entry under mfa/ with fzf, copy a fresh TOTP to clipboard.
# The pass entry's first line is treated as the Base32 TOTP secret.
mfa() {
  command -v pass     > /dev/null 2>&1 || { echo "mfa: pass not found" >&2; return 1; }
  command -v oathtool > /dev/null 2>&1 || { echo "mfa: oathtool not found" >&2; return 1; }
  local store="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
  [[ -d "$store/mfa" ]] || { echo "mfa: $store/mfa not found" >&2; return 1; }
  local entry
  entry="$(find "$store/mfa" -type f -name '*.gpg' 2> /dev/null \
    | sed -e "s|^$store/||" -e 's|\.gpg$||' \
    | sort \
    | fzf --reverse --prompt='mfa> ')" || return
  [[ -z "$entry" ]] && return
  local secret
  secret="$(pass "$entry" | head -n1)" || return
  [[ -z "$secret" ]] && { echo "mfa: empty secret for $entry" >&2; return 1; }
  oathtool --totp --base32 "$secret" | copy && echo "mfa: copied TOTP for $entry"
}

# tmux attach (outside) / switch (inside): pick a session with fzf, or pass a name
a() {
  command -v tmux > /dev/null 2>&1 || { echo "tmux not found" >&2; return 1; }
  local target="$1"
  if [[ -z "$target" ]]; then
    local sessions
    sessions="$(tmux list-sessions -F '#S' 2> /dev/null)" || { echo "no tmux sessions" >&2; return 1; }
    [[ -n "$TMUX" ]] && sessions="$(grep -vxF "$(tmux display-message -p '#S')" <<< "$sessions")"
    [[ -z "$sessions" ]] && { echo "no other sessions" >&2; return 1; }
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

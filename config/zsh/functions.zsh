# ==================================================
# Shell functions (recognized as commands, version-controlled)
# ==================================================

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

# Claude Code + OpenAI GPT-5.6 via local CLIProxyAPI (ChatGPT subscription).
# Expects ~/.cli-proxy-api/client.key holding the same value as api-keys in
# ~/.cli-proxy-api/config.yaml, and cli-proxy-api listening on 127.0.0.1:8317.
_claudex() {
  local model="$1"; shift
  local key_file="$HOME/.cli-proxy-api/client.key"
  [[ -r "$key_file" ]] || { echo "claudex: $key_file not found (run CLIProxyAPI setup first)" >&2; return 1; }
  curl -s -o /dev/null -m 2 http://127.0.0.1:8317/ \
    || { echo "claudex: CLIProxyAPI is not running on 127.0.0.1:8317" >&2; return 1; }
  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
  ANTHROPIC_AUTH_TOKEN="$(<"$key_file")" \
  CLAUDE_CODE_SUBAGENT_MODEL="$model" \
  CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
  CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 \
  ENABLE_TOOL_SEARCH=false \
  claude --model "$model" "$@"
}
sol()  { _claudex gpt-5.6-sol  "$@"; }
luna() { _claudex gpt-5.6-luna "$@"; }

# tmux attach (outside) / switch (inside): pick a session with fzf, or pass a name
a() {
  command -v tmux > /dev/null 2>&1 || { echo "tmux not found" >&2; return 1; }
  local target="$1"
  if [[ -z "$target" ]]; then
    local sessions
    sessions="$(tmux list-sessions -F '#S' 2> /dev/null)" || { echo "no tmux sessions" >&2; return 1; }
    sessions="$(sed '/^_/d' <<< "$sessions")"
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

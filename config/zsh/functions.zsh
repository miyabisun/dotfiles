# ==================================================
# Shell functions (recognized as commands, version-controlled)
# ==================================================

# tmuxinator: pick a project with fzf, then start it
mux() {
  command -v tmuxinator > /dev/null 2>&1 || { echo "tmuxinator not found" >&2; return 1; }
  local config_dir="${TMUXINATOR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/tmuxinator}"
  [[ -d "$config_dir" ]] || { echo "no tmuxinator projects" >&2; return 1; }
  local -a projects
  local file
  for file in "$config_dir"/*.yml(N) "$config_dir"/*.yaml(N); do
    projects+=("${${file:t}%.*}")
  done
  (( ${#projects} )) || { echo "no tmuxinator projects" >&2; return 1; }
  local project
  project="$(printf '%s\n' "${projects[@]}" | sort -u | fzf)" || return
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

# Claude の管理・headless command (mcp/doctor/-p 等) も SessionStart/End hooks
# を発火するため、hooks 側が見る skip 変数を立てて pane の既存登録を守る。
# グローバルオプション (値を取るものを含む) を読み飛ばして実サブコマンドを返す。
# 前置オプションで分類を回避されると pane 登録が壊れるため、位置ではなく内容で判定する。
_agent_cli_subcommand() {
  local value_opts="$1"
  local optional_value_opts="$2"
  local known_subcommands="$3"
  shift 3
  local arg
  while (( $# )); do
    arg="$1"
    case "$arg" in
      --)
        # end-of-options sentinel: 以降はサブコマンドではなく prompt
        return 0
        ;;
      --*=*) shift ;;
      -*)
        if [[ " $value_opts " == *" $arg "* ]]; then
          shift 2
        elif [[ " $optional_value_opts " == *" $arg "* ]]; then
          # 任意値オプション (--debug api 等)。次語が既知サブコマンドなら
          # 値ではないので食わない
          if (( $# > 1 )) && [[ "$2" != -* ]] \
            && [[ " $known_subcommands " != *" $2 "* ]]; then
            shift 2
          else
            shift
          fi
        else
          shift
        fi
        ;;
      *)
        print -r -- "$arg"
        return 0
        ;;
    esac
  done
  return 0
}

# `--` sentinel より前にだけ現れる非対話フラグを検出する。sentinel 以降は
# サブコマンドでもオプションでもなく prompt なので走査を打ち切る。
_agent_cli_has_flag_before_sentinel() {
  local flags="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "$arg" == "--" ]] && return 1
    [[ " $flags " == *" $arg "* ]] && return 0
  done
  return 1
}

_CLAUDE_MANAGEMENT_SUBCOMMANDS="mcp agents auth auto-mode doctor gateway project setup-token ultrareview update upgrade install plugin plugins"

_claude_is_interactive() {
  _agent_cli_has_flag_before_sentinel "-p --print -v --version -h --help" "$@" \
    && return 1

  local subcommand
  # 第2引数は任意値オプション (--debug api mcp list のように空白形式で値を
  # 取り得るもの)。次語が既知サブコマンドなら値として食わない
  subcommand="$(_agent_cli_subcommand \
    "--settings --model --fallback-model --agent --agents --add-dir --mcp-config --plugin-dir --plugin-url --system-prompt --append-system-prompt --system-prompt-file --append-system-prompt-file --permission-mode --session-id --betas --tools --allowedTools --allowed-tools --disallowedTools --disallowed-tools --output-format --input-format --setting-sources --effort --debug-file --file --json-schema --max-budget-usd -n --name --remote-control-session-name-prefix" \
    "-d --debug -r --resume -w --worktree --from-pr --prompt-suggestions --remote-control" \
    "$_CLAUDE_MANAGEMENT_SUBCOMMANDS" \
    "$@")"
  [[ -n "$subcommand" && " $_CLAUDE_MANAGEMENT_SUBCOMMANDS " == *" $subcommand "* ]] \
    && return 1
  return 0
}

claude() {
  if _claude_is_interactive "$@"; then
    command claude "$@"
  else
    CLAUDE_AGENT_TALK_SKIP=1 command claude "$@"
  fi
}

# broker は systemd 管理の常駐サービスで、実体は home-server の規約どおり
# releases/vX.Y.Z + current に不変配置される (`~/.local/bin/<service>` は
# moca-server / shoebox と同じく廃止済みの旧 layout)。PATH には載らないので
# 絶対パスで呼ぶ。broker 不在時に素の CLI へ落とさないのは既存契約 —
# 未登録 pane は peer から不可視な上に MCP tool が全て拒否されるので、
# 黙って起動するより起動しない方が安全。
_AGENT_TALK_BIN="$HOME/.local/share/agent-talk/current/agent-talk"

_agent_talk_run() {
  local pane_name="$1"
  shift
  "$_AGENT_TALK_BIN" run "$pane_name" "$@"
}

# Codex には session lifecycle hook がないため wrapper で登録する。
# 委譲先の agent-talk run は v0.5.1 以降が必要。
# 管理・headless command は対話paneではないため登録しない。透過実行しないと
# 一時的な CLI 起動 (codex mcp list 等) が pane の既存登録を消してしまう。
_CODEX_MANAGEMENT_SUBCOMMANDS="mcp mcp-server app-server remote-control exec exec-server execpolicy review login logout completion apply sandbox debug features cloud update doctor archive delete unarchive plugin version help"

_codex_is_interactive() {
  _agent_cli_has_flag_before_sentinel "--version -V -h --help" "$@" \
    && return 1

  local subcommand
  # 値を取るオプションのみ列挙する (codex --help の arity に一致)。
  # --oss --search --strict-config 等の単独フラグを入れると次語を食って誤判定する
  subcommand="$(_agent_cli_subcommand \
    "-c --config --enable --disable --remote --remote-auth-token-env -i --image -m --model --local-provider -p --profile -s --sandbox -C --cd --add-dir -a --ask-for-approval" \
    "" \
    "$_CODEX_MANAGEMENT_SUBCOMMANDS" \
    "$@")"
  [[ -n "$subcommand" && " $_CODEX_MANAGEMENT_SUBCOMMANDS " == *" $subcommand "* ]] \
    && return 1
  return 0
}

# 素の `codex` は shadow しない。herdr へ移る際に、登録 wrapper が同名を占有して
# いると素の起動が邪魔される。agent-talk 登録つきの起動は opt-in の `codet`
# (code + talk) に分ける。登録される pane 名と実行される executable はどちらも
# 従来どおり `codex` のままで、変わるのは入口の名前だけ。
codet() {
  if _codex_is_interactive "$@"; then
    _agent_talk_run codex codex "$@"
  else
    command codex "$@"
  fi
}

# Cursor の管理・headless command は対話paneではないため登録しない。
_cursor_agent_is_interactive() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -p|--print|-v|--version|-h|--help)
        return 1
        ;;
    esac
  done

  case "${1:-}" in
    install-shell-integration|uninstall-shell-integration|login|logout|mcp|worker|status|whoami|models|about|update|create-chat|generate-rule|rule)
      return 1
      ;;
  esac
  return 0
}

cursor-agent() {
  if _cursor_agent_is_interactive "$@"; then
    _agent_talk_run cursor cursor-agent "$@"
  else
    command cursor-agent "$@"
  fi
}

# Cursor installer provides `agent` as a second symlink to cursor-agent. Do not
# shadow an unrelated command that happens to use this generic name.
agent() {
  local agent_path="$(whence -p agent 2> /dev/null)"
  local cursor_path="$(whence -p cursor-agent 2> /dev/null)"
  if [[ -z "$agent_path" || -z "$cursor_path" \
      || "${agent_path:A}" != "${cursor_path:A}" ]]; then
    command agent "$@"
    return $?
  fi

  if _cursor_agent_is_interactive "$@"; then
    _agent_talk_run cursor agent "$@"
  else
    command agent "$@"
  fi
}

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

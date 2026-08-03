#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
notifier_source="$repo_root/agent/common/bin/notify-file-permission.sh"
emitter_source="$repo_root/agent/common/bin/emit-turn-end.sh"
claude_wait_hook="$repo_root/agent/claude/hooks/notify-waiting.sh"

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_bin="$test_root/bin"
trusted_bin="$test_root/trusted-bin"
fake_home="$test_root/home"
state_root="$test_root/state"
mkdir -p "$fake_bin" "$trusted_bin" "$fake_home/.local/bin" "$state_root"
cp "$notifier_source" "$trusted_bin/notify-file-permission.sh"
cp "$emitter_source" "$trusted_bin/emit-turn-end.sh"
notifier="$trusted_bin/notify-file-permission.sh"
emitter="$trusted_bin/emit-turn-end.sh"

cat >"$fake_bin/tmux" <<'TMUX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$NOTIFY_TEST_TMUX_LOG"

case "${1:-}" in
  display-message)
    format="${*: -1}"
    case "$format" in
      '#S') printf '%s\n' 'settings' ;;
      '#{pane_tty}') printf '%s\n' "$NOTIFY_TEST_PANE_TTY" ;;
      '#{?window_active,1,}') printf '%s' '' ;;
    esac
    ;;
  list-clients)
    exit 0
    ;;
  show-options)
    option="${*: -1}"
    state_file="$NOTIFY_TEST_STATE_ROOT/${option#@}"
    [[ -f "$state_file" ]] && cat "$state_file"
    ;;
  set-option)
    if [[ " $* " == *' -u '* ]]; then
      option="${*: -1}"
      rm -f "$NOTIFY_TEST_STATE_ROOT/${option#@}"
      exit 0
    fi
    argc="$#"
    if [[ "$argc" -ge 2 && "${!argc}" == @* ]]; then
      option="${!argc}"
      value=1
    else
      option_index=$((argc - 1))
      option="${!option_index}"
      value="${!argc}"
    fi
    if [[ "$option" == @* ]]; then
      printf '%s' "$value" >"$NOTIFY_TEST_STATE_ROOT/${option#@}"
    fi
    ;;
esac
TMUX

cat >"$fake_bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$NOTIFY_TEST_CURL_LOG"
[[ "${NOTIFY_TEST_CURL_FAIL:-0}" == 1 ]] && exit 22
exit 0
CURL

cat >"$fake_bin/dirname" <<'DIRNAME'
#!/bin/bash
printf 'PATH dirname must not run\n' >>"$NOTIFY_TEST_PATH_LOG"
exit 99
DIRNAME

cat >"$trusted_bin/agent-talk" <<'AGENT_TALK'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >>"$NOTIFY_TEST_AGENT_TALK_LOG"
AGENT_TALK

printf 'TMUX_BIN=%s\nCURL_BIN=%s\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  "$fake_bin/tmux" "$fake_bin/curl" /usr/bin/sha256sum \
  >"$trusted_bin/.dotfiles-agent-runtime"
chmod +x "$fake_bin/tmux" "$fake_bin/curl" "$fake_bin/dirname" \
  "$trusted_bin/agent-talk" \
  "$notifier" "$emitter"
cp "$emitter" "$fake_home/.local/bin/emit-turn-end.sh"
# broker は systemd 管理サービスの release layout 側に居る (~/.local/bin は旧 layout)
mkdir -p "$fake_home/.local/share/agent-talk/current"
cp "$trusted_bin/agent-talk" \
  "$fake_home/.local/share/agent-talk/current/agent-talk"
cp "$trusted_bin/.dotfiles-agent-runtime" \
  "$fake_home/.local/bin/.dotfiles-agent-runtime"

export PATH="$fake_bin:$PATH"
export HOME="$fake_home"
export TMUX='test-tmux'
export TMUX_PANE='%25'
export MOCA_URL='https://notify.invalid'
export NOTIFY_TEST_STATE_ROOT="$state_root"
export NOTIFY_TEST_PANE_TTY="$test_root/pane.tty"
export NOTIFY_TEST_TMUX_LOG="$test_root/tmux.log"
export NOTIFY_TEST_CURL_LOG="$test_root/curl.log"
export NOTIFY_TEST_AGENT_TALK_LOG="$test_root/agent-talk.log"
export NOTIFY_TEST_PATH_LOG="$test_root/path.log"
: >"$NOTIFY_TEST_PANE_TTY"
: >"$NOTIFY_TEST_TMUX_LOG"
: >"$NOTIFY_TEST_CURL_LOG"
: >"$NOTIFY_TEST_AGENT_TALK_LOG"
: >"$NOTIFY_TEST_PATH_LOG"

"$notifier" codex 619
test "$(od -An -tx1 "$NOTIFY_TEST_PANE_TTY" | tr -d ' \n')" = '07'
grep -F 'settingsでファイル操作の許可が必要です' "$NOTIFY_TEST_CURL_LOG" >/dev/null
grep -F '@agent_bell' "$NOTIFY_TEST_TMUX_LOG" >/dev/null
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 1

# The same broker message emits neither another BEL nor another MOCA request.
"$notifier" codex 619
test "$(od -An -tx1 "$NOTIFY_TEST_PANE_TTY" | tr -d ' \n')" = '07'
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 1

# Claude's generic permission hook and the normal completion hook must not
# duplicate the permission announcement. Completion still returns the pane to
# agent-talk idle exactly once.
printf '%s\n' '{"message":"permission prompt"}' | bash "$claude_wait_hook"
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 1
"$emitter" codex success talk
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 1
test "$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")" -eq 1
test ! -e "$state_root/agent_file_permission_waiting"

# Missing MOCA configuration keeps the BEL path useful and succeeds.
unset MOCA_URL
: >"$NOTIFY_TEST_PANE_TTY"
"$notifier" codex 620
test "$(od -An -tx1 "$NOTIFY_TEST_PANE_TTY" | tr -d ' \n')" = '07'

# A failed destination and an unavailable pane tty degrade safely.
export MOCA_URL='https://notify.invalid'
export NOTIFY_TEST_CURL_FAIL=1
export NOTIFY_TEST_PANE_TTY="$test_root/missing/pane.tty"
"$notifier" codex 621

# Outside tmux, use the project basename for a sanitized MOCA notice.
unset TMUX TMUX_PANE NOTIFY_TEST_CURL_FAIL
mkdir -p "$test_root/project-alpha"
cd "$test_root/project-alpha"
"$notifier" codex 622
grep -F 'project-alphaでファイル操作の許可が必要です' "$NOTIFY_TEST_CURL_LOG" >/dev/null

# curl is optional: permission handling still succeeds without a MOCA sink.
printf 'TMUX_BIN=%s\nCURL_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  "$fake_bin/tmux" /usr/bin/sha256sum \
  >"$trusted_bin/.dotfiles-agent-runtime"
curl_count="$(wc -l <"$NOTIFY_TEST_CURL_LOG")"
"$notifier" codex 623
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq "$curl_count"

# A broken notification pin must not wedge the agent-talk queue: success still
# attempts exactly one adjacent broker turn-end through the EXIT trap.
printf 'TMUX_BIN=/missing/tmux\nCURL_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  /usr/bin/sha256sum >"$trusted_bin/.dotfiles-agent-runtime"
turn_end_count="$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")"
export TMUX='test-tmux'
export TMUX_PANE='%25'
if "$emitter" codex success talk 2>/dev/null; then
  echo 'invalid tmux pin should fail notification processing' >&2
  exit 1
fi
test "$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")" \
  -eq "$((turn_end_count + 1))"
unset TMUX TMUX_PANE

# The sidecar is parsed as strict data, never sourced as shell code.
side_effect="$test_root/runtime-side-effect"
printf 'TMUX_BIN=$(touch %s)\nCURL_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  "$side_effect" /usr/bin/sha256sum >"$trusted_bin/.dotfiles-agent-runtime"
if "$notifier" codex 624 2>/dev/null; then
  echo 'malformed runtime sidecar must fail closed' >&2
  exit 1
fi
test ! -e "$side_effect"

if "$notifier" codex 'not-an-id' 2>/dev/null; then
  echo 'invalid agent-talk message IDs must fail closed' >&2
  exit 1
fi

ln -s "$notifier_source" "$test_root/symlink-notifier"
if "$test_root/symlink-notifier" codex 623 2>/dev/null; then
  echo 'symlinked permission notifier must fail closed' >&2
  exit 1
fi
test ! -s "$NOTIFY_TEST_PATH_LOG"

echo 'file permission notification test: pass'

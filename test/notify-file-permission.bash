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
mkdir -p "$fake_bin" "$trusted_bin" "$fake_home/.local/bin"
cp "$notifier_source" "$trusted_bin/notify-file-permission.sh"
cp "$emitter_source" "$trusted_bin/emit-turn-end.sh"
notifier="$trusted_bin/notify-file-permission.sh"
emitter="$trusted_bin/emit-turn-end.sh"

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

printf 'CURL_BIN=%s\nHERDR_BIN=\nJQ_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  "$fake_bin/curl" /usr/bin/sha256sum \
  >"$trusted_bin/.dotfiles-agent-runtime"
chmod +x "$fake_bin/curl" "$fake_bin/dirname" \
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
export MOCA_URL='https://notify.invalid'
export NOTIFY_TEST_CURL_LOG="$test_root/curl.log"
export NOTIFY_TEST_AGENT_TALK_LOG="$test_root/agent-talk.log"
export NOTIFY_TEST_PATH_LOG="$test_root/path.log"
: >"$NOTIFY_TEST_CURL_LOG"
: >"$NOTIFY_TEST_AGENT_TALK_LOG"
: >"$NOTIFY_TEST_PATH_LOG"

# MOCA 通知は project basename を文脈に使う。
mkdir -p "$test_root/project-alpha"
cd "$test_root/project-alpha"
"$notifier" codex 619
grep -F 'project-alphaでファイル操作の許可が必要です' "$NOTIFY_TEST_CURL_LOG" >/dev/null
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 1
# permission は success ではないので turn-end は発火しない。
test "$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")" -eq 0

# Claude's generic waiting hook announces independently (the tmux dedupe
# option left with the tmux backend). Completion notifies (the herdr pin is
# empty here, so the quiescence gate fail-opens) and returns the pane to
# agent-talk idle exactly once.
printf '%s\n' '{"message":"permission prompt"}' | bash "$claude_wait_hook"
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 2
grep -F 'claudeが確認を求めています' "$NOTIFY_TEST_CURL_LOG" >/dev/null
"$emitter" codex success
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 3
grep -F 'codexが完了しました' "$NOTIFY_TEST_CURL_LOG" >/dev/null
test "$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")" -eq 1

# Missing MOCA configuration still succeeds without a notification.
unset MOCA_URL
"$notifier" codex 620
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 3

# A failed destination degrades safely.
export MOCA_URL='https://notify.invalid'
export NOTIFY_TEST_CURL_FAIL=1
"$notifier" codex 621
unset NOTIFY_TEST_CURL_FAIL

# curl is optional: permission handling still succeeds without a MOCA sink.
printf 'CURL_BIN=\nHERDR_BIN=\nJQ_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  /usr/bin/sha256sum >"$trusted_bin/.dotfiles-agent-runtime"
curl_count="$(wc -l <"$NOTIFY_TEST_CURL_LOG")"
"$notifier" codex 623
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq "$curl_count"

# A broken notification pin must not wedge the agent-talk queue: success still
# attempts exactly one adjacent broker turn-end through the EXIT trap.
printf 'BROKEN=1\nCURL_BIN=\nHERDR_BIN=\nJQ_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  /usr/bin/sha256sum >"$trusted_bin/.dotfiles-agent-runtime"
turn_end_count="$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")"
if "$emitter" codex success talk 2>/dev/null; then
  echo 'a malformed pin should fail notification processing' >&2
  exit 1
fi
test "$(grep -Fc 'turn-end' "$NOTIFY_TEST_AGENT_TALK_LOG")" \
  -eq "$((turn_end_count + 1))"

# The sidecar is parsed as strict data, never sourced as shell code.
side_effect="$test_root/runtime-side-effect"
printf 'CURL_BIN=$(touch %s)\nHERDR_BIN=\nJQ_BIN=\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
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

echo 'notify-file-permission test: pass'

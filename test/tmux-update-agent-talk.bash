#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
tmux_log="$test_root/tmux.log"
mkdir -p "$fake_bin"

cat >"$fake_bin/tmux" <<'TMUX'
#!/bin/sh
printf '%s\n' "$*" >>"$TMUX_UPDATE_TEST_LOG"
TMUX
chmod +x "$fake_bin/tmux"

cat >"$fake_bin/agent-talk" <<'AGENT'
#!/bin/sh
case "${1:-}" in
  update)
    printf '%s\n' "${TMUX_UPDATE_TEST_OUTPUT:-agent-talk: already current}"
    exit "${TMUX_UPDATE_TEST_STATUS:-0}"
    ;;
  *) exit 64 ;;
esac
AGENT
chmod +x "$fake_bin/agent-talk"

PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$test_root/home" \
  TMUX_UPDATE_TEST_LOG="$tmux_log" \
  bash "$repo_root/config/tmux/bin/update-agent-talk"
grep -Fx "display-message agent-talk: already current" "$tmux_log" >/dev/null

: >"$tmux_log"
if PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$test_root/home" \
  TMUX_UPDATE_TEST_LOG="$tmux_log" \
  TMUX_UPDATE_TEST_OUTPUT="network unavailable" \
  TMUX_UPDATE_TEST_STATUS=23 \
  bash "$repo_root/config/tmux/bin/update-agent-talk"; then
  echo "tmux update helper should propagate agent-talk update failures" >&2
  exit 1
fi
grep -Fx "display-message agent-talk update failed: network unavailable" \
  "$tmux_log" >/dev/null

rm "$fake_bin/agent-talk"
: >"$tmux_log"
PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$test_root/home" \
  TMUX_UPDATE_TEST_LOG="$tmux_log" \
  bash "$repo_root/config/tmux/bin/update-agent-talk"
grep -Fx "display-message agent-talk update skipped: command not found" \
  "$tmux_log" >/dev/null

echo "tmux agent-talk update helper test: pass"

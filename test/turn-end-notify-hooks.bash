#!/usr/bin/env bash
# Contract: every runtime's turn-end hook announces an ordinary completion,
# stays silent for Codex subagent threads and Grok non-completion Stops, and
# fails open to the normal notice on unrecognizable payloads.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_home="$test_root/home"
fake_bin="$test_root/bin"
event_log="$test_root/events.log"
mkdir -p "$fake_home/.codex/sessions" "$fake_home/.claude" \
  "$fake_home/.grok/sessions" "$fake_home/.local/bin" "$fake_bin"
ln -s "$repo_root/agent/codex/hooks/notify-turn-end.sh" \
  "$fake_home/.local/bin/notify-turn-end.sh"
ln -s "$repo_root/agent/claude/hooks" "$fake_home/.claude/hooks"
ln -s "$repo_root/agent/grok/hooks" "$fake_home/.grok/hooks"

cat >"$fake_bin/emitter" <<'EMITTER'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TURN_END_TEST_LOG"
EMITTER
chmod +x "$fake_bin/emitter"

fail() {
  printf 'turn-end notify contract broken: %s\n' "$1" >&2
  printf 'events:\n%s\n' "$(cat "$event_log")" >&2
  exit 1
}

assert_silent() {
  [[ ! -s "$event_log" ]] || fail "$1"
}

assert_event() {
  [[ "$(cat "$event_log")" == "$1" ]] || fail "expected event: $1"
}

run_codex() {
  HOME="$fake_home" CODEX_HOME="$fake_home/.codex" \
    CODEX_NOTIFY_EMITTER="$fake_bin/emitter" TURN_END_TEST_LOG="$event_log" \
    bash "$fake_home/.local/bin/notify-turn-end.sh" "$1"
}

run_claude() {
  HOME="$fake_home" TURN_END_EMITTER="$fake_bin/emitter" \
    TURN_END_TEST_LOG="$event_log" \
    bash "$fake_home/.claude/hooks/stop-turn-end.sh" <<<"$1"
}

run_grok() {
  HOME="$fake_home" TURN_END_EMITTER="$fake_bin/emitter" \
    TURN_END_TEST_LOG="$event_log" \
    bash "$fake_home/.grok/hooks/stop-turn-end.sh" <<<"$1"
}

# Codex: a parent thread announces; a subagent thread stays silent.
: >"$event_log"
run_codex '{"thread-id":"parent-final","last-assistant-message":"delivery complete"}'
assert_event 'codex success'

: >"$event_log"
mkdir -p "$fake_home/.codex/sessions/2026/08/15"
printf '%s\n' \
  '{"type":"session_meta","payload":{"source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent"}}}}}' \
  >"$fake_home/.codex/sessions/2026/08/15/rollout-subagent-thread.jsonl"
run_codex '{"thread-id":"subagent-thread","last-assistant-message":"child complete"}'
assert_silent 'Codex subagent announced completion'

: >"$event_log"
run_codex 'not-json'
assert_event 'codex success'

# Claude: Stop always announces.
: >"$event_log"
run_claude '{"hook_event_name":"Stop","transcript_path":"/nonexistent"}'
assert_event 'claude success'

: >"$event_log"
run_claude 'not-json'
assert_event 'claude success'

# Grok: only end_turn announces; session-end Stops stay silent.
: >"$event_log"
run_grok '{"reason":"end_turn","sessionId":"session-final"}'
assert_event 'grok success'

: >"$event_log"
run_grok 'not-json'
assert_event 'grok success'

: >"$event_log"
run_grok '{"reason":"channel_closed","sessionId":"session-final"}'
assert_silent 'Grok non-completion Stop announced completion'

echo 'turn-end notify hooks contract: ok'

#!/usr/bin/env bash
# Contract: a parent turn that explicitly yields an unfinished delivery must
# not announce workspace completion. Ordinary final turns and unrecognizable
# payloads keep the existing fail-open completion behavior.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_home="$test_root/home"
fake_bin="$test_root/bin"
event_log="$test_root/events.log"
marker='<!-- delivery:waiting -->'
mkdir -p "$fake_home/.codex/sessions" "$fake_home/.claude" \
  "$fake_home/.grok/sessions" "$fake_home/.local/bin" "$fake_bin"
ln -s "$repo_root/agent/codex/hooks/notify-turn-end.sh" \
  "$fake_home/.local/bin/notify-turn-end.sh"
ln -s "$repo_root/agent/claude/hooks" "$fake_home/.claude/hooks"
ln -s "$repo_root/agent/grok/hooks" "$fake_home/.grok/hooks"

for skill in \
  "$repo_root/agent/common/skills/agent-talk/SKILL.md" \
  "$repo_root/agent/common/skills/spike/SKILL.md" \
  "$repo_root/agent/common/skills/polish/SKILL.md"; do
  grep -Fq "$marker" "$skill" || {
    printf 'turn-end wait contract broken: marker missing from %s\n' "$skill" >&2
    exit 1
  }
done

cat >"$fake_bin/emitter" <<'EMITTER'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TURN_END_TEST_LOG"
EMITTER
chmod +x "$fake_bin/emitter"

fail() {
  printf 'turn-end wait contract broken: %s\n' "$1" >&2
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

# Codex carries the completed assistant text directly in its notify payload.
: >"$event_log"
run_codex "{\"thread-id\":\"parent-wait\",\"last-assistant-message\":\"peer reply pending\\n$marker\"}"
assert_silent 'Codex parent wait announced completion'

: >"$event_log"
run_codex "{\"thread-id\":\"parent-final\",\"input-messages\":[\"quoted $marker\"],\"last-assistant-message\":\"delivery complete\"}"
assert_event 'codex success'

: >"$event_log"
run_codex "{\"thread-id\":\"parent-explains-marker\",\"last-assistant-message\":\"The marker $marker is documented.\\ndelivery complete\"}"
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

# Claude Stop carries a transcript path; use both array and string assistant
# content shapes so extraction follows the runtime transcript rather than the
# user prompt in the hook payload.
claude_wait="$test_root/claude-wait.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":"please wait <!-- delivery:waiting -->"}}' \
  "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"peer reply pending\\n$marker\"}]}}" \
  >"$claude_wait"
: >"$event_log"
run_claude "{\"hook_event_name\":\"Stop\",\"transcript_path\":\"$claude_wait\"}"
assert_silent 'Claude parent wait announced completion'

claude_final="$test_root/claude-final.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":"quoted <!-- delivery:waiting -->"}}' \
  '{"type":"assistant","message":{"content":"delivery complete"}}' \
  >"$claude_final"
: >"$event_log"
run_claude "{\"hook_event_name\":\"Stop\",\"transcript_path\":\"$claude_final\"}"
assert_event 'claude success'

: >"$event_log"
run_claude 'not-json'
assert_event 'claude success'

# Grok Stop identifies its chat history by session id.
grok_wait_dir="$fake_home/.grok/sessions/project/session-wait"
mkdir -p "$grok_wait_dir"
printf '%s\n' \
  "{\"role\":\"assistant\",\"content\":\"subagent pending\\n$marker\"}" \
  >"$grok_wait_dir/chat_history.jsonl"
: >"$event_log"
run_grok '{"reason":"end_turn","sessionId":"session-wait"}'
assert_silent 'Grok parent wait announced completion'

grok_final_dir="$fake_home/.grok/sessions/project/session-final"
mkdir -p "$grok_final_dir"
printf '%s\n' \
  '{"role":"user","content":"quoted <!-- delivery:waiting -->"}' \
  '{"type":"assistant","message":"delivery complete"}' \
  >"$grok_final_dir/chat_history.jsonl"
: >"$event_log"
run_grok '{"reason":"end_turn","sessionId":"session-final"}'
assert_event 'grok success'

: >"$event_log"
run_grok 'not-json'
assert_event 'grok success'

: >"$event_log"
run_grok '{"reason":"channel_closed","sessionId":"session-final"}'
assert_silent 'Grok non-completion Stop announced completion'

echo 'turn-end wait notify contract: ok'

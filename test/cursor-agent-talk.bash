#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
event_log="$test_root/events.log"
mkdir -p "$fake_bin" "$fake_home/.local/bin"

cat >"$fake_bin/agent-talk" <<'AGENT_TALK'
#!/usr/bin/env bash
printf 'agent-talk %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
exit 0
AGENT_TALK

cat >"$fake_bin/cursor-agent" <<'CURSOR_AGENT'
#!/usr/bin/env bash
printf 'cursor-agent %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
exit "${CURSOR_AGENT_TALK_TEST_STATUS:-0}"
CURSOR_AGENT

cat >"$fake_bin/codex" <<'CODEX'
#!/usr/bin/env bash
printf 'codex %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
exit "${CURSOR_AGENT_TALK_TEST_STATUS:-0}"
CODEX

chmod +x "$fake_bin/agent-talk" "$fake_bin/cursor-agent" "$fake_bin/codex"
ln -s cursor-agent "$fake_bin/agent"

run_zsh() {
  PATH="$fake_bin:/usr/bin:/bin" \
    CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    CURSOR_AGENT_TALK_TEST_STATUS="${CURSOR_AGENT_TALK_TEST_STATUS:-0}" \
    zsh -f -c 'source "$1"; shift; "$@"' zsh \
    "$repo_root/config/zsh/functions.zsh" "$@"
}

run_zsh cursor-agent "review this"
cat >"$test_root/expected" <<'EXPECTED'
agent-talk register cursor
cursor-agent review this
agent-talk unregister
EXPECTED
cmp "$test_root/expected" "$event_log"

: >"$event_log"
run_zsh codex "preserve wrapper"
grep -Fx 'agent-talk register codex' "$event_log" >/dev/null
grep -Fx 'codex preserve wrapper' "$event_log" >/dev/null
grep -Fx 'agent-talk unregister' "$event_log" >/dev/null

: >"$event_log"
run_zsh agent "review alias"
grep -Fx 'agent-talk register cursor' "$event_log" >/dev/null
grep -Fx 'cursor-agent review alias' "$event_log" >/dev/null
grep -Fx 'agent-talk unregister' "$event_log" >/dev/null

: >"$event_log"
run_zsh cursor-agent --version
grep -Fx 'cursor-agent --version' "$event_log" >/dev/null
if grep -F 'agent-talk ' "$event_log" >/dev/null; then
  echo "non-interactive cursor command must not register" >&2
  exit 1
fi

: >"$event_log"
if CURSOR_AGENT_TALK_TEST_STATUS=23 run_zsh cursor-agent "failing turn"; then
  echo "cursor wrapper must preserve a failing CLI status" >&2
  exit 1
fi
grep -Fx 'agent-talk unregister' "$event_log" >/dev/null

rm "$fake_bin/agent"
cat >"$fake_bin/agent" <<'OTHER_AGENT'
#!/usr/bin/env bash
printf 'other-agent %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
OTHER_AGENT
chmod +x "$fake_bin/agent"
: >"$event_log"
run_zsh agent "unrelated command"
grep -Fx 'other-agent unrelated command' "$event_log" >/dev/null
if grep -F 'agent-talk ' "$event_log" >/dev/null; then
  echo "unrelated agent command must not register as cursor" >&2
  exit 1
fi

cat >"$fake_home/.local/bin/agent-talk" <<'FAILING_AGENT_TALK'
#!/usr/bin/env bash
exit 42
FAILING_AGENT_TALK
chmod +x "$fake_home/.local/bin/agent-talk"
HOME="$fake_home" bash "$repo_root/agent/cursor/hooks/agent-talk-busy.sh"

: >"$event_log"
cat >"$fake_home/.local/bin/agent-talk" <<'LOGGING_AGENT_TALK'
#!/usr/bin/env bash
printf 'agent-talk %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
LOGGING_AGENT_TALK
chmod +x "$fake_home/.local/bin/agent-talk"
printf '%s\n' '{"hook_event_name":"sessionStart","cursor_version":"2026.07"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/register-agent-talk.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"SessionStart","session_id":"test"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/register-agent-talk.sh"
grep -Fx 'agent-talk register claude' "$event_log" >/dev/null

: >"$event_log"
printf '%s\n' '{"hook_event_name":"beforeSubmitPrompt","cursor_version":"2026.07"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/agent-talk-busy.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"UserPromptSubmit","session_id":"test"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/agent-talk-busy.sh"
grep -Fx 'agent-talk busy' "$event_log" >/dev/null

: >"$event_log"
printf '%s\n' '{"hook_event_name":"sessionEnd","cursor_version":"2026.07"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/unregister-agent-talk.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"SessionEnd","session_id":"test"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/unregister-agent-talk.sh"
grep -Fx 'agent-talk unregister' "$event_log" >/dev/null

cat >"$fake_bin/turn-end-emitter" <<'TURN_END_EMITTER'
#!/usr/bin/env bash
printf 'turn-end %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
TURN_END_EMITTER
chmod +x "$fake_bin/turn-end-emitter"
: >"$event_log"
printf '%s\n' '{"hook_event_name":"stop","cursor_version":"2026.07"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    TURN_END_EMITTER="$fake_bin/turn-end-emitter" \
    bash "$repo_root/agent/claude/hooks/stop-turn-end.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"Stop","session_id":"test"}' \
  | HOME="$fake_home" CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    TURN_END_EMITTER="$fake_bin/turn-end-emitter" \
    bash "$repo_root/agent/claude/hooks/stop-turn-end.sh"
grep -Fx 'turn-end claude success' "$event_log" >/dev/null

jq -e '.hooks.beforeSubmitPrompt[0].command == "./hooks/agent-talk-busy.sh"' \
  "$repo_root/agent/cursor/hooks.json" >/dev/null
jq -e '.hooks.stop[0].command == "./hooks/stop-turn-end.sh"' \
  "$repo_root/agent/cursor/hooks.json" >/dev/null
jq -e '.hooks.UserPromptSubmit[0].hooks[0].command | endswith("agent-talk-busy.sh")' \
  "$repo_root/agent/claude/settings.json" >/dev/null
jq -e '.hooks.SessionEnd[0].hooks[0].command | endswith("unregister-agent-talk.sh")' \
  "$repo_root/agent/claude/settings.json" >/dev/null
grep -Fq "set -g @agent_talkd_skill_syntax 'cursor=slash'" \
  "$repo_root/config/tmux/tmux.conf"

echo "cursor agent-talk integration test: pass"

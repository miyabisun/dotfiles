#!/usr/bin/env bash
# Contract: Claude 互換 lifecycle hooks の現役挙動。
# - Cursor payload (`cursor_version`) は Claude hooks が無視する
# - 純 Claude payload では register / busy / unregister / turn-end が動く
# - Cursor hooks.json / Claude settings.json の wiring が正しい
# - broker 障害時に busy hook が安全に劣化する
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
event_log="$test_root/events.log"
# broker は systemd 管理サービスの release layout 側に居る (~/.local/bin は旧 layout)
broker_dir="$fake_home/.local/share/agent-talk/current"
mkdir -p "$fake_bin" "$broker_dir"

# broker 障害時: busy hook は失敗を握りつぶして成功しなければならない。
cat >"$broker_dir/agent-talk" <<'FAILING_AGENT_TALK'
#!/usr/bin/env bash
exit 42
FAILING_AGENT_TALK
chmod +x "$broker_dir/agent-talk"
HOME="$fake_home" bash "$repo_root/agent/cursor/hooks/agent-talk-busy.sh"

cat >"$broker_dir/agent-talk" <<'LOGGING_AGENT_TALK'
#!/usr/bin/env bash
printf 'agent-talk %s\n' "$*" >>"$LIFECYCLE_TEST_LOG"
LOGGING_AGENT_TALK
chmod +x "$broker_dir/agent-talk"

# Cursor busy hook (healthy broker): busy が実際に broker へ届く。
: >"$event_log"
HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
  bash "$repo_root/agent/cursor/hooks/agent-talk-busy.sh"
grep -Fx 'agent-talk busy' "$event_log" >/dev/null

# Cursor stop hook: 完了を emit-turn-end.sh へ cursor success として渡す。
mkdir -p "$fake_home/.local/bin"
cat >"$fake_home/.local/bin/emit-turn-end.sh" <<'FAKE_EMITTER'
#!/usr/bin/env bash
printf 'turn-end %s\n' "$*" >>"$LIFECYCLE_TEST_LOG"
FAKE_EMITTER
chmod +x "$fake_home/.local/bin/emit-turn-end.sh"
: >"$event_log"
HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
  bash "$repo_root/agent/cursor/hooks/stop-turn-end.sh"
grep -Fx 'turn-end cursor success' "$event_log" >/dev/null

# Cursor payload は Claude 互換 hooks に無視され、純 Claude payload は動く。
: >"$event_log"
printf '%s\n' '{"hook_event_name":"sessionStart","cursor_version":"2026.07"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/register-agent-talk.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"SessionStart","session_id":"test"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/register-agent-talk.sh"
grep -Fx 'agent-talk register claude' "$event_log" >/dev/null

: >"$event_log"
printf '%s\n' '{"hook_event_name":"beforeSubmitPrompt","cursor_version":"2026.07"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/agent-talk-busy.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"UserPromptSubmit","session_id":"test"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/agent-talk-busy.sh"
grep -Fx 'agent-talk busy' "$event_log" >/dev/null

: >"$event_log"
printf '%s\n' '{"hook_event_name":"sessionEnd","cursor_version":"2026.07"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/unregister-agent-talk.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"SessionEnd","session_id":"test"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/claude/hooks/unregister-agent-talk.sh"
grep -Fx 'agent-talk unregister' "$event_log" >/dev/null

cat >"$fake_bin/turn-end-emitter" <<'TURN_END_EMITTER'
#!/usr/bin/env bash
printf 'turn-end %s\n' "$*" >>"$LIFECYCLE_TEST_LOG"
TURN_END_EMITTER
chmod +x "$fake_bin/turn-end-emitter"
: >"$event_log"
printf '%s\n' '{"hook_event_name":"stop","cursor_version":"2026.07"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    TURN_END_EMITTER="$fake_bin/turn-end-emitter" \
    bash "$repo_root/agent/claude/hooks/stop-turn-end.sh"
test ! -s "$event_log"
printf '%s\n' '{"hook_event_name":"Stop","session_id":"test"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    TURN_END_EMITTER="$fake_bin/turn-end-emitter" \
    bash "$repo_root/agent/claude/hooks/stop-turn-end.sh"
grep -Fx 'turn-end claude success' "$event_log" >/dev/null

# 配線: Cursor hooks.json と Claude settings.json が hooks を指していること。
jq -e '.hooks.beforeSubmitPrompt[0].command == "./hooks/agent-talk-busy.sh"' \
  "$repo_root/agent/cursor/hooks.json" >/dev/null
jq -e '.hooks.stop[0].command == "./hooks/stop-turn-end.sh"' \
  "$repo_root/agent/cursor/hooks.json" >/dev/null
jq -e '.hooks.UserPromptSubmit[0].hooks[0].command | endswith("agent-talk-busy.sh")' \
  "$repo_root/agent/claude/settings.json" >/dev/null
jq -e '.hooks.SessionEnd[0].hooks[0].command | endswith("unregister-agent-talk.sh")' \
  "$repo_root/agent/claude/settings.json" >/dev/null

echo "agent lifecycle hooks test: pass"

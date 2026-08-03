#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
event_log="$test_root/events.log"
# broker は systemd 管理サービスの release layout 側に居る。PATH には載らないので
# wrapper は絶対パスで呼ぶ。fixture も同じ場所に置く (~/.local/bin は旧 layout)
broker_dir="$fake_home/.local/share/agent-talk/current"
mkdir -p "$fake_bin" "$fake_home/.local/bin" "$broker_dir"

cat >"$broker_dir/agent-talk" <<'AGENT_TALK'
#!/usr/bin/env bash
printf 'agent-talk argc=%s' "$#" >>"$CURSOR_AGENT_TALK_TEST_LOG"
printf ' <%s>' "$@" >>"$CURSOR_AGENT_TALK_TEST_LOG"
printf '\n' >>"$CURSOR_AGENT_TALK_TEST_LOG"
if [[ "${1:-}" == run ]]; then
  shift 2
  exec "$@"
fi
exit 0
AGENT_TALK

cat >"$fake_bin/cursor-agent" <<'CURSOR_AGENT'
#!/usr/bin/env bash
printf 'cursor-agent argc=%s' "$#" >>"$CURSOR_AGENT_TALK_TEST_LOG"
printf ' <%s>' "$@" >>"$CURSOR_AGENT_TALK_TEST_LOG"
printf '\n' >>"$CURSOR_AGENT_TALK_TEST_LOG"
exit "${CURSOR_AGENT_TALK_TEST_STATUS:-0}"
CURSOR_AGENT

cat >"$fake_bin/codex" <<'CODEX'
#!/usr/bin/env bash
printf 'codex argc=%s' "$#" >>"$CURSOR_AGENT_TALK_TEST_LOG"
printf ' <%s>' "$@" >>"$CURSOR_AGENT_TALK_TEST_LOG"
printf '\n' >>"$CURSOR_AGENT_TALK_TEST_LOG"
exit "${CURSOR_AGENT_TALK_TEST_STATUS:-0}"
CODEX

chmod +x "$broker_dir/agent-talk" "$fake_bin/cursor-agent" "$fake_bin/codex"
ln -s cursor-agent "$fake_bin/agent"

run_zsh() {
  PATH="$fake_bin:/usr/bin:/bin" \
    HOME="$fake_home" \
    CURSOR_AGENT_TALK_TEST_LOG="$event_log" \
    CURSOR_AGENT_TALK_TEST_STATUS="${CURSOR_AGENT_TALK_TEST_STATUS:-0}" \
    zsh -f -c 'source "$1"; shift; "$@"' zsh \
    "$repo_root/config/zsh/functions.zsh" "$@"
}

run_zsh cursor-agent "review this"
cat >"$test_root/expected" <<'EXPECTED'
agent-talk argc=4 <run> <cursor> <cursor-agent> <review this>
cursor-agent argc=1 <review this>
EXPECTED
cmp "$test_root/expected" "$event_log"

: >"$event_log"
run_zsh codet "preserve wrapper"
cat >"$test_root/expected" <<'EXPECTED'
agent-talk argc=4 <run> <codex> <codex> <preserve wrapper>
codex argc=1 <preserve wrapper>
EXPECTED
cmp "$test_root/expected" "$event_log"

: >"$event_log"
run_zsh agent "review alias"
cat >"$test_root/expected" <<'EXPECTED'
agent-talk argc=4 <run> <cursor> <agent> <review alias>
cursor-agent argc=1 <review alias>
EXPECTED
cmp "$test_root/expected" "$event_log"

: >"$event_log"
run_zsh cursor-agent --version
grep -Fx 'cursor-agent argc=1 <--version>' "$event_log" >/dev/null
if grep -F 'agent-talk ' "$event_log" >/dev/null; then
  echo "non-interactive cursor command must not register" >&2
  exit 1
fi

: >"$event_log"
set +e
CURSOR_AGENT_TALK_TEST_STATUS=23 run_zsh codet "failing turn"
status=$?
set -e
if [[ "$status" -ne 23 ]]; then
  echo "codet wrapper must preserve status 23, got $status" >&2
  exit 1
fi

mv "$broker_dir/agent-talk" "$test_root/agent-talk"
: >"$event_log"
if run_zsh codet "missing broker" 2>"$test_root/missing-agent-talk.err"; then
  echo "codet wrapper must fail when agent-talk is unavailable" >&2
  exit 1
fi
test ! -s "$event_log"

# broker が居なくても素の codex は使えなければならない — user が求めたのは
# 「ラッピングコードに邪魔されずに codex を起動できること」そのもの
: >"$event_log"
run_zsh codex "unwrapped while broker is gone"
grep -Fx 'codex argc=1 <unwrapped while broker is gone>' "$event_log" >/dev/null
if grep -F 'agent-talk ' "$event_log" >/dev/null; then
  echo "plain codex must not emit agent-talk events" >&2
  exit 1
fi

mv "$test_root/agent-talk" "$broker_dir/agent-talk"

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

cat >"$broker_dir/agent-talk" <<'FAILING_AGENT_TALK'
#!/usr/bin/env bash
exit 42
FAILING_AGENT_TALK
chmod +x "$broker_dir/agent-talk"
HOME="$fake_home" bash "$repo_root/agent/cursor/hooks/agent-talk-busy.sh"

: >"$event_log"
cat >"$broker_dir/agent-talk" <<'LOGGING_AGENT_TALK'
#!/usr/bin/env bash
printf 'agent-talk %s\n' "$*" >>"$CURSOR_AGENT_TALK_TEST_LOG"
LOGGING_AGENT_TALK
chmod +x "$broker_dir/agent-talk"
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

#!/usr/bin/env bash
# Contract: lifecycle hooks は agent-talk の状態を push しない。
# daemon が herdr snapshot を live truth とするため register / unregister / busy /
# turn-end は配線も script も持たず、一般通知と herdr state hook だけを残す。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
event_log="$test_root/events.log"
mkdir -p "$fake_bin" "$fake_home"

# Grok stop hook: 完了を emit-turn-end.sh へ grok success として渡す。
mkdir -p "$fake_home/.local/bin"
cat >"$fake_home/.local/bin/emit-turn-end.sh" <<'FAKE_EMITTER'
#!/usr/bin/env bash
printf 'turn-end %s\n' "$*" >>"$LIFECYCLE_TEST_LOG"
FAKE_EMITTER
chmod +x "$fake_home/.local/bin/emit-turn-end.sh"
: >"$event_log"
printf '%s\n' '{"reason":"end_turn"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    bash "$repo_root/agent/grok/hooks/stop-turn-end.sh"
grep -Fx 'turn-end grok success' "$event_log" >/dev/null

cat >"$fake_bin/turn-end-emitter" <<'TURN_END_EMITTER'
#!/usr/bin/env bash
printf 'turn-end %s\n' "$*" >>"$LIFECYCLE_TEST_LOG"
TURN_END_EMITTER
chmod +x "$fake_bin/turn-end-emitter"
: >"$event_log"
printf '%s\n' '{"hook_event_name":"Stop","session_id":"test"}' \
  | HOME="$fake_home" LIFECYCLE_TEST_LOG="$event_log" \
    TURN_END_EMITTER="$fake_bin/turn-end-emitter" \
    bash "$repo_root/agent/claude/hooks/stop-turn-end.sh"
grep -Fx 'turn-end claude success' "$event_log" >/dev/null

# herdr-agent-state hooks: $HOME 展開形の exact 契約。user-home 固定へ戻ると
# portable-paths guard が拾うが、コマンド自体の消失・誤パス化はここで拾う。
jq -e '.hooks.SessionStart[0].hooks[0].command == "bash \"$HOME/.claude/hooks/herdr-agent-state.sh\" session"' \
  "$repo_root/agent/claude/settings.json" >/dev/null
jq -e '.hooks.SessionStart[0].hooks[0].command == "bash \"$HOME/.codex/herdr-agent-state.sh\" session"' \
  "$repo_root/agent/codex/hooks.json" >/dev/null

# 空白入り HOME でも $HOME 展開形の command が実体へ届くこと (sh -c 実行)。
space_home="$test_root/space home"
state_log="$test_root/herdr-state.log"
for state_dir in .claude/hooks .codex; do
  mkdir -p "$space_home/$state_dir"
  cat >"$space_home/$state_dir/herdr-agent-state.sh" <<'STATE'
#!/usr/bin/env bash
printf 'herdr-state %s %s\n' "$0" "$*" >>"$HERDR_STATE_TEST_LOG"
STATE
  chmod +x "$space_home/$state_dir/herdr-agent-state.sh"
done
: >"$state_log"
for hook_json in \
  "$repo_root/agent/claude/settings.json" \
  "$repo_root/agent/codex/hooks.json"; do
  cmd="$(jq -r '.. | .command? // empty' "$hook_json" | grep -F 'herdr-agent-state')"
  HOME="$space_home" HERDR_STATE_TEST_LOG="$state_log" sh -c "$cmd"
done
test "$(grep -c 'herdr-state .* session$' "$state_log")" -eq 2

# 一般の完了通知は残し、agent-talk lifecycle push は全 runtime から消す。
# command は legacy root 直参照ではなく installer が張る安定リンク経由。
jq -e '.hooks.Stop[0].hooks[0].command == "bash \"$HOME/.claude/hooks/stop-turn-end.sh\""' \
  "$repo_root/agent/claude/settings.json" >/dev/null
jq -e '.hooks.Stop[0].hooks[0].command == "./stop-turn-end.sh"' \
  "$repo_root/agent/grok/hooks/lifecycle.json" >/dev/null

for hook_json in \
  "$repo_root/agent/claude/settings.json" \
  "$repo_root/agent/codex/hooks.json" \
  "$repo_root/agent/grok/hooks/lifecycle.json"; do
  if jq -e '.. | strings | select(test("agent-talk.*(register|unregister|busy|turn-end)|register-agent-talk|unregister-agent-talk|agent-talk-busy"))' \
    "$hook_json" >/dev/null; then
    echo "retired agent-talk lifecycle hook remains wired: $hook_json" >&2
    exit 1
  fi
done

for retired_hook in \
  agent/claude/hooks/register-agent-talk.sh \
  agent/claude/hooks/unregister-agent-talk.sh \
  agent/claude/hooks/agent-talk-busy.sh \
  agent/cursor/hooks/agent-talk-busy.sh \
  agent/grok/hooks/register-agent-talk.sh \
  agent/grok/hooks/unregister-agent-talk.sh \
  agent/grok/hooks/agent-talk-busy.sh; do
  test ! -e "$repo_root/$retired_hook" || {
    echo "retired agent-talk lifecycle script remains: $retired_hook" >&2
    exit 1
  }
done

echo "agent lifecycle hooks test: pass"

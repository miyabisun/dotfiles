#!/usr/bin/env bash
# Contract: agent CLI は zsh 関数に shadow されない。agent-talk lifecycle は
# daemon の herdr pull sync が担い、shell 層は broker を呼ばない。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
functions_zsh="$repo_root/config/zsh/functions.zsh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
event_log="$test_root/events.log"
broker_dir="$fake_home/.local/share/agent-talk/current"
mkdir -p "$fake_bin" "$broker_dir"

cat >"$broker_dir/agent-talk" <<'AGENT_TALK'
#!/usr/bin/env bash
printf 'agent-talk %s\n' "$*" >>"$WRAPPER_TEST_LOG"
AGENT_TALK
chmod +x "$broker_dir/agent-talk"

for cli in codex claude cursor-agent agent; do
  cat >"$fake_bin/$cli" <<CLI
#!/usr/bin/env bash
printf '%s argc=%s' "$cli" "\$#" >>"\$WRAPPER_TEST_LOG"
printf ' <%s>' "\$@" >>"\$WRAPPER_TEST_LOG"
printf '\n' >>"\$WRAPPER_TEST_LOG"
exit "\${WRAPPER_TEST_STATUS:-0}"
CLI
  chmod +x "$fake_bin/$cli"
done

run_zsh() {
  PATH="$fake_bin:/usr/bin:/bin" \
    HOME="$fake_home" \
    WRAPPER_TEST_LOG="$event_log" \
    WRAPPER_TEST_STATUS="${WRAPPER_TEST_STATUS:-0}" \
    zsh -f -c 'source "$1"; shift; "$@"' zsh "$functions_zsh" "$@"
}

# 主契約: source 後も4 CLI すべてが関数ではなく command のままであること。
for cli in codex claude cursor-agent agent; do
  kind="$(PATH="$fake_bin:/usr/bin:/bin" HOME="$fake_home" \
    zsh -f -c 'source "$1"; whence -w "$2"' zsh "$functions_zsh" "$cli")"
  if [[ "$kind" != "$cli: command" ]]; then
    echo "$cli must stay an unshadowed command, got: $kind" >&2
    exit 1
  fi
done

# 引数と非0終了値が実体までそのまま届くこと。
: >"$event_log"
set +e
WRAPPER_TEST_STATUS=23 run_zsh codex "plain run"
status=$?
set -e
if [[ "$status" -ne 23 ]]; then
  echo "plain codex must preserve exit status 23, got $status" >&2
  exit 1
fi
grep -Fx 'codex argc=1 <plain run>' "$event_log" >/dev/null

: >"$event_log"
run_zsh cursor-agent "review this"
grep -Fx 'cursor-agent argc=1 <review this>' "$event_log" >/dev/null

# shell 層から broker が呼ばれないこと。
if grep -F 'agent-talk' "$event_log" >/dev/null; then
  echo 'plain agent CLIs must not touch the broker' >&2
  exit 1
fi

# 負契約 (補助): 退役した wrapper 資材の文字列が復活していないこと。
for retired in codet _agent_talk_run _codex_is_interactive \
  _claude_is_interactive CLAUDE_AGENT_TALK_SKIP agent-talk; do
  if grep -Fq "$retired" "$functions_zsh"; then
    echo "functions.zsh still carries retired wrapper material: $retired" >&2
    exit 1
  fi
done

# 汎用関数は残り、source 可能なままであること。
zsh -f -c 'source "$1"; whence -w copy mfa a >/dev/null' zsh "$functions_zsh"

echo 'agent wrapper removal test: pass'

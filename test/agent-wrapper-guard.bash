#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
functions_zsh="$repo_root/config/zsh/functions.zsh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

stub="$test_root/bin"
talk_log="$test_root/agent-talk.log"
cli_log="$test_root/cli.log"
# broker は systemd 管理サービスの release layout 側 (~/.local/bin は旧 layout)。
# PATH には載らないので、wrapper も hooks も絶対パスで呼ぶ
broker_dir="$test_root/.local/share/agent-talk/current"
mkdir -p "$stub" "$broker_dir"

cat >"$broker_dir/agent-talk" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$talk_log"
STUB
for name in codex claude; do
  cat >"$stub/$name" <<STUB
#!/usr/bin/env bash
printf '$name skip=%s args=%s\n' "\${CLAUDE_AGENT_TALK_SKIP:-}" "\$*" >>"$cli_log"
STUB
done
chmod +x "$broker_dir"/agent-talk "$stub"/codex "$stub"/claude

run_wrapped() {
  : >"$talk_log"; : >"$cli_log"
  PATH="$stub:/usr/bin:/bin" HOME="$test_root" \
    zsh -f -c "source '$functions_zsh'; $1" 2>/dev/null || true
}

# 素の `codex` は shadow されない — これが今回の主 acceptance。
# wrapper が同名を占有していると herdr で素の起動が邪魔される
# function だけでなく alias / autoload も弾くため、種別を完全一致で見る
codex_kind="$(PATH="$stub:/usr/bin:/bin" HOME="$test_root" \
  zsh -f -c "source '$functions_zsh'; whence -w codex" 2>/dev/null)"
if [ "$codex_kind" != 'codex: command' ]; then
  echo "plain codex must resolve to the native command, got: ${codex_kind:-<none>}" >&2
  exit 1
fi

# 素の codex は broker を一切通さず実体へ届く (bare / prompt とも)
for cmd in 'codex' 'codex do the thing'; do
  run_wrapped "$cmd"
  if [ -s "$talk_log" ]; then
    echo "plain codex must not touch agent-talk: $cmd" >&2
    exit 1
  fi
  grep -q '^codex ' "$cli_log" \
    || { echo "plain codex must reach the real executable: $cmd" >&2; exit 1; }
done

# codet: 管理・headless command は登録 wrapper を通らない (pane 登録を守る)
for cmd in 'codet mcp list' 'codet review fix it' 'codet plugin list' \
  'codet update' 'codet doctor' 'codet archive x' 'codet exec task' \
  'codet mcp-server' 'codet --version' \
  'codet --strict-config doctor' 'codet -c key=value mcp list' \
  'codet --cd /tmp update' 'codet --oss mcp list' 'codet --search review x' \
  'codet --local-provider ollama mcp list' 'codet --enable foo doctor' \
  'codet -a never update' 'codet --add-dir /tmp plugin list'; do
  run_wrapped "$cmd"
  if [ -s "$talk_log" ]; then
    echo "non-interactive codet must bypass agent-talk run: $cmd" >&2
    exit 1
  fi
  grep -q '^codex ' "$cli_log" || { echo "codet passthrough missing: $cmd" >&2; exit 1; }
done

# codet: 対話起動 (bare / prompt / resume / fork) は従来どおり登録 wrapper 経由。
# 登録 pane 名も実行 executable も codex のままで、変わるのは入口だけ
for cmd in 'codet' 'codet resume' 'codet fork' 'codet do the thing' \
  'codet -- mcp' 'codet -- --help' 'codet -- -V'; do
  run_wrapped "$cmd"
  grep -q '^run codex codex' "$talk_log" \
    || { echo "interactive codet must go through agent-talk run: $cmd" >&2; exit 1; }
done

# claude: 管理・headless command は skip 変数つきで実行される (hooks が登録を触らない)
for cmd in 'claude mcp list' 'claude plugins list' 'claude gateway' \
  'claude project' 'claude update' 'claude -p query' \
  'claude --debug mcp list' 'claude --settings /tmp/s.json doctor' \
  'claude --effort high mcp list' 'claude --fallback-model m doctor' \
  'claude -n title update' 'claude --json-schema s.json project' \
  'claude --debug api mcp list' 'claude -d api doctor'; do
  run_wrapped "$cmd"
  grep -q '^claude skip=1 ' "$cli_log" \
    || { echo "non-interactive claude must set CLAUDE_AGENT_TALK_SKIP: $cmd" >&2; exit 1; }
done

# claude: 対話起動は skip 変数なし (hooks が通常どおり登録する)。
# -- 以降はサブコマンド名ではなく prompt なので対話扱いになる
for cmd in 'claude' 'claude -- mcp' 'claude -- -p' 'claude -- --version'; do
  run_wrapped "$cmd"
  grep -q '^claude skip= ' "$cli_log" \
    || { echo "interactive claude must not set the skip variable: $cmd" >&2; exit 1; }
done

# hooks: broker stub は skip テストより前に置く。後置すると skip guard を外しても
# 「broker 不在で何も記録されない」だけで PASS してしまい偽陽性になる
: "$broker_dir/agent-talk"  # hooks は既にこの実体を見る

# skip なしなら従来どおり register/unregister を実行する (stub が呼ばれる証拠)
for pair in 'register-agent-talk.sh:register claude' 'unregister-agent-talk.sh:unregister'; do
  hook="${pair%%:*}"
  expected="${pair#*:}"
  : >"$talk_log"
  HOME="$test_root" PATH="$stub:/usr/bin:/bin" \
    bash "$repo_root/agent/claude/hooks/$hook" </dev/null
  grep -qx "$expected" "$talk_log" \
    || { echo "$hook must call the broker without skip" >&2; exit 1; }
done

# skip 変数が立っていれば broker を一切触らない
for hook in register-agent-talk.sh unregister-agent-talk.sh; do
  : >"$talk_log"
  CLAUDE_AGENT_TALK_SKIP=1 HOME="$test_root" \
    PATH="$stub:/usr/bin:/bin" bash "$repo_root/agent/claude/hooks/$hook" </dev/null
  if [ -s "$talk_log" ]; then
    echo "$hook must not touch the broker when skip is set" >&2
    exit 1
  fi
done

echo "agent wrapper guard test: pass"

#!/usr/bin/env bash
# emit-turn-end.sh の MOCA 通知契約 (workspace 静穏ゲート):
# 同じ herdr workspace に working/blocked/unknown の他 agent が残っている間は
# 成功完了を通知しない。全員 done/idle (または単独) になった完了だけが鳴る。
# 確認待ち・許可待ち・異常終了は静穏と無関係に通知する。agent-talk の状態は
# daemon が herdr から pull するため broker lifecycle command は呼ばない。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/agent/common/bin/emit-turn-end.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

log="$test_root/log"
agents_json="$test_root/herdr-agents.json"
workspaces_json="$test_root/herdr-workspaces.json"
: >"$log"
mkdir -p "$test_root/bin" "$test_root/home"

cat >"$test_root/bin/curl" <<EOF
#!/bin/bash
echo "CURL \$*" >>"$log"
EOF
cat >"$test_root/bin/herdr" <<EOF
#!/bin/bash
echo "HERDR \$*" >>"$log"
case "\$1 \$2" in
  "agent list")
    [[ -f "$agents_json" ]] || exit 1
    cat "$agents_json"
    ;;
  "workspace list")
    [[ -f "$workspaces_json" ]] || exit 1
    cat "$workspaces_json"
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$test_root/bin/curl" "$test_root/bin/herdr"

# スクリプトは自身の隣にある runtime pin を読むため、コピーして隔離する。
cp "$script" "$test_root/bin/emit-turn-end.sh"
cat >"$test_root/bin/.dotfiles-agent-runtime" <<EOF
CURL_BIN=$test_root/bin/curl
HERDR_BIN=$test_root/bin/herdr
JQ_BIN=/usr/bin/jq
SHA256_BIN=/usr/bin/sha256sum
SHA256_MODE=sha256sum
CP_BIN=/usr/bin/cp
RM_BIN=/usr/bin/rm
STAT_BIN=/usr/bin/stat
STAT_MODE=gnu
EOF

fail() {
  printf 'emit-turn-end notify contract broken: %s\n' "$1" >&2
  printf 'log:\n%s\n' "$(cat "$log")" >&2
  exit 1
}

# 自分は w9:p1。他 agent の状態は各ケースが $agents_json で与える。
peers() {
  local rows="" row
  for row in "$@"; do
    rows="$rows{\"pane_id\":\"${row%%=*}\",\"workspace_id\":\"${row%%:*}\",\"agent\":\"peer\",\"agent_status\":\"${row##*=}\"},"
  done
  printf '{"result":{"agents":[%s{"pane_id":"w9:p1","workspace_id":"w9","agent":"claude","agent_status":"done"}]}}' \
    "$rows" >"$agents_json"
}

run_as() {
  local pane="$1" ws="$2"
  shift 2
  (cd "$test_root" && env -i HOME="$test_root/home" PATH=/usr/bin:/bin \
    MOCA_URL=http://moca.test \
    HERDR_PANE_ID="$pane" HERDR_WORKSPACE_ID="$ws" \
    bash "$test_root/bin/emit-turn-end.sh" "$@" >/dev/null 2>&1) || true
}

run() {
  run_as w9:p1 w9 "$@"
}

# success 通知の主語になる workspace label (user が見る session 名)。
cat >"$workspaces_json" <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w9","label":"settings"},
  {"workspace_id":"workspace-settings","label":"opaque-session"}
]}}
JSON

# 同 workspace に working が居る: 成功完了は通知しない。
# 通知しないなら label 照会もしない。
peers "w9:p2=working"
: >"$log"
run claude success
grep -q "CURL" "$log" && fail "他 agent working 中の完了が通知された"
grep -q "BROKER" "$log" && fail "broker lifecycle command が呼ばれた"
grep -q "HERDR workspace list" "$log" && fail "抑止時に workspace list を照会した"

# blocked / unknown も静穏ではない。
peers "w9:p2=blocked"
: >"$log"
run claude success
grep -q "CURL" "$log" && fail "他 agent blocked 中の完了が通知された"

peers "w9:p2=unknown"
: >"$log"
run claude success
grep -q "CURL" "$log" && fail "他 agent unknown 中の完了が通知された"

# 全員 done/idle: workspace label を主語に通知する。
# 呼び鈴起点の旧 talk 引数が来ても同じ (静穏が唯一の門)。
peers "w9:p2=done" "w9:p3=idle"
: >"$log"
run claude success
grep -q "CURL.*settingsが完了しました" "$log" || fail "label 主語の完了通知が消えた"
grep -q "BROKER" "$log" && fail "broker lifecycle command が呼ばれた"

: >"$log"
run claude success talk
grep -q "CURL.*settingsが完了しました" "$log" || fail "旧 talk 引数が通知を壊した"

# 他 workspace の working は無関係。単独 workspace は完了扱い。
peers "w8:p2=working"
: >"$log"
run claude success
grep -q "CURL.*settingsが完了しました" "$log" || fail "他 workspace の working に引きずられた"

peers
: >"$log"
run claude success
grep -q "CURL.*settingsが完了しました" "$log" || fail "単独 workspace の完了通知が消えた"

# self 除外: hook 実行中の自分は herdr から working と観測され得る。
# 自分を数えると最終通知が永久に抑止されるため、self 行は必ず除外する。
# ID は opaque な値を使い、pane id の文字列分割への退行もここで塞ぐ。
cat >"$agents_json" <<'JSON'
{"result":{"agents":[
  {"pane_id":"opaque-self","workspace_id":"workspace-settings","agent":"claude","agent_status":"working"},
  {"pane_id":"opaque-peer","workspace_id":"workspace-settings","agent":"codex","agent_status":"done"}
]}}
JSON
: >"$log"
run_as opaque-self workspace-settings claude success
grep -q "CURL.*opaque-sessionが完了しました" "$log" || fail "working 中の self が除外されていない"

# 判定不能は fail-open: herdr agent list 失敗でも通知は失われない
# (label 解決は独立に生きているので主語は label のまま)。
rm -f "$agents_json"
: >"$log"
run claude success
grep -q "CURL.*settingsが完了しました" "$log" || fail "herdr 失敗時に fail-open しなかった"

# jq が読めない出力 (malformed JSON) も判定不能 → fail-open。
printf 'not json at all' >"$agents_json"
: >"$log"
run claude success
grep -q "CURL.*settingsが完了しました" "$log" || fail "malformed JSON で fail-open しなかった"
grep -q "BROKER" "$log" && fail "broker lifecycle command が呼ばれた"

# 名前解決の失敗は通知の消失に波及しない: label 無し → workspace id へ、
# workspace list 失敗・malformed → id へ、id も無ければ cwd basename へ。
peers "w9:p2=done"
printf '{"result":{"workspaces":[{"workspace_id":"w9","label":null}]}}' >"$workspaces_json"
: >"$log"
run claude success
grep -q "CURL.*w9が完了しました" "$log" || fail "label 無しで id へ fallback しなかった"

rm -f "$workspaces_json"
: >"$log"
run claude success
grep -q "CURL.*w9が完了しました" "$log" || fail "workspace list 失敗で id へ fallback しなかった"

printf 'broken' >"$workspaces_json"
: >"$log"
run claude success
grep -q "CURL.*w9が完了しました" "$log" || fail "malformed workspaces で id へ fallback しなかった"

# HERDR env 自体が無い環境: 静穏判定も id fallback も不能 → cwd basename 主語。
peers "w9:p2=working"
mkdir -p "$test_root/no-env-proj"
: >"$log"
(cd "$test_root/no-env-proj" && env -i HOME="$test_root/home" PATH=/usr/bin:/bin \
  MOCA_URL=http://moca.test \
  bash "$test_root/bin/emit-turn-end.sh" claude success >/dev/null 2>&1) || true
grep -q "CURL.*no-env-projが完了しました" "$log" || fail "env 欠落時に fail-open しなかった"

# 人間の対応が要る状態は、他 agent が working でも即時通知する。
peers "w9:p2=working"
: >"$log"
run claude waiting
grep -q "CURL.*claudeが確認を求めています" "$log" || fail "waiting の通知が消えた"

: >"$log"
run claude permission
grep -q "CURL.*でファイル操作の許可が必要です" "$log" || fail "permission の通知が消えた"

: >"$log"
run claude failed
grep -q "CURL.*claudeがfailedで終了しました" "$log" || fail "異常終了の通知が消えた"

echo "emit-turn-end notify contract: ok"

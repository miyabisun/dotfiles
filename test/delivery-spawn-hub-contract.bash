#!/usr/bin/env bash
# spike / polish: spawn children for mutation/CLI/facts; parent hubs the
# review tab.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
global="$repo_root/agent/common/rules/GLOBAL.md"
talk="$repo_root/agent/common/skills/agent-talk/SKILL.md"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

assert_absent() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'retired contract still present in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

for skill in "$spike" "$polish"; do
  assert_contains "$skill" '毎回 agent を作成する'
  assert_contains "$skill" 'ファイル変更'
  assert_contains "$skill" 'CLI 待ちとログ読み'
  assert_contains "$skill" '事実確認'
  assert_contains "$skill" '初期の設計'
  assert_contains "$skill" '親はハブである'
  assert_contains "$skill" '親が待ち、親が review タブへ中継する'
  assert_contains "$skill" '子は review タブへ'
  assert_contains "$skill" 'send_message しない'
  assert_contains "$skill" 'peer ではない'
  assert_absent "$skill" '作業担当は発火 pane の runtime 1本でファイル変更まで自分でやる'
  assert_absent "$skill" '子を作らない'
  assert_contains "$skill" '発火 pane から他の runtime へ実装を委譲することはできない'
done

assert_contains "$global" 'not user authority'
assert_contains "$talk" 'do not expose `--skill` or `--from`'

echo 'delivery spawn hub contract test: pass'

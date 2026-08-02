#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
dispatcher="$repo_root/agent/common/skills/deliver/SKILL.md"
harden="$repo_root/agent/common/skills/harden/SKILL.md"
decision="$repo_root/docs/decisions/0003-version-gated-stages.md"

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
    printf 'forbidden phrase in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

# polish: v1.0.0 へ磨き上げる段階。harden 昇格は user 宣言か既存 version のみ
assert_contains "$polish" 'v1.0.0 へ磨き上げる'
assert_contains "$polish" '全世界に問いかける'
assert_contains "$polish" '既に 1.0.0 以上'
assert_absent "$polish" '外部公開・release artifact・第三者へ届く出力'
assert_absent "$polish" 'harden へ強制昇格'

# dispatcher: 決定的 version gate を先に判定し、非該当時のみ spike/polish 自動判断
assert_absent "$dispatcher" '昇格トリガー (secret・権限境界・破壊的データ・'
assert_absent "$dispatcher" '段階未指定の `$deliver` は `harden` として実行する'
assert_absent "$dispatcher" 'harden を自動で選んではならない'
assert_contains "$dispatcher" 'まず決定的 gate を判定する'
assert_contains "$dispatcher" '明示的な `$harden` 起動はこの宣言と同値'
assert_contains "$dispatcher" 'spike / polish を自動判断'
assert_contains "$dispatcher" '迷ったら polish'
assert_contains "$dispatcher" 'リスクや成果物の重さからの推論で harden を選んではならない'

# polish 側も dispatcher 自動判断を受け入れること
assert_contains "$polish" '`$deliver` からの自動判断'
assert_absent "$polish" 'このスキルを推論で選んではならない'

# 入口条件が全 surface で一致すること (version gate: 既に 1.0.0 以上)
assert_contains "$spike" '既に 1.0.0 以上'
assert_contains "$polish" '既に 1.0.0 以上'
assert_contains "$dispatcher" '既に 1.0.0 以上'
assert_contains "$harden" 'at or above 1.0.0'
assert_contains "$decision" '既に 1.0.0 以上'

# decision 0003: 要約に version 例外があり、$harden 起動=宣言の同値が定義されていること
assert_contains "$decision" '同値'
assert_absent "$decision" 'harden を自動で選ぶことを禁止'
grep -A6 '^## 要約' "$decision" | grep -Fq '1.0.0 以上' || {
  echo 'decision 0003 要約に version>=1.0.0 例外が無い' >&2
  exit 1
}

# 決定記録: 昇格モデル改訂の authority が記録されていること
test -f "$repo_root/docs/decisions/0003-version-gated-stages.md"
assert_contains "$repo_root/docs/decisions/0003-version-gated-stages.md" '全世界に問いかける'

echo "stage escalation contract test: pass"

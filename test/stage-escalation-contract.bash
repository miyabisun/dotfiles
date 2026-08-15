#!/usr/bin/env bash
# Household delivery is spike / polish only. No shipping-gate stage.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
dispatcher="$repo_root/agent/common/skills/deliver/SKILL.md"
skills_dir="$repo_root/agent/common/skills"

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

if [ -e "$skills_dir/harden" ]; then
  printf 'retired skill path still exists: %s\n' "$skills_dir/harden" >&2
  exit 1
fi

# dispatcher: spike / polish only
assert_contains "$dispatcher" 'spike / polish を自動判断'
assert_contains "$dispatcher" '迷ったら polish'
assert_absent "$dispatcher" 'なんで spike やねん'

# polish: 全 version の成熟レーン (v1.0.0 は通過点)
assert_contains "$polish" 'どの version でも'
assert_contains "$polish" '通過点'
assert_contains "$polish" '`$deliver` からの自動判断'
assert_absent "$polish" 'v1.0.0 へ磨き上げる'
assert_absent "$polish" 'このスキルを推論で選んではならない'

# polish: 大規模でも追加号令や段階切替で止めず、同じ delivery で続行する
assert_contains "$polish" '規模が大きくても追加号令を求めず、この delivery の内側で続行する'
assert_contains "$polish" '追加号令や段階の切り替えで止めない'
assert_contains "$polish" '書きかけの変更は'
assert_absent "$polish" '`$spike` 再依頼'

# spike: version は停止理由にも段階切替の理由にもならない。337a1e9 以降は
# 互換性影響の判定や next major の注記も持たず、水準決定は bump-tag の専権
assert_contains "$spike" 'spike は spike のまま進む'
assert_contains "$spike" '理由にした判定や注記の儀式は追加しない'
assert_contains "$spike" 'bump 水準の決定 (major を含む) は user の `bump-tag` だけが担う'
assert_absent "$spike" '互換性影響'
assert_absent "$spike" 'next major work'
assert_absent "$spike" 'なんで spike やねん'

echo "stage escalation contract test: pass"

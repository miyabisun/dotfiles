#!/usr/bin/env bash
# polish の基線正規化と pre-review mechanical gate 契約を固定する。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
polish="$repo_root/agent/common/skills/polish/SKILL.md"

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

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local a b
  a="$(grep -n -F -- "$first" "$file" | head -1 | cut -d: -f1)"
  b="$(grep -n -F -- "$second" "$file" | head -1 | cut -d: -f1)"
  if [[ -z "$a" || -z "$b" ]]; then
    printf 'ordering anchors missing in %s\n' "$file" >&2
    return 1
  fi
  if (( a >= b )); then
    printf 'expected %q before %q in %s (lines %s >= %s)\n' \
      "$first" "$second" "$file" "$a" "$b" >&2
    return 1
  fi
}

# commit 契約: 0|1 prerequisite formatting + exactly 1 delivery
assert_contains "$polish" '0または1個の prerequisite formatting'
assert_contains "$polish" 'ちょうど1個の delivery commit'
assert_contains "$polish" 'style: normalize formatting'
assert_absent "$polish" '1 invocation = 1 local commit'

# 基線正規化の安全条件 (style commit は clean 開始に限定)
assert_contains "$polish" '基線正規化 (条件付き・最大1回)'
assert_contains "$polish" 'worktree が clean 開始であること'
assert_contains "$polish" 'style commit は clean 開始に限定'
assert_contains "$polish" '既存 user 差分が 1 byte でもあれば自動 commit 禁止'
assert_contains "$polish" 'blocking recovery'
assert_contains "$polish" 'generated・vendor は除外'
assert_contains "$polish" 'tracked な fingerprint marker ファイルは新設しない'
assert_contains "$polish" '`$polish` 明示起動'
assert_absent "$polish" 'または protected/user'
assert_absent "$polish" 'formatter 由来 path が非重複'

# pre-review mechanical gate (レビュー送信の門)
assert_contains "$polish" 'pre-review mechanical gate'
assert_contains "$polish" 'nonzero ならレビューを送らず'
assert_contains "$polish" '修正へ戻る'
assert_contains "$polish" 'gate を再実行してから'
assert_contains "$polish" '未実装 script を参照して止まってはならない'
assert_contains "$polish" '検証 step の再掲義務ではなく、レビュー送信の門'
assert_contains "$polish" '適用可能な repo-native formatter/linter だけを実行し'
assert_contains "$polish" '非適用/不在は理由付き N/A として記録する'
assert_contains "$polish" '実行対象の nonzero はレビュー送信を止める'

# 独立 formatter 役職は要求しない / hook 非依存
assert_contains "$polish" '独立な formatter 役職ゲートは立てない'
assert_absent "$polish" 'PostToolUse'
assert_absent "$polish" 'Stop hook'

# 順序: 基線 → 実装 → 検証 → gate → レビュー送信 → コミット
assert_before "$polish" \
  '基線正規化 (条件付き・最大1回)' \
  '**直す**:'
assert_before "$polish" \
  'pre-review mechanical gate' \
  '門を通したら実装レビュー召喚を**1回だけ**起動し、user 原文'
assert_before "$polish" \
  'pre-review mechanical gate' \
  '**コミットする**:'

echo "polish formatter gate contract test: pass"

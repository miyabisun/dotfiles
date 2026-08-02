#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"

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

# TDD は死守: red の観測が必須で、自己免除は存在しない
assert_contains "$spike" 'テスト無きゴールは存在しない'
assert_contains "$spike" '失敗するテストを先に書き (red)、通す (green)'
assert_contains "$spike" 'red を観測できないなら未達として止める'
assert_absent "$spike" '守れない事情があるなら'
assert_absent "$spike" '理由を1行'

# ゴール = acceptance テスト + 隣接する既存チェックの全 green
assert_contains "$spike" '変更に隣接する既存 test/build/lint が全て green'
assert_contains "$spike" '黙ってゴールから除外しない'

# formatter / linter は機械的に実行する
assert_contains "$spike" '**formatter / linter を機械的に叩く**'

# レビュワーは counterpart を who で一意に固定してから1往復する
assert_contains "$spike" 'agent-talk-peer who'
assert_contains "$spike" '同じ window、次に同じ session'
assert_contains "$spike" '不在・pane 消失・配達失敗のときだけ self review'

# レビュワーの検査項目: テストの誠実さ・DRY・過度な YAGNI・実行確認
assert_contains "$spike" 'トートロジー'
assert_contains "$spike" '誤魔化し'
assert_contains "$spike" '厳格に blocking とし、修正させる'
assert_contains "$spike" 'このケースは必要か?'
assert_contains "$spike" 'formatter / linter の実行確認'

# DRY blocking は今回 diff 由来の有害な重複に限定 (試作の意図的重複は polish TODO)
assert_contains "$spike" '機構追加なしの局所抽出で消せる'
assert_contains "$spike" 'non-blocking の polish TODO'

# 段階分割の境界: 暗黙選択の禁止・昇格トリガー・commit 授権
assert_contains "$spike" '`$deliver` からこのスキルを推論で選んではならない'
assert_contains "$spike" '1 invocation = 1 local commit'
assert_contains "$spike" '**harden への切り替えを'
assert_contains "$spike" '宣言して停止する**'

echo "spike contract test: pass"

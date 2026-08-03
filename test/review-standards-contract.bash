#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
harden="$repo_root/agent/common/skills/harden/SKILL.md"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

# polish: counterpart は planning で一意固定し、実装レビューは同じ pane を使う
assert_contains "$polish" '**反対 runtime の登録 pane**を同じ window、次に同じ session の'
assert_contains "$polish" 'step 1 で固定した同じ pane へ'
assert_contains "$polish" '同じ window、次に同じ session'

# polish: spike と横並びの検査項目
assert_contains "$polish" 'テストの誠実さ (blocking)'
assert_contains "$polish" 'トートロジー'
assert_contains "$polish" '誤魔化し'
assert_contains "$polish" '機構追加なしの局所抽出で消せる'
assert_contains "$polish" 'このケースは必要か?'
assert_contains "$polish" 'formatter / linter の実行確認 (blocking)'
assert_contains "$polish" '回帰テストが付いているか'

# harden: 同じ横並び項目 (英文本文)
assert_contains "$harden" 'test honesty'
assert_contains "$harden" 'tautological tests that restate the implementation'
assert_contains "$harden" 'weakened or skipped assertions'
assert_contains "$harden" 'harmful duplication introduced by this diff'
assert_contains "$harden" 'Is this case actually needed?'

echo "review standards contract test: pass"

#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
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
    printf 'retired contract still present in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

# polish: レビュワーは planning で一意固定し、実装レビューは同じ pane を使う。
# レビュワーは codex 1名。旧2名並列は復活させない
assert_contains "$polish" 'step 1 で固定した同じ pane へ'
assert_contains "$polish" '同じ window、次に同じ'
assert_contains "$polish" '送るのは1通だけ'
assert_absent "$polish" 'レビュワーが2名の場合は同一内容を両 pane へ並列送信し'
assert_absent "$polish" 'closure は両名から受ける'

# polish: spike と横並びの検査項目
assert_contains "$polish" 'テストの誠実さ (blocking)'
assert_contains "$polish" 'トートロジー'
assert_contains "$polish" '誤魔化し'
assert_contains "$polish" '機構追加なしの局所抽出で消せる'
assert_contains "$polish" 'このケースは必要か?'
assert_contains "$polish" 'formatter / linter の実行確認 (blocking)'
assert_contains "$polish" '回帰テストが付いているか'

# spike: 同じ横並び項目
assert_contains "$spike" 'テストの誠実さ (blocking)'
assert_contains "$spike" 'トートロジー'
assert_contains "$spike" '誤魔化し'
assert_contains "$spike" 'このケースは必要か?'

echo "review standards contract test: pass"

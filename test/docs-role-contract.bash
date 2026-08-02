#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docs="$repo_root/agent/common/agents/docs.md"
deliver="$repo_root/agent/common/skills/harden/SKILL.md"

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
    printf 'retired wording still present in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

# 一般論ではなくプロダクト固有の前提を書く
assert_contains "$docs" '一般的な技術知識だけでは導けないプロダクト固有の'
assert_contains "$docs" '不変条件、信頼境界、外部の制約'
assert_contains "$docs" '該当するものだけを扱う'

# 因果の形で書く (これがドメイン前提と開発経緯・自己弁護を分ける基準)
assert_contains "$docs" '前提または制約 → それが決めている設計判断または不変条件 →'
assert_contains "$docs" 'この対応が書けない一般論は書かない'
assert_contains "$docs" '自己弁護と、上記のドメイン前提の因果は別物として扱う'

# 削除の判定基準 (冗長性を主観で決めない)
assert_contains "$docs" '削除後も読者が正しい操作・設定を選び、失敗を予測し、環境を再現し'

# 設計理由の出典は実装の形ではない
assert_contains "$docs" '設計理由やドメイン上の'
assert_contains "$docs" '前提は実装の形から推測せず'
assert_contains "$docs" 'ユーザー原文が渡されていない場合は実装の形から補わず、不足をgapsに返す'

# 全項目を埋めるテンプレートにしない
assert_contains "$docs" '仕様・手順ごとに、該当する前提、選択条件、期待結果、失敗時の結果、確認方法を'

# receipt: status と sources の意味制約
assert_contains "$docs" '`sources`が1件以上、`status=unverified`は`sources`を空にする'
assert_contains "$docs" '"claims": [{"claim": "...", "sources": ["file:line"], "status": "verified"}],'

# 行動に変換できない語を復活させない
assert_absent "$docs" '宣言的'
assert_absent "$docs" '先回り'

# deliver 側が原文を docs role へ渡す契約を持つこと (無いとドメイン前提の出典が枯れる)
assert_contains "$deliver" '`source_request` original text, material follow-ups, and'
assert_contains "$deliver" "source other than the user's own words"

# receipt 例が JSON として妥当であること
receipt="$(sed -n '/^```json$/,/^```$/p' "$docs" | sed '1d;$d')"
printf '%s\n' "$receipt" | jq empty || {
  printf 'docs receipt example is not valid JSON\n' >&2
  exit 1
}

echo "docs role contract test: pass"

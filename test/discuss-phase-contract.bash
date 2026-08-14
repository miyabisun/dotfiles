#!/usr/bin/env bash
# discuss is spike / polish only.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
discuss="$repo_root/agent/common/skills/discuss/SKILL.md"

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

assert_contains "$discuss" '$discuss spike|polish'
assert_contains "$discuss" '本文中に'
assert_contains "$discuss" '段階の語が現れても判定しない'
assert_contains "$discuss" '**spike / polish を自動判断**'
assert_contains "$discuss" '**迷ったら polish**'
assert_contains "$discuss" '自動では起動しない'
assert_contains "$discuss" '継承は本文の話題からの推論より優先する'
assert_contains "$discuss" '段階の変更は提案に留め'

assert_absent "$discuss" '(または deliver)'
assert_absent "$discuss" '## deliver から呼ばれる場合'
assert_absent "$discuss" '反対 runtime の登録 pane'
assert_absent "$discuss" '議論の目的は発散ではなく**収束**である'

assert_contains "$discuss" 'yes-and'
assert_contains "$discuss" 'ワクワクするか'
assert_contains "$discuss" '明日 spike できる一歩'
assert_contains "$discuss" '承認済みかつ'
assert_contains "$discuss" 'docs/decisions は作らない'

assert_contains "$discuss" '操作数/認知負荷'
assert_contains "$discuss" 'rollback'
assert_contains "$discuss" 'UX-safe'

assert_contains "$discuss" 'agent-talk MCP の `list_peers`'
assert_contains "$discuss" '乗っかり'
assert_contains "$discuss" 'UX 退行'
assert_contains "$discuss" '固定済みのレビュワー集合'
assert_contains "$discuss" 'owner grok または claude → codex'
assert_contains "$discuss" 'owner が'
assert_contains "$discuss" '自己レビュー経路は置かない'
assert_contains "$discuss" 'レビュワーごとに1件だけ'
assert_absent "$discuss" '同一ターンに並列で各1通'
assert_absent "$discuss" '一方の初回回答を他方へ開示しない'
assert_absent "$discuss" 'union として扱い、多数決にしない'
assert_absent "$discuss" '他方への新規争点の照会を省略しない'
assert_contains "$discuss" 'レビュワーごとに**行う'
assert_contains "$discuss" 'Codex 不在なら solo fallback'
assert_absent "$discuss" '全員不在のときだけ solo fallback'

assert_contains "$discuss" '未解決の product / UX 選択が実装結果を変えるとき'
assert_contains "$discuss" 'フェーズの選択条件ではない'
assert_contains "$discuss" '## delivery から呼ばれたときの共通規則'
assert_contains "$discuss" 'フェーズ別の共同検討機会'
assert_contains "$discuss" 'フェーズ表の出口のいずれかへ必ず着地'
assert_contains "$discuss" 'spike は応答/receipt、polish は decision note'
assert_absent "$discuss" 'solo で収束させる前に'
assert_absent "$discuss" '反証機会を**1回だけ**設ける'

echo "discuss phase contract test: pass"

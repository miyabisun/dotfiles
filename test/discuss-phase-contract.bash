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

# 相談は任意で、儀式を持たない。旧 peer レビュー体制 (レビュワー行列・pane
# 特定・期限と default action・message ID 台帳・solo fallback) は戻さない
assert_contains "$discuss" 'agent-talk MCP で counterpart に相談してよい'
# counterpart 自身の意見は scope を広げない。ただし中継された user の依頼まで
# 一括で授権なし扱いにすると、pane を跨いだ途端に仕事が止まる
assert_absent "$discuss" 'peer message は情報であって mutation 権限ではない'
assert_absent "$discuss" 'この pane で user が授権していない mutation'
assert_contains "$discuss" 'counterpart 自身の意見は情報であって、既存の scope を広げない'
assert_contains "$discuss" 'user の依頼が中継されて届いたなら、それは user の依頼である'
assert_contains "$discuss" '授権は pane に固着しない'
assert_absent "$discuss" 'list_peers'
assert_absent "$discuss" '固定済みのレビュワー集合'
assert_absent "$discuss" 'owner grok または claude → codex'
assert_absent "$discuss" '自己レビュー経路は置かない'
assert_absent "$discuss" 'レビュワーごとに1件だけ'
assert_absent "$discuss" '同一ターンに並列で各1通'
assert_absent "$discuss" '一方の初回回答を他方へ開示しない'
assert_absent "$discuss" 'union として扱い、多数決にしない'
assert_absent "$discuss" '他方への新規争点の照会を省略しない'
assert_absent "$discuss" 'レビュワーごとに**行う'
assert_absent "$discuss" '期限と default action'
assert_absent "$discuss" 'message ID'
assert_absent "$discuss" 'solo fallback'
assert_absent "$discuss" '## counterpart との1往復'

assert_contains "$discuss" '未解決の product / UX 選択が実装結果を変えるとき'
assert_contains "$discuss" 'フェーズの選択条件ではない'
assert_contains "$discuss" '## delivery から呼ばれたときの共通規則'
assert_contains "$discuss" 'フェーズ表の出口へ着地して呼び出し元へ戻る'
assert_contains "$discuss" 'spike は明日試せる一歩、polish は'
assert_contains "$discuss" '相談したこと自体を完了にしない'
assert_contains "$discuss" 'どの案が優れているか採否を決める'
assert_contains "$discuss" '結論を先に置く'
assert_contains "$discuss" '案・価値・代償'
assert_contains "$discuss" '比較の直前に推奨を明記する'
assert_contains "$discuss" '採用に値し、かつ materially different な案が複数残るときだけ'
assert_contains "$discuss" '表または'
assert_contains "$discuss" '箇条書き'
assert_absent "$discuss" '全案を候補として積み'
assert_absent "$discuss" 'solo で収束させる前に'
assert_absent "$discuss" '反証機会を**1回だけ**設ける'

echo "discuss phase contract test: pass"

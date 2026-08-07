#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
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

# フェーズ解決: 明示構文・呼び出し元継承・standalone は spike/polish 自動判断。
# 既定 harden (勝手な格上げ) と本文語の推論は禁止 (decision 0004 横並び)
assert_contains "$discuss" '$discuss spike|polish|harden'
assert_contains "$discuss" '本文中に'
assert_contains "$discuss" '段階の語が現れても判定しない'
assert_absent "$discuss" 'どちらも無ければ **harden**'
assert_contains "$discuss" '**spike / polish を自動判断**'
assert_contains "$discuss" '**迷ったら polish**'
assert_contains "$discuss" '号令で起動済みの'
assert_contains "$discuss" '推論で harden を選ばない'
assert_contains "$discuss" '自動では起動しない'

# caller 継承は本文の話題からの推論より優先 (polish 内で作り直し案を検討した
# だけで spike へ転換する事故の防止)。段階変更は提案に留まる
assert_contains "$discuss" '継承は本文の話題からの推論より優先する'
assert_contains "$discuss" '段階の変更は提案に留め'

# harden 級の兆候は advisory (自動格上げの禁止)
assert_contains "$discuss" '自動で harden へ格上げせず'
assert_contains "$discuss" '`$discuss harden` を推奨'

# 旧 deliver 語彙の残存禁止
assert_absent "$discuss" '(または deliver)'
assert_absent "$discuss" '## deliver から呼ばれる場合'
assert_absent "$discuss" '反対 runtime の登録 pane'

# 旧・無条件宣言の排除 (spike モードと矛盾するため)
assert_absent "$discuss" '議論の目的は発散ではなく**収束**である'

# spike: 広げる・repo mutation なし・可逆な一歩・保留ラベル
assert_contains "$discuss" 'yes-and'
assert_contains "$discuss" 'ワクワクするか'
assert_contains "$discuss" '明日 spike できる一歩'
assert_contains "$discuss" '承認済みかつ'
assert_contains "$discuss" '`requires harden/authority`'
assert_contains "$discuss" 'docs/decisions は作らない'
assert_contains "$discuss" 'A〜F・decision receipt・独立再判定は適用しない'

# polish: UX 比較軸と phase 固有の出口
assert_contains "$discuss" '操作数/認知負荷'
assert_contains "$discuss" 'rollback'
assert_contains "$discuss" 'UX-safe'

# harden: 全機構維持と外部評価視点
assert_contains "$discuss" '他の IT エンジニアに評価されても'
assert_contains "$discuss" 'Ready / Ready with reduced scope / Authority gap'

# 重機構の harden 限定スコープと、保護 hunk (要約規定) との整合
assert_contains "$discuss" 'harden フェーズ'
assert_contains "$discuss" '要約規定は decision receipt を書くフェーズにだけ適用'

# counterpart 1往復: 共通部 (pane 解決・権限境界) + phase 別 payload
assert_contains "$discuss" 'agent-talk MCP の `list_peers`'
assert_contains "$discuss" '乗っかり'
assert_contains "$discuss" 'UX 退行'
assert_contains "$discuss" 'material objection / missing risk / concrete correction'

# 担当→レビュワー行列への横並び (eeb1b47): caller 内は固定済みレビュワー集合を
# 継承、standalone は owner runtime から行列で解決。2名は並列各1通・初回回答の
# 相互非開示・union (多数決にしない)・per-reviewer の既出争点/不在/記録
assert_contains "$discuss" '固定済みのレビュワー集合'
assert_contains "$discuss" 'owner grok → claude と codex'
assert_contains "$discuss" 'owner claude → codex、owner codex →'
assert_contains "$discuss" 'レビュワーごとに1件だけ'
assert_contains "$discuss" '同一ターンに並列で各1通'
assert_contains "$discuss" '一方の初回回答を他方へ開示しない'
assert_contains "$discuss" 'union として扱い、多数決にしない'
assert_contains "$discuss" '他方への新規争点の照会を省略しない'
assert_contains "$discuss" 'レビュワーごとに**行う'
assert_contains "$discuss" '全員不在のときだけ solo fallback'
# 「反証だけを反映」の無条件適用が消えていること (harden 限定へ)
assert_absent "$discuss" '反映するのは反証・新事実・権限境界に関わる指摘だけ。単なる選好差は'

# 起動条件は「選択済み phase 内で discuss を使うか」の判定であって、phase の
# 選択条件ではない (第二の harden 入口の禁止)。兆候リストは明示/継承 harden 内の
# A〜F 適用条件としてだけ残る
assert_contains "$discuss" '未解決の product / UX 選択が実装結果を変えるとき'
assert_contains "$discuss" 'フェーズの選択条件ではない'
assert_contains "$discuss" '明示引数・継承で harden に入っている場合'
assert_contains "$discuss" 'A〜F と decision receipt の全機構を要する'
assert_absent "$discuss" 'harden: 次のいずれかを含むとき'
assert_absent "$discuss" '次のいずれかを含むときだけ使う。'

# delivery 呼び出しの共通規則と phase 固有出口の分離 (spike/polish へ A〜F を
# 持ち込まない)
assert_contains "$discuss" '## delivery から呼ばれたときの共通規則'
assert_contains "$discuss" 'harden だけが A〜F と decision receipt を用いる'
assert_contains "$discuss" '## harden delivery のラウンド出口 (A〜F)'
assert_absent "$discuss" '## delivery (spike / polish / harden) から呼ばれる場合'

# counterpart 節の無条件 harden 語の残存禁止
assert_absent "$discuss" 'solo で収束させる前に'
assert_absent "$discuss" '反証機会を**1回だけ**設ける'
assert_contains "$discuss" 'フェーズ別の共同検討機会'

# fallback 出口と記録先のフェーズ委譲 (無条件の Ready 固定・receipt 固定の禁止)
assert_absent "$discuss" 'Ready / Ready with reduced scope / Authority gap のいずれかへ必ず着地'
assert_contains "$discuss" 'フェーズ表の出口のいずれかへ必ず着地'
assert_absent "$discuss" '実装者向け欄に記録し、冒頭要約には書かない'
assert_contains "$discuss" 'spike は応答/receipt、polish は decision note'

echo "discuss phase contract test: pass"

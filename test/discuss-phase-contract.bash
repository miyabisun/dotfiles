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

# フェーズ解決: 明示構文・呼び出し元継承・既定 harden・本文語の推論禁止
assert_contains "$discuss" '$discuss spike|polish|harden'
assert_contains "$discuss" '本文中に'
assert_contains "$discuss" '段階の語が現れても判定しない'
assert_contains "$discuss" 'どちらも無ければ **harden**'
assert_contains "$discuss" '保証を暗黙に弱めない'
assert_contains "$discuss" '自動では起動しない'

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
# 「反証だけを反映」の無条件適用が消えていること (harden 限定へ)
assert_absent "$discuss" '反映するのは反証・新事実・権限境界に関わる指摘だけ。単なる選好差は'

# 起動条件のフェーズ分岐 (spike/polish が起動不能にならないこと)
assert_contains "$discuss" '未解決の product / UX 選択が実装結果を変えるとき'
assert_contains "$discuss" 'harden: 次のいずれかを含むとき'
assert_absent "$discuss" '次のいずれかを含むときだけ使う。'

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

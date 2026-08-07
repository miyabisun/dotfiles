#!/usr/bin/env bash
# spike / polish の「実装前の方針すり合わせ」契約を固定する。
#
# 目的は2つ。(1) 実装より前に counterpart の独立案を取り、user の目的との
# ズレを先に潰す手順が存在すること。(2) その判定軸が「目的 vs 手段」を
# 取り違えないこと — user が挙げた手段は正ではなく、より良い手段で
# 置き換えてよい、という原則が消えないこと。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"

assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_absent() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'retired contract still present in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

# `first` が `second` より前の行に現れることを要求する。単なる存在検査では
# 手順の入れ替え (実装してから方針を聞く) を検出できない
assert_before() {
  local file="$1" first="$2" second="$3"
  local first_line second_line
  first_line="$(grep -nF -- "$first" "$file" | head -n1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$file" | head -n1 | cut -d: -f1)"
  if [ -z "$first_line" ] || [ -z "$second_line" ]; then
    printf 'assert_before needs both anchors in %s: %s / %s\n' \
      "$file" "$first" "$second" >&2
    exit 1
  fi
  if [ "$first_line" -ge "$second_line" ]; then
    printf 'wrong order in %s: %s (line %s) must precede %s (line %s)\n' \
      "$file" "$first" "$first_line" "$second" "$second_line" >&2
    exit 1
  fi
}

for skill in "$spike" "$polish"; do
  # 手順として存在し、実装前であること
  assert_contains "$skill" '**方針を独立にすり合わせる (実装前・1往復)**'
  assert_contains "$skill" 'user 原文 (verbatim)・確認済みの事実・制約だけ'

  # アンカリング防止: 自案を同封しない / 事実に設計判断を混ぜない
  assert_contains "$skill" '**最初の brief に自分の案を入れない。**'
  assert_contains "$skill" '一つの枠内での粗探しに固定され'
  assert_contains "$skill" '設計判断を混ぜない'

  # 独立性を規律ではなく順序で守る
  assert_contains "$skill" '**同じターンで自分の案を起草する。**'
  assert_contains "$skill" '返信本文を読む前に'

  # reconcile 前に実装へ進まない
  assert_contains "$skill" '**reconcile が終わるまでテストと実装を編集しない。**'

  # 軸 A: 照合先は目的であって手段ではない (user-origin, 最重要)
  assert_contains "$skill" '### A. user の目的との一致 (最優先・blocking)'
  assert_contains "$skill" '**照合先は「目的」であって「手段」ではない。**'
  assert_contains "$skill" '強いヒントだが**正ではない**'
  assert_contains "$skill" 'より良く果たす手段があれば置き換えてよい'
  # 制約・非目標・権限境界は手段ではないので置き換え対象外
  assert_contains "$skill" '手段ではなく前提なので破れない'
  # 目的と手段の切り分け規則が実務的に書かれていること
  assert_contains "$skill" 'user はその結果を望むか？'
  # 無断の差し替えを禁じる
  assert_contains "$skill" '**手段を置き換えるときは黙って差し替えない。**'

  # 案同士の比較より前に、各案を目的へ照らす
  assert_contains "$skill" '**突き合わせは「案 A vs 案 B」ではなく、まず「各案 vs user の目的」で行う。**'
  assert_contains "$skill" '二者は同じ誤読をしうる'

  # 軸 B: 手段の優劣。A を上書きしないが、未実施のまま進むこともできない。
  # non-blocking と書くと「記録だけして先へ」の語彙に落ちて B が省略される
  assert_contains "$skill" '### B. どちらの手段が優れているか (選択軸・統合必須)'
  assert_contains "$skill" '**B は A を上書きできない**'
  assert_contains "$skill" '**B を未実施のまま契約化へ進んではならない。**'
  assert_absent "$skill" '### B. どちらの手段が優れているか (選択軸・non-blocking)'

  # 担当→レビュワー行列: 明示指定が最優先、未明示 + 同席 grok は grok が既定
  # 担当。grok 担当は claude+codex 両レビュー。距離規則は runtime を決めない
  assert_contains "$skill" '**user の明示指定が最優先**'
  assert_contains "$skill" '**grok が既定の作業担当**'
  assert_contains "$skill" '担当 grok → レビュワーは claude と codex の**両方**'
  assert_contains "$skill" '担当 claude → レビュワーは codex。担当 codex → レビュワーは claude'
  assert_contains "$skill" '担当・レビュワーの'
  # authority 境界: 受けた pane から grok へ実装を委譲できない
  assert_contains "$skill" '担当未明示の起動を claude / codex の pane が受け'
  assert_contains "$skill" '権限を運ばない**ので、受けた pane から grok へ実装を委譲することは'
  # grok 担当時の並列2通と、読む前の自案確定
  assert_contains "$skill" 'レビュワーが2名なら2通を'
  assert_contains "$skill" 'どちらの返信も読む前に自案を確定させる'
  # 旧二値規定の再発防止
  assert_absent "$skill" '**反対 runtime の登録 pane**'
  assert_absent "$skill" 'Claude の counterpart は Codex'

  # 期限超過を fallback 条件にする以上、期限と default action の設定が要る
  assert_contains "$skill" '**期限と default action を決めて記録する**'
  assert_contains "$skill" '**次に delivery が再開した時点**で評価する'

  # receipt の証跡。照合先は「原文」ではなく「目的」でなければならない
  assert_contains "$skill" '方針すり合わせについては次を残す'
  assert_contains "$skill" '**user の目的とのズレの有無と是正内容**'
  assert_contains "$skill" '原文中の目的と手段を'
  assert_contains "$skill" '**手段を置き換えた場合はその内容と理由**'
  assert_contains "$skill" 'レビュワー不在時は該当レビュワーごとに'
  assert_absent "$skill" 'user 原文とのズレの有無'

  # 文型ヒューリスティックを最終判断にしない
  assert_contains "$skill" '**最終判断は文型ではなく「置換しても望む結果が同一か」**'

  # 不在時 fallback を「相互レビュー」と偽らない
  assert_contains "$skill" 'planning_reviewer_unavailable: <runtime>'
  assert_contains "$skill" 'planning_reviewers: unavailable'
  assert_contains "$skill" '**片方だけ不在** (レビュワー2名時)'
  assert_contains "$skill" '欠けた側の分だけ自案を A 軸で self-check する'
  assert_contains "$skill" '不在を理由に担当を変更しない'
  assert_absent "$skill" 'planning_counterpart: unavailable'
  assert_contains "$skill" '**self の見直しを「相互レビュー」と呼ばない。**'
  assert_contains "$skill" 'ズレ検出だけは省略しない'

  # discuss は独立提案の代替にならない
  assert_contains "$skill" '**blind な独立提案の代替にはならない**'

  # peer 接触は2種類あり、混同しない
  assert_contains "$skill" '**2つで別物**'

  # planning は1往復。統合案の再承認はしない
  assert_contains "$skill" '統合案の再承認・二段階照合は行わない'

  # 旧テキストは独立提案交換そのものを禁止していた
  assert_absent "$skill" '独立提案交換は行わない'
  assert_absent "$skill" 'counterpart 照会・独立提案交換'

  # 順序: 方針すり合わせ -> 契約 -> 実装レビュー
  assert_before "$skill" \
    '**方針を独立にすり合わせる (実装前・1往復)**' \
    '**実装レビュー1回**'
  # 軸 A が軸 B より前に書かれていること (優先順位が読み順に出る)
  assert_before "$skill" \
    '### A. user の目的との一致 (最優先・blocking)' \
    '### B. どちらの手段が優れているか (選択軸・統合必須)'
done

# spike は契約をテストで書く段階が方針すり合わせの後に来る
assert_before "$spike" \
  '**方針を独立にすり合わせる (実装前・1往復)**' \
  '**契約はテストで書く**'
assert_before "$spike" \
  '**契約はテストで書く**' \
  '**TDD で作る**'
assert_contains "$spike" '狙う体験 / 最大3項目の acceptance'

# polish は不満の契約化が方針すり合わせの後に来る
assert_before "$polish" \
  '**方針を独立にすり合わせる (実装前・1往復)**' \
  '**不満を契約にする**'
assert_before "$polish" \
  '**不満を契約にする**' \
  '**直す**'
assert_contains "$polish" '不満の理解 / 最小修正 / 回帰証拠'

# 方針すり合わせで大きな再設計が出ても自動昇格しない (decision 0003 との整合)
assert_contains "$polish" 'step 1 で大きな'
assert_contains "$polish" '自動昇格はしない (decision 0003)'

echo 'planning alignment contract test: pass'

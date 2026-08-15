#!/usr/bin/env bash
# spike / polish の「実装前の方針すり合わせ」契約を固定する。
#
# 目的は2つ。(1) 実装より前に counterpart の独立案を取り、user の目的との
# ズレを先に潰す手順が存在すること。(2) その判定軸が「目的 vs 手段」を
# 取り違えないこと — user が挙げた手段は正ではなく、より良い手段で
# 置き換えてよい、という原則が消えないこと。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
discuss="$repo_root/agent/common/skills/discuss/SKILL.md"

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

  # 独立性は「召喚前に自案を確定し、result はその後に読む」で守る
  # (同期召喚なので、旧来の「返信は次ターン」という順序では守られない)
  assert_contains "$skill" '**同じターンで自分の案を起草する。**'
  assert_contains "$skill" '`$result` を読む前に'
  assert_absent "$skill" '返信本文を読む前に'

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

  # 担当→レビュワー: 担当は skill を発火した pane の runtime (常に)。
  # 既定担当・指名優先・指名待ちの儀式は廃止 (user-origin)。
  # レビュワーは peer pane ではなく同期召喚する codex exec の1プロセス。
  # peer 経路 (review タブ・list_peers・発火タブ例外) は全廃した
  assert_contains "$skill" 'pane の runtime が担う。'
  assert_absent "$skill" '**user の明示指定が最優先**'
  assert_absent "$skill" '**grok が既定の作業担当**'
  assert_absent "$skill" '担当未明示の起動を claude / codex の pane が受け'
  assert_absent "$skill" '起動し直し'
  assert_contains "$skill" 'レビュワーは**同期召喚する `codex exec` の1プロセス**である'
  assert_absent "$skill" 'レビュワーは**発火 pane と同じ space の `review` タブ・常に1名**'
  assert_absent "$skill" 'review タブ'
  assert_absent "$skill" 'list_peers'
  assert_absent "$skill" '`<space>/review` を一意解決'
  assert_absent "$skill" '担当 grok または claude → レビュワーは codex'
  assert_absent "$skill" 'same-window/session は pane の距離規則'
  # authority 境界: 実装は投げ直せない。ただしこれは投げる側の制約であって、
  # 中継されて届いた user の依頼を突き返す根拠ではない
  assert_contains "$skill" 'runtime へ投げ直すことはできない'
  assert_contains "$skill" '投げる側の制約であって、受け取る側の制約ではない'
  # 1回の planning 召喚と、result を読む前の自案確定
  assert_contains "$skill" '送るのは1通だけ'
  assert_contains "$skill" '`$result` を読む前に自案を確定させる'
  assert_contains "$skill" '毎回 agent を作成する'
  assert_contains "$skill" '子の結果は親が待ち、親が召喚 prompt へまとめる'
  assert_absent "$skill" '作業担当は発火 pane の runtime 1本でファイル変更まで自分でやる'
  assert_absent "$skill" '担当 grok → レビュワーは claude と codex の**両方**'
  assert_absent "$skill" '担当 claude → レビュワーは codex。担当 codex → レビュワーは claude'
  assert_absent "$skill" 'レビュワーが2名なら2通を'
  # 旧二値規定の再発防止
  assert_absent "$skill" '**反対 runtime の登録 pane**'
  assert_absent "$skill" 'Claude の counterpart は Codex'

  # 待機は「子 agent の結果待ち」だけ。レビュワー召喚は同期なので待ちにならない。
  # MUST yield は「有用な独立作業が無い」条件付き (unconditional yield への
  # 退行も検出する)。poll の禁止と未完了テンプレート
  assert_contains "$skill" '**子 agent の結果待ち**'
  assert_contains "$skill" '他に有用な独立作業が無いなら'
  assert_contains "$skill" 'turn を終了して yield しなければならない'
  assert_absent "$skill" 'turn を yield してよい'
  assert_contains "$skill" 'sleep・wait loop で turn を保持'
  assert_contains "$skill" '子 agent の結果待ちにだけ使う'
  assert_contains "$skill" '子の結果待ちで一旦 turn を終了する。子の完了でこの delivery を再開する'
  assert_contains "$skill" '完了報告と誤認される文言を使わない'
  assert_contains "$skill" '追加の「続けて」を**再開条件にしない**'
  assert_contains "$skill" '契約は commit まで。途中で止まった配達は未完了である'

  # peer 待ちの機構は全廃: 期限と default action・doorbell 再開・返信待ちの
  # 状態遷移・planning/実装レビューの返信 route
  assert_absent "$skill" '**期限と default action を決めて記録する**'
  assert_absent "$skill" '期限と default action'
  assert_absent "$skill" '**返信待ちの状態遷移**'
  assert_absent "$skill" 'doorbell'
  assert_absent "$skill" '呼び鈴'
  assert_absent "$skill" '同じ delivery の**再開 trigger**'
  assert_absent "$skill" '**planning 返信**が揃った'
  assert_absent "$skill" '**実装レビュー返信**が揃った'
  assert_absent "$skill" 'closure 後 → commit / 報告'
  assert_absent "$skill" '**期限はそれ自体で wake しない。**'
  assert_absent "$skill" '待っていた reply doorbell 到着時の自動再開'
  assert_absent "$skill" '**次に delivery が再開した時点**で評価する'
  assert_absent "$skill" 'または期限・不在の default action が発火'
  # planning result を読んだ後の進行先は残す
  assert_contains "$skill" 'A→B 照合 → 契約化以降'

  # receipt の証跡。照合先は「原文」ではなく「目的」でなければならない
  assert_contains "$skill" '方針すり合わせについては次を残す'
  assert_contains "$skill" '**user の目的とのズレの有無と是正内容**'
  assert_contains "$skill" '原文中の目的と手段を'
  assert_contains "$skill" '**手段を置き換えた場合はその内容と理由**'
  # 記録は message ID / pane ではなく、召喚回数・schema 判定・fallback
  assert_contains "$skill" '**召喚回数と各召喚の schema 判定**'
  assert_contains "$skill" '**fallback の有無と `review_exec_failed` の理由**'
  assert_absent "$skill" 'レビュワー不在時は該当レビュワーごとに'
  assert_absent "$skill" 'message ID'
  assert_absent "$skill" 'user 原文とのズレの有無'

  # 文型ヒューリスティックを最終判断にしない
  assert_contains "$skill" '**最終判断は文型ではなく「置換しても望む結果が同一か」**'

  # fallback は「レビュワー不在」ではなく「召喚の失敗」で発火し、
  # self の見直しを「相互レビュー」と偽らない
  assert_contains "$skill" 'review_exec_failed: <理由>'
  assert_absent "$skill" 'planning_reviewer_unavailable: <runtime>'
  assert_absent "$skill" 'planning_reviewers: unavailable'
  assert_absent "$skill" '**レビュワー不在**'
  assert_absent "$skill" '### レビュワー不在時'
  assert_absent "$skill" 'idle も busy も存在扱いで送る'
  assert_absent "$skill" '**片方だけ不在** (レビュワー2名時)'
  assert_absent "$skill" '欠けた側の分だけ自案を A 軸で self-check する'
  assert_absent "$skill" 'planning_counterpart: unavailable'
  assert_contains "$skill" '**self の見直しを「相互レビュー」と呼ばない。**'
  assert_contains "$skill" 'ズレ検出だけは省略しない'

  # discuss は独立提案の代替にならない
  assert_contains "$skill" '**blind な独立提案の代替にはならない**'

  # 召喚は planning と実装レビューの2種で、混同しない
  assert_contains "$skill" '### 召喚は2種・1 delivery で最大3回'

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

# 旧二値語彙は discuss にも残さない (eeb1b47 の行列横並び)
assert_absent "$discuss" '**反対 runtime の登録 pane**'
assert_absent "$discuss" '反対 runtime'

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

# 方針すり合わせで大きな再設計が出ても同じ delivery で続行する
assert_contains "$polish" 'step 1 で大きな'
assert_contains "$polish" 'この delivery の内側で続行する'

echo 'planning alignment contract test: pass'

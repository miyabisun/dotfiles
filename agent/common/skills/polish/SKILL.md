---
name: polish
description: >-
  ブラッシュアップ段階の配達。動いているものに対する具体的な不満・issue を
  受け取り、実装前の方針すり合わせ1往復・修正・回帰テスト・変更隣接チェック・
  実装レビューを経て、条件付きで最大1個の prerequisite formatting commit と
  ちょうど1個の delivery commit で返し、version を問わず成熟へ磨き上げていく。
  明示起動・段階明示・段階未指定 $deliver からの自動判断で使う。
  push・deploy・release はしない。
---

# polish

**動いているものを、出てきた不満に沿って叩き直し、成熟へ磨き上げる**。
新規の体験づくりは `spike` の仕事であり、polish は
**どの version でも**成熟へ向かう本流である。v1.0.0 は卒業ではなく通過点で、
実利のある品質改善を軽い足取りで積む。

## 起動条件

user の明示的な `$polish` 起動、同じ依頼文での段階明示、または段階未指定の
`$deliver` からの自動判断が起動根拠。自動判断では dispatcher が選択と根拠を
宣言する。

## 共通契約

段階 skill が共通して従う契約 (作業の分担・レビュワー召喚・方針すり合わせの
判定軸・不変条件) は [CONTRACT.md](../deliver/CONTRACT.md) が持つ。
工程と所有者の正本は [PROCESS.md](../deliver/PROCESS.md) である。
この skill は**polish 固有の差分だけ**を持つ。

## 手順

**どの手順よりも先に読む**: 対象 project の知識が knowledge repository に
あるなら、**index だけを読む**のが既定である。読むのは `library/index.md` と、
対象 project の `projects/<name>/index.md`。リンク先は関係するときだけ辿る
(辿り方は `knowledge-read` skill が持つ)。**その index からこの project の
テスト戦略を読み、それに従う** — 無ければ GLOBAL.md「テスト」の default に
従う。polish は戦略を決める側ではなく従う側である。
読んでも曖昧なときだけ knowledge へ質問する。聞く前に読む。

1. **方針を独立にすり合わせる (実装前・1往復)**: 実装は、この skill を発火した
   pane の runtime が担う。skill の効果は発火 pane に留まるので、実装を他の
   runtime へ投げ直すことはできない (担当の選択は構造上存在せず、既定担当と
   指名待ちが無い)。これは**投げる側の制約であって、受け取る側の制約ではない**。
   **担当は、その assignment を現に保持している者である。** user の依頼が
   中継されて届いたなら、それは user が言ったことなので、
   **user に同じことを言い直させない** — そのまま着手する。
   レビュワーは**同期召喚する `codex exec` の1プロセス**である。起動形・schema・
   所有者・fallback は
   「[レビュワー召喚 (codex exec)](../deliver/CONTRACT.md#レビュワー召喚-codex-exec)」。
   planning 召喚を**1回だけ**起動し、
   **user 原文 (verbatim)・確認済みの事実・制約だけ**を渡して
   「あなたならどう直す計画を立てるか」を求める。送るのは1通だけ。
   `$result` を読む前に自案を確定させる。`$result` は user 目的へ照合する。
   - **最初の brief に自分の案を入れない。** 完成した案を見せると相手は
     一つの枠内での粗探しに固定され、第二の設計空間が探索されなくなる。
   - 確認済みの事実に**設計判断を混ぜない** (現状・制約・再現証拠だけ)。
     混ぜるとアンカリングが復活する。
   - **同じターンで自分の案を起草する**。同期召喚では `$result` が同じ turn に
     返るので、順序では独立性が守られない。**召喚を起動する前に自案を会話内で
     確定させ、`$result` はその後に読む**という規律で守る。
   - 求める項目は各1〜数行: 不満の理解 / 最小修正 / 回帰証拠 /
     UX 退行の懸念・疑問。schema の `dissatisfaction` / `minimal_plan` /
     `regression_evidence` / `ux_risks` に対応する。
   - `minimal_plan` には、機構と user 要件の対応表・削れる機構・外側の
     合成で守る案も求める
     (「[最小性](../deliver/CONTRACT.md#最小性-blocking)」)。
   - **reconcile が終わるまでテストと実装を編集しない。**
   すり合わせの詳細は
   「[方針すり合わせの判定軸](../deliver/CONTRACT.md#方針すり合わせの判定軸)」。
2. **不満を契約にする**: frontend sources の修正が必要だと判断できたときだけ、
   先に `frontend-design` skill を完全に読む。対象は browser-rendered frontend
   sources (HTML, CSS, JavaScript, or Svelte) である。そこにある UI surface
   判定・Project design authority・実装規則を適用する。拡張子や「使い勝手」
   だけでは発火しない。CLI/TUI・terminal 出力のみ・Node backend 専用
   JavaScript・設定・docs・test-only は対象外。
   修正が必要だと確認できなければ使わない (迷ったら適用しない)。未解決の
   視覚・操作判断や design contract の変更がある場合だけ `designer` を呼び、
   その brief を契約へ含める。
   そのうえで統合した方針を、観測可能な達成条件に変換する
   (最大5行)。user 原文は verbatim で保持する。ledger の JSON 儀式は作らない。
   独立提案の交換は step 1 の1往復だけで、統合案の再承認・二段階照合は行わない。
   規模が大きくても追加号令を求めず、この delivery の内側で続行する。
3. **基線正規化 (条件付き・最大1回)**: 契約化の直後、delivery 作業を始める前に
   行う。worktree と protected path (既存の user 差分) を snapshot する。
   protected snapshot は後段 gate の scope 保護に使う。repo に意味保存契約の
   ある formatter があるとき、影響範囲が分かるならその workspace に限定して
   check を走らせる。検出するのは legacy の整形差分だけである。
   差分が無ければこの step は no-op (既定の見た目は従来どおり delivery 1 commit)。
   差分があるときだけ、次を**すべて**満たす場合に限り、専用の
   `style: normalize formatting` commit を**最大1個**先行させてよい。
   - **worktree が clean 開始であること** (style commit は clean 開始に限定)
   - first-party source のみ。generated・vendor は除外
   - stage するのは formatter 由来 path だけ (path 単位)
   - 関連する既存 tests が green
   - **既存 user 差分が 1 byte でもあれば自動 commit 禁止**。黙って無視せず、
     path・理由・解消担当を blocking recovery として返し、独立 baseline
     delivery として可視化して引き継ぐ
   授権は **`$polish` 明示起動 (または同等の polish 段階配達) の内側**に限定する。
   tracked な fingerprint marker ファイルは新設しない。使った tool / version /
   config / 対象集合は receipt か style commit の説明に残す。真実源は実際の
   check 結果とする。専用 runner script がまだ無いときは repo-native の
   formatter コマンドを直接実行する (未実装の script 名を前提にしない)。
4. **直す**: 最小の変更で不満を解消する。実装の途中で全面的な作り直しが
   必要だと判明しても、追加号令や段階の切り替えで止めない。書きかけの変更は
   破棄せず、この delivery の内側で続行する。step 1 で大きな
   再設計が見つかった場合も同じである。
5. **検証する**:
   - 変更に隣接する既存チェック (テスト・build・lint) を repo 標準コマンドで
     実行する。存在しないものを新設しない。
   - 直したバグ1件につき回帰テスト1本を実用的な範囲で追加する。
     困難なら理由を receipt に1行で書く。対象は**実行可能コード**のバグに
     限る。Markdown・設定・docs の修正に回帰テストは作らない
     (GLOBAL.md「テスト」)。
   - 適用可能な repo-native formatter/linter だけを実行し、非適用/不在は理由付き N/A として記録する。
     独立な formatter 役職ゲートは立てない (機械的な自己実行であり、
     役職分離ではない)。tooling bootstrap は非目標。
   - UI surface 変更では、変更したstateを影響するviewportとinputで実ブラウザ
     実測する。見た目・interactionの不満は `ui-checker` にcriteriaごとのevidenceを
     求める。
6. **commit 前 gate とレビュー**: まず **commit 前 mechanical gate** を通す
   (commit とレビュー送信の門)。検証 step の再掲義務ではない。
   **この門は経路によらず必須である**。repo-native で
   format → lint check → 回帰+隣接 tests → `git diff` / status 再検査を明示実行する。
   **適用可能な repo-native formatter/linter だけを実行し、非適用/不在は理由付き N/A として記録する。実行対象の nonzero は commit とレビュー送信を止める**。
   成功を current diff と結んで receipt に残す。**nonzero なら先へ進まず
   修正へ戻る**。専用 runner が後から用意されたらそれに置換してよいが、
   未実装 script を参照して止まってはならない。tooling bootstrap は非目標。
   門を通したあとの独立実装レビューは、所有者が経路で決まる
   ([PROCESS.md](../deliver/PROCESS.md#レビュー工程の所有者))。
   - **pipeline 所有が明示的に宣言されているときは、レビュー召喚を行わない。**
     独立実装レビューは control plane の review 工程が所有する。門だけ通して
     手順 7 へ進む。
   - **宣言が無ければ local 所有である** (推測しない)。実装レビュー召喚を
     起動し、user 原文 (verbatim)・diff・達成条件・実行済みの検証結果を渡す。
     `blocking` で source を直したら **gate を再実行してから**再検証召喚を
     起動し、**`verdict` が `pass` になるまで巡回する**。それ以外は記録して進む。
   召喚の種類・所有者・巡回・検査項目・fallback は
   「[レビュワー召喚 (codex exec)](../deliver/CONTRACT.md#レビュワー召喚-codex-exec)」。
7. **コミットする**: 1 invocation = **0または1個の prerequisite formatting
   commit + ちょうど1個の delivery commit**。既定 (基線 no-op) は delivery 1
   個のみ。message は `git` skill の規則に従う (1 行のみ、経緯は knowledge
   へ)。style commit と delivery を混ぜない。
   知識棚卸しは行わない。
8. **報告する**: 解消した不満と証拠、残る不満、追加した回帰テスト、review の
   結果、style commit の有無を短く返す。
   方針すり合わせとレビューについては次を残す:
   **独立実装レビューをどちらの経路で行ったか (local / pipeline)**、
   **召喚回数と各召喚の schema 判定**
   (planning は採否、実装レビューは `verdict` と `blocking` の件数。
   local 所有なら巡回した回数も残す)、
   **未解消の blocking の残件**、
   **fallback の有無と `review_exec_failed` の理由**、
   **user の目的とのズレの有無と是正内容**、原文中の目的と手段を
   どう切り分けたか、**手段を置き換えた場合はその内容と理由**、採用した手段と
   採否理由。
   **最小性の証跡**は最終的な計画についてだけ短く残す: 機構の一覧と user 要件
   への対応付け、削った機構、外側の合成を選んだか内側に持ったか (内側なら
   理由)、範囲外として follow-up へ落とした指摘とその理由。検討の過程は
   書かない。

## 続行

secret・権限境界・破壊的データ・version・将来のリリース可能性を理由に、
作業を止めたり追加号令を求めたりしない。止めてよいのは第三者への迷惑か
犯罪行為のときだけである。polish のまま磨き続ける。

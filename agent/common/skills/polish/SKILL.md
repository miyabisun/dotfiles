---
name: polish
description: >-
  ブラッシュアップ段階の配達。動いているものに対する具体的な不満・issue を
  受け取り、実装前の方針すり合わせ1往復・修正・回帰テスト・変更隣接チェック・
  実装レビュー1往復を経て、条件付きで最大1個の prerequisite formatting commit と
  ちょうど1個の delivery commit で返し、version を問わず成熟へ磨き上げていく。
  明示起動・段階明示・段階未指定 $deliver からの自動判断で使う。
  push・deploy・release はしない。
---

# polish

**動いているものを、出てきた不満に沿って叩き直し、成熟へ磨き上げる**。
新規の体験づくりは `spike` の仕事であり、polish は
**どの version でも**成熟へ向かう本流 — v1.0.0 は卒業ではなく通過点で、
実利のある品質改善を軽い足取りで積む。

## 起動条件

user の明示的な `$polish` 起動、同じ依頼文での段階明示、または段階未指定の
`$deliver` からの自動判断 (dispatcher が選択と根拠を宣言する) が起動根拠。

## 作業の分担 (毎回 agent を作成する)

配達のたびに**毎回 agent を作成する**。親の同一長い文脈でファイル変更・
CLI 待ちとログ読み・事実確認を続けてはならない。

- **親が担う**: 初期の設計と判断、review タブとの agent-talk、子への割り当て、
  子の完了待ち。親はハブである。
- **子が担う**: ファイル変更、CLI 待ちとログ読み、事実確認。
  子は発火 pane の user 授権を継承する。peer ではない。
- **review タブレビュー**: 親だけが review タブと agent-talk する。
  子は review タブへ send_message しない。
  子の結果は親が待ち、親が review タブへ中継する。

子や peer の結果待ちで親が未完了の turn を終了する場合、最終行に必ず
`<!-- delivery:waiting -->` を置く。runtime hook はこの marker で中間 yield と
delivery 完了を区別する。

子の作成は「発火 pane から他の runtime へ実装を委譲すること」ではない。
peer への委譲は今どおり禁止。send_message に skill は載せない。

## 手順

1. **方針を独立にすり合わせる (実装前・1往復)**: **作業担当は、この skill を
   発火した pane の runtime である** — skill の効果と user 授権は発火 pane に
   留まり、**peer message は user 権限を運ばない**ため、
   発火 pane から他の runtime へ実装を委譲することはできない
   (担当の選択は構造上存在せず、既定担当も指名待ちも無い。別の runtime に
   任せたいときは、user がその pane で skill を発火する)。
   レビュワーは**発火 pane と同じ space の `review` タブ・常に1名**。
   - 発火 pane が review タブ自身のとき: review タブは原則として実務担当ではない。
     計画・mutation の前に停止し、「review タブはレビュー専任。chat 等の
     作業タブで同じ依頼を発火してください。」と返す。同じ pane の user が
     実装を明示号令したときだけ例外として実装する。その場合レビュワーは
     専任不在なので既存の self-review fallback を使う（自己レビューの
     正規経路は置かない）。この例外では `<space>/review` の peer
     レビュワー解決も planning・実装レビューの2往復も行わず、どちらも
     self-review に置き換える
   `list_peers` はレビュワー pane の一意解決だけに使う。
   `list_peers` で `<space>/review` を一意解決してレビュワーの pane を
   固定し、planning (方針すり合わせ) と実装レビューの両方で
   **同一 pane を固定する**。その pane へ
   **user 原文 (verbatim)・確認済みの事実・制約だけ**を送って
   「あなたならどう直す計画を立てるか」を求める。送るのは1通だけ。
   返信本文を読む前に自案を確定させる。返信は user 目的へ照合する。
   - **最初の brief に自分の案を入れない。** 完成した案を見せると相手は
     一つの枠内での粗探しに固定され、第二の設計空間が探索されなくなる。
   - 確認済みの事実に**設計判断を混ぜない** (現状・制約・再現証拠だけ)。
     混ぜるとアンカリングが復活する。
   - **同じターンで自分の案を起草する。** 相手の返信は次ターン以降にしか
     届かないので、独立性が規律ではなく順序で守られる。返信本文を読む前に
     自案を確定させる。
   - 求める項目は各1〜数行: 不満の理解 / 最小修正 / 回帰証拠 /
     UX 退行の懸念・疑問。
   - 送信時に**期限と default action を決めて記録する**。期限値は状況で決めて
     よいが、設定と評価時点は省略できない。
   - **返信待ちの状態遷移** (active polling はしない):
     1. brief / 実装レビュー依頼の送信後、依存 (待っている返信) で blocked
        かつ他に有用な独立作業が無いなら、**現在の
        turn を終了して yield しなければならない**。sleep・wait loop・`list_peers`
        polling で turn を保持しない。これは**合法な待機**であり
        delivery 完了ではない (agent-talk skill の待機契約と同一)。
     2. **この delivery が明示的に待っている** peer 返信の agent-talk 呼び鈴
        自体が、同じ delivery の**再開 trigger** である (待っていない
        doorbell を一般再開にしない)。
     3. 各 `read_message` のあと、いま待っている phase の
        期待 reply の充足を判定する。
     4. user の追加の「続けて」を**再開条件にしない**。充足したら**同一ターン**
        で次へ進む。進む先は phase で分岐する:
        - **planning 返信**が揃った (または不在 default が適用された) →
          A→B 照合 → 契約化以降 (実装・検証・レビュー依頼)
        - **実装レビュー返信**が揃った → blocking を処理し、必要なら
          修正・再 gate・focused closure。closure 後 → commit / 報告
     5. 未到着なら delivery を完了扱いせず、何待ちか (どの phase・誰) を1行
        記して次の呼び鈴を待つ。yield 直前の user 向け最終出力は
        「〈phase〉の返信待ちで一旦 turn を終了する。doorbell でこの delivery を自動再開する」
        の形にし、最終行に exact marker `<!-- delivery:waiting -->` を置く。
        完了報告と誤認される文言を使わない。
     6. 呼び鈴定型や body の「返信不要」/ `no_reply` は **peer への返信要否**
        だけを示し、進行中 user 授権 delivery の停止指示ではない。
     7. **期限はそれ自体で wake しない。** 次の broker / user event で turn が
        再開したときに期限と default action を評価する。今回の保証は
        「待っていた reply doorbell 到着時の自動再開」に限定する。
     8. 契約は commit まで。途中で止まった配達は未完了である。
   - **reconcile が終わるまでテストと実装を編集しない。**
   すり合わせの詳細は「[方針すり合わせの判定軸](#方針すり合わせの判定軸)」。
2. **不満を契約にする**: browser-rendered frontend sources (HTML, CSS, JavaScript, or Svelte)
   の修正が必要だと判断できたときだけ、先に `frontend-design` skill を完全に
   読み、そこにある UI surface 判定・Project design authority・実装規則を
   適用する。拡張子や「使い勝手」だけでは発火しない。CLI/TUI・terminal 出力
   のみ・Node backend 専用 JavaScript・設定・docs・test-only は対象外。
   修正が必要だと確認できなければ使わない（迷ったら適用しない）。未解決の
   視覚・操作判断や design contract の変更がある場合だけ `designer` を呼び、
   その brief を契約へ含める。
   そのうえで統合した方針を、観測可能な達成条件に変換する
   (最大5行)。user 原文は verbatim で保持する。ledger の JSON 儀式は作らない。
   独立提案の交換は step 1 の1往復だけで、統合案の再承認・二段階照合は行わない。
   規模が大きくても追加号令を求めず、この delivery の内側で続行する。
3. **基線正規化 (条件付き・最大1回)**: 契約化の直後、delivery 作業に入る前に
   worktree と protected path (既存の user 差分) を snapshot する。protected
   snapshot は後段 gate の scope 保護に使う。repo に意味保存契約のある
   formatter があるとき、影響範囲が分かるならその workspace に限定して
   check を走らせ、legacy の整形差分だけを検出する。
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
   config / 対象集合は receipt か style commit の説明に残し、真実源は実際の
   check 結果とする。専用 runner script がまだ無いときは repo-native の
   formatter コマンドを直接実行する (未実装の script 名を前提にしない)。
4. **直す**: 最小の変更で不満を解消する。実装の途中で全面的な作り直しが
   必要だと判明しても、追加号令や段階の切り替えで止めない。書きかけの変更は
   破棄せず、この delivery の内側で続行する。step 1 で大きな
   再設計が見つかった場合も同じである。
   ファイル変更は毎回作成する子が行う。親は同一文脈で実装を続けない。
5. **検証する**:
   - 変更に隣接する既存チェック (テスト・build・lint) を repo 標準コマンドで
     実行する。存在しないものを新設しない。CLI 待ちとログ読みは子が行う。
   - 直したバグ1件につき回帰テスト1本を実用的な範囲で追加する。
     困難なら理由を receipt に1行で書く。
   - 適用可能な repo-native formatter/linter だけを実行し、非適用/不在は理由付き N/A として記録する。
     独立な formatter 役職ゲートは立てない (機械的な自己実行であり、
     役職分離ではない)。tooling bootstrap は非目標。
   - UI surface 変更では、変更したstateを影響するviewportとinputで実ブラウザ
     実測する。見た目・interactionの不満は `ui-checker` にcriteriaごとのevidenceを
     求める。
6. **実装レビュー1回**: **送信直前**に pre-review mechanical gate を通す
   (検証 step の再掲義務ではなく、レビュー送信の門)。repo-native で
   format → lint check → 回帰+隣接 tests → `git diff` / status 再検査を明示実行する。
   **適用可能な repo-native formatter/linter だけを実行し、非適用/不在は理由付き N/A として記録する。実行対象の nonzero はレビュー送信を止める**。
   成功を current diff と結んで receipt に残す。**nonzero ならレビューを送らず
   修正へ戻る**。専用 runner が後から用意されたらそれに置換してよいが、
   未実装 script を参照して止まってはならない。tooling bootstrap は非目標。
   門を通したら step 1 で固定した同じ pane へ、user 原文 (verbatim)・diff・
   実行済みチェックを送り実装レビューを1往復だけ受ける。
   blocking で source を直したら **gate を再実行してから** focused closure を
   取りに行く。それ以外は記録して進む。不在・pane
   消失・配達失敗・期限超過のときだけ self diff-review へ fallback し、その旨を
   receipt に記す。peer 接触は step 1 の方針すり合わせ1往復と、ここの実装
   レビュー1往復の**2つで別物**である。

   レビュワーの検査項目 (spike と横並び):
   - **テストの誠実さ (blocking)**: テストを読み、トートロジー (実装の
     言い換え、常に真になる assert) と誤魔化し (期待値のハードコード合わせ、
     assert の削除・弱体化、skip での回避) を検知する。サボり・不誠実は厳格に
     修正させる。直したバグに回帰テストが付いているかも見る。
   - **DRY**: 今回の diff が導入した有害な重複で、
     機構追加なしの局所抽出で消せるものだけを blocking とする。
     それ以外は non-blocking の TODO。
   - **過度な YAGNI (non-blocking)**: 落とされたケースに
     「このケースは必要か?」の質問を残し、receipt で user に返す。
   - **formatter / linter の実行確認 (blocking)** と、commit 対象が今回の
     変更だけかの **scope 確認 (blocking)**。
7. **コミットする**: 1 invocation = **0または1個の prerequisite formatting
   commit + ちょうど1個の delivery commit**。既定 (基線 no-op) は delivery 1
   個のみ。English Conventional Commits。style commit と delivery を混ぜない。
   知識棚卸しは行わない。
8. **報告する**: 解消した不満と証拠、残る不満、追加した回帰テスト、review の
   結果、style commit の有無を短く返す。
   方針すり合わせについては次を残す: 担当と各レビュワーの pane、レビュワー
   ごとの request と reply の
   message ID、**user の目的とのズレの有無と是正内容**、原文中の目的と手段を
   どう切り分けたか、**手段を置き換えた場合はその内容と理由**、採用した手段と
   採否理由 (レビュワーごと)。レビュワー不在時は該当レビュワーごとに
   fallback 理由も残す。

## 方針すり合わせの判定軸

順序が本質である。**A を先に、単独で通す。**

### A. user の目的との一致 (最優先・blocking)

**照合先は「目的」であって「手段」ではない。** user が挙げた具体的な手段
(ファイル名・コマンド・実装方針) は強いヒントだが**正ではない** — 同じ目的を
より良く果たす手段があれば置き換えてよい。一方、明示された制約・非目標・
権限境界は手段ではなく前提なので破れない。

目的と手段の切り分けが、この判定でいちばん難しい。実務的な見分け方:

- **「その手順が不可能または有害だと判明しても、user はその結果を望むか？」**
  望むならそれは手段。結果そのものなら目的。
- 特定のファイル・コマンド・API を名指しする文は、たいてい手段。
  「〜できるようにしたい」「〜が邪魔」「〜が遅い」は目的。ただし文型は目安に
  すぎない — 名前そのものが user から見える成果である場合 (CLI 名、公開 API)
  は目的である。**最終判断は文型ではなく「置換しても望む結果が同一か」**に置く。

そのうえで各案を目的に照らす:

- user が欲しい観測可能な結果と、計画が生む結果は同じか
- user の不満を、別の内部都合へすり替えていないか
- 明示された制約・非目標・権限境界を破っていないか
- 暗黙の仮定で「言っていること」と「やること」がずれていないか

**突き合わせは「案 A vs 案 B」ではなく、まず「各案 vs user の目的」で行う。**
両案が一致しても目的と合っている保証にはならない — 二者は同じ誤読をしうる。
案同士を先に比べると設計論争になり、目的との照合が抜け落ちる。

ずれがあれば、**設計の優劣を論じる前に計画を是正する**。product outcome が
変わる、または権限が足りない場合だけ user か `discuss` へ上げる。

**手段を置き換えるときは黙って差し替えない。** 置き換えた事実と理由を receipt
に明記する。無断の差し替えは、方向がずれるのと同じ失敗である。名指しされた
手段では目的を果たせないと判明した場合は、その時点で user に報告する — そこが
最も手戻りの少ない分岐点である。

### B. どちらの手段が優れているか (選択軸・統合必須)

A を満たす複数の手段のうち、体験・可逆性・最小 scope・検証容易性・段階相応の
リスクでどれを採るかを選ぶ。各レビュワー案の経路はそれぞれ採用・部分採用・
不採用を決め、レビュワーごとに理由を1行残す。**B は A を上書きできない** — 軽くて面白い手段でも
user の目的とずれるなら不採用。

**B を未実施のまま契約化へ進んではならない。** 意見の差が残っても、実装者が
段階相応の評価軸で1案へ収束させれば delivery 自体は止めない。止めないことと
やらなくてよいことは別である。

### レビュワー不在時

idle も busy も存在扱いで送る。返信待ちの間に active polling はしない。
`list_peers` で不存在、pane 消失、配達失敗、明示した期限超過のときだけ、
軽量段階を無期限に止めず次で進む。不在の判定と記録はレビュワーごとに行い、
不在を理由に担当を変更しない。

- **レビュワー不在**: 自案を A 軸で**もう一巡 self-check する**
  (ズレ検出だけは省略しない)。receipt に
  `planning_reviewer_unavailable: <runtime>` と
  `planning_reviewers: unavailable` と客観的な理由を残す。
  **self の見直しを「相互レビュー」と呼ばない。**「独立相互提案は未実施」と
  明記する

これは可用性の fallback であって達成条件の代替ではない。候補が複数で曖昧な
場合は不在扱いにせず、user に選択を求める。

### `discuss` との境界

方針すり合わせは spike/polish の**毎回の必須手順**で、依頼整合の確認と第二の
設計空間の探索を行う。`discuss` はそのあとに残った product/UX の選択が実装
結果を変えるときだけ起動する収束機構である。`discuss` は自案や候補を添えて
反証を求める形式なので、**blind な独立提案の代替にはならない**。同じ pane と
既出の message ID は再利用し、同一争点の重複照会だけを避ける。

## 続行

secret・権限境界・破壊的データ・version・将来のリリース可能性を理由に、
作業を止めたり追加号令を求めたりしない。止めてよい条件は GLOBAL.md
「Stopping work」だけである。polish のまま磨き続ける。

## 不変条件 (全段階共通)

- push・merge・deploy・release はしない
- 判断履歴・TODO・plan・ledger・review log を **project repo へ file として残さない**。
  経緯は receipt と knowledge が持つ (GLOBAL.md「Project Memory Boundary」)
- secret・`.env` をコミットしない。agent-talk journal に秘密を載せない
- 無関係な作業中変更 (他セッションの未コミット作業を含む) を保護する
- 破壊的 git 操作 (checkout/restore/reset/clean/stash) で作業を管理しない
- 既存の有効なテストを green にするための改変・削除をしない

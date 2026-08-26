---
name: spike
description: >-
  黎明期の最速試作。v0.1.0 のリリースを目指し、まず動かして画期的な体験を
  得る。契約儀式・セキュリティゲート・知識棚卸しは省くが、実装前に counterpart と
  方針を独立にすり合わせ、実行可能コードには TDD を死守 (テスト無き
  ゴールは存在しない)、formatter/linter は機械的に実行し、テストの誠実さと
  DRY を見る軽量な実装レビューを通す。明示起動・段階明示・段階
  未指定 $deliver からの自動判断で使う。push・deploy・release はしない。
---

# spike

目的はただ一つ: **最短で動くものを作り、体験を得る**。spike は
**v0.1.0 のリリースを目指す**段階である。バグを踏まれても「v0.1.0 だから」と
言える粗さで、まず世に出せる形へ向かう (リリース行為そのものは user が
`bump-tag` で行う)。抽象化・設定項目・将来対応・網羅的な堅牢性はあとの
`polish` が引き受ける。完成度は8割で止めてよく、やり残しは
**follow-up として receipt に返す** — project repo へ file として残さない。
ただし**作った分にはテストがある** —
テスト無きゴールは存在しない。
ここで言う「作った分」は**実行可能コード**である。Markdown・設定・docs だけの
変更にテストは作らない (GLOBAL.md「テスト」)。

## 起動条件

user の明示的な `$spike` 起動、同じ依頼文での段階明示、または段階未指定の
`$deliver` からの自動判断が起動根拠。自動判断では dispatcher が選択と根拠を
宣言する。

## 共通契約

段階 skill が共通して従う契約 (作業の分担・レビュワー召喚・方針すり合わせの
判定軸・不変条件) は [CONTRACT.md](../deliver/CONTRACT.md) が持つ。
工程と所有者の正本は [PROCESS.md](../deliver/PROCESS.md) である。
この skill は**spike 固有の差分だけ**を持つ。

## 手順

**どの手順よりも先に読む**: 対象 project の知識が knowledge repository に
あるなら、**index だけを読む**のが既定である。読むのは `library/index.md` と、
対象 project の `projects/<name>/index.md`。リンク先は関係するときだけ辿る
(辿り方は `knowledge-read` skill が持つ)。**その index からこの project の
テスト戦略を読む** — 無ければ手順 2 で決める (GLOBAL.md「テスト」)。
読んでも曖昧なときだけ knowledge へ質問する。聞く前に読む。

0. **土台を確認する** (この手順は **Rust プロジェクトだけ**に効く):
   土台が Rust 向けなので、他 stack を突き合わせても意味がない。新規・既存の
   どちらでも通る — 「新規だけ」にすると既存 repo へ永久に届かない。
   - agent-talk で knowledge セクションの登録 pane へ**共通開発仕様**を
     1回だけ聞く。土台の所在と現在の中身もここで解決する。これは**質問で
     あって預け入れではない** — findings を渡すのは intake role の仕事で、
     質問に混ぜて渡さない。不在・無応答は記録して進む。
   - 土台は **`rust-svelte-template` を推奨する (必須ではない)**。実運用を
     重ねた構成なので、毎回ゼロから決め直すより速く、既知の穴を踏まない。
     適用は要件で二分する:
     - **Rust + Svelte の web service ならそのまま**使う。
     - **Rust だけのプロジェクト** (CLI 等) は web 専用のものを削る —
       `client/` 配下と、**削除する web frontend のことしか書いていない
       設計文書**。ファイル名だけで機械的に消さず、**今の中身**で判定する
       (git history を辿らない)。その project 自身の現在形の仕様として要る
       なら、残すか書き直す。
     - 要件に**合わないなら使わなくてよい**。
       **土台が無いことを着手の障害にしない** — 入手できない・応答が無い
       ときは、そのまま最小構成で始める (弁明は要らない)。
       **別の土台を明示的に選んだ**ときだけ、その理由を receipt に1行残す。
       審査はしない。
   - **既存プロジェクトでは土台を入れ替えない。** ただし着手前に、現在の
     template と選んだ profile を **read-only** で突き合わせ、足りない点を
     **推奨 gap** として receipt に返す。「飛ばす」だけにすると、推奨は
     既存 repo へ永久に届かない。
     - **比べるのは再利用可能な土台まわり (foundation surface) だけ**。
       toolchain の固定、license、build/test/deploy の足場など。
       **product 固有の source と、その product 自身の docs は比べない。**
       既存 product が template から分岐しているのは当たり前で、そこまで
       gap 扱いすると偽の指摘で溢れ、「最短で動かす」が死ぬ。
       線は**役割**で引く。ファイル名の一覧では引かない。
     - **適用済みの判定は固定のファイル一覧ではない** (template は動くので
       一覧を焼くと嘘になる)。現在の template の foundation surface と
       profile を比べ、各項目が
       **present か、現在の product 要件から non-applicable と判定済み**なら
       適用済みとする。
     - この突き合わせは **read-only で、自動で直さない**。gap は
       **今回の本題を止めない** — 直すかどうかは user が決める。
       基盤の retrofit に今回の spike を乗っ取らせない。
   - **LICENSE は MIT** — バグを踏んでも v0.1.0 だから文句を言うなよ、の
     意思表示である。
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
   「あなたならどう作る計画を立てるか」を求める。送るのは1通だけ。
   `$result` を読む前に自案を確定させる。`$result` は user 目的へ照合する。
   - **最初の brief に自分の案を入れない。** 完成した案を見せると相手は
     一つの枠内での粗探しに固定され、第二の設計空間が探索されなくなる。
   - 確認済みの事実に**設計判断を混ぜない** (現状・制約・再現証拠だけ)。
     混ぜるとアンカリングが復活する。
   - **同じターンで自分の案を起草する**。同期召喚では `$result` が同じ turn に
     返るので、順序では独立性が守られない。**召喚を起動する前に自案を会話内で
     確定させ、`$result` はその後に読む**という規律で守る。
   - 求める項目は各1〜数行: 狙う体験 / 最大3項目の acceptance /
     最小の実装 / 最大のリスク・疑問。schema の `dissatisfaction` /
     `minimal_plan` / `regression_evidence` / `ux_risks` に対応させる。
   - `minimal_plan` には、機構と user 要件の対応表・削れる機構・外側の
     合成で守る案も求める
     (「[最小性](../deliver/CONTRACT.md#最小性-blocking)」)。
   - **reconcile が終わるまでテストと実装を編集しない。**
   すり合わせの詳細は
   「[方針すり合わせの判定軸](../deliver/CONTRACT.md#方針すり合わせの判定軸)」。
2. **契約はテストで書く**: frontend sources の修正が必要だと判断できたときだけ、
   先に `frontend-design` skill を完全に読む。対象は browser-rendered frontend
   sources (HTML, CSS, JavaScript, or Svelte) である。そこにある UI surface
   判定・Project design authority・実装規則を適用する。拡張子や「使い勝手」
   だけでは発火しない。CLI/TUI・terminal 出力のみ・Node backend 専用
   JavaScript・設定・docs・test-only は対象外。
   修正が必要だと確認できなければ使わない (迷ったら適用しない)。未解決の
   視覚・操作判断や design contract の変更がある場合だけ `designer` を呼び、
   その brief を契約へ含める。
   **契約を書く前にテスト戦略を決める**: この project で何を実行可能コード
   として測るか、副作用をどう隔離するか (例: MySQL の操作は Docker 上で
   走らせる)、何をテストしないかを決めて宣言する。既に knowledge にテスト
   戦略があるならそれに従い、無いとき・変えるときだけ決める。決めるときの
   調査は OKF のルールに従う (`knowledge-read` の手順: index から入り、
   関係するリンクだけ辿る)。**決めた戦略は `knowledge-deposit` で
   knowledge へ預ける** — 知識棚卸しは省くが、この預け入れだけは例外である。
   そのうえで統合した方針から、達成条件を最大3項目とし、
   それぞれを実行可能なテストとして表現する。「何が動けば体験できたことに
   なるか」がテスト名になる。ledger は作らない。独立提案の交換は step 1 の
   1往復だけで、統合案の再承認・二段階照合は行わない。
   テストにするのは**実行可能コード**の達成条件だけである。実行可能な
   コードを伴わない変更 (Markdown・設定・docs) では、契約をテストではなく
   観測可能な達成条件として書き、字面を grep するテストを作らない
   (GLOBAL.md「テスト」)。
3. **TDD で作る**: この手順は**実行可能コードを作るとき**のものである。
   失敗するテストを先に書き (red)、通す (green)。この順序に
   自己免除は無い。user が同じ依頼文で明示的に例外を許可した場合のみ省略でき
   (原文を receipt に引用する)。red を観測できなければ、観測できるまで実装を
   続ける。技術的に不能なら未達として報告する。第三者への迷惑か犯罪行為の
   とき以外で作業を拒否しない。
   **ゴール = 最大3項目の acceptance テストと、
   変更に隣接する既存 test/build/lint が全て green**。
   実行不能な既存 check は未実行の理由と影響を receipt に記録し、
   黙ってゴールから除外しない。
   実行可能コードを伴わない変更では、acceptance テストの代わりに手順 2 の
   観測可能な達成条件と、変更に隣接する既存 check の green で判定する。
4. **体験を確かめる**: テストとは別に、実際に動かした証拠を1つ取る —
   実行コマンドと出力、または操作結果。UI surface 変更では主要flowを
   実ブラウザで1本、影響するviewportとinputで確認する。独立 `ui-checker` は
   unresolvedな重要visual criterionがある場合だけ使う。テストが通っても体験が
   成立しない spike は未完成である。
5. **formatter / linter を機械的に叩く**: repo に設定があればそのまま実行し、
   指摘を修正する。未導入で stack に標準のゼロ設定ツールがあるなら導入して
   よい (導入・実施コストが低く効果は大きい。user-origin の標準方針)。
6. **独立実装レビュー**: この工程の所有者は経路で決まる
   ([PROCESS.md](../deliver/PROCESS.md#レビュー工程の所有者))。
   - **pipeline 所有が明示的に宣言されているときは、この手順を行わない。**
     独立実装レビューは control plane の review 工程が所有する。ここで召喚を
     重ねると二重レビューになる。
   - **宣言が無ければ local 所有である** (推測しない)。実装レビュー召喚を
     起動し、user 原文 (verbatim)・diff・達成条件・実行済みの検証結果
     (テスト・実行証拠) を渡す。`blocking` を直したら再検証召喚を起動し、
     **`verdict` が `pass` になるまで巡回する**。それ以外は記録して進む。
   召喚の種類・所有者・巡回・検査項目・fallback は
   「[レビュワー召喚 (codex exec)](../deliver/CONTRACT.md#レビュワー召喚-codex-exec)」。
7. **コミットする**: 既定は 1 invocation = 1 local commit。複数 checkpoint
   commit は、起動時の user 依頼文が明示的に許可した場合のみとする。許可された
   場合は、その原文を receipt に引用し、件数と各 scope を報告する。message は
   `git` skill の規則に従う (1 行のみ、経緯は knowledge へ)。
8. **報告する**: 何が動くか、テスト結果、動作証拠、残した TODO と
   non-blocking の質問リスト、次に polish すべき点を短く返す。
   **v0.1.0 readiness の確認も完了条件に含む**: 新規プロジェクトの該当
   manifest (Cargo.toml 等) は version が 0.1.0 であること、MIT LICENSE と
   土台の不要物除去が済んでいること、そして**リリースを妨げる既知事項**を
   receipt に列挙する (release/push 自体は行わない — それは user の
   `bump-tag`)。既存プロジェクトでは version を書き換えず、現在値だけを
   receipt に記録する。bump 水準の推奨・判定はしない — 水準の決定は user の
   `bump-tag` だけが担う。
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

## spike のレビュー範囲

レビュワー (`codex exec` 召喚、または fallback の self review) の検査項目は
[CONTRACT.md の検査項目](../deliver/CONTRACT.md#実装レビュー-prompt-に書かせる検査項目)
に限定する。
ここに無い観点 (網羅的堅牢性・性能・美観) は spike では扱わない。

## 続行

secret・権限境界・破壊的データ・version・将来のリリース可能性を理由に、
作業を止めたり段階を切り替えたりしない。止めてよいのは第三者への迷惑か
犯罪行為のときだけである。

project の version がいくつでも **spike は spike のまま進む**。version を
理由にした判定や注記の儀式は追加しない。version file は変更しない —
bump 水準の決定 (major を含む) は user の `bump-tag` だけが担う。
spike 自身は push しない。

---
name: discuss
description: フェーズ (spike/polish/harden) で性格を切り替える議論スキル。spike はワクワクする方向へ広げるブレスト、polish は UX を損なわない解決策の探索、harden はセキュリティと外部エンジニアの評価に耐える収束 (decision receipt+A〜F)。明示引数か呼び出し元 skill でフェーズを解決し、単独起動の未指定は議題の性質から spike / polish を自動判断する (迷ったら polish)。harden フェーズは明示引数か、号令で起動済みの harden の内側からの呼び出しのみ (decision 0004)。不可逆な変更、権限境界の変更、binding instruction との競合、複数 agent 間の重要判断は harden 級の兆候として進言対象。
---

# discuss

議論の目的はフェーズで変わる (decision 0002 の3段階に対応)。spike では広げ、
polish では UX を守り、harden では外の目に耐えることを確かめる。共通するのは
「議論を仕事の代わりにしない」ことだけであり、どのフェーズも次の一手に着地して
終わる。harden の成功指標は従来どおり、**会話履歴を持たない実装者が blocking
question ゼロで着手できること**。

## フェーズの解決

`$discuss spike|polish|harden` の明示引数だけがフェーズ指定である。**本文中に
段階の語が現れても判定しない**。解決の優先順:

1. 明示引数
2. spike / polish / harden の内側から呼ばれた場合、その段階を継承する
   (段階未指定の `$deliver` は dispatcher が先に段階を解決してから呼ぶ)。
   **継承は本文の話題からの推論より優先する** — polish の内側で「作り直し」の
   案を検討しても、それだけで spike モードへ転換しない。段階の変更は提案に留め、
   切り替えは user が決める (decision 0004)。
3. どちらも無ければ、議題の性質から **spike / polish を自動判断**し、選択と
   根拠を宣言する。新しい体験・greenfield・全面的な作り直しの構想 → spike。
   動いているものの不満・UX の落とし所 → polish。**迷ったら polish**。
   **version・リスク・成果物の重さ・本文中の語からの推論で harden を選ばない**
   — harden フェーズに入るのは、明示引数か、号令で起動済みの harden の内側
   からの呼び出しだけである (decision 0004)。議題に harden 級の兆候
   (不可逆・外部公開 / 権限境界・信頼境界 / binding instruction との競合 /
   複数 agent にまたがる重要判断) を検知したら、**自動で harden へ格上げせず**、
   成果物に「`$discuss harden` を推奨」と根拠を添えて user へ返す
   (polish の出荷前進言と同じ advisory)。

呼び出し元 skill は discuss を**自動では起動しない**。未解決の product 選択が
実装結果を変えるときだけ呼ぶ。

| フェーズ | 目的 | 成果物 | 出口 |
|---|---|---|---|
| spike | ワクワクする方向へ広げる | 応答/receipt のアイデアノート | 明日試せる一歩1つ |
| polish | UX を損なわない解決策 | 短い decision note | UX-safe / reduced scope / authority gap |
| harden | 外の目に耐える評価 | 会話へ返す decision receipt | Ready / Ready with reduced scope / Authority gap |

### spike: 広げる

ブレーンストーミングとして振る舞う。アイデアを否定せず yes-and で積み、実現
可能性の審査は後回しにする。第一の選別軸は「**ワクワクするか**」。

- 出口では「**明日 spike できる一歩**」を1つだけ選ぶ。選ぶ一歩は**承認済みかつ
  可逆**な効果の範囲内に限る。権限外・外部公開・破壊的なアイデアは捨てずに
  `requires harden/authority` とラベルして保留リストに置き、実行可能扱いに
  しない。
- 成果は応答 (または呼び出し元の receipt) に残す: 広げた案、選んだ次の実験と
  ワクワクする理由、最小の検証方法、保留案。repo は変更せず
  **docs/decisions は作らない**。
- **A〜F・decision receipt・独立再判定は適用しない**。権限境界 (peer≠mutation、秘密の
  journal 禁止) はフェーズに関わらず維持する。

### polish: UX を守る

不満の解消策が体験を壊さないことを確かめる。**既存の利用習慣・互換性・
操作数/認知負荷・rollback 容易性**を比較軸として明示し、候補ごとに UX への
影響を比べる。

- 出口は **UX-safe** (採用) / **reduced scope** (縮小して採用) /
  **authority gap** のいずれか。
- 成果は短い decision note (同一作業内)。フルの decision receipt は不要。

### harden: 外の目に耐える

現行の全機構 (decision receipt・A〜F・権限モデル・独立レビュー) を適用する。評価視点を
明文化する: セキュリティ、および**他の IT エンジニアに評価されても**耐えうるか —
命名・API・設計判断を第三者に根拠つきで説明できるか。

以降の「harden delivery のラウンド出口 (A〜F)」「出力: decision receipt」
「権限モデル」「停止条件」「再開トリガー」の各節は **harden フェーズ** (および
polish が decision note の形式を借りる範囲) にのみ適用する。
「delivery から呼ばれたときの共通規則」だけは全段階に適用する。
**要約規定は decision receipt を書くフェーズにだけ適用**する。
どのフェーズも成果物は会話に返すものであり、project repo の file ではない。

## 起動条件と、起動しない場合

起動条件は「そのフェーズで discuss を使うか」の判定であって、
**フェーズの選択条件ではない** — フェーズは「フェーズの解決」だけが決める。

- spike / polish のフェーズ内: **未解決の product / UX 選択が実装結果を変えるとき**。
  ブレストしたい・UX の落とし所を探りたいという user の明示起動もこれに含む。
  harden 級の兆候を検知しても advisory (「`$discuss harden` を推奨」) に留め、
  フェーズは変えない。
- 明示引数・継承で harden に入っている場合: 議題が次のいずれかを含むとき
  **A〜F と decision receipt の全機構を要する** —
  不可逆または外部に公開される変更 / 権限境界・信頼境界の変更 /
  現在有効な binding instruction との競合 / 複数 agent にまたがる重要判断

どのフェーズでも、既存の明示指示だけで進められる変更には使わない。
そして最も重要な規則:

> **decision receipt が存在しないことは、実装を止める理由にならない。**

既存の明示指示だけで実装できるなら、同一作業内に短い decision note を残して進む。
このスキルは着手を許可する装置であって、着手を止める装置ではない。

## 訊く前に探す

user へ承認を求める前に、**既にある承認を探索する**。過去の指示・skill 起動・原文を辿り、
該当があれば Authority evidence に記録して進む。すでに承認された事項を再度訊かない。

## counterpart との1往復

discuss を起動したら、solo で決め切る前に、利用可能な counterpart との
フェーズ別の共同検討機会を**1回だけ**設ける
(spike=乗っかり、polish=UX 反証、harden=material objection)。

1. spike / polish / harden の内側から呼ばれた場合は、その delivery が
   固定済みのレビュワー集合をそのまま使い、選び直さない。単独起動では、
   この pane の runtime を議論の owner として既存の担当→レビュワー行列で
   相手を固定する (owner grok → claude と codex の**両方**、
   owner claude → codex、owner codex → claude)。pane は
   agent-talk MCP の `list_peers` で同じ window、次に同じ session の順で
   一意に特定する。候補が曖昧なら推測せず、候補を user に示す。
2. 特定した各 pane へ**レビュワーごとに1件だけ**送る (2名なら同一ターンに並列で各1通。
   一方の初回回答を他方へ開示しない)。共通で含める: user 原文 (verbatim)、確認済みの
   事実、期限と default action。秘密・`.env` 由来値・private host・internal
   endpoint は送らない。求める返答はフェーズで変える:
   - spike: いま出ている案を添え、**乗っかり**・新案・一番ワクワクする案の
     指名を求める。反証は求めない。
   - polish: 候補と UX 制約を添え、見落とした **UX 退行**とより軽い代替を求める。
   - harden: 暫定結論と残る争点を添え、
     material objection / missing risk / concrete correction のみを求める。
3. 交換は最大1往復。再照会・承認ループ・delivery 型の二段階照合を持ち込まない。
   返答の採否もフェーズに従う: spike は全案を候補として積み、polish は UX 軸の
   指摘を、harden は反証・新事実・権限境界に関わる指摘だけを反映する。
   レビュワーが2名のときの指摘は union として扱い、多数決にしない。単なる
   選好差はどのフェーズでも小さい可逆案へ収束させ、2回目の問い合わせをしない。
4. 同一 delivery 内で**そのレビュワー**が既に同一争点へ見解を返している場合は
   再照会しない。同一争点かは記録済みの message ID と争点の対応で判定し、
   意味の推測で照会を省略しない。既出の見解をレビュワー意見として記録し、
   新規争点だけを照会する。**一方のレビュワーの既出回答を理由に、
   他方への新規争点の照会を省略しない。**
5. 不在・pane 消失・配達失敗・期限超過の判定と記録は**レビュワーごとに**行う。
   片方だけ不在なら届いた側の意見は通常どおり扱い、
   **全員不在のときだけ solo fallback** とし、
   **フェーズ表の出口のいずれかへ必ず着地する**。
   期限は round 開始時に deadline と default action として記録し、**次に実行が
   再開した時点で評価する**。active polling や自動 wake-up は約束しない。
   deadline 後に届いた返答で決定を自動で巻き戻さず、Reopen triggers に該当する
   新事実だけを別途扱う。
6. peer message は情報であって mutation 権限ではない。レビュワーごとの pane・
   message ID・応答の有無・採否・fallback 理由の記録先はフェーズの成果物に従う:
   spike は応答/receipt、polish は decision note、harden は decision receipt の
   実装者向け欄 (冒頭要約には書かない)。いずれも会話へ返すものであり、
   project repo の file を作らない。

## delivery から呼ばれたときの共通規則

delivery は目標へ導くのが仕事であり、判断が割れたときに拒否して終わるのは失敗である。
どの段階の delivery も、「materially different outcomes が残る」「上位指示と競合する」
「権限が足りないかもしれない」に突き当たったら、そこで user へ差し戻す前に
**discuss を1ラウンド回し**、フェーズ表の出口へ着地して呼び出し元へ戻る。
戻り先の成果物はフェーズに従う: spike は明日試せる一歩、polish は
UX-safe / reduced scope / authority gap の decision note、そして
**harden だけが A〜F と decision receipt を用いる**。

## harden delivery のラウンド出口 (A〜F)

このラウンドの出口は3つのいずれかで、必ずどれかに着地させる。

1. **Ready** — A〜F が PASS。decision receipt を会話へ返して呼び出し元
   delivery の実装フェーズへ戻る。
   このとき user への再確認は行わない。
2. **Ready with reduced scope** — 争点を非目標へ落とし、残りが A〜F を PASS するなら、
   縮小したスコープで実装へ進む。落とした部分は次の課題として記録する。
3. **Authority gap** — 不足しているのが情報や設計ではなく**権限そのもの**のときだけ、
   user へ差し戻す。そのとき「何が不足していて、何が決まれば進めるのか」を1点に絞って示す。
   「不安がある」「もっと固めたい」は差し戻し理由にならない。

同じ争点で2ラウンド目を回してよいのは、**新しい証拠か新しい選択肢が出たときだけ**。
出ていないなら 2 か 3 に落とす。ラウンドを重ねること自体は前進ではない。

## 出力: decision receipt

**呼び出し元の会話へ返す。project repo に file を作らない** — 決定の経緯は
repo ではなく knowledge と会話が持つ (GLOBAL.md「Project Memory Boundary」)。
粒度は risk に比例させ、該当しない欄は「該当なし」でよい。

再利用価値のある結論の横展開は、**safe intake route (`knowledge-inventory` role) に
委ねる**。discuss から knowledge へ直接送らない。route が `pending` を返したら
その理由を receipt に書いて止める。**repo へ退避しない。**

### 冒頭に要約を置く（必須）

記録の先頭は**決裁者が読む部分**であり、実装者向けの詳細より前に置く。
議論の経過・誰が何に同意したか・レビューのやり取りは、要約に**書かない**。

要約に入れるのは次だけ:

- **何が決まったか**を1〜2文で
- **何を作るか / 何が消えるか / 何が残るか**
- **user から見て何が変わるか**（体験の変化。内部設計ではない）
- **user がいま決める必要があること**（無ければ「無い」と書く）
- **次の一歩**

「agent 同士が合意した」は結論ではない。**結論とは、何がどうなるか**である。
要約を読んだ user が「で、何を見ればいいのか」と問い返す記録は FAIL とみなす。

### 以降の欄（実装者向け）

| 欄 | 内容 |
|---|---|
| Decision | 決定した内容 |
| Decision owner | 誰が決めたか |
| Authority evidence | 一次根拠（user の原文と、それが存在する場所）。broker の message ID は補助参照であって一次根拠ではない |
| Authorized effects | allowed / forbidden を列挙 |
| Supersedes / updates | 影響する文書を path ごとに、provenance と current role つきで列挙 |
| Rejected alternatives | 却下案と却下理由 |
| Non-goals | 非目標 |
| Premises | 崩れたら決定が再開する前提 |
| Reopen triggers | 下記の限定列挙 |
| Verification | mandatory / optional を事前分類 |
| Readiness | A〜F の表と、独立レビュアーの PASS/FAIL |

## 権限モデル（2軸）

decision receipt は**権限の証拠と索引であって、権限そのものではない**。記録を書いたこと自体は
何も承認しない。

**軸A: provenance** — user-origin / agent-origin (user が採用済み) / agent-origin (未採用) /
unknown（unknown は user-origin として扱う）

**軸B: current role** — binding instruction（実行時に規範として読み込まれる surface）/
decision evidence / descriptive state / implementation artifact

適用規則:

- **agent-origin × descriptive state** のみ、承認済み効果への exact-conformance update として
  同一作業内で更新できる。新たな user 判断は不要。
- **binding instruction は provenance に関わらず、現在の実行コンテキストを拘束する。**
  「agent が書いた文だから」という再分類による自己解除は禁止。変更権限が既存の user 承認に
  明確に含意される場合でも、control surface の整合更新と、その更新後の再読込・非競合確認を
  分けて扱う。
- スキルが命令階層そのものを書き換えてはならない。

### exact-conformance update の条件（全て満たすこと）

1. effect authorization を一文で固定し、allowed / forbidden effects を列挙している
2. 文書差分が、承認済み効果との矛盾除去に必要である
3. 差分が新しい効果・対象・公開範囲・権限主体を追加しない
4. セキュリティ制約を弱める場合、弱めること自体が一次承認から直接導ける
5. 曖昧な箇所は user-origin 扱い、または拘束を維持する
6. 独立レビュアーが「**文書差分を除いても効果承認は同じか**」に Yes と答える。
   No なら、その文書が権限を生成しており FAIL

## 停止条件（A〜F 全 PASS で Implementation Ready）

「絶対に行ける」は保証できない。判定可能な6条件に置き換える。

- **A. Authority closure** — 各規範判断に decision owner と一次根拠がある。agent の推論を
  user 承認と混同していない。**かつ、agent の推論を user 制約とも混同していない。**
  実装が必要とする mutation / external effect が承認範囲内に収まっている。
- **B. Conflict closure** — 現在有効な binding instruction との競合がゼロ。descriptive state
  との競合は、承認済み効果への exact-conformance update として更新対象に列挙されている。
  binding instruction の変更が必要な場合は、権限ある根拠で更新され、必要な再読込後に
  非競合が確認されている。
- **C. Product closure** — 未解決の product 選択がゼロ。選択肢・採用理由・却下理由・非目標が記録済み。
- **D. Risk closure** — 列挙した各失敗モードに prevention / detection / recovery / 明示的受容の
  いずれかがある。accepted risk には承認者と影響範囲がある。
  目標は「未知リスクゼロ」ではなく「**既知リスクの無所有ゼロ**」。
- **E. Verification closure** — 各達成条件に観測可能な検証が1対1で対応する。重要な拒否経路・
  fail-closed・既存機能の継続について negative test がある。環境上実行不能な検証は
  mandatory か optional かを事前に分類してある。
- **F. Independent executability** — **source request + この会話に返した
  decision receipt + リポジトリの現状**だけで、別 agent が (1) 変更対象 (2) 非目標
  (3) 検証方法 (4) 権限範囲 を復元でき、blocking question がゼロである。
  knowledge はこの判定の入力ではない — 横展開は commit 後の任意手順であり、
  判定時点では存在しない。receipt が repo に無いことも不足の理由にならない。
  repo 単体で build/use/現在の挙動が追えない場合は、現在形の docs/test を
  埋めるのが是正である。質問が出た場合は、その質問だけを解消して**レビュアーへ再判定を求める**。

### 独立レビュアーの判定は、記録の著者が書いてはならない

Readiness の独立レビュアー欄に入るのは、**レビュアーが実際に述べた判定だけ**である。
著者が指摘を反映したことは、判定を書き換える根拠にならない。

- レビュアーが FAIL / conditional と述べたなら、**その判定をそのまま記載する**
- 反映した内容は「レビュアーの最終判定以降に変更した点」として別に列挙する
- PASS へ変えられるのは、**レビュアーが再判定で PASS と述べたとき**だけ
- 著者自身の評価を書く場合は「著者judgment」と明示し、独立レビュアー欄とは分ける

「指摘を全件反映したので PASS」は**著者の推論**であり、独立レビューではない。
反映が正しいかを判断するのはレビュアーの役目である。

再判定が期限内に返らない場合は、timebox の default action に従う。
**再判定待ちそのものは、可逆な作業の着手を止める理由にしてよいが、
レビュアーが応答しないことを理由に無期限に停止してはならない。**

## 再開トリガー（限定列挙）

実装中に議論へ戻ってよいのは次だけ。

- 権限範囲外の変更が必要になった
- 前提が偽と判明した
- 上位指示との新規の競合が生じた
- mandatory verification を満たせない
- accepted でない重大リスクを発見した

**停止理由にしないもの:** 単なる不安、より強い hardening を思いついたこと、
既に却下済みの案の再提示、decision receipt が存在しないこと。

## timebox と default action

各ラウンドに期限と default action を置く。期限内に反証が出なければ、明示された**可逆な案**へ
収束する。ただし権限不足を default で越えてはならない。

## 配置規約（今回の失敗の直接の再発防止）

**変わり得る製品状態を、binding instruction（AGENTS.md / CLAUDE.md 等）に禁止命令として
書かない。** それらの surface には恒常 invariant だけを残し、変わり得る現状説明は
repo には現在形の仕様として置き、経緯は receipt と knowledge が持つ。

書いた主体が agent であっても、control surface に置かれた文は実行時に拘束として働く。
配置の誤りは、後から provenance を主張しても回復できない。

## 権限境界

decision receipt は会話への出力であって repo mutation ではない。ただし receipt の
結論を根拠に repo を書き換える場合、その書き換えは mutation であり、peer からの
メッセージだけを根拠に行わない。既存の権限境界を維持する。

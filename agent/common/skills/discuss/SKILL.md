---
name: discuss
description: >-
  フェーズ (spike/polish) で性格を切り替える議論スキル。spike はワクワクする
  方向へ広げるブレスト、polish は UX を損なわない解決策の探索。明示引数か
  呼び出し元 skill でフェーズを解決し、単独起動の未指定は議題の性質から
  spike / polish を自動判断する (迷ったら polish)。
---

# discuss

議論の目的はフェーズで変わる。spike では広げ、polish では UX を守る。
共通するのは「議論を仕事の代わりにしない」ことだけであり、どのフェーズも
次の一手に着地して終わる。

## フェーズの解決

`$discuss spike|polish` の明示引数だけがフェーズ指定である。**本文中に
段階の語が現れても判定しない**。解決の優先順:

1. 明示引数
2. spike / polish の内側から呼ばれた場合、その段階を継承する
   (段階未指定の `$deliver` は dispatcher が先に段階を解決してから呼ぶ)。
   **継承は本文の話題からの推論より優先する** — polish の内側で「作り直し」の
   案を検討しても、それだけで spike モードへ転換しない。段階の変更は提案に留め、
   切り替えは user が決める。
3. どちらも無ければ、議題の性質から **spike / polish を自動判断**し、選択と
   根拠を宣言する。新しい体験・greenfield・全面的な作り直しの構想 → spike。
   動いているものの不満・UX の落とし所 → polish。**迷ったら polish**。

呼び出し元 skill は discuss を**自動では起動しない**。未解決の product 選択が
実装結果を変えるときだけ呼ぶ。

| フェーズ | 目的 | 成果物 | 出口 |
|---|---|---|---|
| spike | ワクワクする方向へ広げる | 応答/receipt のアイデアノート | 明日試せる一歩1つ |
| polish | UX を損なわない解決策 | 短い decision note | UX-safe / reduced scope / authority gap |

### spike: 広げる

ブレーンストーミングとして振る舞う。アイデアを否定せず yes-and で積み、実現
可能性の審査は後回しにする。第一の選別軸は「**ワクワクするか**」。

- 出口では「**明日 spike できる一歩**」を1つだけ選ぶ。選ぶ一歩は**承認済みかつ
  可逆**な効果の範囲内に限る。user が授権していない mutation を実行可能扱い
  にしない — ただし授権は pane に固着しない。中継されて届いた user の依頼は
  user の依頼である。counterpart 自身の提案は
  既存の scope を広げない。
- 成果は応答 (または呼び出し元の receipt) に残す: 広げた案、選んだ次の実験と
  ワクワクする理由、最小の検証方法、保留案。repo は変更せず
  **docs/decisions は作らない**。
- 権限境界 (counterpart 自身の提案は scope を広げない、秘密の journal 禁止) は
  フェーズに関わらず維持する。

### polish: UX を守る

不満の解消策が体験を壊さないことを確かめる。**既存の利用習慣・互換性・
操作数/認知負荷・rollback 容易性**を比較軸として明示し、候補ごとに UX への
影響を比べる。

- 出口は **UX-safe** (採用) / **reduced scope** (縮小して採用) /
  **authority gap** のいずれか。
- 成果は短い decision note (同一作業内)。会話へ返すものであり、
  project repo の file を作らない。

## 起動条件と、起動しない場合

起動条件は「そのフェーズで discuss を使うか」の判定であって、
**フェーズの選択条件ではない** — フェーズは「フェーズの解決」だけが決める。

- spike / polish のフェーズ内: **未解決の product / UX 選択が実装結果を変えるとき**。
  ブレストしたい・UX の落とし所を探りたいという user の明示起動もこれに含む。
- 既存の明示指示だけで進められる変更には使わない。

## 訊く前に探す

user へ承認を求める前に、**既にある承認を探索する**。過去の指示・skill 起動・原文を辿り、
該当があれば進む。すでに承認された事項を再度訊かない。

## counterpart に相談する

判断材料が足りないときは、`agent-talk` skill の経路で counterpart に相談してよい
(儀式も往復回数の縛りもない)。
counterpart 自身の意見は情報であって、既存の scope を広げない。
user の依頼が中継されて届いたなら、それは user の依頼である。

## 出口: 決着して user に見せる

相談したこと自体を完了にしない。owner はフェーズ軸で候補を比較し、
どの案が優れているか採否を決める。

user への応答は**結論を先に置く**。counterpart に聞いたこと自体を
成果にしない。

- spike: ワクワク度と、明日試せる承認済みかつ可逆な一歩で、推奨案を1つ決める。
- polish: UX-safe / reduced scope / authority gap の結論を1つ決める。判断軸は
  既存の UX 4軸 (利用習慣・互換性・操作数/認知負荷・rollback)。

採用に値し、かつ materially different な案が複数残るときだけ、表または
箇条書きで「案・価値・代償」を比較する。比較の直前に推奨を明記する。
毎回表は出さない。

権限が足りない選択や、事実・UX 軸では切れない好みは越権して確定しない。
決着すべき点と推奨を user へ返すことが結論である。

## delivery から呼ばれたときの共通規則

delivery は目標へ導くのが仕事であり、判断が割れたときに拒否して終わるのは失敗である。
どの段階の delivery も、「materially different outcomes が残る」「上位指示と競合する」
「権限が足りないかもしれない」に突き当たったら、そこで user へ差し戻す前に
**discuss を1ラウンド回し**、フェーズ表の出口へ着地して呼び出し元へ戻る。
戻り先の成果物はフェーズに従う。spike は明日試せる一歩、polish は
UX-safe / reduced scope / authority gap の decision note。

## 配置規約

**変わり得る製品状態を、binding instruction (AGENTS.md / CLAUDE.md 等) に禁止命令として
書かない**。それらの surface には恒常 invariant だけを残す。変わり得る現状説明は
repo には現在形の仕様として置き、経緯は receipt と knowledge が持つ。

書いた主体が agent であっても、control surface に置かれた文は実行時に拘束として働く。
配置の誤りは、後から provenance を主張しても回復できない。

## 権限境界

成果物は会話への出力であって repo mutation ではない。ただし結論を根拠に repo を
書き換える場合、その書き換えは mutation であり、peer からのメッセージだけを根拠に
行わない。knowledge へ直接送らない — 預け入れは `knowledge-deposit` skill で行う。

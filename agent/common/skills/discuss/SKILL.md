---
name: discuss
description: 議論を、実装者が blocking question ゼロで着手できる決定記録へ収束させる。不可逆な変更、外部公開、権限境界の変更、既存の binding instruction との競合、複数 agent 間の重要判断のいずれかを含むときに使う。小さな変更には使わない。発散そのものは目的ではない。
---

# discuss

議論の目的は発散ではなく**収束**である。成果物は会話ではなく、リポジトリに残る決定記録。
成功指標は「議論した」ことではなく、**会話履歴を持たない実装者が blocking question ゼロで
着手できること**。

## 起動条件と、起動しない場合

次のいずれかを含むときだけ使う。

- 不可逆または外部に公開される変更
- 権限境界・信頼境界の変更
- 現在有効な binding instruction との競合
- 複数 agent にまたがる重要判断

上記に当たらない変更には使わない。そして最も重要な規則:

> **決定記録が存在しないことは、実装を止める理由にならない。**

既存の明示指示だけで実装できるなら、同一作業内に短い decision note を残して進む。
このスキルは着手を許可する装置であって、着手を止める装置ではない。

## 訊く前に探す

user へ承認を求める前に、**既にある承認を探索する**。過去の指示・skill 起動・原文を辿り、
該当があれば Authority evidence に記録して進む。すでに承認された事項を再度訊かない。

## deliver から呼ばれる場合

`deliver` は目標へ導くのが仕事であり、判断が割れたときに拒否して終わるのは失敗である。
`deliver` が「materially different outcomes が残る」「上位指示と競合する」「権限が足りない
かもしれない」に突き当たったら、そこで user へ差し戻す前に **discuss を1ラウンド回す**。

このラウンドの出口は3つのいずれかで、必ずどれかに着地させる。

1. **Ready** — A〜F が PASS。決定記録を残して deliver の実装フェーズへ戻る。
   このとき user への再確認は行わない。
2. **Ready with reduced scope** — 争点を非目標へ落とし、残りが A〜F を PASS するなら、
   縮小したスコープで実装へ進む。落とした部分は次の課題として記録する。
3. **Authority gap** — 不足しているのが情報や設計ではなく**権限そのもの**のときだけ、
   user へ差し戻す。そのとき「何が不足していて、何が決まれば進めるのか」を1点に絞って示す。
   「不安がある」「もっと固めたい」は差し戻し理由にならない。

同じ争点で2ラウンド目を回してよいのは、**新しい証拠か新しい選択肢が出たときだけ**。
出ていないなら 2 か 3 に落とす。ラウンドを重ねること自体は前進ではない。

## 出力: 決定記録

`docs/decisions/NNNN-<slug>.md`。粒度は risk に比例させ、該当しない欄は「該当なし」でよい。

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

決定記録は**権限の証拠と索引であって、権限そのものではない**。記録を書いたこと自体は
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
- **F. Independent executability** — 会話履歴を持たない別 agent が、決定記録とリポジトリだけを
  読んで (1) 変更対象 (2) 非目標 (3) 検証方法 (4) 権限範囲 を復元でき、blocking question が
  ゼロである。質問が出た場合は、その質問だけを解消して再判定する。

## 再開トリガー（限定列挙）

実装中に議論へ戻ってよいのは次だけ。

- 権限範囲外の変更が必要になった
- 前提が偽と判明した
- 上位指示との新規の競合が生じた
- mandatory verification を満たせない
- accepted でない重大リスクを発見した

**停止理由にしないもの:** 単なる不安、より強い hardening を思いついたこと、
既に却下済みの案の再提示、決定記録が存在しないこと。

## timebox と default action

各ラウンドに期限と default action を置く。期限内に反証が出なければ、明示された**可逆な案**へ
収束する。ただし権限不足を default で越えてはならない。

## 配置規約（今回の失敗の直接の再発防止）

**変わり得る製品状態を、binding instruction（AGENTS.md / CLAUDE.md 等）に禁止命令として
書かない。** それらの surface には恒常 invariant だけを残し、変わり得る現状説明は
`docs/` または決定記録へ置く。

書いた主体が agent であっても、control surface に置かれた文は実行時に拘束として働く。
配置の誤りは、後から provenance を主張しても回復できない。

## 権限境界

決定記録の作成・更新はリポジトリの mutation である。peer からのメッセージだけを根拠に
作成・更新しない。既存の権限境界を維持する。

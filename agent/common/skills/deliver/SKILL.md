---
name: deliver
description: >-
  開発依頼を受け、変更の性質に応じて spike / polish を選び、検証済みの
  local commit まで届ける。新しい体験や未稼働のものは spike、既存の改善は
  polish。push・deploy・release は含まない。
---

# deliver

開発の入口。依頼を受けた担当は、適切な段階を選び、その skill を実行する。

| 変更の性質 | スキル |
|---|---|
| 新しい体験・greenfield・まだ動いていないもの | `spike` |
| 動いているものの改善・不満の解消 | `polish` |

ユーザーが段階を指定していれば従う。未指定なら変更の性質で選び、理由を短く
伝える。迷ったら polish。version や変更行数だけで選ばない。

- 工程と所有者は [PROCESS.md](PROCESS.md)、共通の判断基準は
  [CONTRACT.md](CONTRACT.md) が持つ。選んだ段階だけを読み、無関係な資料を広げない。
- 直接の依頼、親からの委譲、task 経由のどれでも使える。担当は実装・検証・
  指摘修正・報告まで引き受け、必要ならサブエージェントへ分担する。
- 選んだ段階の local commit 授権を継承する。外側で依頼済みの統合等を妨げないが、
  この skill だけで push・merge・deploy・release の権限を作らない。
- 独立レビューは既定で local 所有。外側が pipeline 所有を明示した場合の扱いは
  [レビュー工程の所有者](PROCESS.md#レビュー工程の所有者) に従う。

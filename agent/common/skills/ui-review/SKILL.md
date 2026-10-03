---
name: ui-review
description: >-
  UI変更の完了判断で、元の要求・製品設計・実画像と操作結果を照合するときに使う。非UI差分には使わない。
---

# UI成果を要求と照合する

[実装方針の適用境界](../deliver/implementation-scope.md)を適用してから進める。

入力は元の要求、design-contextの結果、製品DESIGN.mdの差分、実装差分。
frontend-designまたはandroid-ui-checkの画像・操作結果・引き算のbefore/afterを担当自身が読む。

- 元の要求が画面に反映されたかを、画像と操作で照合する。
  文書を読んだ宣言、tokenの使用、DESIGN.mdへの適合だけで合格にしない。
- [frontend-design](../frontend-design/SKILL.md)の「画面の引き算」の結果を照合する。
  同じデータで、読む量と操作が実際に減っているかを見る。
  必要な情報・操作・accessibilityの欠落も確認する。
- 製品DESIGN.mdの差分を、[design-context](../design-context/SKILL.md)の「製品DESIGN.mdへ書くもの」と照合する。
- 新規UIの両テーマなど必要な証拠をそろえる。fakeや自己申告を未実施の実画面・実機へ拡大しない。

出力は確認結果と、失敗/未確認の根拠・戻し先。担当が同じ依頼内で直す。
戻し先は、設計がdesign-context、Webの実装と実測がfrontend-design、Androidがandroid-ui/android-ui-checkである。
この結果を [change-review](../change-review/SKILL.md) へ一緒に渡す。
Jevへは関連する設計本文と実際の観測結果を含め、pathや「確認済み」の要約だけを渡さない。
独立したUI承認、署名、全件への別担当レビューを追加しない。

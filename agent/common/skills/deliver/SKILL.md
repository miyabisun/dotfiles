---
name: deliver
description: >-
  開発依頼を、対象に必要な設計・実装・検証スキルへつなぎ、修正・レビュー・commit・pushまで完走する。
---

# 開発を成果まで届ける

主担当は元の要求と達成条件、現在の工程、残件を持つ。GLOBALの自律性・他者の作業保護に従い、
依頼された後続まで進める。このskillはcommit・pushまでを授権する。同期と配達は [git](../git/SKILL.md)。

1. [knowledge-read](../knowledge-read/SKILL.md)で関連判断・共有テスト戦略を読み、実装と照合する。
   導入済み `ponytail:ponytail` の公式SKILL.mdを読み、設計・実装へfullを適用する。
   [task-creater](../task-creater/SKILL.md)の元の要求と事前判断を引き継ぎ、未実施分だけ行う。
   直接開発の台帳登録は必須にせず、同じ範囲の判断を繰り返さない。
2. 下の条件に該当するskillを実際に読み、成果を次へ渡す。既読で充足しているものは再利用する。
   新規UIでは正本・操作・配置・テーマを揃える。backend-onlyではUI skillを呼ばない。
3. [test-verify](../test-verify/SKILL.md)のTDDと実検証を行い、未達は実装へ戻して修正する。
4. UIは環境別実測と [ui-review](../ui-review/SKILL.md)の照合を終え、
   [change-review](../change-review/SKILL.md)で元の要求・実差分・検証証拠をレビューする。
   指摘を直し、影響範囲を確認する。外側がレビューを明示所有する場合だけ [PROCESS.md](PROCESS.md)を使う。
5. gitで自分の差分をcommit・pushし、成果、検証・レビュー、送信先、残件を返す。
   依頼済みのmerge/release/配備は対応skillへ続ける。変更不要なら空commitを作らない。

| 今回作る・変えるもの | 読むskill | 次へ渡すもの |
| --- | --- | --- |
| Web/nativeの表示・操作 | [design-context](../design-context/SKILL.md) | 正本の適用節と製品設計の不足 |
| 新規UI、主操作・遷移・通知・外部起動 | [ui-flow](../ui-flow/SKILL.md) | 利用前後の経路と状態・復帰 |
| 新規UI、一覧・配置・部品・文字や余白 | [ui-layout](../ui-layout/SKILL.md) | 製品配置と代表データの観測条件 |
| 新規UI、色・明暗・状態の配色 | [ui-theme](../ui-theme/SKILL.md) | 製品tokenと両テーマの仕様 |
| ブラウザUIの実装 | [frontend-design](../frontend-design/SKILL.md) | 差分 → [web-ui-check](../web-ui-check/SKILL.md)の実画像・操作 |
| Android UI・通知・起動経路の実装 | [android-ui](../android-ui/SKILL.md) | 差分 → [android-ui-check](../android-ui-check/SKILL.md)の実画像・操作 |

配色だけなら操作・配置の設計をやり直さず、配置だけならテーマを再設計しない。
既存の契約の不足が今回の成果に影響するときは対応skillで補う。原本や製品仕様を読んだ宣言だけで適用済みにしない。
未解決のproduct判断は必要時だけ [discuss](../discuss/SKILL.md)を使い、担当が決める。

実装方法・可逆な修正・規則の不足は要求と現状から解決し、新しい承認段階にしない。
実際に不足する情報・権限だけを尋ね、独立した作業を続ける。ツール拒否は実際の理由を区別する。
範囲外で観測した具体的な問題はtask-createrで重複/利用先を確認してdraft登録し、IDまたは未登録理由と保存先を残す。
元の要求の達成に必要な修正はdraftへ逃がさない。再利用する判断はknowledge-depositで正本へ残す。

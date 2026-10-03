---
name: design-context
description: >-
  UIの新規作成や、表示・操作・配置・配色の変更で、knowledgeのデザイン方針・共通原本・製品DESIGN.mdを照合し、操作の流れ・配置・テーマを決める。Webとnative UIを含む。backendだけの変更には使わない。
---

# UIの設計を決める

[実装方針の適用境界](../deliver/implementation-scope.md)を適用してから進める。

入力は元の要求、対象repository、変更するUI、knowledge-readで解決したknowledge checkout。
単独起動でcheckoutが未解決なら `$KNOWLEDGE_REPO` または今回明示された場所を使う。

## 参照する文書

1. knowledgeの `library/policies/home-development-rules.md#design-ownership`、
   `library/playbooks/project-design-md-adoption.md`、
   `library/lessons/preserve-design-authority-across-workflow-tiers.md` を読む。
   対象product indexの関連判断も照合し、共通原本の所在はplaybookのsourceから辿る。
2. 製品rootの `DESIGN.md` を読む。rootがない既存製品だけは `docs/DESIGN.md` を使う。
   新規UI、原本の導入が未確認、または今回変える規則に不足・矛盾がある場合は、
   rust-svelte-templateのroot DESIGN.mdの該当節まで実際に読む。
3. 現在のユーザー要求は、製品DESIGN.mdの既存記述より優先する。既存記述は過去の判断であり、
   原文参照のない「ユーザーの決定」は担当判断として要求に合わせて直す（[knowledge-read](../knowledge-read/SKILL.md)末尾）。
   原本更新を理由に既存画面を一括上書きしない。

## 操作の流れ

- 主操作を一つ定め、初回準備と普段の操作を分ける。保存済み条件で省ける入力を毎回求めない。
- 今回の入口（通常起動・外部リンク・通知など）から、成功・失敗・再試行・取消し・戻るを追う。
  失敗時は原因、直す項目、再試行の操作を決める。API受付を成功と扱わない。

## 配置

- 利用者が探す対象を最初に置く。件数・長い名前・状態の混在を含む代表データで決める。
- 近い情報をまとめ、現在地・選択・件数を繰り返さない。
  初期表示から削る手順は [frontend-design](../frontend-design/SKILL.md)の「画面の引き算」に従う。
- 狭い画面・文字拡大・空/失敗でも主操作へ届くようにする。
  Webはページの縦スクロール、Androidはnativeのスクロールとsystem insetを基準にする。

## テーマ

- 新規UIは共通原本の暗色から設計し、通常の明色も用意する。既存製品は採用済みの配色を保つ。
- 背景・面・文字・境界・アクセント・失敗の役割を製品tokenへ対応付け、値を一箇所に集める。
- OSへの追従と手動選択の保存を製品に合わせて決める。AndroidへWebのlocalStorageを写さない。
- 明暗両方でコントラストを満たす。色だけで状態を伝えず、短い状態名やアイコンを添える。

## 製品DESIGN.mdへ書くもの

書くのは意匠の規則（色・寸法・部品・配置の原則）と、原文参照付きのユーザーの決定だけとする。
ボタン文言、取得間隔などのタイミング、プロトコル・API・要求ID、今回の画面の文字列や並びは書かない。
これらは実装とテストが持つ。今回作った画面を、以後変えさせない規則にしない。
記録の原則は [knowledge-deposit](../knowledge-deposit/SKILL.md)に従う。外部必読や非公開pathを残さない。

出力は確認した文書のpath/節、今回の流れ・配置・テーマの決定、製品DESIGN.mdの差分。
Webは[frontend-design](../frontend-design/SKILL.md)、Androidは[android-ui](../android-ui/SKILL.md)へ渡す。
WebのCSSやpxをAndroidへそのまま写さない。参照不能なら未確認箇所を示して一次情報で進め、
実際に不足する製品判断だけを尋ねる。

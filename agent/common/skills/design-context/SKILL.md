---
name: design-context
description: >-
  UIの新規作成・表示・操作変更で、knowledgeのデザイン方針、共通原本、製品DESIGN.mdを照合する。Webとnative UIを含む。backendだけの変更には使わない。
---

# 適用するデザイン方針と参照文書を特定する

[実装方針の適用境界](../deliver/implementation-scope.md)を適用してから進める。

入力は元の要求、対象repository、変更するUI、knowledge-readで解決したknowledge checkout。
単独起動でcheckoutが未解決なら `$KNOWLEDGE_REPO` または今回明示された場所を使う。

1. knowledgeの `library/policies/home-development-rules.md#design-ownership`、
   `library/playbooks/project-design-md-adoption.md`、
   `library/lessons/preserve-design-authority-across-workflow-tiers.md` を読む。
   対象product indexの関連判断も照合し、共通原本の所在はplaybookのsourceから辿る。
2. 製品rootの `DESIGN.md` を読む。rootがない既存製品だけは `docs/DESIGN.md` を使う。
   新規UI、原本の導入が未確認、または今回変更する規則に不足・矛盾がある場合は、
   rust-svelte-templateのroot DESIGN.mdの該当節まで実際に読む。
   原本名だけ、古いdotfiles雛形だけ、製品文書への自己適合だけで解決済みにしない。
3. 現在の画面・実装・ユーザーの要求と照合し、適用する操作・配置・テーマの規則と不足を返す。
   採用済みの製品設計は製品が所有する。原本更新を理由に既存画面を一括上書きしない。
   ただし導入漏れを製品固有の合意と推測しない。今回の要求に必要な不足は担当が補う。

出力は確認したデザイン文書のpath/節、適用する規則、今回補う製品設計、実測条件。
設計を具体化する責務は [ui-flow](../ui-flow/SKILL.md)、[ui-layout](../ui-layout/SKILL.md)、
[ui-theme](../ui-theme/SKILL.md)。関係するものだけへ解決結果を渡す。
製品DESIGN.mdは操作・数値・状態を製品内で判断できる形にする。外部必読や非公開pathを残さない。

WebのCSSやpxをAndroidへそのまま写さず、情報の優先順位と意匠の意味をnative部品へ適用する。
方針の全文・色値を各skillへ複製しない。参照不能なら未確認箇所を明示して一次情報で進め、
実際に不足する製品判断だけを尋ねる。設計文書の更新を新しい承認段階にしない。

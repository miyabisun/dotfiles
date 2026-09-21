---
name: frontend-design
description: >-
  HTML・CSS・JavaScript・SvelteなどブラウザUIの表示・操作を実装するときに使う。native UI、backend、文書だけの変更には使わない。
---

# Web UIへ実装する

[実装方針の適用境界](../deliver/implementation-scope.md)を適用してから進める。

入力は要求、製品DESIGN.md、既存のtoken/componentと実装経路。
適用するデザイン方針が未確認なら [design-context](../design-context/SKILL.md)を先に読む。
操作・配置・テーマに今回必要な設計が欠けていれば、該当するui-flow/ui-layout/ui-themeで補う。
設計責務の選択は [deliver](../deliver/SKILL.md)の条件に従い、全skillを一括で読まない。

1. 既存component、token、semantic HTMLとCSSの標準機能を使って製品設計を実装する。
   見た目だけでなく、文言・状態・URL・keyboard・focus・ARIAも変更の影響に含める。
2. 主情報の表示領域を守り、共通tokenを使っただけで適合としない。
   状態と選択を属性・文字でも伝え、可視focus、操作領域、reduced motionを保つ。
3. SVG・画像は既存資産を再利用する。必要のない依存や独自widgetを足さない。
   新規/変更する純粋な判断は [test-verify](../test-verify/SKILL.md)のTDDに従う。

出力は製品設計を反映した差分と、維持した操作、確認する状態。
[web-ui-check](../web-ui-check/SKILL.md)へ実装と観測条件を渡す。
表示や操作の未達箇所は担当が修正し、[ui-review](../ui-review/SKILL.md)へ証拠を渡す。
commit/pushまでの依頼はdeliverへ戻して完走する。

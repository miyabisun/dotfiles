---
name: android-ui
description: >-
  KotlinのAndroid native画面・テーマ・通知・NFC等からの起動経路を実装するときに使う。Web UIやUIに影響しないAndroid処理だけの変更には使わない。
---

# Android UIへ実装する

入力は要求、製品DESIGN.md、既存のActivity/Service/ComposeまたはViewの経路。
正本が未解決なら [design-context](../design-context/SKILL.md)を先に読む。
今回必要な操作・配置・テーマの不足だけをui-flow/ui-layout/ui-themeへ渡す。
設計責務の選択は [deliver](../deliver/SKILL.md)に従う。既存のUI方式は不用意に移行しない。

1. 既存部品とAndroidのresource/theme、platform部品を使う。製品tokenをresource等の
   一箇所へ集め、OSの明暗と再生成に反映する。色の固定値を各Viewへ散らさない。
2. dp/sp、system inset、文字拡大、読み上げ、状態説明、48dp以上の操作領域を扱う。
   共通原本のWeb部品を丸写しせず、製品の主情報と操作をnativeで成立させる。
3. 外部起動・通知は利用中の他アプリとの関係を実装する。通常起動の権限導線と
   タグ等の日常操作を区別し、画面のない処理を結果Activityで覆わない。
   対象SDKの権限・background制約・寿命をAndroid公式資料で確認する。
4. lifecycleの再生成・取消し・遅延結果を扱い、既存の認可や入力検証を保つ。
   判断とOS操作を分け、[test-verify](../test-verify/SKILL.md)のTDDと既存fake境界を使う。

出力は画面/通知/入口の実装と、状態・lifecycleの観測条件。
[android-ui-check](../android-ui-check/SKILL.md)へ渡し、emulatorと必要な実機の証拠を区別する。
未達は担当が直し、ui-reviewと依頼済みのcommit/pushへ進める。

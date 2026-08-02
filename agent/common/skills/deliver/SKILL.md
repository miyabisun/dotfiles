---
name: deliver
description: >-
  互換ディスパッチャ。deliver は開発段階別の3スキル (spike / polish / harden)
  に分割された (decision 0002)。段階未指定の $deliver は従来と同じ保証を持つ
  harden として実行する。user が同じ依頼で段階を明示した場合のみ該当スキルへ
  委譲し、選択を宣言する。保証を暗黙に弱めない。push・deploy・release は
  しない。
---

# deliver (dispatcher)

`deliver` は decision 0002 で開発段階別の3スキルに分割された。

| 段階 | スキル | 概要 |
|---|---|---|
| 黎明期 | `spike` | まず動かして体験を得る。ゲートなし、動作証拠1つ |
| ブラッシュアップ | `polish` | 不満を直す。隣接チェック+レビュー1回 |
| リリース水準 | `harden` | 旧 deliver のフルパイプライン承継 |

## ディスパッチ規則

1. **段階未指定の `$deliver` は `harden` として実行する。** 旧 `$deliver` が
   持っていた「verified local commit + full gate」の保証を暗黙に弱めない。
   既存の参照 (consolidate、tests、agent 定義) はこの既定で従来どおり成立する。
2. user が**同じ依頼文で**段階を明示した場合 (例: 「spike で」「まず動かす
   だけ」「ブラッシュアップして」) のみ、該当スキルへ委譲する。委譲時は選択
   した段階と根拠 (user の文言) を宣言してから実行する。
3. 変更の性質からの推論だけで spike / polish を選んではならない。迷ったら
   harden。降格の既定変更を望む場合は、別途の明示的な user decision とする。
4. spike / polish の内側で昇格トリガー (secret・権限境界・破壊的データ・
   外部公開) に触れたら、各スキルの規定どおり harden へ強制昇格する。

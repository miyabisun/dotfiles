---
name: deliver
description: >-
  互換ディスパッチャ。deliver は開発段階別の3スキル (spike / polish / harden)
  に分割された (decision 0002/0003)。まず決定的 gate (user の v1.0.0 宣言=
  明示 $harden 起動と同値、または version が既に 1.0.0 以上) を判定し、該当
  なら harden、非該当なら変更の性質から spike / polish を自動判断して選択と
  根拠を宣言する。リスクの重さからの推論で harden を選ばない。push・deploy・
  release はしない。
---

# deliver (dispatcher)

`deliver` は decision 0002 で開発段階別の3スキルに分割され、decision 0003 で
段階の既定が「作りたいものを何とか実装してくれる」方向へ再定義された。

| 段階 | スキル | 概要 |
|---|---|---|
| 黎明期 (〜v0.1.0) | `spike` | まず動かして体験を得る。TDD+軽レビュー1回 |
| ブラッシュアップ (0.x) | `polish` | 不満を直し v1.0.0 へ磨く。隣接チェック+レビュー1回 |
| 全世界に問いかける (v1.0.0〜) | `harden` | 旧 deliver のフルパイプライン |

## ディスパッチ規則

1. **まず決定的 gate を判定する**: user が「v1.0.0 にして全世界に問いかける」と
   宣言している (**明示的な `$harden` 起動はこの宣言と同値**)、または project の
   version (Rust なら Cargo.toml) が**既に 1.0.0 以上**なら、`harden` で実行
   する。この gate は依頼文が spike/polish を明示していても優先される
   (「これ既に v1.0.0 やん、なんで spike やねん」条項)。
2. gate に該当しなければ、変更の性質から **spike / polish を自動判断**し、
   選択した段階と根拠を宣言して実行する。新しい体験・greenfield・まだ動いて
   いないもの → spike。動いているものの改善・不満の解消 → polish。
   **迷ったら polish** (レビュー1回が付く方)。
   **リスクや成果物の重さからの推論で harden を選んではならない** —
   gate だけが harden への入口である (decision 0003)。
3. gate 非該当で user が同じ依頼文で段階を明示した場合はそれに従う。
4. spike の内側で credential・secret・権限境界・破壊的データに触れる必要が
   生じたときの昇格先は polish (各スキルの規定どおり)。

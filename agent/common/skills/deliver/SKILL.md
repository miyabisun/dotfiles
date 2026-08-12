---
name: deliver
description: >-
  互換ディスパッチャ。deliver は開発段階別の3スキル (spike / polish / harden)
  に分割された (decision 0002/0003/0004)。まず決定的 gate (user のリリース
  号令 = 明示 $harden 起動と同値) を判定し、該当なら harden、非該当なら変更の
  性質から spike / polish を自動判断して選択と根拠を宣言する。version・
  リスク・成果物の重さからの推論で harden を選ばない。push・deploy・release
  はしない。
---

# deliver (dispatcher)

`deliver` は decision 0002 で開発段階別の3スキルに分割され、decision 0003 で
段階の既定が「作りたいものを何とか実装してくれる」方向へ再定義された。

| 段階 | スキル | 概要 |
|---|---|---|
| 黎明期 (〜v0.1.0) | `spike` | まず動かして体験を得る。TDD+軽レビュー1回 |
| ブラッシュアップ (全 version) | `polish` | 不満を直し成熟へ磨く。隣接チェック+レビュー1回 |
| 出荷 (user のリリース号令) | `harden` | 出荷ゲート。旧 deliver のフルパイプライン |

## ディスパッチ規則

1. **まず決定的 gate を判定する**: user がリリース号令を出している —
   「リリースして v1.0.0 にしたい」「v1.0.0 にして全世界に問いかける」等、
   出荷ゲートの実行を明示した命令であって、文中に "release" が現れるだけの
   文は号令ではない — なら `harden` で実行する
   (**明示的な `$harden` 起動はこの号令と同値**)。
   **version は gate ではない** — project の version
   (Rust なら Cargo.toml) が 1.0.0 を過ぎていても、号令が無ければ harden を
   選ばない (decision 0004)。
2. gate に該当しなければ、変更の性質から **spike / polish を自動判断**し、
   選択した段階と根拠を宣言して実行する。新しい体験・greenfield・まだ動いて
   いないもの → spike。動いているものの改善・不満の解消 → polish。
   **迷ったら polish** (レビュー1回が付く方)。
   **リスクや成果物の重さからの推論で harden を選んではならない** —
   号令だけが harden への入口である (decision 0004)。
3. gate 非該当で user が同じ依頼文で段階を明示した場合はそれに従う。
4. spike の内側で credential・secret・権限境界・破壊的データに触れる必要が
   生じたときの昇格先は polish (各スキルの規定どおり)。
5. `$deliver` 自体に commit 手順は無い。選択した段階スキル (`spike` /
   `polish` / `harden`) の documented workflow に commit が含まれるとき、その
   commit 授権を継承する (GLOBAL Git 規則の delivery skill 例外と同一)。

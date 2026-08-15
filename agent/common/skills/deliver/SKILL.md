---
name: deliver
description: >-
  互換ディスパッチャ。変更の性質から spike / polish を自動判断して選択と
  根拠を宣言する。新しい体験・greenfield・まだ動いていないもの → spike。
  動いているものの改善・不満の解消 → polish。迷ったら polish。
  push・deploy・release はしない。
---

# deliver (dispatcher)

`deliver` は spike と polish の入口である。

| 段階 | スキル | 概要 |
|---|---|---|
| 黎明期 (〜v0.1.0) | `spike` | まず動かして体験を得る。TDD+軽レビュー1回 |
| ブラッシュアップ (全 version) | `polish` | 不満を直し成熟へ磨く。隣接チェック+レビュー1回 |

## ディスパッチ規則

1. 変更の性質から **spike / polish を自動判断**し、選択した段階と根拠を
   宣言して実行する。新しい体験・greenfield・まだ動いていないもの → spike。
   動いているものの改善・不満の解消 → polish。
   **迷ったら polish** (レビュー1回が付く方)。
2. user が同じ依頼文で段階を明示した場合はそれに従う。
3. `$deliver` 自体に commit 手順は無い。選択した段階スキル (`spike` /
   `polish`) の documented workflow に commit が含まれるとき、その
   commit 授権を継承する (GLOBAL Git 規則の delivery skill 例外と同一)。
4. `$deliver` は user の直接起動のほかに、user が起動した `working` skill が
   claim した修正 task からも呼ばれる。どちらの経路でも `$deliver` 自身と
   それが選ぶ `spike` / `polish` は push しない。
   **push を所有するのは呼び出し元の `working` である**。

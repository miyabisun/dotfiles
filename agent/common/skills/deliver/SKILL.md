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
| 黎明期 (〜v0.1.0) | `spike` | まず動かして体験を得る。TDD+軽い実装レビュー |
| ブラッシュアップ (全 version) | `polish` | 不満を直し成熟へ磨く。隣接チェック+実装レビュー |

段階を跨ぐ正本は 2 つある。**工程と所有者は [PROCESS.md](PROCESS.md)**、
**段階 skill の共通契約は [CONTRACT.md](CONTRACT.md)** が持つ。
`spike` / `polish` は段階固有の差分だけを持つ。

## ディスパッチ規則

1. 変更の性質から **spike / polish を自動判断**し、選択した段階と根拠を
   宣言して実行する。新しい体験・greenfield・まだ動いていないもの → spike。
   動いているものの改善・不満の解消 → polish。
   **迷ったら polish** (検証が厚い方)。
2. user が同じ依頼文で段階を明示した場合はそれに従う。
3. `$deliver` 自体に commit 手順は無い。選択した段階スキル (`spike` /
   `polish`) の documented workflow に commit が含まれるとき、その
   commit 授権を継承する。
4. `$deliver` は user の直接起動のほかに、task-worker が claim した task の
   session からも呼ばれる (pipeline 経路)。どちらの経路でも `$deliver` 自身と
   それが選ぶ `spike` / `polish` は push しない。
   起動 prompt が **pipeline 所有を宣言しているとき**は、独立実装レビューを
   control plane の review 工程が所有する。段階 skill は実装レビュー召喚を
   行わない。**宣言が無ければ local へ倒す** (推測しない)。宣言の文面と
   所有者は [PROCESS.md](PROCESS.md#レビュー工程の所有者) が持つ。

---
name: git
description: >-
  Use before any git operation: worktree, branch, commit, merge, push.
  Holds the house rules for commit messages and branch flow shared by
  every runtime.
---

# git

git コマンドで操作する場面の共通ルール。

## コミットメッセージ

- 常に英語で書く
- Conventional Commits 形式を使う (例: `feat:`, `fix:`, `refactor:`)
- **message は 1 行だけ** (subject のみ・本文なし)。50 字を目安に最大 72 字
- 1 行に収まらない経緯・設計判断・却下した代替案・教訓は commit message
  ではなく knowledge の領分 — `knowledge-deposit` で預ける。`git log` は
  1 画面で流し読みできる状態を保つ

## ブランチフロー

- タスク用の作業ブランチ上では自発的に進めてよい: worktree の複製 →
  新ブランチ作成 → commit → そのブランチの push は通常の配達作業であり、
  追加の許可は不要
- 共有ブランチ (デフォルトブランチや他者が作業中のブランチ) へ直接
  コミットしない。自分のブランチからマージで載せる

## 専用スキルとの関係

`merge` / `rebase` / `bump-tag` が明示起動された場合は、そのスキルの documented
workflow に従う。本スキルはそれらに共通する土台。

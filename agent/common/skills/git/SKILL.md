---
name: git
description: >-
  git のあらゆる操作の前に使う: worktree, branch, commit, merge, push。
  commit message とブランチフローについて、すべての runtime で共有する
  共通ルールを持つ。
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

- **既定は今いるブランチに積む。** 新規ブランチの作成は任意である。
  既定ブランチへ直接 commit してよい
- **git 操作として新規ブランチを切った側が、そのブランチを完走させる** —
  worktree / branch の作成 → commit → push → `merge` skill で既定ブランチへ
  反映 → 成功後に local / remote の branch を片付ける。**追加の号令を待たない**
- そのブランチの push は通常の配達作業であり、追加の許可は不要

## 専用スキルとの関係

`merge` / `rebase` / `bump-tag` / `working` が明示起動された場合は、その
スキルの documented workflow に従う。本スキルはそれらに共通する土台。

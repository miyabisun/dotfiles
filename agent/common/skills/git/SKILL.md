---
name: git
description: >-
  git のあらゆる操作の前に使う: worktree, branch, commit, merge, push。
  commit message とブランチフローについて、すべての runtime で共有する
  共通ルールを持つ。
---

# git

git コマンドで操作する場面の共通ルール。

## 同期と完了

- repositoryを変更する前に、作業ツリー・現在のbranch・upstreamを確認する。
  remoteをfetchして同期する。fast-forwardできれば前進させ、分岐していれば両方の変更を保って統合する。
  他者の未コミット変更を巻き込まず、未送信のcommitを捨てない。
- **通常の完了は、必要な検証・レビューを終えたcommitをpushするまで。**
  既存・新規いずれのbranchも、push・pullの追加の号令を待たない。
  ユーザーが明示的にローカル限定・push保留を指定した場合は、その指示を優先する。
- push時にremoteが進んでいたら、fetch・統合・競合解消・影響範囲の再検証を担当が進め、再度pushする。
  既存の要件から決められない製品判断だけをユーザーへ返す。通常pushをforceで押し通さない。
- pushの成功と送信先を確認して報告する。認証・通信・権限などの障害は解消を試み、
  解消できなければ実際の障害と未送信のcommitを報告する。未pushを完了扱いにしない。

## コミットメッセージ

- 常に英語で書く
- Conventional Commits 形式を使う (例: `feat:`, `fix:`, `refactor:`)
- **message は 1 行だけ** (subject のみ・本文なし)。50 字を目安に最大 72 字
- 1 行に収まらない経緯・設計判断・却下した代替案・教訓は commit message
  ではなく knowledge の領分 — `knowledge-deposit` で預ける。`git log` は
  1 画面で流し読みできる状態を保つ

## ブランチフロー

- pushはremoteへの送信を指す。ローカルbranchを更新しただけではpush完了としない。
- **既定は今いるブランチに積む。** 新規ブランチの作成は任意である。
  既定ブランチへ直接 commit してよい
- **新規ブランチを切った側が、そのブランチを完走させる。**
  worktree / branch の作成からcommit・pushまで進める。
  `merge` skillで既定ブランチへ反映し、成功後にlocal / remoteのbranchを片付ける。**追加の号令を待たない。**
- pushは通常の配達作業であり、追加の許可は不要

## 専用スキルとの関係

`merge` / `rebase` / `bump-tag` が明示起動された場合は、その
スキルの documented workflow に従う。本スキルはそれらに共通する土台。

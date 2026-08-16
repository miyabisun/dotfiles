---
name: knowledge-read
description: >-
  Run before starting any development work. Locates the knowledge (OKF)
  repository via $KNOWLEDGE_REPO and reads the shared development rules and
  user context stored there.
---

# knowledge-read

開発作業を始める前に、knowledge の共有情報を読む。

ユーザーに関する情報や共通開発ルールは knowledge に **OKF** として
まとめられている (OKF: Google 発の、Markdown で作るゆるい DB 形式)。

## 手順

1. knowledge repository の場所は環境変数 `$KNOWLEDGE_REPO` が教える。
   これはマシンローカルのシェル設定 (`~/.zshrc` など) が持つマシン固有の
   事実であり、スキルにパスを決め打ちしない
2. `$KNOWLEDGE_REPO` が未設定なら、ユーザーに場所を尋ね、シェル設定への
   `export KNOWLEDGE_REPO=<path>` の追記を提案する。勝手に推測しない
3. repository 直下の index (README や `library/index.md`) から入り、
   現在のプロジェクトに関係する `projects/<name>/` と共通ルールを読む。
   以後は OKF のルールに従って情報を閲覧する

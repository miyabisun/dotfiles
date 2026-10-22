---
name: project-architecture
description: >-
  CI・検証の門・ブランチ運用・release/配備の経路・実行先・repo構成など、製品の開発基盤に触れる
  タスク本文や実装を書く前に、自宅開発の前提と対象repoの現状を確かめる。アプリの挙動だけの変更には使わない。
---

# 開発基盤の前提を確かめる

[task-creater](../task-creater/SKILL.md)の候補や[deliver](../deliver/SKILL.md)の実装が次に触れるとき、書く前に読む。

- GitHub Actionsのworkflow、format・lint・testを実行する場所
- ブランチとPR、release・配備の経路
- 実行先（sandbox・homeserver・game）、repo・crateの構成

## 前提

- 開発はPR駆動ではない。既定ブランチへ直接commitする（[git](../git/SKILL.md)）。
- 検証の門は手元にある。format・lint・test・buildはcommit前に[test-verify](../test-verify/SKILL.md)で通す。
  未検証のcommitは `agent-test` hookが拒否する（dotfilesの `agent/README.md`「エージェント共通のテストゲート」）。
- エージェントはpush後のCIの結果を門として読まない。GitHub Actionsへlint・format・testのゲートを足さない。
  CIはtagを契機とするreleaseのbuildとartifactの公開を持つ。
  経路はknowledgeの `library/playbooks/tag-driven-service-release.md` にある。
  既存repoにpushで動くlint・testのjobがあっても、手本にして他のrepoへ広げない。

根拠（2026-10-22 user）:

- 「ActionsのCIでやるな」
- 「お前はlinterやformatterで確認すらしていないような物を出来ました！とコミットするつもりか？」
- 「PR駆動開発じゃないし、このAIエージェントはCIの結果なんて読まないから
  GitHub ActionsのCIでテストやLinterのゲートを書く意味が全くない」

## 手順

1. 対象product indexの開発基盤に関する判断を[knowledge-read](../knowledge-read/SKILL.md)で読む。
   対象repoの `.github/workflows` と、そこに書かれた方針のコメントも読む。
2. 前提・knowledge・repoの方針コメントと食い違う指示や既存設定は、食い違いを候補本文や報告に書く。
   担当が書き足した方針で前提を上書きしない。原文参照のない記録は担当判断として扱う（knowledge-read末尾）。
3. 検査は完了条件の「手元で実行して成功」に置き、CIの成功で代えない。
   release対象はtagで動くworkflowの成功とartifactを確かめる。

---
name: project-architecture
description: >-
  CI・検証の門・ブランチ運用・release/配備の経路・実行先・repo構成など、製品の開発基盤に触れる
  タスク本文や実装を書く前に、自宅開発の前提と対象repoの現状を確かめる。アプリの挙動だけの変更には使わない。
---

# 開発基盤の前提を確かめる

[task-creator](../task-creator/SKILL.md)の候補や[deliver](../deliver/SKILL.md)の実装が次に触れるとき、書く前に読む。

- GitHub Actionsのworkflow、format・lint・testを実行する場所
- ブランチとPR、release・配備の経路
- 実行先（agent-hub・homeserver・game）、repo・crateの構成

## 前提

- 開発はPR駆動ではない。レビュー待ちのPRを作らず、既定ブランチへ直接commitするか、作業branchを自分で既定ブランチへmergeする（[git](../git/SKILL.md)）。
- 検証の門は手元にある。format・lint・test・buildはcommit前に[test-verify](../test-verify/SKILL.md)で通す。
  Claude Code / Codex など `agent-test` hook が導入された環境では、未検証のcommitをhookが拒否する（dotfilesの `agent/README.md`「エージェント共通のテストゲート」）。
- エージェントはpush後のCIの結果を門として読まない。GitHub Actionsへlint・format・testのゲートを足さない。
  CIはtagを契機とするreleaseのbuildとartifactの公開を持つ。
  経路はknowledgeの `rules/release-and-ci.md` にある。
  CIに残す照合は、tagと版・archiveの中身・checksum・image digestの一致だけにする。
  formatterの検査、linter、smoke・e2eを含むテストは、repoの手元の検証手順に置く。
  既存repoにpushで動くlint・testのjobがあっても、手本にして他のrepoへ広げない。
- execution_targetがgameの製品はWindowsで走らせるので、CIのこの前提から外す。
  対象の `projects/<repo>.md` や repo の workflow に方針があれば、それに従う。

## 手順

1. [knowledge-read](../knowledge-read/SKILL.md)で `rules/release-and-ci.md` と、対象があれば `projects/<repo>.md` を読む。
   対象repoの `.github/workflows` と、そこに書かれた方針のコメントも読む。
2. 前提・knowledge・repoの方針コメントと食い違う指示や既存設定は、食い違いを候補本文や報告に書く。
   担当が書き足した方針で前提を上書きしない。
3. 検査は完了条件の「手元で実行して成功」に置き、CIの成功で代えない。
   release対象はtagで動くworkflowの成功とartifactを確かめる。

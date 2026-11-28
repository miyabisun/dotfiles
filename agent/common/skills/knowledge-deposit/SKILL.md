---
name: knowledge-deposit
description: >-
  再利用する NG/正解行動・横断ルール・コード外の物理実測や地雷だけを
  $KNOWLEDGE_REPO へ上書き維持し、scripts/lint を通して commit・push する。
---

# knowledge-deposit

全エージェント共通の薄い規範と地雷だけを `$KNOWLEDGE_REPO` に保つ。
**タスク完了ごとの自動記録はしない。** 進捗・完了報告・テスト件数・廃止履歴・ユーザーの逐語引用は書かない。

## 更新する条件と置き場

- **横断の NG / 正解行動**: `MEMORY.md` に 1 行で追記・更新する（上限 150 行）。
  詳しい基準が必要な場合だけ `rules/<topic>.md` に分け、`MEMORY.md` からリンクする。
- **プロジェクト固有の物理実測・環境地雷・権利境界**: `projects/<repo>.md` を最新事実で上書きする（上限 200 行）。
  仕様や実装詳細はコード・README に任せ、ここへ写さない。
- **古くなった・誤った記述**: 追記で履歴を積まず、該当箇所を上書きまたは削除する。

## 書き方と検査

- 中立で短い行動規範として書く。秘密情報・私設 IP（`192.168.*` 等）・内部ホスト名・R18 区画の path/ラベルは入れない。
- 編集した path へ `$KNOWLEDGE_REPO/scripts/lint <path>...` を実行し、指摘ゼロを確認する。
- [git](../git/SKILL.md) に従い、自分の差分だけを stage して commit・push する（他者の未 commit 変更を巻き込まない）。

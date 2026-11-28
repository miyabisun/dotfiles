---
name: task-creator
description: >-
  タスクの新規作成・大幅な変更時に、要件と完了条件を短く整理して task-server へ登録する。
  単純な状態変更やメモ追記だけには使わない。
---

# task-creator

タスクの要件整理と登録を所有する。実装・検証・レビューは [deliver](../deliver/SKILL.md) が所有する。

## 登録前に確認すること

1. 対象 repo の現在のコード・設定（推測で書かない）
2. `task_search`（必要なら `task_list`）で重複・関連タスクの有無
3. 必要な場合だけ関連スキルを読む（UI 変更なら `design-context`、CI/配備変更なら `project-architecture`、既存設計判断に触れるなら `knowledge-read`）

## 本文の書き方

短く、素直な日本語で書き、トークンと読む手間を節約する。

- ユーザーの生発言・誤字脱字・感情表現をそのまま引用コピペしない。意図を汲んで自然な日本語に整える。
- 「やらないこと」「対象外」は言質取りのように発言を引用せず、仕様の境界として簡潔に書く。
- 元の意図にある機能・対になる操作（例: 施錠と解錠、Web 管理画面など）を勝手に狭めない。未決の問いは黙って決めない。
- 本文は次の 3 点（目的、方針・条件、完了条件）に絞って書く。

## 登録（MCP）

- ツールは `task_create` / `task_update` / `task_append` / `task_move` を使う。
- 作成だけなら `status: "draft"`、実行の合意があれば最初から `status: "ready"` で 1 回で登録する。
- 関連リポジトリは `project`（例: `sunny-side/home-server`）、前提タスクは `depends_on`（配列）、実行先や補足（`homeserver`, `game`, `release:minor` 等）は `tags` に付ける。
- 人が手を動かす作業（物理操作・外部画面の設定・目視確認）はタスクにせず [todo](../todo/SKILL.md) へ登録する。
- 登録後は ID・タイトル・status だけを短く返す。登録前に別モデルレビューや追加の承認工程は挟まない。

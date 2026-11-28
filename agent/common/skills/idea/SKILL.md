---
name: idea
description: >-
  タスクになるか未定の思いつき・構想を、task-server の ideas フォルダで記録・調査・破棄・タスク化する。
  「アイデア出し」「アイデアとして残す」「このアイデアを調べて」などの依頼で使う。
---

# idea

アイデアは task-server の `ideas` フォルダで管理する。MCP ツールはタスクと共通（`task_list` / `task_search` / `task_get` / `task_create` / `task_append` / `task_move` / `task_delete`）。

## 記録する

1. `task_search`（または `task_list(status="ideas")`）で同じ主題が無いか探す。あれば新規作成せず `task_append` で追記する。
2. `task_create(title=..., status="ideas", project=..., body=...)` で登録する。ユーザーの生発言・誤字脱字を引用コピペせず、狙い・案・調査結果・未決事項を素直な日本語で短く書く。
3. ID とタイトルを短く返す。

## 調べて育てる

`task_append(id, text=...)` で調査結果や出典 URL を末尾へ追記する（本文全体を送り直さない）。

## 破棄する・タスク化する

- 破棄: 残す価値がなければ `task_delete(id)`。経緯を残すなら理由を `task_append` して `done` へ移す（必要ならタグ `idea-archived`）。
- タスク化: user が明示したときだけ行う。[task-creator](../task-creator/SKILL.md) に従って完了条件を整え、`task_update(id, body=..., status="draft")`（実行指示があれば `status="ready"`）で移動する。

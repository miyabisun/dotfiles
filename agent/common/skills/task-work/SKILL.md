---
name: task-work
description: >-
  task-server の ready タスクを、deliver・merge・必要なら patch リリースまで完走する。
  「タスクを全てこなす」自動運転に使う。
---

# task-work

task-server（MCP: `task_list` / `task_get` / `task_search` / `task_move` / `task_append`）上のタスクを成果まで進める。
agent-hub の対話型エージェントへ `/goal` で全件の完了を頼んで始める。

- Claude Code: `/goal task-serverのタスクを全て完了させてください`
- Codex: `/goal $task-work を使ってtask-serverのタスクを全てこなして`
- agy: `/goal task-work skillに従ってtask-serverのタスクを全て完了させてください`

agy は配車係を務め、worker は [herdr-worker](../herdr-worker/SKILL.md) で Claude Code を起動する。
user による実行依頼は commit・push・merge と、リリース対象 repo での `bump-tag patch` を含む。

## 配車（全件モード）

配車係は同時 1 本の worker で回す。`game` タグ（Windows 専用）や人が手を動かす作業は対象外として残件にする。

1. `task_list(ready_only=true)` で依存が解消済みの `ready` タスクを確認する（再開時は `wip` や残存 `task-*` workspace も確認）。
2. 優先度順に選ぶ。同じ `project` の関連タスクは 1 人の worker にまとめて順に渡してよい（毎回ゼロから読み直す無駄を省く）。
3. `herdr-worker` で worker（名前 `task-<id先頭8桁>` 等）を起動し、対象 `id`（複数可）と次の依頼を渡す。
   `/goal task-work の 1 件モードで対象タスクを順に完走し、各件を done または blocked に移す。user に質問せず、判断できない点は blocked に理由を追記する。本文の完了条件に無い余計な検証は足さない。`
4. worker 終了後、`task_get` / Git / CI で結果を照合する。不足があれば `task_append` で補足を足して `ready` に戻す。
5. worker を片付け、`/tmp` の不要ファイルを掃除して次へ進む。配車できる `ready` が無くなったら完了件数と残件だけを短く報告する。

## 1 件モード（worker）

1. `task_get` で対象タスク（複数指定なら `ids` で一括）を読む。
2. 着手する 1 件を `task_move(id, to="wip", expected_status="ready")` で `wip` に移す（競合したらスキップ）。
3. 対象 repo の最新既定ブランチから専用 branch / worktree を作り（他者の未 commit 変更に触れない）、`knowledge-read` → `deliver` で実装・検証・レビュー・修正・commit・push を行う。
4. `merge` で既定ブランチへ統合・push し、worktree を片付ける。
5. リリース対象（Docker image や配布バイナリを tag でビルドする repo）なら既定ブランチで `bump-tag patch` を実行し、CI と公開成果物の成功を確認する（変更不要なら空リリースしない。dotfiles 等はリリース不要）。
6. 作業用の一時ファイル（`/tmp` 等に自分が作ったもの）と起動した一時プロセスを片付ける。
7. 完了報告は `task_append(id, text="## 結果\n- commit: <sha>\n- release: <tag or なし>\n- 検証: <コマンドと結果>", status="done", expected_status="wip")` の 1 回で閉じる。
8. 進められない場合は `task_append(id, text="## ブロック理由\n<理由と再開条件>", status="blocked")` で途中状態と理由を短く追記して止める。

---
name: task-work
description: >-
  task-serverの未完了タスクを、新しいサブエージェントでのdeliver、merge、
  patchリリースまで1件ずつ完走する。「タスクを全てこなす」自動運転に使う。
---

# task-work

親は台帳と次の工程を持ち、実装はタスクごとに新しい子へ渡す。
`/goal $task-work を使ってtask-serverのタスクを全てこなして` が入口。
**userによるこの実行依頼は、対象タスクのcommit・push・mergeと、リリース対象
productの `$bump-tag patch` を含む。** スキルの作成・説明依頼では実行しない。
タスクに明示されたrelease水準やuserの制限は優先する。

## 引き取る

1. `knowledge-read` と `git` を読み、MCPでタスク一覧とproduct情報を取得する。
   全件は通常タスクのdraft・ready・再開対象blocked。closedとarchivedは除く。
   詳細は着手する1件だけ取得してfileへ保存し、子へ参照先を渡す。親のcontextには
   ID・product・状態・短い成果を残し、本文・legacy・ログ全文を毎回展開しない。
   依存順に進め、後から追加されたタスクも
   同じ全件依頼の範囲なら取り込む。対象を狭めた依頼では範囲外を実行しない。
2. [台帳との接続](references/queue.md) に従い既存executorと競合しない状態にし、
   親がclaim・heartbeat・reportを所有する。子や別のloopへ二重に引き取らせない。
3. 再開できるタスクをreadyにし、1件claimする。blockedの原因が変わっていない
   ものは同じ実行を反復せず、独立したタスクへ進む。204だけで全件完了にしない。

## 1件を完走する

1. productのrepositoryとローカルbare repositoryを照合し、originの既定ブランチ
   からタスク専用branch・worktreeを作る。通常cloneならそのrepositoryで同じ操作を
   行う。再開時は記録した自分のworktreeと変更を再利用し、他者の作業を保護する。
2. **新しいサブエージェント**へ、タスク本文、worktree、対象repoの規約、達成条件、
   再開時の証拠だけを渡し、そこで `knowledge-read` → `deliver` を実行させる。
   会話全文・全タスク・haystack全文は渡さない。Codexのspawn_agentでは
   `fork_turns: "none"` を指定する。子は検証・独立レビュー・指摘修正と
   local commitまでを担当し、merge・release・台帳操作は親へ返す。この分担を子へ
   明示し、他者の変更を戻さないよう伝える。
3. 子の返却は成果、commit、検証・レビュー証拠、残件と参照先。親は差分と証拠を
   確認し、未達なら修正を子へ戻す。レビュー手順はdeliverが所有し、親は重複しない。
4. 子の終了を確認し、`merge` で既定ブランチへ統合・pushとworktreeの片付けを行う。
   競合は同skillから `rebase` へ渡して解消し、mergeへ戻る。
   未修正の指摘やmerge失敗を成功扱いして先へ進まない。
5. productが `releases: true` なら、既定ブランチで **`bump-tag patch`** を実行する。
   version計算・commit・tag・pushは同skillに任せる。親はそのcommitのCIとrelease
   workflowの成功、公開artifactを確認する。起動確認だけではreleasedにしない。
   `releases: false` はリリース不要と記録する。変更不要なら既存artifactの包含を
   確認し、空のreleaseを作らない。配備がタスクに含まれる場合は実反映・動作確認も行う。
6. 要求された成果がそろってから、doneと結果の原文を一度reportする（haystackにも保存される）。
   merge済みcommitをtaskの対象SHAとし、release tag・artifact・CI URLも証拠に残す。
   次のタスクへ進む。local commitやCIの起動で依頼全体を終えない。

## 中断・復帰

worktree、子のhandle、完了工程のSHA・tag・CI URL、次の工程は、工程の境界で
[台帳のcheckpoint](references/queue.md#引き継ぎ情報)へ保存する。未送信payloadと詳細ログは
repository外へ保管し、その参照先を残す。待機中もleaseを更新する。
子の観測timeoutは終了ではなく、同じhandleを確認する。親が再開したらcheckpointを読み、
台帳・Git・CI・子の実在と稼働を照合し、既に統合・公開済みの工程は飛ばす。
新claimでは必要な引き継ぎ値だけを保存し直す。前の実行の状態や所有権を引き継いだとみなさない。
CI失敗は原因を修正して再確認する。公開済みtagは動かさず、追加releaseが必要なら
同じ依頼の範囲でbump-tagを使う。失敗を理由に最初からdeliverやbumpを繰り返さない。

進められない1件は理由・保存先・残工程をblockedのreportに残し、他のタスクを続ける。
最後に一覧を再確認し、残件があれば全件完了とは報告しない。元のexecutorを復元し、
完了件数、release、未完了と実際に必要な対応だけを返す。

---
name: task-work
description: >-
  task-serverの未完了タスクを、deliver、merge、
  patchリリースまで1件ずつ完走する。「タスクを全てこなす」自動運転に使う。
---

# task-work

担当は台帳と次の工程を持ち、各タスクを成果まで進める。
`/goal $task-work を使ってtask-serverのタスクを全てこなして` が入口。
userによる実行依頼は、対象タスクのcommit・push・mergeを含む。
リリース対象productでは `$bump-tag patch` まで実行する。 スキルの作成・説明依頼では実行しない。
タスクに明示されたrelease水準やuserの制限は優先する。

## 引き取る

1. `knowledge-read` と `git` を読む。実行先は呼び出し元の設定・userの指定に従い、
   指定がなければ現行運用の `sandbox` とする。`homeserver` は明示された場合だけ選ぶ。
   MCPでタスク一覧とproduct情報を取得し、今回の実行先に一致するタスクを対象にする。
   タスク本文から実行先を推測したり、取得のために実行先を変更したりしない。
   着手する製品は`product_get({id})`でrepository・local_path・releasesを読む。
   未設定のrepository・releasesは実在と運用設定を確認して`product_update`で補う。releasesの未設定とfalseを混同しない。
   一覧はnext_offsetがnullになるまでページを取得し、最初のページだけで全件完了にしない。
   本文はtask_get、報告原文はrun_get、証拠履歴はtask_history、再開情報はtask_checkpoint_getで
   必要なものだけ取得する。一覧や更新応答に詳細が埋め込まれる前提を置かない。
   全件は通常タスクのdraft・ready・再開対象blocked。closedとarchivedは除く。
   詳細は着手する1件だけ取得してfileへ保存する。進捗の一覧には
   ID・product・状態・短い成果を残し、本文・legacy・ログ全文を毎回展開しない。
   依存順に進め、後から追加されたタスクも
   同じ全件依頼の範囲なら取り込む。対象を狭めた依頼では範囲外を実行しない。
2. [台帳との接続](references/queue.md) に従い既存executorと競合しない状態にし、
   担当がclaim・heartbeat・reportを所有する。委譲先や別のloopへ二重に引き取らせない。
3. 再開できるタスクをreadyにし、1件claimする。blockedの原因が変わっていない
   ものは同じ実行を反復せず、独立したタスクへ進む。204だけで全件完了にしない。

## 1件を完走する

1. productのlocal_pathがこのマシンに存在すればrepositoryとGitのoriginを照合する。
   存在しない・未設定なら、登録済みrepositoryからこの実行者のローカル領域へcloneする。
   別マシンの絶対パスを再現せず、共有productのlocal_pathも書き換えない。
   originの既定ブランチからタスク専用branch・worktreeを作る。通常cloneならそのrepositoryで同じ操作を
   行う。再開時は記録した自分のworktreeと変更を再利用し、他者の作業を保護する。
2. そのworktreeで `knowledge-read` → `deliver` を進め、検証・レビュー・指摘修正と
   local commitまで完了する。分担とレビュー方法はdeliverの手順に従う。
   委譲する場合はタスク本文・worktree・規約・達成条件・再開時の証拠の参照先を渡す。
   merge・release・台帳操作の所有者を明示し、成果、commit、検証・レビュー証拠、残件を受け取る。
3. 差分と証拠を確認し、未達なら修正する。レビュー手順はdeliverが所有し、重複しない。
4. 委譲した場合は作業先を使っている子の終了を確認する。
   `merge` で既定ブランチへ統合・pushとworktreeの片付けを行う。
   競合は同skillから `rebase` へ渡して解消し、mergeへ戻る。
   未修正の指摘やmerge失敗を成功扱いして先へ進まない。
5. productが `releases: true` なら、既定ブランチで **`bump-tag patch`** を実行する。
   version計算・commit・tag・pushは同skillに任せる。担当はそのcommitのCIとrelease
   workflowの成功、公開artifactを確認する。起動確認だけではreleasedにしない。
   `releases: false` はリリース不要と記録する。変更不要なら既存artifactの包含を
   確認し、空のreleaseを作らない。配備・実機確認は、その作業を含むhomeserver向けタスクで実施する。
6. 要求された成果がそろってから、doneと結果の原文を一度reportする（haystackにも保存される）。
   merge済みcommitをtaskの対象SHAとし、release tag・artifact・CI URLも証拠に残す。
   次のタスクへ進む。local commitやCIの起動で依頼全体を終えない。

## 開発と実機作業の引き継ぎ

タスク作成・範囲変更、利用先の確認、実行先・depends_on・完了条件の分割は
[task-creater](../task-creater/SKILL.md) が所有する。通常のready化では事前レビューを重ねない。
実行担当は事前判断をdeliverへ渡し、前提タスクの完了報告から対象版と検証証拠を後続へ引き継ぐ。
授権済みの後続を続け、範囲外の発見はdeliverのdraft登録に従う。

## 中断・復帰

worktree、委譲した場合は子のhandle、完了工程のSHA・tag・CI URL、次の工程は、工程の境界で
[台帳のcheckpoint](references/queue.md#引き継ぎ情報)へ保存する。未送信payloadと詳細ログは
repository外へ保管し、その参照先を残す。待機中もleaseを更新する。
委譲先の観測timeoutは終了ではなく、同じhandleを確認する。再開したらcheckpointを読み、
台帳・Git・CIと委譲先があればその稼働を照合し、既に統合・公開済みの工程は飛ばす。
新claimでは必要な引き継ぎ値だけを保存し直す。前の実行の状態や所有権を引き継いだとみなさない。
CI失敗は原因を修正して再確認する。公開済みtagは動かさず、追加releaseが必要なら
同じ依頼の範囲でbump-tagを使う。失敗を理由に最初からdeliverやbumpを繰り返さない。

進められない1件は理由・保存先・残工程をblockedのreportに残し、他のタスクを続ける。
最後に両実行先の一覧を再確認し、依頼範囲に別実行先の残件があればその待機先を報告する。
残件があれば全件完了とは報告しない。元のexecutorを復元し、
完了件数、release、未完了と実際に必要な対応だけを返す。

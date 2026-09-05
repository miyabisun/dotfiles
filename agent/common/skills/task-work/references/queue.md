# 台帳との接続

task-serverのMCP接続先を稼働設定から取得する。`/mcp` を除いたURLをHTTPのbaseに
使う。接続情報はこのskillやdotfilesへ複製しない。MCPは一覧・詳細・readyへの更新、
HTTPはleaseと結果記録を担う。現行MCPにclaim/heartbeat/reportツールはない。

## 実行者

同じ台帳を処理する既存executorを確認する。ローカルの `task-loop.service` が
動いている場合は、実行中のタスクを奪わず完了を待ち、idleになってから停止する。
停止後にclaimが残っていないか再確認する。外部の生きたclaimは完了を待ち、孤児は
期限切れ後に再開する。開始前の稼働状態をメモし、最後に元に戻す。
別の手動親も同時に起動しない。既存claimを持つloopから呼ばれた場合は全件取得せず、
その1件だけを処理し、claim/reportは呼び出し元へ返す。

## HTTP契約

すべてJSON POST。入力と未送信の結果は作業メモの隣へ保存し、HTTPエラーを無視しない。

| path | 入力 / 応答 |
| --- | --- |
| `/worker/claim` | `{"worker":"task-work:<run-id>"}` → 204、または `{claim_id,lease_expires_at,task}` |
| `/worker/heartbeat` | `{"claim_id":"…"}` → 更新された期限。応答期限の半分以内、最大30秒間隔で更新 |
| `/worker/report` | `{claim_id,outcome:"done"または"blocked",report_markdown,commit_sha?,checks?,milestones?,run:{worker:"task-work"}}` → `report_id`を含むtask（`?`は省略可） |

claimは全readyから選び、ID指定はできない。対象を限定した依頼で範囲外のreadyがある
場合は引き取らず、その制約を報告する。全件実行なら依存がdoneのものから順に取れる。
claim中はMCPからtaskを更新できない。heartbeatで期限切れ・claim喪失を確認したら
子を止めて成果を保全し、台帳を読み直す。reportの内容不一致409とは区別する。
古いclaimで未受理のreportを押し通さない。

成果・検証・残件・参照先は自由なMarkdownの`report_markdown`へ一度書く。
reportはその原文をhaystackへ保存し、taskとmilestoneから参照する。別のruns追記は不要。
milestoneは `{name,commit_sha?}`。nameはimplemented/verified/reviewed/merged/released。
taskの対象SHAに対応する今回の達成分だけを渡す。証拠の説明は原文にまとめ、各欄へ複製しない。
返された`report_id`の原文はMCP `run_get({id:"…"})`で取得できる。送信失敗なら保存した同じpayloadを
再送してから次のclaimへ進む。同claim・同payloadは冪等。内容不一致409なら、保存した
元payloadとtaskの`report_id`を照合し、別内容で上書きしない。

## 引き継ぎ情報

MCP `task_checkpoint_get({id,execution_id?})`で引き継ぎ値を取得する。execution_idはclaim ID。
省略時は各実行のcheckpointを取得でき、未claimなら空。期限切れ後も過去の値を読める。
応答は`{task_id,active_claim_id,checkpoints:[...]}`。手元で所有するclaimとactive_claim_idを照合し、
現在のcheckpointを選ぶ。各checkpointは`execution_id,revision,updated_at,values`を持つ。

更新は`task_checkpoint_update({id,claim_id,expected_revision,set?,delete_keys?})`。
getで得たrevisionを渡し、setオブジェクトで必要なキーだけ更新、delete_keys配列で明示削除する。
更新が競合したら再取得して必要なキーだけ再適用する。claim喪失なら更新を押し通さない。
JSON値は引き継ぎ用であり、正式なtask状態・milestone・leaseを変更しない。
branch/worktree、agent、CI URL、next_step、詳細ログの参照先などを保存し、認証情報は入れない。

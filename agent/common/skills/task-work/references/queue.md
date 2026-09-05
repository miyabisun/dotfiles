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
| `/worker/report` | `{claim_id,outcome:"done"または"blocked",commit_sha,summary,verification,checks:[],milestones:[]}` |
| `/worker/runs` | `{source:"task-work",task_id,claim_id,attempt:1,note:"成果・検証・残件・参照先"}` |

claimは全readyから選び、ID指定はできない。対象を限定した依頼で範囲外のreadyがある
場合は引き取らず、その制約を報告する。全件実行なら依存がdoneのものから順に取れる。
claim中はMCPからtaskを更新できない。期限切れ・409では所有権を失っているので子を
止めて成果を保全し、台帳を読み直す。古いclaimでreportを押し通さない。

milestoneは `{name,evidence,commit_sha}`。nameはimplemented/verified/reviewed/merged/
released。taskの対象SHAに対応する証拠と今回の追加分だけを渡す。既存証拠を再送しない。
report成功後にrunsを送る。送信失敗なら保存した同じpayloadで再送してから次のclaimへ
進む（reportは同claim・同payload、runsはsource+claim_id+attemptで冪等）。

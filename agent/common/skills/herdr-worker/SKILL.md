---
name: herdr-worker
description: >-
  homeserverからherdrでsandbox等のマシンにagentを起動し、作業を渡して終わるまで見届ける。
  sandboxで開発させる、別の実行先へ作業を委譲する、task-workの配車で使う。
---

# herdr-worker

依頼元はworkerを起動し、作業を渡し、成果を確かめて片付けるまでを持つ。
workerの質問・入力待ち・承認ダイアログには依頼元が答え、userを承認ゲートにしない。
herdr CLIの細部は `herdr --skill` に従う。

| 実行先 | herdr | worker の cwd |
| --- | --- | --- |
| homeserver | ローカル | `~/projects/household/workers` |
| sandbox | `--machine sandbox` | `~/projects/household/workers/main` |

依頼元はhomeserverに置く（sandboxからhomeserverへは届かない）。以下の `herdr` には実行先の列を付ける。
machineが無ければ `herdr machine add --label sandbox sandbox` で足す。両マシンのherdrが0.9.1以上であること。

## 起動して渡す

1. `herdr workspace create --label <名前> --cwd <cwd> --no-focus` で作る。返る `.result.root_pane.pane_id` を次に使う。
   名前は依頼が分かる短いもの。同名のworkspaceが残っていれば作り直さず、そのworkerを待つ。
2. `herdr agent start <名前> --kind <自分と同じruntime> --pane <pane_id>`
3. `herdr agent prompt <名前> "<依頼>" --wait` を背景で実行する。依頼は `/goal` で始め、
   目的・対象（repo・タスクID）・完了条件・報告先を書く。依頼元の会話を前提にしない。
   「userには質問せず、判断できない点は理由を書いて止まる」を添える。

## 見届ける

- 待機が戻ったら、成果を一次情報（台帳・Git・CI・実機）で確かめる。workerの自己申告だけで完了にしない。
- 止まっていたら `herdr agent read <名前> --source recent-unwrapped --lines 120` で画面を読む。
  質問には答え、続ければ済むなら続行を促して再び待つ。不足は同じworkerへ追加で依頼する。
- workerが終了した・応答しないときは、成果と残った作業先を確かめてから起動し直す。
- 終わったら `herdr workspace close <workspace_id>` で閉じる。自分が作っていないworkspaceは閉じない。

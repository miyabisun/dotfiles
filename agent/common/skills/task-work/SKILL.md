---
name: task-work
description: >-
  task-serverの未完了タスクを、deliver、merge、
  patchリリースまで1件ずつ完走する。「タスクを全てこなす」自動運転に使う。
---

# task-work

担当は台帳と次の工程を持ち、各タスクを成果まで進める。
agent-hubの対話型agentへ `/goal` で全件の完了を頼む一言が入口になる
（`/goal` の意味は [herdr-worker](../herdr-worker/SKILL.md#起動して渡す)）。runtimeごとに次のように書く。

- Claude Code: `/goal task-serverのタスクを全て完了させてください`
- Codex: `/goal $task-work を使ってtask-serverのタスクを全てこなして`
- Antigravity CLI（agy）: `/goal task-work skillに従ってtask-serverのタスクを全て完了させてください`

agyは配車係を務め、workerは [herdr-worker](../herdr-worker/SKILL.md) に従ってClaude Codeで起動する。
userによる実行依頼は、対象タスクのcommit・push・mergeを含む。
リリース対象productでは `bump-tag patch` まで実行する。 スキルの作成・説明依頼では実行しない。
タスクに明示されたrelease水準やuserの制限は優先する。

全件・範囲の依頼は [配車](#配車) で受け、各タスクをその実行先のworkerへ渡す。
task_idを指定して起動されたworkerは、[引き取る](#引き取る)以降でその1件だけを完走する（1件モード）。

## 配車

agent-hubで動かす。配車係は台帳を読み、自分ではclaimせず、workerを全体で同時に1本だけ動かす。
workerの起動・依頼・見届け・片付けは [herdr-worker](../herdr-worker/SKILL.md) に従う。
配車するのは、実行先がherdr-workerの表にあるタスクだけ。表にない実行先は残件にする。
task-serverはエージェントの台帳であり、userが手を動かす作業は載せない。それは `todo` でToDoへ追加する。

1. `knowledge-read` を読む。MCPの `task_list` で対象のタスクを、next_offsetがnullになるまで取得する。
   draft・ready・再開できるblockedを対象にする。closed（done・cancelled・dropped）は除く。
   再開時は、名前が `task-` で始まるworkspaceに残ったworkerを先に待つ。
   後から追加されたタスクも同じ全件依頼の範囲なら取り込む。対象を狭めた依頼では範囲外を実行しない。
2. 再開できるタスクをreadyにし、依存タスクがdone（release対象productならrelease済み）で、実行先が表にある1件を優先度順に選ぶ。
   blockedの原因が変わっていないものは同じ実行を反復しない。
3. 選んだタスクの実行先で、herdr-workerに従いworkerを `task-<id先頭8桁>` の名前で起動して、次の依頼を渡す。
   `/goal task-workの1件モードでtask_id=<id>を完走し、doneかblockedをreportする。userには質問せず、判断できない点はblockedの理由に書く。`
4. 待機が戻ったら台帳のstatusを読む。
   - done: report（`run_get`）をタスクの完了条件と照合する。不足があれば本文へ追記してreadyに戻し、3へ戻る。
   - blocked: 配車係が判断・情報で解けるなら本文へ追記してreadyに戻す。物理操作・userの持ち物が要るものは残件にする。
   - claimされたまま: herdr-workerに従って画面を読み、答えるか続行を促して待つ。workerが終了してreportが無いときは、
     lease満了後に1回だけ配車し直す。2回目もreportが無ければblockedにする。
5. workerを片付け、[一時領域の片付け](#一時領域の片付け)のチェックリストを通して2へ戻る。
6. 表の実行先に配車できるタスクが無くなったら終わる。完了件数、release、
   残件（物理操作待ちのblocked、表にない実行先）と実際に必要な対応だけを返す。

## 引き取る

1. `knowledge-read` と `git` を読む。実行先は、指定されたタスクのexecution_targetを使う。
   着手する製品は`product_get({id})`でrepository・local_path・releasesを読む。
   未設定のrepository・releasesは実在と運用設定を確認して`product_update`で補う。releasesの未設定とfalseを混同しない。
   本文はtask_get、報告原文はrun_get、証拠履歴はtask_history、再開情報はtask_checkpoint_getで
   必要なものだけ取得する。一覧や更新応答に詳細が埋め込まれる前提を置かない。
   詳細はfileへ保存し、本文・`product_get` の `legacy` 欄・ログ全文を毎回展開しない。
2. [台帳との接続](references/queue.md) に従い、担当がclaim・heartbeat・reportを所有する。
   委譲先や別のloopへ二重に引き取らせない。
3. task_idを指定して1件claimする。依存未完了・実行先不一致の204は待機であり、blockedにしない。

## 1件を完走する

1. productのlocal_pathがこのマシンに存在すればrepositoryとGitのoriginを照合する。
   存在しない・未設定なら、登録済みrepositoryからこの実行者のローカル領域へcloneする。
   別マシンの絶対パスを再現せず、共有productのlocal_pathも書き換えない。
   originの既定ブランチからタスク専用branch・worktreeを作る。通常cloneならそのrepositoryで同じ操作を
   行う。同じcheckoutにあるuserや他sessionの未commitの変更から離し、中断後に同じ作業先へ戻るためである。
   再開時は記録した自分のworktreeと変更を再利用し、他者の作業を保護する。
2. そのworktreeで `knowledge-read` → `deliver` を進め、検証・レビュー・指摘修正と
   commit・pushまで完了する。分担とレビュー方法はdeliverの手順に従う。
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
6. 要求された成果がそろってから、doneと結果の原文を一度reportする。
   merge済みcommitをtaskの対象SHAとし、release tag・artifact・CI URLも証拠に残す。
   検証の所要は [test-verify](../test-verify/SKILL.md#検証の回数と時間) に従って書く。
   commit・pushやCIの起動で依頼を終えない。
7. reportの前に [一時領域の片付け](#一時領域の片付け) のチェックリストを通し、消した物と残した物をreportに書く。

## 開発と実機作業の引き継ぎ

タスク作成・範囲変更、利用先の確認、実行先・depends_on・完了条件の分割は
[task-creator](../task-creator/SKILL.md) が所有する。通常のready化では登録前の確認を重ねない。
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

進められない1件は理由・保存先・残工程をblockedのreportに残す。

## 一時領域の片付け

一時領域（`/tmp`・`$TMPDIR`・`%TEMP%`・scratchpadなど）に作った物は、作った者が消す。
担当は1件のreportの前に、配車係はworkerの完了を確かめた直後に、下のチェックリストを通す。blockedで止まる時も同じ。

一時領域の意味はOSと設定で変わる。着手時に実体を確かめ（Linuxなら `findmnt -T /tmp`、`df -h /tmp`）、その機械に合わせて判断する。

- tmpfsはRAMを使う。置いた分だけ空きメモリが減り、ほかの仕事（モデルの読み込み・build）を止める。
- ディスク上の一時領域は容量を使う。
- 自動の掃除（再起動時、数日〜10日触らなかった物など）は有無も時期も機械ごとに違う。長く動き続ける機械では来ない。「いずれ消える」を理由に置いたままにしない。

### チェックリスト

消す前に、使っているprocessが無い事と、自分か自分のworkerが作った物である事を確かめる。

- [ ] 着手時に、一時領域の実体（RAMかディスクか）と空きを確かめた。
- [ ] 起動したprocess（server・browser・emulator・別portで起こした常駐の写し）を止め、**止めた直後に**その一時fileを消した。
      Android emulatorは一時領域の `android-<user>/` にsnapshot（数GB）を残す。emulatorを止めたら、その場で消す。
- [ ] 作業用directory（scratchpad、log、レビューの依頼と応答、buildの写し、一時のstate・DB、取得したfile）を消した。
- [ ] この作業で一時領域に出来たtoolのcache・profile（build、test runner、browser）を消した。
- [ ] 配車係: 終えたworkerのsession・作業directoryが残っていない事を確かめ、残りを消した。
- [ ] 残す物（reportにpathを書いた証拠の画像など）は、名前と大きさをreportに書いた。
- [ ] 一時領域の使用量（`du -sh`、`df -h`）を見て、自分の物がほかに残っていない事を確かめた。

他者の物と、稼働中のprocessが使っている物は消さない。持ち主・大きさ・最後に書かれた日時をreportに書く。

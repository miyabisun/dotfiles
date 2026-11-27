---
name: depot
description: >-
  userに見せる動画・画像（頼まれて作った成果物）を、agent-hubのdepot-serverへ入れてURLを渡す。
  検査・試し・見比べの物は入れずに一時領域で見て、置くだけでdepotに出るdirectoryに残した試しは消す。
  動画・画像を作ってuserに見せるとき、検査で画面の画像を撮るとき、ComfyUIなどで試しに書き出したとき、
  depotの物を消すか迷ったときに使う。
---

# depot

depot-serverは生成した動画・画像をLANの端末へ配る置き場で、agent-hubの5015番で動く。
userが見て使う物の置き場であり、検査の置き場ではない。
video-deskの絵を選ぶ窓にもdepotの絵が新しい順に出るので、試しの物が並ぶとuserの物が埋もれる。
2026-11-26には、agentが入れた検査・試し・見比べの物が392件中375件を占め、userに指摘された。

画面とAPIの現行仕様は製品のREADME（`miyabi-sunny-side/depot-server`）が持つ。
depotが読んでいるdirectoryなど、この機械の配備はhome-serverの `systemd/README.md` のdepot-serverの節が持つ。

## 入れる物

userが頼んだ成果物（完成した動画・画像）と、userが「見せて」と言った物だけを入れる。
途中の書き出しや没にした物は入れない。候補からuserに選んでもらうときは、その候補が見せる物になる。
入れたら、そのURL（[入れ方](#入れ方)）をuserに渡す。同じ仕事の物には同じラベルを付ける。

## 入れない物

検査の画像、画面の画像、試しの書き出し、見比べは入れない。
担当の一時領域に置いて自分で見て、報告には言葉とpathで書く。
taskの本文やworkerへの依頼にも「depotへ入れる」と書かず、「depotへ入れない。一時領域に置き、報告にpathを書く」と書く。

## 置くだけで出るdirectory

depotは一部のdirectoryをそのまま一覧に出す。今はComfyUIの `output/`（生成元 `comfyui`）で、
video-deskの仕事の動画・静止画もここに出来る。一覧の正はhome-serverの節にあるunitの `--watch` である。
そこへ書いた物は入れなくてもdepotに並ぶので、ComfyUIのAPIなどで試しに書き出したら、確かめた後に自分のfileを消す。
消すのは書き出した道具の応答にあった自分のfileの名前だけにし、directoryを見回して探さない。

## depotから消すとき

depotから消してよいのは、自分がその仕事で入れた物だけである。ほかはuserの物として扱う。
「agentが作った物 = ごみ」と決めない。2026-11-26の掃除ではuserの設定画まで消した。
depotのごみ箱へ移すと、置くだけで出るdirectoryのfileも動く。video-deskの仕事の動画を消すと、その仕事から動画が見られなくなる。
userに掃除を頼まれたときも、頼まれた範囲の物だけを消す。
誤って消した物は、ごみ箱が空になる7日の間なら戻せる（READMEの「HTTP API」）。

## 入れ方

- 接続先は `http://agent-hub:5015`（LANでは `http://192.168.1.101:5015`）。動いているかは `GET /api/health` で確かめる。
- 生成元（source）は作った道具の名前にする（例: three-liveの書き出しは `threejs`）。
  置くだけで出るdirectoryにある物は入れ直さない。
- ラベルは仕事ごとに1つ決め、その仕事で入れる物のすべてに付ける。
- userに渡すURLは入れたときの応答の `page`（説明の付いた画面）である。fileそのものは `url`。
  どちらも要求に使ったhost名で返るので、`agent-hub` の名前で入れる。
- 置くだけで出るdirectoryの物は、`page` と同じ形の `http://agent-hub:5015/view/<生成元>/<そのdirectoryからのpath>` を渡す。

入れ方（`curl -T`、ラベル・題・説明の付け方）はREADMEの「Putting files in」と「HTTP API」、
agentが守る事は「For AI agents」を読む。

## 外へ出さない

動画・画像をgitや外部のserviceへ上げない。再配布が禁じられた素材が写っていることがある。
R18は共通ルール（Global Rules）の「R18の区画」に従う。

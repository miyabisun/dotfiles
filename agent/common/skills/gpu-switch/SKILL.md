---
name: gpu-switch
description: >-
  agent-hubのGPU（RTX 5060 Ti 1枚）を使う仕事の前にvideo-deskの列を待たせて持ち主を切り替え、
  終わったら返して列を再開する。ComfyUIの動画・画像（H3-Image）を生成するとき、three-liveを書き出すとき、
  「GPUを切り替えて」「GPUは空いている？」「ComfyUIが動いていない」と言われたときに使う。
  GPUを使わない仕事と、video-deskに動画・絵を頼む仕事には使わない。
---

# gpu-switch

agent-hubのGPUは1枚で、three-live・動画・画像は同じVRAMを食う。同居させない（2026-11-24 user）。
重ねても失敗せず、互いに約2倍遅くなり、メモリが尽きかける。
持ち主を一度に1つに保つのが切換器 gpu-switch で、MCP（`status`・`switch`・`done`・`release`）と
画面（`http://agent-hub:5017/`）を持つ。設定とAPIの現行仕様は製品のREADME
（`miyabi-sunny-side/gpu-switch`）、この機械の候補と実測は home-server の
`systemd/README.md` の gpu-switch の節が持つ。
video-desk（`:5018`）は列の候補を1本ずつ自分で切換器に頼むので、自分の仕事の前にその列を待たせる
（[列を待たせる](#列を待たせる)）。列の口の現行仕様は製品のREADME（`miyabi-sunny-side/video-desk` の
Holding the queue）が持つ。

## 候補

`status` が返す `tenants` が正である。2026-11-25 時点では次の3つ。

| id | 仕事 | 切り替えると |
|---|---|---|
| `three-live` | three-liveの書き出し（`render`・`frames`） | ComfyUIが止まる |
| `video` | ComfyUIの動画。画面の行の名前は video-desk（動画のモデルは video-desk の頼む欄で選ぶ） | ComfyUIが起きる（約6秒）。画像のmodelは降りる |
| `image` | ComfyUIの画像（H3-Image） | ComfyUIが起きる。動画のmodelは降りる |

## 列を待たせる

video-deskは列に候補がある限り、候補 `video` として1本ずつGPUを頼んで次を作る。待たせないと、
自分の仕事の合間に次の1本が始まる。切換器は候補を見分けてもprogramを見分けないので、同じ `video` で頼む仕事では最中にも始まる。
GPUを使う自分の仕事（three-liveの書き出し、ComfyUIをAPIで回す確認など）の前後に、
MCP video-desk の道具で列を待たせ、再開する。video-deskに動画や絵を頼む仕事では待たせない（その注文も止まる）。

1. `queue_hold` を呼ぶ。`by` は自分のsessionか仕事の名前（40字まで。再開にも使う）、
   `reason` は何の為か（120字まで。画面に出る）、`minutes` は見込みの長さ（1〜240、無ければ30）、
   `wait_seconds` は600（最大）。
2. 答えの `idle` が true になってから、[手順](#手順)で切り替える（three-liveは書き出しを始める）。
   false なら `queue_status` を `wait_seconds` 付きで呼び直す。作っている最中の1本は最後まで作られる。
   clientの道具の時間切れが `wait_seconds` より短いと答えの前に切れるので、そのときは短い秒で呼び直す。
3. 長引くときは期限の前に同じ `by` で `queue_hold` を呼び直す（期限と理由が置き換わる）。
4. 仕事が終わってGPUを返したら（[手順](#手順)の3。three-liveは自分で返す）、同じ `by` で `queue_resume` を呼ぶ。
   失敗して終わるとき、始めずにやめるときも呼ぶ。忘れても期限で外れるが、それまでvideo-deskは止まったままになる。

答えは `held`・`holds`（各 `by`・`reason`・`since_unix`・`until_unix`）・`making`・`queued`・`idle` で、仕事を名指ししない。
`queue_resume` が解くのはその `by` の待たせだけで、ほかの者の待たせは残る。全部を解くのは画面の「再開」で、userの操作である。
断られた呼び出し（空の `by`、範囲の外の `minutes` など）は道具のerrorで理由を返し、何も変えない。

## 手順

1. video-deskの列を待たせて `idle` が true になったら（[列を待たせる](#列を待たせる)）、
   仕事を始める直前に `switch` を呼ぶ（`to` に候補のid）。今の持ち主と同じなら切り替えは起きず、
   猶予（[断られたとき](#断られたとき)）を置き直して、次の仕事のためにGPUを押さえる。
   長い仕事（ComfyUIをAPIで回す確認など）は `lease: true` を付けて鍵を取る。鍵がある間は、
   probeが何を見てもほかの候補に渡らない。仕事の間は答えの `lease.renew_every_seconds`
   （既定30秒）ごとに同じ頼みを送って更新する。
2. 返事の `freed` が true で、`after` のVRAMと空きメモリが仕事に足りることを確かめてから始める。
   動画と画像はVRAMを約15.8GB、メモリを約37GB使う。`freed` が false なら始めず、`previous.left` と
   `after.gpu.processes`（VRAMを持っているprocess）をuserに伝える。
   始めないときは `release` を呼ぶ（`tenant` に自分の候補のid。鍵も外れる）。呼ばないと、ほかの候補が猶予の間（既定30秒）待たされる。
3. 鍵を取ったなら、出来た物を保存した後に `done`（`tenant` に自分の候補のid）を呼ぶ。
   仕事が全部終わったら `release` を呼ぶ（`tenant` に自分の候補のid）。
   後から別の持ち主に替わっていれば、何もせずに返る。続けて同じ候補の仕事をするなら、最後に1回でよい。
   持ち主は仕事の後も余韻（既定20秒）の間、ほかの候補に対して仕事中と数えられ、返すと余韻はすぐ終わる。
   返さないとほかの候補が余韻の間待たされるので、最後の仕事の後は必ず返す。
   仕事の合間が余韻より長いと、待っているほかの候補に渡ることがある。次の仕事の前にも1の `switch` を呼ぶ。
   返した後に、列を待たせた `by` で `queue_resume` を呼ぶ。
4. 生成した動画・画像を見せるときは、返した後でよい。

鍵が外れるときと、そのときの答えは次のとおり。外れた後に頼むと、ほかへ渡っていなければ取り直せる。

- 更新の答えの `lease.renewed` が false: 途中で鍵を失い、取り直した。`changed` も true なら、
  GPUは一度ほかの候補へ渡り、ComfyUIは止められた。仕事が残っているかを確かめる。
- 更新が断られた（`busy`）: 鍵はほかの候補へ渡った。仕事は止められていることがある。
- GPUに動きが無いまま3分（既定）続くと、更新していても切換器が鍵を取り返す（`status` の `taken_back`）。
  鍵はGPUの仕事を流す直前に取り、GPUを使わない合間が長いときは `done` で区切る。
- 更新が途切れると、期限（既定120秒）で鍵は外れる。その後はprobeと余韻が決め、動いている仕事は止められない。
- `done` が断られたら（`no_lease`）、鍵はもう無い（`taken_back` に理由）。続けて `release` を呼ぶ。

three-liveの `render`・`frames` は描画の前に自分で鍵を取り（候補 `three-live`）、描く間は更新し、
書き終えた後に `done` と返却をする。agentは `switch`・`done`・`release` を呼ばなくてよいが、列は待たせる。
ほかの候補が仕事の途中（[断られたとき](#断られたとき)）なら、描かずに1で終わる。待つなら `--wait 秒` を付けると切換器の列に並ぶ。
描く間に鍵を取り返されると、描いた分を残し、足りないコマを示して1で終わる。
video-deskは候補ごとに鍵を取り、出来た物を保存した後に `done` を言い、列が空になるか待たされると返す。

ComfyUIは、持ち主が `video` か `image` の間だけ動いている。`http://127.0.0.1:8188` に届かないときは
serviceを手で起こさず `switch` する（手で起こしても、切換器が止める）。

## 断られたとき

ほかの候補が仕事の途中だと、`switch` も `release` も断られ、誰が忙しいかが返る。何も変わっていない。
仕事を始める前と終えた直後の持ち主と、鍵を持つ候補も、次の間はほかの候補に対して仕事の途中と数えられる。

- 猶予: `switch` で渡された直後で、まだ仕事を始めていない持ち主（`status` の `grace`）。
  そのprobeが仕事中を1度見るか、既定30秒が過ぎるか、持ち主が返すと終わる。
- 余韻: probeが持ち主の仕事を最後に見てから既定20秒（`status` の `linger`）。持ち主が返すとすぐ終わる。
- 鍵: `lease: true` で取った候補（`status` の `lease`）。`done`・返却・期限切れ・取り返しで終わる。

断られるのは、ほかの候補の `switch`（HTTPの `"to": null` を含む）と、`tenant` の無い `release` である。
持ち主自身の `switch` と `release`（`tenant` 付き）は自分の猶予・余韻・鍵には止められない。
`wait_seconds` 付きの頼みは切換器の列に並ぶ（`status` の `waiting`、先頭が次）。順は候補の `priority` の高い方、
次に頼んだ順である。鍵か待ちを付けた頼みは、列で自分より前の候補が居る間も断られる。
鍵も待ちも無い頼み（画面など）は列に止められない。
断られた答えの `busy`（忙しい候補のid）には猶予と余韻の持ち主、鍵を持つ候補、列で前に居る候補も出る。
列で前に居る候補は `ahead` に順番どおり並ぶ（MCPでは断りの文の "in line before you"）。
`wait_seconds` と `force` の効き方は仕事の途中と同じである。
待つと、猶予が切れたとき、または始まった仕事とその後の余韻が終わったとき（持ち主が返せばその時点）に空く。
鍵は持ち主が `done` を言うと終わり、GPUは列に誰か居れば先頭へ渡り、居なければ持ち主に残る。
秒数は切換器の設定で決まり、0なら猶予・余韻・鍵・取り返しは無い。
切換器を起こし直すと猶予・余韻・列は消え（持ち主と鍵は残る）、probeが見た仕事と鍵だけで決まる。

- 待てるなら `wait_seconds`（最大3600）を付けて呼び直す。列に並び、空いた時点で切り替わる。
- 待てないなら、誰の仕事が動いているかをuserに伝える。
- `force` は実行中の仕事を止め、鍵も取り上げる。userが止めてよいと明示したときだけ使う。
- `status` の `intruding` は切り替えずに始まった仕事である。止めずに、userに伝える。
- `status` の `grace` と `linger` は猶予と余韻の中の持ち主と残りの秒（`{tenant, seconds_left}`、無ければ `null`）である。
  同じ候補が両方に出ることがある。`tenants` の各 `busy` はprobeが今見た仕事だけで、猶予と余韻を含まない。
- `status` の `lease` は鍵を持つ候補と残りの秒（`seconds_left`）・動きの無い秒（`idle_seconds`）、
  `taken_back` は最後に取り返された鍵（`reason` は `idle`・`expired`・`forced`）である。無ければ `null`。

## 画面

userは `http://agent-hub:5017/`（LANは `http://192.168.1.101:5017/`）で、今の持ち主を見て、行を選んで切り替える。
行の右端のリンクは、video-desk の行が video-desk（:5018）、画像の行が ComfyUI の画面（:8188）を開く。

## 接続

MCPのURLはマシンごとの設定に登録し、dotfilesのテンプレートへ入れない。
gpu-switchはagent-hubの5017番、video-deskは5018番で動く。agent-hubではどちらも `http://127.0.0.1:<番号>/mcp` を登録する。
GPUを使う仕事はagent-hubで動かすので、ほかのマシンには登録しない。
未登録なら次で追加し、`claude mcp get gpu-switch`・`claude mcp get video-desk` で接続を確かめる。

```sh
claude mcp add --transport http --scope user gpu-switch http://127.0.0.1:5017/mcp
claude mcp add --transport http --scope user video-desk http://127.0.0.1:5018/mcp
```

Codexは `~/.codex/config.toml` に次の表を足す。

```toml
[mcp_servers.gpu_switch]
url = "http://127.0.0.1:5017/mcp"

[mcp_servers.video_desk]
url = "http://127.0.0.1:5018/mcp"
```

Antigravity CLI（agy）は次で `~/.gemini/config/mcp_config.json` へ足し、`agy mcp list` で確かめる。

```sh
agy mcp add gpu-switch http://127.0.0.1:5017/mcp
agy mcp add video-desk http://127.0.0.1:5018/mcp
```

追加したMCPのtoolは次のsessionから使える。今のsessionやMCPの無い場所では、同じ操作をHTTPで行う。

```sh
curl -s localhost:5017/api/status
curl -s -X POST localhost:5017/api/switch -H 'Content-Type: application/json' -d '{"to":"video","wait_seconds":600}'
curl -s -X POST localhost:5017/api/switch -H 'Content-Type: application/json' -d '{"to":"video","lease":true,"wait_seconds":600}'
curl -s -X POST localhost:5017/api/done -H 'Content-Type: application/json' -d '{"tenant":"video"}'
curl -s -X POST localhost:5017/api/release -H 'Content-Type: application/json' -d '{"tenant":"video"}'
```

video-deskの列はHTTPでは次のとおり。`by` と `reason` は自分の物にし、`minutes` を付ける（`null` は期限の無い待たせで、画面の為の物）。
`by` の無い `DELETE` はほかの者の待たせも解くので使わない。

```sh
curl -s -X PUT localhost:5018/api/hold -H 'Content-Type: application/json' -d '{"by":"task-1234","reason":"three-liveの書き出し","minutes":30}'
curl -s 'localhost:5018/api/hold?wait=600'
curl -s -X DELETE 'localhost:5018/api/hold?by=task-1234'
```

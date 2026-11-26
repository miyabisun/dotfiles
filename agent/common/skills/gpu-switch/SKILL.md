---
name: gpu-switch
description: >-
  agent-hubのGPU（RTX 5060 Ti 1枚）を使う仕事の前に持ち主を切り替え、終わったら返す。
  ComfyUIの動画・画像（H3-Image）を生成するとき、three-liveを書き出すとき、
  「GPUを切り替えて」「GPUは空いている？」「ComfyUIが動いていない」と言われたときに使う。
  GPUを使わない仕事には使わない。
---

# gpu-switch

agent-hubのGPUは1枚で、three-live・動画・画像は同じVRAMを食う。同居させない（2026-11-24 user）。
重ねても失敗せず、互いに約2倍遅くなり、メモリが尽きかける。
持ち主を一度に1つに保つのが切換器 gpu-switch で、MCP（`status`・`switch`・`release`）と
画面（`http://agent-hub:5017/`）を持つ。設定とAPIの現行仕様は製品のREADME
（`miyabi-sunny-side/gpu-switch`）、この機械の候補と実測は home-server の
`systemd/README.md` の gpu-switch の節が持つ。

## 候補

`status` が返す `tenants` が正である。2026-11-25 時点では次の3つ。

| id | 仕事 | 切り替えると |
|---|---|---|
| `three-live` | three-liveの書き出し（`render`・`frames`） | ComfyUIが止まる |
| `video` | ComfyUIの動画。画面の行の名前は video-desk（動画のモデルは video-desk の頼む欄で選ぶ） | ComfyUIが起きる（約6秒）。画像のmodelは降りる |
| `image` | ComfyUIの画像（H3-Image） | ComfyUIが起きる。動画のmodelは降りる |

## 手順

1. 仕事を始める直前に `switch` を呼ぶ（`to` に候補のid）。今の持ち主と同じなら切り替えは起きず、
   猶予（[断られたとき](#断られたとき)）を置き直して、次の仕事のためにGPUを押さえる。
2. 返事の `freed` が true で、`after` のVRAMと空きメモリが仕事に足りることを確かめてから始める。
   動画と画像はVRAMを約15.8GB、メモリを約37GB使う。`freed` が false なら始めず、`previous.left` と
   `after.gpu.processes`（VRAMを持っているprocess）をuserに伝える。
   始めないときは `release` を呼ぶ（`tenant` に自分の候補のid）。呼ばないと、ほかの候補が猶予の間（既定30秒）待たされる。
3. 仕事が全部終わったら `release` を呼ぶ（`tenant` に自分の候補のid）。
   後から別の持ち主に替わっていれば、何もせずに返る。続けて同じ候補の仕事をするなら、最後に1回でよい。
   持ち主は仕事の後も余韻（既定20秒）の間、ほかの候補に対して仕事中と数えられ、返すと余韻はすぐ終わる。
   返さないとほかの候補が余韻の間待たされるので、最後の仕事の後は必ず返す。
   仕事の合間が余韻より長いと、待っているほかの候補に渡ることがある。次の仕事の前にも1の `switch` を呼ぶ。
4. 生成した動画・画像を見せるときは、返した後でよい。

three-liveの `render`・`frames` は自分で切換器に頼み、終わると返す。
agentは `switch`・`release` を呼ばなくてよい。ほかの仕事が終わるのを待たせるなら `--wait 秒` を付ける。

ComfyUIは、持ち主が `video` か `image` の間だけ動いている。`http://127.0.0.1:8188` に届かないときは
serviceを手で起こさず `switch` する（手で起こしても、切換器が止める）。

## 断られたとき

ほかの候補が仕事の途中だと、`switch` も `release` も断られ、誰が忙しいかが返る。何も変わっていない。
仕事を始める前と終えた直後の持ち主も、次の間はほかの候補に対して仕事の途中と数えられる。

- 猶予: `switch` で渡された直後で、まだ仕事を始めていない持ち主（`status` の `grace`）。
  そのprobeが仕事中を1度見るか、既定30秒が過ぎるか、持ち主が返すと終わる。
- 余韻: probeが持ち主の仕事を最後に見てから既定20秒（`status` の `linger`）。持ち主が返すとすぐ終わる。

断られるのは、ほかの候補の `switch`（HTTPの `"to": null` を含む）と、`tenant` の無い `release` である。
持ち主自身の `switch` と `release`（`tenant` 付き）は自分の猶予と余韻には止められない。
断られた答えの `busy`（忙しい候補のid）には猶予と余韻の持ち主も出る。`wait_seconds` と `force` の効き方は仕事の途中と同じである。
待つと、猶予が切れたとき、または始まった仕事とその後の余韻が終わったとき（持ち主が返せばその時点）に空く。
秒数は切換器の設定で決まり、0なら猶予・余韻は無い。
切換器を起こし直すと猶予と余韻は消え（持ち主は残る）、probeが見た仕事だけで決まる。

- 待てるなら `wait_seconds`（最大3600）を付けて呼び直す。空いた時点で切り替わる。
- 待てないなら、誰の仕事が動いているかをuserに伝える。
- `force` は実行中の仕事を止める。userが止めてよいと明示したときだけ使う。
- `status` の `intruding` は切り替えずに始まった仕事である。止めずに、userに伝える。
- `status` の `grace` と `linger` は猶予と余韻の中の持ち主と残りの秒（`{tenant, seconds_left}`、無ければ `null`）である。
  同じ候補が両方に出ることがある。`tenants` の各 `busy` はprobeが今見た仕事だけで、猶予と余韻を含まない。

## 画面

userは `http://agent-hub:5017/`（LANは `http://192.168.1.101:5017/`）で、今の持ち主を見て、行を選んで切り替える。
行の右端のリンクは、video-desk の行が video-desk（:5018）、画像の行が ComfyUI の画面（:8188）を開く。

## 接続

MCPのURLはマシンごとの設定に登録し、dotfilesのテンプレートへ入れない。
gpu-switchはagent-hubの5017番で動く。agent-hubでは `http://127.0.0.1:5017/mcp` を登録する。
GPUを使う仕事はagent-hubで動かすので、ほかのマシンには登録しない。
未登録なら次で追加し、`claude mcp get gpu-switch` で接続を確かめる。

```sh
claude mcp add --transport http --scope user gpu-switch http://127.0.0.1:5017/mcp
```

Codexは `~/.codex/config.toml` に次の表を足す。

```toml
[mcp_servers.gpu_switch]
url = "http://127.0.0.1:5017/mcp"
```

Antigravity CLI（agy）は次で `~/.gemini/config/mcp_config.json` へ足し、`agy mcp list` で確かめる。

```sh
agy mcp add gpu-switch http://127.0.0.1:5017/mcp
```

追加したMCPのtoolは次のsessionから使える。今のsessionやMCPの無い場所では、同じ操作をHTTPで行う。

```sh
curl -s localhost:5017/api/status
curl -s -X POST localhost:5017/api/switch -H 'Content-Type: application/json' -d '{"to":"video","wait_seconds":600}'
curl -s -X POST localhost:5017/api/release -H 'Content-Type: application/json' -d '{"tenant":"video"}'
```

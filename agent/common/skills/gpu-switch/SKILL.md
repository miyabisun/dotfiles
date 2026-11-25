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

1. 仕事を始める直前に `switch` を呼ぶ（`to` に候補のid）。今の持ち主と同じなら何も起きない。
2. 返事の `freed` が true で、`after` のVRAMと空きメモリが仕事に足りることを確かめてから始める。
   動画と画像はVRAMを約15.8GB、メモリを約37GB使う。`freed` が false なら始めず、`previous.left` と
   `after.gpu.processes`（VRAMを持っているprocess）をuserに伝える。
3. 仕事が全部終わったら `release` を呼ぶ（`tenant` に自分の候補のid）。
   後から別の持ち主に替わっていれば、何もせずに返る。続けて同じ候補の仕事をするなら、最後に1回でよい。
4. 生成した動画・画像を見せるときは、返した後でよい。

three-liveの `render`・`frames` は自分で切換器に頼み、終わると返す。
agentは `switch`・`release` を呼ばなくてよい。ほかの仕事が終わるのを待たせるなら `--wait 秒` を付ける。

ComfyUIは、持ち主が `video` か `image` の間だけ動いている。`http://127.0.0.1:8188` に届かないときは
serviceを手で起こさず `switch` する（手で起こしても、切換器が止める）。

## 断られたとき

ほかの候補が仕事の途中だと、`switch` も `release` も断られ、誰が忙しいかが返る。何も変わっていない。

- 待てるなら `wait_seconds`（最大3600）を付けて呼び直す。空いた時点で切り替わる。
- 待てないなら、誰の仕事が動いているかをuserに伝える。
- `force` は実行中の仕事を止める。userが止めてよいと明示したときだけ使う。
- `status` の `intruding` は切り替えずに始まった仕事である。止めずに、userに伝える。

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

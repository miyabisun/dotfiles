# OrcaServerへ接続する

OrcaServer v0.1.22以降のStreamable HTTP MCPを使い、
[プレート保存](common/skills/orca-plate/SKILL.md)と[材料管理](common/skills/orca-material/SKILL.md)を行えます。
SCADモデルの参照にはサーバー側の`SCAD_LIVE_URL`設定も必要です。
APIと利用例は[OrcaServerのMCPガイド](https://github.com/miyabi-sunny-side/orca-server/blob/main/docs/mcp.md)を参照してください。

## 接続先を選ぶ

| クライアントの実行場所 | MCP URL |
| --- | --- |
| OrcaServerと同じ母艦 | 公開ポートが3000なら`http://127.0.0.1:3000/mcp` |
| sandboxや別PC | クライアントから到達できる母艦のLAN/Tailscaleホスト名と公開ポートに`/mcp`を付ける |

sandboxの`127.0.0.1`はsandbox自身です。母艦への接続に読み替えないでください。
接続先は利用するマシンの設定へ保存し、dotfilesの共有テンプレートへホスト名・資格情報を取り込みません。
接続範囲はOrcaServerの運用に合わせて信頼できるLAN/Tailscaleとします。

## Codexへ登録する

`~/.codex/config.toml`が共有テンプレートへのsymlinkではなく通常ファイルであることを確認します。
旧symlinkは既存の`bin/install`で内容を保ったコピーへ移行します。
設定変更前にローカルへバックアップを保存し、登録済みなら`codex mcp get orca_server`で現在値を確認してください。

`ORCA_MCP_URL`に上で選んだ実際のURLを設定して、次を実行します。

```sh
codex mcp add orca_server --url "$ORCA_MCP_URL"
codex --strict-config --version
codex mcp get orca_server
```

このコマンドがローカル設定へ追加する内容は次の形です。例のホスト名は実際の接続先に置き換えます。

```toml
[mcp_servers.orca_server]
url = "http://mother-host:3000/mcp"
```

既存の他のMCP・認証・project設定を保持し、設定全体をテンプレートで上書きしません。
共有するのはこの手順とskillです。installerの初回seedは既存設定へこの登録を配布しません。
差分の扱いは[config-merge](common/skills/config-merge/SKILL.md)、
対応オプションは[Codex公式MCP仕様](https://developers.openai.com/codex/mcp/)を参照してください。

## 接続と保存を確かめる

新しいCodexセッションの`/mcp`で接続を確認し、`scad_models`で公開モデル、
`filament_products`で製品が読めることを確認します。CLIの`mcp get`は登録の確認だけです。
skillは既存の`~/.agents/skills`から読み込みます。Claude Code/Grokには同じskillを既存リンクで配布します。
CodexのMCP登録は、それらのクライアントへ共有されません。各クライアントでも同じURLを登録してください。

「このモデルを10個のプレートとして保存」と依頼したら、返された管理画面リンクで個数・条件を確認します。
「同じ製品へ黄を追加」と依頼したら、製品の色一覧と共通設定を確認します。
プレート保存だけでは印刷を開始しません。未指定の条件は未設定のままで、追加可否は別に確認できます。

検証には隔離したOrcaServerとDBを使えます。その場合だけ一時環境のURLへ接続し、
終了後は本来の接続先へ戻してください。母艦へ反映する際は同じ手順を母艦のCodexで実行します。

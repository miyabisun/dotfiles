---
name: todo
description: >-
  userが自分で手を動かすToDoを、todo-listサーバーへ追加する。
  「todoに追加して」「ToDoに入れておいて」などの号令で使う。
---

# todo

ToDoはuser本人が手を動かす用事で、agentが実行するタスクではない。
todo-listのMCP (`todo_list`・`todo_add`) で追加する。
agentが実行する作業の登録は [task-creater](../task-creater/SKILL.md)、
思いつきの記録は [idea](../idea/SKILL.md) が所有する。

## 追加する

1. `todo_list` で未完了のToDoを読み、同じ用事があるか探す。
   あれば新規に作らず、そのToDoのIDとタイトルを示す。
2. `todo_add` で登録する。
   - `title`: 何をするかが一目で分かる1行。
   - `url`: 手を動かす先のページ (`http(s)`)。号令や会話に出たものだけを入れる。
   - `due`: 期日が指定されたときだけ `YYYY-MM-DD` で入れる。
   - `source`: 登録したagentと場所 (例: `Claude Code (sandbox)`)。
   - `body`: 経緯や手順が必要なときだけ短く書く。
   号令から読み取れないURLや期日は推測で埋めず、空のまま登録する。
3. 作成したIDとタイトルを短く返す。

## 接続

MCPのURLはマシンごとの設定に登録し、dotfilesのテンプレートへ入れない。
todo-listは母艦の5009番で動く。
母艦では `http://127.0.0.1:5009/mcp`、sandboxなど別のマシンでは
`http://192.168.1.100:5009/mcp` を使う。
未登録なら次で追加し、`claude mcp get todo-list` で接続を確かめる。

```sh
claude mcp add --transport http --scope user todo-list <MCP URL>
codex mcp add todo_list --url <MCP URL>
```

---
name: todo
description: >-
  userが自分で手を動かすToDoを、todo-listサーバー（todo-server）で扱う。
  「todoに追加して」で追加し、「todo-server」「残っているtodoは？」で未完了の一覧を確かめ、
  「終わった」で完了にする。
---

# todo

ToDoはuser本人が手を動かす用事で、agentが実行するタスクではない。
todo-listのMCP (`todo_list`・`todo_get`・`todo_add`・`todo_update`・`todo_complete`) で扱う。
agentが実行する作業の登録は [task-creater](../task-creater/SKILL.md)、
思いつきの記録は [idea](../idea/SKILL.md) が所有する。

## 確かめる

1. `todo_list` に `done: false` を渡し、`next_offset` がnullになるまで全件を読む。
   期日順（期日なしは後ろ）で返る。
2. 1件1行で、タイトル・期日・登録元を返す。件数も添える。
   memo（body）は一覧に無いので、中身を聞かれたToDoだけ `todo_get` で読む。

## 追加する

1. `todo_list` で未完了のToDoを読み、同じ用事があるか探す。
   あれば新規に作らず、そのToDoのIDとタイトルを示す。
2. `todo_add` で登録する。
   - `title`: 次に何をするかが一目で分かる1行。
   - `url`: 手を動かす先のページ (`http(s)`)。号令や会話に出たものだけを入れる。
   - `due`: 期日が指定されたときだけ `YYYY-MM-DD` で入れる。
   - `source`: 登録したagentと場所 (例: `Claude Code (sandbox)`)。
   - `body`: 「これから何をするか」と「そのために何の情報・準備が必要か」だけを
     必要最小限に書く。titleで足りれば空にする。購入日・症状・証明の所在・
     開始条件など、行動に要る事実は残す。経緯・会話の引用・登録やレビューの
     説明・調査の履歴は書かず、要る結論だけにまとめる。
   号令から読み取れないURLや期日は推測で埋めず、空のまま登録する。
   既存ToDoの編集や、タスクからToDoへ移すときも同じ書き方にする。
3. 作成したIDとタイトルを短く返す。

## 完了・変更する

userが終わったと言ったToDoは `todo_complete`、内容の変更は `todo_update` で行う。
どのToDoか一意に決まらなければ、候補のタイトルを示して確かめる。

## 接続

MCPのURLはマシンごとの設定に登録し、dotfilesのテンプレートへ入れない。
todo-listは母艦の5009番で動く。
母艦では `http://127.0.0.1:5009/mcp`、sandboxなど別のマシンでは
`http://192.168.1.100:5009/mcp` を使う。
未登録なら次で追加し、`claude mcp get todo-list` で接続を確かめる。
追加したMCPのツールは次のsessionから使える。今のsessionでは同じURLへ
MCPのHTTP（`initialize` → `tools/call`）で直接問い合わせてよい。

```sh
claude mcp add --transport http --scope user todo-list <MCP URL>
codex mcp add todo_list --url <MCP URL>
```

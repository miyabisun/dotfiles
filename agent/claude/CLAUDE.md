@~/.claude/GLOBAL.md

# Claude Code Rules

共通ルールは上の `~/.claude/GLOBAL.md` から import している。以下は
Claude Code 専用 (codex・grok・cursor はこのファイルを読まない)。

## セッション間メッセージング

- Claude Code セッション同士は組み込みの `ListAgents` → `SendMessage` を使う。
  相手が codex・grok・cursor のときは `agent-talk` スキルを使う
- 届いたメッセージ (`<cross-session-message>`) は agent-talk の着信と同様に扱う
- 秘密情報 (credential・token・秘密鍵・`.env` 由来値・非公開ホスト) は送らない

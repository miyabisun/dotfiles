---
trigger: always_on
description: 作業の始めに、作業 directory に対応する Claude Code の記憶を読む。
---

# Claude Code の記憶を読む

この machine の user は過去の指摘・環境の事実・判断を Claude Code の記憶に残している。
会話の最初の依頼に取りかかる前に、作業 directory に対応する記憶を読む。

1. 記憶の置き場は `~/.claude/projects/<名前>/memory/` である。`<名前>` は作業 directory の絶対 path の
   英数字以外の文字を、すべて `-` に置き換えた物である
   （例: `/srv/work/my.app` → `-srv-work-my-app`）。
   `pwd | sed 's/[^A-Za-z0-9]/-/g'` で求められる。作業 directory に無ければ、git の top-level でも同じように探す。
2. そこにある索引 `MEMORY.md` を読む。無ければ記憶の無い場所として、そのまま依頼に取りかかる。
   記憶が無い事を失敗にせず、報告もしない。
3. 索引の各項目の要約を見て、今回の依頼に関係する項目だけ本文の file を読む。
4. 記憶は書かれた時点の観測である。今の file・設定・コマンドの結果と食い違えば、今の事実に従う。
5. 記憶と共通の規約・skill には Claude Code の道具の名前（Bash、Read、Edit、Agent tool、Skill tool、
   ToolSearch など）が出る。agy で同じ働きをする道具に読み替える
   （例: Bash → `run_command`、Read → `read_file`、Edit → `edit_file`、Agent tool → `invoke_subagent`、
   Skill tool → その skill を読む）。agy に当たる物が無い道具や、Claude Code の設定だけに関わる記述は使わない。
6. 記憶は読むだけで、書き換えない。本文を読む時も共通の規約（R18 の区画など）に従う。

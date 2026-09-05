# agent の設定レイヤー

AI agent の tooling はすべて `agent/` 以下にある。

```
agent/
├── common/          # Shared across tools
│   ├── agents/      # Subagent role defs (designer, ui-checker)
│   ├── bin/         # Shared notification helpers → ~/.local/bin
│   ├── designs/     # DESIGN.md templates (Sumi, Kinari, …)
│   ├── rules/       # GLOBAL.md
│   └── skills/      # Agent Skills (SKILL.md)
├── claude/          # Claude Code only
│   ├── hooks/
│   ├── settings.json
│   ├── CLAUDE.md    # Claude-only rules + @~/.claude/GLOBAL.md import
│   ├── agents → ../common/agents
│   ├── designs → ../common/designs
│   └── skills → ../common/skills
├── codex/           # Codex CLI only
│   ├── agents/      # Codex subagent TOML role adapters
│   ├── hooks/ + hooks.json
│   └── config.toml
└── grok/            # Grok CLI only
    ├── hooks/       # lifecycle + guards (JSON + shell adapters)
    └── config.toml  # portable template → seed ~/.grok/config.toml
```

`bin/install` が張る symlink:

| home 側 | source 側 |
|------|--------|
| `~/.claude/skills`, `~/.grok/skills` | `agent/common/skills` |
| `~/.claude/agents`, `~/.grok/agents` | `agent/common/agents` |
| `~/.claude/designs`, `~/.grok/designs` | `agent/common/designs` |
| `~/.claude/*` (hooks, settings, …) | `agent/claude/*` |
| `~/.codex/config.toml`, `~/.codex/hooks.json` | `agent/codex/*` |
| `~/.codex/AGENTS.md`, `~/.grok/AGENTS.md`, `~/.claude/GLOBAL.md` | `agent/common/rules/GLOBAL.md` |
| `~/.grok/hooks` | `agent/grok/hooks` |
| `~/.grok/config.toml` | `agent/grok/config.toml` の seed copy (symlink ではない) |
| `~/.agents/skills`, `~/.agents/agents`, `~/.agents/designs` | `agent/common/*` |

agent の完了イベントは `~/.local/bin/emit-turn-end.sh` を呼ぶ。`MOCA_URL` が
設定されているときは、MOCA へイベントの通知を依頼する。成功した turn を
通知するのは、同じ herdr workspace のほかの agent がすべて done/idle に
落ち着いたときだけである。claude↔codex のレビュー往復が、turn ごとではなく
最後に1回だけ完了通知を出すようにするためである。この script は lifecycle の
状態を agent-talk へ報告しない。broker は herdr から直接それを読む。Codex は
完了に `notify` を使う。その通知 wrapper は subagent の rollout thread を
識別し、自動承認の reviewer を含めて、その完了通知を抑止する。

agent 間の message は Claude Code 組み込みの cross-session channel
(`ListAgents` / `SendMessage`) を通る。broker は
[`miyabi-sunny-side/agent-talkd`](https://github.com/miyabi-sunny-side/agent-talkd)
の Rust 実装である。systemd が管理する daemon である
(下の *broker 自体はどこから来るか* を見よ)。仕事は 2 つしか残っていない。
1 つは legacy の `[agent-talk]` 呼び鈴を捌くこと。もう 1 つは、外部 mailbox
から届いた人間の手紙へ bounded な `agent-talk reply` を1通運ぶことである。
登録は、herdr 固有の agent 検出に対する daemon 側の pull 同期である。herdr の
pane にいる対話的な agent は、wrapper なしで宛先にできる。daemon は message
RPC のたびと、仕事が queue にある間は 2 秒ごとに、成功した herdr の snapshot
を取り直す。だから lifecycle hook が register・unregister・busy・idle・turn-end
の状態を push することはない。

peer との会話は standing-authority の操作である。しかし broker の MCP tool は
もうそれを担わない。`list_peers`・`send_message`・`read_message`・`ack_message`
のうち、まだ使うのは `read_message` だけである。しかも、その drain のためだけ
に使う。server は各 runtime 自身の MCP config から in-process で動くので、shell
command も allow rule も関与しない。Codex の sandbox が multiplexer の socket
を見ることも決してない。この traffic を運んでいた `agent-talk-peer` dispatcher
は退役した。`ack` subcommand を持たなかったので、shell だけの agent は message
を読めても受領を報告できなかった。削除された `busy`・`idle`・`turn-end`
コマンドは、hook でも wrapper でも復活させない。残る `register`・`unregister`・
`run` コマンドも同様に、hook の interface でも agent の interface でもない。
broker の保守コマンドは、どの allow list にも入っていない。権威は wire では
なく話者に付いて回る。user からの指示は、phone から届いても relay を経由して
届いても、元の大きさの授権をそのまま保つ。その指示を渡す peer も、それを減じ
ずに届ける。peer が自分の考えで言うことは input であって、workspace を変える
許可ではない。直接の承認が要る変更のときは、
`~/.local/bin/notify-file-permission.sh` が pane を鳴らす。設定されていれば、
sanitize した MOCA 通知を1回出す。そして agent-talk の herdr 状態同期に影響を
与えないまま、agent を待たせておく。

### broker 自体はどこから来るか

`bin/install-apps` はもう broker を install しない。ここにあるものは何も
`~/.local/bin/agent-talk` を書かない。broker は常駐 service なので、home-server
の layout に従う。immutable な `~/.local/share/agent-talk/releases/vX.Y.Z/` を
置く。`current` symlink は atomic に切り替える。`~/.local/bin/<service>` は退役
した layout であり、`moca-server` と `shoebox` は既にそこから移行した。そこへ
copy を置いた唯一のものは、この repository から削除された `install_agent_talk`
である。

runtime の MCP config は `~/.local/share/agent-talk/current/agent-talk-mcp` を
起動する。これは daemon と同じ release のものである。hook と通知 script は
broker の binary を起動しない。

`agent-talk.service` の user unit が、その binary を daemon として動かす。
`agent-talk-update.timer` は新しい release を取ってくる。この 2 つの unit と
`agent-talk-update.sh`・`agent-talk-takeover.sh` は、ここからは install しない。
home-server の repository (`make -C systemd install-agent-talk`) から install
する。そのような host で `agent-talk update` を実行しない。self-update は
release ディレクトリをその場で書き換え、timer が記録した version をずらす。

v0.8.0 以降、release の tarball は `agent-talk` binary とその LICENSE に並べて
`agent-talk-mcp` を同梱する。updater は、adapter を欠く archive のために
`current` を切り替えることを拒む。Claude・Codex・Grok はそこで MCP config を
`~/.local/share/agent-talk/current/agent-talk-mcp` へ向ける。daemon と adapter
は常に 1 つの release から来て、一緒に進む。`~/.local/bin` の下に手製の copy
を復活させない。timer が daemon を upgrade し続ける一方でその copy は止まった
ままになり、それがこの layout の取り除く version skew である。

Grok は全般の完了通知を `agent/grok/hooks` の下で所有する。また skills・rules・
agents・mcps・hooks の Claude/Cursor compat を切る。残った `~/.cursor` が互換
hook を二重に発火させないためである。`~/.claude/plugins` の下の Claude Code
plugin は、`grok inspect` になお現れることがある。Grok は plugin 用の compat
セルを別に持たないためである。`compat.claude.skills` が off なら、その skill は
無効になる。全般の通知元は Grok 自身の hook のままである。

## agent (`common/agents`)

Claude Code と Grok が共有する役割定義である。frontmatter は `name` /
`description` だけを持つので、親の chat model を継承する (`model` の既定は
`inherit`)。Claude 固有の `model` / `effort` / `tools` は意図的に省く。

Google 形式の `DESIGN.md` テンプレートは、bootstrap input としてここに置く。
各 project は、テンプレートを取り込んで適合させたあと、自己完結したルートの
`DESIGN.md` を所有する。共有テンプレートは外部の authority として残らない。
`docs/DESIGN.md` しか持たない既存 project は、明示的な移行までそれを legacy
fallback として読んでよい。ただしルートと docs が暗黙に merge されることは
決してない。

## 新しい skill を足す

1. `agent/common/skills/<name>/SKILL.md` を作る
2. 既存の symlink が、それを Claude Code・Codex・Grok へ届ける

主な skill:

- `deliver` — 成果駆動の実装、証拠ゲート、local commit
- `git` — commit message とブランチフローの house rule
- `bump-tag` — semver の bump、tag、push
- `knowledge-deposit` — 再利用できる knowledge を預ける。エントリを書き、lint
  し、自分が書いた path だけを stage する。staged diff を `review` の召喚1回で
  レビューし、local で commit する

`deliver` の分担とレビューは
[共通契約](common/skills/deliver/CONTRACT.md) に従う。
実装担当はコンテキストの分離や独立した作業にサブエージェントを使える。
独立レビューはサブエージェントまたは `review` wrapper で行い、二重に重ねない。

`review <repo> --kind implementation --result <temp-result.json>` は標準入力の依頼に
定型 prompt と schema を添え、結果の形式・判定の矛盾を検査する（Python 3 が必要）。
`planning` / `recheck` も選べる。終了コード 0 は有効な結果を示し、
`changes_required` を pass と扱わない。詳細ログは `<temp-result.json>.log` に残す。
既存の `--schema` 呼び出しは従来どおり、独自形式の検証を呼び出し側が持つ。
Claude の編集ごとの一括テスト・build hooks は使わず、変更に必要な checks を
担当がまとめて実行する。残る Markdown lint hook は補助であり、検証完了の証明ではない。

## 新しい agent tool を足す

1. tool 固有の設定を持つ `agent/<tool>/` を作る
2. `agent/common/skills` を symlink する (必要なら rules の形式を合わせる)
3. `bin/install` へ install 手順を足す

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
最後に1回だけ完了通知を出すようにするためである。
状態は Herdr の integration hook が Herdr へ報告する。Codex は
完了に `notify` を使う。その通知 wrapper は subagent の rollout thread を
識別し、自動承認の reviewer を含めて、その完了通知を抑止する。

agent-talk は、人間がブラウザから Herdr 内の Codex / Claude Code に
メッセージを送る HTTP daemon である。返答は同じ CLI セッションの履歴から読む。
対象・作業先・状態は Herdr から取得する。Grok の通知 hook の配布は、
agent-talk の入力・履歴 adapter の対応を意味しない。

`bin/install` は Herdr が生成する Codex / Claude Code の状態報告 script を配布する。
配置先は `~/.local/bin/herdr-<runtime>-agent-state.sh`。各 runtime の hook から呼ぶ。
agent-talk 用の lifecycle 登録、peer MCP、返信 CLI は使わない。
旧 peer dispatcher・宛先 helper・Codex/Grok の旧 MCP 登録は再導入時に撤去する。

人間から届いた追加指示も、その対象セッションで続けて扱う。応答は通常の
CLI 会話履歴に残るため、別の journal や mailbox への転記は要らない。
受信側の最小の説明は [agent-talk skill](common/skills/agent-talk/SKILL.md) に置く。

### daemon の配布

binary と user service は sandbox-server の `make agent-talk-install` が所有する。
binary の配置先は `~/.local/share/sandbox-agent-talk/releases/<version>/agent-talk`。
`current` symlink を切り替えて `sandbox-agent-talk.service` を再起動する。
HTTP の待受と Tailscale/HTTPS の入口も sandbox-server が設定する。
dotfiles は daemon のコピーや MCP adapter を配置しない。

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

- `deliver` — 目的に応じて `spike` / `polish` / `refactor` / `slim` を選び、検証・レビュー・local commit まで届ける
- `spike` — 新しい体験を最小の実装で動かす
- `polish` — 既存の不満・不具合を解消する
- `refactor` — 外から見える挙動を保ち、実装の重複や不要な機構を減らす
- `slim` — 不要な機能・設定・責務・運用工程を取り除く。refactor中に気付いた候補も受け取る
- `task-work` — task-serverの全件処理。新しい子でdeliver → merge → patchリリース。
  `/goal $task-work を使ってタスクを全てこなして` で起動する
- `git` — commit message とブランチフローの house rule
- `bump-tag` — semver の bump、tag、push
- `knowledge-deposit` — 再利用できる knowledge を預ける。エントリを書き、lint
  し、自分が書いた path だけを stage する。staged diff を `review` の召喚1回で
  レビューし、local で commit する

`deliver` の分担とレビューは
[共通契約](common/skills/deliver/CONTRACT.md) に従う。
`polish`・`refactor`・`slim` は [Ponytail の実装方針](common/skills/deliver/PONYTAIL.md) を共有する。
実装担当はコンテキストの分離や独立した作業にサブエージェントを使える。
独立レビューはサブエージェントまたは `review` wrapper で行い、二重に重ねない。

`review <repo> --kind implementation --result <temp-result.json>` は標準入力の依頼に
定型 prompt と schema を添え、結果の形式・判定の矛盾を検査する（Python 3 が必要）。
`planning` / `recheck` も選べる。終了コード 0 は有効な結果を示し、
`changes_required` を pass と扱わない。詳細ログは `<temp-result.json>.log` に残す。
既存の `--schema` 呼び出しは従来どおり、独自形式の検証を呼び出し側が持つ。
Claude の編集ごとの一括テスト・build hooks は使わず、変更に必要な checks を
担当がまとめて実行する。

## Git の変更破棄 hook

`common/bin/block-git-discard` は、未コミット変更を誤って破棄する事故を減らす補助である。
2026-07-03 の `git checkout .` と clean による消失事故を踏まえて維持する。
各 runtime の既存登録から呼び、Claude/Codex の `hookSpecificOutput` と
Grok の `decision` を返す。登録範囲は既存どおりで、Codex は `Bash` に限る。

分類は shell 文字列の正規表現による近似で、複合コマンドや引用などを網羅しない。
任意の shell を実行できる agent を封じ込める認可境界ではない。
隔離検証は `python3 -B test/git-discard-hook.py` で登録済み hook を実行する。
安全な操作の無出力、危険操作の拒否、runtime ごとの入出力を確認する。

## Markdown lint

編集後の hook が、変更された `.md` だけに `meiseki-lint` の決定論層を掛ける。
共通処理は `common/bin/meiseki-lint-markdown` (Python 3) が持つ。
既存の textlint 起動形は `common/bin/meiseki-lint` に置く。
LLM rewrite や repo 全体の検査は起動しない。

| runtime | 対象の編集 | 指摘の返却 |
| --- | --- | --- |
| Claude Code | `Write` / `Edit` / `MultiEdit` | `PostToolUse.additionalContext` |
| Codex | `apply_patch` (code mode の nested call を含む) | `PostToolUse.additionalContext` |
| Grok | `search_replace` | `~/.grok/logs/markdown-lint.log` のみ |

Codex 0.153.4 と Claude Code 2.1.252 で、実編集から次のモデル入力への返却を確認した。
Grok 1.0.13 は `PostToolUse` の出力本文を破棄するため、adapter が診断をログへ保存する。
`GROK_HOME` 指定時はその配下の `logs/markdown-lint.log` を使う。
指摘を編集担当モデルへ返す経路と、この構成で利用不可の `apply_patch` は未対応である。
任意の shell コマンドや MCP tool の書込みは自動検出しない。その経路では担当が
変更した Markdown へ `meiseki-lint <file>` を実行する。

正常時は無出力、指摘と起動失敗は区別して返す。複数ファイルの patch は編集先を
重複なく検査し、削除ファイルは除く。hook 全体の時間枠を超えた対象は未実行として返す。
指摘は補助情報であり、文章の好みを承認待ちや検証完了の証明にしない。
knowledge repository の形式 lint は OKF の検査を所有し、この hook からは呼ばない。

`bin/install` は各 runtime の hooks directory をリンクする。既存の Claude settings は
machine-local なので matcher の変更を `config-merge` で取り込む。Codex の新規・変更 hook は
`/hooks` で内容を確認して trust するまで実行されない。自動試験では、内容を検査済みの
隔離 hook に限り `--dangerously-bypass-hook-trust` を使った。

隔離検証は `python3 -B test/markdown-edit-hook.py` と
`bash test/meiseki-lint-hook.bash` で行う。
決定論層は `bash test/meiseki-lint.bash` で検証する。

## 新しい agent tool を足す

1. tool 固有の設定を持つ `agent/<tool>/` を作る
2. `agent/common/skills` を symlink する (必要なら rules の形式を合わせる)
3. `bin/install` へ install 手順を足す

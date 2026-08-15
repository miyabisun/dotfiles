#!/usr/bin/env bash
# project repo を agent の記憶媒体にしない契約を固定する。
#
# 狙いは「repo を綺麗にすること」ではなく、その逆側 — agent が判断を
# project file へ書き置く代わりに、agent-talk で相手を探して相談し、
# 再利用可能なものを knowledge へ流す、を default にすることである。
# 禁止だけを入れて流路を書かないと情報が会話ごと消えるので、
# 「置かない」と「どこへ流すか」は同じ契約として pin する。
# 契約リテラルは対象ファイルの文字列そのもの。$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
discuss="$repo_root/agent/common/skills/discuss/SKILL.md"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
inventory="$repo_root/agent/common/agents/knowledge-inventory.md"

assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_absent() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'retired contract still present in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

# --- A1: 全 runtime 共通の memory boundary --------------------------------
# AGENTS.md は GLOBAL.md への symlink。CLAUDE.md は Claude 専用規則を持つ
# regular file で、共通規則は冒頭 import (@~/.claude/GLOBAL.md) で取り込む。
# 共通規則の本文は1ファイルに書く。複製は将来必ず drift する
claude_md="$repo_root/agent/claude/CLAUDE.md"
if [ -L "$claude_md" ] || [ ! -f "$claude_md" ]; then
  printf 'agent/claude/CLAUDE.md must be a regular file importing GLOBAL.md\n' >&2
  exit 1
fi
assert_contains "$claude_md" '@~/.claude/GLOBAL.md'
# installer が import 先へ GLOBAL.md を配置する
assert_contains "$repo_root/bin/install" 'agent/common/rules/GLOBAL.md" "$HOME/.claude"'
# Windows 同期は dotfiles の所有物ではない (別 repository の領分)。
# 撤去した windows-install を復活させない
if [ -e "$repo_root/bin/windows-install" ]; then
  printf 'bin/windows-install must stay removed (Windows sync lives outside dotfiles)\n' >&2
  exit 1
fi
assert_absent "$claude_md" 'windows-install'
# install は ~/.codex/AGENTS.md と ~/.grok/AGENTS.md を GLOBAL.md に張る
assert_contains "$repo_root/bin/install" 'agent/common/rules/GLOBAL.md" "$HOME/.codex/AGENTS.md'
assert_contains "$repo_root/bin/install" 'agent/common/rules/GLOBAL.md" "$HOME/.grok/AGENTS.md'

assert_contains "$global_rules" '## Project Memory Boundary'
# repo が何の正なのか
assert_contains "$global_rules" 'repository holds the current state of the product'
# 置かないものの列挙 (agent の記憶・経緯・将来作業)
for banned in 'decision record' 'TODO' 'plan' 'ledger' 'receipt' 'review log' 'handoff'; do
  assert_contains "$global_rules" "$banned"
done
# runtime 証跡を tracked file へ持ち込まない
assert_contains "$global_rules" 'message ID'
assert_contains "$global_rules" 'pane ID'
# 代替経路が同じ契約に書かれていること (禁止だけでは情報が消える)
assert_contains "$global_rules" 'ask a counterpart through your peer'
assert_contains "$global_rules" 'conversation receipt'
assert_contains "$global_rules" 'knowledge'
# 送れないときに repo へ逃がさない
assert_contains "$global_rules" 'fall back to a file in the repository'
# 例外 — ここを曖昧にすると repo の自己完結性まで禁止してしまう
assert_contains "$global_rules" 'current-state'
assert_contains "$global_rules" 'the product itself needs'

# --- A2: repo 書き込み動線を skill から除去 -------------------------------
assert_absent "$discuss" '`docs/decisions/NNNN-<slug>.md`'
assert_absent "$discuss" 'docs/ または決定記録へ置く'
assert_absent "$discuss" 'docs/decisions の決定記録'
assert_absent "$discuss" '決定記録を残して deliver の実装フェーズへ戻る'
assert_absent "$discuss" '決定記録の作成・更新はリポジトリの mutation である'
assert_absent "$discuss" '出力: 決定記録'
assert_contains "$discuss" 'docs/decisions は作らない'
assert_contains "$discuss" 'project repo の file を作らない'

# canonical な安全境界 (knowledge-inventory) と競合しないこと。
# discuss から knowledge へ直接送る命令を持たせない
assert_contains "$discuss" 'safe intake route'
assert_absent "$discuss" '`knowledge/<name>` へ 1 Decision = 1 message として送る'

# spike: TODO を repo へ残す許可を消し、receipt の follow-up へ
assert_absent "$spike" 'TODO を残してよい'
assert_absent "$spike" 'non-blocking の polish TODO'
assert_contains "$spike" 'follow-up として receipt'

# 各段階が repo へ退避しないこと
for skill in "$spike" "$polish"; do
  assert_contains "$skill" 'project repo へ file として残さない'
done

# knowledge が pending でも repo へ逃がさない (fail-closed を迂回させない)
assert_contains "$inventory" 'project repoへ退避しない'

# --- A3: 横展開の経路と、到達できる宛先 -----------------------------------
# 預け入れ経路は二本化された (user との対話 / knowledge-deposit skill)。
# 単一 role の専権という旧裁定は退役 — 常駐 intake pane が止まった以上、
# skill を使うこと自体が役割違反と読まれてはならない。
# 短くすれば安全になる、という誤りを塞ぐのは従来どおり —
# 手書きの要約は scan を一度も通っていない文字列であり、SHA-256 は source の
# 同一性であって投入 body の同一性ではない
# GLOBAL は恒常 invariant だけを持つ。route の可用性は変わり得る状態なので、
# 経路側にしか置かない (discuss「配置規約」と同じ理由 —
# binding instruction に現状を焼くと、直った後も古い指示が全 runtime に残る)
deposit_skill="$repo_root/agent/common/skills/knowledge-deposit/SKILL.md"
test -f "$deposit_skill" || {
  printf 'knowledge-deposit skill must exist: %s\n' "$deposit_skill" >&2
  exit 1
}
assert_contains "$global_rules" 'exactly two deposit routes'
assert_contains "$global_rules" 'the conversation you'
assert_contains "$global_rules" '`knowledge-deposit` skill'
# 「これ以外から預け入れない」を明文で塞ぐ。経路を2本にしただけでは、
# peer message や置き手紙が3本目として復活する
assert_contains "$global_rules" 'Nothing else'
# skill を使うこと自体を役割違反と読ませない (旧裁定の副作用を潰す)
assert_contains "$global_rules" 'never a role violation'
assert_contains "$global_rules" 'owns whether it is currently safe and'
assert_contains "$global_rules" 'Asking knowledge a question is ordinary peer conversation'
assert_contains "$global_rules" 'do not use a question to hand findings over'
assert_contains "$global_rules" 'do not restate its current status here'
assert_absent "$global_rules" 'That role is currently'
# 退役した専権裁定を復活させない
assert_absent "$global_rules" 'Depositing findings into knowledge is that'
assert_absent "$global_rules" 'safe intake route'
# bypass の口実を塞ぐのは機構の性質であって現状ではないので GLOBAL に残す
assert_contains "$global_rules" 'a hand-written summary is text the secret scan'
assert_contains "$global_rules" 'identifies the source, not the bytes you typed'
assert_contains "$global_rules" 'not grounds to bypass the route'
assert_absent "$global_rules" 'keeps the secret-scan guarantee intact'
# 経路が塞がっていることは repo を記憶にしてよい理由にならない
assert_contains "$global_rules" 'A blocked'
# blocked を黙って飲み込ませない。どの経路がどの理由で止めたかまで報告させる
assert_contains "$global_rules" 'which route and which'
# 塞がった経路は理由を潰せば再開する。user に同じ依頼をさせない
assert_contains "$global_rules" 'run the same route again'
assert_contains "$global_rules" 'does not have to ask a second time'

# 同期召喚は peer 会話ではなく、権限を広げない。ここを曖昧にすると
# 「codex exec を挟めば何でもできる」という抜け道が開く
assert_contains "$global_rules" 'headless synchronous summon'
assert_contains "$global_rules" 'carries no authority of its own and never widens'
# agent-talk の守備範囲は「走っている session 同士」へ限定された
assert_contains "$global_rules" 'between *running agent sessions*'
assert_absent "$global_rules" 'The only cross-runtime agent interface'
claude_md_rules="$repo_root/agent/claude/CLAUDE.md"
assert_absent "$claude_md_rules" 'the only cross-runtime'
assert_contains "$claude_md_rules" 'only channel between'

# role は投入経路を skill へ委ね、自分では knowledge の git を触らない
assert_contains "$inventory" 'knowledge-deposit'
assert_contains "$inventory" 'stageとcommitは`knowledge-deposit`のscriptが所有する'
# 旧経路の停止条項は退役。復活すると skill があっても投入できなくなる
assert_absent "$inventory" 'ただし現在この送信は行わない'
assert_absent "$inventory" "\`send_message\` (\`to: 'knowledge/codex'\`, \`no_reply: true\`)"

# 宛先が古いままだと、横展開しようにも相手へ届かない (v0.11.0)
talk_skill="$repo_root/agent/common/skills/agent-talk/SKILL.md"
assert_contains "$talk_skill" 'workspace の人間向けの名前'
assert_contains "$talk_skill" 'workspace id へ fallback'
# 退役した主張だけを1行で塞ぐ (改行を含むリテラルは grep -F が別パターンに割る)
assert_absent "$talk_skill" 'は**別の名前空間**'
assert_absent "$talk_skill" 'tmux/<scope>/<name>'

echo 'repository memory contract test: pass'

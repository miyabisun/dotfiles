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
harden="$repo_root/agent/common/skills/harden/SKILL.md"
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
# AGENTS.md / CLAUDE.md は GLOBAL.md への symlink なので、3箇所へ複製せず
# 1ファイルに書く。複製は将来必ず drift する
claude_md_target="$(readlink "$repo_root/agent/claude/CLAUDE.md" || true)"
[ "$claude_md_target" = "../common/rules/GLOBAL.md" ] || {
  printf 'agent/claude/CLAUDE.md must stay a symlink to GLOBAL.md (got: %s)\n' \
    "${claude_md_target:-<not a symlink>}" >&2
  exit 1
}

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
assert_contains "$global_rules" 'ask a counterpart through agent-talk'
assert_contains "$global_rules" 'conversation receipt'
assert_contains "$global_rules" 'knowledge'
# 送れないときに repo へ逃がさない
assert_contains "$global_rules" 'fall back to a file in the repository'
# 例外 — ここを曖昧にすると repo の自己完結性まで禁止してしまう
assert_contains "$global_rules" 'current-state'
assert_contains "$global_rules" 'the product itself needs'

# --- A2: repo 書き込み動線を skill から除去 -------------------------------
# discuss: 決定記録の書式は維持し、出力先だけ conversation receipt にする
assert_contains "$discuss" '## 出力: decision receipt'
assert_absent "$discuss" '`docs/decisions/NNNN-<slug>.md`'
assert_absent "$discuss" 'docs/ または決定記録へ置く'
# F は「決定記録とリポジトリだけ」を前提にしていたので、記録が repo から出る以上
# 判定の根拠も更新しないと成立しない
assert_absent "$discuss" '決定記録とリポジトリだけを'

# discuss は「出力節だけ直して他は旧命令のまま」になりやすい。実行命令が
# 分散しているので、旧 repo 出力を指す経路を1つずつ塞ぐ
assert_absent "$discuss" 'docs/decisions の決定記録'
assert_absent "$discuss" '決定記録を残して deliver の実装フェーズへ戻る'
assert_absent "$discuss" '決定記録の作成・更新はリポジトリの mutation である'
assert_absent "$discuss" 'harden は決定記録の'
assert_absent "$discuss" '出力: 決定記録'
assert_contains "$discuss" '会話へ返す decision receipt'
assert_contains "$discuss" 'project repo の file を作らない'

# canonical な安全境界 (knowledge-inventory) と競合しないこと。
# discuss から knowledge へ直接送る命令を持たせない
assert_contains "$discuss" 'safe intake route'
assert_absent "$discuss" '`knowledge/<name>` へ 1 Decision = 1 message として送る'

# Readiness F は判定時点で存在する入力だけを要求する。
# knowledge は commit 後の横展開なので F の前提にできない
assert_contains "$discuss" 'source request + この会話に返した'
assert_absent "$discuss" 'knowledge の claims** を読んで'

# spike: TODO を repo へ残す許可を消し、receipt の follow-up へ
assert_absent "$spike" 'TODO を残してよい'
assert_absent "$spike" 'non-blocking の polish TODO'
assert_contains "$spike" 'follow-up として receipt'

# 各段階が repo へ退避しないこと
for skill in "$spike" "$polish" "$harden"; do
  assert_contains "$skill" 'project repo へ file として残さない'
done
# harden の ledger は会話のもの
assert_contains "$harden" 'parent conversation context only'

# knowledge が pending でも repo へ逃がさない (fail-closed を迂回させない)
assert_contains "$inventory" 'project repoへ退避しない'

# --- A3: 横展開の経路と、到達できる宛先 -----------------------------------
# 送信は canonical role の専権。短くすれば安全になる、という誤りを塞ぐ —
# 手書きの要約は scan を一度も通っていない文字列であり、SHA-256 は source の
# 同一性であって送信 body の同一性ではない
# GLOBAL は恒常 invariant だけを持つ。route の可用性は変わり得る状態なので、
# canonical role 側にしか置かない (discuss「配置規約」と同じ理由 —
# binding instruction に現状を焼くと、直った後も古い指示が全 runtime に残る)
assert_contains "$global_rules" 'safe intake route'
assert_contains "$global_rules" 'owns whether that route is safe and available'
assert_contains "$global_rules" 'Never send to knowledge'
assert_contains "$global_rules" 'do not restate its current status here'
assert_absent "$global_rules" 'That role is currently'
# bypass の口実を塞ぐのは機構の性質であって現状ではないので GLOBAL に残す
assert_contains "$global_rules" 'a hand-written summary is text the secret scan'
assert_contains "$global_rules" 'identifies the source, not the bytes you typed'
assert_contains "$global_rules" 'not grounds to bypass the route'
assert_absent "$global_rules" 'keeps the secret-scan guarantee intact'
# 現状 (pending を返す) は canonical role が持つ
assert_contains "$inventory" 'pending'
# 経路が塞がっていることは repo を記憶にしてよい理由にならない
assert_contains "$global_rules" 'A blocked'

# 宛先が古いままだと、横展開しようにも相手へ届かない (v0.9.0)
talk_skill="$repo_root/agent/common/skills/agent-talk/SKILL.md"
assert_contains "$talk_skill" '明示 scope は backend をまたいで解決する'
assert_contains "$talk_skill" 'workspace **label** が tmux の session 名の対応物'
assert_contains "$talk_skill" '自 backend 限定'
assert_contains "$talk_skill" 'tmux/<scope>/<name>'
assert_contains "$talk_skill" 'workspace id へ fallback'
# 退役した主張だけを1行で塞ぐ (改行を含むリテラルは grep -F が別パターンに割る)
assert_absent "$talk_skill" 'は**別の名前空間**'

echo 'repository memory contract test: pass'

#!/usr/bin/env bash
# Claude Code 同士の通信経路の契約を固定する。
#
# claude↔claude はネイティブのクロスセッション経路 (ListAgents / SendMessage)
# が第一選択で、その規則は Claude 専用の CLAUDE.md にだけ書く。共有ファイル
# (GLOBAL.md / agent-talk SKILL.md) へ Claude 固有の tool 名を混ぜると
# codex / grok / cursor の文脈を汚すので、負契約で塞ぐ。agent-talk は
# cross-runtime interface として残り、混成 runtime と配達保証つき workflow は
# 引き続きそちらを使う。
# 契約リテラルは対象ファイルの文字列そのもの。$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_md="$repo_root/agent/claude/CLAUDE.md"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
talk_skill="$repo_root/agent/common/skills/agent-talk/SKILL.md"

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
    printf 'runtime-specific leak in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

# claude↔claude の第一選択と宛先規律 (ref は一覧・エラーからの verbatim のみ)
assert_contains "$claude_md" '`ListAgents`'
assert_contains "$claude_md" '`SendMessage`'
assert_contains "$claude_md" 'name [ref]'
assert_contains "$claude_md" 'never invent a ref'

# agent-talk へ残る条件: 混成 runtime・pane/workspace 指定・配達保証契約
assert_contains "$claude_md" 'codex, grok, or cursor'
assert_contains "$claude_md" 'durable queue, doorbell resume, read is receipt'
# cwd は一意 identity ではない。list_peers と ListAgents の cwd 突き合わせで
# pane 上の session を特定する手順は誤送信を招くので、復活させない
assert_absent "$claude_md" 'match agent-talk'

# authority 境界は native 経路でも agent-talk と同一。送信者を区別せずに
# 一括拒否すると、携帯や中継から届いた user 本人の指示まで遮る
assert_absent "$claude_md" 'carries peer information, not user authority'
assert_contains "$claude_md" 'read who'
assert_contains "$claude_md" 'sent it before you read what it authorizes'
assert_contains "$claude_md" 'The user reaching you this way is the user'
assert_contains "$claude_md" 'carries no authority'
assert_contains "$claude_md" 'permission laundering'
assert_contains "$claude_md" 'standing-authority'

# GLOBAL は runtime 中立の interface 分類だけを持つ。agent-talk の守備範囲は
# 「走っている session 同士の会話」であり、headless な同期召喚は別分類
assert_contains "$global_rules" 'between *running agent sessions*'
assert_contains "$global_rules" 'headless synchronous summon'

# 共有ファイルに Claude 固有 tool 名を書かない (user 依頼の中核制約)
for shared in "$global_rules" "$talk_skill"; do
  assert_absent "$shared" 'ListAgents'
  assert_absent "$shared" 'SendMessage'
  assert_absent "$shared" 'cross-session-message'
done

echo 'claude session messaging contract: pass'

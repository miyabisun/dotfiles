#!/usr/bin/env bash
# project repo を agent の記憶媒体にしない契約を固定する。
#
# 狙いは「repo を綺麗にすること」ではなく、その逆側 — agent が判断を
# project file へ書き置く代わりに、agent-talk で相手を探して相談し、
# 再利用可能なものを knowledge へ流す、を default にすることである。
# 禁止だけを入れて流路を書かないと情報が会話ごと消えるので、
# 「置かない」と「どこへ流すか」は同じ契約として pin する。
#
# この契約は GLOBAL.md の `## Project Memory Boundary` 節ではなく、実際に
# 書き込みが起きる場所が所有する:
#   置かない (判断履歴・TODO・plan・ledger・review log) → spike / polish /
#     merge / working skill
#   置き場の切り分け (repo は現在形の仕様、経緯は receipt と knowledge) → discuss
#   runtime 座標を payload に残さない → knowledge-deposit skill
#   投入経路は script だけ・blocked でも repo へ逃がさない
#     → knowledge-deposit skill と knowledge-inventory role
# 契約リテラルは対象ファイルの文字列そのもの。$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
discuss="$repo_root/agent/common/skills/discuss/SKILL.md"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
merge="$repo_root/agent/common/skills/merge/SKILL.md"
working="$repo_root/agent/common/skills/working/SKILL.md"
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

# --- A1: 全 runtime 共通の規則配布 ----------------------------------------
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

# 開発に入る前に knowledge を読む動線が全 runtime 共通の規則に残っていること。
# ここが消えると「repo に書いていないことは存在しない」に戻る
assert_contains "$global_rules" '| 開発を行う | `knowledge-read` → `deliver` |'

# --- A2: 置かないものと、その代わりの置き場 --------------------------------
# 置かないものの列挙 (agent の記憶・経緯・将来作業) は polish が所有する。
# receipt と handoff は禁止語ではない — receipt は推奨される置き場であり、
# handoff は user が明示する正当な引き継ぎである
assert_contains "$polish" \
  '判断履歴・TODO・plan・ledger・review log を **project repo へ file として残さない**'
# 同じ境界が repository を触る他の skill にもあること
assert_contains "$merge" '判断履歴・TODO・plan・review log を tracked file に残さない'
assert_contains "$working" '判断履歴・TODO・plan・log を tracked file に残さない'
# 何を repo に置くのかの切り分け (repo は現在形の仕様、経緯は別の所有者)
assert_contains "$discuss" 'repo には現在形の仕様として置き、経緯は receipt と knowledge が持つ'
# runtime 証跡を投入 payload や tracked file へ持ち込まない
assert_contains "$repo_root/agent/common/skills/knowledge-deposit/SKILL.md" \
  '**pane ID などの runtime 座標を payload に残さない**'

# 4527502 で規則ごと削除 (repo に該当文言なし)。復元は user の判断:
# - 'the repository holds the current state of the product' の宣言文
# - 送れないときの代替経路の明示 ('ask a counterpart through your peer' /
#   'fall back to a file in the repository' の禁止)
# - 例外リスト ('current-state' / 'the product itself needs') — repo の
#   自己完結性まで禁止しないための逃げ道だった

# --- A3: repo 書き込み動線を skill から除去 -------------------------------
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

# --- A4: 横展開の経路と、到達できる宛先 -----------------------------------
# 預け入れ経路は script 1本である。常駐 intake pane が止まった以上、
# skill を使うこと自体が役割違反と読まれてはならない。
# 短くすれば安全になる、という誤りを塞ぐのは従来どおり —
# 手書きの要約は scan を一度も通っていない文字列であり、SHA-256 は source の
# 同一性であって投入 body の同一性ではない
deposit_skill="$repo_root/agent/common/skills/knowledge-deposit/SKILL.md"
test -f "$deposit_skill" || {
  printf 'knowledge-deposit skill must exist: %s\n' "$deposit_skill" >&2
  exit 1
}
# 投入経路の本数を明文で固定する。ここが曖昧だと peer message や置き手紙が
# 別経路として復活する
assert_contains "$inventory" '投入経路は`knowledge-deposit` skillのscriptだけである'
# role は投入経路を skill へ委ね、自分では knowledge の git を触らない
assert_contains "$inventory" 'knowledge-deposit'
assert_contains "$inventory" 'stageとcommitは`knowledge-deposit`のscriptが所有する'
# 旧経路の停止条項は退役。復活すると skill があっても投入できなくなる
assert_absent "$inventory" 'ただし現在この送信は行わない'
assert_absent "$inventory" "\`send_message\` (\`to: 'knowledge/codex'\`, \`no_reply: true\`)"

# 質問と預け入れを混同させない。質問は普通の peer 会話で、findings を渡すのは
# 投入経路の仕事である
assert_contains "$spike" 'あって預け入れではない**'
assert_contains "$spike" 'findings を渡すのは intake role の仕事で、'
assert_contains "$spike" '質問に混ぜて渡さない'

# 短くすれば安全になる、を塞ぐ。scan を通していない byte を足させない
assert_contains "$inventory" 'scan後に本文を追記・整形・置換・要約しない。scanを通していない文字列を足さない。'
assert_contains "$deposit_skill" '要約を code comment に埋めるのも同じ違反である'

# 経路が塞がっていることは repo を記憶にしてよい理由にならない
assert_contains "$deposit_skill" '`blocked` のときは `reason` を receipt に残して次へ進む'
assert_contains "$deposit_skill" 'project repository へ退避しない**'
# 塞がった経路は理由を潰せば再開する。user に同じ依頼をさせない
assert_contains "$deposit_skill" 'payload を直せる blocked なら直して呼び直す'
assert_contains "$inventory" '呼び直しはuserへの再依頼を必要としない'

# 退役した裁定・主張を GLOBAL.md へ復活させない (条文は消えたが、この
# assert_absent は「戻ってこないこと」を測るので残す)
assert_absent "$global_rules" 'That role is currently'
assert_absent "$global_rules" 'Depositing findings into knowledge is that'
assert_absent "$global_rules" 'safe intake route'
assert_absent "$global_rules" 'keeps the secret-scan guarantee intact'
assert_absent "$global_rules" 'The only cross-runtime agent interface'

# 4527502 で規則ごと削除 (repo に該当文言なし)。復元は user の判断:
# - 「預け入れ経路はちょうど2本 (user との対話 / knowledge-deposit skill)」と
#   「Nothing else」の封じ込め条項 — 現行は script 1本へ統合された
# - 「skill を使うこと自体は role 違反ではない」('never a role violation') と
#   「経路の可用性は経路側が所有する」の条項
# - 「blocked はどの経路がどの理由で止めたかまで報告する」条項
# - `codex exec` の同期召喚は権限を広げない、という条項
#   ('headless synchronous summon' / 'carries no authority of its own')
# - agent-talk の守備範囲を「走っている session 同士」へ限る条項

# --- A5: 宛先と、秘密を載せない channel -----------------------------------
# 宛先が古いままだと、横展開しようにも相手へ届かない (v0.11.0)
talk_skill="$repo_root/agent/common/skills/agent-talk/SKILL.md"
assert_contains "$talk_skill" 'workspace の人間向けの名前'
assert_contains "$talk_skill" 'workspace id へ fallback'
# 退役した主張だけを1行で塞ぐ (改行を含むリテラルは grep -F が別パターンに割る)
assert_absent "$talk_skill" 'は**別の名前空間**'
assert_absent "$talk_skill" 'tmux/<scope>/<name>'
# 会話の証跡は message ID で辿る。tracked file に写経させない
assert_contains "$talk_skill" 'The doorbell names the message ID'

# Claude 専用 channel (組み込み SendMessage) は agent-talk skill の外にあるので、
# 秘密を載せない条項を自前で持つ必要がある
assert_absent "$claude_md" 'the only cross-runtime'
assert_contains "$claude_md" '相手が codex・grok・cursor のときは `agent-talk` スキルを使う'
assert_contains "$claude_md" '秘密情報 (credential・token・秘密鍵・`.env` 由来値・非公開ホスト) は送らない'

echo 'repository memory contract test: pass'

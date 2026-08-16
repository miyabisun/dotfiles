#!/usr/bin/env bash
# Contract: ファイル修正は編集スキルを通す。chore は〜20行の小修正を
# 子agent修正 → codex execレビュー → blocking無しでcommitの流れで運び、
# 超過時は deliver へ持ち替える (拒否ではなく持ち替え)。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chore="$repo_root/agent/common/skills/chore/SKILL.md"
global="$repo_root/agent/common/rules/GLOBAL.md"

# 1. chore skill が存在し、適用範囲 (20行と数え方) と deliver 持ち替えを定義する
test -f "$chore"
grep -q '^name: chore$' "$chore"
grep -q '20 行' "$chore"
grep -q '追加+削除' "$chore"
grep -q '持ち替える' "$chore"
grep -q '作業は止めない' "$chore"

# 2. 手順: 子agent修正 / codex execレビュー / blocking中はcommit禁止 / fallback
grep -q '子 agent' "$chore"
grep -q 'codex exec' "$chore"
# 起動形は review ラッパー経由 (共通 flag と timeout は review が所有する)
# shellcheck disable=SC2016  # $repo 等は SKILL.md 上のリテラル表記
grep -Fq 'review "$repo" --schema "$schema" --result "$result" < "$prompt"' "$chore"
# shellcheck disable=SC2016  # バッククォートは SKILL.md 上のリテラル表記
grep -q '`review` が所有する' "$chore"
# shellcheck disable=SC2016  # バッククォートは SKILL.md 上のリテラル表記
grep -q '`review` が無い' "$chore"
grep -q 'blocking が残っている間は commit しない' "$chore"
grep -q 'self diff-review' "$chore"
grep -q '独立レビューは未実施' "$chore"

# 3. GLOBAL.md がファイル修正を chore へルーティングし、持ち替え原則を記す
# shellcheck disable=SC2016  # バッククォートは GLOBAL.md 上のリテラル表記
grep -q '`chore`' "$global"
grep -q 'ファイルの修正' "$global"
grep -q '持ち替えて' "$global"

echo ok

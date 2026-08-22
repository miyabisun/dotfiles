#!/usr/bin/env bash
# PostToolUse hook for Edit|Write: 編集された file が *.md のときだけ、その 1 file へ
# meiseki-lint (textlint の決定論層) を掛けて、finding を編集した agent へ返す。
# Advisory only: 編集はすでに済んでいるので blocking はせず、常に exit 0 で
# additionalContext だけを喋る。clean は無出力。rc=2 や起動不能は clean と
# 取り違えないよう「lint 未実行」として同じ経路で伝える。
set -uo pipefail

file="$(jq -r '.tool_input.file_path // ""' 2>/dev/null || true)"
[[ "$file" == *.md ]] || exit 0

lint="${MEISEKI_LINT:-$HOME/.local/bin/meiseki-lint}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

"$lint" "$file" >"$work/out.json" 2>"$work/err.txt"
lint_status=$?
[[ "$lint_status" -eq 0 ]] && exit 0

emit() {
    jq -n --arg context "$1" \
        '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
    exit 0
}

if [[ "$lint_status" -eq 1 ]]; then
    # meiseki-lint は本文を temp へ写して textlint に掛けるので、JSON の filePath は
    # 編集された file ではない。報告する path は hook が知る編集対象を使う。
    findings="$(jq -r --arg path "$file" \
        '[.[].messages[] | "\($path):\(.line):\(.column) [\(.ruleId)] \(.message)"]
         | join("\n")' "$work/out.json")"
    emit "meiseki-lint が Markdown に指摘を出した (編集は完了済み・advisory):
$findings

日本語として不明瞭・冗長な箇所である。直せる指摘は直すこと。"
fi

emit "Markdown の lint を実行できず未実行のままである (clean ではない): $lint exit $lint_status
$(cat "$work/err.txt")"

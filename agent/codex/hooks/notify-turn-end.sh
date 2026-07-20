#!/usr/bin/env bash
set -euo pipefail

# Codex appends one JSON notification argument to the configured command.
PAYLOAD="${1:-}"
THREAD_ID=""
if [[ "${PAYLOAD}" =~ \"thread-id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    THREAD_ID="${BASH_REMATCH[1]}"
fi

# Suppress completion announcements from every subagent kind, including the
# automatic approval reviewer. If identification fails, preserve the parent's
# notification rather than silently dropping it.
if [[ -n "${THREAD_ID}" ]] \
    && bash ~/.dotfiles/agent/codex/hooks/is-subagent.sh "${THREAD_ID}"; then
    exit 0
fi

# このターンを起動した入力が agent-talk の呼び鈴なら、完了通知の文言を変える。
# input-messages は agent-turn-complete payload の文書化フィールド
TALK=""
if command -v jq > /dev/null 2>&1 && [[ -n "${PAYLOAD}" ]]; then
    if jq -e '[."input-messages"[]? | select(startswith("[agent-talk]"))] | length > 0' \
        <<< "${PAYLOAD}" > /dev/null 2>&1; then
        TALK="talk"
    fi
fi

exec bash "${CODEX_NOTIFY_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" codex success ${TALK:+"${TALK}"}

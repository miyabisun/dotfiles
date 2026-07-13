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

exec bash "${CODEX_NOTIFY_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" codex success

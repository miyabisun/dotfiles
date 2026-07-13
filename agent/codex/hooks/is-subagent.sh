#!/usr/bin/env bash
set -euo pipefail

# Accept either a transcript path or a Codex thread id. A session rollout's
# first record identifies whether Codex created it as a subagent thread.
TARGET="${1:-}"
[[ -n "${TARGET}" ]] || exit 1

TRANSCRIPT_PATH="${TARGET}"
if [[ ! -f "${TRANSCRIPT_PATH}" ]]; then
    SESSIONS_DIR="${CODEX_HOME:-${HOME}/.codex}/sessions"
    [[ -d "${SESSIONS_DIR}" ]] || exit 1
    TRANSCRIPT_PATH="$(find "${SESSIONS_DIR}" -type f \
        -name "*-${TARGET}.jsonl" -print 2>/dev/null | sed -n '1p')"
fi

[[ -f "${TRANSCRIPT_PATH}" ]] || exit 1
IFS= read -r METADATA < "${TRANSCRIPT_PATH}" || exit 1

[[ "${METADATA}" =~ \"source\"[[:space:]]*:[[:space:]]*\{[[:space:]]*\"subagent\"[[:space:]]*: ]]

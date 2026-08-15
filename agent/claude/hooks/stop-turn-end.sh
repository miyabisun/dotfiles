#!/usr/bin/env bash
set -euo pipefail

# Stop フック: ターン完了を emit-turn-end.sh へ渡す。通知するかどうかの判断
# (workspace 静穏ゲート) は emitter 側が行う。

INPUT="$(cat 2>/dev/null || true)"

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WAIT_CHECKER="${SELF_DIR}/../../common/bin/is-delivery-wait.sh"
LAST_ASSISTANT=""
if command -v jq >/dev/null 2>&1 && [[ -n "${INPUT}" ]]; then
    TRANSCRIPT="$(jq -r '
        if type == "object" then .transcript_path // "" else "" end
    ' <<<"${INPUT}" 2>/dev/null || true)"
    if [[ -n "${TRANSCRIPT}" && -f "${TRANSCRIPT}" ]]; then
        LAST_ASSISTANT="$(tail -n 200 "${TRANSCRIPT}" | jq -rs '
            [ .[]
              | select(.type == "assistant")
              | .message.content
              | if type == "string" then .
                else ([ .[]? | select(.type == "text") | .text ] | join("\n"))
                end
              | select(length > 0)
            ] | last // ""' 2>/dev/null || true)"
    fi
fi
if [[ -n "${LAST_ASSISTANT}" ]] \
    && printf '%s' "${LAST_ASSISTANT}" | bash "${WAIT_CHECKER}"; then
    exit 0
fi

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" claude success

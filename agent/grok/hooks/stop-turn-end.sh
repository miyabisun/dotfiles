#!/usr/bin/env bash
set -euo pipefail

# Stop: emit a turn-end notification. 通知するかどうかの判断 (workspace
# 静穏ゲート) は emitter 側が行う。
#
# Grok also fires Stop at session end (reason channel_closed / shutdown);
# only genuine end_turn completions should notify.

INPUT="$(cat 2>/dev/null || true)"

REASON=""
SESSION_ID=""
if command -v jq >/dev/null 2>&1 && [[ -n "${INPUT}" ]]; then
    REASON="$(jq -r '.reason // empty' <<<"${INPUT}" 2>/dev/null || true)"
    SESSION_ID="$(jq -r '
        if type == "object" then .sessionId // .session_id // "" else "" end
    ' <<<"${INPUT}" 2>/dev/null || true)"
fi

# Session-end / non-completion Stop: observe only.
if [[ -n "${REASON}" && "${REASON}" != "end_turn" ]]; then
    exit 0
fi

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WAIT_CHECKER="${SELF_DIR}/../../common/bin/is-delivery-wait.sh"
LAST_ASSISTANT=""
if command -v jq >/dev/null 2>&1 \
    && [[ "${SESSION_ID}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    SESSIONS_ROOT="${HOME}/.grok/sessions"
    if [[ -d "${SESSIONS_ROOT}" ]]; then
        HISTORY="$(find "${SESSIONS_ROOT}" -type f \
            -path "*/${SESSION_ID}/chat_history.jsonl" -print 2>/dev/null \
            | head -n 1 || true)"
        if [[ -n "${HISTORY}" && -f "${HISTORY}" ]]; then
            LAST_ASSISTANT="$(tail -n 200 "${HISTORY}" | jq -rs '
                [ .[]
                  | select(.type == "assistant" or .role == "assistant")
                  | if .content? != null then .content
                    elif .text? != null then .text
                    elif (.message? | type) == "object" then .message.content // ""
                    else .message // ""
                    end
                  | if type == "string" then .
                    else ([ .[]? | select(.type == "text") | .text ] | join("\n"))
                    end
                  | select(length > 0)
                ] | last // ""' 2>/dev/null || true)"
        fi
    fi
fi
if [[ -n "${LAST_ASSISTANT}" ]] \
    && printf '%s' "${LAST_ASSISTANT}" | bash "${WAIT_CHECKER}"; then
    exit 0
fi

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" grok success

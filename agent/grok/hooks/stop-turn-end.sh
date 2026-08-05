#!/usr/bin/env bash
set -euo pipefail

# Stop: emit a turn-end notification. Prefer talk-flavored wording when the
# latest user turn looks like an agent-talk doorbell. Fail open to a normal
# success notice when the payload cannot be inspected.
#
# Grok also fires Stop at session end (reason channel_closed / shutdown);
# only genuine end_turn completions should notify.

INPUT="$(cat 2>/dev/null || true)"

REASON=""
SESSION_ID=""
if command -v jq >/dev/null 2>&1 && [[ -n "${INPUT}" ]]; then
    REASON="$(jq -r '.reason // empty' <<<"${INPUT}" 2>/dev/null || true)"
    SESSION_ID="$(jq -r '.sessionId // .session_id // empty' <<<"${INPUT}" 2>/dev/null || true)"
fi

# Session-end / non-completion Stop: observe only.
if [[ -n "${REASON}" && "${REASON}" != "end_turn" ]]; then
    exit 0
fi

TALK=""
if command -v jq >/dev/null 2>&1 && [[ -n "${INPUT}" ]]; then
    # Prefer an explicit prompt field when present.
    LAST_USER="$(jq -r '
        .prompt // .userPrompt // .lastUserMessage // .user_message // empty
    ' <<<"${INPUT}" 2>/dev/null || true)"

    # Fall back to the session chat history (Grok stores under ~/.grok/sessions).
    if [[ -z "${LAST_USER}" && -n "${SESSION_ID}" ]]; then
        SESSIONS_ROOT="${HOME}/.grok/sessions"
        if [[ -d "${SESSIONS_ROOT}" ]]; then
            HISTORY="$(find "${SESSIONS_ROOT}" -type f -path "*/${SESSION_ID}/chat_history.jsonl" 2>/dev/null | head -1 || true)"
            if [[ -n "${HISTORY}" && -f "${HISTORY}" ]]; then
                LAST_USER="$(tail -n 80 "${HISTORY}" | jq -rs '
                    [ .[]
                      | select(.type == "user" or .role == "user")
                      | (.content // .text // .message // "")
                      | if type == "string" then .
                        else ([ .[]? | select(.type == "text") | .text ] | join("\n"))
                        end
                      | select(length > 0)
                    ] | last // ""
                ' 2>/dev/null || true)"
            fi
        fi
    fi

    [[ "${LAST_USER}" == "[agent-talk]"* ]] && TALK="talk"
fi

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" grok success ${TALK:+"${TALK}"}

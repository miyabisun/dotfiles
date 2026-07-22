#!/usr/bin/env bash
# Cursor CLI imports Claude-compatible hooks; its own prompt hook owns busy.
HOOK_INPUT="$(cat 2> /dev/null || true)"
if command -v jq > /dev/null 2>&1; then
    if jq -e 'type == "object" and has("cursor_version")' \
        <<< "${HOOK_INPUT}" > /dev/null 2>&1; then
        exit 0
    fi
elif [[ "${HOOK_INPUT}" == *'"cursor_version"'* ]]; then
    exit 0
fi

"${HOME}/.local/bin/agent-talk" busy > /dev/null 2>&1 || true
exit 0

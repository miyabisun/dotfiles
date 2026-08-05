#!/usr/bin/env bash
set -euo pipefail

# Stop フック: ターン完了を emit-turn-end.sh へ渡す。通知するかどうかの判断
# (workspace 静穏ゲート) は emitter 側が行う。

INPUT="$(cat 2>/dev/null || true)"

# Cursor CLI imports Claude-compatible hooks but has its own stop hook.
if command -v jq > /dev/null 2>&1; then
    if jq -e 'type == "object" and has("cursor_version")' \
        <<< "${INPUT}" > /dev/null 2>&1; then
        exit 0
    fi
elif [[ "${INPUT}" == *'"cursor_version"'* ]]; then
    exit 0
fi

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" claude success

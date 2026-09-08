#!/bin/bash
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
[[ ! -L "$SELF_PATH" ]] || exit 126
[[ "$SELF_PATH" == */* ]] || exit 126
SELF_PARENT="${SELF_PATH%/*}"
SELF_DIR="$(cd -- "$SELF_PARENT" && pwd -P)"
RUNTIME_PATHS="$SELF_DIR/.dotfiles-agent-runtime"
EMITTER="$SELF_DIR/emit-turn-end.sh"
[[ -f "$RUNTIME_PATHS" && ! -L "$RUNTIME_PATHS" ]] || exit 126
[[ -f "$EMITTER" && -x "$EMITTER" && ! -L "$EMITTER" ]] || exit 126
CURL_BIN=""
HERDR_BIN=""
JQ_BIN=""
SEEN_CURL=0
SEEN_HERDR=0
SEEN_JQ=0
while IFS= read -r RUNTIME_LINE || [[ -n "$RUNTIME_LINE" ]]; do
    case "$RUNTIME_LINE" in
        CURL_BIN=*)
            [[ "$SEEN_CURL" -eq 0 ]] || exit 126
            CURL_BIN="${RUNTIME_LINE#CURL_BIN=}"
            SEEN_CURL=1
            ;;
        HERDR_BIN=*)
            [[ "$SEEN_HERDR" -eq 0 ]] || exit 126
            HERDR_BIN="${RUNTIME_LINE#HERDR_BIN=}"
            SEEN_HERDR=1
            ;;
        JQ_BIN=*)
            [[ "$SEEN_JQ" -eq 0 ]] || exit 126
            JQ_BIN="${RUNTIME_LINE#JQ_BIN=}"
            SEEN_JQ=1
            ;;
        *) exit 126 ;;
    esac
done <"$RUNTIME_PATHS"
[[ "$SEEN_CURL" -eq 1 && "$SEEN_HERDR" -eq 1 && "$SEEN_JQ" -eq 1 ]] || exit 126
for RUNTIME_VALUE in "$CURL_BIN" "$HERDR_BIN" "$JQ_BIN"; do
    [[ "$RUNTIME_VALUE" != *[$' \t\r\n']* ]] || exit 126
done
[[ -z "$CURL_BIN" || "$CURL_BIN" == /* ]] || exit 126
[[ -z "$HERDR_BIN" || "$HERDR_BIN" == /* ]] || exit 126
[[ -z "$JQ_BIN" || "$JQ_BIN" == /* ]] || exit 126

AGENT="${1:-unknown}"
exec "$EMITTER" "$AGENT" permission

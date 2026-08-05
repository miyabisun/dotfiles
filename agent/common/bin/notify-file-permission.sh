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
SHA256_BIN=""
SHA256_MODE=""
CP_BIN=""
RM_BIN=""
STAT_BIN=""
STAT_MODE=""
SEEN_CURL=0
SEEN_HERDR=0
SEEN_JQ=0
SEEN_SHA256=0
SEEN_SHA256_MODE=0
SEEN_CP=0
SEEN_RM=0
SEEN_STAT=0
SEEN_STAT_MODE=0
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
        SHA256_BIN=*)
            [[ "$SEEN_SHA256" -eq 0 ]] || exit 126
            SHA256_BIN="${RUNTIME_LINE#SHA256_BIN=}"
            SEEN_SHA256=1
            ;;
        SHA256_MODE=*)
            [[ "$SEEN_SHA256_MODE" -eq 0 ]] || exit 126
            SHA256_MODE="${RUNTIME_LINE#SHA256_MODE=}"
            SEEN_SHA256_MODE=1
            ;;
        CP_BIN=*)
            [[ "$SEEN_CP" -eq 0 ]] || exit 126
            CP_BIN="${RUNTIME_LINE#CP_BIN=}"
            SEEN_CP=1
            ;;
        RM_BIN=*)
            [[ "$SEEN_RM" -eq 0 ]] || exit 126
            RM_BIN="${RUNTIME_LINE#RM_BIN=}"
            SEEN_RM=1
            ;;
        STAT_BIN=*)
            [[ "$SEEN_STAT" -eq 0 ]] || exit 126
            STAT_BIN="${RUNTIME_LINE#STAT_BIN=}"
            SEEN_STAT=1
            ;;
        STAT_MODE=*)
            [[ "$SEEN_STAT_MODE" -eq 0 ]] || exit 126
            STAT_MODE="${RUNTIME_LINE#STAT_MODE=}"
            SEEN_STAT_MODE=1
            ;;
        *) exit 126 ;;
    esac
done <"$RUNTIME_PATHS"
[[ "$SEEN_CURL" -eq 1 && "$SEEN_HERDR" -eq 1 && "$SEEN_JQ" -eq 1 \
    && "$SEEN_SHA256" -eq 1 && "$SEEN_SHA256_MODE" -eq 1 \
    && "$SEEN_CP" -eq 1 && "$SEEN_RM" -eq 1 \
    && "$SEEN_STAT" -eq 1 && "$SEEN_STAT_MODE" -eq 1 ]] || exit 126
for RUNTIME_VALUE in "$CURL_BIN" "$HERDR_BIN" "$JQ_BIN" "$SHA256_BIN" \
    "$CP_BIN" "$RM_BIN" "$STAT_BIN"; do
    [[ "$RUNTIME_VALUE" != *[$' \t\r\n']* ]] || exit 126
done
[[ -z "$CURL_BIN" || "$CURL_BIN" == /* ]] || exit 126
[[ -z "$HERDR_BIN" || "$HERDR_BIN" == /* ]] || exit 126
[[ -z "$JQ_BIN" || "$JQ_BIN" == /* ]] || exit 126
[[ "$SHA256_BIN" == /* ]] || exit 126
[[ "$CP_BIN" == /* && "$RM_BIN" == /* ]] || exit 126
[[ "$STAT_BIN" == /* ]] || exit 126
[[ "$SHA256_MODE" == "sha256sum" || "$SHA256_MODE" == "shasum" ]] || exit 126
[[ "$STAT_MODE" == "gnu" || "$STAT_MODE" == "bsd" ]] || exit 126

AGENT="${1:-unknown}"
MESSAGE_ID="${2:-}"

if [[ ! "$MESSAGE_ID" =~ ^[0-9]+$ ]]; then
    printf 'agent-talk message ID must be numeric\n' >&2
    exit 2
fi

exec "$EMITTER" "$AGENT" permission

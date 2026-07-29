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
TMUX_BIN=""
CURL_BIN=""
SHA256_BIN=""
SHA256_MODE=""
CP_BIN=""
RM_BIN=""
STAT_BIN=""
STAT_MODE=""
SEEN_TMUX=0
SEEN_CURL=0
SEEN_SHA256=0
SEEN_SHA256_MODE=0
SEEN_CP=0
SEEN_RM=0
SEEN_STAT=0
SEEN_STAT_MODE=0
while IFS= read -r RUNTIME_LINE || [[ -n "$RUNTIME_LINE" ]]; do
    case "$RUNTIME_LINE" in
        TMUX_BIN=*)
            [[ "$SEEN_TMUX" -eq 0 ]] || exit 126
            TMUX_BIN="${RUNTIME_LINE#TMUX_BIN=}"
            SEEN_TMUX=1
            ;;
        CURL_BIN=*)
            [[ "$SEEN_CURL" -eq 0 ]] || exit 126
            CURL_BIN="${RUNTIME_LINE#CURL_BIN=}"
            SEEN_CURL=1
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
[[ "$SEEN_TMUX" -eq 1 && "$SEEN_CURL" -eq 1 \
    && "$SEEN_SHA256" -eq 1 && "$SEEN_SHA256_MODE" -eq 1 \
    && "$SEEN_CP" -eq 1 && "$SEEN_RM" -eq 1 \
    && "$SEEN_STAT" -eq 1 && "$SEEN_STAT_MODE" -eq 1 ]] || exit 126
for RUNTIME_VALUE in "$TMUX_BIN" "$CURL_BIN" "$SHA256_BIN" \
    "$CP_BIN" "$RM_BIN" "$STAT_BIN"; do
    [[ "$RUNTIME_VALUE" != *[$' \t\r\n']* ]] || exit 126
done
[[ "$TMUX_BIN" == /* ]] || exit 126
[[ -z "$CURL_BIN" || "$CURL_BIN" == /* ]] || exit 126
[[ "$SHA256_BIN" == /* ]] || exit 126
[[ "$CP_BIN" == /* && "$RM_BIN" == /* ]] || exit 126
[[ "$STAT_BIN" == /* ]] || exit 126
[[ "$SHA256_MODE" == "sha256sum" || "$SHA256_MODE" == "shasum" ]] || exit 126
[[ "$STAT_MODE" == "gnu" || "$STAT_MODE" == "bsd" ]] || exit 126
if [[ -n "${TMUX:-}" ]]; then
    [[ -x "$TMUX_BIN" ]] || exit 126
fi

AGENT="${1:-unknown}"
MESSAGE_ID="${2:-}"

if [[ ! "$MESSAGE_ID" =~ ^[0-9]+$ ]]; then
    printf 'agent-talk message ID must be numeric\n' >&2
    exit 2
fi

if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    LAST_ID="$("$TMUX_BIN" show-options -pqv -t "${TMUX_PANE}" \
        @agent_file_permission_notice_id 2>/dev/null || true)"
    [[ "$LAST_ID" == "$MESSAGE_ID" ]] && exit 0

    "$TMUX_BIN" set-option -p -t "${TMUX_PANE}" \
        @agent_file_permission_notice_id "$MESSAGE_ID" 2>/dev/null || true
    "$TMUX_BIN" set-option -p -t "${TMUX_PANE}" \
        @agent_file_permission_waiting 1 2>/dev/null || true

    PANE_TTY="$("$TMUX_BIN" display-message -p -t "${TMUX_PANE}" \
        '#{pane_tty}' 2>/dev/null || true)"
    if [[ -n "$PANE_TTY" && -w "$PANE_TTY" ]]; then
        printf '\a' >"$PANE_TTY" 2>/dev/null || true
    fi
fi

exec "$EMITTER" "$AGENT" permission

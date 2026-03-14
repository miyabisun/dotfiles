#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-unknown}"
STATUS="${2:-success}"

# tmux 外なら何もしない
[[ -n "${TMUX:-}" ]] || exit 0

# pane の TTY に直接 BEL を書く
if [[ -n "${TMUX_PANE:-}" ]]; then
    PANE_TTY="$(tmux display-message -p -t "${TMUX_PANE}" '#{pane_tty}' 2>/dev/null || true)"
    if [[ -n "${PANE_TTY}" && -w "${PANE_TTY}" ]]; then
        printf '\a' > "${PANE_TTY}"
        exit 0
    fi
fi

# fallback
printf '\a'

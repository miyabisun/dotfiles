#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-unknown}"
STATUS="${2:-success}"

# MOCA_URL があれば /notify に完了通知を投げる (moca-server が喋る。失敗は無視)
# ただし、最後に操作したクライアントが表示中のウィンドウなら
# 目の前で完了が見えているので喋らせない
if [[ -n "${MOCA_URL:-}" ]]; then
    SESSION=""
    VIEWING=""
    if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
        SESSION="$(tmux display-message -p -t "${TMUX_PANE}" '#S' 2>/dev/null || true)"
        # 「最後に操作したクライアント」が見ているセッションを取る
        # (放置されたままの古いアタッチに引きずられないため)
        LAST_CLIENT_SESSION="$(tmux list-clients -F '#{client_activity} #{client_session}' 2>/dev/null \
            | sort -rn | head -1 | cut -d' ' -f2- || true)"
        if [[ -n "${SESSION}" && "${LAST_CLIENT_SESSION}" == "${SESSION}" ]]; then
            VIEWING="$(tmux display-message -p -t "${TMUX_PANE}" '#{?window_active,1,}' 2>/dev/null || true)"
        fi
    fi
    if [[ -z "${VIEWING}" ]]; then
        case "${STATUS}" in
            success) MSG="${SESSION:+${SESSION}の}${AGENT}が完了しました" ;;
            waiting) MSG="${SESSION:+${SESSION}の}${AGENT}が確認を求めています" ;;
            *)       MSG="${SESSION:+${SESSION}の}${AGENT}が${STATUS}で終了しました" ;;
        esac
        curl -fsS -m 5 -X POST -H 'Content-Type: text/plain' \
            --data "${MSG}" "${MOCA_URL%/}/notify" >/dev/null 2>&1 &
    fi
fi

# tmux 外なら BEL は出せないので終了
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

#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-unknown}"
STATUS="${2:-success}"

# tmux 内なら所属セッションと「ユーザーが目の前で見ているか」を判定する
# 「最後に操作したクライアント」基準で見る
# (放置されたままの古いアタッチに引きずられないため)
SESSION=""
VIEWING=""
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    SESSION="$(tmux display-message -p -t "${TMUX_PANE}" '#S' 2>/dev/null || true)"
    LAST_CLIENT_SESSION="$(tmux list-clients -F '#{client_activity} #{client_session}' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2- || true)"
    if [[ -n "${SESSION}" && "${LAST_CLIENT_SESSION}" == "${SESSION}" ]]; then
        VIEWING="$(tmux display-message -p -t "${TMUX_PANE}" '#{?window_active,1,}' 2>/dev/null || true)"
    fi
fi

# 第3引数 "talk" = agent-talk の呼び鈴で始まったターン。
# 判定は呼び出し元 (claude: Stop フックが transcript の最終ユーザー入力を、
# codex: notify-turn-end.sh が payload の input-messages を見る) が行う。
# 呼び鈴の到着と実行中ターンの順序ずれがあるため、これは pane 状態では持たない
TALK="${3:-}"

# このターン内で agent-talk send した (=ボールを渡した) なら声は出さない。
# チェーン最後の者だけが喋る。印は send 自身が同一ターン内で立てるので
# 順序ずれはなく、ターン完走時に消費する
SENT=""
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    SENT="$(tmux show-options -pqv -t "${TMUX_PANE}" @agent_talk_sent 2>/dev/null || true)"
    if [[ -n "${SENT}" && "${STATUS}" == "success" ]]; then
        tmux set-option -p -t "${TMUX_PANE}" -u @agent_talk_sent 2>/dev/null || true
    fi
fi

# MOCA_URL があれば /notify に通知する (moca-server が喋る。失敗は無視)
# 目の前で見ている場合も反応は残し、セッション名・agent名だけ省略する
if [[ -n "${MOCA_URL:-}" && ( -z "${SENT}" || "${STATUS}" != "success" ) ]]; then
    DONE="完了しました"
    [[ -n "${TALK}" ]] && DONE="agent-talkを完了しました"
    if [[ -n "${VIEWING}" ]]; then
        case "${STATUS}" in
            success) MSG="${DONE}" ;;
            waiting) MSG="確認させてください" ;;
            *)       MSG="${STATUS}で終了しました" ;;
        esac
    else
        case "${STATUS}" in
            success) MSG="${SESSION:+${SESSION}の}${AGENT}が${DONE}" ;;
            waiting) MSG="${SESSION:+${SESSION}の}${AGENT}が確認を求めています" ;;
            *)       MSG="${SESSION:+${SESSION}の}${AGENT}が${STATUS}で終了しました" ;;
        esac
    fi
    curl -fsS -m 5 -X POST -H 'Content-Type: text/plain' \
        --data "${MSG}" "${MOCA_URL%/}/notify" >/dev/null 2>&1 || true
fi

# tmux 外なら以降は何もできない
[[ -n "${TMUX:-}" ]] || exit 0

# status-right のラベル用フラグを立てる。
# tmux 標準の bell アラートは「アタッチ中セッションのカレントウィンドウ」では
# 記録されないため、放置されたアタッチが1つあるだけでラベルが出なくなる。
# そこで独自のセッションオプションで持ち、消灯はユーザーがそのセッションを
# 見に行ったときに tmux.conf のフックで行う
if [[ -n "${TMUX_PANE:-}" && -z "${VIEWING}" ]]; then
    tmux set-option -t "${TMUX_PANE}" @agent_bell 1 2>/dev/null || true
    tmux set-option -w -t "${TMUX_PANE}" @agent_bell 1 2>/dev/null || true
fi

# ターン完走時は idle 化し、busy 中に届いた agent-talk の呼び鈴があれば
# ここで配達する (アイドルの瞬間に本人が配るので steer が起きない)。
# あわせて宛先不在キューの回収 (gc: 送信元への失敗通知) も行う
if [[ "${STATUS}" == "success" ]]; then
    bash "${HOME}/.local/bin/agent-talk" turn-end 2>/dev/null || true
    bash "${HOME}/.local/bin/agent-talk" gc 2>/dev/null || true
fi

#!/bin/bash
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
[[ ! -L "$SELF_PATH" ]] || exit 126
[[ "$SELF_PATH" == */* ]] || exit 126
SELF_PARENT="${SELF_PATH%/*}"
SELF_DIR="$(cd -- "$SELF_PARENT" && pwd -P)"
RUNTIME_PATHS="$SELF_DIR/.dotfiles-agent-runtime"
# broker は systemd 管理の常駐サービスであり、その実体は home-server の規約で
# releases/vX.Y.Z + current に不変配置される (`~/.local/bin/<service>` は
# moca-server / shoebox と同様に廃止済みの旧 layout)。current は symlink だが
# leaf は通常ファイルなので、下の非 symlink 検査はそのまま成立する。
BROKER="${HOME}/.local/share/agent-talk/current/agent-talk"
AGENT="${1:-unknown}"
STATUS="${2:-success}"

turn_end_on_exit() {
    if [[ -f "$BROKER" && -x "$BROKER" && ! -L "$BROKER" ]]; then
        "$BROKER" turn-end 2>/dev/null || true
    fi
}
if [[ "$STATUS" == "success" ]]; then
    trap turn_end_on_exit EXIT
fi

[[ -f "$BROKER" && -x "$BROKER" && ! -L "$BROKER" ]] || exit 126
[[ -f "$RUNTIME_PATHS" && ! -L "$RUNTIME_PATHS" ]] || exit 126
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

# tmux 内なら所属セッションと「ユーザーが目の前で見ているか」を判定する
# 「最後に操作したクライアント」基準で見る
# (放置されたままの古いアタッチに引きずられないため)
SESSION=""
VIEWING=""
LAST_CLIENT_SESSION=""
CONTEXT="${PWD##*/}"
[[ -n "${CONTEXT}" ]] || CONTEXT="project"
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    SESSION="$("$TMUX_BIN" display-message -p -t "${TMUX_PANE}" '#S' 2>/dev/null || true)"
    [[ -n "${SESSION}" ]] && CONTEXT="${SESSION}"
    LAST_CLIENT_ACTIVITY=-1
    while read -r CLIENT_ACTIVITY CLIENT_SESSION; do
        if [[ "$CLIENT_ACTIVITY" =~ ^[0-9]+$ \
            && "$CLIENT_ACTIVITY" -gt "$LAST_CLIENT_ACTIVITY" ]]; then
            LAST_CLIENT_ACTIVITY="$CLIENT_ACTIVITY"
            LAST_CLIENT_SESSION="$CLIENT_SESSION"
        fi
    done < <("$TMUX_BIN" list-clients \
        -F '#{client_activity} #{client_session}' 2>/dev/null || true)
    if [[ -n "${SESSION}" && "${LAST_CLIENT_SESSION}" == "${SESSION}" ]]; then
        VIEWING="$("$TMUX_BIN" display-message -p -t "${TMUX_PANE}" '#{?window_active,1,}' 2>/dev/null || true)"
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
PERMISSION_WAITING=""
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    SENT="$("$TMUX_BIN" show-options -pqv -t "${TMUX_PANE}" @agent_talk_sent 2>/dev/null || true)"
    PERMISSION_WAITING="$("$TMUX_BIN" show-options -pqv -t "${TMUX_PANE}" \
        @agent_file_permission_waiting 2>/dev/null || true)"
    if [[ -n "${SENT}" && "${STATUS}" == "success" ]]; then
        "$TMUX_BIN" set-option -p -t "${TMUX_PANE}" -u @agent_talk_sent 2>/dev/null || true
    fi
    if [[ -n "${PERMISSION_WAITING}" && "${STATUS}" == "success" ]]; then
        "$TMUX_BIN" set-option -p -t "${TMUX_PANE}" -u \
            @agent_file_permission_waiting 2>/dev/null || true
    fi
fi

# MOCA_URL があれば /notify に通知する (moca-server が喋る。失敗は無視)
# 目の前で見ている場合も反応は残し、セッション名・agent名だけ省略する
# agent-talk の呼び鈴で始まったターンの成功完了は通知しない — peer 往復の
# たびに完了音声が飛ぶのは過剰。確認待ち・許可待ち・異常終了は起点に関係
# なく人間の対応が要るので残す
if [[ -n "${MOCA_URL:-}" && -n "$CURL_BIN" && -x "$CURL_BIN" \
    && ( -z "${TALK}" || "${STATUS}" != "success" ) \
    && ( -z "${SENT}" || "${STATUS}" != "success" ) \
    && ( -z "${PERMISSION_WAITING}" || "${STATUS}" == "permission" ) ]]; then
    DONE="完了しました"
    if [[ -n "${VIEWING}" ]]; then
        case "${STATUS}" in
            success) MSG="${DONE}" ;;
            waiting) MSG="確認させてください" ;;
            permission) MSG="${CONTEXT}でファイル操作の許可が必要です" ;;
            *)       MSG="${STATUS}で終了しました" ;;
        esac
    else
        case "${STATUS}" in
            success) MSG="${SESSION:+${SESSION}の}${AGENT}が${DONE}" ;;
            waiting) MSG="${SESSION:+${SESSION}の}${AGENT}が確認を求めています" ;;
            permission) MSG="${CONTEXT}でファイル操作の許可が必要です" ;;
            *)       MSG="${SESSION:+${SESSION}の}${AGENT}が${STATUS}で終了しました" ;;
        esac
    fi
    "$CURL_BIN" -fsS -m 5 -X POST -H 'Content-Type: text/plain' \
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
    "$TMUX_BIN" set-option -t "${TMUX_PANE}" @agent_bell 1 2>/dev/null || true
    "$TMUX_BIN" set-option -w -t "${TMUX_PANE}" @agent_bell 1 2>/dev/null || true
fi

# STATUS=success の turn-end は EXIT trap が常に一度試みる。通知用 runtime
# pin が壊れていても、busy queue と idle 復帰を巻き添えにしない。

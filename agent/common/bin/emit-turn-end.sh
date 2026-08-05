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
CURL_BIN=""
SHA256_BIN=""
SHA256_MODE=""
CP_BIN=""
RM_BIN=""
STAT_BIN=""
STAT_MODE=""
SEEN_CURL=0
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
[[ "$SEEN_CURL" -eq 1 \
    && "$SEEN_SHA256" -eq 1 && "$SEEN_SHA256_MODE" -eq 1 \
    && "$SEEN_CP" -eq 1 && "$SEEN_RM" -eq 1 \
    && "$SEEN_STAT" -eq 1 && "$SEEN_STAT_MODE" -eq 1 ]] || exit 126
for RUNTIME_VALUE in "$CURL_BIN" "$SHA256_BIN" \
    "$CP_BIN" "$RM_BIN" "$STAT_BIN"; do
    [[ "$RUNTIME_VALUE" != *[$' \t\r\n']* ]] || exit 126
done
[[ -z "$CURL_BIN" || "$CURL_BIN" == /* ]] || exit 126
[[ "$SHA256_BIN" == /* ]] || exit 126
[[ "$CP_BIN" == /* && "$RM_BIN" == /* ]] || exit 126
[[ "$STAT_BIN" == /* ]] || exit 126
[[ "$SHA256_MODE" == "sha256sum" || "$SHA256_MODE" == "shasum" ]] || exit 126
[[ "$STAT_MODE" == "gnu" || "$STAT_MODE" == "bsd" ]] || exit 126

CONTEXT="${PWD##*/}"
[[ -n "${CONTEXT}" ]] || CONTEXT="project"

# 第3引数 "talk" = agent-talk の呼び鈴で始まったターン。
# 判定は呼び出し元 (claude: Stop フックが transcript の最終ユーザー入力を、
# codex: notify-turn-end.sh が payload の input-messages を見る) が行う。
TALK="${3:-}"

# MOCA_URL があれば /notify に通知する (moca-server が喋る。失敗は無視)
# agent-talk の呼び鈴で始まったターンの成功完了は通知しない — peer 往復の
# たびに完了音声が飛ぶのは過剰。確認待ち・許可待ち・異常終了は起点に関係
# なく人間の対応が要るので残す
if [[ -n "${MOCA_URL:-}" && -n "$CURL_BIN" && -x "$CURL_BIN" \
    && ( -z "${TALK}" || "${STATUS}" != "success" ) ]]; then
    case "${STATUS}" in
        success) MSG="${AGENT}が完了しました" ;;
        waiting) MSG="${AGENT}が確認を求めています" ;;
        permission) MSG="${CONTEXT}でファイル操作の許可が必要です" ;;
        *)       MSG="${AGENT}が${STATUS}で終了しました" ;;
    esac
    "$CURL_BIN" -fsS -m 5 -X POST -H 'Content-Type: text/plain' \
        --data "${MSG}" "${MOCA_URL%/}/notify" >/dev/null 2>&1 || true
fi

# STATUS=success の turn-end は EXIT trap が常に一度試みる。通知用 runtime
# pin が壊れていても、busy queue と idle 復帰を巻き添えにしない。

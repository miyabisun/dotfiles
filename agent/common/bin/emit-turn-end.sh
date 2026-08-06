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

CONTEXT="${PWD##*/}"
[[ -n "${CONTEXT}" ]] || CONTEXT="project"

# 完了通知は workspace が静穏になったときだけ出す。協働 (agent-talk の往復)
# の途中では誰かが working なので黙り、最後のターンが終わって全員 done/idle
# になった1回だけ鳴る。判定不能 (herdr/jq/env の欠落・照会失敗) は従来どおり
# 通知する — herdr の不調で完了通知が消える方を避ける (fail-open)。
workspace_quiescent() {
    [[ -n "$HERDR_BIN" && -x "$HERDR_BIN" ]] || return 0
    [[ -n "$JQ_BIN" && -x "$JQ_BIN" ]] || return 0
    [[ -n "${HERDR_PANE_ID:-}" && -n "${HERDR_WORKSPACE_ID:-}" ]] || return 0
    local agents statuses
    agents="$("$HERDR_BIN" agent list 2>/dev/null)" || return 0
    # $ws / $self は jq 側の変数 (shell 展開ではない)
    # shellcheck disable=SC2016
    statuses="$(printf '%s' "$agents" | "$JQ_BIN" -r \
        --arg ws "$HERDR_WORKSPACE_ID" --arg self "$HERDR_PANE_ID" '
        .result.agents[]?
        | select(.workspace_id == $ws and .pane_id != $self)
        | .agent_status' 2>/dev/null)" || return 0
    # unknown は「herdr が判定できた結果」なので静穏には数えない。
    case "$statuses" in
        *working* | *blocked* | *unknown*) return 1 ;;
    esac
    return 0
}

# success 通知の主語は workspace label (= user が見る session 名)。通知は
# workspace 全体の静穏化を表すので、単位も名前も workspace に合わせる。
# 解決できなければ workspace id、id も無ければ cwd basename — 名前解決の
# 失敗を通知の消失に波及させない。呼ぶのは実際に通知するときだけ。
workspace_display_name() {
    if [[ -n "${HERDR_WORKSPACE_ID:-}" ]]; then
        if [[ -n "$HERDR_BIN" && -x "$HERDR_BIN" && -n "$JQ_BIN" && -x "$JQ_BIN" ]]; then
            local workspaces label
            if workspaces="$("$HERDR_BIN" workspace list 2>/dev/null)"; then
                # $ws は jq 側の変数 (shell 展開ではない)
                # shellcheck disable=SC2016
                label="$(printf '%s' "$workspaces" | "$JQ_BIN" -r \
                    --arg ws "$HERDR_WORKSPACE_ID" '
                    .result.workspaces[]?
                    | select(.workspace_id == $ws)
                    | .label // empty' 2>/dev/null)" || label=""
                if [[ -n "$label" ]]; then
                    printf '%s' "$label"
                    return 0
                fi
            fi
        fi
        printf '%s' "$HERDR_WORKSPACE_ID"
        return 0
    fi
    printf '%s' "$CONTEXT"
}

# MOCA_URL があれば /notify に通知する (moca-server が喋る。失敗は無視)
# 確認待ち・許可待ち・異常終了は静穏と無関係に人間の対応が要るので常に通知する
NOTIFY=1
if [[ "$STATUS" == "success" ]] && ! workspace_quiescent; then
    NOTIFY=0
fi
if [[ -n "${MOCA_URL:-}" && -n "$CURL_BIN" && -x "$CURL_BIN" \
    && "$NOTIFY" -eq 1 ]]; then
    case "${STATUS}" in
        success) MSG="$(workspace_display_name)が完了しました" ;;
        waiting) MSG="${AGENT}が確認を求めています" ;;
        permission) MSG="${CONTEXT}でファイル操作の許可が必要です" ;;
        *)       MSG="${AGENT}が${STATUS}で終了しました" ;;
    esac
    "$CURL_BIN" -fsS -m 5 -X POST -H 'Content-Type: text/plain' \
        --data "${MSG}" "${MOCA_URL%/}/notify" >/dev/null 2>&1 || true
fi

# STATUS=success の turn-end は EXIT trap が常に一度試みる。通知用 runtime
# pin が壊れていても、busy queue と idle 復帰を巻き添えにしない。

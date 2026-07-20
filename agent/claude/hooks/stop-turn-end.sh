#!/usr/bin/env bash
set -euo pipefail

# Stop フック: 完了通知を出す前に、このターンを起動したユーザー入力が
# agent-talk の呼び鈴 ("[agent-talk]" で始まる) かを transcript で判定し、
# 該当すれば talk フラグ付きで emit-turn-end.sh を呼ぶ。
# 判定不能時は通常の完了通知に落とす (通知を失わないことを優先)

INPUT="$(cat 2>/dev/null || true)"

TALK=""
if command -v jq > /dev/null 2>&1 && [[ -n "${INPUT}" ]]; then
    TRANSCRIPT="$(jq -r '.transcript_path // empty' <<< "${INPUT}" 2>/dev/null || true)"
    if [[ -n "${TRANSCRIPT}" && -f "${TRANSCRIPT}" ]]; then
        # 直近のユーザー入力だけ見ればよいので末尾に絞る。
        # type=user でも tool_result 行が混ざるため、text を持つ行だけ拾う
        LAST_USER="$(tail -n 200 "${TRANSCRIPT}" | jq -rs '
            [ .[]
              | select(.type == "user")
              | .message.content
              | if type == "string" then .
                else ([ .[]? | select(.type == "text") | .text ] | join("\n"))
                end
              | select(length > 0)
            ] | last // ""' 2>/dev/null || true)"
        [[ "${LAST_USER}" == "[agent-talk]"* ]] && TALK="talk"
    fi
fi

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" claude success ${TALK:+"${TALK}"}

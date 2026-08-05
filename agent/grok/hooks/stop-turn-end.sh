#!/usr/bin/env bash
set -euo pipefail

# Stop: emit a turn-end notification. 通知するかどうかの判断 (workspace
# 静穏ゲート) は emitter 側が行う。
#
# Grok also fires Stop at session end (reason channel_closed / shutdown);
# only genuine end_turn completions should notify.

INPUT="$(cat 2>/dev/null || true)"

REASON=""
if command -v jq >/dev/null 2>&1 && [[ -n "${INPUT}" ]]; then
    REASON="$(jq -r '.reason // empty' <<<"${INPUT}" 2>/dev/null || true)"
fi

# Session-end / non-completion Stop: observe only.
if [[ -n "${REASON}" && "${REASON}" != "end_turn" ]]; then
    exit 0
fi

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" grok success

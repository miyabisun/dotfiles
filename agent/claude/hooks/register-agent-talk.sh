#!/usr/bin/env bash
# Cursor CLI imports Claude-compatible hooks. Keep its zsh wrapper registration
# instead of overwriting the pane name with "claude" during SessionStart.
# 管理・headless 起動 (claude mcp 等) は対話 pane ではない。zsh wrapper が
# 立てる skip 変数を尊重し、pane の既存登録を消さない。
if [[ -n "${CLAUDE_AGENT_TALK_SKIP:-}" ]]; then
    exit 0
fi

HOOK_INPUT="$(cat 2> /dev/null || true)"
if command -v jq > /dev/null 2>&1; then
    if jq -e 'type == "object" and has("cursor_version")' \
        <<< "${HOOK_INPUT}" > /dev/null 2>&1; then
        exit 0
    fi
elif [[ "${HOOK_INPUT}" == *'"cursor_version"'* ]]; then
    exit 0
fi

"${HOME}/.local/share/agent-talk/current/agent-talk" register claude > /dev/null 2>&1 || true
exit 0

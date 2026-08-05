#!/usr/bin/env bash
# SessionEnd: drop this pane from the agent-talk registry.
if [[ -n "${GROK_AGENT_TALK_SKIP:-}" ]]; then
    exit 0
fi

cat >/dev/null 2>&1 || true

"${HOME}/.local/share/agent-talk/current/agent-talk" unregister >/dev/null 2>&1 || true
exit 0

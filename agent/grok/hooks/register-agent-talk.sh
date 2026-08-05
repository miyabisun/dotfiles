#!/usr/bin/env bash
# SessionStart: register this pane as "grok" with the agent-talk broker.
# Management / headless launches set GROK_AGENT_TALK_SKIP so they do not
# clobber an interactive pane's registration.
if [[ -n "${GROK_AGENT_TALK_SKIP:-}" ]]; then
    exit 0
fi

# Drain stdin (hook payload) so the runner does not see a broken pipe.
cat >/dev/null 2>&1 || true

"${HOME}/.local/share/agent-talk/current/agent-talk" register grok >/dev/null 2>&1 || true
exit 0

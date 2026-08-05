#!/usr/bin/env bash
# UserPromptSubmit: mark the registered pane busy without blocking input.
cat >/dev/null 2>&1 || true

"${HOME}/.local/share/agent-talk/current/agent-talk" busy >/dev/null 2>&1 || true
exit 0

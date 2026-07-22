#!/usr/bin/env bash
# Cursor prompt hook: mark this registered pane busy without ever blocking input.
"${HOME}/.local/bin/agent-talk" busy > /dev/null 2>&1 || true
exit 0

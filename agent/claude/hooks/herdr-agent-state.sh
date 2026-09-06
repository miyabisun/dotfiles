#!/bin/sh
# Herdr owns the session reporter; bin/install distributes its generated hook.
reporter="$HOME/.local/bin/herdr-claude-agent-state.sh"
[ -x "$reporter" ] || exit 0
exec "$reporter" "$@"

#!/usr/bin/env bash
set -euo pipefail

# spike / polish / agent-talk use this marker only when an unfinished delivery
# deliberately yields while waiting for a peer or subagent. Callers provide
# the last assistant message on stdin.
MESSAGE="$(cat 2>/dev/null || true)"
LAST_LINE="${MESSAGE##*$'\n'}"
[[ "$LAST_LINE" == '<!-- delivery:waiting -->' ]]

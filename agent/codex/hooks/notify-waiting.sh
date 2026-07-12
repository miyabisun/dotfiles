#!/usr/bin/env bash
set -euo pipefail

# PermissionRequest hook: Codex is about to wait for human approval.
# Consume the hook payload but return no JSON decision so the normal approval
# prompt remains in control.
cat >/dev/null
exec bash ~/.local/bin/emit-turn-end.sh codex waiting

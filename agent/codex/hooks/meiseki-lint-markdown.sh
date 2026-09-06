#!/usr/bin/env bash
# Routing and feedback belong to common; preserve the installed hook path.
set -euo pipefail
self="$(readlink -f "${BASH_SOURCE[0]}")"
exec "$(dirname "$self")/../../common/bin/meiseki-lint-markdown"

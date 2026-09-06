#!/usr/bin/env bash
set -euo pipefail
self="$(readlink -f "${BASH_SOURCE[0]}")"
# Grok discards successful hook stderr too; keep the diagnostics explicitly.
log_dir="${GROK_HOME:-$HOME/.grok}/logs"
mkdir -p "$log_dir"
exec "$(dirname "$self")/../../common/bin/meiseki-lint-markdown" --grok \
    2>>"$log_dir/markdown-lint.log"

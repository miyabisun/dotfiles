#!/usr/bin/env bash
# Keep the registered runtime path; classification belongs to common.
set -euo pipefail
hook_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${hook_dir}/../../common/bin/block-git-discard" grok

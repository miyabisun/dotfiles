#!/usr/bin/env bash
set -euo pipefail

metadata_error() {
  echo "tmuxinator-export: unsafe or malformed tmux metadata" >&2
  exit 1
}

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmuxinator-export: tmux not found" >&2
  exit 1
fi

if [ -z "${TMUX_PANE:-}" ]; then
  echo "tmuxinator-export: run this skill from inside the tmux session to export" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/validate-metadata.py" 2>/dev/null || metadata_error

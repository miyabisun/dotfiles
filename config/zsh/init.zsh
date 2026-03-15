# ==================================================
# Zsh configuration entry point
# Sourced after exports.sh
# ==================================================

_zsh_dir="${${(%):-%x}:A:h}"

source "$_zsh_dir/prompt.zsh"

# Plugins (sheldon)
if command -v sheldon > /dev/null 2>&1; then
  eval "$(sheldon source)"
else
  echo "[dotfiles] sheldon not found. Install it for zsh plugins:" >&2
  if [[ "$OSTYPE" == darwin* ]]; then
    echo "  brew install sheldon" >&2
  elif command -v cargo > /dev/null 2>&1; then
    echo "  cargo install sheldon" >&2
  else
    echo "  Install Rust first: https://rustup.rs" >&2
    echo "  Then run: cargo install sheldon" >&2
  fi
fi

source "$_zsh_dir/keybindings.zsh"
source "$_zsh_dir/tools.zsh"

unset _zsh_dir

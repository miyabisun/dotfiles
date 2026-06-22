# ==================================================
# Shared environment variables (POSIX sh compatible)
# Sourced by both .bashrc and .zshrc
# ==================================================

# --------------------------------------------------
# Secrets
# --------------------------------------------------
[ -f "$HOME/.config/.secrets" ] && . "$HOME/.config/.secrets"

# --------------------------------------------------
# PATH (with dedup guard for re-sourcing safety)
# --------------------------------------------------
_prepend_path() {
  case ":$PATH:" in
    *:"$1":*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

[ -d "$HOME/.local/bin" ]         && _prepend_path "$HOME/.local/bin"
[ -d "$HOME/.local/share/fnm" ]   && _prepend_path "$HOME/.local/share/fnm"
[ -d "$HOME/.dotfiles/bin/bw" ]   && _prepend_path "$HOME/.dotfiles/bin/bw"
[ -d "$HOME/go/bin" ]             && _prepend_path "$HOME/go/bin"
[ -d "$HOME/.bun/bin" ]           && _prepend_path "$HOME/.bun/bin"

# Homebrew keg-only formulas (resolves /opt/homebrew, /usr/local, /home/linuxbrew/.linuxbrew)
if command -v brew >/dev/null 2>&1; then
  for _keg in rustup; do
    _keg_bin="$(brew --prefix "$_keg" 2>/dev/null)/bin"
    [ -d "$_keg_bin" ] && _prepend_path "$_keg_bin"
  done
  unset _keg _keg_bin
fi

unset -f _prepend_path

# --------------------------------------------------
# Tool environment
# --------------------------------------------------

# bun
export BUN_INSTALL="$HOME/.bun"

# cargo / rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Aliases (fish built-in equivalents)
alias la='ls -lAh'
alias ll='ls -lh'

# fnm (Fast Node Manager)
if command -v fnm > /dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

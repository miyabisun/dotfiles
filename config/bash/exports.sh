# shellcheck shell=sh
# ==================================================
# Shared environment variables (POSIX sh compatible)
# Sourced by both .bashrc and .zshrc
# ==================================================

# --------------------------------------------------
# Secrets
# --------------------------------------------------
# shellcheck source=/dev/null
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
[ -d "$HOME/go/bin" ]             && _prepend_path "$HOME/go/bin"
[ -d "$HOME/.bun/bin" ]           && _prepend_path "$HOME/.bun/bin"

# repo 配下の bin/bw は、この file 自身の位置から repo root を導出して足す。
# bash は BASH_SOURCE、zsh は %x prompt 展開 (bash が構文解析しないよう eval
# で包む)。どちらでもなければ黙って skip する。
if [ -n "${BASH_SOURCE:-}" ]; then
  _dotfiles_self="${BASH_SOURCE}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  eval '_dotfiles_self="${(%):-%x}"'
else
  _dotfiles_self=""
fi
if [ -n "$_dotfiles_self" ]; then
  _dotfiles_bw="$(cd -- "$(dirname -- "$_dotfiles_self")/../.." && pwd -P)/bin/bw"
  [ -d "$_dotfiles_bw" ] && _prepend_path "$_dotfiles_bw"
  unset _dotfiles_bw
fi
unset _dotfiles_self

# Homebrew keg-only formulas (resolves /opt/homebrew, /usr/local, /home/linuxbrew/.linuxbrew)
if command -v brew >/dev/null 2>&1; then
  _keg_bin="$(brew --prefix rustup 2>/dev/null)/bin"
  [ -d "$_keg_bin" ] && _prepend_path "$_keg_bin"
  unset _keg_bin
fi

unset -f _prepend_path

# --------------------------------------------------
# Tool environment
# --------------------------------------------------

# bun
export BUN_INSTALL="$HOME/.bun"

# cargo / rust
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Aliases (fish built-in equivalents)
alias la='ls -lAh'
alias ll='ls -lh'

# fnm (Fast Node Manager)
if command -v fnm > /dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

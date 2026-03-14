# ==================================================
# Zsh-specific configuration (fish-like experience)
# Sourced after exports.sh
# ==================================================

# --------------------------------------------------
# Zsh plugins
# Paths differ by OS/package manager, so we search
# --------------------------------------------------
typeset -a _plugin_search_paths=(
  /usr/share/zsh/plugins            # Arch / Manjaro
  /usr/share                        # Ubuntu / Debian
  /opt/homebrew/share               # macOS (Apple Silicon)
  /usr/local/share                  # macOS (Intel) / Linuxbrew
  /home/linuxbrew/.linuxbrew/share  # Linuxbrew
)

function _source_plugin() {
  local plugin="$1" guard="$2"
  [[ -n "$guard" ]] && return
  for base in "${_plugin_search_paths[@]}"; do
    local path="$base/$plugin/$plugin.zsh"
    if [[ -f "$path" ]]; then
      source "$path"
      return
    fi
  done
}

_source_plugin zsh-autosuggestions          "$ZSH_AUTOSUGGEST_STRATEGY"
_source_plugin zsh-syntax-highlighting      "$ZSH_HIGHLIGHT_VERSION"
_source_plugin zsh-history-substring-search "$_history_substring_search_result"

unfunction _source_plugin
unset _plugin_search_paths

# History substring search keybindings (↑↓ for filtered history)
if (( $+widgets[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi

# --------------------------------------------------
# Zsh-specific tool integrations
# --------------------------------------------------

# bun completions (zsh only)
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"

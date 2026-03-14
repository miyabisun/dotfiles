# ==================================================
# Zsh-specific configuration (fish-like experience)
# Sourced after exports.sh
# ==================================================

# --------------------------------------------------
# Prompt: fish-like minimal (override Powerlevel10k)
# --------------------------------------------------
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir prompt_char)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

# Remove powerline separators and background fills
typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''
typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=''
typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''

# Dir: no background, blue text like fish
typeset -g POWERLEVEL9K_DIR_BACKGROUND='none'
typeset -g POWERLEVEL9K_DIR_FOREGROUND=253
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=253
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=253
typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_BACKGROUND='none'
typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_FOREGROUND=253
typeset -g POWERLEVEL9K_DIR_NON_EXISTENT_BACKGROUND='none'
typeset -g POWERLEVEL9K_DIR_NON_EXISTENT_FOREGROUND=253
typeset -g POWERLEVEL9K_DIR_VISUAL_IDENTIFIER_EXPANSION=''
typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_VISUAL_IDENTIFIER_EXPANSION=''
typeset -g POWERLEVEL9K_DIR_NON_EXISTENT_VISUAL_IDENTIFIER_EXPANSION=''

# Prompt char: $ (green=ok, red=error)
typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND='none'
typeset -g POWERLEVEL9K_DIR_LEFT_{LEFT,RIGHT}_WHITESPACE=
typeset -g POWERLEVEL9K_DIR_RIGHT_{LEFT,RIGHT}_WHITESPACE=
typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='$'
typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='$'
typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='$'
typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='$'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND='green'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND='red'

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
# zsh-abbr (fish-like abbreviations)
# --------------------------------------------------
_dotfiles_dir="${${(%):-%x}:A:h:h:h}"
_abbr_path="$_dotfiles_dir/config/zsh/plugins/zsh-abbr/zsh-abbr.zsh"
[[ -f "$_abbr_path" ]] && source "$_abbr_path"
unset _dotfiles_dir _abbr_path

# --------------------------------------------------
# Zsh-specific tool integrations
# --------------------------------------------------

# bun completions (zsh only)
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"

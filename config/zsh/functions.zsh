# ==================================================
# Shell functions (recognized as commands, version-controlled)
# ==================================================

# tmuxinator: pick a project with fzf, then start it
mux() {
  local project
  project="$(ls ~/.config/tmuxinator/ | sed 's/\.yml$//' | fzf)" || return
  [[ -n "$project" ]] && tmuxinator start "$project"
}

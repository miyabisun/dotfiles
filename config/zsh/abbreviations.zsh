# ==================================================
# zsh-abbr abbreviations (session scope, version-controlled)
# ==================================================

# tmuxinator: pick a project with fzf, then start it
abbr -S -q add "mux=tmuxinator start \$(ls ~/.config/tmuxinator/ | sed 's/\.yml\$//' | fzf)"

# dotenvx: run a command with env loaded quietly
abbr -S -q add "dx=dotenvx run -q --"

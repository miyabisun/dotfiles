if filereadable(expand('~/.vimrc.common.settings')) | source ~/.vimrc.common.settings | en
if filereadable(expand('~/.vimrc.plugins')) | source ~/.vimrc.plugins | en
if filereadable(expand('~/.vimrc.plugin.settings')) | source ~/.vimrc.local | en
if filereadable(expand('~/.vimrc.local')) | source ~/.vimrc.local | en

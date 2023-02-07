set list
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:%
augroup highlightIdegraphicSpace
  autocmd!
  autocmd VimEnter,ColorScheme * highlight IdeographicSpace term=underline ctermbg=DarkGreen guibg=DarkGreen
  autocmd VimEnter,WinEnter * match IdeographicSpace /　/
augroup END

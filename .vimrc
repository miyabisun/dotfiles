" File Encoding
set encoding=utf-8
scriptencoding utf-8
set fileencodings=utf-8,cp932,euc-jp
filetype plugin indent on

" Install Packages
if filereadable(expand('~/.vimrc.plugins')) | source ~/.vimrc.plugins | en

" Common Settings
syntax on
set nu
set ruler
set incsearch
set hlsearch
set ignorecase
set smartcase
set nobackup
set hlsearch
set autoread
set diffopt+=vertical
set noundofile
set backspace=indent,eol,start
set ttyfast
vnoremap * "zy:let @/ = '\V' . substitute(escape(@z, '\/'), '\n', '\\n', 'g')<CR>n
inoremap <silent> jj <ESC>
nmap <C-p> :FZF<CR>
nnoremap <ESC><ESC> :nohlsearch<CR>

set background=dark
hi IndentGuidesOdd  ctermbg=black
hi IndentGuidesEven ctermbg=darkgrey

augroup vimrc-auto-cursorline
  autocmd!
  autocmd CursorMoved,CursorMovedI * call s:auto_cursorline('CursorMoved')
  autocmd CursorHold,CursorHoldI * call s:auto_cursorline('CursorHold')
  autocmd WinEnter * call s:auto_cursorline('WinEnter')
  autocmd WinLeave * call s:auto_cursorline('WinLeave')

  let s:cursorline_lock = 0
  function! s:auto_cursorline(event)
    if a:event ==# 'WinEnter'
      setlocal cursorline
      let s:cursorline_lock = 2
    elseif a:event ==# 'WinLeave'
      setlocal nocursorline
    elseif a:event ==# 'CursorMoved'
      if s:cursorline_lock
        if 1 < s:cursorline_lock
          let s:cursorline_lock = 1
        else
          setlocal nocursorline
          let s:cursorline_lock = 0
        endif
      endif
    elseif a:event ==# 'CursorHold'
      setlocal cursorline
      let s:cursorline_lock = 1
    endif
  endfunction
augroup END

" Tab Remap
nnoremap zj <C-w>j
nnoremap zk <C-w>k
nnoremap zl <C-w>l
nnoremap zh <C-w>h
nnoremap zJ <C-w>J
nnoremap zK <C-w>K
nnoremap zL <C-w>L
nnoremap zH <C-w>H

" Highlight
set list
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:%
augroup highlightIdegraphicSpace
  autocmd!
  autocmd VimEnter,ColorScheme * highlight IdeographicSpace term=underline ctermbg=DarkGreen guibg=DarkGreen
  autocmd VimEnter,WinEnter * match IdeographicSpace /　/
augroup END

" Plugin Settings
" submode
call submode#enter_with('bufmove', 'n', '', 'z>', '<C-w>>')
call submode#enter_with('bufmove', 'n', '', 'z<', '<C-w><')
call submode#enter_with('bufmove', 'n', '', 'z+', '<C-w>+')
call submode#enter_with('bufmove', 'n', '', 'z-', '<C-w>-')
call submode#map('bufmove', 'n', '', '>', '<C-w>>')
call submode#map('bufmove', 'n', '', '<', '<C-w><')
call submode#map('bufmove', 'n', '', '+', '<C-w>+')
call submode#map('bufmove', 'n', '', '-', '<C-w>-')

" linter
let g:ale_fixers = {
\   'javascript': ['eslint'],
\}
let g:ale_lint_on_enter = 1
let g:ale_fix_on_save = 1
let g:ale_completion_enabled = 1
let g:ale_sign_column_always = 1
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" others
command! UniDecode %s/\\u\([0-9a-f]\{4}\)/\=nr2char(eval("0x".submatch(1)),1)/g

" Language Settings
" livescript
function! s:isLiveScript()
  let shebang = getline(1)
  if shebang =~# '^#!.*/bin/env\s\+lsc\>' | return 1 | en
  return 0
endfunction
augroup livescriptSyntax
  autocmd!
  autocmd BufRead,BufNewFile * if s:isLiveScript() | set filetype=ls | en
augroup END

" markdown
augroup markdownPreviewSetting
  autocmd!
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  let g:previm_open_cmd = 'open -a "Google Chrome"'
  let g:vim_markdown_folding_disabled=1
augroup END

" pug
let g:syntastic_pug_checkers = ['pug_lint']

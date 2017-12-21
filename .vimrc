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
set cursorline
set autoread
set diffopt+=vertical
set noundofile
vnoremap * "zy:let @/ = '\V' . substitute(escape(@z, '\/'), '\n', '\\n', 'g')<CR>n
inoremap <silent> jj <ESC>
nmap <C-p> :FZF<CR>
nnoremap <ESC><ESC> :nohlsearch<CR>

set background=dark
hi IndentGuidesOdd  ctermbg=black
hi IndentGuidesEven ctermbg=darkgrey

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

" vim-go
map <C-n> :cnext<CR>
map <C-m> :cprevious<CR>
nnoremap <leader>a :cclose<CR>
let g:go_fmt_command = "goimports"


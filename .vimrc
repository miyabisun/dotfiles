syntax on
filetype plugin indent on
set encoding=utf-8
scriptencoding utf-8
set fileencodings=utf-8,cp932

" vim-plug
if has('vim_starting')
  set rtp+=~/.vim/plugged/vim-plug
  if !isdirectory(expand('~/.vim/plugged/vim-plug'))
    echo 'install vim-plug...'
    call system('mkdir -p ~/.vim/plugged/vim-plug')
    call system('git clone https://github.com/junegunn/vim-plug.git ~/.vim/plugged/vim-plug/autoload')
  end
endif

call plug#begin('~/.vim/plugged')

" Add plagin's
Plug 'crusoexia/vim-monokai'
Plug 'editorconfig/editorconfig-vim'
Plug 'Shougo/unite.vim'
Plug 'rking/ag.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'kannokanno/previm', { 'for': ['markdown'] }
Plug 'tyru/open-browser.vim', { 'for': ['markdown'] }
Plug 'scrooloose/syntastic'

" Add plagin's in Language
Plug 'plasticboy/vim-markdown', { 'for': ['markdown'] }
Plug 'pangloss/vim-javascript', { 'for': ['js'] }
Plug 'raichoo/purescript-vim', { 'for': ['purs'] }
Plug 'gkz/vim-ls', { 'for': ['ls'] }
Plug 'digitaltoad/vim-pug', { 'for': ['pug'] }
Plug 'wavded/vim-stylus', { 'for': ['stylus'] }
Plug 'dag/vim2hs', { 'for': ['hs'] }
Plug 'elixir-lang/vim-elixir', { 'for': ['ex'] }

call plug#end()

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

" markdown preview setting -> :PrevimOpen command
augroup markdownPreviewSetting
  autocmd!
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  let g:previm_open_cmd = 'open -a "Google Chrome"'
augroup END

set background=dark
hi IndentGuidesOdd  ctermbg=black
hi IndentGuidesEven ctermbg=darkgrey

let g:syntastic_pug_checkers = ['pug_lint']

" highlight settings
set list
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:%
augroup highlightIdegraphicSpace
  autocmd!
  autocmd VimEnter,ColorScheme * highlight IdeographicSpace term=underline ctermbg=DarkGreen guibg=DarkGreen
  autocmd VimEnter,WinEnter * match IdeographicSpace /　/
augroup END

set nu
set ruler
set tabstop=2
set shiftwidth=2
set softtabstop=2
set incsearch
set hlsearch

set ignorecase
set smartcase
set nobackup
vnoremap * "zy:let @/ = '\V' . substitute(escape(@z, '\/'), '\n', '\\n', 'g')<CR>n
set hlsearch
nnoremap <ESC><ESC> :nohlsearch<CR>
set cursorline
inoremap <silent> jj <ESC>

nmap <C-p> :FZF<CR>


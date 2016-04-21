syntax on
filetype plugin indent on
set encoding=utf-8
set fileencodings=utf-8,cp932

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

" Add plagin's in Language
Plug 'plasticboy/vim-markdown', { 'for': ['markdown'] }
Plug 'pangloss/vim-javascript', { 'for': ['js'] }
Plug 'raichoo/purescript-vim', { 'for': ['purs'] }
Plug 'gkz/vim-ls', { 'for': ['ls'] }
Plug 'digitaltoad/vim-jade', { 'for': ['jade'] }
Plug 'wavded/vim-stylus', { 'for': ['styl'] }
Plug 'dag/vim2hs', { 'for': ['hs'] }
Plug 'elixir-lang/vim-elixir', { 'for': ['ex'] }

call plug#end()

" markdown preview setting -> :PrevimOpen command
au BufRead,BufNewFile *.md set filetype=markdown
let g:previm_open_cmd = 'open -a "Google Chrome"'

hi link lsSpaceError NONE
hi link lsReservedError NONE
au BufNewFile,BufReadPost *.ls setl foldmethod=indent nofoldenable
au BufNewFile,BufReadPost *.ls setl shiftwidth=2 expandtab

set background=dark
hi IndentGuidesOdd  ctermbg=black
hi IndentGuidesEven ctermbg=darkgrey

set list
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:%

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

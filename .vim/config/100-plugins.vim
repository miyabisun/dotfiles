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
Plug 'editorconfig/editorconfig-vim'
Plug 'Shougo/denite.nvim'
Plug 'rking/ag.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'kana/vim-submode'
Plug 'cocopon/iceberg.vim'
Plug 'severin-lemaignan/vim-minimap'
Plug 'vim-scripts/dbext.vim'
Plug 'tyru/open-browser.vim'
" Plug 'w0rp/ale'

" Add plagin's for Language Server Protocol
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'
Plug 'mattn/vim-lsp-icons'
" Plug 'hrsh7th/vim-vsnip'
" Plug 'hrsh7th/vim-vsnip-integ'

" Add plagin's for each language
" Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
" Plug 'kannokanno/previm', { 'for': 'markdown' }
" Plug 'othree/yajs.vim', { 'for': 'javascript' }
Plug 'gkz/vim-ls', { 'for': 'ls' }
Plug 'miyabisun/lslint.vim', { 'for': 'ls' }
" Plug 'digitaltoad/vim-pug', { 'for': 'pug' }
" Plug 'wavded/vim-stylus', { 'for': 'stylus' }
" Plug 'fatih/vim-go', { 'for': 'go', 'do': ':GoInstallBinaries' }
" Plug 'stephpy/vim-yaml', { 'for': 'yaml' }
" Plug 'guns/vim-sexp',    { 'for': 'clojure' }
" Plug 'liquidz/vim-iced', { 'for': 'clojure' }

call plug#end()

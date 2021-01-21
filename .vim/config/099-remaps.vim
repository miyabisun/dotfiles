vnoremap * "zy:let @/ = '\V' . substitute(escape(@z, '\/'), '\n', '\\n', 'g')<CR>n
inoremap <silent> jj <ESC>
nmap <C-p> :FZF<CR>
nnoremap <ESC><ESC> :nohlsearch<CR>
nnoremap c "_c

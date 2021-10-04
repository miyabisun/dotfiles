function! s:isClojure()
  let shebang = getline(1)
  if shebang =~# '^#!.*/bin/env\s\+bb\>' | return 1 | en
  return 0
endfunction
augroup clojureSyntax
  autocmd!
  autocmd BufRead,BufNewFile * if s:isClojure() | let g:LanguageClientSettingsPath="~/.vim/config/202-clojure-lsp-settings.json" | en
augroup END

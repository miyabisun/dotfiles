function! s:isClojure()
  let shebang = getline(1)
  if shebang =~# '^#!.*/bin/env\s\+bb\>' | return 1 | en
  return 0
endfunction
augroup clojureSyntax
  autocmd!
  autocmd BufRead,BufNewFile * if s:isClojure() | set filetype=clojure | en
augroup END

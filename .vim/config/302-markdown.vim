augroup markdownPreviewSetting
  autocmd!
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  let g:previm_open_cmd = 'open -a "Google Chrome"'
  let g:vim_markdown_folding_disabled=1
augroup END

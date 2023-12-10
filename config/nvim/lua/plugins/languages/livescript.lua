return {
  {
    'gkz/vim-ls',
    config = function()
      vim.cmd([[
      function! s:isLiveScript()
      let shebang = getline(1)
      if shebang =~# '^#!.*/bin/env\s\+lsc\>' | return 1 | en
        return 0
        endfunction

        augroup livescriptSyntax
        autocmd!
        autocmd BufRead,BufNewFile *.lson set filetype=ls
        autocmd BufRead,BufNewFile * if s:isLiveScript() | set filetype=ls | en
        autocmd BufWritePost * if s:isLiveScript() | silent LiveScriptMake! -bp | cwindow | redraw!
        autocmd FileType ls set formatoptions-=ro
        augroup END
        ]])
    end,
  },
  {'miyabisun/lslint.vim'},
}

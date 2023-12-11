local options = {
  number = true,
  diffopt = "internal,filler,closeoff,vertical",

  -- 日本語優先
  fileencodings = "utf-8,cp932,euc-jp,ucs-bom,default,latin1",
  helplang = "ja,en",

  -- 一時ファイルは作成しない
  swapfile = false,

  -- ファイル内検索
  ignorecase = true,
  smartcase = true,

  -- 仮想端末透過
  winblend = 20,
  pumblend = 20,
  termguicolors = true,

  -- 左端の欄(sign)を常に確保してガタガタを防止
  signcolumn = "yes",
}
for k, v in pairs(options) do
  vim.opt[k] = v
end

-- スペースハイライト
vim.api.nvim_create_augroup('extra-whitespace', {})
vim.api.nvim_create_autocmd({'VimEnter', 'WinEnter'}, {
  group = 'extra-whitespace',
  pattern = {'*'},
  command = [[call matchadd('ExtraWhitespace', '[\u00A0\u2000-\u200B\u3000]')]],
})
vim.api.nvim_create_autocmd({'ColorScheme'}, {
  group = 'extra-whitespace',
  pattern = {'*'},
  command = [[highlight default ExtraWhitespace ctermbg=202 ctermfg=202 guibg=salmon]],
})

local highlight = {
  Visual = {bg = "#6f8696"},
}
for group, conf in pairs(highlight) do
  vim.api.nvim_set_hl(0, group, conf)
end

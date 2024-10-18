local nnoremaps = {
  zt = ":tabe<cr>",
  zs = "<C-w>s",
  zv = "<C-w>v",
  zj = "<C-w>j",
  zk = "<C-w>k",
  zl = "<C-w>l",
  zh = "<C-w>h",
  zJ = "<C-w>J",
  zK = "<C-w>K",
  zL = "<C-w>L",
  zH = "<C-w>H",
  ["z="] = "<C-w>=",

  -- netrw
  ze = ":Explore<cr>",

  -- search
  ["<ESC><ESC>"] = ":nohlsearch<CR>",
}
for k, v in pairs(nnoremaps) do
  vim.keymap.set("n", k, v, {noremap = true, silent = true})
end

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- ze: Go back to explorer (Netrw)
map("n", "ze", "<cmd>Ex<cr>", { desc = "Go back to explorer" })

-- zp: Fzf Project Files
map("n", "zp", "<cmd>FzfLua files<cr>", { desc = "Fzf Project Files" })
-- z/: Fzf Live Grep (Full Text Search)
map("n", "z/", "<cmd>FzfLua live_grep<cr>", { desc = "Fzf Live Grep" })

-- z + hjkl: Window navigation
map("n", "zh", "<C-w>h", { desc = "Go to left window" })
map("n", "zj", "<C-w>j", { desc = "Go to lower window" })
map("n", "zk", "<C-w>k", { desc = "Go to upper window" })
map("n", "zl", "<C-w>l", { desc = "Go to right window" })

-- z + Shift-HJKL: Window resize → enters resize mode (see plugins/hydra.lua)

-- z + Ctrl-HJKL: Window swap (smart-splits)
map("n", "z<C-h>", function() require("smart-splits").swap_buf_left() end, { desc = "Swap window left" })
map("n", "z<C-j>", function() require("smart-splits").swap_buf_down() end, { desc = "Swap window down" })
map("n", "z<C-k>", function() require("smart-splits").swap_buf_up() end, { desc = "Swap window up" })
map("n", "z<C-l>", function() require("smart-splits").swap_buf_right() end, { desc = "Swap window right" })

-- z + v/s: Window split
map("n", "zv", "<C-w>v", { desc = "Split window vertically" })
map("n", "zs", "<C-w>s", { desc = "Split window horizontally" })

-- Diagnostics
map("n", "gl", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

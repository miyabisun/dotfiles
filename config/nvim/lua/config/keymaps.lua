-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- ze: Go back to explorer (Netrw)
map("n", "ze", "<cmd>Ex<cr>", { desc = "Go back to explorer" })

-- zp: Fzf Project Files
map("n", "zp", "<cmd>FzfLua files<cr>", { desc = "Fzf Project Files" })
-- z/: Grep → Quickfix (Full Text Search)
map("n", "z/", function()
  vim.ui.input({ prompt = "Grep: " }, function(pattern)
    if not pattern or pattern == "" then return end
    vim.cmd("silent grep! " .. vim.fn.shellescape(pattern))
    vim.cmd("botright copen")
  end)
end, { desc = "Grep → Quickfix" })

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

-- zt: Add current line to quickfix as a TODO, in a 5-line bottom window.
-- Theme picker moved off this key (still available as :Theme).
map("n", "zt", function()
  vim.fn.setqflist({ {
    filename = vim.api.nvim_buf_get_name(0),
    lnum = vim.api.nvim_win_get_cursor(0)[1],
    text = "TODO " .. vim.api.nvim_get_current_line(),
  } }, "a")
  vim.cmd("botright copen 5")
  vim.cmd("wincmd p")
end, { desc = "Add line to quickfix (TODO)" })

-- Quickfix window: dd removes the item under the cursor and rebuilds the list
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(ev)
    vim.keymap.set("n", "dd", function()
      -- filetype=qf is shared by quickfix and location-list windows
      local is_loclist = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].loclist == 1
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local items = is_loclist and vim.fn.getloclist(0) or vim.fn.getqflist()
      if #items == 0 then return end
      table.remove(items, row)
      if is_loclist then
        vim.fn.setloclist(0, items, "r")
      else
        vim.fn.setqflist(items, "r")
      end
      vim.api.nvim_win_set_cursor(0, { math.min(row, math.max(#items, 1)), 0 })
    end, { buffer = ev.buf, desc = "Remove quickfix/loclist item" })
  end,
})

-- Diagnostics
map("n", "gl", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

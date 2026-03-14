-- Set <space> as the leader key
-- See `:help mapleader`
-- NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.languages")
require("config.keymaps")
require("config.lazy")

-- Load persisted colorscheme
local scheme_file = vim.fn.stdpath("config") .. "/colorscheme.txt"
local f = io.open(scheme_file, "r")
if f then
  local scheme = f:read("*l")
  f:close()
  if scheme and #scheme > 0 then
    pcall(vim.cmd.colorscheme, scheme)
  end
end

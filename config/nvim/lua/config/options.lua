-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.opt.number = true          -- Print line number
vim.opt.relativenumber = false -- Disable relative line numbers
vim.opt.clipboard = ""           -- Do not sync with system clipboard
vim.opt.smartindent = true     -- Insert indents automatically
vim.opt.tabstop = 2            -- Number of spaces that a <Tab> in the file counts for
vim.opt.softtabstop = 2        -- Number of spaces that a <Tab> counts for while performing editing operations
vim.opt.shiftwidth = 2         -- Size of an indent
vim.opt.expandtab = true       -- Use spaces instead of tabs
vim.opt.ignorecase = true      -- Ignore case in search patterns
vim.opt.smartcase = true       -- Don't ignore case with capitals
vim.opt.termguicolors = true   -- True color support
vim.opt.scrolloff = 8          -- Min number of lines to keep above and below the cursor
vim.opt.signcolumn = "yes"     -- Always show the signcolumn
vim.opt.cursorline = true      -- Highlight the current line

-- Disable temporary files
vim.opt.swapfile = false       -- Disable swap file
vim.opt.backup = false         -- Disable backup file
vim.opt.undofile = false       -- Disable undo file (persistent undo)

-- Marker (Shada) configuration implies standard behavior,
-- but verifying shadafile is enabled (it is by default).
-- If specific marker behavior is needed, we can tune vim.opt.shada



-- Language specific configurations

-- Pre-compile regex objects to avoid memory leak (neovim/neovim#13013)
local civet_re = vim.regex([[^#!.*civet]])
local bb_re = vim.regex([[^#!.*\<bb\>]])

-- Civet filetype detection and syntax highlighting
vim.filetype.add({
  extension = {
    civet = "civet",
  },
  pattern = {
    [".*"] = {
      function(path, bufnr)
        local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
        if civet_re:match_str(content) then
          return "civet"
        end
        if bb_re:match_str(content) then
          return "clojure"
        end
      end,
    },
    [".*/git/config"] = "gitconfig", -- Detect git config files in XDG paths
  },
})

-- Force typescript syntax for civet filetype
vim.api.nvim_create_autocmd("FileType", {
  pattern = "civet",
  callback = function()
    vim.bo.syntax = "typescript"
  end,
})



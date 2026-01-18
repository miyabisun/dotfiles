-- Language specific configurations

-- Civet filetype detection and syntax highlighting
vim.filetype.add({
  extension = {
    civet = "civet",
  },
  pattern = {
    [".*"] = {
      function(path, bufnr)
        local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
        if vim.regex([[^#!.*civet]]):match_str(content) then
          return "civet"
        end
      end,
    },
  },
})

-- Force typescript syntax for civet filetype
vim.api.nvim_create_autocmd("FileType", {
  pattern = "civet",
  callback = function()
    vim.bo.syntax = "typescript"
  end,
})



return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local status, configs = pcall(require, "nvim-treesitter.configs")
      if not status then
        configs = require("nvim-treesitter.config")
      end

      configs.setup({
        ensure_installed = {
          "lua",
          "vim",
          "vimdoc",
          "query",
          "markdown",
          "markdown_inline",
          "clojure",
          "typescript", -- Add typescript parser
          "yaml",
          "javascript",
          "json",
        },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
      
      -- Register typescript parser for civet
      vim.treesitter.language.register("typescript", "civet")
    end,
  },
}

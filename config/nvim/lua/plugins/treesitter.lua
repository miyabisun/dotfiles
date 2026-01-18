return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local configs = require("nvim-treesitter.config")

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

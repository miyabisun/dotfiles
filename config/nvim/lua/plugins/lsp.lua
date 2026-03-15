return {
  {
    "neovim/nvim-lspconfig",
    lazy = false, -- Force load at startup (No event, no lazy)
    priority = 1000, -- Ensure it loads early
    dependencies = {
      {
        "williamboman/mason.nvim",
        config = function()
          require("mason").setup({
            ensure_installed = {
              "lua-language-server",
              "clojure-lsp",
              "yaml-language-server",
              "typescript-language-server",
              "json-lsp",
            },
          })
        end,
      },
    },
    config = function()
      -- Civet Configuration
      vim.lsp.config('civet', {
        cmd = { "node", vim.fn.stdpath("data") .. "/civet-ls/extension/dist/server.js", "--stdio" },
        filetypes = { "civet" },
        root_markers = { "package.json", ".git" },
      })
      vim.lsp.enable("civet")

      -- Lua LS
      vim.lsp.enable("lua_ls")

      -- Clojure LS
      vim.lsp.enable("clojure_lsp")

      -- YAML LS
      vim.lsp.enable("yamlls")

      -- TS/JS LS
      vim.lsp.enable("ts_ls")

      -- JSON LS
      vim.lsp.enable("jsonls")
    end,
  },
}

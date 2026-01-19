return {
  {
    "neovim/nvim-lspconfig",
    lazy = false, -- Force load at startup (No event, no lazy)
    priority = 1000, -- Ensure it loads early
    dependencies = {
      -- Mason (Package Manager)
      {
        "williamboman/mason.nvim",
        build = ":MasonUpdate",
        config = function()
          require("mason").setup()
        end,
      },
      -- Mason LSP Config (Installer Bridge)
      {
        "williamboman/mason-lspconfig.nvim",
        config = function()
          require("mason-lspconfig").setup({
            ensure_installed = { "lua_ls", "clojure_lsp", "yamlls", "ts_ls", "jsonls" },
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

return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "clojure_lsp" },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Civet Configuration
      -- Manually register the civet server config
      vim.lsp.config('civet', {
        cmd = { "node", "/home/miyabi/.local/share/nvim/civet-ls/extension/dist/server.js", "--stdio" },
        filetypes = { "civet" },
        root_markers = { "package.json", ".git" },
      })
      vim.lsp.enable("civet")

      -- Lua LS
      -- Enable lua_ls which is configured by default in nvim-lspconfig
      vim.lsp.enable("lua_ls")

      -- Clojure LS
      vim.lsp.enable("clojure_lsp")
    end,
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
  },
}

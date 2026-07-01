return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Pin to legacy `master` because `main` (v1.0 rewrite) breaks on Neovim 0.12+
    -- and the repo was archived 2026-04, so upstream HEAD won't be fixed.
    branch = "master",
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
          "clojure",
          "typescript", -- Add typescript parser
          "yaml",
          "javascript",
          "json",
        },
        sync_install = false,
        -- Disable markdown highlighting: the frozen master branch's injection
        -- query hits a Neovim 0.12 API break (node:range on nil).
        -- Fall back to vim's regex syntax for markdown; other languages keep TS.
        highlight = {
          enable = true,
          disable = { "markdown", "markdown_inline" },
          additional_vim_regex_highlighting = { "markdown" },
        },
        indent = {
          enable = true,
          disable = { "markdown", "markdown_inline" },
        },
      })

      -- Register typescript parser for civet
      vim.treesitter.language.register("typescript", "civet")

      -- Fully detach treesitter for markdown buffers. `highlight.disable` alone
      -- is not enough: parse still runs for indent/injections/folds and
      -- crashes on Neovim 0.12 with the frozen master branch.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown" },
        callback = function(args)
          pcall(vim.treesitter.stop, args.buf)
        end,
      })
    end,
  },
}

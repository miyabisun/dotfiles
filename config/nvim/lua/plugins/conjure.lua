return {
  {
    "Olical/conjure",
    ft = { "clojure", "fennel" },
    dependencies = {
      -- S-expression editing (paredit alternative, Lua native)
      {
        "julienvincent/nvim-paredit",
        ft = { "clojure", "fennel" },
        config = function()
          require("nvim-paredit").setup()
        end,
      },
    },
    init = function()
      -- Disable unused clients to avoid noise on non-Clojure files
      vim.g["conjure#filetypes"] = { "clojure", "fennel" }

      -- HUD (floating result window)
      vim.g["conjure#log#hud#width"] = 0.6
      vim.g["conjure#log#hud#anchor"] = "SE"
    end,
  },
}

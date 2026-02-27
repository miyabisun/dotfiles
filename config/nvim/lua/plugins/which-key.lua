return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        plugins = {
          presets = {
            z = false, -- Disable built-in z descriptions
          },
        },
      })
    end,
  },
}

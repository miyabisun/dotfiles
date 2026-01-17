return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      options = {
        icons_enabled = false, -- Disable icons for now to match fzf settings and avoid errors
        theme = "auto",
        component_separators = { left = "|", right = "|" },
        section_separators = { left = "", right = "" },
      },
    })
  end,
}

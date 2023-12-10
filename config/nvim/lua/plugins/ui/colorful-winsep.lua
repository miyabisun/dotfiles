return {
  "nvim-zh/colorful-winsep.nvim",
  config = true,
  event = { "WinNew" },
  config = function()
    require("colorful-winsep").setup({
      highlight = {
        bg = "",
        fg = "#E8AEAA",
      }
    })
  end
}

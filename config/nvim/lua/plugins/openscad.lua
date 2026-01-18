return {
  {
    "salkin-mada/openscad.nvim",
    config = function()
      vim.g.openscad_load_snippets = true
    end,
    dependencies = {
      "L3MON4D3/LuaSnip"
    },
  },
}

return {
  "nathom/filetype.nvim",
  config = function()
    require("filetype").setup({
      overrides = {
        shebang = {
          bb = "clojure",
        },
      },
    })
  end
}

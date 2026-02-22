return {
  "nvimtools/hydra.nvim",
  dependencies = { "mrjones2014/smart-splits.nvim" },
  config = function()
    local Hydra = require("hydra")
    local ss = require("smart-splits")

    Hydra({
      name = "Resize",
      mode = "n",
      body = "z",
      config = {
        timeout = 3000,
      },
      heads = {
        { "H", function() ss.resize_left(5) end, { desc = "Resize left" } },
        { "J", function() ss.resize_down(3) end, { desc = "Resize down" } },
        { "K", function() ss.resize_up(3) end, { desc = "Resize up" } },
        { "L", function() ss.resize_right(5) end, { desc = "Resize right" } },
        { "<Esc>", nil, { exit = true, desc = false } },
      },
    })
  end,
}

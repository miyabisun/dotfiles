return {
  -- gitsigns: inline git status signs + hunk operations
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local gs = require("gitsigns")
      gs.setup({
        current_line_blame = false, -- toggle with keymap
      })

      local map = vim.keymap.set

      -- Navigation between hunks
      map("n", "]h", gs.next_hunk, { desc = "Next git hunk" })
      map("n", "[h", gs.prev_hunk, { desc = "Prev git hunk" })

      -- Blame
      map("n", "gb", gs.blame_line, { desc = "Git blame line" })
      map("n", "gB", gs.toggle_current_line_blame, { desc = "Toggle inline blame" })

      -- Hunk operations
      map("n", "ghs", gs.stage_hunk, { desc = "Stage hunk" })
      map("n", "ghr", gs.reset_hunk, { desc = "Reset hunk" })
      map("n", "ghp", gs.preview_hunk, { desc = "Preview hunk" })
    end,
  },

  -- fugitive: Git commands (:Git blame, :Git log, etc.)
  {
    "tpope/vim-fugitive",
  },

  -- diffview: rich diff viewer & merge conflict resolution
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: open" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: branch history" },
    },
    config = function()
      require("diffview").setup({
        use_icons = false,
      })
    end,
  },
}

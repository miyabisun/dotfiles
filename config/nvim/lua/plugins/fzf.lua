return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    -- calling `setup` is optional for customization
    local fzf = require("fzf-lua")
    -- Disable icons for now to fix the crash
    fzf.setup({
      defaults = {
        file_icons = false,
        git_icons = false,
      },
    })

    -- Keymaps
    local map = vim.keymap.set

    -- Ctrl+p to search files
    map("n", "<C-p>", fzf.files, { desc = "Fzf Files" })

    -- Other useful fzf mappings (optional but recommended)
    map("n", "<leader>sg", fzf.live_grep, { desc = "[S]earch by [G]rep" })
    map("n", "<leader>sb", fzf.buffers, { desc = "[S]earch [B]uffers" })
    map("n", "<leader>sh", fzf.help_tags, { desc = "[S]earch [H]elp" })
  end,
}

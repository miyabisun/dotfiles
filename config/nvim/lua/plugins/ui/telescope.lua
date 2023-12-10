return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  dependencies = {'nvim-lua/plenary.nvim'},
  config = function()
    vim.keymap.set("n", "<C-p>", ":Telescope find_files hidden=true<CR>", {noremap = true, silent = true})
  end
}

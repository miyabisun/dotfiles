return {
  "mrjones2014/smart-splits.nvim",
  version = ">=1.0.0",
  opts = {
    log_level = "error",
  },
  -- Workaround: tmux_exec() doesn't return exit codes from utils.system(),
  -- causing on_init to always warn "failed to detect pane_id".
  -- Manually set @pane-is-vim and skip the buggy on_init.
  init = function()
    local pane_id = os.getenv("TMUX_PANE")
    if pane_id then
      vim.fn.system({ "tmux", "set-option", "-pt", pane_id, "@pane-is-vim", "1" })
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          vim.fn.system({ "tmux", "set-option", "-pt", pane_id, "@pane-is-vim", "0" })
        end,
      })
    end
  end,
  config = function(_, opts)
    -- Prevent the default startup from running on_init
    opts.multiplexer_integration = false
    require("smart-splits").setup(opts)
  end,
}

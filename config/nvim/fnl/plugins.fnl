(local install-path
  (.. (vim.fn.stdpath "data")
      "/site/pack/packer/start/packer.nvim"))

(when (> (vim.fn.empty (vim.fn.glob install-path)) 0)
  (->> ["git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install-path]
       vim.fn.system
       (global PACKER_BOOTSTRAP))
  (print "Installing packer close and reopen Neovim...")
  (vim.cmd "packadd packer.nvim"))

(vim.cmd (.. "augroup packer_user_config\n"
             "  autocmd!\n"
             "  autocmd BufWritePost plugins.lua source <afile> | PackerSync\n"
             "augroup end"))

(local (status-ok, packer) (pcall require "packer"))
(when status-ok
  (packer.init {:display
                {:open_fn
                 (fn []
                   ((. (require "packer.util") :float {:border "rounded"})))}})
  (let [options
        [{"wbthomason/packer.nvim"}
         {"nvim-lua/plenary.nvim"}]]
    (packer.startup (fn [use]
                      ))))

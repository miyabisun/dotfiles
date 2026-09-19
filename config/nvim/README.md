# Neovim bookmark spaces

[tabspaces.nvim v0.1.2](https://github.com/miyabisun/tabspaces.nvim/releases/tag/v0.1.2)
groups live tabs by directory. Neovim 0.10+, fzf-lua and `fzf` are required.
The installer links this configuration.
Lazy.nvim installs the public tag on the next Neovim startup.

Press **z then q in normal mode** to name and bookmark the current directory.
Leave the name empty and press Enter to use the directory's basename.
Press Esc to cancel. `:TabspacesAdd Name` also remains available.
For any other directory, including non-Git locations:

```vim
:lua require('tabspaces').add('Shared data', '~/.local/share')
```

Press **Ctrl+n twice in normal mode** to search by bookmark name and switch.
Paths and tab counts are displayed but are not searched.
Live spaces appear first with their tab counts. `:tabe` adds a tab to the space.
`gt` / `gT` wrap through its tabs; `g1`–`g9` select its visible tab numbers.
Absent numbers do nothing. Switching back restores the last selected live tab.
Existing `ze`, `zp` and split bindings remain available; `zp` uses the space cwd.
Insert-mode Ctrl+n keeps its completion behavior.

`:TabspacesRemove` removes the current bookmark without closing its tabs.
Starting Neovim in a bookmarked directory assigns its initial tabs to that space.
Startup files are preserved. Unregistered directories remain Unassigned;
parent directories are not searched. Native `:tabnext` still reaches all tabs.
`:qa` keeps normal unsaved warnings. Restarting starts fresh tabs and buffers.
Only bookmark names and paths persist under Neovim's data directory, outside Git.
See the plugin README or `:help tabspaces` for the full API and limitations.


Return to the [installation overview](../../README.md).

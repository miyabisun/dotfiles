vim.opt.rtp:prepend(vim.fn.getcwd() .. '/config/nvim')
local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch .. '/task-server', 'p')
local added, answer, requested
package.preload.tabspaces = function()
  return { add = function(name, path) added = { name, path } end }
end
vim.ui.input = function(_, callback)
  requested = true
  callback(answer)
end
local function check()
  require('config.keymaps')
  vim.cmd.tcd(scratch .. '/task-server')
  local cwd = vim.fn.getcwd()
  local function submit(value)
    added, requested, answer = nil, false, value
    vim.cmd('normal zq')
    assert(requested, 'zq must request a bookmark name')
  end
  submit('My project')
  assert(vim.deep_equal(added, { 'My project', cwd }))
  submit('')
  assert(vim.deep_equal(added, { 'task-server', cwd }))
  submit(nil)
  assert(added == nil, 'Cancelling must not register a bookmark')
end
local ok, err = xpcall(check, debug.traceback)
vim.fn.delete(scratch, 'rf')
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
print('bookmark shortcut checks passed')
vim.cmd('qa!')

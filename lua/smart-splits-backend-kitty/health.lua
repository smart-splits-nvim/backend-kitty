local config = require('smart-splits-backend-kitty.config')
local kitty = require('smart-splits-backend-kitty.kitty')

local M = {}

function M.report()
  local version = kitty.version()
  if version then
    vim.health.ok('Found ' .. version)
  end

  if not config.options.enable then
    vim.health.warn('Backend is disabled by configuration')
  end

  if kitty.is_running() then
    vim.health.ok('KITTY_LISTEN_ON=' .. vim.env.KITTY_LISTEN_ON)
  else
    vim.health.error('Not in a kitty session. Set allow_remote_control and listen_on so KITTY_LISTEN_ON is present.')
  end

  if config.password() ~= '' then
    vim.health.ok('Remote control password is configured')
  end

  if not kitty.usable() then
    return
  end

  local ok, window = pcall(kitty.active_window)
  if not ok then
    vim.health.error('kitty socket ls failed: ' .. tostring(window))
  elseif window then
    vim.health.ok(('Focused kitty window id %s (%sx%s)'):format(window.id, window.columns or '?', window.lines or '?'))
  else
    vim.health.warn('Could not find the focused kitty window')
  end
end

function M.check()
  vim.health.start('smart-splits-backend-kitty')
  M.report()
end

return M

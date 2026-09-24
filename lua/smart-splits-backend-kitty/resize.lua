local config = require('smart-splits-backend-kitty.config')
local kitty = require('smart-splits-backend-kitty.kitty')
local layout = require('smart-splits-backend-kitty.layout')

local M = {}

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendResizeOpts
---@return boolean
local function handle_resize(direction, opts)
  if not kitty.usable() then
    return false
  end

  opts = opts or {}
  local amount = tonumber(opts.amount) or 1
  local ctx = kitty.active_context()
  if not ctx then
    return false
  end

  if config.options.zoom.block_nav and ctx.tab.layout == 'stack' then
    return false
  end

  if not ctx.window.neighbors then
    return false
  end

  local axis, increment = layout.resize_increment(ctx.window, direction, amount)
  if not axis or not increment then
    return false
  end
  return kitty.resize_window(axis, increment)
end

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendResizeOpts
---@return boolean
function M.resize(direction, opts)
  local ok, result = pcall(handle_resize, direction, opts)
  if not ok then
    vim.notify('[smart-splits-backend-kitty] ' .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  return result == true
end

return M

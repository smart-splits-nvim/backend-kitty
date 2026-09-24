local config = require('smart-splits-backend-kitty.config')
local kitty = require('smart-splits-backend-kitty.kitty')
local layout = require('smart-splits-backend-kitty.layout')

local M = {}

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendMoveOpts
---@return boolean
local function handle_move(direction, opts)
  if not kitty.usable() then
    return false
  end

  opts = opts or {}
  local at_edge = opts.at_edge or 'stop'

  local ctx = kitty.active_context()
  if not ctx then
    return false
  end

  if config.options.zoom.block_nav and ctx.tab.layout == 'stack' then
    return false
  end

  local neighbors = layout.neighbor_ids(ctx.window, direction)
  if neighbors == nil then
    return kitty.neighboring_window(direction)
  end
  if #neighbors > 0 then
    return kitty.neighboring_window(direction)
  end

  if at_edge == 'wrap' then
    local target = layout.wrap_target(ctx.windows, ctx.window, direction)
    if not target then
      return false
    end
    return kitty.focus_window(target)
  end

  if at_edge == 'split' then
    if config.options.split[direction] == false then
      return false
    end
    return kitty.split(direction)
  end

  return false
end

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendMoveOpts
---@return boolean
function M.move(direction, opts)
  local ok, result = pcall(handle_move, direction, opts)
  if not ok then
    vim.notify('[smart-splits-backend-kitty] ' .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  return result == true
end

return M

---@module 'smart-splits.backend'

local mock_mux = require('smart-splits-backend-template.mock_mux')

local M = {}

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendMoveOpts
---@return boolean
function M.move(direction, opts)
  if not mock_mux.is_enabled() then
    return false
  end

  opts = opts or {}
  local at_edge = opts.at_edge or 'stop'

  if mock_mux.has_neighbor(direction) then
    return mock_mux.move(direction)
  end

  if at_edge == 'wrap' then
    return mock_mux.wrap(direction)
  elseif at_edge == 'split' then
    return mock_mux.split(direction)
  end

  return false
end

return M

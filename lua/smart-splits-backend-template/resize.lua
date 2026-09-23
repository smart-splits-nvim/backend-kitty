---@module 'smart-splits.backend'

local mock_mux = require('smart-splits-backend-template.mock_mux')

local M = {}

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendResizeOpts
---@return boolean
function M.resize(direction, opts)
  if not mock_mux.is_enabled() then
    return false
  end

  opts = opts or {}
  local amount = opts.amount or 1

  return mock_mux.resize(direction, amount)
end

return M

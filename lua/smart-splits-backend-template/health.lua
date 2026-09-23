local mock_mux = require('smart-splits-backend-template.mock_mux')

local M = {}

function M.report()
  if mock_mux.is_enabled() then
    vim.health.ok('Mock multiplexer is enabled')
    local current = mock_mux.get_current_pane()
    if current then
      vim.health.ok(string.format('Current pane: %d at (%d, %d)', current.id, current.x, current.y))
    else
      vim.health.warn('No current pane found')
    end
  else
    vim.health.error('Mock multiplexer is disabled')
  end
end

---@return nil
function M.check()
  vim.health.start('backend-template')
  M.report()
end

return M

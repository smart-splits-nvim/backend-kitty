local M = {}

function M.reset_backend()
  local mock_mux = require('smart-splits-backend-template.mock_mux')
  mock_mux.reset()
  local config = require('smart-splits-backend-template.config')
  config.setup()
end

function M.disable_backend()
  local mock_mux = require('smart-splits-backend-template.mock_mux')
  mock_mux.set_enabled(false)
end

function M.enable_backend()
  local mock_mux = require('smart-splits-backend-template.mock_mux')
  mock_mux.set_enabled(true)
end

return M

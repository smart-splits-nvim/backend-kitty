---@module 'smart-splits.backend'

local config = require('smart-splits-backend-template.config')
local health = require('smart-splits-backend-template.health')
local mock_mux = require('smart-splits-backend-template.mock_mux')
local move = require('smart-splits-backend-template.move')
local resize = require('smart-splits-backend-template.resize')

---@type SmartSplitsBackend
local M = {
  name = 'smart-splits-backend-template',
  protocol_version = '3.0.0',
  setup = function(opts)
    config.setup(opts)
  end,
  detect = function()
    return config.options.enable and mock_mux.is_enabled()
  end,
  move = move.move,
  resize = resize.resize,
  health = health.report,
}

return M

---@module 'smart-splits.backend'

local config = require('smart-splits-backend-kitty.config')
local health = require('smart-splits-backend-kitty.health')
local kitty = require('smart-splits-backend-kitty.kitty')
local move = require('smart-splits-backend-kitty.move')
local resize = require('smart-splits-backend-kitty.resize')

---@type SmartSplitsBackend
local M = {
  name = 'smart-splits-backend-kitty',
  protocol_version = '3.0.0',
  setup = function(opts)
    config.setup(opts)
  end,
  detect = function()
    return kitty.usable()
  end,
  move = move.move,
  resize = resize.resize,
  activate = kitty.activate,
  health = health.report,
}

return M

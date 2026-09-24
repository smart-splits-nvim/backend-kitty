local M = {}

function M.reset_backend()
  vim.env.KITTY_LISTEN_ON = 'unix:/tmp/kitty-smart-splits-test'
  local kitty = require('smart-splits-backend-kitty.kitty')
  local fake = require('tests.fake_kitty')
  fake.reset()
  kitty.request = fake.request
  require('smart-splits-backend-kitty.config').setup()
end

function M.disable_backend()
  vim.env.KITTY_LISTEN_ON = nil
end

return M

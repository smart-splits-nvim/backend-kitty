local h = require('tests.helpers')

describe('backend protocol conformance', function()
  before_each(function()
    h.reset_backend()
  end)

  it('implements the v3 backend protocol', function()
    local backend = require('smart-splits-backend-template')
    local protocol_tests = require('smart-splits.protocol_tests')
    for _, test in ipairs(protocol_tests.tests(backend)) do
      local result = test.fn()
      assert.is_true(result, test.name .. ': ' .. tostring(result))
    end
  end)
end)

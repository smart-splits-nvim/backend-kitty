local h = require('tests.helpers')

describe('detect()', function()
  before_each(function()
    h.reset_backend()
  end)

  it('returns true when backend is enabled', function()
    local backend = require('smart-splits-backend-kitty')
    assert.is_true(backend.detect())
  end)

  it('returns false when backend is disabled', function()
    local backend = require('smart-splits-backend-kitty')
    backend.setup({ enable = false })
    assert.is_false(backend.detect())
  end)

  it('returns false when kitty remote control is unavailable', function()
    local backend = require('smart-splits-backend-kitty')
    h.disable_backend()
    assert.is_false(backend.detect())
  end)
end)

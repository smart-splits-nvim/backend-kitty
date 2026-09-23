local h = require('tests.helpers')

describe('detect()', function()
  before_each(function()
    h.reset_backend()
  end)

  it('returns true when backend is enabled', function()
    local backend = require('smart-splits-backend-template')
    assert.is_true(backend.detect())
  end)

  it('returns false when backend is disabled', function()
    local backend = require('smart-splits-backend-template')
    backend.setup({ enable = false })
    assert.is_false(backend.detect())
  end)

  it('returns false when mock multiplexer is disabled', function()
    local backend = require('smart-splits-backend-template')
    h.disable_backend()
    assert.is_false(backend.detect())
  end)
end)

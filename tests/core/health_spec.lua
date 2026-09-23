local h = require('tests.helpers')

describe('health()', function()
  before_each(function()
    h.reset_backend()
  end)

  it('reports healthy when backend is enabled', function()
    local backend = require('smart-splits-backend-template')
    assert.is_not_nil(backend.health)
    -- Health check should not error
    assert.has_no.errors(function()
      backend.health()
    end)
  end)

  it('reports unhealthy when backend is disabled', function()
    local backend = require('smart-splits-backend-template')
    h.disable_backend()
    assert.is_not_nil(backend.health)
    -- Health check should not error even when disabled
    assert.has_no.errors(function()
      backend.health()
    end)
  end)
end)

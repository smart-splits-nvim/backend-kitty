local h = require('tests.helpers')

describe('resize()', function()
  before_each(function()
    h.reset_backend()
  end)

  it('resizes right', function()
    local backend = require('smart-splits-backend-template')
    local mock_mux = require('smart-splits-backend-template.mock_mux')
    local initial_width = mock_mux.get_current_pane().width
    assert.is_true(backend.resize('right', { amount = 5 }))
    assert.are.equal(initial_width + 5, mock_mux.get_current_pane().width)
  end)

  it('resizes left', function()
    local backend = require('smart-splits-backend-template')
    local mock_mux = require('smart-splits-backend-template.mock_mux')
    local initial_width = mock_mux.get_current_pane().width
    assert.is_true(backend.resize('left', { amount = 5 }))
    assert.are.equal(initial_width - 5, mock_mux.get_current_pane().width)
  end)

  it('resizes down', function()
    local backend = require('smart-splits-backend-template')
    local mock_mux = require('smart-splits-backend-template.mock_mux')
    local initial_height = mock_mux.get_current_pane().height
    assert.is_true(backend.resize('down', { amount = 3 }))
    assert.are.equal(initial_height + 3, mock_mux.get_current_pane().height)
  end)

  it('resizes up', function()
    local backend = require('smart-splits-backend-template')
    local mock_mux = require('smart-splits-backend-template.mock_mux')
    local initial_height = mock_mux.get_current_pane().height
    assert.is_true(backend.resize('up', { amount = 3 }))
    assert.are.equal(initial_height - 3, mock_mux.get_current_pane().height)
  end)

  it('uses default amount of 1 when not specified', function()
    local backend = require('smart-splits-backend-template')
    local mock_mux = require('smart-splits-backend-template.mock_mux')
    local initial_width = mock_mux.get_current_pane().width
    assert.is_true(backend.resize('right'))
    assert.are.equal(initial_width + 1, mock_mux.get_current_pane().width)
  end)

  it('returns false when backend is disabled', function()
    local backend = require('smart-splits-backend-template')
    h.disable_backend()
    assert.is_false(backend.resize('right'))
  end)
end)

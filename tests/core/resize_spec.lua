local h = require('tests.helpers')

describe('resize()', function()
  before_each(function()
    h.reset_backend()
  end)

  it('resizes right', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    local initial_width = fake.get_current_pane().width
    assert.is_true(backend.resize('right', { amount = 5 }))
    assert.are.equal(initial_width + 5, fake.get_current_pane().width)
  end)

  it('resizes left', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    local initial_width = fake.get_current_pane().width
    assert.is_true(backend.resize('left', { amount = 5 }))
    assert.are.equal(initial_width - 5, fake.get_current_pane().width)
  end)

  it('resizes down', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    local initial_height = fake.get_current_pane().height
    assert.is_true(backend.resize('down', { amount = 3 }))
    assert.are.equal(initial_height + 3, fake.get_current_pane().height)
  end)

  it('resizes up', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    local initial_height = fake.get_current_pane().height
    assert.is_true(backend.resize('up', { amount = 3 }))
    assert.are.equal(initial_height - 3, fake.get_current_pane().height)
  end)

  it('grows a right-edge pane when resizing left', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    assert.is_true(backend.move('right'))
    local initial_width = fake.get_current_pane().width
    assert.is_true(backend.resize('left', { amount = 4 }))
    assert.are.equal(initial_width + 4, fake.get_current_pane().width)
  end)

  it('uses default amount of 1 when not specified', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    local initial_width = fake.get_current_pane().width
    assert.is_true(backend.resize('right'))
    assert.are.equal(initial_width + 1, fake.get_current_pane().width)
  end)

  it('returns false when backend is disabled', function()
    local backend = require('smart-splits-backend-kitty')
    h.disable_backend()
    assert.is_false(backend.resize('right'))
  end)
end)

local h = require('tests.helpers')

describe('move()', function()
  before_each(function()
    h.reset_backend()
  end)

  it('moves right to adjacent pane', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    assert.are.equal(0, fake.get_state().current_pane_id)
    assert.is_true(backend.move('right'))
    assert.are.equal(1, fake.get_state().current_pane_id)
  end)

  it('moves left to adjacent pane', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    backend.move('right')
    assert.is_true(backend.move('left'))
    assert.are.equal(0, fake.get_state().current_pane_id)
  end)

  it('moves down to adjacent pane', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    assert.is_true(backend.move('down'))
    assert.are.equal(2, fake.get_state().current_pane_id)
  end)

  it('moves up to adjacent pane', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    backend.move('down')
    assert.is_true(backend.move('up'))
    assert.are.equal(0, fake.get_state().current_pane_id)
  end)

  it('returns false at edge with at_edge=stop', function()
    local backend = require('smart-splits-backend-kitty')
    assert.is_false(backend.move('left', { at_edge = 'stop' }))
  end)

  it('wraps at edge with at_edge=wrap', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    assert.is_true(backend.move('left', { at_edge = 'wrap' }))
    assert.are.equal(1, fake.get_state().current_pane_id)
  end)

  it('wraps to the far pane across a row', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.use_horizontal_row()
    assert.is_true(backend.move('left', { at_edge = 'wrap' }))
    assert.are.equal(2, fake.get_state().current_pane_id)
  end)

  it('wraps a full-height pane onto the middle of the stack beside it', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.use_tall_layout()
    assert.is_true(backend.move('left', { at_edge = 'wrap' }))
    assert.are.equal(5, fake.get_state().current_pane_id)
  end)

  it('wraps the top of a stack to the bottom', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.use_tall_layout()
    fake.focus(4)
    assert.is_true(backend.move('up', { at_edge = 'wrap' }))
    assert.are.equal(6, fake.get_state().current_pane_id)
  end)

  it('does not wrap a full-height pane up or down when nothing sits above or below it', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.use_tall_layout()
    assert.is_false(backend.move('up', { at_edge = 'wrap' }))
    assert.is_false(backend.move('down', { at_edge = 'wrap' }))
    assert.are.equal(2, fake.get_state().current_pane_id)
  end)

  it('wraps the right stack back to the full-height pane', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.use_tall_layout()
    fake.focus(4)
    assert.is_true(backend.move('right', { at_edge = 'wrap' }))
    assert.are.equal(2, fake.get_state().current_pane_id)
  end)

  it('splits at edge with at_edge=split', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    local initial_count = #fake.get_state().panes
    assert.is_true(backend.move('left', { at_edge = 'split' }))
    assert.are.equal(initial_count + 1, #fake.get_state().panes)
  end)

  it('splits a tall layout by switching to splits and placing the window on that side', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.use_tall_layout()
    assert.is_true(backend.move('left', { at_edge = 'split' }))

    local saw_layout, saw_launch, saw_move = false, false, false
    for _, command in ipairs(fake.commands()) do
      if command.cmd == 'goto-layout' and command.payload.layout == 'splits' then
        saw_layout = true
      elseif command.cmd == 'launch' and command.payload.location == 'vsplit' then
        saw_launch = true
      elseif command.cmd == 'action' and command.payload.action == 'move_window left' then
        saw_move = true
      end
    end
    assert.is_true(saw_layout)
    assert.is_true(saw_launch)
    assert.is_true(saw_move)
  end)

  it('returns false when split is disabled for that direction', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    backend.setup({ split = { left = false } })
    local initial_count = #fake.get_state().panes
    assert.is_false(backend.move('left', { at_edge = 'split' }))
    assert.are.equal(initial_count, #fake.get_state().panes)
  end)

  it('returns false when the tab is zoomed and block_nav is set', function()
    local backend = require('smart-splits-backend-kitty')
    local fake = require('tests.fake_kitty')
    fake.set_layout('stack')
    backend.setup({ zoom = { block_nav = true } })
    assert.is_false(backend.move('right'))
    assert.are.equal(0, fake.get_state().current_pane_id)
  end)

  it('returns false when backend is disabled', function()
    local backend = require('smart-splits-backend-kitty')
    h.disable_backend()
    assert.is_false(backend.move('right'))
  end)
end)

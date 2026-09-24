---Stand-in for Kitty's remote-control socket so tests can exercise move/resize without a terminal.
local M = {}

local state = {}

local function window(id, columns, lines, neighbors, focused)
  return {
    id = id,
    columns = columns,
    lines = lines,
    neighbors = neighbors,
    is_focused = focused,
    is_active = focused,
  }
end

local function initial_windows()
  return {
    window(0, 40, 12, { right = { 1 }, bottom = { 2 } }, true),
    window(1, 40, 12, { left = { 0 }, bottom = { 3 } }, false),
    window(2, 40, 12, { top = { 0 }, right = { 3 } }, false),
    window(3, 40, 12, { left = { 2 }, top = { 1 } }, false),
  }
end

function M.reset()
  state.windows = initial_windows()
  state.layout = 'splits'
  state.commands = {}
end

---The live tall tab: one full-height window on the left, three stacked on the right.
function M.use_tall_layout()
  state.layout = 'tall'
  state.windows = {
    window(2, 125, 42, { right = { 4, 5, 6 } }, true),
    window(4, 125, 13, { left = { 2 }, bottom = { 5 } }, false),
    window(5, 125, 13, { left = { 2 }, top = { 4 }, bottom = { 6 } }, false),
    window(6, 125, 14, { left = { 2 }, top = { 5 } }, false),
  }
end

function M.commands()
  return state.commands
end

function M.use_horizontal_row()
  state.layout = 'splits'
  state.windows = {
    window(0, 20, 20, { right = { 1 } }, true),
    window(1, 20, 20, { left = { 0 }, right = { 2 } }, false),
    window(2, 20, 20, { left = { 1 } }, false),
  }
end

---@param layout string
function M.set_layout(layout)
  state.layout = layout
end

local function focused()
  for _, win in ipairs(state.windows) do
    if win.is_focused then
      return win
    end
  end
  return nil
end

local function focus(id)
  local found = false
  for _, win in ipairs(state.windows) do
    local on = win.id == id
    win.is_focused = on
    win.is_active = on
    found = found or on
  end
  return found
end

function M.focus(id)
  return focus(id)
end

local function ls()
  return {
    {
      id = 1,
      is_active = true,
      is_focused = true,
      tabs = {
        {
          id = 1,
          is_active = true,
          is_focused = true,
          layout = state.layout,
          windows = state.windows,
        },
      },
    },
  }
end

local NEIGHBOR = { left = 'left', right = 'right', up = 'top', down = 'bottom' }
local OPPOSITE = { left = 'right', right = 'left', top = 'bottom', bottom = 'top' }

local function launch(payload)
  local current = focused()
  if not current then
    return false
  end
  local location = payload and payload.location
  local direction = location == 'hsplit' and 'down' or 'right'
  local new_id = 0
  for _, win in ipairs(state.windows) do
    if win.id >= new_id then
      new_id = win.id + 1
    end
  end
  local key = NEIGHBOR[direction]
  local created = window(new_id, current.columns, current.lines, {}, true)
  current.neighbors[key] = current.neighbors[key] or {}
  table.insert(current.neighbors[key], new_id)
  created.neighbors[OPPOSITE[key]] = { current.id }
  current.is_focused = false
  current.is_active = false
  table.insert(state.windows, created)
  return new_id
end

---Stand-in for `kitty.request`. Returns decoded command data, or `true` when kitty would not reply.
---@param cmd string
---@param payload? table
---@return any
function M.request(cmd, payload)
  payload = payload or {}
  table.insert(state.commands, { cmd = cmd, payload = payload })
  if cmd == 'ls' then
    return ls()
  end
  if cmd == 'goto-layout' then
    state.layout = payload.layout or state.layout
    return true
  end
  if cmd == 'focus-window' then
    local id = tonumber((payload.match or ''):match('^id:(%-?%d+)$'))
    if id and focus(id) then
      return true
    end
    return false
  end
  if cmd == 'resize-window' then
    local current = focused()
    if not current then
      return false
    end
    local increment = tonumber(payload.increment) or 0
    if payload.axis == 'horizontal' then
      current.columns = current.columns + increment
    elseif payload.axis == 'vertical' then
      current.lines = current.lines + increment
    else
      return false
    end
    return true
  end
  if cmd == 'launch' then
    return launch(payload)
  end
  if cmd == 'action' then
    local action, arg = (payload.action or ''):match('^(%S+)%s*(.*)$')
    if action == 'neighboring_window' then
      local current = focused()
      local ids = current and current.neighbors[arg] or nil
      if not ids or #ids == 0 then
        return false
      end
      focus(ids[1])
      return true
    end
    if action == 'move_window' then
      return true
    end
  end
  return false
end

function M.get_current_pane()
  local current = focused()
  if not current then
    return nil
  end
  return {
    id = current.id,
    width = current.columns,
    height = current.lines,
  }
end

function M.get_state()
  local current = focused()
  return {
    current_pane_id = current and current.id or nil,
    panes = state.windows,
  }
end

M.reset()

return M

---@class TemplateBackend.MockPane
---@field id integer
---@field x integer
---@field y integer
---@field width integer
---@field height integer

---@class TemplateBackend.MockMux
---@field panes TemplateBackend.MockPane[]
---@field current_pane_id integer
---@field enabled boolean

local M = {}

---@type TemplateBackend.MockMux
local state = {
  panes = {
    { id = 0, x = 0, y = 0, width = 40, height = 12 },
    { id = 1, x = 40, y = 0, width = 40, height = 12 },
    { id = 2, x = 0, y = 12, width = 40, height = 12 },
    { id = 3, x = 40, y = 12, width = 40, height = 12 },
  },
  current_pane_id = 0,
  enabled = true,
}

function M.reset()
  state.panes = {
    { id = 0, x = 0, y = 0, width = 40, height = 12 },
    { id = 1, x = 40, y = 0, width = 40, height = 12 },
    { id = 2, x = 0, y = 12, width = 40, height = 12 },
    { id = 3, x = 40, y = 12, width = 40, height = 12 },
  }
  state.current_pane_id = 0
  state.enabled = true
end

---@return TemplateBackend.MockMux
function M.get_state()
  return state
end

---@param enabled boolean
function M.set_enabled(enabled)
  state.enabled = enabled
end

---@return boolean
function M.is_enabled()
  return state.enabled
end

---@return TemplateBackend.MockPane|nil
function M.get_current_pane()
  for _, pane in ipairs(state.panes) do
    if pane.id == state.current_pane_id then
      return pane
    end
  end
  return nil
end

---@param id integer
---@return TemplateBackend.MockPane|nil
function M.get_pane_by_id(id)
  for _, pane in ipairs(state.panes) do
    if pane.id == id then
      return pane
    end
  end
  return nil
end

---@param a_start integer
---@param a_length integer
---@param b_start integer
---@param b_length integer
---@return boolean
local function intervals_overlap(a_start, a_length, b_start, b_length)
  return a_start < b_start + b_length and b_start < a_start + a_length
end

---@param direction SmartSplitsDirection
---@return boolean
function M.has_neighbor(direction)
  local current = M.get_current_pane()
  if not current then
    return false
  end

  for _, target in ipairs(state.panes) do
    if target.id ~= current.id then
      local in_direction = false
      local is_aligned = false

      if direction == 'left' then
        in_direction = current.x > target.x
        is_aligned = intervals_overlap(current.y, current.height, target.y, target.height)
      elseif direction == 'right' then
        in_direction = target.x > current.x
        is_aligned = intervals_overlap(current.y, current.height, target.y, target.height)
      elseif direction == 'up' then
        in_direction = current.y > target.y
        is_aligned = intervals_overlap(current.x, current.width, target.x, target.width)
      elseif direction == 'down' then
        in_direction = target.y > current.y
        is_aligned = intervals_overlap(current.x, current.width, target.x, target.width)
      end

      if in_direction and is_aligned then
        return true
      end
    end
  end

  return false
end

---@param direction SmartSplitsDirection
---@return boolean
function M.move(direction)
  if not state.enabled then
    return false
  end

  local current = M.get_current_pane()
  if not current then
    return false
  end

  for _, target in ipairs(state.panes) do
    if target.id ~= current.id then
      local in_direction = false
      local is_aligned = false

      if direction == 'left' then
        in_direction = current.x > target.x
        is_aligned = intervals_overlap(current.y, current.height, target.y, target.height)
      elseif direction == 'right' then
        in_direction = target.x > current.x
        is_aligned = intervals_overlap(current.y, current.height, target.y, target.height)
      elseif direction == 'up' then
        in_direction = current.y > target.y
        is_aligned = intervals_overlap(current.x, current.width, target.x, target.width)
      elseif direction == 'down' then
        in_direction = target.y > current.y
        is_aligned = intervals_overlap(current.x, current.width, target.x, target.width)
      end

      if in_direction and is_aligned then
        state.current_pane_id = target.id
        return true
      end
    end
  end

  return false
end

---@param direction SmartSplitsDirection
---@param amount integer
---@return boolean
function M.resize(direction, amount)
  if not state.enabled then
    return false
  end

  amount = amount or 1
  local current = M.get_current_pane()
  if not current then
    return false
  end

  if direction == 'left' or direction == 'right' then
    current.width = current.width + (direction == 'right' and amount or -amount)
  elseif direction == 'up' or direction == 'down' then
    current.height = current.height + (direction == 'down' and amount or -amount)
  end

  return true
end

---@param direction SmartSplitsDirection
---@return boolean
function M.split(direction)
  if not state.enabled then
    return false
  end

  local current = M.get_current_pane()
  if not current then
    return false
  end

  local new_id = #state.panes
  local new_pane

  if direction == 'right' then
    new_pane = {
      id = new_id,
      x = current.x + current.width,
      y = current.y,
      width = 20,
      height = current.height,
    }
  elseif direction == 'down' then
    new_pane = {
      id = new_id,
      x = current.x,
      y = current.y + current.height,
      width = current.width,
      height = 6,
    }
  elseif direction == 'left' then
    new_pane = {
      id = new_id,
      x = current.x - 20,
      y = current.y,
      width = 20,
      height = current.height,
    }
  elseif direction == 'up' then
    new_pane = {
      id = new_id,
      x = current.x,
      y = current.y - 6,
      width = current.width,
      height = 6,
    }
  else
    return false
  end

  table.insert(state.panes, new_pane)
  state.current_pane_id = new_id
  return true
end

---@param direction SmartSplitsDirection
---@return boolean
function M.wrap(direction)
  if not state.enabled then
    return false
  end

  local opposite = {
    left = 'right',
    right = 'left',
    up = 'down',
    down = 'up',
  }

  return M.move(opposite[direction])
end

return M

---Pure layout decisions over a Kitty `ls` window list.
---Kitty directions for the vertical axis are `top` and `bottom`.

local M = {}

local NEIGHBOR = {
  left = 'left',
  right = 'right',
  up = 'top',
  down = 'bottom',
}

local REVERSE = {
  left = 'right',
  right = 'left',
  up = 'down',
  down = 'up',
}

---Sign applied to the resize amount. `before` is the neighbor on the start side
---(left/top), `after` is the neighbor on the end side (right/bottom).
---Mirrors `relative_resize.py`: the pane grows into the direction you asked for
---when that side is free, and shrinks when the only free side is behind you.
local HORIZONTAL = {
  left = { both = -1, before = 1, after = -1 },
  right = { both = 1, before = -1, after = 1 },
}
local VERTICAL = {
  up = { both = -1, before = 1, after = -1 },
  down = { both = 1, before = -1, after = 1 },
}

---@param direction SmartSplitsDirection
---@return string|nil
function M.neighbor_key(direction)
  return NEIGHBOR[direction]
end

---@param direction SmartSplitsDirection
---@return SmartSplitsDirection
function M.reverse(direction)
  return REVERSE[direction]
end

---@param windows table[]
---@return table<integer, table>
function M.index_by_id(windows)
  local by_id = {}
  for _, window in ipairs(windows or {}) do
    by_id[window.id] = window
  end
  return by_id
end

---Neighbor window ids in `direction`, or `nil` when this kitty build did not
---report a `neighbors` map.
---@param window table|nil
---@param direction SmartSplitsDirection
---@return integer[]|nil
function M.neighbor_ids(window, direction)
  if type(window) ~= 'table' or type(window.neighbors) ~= 'table' then
    return nil
  end
  local key = NEIGHBOR[direction]
  if not key then
    return {}
  end
  local ids = window.neighbors[key]
  if type(ids) ~= 'table' then
    return {}
  end
  return ids
end

---@param window table|nil
---@param direction SmartSplitsDirection
---@return boolean
function M.has_neighbor(window, direction)
  local ids = M.neighbor_ids(window, direction)
  return ids ~= nil and #ids > 0
end

---@param window table|nil
---@param key string
---@return integer[]
local function neighbor_list(window, key)
  local neighbors = window and window.neighbors
  local ids = neighbors and neighbors[key]
  if type(ids) ~= 'table' then
    return {}
  end
  return ids
end

---Recover x/y from neighbor links and each window's cell size.
---A tall layout lists every stacked window as a neighbor of the full-height
---pane, so a single "first neighbor" walk cannot see the rest of that edge.
---@param windows table[]
---@return table<integer, { x: number, y: number, w: number, h: number }>
function M.place(windows)
  local by_id = M.index_by_id(windows)
  ---@type table<integer, { x: number|nil, y: number|nil, w: number, h: number }>
  local box = {}
  for _, window in ipairs(windows or {}) do
    box[window.id] = {
      x = nil,
      y = nil,
      w = window.columns or window.width or 1,
      h = window.lines or window.height or 1,
    }
  end

  local function resolve(axis)
    local parent_key = axis == 'x' and 'left' or 'top'
    local size_key = axis == 'x' and 'w' or 'h'
    local pos_key = axis == 'x' and 'x' or 'y'
    local pending = {}
    for _, window in ipairs(windows or {}) do
      pending[window.id] = true
    end

    for _ = 1, #(windows or {}) + 1 do
      if not next(pending) then
        break
      end
      local progressed = false
      local ids = {}
      for id in pairs(pending) do
        table.insert(ids, id)
      end
      for _, id in ipairs(ids) do
        local parents = neighbor_list(by_id[id], parent_key)
        local ready = true
        local pos = 0
        for _, parent_id in ipairs(parents) do
          local parent = box[parent_id]
          if not parent or parent[pos_key] == nil then
            ready = false
            break
          end
          pos = math.max(pos, parent[pos_key] + parent[size_key])
        end
        if ready then
          box[id][pos_key] = pos
          pending[id] = nil
          progressed = true
        end
      end
      if not progressed then
        for id in pairs(pending) do
          box[id][pos_key] = 0
        end
        break
      end
    end
  end

  resolve('x')
  resolve('y')
  return box
end

---@param a0 number
---@param a1 number
---@param b0 number
---@param b1 number
---@return boolean
local function overlaps(a0, a1, b0, b1)
  return a0 < b1 and b0 < a1
end

---Window on the opposite edge. When several share that edge, pick the one
---whose span contains the center of `origin` (the full-height pane beside a
---stack, for example).
---@param windows table[]
---@param origin table
---@param direction SmartSplitsDirection
---@return integer|nil
function M.wrap_target(windows, origin, direction)
  if type(origin) ~= 'table' or origin.neighbors == nil then
    return nil
  end

  local boxes = M.place(windows)
  local origin_box = boxes[origin.id]
  if not origin_box or origin_box.x == nil or origin_box.y == nil then
    return nil
  end

  local horizontal = direction == 'left' or direction == 'right'
  local want_max = direction == 'left' or direction == 'up'
  local origin_center = horizontal and (origin_box.y + origin_box.h / 2) or (origin_box.x + origin_box.w / 2)
  local best

  for _, window in ipairs(windows or {}) do
    local box = boxes[window.id]
    if window.id ~= origin.id and box and box.x ~= nil and box.y ~= nil then
      local aligned = horizontal
          and overlaps(origin_box.y, origin_box.y + origin_box.h, box.y, box.y + box.h)
        or (not horizontal and overlaps(origin_box.x, origin_box.x + origin_box.w, box.x, box.x + box.w))
      if aligned then
        local pos = horizontal and box.x or box.y
        local center = horizontal and (box.y + box.h / 2) or (box.x + box.w / 2)
        local contains = horizontal and (box.y <= origin_center and origin_center < box.y + box.h)
          or (not horizontal and box.x <= origin_center and origin_center < box.x + box.w)
        local candidate = { id = window.id, pos = pos, contains = contains, center = center }
        local replace = best == nil
        if best and not replace then
          if pos ~= best.pos then
            replace = want_max and pos > best.pos or (not want_max and pos < best.pos)
          elseif contains ~= best.contains then
            replace = contains
          else
            replace = math.abs(center - origin_center) < math.abs(best.center - origin_center)
          end
        end
        if replace then
          best = candidate
        end
      end
    end
  end

  return best and best.id or nil
end

---Axis and signed increment for the `resize-window` command.
---`nil` when the window has no neighbor on that axis.
---@param window table
---@param direction SmartSplitsDirection
---@param amount number
---@return 'horizontal'|'vertical'|nil
---@return integer|nil
function M.resize_increment(window, direction, amount)
  amount = math.abs(math.floor(tonumber(amount) or 1))
  if amount == 0 then
    return nil, nil
  end

  local horizontal = direction == 'left' or direction == 'right'
  local before = M.has_neighbor(window, horizontal and 'left' or 'up')
  local after = M.has_neighbor(window, horizontal and 'right' or 'down')
  if not before and not after then
    return nil, nil
  end

  local which = (before and after and 'both') or (before and 'before') or 'after'
  local signs = horizontal and HORIZONTAL or VERTICAL
  local sign = signs[direction][which]
  return horizontal and 'horizontal' or 'vertical', sign * amount
end

return M

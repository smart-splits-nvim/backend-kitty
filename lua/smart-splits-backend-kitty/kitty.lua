local config = require('smart-splits-backend-kitty.config')
local layout = require('smart-splits-backend-kitty.layout')
local socket = require('smart-splits-backend-kitty.socket')

local M = {}

local AUGROUP = 'smart-splits-backend-kitty'

-- Kitty rejects a client version newer than the instance it is talking to.
local PROTOCOL_VERSION = { 0, 45, 0 }

---@return integer
local function window_id()
  return tonumber(vim.env.KITTY_WINDOW_ID) or 0
end

---Send one remote-control command. Tests replace this.
---With `no_response`, kitty sends nothing back and the result is `true` after the write.
---@param cmd string
---@param payload? table
---@param opts? { no_response?: boolean }
---@return any
function M.request(cmd, payload, opts)
  opts = opts or {}
  local command = {
    cmd = cmd,
    version = PROTOCOL_VERSION,
    no_response = opts.no_response == true,
    kitty_window_id = window_id(),
  }
  if payload then
    command.payload = payload
  end
  local password = config.password()
  if password ~= '' then
    command.password = password
  end

  if command.no_response then
    socket.send(command)
    return true
  end
  return socket.exchange(command)
end

---@return boolean
function M.is_running()
  local listen = vim.env.KITTY_LISTEN_ON
  return type(listen) == 'string' and #listen > 0
end

---@return boolean
function M.usable()
  return config.options.enable and M.is_running()
end

---@return string|nil
function M.version()
  if vim.fn.executable('kitty') ~= 1 and vim.fn.executable('kitty.exe') ~= 1 then
    return nil
  end
  local name = vim.fn.executable('kitty') == 1 and 'kitty' or 'kitty.exe'
  local ok, waited = pcall(function()
    return vim.system({ name, '--version' }, { text = true, timeout = 2000 }):wait()
  end)
  if not ok or type(waited) ~= 'table' or waited.code ~= 0 then
    return nil
  end
  local stdout = waited.stdout or ''
  if stdout == '' then
    return nil
  end
  return vim.trim(stdout)
end

---@return table[]
function M.list_os_windows()
  local data = M.request('ls')
  if type(data) ~= 'table' then
    error('failed to parse kitty ls response')
  end
  return data
end

---@class SmartSplits.Kitty.Context
---@field tab table
---@field window table
---@field windows table[]

---@return SmartSplits.Kitty.Context|nil
function M.active_context()
  for _, client in ipairs(M.list_os_windows()) do
    if client.is_active and client.is_focused then
      for _, tab in ipairs(client.tabs or {}) do
        local tab_active = tab.is_active or tab.is_active_tab
        if tab_active and tab.is_focused then
          for _, window in ipairs(tab.windows or {}) do
            local win_active = window.is_active or window.is_active_window
            if win_active and window.is_focused then
              return {
                tab = tab,
                window = window,
                windows = tab.windows,
              }
            end
          end
        end
      end
    end
  end
  return nil
end

---@return table|nil
function M.active_window()
  local ctx = M.active_context()
  return ctx and ctx.window or nil
end

---Stack layout is kitty's fullscreen/zoom.
---@return boolean
function M.is_zoomed()
  local ctx = M.active_context()
  return ctx ~= nil and ctx.tab.layout == 'stack'
end

---@param direction SmartSplitsDirection
---@return boolean
function M.neighboring_window(direction)
  local key = layout.neighbor_key(direction)
  return M.request('action', { action = 'neighboring_window ' .. key }, { no_response = true }) == true
end

---@param id integer
---@return boolean
function M.focus_window(id)
  local result = M.request('focus-window', { match = 'id:' .. tostring(id) })
  return result ~= nil and result ~= false
end

---@param axis 'horizontal'|'vertical'
---@param increment integer
---@return boolean
function M.resize_window(axis, increment)
  local payload = {
    self = true,
    increment = increment,
    axis = axis,
  }
  local id = tonumber(vim.env.KITTY_WINDOW_ID)
  if id then
    payload.match = 'id:' .. tostring(id)
  end
  return M.request('resize-window', payload, { no_response = true }) == true
end

---@param direction SmartSplitsDirection
---@return boolean
function M.split(direction)
  -- hsplit/vsplit are applied only by the splits layout. Tall, fat, and grid
  -- ignore them and just append a window, so switch first.
  M.request('goto-layout', { layout = 'splits' }, { no_response = true })

  local location = (direction == 'up' or direction == 'down') and 'hsplit' or 'vsplit'
  local created = M.request('launch', {
    args = {},
    cwd = 'current',
    location = location,
  })
  if not created then
    return false
  end
  if direction == 'left' or direction == 'up' then
    local edge = direction == 'up' and 'top' or 'left'
    return M.request('action', { action = 'move_window ' .. edge, self = true }, { no_response = true }) == true
  end
  return true
end

---Kitty conditional mappings read the `IS_NVIM` user variable.
---@param active boolean
function M.set_nvim_user_var(active)
  local ok, handle = pcall(vim.uv.guess_handle, 1)
  if not ok or handle ~= 'tty' then
    return
  end
  local esc = string.char(27)
  local bel = string.char(7)
  local seq = active and (esc .. ']1337;SetUserVar=IS_NVIM=MQo' .. bel) or (esc .. ']1337;SetUserVar=IS_NVIM' .. bel)
  -- selene: allow(incorrect_standard_library_use)
  io.stdout:write(seq)
  -- selene: allow(incorrect_standard_library_use)
  io.stdout:flush()
end

---Called by core once this backend is the one in use.
function M.activate()
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  M.set_nvim_user_var(true)
  vim.api.nvim_create_autocmd('VimResume', {
    group = group,
    callback = function()
      M.set_nvim_user_var(true)
    end,
  })
  vim.api.nvim_create_autocmd({ 'VimSuspend', 'VimLeavePre' }, {
    group = group,
    callback = function()
      M.set_nvim_user_var(false)
    end,
  })
end

return M

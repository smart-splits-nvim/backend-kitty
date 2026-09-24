---Kitty remote-control framing and a synchronous socket client.
---Commands are `<ESC>P@kitty-cmd<JSON><ESC>\`. See https://sw.kovidgoyal.net/kitty/rc_protocol/

local M = {}

local ESC = string.char(0x1b)
local FRAME_PREFIX = ESC .. 'P@kitty-cmd'
local FRAME_SUFFIX = ESC .. '\\'

---@param addr string
---@return 'tcp'|'unix'|nil
---@return string|integer|nil
---@return integer|nil
function M.parse_address(addr)
  local host, port = addr:match('^tcp:([^:]+):(%d+)$')
  if host and port then
    return 'tcp', host, tonumber(port)
  end

  host, port = addr:match('^([^:]+):(%d+)$')
  if host and port and not host:find('/', 1, true) then
    return 'tcp', host, tonumber(port)
  end

  local unix_path = addr:match('^unix:(.+)$')
  if unix_path then
    return 'unix', unix_path, nil
  end

  if addr:sub(1, 1) == '/' then
    return 'unix', addr, nil
  end

  return nil, 'invalid kitty address: ' .. addr, nil
end

---@param command table
---@return string
function M.encode(command)
  return FRAME_PREFIX .. vim.json.encode(command) .. FRAME_SUFFIX
end

---Unwrap a kitty response. `data` is JSON-encoded a second time, as with `ls`.
---@param raw string
---@return any|nil
---@return string|nil err
function M.decode(raw)
  local body = raw:match(ESC .. 'P@kitty%-cmd(.-)' .. ESC .. '\\')
  if not body then
    return nil, 'invalid kitty frame'
  end

  local ok, envelope = pcall(vim.json.decode, body, { luanil = { object = true, array = true } })
  if not ok or type(envelope) ~= 'table' then
    return nil, 'invalid kitty response'
  end
  if envelope.ok == false then
    return nil, envelope.error or 'kitty command failed'
  end

  local data = envelope.data
  if type(data) == 'string' then
    local decoded_ok, inner = pcall(vim.json.decode, data, { luanil = { object = true, array = true } })
    if decoded_ok then
      return inner, nil
    end
    return data, nil
  end
  if data == nil then
    return true, nil
  end
  return data, nil
end

---@param is_done fun(): boolean
---@param what string
local function wait_until(is_done, what)
  if not vim.wait(2000, is_done, 10) then
    error('timed out ' .. what)
  end
end

---@param addr string
---@return table client
local function connect(addr)
  local kind, host_or_path, port = M.parse_address(addr)
  if not kind then
    error(host_or_path)
  end

  local client = kind == 'tcp' and vim.uv.new_tcp() or vim.uv.new_pipe(false)
  if not client then
    error('failed to create kitty socket')
  end

  local done, err = false, nil
  local function on_connect(connect_err)
    err = connect_err
    done = true
  end

  if kind == 'tcp' then
    local host = host_or_path == 'localhost' and '127.0.0.1' or host_or_path
    client:connect(host, port, on_connect)
  else
    client:connect(host_or_path, on_connect)
  end

  local ok, wait_err = pcall(wait_until, function()
    return done
  end, 'connecting to ' .. addr)
  if not ok or err then
    if not client:is_closing() then
      client:close()
    end
    error(wait_err or err)
  end
  return client
end

---@param client table
local function close_client(client)
  if client and not client:is_closing() then
    pcall(function()
      client:read_stop()
    end)
    client:close()
  end
end

---@param client table
---@param frame string
local function write_frame(client, frame)
  local done, err = false, nil
  client:write(frame, function(write_err)
    err = write_err
    done = true
  end)
  wait_until(function()
    return done
  end, 'writing to kitty')
  if err then
    error(err)
  end
end

---@param client table
---@return string
local function read_frame(client)
  local buffer = ''
  local done, err = false, nil
  client:read_start(function(read_err, data)
    if read_err then
      err = read_err
      done = true
      return
    end
    if not data then
      done = true
      return
    end
    buffer = buffer .. data
    if buffer:sub(-2) == FRAME_SUFFIX then
      client:read_stop()
      done = true
    end
  end)
  wait_until(function()
    return done
  end, 'reading from kitty')
  if err then
    error(err)
  end
  if buffer == '' then
    error('kitty closed the socket without a response')
  end
  return buffer
end

---@param command table
function M.send(command)
  local addr = vim.env.KITTY_LISTEN_ON
  if type(addr) ~= 'string' or addr == '' then
    error('KITTY_LISTEN_ON is unset')
  end
  local client = connect(addr)
  local ok, err = pcall(write_frame, client, M.encode(command))
  close_client(client)
  if not ok then
    error(err)
  end
end

---@param command table
---@return any
function M.exchange(command)
  local addr = vim.env.KITTY_LISTEN_ON
  if type(addr) ~= 'string' or addr == '' then
    error('KITTY_LISTEN_ON is unset')
  end
  local client = connect(addr)
  local ok, result = pcall(function()
    write_frame(client, M.encode(command))
    local raw = read_frame(client)
    local decoded, decode_err = M.decode(raw)
    if decode_err then
      error(decode_err)
    end
    return decoded
  end)
  close_client(client)
  if not ok then
    error(result)
  end
  return result
end

return M

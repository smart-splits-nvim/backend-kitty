---Use Kitty's client to encrypt password-authenticated remote-control requests.
local M = {}

---@param cmd string
---@param payload table
---@return string[]
local function arguments(cmd, payload)
  local args = { cmd }
  if payload.match then
    vim.list_extend(args, { '--match', payload.match })
  end
  if payload.self then
    table.insert(args, '--self')
  end
  if cmd == 'action' then
    table.insert(args, payload.action)
  elseif cmd == 'resize-window' then
    vim.list_extend(args, { '--axis', payload.axis, '--increment', tostring(payload.increment) })
  elseif cmd == 'goto-layout' then
    table.insert(args, payload.layout)
  elseif cmd == 'launch' then
    vim.list_extend(args, { '--cwd', payload.cwd, '--location', payload.location, '--' })
    vim.list_extend(args, payload.args or {})
  elseif cmd ~= 'ls' and cmd ~= 'focus-window' then
    error('unsupported authenticated kitty command: ' .. cmd)
  end
  return args
end

---@param cmd string
---@param payload? table
---@param password string
---@return any
function M.request(cmd, payload, password)
  local executable
  for _, name in ipairs({ 'kitten', 'kitty', 'kitten.exe', 'kitty.exe' }) do
    if vim.fn.executable(name) == 1 then
      executable = name
      break
    end
  end
  if not executable then
    error('kitty password authentication requires kitten or kitty on PATH')
  end
  local addr = vim.env.KITTY_LISTEN_ON
  if not addr or addr == '' then
    error('KITTY_LISTEN_ON is unset')
  end
  local argv = { executable, '@', '--to', addr, '--password-file', '-', '--use-password', 'always' }
  vim.list_extend(argv, arguments(cmd, payload or {}))
  -- Pass the password over stdin, not argv or Neovim's global environment.
  -- The client uses KITTY_PUBLIC_KEY to encrypt it and add a fresh timestamp.
  -- Wait for acknowledgement even for commands using no_response on the socket
  -- path, so an authentication failure is not mistaken for a successful move.
  local result = vim.system(argv, { stdin = password, text = true, timeout = 2000 }):wait()
  if result.code ~= 0 then
    error(('kitty %s failed (exit %s): %s'):format(cmd, result.code, vim.trim(result.stderr or '')))
  end
  local output = vim.trim(result.stdout or '')
  if output == '' then
    return true
  end
  local ok, data = pcall(vim.json.decode, output, { luanil = { object = true, array = true } })
  if ok then
    return data
  end
  return output
end

return M

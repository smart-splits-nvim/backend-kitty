local M = {}

---@class SmartSplits.Kitty.Config
---@field enable boolean
---@field password string|nil remote control password; falls back to `vim.g.smart_splits_kitty_password`
---@field split SmartSplits.Kitty.Config.Split
---@field zoom SmartSplits.Kitty.Config.Zoom

---@class SmartSplits.Kitty.Config.Split
---@field left boolean
---@field right boolean
---@field up boolean
---@field down boolean

---@class SmartSplits.Kitty.Config.Zoom
---@field block_nav boolean block move and resize while the tab layout is `stack`

---@class SmartSplits.Kitty.PartialConfig
---@field enable? boolean
---@field password? string|nil
---@field split? SmartSplits.Kitty.PartialConfig.Split
---@field zoom? SmartSplits.Kitty.PartialConfig.Zoom

---@class SmartSplits.Kitty.PartialConfig.Split
---@field left? boolean
---@field right? boolean
---@field up? boolean
---@field down? boolean

---@class SmartSplits.Kitty.PartialConfig.Zoom
---@field block_nav? boolean

---@type SmartSplits.Kitty.Config
M.defaults = {
  enable = true,
  password = nil,
  split = {
    left = true,
    right = true,
    up = true,
    down = true,
  },
  zoom = {
    block_nav = false,
  },
}

---@type SmartSplits.Kitty.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? SmartSplits.Kitty.PartialConfig
---@return SmartSplits.Kitty.Config
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
  return M.options
end

---Password sent on the remote-control socket. An empty config value falls back to the v2 global.
---@return string
function M.password()
  local password = M.options.password
  if type(password) ~= 'string' or password == '' then
    password = vim.g.smart_splits_kitty_password
  end
  if type(password) ~= 'string' then
    return ''
  end
  return password
end

return M

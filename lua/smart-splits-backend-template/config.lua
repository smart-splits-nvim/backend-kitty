---@class TemplateBackend.Config
---@field enable boolean

---@alias TemplateBackend.PartialConfig { enable?: boolean }

local M = {}

---@type TemplateBackend.Config
M.defaults = {
  enable = true,
}

---@type TemplateBackend.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? TemplateBackend.PartialConfig
---@return TemplateBackend.Config
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend('force', M.defaults, opts)
  return M.options
end

return M

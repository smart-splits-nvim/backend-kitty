local kitten = 'relative_resize.py'

local home = os.getenv('HOME') or ''
local xdg_config = os.getenv('XDG_CONFIG_HOME')
local prefix = (xdg_config and xdg_config ~= '') and xdg_config or (home .. '/.config')
local kitty_config_path = prefix .. '/kitty/'

local source_file = require('lazy.core.config').plugins['backend-kitty'].dir .. '/kitten/' .. kitten
local dest_file = kitty_config_path .. kitten

if vim.fn.isdirectory(kitty_config_path) == 0 then
  vim.notify('Kitty config directory not found: ' .. kitty_config_path, vim.log.levels.ERROR)
else
  local success, err = vim.loop.fs_copyfile(source_file, dest_file)
  if not success then
    vim.notify('Failed to copy kitty helper script: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

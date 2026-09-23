-- Test initialization
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.env.SMART_SPLITS_DIR)
package.path = table.concat({ root .. '/?.lua', root .. '/?/init.lua', package.path }, ';')
vim.opt.shadafile = 'NONE'
vim.lsp.log.set_level('off')

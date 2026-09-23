# backend-template

Template repository for creating [smart-splits.nvim](https://github.com/smart-splits-nvim/smart-splits.nvim) v3 backends.

## About

This template provides a complete starting point for implementing a smart-splits v3 backend. It includes:

- A mock multiplexer implementation demonstrating the v3 backend protocol
- Comprehensive test scaffolding using Busted
- CI automation for linting, type checking, and testing
- All necessary configuration files (Stylua, Selene, LuaLS)

## Using This Template

1. Click "Use this template" on GitHub to create your new backend repository
2. Rename the module from `smart-splits-backend-template` to your backend name (e.g., `smart-splits-backend-myterminal`)
3. Replace the mock multiplexer with your actual terminal/multiplexer integration
4. Update the README, LICENSE, and other metadata

## Protocol

This template implements the smart-splits v3 backend protocol:

```lua
---@class SmartSplitsBackend
---@field name string                          -- Backend identifier
---@field protocol_version string              -- "3.0.0"
---@field detect fun():boolean                 -- Check if backend is available
---@field move SmartSplitsBackendMove          -- Navigate between panes
---@field resize? SmartSplitsBackendResize     -- Resize panes (optional)
---@field health? fun()                        -- Health check (optional)
```

### Move Behavior

The `move` function receives a direction and options:

```lua
---@alias SmartSplitsDirection 'left'|'right'|'up'|'down'

---@class SmartSplitsBackendMoveOpts
---@field at_edge? 'stop'|'wrap'|'split'

---@alias SmartSplitsBackendMove fun(direction: SmartSplitsDirection, opts?: SmartSplitsBackendMoveOpts):boolean
```

- `at_edge = 'stop'`: Return `false` when no neighbor exists (default)
- `at_edge = 'wrap'`: Wrap to opposite edge if possible
- `at_edge = 'split'`: Create a new pane if possible

Return `true` if the move succeeded, `false` otherwise. When `false` is returned, smart-splits core handles the edge behavior within Neovim's layout.

## Installation

Users install your backend as a dependency of smart-splits:

```lua
{
  'smart-splits-nvim/smart-splits.nvim',
  branch = 'v3',
  opts = {
    mux = {
      backend = 'smart-splits-backend-myterminal',
    },
  },
  dependencies = {
    {
      'your-username/backend-myterminal',
      opts = {
        -- Backend-specific configuration
      },
    },
  },
}
```

## Project Structure

```
.
├── lua/smart-splits-backend-template/
│   ├── init.lua          # Main backend interface
│   ├── config.lua        # Configuration management
│   ├── mock_mux.lua      # Mock multiplexer (replace with real implementation)
│   ├── move.lua          # Navigation logic
│   ├── resize.lua        # Resize logic
│   └── health.lua        # Health check implementation
├── tests/
│   ├── init.lua          # Test initialization
│   ├── helpers.lua       # Test utilities
│   └── core/             # Test specifications
├── justfile              # Command runner
├── .busted               # Busted configuration
├── selene.toml           # Selene configuration
├── .luarc.json           # LuaLS configuration
└── .stylua.toml          # Stylua configuration
```

## License

MIT

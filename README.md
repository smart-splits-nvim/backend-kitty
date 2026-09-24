# Backend Kitty

Kitty integration for [smart-splits.nvim](https://github.com/smart-splits-nvim/smart-splits.nvim) v3.

Neovim talks to Kitty on the `KITTY_LISTEN_ON` socket using the [remote-control protocol](https://sw.kovidgoyal.net/kitty/rc_protocol/).

## Install

### lazy.nvim

It is recommended not to lazy load smart-splits.nvim if using the Kitty integration, since it depends on the plugin setting the IS_NVIM Kitty user variable on startup. 
```lua
{
  'smart-splits-nvim/smart-splits.nvim',
  branch = 'v3',
  lazy = false,
  opts = { -- Plugin Configuration
    mux = {
      backend = 'smart-splits-backend-kitty',
    },
  },
  dependencies = {
    {
      'smart-splits-nvim/backend-kitty',
      module = 'smart-splits-backend-kitty',
      opts = { -- Backend Configuration
        -- password = 'secret',
      },
    },
  },
}
```

#### Backend Configuration

```lua
opts = {
  -- Set false to force detect() to fail without uninstalling the plugin.
  enable = true,

  -- Remote-control password. When unset, falls back to
  -- vim.g.smart_splits_kitty_password.
  -- https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.remote_control_password
  password = nil,

  -- Which edges may create a Kitty split when move.at_edge is 'split'.
  split = {
    left = true,
    right = true,
    up = true,
    down = true,
  },

  -- Kitty's stack layout is its zoom/fullscreen.
  zoom = {
    block_nav = false, -- refuse move and resize while the tab layout is 'stack'
  },
}
```

### Kitty Configuration

#### Mappings

```
map ctrl+j neighboring_window bottom
map ctrl+k neighboring_window top
map ctrl+h neighboring_window left
map ctrl+l neighboring_window right

map --when-focus-on var:IS_NVIM ctrl+j
map --when-focus-on var:IS_NVIM ctrl+k
map --when-focus-on var:IS_NVIM ctrl+h
map --when-focus-on var:IS_NVIM ctrl+l
```

#### Communication
Kitty has to accept remote-control commands. Either start it with a socket:
```bash

kitty -o allow_remote_control=yes --single-instance --listen-on unix:/tmp/mykitty
```

or put the same settings in `~/.config/kitty/kitty.conf`:

```
# Unix systems:
allow_remote_control yes
listen_on unix:/tmp/mykitty
```

This will set the `KITTY_LISTEN_ON` environment variable, that the plugin uses to confirm a Kitty session.


TODO: Resize while Neovim is focused is handled inside Neovim and, at a full-width or full-height window, by `resize-window` on the socket.

#### Neovim over SSH

The remote machine needs Neovim and this plugin. Forward the Kitty socket with `kitten ssh`, and only do that for hosts you trust: forwarded remote control gives the remote host access to the local Kitty instance.

In the local `~/.config/kitty/ssh.conf`:

```
forward_remote_control yes
```

Use a filesystem socket rather than an abstract one:

```
allow_remote_control yes
listen_on unix:/tmp/mykitty
```

```bash
kitten ssh user@remotehost
```

See Kitty's [SSH remote control documentation](https://sw.kovidgoyal.net/kitty/kittens/ssh/) if the socket does not show up on the remote host.

## Health

`:checkhealth smart-splits` includes this backend's report: whether `KITTY_LISTEN_ON` is set, and whether a socket `ls` can see the focused window.

`:checkhealth smart-splits-backend-kitty` runs the same report on its own.

## Testing

```sh
just test
```

The suite stubs the socket with an in-memory layout, and it also runs smart-splits' protocol conformance tests. See [CONTRIBUTING.md](./CONTRIBUTING.md).

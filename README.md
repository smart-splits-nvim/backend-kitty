# Backend Kitty

Kitty integration for [smart-splits.nvim](https://github.com/smart-splits-nvim/smart-splits.nvim):

| Smarter and more intuitive split pane management for NeoVim. Resize splits using a mental model of left/right/up/down instead of wider/narrower/taller/shorter. Navigate seamlessly between NeoVim windows and terminal multiplexer panes with a clean, backend-driven architecture.

All conversation between NeoVim and Kitty happens through socket using the [remote-control protocol](https://sw.kovidgoyal.net/kitty/rc_protocol/).

<!-- BEGIN mktoc {"min_depth":2, "max_depth":5} -->

- [Install](#install)
  - [lazy.nvim](#lazynvim)
    - [Backend Configuration Options](#backend-configuration-options)
  - [Kitty Configuration](#kitty-configuration)
    - [Mappings](#mappings)
- [Smart-splits.nvim Setup END](#smart-splitsnvim-setup-end)
    - [Communication](#communication)
      - [Password](#password)
- [Neovim over SSH](#neovim-over-ssh)
- [Health](#health)
- [Contributing](#contributing)
<!-- END mktoc -->

## Install

First complete the [smart-splits.nvim](https://github.com/smart-splits-nvim/smart-splits.nvim) installation/setup instructions.
The complete list of options for the plugin configuration can be found there.

### lazy.nvim

It is recommended not to lazy load smart-splits.nvim if using the Kitty integration, since it depends on the plugin setting the IS_NVIM user variable at start-up.

It is also strongly recommended setting up an password, otherwise arbitrary processes can control Kitty and execute commands. More in Kitty [documentation](https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.remote_control_password).

```lua
{
  'smart-splits-nvim/smart-splits.nvim',
  version = '^3.0.0',
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
	  build = "./kitten/install_relative_resize.lua",
      opts = { -- Backend Configuration
        -- password = 'secret',
      },
    },
  },
}
```

#### Backend Configuration Options

```lua
opts = {
  -- Set false to force detect() to fail without uninstalling the plugin.
  enable = true,

  -- Remote-control password. Refer to the Kitty documentation for more details.
  -- https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.remote_control_password
  password = nil,

  -- Use kitten/kitty with the password on stdin instead of native encryption.
  provide_password_via_stdin = false,

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

Add to your Kitty configuration (usually ~/.config/kitty/kitty.conf) :

```
## Smart-splits.nvim Setup
map ctrl+j neighboring_window bottom
map ctrl+k neighboring_window top
map ctrl+h neighboring_window left
map ctrl+l neighboring_window right

# Unset the mappings to pass control to Neovim
map --when-focus-on var:IS_NVIM ctrl+j
map --when-focus-on var:IS_NVIM ctrl+k
map --when-focus-on var:IS_NVIM ctrl+h
map --when-focus-on var:IS_NVIM ctrl+l

map --when-focus-on var:IS_NVIM alt+j
map --when-focus-on var:IS_NVIM alt+k
map --when-focus-on var:IS_NVIM alt+h
map --when-focus-on var:IS_NVIM alt+l

# **Optiomal** : Use the provided Kitten to control the Resizing of Kitty's
# windows outside of Neovim.
# The number 20 here is the resize amount: adjust as needed
map alt+j kitten relative_resize.py down  20
map alt+k kitten relative_resize.py up    20
map alt+h kitten relative_resize.py left  20
map alt+l kitten relative_resize.py right 20

## Smart-splits.nvim Setup END
```

#### Communication

Kitty has to accept remote-control commands. Either start it with a socket:

```bash

kitty -o allow_remote_control=yes --single-instance --listen-on unix:/tmp/mykitty
```

Or add/modify these settings in your Kitty configuration:

```
# Unix systems:
allow_remote_control yes
listen_on unix:/tmp/mykitty
```

This will set the `KITTY_LISTEN_ON` environment variable, that the plugin uses to confirm a Kitty session.

##### Password

By default, password authentication encrypts commands inside Neovim using OpenSSL
libcrypto. Set `provide_password_via_stdin = true` to use `kitten` (preferred) or
`kitty` on Neovim's `PATH` instead. This avoids the plugin's libcrypto dependency
but starts a client process for each authenticated command. Both transports need
`KITTY_PUBLIC_KEY` from Kitty.

With this option, the configured `password` (or legacy
`vim.g.smart_splits_kitty_password`) is passed to the client over stdin, without
changing `KITTY_RC_PASSWORD`. Commands wait for acknowledgement so authentication
errors are reported. Requests without a configured password still use the socket.

| When using the remote_control_password option communication to the terminal is encrypted to keep the password secure. A public key is used from the KITTY_PUBLIC_KEY environment variable.

When setting up a password in your plugin configuration, you have to add to you Kitty configuration:

```
remote_control_password "yourpassword" ls focus-window resize-window action goto-layout launch
```

And add/change the 'allow_remote_control' to:

```
allow_remote_control password
```

You can control what commands can be executed by the remote host but the minimum required by the plugin are: `ls focus-window resize-window action goto-layout launch`

More information in Kitty's [documentation](https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.remote_control_password).

If you receive an error message like: "Remote control is disabled. Add allow_remote_control to your kitty.conf", make sure:

- You provided the correct password in your plugin configuration.
- You provided the minimum permissions to the 'remote_control_password'.
- You used `kitten ssh` instead of `ssh` when using NeoVim over ssh (see bellow).

## Neovim over SSH

The remote machine needs NeoVim with this plugin installed.

To forward the Kitty socket use `kitten ssh` instead of the vanilla 'ssh' command.

Only forward that for hosts you trust: forwarding remote control gives the remote host access to the local Kitty instance.

In the local `~/.config/kitty/ssh.conf`:

```
forward_remote_control yes
```

Use a file system socket rather than an abstract one (don't use the 'unix:@mykitty'):

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

## Contributing

Found a bug? Had a brilliant idea? Feel free to open an issue or a pull request! 🙌.
See how :[CONTRIBUTING.md](./CONTRIBUTING.md).

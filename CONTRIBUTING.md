# Contributing

Thank you for your interest in contributing to this backend template!

## Development Setup

### Prerequisites (Preferred: Nix + direnv)

If you have Nix and direnv installed:

```sh
direnv allow
```

That's it! All dependencies are provided by the Nix flake.

### Prerequisites (Alternative: Manual Installation)

If you prefer to install tools manually:

```sh
# macOS
brew install neovim stylua lua-language-server luajit luarocks just \
  yamlfmt prettier tombi nixfmt actionlint statix

LUAJIT_PREFIX="$(brew --prefix luajit)"
ROCKS=(--lua-version=5.1 --lua-dir="$LUAJIT_PREFIX" --local)
luarocks "${ROCKS[@]}" install busted 2.3.0
luarocks "${ROCKS[@]}" install nlua 0.3.2
eval "$(luarocks "${ROCKS[@]}" path --bin)"
```

### Running Tests

Run all checks before submitting a PR:

```sh
just check
```

This runs:
- Formatting checks (Stylua, yamlfmt, prettier, tombi, actionlint, statix)
- Selene linting
- LuaLS type checking
- Busted test suite

Individual commands:

```sh
just test        # Run tests
just lint        # Run linters
just fmt-check   # Check formatting
just fmt         # Auto-format code
just typecheck   # Type checking
```

To run the tests against Neovim nightly:

```sh
nix develop .#ci-nightly --command just test
```

The nightly build is downloaded from the [nix-community binary cache](https://nix-community.org/cache/); without that
cache configured, Nix compiles Neovim from source. CI runs `nix flake update neovim-nightly-overlay` first to test the
latest nightly.

## Implementation Guidelines

### Backend Protocol

Your backend must implement the v3 protocol:

```lua
---@class SmartSplitsBackend
---@field name string
---@field protocol_version string  -- "3.0.0"
---@field detect fun():boolean
---@field move SmartSplitsBackendMove
---@field resize? SmartSplitsBackendResize
---@field health? fun()
```

### Type Annotations

Use LuaCATS type annotations extensively. All functions should have:
- Parameter types with `@param`
- Return types with `@return`
- Class definitions with `@class` and `@field`

Example:

```lua
---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendMoveOpts
---@return boolean
function M.move(direction, opts)
  -- implementation
end
```

### Testing

All new functionality should include tests. The test suite uses:
- Busted test framework
- nlua (Neovim Lua interpreter)
- smart-splits core's `protocol_tests` for conformance

Test files follow the pattern `tests/core/*_spec.lua`.

## Code Style

- Use 2-space indentation
- Single quotes for strings
- Maximum line length: 120 characters
- Sort requires alphabetically

These are enforced by Stylua, yamlfmt, prettier, tombi, actionlint, and statix.

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `just check` to ensure all checks pass
5. Submit a pull request

## Questions?

Open an issue if you have questions about implementing a backend.

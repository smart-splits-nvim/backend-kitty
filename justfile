# Smart-splits core revision to test against
SMART_SPLITS_REV := "v3" # TODO: update to v3.0.0 when tagged

# Clone smart-splits core at pinned revision (no-op if already correct)
[private]
deps:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="deps/smart-splits.nvim"
    if [ -d "$dir" ] && [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$(git -C "$dir" rev-parse '{{ SMART_SPLITS_REV }}' 2>/dev/null)" ]; then
      exit 0
    fi
    rm -rf "$dir"
    mkdir -p deps
    git clone --filter=blob:none --no-checkout https://github.com/smart-splits-nvim/smart-splits.nvim "$dir"
    git -C "$dir" checkout --quiet '{{ SMART_SPLITS_REV }}'

# Force re-clone smart-splits core
[private]
deps-force:
    rm -rf deps/smart-splits.nvim
    just deps

# Run all tests
test: deps
    SMART_SPLITS_DIR="$(pwd)/deps/smart-splits.nvim" busted --run=core

# Check formatting
fmt-check:
    stylua --check lua tests
    yamlfmt -gitignore_excludes -dry .
    prettier --check "**/*.{json,jsonc}"
    tombi format --offline --check .
    nixfmt --check flake.nix treefmt.nix

# Format code
fmt:
    stylua lua tests
    yamlfmt -gitignore_excludes .
    prettier --write "**/*.{json,jsonc}"
    tombi format --offline .
    nixfmt flake.nix treefmt.nix

# Run selene
lint:
    selene ./lua/ ./tests/
    actionlint
    statix check

# Run LuaLS type checking
typecheck: deps
    #!/usr/bin/env bash
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    VIMRUNTIME="$(nvim --clean -i NONE --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quitall')" \
    lua-language-server --check=. --checklevel=Warning --check_format=pretty --configpath=.luarc.json --logpath="$tmpdir/luals"

# Run all checks
check: fmt-check lint typecheck test

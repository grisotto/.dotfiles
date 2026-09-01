.PHONY: test test-file lint format

# Run the whole suite in headless Neovim.
test:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }"

# Run a single spec: make test-file FILE=tests/review/panel_spec.lua
#
# Runs busted in this editor, the one started with the minimal init.
# `PlenaryBustedFile` would spawn another one instead, and that one gets no
# `-u`: the spec would run against the real configuration, with whatever the
# plugin manager has loaded into it.
test-file:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.busted').run('$(FILE)')"

lint:
	selene lua tests

format:
	stylua lua tests

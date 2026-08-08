NVIM := nvim

.PHONY: test
test:
	$(NVIM) --headless -u tests/minimal_init.lua -l tests/run.lua

NVIM := nvim
STYLUA ?= stylua

.PHONY: test lint format ci

test:
	$(NVIM) --headless -u tests/minimal_init.lua -l tests/run.lua

format:
	$(STYLUA) lua/ plugin/ tests/

lint:
	$(STYLUA) --check lua/ plugin/ tests/

ci: lint test

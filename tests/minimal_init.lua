-- Minimal init used by the headless test runner.
vim.env.NVIM_TEST_ROOT = vim.fn.getcwd()

local root = vim.env.NVIM_TEST_ROOT
vim.opt.rtp:prepend(root)

vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.hidden = true

-- A scratch notes dir so tests never touch the user's real notes.
local scratch = root .. "/tests/scratch"
vim.env.NV_TEST_NOTES_DIR = scratch
vim.fn.mkdir(scratch, "p")

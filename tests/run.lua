-- Minimal headless test framework for nv.nvim
--
-- Run from the repo root:
--   nvim --headless -u tests/minimal_init.lua -l tests/run.lua
local root = vim.fn.fnamemodify(vim.env.NVIM_TEST_ROOT or ".", ":p")

local M = {}

M.tests = {}

local current = nil

local function format_assert(ok, actual, expected)
  local fmt = "expected: %s, actual: %s"
  return fmt:format(vim.inspect(expected), vim.inspect(actual))
end

function M.describe(name, fn)
  current = name
  fn()
  current = nil
end

function M.it(name, fn)
  table.insert(M.tests, { describe = current or "", name = name, fn = fn })
end

function M.eq(expected, actual, message)
  if vim.deep_equal(expected, actual) then
    return
  end
  error((message or "assertion failed") .. "\n  " .. format_assert(false, actual, expected), 2)
end

function M.ok(cond, message)
  if not cond then
    error(message or "expected truthy value", 2)
  end
end

function M.throws(fn, pattern, message)
  local ok, err = pcall(fn)
  if ok then
    error(message or "expected function to throw", 2)
  end
  if pattern and not tostring(err):find(pattern) then
    error((message or "exception mismatch") .. "\n  expected pattern: " .. pattern .. "\n  actual: " .. tostring(err), 2)
  end
end

-- Expose the assertion DSL to spec files as globals.
_G.describe = M.describe
_G.it = M.it
_G.eq = M.eq
_G.ok = M.ok
_G.throws = M.throws

local function load_test_files()
  local files = vim.fn.glob(root .. "/tests/spec/*.lua", false, true)
  table.sort(files)
  for _, file in ipairs(files) do
    vim.cmd("luafile " .. vim.fn.fnameescape(file))
  end
end

local function run()
  local failures = 0
  local start = vim.uv.hrtime()
  for _, t in ipairs(M.tests) do
    local ok, err = pcall(t.fn)
    if ok then
      io.write(("%s > %s ... ok\n"):format(t.describe, t.name))
    else
      failures = failures + 1
      io.write(("%s > %s ... FAIL\n%s\n"):format(t.describe, t.name, err or "unknown error"))
    end
  end
  local elapsed = (vim.uv.hrtime() - start) / 1e6
  io.write(("\n%d passed, %d failed (%.1fms)\n"):format(#M.tests - failures, failures, elapsed))
  if failures > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("cquit 0")
  end
end

load_test_files()
run()

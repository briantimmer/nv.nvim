-- Test helpers for nv.nvim headless tests.
local M = {}

local nv = require("nv")

local scratch = vim.env.NV_TEST_NOTES_DIR

-- Point the plugin at the scratch dir so tests never touch the user's notes
-- and note autocommands match the buffers the tests create.
nv.setup({
  notes_dir = scratch,
  extension = "md",
  auto_save = true,
  auto_save_delay = 300,
  wikilink_mapping = true,
})

function M.config()
  return nv.config
end

-- Re-run setup() with extra options merged over the current config.
function M.reload_with_config(opts)
  nv.setup(vim.tbl_deep_extend("force", nv.config, opts or {}))
end

-- Path of a (not yet existing) note inside the scratch notes dir.
function M.tmp_note(name)
  return scratch .. "/" .. name
end

function M.write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)
end

-- Open a fresh unnamed buffer and set its lines.
function M.buffer(lines)
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(lines, "\n", { plain = true }))
  return buf
end

-- True when the filesystem does not distinguish path case (e.g. APFS).
function M.case_insensitive_fs()
  local probe = scratch .. "/.nv_case_probe"
  vim.fn.writefile({ "x" }, probe)
  local flipped = (probe:gsub("probe", "PROBE"))
  local ok = vim.fn.filereadable(flipped) == 1
  os.remove(probe)
  return ok
end

return M

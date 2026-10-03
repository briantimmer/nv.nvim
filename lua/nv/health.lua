-- lua/nv/health.lua
local M = {}

local health = vim.health or require("health")

-- Minimum Neovim version required by the plugin
local MIN_VERSION = { 0, 10, 0 }

function M.check()
  health.start("nv.nvim")

  -- Neovim version
  local nvim = vim.version()
  local ok_version, why = pcall(vim.version.ge, nvim, MIN_VERSION)
  if ok_version and why then
    health.ok(
      ("Neovim %d.%d.%d (>= %d.%d.%d required)"):format(
        nvim.major,
        nvim.minor,
        nvim.patch,
        MIN_VERSION[1],
        MIN_VERSION[2],
        MIN_VERSION[3]
      )
    )
  else
    health.error(("Neovim is too old (>= %d.%d.%d required)"):format(MIN_VERSION[1], MIN_VERSION[2], MIN_VERSION[3]))
  end

  -- snacks.nvim dependency
  local has_snacks = pcall(require, "snacks")
  if has_snacks then
    health.ok("snacks.nvim loaded")
  else
    health.error("snacks.nvim is not installed", "Install folke/snacks.nvim (e.g. via vim.pack.add() or lazy.nvim)")
  end

  -- Notes directory
  local nv = require("nv")
  local ok_nb, nb = pcall(nv.notebook)
  if not ok_nb or not nb then
    health.error("failed to load notebook", tostring(nb))
  else
    local notes_dir = nb.root
    if notes_dir == "" then
      health.error("notes_dir is empty", "Set notes_dir in require('nv').setup({})")
    elseif vim.fn.isdirectory(notes_dir) == 0 then
      health.warn(
        ("notes_dir does not exist: %s"):format(notes_dir),
        "It will be created on setup(); use :NV to start writing notes."
      )
    else
      local writable = vim.fn.filewritable(notes_dir)
      if writable == 2 then
        health.ok(("notes_dir exists and is writable: %s"):format(notes_dir))
      else
        health.error(("notes_dir is not writable: %s"):format(notes_dir))
      end
    end

    -- Extension
    local ext = nb.ext or "md"
    health.info(("notes extension: .%s"):format(ext:gsub("^%.", "")))
  end

  -- Feature flags
  if nv.config.auto_open_on_dir then
    health.info("auto_open_on_dir: enabled")
  else
    health.info("auto_open_on_dir: disabled")
  end
  if nv.config.auto_save then
    health.info(("auto_save: enabled (debounce %d ms)"):format(nv.config.auto_save_delay or 300))
  else
    health.info("auto_save: disabled")
  end
  if nv.config.wikilink_mapping then
    health.info("wikilink_mapping: enabled (<CR> follows WikiLinks in notes)")
  else
    health.info("wikilink_mapping: disabled")
  end

  -- Picker layout
  local layout = nv.config.picker_layout
  local layouts = require("nv.layouts")
  if type(layout) == "string" and has_snacks and not layouts.is_valid(layout) then
    health.warn(
      ("unknown picker_layout: %s (predefined layouts: %s)"):format(
        layout,
        table.concat(layouts.predefined_names(), ", ")
      ),
      "Any snacks.picker preset name or layout table is also valid; fix picker_layout in require('nv').setup()"
    )
  elseif type(layout) == "string" then
    health.info(("picker layout: %s"):format(layout))
  else
    health.info("picker layout: custom")
  end
end

return M

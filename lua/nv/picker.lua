-- lua/nv/picker.lua
local nv = require("nv")

local M = {}

-- Helper to turn prompt text into a clean filename
local function clean_filename(prompt)
  return nv.clean_filename(prompt)
end

-- Resolve the picker associated with the given snacks.win (input window),
-- instead of relying on picker stack order.
local function picker_from_win(win)
  local win_handle = win and win.win
  if not win_handle then
    return nil
  end
  for _, picker in ipairs(require("snacks").picker.get()) do
    if picker.input and picker.input.win and picker.input.win.win == win_handle then
      return picker
    end
  end
  return nil
end

-- A window is a candidate for the main editor if it is non-floating and
-- not a sidebar (Neo-tree, NvimTree, oil, netrw) or a non-normal buffer.
local function is_editor_window(win)
  local config = vim.api.nvim_win_get_config(win)
  if config.relative ~= "" then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local buftype = vim.bo[buf].buftype
  local filetype = vim.bo[buf].filetype
  return buftype == ""
    and filetype ~= "neo-tree"
    and filetype ~= "NvimTree"
    and filetype ~= "oil"
    and filetype ~= "netrw"
end

-- Find the first valid non-floating, non-sidebar window
local function get_main_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_window(win) then
      return win
    end
  end
  return nil
end

-- Open or create a file (acting as the confirm handler)
local function open_or_create(picker, item)
  local current_line = vim.trim(picker.input:get() or "")

  -- Stop insert mode and close the picker
  vim.cmd.stopinsert()
  picker:close()

  -- Schedule opening/creating the file to happen after the picker is fully closed
  vim.schedule(function()
    local main_win = get_main_window()
    if main_win then
      vim.api.nvim_set_current_win(main_win)
    end

    if item and item.file then
      -- 1. Open existing note
      nv.open_note(item.file)
    elseif current_line and current_line ~= "" then
      -- 2. Create new note with the prompt text
      local filename = clean_filename(current_line)
      nv.open_note(nv.config.notes_dir .. "/" .. filename, current_line)
    else
      print("nv.nvim: No search query or selection provided.")
    end
  end)
end

-- Resolve layout config: if it's a string reference, resolve it from layouts
local function resolve_layout(layout_config)
  if type(layout_config) == "string" then
    local layouts = require("nv.layouts")
    return layouts[layout_config] or layout_config
  end
  return layout_config
end

-- Main picker function using snacks.nvim
function M.search_notes()
  -- Ensure snacks is loaded
  local has_snacks, snacks = pcall(require, "snacks")
  if not has_snacks then
    error("nv.nvim: snacks.nvim is required for this plugin to work.")
  end

  local layout = resolve_layout(nv.config.picker_layout)

  snacks.picker.files({
    cwd = nv.config.notes_dir,
    title = "Notational Velocity Notes",
    layout = layout,
    confirm = open_or_create, -- Use open_or_create as the confirm action
    win = {
      input = {
        keys = {
          -- Ctrl-y to force-create a new note with prompt, even if matches exist
          ["<C-y>"] = {
            function(win)
              local active_picker = picker_from_win(win)
              if active_picker then
                open_or_create(active_picker, nil) -- passing nil for item forces creation
              end
            end,
            mode = { "i", "n" },
          },
        },
      },
    },
  })
end

return M

-- lua/nv/picker.lua
local nv = require("nv")

local M = {}

-- Helper to turn prompt text into a clean filename
local function clean_filename(prompt)
  return nv.clean_filename(prompt)
end

-- Find the first valid non-floating, non-sidebar window
local function get_main_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      local buftype = vim.bo[buf].buftype
      local filetype = vim.bo[buf].filetype
      if buftype == "" and filetype ~= "neo-tree" and filetype ~= "NvimTree" and filetype ~= "oil" and filetype ~= "netrw" then
        return win
      end
    end
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative == "" then
      return win
    end
  end
  return nil
end

-- Open or create a file
local function open_or_create(win, force_new)
  local snacks = require("snacks")
  local picker = snacks.picker.get()[1]
  if not picker then
    print("nv.nvim: Active picker not found.")
    return
  end

  local item = picker:current()
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

    if item and item.file and not force_new then
      -- 1. Open existing note
      vim.cmd("edit " .. item.file)
    elseif current_line and current_line ~= "" then
      -- 2. Create new note with the prompt text
      local filename = clean_filename(current_line)
      local filepath = nv.config.notes_dir .. "/" .. filename
      
      -- Ensure the parent directory exists
      local dir = vim.fn.fnamemodify(filepath, ":h")
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end
      
      -- Edit the file
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      
      -- Insert the prompt text as the H1 title in the new note
      local title = "# " .. current_line
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { title, "", "" })
      vim.cmd("write")
    else
      print("nv.nvim: No search query or selection provided.")
    end
  end)
end

-- Main picker function using snacks.nvim
function M.search_notes()
  -- Ensure snacks is loaded
  local has_snacks, snacks = pcall(require, "snacks")
  if not has_snacks then
    error("nv.nvim: snacks.nvim is required for this plugin to work.")
  end

  snacks.picker.files({
    cwd = nv.config.notes_dir,
    title = "Notational Velocity Notes",
    win = {
      input = {
        keys = {
          -- Replace Enter to open selected, or create file if selection is empty
          ["<CR>"] = {
            function(picker)
              open_or_create(picker, false)
            end,
            mode = { "i", "n" },
          },
          -- Ctrl-y to force-create a new note with prompt, even if matches exist
          ["<C-y>"] = {
            function(picker)
              open_or_create(picker, true)
            end,
            mode = { "i", "n" },
          },
        },
      },
    },
  })
end

return M

-- lua/nv/init.lua
local M = {}

local notebook_cache = nil

local function get_notebook()
  if notebook_cache then
    return notebook_cache
  end
  local Notebook = require("nv.notebook").Notebook
  notebook_cache = Notebook.new(M.config)
  return notebook_cache
end

-- Expose layouts module for user reference
M.layouts = require("nv.layouts")

-- Default options
M.config = {
  notes_dir = vim.fn.expand("~/notes"), -- Default directory for notes
  extension = "md", -- Default file extension (.md)
  auto_open_on_dir = true, -- Auto-open NV if directory is opened
  auto_save = true, -- Auto-save notes on change
  auto_save_delay = 300, -- Auto-save debounce (ms)
  wikilink_mapping = true, -- Map <CR> to follow WikiLinks in notes
  picker_layout = "default", -- snacks.picker layout name or custom config table
}

-- Setup function to override defaults
function M.notebook()
  return get_notebook()
end

function M.setup(user_opts)
  M.config = vim.tbl_deep_extend("force", M.config, user_opts or {})
  notebook_cache = nil

  local nb = get_notebook()
  M.config.notes_dir = nb.root
  M.config.extension = nb.ext
  local ok, err = nb:ensure()
  if not ok then
    vim.notify(tostring(err or "failed to create notes directory"), vim.log.levels.ERROR)
  end

  -- Register WikiLink autocommands
  M.register_autocmds()
end

-- Helper to turn text into a clean filename
function M.clean_filename(prompt)
  -- Strip ASCII punctuation that is unsafe in filenames, but preserve bytes
  -- >= 0x80 so Unicode letters and symbols survive (Lua's %w is ASCII-only).
  local clean = (prompt or "")
    :gsub("[^%w%s%-/_%.\128-\255]", "")
    :gsub("%s+", "-") -- whitespace runs -> dash
    :gsub("%-+", "-") -- collapse dash runs
    :gsub("^[%-.]+", "") -- strip leading dashes/dots
    :gsub("[%-.%/]+$", "") -- strip trailing dashes/dots/slashes
    :lower()

  -- Drop empty, "." and ".." path segments so note titles cannot traverse out
  -- of notes_dir (e.g. "a/../../etc") while still allowing subdirectories.
  local segments = {}
  for segment in clean:gmatch("[^/]+") do
    if segment ~= "." and segment ~= ".." then
      segments[#segments + 1] = segment
    end
  end
  clean = table.concat(segments, "/")

  -- Guard against empty/garbage input
  if clean == "" then
    clean = "untitled-" .. os.date("%Y-%m-%d-%H%M%S")
  end

  -- Avoid duplicating the extension (e.g. a query ending in ".md")
  if clean:sub(-#M.config.extension - 1) ~= "." .. M.config.extension then
    clean = clean .. "." .. M.config.extension
  end
  return clean
end

-- Open an existing note, or create it (with an H1 title) if it doesn't exist
function M.open_note(filepath, title)
  return get_notebook():open_path(filepath, title)
end

-- Navigate WikiLink under cursor
function M.follow_link()
  local line = vim.api.nvim_get_current_line()
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1

  -- Find nearest '[[' to the left
  local left = nil
  for i = col + 1, 1, -1 do
    if line:sub(i - 1, i) == "[[" then
      left = i + 1
      break
    end
  end

  -- Find nearest ']]' to the right
  local right = nil
  for i = math.max(col - 1, 1), #line do
    if line:sub(i, i + 1) == "]]" then
      right = i - 1
      break
    end
  end

  if left and right and left <= right then
    local link = line:sub(left, right)
    if not link:find("[%[%]]") then
      local filename = M.clean_filename(link)
      local filepath = M.config.notes_dir .. "/" .. filename

      -- Schedule the navigation to run outside the restricted expression evaluation context
      vim.schedule(function()
        M.open_note(filepath, link)
      end)
      return ""
    end
  end

  return "<CR>"
end

-- Resolve a path to its canonical form so directory comparisons survive
-- symlinks and case differences on case-insensitive filesystems (e.g. APFS).
-- Falls back to the absolute path if the OS cannot resolve it.
function M._normalize_path(path)
  local real = vim.uv.fs_realpath(path)
  if real then
    return real
  end
  local expanded = vim.fn.fnamemodify(path, ":p")
  if expanded:sub(-1) == "/" or expanded:sub(-1) == "\\" then
    expanded = expanded:sub(1, -2)
  end
  return expanded
end

-- True when the buffer is a modified, normal-type note buffer.
local function is_saveable_note(buf)
  return vim.bo[buf].modified and vim.bo[buf].buftype == ""
end

function M.register_autocmds()
  local group = vim.api.nvim_create_augroup("nv_autocmds", { clear = true })

  -- In autocmd patterns `*` already matches across path separators, so a
  -- single pattern covers root and nested notes. Escape metacharacters in
  -- the directory path so it is matched literally.
  local nb = get_notebook()
  local note_patterns = {
    nb:autocmd_pattern(),
  }

  -- When entering a note buffer, map <CR> to follow WikiLinks
  if M.config.wikilink_mapping then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      pattern = note_patterns,
      callback = function()
        vim.keymap.set("n", "<CR>", M.follow_link, {
          buffer = true,
          expr = true,
          desc = "Follow WikiLink under cursor",
        })
      end,
    })
  end

  -- Auto-save notes on change, debounced so rapid typing doesn't rewrite the
  -- whole buffer on every keystroke. Leaving insert mode flushes immediately.
  if M.config.auto_save then
    local save_timers = {}
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
      group = group,
      pattern = note_patterns,
      callback = function(args)
        if not is_saveable_note(args.buf) then
          return
        end

        local timer = save_timers[args.buf]
        if timer then
          timer:stop()
          save_timers[args.buf] = nil
        end

        if args.event == "InsertLeave" then
          vim.cmd("silent! write")
          return
        end

        save_timers[args.buf] = vim.defer_fn(function()
          save_timers[args.buf] = nil
          if vim.api.nvim_buf_is_valid(args.buf) and is_saveable_note(args.buf) then
            vim.api.nvim_buf_call(args.buf, function()
              vim.cmd("silent! write")
            end)
          end
        end, M.config.auto_save_delay)
      end,
    })
  end

  -- Auto-open NV if notes directory is opened
  if M.config.auto_open_on_dir then
    vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
      group = group,
      callback = function(args)
        local bufname = vim.api.nvim_buf_get_name(args.buf)
        if bufname == "" then
          return
        end

        local nb2 = get_notebook()
        if nb2:is_root(bufname) then
          -- Defer by 50ms to allow lazy-loaded Neo-tree and directory explorer to finish rendering first
          vim.defer_fn(function()
            -- Close Neo-tree if it was opened
            if vim.fn.exists(":Neotree") == 2 then
              pcall(function()
                require("neo-tree.command").execute({ action = "close" })
              end)
            end

            -- Delete the directory buffer if valid
            if vim.api.nvim_buf_is_valid(args.buf) then
              pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
            end

            -- Launch NV picker
            require("nv.picker").search_notes()
          end, 50)
        end
      end,
    })
  end
end

return M

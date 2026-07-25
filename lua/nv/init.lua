-- lua/nv/init.lua
local M = {}

-- Default options
M.config = {
  notes_dir = vim.fn.expand("~/notes"), -- Default directory for notes
  extension = "md",                     -- Default file extension (.md)
  auto_open_on_dir = true,              -- Auto-open NV if directory is opened
}

-- Setup function to override defaults
function M.setup(user_opts)
  M.config = vim.tbl_deep_extend("force", M.config, user_opts or {})
  
  -- Create the notes directory if it doesn't exist
  if vim.fn.isdirectory(M.config.notes_dir) == 0 then
    vim.fn.mkdir(M.config.notes_dir, "p")
  end

  -- Register WikiLink autocommands
  M.register_autocmds()
end

-- Helper to turn text into a clean filename
function M.clean_filename(prompt)
  local clean = prompt:gsub("[^%w%s%-/]", ""):gsub("%s+", "-"):lower()
  return clean .. "." .. M.config.extension
end

-- Navigate WikiLink under cursor
function M.follow_link()
  local line = vim.api.nvim_get_current_line()
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1

  -- Find nearest '[[' to the left
  local left = nil
  for i = col, 1, -1 do
    if line:sub(i - 1, i) == "[[" then
      left = i + 1
      break
    end
  end

  -- Find nearest ']]' to the right
  local right = nil
  for i = col, #line do
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
        -- Ensure the parent directory exists
        local dir = vim.fn.fnamemodify(filepath, ":h")
        if vim.fn.isdirectory(dir) == 0 then
          vim.fn.mkdir(dir, "p")
        end

        -- Edit the file
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))

        -- If it's a new file, write heading
        if vim.fn.filereadable(filepath) == 0 then
          local title = "# " .. link
          vim.api.nvim_buf_set_lines(0, 0, -1, false, { title, "", "" })
          vim.cmd("write")
        end
      end)
      return ""
    end
  end

  return "<CR>"
end

function M.register_autocmds()
  local group = vim.api.nvim_create_augroup("nv_autocmds", { clear = true })
  
  -- When entering a note buffer, map <CR> to follow WikiLinks
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = M.config.notes_dir .. "/**/*." .. M.config.extension,
    callback = function()
      vim.keymap.set("n", "<CR>", M.follow_link, {
        buffer = true,
        expr = true,
        desc = "Follow WikiLink under cursor",
      })
    end,
  })

  -- Auto-save notes on change
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    pattern = M.config.notes_dir .. "/**/*." .. M.config.extension,
    callback = function()
      if vim.bo.modified and vim.bo.buftype == "" then
        vim.cmd("silent! write")
      end
    end,
  })

  -- Auto-open NV if notes directory is opened
  if M.config.auto_open_on_dir then
    vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
      group = group,
      callback = function(args)
        local bufname = vim.api.nvim_buf_get_name(args.buf)
        if bufname == "" then return end

        local path = vim.fn.fnamemodify(bufname, ":p")
        -- Normalize trailing slashes
        if path:sub(-1) == "/" or path:sub(-1) == "\\" then
          path = path:sub(1, -2)
        end

        local notes_path = vim.fn.fnamemodify(M.config.notes_dir, ":p")
        if notes_path:sub(-1) == "/" or notes_path:sub(-1) == "\\" then
          notes_path = notes_path:sub(1, -2)
        end

        if path == notes_path then
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

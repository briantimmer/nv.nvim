-- lua/nv/init.lua
local M = {}

-- Default options
M.config = {
  notes_dir = vim.fn.expand("~/notes"), -- Default directory for notes
  extension = "md",                     -- Default file extension (.md)
}

-- Setup function to override defaults
function M.setup(user_opts)
  M.config = vim.tbl_deep_extend("force", M.config, user_opts or {})
  
  -- Create the notes directory if it doesn't exist
  if vim.fn.isdirectory(M.config.notes_dir) == 0 then
    vim.fn.mkdir(M.config.notes_dir, "p")
  end
end

return M

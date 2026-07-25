-- plugin/nv.lua

-- Prevent reloading twice
if vim.g.loaded_nv_nvim then
  return
end
vim.g.loaded_nv_nvim = true

-- Register user command
vim.api.nvim_create_user_command("NV", function()
  require("nv.picker").search_notes()
end, {})

-- lua/nv/layouts.lua
-- Predefined picker layouts for snacks.nvim

local M = {}

-- Compact vertical layout: short list, tall preview/editor
M.vertical_compact = {
  layout = {
    backdrop = false,
    width = 0.6,
    min_width = 60,
    height = 0.9,
    min_height = 30,
    box = "vertical",
    border = true,
    title = "{title} {live} {flags}",
    title_pos = "center",
    { win = "input", height = 1, border = "bottom" },
    { win = "list", height = 0.25, border = "none" },
    { win = "preview", title = "{preview}", height = 0.75, border = "top" },
  },
}

-- Balanced vertical layout: equal split between list and preview
M.vertical_balanced = {
  layout = {
    backdrop = false,
    width = 0.6,
    min_width = 60,
    height = 0.9,
    min_height = 30,
    box = "vertical",
    border = true,
    title = "{title} {live} {flags}",
    title_pos = "center",
    { win = "input", height = 1, border = "bottom" },
    { win = "list", height = 0.5, border = "none" },
    { win = "preview", title = "{preview}", height = 0.5, border = "top" },
  },
}

-- Wide layout: larger modal with more screen real estate
M.vertical_wide = {
  layout = {
    backdrop = false,
    width = 0.8,
    min_width = 80,
    height = 0.95,
    min_height = 30,
    box = "vertical",
    border = true,
    title = "{title} {live} {flags}",
    title_pos = "center",
    { win = "input", height = 1, border = "bottom" },
    { win = "list", height = 0.3, border = "none" },
    { win = "preview", title = "{preview}", height = 0.7, border = "top" },
  },
}

-- Sorted names of the layouts predefined in this module (the table entries)
function M.predefined_names()
  local names = {}
  for name, value in pairs(M) do
    if type(value) == "table" then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

-- True when value is usable as a picker layout: a predefined layout, a
-- snacks.picker preset name (built-in or user-registered), or a layout
-- table/function as accepted by snacks.picker. When snacks.nvim cannot be
-- consulted (not installed yet), string values are assumed valid so that
-- validation itself never blocks usage.
function M.is_valid(value)
  local kind = type(value)
  if kind == "table" or kind == "function" then
    return true
  elseif kind ~= "string" then
    return false
  elseif M[value] ~= nil then
    return true
  end

  -- Not predefined: defer to snacks for its built-in and registered presets.
  local consultable = false
  local ok_presets, presets = pcall(require, "snacks.picker.config.layouts")
  if ok_presets then
    consultable = true
    if presets[value] ~= nil then
      return true
    end
  end

  local ok_config, config = pcall(require, "snacks.picker.config")
  if ok_config and type(config.get) == "function" then
    local ok_get, merged = pcall(config.get)
    if ok_get and type(merged) == "table" then
      consultable = true
      if merged.layouts and merged.layouts[value] ~= nil then
        return true
      end
    end
  end

  return not consultable
end

-- Default snacks layouts (pass through)
M.default = "default"
M.vertical = "vertical"
M.sidebar = "sidebar"
M.telescope = "telescope"
M.ivy = "ivy"
M.ivy_split = "ivy_split"
M.dropdown = "dropdown"
M.select = "select"

return M

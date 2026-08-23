-- lua/nv/layouts.lua
-- Predefined picker layouts for snacks.nvim

local M = {}

-- Compact vertical layout: short list, tall preview/editor
M.vertical_compact = {
  layout = {
    backdrop = false,
    width = 0.6,
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

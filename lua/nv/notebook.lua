-- lua/nv/notebook.lua
local M = {}

---@class nv.Notebook
---@field root string  -- absolute, no trailing slash, ~ and $VAR expanded (read-only)
---@field ext  string  -- lowercase, no leading dot (read-only)
local Notebook = {}
Notebook.__index = Notebook

local function normalize_root(notes_dir)
  if type(notes_dir) ~= "string" or notes_dir == "" then
    error("notes_dir must be a non-empty string")
  end

  local expanded = vim.fs.normalize(notes_dir)
  if expanded == nil or expanded == "" then
    expanded = notes_dir
  end

  -- Make absolute if relative
  if expanded:sub(1, 1) ~= "/" and expanded:sub(2, 2) ~= ":" then
    local cwd = vim.fn.getcwd()
    expanded = cwd .. "/" .. expanded
    expanded = vim.fs.normalize(expanded) or expanded
  end

  -- Strip trailing slashes
  while expanded:sub(-1) == "/" and #expanded > 1 do
    expanded = expanded:sub(1, -2)
  end

  return expanded
end

local function normalize_ext(extension)
  if type(extension) ~= "string" or extension == "" then
    return "md"
  end

  -- Strip leading dots
  local ext = extension:gsub("^%.+", "")
  if ext == "" then
    ext = "md"
  end

  return ext:lower()
end

local function sanitize_filename(prompt)
  local clean = (prompt or "")
    :gsub("[^%w%s%-/_%.\128-\255]", "")
    :gsub("%s+", "-")
    :gsub("%-+", "-")
    :gsub("^[%-.]+", "")
    :gsub("[%-.%/]+$", "")
    :lower()

  local segments = {}
  for segment in clean:gmatch("[^/]+") do
    if segment ~= "." and segment ~= ".." then
      segments[#segments + 1] = segment
    end
  end
  clean = table.concat(segments, "/")

  if clean == "" then
    clean = "untitled-" .. os.date("%Y-%m-%d-%H%M%S")
  end

  return clean
end

function Notebook.new(opts, deps)
  opts = opts or {}
  local root = normalize_root(opts.notes_dir)
  local ext = normalize_ext(opts.extension)

  local self = {
    root = root,
    ext = ext,
    _deps = deps or {},
  }
  setmetatable(self, Notebook)
  return self
end

function Notebook:ensure()
  local ok, err = pcall(vim.fn.mkdir, self.root, "p")
  if ok then
    return true, nil
  else
    return false, err
  end
end

function Notebook:rel(title)
  local rel = sanitize_filename(title)
  if rel:sub(-#self.ext - 1) ~= "." .. self.ext then
    rel = rel .. "." .. self.ext
  end
  return rel
end

function Notebook:path(title)
  local rel = self:rel(title)
  return vim.fs.normalize(self.root .. "/" .. rel) or (self.root .. "/" .. rel)
end

function Notebook._realpath(p)
  if type(p) ~= "string" then
    return nil
  end
  local real = vim.uv.fs_realpath(p)
  if real then
    return real
  end
  local expanded = vim.fn.fnamemodify(p, ":p")
  while expanded:sub(-1) == "/" or expanded:sub(-1) == "\\" do
    expanded = expanded:sub(1, -2)
    if #expanded == 0 then
      break
    end
  end
  return expanded
end

local function join_path(base, rest)
  if rest == "" then
    return base
  end
  return vim.fs.normalize(base .. "/" .. rest) or (base .. "/" .. rest)
end

local function path_with_trailing_sep(p)
  if p:sub(-1) == "/" then
    return p
  end
  return p .. "/"
end

local function deepest_existing_ancestor(p)
  local cur = vim.uv.fs_realpath(p)
  if cur then
    return cur
  end

  local parent = vim.fn.fnamemodify(p, ":h")
  if parent == p then
    return nil
  end

  return deepest_existing_ancestor(parent)
end

function Notebook:contains(p)
  if type(p) ~= "string" then
    return false
  end

  local root_real = vim.uv.fs_realpath(self.root)
  if not root_real then
    root_real = self.root
  end
  local root_sep = path_with_trailing_sep(root_real)

  local p_real = vim.uv.fs_realpath(p)
  if p_real then
    if p_real == root_real then
      return false
    end
    local p_sep = path_with_trailing_sep(p_real)
    if p_sep:sub(1, #root_sep) == root_sep then
      return true
    end
    return false
  end

  local ancestor = deepest_existing_ancestor(p)
  if not ancestor then
    return false
  end
  local ancestor_sep = path_with_trailing_sep(ancestor)
  if ancestor_sep:sub(1, #root_sep) ~= root_sep then
    return false
  end

  local remaining = p:gsub("^" .. vim.pesc(ancestor), "")
  remaining = remaining:gsub("^[/\\]+", "")
  if remaining == "" then
    return false
  end

  for segment in remaining:gmatch("[^/\\]+") do
    if segment == "." or segment == ".." then
      return false
    end
  end

  return true
end

function Notebook:is_root(p)
  if type(p) ~= "string" then
    return false
  end
  local root_real = vim.uv.fs_realpath(self.root)
  if not root_real then
    root_real = self.root
  end
  local p_real = vim.uv.fs_realpath(p)
  if not p_real then
    local expanded = vim.fn.fnamemodify(p, ":p")
    while expanded:sub(-1) == "/" or expanded:sub(-1) == "\\" do
      expanded = expanded:sub(1, -2)
      if #expanded == 0 then
        break
      end
    end
    p_real = expanded
  end
  return root_real == p_real
end

function Notebook:autocmd_pattern()
  local root = self.root
  local escaped = vim.fn.escape(root, "\\*?[]{}~$,")
  return escaped .. "/*." .. self.ext
end

setmetatable(M, { __index = Notebook })
M.Notebook = Notebook
M.new = Notebook.new

local function create_exclusive(path, title)
  local fd, err = vim.uv.fs_open(path, "wx", 420)
  if not fd then
    local msg = tostring(err or "")
    if msg:match("EEXIST") or msg:match("File exists") or msg:match("already exists") then
      return false, nil
    end
    return false, err
  end

  local content = "# " .. title .. "\n\n\n"
  vim.uv.fs_write(fd, content, -1)
  vim.uv.fs_close(fd)
  return true, nil
end

function Notebook:_edit(path)
  if self._deps.edit and type(self._deps.edit) == "function" then
    self._deps.edit(path)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function Notebook:open(title)
  if type(title) ~= "string" then
    return nil, "title must be a string"
  end

  local path = self:path(title)
  local parent = vim.fn.fnamemodify(path, ":h")
  pcall(vim.fn.mkdir, parent, "p")

  local created, err = create_exclusive(path, title)
  if err then
    return nil, err
  end

  self:_edit(path)
  return path, created
end

function Notebook:open_path(p, title)
  if type(p) ~= "string" then
    return nil, "path must be a string"
  end

  local resolved
  if p:sub(1, 1) == "/" or p:sub(2, 2) == ":" then
    resolved = vim.fs.normalize(p) or p
  else
    resolved = vim.fs.normalize(self.root .. "/" .. p) or (self.root .. "/" .. p)
  end

  local inside = self:contains(resolved)
  local is_root_path = self:is_root(resolved)

  if inside or is_root_path then
    if type(title) == "string" and title ~= "" then
      local parent = vim.fn.fnamemodify(resolved, ":h")
      pcall(vim.fn.mkdir, parent, "p")
      local created, err = create_exclusive(resolved, title)
      if err then
        return nil, err
      end
      self:_edit(resolved)
      return resolved, created
    end

    self:_edit(resolved)
    return resolved, false
  end

  self:_edit(resolved)
  return resolved, false
end

return M

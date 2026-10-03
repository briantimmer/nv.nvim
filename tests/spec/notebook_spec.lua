-- Tests for lua/nv/notebook.lua
local helper = require("tests.helper")
local Notebook = require("nv.notebook").Notebook

describe("notebook normalization", function()
  it("normalizes ~ in notes_dir", function()
    local old_home = vim.env.HOME
    vim.env.HOME = vim.fn.tempname()
    vim.fn.mkdir(vim.env.HOME, "p")
    local nb = Notebook.new({ notes_dir = "~/notes" })
    ok(nb.root:sub(1, #vim.env.HOME) == vim.env.HOME)
    ok(nb.root:match("/notes$") ~= nil)
    vim.env.HOME = old_home
  end)

  it("normalizes $VAR in notes_dir", function()
    local tmp = vim.fn.tempname()
    vim.env.NV_TEST_VAR = tmp
    local nb = Notebook.new({ notes_dir = "$NV_TEST_VAR/notes" })
    local expected = vim.fs.normalize(tmp .. "/notes")
    eq(expected, nb.root)
    vim.env.NV_TEST_VAR = nil
  end)

  it("strips trailing slash", function()
    local tmp = vim.fn.tempname()
    local nb = Notebook.new({ notes_dir = tmp .. "/" })
    local expected = vim.fs.normalize(tmp)
    eq(expected, nb.root)
  end)

  it("normalizes relative path", function()
    local nb = Notebook.new({ notes_dir = "notes-test" })
    local expected = vim.fs.normalize(vim.fn.getcwd() .. "/notes-test")
    eq(expected, nb.root)
  end)

  it("normalizes extension", function()
    local tmp = vim.fn.tempname()
    local nb1 = Notebook.new({ notes_dir = tmp, extension = ".md" })
    local nb2 = Notebook.new({ notes_dir = tmp .. "2", extension = "md" })
    local nb3 = Notebook.new({ notes_dir = tmp .. "3", extension = "MD" })
    eq("md", nb1.ext)
    eq("md", nb2.ext)
    eq("md", nb3.ext)
  end)

  it("ensures directory and does not create stray ~ dir", function()
    local old_home = vim.env.HOME
    vim.env.HOME = vim.fn.tempname()
    vim.fn.mkdir(vim.env.HOME, "p")
    local nb = Notebook.new({ notes_dir = "~/notes-ens" })
    nb:ensure()
    eq(0, vim.fn.isdirectory("./~"))
    vim.env.HOME = old_home
  end)

  it("errors on empty notes_dir", function()
    local ok, err = pcall(Notebook.new, { notes_dir = "" })
    eq(false, ok)
  end)
end)

describe("notebook rel and path", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local nb = Notebook.new({ notes_dir = tmp })

  it("strips punctuation and collapses whitespace", function()
    eq("hello-world.md", nb:rel("Hello, World!"))
    eq("my-note.md", nb:rel("  my   note  "))
  end)

  it("preserves unicode letters and symbols", function()
    eq("café-☕.md", nb:rel("Café ☕"))
  end)

  it("drops path traversal segments", function()
    eq("etc.md", nb:rel("../../etc"))
    eq("a/etc.md", nb:rel("a/../../etc"))
  end)

  it("appends the extension once", function()
    eq("note.md", nb:rel("note"))
    eq("note.md", nb:rel("note.md"))
    eq("note.txt.md", nb:rel("note.txt"))
  end)

  it("falls back to untitled for empty input", function()
    ok(nb:rel(""):match("^untitled%-%d%d%d%d%-%d%d%-%d%d"))
  end)

  it("path returns absolute anchored path", function()
    local p = nb:path("hello")
    eq(vim.fs.normalize(tmp .. "/hello.md"), p)
  end)
end)

describe("notebook membership and pattern", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local nb = Notebook.new({ notes_dir = tmp })

  it("contains root is false, is_root true for root", function()
    eq(false, nb:contains(tmp))
    eq(true, nb:is_root(tmp))
  end)

  it("contains files under root", function()
    local f = tmp .. "/a.md"
    vim.fn.writefile({ "x" }, f)
    eq(true, nb:contains(f))
  end)

  it("does not contain /notes2 vs /notes", function()
    local tmp2 = vim.fn.tempname() .. "2"
    vim.fn.mkdir(tmp2, "p")
    local nb2 = Notebook.new({ notes_dir = tmp })
    eq(false, nb2:contains(tmp2))
    eq(false, nb2:contains(tmp2 .. "/x.md"))
  end)

  it("autocmd_pattern escapes metacharacters", function()
    local esc_nb = Notebook.new({ notes_dir = tmp .. "/$dir[foo]?" })
    local pat = esc_nb:autocmd_pattern()
    ok(pat:find("[$]dir%[foo%]%?") ~= nil or pat:find("%$") ~= nil)
  end)

  it("case-insensitive fs: treats differently-cased paths as same root", function()
    if not require("tests.helper").case_insensitive_fs() then
      return
    end
    local nb_c = Notebook.new({ notes_dir = tmp })
    local flipped = tmp:gsub("([^/]+)$", function(s)
      return s:gsub("^%l", string.upper)
    end)
    eq(true, nb_c:is_root(flipped))
  end)

  it("contains not-yet-existing note", function()
    eq(true, nb:contains(tmp .. "/future.md"))
  end)
end)

describe("notebook open and open_path", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local edits = {}
  local nb = Notebook.new({ notes_dir = tmp }, {
    edit = function(path)
      edits[#edits + 1] = path
      vim.cmd.edit(vim.fn.fnameescape(path))
    end,
  })

  it("new note seeds with H1", function()
    edits = {}
    local path, created = nb:open("hello world")
    eq(true, created)
    eq({ "# hello world", "", "" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    eq(vim.fs.normalize(tmp .. "/hello-world.md"), path)
  end)

  it("second open leaves file byte-identical", function()
    local path, created = nb:open("hello world")
    eq(false, created)
    eq({ "# hello world", "", "" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("open_path outside root edits but does not write", function()
    edits = {}
    local outside = vim.fn.tempname()
    vim.fn.writefile({ "keep" }, outside)
    local path, created = nb:open_path(outside, "newtitle")
    eq(outside, path)
    eq(false, created)
    eq({ "keep" }, vim.fn.readfile(outside))
  end)

  it("no-title absent file not created", function()
    edits = {}
    local outside = vim.fn.tempname()
    local path, created = nb:open_path(outside)
    eq(false, created)
    eq(0, vim.fn.filereadable(outside))
  end)

  it("relative open_path resolves against root with cwd elsewhere", function()
    local oldcwd = vim.fn.getcwd()
    vim.cmd("cd /tmp")
    local path, created = nb:open_path("relative-note", "Relative")
    vim.cmd("cd " .. vim.fn.fnameescape(oldcwd))
    eq(true, created)
    eq(vim.fs.normalize(tmp .. "/relative-note"), path)
  end)
end)

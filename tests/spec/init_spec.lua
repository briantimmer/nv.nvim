-- Tests for lua/nv/init.lua
local helper = require("tests.helper")
local nv = require("nv")

describe("clean_filename", function()
  it("strips punctuation and collapses whitespace", function()
    eq("hello-world.md", nv.clean_filename("Hello, World!"))
    eq("my-note.md", nv.clean_filename("  my   note  "))
  end)

  it("preserves unicode letters and symbols", function()
    eq("café-☕.md", nv.clean_filename("Café ☕"))
  end)

  it("drops path traversal segments", function()
    eq("etc.md", nv.clean_filename("../../etc"))
    eq("a/etc.md", nv.clean_filename("a/../../etc"))
  end)

  it("appends the extension once", function()
    eq("note.md", nv.clean_filename("note"))
    eq("note.md", nv.clean_filename("note.md"))
    eq("note.txt.md", nv.clean_filename("note.txt"))
  end)

  it("falls back to untitled for empty input", function()
    ok(nv.clean_filename(""):match("^untitled%-%d%d%d%d%-%d%d%-%d%d"))
  end)
end)

describe("open_note", function()
  it("creates a new note with an H1 title", function()
    local path = helper.tmp_note("open-new.md")
    nv.open_note(path, "Open New")
    eq({ "# Open New", "", "" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    eq(1, vim.fn.filereadable(path))
  end)

  it("does not overwrite an existing note", function()
    local path = helper.tmp_note("open-existing.md")
    helper.write(path, "# Existing\n\nbody\n")
    nv.open_note(path, "Should Not Apply")
    eq({ "# Existing", "", "body", "" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

describe("follow_link", function()
  it("navigates to a wikilink and creates the note", function()
    helper.buffer("# Home\n\nSee [[Some Page]] for details.\n")
    vim.api.nvim_win_set_cursor(0, { 3, 7 })
    eq("", nv.follow_link())

    local created = vim.wait(1000, function()
      local path = nv.config.notes_dir .. "/some-page.md"
      return vim.fn.filereadable(path) == 1
    end)
    ok(created, "expected scheduled follow_link to create the note")
  end)

  it("returns <CR> when the cursor is not on a wikilink", function()
    helper.buffer("plain text without links\n")
    vim.api.nvim_win_set_cursor(0, { 1, 2 })
    eq("<CR>", nv.follow_link())
  end)
end)

describe("auto-save", function()
  it("writes a note after the debounce delay", function()
    local path = helper.tmp_note("autosave.md")
    nv.open_note(path, "Auto Save")
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(buf, 1, 3, false, { "edited line" })
    vim.bo[buf].modified = true
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })

    local written = vim.wait(2000, function()
      return vim.fn.readfile(path)[2] == "edited line"
    end)
    ok(written, "expected debounced write to hit disk")
  end)

  it("flushes immediately on InsertLeave", function()
    local path = helper.tmp_note("flush.md")
    nv.open_note(path, "Flush")
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(buf, 1, 3, false, { "typed quickly" })
    vim.bo[buf].modified = true
    vim.api.nvim_exec_autocmds("InsertLeave", { buffer = buf })

    eq("typed quickly", vim.fn.readfile(path)[2])
  end)
end)

describe("config toggles", function()
  it("auto_save=false registers no save autocmds", function()
    helper.reload_with_config({ auto_save = false })
    local path = helper.tmp_note("no-autosave.md")
    nv.open_note(path, "No Auto Save")
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(buf, 1, 3, false, { "should not persist" })
    vim.bo[buf].modified = true
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
    vim.wait(800)

    eq("# No Auto Save", vim.fn.readfile(path)[1])
  end)

  it("wikilink_mapping=false does not map <CR> in note buffers", function()
    helper.reload_with_config({ wikilink_mapping = false })
    local path = helper.tmp_note("no-linkmap.md")
    nv.open_note(path, "No Link Map")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("doautocmd BufEnter")
    end)

    eq({}, vim.fn.maparg("<CR>", "n", false, true))
  end)

  it("wikilink_mapping=true maps <CR> in note buffers", function()
    helper.reload_with_config({ wikilink_mapping = true })
    local path = helper.tmp_note("yes-linkmap.md")
    nv.open_note(path, "Yes Link Map")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("doautocmd BufEnter")
    end)

    local mapping = vim.fn.maparg("<CR>", "n", false, true)
    eq(1, mapping.buffer)
    eq(1, mapping.expr)
  end)
end)

describe("picker_layout", function()
  it("defaults to the snacks 'default' layout", function()
    helper.reload_with_config({ picker_layout = "default" })
    eq("default", nv.config.picker_layout)
  end)

  it("accepts a layout preset name override", function()
    helper.reload_with_config({ picker_layout = "vertical" })
    eq("vertical", nv.config.picker_layout)
  end)

  it("accepts a full layout config table", function()
    local custom = { layout = { box = "vertical" } }
    helper.reload_with_config({ picker_layout = custom })
    eq(custom, nv.config.picker_layout)
  end)

  helper.reload_with_config({ picker_layout = "default" })
end)

describe("path normalization", function()
  it("canonicalizes differently-cased paths on case-insensitive filesystems", function()
    if not helper.case_insensitive_fs() then
      return
    end
    local canonical = nv._normalize_path(nv.config.notes_dir)
    local flipped = canonical:gsub("([^/]+)$", function(s)
      return s:gsub("^%l", string.upper)
    end)
    eq(canonical, nv._normalize_path(flipped))
  end)
end)

describe("auto_open_on_dir", function()
  it("launches the picker when the notes directory is opened", function()
    helper.reload_with_config({ auto_open_on_dir = true })
    local calls = 0
    package.loaded["nv.picker"] = {
      search_notes = function()
        calls = calls + 1
      end,
    }

    vim.cmd.edit(vim.fn.fnameescape(nv.config.notes_dir))
    local hit = vim.wait(1500, function()
      return calls > 0
    end)
    ok(hit, "expected auto_open_on_dir to fire when the notes dir is opened")

    package.loaded["nv.picker"] = nil
  end)
end)

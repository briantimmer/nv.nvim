# nv.nvim

A lightweight Neovim plugin written in Lua that replicates the fast "search-or-create" note-taking workflow of **Notational Velocity**.

Built on top of **snacks.nvim**.

## Features

- **Fast search-or-create:** Launch notes search. If a matching note exists, hit `Enter` to open it. If it doesn't exist, hit `Enter` to instantly create and open a new note named after your search query.
- **Force-create:** Press `Ctrl-y` in the search box to force-create a new note with your query even if other search results exist.
- **Auto-heading insertion:** Automatically populates the new note with a neat Markdown H1 title.
- **Auto-open on folder open:** Automatically intercepts Neovim starting in your notes folder and launches the search interface immediately.
- **WikiLinks:** `<CR>` follows `[[WikiLink]]` targets inside notes, creating them if they don't exist.
- **Auto-save:** notes are written to disk automatically after a debounce delay.

## Requirements

- Neovim >= 0.10 (>= 0.12 if using `vim.pack.add()`)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (for the picker)

## Installation

### Using lazy.nvim

Add this to your plugin spec:

```lua
{
  "briantimmer/nv.nvim",
  dependencies = { "folke/snacks.nvim" },
  event = "VeryLazy", -- or a keymap like keys = { { "<leader>n", "<cmd>NV<CR>", desc = "Notes" } }
  config = function()
    require("nv").setup({
      notes_dir         = vim.fn.expand("~/notes"), -- Directory for notes
      extension         = "md",                     -- Note file extension
      auto_open_on_dir  = true,                     -- Open picker when notes dir is opened
      auto_save         = true,                     -- Auto-save notes on change
      auto_save_delay   = 300,                      -- Auto-save debounce in ms
      wikilink_mapping  = true,                     -- Map <CR> to follow WikiLinks
      picker_layout     = "default",                -- Layout: see Picker Layouts below
    })
  end,
}
```

### Using Neovim 0.12's Built-in Package Manager (`vim.pack.add()`)

Add this entry to your Neovim initialization configuration (e.g. `init.lua`):

```lua
-- 1. Load snacks.nvim and nv.nvim
vim.pack.add({
  "https://github.com/folke/snacks.nvim",
  "https://github.com/briantimmer/nv.nvim",
})

-- 2. Load the plugin and configure nv.nvim
vim.cmd.packadd("nv.nvim")

local nv = require("nv")
nv.setup({
  notes_dir         = vim.fn.expand("~/notes"),      -- Directory for notes
  extension         = "md",                          -- Note file extension
  auto_open_on_dir  = true,                          -- Open picker when notes dir is opened
  auto_save         = true,                          -- Auto-save notes on change
  auto_save_delay   = 300,                           -- Auto-save debounce in ms
  wikilink_mapping  = true,                          -- Map <CR> to follow WikiLinks
  picker_layout     = nv.layouts.vertical_compact,   -- See Picker Layouts below
})

-- 3. Bind a key to trigger the search
vim.keymap.set("n", "<leader>n", "<cmd>NV<CR>", { desc = "Notational Velocity Notes" })
```

## Picker Layouts

Customize how the search modal is laid out. Built-in options:

- **`nv.layouts.vertical_compact`** — Input on top, short list (25%), tall preview/editor (75%) — great for editing notes
- **`nv.layouts.vertical_balanced`** — Input on top, 50/50 split between list and preview
- **`nv.layouts.vertical_wide`** — Larger modal (80% width) with short list and tall preview
- **`"default"`** — List and preview side-by-side (snacks.nvim default)
- **`"vertical"`** — Stack input/list/preview vertically (snacks.nvim standard)
- Any other snacks.nvim layout name or a custom table (unknown names warn and fall back to `"default"`)

Example:

```lua
nv.setup({
  picker_layout = nv.layouts.vertical_compact,
})
```

## Usage

1. Press your keymap (e.g., `<leader>n`) or type `:NV` to launch search.
2. Start typing to search by title.
3. If the note exists, highlight it and press `<CR>` (Enter).
4. If it doesn't exist, press `<CR>` to create and open it.
5. To force create a new note with your search query (even if there are matching search options), press `<C-y>` (Ctrl-y).

## Help, health, and tests

- Browse options from `:help nv`.
- Diagnose your setup with `:checkhealth nv`.
- Run the headless test suite with `make test` (or directly: `nvim --headless -u tests/minimal_init.lua -l tests/run.lua`).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). To report a security issue, follow the process in [SECURITY.md](SECURITY.md).

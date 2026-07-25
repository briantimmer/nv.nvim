# nv.nvim

A lightweight Neovim plugin written in Lua that replicates the fast "search-or-create" note-taking workflow of **Notational Velocity**.

Built on top of **snacks.nvim**.

## Features

- **Fast search-or-create:** Launch notes search. If a matching note exists, hit `Enter` to open it. If it doesn't exist, hit `Enter` to instantly create and open a new note named after your search query.
- **Force-create:** Press `Ctrl-y` in the search box to force-create a new note with your query even if other search results exist.
- **Auto-heading insertion:** Automatically populates the new note with a neat Markdown H1 title.
- **Auto-open on folder open:** Automatically intercepts Neovim starts targeting your notes folder and launches the search interface immediately.

## Requirements

- Neovim >= 0.12 (if using `vim.pack.add()`)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (for the picker)

## Installation

### Using Neovim 0.12's Built-in Package Manager (`vim.pack.add()`)

Add this entry to your Neovim initialization configuration (e.g. `init.lua`):

```lua
-- 1. Load snacks.nvim and your local nv.nvim plugin
vim.pack.add({
  "https://github.com/folke/snacks.nvim",
  "file://" .. vim.fn.expand("~/nv.nvim")
})

-- 2. Configure nv.nvim
require("nv").setup({
  notes_dir = vim.fn.expand("~/notes"), -- Custom notes directory
  extension = "md",                     -- Custom extension
  auto_open_on_dir = true,              -- Auto-open search picker when notes directory is opened
})

-- 3. Bind a key to trigger the search
vim.keymap.set("n", "<leader>n", "<cmd>NV<CR>", { desc = "Notational Velocity Notes" })
```

## Usage

1. Press your keymap (e.g., `<leader>n`) or type `:NV` to launch search.
2. Start typing to search by title.
3. If the note exists, highlight it and press `<CR>` (Enter).
4. If it doesn't exist, press `<CR>` to create and open it.
5. To force create a new note with your search query (even if there are matching search options), press `<C-y>` (Ctrl-y).

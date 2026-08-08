# Contributing to nv.nvim

Thanks for your interest in contributing! This project is a small, focused
Neovim plugin, and the bar for changes is intentionally low but careful.

## Pull requests

Pull requests are welcome. Because this repository is configured to only
accept pull requests from collaborators, if you don't already have write
access you can still open a PR from a fork — reach out first if you plan
substantial work so we don't duplicate effort.

Before submitting, please make sure:

- Your changes are scoped to a single concern. Prefer several small PRs over
  one large one.
- The full check suite passes locally: `make ci` (format check + tests).
- New behavior is covered by a test in `tests/spec/`.

## Development setup

You need:

- Neovim >= 0.12
- [stylua](https://github.com/JohnnyMorganz/StyLua) >= 2.5.2
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (the only runtime
  dependency)

## Commands

| Command        | Description                                           |
| -------------- | ----------------------------------------------------- |
| `make test`    | Run the headless test suite (`tests/run.lua`)         |
| `make format`  | Format `lua/`, `plugin/`, and `tests/` with stylua    |
| `make lint`    | Check formatting without modifying files              |
| `make ci`      | Run `lint` then `test` (mirrors CI)                   |

## Project layout

- `lua/nv/` — plugin source (config, picker, utilities).
- `plugin/nv.lua` — entry point that wires up commands and keymaps.
- `tests/` — headless test suite using a minimal Neovim config
  (`tests/minimal_init.lua`), with a tiny framework in `tests/run.lua` and
  specs in `tests/spec/`.
- `doc/nv.txt` — the help file. If your change touches user-facing behavior,
  update it and regenerate `doc/tags` with `:helptags doc/`.

## Style

- Lua formatted with stylua per `.stylua.toml` (120-column, 2-space indent,
  Unix line endings).
- Match the surrounding code's conventions. Comments should explain *why*,
  not *what*.

## Reporting issues

Please search existing issues first. Include your Neovim version
(`nvim --version`) and the output of `:checkhealth nv`.

## Security

If you find a security issue, do not open a public issue. See
[SECURITY.md](SECURITY.md) for how to report it privately.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).

# Security Policy

## Reporting a vulnerability

Please do **not** report security vulnerabilities through public GitHub
issues, since those are visible to everyone before a fix is in place.

Instead, report privately. This repository is maintained by `btdstudio`; the
owner's public profile on GitHub (`https://github.com/btdstudio`) lists the
contact email to use. You can also open a [private security advisory](
https://github.com/btdstudio/nv.nvim/security/advisories/new), which keeps the
discussion confidential.

Please include:

- A description of the issue and the impact you observed.
- Steps to reproduce, ideally as minimal as possible.
- Your Neovim version (`nvim --version`).

You should receive an acknowledgement within a few business days.

## Scope

In scope: the Lua source in `lua/`, `plugin/`, and the headless test suite.
Out of scope: third-party dependencies (for example `snacks.nvim`) — report
those to their respective projects.

## Supported versions

Only the latest release is supported. Security fixes are released on `main`
and backported to the most recent tagged release when feasible.

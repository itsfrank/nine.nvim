# nine

Nine is a Neovim plugin that uses `pi` RPC mode to generate **text to insert at the current cursor position** or **replacement text for a visual selection**.

It is directly inspired by [ThePrimeagen/99](https://github.com/ThePrimeagen/99) and is my take on the idea using the more minimal `pi` coding agent.

## Current behavior

Nine supports two workflows:

- Normal mode `:Nine` opens a floating prompt for text to insert at the cursor.
- Visual mode `:'<,'>Nine` opens the same prompt for rewriting the selected text.
- Neovim applies the returned text in a single buffer mutation.
- In visual mode, only the selected range is replaced; text around the selection is immutable context.

## Requirements

- `pi` must be installed and available on `$PATH`
- Neovim with Lua support

## Default config

It is not required to call setup, but if you want to modify the options, these are the defaults:

```lua
require("nine").setup({
  pi_cmd = "pi",
  pi_args = { "--mode", "rpc", "--no-session", "--tools", "read,grep,find,ls" },
})
```

## Usage

For insertion, run:

```vim
:Nine
```

For visual replacement, select text and run:

```vim
:'<,'>Nine
```

Example Lua keymaps:

```lua
vim.keymap.set("n", "<leader>nn", "<cmd>Nine<cr>", { desc = "nine insert" })
vim.keymap.set("x", "<leader>nn", ":Nine<cr>", { desc = "nine rewrite selection" })
```

Inside the prompt window:

- `<C-d>` submits in insert and normal mode
- `<Esc>` cancels in normal mode

## Tests

Run the headless Neovim test suite:

```bash
./tests/run.sh
```

Test output is colored by default. Disable ANSI colors with:

```bash
NO_COLOR=1 ./tests/run.sh
```

## Notes

- Nine keeps `pi` read-only for these workflows.
- Neovim is the only part that mutates the buffer.
- Insertions and replacements are applied with one `nvim_buf_set_text()` call so they land as a single undo step.

See `plan.md` for the v1 design.

# nine

Nine is a Neovim plugin that uses `pi` RPC mode to generate **text to insert at the current cursor position**.

It is directly inspired by [ThePrimeagen/99](https://github.com/ThePrimeagen/99) and is my take on the idea using the more minimal `pi` coding agent.

## Current behavior

Nine intentionally supports one workflow for now:

- `:Nine` opens a floating prompt
- you describe what should be inserted at the cursor
- Nine asks `pi` for strict JSON output
- if needed, Nine retries malformed JSON up to 3 times in the same session
- Nine inserts the returned text at the original cursor position in a single buffer mutation
- the cursor moves to the end of the inserted text

## Requirements

- `pi` must be installed and available on `$PATH`
- Neovim with Lua support

## Minimal setup

```lua
require("nine").setup({
  pi_cmd = "pi",
  pi_args = { "--mode", "rpc", "--no-session", "--tools", "read,grep,find,ls" },
})
```

## Usage

Run:

```vim
:Nine
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

- Nine keeps `pi` read-only for this workflow.
- Neovim is the only part that mutates the buffer.
- Insertions are applied with one `nvim_buf_set_text()` call so they land as a single undo step.

See `plan.md` for the v1 design.

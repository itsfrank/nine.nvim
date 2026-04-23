#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

run_test() {
  local file="$1"
  echo "==> $file"
  nvim --headless -u NONE -c "lua dofile('$file')"
}

run_test tests/e2e_success.lua
run_test tests/e2e_retry.lua
run_test tests/e2e_fail_three.lua

echo "All tests passed"

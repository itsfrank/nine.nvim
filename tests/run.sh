#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

nvim --headless -u NONE -c "lua dofile('tests/all.lua')"

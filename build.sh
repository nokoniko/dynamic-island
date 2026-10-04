#!/bin/sh
# Shortcut for `cd builder && cargo run` — works from any directory.
set -e
cd "$(dirname "$0")/builder"
exec cargo run

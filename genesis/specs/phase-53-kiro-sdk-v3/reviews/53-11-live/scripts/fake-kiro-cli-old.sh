#!/bin/sh
# 53-11 A5 fake: reports kiro-cli 2.36.0 (below the 2.37.1 minimum) for --version; every other call runs the real
# kiro-cli 2.37.1.
if [ "$1" = "--version" ]; then echo "kiro-cli 2.36.0"; exit 0; fi
exec /Users/ramaswamy.u/.local/bin/kiro-cli "$@"

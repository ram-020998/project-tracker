#!/bin/sh
# 53-11 A5 fake: reports kiro-cli 2.38.0 (newer than the verified 2.37.1) for --version; every other call runs the real
# kiro-cli 2.37.1.
if [ "$1" = "--version" ]; then echo "kiro-cli 2.38.0"; exit 0; fi
exec /Users/ramaswamy.u/.local/bin/kiro-cli "$@"

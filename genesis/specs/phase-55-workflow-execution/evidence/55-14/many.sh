#!/usr/bin/env bash
# 55-14: one pytest process running each selected test REPEAT times (scratch plugin), under CPU load.
# usage: many.sh <label> <repeat> <burners> <pytest args...>
set -u
label=$1; repeat=$2; burners=$3; shift 3
cd /w/genesis
pids=()
for _ in $(seq 1 "$burners"); do python -c "while True: pass" & pids+=($!); done
REPEAT=$repeat PYTHONPATH=/w pytest -q -p no:cacheprovider -p repeat_plugin "$@" > "/w/out/$label.txt" 2>&1
echo "pytest exit=$?"
for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done
grep -E "^FAILED|passed|failed" "/w/out/$label.txt" | sed -E 's/\[[0-9]+\]|-[0-9]+\]/]/' | sort | uniq -c

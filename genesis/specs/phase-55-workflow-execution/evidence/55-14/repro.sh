#!/usr/bin/env bash
# 55-14: run pytest selections N times in the python:3.13 CI image under CPU load (L-112).
# usage: repro.sh <label> <count> <burners> <pytest args...>
set -u
label=$1; count=$2; burners=$3; shift 3
cd /w/genesis
pids=()
for _ in $(seq 1 "$burners"); do python -c "while True: pass" & pids+=($!); done
pass=0; fail=0
for i in $(seq 1 "$count"); do
  if pytest -q -p no:cacheprovider "$@" > "/w/out/$label-$i.txt" 2>&1; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "run $i FAILED: $(grep -E '^FAILED|passed|failed' "/w/out/$label-$i.txt" | tr '\n' ' ')"
  fi
done
for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done
echo "$label: $count runs, burners=$burners, pass=$pass fail=$fail"
tail -n 1 "/w/out/$label-$count.txt"

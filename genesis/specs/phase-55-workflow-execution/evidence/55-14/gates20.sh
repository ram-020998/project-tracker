#!/usr/bin/env bash
# 55-14 §3: each target test file 20 times (a fresh pytest per run, -x -p no:randomly) under 6 CPU burners, then
# the exec-window probes, in the python:3.13 image with an init PID 1 (docker run --init).
set -u
bash /w/repro.sh i-docs 20 6 -x -p no:randomly tests/test_document_records.py
bash /w/repro.sh i-apwt 20 6 -x -p no:randomly tests/test_apwt_client.py
bash /w/repro.sh i-procs 20 6 -x -p no:randomly tests/test_testexec_procs.py
python /w/probe_exec.py 6 > /w/out/probe_exec.txt 2>&1
cat /w/out/probe_exec.txt
python /w/probe_reap.py 300 0 6 60 > /w/out/probe_reap.txt 2>&1
cat /w/out/probe_reap.txt

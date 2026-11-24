#!/usr/bin/env bash
# 55-14: the genesis job of .gitlab-ci.yml (ruff + pytest -q) once in the python:3.13 image, on the staged tree.
set -u
cd /w/genesis
echo "== ruff $(date -u +%FT%TZ)"
ruff check genesis; echo "ruff exit=$?"
echo "== pytest $(date -u +%FT%TZ)"
pytest -q -p no:warnings -ra --tb=long > /w/out/full-pytest.txt 2>&1
echo "pytest exit=$?"
tail -n 15 /w/out/full-pytest.txt
echo "== done $(date -u +%FT%TZ)"

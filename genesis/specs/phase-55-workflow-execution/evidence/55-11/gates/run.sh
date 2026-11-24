#!/usr/bin/env bash
# 55-11 §2 CI-image run (L-112): python:3.13, local genesis 76b27a57 + genesis-workflows 3c29e73 (git archives),
# installed WITH the memory model (fastembed + the pinned bge-small files fetched by install-packages.sh).
set -u
export GENESIS_STATE_DIR=/work/state
python -m venv /work/venv
cd /work/genesis
echo "== install (with model)"
scripts/install-packages.sh --dev --python /work/venv/bin/python > /work/install.txt 2>&1
echo "install exit=$?"
grep -iE "model|fetch|reembed|sha|embedd" /work/install.txt | tail -15
/work/venv/bin/python -c "import fastembed, sys; print('fastembed', fastembed.__version__)"
ls -la /work/state/models/* 2>&1 | head -20
cd /work/genesis-workflows
/work/venv/bin/pip install --no-deps -e . >> /work/install.txt 2>&1
/work/venv/bin/pip install "pyyaml>=6" "jsonschema>=4" "pytest>=8" "pytest-asyncio>=0.23" >> /work/install.txt 2>&1
echo "== validate_library"; /work/venv/bin/python ci/validate_library.py > /work/validate_library.txt 2>&1; echo "exit=$?"; tail -2 /work/validate_library.txt
echo "== validate_skills"; /work/venv/bin/python ci/validate_skills.py 2>&1 | tail -1
echo "== library pytest"; /work/venv/bin/python -m pytest -q -p no:cacheprovider workflows --ignore=workflows/_fixtures > /work/library-pytest.txt 2>&1; echo "exit=$?"; tail -2 /work/library-pytest.txt
cd /work/genesis/packages/genesis-core
echo "== genesis-core"; /work/venv/bin/python -m pytest -q -p no:cacheprovider tests > /work/core-pytest.txt 2>&1; echo "exit=$?"; tail -1 /work/core-pytest.txt
cd /work/genesis/packages/kiro-agent-sdk
echo "== kiro-agent-sdk"; /work/venv/bin/python -m pytest -q -p no:cacheprovider > /work/sdk-pytest.txt 2>&1; echo "exit=$?"; tail -1 /work/sdk-pytest.txt
cd /work/genesis
echo "== genesis full (fastembed + model installed)"
GENESIS_STATE_DIR=/work/state-tests /work/venv/bin/python -m pytest -q -p no:cacheprovider -rfE > /work/genesis-pytest.txt 2>&1
echo "exit=$?"; tail -12 /work/genesis-pytest.txt
echo "== test_document_records x5"
for i in 1 2 3 4 5; do GENESIS_STATE_DIR=/work/state-tests /work/venv/bin/python -m pytest -q -p no:cacheprovider tests/test_document_records.py 2>&1 | grep -E "^E |passed|failed" | head -6; done

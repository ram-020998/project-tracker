#!/usr/bin/env bash
# 55-11 §2: the pinned model loads on Linux with the network OFF (docker --network none), from the folder run.sh filled.
set -u
export GENESIS_STATE_DIR=/work/state
echo "== negative control: the network is really off"
/work/venv/bin/python - <<'EOF'
import socket
try:
    socket.create_connection(("huggingface.co", 443), timeout=5)
    print("CONTROL FAILED: connected")
except Exception as e:
    print("control ok, no network:", type(e).__name__, str(e)[:80])
EOF
echo "== load + embed offline"
cd /work
/work/venv/bin/python - <<'EOF'
import time
from genesis.runtime.settings import Settings
from genesis.memory import build_embedder
from genesis.memory.embedder import LocalEmbedder
s = Settings.load()
t0 = time.monotonic()
emb = build_embedder(s)
print("embedder:", type(emb).__name__, getattr(emb, "model_id", None), getattr(emb, "model_dir", None))
assert isinstance(emb, LocalEmbedder), "fell back: not the real embedder"
v = emb.embed_query("Document Builder feature: generate a contract document")
d = emb.embed(["a memory about the Document Builder", "another one"])
print("dim:", emb.dim, "query len:", len(v), "docs:", len(d), "load+embed s: %.2f" % (time.monotonic() - t0))
assert emb.dim == 384 and len(v) == 384 and len(d) == 2
print("OFFLINE LOAD OK")
EOF
echo "exit=$?"
echo "== genesis memory status (offline)"
/work/venv/bin/genesis memory status 2>&1 | head -5
echo "== memory tests offline"
cd /work/genesis && GENESIS_STATE_DIR=/work/state-tests /work/venv/bin/python -m pytest -q -p no:cacheprovider -rs tests/test_memory_brief.py tests/test_memory_brief_worker.py 2>&1 | tail -8

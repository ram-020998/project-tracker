import sqlite3, json
from pathlib import Path
from genesis.memory import MemoryStore, GraphStore
from genesis.memory.embedder import LocalEmbedder
from genesis.memory.vector import reembed, readonly_vector_index
from genesis.memory.db import ReadOnlyDatabase
from genesis.memory.retrieval import HybridRetriever
from genesis.memory import brief as mb
P = Path("/tmp/gv-55-04/probe")
if not (P/"memory.db").exists():
    s = sqlite3.connect("file:/Users/ramaswamy.u/.genesis/memory.db?mode=ro", uri=True); d = sqlite3.connect(P/"memory.db"); s.backup(d); d.close()
    s = sqlite3.connect("file:/Users/ramaswamy.u/.genesis/genesis.db?mode=ro", uri=True); d = sqlite3.connect(P/"genesis.db"); s.backup(d); d.close()
emb = LocalEmbedder(backend="fastembed", model_dir="/tmp/gv-55-04/state/models/bge-small-en-v1.5")
reembed(MemoryStore(P/"memory.db"), emb, P/"memory.db")
ro = ReadOnlyDatabase(P/"memory.db", immutable=True)
store, graph = MemoryStore(ro), GraphStore(ro)
kb = mb.KbNames(ReadOnlyDatabase(P/"genesis.db", immutable=True))
wfs = json.load(open("/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/tests/fixtures/memory_brief/workflows.json"))
gdb = sqlite3.connect(f"file:{P/'genesis.db'}?mode=ro&immutable=1", uri=True)
def inputs(r): return json.loads(gdb.execute("select inputs from runs where run_id=?", (r,)).fetchone()[0])
cases = {"td4": ("technical-design-analysis", "r-19cf98e94757"), "story80": ("story-implementation", "r-fb5a9cd14f72"),
         "ap": ("agent-prompt", "r-87781054aa00")}
ents_all = {}
def run(label, query, ents, kw):
    idx = readonly_vector_index(ro, 384)
    r = HybridRetriever(store, graph, emb, idx)
    res = r.search(query, scope="shared", entity_ids=ents or None, top_k=12, keyword_phrases=kw or None)
    return [s.memory.id for s in res]
for k, (wid, rid) in cases.items():
    wf = wfs[wid]; inp = inputs(rid)
    d = mb.describe_run(wf["meta"], inp, steps=wf["steps"], kb=kb)
    ents = mb.entity_ids(store, d)
    ctx = "\n".join(l for l in d.text.splitlines() if l.split(":")[0] in ("Application","Feature","Story","Inputs"))
    by = {e.id: e for e in store.list_entities()}
    spec = [i for i in ents if by[i].entity_kind != "application"]
    print(k, "ents", [(i, by[i].entity_kind) for i in ents])
    print("  A full+all      ", run(k, d.text, ents, d.names))
    print("  B ctx+all       ", run(k, ctx or d.text, ents, d.names))
    print("  C ctx+specific  ", run(k, ctx or d.text, spec or ents, d.names[1:] or d.names))

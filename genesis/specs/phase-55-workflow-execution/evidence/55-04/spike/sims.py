import json, sqlite3, numpy as np
from fastembed import TextEmbedding
m = TextEmbedding(model_name="BAAI/bge-small-en-v1.5", specific_model_path="/tmp/gv-55-04/state/models/bge-small-en-v1.5",
                  cache_dir="/tmp/gv-55-04/state/models/bge-small-en-v1.5", local_files_only=True)
c = sqlite3.connect("file:/Users/ramaswamy.u/.genesis/memory.db?mode=ro&immutable=1", uri=True)
rows = c.execute("select id, text, coalesce(summary,'') from memories where valid_to is null and archived=0").fetchall()
docs = list(m.embed([f"{t}\n{s}".strip() for _i, t, s in rows]))
D = np.array(docs); D /= np.linalg.norm(D, axis=1, keepdims=True)
B = "/tmp/gv-55-04/briefs-bge/"
td = open(B+"technical-design-feature-4.description.txt").read().strip()
ap = open(B+"agent-prompt.description.txt").read().strip()
st = open(B+"story-implementation-story-80.description.txt").read().strip()
def nosteps(t): return "\n".join(l for l in t.splitlines() if not l.startswith("Steps: "))
def ctx(t): return "\n".join(l for l in t.splitlines() if l.split(":")[0] in ("Application","Feature","Story","Inputs"))
for label, q in [("td-full", td), ("td-nosteps", nosteps(td)), ("td-ctx", ctx(td)), ("story-nosteps", nosteps(st)), ("ap-full", ap), ("ap-nosteps", nosteps(ap))]:
    v = np.array(list(m.query_embed([q]))[0]); v /= np.linalg.norm(v)
    sims = D @ v
    order = np.argsort(-sims)
    ids = [rows[i][0] for i in order]
    top = [(rows[i][0], round(float(sims[i]),3)) for i in order[:8]]
    pos = {k: ids.index(k)+1 for k in (26,27,83)}
    print(label, "rank26/27/83", pos, "max", round(float(sims.max()),3), "p50", round(float(np.median(sims)),3), "top", top)

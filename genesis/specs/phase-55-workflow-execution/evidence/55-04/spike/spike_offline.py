"""55-04 §0 spike: load bge-small-en-v1.5 from a Genesis-owned folder with no network."""
import json, sys, time, resource
mode = sys.argv[1]
t0 = time.monotonic()
from fastembed import TextEmbedding
if mode == "local":
    m = TextEmbedding(model_name="BAAI/bge-small-en-v1.5",
                      specific_model_path="/tmp/gv-55-04/models/bge-small-en-v1.5",
                      cache_dir="/tmp/gv-55-04/empty-cache", local_files_only=True)
else:  # control: the default download path, empty cache
    m = TextEmbedding(model_name="BAAI/bge-small-en-v1.5", cache_dir="/tmp/gv-55-04/empty-cache2")
t1 = time.monotonic()
v = list(m.embed(["Document Builder templates feature", "Templates management tab for Word documents"]))
q = list(m.query_embed(["document builder"]))[0]
import numpy as np
cos = [float(np.dot(q, x) / (np.linalg.norm(q) * np.linalg.norm(x))) for x in v]
print(json.dumps({"mode": mode, "dim": len(v[0]), "load_s": round(t1 - t0, 2),
                  "embed_s": round(time.monotonic() - t1, 3), "cos": [round(c, 3) for c in cos],
                  "maxrss_mb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1e6, 1)}))

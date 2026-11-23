exec(open("variants.py").read().split("for k, (wid, rid)")[0])
from genesis.memory.retrieval import RetrievalWeights
by = {e.id: e for e in store.list_entities()}
idx = readonly_vector_index(ro, 384)
def go(k, w, mode):
    wid, rid = cases[k]; wf = wfs[wid]; inp = inputs(rid)
    d = mb.describe_run(wf["meta"], inp, steps=wf["steps"], kb=kb)
    ents = mb.entity_ids(store, d)
    ctx = "\n".join(l for l in d.text.splitlines() if l.split(":")[0] in ("Application","Feature","Story","Inputs"))
    q = d.text if mode == "full" else (ctx or d.text)
    spec = [i for i in ents if by[i].entity_kind != "application"] or ents
    kw = d.names[1:] or d.names
    r = HybridRetriever(store, graph, emb, idx, weights=w)
    return [s.memory.id for s in r.search(q, scope="shared", entity_ids=spec or None, top_k=12, keyword_phrases=kw or None)]
for name, w in [("default", RetrievalWeights()),
                ("rel.75", RetrievalWeights(w_relevance=0.75, w_recency=0.05, w_importance=0.20)),
                ("rel.75 a.8", RetrievalWeights(w_relevance=0.75, w_recency=0.05, w_importance=0.20, alpha_semantic=0.8, beta_keyword=0.1, gamma_entity=0.1)),
                ("rel.85 a.7", RetrievalWeights(w_relevance=0.85, w_recency=0.05, w_importance=0.10, alpha_semantic=0.7, beta_keyword=0.2, gamma_entity=0.1))]:
    for mode in ("full", "ctx"):
        out = {k: go(k, w, mode) for k in cases}
        print(f"{name:12} {mode:4}", " td4:", out["td4"], "27" if 27 in out["td4"] else "-", "| st:", out["story80"][:6], "27" if 27 in out["story80"] else "-")

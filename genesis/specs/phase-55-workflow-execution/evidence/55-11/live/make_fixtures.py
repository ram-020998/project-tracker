"""55-11 §3 scratch fixtures (never in a repo): three cheap workflows derived from hello-appian whose validator can
never pass on the first turns (it also requires the key ``k55``, which the prompt does not ask for), so a real Kiro turn
escalates after retry_max=1 (two turns). result.json exists and is non-empty, so Accept / Fix then accept are offered.

- probe-accept      : HEAD hello-appian (standard escalation_gate), relaunchable: true
- probe-norelaunch  : HEAD hello-appian, relaunchable: false + relaunch_hint (D23 row)
- probe-legacy      : v0.27.0 hello-appian (the old hitl_gate escalation; legacy Resolve, A12/A14)
"""
import json
import re
from pathlib import Path

LIB = Path("/tmp/gr-55-11/lib-head")
HEAD = LIB / "workflows" / "hello-appian"
OLD = Path("/tmp/gr-55-11/lib-v027/workflows/hello-appian")


def derive(src: Path, wid: str, name: str, relaunchable: bool | None, hint: str | None) -> dict:
    dst = LIB / "workflows" / wid
    dst.mkdir(parents=True, exist_ok=True)
    g = (src / "graph.py").read_text()
    y = (src / "workflow.yaml").read_text()
    g = g.replace('"id": "hello-appian"', f'"id": "{wid}"').replace('"name": "Hello Appian"', f'"name": "{name}"')
    g = g.replace('"retry_defaults": {"max": 2}', '"retry_defaults": {"max": 1}')
    g = g.replace('V.required_keys(["value"], "result.json")', 'V.required_keys(["value", "k55"], "result.json")')
    assert '"k55"' in g and f'"id": "{wid}"' in g, wid
    y = y.replace("id: hello-appian", f"id: {wid}").replace('name: "Hello Appian"', f'name: "{name}"')
    y = re.sub(r"retry_defaults:\n  max: 2", "retry_defaults:\n  max: 1", y)
    if relaunchable is not None:
        g = g.replace('"relaunchable": True,', f'"relaunchable": {relaunchable},'
                      + (f'\n    "relaunch_hint": {hint!r},' if hint else ""))
        y = y.replace("relaunchable: true", f"relaunchable: {str(relaunchable).lower()}"
                      + (f'\nrelaunch_hint: "{hint}"' if hint else ""))
    (dst / "graph.py").write_text(g)
    (dst / "workflow.yaml").write_text(y)
    ver = re.search(r"^version: (\S+)", y, re.M).group(1)
    return {"id": wid, "name": name, "version": ver, "roles": ["developer"],
            "summary": "55-11 scratch probe: hello-appian whose check needs a key the prompt does not ask for.",
            "path": f"workflows/{wid}", "required_mcp": [], "required_cli": []}


entries = [derive(HEAD, "probe-accept", "Probe 55-11 accept", None, None),
           derive(HEAD, "probe-norelaunch", "Probe 55-11 not relaunchable", False,
                  "Start it again from the Catalog (55-11 probe hint)"),
           derive(OLD, "probe-legacy", "Probe 55-11 legacy gate", None, None)]
reg = json.loads((LIB / "registry.json").read_text())
reg["workflows"] = [w for w in reg["workflows"] if not w["id"].startswith("probe-")] + entries
(LIB / "registry.json").write_text(json.dumps(reg, indent=2) + "\n")
print([e["id"] for e in entries])

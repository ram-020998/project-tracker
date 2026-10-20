"""47-09 §3 recall replay: pack ADR set vs every ADR cited in the sub-spec (+As-built) and in 46-10."""
import re, sys, json
from pathlib import Path
sys.path.insert(0, "/Users/ramaswamy.u/repo/project-tracker/genesis/agent-system/tools")
from genesis_ctx import config, model
from genesis_ctx.pack import select
from genesis_ctx.sources import parse_manifest

ctx = config.Ctx(config.default_tracker(), config.default_repos())
c = model.Corpus(ctx)
S = ctx.tracker / "specs/phase-46-spec-change-requests"
def ids(t):
    out = set()
    for m in re.finditer(r"ADR-(\d{3})((?:\s*/\s*-?\d{3})*)", t):   # expands "ADR-031/045" and "ADR-075/-076"
        out.add("ADR-" + m.group(1))
        out.update("ADR-" + x for x in re.findall(r"\d{3}", m.group(2)))
    return out
r10 = ids((S / "46-10-review-and-acceptance.md").read_text())
subs = {"46-02": ["46-02-clause-model.md"], "46-03": ["46-03-story-spec-links.md"],
        "46-04": ["46-04-change-request-lifecycle.md"], "46-05": ["46-05-impact-analysis.md"],
        "46-06": ["46-06-apply-and-discard.md"], "46-07": ["46-07-web-experience.md"],
        "46-08": ["46-08-story-answers-history-and-badges.md"],
        "46-09": ["46-09-collaboration-and-hub.md", "46-09-appian-agent-handoff.md", "46-09-appian-agent-prompt.md"]}
tot_exp = tot_hit = 0; rows = []
for sid, files in subs.items():
    own = set().union(*(ids((S / f).read_text()) for f in files))
    exp = own | r10
    m = parse_manifest((Path(__file__).resolve().parent / "replay-46" / f"{sid}.md").read_text())
    assert not m.error, m.error
    sel = select(c, m.data, [])
    got = set(sel["adrs"])
    miss = sorted(exp - got); miss_own = sorted(own - got)
    tot_exp += len(exp); tot_hit += len(exp & got)
    rows.append((sid, sorted(own), len(exp), len(exp & got), miss_own, miss, len(got), len(sel["lessons"])))
    print(f"{sid}: own={sorted(own)} expected={len(exp)} hit={len(exp&got)} recall={len(exp&got)/len(exp):.0%} "
          f"miss_own={miss_own} miss_46-10={sorted(set(miss)-set(miss_own))} pack_adrs={len(got)} "
          f"precision={len(exp&got)/len(got):.0%} lessons={len(sel['lessons'])} areas={sorted(sel['areas'])}")
print(f"46-10 cites: {sorted(r10)}")
print(f"TOTAL recall {tot_hit}/{tot_exp} = {tot_hit/tot_exp:.1%}")

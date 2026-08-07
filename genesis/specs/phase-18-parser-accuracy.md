# Phase 18 — Appian Parser Accuracy Overhaul

> **Status:** ✅ IMPLEMENTED + live-validated (18-01..18-05 on `genesis-appian-parser` main; **release/tag = 18-06,
> pending**). On the 2,620-object fixture and the user's **real app** (validated 2026-08-07): edge recall **0.978**,
> precision **0.999**, referenced-object recall **1.0**, **orphans 804 → 0** (false-orphan rate 0.311 → 0.0), 12
> integration points classified. See `progress/phase-18-parser-accuracy.md`. · **Repo:** `genesis-appian-parser`
> (+ repin `genesis` + `sync-application`). · **Author:** Genesis agent · **Date:** 2026-08-07
>
> **One line.** The Appian package parser under-links dependencies so badly that **30.7% of objects are reported as
> orphans and 803/804 of those are provably false** — objects that ARE referenced by other objects. This phase
> reverifies every object-type parser against real exported XML and drives dependency/relationship/orphan accuracy
> **above 95%**, verified by a raw-XML reference oracle + per-type golden fixtures.

---

## 1. Current state (grounded — measured 2026-08-07)

`genesis-appian-parser` **v0.1.0** (Phase 16-01) is a faithful port of the Atlas parser front-half:
`unzip → type-detect → 25 per-type parsers → ReferenceResolver (rewrites `#"_a-uuid"` → `rule!Name(`, RT/translation
URNs, in place) → DependencyAnalyzer (scans configured field paths for named/UUID/URN refs) → BundleCoordinator
(entry-point discovery + BFS) → KbParseResult`. `api.parse()` marks an object **`is_orphan`** when it is **not assigned
to any entry-point bundle**.

**Measured baseline** (`tests/fixtures/AiDocumentCenterv4.3.1.zip`, 2,620 objects, 5,084 edges):

| Metric | Value |
|---|---|
| Objects | 2,620 |
| Edges | 5,084 (CALLS 4006, USES_CONSTANT 882, USES_RECORD_TYPE 183, USES_SITE 13) |
| **Orphans reported** | **804 (30.7% of all objects)** |
| **False orphans** (uuid token present in ≥1 *other* object's defining XML) | **803 / 804** |
| True orphans | 1 (the `Application` root — expected) |

**False-orphans split into two independent defects:**

- **Defect 1 — edge-extraction recall (419 orphans, ~52%): ZERO incoming edges** despite being referenced. Root cause:
  extraction is **field-path-scoped** (`SAIL_CODE_FIELDS` / `STRUCTURAL_FIELDS` in `domain/constants.py`) and those maps
  only have keys for *Interface, Expression Rule, Process Model, Record Type, Web API, Site, Control Panel, Integration*.
  They have **no entry at all** for **Constant (288), AI Skill (14), Decision (2), Translation String (1316), Document
  (19), Data Store, Connected System, Group, CDT, Folder, Application** — so those types emit **no edges**. Concrete
  example: a Constant whose value holds `displayRule: #"_a-…_154866"` rule references produces no `Constant→Rule` edge,
  so the rule looks unused. Translation strings referenced via `urn:appian:translation-string:v1:{uuid}` get no edge.
  Zero-incoming orphans by type: TranslationString 270, ExpressionRule 75, Document 17, AI Skill 14, Folder 11, Constant
  14, Interface 7, CDT 2, Group 6, Data Store 1, Connected System 1, Application 1.
- **Defect 2 — orphan semantics (385 orphans, ~48%): HAVE incoming edges** but are still flagged orphan, because
  `is_orphan = "not in an entry-point bundle"` (reachability), not `"has no references"`. This matches Atlas's own
  definition ("not reachable from any entry point"), but it does **not** match the user's expectation ("orphan = unused")
  and mislabels used objects.

**This is not a port regression** — our `DependencyAnalyzer`/field maps are identical to the original Atlas parser
(`appian/solutions-atlas-parser`, verified via the indexed KB). It is an inherited design limitation that this
large, constant/translation-heavy app exposes.

---

## 2. Goal & success criteria (the >95% bar)

Raise **parser accuracy > 95%**, defined and measured concretely (see §3):

1. **Edge recall ≥ 95%** — of all UUID references that genuinely exist in the raw XML (object-to-object), ≥95% produce a
   dependency edge. (Baseline: unknown-but-low; 419 objects have 0 of their real incoming refs captured.)
2. **False-orphan rate ≤ 5%** — of objects reported as orphans, ≤5% are actually referenced elsewhere. (Baseline: 803/804
   = 99.9% false.) Equivalent target: **true orphans only** (the Application root + genuinely dead objects).
5. **Integration points classified (§4.4)** — every APPREF/ENTRYPOINT object is flagged with its `integration_role` and
   is exempt from orphan reporting; in-package `rulereferencebyname("X")` links resolve to an edge, cross-app ones are
   retained as external references. Verified by targeted tests (not the statistical oracle, which is UUID-based).
3. **Edge precision ≥ 95%** — edges point at real referenced objects, not coincidental UUID collisions (guard against
   over-linking when we broaden the scan).
4. **Per-object-type field completeness** — for each of the ~20 object types, every required structural field +
   relationship the KB/Business-Map depends on is extracted (audited vs real XML + golden fixtures).

**Non-goals:** storing SAIL source (ADR-037 — stays code-free); semantic/behavioral analysis; changing the KB schema
(edges/orphans are already modeled). Bundle *content* quality is in scope only insofar as orphan reachability.

---

## 3. Accuracy methodology (the measurement backbone)

A parser cannot be "improved to 95%" without a metric. We build a **reference oracle** from the raw export and a
**harness** that scores the parser against it — committed to the repo and run in CI.

**Raw-XML reference oracle (ground truth, parser-independent):**
- Extract the package. For each object file, record the object UUID it *defines* (`<uuid>` under the primary element).
- Collect the set of **known object UUIDs** (all defined objects, plus their base/canonical forms).
- For every object file, scan its full text for occurrences of *other* objects' known UUID tokens (prefixed `_a-/_e-`,
  bare 36-char, and URN-embedded). Each such occurrence in file A referencing object B ⇒ a **ground-truth reference
  A→B**. (Exclude self, version UUIDs, and the object's own `<uuid>`/`<versionUuid>`.)
- Ground-truth orphan = an object whose UUID appears in **no other** object's file.

**Scoring (harness):** compare parser edges vs oracle references →
`edge recall = |parser_edges ∩ oracle_refs| / |oracle_refs|`, `edge precision = |∩| / |parser_edges|`,
`false-orphan rate = |reported_orphans that are oracle-referenced| / |reported_orphans|`. Report **overall + per source
object type**, and a ranked list of the worst-missed references (for triage).

**Caveats to control for:** the oracle over-counts when a UUID appears in a non-semantic position (a comment, a version
ref, an unrelated string). The harness excludes `<versionUuid>` and the defining file, and we spot-audit the residual.
The bar is set at 95% (not 100%) to tolerate legitimate oracle noise.

**Golden fixtures:** for each object type, a small committed fixture (real, redacted XML) + an expected extraction
snapshot (fields + emitted edges) so per-type regressions fail a test — the "stub hid the bug" lesson (bible §7).

---

## 4. Design of the fixes

**4.1 Edge recall (Defect 1) — universal known-UUID scan + all reference forms.** Replace the type-gated scan with a
comprehensive pass that runs for **every** object:
- **Universal UUID scan:** walk *all* string values in the object's parsed `data` (and, where needed, the retained raw
  text pre-strip) and match every **known** object UUID token — prefixed (`_a-…_suffix`), bare 36-char, canonical, and
  base forms — emitting an edge to the resolved target with a type inferred from the target. This is type-agnostic and
  catches Constants, AI Skills, Decisions, Documents, and any field the current maps miss. (Keep it *known-UUID-gated*
  so we never invent edges to non-objects → protects precision.)
- **Translation-string references:** extract `urn:appian:translation-string:v1:{uuid}` → `USES_TRANSLATION` edges
  (new dep type) so the 1,316 translation strings link to their consumers. (Decision point in 18-03: model as edges vs.
  exclude translation strings/documents from orphan accounting — see §5.)
- **All URN forms (parity with Jarvis `XmlParser.extractReferences`):** in addition to record-type/field/relationship,
  extract **`urn:appian:record-action:v1:{uuid}`** (record-action refs — currently missed) and the translation-string URN
  above, via a generic `#"(urn:appian:[^"]+)"` capture that dispatches by URN kind.
- **System-rule exclusion (precision guard, from Jarvis `SYSTEM_RULES_OVERRIDES`/`TagDetector`):** recognize
  `#"SYSTEM_SYSRULES_…"` builtins (query/write/sync/sendEmail/startProcess/http/refresh/etc.) and **never** emit them as
  app dependencies — they are platform functions, not package objects. (Also usable as behavioral tags — future.)
- **By-name references (`rulereferencebyname`):** extract a *static-literal* `rulereferencebyname(ruleName: "X")` (and the
  positional `rulereferencebyname("X")`) → an edge to the object **named** `X` if present in the package. This is the
  APPREF cross-app mechanism (see §4.4) and is invisible to both the UUID scan and the `rule!Name(` regex. When the
  dynamic form is used (`rulereferencebyname(ri!…)`) there is no static target, but the caller is still flagged an
  integration consumer.
- **Retain named-ref + RT-URN extraction** (post-resolution) for readable dep context; the universal scan is additive.
- **Ensure every parser retains its reference-bearing text** in `data` long enough for extraction (e.g. Constant `value`,
  Decision rules, AI Skill config) — audited in 18-05.

**4.2 Orphan semantics (Defect 2) — separate "unreferenced" from "not-bundled."** Redefine
`KbObject.is_orphan = (no incoming edges AND no outgoing edges)` — i.e. genuinely disconnected — computed from the final
edge set, independent of bundle assignment. Keep bundle membership as its own field (already have `is_entry_point` /
bundle assignment). Optionally expose `not_bundled` separately for the bundle view. This immediately reclassifies the 385
"has-edges-but-unbundled" objects as non-orphans and aligns "orphan" with the user's meaning.

**4.3 Per-type completeness (§6 audit)** — for each object type verify required fields/relationships vs real XML; add
golden fixtures.

**4.4 APPREF / ENTRYPOINT cross-application integration points (new — user requirement).** Appian apps soft-integrate
across environments via **by-name** rule references, not object UUIDs: an app exposes an **ENTRYPOINT** rule
(`AS_GSS_ENTRYPOINT_GCW_GETDATA_getRefIdConstants`) and a consuming app holds an **APPREF** rule
(`AS_GCW_APPREF_GSS_GETDATA_getRefIdConstants`) that calls it via
`a!refreshVariable(value: rulereferencebyname(ruleName: "AS_GSS_ENTRYPOINT_…"), refreshAlways: true)`. Because the link
is a **name string** (and the peer is usually in a *different* package), these objects have **no incoming UUID edge**, so
today they are misreported as orphans. They are deliberate integration boundaries and must be classified as such.

- **Classification (`integration_role`):** flag an object as an integration point when either signal holds:
  - **Naming convention (adopt Jarvis's proven regexes):**
    - ENTRYPOINT: `AS_([A-Z0-9_]+?)_ENTRYPOINT_(?:([A-Z0-9_]+?)_)?(?:(GETDATA|DISPLAY|STARTPROCESS|RECORDACTION|LOGIC|URL|SAVE|APPVERSION|REF|AI)_)?(.+)` → (source app, optional peer app, **category**, logical name) ⇒ role `entrypoint`.
    - APPREF: `AS_([A-Z0-9_]+?)_APPREF_([A-Z0-9_]+?)_(?:(GETDATA|DISPLAY|STARTPROCESS|RECORDACTION|LOGIC|URL|SAVE|APPVERSION|REF|AI)_)?(.+)` → (caller app, target app, **category**, logical name) ⇒ role `appref`.
    - The **category** enum (GETDATA/DISPLAY/STARTPROCESS/RECORDACTION/LOGIC/URL/SAVE/APPVERSION/REF/AI) classifies the integration's *purpose* and is retained on the object.
  - **Behavioral:** an object whose SAIL calls `rulereferencebyname(…)` is an `appref` consumer; a rule targeted by a
    static `rulereferencebyname(ruleName: "thisName")` from another object is an `entrypoint`.
- **By-name edges (Jarvis `RULENAME_PATTERN = ruleName:\s*"([^"]+)"`):** extract the static ruleName literal → resolve by
  name. Pair APPREF→ENTRYPOINT across apps by matching (target app, category, logical name).
- **Edges:** when a static `rulereferencebyname("X")` resolves to an in-package object, emit a `CALLS` (or
  `INTEGRATION_POINT`) edge APPREF→ENTRYPOINT. When the target is **not** in the package (true cross-app), record the
  reference as an **external/unresolved integration reference** (target name retained, `is_resolved=False`) — do not drop
  it.
- **Orphan exemption:** an object with `integration_role` set is **never** an orphan even with no in-package edges — it is
  an intentional boundary. Surface these prominently (the KB/Business Map can render an "Integration Points" view / a
  cross-app edge).
- **Result surface (mirror Jarvis fields):** add `integration_role: "entrypoint"|"appref"|None`,
  `integration_peer: str|None` (the cross-app target/caller), `integration_category: str|None`, and an
  `is_integration_point` convenience flag to `KbObject`. Genesis-side (16-02 `KbStore`) can carry these in the existing
  `metadata` JSON to avoid a schema migration, or a dedicated column in rollout — decided in 18-04.

---

## 5. Open decisions (confirm during 18-03)

1. **Translation strings & documents in the orphan count.** They are leaf resources referenced by UUID. Options:
   (a) emit `USES_TRANSLATION` / `USES_DOCUMENT` edges (most accurate, larger graph), or (b) exclude these types from
   orphan *reporting* (they're not "code" and a huge count skews the metric). Recommendation: **(a) emit edges** so the
   graph is truthful, and let the Business Map/consumers filter by type. Decide with the human.
2. **Dependency-type taxonomy additions** (`USES_TRANSLATION`, `USES_DOCUMENT`, `USES_AI_SKILL`) — additive to the KB
   `kb_edges.dep_type` (no schema change; it's a free-text column).
3. **Precision guardrails** — the universal scan must exclude an object's own version UUIDs and the defining occurrence;
   confirm the 95% precision bar holds on the fixture before release.

---

## 6. Per-object-type audit checklist (18-05)

Audit each parser against real XML from the fixture (and a second package if available), verifying required fields +
every outbound reference is discoverable: **Interface, Expression Rule, Process Model, Record Type, CDT/Data Type,
Integration, Web API, Site, Control Panel, Constant, Connected System, Group, Decision, Data Store, AI Skill, AI Agent,
Translation Set, Translation String, Document, Folder, Application** — plus **Tempo Report** (Jarvis has
`parseTempoReportHaul`; we currently have no Tempo Report parser) and a **generic content-haul fallback**
(Jarvis `parseGenericHaul`) so an unrecognized/new content type still extracts references instead of dropping out. Each
gets a golden fixture + expected-extraction snapshot.

> **Prior art — Jarvis parser (`jarvis-plugin.jar`, decompiled 2026-08-07).** The Jarvis Appian plugin (Java) treats our
> exact weak areas as first-class and we adopt its proven logic: the `RULENAME_PATTERN` (`ruleName:\s*"…"`) by-name
> extractor; the `APPREF_NAME_PATTERN`/`ENTRYPOINT_NAME_PATTERN` regexes + the 10-value category taxonomy +
> `crossAppRole/crossAppTarget/crossAppCaller/targetEntrypoint` fields (§4.4); the full URN set incl. **record-action** +
> **translation-string** (§4.1); the `SYSTEM_RULES_OVERRIDES` system-rule exclusion/behavioral `TagDetector` set (§4.1
> precision guard, and a future capability-signal input for the Business Map); a **generic haul fallback**; a **Tempo
> Report** parser; and analytics (`referencedBy` reverse index, `centralRecordTypes` hubs, `entryPointsByType`,
> `orphanCluster`) that align with our KB tools + a richer future orphan-cluster model.

---

## 7. Sub-phases & release plan

- **18-01 — Accuracy harness + oracle + baseline lock.** Commit the raw-XML oracle + scoring harness as a test/tool;
  record the baseline numbers; wire a CI accuracy report (non-gating first). *No behavior change.* **✅ DONE (parser afcb66d).**
- **18-02 — Edge recall: universal known-UUID scan + reference forms.** Implement §4.1; re-measure recall. *Biggest win.*
- **18-03 — Orphan semantics + translation/document edges.** Implement §4.2 + resolve §5; re-measure false-orphan rate.
- **18-04 — APPREF/ENTRYPOINT integration points (§4.4).** By-name `rulereferencebyname` edge extraction + integration-role
  classification + orphan exemption + external-reference retention; targeted tests + the `KbObject` surface fields.
- **18-05 — Per-object-type audit + golden fixtures.** §6; fill field/relationship gaps; per-type regression tests.
- **18-06 — Gate + release + rollout.** Turn the accuracy thresholds into a CI gate (≥95%); release
  `genesis-appian-parser` vX; repin `genesis` + `sync-application`; re-baseline any tracked apps (a fresh sync
  recomputes edges/orphans/bundles); update docs (spec/progress/tracker/bible §2/§7).

**Release chain:** `genesis-appian-parser` (new tag) → `genesis` (repin) → `genesis-workflows` (`sync-application` pin).
Existing KB rows are recomputed by the next `sync-application` run (baseline or delta re-export).

---

## 8. Risks

- **Over-linking (precision loss)** from the broad scan — mitigated by known-UUID gating + the precision metric + CI gate.
- **Graph size / sync cost** if translation-string edges balloon the edge count (1,316 strings) — measure; if needed,
  keep translation edges but exclude the type from bundle traversal.
- **Second-package generalization** — 95% on one package may not hold on another; acquire a second real export for the
  harness if possible (the fixture is the AI Document Center app).

---

## 9. Best-of-both concept decision matrix (Atlas ⋈ Jarvis ⋈ ours)

Full read-only inventories of both references done 2026-08-07 (Atlas `appian/solutions-atlas-parser` on disk + indexed;
Jarvis `jarvis-plugin.jar` decompiled with `javap`). **Major finding: our front-half port dropped three whole Atlas
layers** — `output/app_cross_app_builder.py`, `output/graph_builder.py`, and the entire `enrichment/` package — which is
*why* cross-app links and the inbound/outbound graph are missing. Decisions:

| Concept | Atlas | Jarvis | Ours today | Decision (best of both) |
|---|---|---|---|---|
| Per-type parsers + resolvers (UUID/RT-URN incl. name/chain/%40, translation URN, canonical/base fallback) | ✅ | ✅ | ✅ (faithful port) | **Keep ours** — already equal/better |
| Cross-app **APPREF/ENTRYPOINT — object-level** (by-name edges, `integration_role`, category, orphan-exempt) | name-convention map only (no object edges, no orphan fix) | ✅ rich: `RULENAME_PATTERN`, 10-cat taxonomy, crossAppRole/target, pairing | ❌ | **Adopt Jarvis model** (18-04) |
| Cross-app **app-level map** (entry_points / app_references / prefix→prefix edges) + **shared-library usage** (cross-prefix call aggregation) | ✅ `app_cross_app_builder.py` | partial | ❌ (dropped) | **Adopt Atlas** `app_cross_app_builder` (18-04) |
| Graph model: **inbound/outbound counts + is_hub** | ✅ `graph_builder.py` | ✅ directCallers/callersByType | ❌ (dropped) | **Adopt Atlas GraphBuilder** (18-03) |
| **Orphan definition** | `len(bundles)==0` (bundle-based) | reachability dead-code + `orphanCluster` | `not bundled` (same flaw) | **Redefine ours**: `is_orphan = inbound==0 AND outbound==0`, integration-exempt; add `not_bundled` separately; Jarvis `orphanCluster` = richer future layer (18-03) |
| Edge forms: record-**action** URN, `rulereferencebyname` by-name | partial | ✅ | ❌ | **Adopt** (18-02/18-04) |
| **System-rule set** (`SYSTEM_SYSRULES_*` exclude + behavioral tag) | ❌ (none) | ✅ `SYSTEM_RULES_OVERRIDES` + ~40-entry tag table | ❌ | **Adopt Jarvis** — precision guard + capability tags (18-02) |
| Universal known-UUID scan (catch Constant/AI-Skill/Decision/Doc refs) | ❌ (field-path-scoped) | ❌ (field-path-scoped) | ❌ | **New (ours)** — neither ref does this; our biggest recall win (18-02) |
| Object coverage: **Tempo Report**, AI Agent, control-panel tier item, **generic haul fallback** | AI Agent ✅ | ✅ all incl. Tempo/generic | partial (no Tempo/generic) | **Adopt** (18-05) |
| Enrichment: `referencedBy`, statistics, hubs/`centralRecordTypes`, entryPointsByType | ✅ `enrichment/` pkg | ✅ AnalyticsGenerator | partial (KB tools) | **Adopt referencedBy + hubs + stats** (18-03/05); tags/depth/critical-path = nice-to-have |
| Capability/domain builders (business meaning) | ✅ `app_capability_builder.py`/`app_domain_builder.py` | ✅ DescriptionGenerator | Phase-17 does this via agent | **Skip in parser** — Phase 17 owns business synthesis; note as input |
| Versioning / DDL schema replay (`schema/`, `versioning/`) | ✅ | partial | ❌ | **Adopt-later** — aligns with 16-06 backlog (write-set/schema), not this phase |
| `_v\d+$` version-suffix normalization on names | — | ✅ | ❌ | **Adopt** (small recall/precision win, 18-02) |

## 10. What the comparison changes in the plan

The sub-phases in §7 stand; the comparison makes several of them **"restore from Atlas + enrich from Jarvis"** rather
than build-from-scratch, which de-risks them:
- **18-02 (recall):** universal known-UUID scan (ours, novel) **+** record-action URN + `_v\d+$` normalization + system-rule
  exclusion (Jarvis).
- **18-03 (orphan/graph):** port Atlas **`graph_builder.py`** (inbound/outbound/is_hub) and **redefine `is_orphan`** off
  those counts (not bundles); add `referencedBy`/stats from Atlas `enrichment/`.
- **18-04 (integration points):** adopt Jarvis's **object-level** model (by-name edges, category taxonomy, orphan-exempt)
  **+** restore Atlas **`app_cross_app_builder.py`** for the app-level map + shared-library usage.
- **18-05 (coverage):** add Tempo Report + generic-haul fallback (Jarvis); adopt Jarvis TagDetector behavioral tags as a
  capability signal.

**Bottom line for the "analyze vs build" question:** analysis is now COMPLETE (root cause + baseline + full two-source
comparison). Everything else is implementation, each step measured against the 18-01 oracle. No further analysis phase.

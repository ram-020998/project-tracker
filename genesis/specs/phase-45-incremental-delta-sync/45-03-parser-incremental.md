# 45-03 — Parser: KB-aware incremental parse (genesis-appian-parser v0.3.0)

> **Status:** 🟡 DRAFTED. Repo: **genesis-appian-parser**. Implements the parser half of **ADR-074**.
> Parent: `specs/phase-45-incremental-delta-sync.md`. Evidence: `45-01-findings.md` §5.

## 1. Problem

`DependencyAnalyzer._build_lookups` and `_build_qname_lookup` index only the objects in the zip, so a reference to an
object outside the package is dropped. Bundles, orphans, hubs and inbound/outbound counts are computed over the
package only. A delta package (changed objects + roots) therefore produces 0% of the changed objects' outgoing edges
and a handful of bundles.

## 2. API (additive; `parse(zip)` unchanged)

```python
@dataclass
class KnownObject:          # one current KB object (code-free)
    uuid: str; name: str; type: str          # parser object_type ("Expression Rule", "CDT", …)
    metadata: dict = field(default_factory=dict)   # kb_objects.metadata_json (incl. CDT namespace)
    description: str | None = None

@dataclass
class KnownEdge:
    source_uuid: str; target_uuid: str; dep_type: str
    source_name: str | None = None; target_name: str | None = None
    source_type: str | None = None; target_type: str | None = None

def parse(source, *, locale="en-US", exclude_types=None,
          known_objects: list[KnownObject] | None = None,
          known_edges: list[KnownEdge] | None = None) -> KbParseResult
```

When `known_objects` is given (**incremental mode**), the result has these semantics:
- `objects` = **package objects only** (full metadata, fresh `diff_hash`).
- `edges` = **outgoing edges of package objects only**, resolved against package + known objects.
- `bundles` = **all bundles of the app**, built from package objects (full data) + known-object stubs, over the edge
  set `known_edges − (edges whose source is a package object) + new package edges`.
- `orphans` and the derived metadata (`inbound_count`, `outbound_count`, `is_hub`, `is_bundled`, `is_orphan`,
  entry-point flags) computed over the **whole app** (package + known).
- `stats["derived"]` = `{uuid: {inbound_count, outbound_count, is_hub, is_bundled, is_orphan}}` for **every** app
  object, so the KB can update unchanged objects in place (45-04).
- `stats["incremental"] = {package_objects, known_objects, edges_resolved_external}`.

## 3. Implementation

1. **Stubs:** each `KnownObject` → `ParsedObject(uuid, name, object_type=type, data={**metadata, "description": …})`.
   Package objects override stubs of the same uuid.
2. **Lookups:** build uuid/name/qname lookups over package + stubs (existing `_build_lookups` /
   `_build_qname_lookup`, unchanged logic incl. canonical/base-uuid and `_vN` stripping).
3. **Extraction:** run `_extract_for_object` for **package objects only** (raw XML available only for them).
4. **Integration-point classification:** package objects classified as today; for known objects, reuse
   `metadata.is_integration_point/integration_*` (already stored).
5. **Resolver:** `ReferenceResolver` runs over package objects with the combined name map so readable names resolve.
6. **Bundles:** `BundleCoordinator.build_all_v3(package + stubs, merged_edges)`. Entry-point discovery reads
   `obj.data`; stubs carry the code-free fields bundles use. Roots **must** be package objects (the delta package always
   includes them — 45-06). A stub that is an entry point (root missing from the package) is still discovered from its
   metadata where possible; if its full data is required and absent, keep the KB's existing bundle (flag
   `stats.incremental.roots_missing`).
7. **Hub/orphan/inbound:** computed over the merged edge set.
8. **`root_uuid` fix (both modes):** set `KbBundle.root_uuid` from the entry point's uuid (today `entry_point` is
   the detail dict, which has no `uuid` key → always None).

## 4. Tests (new; real vendored package fixture)

- **Equivalence oracle:** for random samples from the fixture, `parse(sub_package, known_objects=stubs(full),
  known_edges=edges(full))` reproduces the full parse's outgoing edges for package objects (recall = 1.0,
  precision = 1.0) and bundles (identical ids, membership, flow, entry point). Gate in CI.
- No-known-objects call is byte-identical to v0.2.0 behaviour (except `root_uuid`).
- `stats.derived` matches the full parse's per-object derived metadata.
- `root_uuid` populated for every bundle.
- The existing ≥95% accuracy oracle stays green.

## 5. Release

`v0.3.0` (minor, additive). genesis re-pins it in 45-10.

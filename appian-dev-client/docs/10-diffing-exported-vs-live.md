# 10 — Diffing an Exported (Unimported) Object vs. the Live Environment

Goal: given an object sitting in a normal Appian **export package** (not yet imported), show a
diff against the **live** object in the environment. We can already read the live object via the
plugin. This doc explains how to represent the exported object comparably, and prototypes the
plugin support.

## The three representations problem

The same object has three incompatible serializations:

| Representation | Produced by | Notes |
|---|---|---|
| **Plugin JSON** | `ObjectRenderer` + `*Mapper` over **live domain objects** | curated, lossy |
| **IX export XML** | `Haul` subclasses via JAXB/MOXy (`ContentHaul`, `RecordTypeHaul`, …) | complete transport form; what's in an export `.zip` |
| **appian-dev YAML** | `roundtrip` (stripped UUIDs, display-form refs) | checkout format |

A normal Appian export `.zip` contains per-object **IX XML**, named `[typeKey]/[uuid].xml`
(`XmlZipExportDriver`), references by UUID. That is a different representation from the plugin
JSON your client reads. The plugin mappers consume **live domain objects**, not Hauls, so there
is no free "export file → plugin JSON" path.

## Why the conversion must live in the plugin

Turning an exported object into anything typed requires parsing its Haul XML through Appian's IX
framework (`IxTypeRegistry`, `Haul`, the import drivers) — which needs the Appian engine and type
system. Only code running **inside the Appian JVM** (i.e. the plugin) can do that. The external
client cannot. Fortunately the plugin already has all the machinery:

- Exports live objects to IX: `ExportFacade.export(...)` (used by `DeploymentHandler`).
- Builds `ContentHaul`s in memory: `ObjectExpressionChecker`.
- Uses the conflict model: `ConflictDetectionHaul`, `Haul.generateDiffHash`, `ImportChangeStatus`
  (`NEW / CHANGED / CONFLICT_DETECTED / NOT_CHANGED / CONFLICT_RESOLVED / UNKNOWN`), and reads
  precomputed `diffHash` from the search index (`DesignObjectSearchService.getDiffHashes`).

## Alternative: diff in IX-XML form (no conversion)

If you'd rather not convert, you can diff **both sides in IX XML**: the exported side is already
IX XML, and a plugin route can export the live object's IX XML (`GET /objects/{uuid}/export-xml`,
see `ExportXmlHandler`). This reuses Appian's own conflict model (`generateDiffHash`,
`ConflictDetectionHaul`, `ImportChangeStatus`) and never touches the mappers. It's more faithful
for a "will importing change anything?" verdict, but the diff is XML, not your JSON format. Use it
when you want the exact import-conflict verdict; use the converter (above) when you want the
objects in live JSON form.

## The prototype

Reference handlers live in [`../prototype/plugin/`](../prototype/plugin/):

- **`ConvertExportHandler.java`** — `POST /objects/from-export-xml` (the primary one): IX export XML
  → live plugin JSON, via `HaulMarshaller` → Haul domain getter → `ObjectRenderer`.
- **`ExportXmlHandler.java`** — `GET /objects/{uuid}/export-xml`: a live object's IX XML (the
  alternative, for an IX-XML-vs-IX-XML diff).

See the prototype README for the verified building blocks and the `// VERIFY` wiring points.

## End-to-end diff flow (target design)

```
          ┌─ exported side ─┐                         ┌─ live side ─┐
export.zip → unzip [uuid].xml (IX XML)        plugin GET /objects/{uuid}/export-xml (IX XML)
          └────────────┬─────────────┘                └──────┬──────┘
                       └──────────────► canonicalize both ◄───┘
                                              │
                                      textual / structural diff
                                      + ImportChangeStatus verdict (NEW/CHANGED/CONFLICT/NOT_CHANGED)
                                              │
                                      render diff view (client)
```

Client responsibilities (our `appian-dev-client`): hold the export `.zip`, read the per-object
XML, call the new route for the live XML, canonicalize, diff, and render. The plugin does the
Appian-internal work.

## Chosen approach: convert the exported object to live JSON (internal functions)

Appian's IX classes let us turn an exported object's XML into the **same domain object the live
services return**, then render it with the plugin's own renderer — producing JSON identical to a
live read, in memory, with **no import**. This is the approach to build.

### The pipeline (all internal Appian/plugin functions)

```
[uuid].xml (from export .zip)
   │  HaulMarshaller + XmlContext.getContext()      ← internal "XML → Haul" unmarshaller
   ▼
 Haul  (ContentHaul | RecordTypeHaul | ProcessModelHaul | SiteHaul | …)
   │  domain-object getter:
   │    ContentHaul.getIxObject()       → Interface / FreeformRule / Constant / Decision / Document (all Content)
   │    RecordTypeHaul.getRecordType()  → RecordTypeDefinition
   │    ProcessModelHaul.getProcessModel() → ProcessModel
   ▼
 the SAME domain object a live read holds
   │  ObjectRenderer.renderContent / renderRecordType / renderProcessModel / renderSite …
   ▼
 plugin JSON (identical shape to a live object)
```

### The internal functions

| Step | Internal function | Where |
|---|---|---|
| XML → Haul | `HaulMarshaller.createUnmarshallerAndUnmarshall(Node)` over `XmlContext.getContext()` | `com.appiancorp.ix.xml.HaulMarshaller` (ae). Javadoc: "broken out so ... other clients ... can use it." |
| Haul → content object | `ContentHaul.getIxObject()` → a `Content` subtype | `com.appiancorp.ix.data.ContentHaul` — `@XmlElements` map `interface`→`Interface`, `rule`→`FreeformRule`, `constant`→`Constant`, `decision`→`Decision`, `document`→`Document` |
| Haul → record type | `RecordTypeHaul.getRecordType()` → `RecordTypeDefinition` | `com.appiancorp.ix.data.RecordTypeHaul` |
| Haul → process model | `ProcessModelHaul.getProcessModel()` → `ProcessModel` | `com.appiancorp.ix.data.ProcessModelHaul` |
| domain object → JSON | `ObjectRenderer.renderContent / renderRecordType / renderProcessModel / renderSite / renderWebApi` | the plugin's own renderer — the exact code path the live GETs use |

Because the final step is the plugin's own `ObjectRenderer`, the converted JSON is byte-for-byte
what a live read produces — so diffing is plugin-JSON vs plugin-JSON from one renderer.

### Why this must live in the plugin

`HaulMarshaller`, `XmlContext`, the Haul classes and `ObjectRenderer` all require the Appian type
system and only coexist in the plugin's JVM. The external client cannot do this; it POSTs the XML
and gets JSON back. See the prototype route `POST /objects/from-export-xml`
([`../prototype/plugin/ConvertExportHandler.java`](../prototype/plugin/ConvertExportHandler.java)).

### Expected (correct) differences

Server-assigned fields absent on an unimported object — numeric id, `versionId` — render as
null/empty. That is accurate (the object isn't on the environment yet) and is exactly what a
design-content diff should show.

## Deployment prerequisite (important)

The `export-xml` route is a **new handler we add to the plugin**. It does not exist on any stock
build. Calling it against a plugin that doesn't have it returns the generic
`501 {"error":"Operation not implemented by this plugin version"}` — which is exactly what the
deployed `merge-assist-dev` build (v26.6.110) returns, because:

- that build has **no export/deployment routes at all** (`/applications/{app}/export`,
  `POST /deployments`, `GET /deployments`, `POST /objects/versions` → all 501), and
- even a newer stock build (e.g. 26.9.10) would add `manifest`/`batch`/`deployments`, **not** our
  custom `export-xml` — that route only exists once someone builds this handler into the plugin
  and installs it.

So `export-xml` requires: build the modified `lcp-api-plugin` → install the plugin jar on the
environment → then the Integration works. A 501 before that is expected, not a misconfiguration.

## Zero-development alternative that works today: diff two export packages

Because a **normal Appian export already produces IX XML for live objects**, you don't strictly
need the plugin route to get "both sides in IX XML":

1. Export the application **from the live environment** via normal Appian export (Designer UI,
   admin console, or the deployment API) → an IX `.zip` whose objects are `[typeKey]/[uuid].xml`.
2. You already have the **unimported** package (also IX `.zip`, same layout).
3. Diff `[uuid].xml` from package (2) against `[uuid].xml` from export (1). Same format, no plugin
   change, no new code.

The `export-xml` route is a *convenience* over this: it returns one live object's IX XML on demand
via a single API call, instead of exporting the whole app each time. Use the route when you want
per-object, on-demand live XML inside an automated flow; use the two-package diff when you just
need the comparison now.

## Open items

- **Zip internal layout:** confirmed objects are `[typeKey]/[uuid].xml`; validate the full layout
  (manifest, resources, type-folder labels) against a **real export `.zip`** before building the
  reader.
- **Canonicalization rules:** decide what to normalize (attribute order, volatile fields, ns
  prefixes) so the diff shows only meaningful changes. `generateDiffHash` already encodes Appian's
  notion of "meaningfully equal" — use it as the equality oracle.
- **Batch:** add `POST /objects/export-xml-batch` (one export + one zip read for many objects).
- **Datatype local ids** are QNames, not Longs — handle before relying on the route for data types.

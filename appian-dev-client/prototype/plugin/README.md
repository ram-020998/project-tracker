# Prototype: exported-object → live-JSON conversion (plugin routes)

Reference plugin handlers that let you turn a normal Appian **export package** object into the
**same JSON a live read produces**, so you can diff an unimported object against the environment.

See [`../../docs/10-diffing-exported-vs-live.md`](../../docs/10-diffing-exported-vs-live.md) for
the design.

## Files

| File | Route | What it does |
|---|---|---|
| `ConvertExportHandler.java` | `POST /objects/from-export-xml` | **Primary.** IX export XML → live plugin JSON. Unmarshal the `[uuid].xml` into a Haul, pull its domain object, render with the plugin's own `ObjectRenderer`. No import. |
| `ExportXmlHandler.java` | `GET /objects/{uuid}/export-xml` | Alternative. Returns a *live* object's IX XML (for an IX-XML-vs-IX-XML diff). |
| `RequestRouter.additions.java` | — | Route-registration lines + imports to add to `RequestRouter.java`. |

## The converter pipeline (all internal functions)

```
[uuid].xml  --HaulMarshaller + XmlContext-->  Haul
            --Haul.getIxObject()/getRecordType()/getProcessModel()-->  domain object
            --ObjectRenderer.renderContent/renderRecordType/...-->  plugin JSON
```

## Where it goes in the real repo

Both handlers belong in the **`lcp-api-plugin`** module of the `composer` repo:

```
service-components/lcp-api-plugin/src/main/java/com/appian/research/lcpapis/
  handlers/ConvertExportHandler.java      ← new (primary)
  handlers/ExportXmlHandler.java          ← new (alternative)
  routing/RequestRouter.java              ← add the route lines + imports
```

They are **reference Java**: they compile against the plugin + `ae` classpath inside the Appian
build, not in this repo. Copy them into a plugin working tree to build/test.

## Verified building blocks (grounded in real plugin/ae code)

| Step | Call | Seen in |
|---|---|---|
| XML → Haul | `new HaulMarshaller<>(scProvider).createUnmarshallerAndUnmarshall(domNode)` over `XmlContext.getContext()` | `com.appiancorp.ix.xml.HaulMarshaller` (ae) |
| content object off haul | `ContentHaul.getIxObject()` → `Interface`/`FreeformRule`/`Constant`/`Decision`/`Document` | `ContentHaul` `@XmlElements` |
| record type off haul | `RecordTypeHaul.getRecordType()` → `RecordTypeDefinition` | `RecordTypeHaul` |
| process model off haul | `ProcessModelHaul.getProcessModel()` → `ProcessModel` | `ProcessModelHaul` |
| content category | subtype switch (`SUBTYPE_RULE_CONSTANT/FREEFORM/INTERFACE`) | `ObjectResolver.categorizeContent` |
| render → JSON | `ObjectRenderer.renderContent / renderRecordType / renderProcessModel / renderSite` | `ObjectRenderer` (live GETs use it) |
| (alt) live IX XML | `ExportFacade.export(map, cs, sc, folderId, name)` → zip → `[uuid].xml` | `ExportApplicationsAction`, `DeploymentHandler`, `XmlZipExportDriver` |

## Spots to confirm in your build (`// VERIFY`)

- **`ServiceContextProvider`** bean for `HaulMarshaller`'s constructor (fetched via
  `ApplicationContextHolder`, as `DeploymentHandler` does for its beans).
- **`categorizeContent`** — prefer exposing/reusing `ObjectResolver`'s existing private method
  over the copy in the prototype.
- **`SiteHaul.getSite()`** and other hauls' domain getter names — confirm per type as you extend.
- (ExportXmlHandler only) the **IX folder id** source and **`SecurityEscalator`** bean, both
  copied from `DeploymentHandler`.

## Expected (correct) differences from a live read

An unimported object has no server-assigned numeric id or `versionId`, so those render null/empty.
That's accurate and is exactly what a design-content diff should surface.

## How to test once integrated

```bash
BASE="https://<host>/suite/plugins/servlet/stateless/lcp-api"
# 1. the converted (exported) side — POST the object's [uuid].xml from an export .zip:
curl -sS -u "<user>:<password>" -X POST "$BASE/objects/from-export-xml" \
  -H 'Content-Type: application/xml' --data-binary @path/to/<uuid>.xml
# 2. the live side — the existing read:
curl -sS -u "<user>:<password>" "$BASE/interfaces/<uuid>"
# 3. diff the two JSON documents.
```

## Notes / refinements

- **Batch** both routes (`POST /objects/from-export-xml-batch` accepting a zip + uuid list) for
  whole-application diffs.
- Consider having the converter accept the **whole export `.zip`** + a uuid and locate the
  `[uuid].xml` itself, so the client doesn't have to unzip.
- Normalize for diffing: ignore the known-null server fields (id, versionId) so they don't show as
  spurious changes.

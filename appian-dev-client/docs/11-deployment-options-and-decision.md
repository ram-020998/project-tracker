# 11 — Deployment Options & Decision

This doc records *how* the exported-object → live-JSON converter can be delivered, the trade-offs,
and the open decision. It follows from [`10-diffing-exported-vs-live.md`](10-diffing-exported-vs-live.md),
which establishes the converter pipeline; this doc is about **where that code runs and how it ships**.

## The hard constraint: it must run inside the Appian JVM

The converter chain uses classes that only exist on the Appian server classpath:

| Piece | Lives in |
|---|---|
| `HaulMarshaller`, `XmlContext`, the `Haul` classes (XML → Haul → domain object) | `ae` (core engine) |
| `ObjectRenderer` + the `*Mapper`s (domain object → the exact plugin JSON) | `lcp-api-plugin` |

Neither the external `appian-dev-client`, nor an Appian SAIL expression, nor a Web API object can
invoke these. The only place all of them coexist is **a plugin running inside the environment**.
So the converter ships as a plugin route; the external client (or an Appian Integration) just calls
it over HTTP.

**Consequence:** calling the prototype route against a plugin that doesn't contain it returns
`501 {"error":"Operation not implemented by this plugin version"}` — which is exactly what
`merge-assist-dev` (plugin v26.6.110) returns today, because the route isn't built in. That 501 is
expected, not a misconfiguration; the Integration/Connected System are fine.

## Does this mean modifying the composer plugin?

As prototyped: **yes.** The handlers (`ConvertExportHandler`, `ExportXmlHandler`) add routes to
`lcp-api-plugin`, which is part of the `composer` repo (the `appian-dev` / `dev-mcp` line). There
are other shapes, but each gives something up. The three real options:

### Option 1 — Modify / extend `lcp-api-plugin` (what the prototype does)

- **Pro:** reuses the plugin's own `ObjectRenderer` / `*Mapper`s, so the converted JSON is
  **guaranteed identical** to a live read. Least code. One rendering path, no drift.
- **Con:** it is Appian's plugin. Shipping the change means either landing it upstream in the
  composer `appian-dev`/`dev-mcp` branch (official plugin build + App-Market release) or building a
  custom fork jar for a dev environment. Not appropriate to slip into a customer environment ad hoc.

### Option 2 — A separate, standalone plugin of your own

- **Pro:** you own it and can install it independently. `ae`'s IX classes (`HaulMarshaller`, the
  `Haul`s) are on the server classpath, so the XML → domain-object half works.
- **Con:** the **mappers that produce the JSON live in `lcp-api-plugin`, not in `ae`.** So you must
  either depend on that plugin's classes (brittle cross-plugin coupling) or **re-implement the
  mapping** — which then drifts from the real format over time. You lose the "guaranteed identical"
  property that was the whole point.

### Option 3 — No plugin changes at all

- **3a. Diff two export packages (IX XML).** Export the live app normally → IX XML; diff `[uuid].xml`
  from the unimported package vs the live export. Zero code, works today. Catch: it's XML, not the
  live JSON format.
- **3b. Sandbox import, then read via existing routes.** Import the package into a throwaway app,
  call the existing `GET /interfaces/{uuid}` etc. → live JSON, diff against the real object, delete
  the scratch app. No new code. Catch: it mutates the environment temporarily.

## The trade-off, in one line

**If you want the exported object in the *exact* live-JSON format, you must run inside the plugin
that owns the mappers — i.e. extend `lcp-api-plugin`.** If you can't touch that plugin, you fall
back to IX-XML diffing (Option 3a) or a duplicated-mapper standalone plugin (Option 2), each of
which gives up fidelity or adds maintenance.

## How a plugin is deployed (for Options 1 / 2)

1. **Add the handler + route** (the prototype files + the `RequestRouter` lines).
2. **Build the plugin jar** — `lcp-api-plugin` builds via Gradle; the repo's `tools/plugin-factory`
   packages/publishes it.
3. **Install on the environment** — Admin Console → Plugins (upload the jar), or publish through the
   App-Market channel this plugin already uses (`/meta` advertises an App-Market update link for it).

Two routes to get there:
- **Official:** land the route in the composer `appian-dev`/`dev-mcp` branch → normal plugin build +
  App-Market release → the environment picks up the new version.
- **Custom / test:** build a forked plugin jar with the handler and install it on a dev environment
  you control. Whether `merge-assist-dev` (a preview env) allows a hot custom-jar install depends on
  your admin access there.

## Open decision (needs an answer before building further)

**Can we land changes in the composer `lcp-api-plugin` (or get an official build), or must this be
deployed independently?**

- If **yes, we can extend `lcp-api-plugin`** → Option 1. Proceed to productionize the prototype
  (`ConvertExportHandler`), confirm the `// VERIFY` wiring points, build, install on a dev env,
  validate against a real `[uuid].xml`.
- If **no, it must be standalone** → Option 2 (accept mapper duplication/coupling) or stay on
  Option 3a (IX-XML diff) / 3b (sandbox import).

## Status / next steps

- Prototype written (Option 1): see [`../prototype/plugin/`](../prototype/plugin/).
- Not yet built or deployed anywhere; `merge-assist-dev` returns 501 for the prototype routes (expected).
- Blocked on the open decision above.
- Once decided: (a) write the exact Gradle build + Admin-Console install steps, (b) validate with a
  real export `[uuid].xml` vs the live JSON for the same object, (c) optionally add batch variants.

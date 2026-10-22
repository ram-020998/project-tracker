# Understanding — Three-Way Merge Assistant (3WM), the original desktop app

> **Role in Upgrade Assist:** 3WM is the **origin of the product idea** and the source of the **merge/diff
> algorithm and object-parsing knowledge**. It is the standalone tool customers used before we moved the product into
> Appian. Read this to understand the domain problem and the classification logic we re-implemented in Appian.

- **Location:** `/Users/ramaswamy.u/repo/3WM`
- **Captured:** 2026-10-22 (from README.md + QUICKSTART.md + repo layout).

---

## ⚠️ Correction to the common framing

3WM is frequently described as "the React app". **It is not React.** The repo at `/Users/ramaswamy.u/repo/3WM` is a
**Flask / Python** application:

- **Backend/UI:** Flask 2.3+ (Werkzeug WSGI), **Jinja2 templates + Bootstrap CSS + vanilla JavaScript**.
- **Packaging:** a **native desktop app via `pywebview`** (macOS `.app` / Windows ZIP), launched by `3wm.sh` / `3wm.bat`
  (which bootstrap `uv`, Python, deps, then start the app at `http://localhost:5000`).

This still matches the product history: it is the **locally-installed desktop tool** customers said they did not want
to run on their own machines. If an earlier pure-React prototype existed, this repo is not it — this is the Python
desktop tool that the Appian application (Merge Assist / Upgrade Assist) replaces.

## 1. The problem it solves

Enterprise Appian customers buy a vendor solution, then **customize it**. When the vendor ships a new version, merging
vendor updates with customer customizations is painful: hundreds of interdependent objects, dual modification, and no
good way to see what actually conflicts. 3WM automates the **three-way merge analysis**.

## 2. The three-way model (set theory)

Three package versions are compared:

- **Package A — Base:** the original vendor package before customizations.
- **Package B — Customer:** base + customer modifications.
- **Package C — New Vendor:** the latest vendor package.

> **Key difference from the Appian version:** in 3WM **all three are uploaded ZIPs**. In Merge Assist / Upgrade Assist,
> the **customer version (B) is the live Appian environment**, not an upload. See `merge-assist-appian.md` §4.

Changes are classified by set membership + a content check (SHA-512 **diff hashes**, mirroring Appian's own approach —
same hash = identical content despite different version UUIDs):

| Scenario | Membership | Content | Classification |
|---|---|---|---|
| Vendor modified, customer didn't | D only | — | COMPATIBLE |
| Customer modified, vendor didn't | E only | — | COMPATIBLE |
| Both modified identically | D ∩ E | B = C | COMPATIBLE |
| Both modified differently | D ∩ E | B ≠ C | **CONFLICT** |
| Vendor added new object | D (NEW) | — | NEW |
| Vendor removed, customer modified | D (DEPRECATED) ∩ E | — | DELETED |

(D = vendor delta A→C; E = customer delta A→B.) Output is ordered CONFLICT → DELETED → NEW → COMPATIBLE.

## 3. Architecture (clean layered DI)

```
HTTP → Controllers (Flask blueprints) → Services (business logic) → Repositories → Models (SQLAlchemy ORM)
```

Core services (the pieces we re-implemented as Appian expression rules / process models):

- **ThreeWayMergeOrchestrator** — coordinates a 10-step workflow.
- **PackageExtractionService** — ZIP extraction → XML parse → SAIL formatting + UUID resolution, via
  **ZipExtractionService / ObjectProcessor / PostExtractionProcessor**.
- **DeltaComparisonService** (A→C, set D) and **CustomerComparisonService** (A→B, set E).
- **ClassificationService** — the set-based conflict rules above.
- **DependencyExtractionService / DependencyOrderingService** — extract object dependencies from SAIL and compute a
  dependency-aware review order.
- **~12 object-type parsers** (`services/extraction/parsers/handlers/`) + object-specific **comparison strategies**
  (`domain/comparison_strategies.py`): Interface, Expression Rule, Process Model, Record Type, CDT, Integration, Web API,
  Site, Group, Constant, Connected System, Control Panel.
- Optional **async AI summaries** of changes.

Tech: Python 3.10+, SQLAlchemy (SQLite dev / PostgreSQL prod), openpyxl/python-docx for export, pytest (unit/integration/
e2e markers, 80% coverage gate), GitHub Actions CI, multi-OS + multi-Python matrix.

## 4. REST surface (conceptual parity with the Appian workflow)

- `POST /merge/create` — upload base/customized/new-vendor ZIPs → a session with `reference_id`, status, total changes.
- `GET /merge/api/{ref}/summary` — package stats + counts by classification.
- `GET /merge/{ref}/changes?classification=…` — the working set (filterable), each change carrying classification +
  vendor/customer change types + object identity + display order.
- `POST …/changes/{id}/review | /skip | /notes` — reviewer actions.

## 5. Takeaways we carry into Upgrade Assist

1. **The domain vocabulary and classification semantics are the product's core** — Base / Customer / New-Vendor, the
   set-theory conflict rules, diff-hash content comparison, dependency-aware ordering. All of this survives into Appian.
2. **The ~12 object-type parsers map directly** to Merge Assist's `MA_convert_*` expression rules (see
   `merge-assist-appian.md` §3).
3. **Per-change review workflow** (review / skip / notes, ordered by conflict priority) is the UX the Appian app
   re-creates and the React app must preserve.
4. It is a **single-user, in-memory, synchronous** tool — several of its "known limitations" are exactly why the product
   moved onto Appian (multi-user, persisted, platform-native).

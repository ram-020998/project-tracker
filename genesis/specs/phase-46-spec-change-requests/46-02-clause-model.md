# 46-02 — The spec clause model (stable IDs, repair, fingerprints, labels)

> **Status:** 🟡 DRAFTED 2026-10-14. Repo: **genesis**. Implements the clause half of **ADR-075**.
> Parent: `specs/phase-46-spec-change-requests.md`. Findings: `46-01-findings.md` §3.2.

## 1. Goal

Give every part of a spec a **stable identity** that survives the agent rewriting the document, so stories can link
to it and a later change can be traced to exactly the stories it affects. The agent is asked to preserve IDs, but
**program code owns them**: it assigns, repairs and de-duplicates them after every agent turn.

## 2. Terms

| Term | Meaning |
|---|---|
| **Block** | An HTML element Genesis treats as one unit of spec content (§3). |
| **Section** | A heading block (`h2`, `h3`, `h4`). It groups the clauses that follow it until the next heading of the same or higher level. |
| **Clause** | A non-heading block: one requirement, rule, bullet, table row, definition, or paragraph. |
| **Clause ID** | The hidden attribute `data-cid="c-<8 lowercase hex>"`, e.g. `data-cid="c-9f2a1c0b"`. Unique within the spec. Never reused after removal. |
| **Fingerprint** | `sha256(normalized_text)[:16]` of the block's own text (§5). Changes only when the wording changes. |
| **Label** | The human reference shown in the UI, computed from document order (§6): sections `3`, `3.2`; clauses `§3.2-1`. Labels may shift between revisions; IDs never do. |
| **Clause map** | The ordered list of blocks of one spec version: `{clause_id, kind, tag, label, section_path, text, fingerprint, parent_section_id}`. |

## 3. Which elements are blocks

Applied by `genesis/kb/spec_clauses.py` (new) with BeautifulSoup + the stdlib `html.parser` backend. Pin
`beautifulsoup4==4.15.0` as a **direct** dependency in `pyproject.toml` (today it is only transitive via
`markdownify`; same version already installed).

- **Sections:** every `h2`, `h3`, `h4` inside `<body>`.
- **Clauses:** inside `<body>`, every
  - `p` that is not inside another block,
  - `li` — its own text only (text of nested `ul`/`ol` belongs to the nested `li`s),
  - `tr` inside `tbody` (or inside a `table` without `thead`, excluding the first row when it contains only `th`),
  - `dt` and `dd`,
  - `blockquote`, `pre`.
- **Excluded:** the document title (`h1`, `title`), anything inside `<header>`, `<nav>`, `<footer>`, `<script>`,
  `<style>`, any element (and its descendants) with `data-gn-ignore`, and blocks whose normalized text is empty.
- A clause belongs to the nearest preceding section; clauses before the first section belong to a virtual section
  `0` ("Introduction").

## 4. Steering (agent side)

`_STEERING_SPEC` (`genesis/chat/mode_profile.py`) gains a **Structure** paragraph (exact wording to be refined in the
build, meaning fixed):

> Structure the spec with `<h2>`/`<h3>` sections. Write each requirement as its own `<p>`, `<li>` or table row — one
> requirement per element. Genesis adds hidden `data-cid` attributes to these elements. **Never remove, change,
> invent or copy a `data-cid` value.** When you reword a requirement, keep its element (and its `data-cid`). When you
> add a requirement, add a new element without a `data-cid`. When you split one requirement into two, keep the
> `data-cid` on the part that keeps the original meaning. Do not write requirement numbers in the text — Genesis
> numbers clauses automatically.

The agent sees the IDs because the normalizer writes them into the sandbox `spec.html` (§7) before its next turn.

## 5. Normalized text and fingerprints

`normalize_text(block)`:
1. take the block's own text (for `li`: excluding nested lists; for `tr`: cell texts joined with ` | `);
2. Unicode NFKC; replace every run of whitespace with one space; strip.

`fingerprint = sha256(normalized.encode("utf-8")).hexdigest()[:16]`.

`formatting_key = lowercase(normalized)` with every character that is not a letter or digit removed — used only to
recognise **formatting-only** changes (46-05 §3): same `formatting_key`, different fingerprint ⇒ formatting.

## 6. Labels (computed, never stored)

- Sections are numbered by heading hierarchy in document order: `h2` → `1`, `2`, `3`; `h3` under section 3 →
  `3.1`, `3.2`; `h4` → `3.2.1`. A heading level that skips (`h2` → `h4`) is numbered as the next level down.
- Clauses are numbered 1..n within their section: label `§<section>-<n>` (e.g. `§3.2-1`); clauses of the virtual
  section are `§0-1`, `§0-2`.
- Labels are produced with every clause map. Every stored reference keeps the **ID**; documents that need a frozen
  human reference (CR documents, story change history) also store the label **as of that revision**.

## 7. The normalizer — assign and repair IDs

`normalize_spec(html: str, previous: ClauseMap | None) -> (normalized_html, ClauseMap, RepairReport)`:

1. Parse; collect blocks in document order.
2. **Keep valid IDs.** A block whose `data-cid` matches `^c-[0-9a-f]{8}$`, is unique in the document, and exists in
   `previous` (or `previous` is None) keeps it.
3. **Duplicates** (split or copy-paste): among blocks sharing an ID, the one whose fingerprint equals the previous
   fingerprint keeps it; otherwise the one with the highest similarity (step 5) to the previous text keeps it; the
   others are treated as new.
4. **Exact re-anchor.** A block without a (valid) ID whose fingerprint equals the fingerprint of a *previous* block
   whose ID is not yet used in this document takes that ID.
5. **Fuzzy re-anchor.** Otherwise, among unused previous IDs **in the same section** (by section ID), pick the one
   with the highest `difflib.SequenceMatcher(None, a, b).ratio()` on normalized text; take it if ratio ≥ **0.85**.
   If none in the section, try the whole document with ratio ≥ **0.92**. Ties → the earliest in document order.
6. **Mint.** Remaining blocks get a new ID `c-` + 8 hex from `secrets.token_hex(4)`, retried until unique against
   the document **and** every ID ever recorded for this spec (`ClauseRegistry`, §8), so removed IDs are never
   reused.
7. Write `data-cid` onto each block; never touch any other attribute or text. Output is the re-serialized HTML
   (BeautifulSoup `decode(formatter="minimal")`).
8. **RepairReport:** `{kept, re_anchored_exact[], re_anchored_fuzzy[{id, ratio}], minted[], dropped_previous_ids[],
   foreign_ids_removed[]}`. `dropped_previous_ids` are clauses that disappeared (= removed clauses for a diff);
   `foreign_ids_removed` are agent-invented IDs that matched nothing (logged).

Idempotent: running it twice on its own output changes nothing (a test asserts this).

## 8. Where the clause map lives

The clause map is **computed from HTML** whenever needed (parse cost is milliseconds for a spec); no table.

- `previous` for the normalizer = the clause map of `working/last-normalized.html` under
  `settings.feature_stage_artifacts_dir/<spec_stage_id>/` (outside the agent sandbox), updated after every
  normalization. If absent, the latest revision HTML; if absent, None.
- **ClauseRegistry:** `<spec_stage_id>/working/clause-registry.json` = every ID ever issued for this spec with its
  first/last seen revision — used only to prevent reuse. Written atomically (`genesis_core.util.atomic_json`).
- Revisions: each milestone/apply revision file is normalized before it is written, so every revision HTML carries
  IDs; its clause map is computed from the file on demand.

## 9. When the normalizer runs

| Trigger | Where | Effect |
|---|---|---|
| **After every agent turn** of a `feature_spec` session | new `ChatModeProfile.post_turn` hook (`feature_spec` only) invoked by `ChatSession.stream_turn` after the turn completes and before the lock is released | normalizes the sandbox `spec.html` in place (atomic temp + `os.replace`, only if changed) |
| Save milestone | `POST /features/{id}/spec/milestone` | normalizes before writing the revision |
| Initiate CR / Analyze impact / Apply | 46-04 / 46-05 / 46-06 | normalizes first, so analysis and apply see repaired IDs |
| First run on an existing spec | any of the above | assigns IDs to a spec created before Phase 46 (all minted; nothing to repair) |

The hook runs off the event loop (`asyncio.to_thread`), never blocks streaming, and logs (never swallows) a failure
(the §7 "loud failures" lesson). A failure leaves the file unchanged; the next trigger retries.

## 10. API

`GET /features/{id}/spec/clauses?revision=<n>|working` → `{revision, clauses: [{clause_id, kind, tag, label,
section_path, parent_section_id, text, fingerprint}]}`. Default: the **consumer** version (46-04 §6) — the last
completed revision while a CR is open, else the working copy. `GET …/spec/coverage` takes the same `revision`
parameter; the preview passes `working`.

## 11. Preview overlay (data side; UI in 46-07)

The spec artifact endpoints (`GET /features/{id}/spec/artifact`, `…/stages/spec/artifact`) add, **in the served
copy only**:
- `data-gn-label="§3.2-1"` on every block, and `data-gn-stories="<n>"` (clauses only) from the coverage API
  (46-03 §6) when stories or backlog items exist;
- a small stylesheet rendering the label in the left margin and a badge in the right margin (filled = n stories,
  hollow "no story" when 0);
- a tiny script: clicking a badge posts `{type: "genesis:clause", clause_id}` to the parent window (same pattern as
  Lavish's `postMessage`).
The stored HTML never contains these attributes; the normalizer strips any `data-gn-*` attribute it finds.

**Which clause map the overlay uses:** the overlay always matches the HTML being served. The spec chat preview serves
the **working copy**, so labels and coverage are computed from the working map: clauses added in an open CR show a
hollow "no story" badge, removed clauses simply disappear, and coverage counts come from the stories' `spec_refs`
matched by clause ID. Consumers that read the base revision (46-04 §6) use the base map.

## 12. Tests

- Extraction: each block rule in §3, exclusions, nested lists, table rows, virtual section.
- Normalizer: assigns IDs; idempotent; keeps IDs through rewording (ratio ≥ 0.85); re-anchors after the agent drops
  all IDs; split keeps the original ID on the closer half; copy-paste duplicate gets a new ID; never reuses a
  registry ID; strips `data-gn-*`; leaves all other markup byte-identical (golden file).
- Labels: hierarchy, skipped levels, virtual section.
- Post-turn hook: runs only for `feature_spec`; a broken `spec.html` (unparseable) logs and leaves the file.
- A **real spec** fixture (copy of a live AS GSS spec) round-trips: IDs on every block, identical rendered text.

## 13. Acceptance

Editing the spec in the chat for 20 turns (reword, insert, delete, reorder, split) keeps every unchanged and
reworded clause's ID; new clauses get new IDs; removed IDs appear in `dropped_previous_ids`; the rendered spec text
is unchanged by normalization.

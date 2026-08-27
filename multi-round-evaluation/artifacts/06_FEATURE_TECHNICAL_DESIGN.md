# 06 — Feature Technical Design: GSS Multi-Round Evaluations

> **Purpose.** Object-by-object technical design that turns the POC into a **production-quality** build. For each object: what the prototype did, why it works, where it's used — then a **redesigned, optimized, standards-compliant implementation** (with real code). This is **NOT** the prototype code from the environment: the POC was hand-built, unoptimized, inconsistently named, and full of shortcuts. This is where we fix that.
>
> **Reads with:** `artifacts/05_FEATURE_IMPLEMENTATION_PLAN.md` (the *what/where/why*, code-free) and — **governing** — `artifacts/SOLUTIONS - Design Best Practices & Guidance 3.md` (**every design here conforms to it**).
>
> **Status: IN PROGRESS.** Locked so far: the standard (§A), the data model = **Batch 1** (§B), and the compliant worked exemplar (§C). Remaining objects are filled in **batches, in build-sequence order** (§D.3), each batch reviewed before the next.

---

## Decisions locked with the PO (2026-08-27)
1. **Rename / consolidate / eliminate is approved** — the final object set should be *smaller and cleaner* than the 63 prototype objects; signatures may change.
2. **Family key lives on the rounds table** — add **`parentEvalId` to `AS_GSS_EvaluationRound`** (not a new column on `Evaluation`). Family resolution then queries the **rounds table only** (§B.2, §C).
3. **Governing standard** = the best-practices doc. §A distills the parts that most affect this feature; when in doubt, that doc wins.
4. **Delivery in batches** with a review checkpoint after each.
5. **Code depth:** full working SAIL for rules/interfaces; **node-by-node** design for process models (not literal XML).

---

## A. The standard this design follows (distilled from the best-practices doc)

Only the rules that most shape this feature are listed; the full doc governs.

**Querying (§5.E, §3.F).** Never use raw Query Rules or ad-hoc `a!queryRecordType`; use **`AS_CO_UT_queryRecord`** with a `returnType` input (`SINGLE_OBJECT` / `OBJECT_ARRAY` / aggregation / count). It exposes `filters`, `logicalExpression`, `sort`, `pagingInfo`, `relatedRecordData`, `executeWhen`, `triggerRefresh`, and sets `ignoreFiltersWithEmptyValues: true`. **One round-trip per logical need**; filter on **related-record fields** instead of query-then-filter; **select only used fields**; **sort in the query** (the `sort` param), never rely on implicit order.

**Naming (§2–§6).** Keep GSS prefixes: `_QR_` query-record · `_UT_` utility · `_BL_` business logic (customer-tweakable) · `_CPS_`/`_CP_` component · `_SEC_`→ per doc use `_SCT_` for sections · `_FM_` form/modal · `_GRD_` grid · `_UI_` error-on-standalone UI rules · `_VD_` validation · `_CONS_` constant lists · `_ENUM_` grouped constants. Record types trend to `_RecordType` (legacy `_SYNCEDRECORD`); **for GSS consistency we keep `_SYNCEDRECORD`** but note it. Names state intent; **rename** vague/misprefixed prototype objects (each with **OLD → NEW** + migration note).

**Scope & reuse (§1.C, §1.E).** One responsibility per object; inputs/outputs match the name. Break large objects down; **consolidate duplicates**; store repeated logic in a local variable. Don't over-parameterize (>~5 behavioral params → new object).

**Parameters (§1.G).** Keyword syntax always. **Pass full objects**, not individual fields (exception: when called from a record type where only fields are available). **No behavior-changing flag args** (§5.A.1) — split into separate rules instead. Behavioral booleans use `is`/`show`/`allow` prefixes, default sensibly when null, and carry **rule-input descriptions** (start "(Required)…" when required).

**Variables & typing (§1.F, §1.I).** Affirmative names (`isExisting`, not `isNotNew`); plural for arrays; same name for the same concept app-wide. **Strong-type** locals (init via `AS_CO_UT_initializeBlankLocalVariable`); booleans are always `true`/`false`, never null. Don't duplicate a concept across two locals. **Bracket-notation with `a!defaultValue`** for record fields (not `index()`), guard all null-exposed comparisons (`and()`/`or()` don't short-circuit).

**Return (§5.C).** Prefer a consistent return type (cast where sensible); a record-array query rule returns that record-array type by contract.

**Test cases (§5.D).** Every rule gets coverage incl. an all-null case. **Rules that contain DB queries** use test cases named **"Case with No Assertions"** / assertion **"Test Case Completes without Error"**, with a top comment `/*This rule cannot have assertion*/`. No hard-coded i18n labels; no environment-specific/user data (construct complex inputs inline).

**Interfaces (§6).** No `a!form*`; headers via the header pattern. Content meant to nest per round is **embeddable** (no outer header/wrapper inside it). No `paneLayout` in `a!tabItem`. Keep logic out of forms; compartmentalize logic in rules. Load `i18nData` at top and pass down; display via the app's `displayLabel` rule; label-key prefixes per §10.B.

**Constants (§4).** Type sub-prefixes (`INT`/`TXT`/`BOL`/`RT`/`PM`/`REF_TYPE`/`REF_CODE`…). **No array constants** — wrap lists in a `_CONS_` rule. Use constants for DB ids, ref codes, and dependency-checkable references.

**Process models (§7).** Headless **start forms** (so Data Driver can run them); to chain into a form, use a **wrapper process**. **Security:** each entry-point PM has its own `… PM Access` group (business groups as direct members); backend PMs' viewer = the app Security Groups group. **Lane assigned to the initiator.** Alerts → the app Designer Alerts group. Archive user-facing PMs after 3 days; delete backend PMs after 1 day. Prefer **subprocess reuse** over cloned graphs.

**Record actions (§3.E).** Decide **list vs related**; never hardcode an id into a related action; **don't pass `rv!record` into the process** (pass the id/needed fields); drive visibility via **relationships**, not queries (evaluated on every page load).

**Security (§3.C, §8).** Groups not users; group-based object security; dynamic record-level security expressions.

---

## B. Batch 1 — Data model (foundation)

### B.1 `AS_GSS_EvaluationRound_SYNCEDRECORD` (new) — keep, with one added column
Fields: `roundId` (PK), `evaluationId` (FK → the round's Evaluation clone), `roundName`, `sequence`, `startDate`, `endDate`, `duration`, `isOnSpotConsensus`, audit columns; many-to-one `evaluation` relationship. **Add one column (see B.2).** Column/table naming per §2.E (UPPERCASE, ≤30 chars, no `VARCHAR length`, new column added `AFTER` existing business columns, before audit columns).

### B.2 Add `parentEvalId` to the rounds table (PO decision)
- **What:** a new `parentEvalId` (integer FK → Evaluation) on `AS_GSS_EvaluationRound`, **denormalized from the round's evaluation**: **null** for the root's Round-1 row, **= root evaluationId** for every child round's row. Same name = same concept as `Evaluation.parentEvalId` (§1.F.4).
- **Why:** family resolution today queries the **Evaluation** table and then indexes the `round` relationship. With `parentEvalId` on the round row, the entire family can be resolved by querying the **rounds table only** — no Evaluation query, no relationship-index gymnastics (§C). Index the column (§12.B) — it's queried on every round-aware screen.
- **Populate it:** set on the same write that creates each round row — null when the root is started (Round 1), root id when a child is cloned (§ Start Evaluation / Setup New Round batches).
- **Migration:** backfill existing round rows (`parentEvalId` = the round evaluation's `parentEvalId`); legacy single-pass evaluations have no round rows and are unaffected.

### B.3 `AS_GSS_Evaluation_SYNCEDRECORD` — keep `parentEvalId` + `round` relationship
`parentEvalId` (null root / root-id child) and the cascading `round` relationship (writing an Evaluation with a populated `round` persists the EvaluationRound row atomically). **No further core-schema change** — the family key now rides on the rounds table (B.2).

### B.4 Regenerated CDTs — verify, don't assume
`AS_GSS_Evaluation` regenerates from the schema. The other 9 package types are dependency regenerations — **diff each vs. baseline** and carry forward only genuine field additions (per §13, never drop columns on a shipped table; comment-deprecate instead).

---

## C. Worked exemplar (the template for every object) — family resolver

### C.1 Prototype: `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation(evaluationId, additionalFields, excludeParent)`
Reads the evaluation to get `parentEvalId`, computes `anchor = coalesce(parentEvalId, evaluationId)`, runs **two near-identical Evaluation queries** (anchor + its children) each selecting the `round` relationship + `additionalFields`, then `append`/`index`/`a!flatten`s out the round rows. `excludeParent` drops the anchor query.

### C.2 Why it works
`parentEvalId` defines the family; anchor + children cover Round 1 + Rounds 2..n; indexing `round` yields the `EvaluationRound` rows.

### C.3 Callers
`AS_GSS_SEC_rounds`, all round-aware `_Parent` tabs, the Setup-New-Round / Complete-Round visibility gates, `returnLatestChildEvaluationInSetupForGivenEvaluation`. **Hot path.**

### C.4 Anti-patterns
1. **Three queries** (1 Evaluation lookup + 2 family queries) — reducible to **two, on the rounds table only** (§B.2).
2. **Dead `additionalFields`** — fetched on the Evaluation query but discarded (output only indexes `round`); empty value triggers the `[""]` invalid-fields error.
3. **No `sequence` sort** — relies on implicit order.
4. **Behavior-flag `excludeParent`** (violates §5.A.1) + manual `append`/`index`/`flatten` where a filter/sort belongs.
5. Queries `Evaluation` (extra dependency) when callers consume `EvaluationRound` rows.

### C.5 Optimized design
**Rename:** `returnEvaluationRoundsForGivenEvaluation` → **`AS_GSS_QR_getRoundsForEvaluation`** (it's fundamentally a record query → `QR_get…`, §5.B). **Drop `additionalFields`** (dead) and **drop `excludeParent`** (behavior flag; child-only callers filter `sequence > 1` on the small result). Single input `evaluationId` with a description. Uses **`AS_CO_UT_queryRecord`**, sorts in-query, and joins the round-evaluation status callers actually need.

```
a!localVariables(
  /* The round row for the passed evaluation — used only to read its family linkage.
     returnType SINGLE_OBJECT: we expect at most one round row per evaluation clone. */
  local!currentRound: rule!AS_CO_UT_queryRecord(
    recordType: 'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD',
    returnType: "SINGLE_OBJECT",
    fields: {
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{1756683f-efcf-4edb-8ed1-aa9d83468af7}evaluationId',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{PARENT_EVAL_ID_UUID}parentEvalId'
    },
    filters: a!queryFilter(
      field: 'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{1756683f-efcf-4edb-8ed1-aa9d83468af7}evaluationId',
      operator: "=",
      value: ri!evaluationId
    )
  ),
  /* Family anchor: a child round carries the root in parentEvalId; the root's round carries null,
     so it is its own anchor. */
  local!familyRootId: a!defaultValue(
    local!currentRound['recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{PARENT_EVAL_ID_UUID}parentEvalId'],
    ri!evaluationId
  ),
  /* All rounds in the family — the root's own round OR any child of the root — in sequence order,
     with each round's evaluation status joined in (used by gates/labels), in ONE query on the rounds table. */
  rule!AS_CO_UT_queryRecord(
    recordType: 'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD',
    returnType: "OBJECT_ARRAY",
    fields: {
      'recordType!{931e8145}...{3a4b03be}roundId',
      'recordType!{931e8145}...{1756683f}evaluationId',
      'recordType!{931e8145}...{31c08880}roundName',
      'recordType!{931e8145}...{d20a1017}sequence',
      'recordType!{931e8145}...{7abbf0d2}startDate',
      'recordType!{931e8145}...{c3f17341}endDate',
      'recordType!{931e8145}...{85812d35}isOnSpotConsensus',
      'recordType!{931e8145}...relationships.{029ebc2e-4210-4f78-bbea-00df4267bd1d}evaluation.fields.{4e467ee1-e9e1-4350-9df9-ec1266418014}evaluationStatusId'
    },
    logicalExpression: a!queryLogicalExpression(
      operator: "OR",
      filters: {
        a!queryFilter(field: 'recordType!{931e8145}...{1756683f}evaluationId', operator: "=", value: local!familyRootId),
        a!queryFilter(field: 'recordType!{931e8145}...{PARENT_EVAL_ID_UUID}parentEvalId', operator: "=", value: local!familyRootId)
      }
    ),
    sort: a!sortInfo(
      field: 'recordType!{931e8145}...{d20a1017}sequence',
      ascending: true
    )
  )
)
```
*(Field refs abbreviated after the first full form for readability; use full `recordType!{uuid}…{fieldUuid}fieldName` refs in the object. `PARENT_EVAL_ID_UUID` = the new column from §B.2.)*

### C.6 Why this is better
- **3 queries → 2**, and **entirely on the rounds table** (no Evaluation dependency).
- **Correct output contract:** returns the `EvaluationRound` rows callers consume, **with** each round's evaluation status joined in — no dead param, no `[""]` error class.
- **Deterministic `sequence` order**, sorted in-query.
- **Single-responsibility, no flag branching, no manual `append`/`index`/`flatten`.**
- **Empty-safe:** a non-round evaluation returns `{}` (no round row → `familyRootId` = self → no matches), so legacy evaluations render unchanged.

### C.7 Test cases (§5.D — contains DB queries ⇒ "No Assertions")
Top comment `/*This rule cannot have assertion*/`. Cases: (1) **null** `evaluationId` — completes without error; (2) **root** id — completes, returns the family; (3) **child** id — completes, resolves upward to the full family. Assertion type: "Test Case Completes without Error"; no env-specific ids asserted.

### C.8 Migration notes
- Rename + repoint the C.3 callers to `AS_GSS_QR_getRoundsForEvaluation`.
- Callers that passed `additionalFields` for round-evaluation status now read `…evaluation.evaluationStatusId` off the returned rows (already included).
- Child-only callers replace `excludeParent: true` with a `sequence > 1` filter on the result.
- **Consolidation candidate:** review `AS_GSS_QR_getEvaluationRoundDetails` and `AS_GSS_UT_returnIdentifiersForEvaluationRounds` against this rule in Batch 2 — likely collapsible into this one query rule (+ thin helpers).

---

## D. Method for the remaining objects

### D.1 Per-object template
> **Object · Kind · New/Modified/Consolidated/Renamed (OLD → NEW)**
> 1. Prototype (summary, not pasted) · 2. Why it works · 3. Callers · 4. Anti-patterns · 5. Optimized design (signature + real code) · 6. Why better · 7. Test cases · 8. Migration notes.

For process models: node-by-node (nodes, gateways, data flow, lane, security group, start-form/wrapper, archive/delete) — not XML.

### D.2 Consolidation watch-list (revisit as batches proceed)
- Round query rules: `getRoundsForEvaluation` (this) ⊕ `getEvaluationRoundDetails` ⊕ `returnIdentifiersForEvaluationRounds` → collapse where possible.
- The 8 `_Parent` wrappers likely share one generic per-round tab host → consider a single parametrized wrapper instead of eight near-duplicates.
- Duplicate/round-clone helpers (`duplicateEvaluationForNewRound`, `updateFactorTeamMappingForDuplicatedEvaluation`, `constructFactorDocumentMappingsForNewRound`) → verify boundaries; keep single-responsibility but eliminate overlap.

### D.3 Batch order (build-sequence, each reviewed before the next)
1. **Data model** — §B ✅ (this revision).
2. **Family/round helpers** — `getRoundsForEvaluation` ✅ exemplar; then `getEvaluationRoundDetails`, `returnIdentifiersForEvaluationRounds`, `returnLatestChildEvaluationInSetupForGivenEvaluation`, `checkifAnyOpenTaskForGivenEval`.
3. **Start Evaluation as Round 1** — modal, PM (node-by-node), record actions + visibility split.
4. **Round-aware tabs** — embeddable content contract + the wrapper(s).
5. **Setup New Round + clone** — wizard, duplicate, team-mapping, factor-doc-mapping.
6. **Start / Complete round + Rounds panel.**
7. **Summary recomposition + Vendors.**
8. **Integration touchpoints** (VM, GCW).

### D.4 Next step
Batch 2 (family/round helpers): read each prototype, then design the optimized/consolidated versions here in this document.

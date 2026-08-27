# 06 — Feature Technical Design: GSS Multi-Round Evaluations

> **Purpose.** This is the object-by-object technical design that turns the POC into a **production-quality** implementation. For every object it states: what the prototype did, *why* it works, where it's used — and then a **redesigned, optimized, standards-compliant implementation** (with real code). It is explicitly **NOT** a copy of the environment's prototype code: the POC was hand-built, unoptimized, inconsistently named, and full of shortcuts. This document is where we correct all of that.
>
> **Relationship to the other docs:** `artifacts/05_FEATURE_IMPLEMENTATION_PLAN.md` says *what/where/why* (code-free). **This doc says *how*, with the code we actually want built.** Read 05 first for intent; use this for construction.
>
> **Status: IN PROGRESS.** This first revision establishes the **optimization standard (§A)**, the **data-model recommendation (§B)**, and **one fully-worked exemplar (§C)** — the family resolver — as the template for all remaining objects. **The per-object designs (§E onward) will be filled in, in build-sequence order, after the standard in §A–§C is approved.** See §D for the open questions and the object template.

---

## A. The optimization standard (the rules this redesign follows)

Every object design in this document conforms to the following. These are derived from the GSS naming conventions (onboarding §4), Appian platform best practices, and the specific anti-patterns found in the POC.

### A.1 Naming
- Follow the GSS prefix grammar: `_QR_` query rule · `_UT_` utility · `_BL_` business logic · `_CPS_`/`_CP_` component · `_SEC_` section · `_FM_` form/modal · `_GRD_` grid · `_SYNCEDRECORD`/`_RECORD`.
- Names must state intent, not implementation. Rename prototype objects whose names are vague, misleading, or misprefixed (each rename is called out with **OLD → NEW** and a migration note).
- One responsibility per object; if a name needs "And"/"With" to describe it, consider splitting.

### A.2 Querying
- **One round-trip per logical need.** Never issue multiple near-identical queries that can be expressed as one with an `OR`/`in` filter or a related-record-field filter.
- **Filter on related-record fields** instead of query-then-index-then-filter in memory.
- **Select only the fields you use.** No blanket relationship pulls; no fetching fields that are then discarded.
- **Sort in the query** (`a!pagingInfo`/`a!sortInfo`), not in memory, and never rely on implicit/default ordering for correctness.
- Use `a!queryRecordType(...)` directly for record-backed reads; only wrap in `AS_CO_UT_queryRecord` when the team's convention requires it (call this out per object).

### A.3 Null-safety & correctness
- Guard every comparison that can see a null (`and()`/`or()` do **not** short-circuit in SAIL): wrap with `a!defaultValue(...)`.
- Boolean inputs default explicitly (`a!defaultValue(ri!flag, false)`).
- Prefer positive, single-purpose signatures over boolean **flag arguments**; where a flag is justified, document it.
- Empty-list-safe: a family/round helper must return `{}` (not error) for a non-round or unstarted evaluation, so legacy single-pass evaluations render unchanged.

### A.4 Reuse & consolidation
- The POC created several overlapping helpers. Where two rules compute the same thing, **consolidate into one** and list the callers to repoint. Net object count should **go down** relative to the 63 prototype objects wherever safe.
- Shared logic (anchor resolution, round-status gating) lives in **one** rule that everything calls.

### A.5 Interfaces
- Content interfaces are **embeddable by contract**: no outer `headerContentLayout`/wrapper inside a component meant to be nested per round. The header frame is supplied once by the `_Parent` wrapper.
- No `paneLayout` inside `a!tabItem` (use `columnsLayout`).
- Presentation helpers (round lists, per-round loaders) live inside the `_Parent` interface (they use `env!` context that fails in plain expression rules).

### A.6 Process models
- Prefer reuse-by-subprocess over duplicated node graphs. A new entry form that must reuse an existing generation flow uses a **thin wrapper PM** (start form + subprocess call), not a re-implementation.
- Every gateway condition is null-safe at validation time.
- Externalities (GCW sync, requirement extraction) are called consistently (sync vs async) and documented.

### A.7 Verification bar (per object)
- Each rule/interface design lists its **test cases** (inputs → expected) and is validated with live execution (`testRule`/`testInterface`), not just static validation — especially for i18n-bundle grids.

---

## B. Data-model recommendation (foundation for everything)

### B.1 `EvaluationRound` (new) — keep as designed
New synced record `AS_GSS_EvaluationRound_SYNCEDRECORD`: `roundId` (PK), `evaluationId` (FK→Evaluation), `roundName`, `sequence`, `startDate`, `endDate`, `duration`, `isOnSpotConsensus`, audit columns; many-to-one `evaluation` relationship. **No change from the POC** — this record is clean.

### B.2 `Evaluation` — add `parentEvalId` **and a denormalized `rootEvaluationId`**
The POC added `parentEvalId` (null on root, root's id on children) + the cascading `round` relationship. **Keep both.**

**Optimization to add: a `rootEvaluationId` field that is *always populated* (root points to itself).** 
- **Why:** every family read today must first do an **anchor lookup** (`coalesce(parentEvalId, evaluationId)`) *before* it can query the family — an extra round-trip on the hottest path in the feature (§C shows it). With `rootEvaluationId` always set, "give me the whole family" becomes **one indexed query** (`rootEvaluationId = :root`) from any member, no pre-lookup, no `OR` across two fields.
- **How:** set `rootEvaluationId = evaluationId` when the root is started (Round 1); set `rootEvaluationId = <root's id>` on every clone. Index the column.
- **Trade-off:** one denormalized column vs. an eliminated query on essentially every round-aware screen and gate. Strongly recommended. (If the team rejects denormalization, §C also gives the optimized two-query version.)

### B.3 Regenerated CDTs — verify, don't assume
`Evaluation` regenerates from the new field(s). The other 9 types in the package (`EvaluationVendor`, `Criteria`, `EvaluatorTeam`, `Rating`, `EvaluationPhase`, `TMG_Task`, `TMG_TaskActionAudit`, `EvaluationComments`, `FactorDocumentMapping`) are dependency regenerations — **diff each against baseline** and only carry forward genuine field additions.

---

## C. Worked exemplar — `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation`

> This is the template for how every object is treated below. It is the **keystone** rule (§3 of the Impl Plan): almost every round-aware screen and gate calls it.

### C.1 What the prototype does
Signature: `(evaluationId, additionalFields, excludeParent)`. It (1) looks up the evaluation to read `parentEvalId` and computes `anchor = coalesce(parentEvalId, evaluationId)`; (2) runs **one query for the anchor evaluation** and **a second, near-identical query for the anchor's children**, both selecting the `round` relationship + `additionalFields`; (3) `append`s the two, `index`es out the `round` relationship, and `a!flatten`s the result. `excludeParent` drops the anchor query from the append.

### C.2 Why it works
`parentEvalId` defines the family; the two queries together cover Round 1 (the anchor itself) + Rounds 2..n (its children); indexing the `round` relationship yields the `EvaluationRound` rows the callers want.

### C.3 Where it's used
The Rounds panel (`AS_GSS_SEC_rounds`), every round-aware `_Parent` tab, the Setup-New-Round / Complete-Round visibility gates, and `returnLatestChildEvaluationInSetupForGivenEvaluation`. High call frequency.

### C.4 Anti-patterns to fix
1. **Three queries** (1 anchor lookup + 2 family queries) where **two** — ideally **one** (§B.2) — suffice.
2. **`additionalFields` is fetched on the Evaluation query but then discarded** (the output only indexes the `round` relationship), so the parameter is effectively dead weight and, when empty, triggers the `[""]` invalid-fields error (documented gotcha). Callers that "needed" round-evaluation status never actually received it cleanly.
3. **No `sequence` sort** — round order relies on implicit query ordering; fragile.
4. **Flag argument** `excludeParent` + manual `append`/`index`/`flatten` where a filter belongs.
5. Queries `Evaluation` and indexes the relationship, rather than querying `EvaluationRound` directly (which is what callers consume) with the needed evaluation fields joined in.

### C.5 Optimized design

**Signature:** `AS_GSS_UT_returnRoundsForEvaluation(evaluationId, includeRoundStatus?, excludeRoundOne?)` — renamed for clarity (OLD: `returnEvaluationRoundsForGivenEvaluation`), the dead `additionalFields` param removed in favor of a purpose-built, always-useful output (round rows + the round-evaluation status callers actually need).

**With the recommended `rootEvaluationId` field (§B.2) — single query, no anchor pre-lookup:**
```
a!localVariables(
  a!queryRecordType(
    recordType: 'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD',
    fields: {
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{3a4b03be-cd32-408b-a301-60d75dfb3587}roundId',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{1756683f-efcf-4edb-8ed1-aa9d83468af7}evaluationId',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{31c08880-eb84-47ee-b92b-9f3c41a446fb}roundName',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{d20a1017-98de-4b58-abaa-f8a119687931}sequence',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{7abbf0d2-90d9-4342-9b6a-034ba226298d}startDate',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{c3f17341-a436-4024-a184-6a70957ca7fd}endDate',
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{85812d35-fe1f-4ccc-b7b0-c61f0e2757d0}isOnSpotConsensus',
      /* the round's evaluation status, joined in via the many-to-one 'evaluation' relationship —
         the field the gates/labels need, fetched in the same round-trip instead of a dead param */
      'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD.relationships.{029ebc2e-4210-4f78-bbea-00df4267bd1d}evaluation.fields.{4e467ee1-e9e1-4350-9df9-ec1266418014}evaluationStatusId'
    },
    filters: a!queryLogicalExpression(
      operator: "AND",
      filters: {
        /* whole family in one indexed predicate — every member shares rootEvaluationId */
        a!queryFilter(
          field: 'recordType!{931e8145-...}AS_GSS_EvaluationRound_SYNCEDRECORD.relationships.{029ebc2e-...}evaluation.fields.{<rootEvaluationId-uuid>}rootEvaluationId',
          operator: "=",
          value: ri!evaluationId  /* resolves the family from ANY member, root or child */
        ),
        /* optional: drop Round 1 when the caller only wants child rounds */
        if(
          a!defaultValue(ri!excludeRoundOne, false),
          a!queryFilter(
            field: 'recordType!{931e8145-...}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{d20a1017-...}sequence',
            operator: ">",
            value: 1
          ),
          null
        )
      },
      ignoreFiltersWithEmptyValues: true
    ),
    pagingInfo: a!pagingInfo(
      startIndex: 1,
      batchSize: - 1,
      sort: a!sortInfo(
        field: 'recordType!{931e8145-...}AS_GSS_EvaluationRound_SYNCEDRECORD.fields.{d20a1017-...}sequence',
        ascending: true
      )
    )
  ).data
)
```
*Note:* `ri!evaluationId` here is matched against `rootEvaluationId`. If the caller may pass a **child** id, either (a) always store the family's root id in `rootEvaluationId` on every member (recommended — then passing any member's id won't match; instead pass the member's own `rootEvaluationId`), or (b) keep the tiny anchor lookup below. To keep the call site trivial ("give me the family for *this* eval id"), use the two-query form:

**Without the schema change — two queries, sorted, no dead param (drop-in optimization of the current model):**
```
a!localVariables(
  /* 1) one lightweight lookup to resolve the family anchor */
  local!anchorId: a!defaultValue(
    rule!AS_GSS_QR_getEvaluationByIdentifier(evaluationId: ri!evaluationId)[
      'recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD.fields.{6889c500-986b-4df6-93c2-6aa8a890cbd7}parentEvalId'
    ],
    ri!evaluationId
  ),
  /* 2) ONE query over EvaluationRound joined to its Evaluation: anchor itself OR any child of it,
        sorted by sequence, with round-evaluation status joined in. Replaces the prototype's 2 queries + manual flatten. */
  a!queryRecordType(
    recordType: 'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD',
    fields: { /* roundId, evaluationId, roundName, sequence, startDate, endDate, isOnSpotConsensus,
                 evaluation.evaluationStatusId — as above */ },
    filters: a!queryLogicalExpression(
      operator: "AND",
      logicalExpressions: a!queryLogicalExpression(
        operator: "OR",
        filters: {
          a!queryFilter(field: '...evaluation.fields.{7f7c2d3b-...}evaluationId', operator: "=", value: local!anchorId),
          a!queryFilter(field: '...evaluation.fields.{6889c500-...}parentEvalId', operator: "=", value: local!anchorId)
        }
      ),
      filters: if(
        a!defaultValue(ri!excludeRoundOne, false),
        a!queryFilter(field: '...fields.{d20a1017-...}sequence', operator: ">", value: 1),
        null
      ),
      ignoreFiltersWithEmptyValues: true
    ),
    pagingInfo: a!pagingInfo(1, - 1, a!sortInfo(field: '...fields.{d20a1017-...}sequence', ascending: true))
  ).data
)
```

### C.6 Why this is better
- **3 queries → 1** (with §B.2) or **→ 2** (without): removes the hottest-path overhead in the feature.
- **Correct output contract:** returns the `EvaluationRound` rows callers consume, **with** each round's evaluation status joined in — no dead `additionalFields`, no `[""]` error class.
- **Deterministic order:** sorted by `sequence` in the query.
- **No manual `append`/`index`/`flatten`; no flag-driven branching** — a single filtered, sorted query.
- **Empty-safe** by construction (a non-family eval returns `{}`).

### C.7 Migration notes
- **Rename** `returnEvaluationRoundsForGivenEvaluation` → `returnRoundsForEvaluation`; repoint the callers in C.3.
- Callers that passed `additionalFields` to fetch round-evaluation status now read `…evaluation.evaluationStatusId` off the returned rows (already included) — simplifies those call sites too.
- If `rootEvaluationId` (§B.2) is adopted, also repoint the anchor-resolution in `returnLatestChildEvaluationInSetupForGivenEvaluation` and the Setup/Complete gates to the single-query form.

---

## D. How we proceed (and questions before I fan out to all objects)

### D.1 Per-object template (used for every object in §E+)
> **Object · Kind · New/Modified/Consolidated · Proposed name (if renamed)**
> 1. **Purpose** — one line.
> 2. **Callers / where used.**
> 3. **What the prototype does** (summary, not pasted).
> 4. **Anti-patterns / why it's not production-ready.**
> 5. **Optimized design** — signature + real code + query/interface notes.
> 6. **Why it's better.**
> 7. **Test cases** (inputs → expected).
> 8. **Migration notes** (renames, caller repoints, consolidations).

### D.2 Proposed sequencing (build-order from Impl Plan §16)
1. Data model (§B) → 2. Family/round helpers (resolver ✅ exemplar, identifiers, latest-in-setup, round-details query, open-task guard) → 3. Start Evaluation (modal, PM, actions) → 4. Round-aware tabs (embeddable content + `_Parent` wrappers) → 5. Setup New Round + clone (duplicate, team-mapping, factor-doc-mapping) → 6. Start/Complete round + Rounds panel → 7. Summary recomposition + Vendors → 8. Integrations.

### D.3 Questions for you (so the fan-out matches your intent)
1. **Optimization aggressiveness — confirm the mandate:** may I (a) **rename** objects to standard names, (b) **consolidate/eliminate** redundant prototype rules (so the final count is *lower* than 63), and (c) **change signatures/inputs** (e.g., drop the dead `additionalFields`)? The exemplar assumes **yes** to all three.
2. **Schema latitude:** is a data-model optimization like **`rootEvaluationId`** (§B.2) on the table acceptable, or must the design stay within the existing columns (`parentEvalId` only)? This materially changes many query designs.
3. **Style/gold-standard:** is there a GSS coding standard doc or a set of "known-good" reference objects you want me to conform to beyond the §4 naming conventions? If yes, point me at them and I'll align every design to them.
4. **Delivery shape:** this will be large. I propose filling §E in **batches by area** (per §D.2), pausing after each batch for your review, rather than one giant unreviewed dump. Good?
5. **Depth of code:** full working SAIL for rules/interfaces (as in §C), and for **process models** a node-by-node design (nodes, gateways, data flow, lanes) rather than literal XML — acceptable?

Once you confirm §D.3, I'll proceed batch-by-batch and keep this document as the single source of truth for the technical design.

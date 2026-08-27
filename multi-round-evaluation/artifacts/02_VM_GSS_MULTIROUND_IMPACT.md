# 02 — VM ↔ GSS Integration: Multi-Round Impact (Phase 2)

> **Purpose:** given the current-state integration in `01_VM_GSS_CURRENT_STATE_INTEGRATION.md`, determine what the **Multi-Round Evaluations** feature **breaks, degrades, or leaves working** across every VM↔GSS flow — with root cause, severity, and recommended fix per flow.
>
> **Verified** (2026-08-27) against the live duplicate rule, the inbound/outbound handlers, and actual round data. Evidence UUIDs are cited inline; the verification appendix is §7.

---

## 1. The one root cause (read this first)

Multi-round has a single structural collision with the integration:

> **`evaluationNumber` is overloaded** — it is simultaneously (a) GSS's **display label** for the evaluation and (b) the **join key** to VM (`Evaluation.evaluationNumber` ↔ `Opportunity.noticeId` = the solicitation PIID).

When a new round is created, `AS_GSS_UT_duplicateEvaluationForNewRound` (`_…42160` v9) **rewrites the clone's `evaluationNumber`**:

```
newEvaluation.evaluationNumber = concat(sourceEvaluation.evaluationNumber, " Round ", round.sequence)
```

**Verified in data** (Evaluation record `e6bc8561`): root `16 = "26082602"` (raw PIID, `parentEvalId` null); its round clones `17/18/19 = "26082602 Round 2 / Round 3 / Round 4"` (`parentEvalId=16`, all `isActive=true`). So:

- **Only the ROOT (Round 1) carries the real solicitation PIID** as its `evaluationNumber`.
- **Every round clone's `evaluationNumber` no longer equals the VM `noticeId`.**

Everything below is a consequence of this. Two secondary facts matter:

- **Round creation is 100% internal to GSS** — the duplicate rule makes **no VM callout**. So VM's `Proposal.isEvaluationLinked` flag is *not* touched when rounds are created/advanced; it still reflects whatever Round 1 set.
- **Vendor identity & provenance survive cloning** — carried `EvaluationVendor` rows get a new per-round PK (`vendorId=null`→new) but **preserve `externalVendorId` (=VM vendorId), `uniqueEntityId`, `sourceApplicationId=VM`**, and their `EvaluationDocument` rows **preserve `appianDocId`** (only PK/FKs nulled). So *identifying* a vendor/doc across the boundary still works; only *which evaluation/round it maps to* is affected.

---

## 1b. Reassessment under the parent-only model (PO-confirmed 2026-08-27) — AUTHORITATIVE

> **Design clarification received:** the **parent evaluation is the only user-facing evaluation**; round clones are **backend-only and hidden from users** (see `01_…` §1a). Vendor addition happens **only on the parent**; awardee selection happens **only on the parent**. This changes the *verdicts* below — the underlying mechanics in §1/§3 remain accurate, but most items are **expected behavior, not defects.**

**Revised verdicts:**
| Flow | Original concern | Revised verdict (parent-only) |
| :-- | :-- | :-- |
| A Opportunity Details | Blank on round-clone views | ✅ **Not an issue** — users never open clone views. VM shows/links the parent, and the parent's `evaluationNumber` is the raw PIID → the call resolves. |
| B / C / D | — | ✅ **Not an issue** — Round-1/parent activity; `appianDocId` retained for downloads. |
| E Update Vendor Action → VM | Breaks from clones; between-round down-select not pushed | ✅ **Not an issue** — vendor add/remove→VM happens **only on the parent** (raw PIID → VM resolves). Between-round down-select is *internal selection* of already-linked vendors, **not** a VM unlink, so no push is expected. A vendor stays `isEvaluationLinked=1` in VM as long as it remains on the parent — which is correct. |
| F Evaluation Details for VM | Stale (Round-1) status/link | ✅ **Not an issue** — showing the **parent** status/link is the **intended** behavior; VM screens are meant to reflect the parent evaluation only. |
| G Vendor Proposal Action → GSS | Attaches to root, not active round | ✅ **Implemented (2026-08-27, v2)** — `AS_GSS_mapVendorUpdatesToRecord` now resolves the family's **latest round** via `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (max `sequence`) and targets the vendor + writes the `VendorUpdates` against that **latest round's child `evaluationId`** (falls back to the parent when the family has no round rows). `evaluationNumber` still stores the solicitation PIID. Verified via `testRule` on solicitation `26082602` → resolved to the latest round eval (21), not the root (16), `error: null`. |

**Net:** **Flow G has been implemented** (latest-round targeting, v2, verified). All other VM flows are correct under the parent-only model with no change required.

---

## 2. Impact matrix (summary)

> Superseded by §1b for verdicts. The severities below reflect the *pre-clarification* structural analysis and are retained for the mechanism record.


| Flow | Direction | Multi-round verdict | Severity |
| :-- | :-- | :-- | :-- |
| **A** Opportunity Details | GSS→VM (read) | ⚠️ **Degrades** — blank on round-clone views if the clone's `evaluationNumber` is passed as `noticeId` | Medium |
| **B** Vendor Identifier list | GSS→VM (read) | ✅ Works (Round-1 activity on root); ⚠️ fails only if invoked from a clone | Low |
| **C** Vendors + Docs pull | GSS→VM (read+write GSS) | ✅ Works — Round-1-only on the root; later rounds carry vendors internally (no VM re-fetch) | Low |
| **D** Download Proposal Document | GSS→VM (binary) | ✅ **Works across all rounds** — `appianDocId` is retained on carried docs (as intended) | None |
| **E** Update Vendor Action → VM | GSS→VM (write VM) | ❌ **Breaks from clones** (VM opp lookup fails) **and** between-round down-selects don't push at all | High |
| **F** Evaluation Details for VM | VM→GSS (read GSS) | ❌ **Stale** — always returns Round-1 status + Round-1 record URL, never the active round | High |
| **G** Vendor Proposal Action → GSS | VM→GSS (write GSS) | ❌ **Mis-targets** — always attaches to the Round-1 evaluation + Round-1 vendor row, never the active round | High |

**Unaffected by multi-round:** the two master toggles, sealed-bid gating, vendor identity matching (externalVendorId/UEI), provenance tagging (`sourceApplicationId`).

---

## 3. Per-flow analysis

### Flow D — Download Proposal Document ✅ (the one you asked to preserve)
- **Behavior:** GSS calls `downloadVmDocument?appianDocId={appianDocId}`. Carried docs keep the **same VM `appianDocId`** across every round (verified: duplicate nulls PK/FKs but copies `appianDocId`).
- **Verdict:** **Works in every round.** A CO viewing a carried proposal document in Round 3 downloads it from VM by the identical `appianDocId` used in Round 1. This is exactly the intended behavior ("retain the same VM appianDocId") and it holds. **No change needed.**

### Flow C — Get Vendors + Documents ✅ / Flow B — Vendor Identifier ✅
- **Behavior:** the VM vendor pull is a **Round-1 activity**. Vendors enter the family once (root, `evaluationNumber` = raw PIID → VM resolves the opportunity), and later rounds obtain vendors by **internal carry-forward** in the duplicate rule (no VM re-fetch). Between-round *re-include* of a previously excluded vendor draws from the carried family pool, not a fresh VM call.
- **Verdict:** **Works**, because these run on the root where `evaluationNumber` is still the PIID.
- **Residual risk to confirm:** if the Add-Vendors / vendor-identifier UI is ever reachable from a **round-clone** record and passes that clone's `evaluationNumber` as `solicitationNumber`, VM returns `NO_OPPORTUNITY`. Confirm the Add-Vendors entry point is root/Round-1-scoped (callers: `AS_GSS_mapDataFromVMToEvalVendorRecord` `_…15371691`, `AS_GSS_mapDataFromVMToEvaluationDocumentRecord` `_…15485501`, vendor-identifier caller `_…15617141`).

### Flow A — Get Opportunity Details from VM ⚠️
- **Behavior:** GSS interfaces show VM opportunity details by calling `getOppDetailsForEval?noticeId`. The `noticeId` supplied is the evaluation's `evaluationNumber`.
- **Impact:** on a **round-clone** record view, `evaluationNumber = "PIID Round N"` → VM returns **204 NO_DATA** → the opportunity panel is **blank/absent** on Round 2+ views. On the root it works.
- **Severity:** Medium (display only; no data corruption).
- **Fix:** resolve the family root and pass the **root's `evaluationNumber`** (raw PIID) to the integration, or strip the `" Round N"` suffix before the call.
- **To confirm:** the 3 consuming interfaces (`_…15003193`, `_…14412361`, `_…15321422`) — verify they pass `evaluationNumber` (vs a stored raw PIID).

### Flow E — Update Vendor Action to VM ❌ (High)
- **Behavior:** GSS PM `AS GSS Update Vendor Action to VM` (`0002ed96`) posts `{solicitationPiid, vendorId[], actionType}`; the payload builder `AS_GSS_BL_constructVendorActionDetailsForVM` (`_…15537184`) sets **`solicitationPiid = evaluation.evaluationNumber`** (verified).
- **Impact — two distinct problems:**
  1. **Wrong key from clones:** if this PM is triggered from a round clone, `solicitationPiid = "PIID Round N"` → VM `updateProposalDetailsForGSSVendorAction` (`b82baa58`) resolves `Opportunity` by `noticeId = "PIID Round N"` → **not found** → `Proposal.isEvaluationLinked` is **not updated**.
  2. **No push on between-round down-select:** the round-creation/down-select path runs entirely inside the duplicate rule, which **never calls VM**. So when vendors are eliminated (or re-included) between rounds, VM is **never notified** — `isEvaluationLinked` continues to reflect **Round-1 membership only**.
- **Net effect on VM:** VM's "available to add" / "linked" view of vendors drifts from GSS's actual current-round vendor set. A vendor dropped in Round 2 still shows `isEvaluationLinked=1` in VM.
- **Severity:** High (VM data integrity / vendor-pool correctness) — *if* the business wants VM to reflect per-round membership. If VM only needs "vendor entered the source-selection process at all," the drift may be tolerable but should be an explicit product decision.
- **Fix:** (a) send the **root's `evaluationNumber`** (raw PIID) as `solicitationPiid`; (b) decide whether between-round eliminations/re-includes should notify VM and, if so, invoke the push from the down-select path.

### Flow F — Get Evaluation Details for VM ❌ (High)
- **Behavior:** VM's opportunity summary shows the linked GSS evaluation's status + deep link, via GSS handler `AS_GSS_BL_getEvaluationDetailsForVM_v1` (`_…15278632`), which matches `Evaluation` by **`evaluationNumber = solicitationPiid` (isActive, SINGLE_OBJECT)**.
- **Impact:** only the **root** has `evaluationNumber = PIID`, so this **deterministically returns Round 1** — its `evaluationStatus`, `evaluationTitle`, and `evaluationUrl` (a record link to the Round-1 evaluation). When the evaluation has advanced (e.g., Round 3 in progress, Round 1 long complete), **VM still displays Round 1's status and links to the Round-1 record.** VM never sees the current round.
- **Severity:** High (VM users see stale/incorrect source-selection status; deep link lands on an old round).
- **Fix:** make the handler **family/round-aware** — resolve the anchor (`coalesce(parentEvalId, evaluationId)`), then return the **latest/active round's** status + that round's record URL (or a rollup that names the current round). Reuse `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` to find the family.

### Flow G — Vendor Proposal Action to GSS ❌ (High)
- **Behavior:** VM pushes a vendor proposal submit/withdraw; GSS handler `AS_GSS_mapVendorUpdatesToRecord` (`_…15443462`) matches `Evaluation` by `evaluationNumber = noticeId` (SINGLE), then matches the `EvaluationVendor` **scoped to that evaluation's `evaluationId`**, and writes an `AS_GSS_VendorUpdates` row (`evaluationId`, `evalVendorId`).
- **Impact:** the evaluation match resolves to the **root** only, so:
  - the `VendorUpdates` row is always stamped with the **Round-1 `evaluationId`**, and
  - `evalVendorId` is the **Round-1 `EvaluationVendor.vendorId`**, not the active round's vendor row.
  So proposal-action notifications never surface against the round the CO is actually working in; a CO in Round 3 won't see the update attached to their round.
- **Nuance:** most proposal submissions occur during the Round-1 solicitation window, so the common case lands acceptably on Round 1. The problem is **late** actions (re-submission/withdrawal) once the evaluation has advanced.
- **Severity:** High (data attaches to the wrong round; possibly invisible in the active round's context).
- **Fix:** resolve the family and attach the update to the **active/current round** (and/or fan out to every active round's `EvaluationVendor` matched by `externalVendorId`/`uniqueEntityId`). Identity matching already works because carried vendors preserve `externalVendorId`.

---

## 4. Cross-cutting themes

1. **Join-key vs display-label collision** (the root cause). The cleanest structural fix is to **stop overloading `evaluationNumber`**: keep the raw solicitation PIID in a dedicated, never-rewritten field on every round (or leave `evaluationNumber` = PIID and move "Round N" into `evaluationTitle`/a display expression). Then inbound handlers can match all rounds by PIID and choose the right one, and outbound calls always send the true PIID.
2. **VM's model is per-opportunity, not per-round.** `Proposal.isEvaluationLinked` is a single boolean per proposal/opportunity. It cannot express "in Round 2, dropped in Round 3." Decide whether VM needs round granularity or only "linked to the SS process."
3. **Identity & documents are safe.** `externalVendorId`, `uniqueEntityId`, `sourceApplicationId=VM`, and `appianDocId` all carry across rounds — so vendor matching (Flow G) and document download (Flow D) are robust. The gap is always *evaluation/round scoping*, never *identity*.
4. **Directionality of severity:** inbound reads/writes (F, G) silently bind to Round 1 (no error, wrong target); outbound writes from a clone (E) hard-fail the VM lookup (no error surfaced to the user either, since the PM routes failures to an email). None throw a user-visible error — the failures are **silent**, which raises the priority of fixing them.

---

## 5. Recommendations (prioritized)

| # | Change | Fixes | Effort |
| :-- | :--- | :--- | :--- |
| 1 | **Decouple the VM join key from the label.** Add/retain a raw `solicitationPiid` on every round (or don't mangle `evaluationNumber`). Point all 5 GSS↔VM touchpoints at it. | Root cause → A, E outbound key | Medium (data + rule touch-ups) |
| 2 | **Make Flow F round-aware** — return the latest/active round's status + record URL (resolve via anchor + rounds). | F | Small–Medium |
| 3 | **Make Flow G round-aware** — attach `VendorUpdates` to the active round's evaluation + `EvaluationVendor` (match by `externalVendorId`/UEI within the family). | G | Small–Medium |
| 4 | **Decide + implement between-round → VM sync** — whether eliminations/re-includes update VM `isEvaluationLinked`; if yes, call the push from the down-select path with the raw PIID. | E design gap | Product decision + Medium |
| 5 | **Fix Flow A** — pass the root's raw PIID to `getOppDetailsForEval` on clone views. | A | Small |

Recommendation #1 is the highest-leverage: it neutralizes the root cause and makes A/E behave, after which F/G still need round-selection logic (#2/#3) to pick *which* round, not just *which solicitation*.

---

## 6. Open confirmations (not blockers)
- **Flow A/B/C trigger inputs:** confirm the consuming interfaces/rules pass `evaluation.evaluationNumber` (vs a stored raw PIID) — determines whether A actually breaks on clone views and whether B/C are truly root-only.
- **Flow E trigger scope:** confirm whether the between-round down-select path ever starts PM `0002ed96` (evidence so far: it does not — the duplicate rule has no VM call).
- **"Latest/active round" definition for F/G:** align with the team (latest by `sequence`? the single `INPROGRESS` round? the latest non-`SETTING_UP`?).

## 7. Verification appendix
- Round-clone semantics: `getExpressionRule _a-0000f04a-0c6d-8000-9ba8-011c48011c48_42160` (duplicate rule) + `listRecordData e6bc8561` (roots 6/13/16 raw PIID; clones 17/18/19 = "26082602 Round N", parentEvalId=16, isActive=true).
- Inbound handlers: `_…15278632` (F), `_…15443462` (G) — match `evaluationNumber` = raw `noticeId`, SINGLE_OBJECT.
- Outbound payload key: `_…15537184` (`constructVendorActionDetailsForVM`) → `solicitationPiid = evaluation.evaluationNumber`.
- Multi-round mechanics reference: `../01_FEATURE_AND_TECHNICAL_DESIGN.md`, `../03_AGENT_ONBOARDING.md` §10.45–10.49; current-state integration: `01_VM_GSS_CURRENT_STATE_INTEGRATION.md`.

# 04 — GCW ↔ GSS Integration: Multi-Round Impact (Phase 2)

> **Purpose:** given the current-state map in `03_GCW_GSS_CURRENT_STATE_INTEGRATION.md`, determine what **Multi-Round Evaluations** breaks / degrades / leaves working across every GCW↔GSS flow, with root cause, severity, and prioritized fixes.
>
> **Verified** (2026-08-27) against the duplicate rule, the GCW-facing handlers, and round data. Evidence UUIDs in §7. Multi-round mechanics reused from the VM analysis (`02_…` §1) and re-confirmed here.

---

## 1. Two identity models — the GCW-specific root cause

GCW↔GSS keys on **two different identities**, and multi-round hits them differently:

**(a) By solicitation PIID** — used by the summary display `getEvaluationDetailsBySolicPiid_V1`, which matches `AS_GSS_Evaluation_RECORD` on **`evaluationNumber = PIID` AND `sourceApplication = AM` AND `isActive`** (SINGLE_OBJECT).
- Round clones have `evaluationNumber = "PIID Round N"` **and** `sourceApplication = GSS` (set by `AS_GSS_UT_duplicateEvaluationForNewRound`). So this is **doubly root-only** → it can only ever return the **root (Round 1)** evaluation.

**(b) By `evaluationId` (numeric)** — used by status sync (`syncEvalStatusInGcw` / `evaluationList`), winning-vendors (`getWinningVendorAndBasicInformation`), vendor/doc details (`getEvaluationandVendordetails`), and award creation. These operate on **exactly the `evaluationId`(s) passed** — `AS_GSS_UT_constructEvalVendorAndDocsForMultipleEvalIds` queries `WHERE evaluationId IN (…)` with **no family/round expansion** (verified).

Two secondary facts (from `02_…` §1, re-confirmed): round creation is **internal to GSS** (no GCW callout in the duplicate rule); carried vendors/docs **preserve `externalVendorId`, `uniqueEntityId`, `gsmVendorRefId`, and `appianDocId`** but get new per-round PKs.

**Consequences in one line:** PIID-keyed reads silently bind to **Round 1**; `evaluationId`-keyed reads/writes are only correct if the **right round's id** is supplied — and GCW's stored eval↔solic mapping points at the **root**.

---

## 1b. Reassessment under the parent-only model (PO-confirmed 2026-08-27) — AUTHORITATIVE

> **Design clarification received:** the **parent evaluation is the only user-facing evaluation**; round clones are **backend-only and hidden from users** (see `01_…` §1a). **Select Awardees and award creation happen only on the parent.** This changes the *verdicts* below — the mechanics in §1/§3 remain accurate, but nearly all items are **expected behavior, not defects.**

**Revised verdicts:**
| Flow | Original concern | Revised verdict (parent-only) |
| :-- | :-- | :-- |
| B createEvaluationFromSolicitation | — | ✅ **Not an issue** — seeds the parent. |
| 4 updateEvalSolicMapping | Root-only mapping | ✅ **Not an issue** — the parent *is* the identity GCW should map to. |
| 7 folder security | — | ✅ **Not an issue.** |
| C getEvaluationDetailsBySolicPiid / relatedEvaluationDetails | Always Round-1 status/link | ✅ **Not an issue** — GCW is meant to show the **parent** only; parent status/link is correct. |
| H getWinningVendorAndBasicInformation | Must be final round or wrong awardees | ✅ **Not an issue** — **Select Awardees is only on the parent**; the winning selection is recorded on the parent and only that is passed to GCW → correct. |
| 8/11 create(Single/Multiple)AwardsFromEvaluation | Correct only if final-round id | ✅ **Not an issue** — award creation happens **only on the parent** → parent `evaluationId` used → correct. |
| F getEvaluationandVendordetails | Wrong round if root id | ✅ **Not an issue** — the parent id is the intended id. |
| 9 getAwardLinksForEvaluation | Scope mismatch | ✅ **Not an issue** — awards are created against the parent; links resolve under the parent. |
| 10 syncEvalStatusInGcw + HTTP `evaluationList` | Accumulates one status row per round | 🔧 **Decision (implement later):** **GCW status syncs should be skipped for child evaluations.** Only the parent evaluation's status should sync to GCW; Start Round / Complete Round (which run on child evals and currently trigger the reused Sync-GCW subprocess) must not push child-evaluation statuses. Deferred — to be implemented in a later change. Low severity (user-facing GCW status is parent-only via flow C, so child rows are inert until then). |
| 2,5,6,13 / ref-data / toggles | — | ✅ **Not an issue** — round-agnostic. |

**Net:** all GCW flows are correct under the parent-only model. The only follow-up is the **optional** status-sync hygiene item (10) — ensure child-round Start/Complete don't leak child statuses into GCW.

---

## 2. Impact matrix

> Superseded by §1b for verdicts. The severities below reflect the *pre-clarification* structural analysis and are retained for the mechanism record.


| Flow | Direction | Verdict | Severity |
| :-- | :-- | :-- | :-- |
| **B** createEvaluationFromSolicitation | GCW→GSS (write GSS) | ✅ Works — creates the root/Round 1 (evaluationNumber=PIID, sourceApplication=AM); rounds spawn internally | None |
| **4** updateEvalSolicMapping | GSS→GCW (write GCW) | ⚠️ Root-only — mapping made once for the root; GCW's known id stays the root (feeds H/F/award risk) | Medium |
| **7** updateSolicPublicFolderSecurity | GSS→GCW (write GCW) | ✅ Works — solicitation folder security granted at create; carried teams reuse it | Low |
| **10** syncEvalStatusInGcw + HTTP `evaluationList` | GSS→GCW (write GCW) | ⚠️ GCW accumulates **one status row per round** (anchor + clones) with mangled `"PIID Round N"` names, no round/parent context | Medium–High |
| **C** getEvaluationDetailsBySolicPiid / relatedEvaluationDetails | GCW→GSS (read) | ❌ **Stale** — always returns Round-1 status + Round-1 record link | High |
| **H** getWinningVendorAndBasicInformation | GCW→GSS (read) | ❌ **Round-sensitive** — winners come only from the passed `evaluationIds`; must be the **final round** or awardees are wrong | High |
| **8/11** create(Single/Multiple)AwardsFromEvaluation | GSS→GCW (write GCW) | ⚠️/❌ Correct **iff** driven by the final (awardees-selected) round's `evaluationId` | High |
| **F** getEvaluationandVendordetails | GCW→GSS (read) | ⚠️ Returns only the passed `evaluationId`'s vendors/docs — wrong round if root id used | Medium–High |
| **9** getAwardLinksForEvaluation | GSS→GCW (read) | ⚠️ Award links stored under the final-round id; GSS must query by the same id/family | Low–Medium |
| **2,5,6,13** solicitation data / procurement / contract text | both | ✅ Solicitation-level, round-agnostic | None |
| **3,12,E,G,I,D,A** toggles / ref-data / version | both | ✅ Round-agnostic | None |

---

## 3. Per-flow analysis (the ones that matter)

### C — GCW/AM summary shows GSS status ❌ (High)
- `getEvaluationDetailsBySolicPiid_V1` (`_…16904747`) matches `evaluationNumber = PIID` **AND `sourceApplication = AM`** → only the root qualifies. GCW/AM's procurement summary therefore shows **Round 1's** status, title, branding, and a deep link to the **Round-1** evaluation record — even when the live evaluation is in Round 3 (COMPLETE/AWARDEES_SELECTED).
- **Impact:** contracting officers in GCW see stale source-selection status and land on an old round when they click through.
- **Fix:** resolve the family from the AM root (`coalesce(parentEvalId, evaluationId)` / `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation`) and return the **latest/active round's** status + record link (keep the `sourceApplication=AM` match only to *find* the anchor, then hop to the newest round).

### 10 — Status sync accumulates rounds ⚠️ (Medium–High)
- Both sync paths key on `evaluationId`. The sync PM (`0006ef1c`, reused by Start Evaluation / Start Round / Complete Round / Mark-Complete) fires **per round**, so GCW receives a status record for **each round's `evaluationId`**; `evaluationList` (`AS_GSS_WA_GET_EvaluationStatusList`, **no `parentEvalId` filter**) likewise returns anchor + all clones. Payload includes `evaluationNumber`, which for clones is `"PIID Round N"`.
- **Impact:** GCW's synced status list holds **N rows per solicitation** (`26082602`, `26082602 Round 2`, `26082602 Round 3`…) with **no parent/round linkage** — looks like several separate evaluations. This also **contradicts** the PIID summary (flow C), which shows only Round 1.
- **Fix (product decision):** either (a) sync only the **anchor** with a rolled-up "current round / status," or (b) keep per-round rows but pass **round + parentEvalId** context so GCW can group them and label rounds properly (and stop showing the raw mangled `evaluationNumber`).

### H + 8/11 — Winning vendors & Award creation ❌/⚠️ (High)
- `getWinningVendorAndBasicInformation_V1` (`_…18080158`) → `constructEvalVendorAndDocsForMultipleEvalIds` queries `EvaluationVendor`/`EvaluationDocument` **`WHERE evaluationId IN (evaluationIds)`**, marks `isWinningVendor = (decisionType = SELECT)`, and returns `appianDocumentIds`. **No family expansion.**
- In multi-round the **final round** holds the true awardee decisions (each round has its own `EvaluationVendor` rows + decisions). So:
  - If award creation is driven by the **final (awardees-selected) round's `evaluationId`** → correct winners + their carried docs (`appianDocId` retained → docs resolve).
  - If GCW instead uses its **stored (root) mapping** id, or GSS passes the root id, the result is **Round-1 vendors and Round-1 decisions → wrong awardees.**
- **Severity:** High — wrong awardees / wrong award documents is a correctness (not cosmetic) failure.
- **Fix / confirm:** guarantee the award + winning-vendor calls use the **final round's `evaluationId`** (e.g., GSS drives `create…AwardsFromEvaluation` from the awardees-selected round record via `rv!identifier`), **or** make the winning-vendor helper resolve the family and pick the terminal round. Needs the §6 confirmation of which id GCW actually uses.

### F — Eval + vendor + doc details ⚠️ (Medium–High)
- `getEvaluationandVendordetails` (`_…17983502`) takes a **single `evaluationId`** → same round-sensitivity as H. Wrong round if the root id is passed. Fix travels with H.

### 4 / 9 — eval↔solic mapping & award links ⚠️ (Medium / Low–Medium)
- The eval↔solic mapping is created **once for the root** (via PM `0002ec9e` "Construct Eval Solic Map") and not refreshed per round → it's the source of GCW's "root id" bias behind H/F. Award links (flow 9) are stored against whichever id created the award (ideally the final round); GSS must query links by that id or the family to display them on the evaluation.

### B / 7 / solicitation reads / ref-data ✅
- `createEvaluationFromSolicitation` correctly seeds the root; solicitation-level reads (`getSolicitationDataForDraftingEvaluation`, `getLatestOrBaseSolicitationDetails`, `solicitationContractText`, `relatedProcurementDetailsForEvalSummary`) and ref-data/toggle/version flows are **round-agnostic** and unaffected.

---

## 4. Cross-cutting themes
1. **Root cause = the two identity models** (§1): PIID-keyed → root-only (stale); `evaluationId`-keyed → whatever id is passed, no family expansion, and GCW's cached id is the root. Both stem from the same multi-round facts as VM (mangled `evaluationNumber`, `sourceApplication=GSS` on clones) plus GCW's `evaluationId`-based flows.
2. **Internal inconsistency:** GCW simultaneously (a) shows Round-1 status via the PIID summary and (b) holds all rounds in its synced status list. These should be reconciled.
3. **Identity & documents are safe:** `gsmVendorRefId`, `externalVendorId`, `uniqueEntityId`, and `appianDocId` all carry across rounds → once the **correct round id** is used, vendor matching and award documents resolve correctly. The gap is always **round selection**, not identity.
4. **Silent failures:** as with VM, none of these throw — GCW just shows stale data or (worst case) creates awards from the wrong round. That raises priority.
5. **Both sync mechanisms** (APPREF in-JVM + HTTP) exhibit the same per-round accumulation, so a status-sync fix must cover both paths.

---

## 5. Recommendations (prioritized)
| # | Change | Fixes | Effort |
| :-- | :--- | :--- | :--- |
| 1 | **Make award / winning-vendor creation target the final round's `evaluationId`** (drive from the awardees-selected round record, or family-resolve to the terminal round in the winning-vendor helper). | H, 8/11, F | Medium — highest stakes (award correctness) |
| 2 | **Make the PIID summary family-aware** — resolve the AM anchor, then return the latest/active round's status + record link. | C | Small–Medium |
| 3 | **Decide GCW status-sync semantics** — anchor-only rollup vs per-round-with-parent-context; stop surfacing mangled `"PIID Round N"` names; cover both APPREF + HTTP paths. | 10 | Medium + product decision |
| 4 | **Refresh/extend eval↔solic mapping** so GCW can address the current/active round (removes the root-id bias feeding H/F). | 4 → H/F | Small–Medium |
| 5 | **Align award-links query** (flow 9) to the award-creating round or the family. | 9 | Small |

Priority #1 (award correctness) is the most consequential; #2/#3 fix the visible status drift; #4 removes the underlying root-id bias.

---

## 6. Open confirmations (GCW-side; not blockers)
1. **Which `evaluationId` reaches award creation / H / F** — the root (from GCW's eval↔solic mapping) or the final round (from a GSS record action on the awardees-selected round)? This single fact decides whether awards are correct today. *(Requires reading the GCW-side award-creation process + how GCW invokes `getWinningVendorAndBasicInformation`.)*
2. **Is GCW's synced status list intended to be plural** (per-round) or singular per solicitation? Determines fix #3 direction.
3. **`getAwardLinksForEvaluation` query scope** on the GSS side (by single id vs family).
4. **Does WI-1 keep the root `sourceApplication = AM`?** (Assumed yes — clones set GSS; the root created from a procurement stays AM. If WI-1 ever re-stamped it, flow C would return nothing.)

---

## 7. Verification appendix
- Winning-vendor builder (no family expansion): `AS_GSS_UT_constructEvalVendorAndDocsForMultipleEvalIds` (`_…23014528`) — `WHERE evaluationId IN evaluationIds`; `isWinningVendor = decisionType SELECT`.
- Winning-vendor entrypoint: `_…18080306` → `_…18080158` (`evaluationIds` list).
- Eval+vendor+doc entrypoint: `_…17983502` → `AS_GSS_GCW_getEvaluationVendorAndDocumentDetails_V1` (single `evaluationId`).
- PIID summary (root-only): `_…16906534` → `_…16904747` (evaluationNumber=PIID + sourceApplication=AM + isActive).
- Status list Web API (no parentEvalId filter): `AS_GSS_WA_GET_EvaluationStatusList` `_…17688586`; sync PM `0006ef1c`; eval↔solic map PM `0002ec9e`.
- Round-clone semantics (evaluationNumber="PIID Round N", sourceApplication=GSS, carry-forward with appianDocId): `AS_GSS_UT_duplicateEvaluationForNewRound` `_…42160`; data roots vs `"… Round N"` clones (see `02_…` §1).

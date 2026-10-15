# 46-07 — Web experience (spec workspace, CR flow, preview tabs, coverage)

> **Status:** 🟡 DRAFTED 2026-10-14. Repo: **genesis** (`web/`). Parent: `specs/phase-46-spec-change-requests.md`.
> Decisions D3–D7, D10, D12, D14–D16, D19 (umbrella §3).
> Story-side UI (answers, references, history, badges) is in 46-08. Follows ADR-055 (design language, tokens, no
> hard-coded brand hex) and ADR-028 (typed client, `/api` prefix centrally); every new interactive surface gets a
> jest-axe test; `web/static` rebuilt and committed.

## 1. Principles

- **One place.** Everything happens in the spec's stage workspace: the toolbar, a CR banner, the chat, and the
  full-screen preview. No new pages.
- **Two clicks matter:** **Analyze impact** (prepare) and **Apply changes** (commit). Both always say what they
  will do before doing it.
- **The document is the truth.** The CR document shows exactly what Apply will execute; the chat is where it is
  discussed.

## 2. Spec workspace toolbar (`StageArtifactWorkspace.tsx`, spec stage)

| Spec state | Toolbar actions (left → right, existing items unchanged unless noted) |
|---|---|
| Draft / In progress / In review | unchanged (Start / Submit for review / Approve / Request changes) |
| Completed, breakdown **not** complete | unchanged (**Reopen**) |
| Completed, breakdown complete or stories finalized | **Initiate change request** (primary) replaces Reopen · **Change requests (n)** · Export .md · Publish to team · Preview. *Save milestone hidden.* |
| Under change | status badge **"Under change · CR-03"** (warning tone) · **Change requests (n)** · Export .md (working copy) · Preview. *Save milestone and Publish hidden.* The CR banner (§4) appears under the toolbar. |
| Pulled read-only mirror | no actions except **Change requests (n)** (read-only) and Preview; when the owner has a CR open: an `AdvisoryMarker` "Spec under change by ram" (46-09 §5). |

`status.ts`: `SPEC_STATUSES` += `under-change`; `SPEC_STATUS_LABEL["under-change"] = "Under change"`;
`specStatusTone("under-change") = "warning"`; `SPEC_ACTION_LABEL` is unchanged (CR actions are not generic actions).
`types/features.ts`: `SpecStatus` += `"under-change"`; new `ChangeRequest`, `ChangeRequestDetail`, `CrAnalysis`,
`CrPlanValidation`, `ApplyReport`, `ClauseCoverage` types mirroring 46-04 §5 / 46-05 / 46-06 §8.

## 3. Initiate change request

`InitiateChangeRequestDialog`: title "Start change request CR-03"; one optional field "What's changing?"
(placeholder "e.g. Accept LEI for corporate applicants"); text: "While CR-03 is open, developers keep working from
spec revision 6. Your edits take effect only when you apply the change request." Buttons **Start CR-03** /
Cancel. On success the chat shows the CR divider and the banner appears.

## 4. The CR banner (`ChangeRequestBanner`)

A slim bar under the toolbar, one row, content by `analysis.state`:

| State | Text | Buttons |
|---|---|---|
| No analysis yet | "**CR-03 open** — edit the spec in the chat, then analyze the impact on stories." | **Analyze impact** · Discard change request |
| Analyzing (chat turn streaming) | "Analyzing the impact of CR-03…" (spinner) | — |
| Awaiting plan (analysis computed, no plan for it yet, chat idle) | "The impact input is ready but the agent hasn't written the plan yet." | **Ask the agent to write the plan** (sends "Please write ./cr/CR-03/plan.json for the latest impact analysis.") · Analyze again · Discard |
| Current, plan valid | "**CR-03 impact analysis ready** — 3 to update · 1 new · 2 unchanged (past Design)." | Open impact analysis · **Apply changes** · Analyze again · Discard |
| Current, plan has errors | "The impact analysis has **2 problems** to resolve." | Open impact analysis · **Ask the agent to fix** · Discard |
| Stale | "You changed the spec after the analysis." | **Analyze impact** · Open previous analysis · Discard |

- **Analyze impact** → `POST …/analyze`; if `no_changes`, toast "No spec changes since CR-03 opened". Otherwise the
  web sends the visible chat message "Analyze impact for CR-03." through the normal `ChatThread` send path (the
  agent instructions arrive as an agent note posted by the endpoint). When the turn ends, the banner refetches the CR
  detail.
- **Ask the agent to fix** sends "Please fix these problems in plan.json: …" with the validation errors.
- **Open impact analysis** opens the preview on the CR tab (§6).
- Disabled states always carry a tooltip with the reason (e.g. "Wait for the chat to finish").

## 5. Apply and discard dialogs

**`ApplyChangesDialog`** (opened by Apply changes; fetches the CR detail first):
- Heading "Apply CR-03?"; a compact summary list: "Update 3 stories", "Create 1 story", "Remove 0 stories",
  "Leave 2 stories unchanged (past Design)", "Spec becomes revision 7", "UX Design and Technical Design will be
  marked *spec changed*".
- **Locked changes** (only when the plan changes a Design Review+ story at the user's request): a warning box with
  one checkbox per story — "Change **GNS_000057** (Implementation) as you asked" — all must be ticked to enable
  Apply; their IDs are sent as `confirm_locked_story_ids`.
- Buttons **Apply changes** / Cancel. On 409 `apply_blocked` the dialog lists the blockers with the next step
  ("Analyze impact again").
- On success: toast "CR-03 applied — 3 updated, 1 created"; the banner disappears; the toolbar returns to the
  Completed set; the preview CR tab shows the frozen *Applied* document.

**`DiscardChangeRequestDialog`**: "Discard CR-03? The spec goes back to revision 6. No stories change. The CR stays
in the list as *Discarded*." Buttons **Discard CR-03** (destructive tone) / Cancel.

## 6. Preview with tabs (`AnnotatablePreviewDialog`)

- Gains a `documents: {key, label, artifactUrl}[]` prop (backward compatible: a single document → no tab strip).
- While a CR is open (or when opened from the CR list), the tabs are **Spec** (working copy) and
  **CR-03 Impact Analysis**. Opening from the CR list of a closed CR shows that CR's frozen document plus the spec
  revision it produced.
- Annotations work on both tabs; the composed chat message names the document
  (`> [CR-03 Impact Analysis] "GNS_000057 …"` + the comment) so the agent knows which file the comment is about.
- **Refresh** re-renders the current tab (the CR document is rendered live from the plan, 46-05 §9).

## 7. Clause numbers and coverage in the spec preview

- The served spec shows clause labels in the left margin and a badge in the right margin (46-02 §11): filled with the
  number of stories (or backlog items), **hollow "no story"** when uncovered. Legacy features (46-03 §7) show labels
  only, no badges.
- Clicking a badge posts `genesis:clause` to the host; `ClauseCoveragePopover` (anchored near the dialog's
  right edge) lists the items: key, title, lane chip; each row links to the
  Story Workspace (`/applications/:app/stories/:id?from=feature`) in a new tab. Uses `GET …/spec/coverage`.
- Toolbar inside the preview: a **Coverage** toggle (default on when items exist) to hide/show the margin badges.

## 8. Legacy features

Features whose breakdown pre-dates Phase 46 (46-03 §7) look and behave exactly as today: Reopen after the breakdown,
no CR controls, no coverage badges, no "From the spec" card on stories. Nothing prompts the user to link them.

## 9. Change requests list (`ChangeRequestsPanel`)

Opened from **Change requests (n)** as a right-side `Drawer`. Rows newest first: **CR-03** · title · status chip
(Open / Applied / Discarded) · opened by + date · closed date · "rev 6 → 7" · counts ("3 updated · 1 created").
Clicking a row opens the preview on that CR's document. Empty state: "No change requests yet. Once the breakdown is
complete, spec changes go through change requests."

## 10. Elsewhere

- **Feature overview, Spec stage card:** a chip "CR-03 open" (warning) or "Last change: CR-02 · 12 Oct" (neutral).
- **Feature Activity feed:** the audited transitions already appear; render `initiate-change` / `apply-change` /
  `discard-change` with friendly text ("ram opened CR-03", "ram applied CR-03").
- **Chat dividers (`ChatThread`):** `system` messages with `meta.kind` ∈ `cr-divider | cr-analyzed | cr-applied |
  cr-discarded` render as a full-width divider with the CR label and a link "Open CR-03"; other system messages keep
  `SystemNudge`. The chat API includes `meta` (parsed `meta_json`, **without** `agent_text`) on messages.

## 11. Client plumbing

`lib/api/features.ts` (or `changeRequests.ts`): `listChangeRequests`, `getChangeRequest`, `initiateChangeRequest`,
`analyzeChangeRequest`, `applyChangeRequest`, `discardChangeRequest`, `crDocumentUrlFor`, `crExportUrlFor`,
`specCoverage`, `specClauses`. `lib/query/keys.ts`: `qk.features.changeRequests(featureId)`,
`qk.features.changeRequest(featureId, crNo)`, `qk.features.specCoverage(featureId)`. Hooks in
`features/features/hooks.ts`: `useChangeRequests`, `useChangeRequest` (polls every 5 s while a chat turn is
streaming), `useInitiateChangeRequest`, `useAnalyzeChangeRequest`, `useApplyChangeRequest`,
`useDiscardChangeRequest`, `useSpecCoverage`. Mutations invalidate the spec, its `allowed`, the CR
queries, coverage, and the feature's stories.

## 12. Tests (Vitest + RTL + MSW + jest-axe)

Toolbar per state (§2 table); Initiate dialog; banner per analysis state incl. disabled tooltips; Analyze →
`no_changes` toast vs chat send; Apply dialog summary + locked-story checkboxes gate the button + 409 blocker list;
Discard dialog; preview tabs (single-document back-compat, annotation message names the document); coverage popover
from a `genesis:clause` message; legacy feature (no CR controls, no badges); CR list; chat divider rendering; feature card chip;
jest-axe on the workspace in Under change, the three dialogs, the drawer and the popover.

## 13. Acceptance (manual, live)

On a finalized feature: Initiate CR-01 → edit two clauses and add one in the chat → Analyze impact → the document
lists the right stories with sensible defaults → change one decision in the chat → the document updates → Apply →
stories updated/created, document frozen, spec revision +1, coverage badges updated; Discard on a second CR restores
the spec exactly.

## 14. Build decisions (2026-10-15, asked one at a time before the build; these win over §2–§13 where they differ)

- **Q1 — small additive backend reads → A:** 46-07 adds them (with pytest) so the UI renders from durable state
  instead of inferring it; recorded as a deviation from "web-only". Rejected: web-only inference (lock = "Reopen is
  missing", busy = matching blocker text).
- **Q2 — a closed CR opened from the list → A:** `/spec/artifact` gains `revision=<n>` (labels + coverage computed
  for that revision). An applied CR opens with two read-only, non-annotatable tabs: **CR-n Impact Analysis** (frozen)
  and **Spec rev N**; a discarded CR (no revision produced) opens its document tab only. Rejected: the frozen CR
  document only.
- **Q3 — proposals 1–14 → A (all accepted):**
  1. Toolbar — locked Completed: **Initiate change request** (primary) · Change requests (n) · Export .md · Publish ·
     Preview, Save milestone hidden; Under change: badge "Under change · CR-n" (warning) · Change requests (n) ·
     Export .md · Preview, Save milestone + Publish hidden; legacy features unchanged; "Change requests (n)" hidden
     while the count is 0 and the spec isn't locked.
  2. Initiate dialog — "Start change request CR-0n" (n = the highest existing number + 1); generic wording ("developers
     keep working from the current spec revision"); the banner then shows the real base revision.
  3. Banner — driven by the CR detail (`analysis.state` + validation + `chat_busy`); "Analyzing…" while our own turn
     streams or while `chat_busy`; the detail polls every 5 s while busy and refetches when the turn ends; every
     disabled button carries a tooltip with its blocker.
  4. Analyze impact — `no_changes` → toast "No spec changes since CR-n opened"; else the chat sends "Analyze impact
     for CR-n." through the normal send path; the two "ask the agent" buttons send §4's texts (+ the validation
     errors listed).
  5. Apply dialog — summary from `counts.plan`, the next revision number, and "UX Design / Technical Design will be
     marked spec changed" for each stage that exists; one checkbox per locked story needing confirmation (Apply
     disabled until all are ticked); 409 `blockers` listed with "Analyze impact again"; 409 `apply_failed` shows its
     message; success → toast + invalidate the spec, its allowed actions, the CR queries, coverage, stories and the
     feature detail.
  6. Discard dialog — §5 text, destructive-tone button.
  7. Preview tabs — a `documents[]` prop (a single document → no tab strip, so existing callers are unchanged); while
     a CR is open: Spec (working copy) + CR-n Impact Analysis, both annotatable; each queued comment is tagged with its
     tab and the `[CR-n Impact Analysis]` prefix appears only when there are several tabs; Refresh reloads the current
     tab.
  8. Coverage — a "Coverage" switch in the preview (default on when coverage exists) via the new `coverage=0`
     option; the popover opens only on a `genesis:clause` message whose source is the spec iframe, reads
     `/spec/coverage?revision=working`, is a small `role=dialog` panel inside the preview (Esc closes); rows link to
     the Story Workspace in a new tab, or show backlog items without a link.
  9. CR list — the existing `Drawer`, newest first, §9 columns; counts from the stored `summary`, "rev 6 → 7" from
     the base/result revisions; a row opens the preview (Q2).
  10. Overview chip — "CR-n open" (warning) when one is open, else "Last change: CR-n · 12 Oct" for the latest
      **applied** CR (neutral); discarded CRs don't count as a change.
  11. Activity — "ram opened CR-03" / "ram applied CR-03" / "ram discarded CR-03" from a CR label the activity
      endpoint adds (Q1).
  12. Chat dividers — `meta` on the web `ChatMessage` type; the four `meta.kind` values render a full-width divider
      with the visible text + "Open CR-n" (in the spec workspace it opens the preview on the CR tab; elsewhere the CR
      document in a new tab); `context` and other system messages keep `SystemNudge`.
  13. Pulled mirrors — no CR controls in 46-07; the read-only CR list + the "under change by …" marker go to 46-09.
  14. Backend additions (Q1 + Q2): `/spec/allowed` + `change_requests {downstream_locked, open, count}`; the CR
      detail + `locked_confirmations`, `next_revision_no`, `chat_busy`; the activity CR label (initiate events matched
      to CRs by number, apply/discard events by close time — each is written in the same transaction as its CR);
      `coverage=0` and `revision=<n>` on `/spec/artifact`. All additive, with pytest.


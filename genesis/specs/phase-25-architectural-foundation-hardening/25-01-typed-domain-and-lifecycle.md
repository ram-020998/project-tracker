# 25-01 — Typed SDLC Domain Model & Lifecycle State Machine (keystone)

- **Status:** ✅ BUILT (2026-08-18) — implemented + tested + committed locally; **NOT released** (ships with the Phase-25 rollup via 25-14). · **Review items:** C-1, C-2, §H, E-1 · **Roadmap:** Phase 1 · **Proposed ADR:** ADR-050
- **Repos:** genesis (+ migration **m0013**) · **Depends on:** nothing · **Unblocks:** 25-06 (services), 25-08 (locking), 25-11 (stories), 25-13 (lifecycle audit)
- **As built:** `genesis/domain/` (enums/entities/transitions/lifecycle/events/errors) + `LifecycleService` (single authority); m0013 `lifecycle_transitions` + `LifecycleAuditStore`; `POST /features/{id}/spec/actions/{action}` (+ `GET /spec/allowed`), illegal→409 `{current,action,allowed}` / precondition→409 `{reason}`; legacy `PATCH /spec/status` deprecated (header); `FeatureStore.set_status` demoted; web allowed-action buttons replace the any-status select. Commits `d70bd20` (domain core) + `0b90392` (audit/API/web). Backend **509** pytest + ruff green; web **163** vitest + lint + tsc + build green. Version unchanged (0.48.7 — no release).

## 1. Goal

Replace the untyped, string-status SDLC model with a **typed domain** (`Feature`, `Story`, `Stage`, `Artifact`, `ArtifactVersion` + enum states) and a **single authoritative `LifecycleService`** that owns every lifecycle transition via a declarative transition table. This is the substrate every future SDLC stage/agent/artifact grows on.

## 2. Why (review evidence)

- **C-1:** `kb/features.py` returns raw `dict`s from every read; `api/features.py` re-interprets them; there is no typed entity.
- **C-2:** `FeatureStore.set_status` (`kb/features.py:158`) validates only that the target is in `VALID_SPEC_STATUSES` — **any current → any target** is accepted (`completed → draft` is legal today). No transition matrix, no single authority.
- **No Story/Stage/Artifact concept** exists (`grep story` = 0 backend hits); Design/Breakdown are placeholder cards (ADR-044). The product roadmap (Feature→UX→Tech-Design→Breakdown→Story; Story: Design→Impl→Review→Deploy→Verify) has no domain behind it.
- **E-1:** building Design/Breakdown/Story on the current string model would metastasize the placeholder pattern.

## 3. Current state (cited)

- `kb/features.py`: `FeatureStore` — dict-returning CRUD over `kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`; `VALID_SPEC_STATUSES = ("draft","in-progress","in-review","completed")`; `set_status` membership-check only.
- `api/features.py`: `register_features_routes(api, settings, kb_store, chat)` — closures return `dict`s directly as JSON.
- Schema owned by `db/migrations/m0010_features.py`; `status` is plain `TEXT`.
- `web/src/features/features/**`: reads `spec_status` strings; ArtifactPipeline (ADR-044) renders Spec + disabled Design/Breakdown.

## 4. Design

### 4.1 Domain entities (`genesis/domain/` — NEW package)

Plain `@dataclass(frozen=True)` value/entity types (no ORM). Mapped from DB rows at the store boundary; serialized to Pydantic response models at the API edge.

```
genesis/domain/
  __init__.py
  ids.py           # typed ids: FeatureId, StoryId, StageId, ArtifactId (NewType[int])
  enums.py         # StrEnum: FeatureStageKind, StoryStageKind, ArtifactKind, LifecycleState
  entities.py      # Feature, Story, Stage, Artifact, ArtifactVersion (frozen dataclasses)
  transitions.py   # the declarative transition tables (data, not code branches)
  lifecycle.py     # LifecycleService — the ONLY mutator of lifecycle state
  errors.py        # IllegalTransitionError, UnknownStateError, DomainError
  events.py        # LifecycleEvent (emitted on every transition)
```

- `LifecycleState` is a `StrEnum` so it serializes as its current string (back-compat with stored TEXT + the web).
- `ArtifactKind`: `spec | ux_design | technical_design | breakdown | story_design | implementation | code_review | deployment | verification` (extensible — adding a kind is one enum member + one transition-table row).
- `Feature` holds `stages: tuple[Stage, ...]`; a `Story` holds its own `stages`; each `Stage` references its `Artifact` + `LifecycleState`. Stories belong to a Feature (post-Breakdown); Phase 25-11 wires story execution — 25-01 only defines the types + tables so they exist and are enforced.

### 4.2 Transition tables (`transitions.py`) — the §H matrix as data

```python
# artifact/spec lifecycle (illegal transitions simply absent from the table)
SPEC_TRANSITIONS: dict[tuple[LifecycleState, str], LifecycleState] = {
    (DRAFT,       "start"):           IN_PROGRESS,
    (IN_PROGRESS, "submit"):          IN_REVIEW,
    (IN_REVIEW,   "approve"):         COMPLETED,
    (IN_REVIEW,   "request-changes"): IN_PROGRESS,
    (COMPLETED,   "reopen"):          IN_PROGRESS,
}
STORY_TRANSITIONS = { ... design→implementation→code_review→deployment→verification→done ... }
```

Each table is pure data + optional `precondition` predicates (e.g. "html artifact present", "reviewer sign-off"). New stage/state = a new row; **no code branch changes.**

### 4.3 `LifecycleService` — single authority

```python
class LifecycleService:
    def __init__(self, feature_store, *, clock=..., emit=None): ...
    def transition(self, *, entity_kind, entity_id, action, actor=None) -> LifecycleState:
        # 1. load current state (typed)  2. look up (state, action) in the table
        # 3. missing → raise IllegalTransitionError(current, action, allowed=[...])
        # 4. evaluate precondition → PreconditionFailed if unmet
        # 5. persist via the store  6. emit LifecycleEvent (feeds 25-13 audit)
```

- `FeatureStore.set_status` becomes **private/deprecated**; the only public path to change a status is `LifecycleService.transition`. A guard test asserts no other module calls the low-level setter.
- `IllegalTransitionError` maps to **HTTP 409** at the API edge with `{current, action, allowed:[...]}` (review §9 — meaningful domain errors, not field mutation).

### 4.4 API changes (review §9 — action endpoints over field mutation)

Replace/augment the direct status PUT with intent endpoints:

```
POST /api/features/{id}/spec/actions/{action}     # start|submit|approve|request-changes|reopen
  → 200 {state} | 409 {error:"illegal_transition", current, action, allowed}
```

The existing `POST /features/{id}/spec/status` remains for one release (delegates to the service, rejects illegal transitions) then is removed in 25-11's cleanup — deprecation noted in the response header.

### 4.5 Persistence (m0013)

- No destructive change. `kb_feature_specs.status` stays TEXT (enum serializes to the same strings).
- Add `lifecycle_transitions` audit table (append-only: `entity_kind, entity_id, from_state, to_state, action, actor, at`) — consumed by 25-13. This is additive; `current_version` → 13; bump all `current_version==N` tests (bible §7).

## 5. Files touched
- **New:** `genesis/domain/**` (7 modules), `db/migrations/m0013_lifecycle.py`, `tests/test_domain_lifecycle.py`, `tests/test_lifecycle_transitions.py`.
- **Edit:** `kb/features.py` (add row↔entity mappers; demote `set_status`), `api/features.py` (action endpoints + 409 mapping + Pydantic response models), the web feature pages (call action endpoints; render `allowed` actions as the only enabled buttons).

## 6. Tests (must run without DB/LLM/network where possible)
- Pure transition-table unit tests: every legal transition succeeds; a matrix of illegal transitions each raises `IllegalTransitionError` with the correct `allowed` set.
- Precondition tests (submit without html → `PreconditionFailed`).
- Mapper round-trip tests (row → entity → row).
- API tests: action endpoints return 200/409 with the documented body; the deprecated status endpoint still works + emits the deprecation header.
- Guard test: `grep`-style AST check that no module outside `LifecycleService` calls the low-level status setter.
- jest-axe + RTL: the feature page renders only allowed actions.

## 7. Risks & mitigations
- **Risk:** web currently sets arbitrary statuses. **Mitigation:** keep the status endpoint one release; ship the web switch to action buttons in the same release.
- **Risk:** enum drift vs stored strings. **Mitigation:** `StrEnum` with values identical to today's strings; a migration test asserts every stored value parses.

## 8. Backward-compat & Out of scope
- Compat: existing specs keep working; statuses unchanged on disk.
- Out of scope: authoring Design/Breakdown/Story *content* (later product work); the Story *execution* wiring (25-11 consumes these types).

## 9. Definition of Done
Typed domain + `LifecycleService` shipped; illegal transitions rejected app-wide with 409; m0013 applied + version tests bumped; web uses action endpoints; ADR-050 → Accepted + mirrored to `bible/04`; `progress/phase-25-01-*.md`; genesis release CI-green.

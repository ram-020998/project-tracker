# Backlog — Implementation packages (one deployment package per story)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-10-12 (Phase 45 spin-off, decision 1a/1b). · Depends on
> Phase 42 (the implementation lane) + Phase 45 (ADR-073 + the `DevMcpPackages` client).

## Context
The Workbench Implementation lane (Phase 42, `story-implementation`) creates and updates design objects in the
dev-tagged environment, but nothing groups them for deployment — a developer has to find and package them by hand.
Phase 45 introduces ADR-073 (package management as the only sanctioned non-design-object write, performed by Genesis
code through `genesis/kb/dev_packages.py::DevMcpPackages`) and uses it for temporary delta-sync packages.

## The deferred capability
Create and maintain **one Appian deployment package per story** for the objects the implementation modified.

- **Name:** `GNS_000123 – <story title>` (the Phase-44 story id + title; truncate to Appian's name limit).
- **One package per story** (decided with the user, 2026-10-12). Re-implementing the story (a re-run after send-back)
  **adds** to the same package; Genesis never deletes it.
- **Who adds objects:** a deterministic program node in `story-implementation` after `verify`/`heal` (not the agent):
  find-or-create the story's package → `addPackageObjects` for every object in `implementation.json` with action
  create/update → `getPackage` to confirm → record the package uuid + Designer link in the implementation report, on
  the story (a new `kb_stories.package_uuid` or a story-stage field), and in the Object Wiki entry.
- **Safety:** reuse the ADR-073 client unchanged. Its delete guard (`genesis-delta-` prefix only) means story packages
  can never be deleted by Genesis. Agents keep their current tools; `appian-dev-write` is unchanged.
- **UI:** a package link on the Story Workspace Implementation tab + the board card.

## Open questions when picked up
- Associate the story package with an Appian **release** (`createRelease`/`releaseUuid`), e.g. per feature?
- Include database scripts (`addPackageDbScript`) for record types whose tables changed?
- Behaviour when an object was already in another story's package (Appian allows an object in many packages).
- Remove objects from the package when a rollback is executed (backlog `implementation-rollback-execution.md`)?
- Collaboration: publish the package link to the Hub with the story (an additive story field)?

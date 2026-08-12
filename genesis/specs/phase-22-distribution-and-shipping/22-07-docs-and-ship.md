# 22-07 — Docs + ship

> **Status:** ✅ SHIPPED (2026-08-12) — README quickstart + `docs/INSTALL.md` shipped in **genesis v0.47.0**; bible
> (`AGENT_ONBOARDING.md`) refreshed (§2 tag + Phase-22 note, §4 map, **ADR-046**, §7 lessons, §9 Phase-22 block, header ⭐);
> `reference/decision-log.md` ADR-046 appended; tracker §3 → SHIPPED + §6 entry; umbrella/sub-specs flipped. · **Phase:** 22 ·
> **Repo:** genesis (+ project-tracker) · **Depends on:** 22-01..22-06

## Goal
A user-facing "Install & Run Genesis" guide that lives **with the code** (§10.4), plus the release + bible refresh.

## Docs (in the `genesis` repo)
- **README quickstart** (top of README): prereqs → `git clone` → `scripts/install.sh` → `genesis up` → in-app Kiro sign-in.
- **`docs/INSTALL.md`** (full guide):
  - **Prerequisites:** Python 3.13, git + SSH access to the four repos, `kiro-cli`; optional (Appian features): a dev-tagged
    environment, `uv`, `gws` dotfiles.
  - **Install:** clone `genesis`, run `scripts/install.sh` (what it does, the SSH-access preflight, idempotency).
  - **Run:** `genesis up` (opens the browser), `down` / `status` / `logs`.
  - **First run:** the preflight checklist + Kiro sign-in.
  - **Updating:** the in-app "Update to vX.Y.Z" banner (one-click) and `genesis update`; note the on-`main` requirement.
  - **Security:** local single-user, **localhost-only, no auth — do not expose on a network** (ADR-026/031).
  - **Troubleshooting:** SSH-access errors, kiro not signed in, port in use, where logs/state live (`~/.genesis`).

## Ship
- Release **genesis v0.47.0** (per 22-06); confirm the `clean-install` + `genesis` + `frontend` CI jobs are green.
- **Bible refresh** (`AGENT_ONBOARDING.md`): §2 tag (v0.47.0) + a "Distribution" note; §4 map (`scripts/install.sh`,
  `api/system`, the CLI subcommands, the web update banner/panels); §5 **ADR-046** (clone+tag distribution; wheel+index
  deferred); §7 a lesson if any surfaced; §9 a Phase-22 SHIPPED block. tracker §3 row + §6 status entry.

## Acceptance
- A colleague, given only `docs/INSTALL.md`, can install + launch + sign into Kiro + update, on a clean machine, without help.

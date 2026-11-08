<!-- archived verbatim by the Phase 51 write-back (2026-11-08, L0 cut B4) from bible/02-architecture.md §3; superseded by ADR-080 (one repo, one tag); never mandatory reading -->

**Release/versioning (ADR-019):** git+ssh tag pins along `genesis → genesis-core → kiro-agent-sdk`;
`CORE_MAJOR` (currently 1, distinct from pip version) is the hard compat gate the loader enforces
(refuse-to-load on mismatch; additive-only within a major).

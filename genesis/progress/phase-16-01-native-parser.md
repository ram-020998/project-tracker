# Phase 16-01 — Native Appian parser (`genesis-appian-parser`) — AS BUILT

> **Status:** ✅ Implemented + tested locally · **Tag:** `v0.1.0` (commit `822b683`) · **Date:** 2026-08-04
> **Repo:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-appian-parser` (NEW; **local only — no remote yet**)
> **Spec:** `specs/phase-16-appian-knowledge-base/16-01-native-parser.md`

## What was built

A Genesis-owned, **stdlib-only** Python 3.13 package that parses an Appian export
package into an **in-memory** `KbParseResult` — **no file output, no SAIL source
retained** (ADR-037).

- **Public API** (`genesis_appian_parser/api.py`): `parse(source: str|bytes, *, locale="en-US", exclude_types=None) -> KbParseResult`.
- **Result model** (`result.py`): `KbObject`, `KbEdge`, `KbBundle`, `KbBundleMember`,
  `KbApplicationInfo`, `ParseError`, `KbParseResult`.
- **Code-free metadata**: `_TYPE_SPECIFIC_FIELDS` per type + a recursive `_strip_sail`
  that removes any SAIL-bearing key (`sail_code`, `definition`, `form_expression`,
  `input_expression`, `output_expression`, `ui_expr`, `visibility_expr`, `expressions`,
  `condition`, `gateway_conditions`, `test_cases`, `test_inputs`, `settings_json_raw`,
  `request_body`).
- **Debug CLI**: `python -m genesis_appian_parser <zip>` → JSON summary (no code).

## Approach — faithful port, not rewrite

Physically copied the Atlas `appian_parser` package → `genesis_appian_parser`,
rewrote imports, then:
- **Kept (ported):** `package_reader`, `type_detector`, `parser_registry` + all 20+
  `parsers/` (incl. `write_extractor`), `resolution/`, `dependencies/analyzer`,
  `domain/`, `diff_hash`, and the **in-memory bundle builders** (`output/bundle_coordinator`,
  `bundle_file_builder`, `bundle_structure_builder`, `bundle_code_builder`).
- **Dropped:** `cli.py`, `__main__.py` (replaced with a thin one), `versioning/`,
  `schema/`, `enrichment/`, and all Atlas file-writers. Versioning moves into the
  Genesis `KbStore` SCD-2 model (16-02).
- Fixed one ruff `F811` (a duplicate `DumpOptions` dataclass, dead code from the CLI).

## Verification (evidence)

Tested with the genesis venv Python 3.13 against the **real** vendored package
`tests/fixtures/AiDocumentCenterv4.3.1.zip` (the user's sample, 4.7 MB):

- **Parse result:** 2620 objects · 5084 edges · 174 bundles · 804 orphans · **0 errors** · ~1.9 s.
- Object counts look right (Expression Rule 570, Interface 238, Process Model 110,
  Record Type 39, Constant 288, Translation String 1316, AI Skill 14, …).
- The **newer `aiAgent` type** (2 objects, unknown to the Atlas parser) is **skipped
  gracefully** — no crash — confirming unknown-type fallback (spec R1).
- **13 pytest tests green**: populated result + exact counts; app identity; stats shape;
  human-readable types; resolved names (no raw `_a-…` tokens); edges reference known
  objects; bundles have members/types; entry points flagged; orphans consistent;
  deterministic diff-hashes; `parse(bytes) == parse(path)`; **no-SAIL key guard**;
  **known-code-string-absent guard** (real SAIL present in source is proven absent
  from the serialized result).
- **ruff clean.** `.gitlab-ci.yml` runs ruff + pytest on `python:3.13-slim`.

## Decisions / notes

- **`KbBundle.flow` is a `dict | None`** (the Atlas structure: `{process_model:<graph>, subprocesses:[…]}`).
  **Resolved (2026-08-04, "follow the standard solution"):** this **is** the Atlas standard — verified against the
  Atlas MCP (`atlas_mcp/tools/write_set.py` consumes `flow["process_model"]`) and the parser's own MCP
  (`mcp_server/server.py` returns `structure.get("flow")` verbatim). The KB stores it verbatim in
  `kb_bundles.flow_json` and `get_bundle` returns it verbatim. The tool-contracts doc §2.10 (which wrongly assumed a
  textual string list), the umbrella §5 DDL comment, and 16-01's field type were corrected. No parser code change (it
  already emits the dict); the code comment was clarified (`6760d54`).
- Application identity = the single `Application` object's `name`+`uuid`; falls back to
  the zip stem if absent.
- Fixture is **vendored** for reproducible tests (Atlas does the same); overridable via
  `$GENESIS_APPIAN_PARSER_FIXTURE`. Flag if the app export should not live in git.

## Remaining / hand-off

- **Remote repo + push:** the code repo is **local only** (git init + commit + tag
  `v0.1.0`). Creating the GitLab remote + pushing likely needs the user — the `glab`
  token lacks `api` scope (bible §6). Provide a repo URL or create it, and I'll push.
- **Next:** 16-02 (m0007 `kb_*` schema + `KbStore`) consumes `KbParseResult`; resolve
  the `flow` shape there.

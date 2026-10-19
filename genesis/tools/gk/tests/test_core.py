"""gk unit tests (python3 -m unittest). Every check has at least one negative test.

Run:  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s genesis/tools/gk/tests
"""
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))        # genesis/tools/gk on sys.path
import core  # noqa: E402

FIX = HERE / "fixtures"
SAMPLE = (FIX / "sample_source.md").read_text()
SAMPLE_LINES = SAMPLE.splitlines()


def fake_blob(_path):
    return SAMPLE_LINES


class InventoryTests(unittest.TestCase):
    def test_classify_and_counts(self):
        rows = core.build_inventory([
            ("genesis/doc.md", b"# Title\n\nbody\n"),
            ("genesis/.DS_Store", b"\x00\x01binary"),
            ("genesis/x/.obsidian/app.json", b'{"k":1}\n'),
            ("genesis/pic.png", b"\x89PNG\r\n"),
        ])
        by = {r[0]: r for r in rows}
        self.assertEqual(by["genesis/doc.md"][5], "extract")
        self.assertEqual(by["genesis/doc.md"][3], 3)                 # 3 lines
        # M4: EVERY archive-only row has chars=0 and lines=0 (text and binary alike)
        for p in ("genesis/.DS_Store", "genesis/x/.obsidian/app.json", "genesis/pic.png"):
            self.assertEqual(by[p][5], "archive-only", p)
            self.assertEqual((by[p][2], by[p][3]), (0, 0), p)

    def test_negative_obsidian_not_extract(self):
        rows = core.build_inventory([("genesis/x/.obsidian/workspace.json", b'{"a":1}')])
        self.assertEqual(rows[0][5], "archive-only")


class LedgerValidateTests(unittest.TestCase):
    def good_unit(self, **over):
        u = {"id": "KU-B99-0001", "src": "genesis/x.md", "lines": [3, 3],
             "type": "RULE", "areas": ["collaboration-hub"], "statement": "restated here",
             "strength": "MUST", "scope": "always", "exact": ["twelve words"]}
        u.update(over)
        return u

    def test_valid(self):
        errs = core.validate_ledger([self.good_unit()], blob_lines=fake_blob, batch_id="B99")
        self.assertEqual(errs, [])

    def test_negative_duplicate_id(self):
        errs = core.validate_ledger([self.good_unit(), self.good_unit()], blob_lines=fake_blob)
        self.assertTrue(any("duplicate id" in e for e in errs))

    def test_negative_exact_absent(self):
        errs = core.validate_ledger([self.good_unit(exact=["not in source at all"])],
                                    blob_lines=fake_blob)
        self.assertTrue(any("not found literally" in e for e in errs))

    def test_negative_lines_exceed(self):
        errs = core.validate_ledger([self.good_unit(lines=[3, 9999])], blob_lines=fake_blob)
        self.assertTrue(any("exceed" in e for e in errs))

    def test_negative_schema_missing_scope(self):
        u = self.good_unit(); del u["scope"]
        errs = core.validate_ledger([u], blob_lines=fake_blob)
        self.assertTrue(any("scope" in e for e in errs))


class CoverageTests(unittest.TestCase):
    ids = {f"KU-B99-{i:04d}" for i in range(1, 6)}

    def full_map(self):
        return {"batch": "B99", "coverage": [
            {"src": "s", "lines": [1, 1], "skip": "heading-only"},
            {"src": "s", "lines": [2, 2], "skip": "blank"},
            {"src": "s", "lines": [3, 3], "units": ["KU-B99-0001"]},
            {"src": "s", "lines": [4, 4], "skip": "blank"},
            {"src": "s", "lines": [5, 5], "skip": "heading-only"},
            {"src": "s", "lines": [6, 7], "units": ["KU-B99-0002"]},
            {"src": "s", "lines": [8, 8], "skip": "blank"},
            {"src": "s", "lines": [9, 9], "units": ["KU-B99-0003"]},
            {"src": "s", "lines": [10, 10], "skip": "formatting"},
            {"src": "s", "lines": [11, 11], "skip": "blank"},
            {"src": "s", "lines": [12, 14], "units": ["KU-B99-0004"]},
            {"src": "s", "lines": [15, 15], "skip": "blank"},
            {"src": "s", "lines": [16, 16], "units": ["KU-B99-0005"]},
        ]}

    def test_full_coverage(self):
        res = core.validate_coverage(self.full_map(), self.ids, blob_lines=fake_blob)
        self.assertEqual(res["errs"], [])
        self.assertEqual(res["gaps"], [])
        self.assertEqual(res["pct"], 100.0)

    def test_negative_gap(self):
        m = self.full_map(); m["coverage"].pop()         # drop line 16
        res = core.validate_coverage(m, self.ids, blob_lines=fake_blob)
        self.assertLess(res["pct"], 100.0)
        self.assertTrue(any("s:16" in g for g in res["gaps"]))

    def test_negative_formatting_has_words(self):
        m = {"batch": "B99", "coverage": [{"src": "s", "lines": [3, 3], "skip": "formatting"}]}
        res = core.validate_coverage(m, self.ids, blob_lines=fake_blob)
        self.assertTrue(any("skip=formatting" in e for e in res["errs"]))

    def test_negative_heading_only_not_heading(self):
        m = {"batch": "B99", "coverage": [{"src": "s", "lines": [3, 3], "skip": "heading-only"}]}
        res = core.validate_coverage(m, self.ids, blob_lines=fake_blob)
        self.assertTrue(any("skip=heading-only" in e for e in res["errs"]))

    def test_negative_blank_not_blank(self):
        m = {"batch": "B99", "coverage": [{"src": "s", "lines": [3, 3], "skip": "blank"}]}
        res = core.validate_coverage(m, self.ids, blob_lines=fake_blob)
        self.assertTrue(any("skip=blank" in e for e in res["errs"]))

    def test_negative_duplicate_unknown_target(self):
        m = {"batch": "B99", "coverage": [
            {"src": "s", "lines": [3, 3], "skip": "duplicate", "duplicate_of": "KU-B99-9999"}]}
        res = core.validate_coverage(m, self.ids, blob_lines=fake_blob)
        self.assertTrue(any("not a unit in this batch" in e for e in res["errs"]))


class CoverageBatchTests(unittest.TestCase):
    """The batch denominator comes from batches.yaml, not from the map. A batch
    whose map covers only some of its sources must FAIL by default and must list
    the unmapped sources; --partial scores only the mapped sources (exit 0 when
    complete) while still reporting the unmapped ones; a map entry for a source
    or range outside the batch is an error."""
    ids = {f"KU-B99-{i:04d}" for i in range(1, 6)}

    def full_map(self, src="s"):
        # Fully covers lines 1-16 of the 16-line sample fixture for one source.
        return {"batch": "B99", "coverage": [
            {"src": src, "lines": [1, 1], "skip": "heading-only"},
            {"src": src, "lines": [2, 2], "skip": "blank"},
            {"src": src, "lines": [3, 3], "units": ["KU-B99-0001"]},
            {"src": src, "lines": [4, 4], "skip": "blank"},
            {"src": src, "lines": [5, 5], "skip": "heading-only"},
            {"src": src, "lines": [6, 7], "units": ["KU-B99-0002"]},
            {"src": src, "lines": [8, 8], "skip": "blank"},
            {"src": src, "lines": [9, 9], "units": ["KU-B99-0003"]},
            {"src": src, "lines": [10, 10], "skip": "formatting"},
            {"src": src, "lines": [11, 11], "skip": "blank"},
            {"src": src, "lines": [12, 14], "units": ["KU-B99-0004"]},
            {"src": src, "lines": [15, 15], "skip": "blank"},
            {"src": src, "lines": [16, 16], "units": ["KU-B99-0005"]},
        ]}

    def test_fully_covered_batch_passes(self):
        res = core.validate_coverage(self.full_map(), self.ids, blob_lines=fake_blob,
                                     batch_ranges=[("s", 1, 16)])
        self.assertEqual(res["errs"], [])
        self.assertEqual(res["gaps"], [])
        self.assertEqual(res["unmapped"], [])
        self.assertEqual(res["pct"], 100.0)
        self.assertTrue(core.coverage_ok(res, partial=False))

    def test_missing_source_fails_by_default(self):
        # batch has two sources; the map only covers the first.
        res = core.validate_coverage(self.full_map("s"), self.ids, blob_lines=fake_blob,
                                     batch_ranges=[("s", 1, 16), ("s2", 1, 16)])
        self.assertIn("s2:1-16", res["unmapped"])
        self.assertLess(res["pct"], 100.0)        # the unmapped source drags the denominator
        self.assertFalse(core.coverage_ok(res, partial=False))

    def test_missing_source_partial_exits_ok_and_lists_unmapped(self):
        # Same input + --partial: the mapped source is complete -> exit 0, but
        # the unmapped source is still reported (PARTIAL progress for a resume).
        res = core.validate_coverage(self.full_map("s"), self.ids, blob_lines=fake_blob,
                                     batch_ranges=[("s", 1, 16), ("s2", 1, 16)], partial=True)
        self.assertEqual(res["pct"], 100.0)
        self.assertEqual(res["gaps"], [])
        self.assertEqual(res["unmapped"], ["s2:1-16"])
        self.assertTrue(core.coverage_ok(res, partial=True))

    def test_map_entry_for_source_outside_batch_is_error(self):
        cov = self.full_map("s")
        cov["coverage"].append({"src": "s2", "lines": [3, 3], "units": ["KU-B99-0001"]})
        res = core.validate_coverage(cov, self.ids, blob_lines=fake_blob,
                                     batch_ranges=[("s", 1, 16)])
        self.assertTrue(any("not in the batch" in e for e in res["errs"]), res["errs"])
        self.assertFalse(core.coverage_ok(res, partial=False))
        self.assertFalse(core.coverage_ok(res, partial=True))

    def test_map_range_outside_batch_range_is_error(self):
        # the batch only owns lines 1-10 of s, but the map covers 12-14.
        res = core.validate_coverage(self.full_map("s"), self.ids, blob_lines=fake_blob,
                                     batch_ranges=[("s", 1, 10)])
        self.assertTrue(any("outside the batch's ranges" in e for e in res["errs"]), res["errs"])
        self.assertFalse(core.coverage_ok(res, partial=False))


class QueryFatesTests(unittest.TestCase):
    units = [
        {"id": "KU-A-0001", "areas": ["memory"], "type": "RULE", "src": "a.md", "fate": "keep"},
        {"id": "KU-A-0002", "areas": ["web-ui"], "type": "LESSON", "src": "b.md",
         "fate": "merge", "fate_target": "KU-A-0001"},
        {"id": "KU-A-0003", "areas": ["web-ui"], "type": "DECISION", "src": "b.md",
         "fate": "superseded", "fate_target": "ADR-063"},
        {"id": "KU-A-0004", "areas": ["web-ui"], "type": "STATE", "src": "b.md",
         "fate": "wrong", "notes": "see conflicts.md#c1"},
    ]

    def test_query_filters(self):
        self.assertEqual(len(core.query_units(self.units, area="web-ui")), 3)
        self.assertEqual(len(core.query_units(self.units, type="RULE")), 1)
        self.assertEqual(len(core.query_units(self.units, fate="merge")), 1)

    def test_fates_ok(self):
        self.assertEqual(core.check_fates(self.units), [])

    def test_negative_missing_fate(self):
        u = [dict(self.units[0])]
        del u[0]["fate"]
        self.assertTrue(any("no fate" in e for e in core.check_fates(u)))

    def test_negative_merge_target_absent(self):
        u = [dict(self.units[1], fate_target="KU-ZZ-9999")]
        self.assertTrue(any("merge target" in e for e in core.check_fates(u)))

    def test_negative_wrong_without_conflict(self):
        u = [dict(self.units[3])]
        u[0].pop("notes", None); u[0].pop("fate_target", None)
        self.assertTrue(any("without a conflict id" in e for e in core.check_fates(u)))


class CopycheckTests(unittest.TestCase):
    SENT = "This paragraph has exactly twelve words here to test the copy checker now."

    def test_catches_12_word_copy(self):
        res = core.copycheck({"new.md": f"Intro.\n\n{self.SENT}\n"}, {"src.md": SAMPLE})
        self.assertTrue(res["hits"])

    def test_ignores_code_span_copy(self):
        doc = f"```\n{self.SENT}\n```\n"
        res = core.copycheck({"new.md": doc}, {"src.md": SAMPLE})
        self.assertEqual(res["hits"], [])
        self.assertTrue(any(e["kind"] == "code-fence" for e in res["exemptions"]))

    def test_ignores_short_overlap(self):
        doc = "This paragraph has exactly twelve words here to test\n"   # 10 words
        self.assertEqual(core.copycheck({"new.md": doc}, {"src.md": SAMPLE})["hits"], [])

    def test_verbatim_with_reason_exempts_and_is_listed(self):
        doc = f"{self.SENT} <!-- verbatim: quoted frozen contract -->\n"
        res = core.copycheck({"new.md": doc}, {"src.md": SAMPLE})
        self.assertEqual(res["hits"], [])
        ex = [e for e in res["exemptions"] if e["kind"] == "verbatim"]
        self.assertEqual(len(ex), 1)
        self.assertEqual(ex[0]["reason"], "quoted frozen contract")

    def test_negative_empty_verbatim_reason_is_error_and_copy_caught(self):
        # M3: an empty-reason verbatim must NOT exempt — the copy is still caught,
        # and the empty reason is reported as an error.
        doc = f"{self.SENT} <!-- verbatim: -->\n"
        res = core.copycheck({"new.md": doc}, {"src.md": SAMPLE})
        self.assertTrue(res["hits"], "copy inside an empty-reason verbatim must still be caught")
        self.assertTrue(any("empty verbatim reason" in e["msg"] for e in res["errors"]))

    def test_negative_nested_verbatim_reason_is_error(self):
        # F3: a nested/garbled verbatim reason (contains <!-- / verbatim:) is malformed:
        # it is an error and must NOT exempt, so the copy is still caught.
        doc = f"{self.SENT} <!-- verbatim: a <!-- verbatim: b --> -->\n"
        res = core.copycheck({"new.md": doc}, {"src.md": SAMPLE})
        self.assertTrue(any("malformed" in e["msg"] or "nested" in e["msg"] for e in res["errors"]), res)
        self.assertTrue(res["hits"])


class ExactTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        (self.root / "genesis-core" / "src").mkdir(parents=True)
        (self.root / "genesis-core" / "src" / "foo.py").write_text("x=1\n")

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_existing_path_ok(self):
        docs = {"d.md": "See `genesis-core/src/foo.py` for detail."}
        self.assertEqual(core.exact_check(docs, self.root, ["genesis-core"]), [])

    def test_negative_missing_path(self):
        docs = {"d.md": "See `genesis-core/src/missing.py`."}
        miss = core.exact_check(docs, self.root, ["genesis-core"])
        self.assertTrue(any(m["token"].endswith("missing.py") for m in miss))

    def test_glob_matches(self):
        docs = {"d.md": "Edit `genesis-core/src/*.py`."}
        self.assertEqual(core.exact_check(docs, self.root, ["genesis-core"]), [])


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", self.k)

    def tearDown(self):
        shutil.rmtree(self.k.parent)

    def test_valid_store(self):
        self.assertEqual(core.validate_store(self.k), [])

    def test_negative_version_outside_state(self):
        p = self.k / "areas" / "collaboration-hub" / "pack.md"
        p.write_text(p.read_text() + "\nShipped in genesis v1.2.3 now. <!-- src: KU-B99-0009 -->\n")
        errs = core.validate_store(self.k)
        self.assertTrue(any("outside state" in e for e in errs))

    def test_negative_dangling_link(self):
        p = self.k / "core.md"
        p.write_text(p.read_text() + "\nSee [gone](./nope.md). <!-- src: KU-B99-0010 -->\n")
        self.assertTrue(any("dangling link" in e for e in core.validate_store(self.k)))

    def test_negative_archive_link(self):
        p = self.k / "core.md"
        (self.k / "archive").mkdir(exist_ok=True)
        (self.k / "archive" / "old.md").write_text("old\n")
        p.write_text(p.read_text() + "\nSee [old](./archive/old.md). <!-- src: KU-B99-0011 -->\n")
        self.assertTrue(any("archive/" in e for e in core.validate_store(self.k)))

    def test_negative_missing_provenance(self):
        p = self.k / "core.md"
        p.write_text(p.read_text() + "\nAn authored paragraph with no provenance marker at all here.\n")
        self.assertTrue(any("without provenance" in e for e in core.validate_store(self.k)))

    def test_negative_rule_missing_status(self):
        p = self.k / "rules" / "ADR-063.md"
        p.write_text(p.read_text().replace("status: accepted\n", ""))
        self.assertTrue(any("status" in e for e in core.validate_store(self.k)))

    def test_negative_superseded_rule_in_pack(self):
        r = self.k / "rules" / "ADR-063.md"
        r.write_text(r.read_text().replace("status: accepted", "status: superseded"))
        self.assertTrue(any("superseded rule" in e for e in core.validate_store(self.k)))


class BuildBudgetTests(unittest.TestCase):
    def setUp(self):
        self.k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", self.k)

    def tearDown(self):
        shutil.rmtree(self.k.parent)

    def test_build_strips_provenance_and_is_deterministic(self):
        b1 = core.build_store(self.k)
        b2 = core.build_store(self.k)
        self.assertEqual(b1, b2)
        self.assertIn("CORE.md", b1)
        self.assertIn("areas/collaboration-hub/SKILL.md", b1)
        for content in b1.values():
            self.assertNotIn("<!-- src:", content)
        # the area SKILL inlines its active rule text
        self.assertIn("Collaboration is opt-in", b1["areas/collaboration-hub/SKILL.md"])

    def test_build_check_fresh_then_stale(self):
        out = self.k / "_build"
        core.write_build(self.k, out)
        self.assertEqual(core.build_check(self.k, out), [])
        (out / "CORE.md").write_text("tampered\n")
        self.assertIn("CORE.md", core.build_check(self.k, out))

    def test_budget_ok(self):
        self.assertFalse(any(b["over"] for b in core.budget_report(core.build_store(self.k))))

    def test_negative_over_budget(self):
        big = {"CORE.md": "x " * 40000}      # ~80k chars -> ~20k tokens > 15k
        rep = core.budget_report(big)
        self.assertTrue(rep[0]["over"])


class RulesContextTests(unittest.TestCase):
    def setUp(self):
        self.areas = core.load_areas()["areas"]

    def test_area_selection(self):
        al = core.areas_for_paths(["genesis/genesis/collab/service.py"], self.areas)
        self.assertIn("collaboration-hub", al)

    def test_rule_selected_by_area(self):
        rules = core.load_rules(FIX / "knowledge" / "rules")
        sel = core.rules_for_paths(["genesis/genesis/collab/service.py"], self.areas, rules)
        self.assertIn("ADR-063", sel)

    def test_rule_selected_by_applies_to_not_area(self):
        rules = [{"id": "STD-050", "path": None, "body": "",
                  "frontmatter": {"id": "STD-050", "status": "accepted", "areas": ["engine"],
                                  "applies_to": ["genesis/genesis/collab/special.py"]}}]
        sel = core.rules_for_paths(["genesis/genesis/collab/special.py"], self.areas, rules)
        self.assertIn("STD-050", sel)   # path's area is collaboration-hub, not engine, but applies_to matches

    def test_negative_superseded_rule_not_selected(self):
        rules = [{"id": "ADR-063", "path": None, "body": "",
                  "frontmatter": {"id": "ADR-063", "status": "superseded",
                                  "areas": ["collaboration-hub"], "applies_to": []}}]
        sel = core.rules_for_paths(["genesis/genesis/collab/service.py"], self.areas, rules)
        self.assertNotIn("ADR-063", sel)

    def test_context_manifest(self):
        text = ("# Sub-spec\n\ncontext:\n  areas: [collaboration-hub, web-ui]\n"
                "  rules: [ADR-063]\n  read: [genesis/genesis/collab/service.py]\n"
                "  depends_on: [48-02]\n\n## More\n")
        man = core.parse_context_manifest(text)
        self.assertEqual(man["areas"], ["collaboration-hub", "web-ui"])
        self.assertEqual(man["rules"], ["ADR-063"])

    def test_negative_no_manifest(self):
        self.assertIsNone(core.parse_context_manifest("# Sub-spec\n\nNo manifest here.\n"))


class SampleNextIdBoundaryTests(unittest.TestCase):
    def test_sample_deterministic(self):
        units = [{"id": f"KU-X-{i:04d}"} for i in range(50)]
        a = core.sample(42, "ledger", 5, units=units)
        b = core.sample(42, "ledger", 5, units=units)
        self.assertEqual(a, b)

    def test_sample_different_seed(self):
        units = [{"id": f"KU-X-{i:04d}"} for i in range(50)]
        self.assertNotEqual(core.sample(1, "ledger", 5, units=units),
                            core.sample(2, "ledger", 5, units=units))

    def test_next_id(self):
        self.assertEqual(core.next_id("LSN", FIX / "knowledge" / "rules"), "LSN-002")
        self.assertEqual(core.next_id("STD", FIX / "knowledge" / "rules"), "STD-001")

    def test_next_id_negative_bad_prefix(self):
        with self.assertRaises(core.GkError):
            core.next_id("ADR", FIX / "knowledge" / "rules")

    def test_boundary_safe(self):
        lines = SAMPLE_LINES
        self.assertEqual(core.unsafe_boundaries(lines, [(1, 7), (8, 16)]), [])

    def test_boundary_unsafe_mid_paragraph(self):
        lines = ["a paragraph line", "continues on the next line", "", "after"]
        self.assertEqual(core.unsafe_boundaries(lines, [(1, 1), (2, 4)]), [2])


class SchemaTests(unittest.TestCase):
    def test_x_required_if_duplicate(self):
        schema = core.load_schema("coverage.schema.json")
        bad = {"batch": "P1", "coverage": [{"src": "s", "lines": [1, 1], "skip": "duplicate"}]}
        errs = core.schema_validate(schema, bad)
        self.assertTrue(any("duplicate_of" in e for e in errs))

    def test_x_required_if_satisfied(self):
        schema = core.load_schema("coverage.schema.json")
        ok = {"batch": "P1", "coverage": [
            {"src": "s", "lines": [1, 1], "skip": "duplicate", "duplicate_of": "KU-P1-0001"}]}
        self.assertEqual(core.schema_validate(schema, ok), [])


class FateGraphTests(unittest.TestCase):
    """B1 — merge/supersede chains must terminate at a surviving unit; no cycles."""
    def u(self, uid, fate, tgt=None, notes=None):
        d = {"id": uid, "areas": ["memory"], "type": "RULE", "src": "a.md", "fate": fate}
        if tgt is not None:
            d["fate_target"] = tgt
        if notes is not None:
            d["notes"] = notes
        return d

    def test_merge_chain_to_keep_ok(self):
        units = [self.u("KU-A-0001", "merge", "KU-A-0002"),
                 self.u("KU-A-0002", "merge", "KU-A-0003"),
                 self.u("KU-A-0003", "keep")]
        self.assertEqual(core.check_fates(units), [])

    def test_negative_merge_cycle(self):
        units = [self.u("KU-A-0001", "merge", "KU-A-0002"),
                 self.u("KU-A-0002", "merge", "KU-A-0001")]
        errs = core.check_fates(units)
        self.assertTrue(any("cycle" in e.lower() for e in errs), errs)

    def test_negative_merge_self_cycle(self):
        units = [self.u("KU-A-0001", "merge", "KU-A-0001")]
        self.assertTrue(any("cycle" in e.lower() for e in core.check_fates(units)))

    def test_negative_merge_chain_ends_at_wrong(self):
        units = [self.u("KU-A-0001", "merge", "KU-A-0002"),
                 self.u("KU-A-0002", "wrong", notes="see conflicts.md#c1")]
        errs = core.check_fates(units)
        self.assertTrue(any("KU-A-0001" in e and "surviv" in e.lower() for e in errs), errs)

    def test_negative_merge_chain_ends_at_history(self):
        # a merge must land on a 'keep' survivor, not 'history'
        units = [self.u("KU-A-0001", "merge", "KU-A-0002"),
                 self.u("KU-A-0002", "history")]
        self.assertTrue(any("KU-A-0001" in e for e in core.check_fates(units)))

    def test_supersede_chain_to_history_ok(self):
        units = [self.u("KU-A-0001", "superseded", "KU-A-0002"),
                 self.u("KU-A-0002", "history")]
        self.assertEqual(core.check_fates(units), [])

    def test_supersede_to_adr_ok(self):
        units = [self.u("KU-A-0001", "superseded", "ADR-063")]
        self.assertEqual(core.check_fates(units), [])


class BatchesAllTests(unittest.TestCase):
    """M1 — gk batches check must enforce tiling + cap, not only boundaries."""
    inv = {"s.md": {"chars": 10, "lines": 5, "class": "extract"},
           "pic.png": {"chars": 0, "lines": 0, "class": "archive-only"}}
    blob = staticmethod(lambda _p: ["l1", "l2", "l3", "l4", "l5"])

    def test_valid_plan(self):
        batches = [{"id": "P1", "chars": 10, "entries": [("s.md", 1, 5, 10)]}]
        errs, stats = core.check_batches_all(self.inv, batches, 200000, blob_lines=self.blob)
        self.assertEqual(errs, [])
        self.assertEqual(stats["extract"], 1)

    def test_negative_overlap(self):
        batches = [{"id": "P1", "chars": 10, "entries": [("s.md", 1, 3, 6), ("s.md", 3, 5, 4)]}]
        errs, _ = core.check_batches_all(self.inv, batches, 200000, blob_lines=self.blob)
        self.assertTrue(any("gap/overlap" in e for e in errs), errs)

    def test_negative_gap(self):
        batches = [{"id": "P1", "chars": 6, "entries": [("s.md", 1, 3, 6)]}]
        errs, _ = core.check_batches_all(self.inv, batches, 200000, blob_lines=self.blob)
        self.assertTrue(any("covered to line" in e for e in errs), errs)

    def test_negative_over_cap(self):
        batches = [{"id": "P1", "chars": 10, "entries": [("s.md", 1, 5, 10)]}]
        errs, _ = core.check_batches_all(self.inv, batches, 5, blob_lines=self.blob)
        self.assertTrue(any("exceeds limit" in e for e in errs), errs)

    def test_negative_archive_in_batch(self):
        batches = [{"id": "P1", "chars": 10, "entries": [("s.md", 1, 5, 10), ("pic.png", 1, 1, 0)]}]
        errs, _ = core.check_batches_all(self.inv, batches, 200000, blob_lines=self.blob)
        self.assertTrue(any("archive-only" in e for e in errs), errs)


class StateFactTests(unittest.TestCase):
    """Two-tier state-fact check (review-3 redesign): exact state values + a few
    unambiguous strict forms are ERRORS (block); looser heuristics are WARNINGS
    (printed, never block). Tests target the pure ``core.state_fact_scan`` plus a
    couple of ``validate_store`` integrations."""
    STATE = {"v0.69.0", "1234"}          # mimics flattened state/current.yaml scalars

    def errs(self, text, state=()):
        return core.state_fact_scan(text, state)["errors"]

    def warns(self, text, state=()):
        return core.state_fact_scan(text, state)["warnings"]

    # --- positives: must NOT error (ordinary/procedural prose + allowed forms) ---
    def test_positive_prose_allowed(self):
        for t in ["run 2 of the pilot", "job 3", "run 3 times", "pipeline 2", "ci 3",
                  "gl 4", "step 13", "retry 3 times", "port 8760", "Phase 46",
                  "ADR-076", "HTTP 409", "Python 3.11", "pytest -q",
                  "pytest tests/test_x.py", "go test ./..."]:
            self.assertEqual(self.errs(t), [], f"should not error: {t!r}")

    def test_positive_parenthesised_md_link_url(self):
        self.assertEqual(self.errs("See [docs](https://e.com/p_(v2)/v1.2.3/g) now."), [])

    def test_positive_parenthesised_bare_url(self):
        self.assertEqual(self.errs("Fetch https://e.com/p_(v2)/v1.2.3/g here."), [])

    def test_positive_reference_style_link(self):
        self.assertEqual(self.errs("See notes[1].\n\n[1]: https://e.com/v1.2.3/notes"), [])

    def test_positive_code_span_identifier_allowed(self):
        self.assertEqual(self.errs("See `db_current_version` and `genesis v0.77.0` here."), [])

    # --- negatives: must ERROR (strict unambiguous forms) ---
    def test_error_repo_semver(self):
        self.assertTrue(self.errs("Requires genesis v0.77.0 to run."))

    def test_error_repo_semver_table_cell(self):
        self.assertTrue(self.errs("| current | genesis v0.77.0 |"))

    def test_error_db_v(self):
        self.assertTrue(self.errs("Requires DB v24 at least."))

    def test_error_db_current_version(self):
        self.assertTrue(self.errs("The db_current_version is bumped."))

    def test_error_hash_big_number(self):
        self.assertTrue(self.errs("Built in #7087827 today."))

    def test_error_pipeline_big(self):
        self.assertTrue(self.errs("From pipeline 7087827 here."))

    def test_error_ci_big(self):
        self.assertTrue(self.errs("See CI 7087827 for the run."))

    def test_error_job_big(self):
        self.assertTrue(self.errs("Logged under job 7087827 now."))

    def test_error_runner_counts(self):
        for t in ["pytest 1105", "vitest 332", "jest 332", "unittest 50"]:
            self.assertTrue(self.errs("The suite is " + t + " now."), t)

    def test_error_link_text_semver(self):
        self.assertTrue(self.errs("Read [genesis v0.77.0](https://e.com/guide) today."))

    def test_error_exact_state_value(self):
        self.assertTrue(self.errs("We are on v0.69.0 in production.", {"v0.69.0"}))

    # M1 — the repo+semver ERROR form accepts the common pin separators
    def test_error_repo_semver_separators(self):
        for t in ["genesis v0.77.0", "genesis@v0.77.0", "genesis==0.77.0",
                  "genesis-v0.77.0", "genesis/v0.77.0", "genesis:v0.77.0",
                  "kiro-agent-sdk@0.77.0", "genesis-workflows: v0.22.0"]:
            self.assertTrue(self.errs("Pin " + t + " here."), t)

    def test_error_repo_longest_name_wins(self):
        errs = self.errs("Uses genesis-workflows v0.22.0 now.")
        self.assertTrue(any("genesis-workflows" in e for e in errs), errs)
        self.assertFalse(any("repo version 'genesis v" in e for e in errs), errs)

    def test_positive_repo_name_alone_or_path(self):
        for t in ["genesis-core", "genesis ships a new loop",
                  "genesis/genesis/collab/service.py", "run genesis-core locally"]:
            self.assertEqual(self.errs(t), [], t)

    # P1 — pure integers are excluded from the exact tier (ports/lines/ids are prose)
    def test_load_state_values_excludes_integers(self):
        d = Path(tempfile.mkdtemp())
        try:
            f = d / "current.yaml"
            f.write_text("genesis_version: v0.69.0\ndb_current_version: 20\ntest_count: 1105\n")
            vals = core.load_state_values(f)
            self.assertIn("v0.69.0", vals)
            self.assertNotIn("1105", vals)
            self.assertNotIn("20", vals)
        finally:
            shutil.rmtree(d)

    def test_exact_tier_ignores_pure_integers(self):
        self.assertEqual(self.errs("Listens on port 1105 and line 1234.", {"1105", "1234"}), [])

    def test_integration_integer_state_value_not_blocked(self):
        k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", k)
        try:
            (k / "state" / "current.yaml").write_text("db_current_version: 1105\n")
            p = k / "areas" / "collaboration-hub" / "pack.md"
            p.write_text(p.read_text() + "\nListens on port 1105 here. <!-- src: KU-B99-0009 -->\n")
            self.assertEqual(core.validate_store(k), [])
        finally:
            shutil.rmtree(k.parent)

    # --- warnings: looser forms — never error, surface as warnings ---
    def test_warning_bare_semver(self):
        self.assertEqual(self.errs("Shipped in 0.69.0 recently."), [])
        self.assertTrue(self.warns("Shipped in 0.69.0 recently."))

    def test_warning_version_number(self):
        self.assertEqual(self.errs("Now at version 20 of the schema."), [])
        self.assertTrue(self.warns("Now at version 20 of the schema."))

    def test_warning_migration_in_prose(self):
        self.assertEqual(self.errs("Added in migration m0024 here."), [])
        self.assertTrue(self.warns("Added in migration m0024 here."))

    def test_warning_gitlab_id(self):
        self.assertEqual(self.errs("See job gl-9931 for logs."), [])
        self.assertTrue(self.warns("See job gl-9931 for logs."))

    def test_warning_bare_test_count(self):
        self.assertEqual(self.errs("There are 99 tests now."), [])
        self.assertTrue(self.warns("There are 99 tests now."))

    # --- integration through validate_store ---
    def test_integration_exact_value_errors(self):
        k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", k)
        try:
            p = k / "areas" / "collaboration-hub" / "pack.md"
            p.write_text(p.read_text() + "\nWe are on v0.69.0 here. <!-- src: KU-B99-0009 -->\n")
            errs = core.validate_store(k)
            self.assertTrue(any("outside state" in e for e in errs), errs)
        finally:
            shutil.rmtree(k.parent)

    def test_integration_warning_does_not_block(self):
        k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", k)
        try:
            p = k / "areas" / "collaboration-hub" / "pack.md"
            p.write_text(p.read_text() + "\nSome older 1.2.3 note here. <!-- src: KU-B99-0009 -->\n")
            warns = []
            errs = core.validate_store(k, warnings=warns)
            self.assertFalse(any("outside state" in e for e in errs), errs)
            self.assertTrue(any("1.2.3" in w for w in warns), warns)
        finally:
            shutil.rmtree(k.parent)

    def test_fixture_store_clean(self):
        k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", k)
        try:
            self.assertEqual(core.validate_store(k), [])
        finally:
            shutil.rmtree(k.parent)


class ContextCliTests(unittest.TestCase):
    """m1 — gk context validates the manifest against the schema."""
    def setUp(self):
        sys.path.insert(0, str(HERE.parent))
        import gk  # noqa
        self.gk = gk
        self.d = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.d)

    def _run(self, body):
        p = self.d / "sub.md"
        p.write_text(body)
        import argparse
        return self.gk.cmd_context(argparse.Namespace(subspec=str(p)))

    def test_valid_manifest(self):
        body = "# S\n\ncontext:\n  areas: [collaboration-hub, web-ui]\n  rules: [ADR-063]\n\n## x\n"
        self.assertEqual(self._run(body), 0)

    def test_negative_invalid_manifest(self):
        body = "# S\n\ncontext:\n  areas: [collab-hub]\n\n## x\n"   # bad enum id
        self.assertEqual(self._run(body), 1)


class ValidateAppliesToTests(unittest.TestCase):
    """P3 — validate fails on an applies_to glob matching no file in the repos."""
    def setUp(self):
        self.k = Path(tempfile.mkdtemp()) / "knowledge"
        shutil.copytree(FIX / "knowledge", self.k)

    def tearDown(self):
        shutil.rmtree(self.k.parent)

    def test_live_globs_ok(self):
        repo_files = {"genesis/genesis/collab/service.py"}
        self.assertEqual(core.validate_store(self.k, repo_files=repo_files), [])

    def test_negative_dead_glob(self):
        r = self.k / "rules" / "STD-010.md"
        r.write_text("---\nid: STD-010\nkind: standard\nstatus: accepted\n"
                     "areas: [collaboration-hub]\napplies_to: [\"genesis/genesis/ghost/**\"]\n"
                     "amends: null\nsuperseded_by: null\nverify: null\n---\nMUST: nothing.\n")
        repo_files = {"genesis/genesis/collab/service.py"}
        errs = core.validate_store(self.k, repo_files=repo_files)
        self.assertTrue(any("applies_to" in e and "no file" in e for e in errs), errs)


if __name__ == "__main__":
    unittest.main()

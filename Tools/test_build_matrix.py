"""Focused tests for Tools/build_matrix.py.

    python -m unittest discover -s Tools -p "test_*.py"

Two halves: the ruling-table parser against small synthetic tables (each malformed shape must
fail loudly, never produce a quiet matrix), and the real repository — the committed rulings
table, registry and suites — so the numbers the docs quote are asserted, not assumed.
"""

from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("build_matrix", TOOLS / "build_matrix.py")
bm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bm)

HEADING = bm.RULING_TABLE_HEADING


def _doc(*rows: str, header: str = "| # | Card | Status | Question to resolve |") -> str:
    return "\n".join(["# Rulings", "", HEADING, "", header, "|---|---|---|---|", *rows,
                      "", "## 5. Next section", "| R99 | `Not Parsed` | **OPEN** | x |"])


class ParseRulingTable(unittest.TestCase):

    def test_reads_status_and_id_per_card(self):
        got = bm.parse_ruling_table(_doc(
            "| R1 | `Alpha` | **OPEN** | q |",
            "| R2 | `Beta` | **CLOSED** | **CLOSED — see R9.** q |",
            "| R3 | `Gamma` | DECIDED | q |"))
        self.assertEqual(got, {"Alpha": ("R1", "OPEN"), "Beta": ("R2", "CLOSED"),
                               "Gamma": ("R3", "DECIDED")})

    def test_one_row_may_name_two_cards(self):
        got = bm.parse_ruling_table(_doc("| R4 | `Chain A` / `Chain B` | **CLOSED** | q |"))
        self.assertEqual(got, {"Chain A": ("R4", "CLOSED"), "Chain B": ("R4", "CLOSED")})

    def test_stops_at_the_next_section(self):
        got = bm.parse_ruling_table(_doc("| R1 | `Alpha` | **OPEN** | q |"))
        self.assertNotIn("Not Parsed", got)

    def test_a_later_table_in_the_same_section_is_not_read(self):
        doc = _doc("| R1 | `Alpha` | **OPEN** | q |").replace(
            "\n## 5.", "\nThe statuses:\n\n| Status | Meaning |\n|---|---|\n| **OPEN** | x |\n\n## 5.")
        self.assertEqual(bm.parse_ruling_table(doc), {"Alpha": ("R1", "OPEN")})

    def test_unknown_status_fails(self):
        with self.assertRaises(bm.RulingTableError):
            bm.parse_ruling_table(_doc("| R1 | `Alpha` | **PENDING** | q |"))

    def test_missing_status_column_fails(self):
        with self.assertRaises(bm.RulingTableError):
            bm.parse_ruling_table(_doc("| R1 | `Alpha` | q |",
                                       header="| # | Card | Question to resolve |"))

    def test_missing_heading_fails(self):
        with self.assertRaises(bm.RulingTableError):
            bm.parse_ruling_table("# nothing here\n| R1 | `Alpha` | **OPEN** | q |")

    def test_row_without_a_card_name_fails(self):
        with self.assertRaises(bm.RulingTableError):
            bm.parse_ruling_table(_doc("| R1 | Alpha | **OPEN** | q |"))

    def test_card_flagged_twice_fails(self):
        with self.assertRaises(bm.RulingTableError):
            bm.parse_ruling_table(_doc("| R1 | `Alpha` | **OPEN** | q |",
                                       "| R2 | `Alpha` | **CLOSED** | q |"))

    def test_a_flagged_card_outside_the_pool_fails(self):
        cards = [{"name": "Alpha", "text": "", "category": "Spell", "passcode": "1",
                  "decks": ["D1"], "copies_total": 1, "source_url": ""}]
        with self.assertRaises(bm.RulingTableError):
            bm.build_rows(cards, {}, {}, {"Ghost": ("R1", "OPEN")})


class TheRealRepository(unittest.TestCase):
    """The committed data. These numbers are the ones the docs quote."""

    @classmethod
    def setUpClass(cls):
        cls.cards = json.loads(bm.CARDS.read_text(encoding="utf-8"))["cards"]
        cls.rulings = bm.parse_ruling_table(bm.RULINGS.read_text(encoding="utf-8"))
        cls.rows = bm.build_rows(cls.cards, bm.registered_cards(), bm.tested_cards(),
                                 cls.rulings)
        cls.col = {h: i for i, h in enumerate(bm.HEADERS)}

    def _column(self, name):
        return [r[self.col[name]] for r in self.rows]

    def test_77_cards_all_implemented_and_tested(self):
        self.assertEqual(len(self.rows), 77)
        self.assertEqual(self._column("Implementation Status").count("IMPLEMENTED"), 77)
        self.assertEqual(self._column("Test Status").count("TESTED"), 77)

    def test_21_cards_carry_20_rulings(self):
        self.assertEqual(len(self.rulings), 21)
        self.assertEqual(len({rid for rid, _ in self.rulings.values()}), 20)

    def test_no_card_reads_pending_any_more(self):
        self.assertNotIn("PENDING", self._column("Ruling Verified"))

    def test_the_two_columns_agree(self):
        for needed, verified in zip(self._column("Special Ruling Needed"),
                                    self._column("Ruling Verified")):
            if needed == "NO":
                self.assertEqual(verified, bm.NO_RULING)
            else:
                self.assertIn(verified, bm.RULING_STATUSES)

    def test_only_r1_and_r2_are_open(self):
        open_ids = sorted({rid for rid, s in self.rulings.values() if s == "OPEN"})
        self.assertEqual(open_ids, ["R1", "R2"])

    def test_every_open_ruling_belongs_to_an_implemented_tested_card(self):
        by_name = {r[0]: r for r in self.rows}
        for name, (_, status) in self.rulings.items():
            if status == "OPEN":
                self.assertEqual(by_name[name][self.col["Implementation Status"]], "IMPLEMENTED")
                self.assertEqual(by_name[name][self.col["Test Status"]], "TESTED")


if __name__ == "__main__":
    unittest.main()

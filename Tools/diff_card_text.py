"""Compare official Konami card data against the locally saved card data.

Highlights every discrepancy so it can be resolved in favour of the official source
(master prompt section 4, step 3) and recorded in Research/CARD_RULINGS.md.

Usage:
    python Tools/diff_card_text.py
    python Tools/diff_card_text.py --full     # print full texts, not just flags
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GEN = PROJECT / "Data" / "generated"


def norm_text(s: str | None) -> str:
    if not s:
        return ""
    s = s.replace("’", "'").replace("‘", "'")
    s = s.replace("“", '"').replace("”", '"')
    s = s.replace("−", "-").replace("–", "-").replace("—", "-")
    s = re.sub(r"\s+", " ", s)
    return s.strip().lower()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--full", action="store_true")
    args = ap.parse_args()

    data = json.loads((GEN / "konami_cards.json").read_text(encoding="utf-8"))
    pool = json.loads((GEN / "card_pool.json").read_text(encoding="utf-8"))
    csv_by_name = {c["name"]: c for c in pool["unique_cards"]}

    diffs, name_diffs, type_diffs, empty = [], [], [], []

    for c in data["cards"]:
        csv_name = c["csv_name"]
        official_name = c.get("official_name") or ""
        src = csv_by_name.get(csv_name, {})

        if csv_name != official_name:
            name_diffs.append((csv_name, official_name))

        off = norm_text(c.get("card_text"))
        saved = norm_text(c.get("saved_desc"))
        if not off:
            empty.append(csv_name)
        elif off != saved:
            diffs.append((csv_name, saved, off))

        # card category cross-check (CSV "Category" vs official)
        species = c.get("species") or []
        icon = c.get("st_icon") or []
        csv_cat = (src.get("csv_category") or "").strip()
        if species:
            official_cat = "Monster"
        elif "Trap" in (c.get("spell_trap_kind") or "") or "Trap" in str(c.get("texts", {})):
            official_cat = None
        else:
            official_cat = None
        if official_cat and csv_cat and official_cat != csv_cat:
            type_diffs.append((csv_name, csv_cat, official_cat))

    print("=" * 78)
    print(f"OFFICIAL NAME DIFFERS FROM DECK CSV: {len(name_diffs)}")
    print("=" * 78)
    for a, b in name_diffs:
        print(f"  CSV '{a}'  ->  OFFICIAL '{b}'")

    print()
    print("=" * 78)
    print(f"EMPTY OFFICIAL TEXT (must be resolved): {len(empty)}")
    print("=" * 78)
    for n in empty:
        print("  ", n)

    print()
    print("=" * 78)
    print(f"CARD TEXT DIFFERS FROM SAVED official_card_data.json: {len(diffs)} / {len(data['cards'])}")
    print("=" * 78)
    for name, saved, off in diffs:
        print(f"\n### {name}")
        if args.full:
            print(f"  SAVED   : {saved or '(none)'}")
            print(f"  OFFICIAL: {off}")
        else:
            print(f"  SAVED   : {(saved or '(none)')[:150]}")
            print(f"  OFFICIAL: {off[:150]}")

    print()
    print("=" * 78)
    print("SUMMARY")
    print("=" * 78)
    print(f"  cards verified        : {len(data['cards'])}")
    print(f"  official name changes : {len(name_diffs)}")
    print(f"  text discrepancies    : {len(diffs)}")
    print(f"  empty official text   : {len(empty)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

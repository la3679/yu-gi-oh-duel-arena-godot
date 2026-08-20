"""Enumerate the unique playable card pool from the two finalized deck CSVs.

Authoritative input (READ-ONLY):
    PlayerFiles/Deck 1/Deck_1.csv
    PlayerFiles/Deck 2/Deck_2.csv
    PlayerFiles/Data/official_card_data.json   (passcode/identity starting point only)

This script never writes to PlayerFiles. Output goes to DuelArenaGame/Data/generated/.

Usage:
    python Tools/enumerate_cards.py
"""

from __future__ import annotations

import csv
import json
import os
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

# The physical-collection inputs live OUTSIDE this repository: they are the owner's private
# card inventory and are never committed. Default to the repository's parent directory (the
# layout this project was developed in) and let an environment variable override it, so this
# file carries no one's home directory.
PLAYERFILES = Path(os.environ.get("DUEL_ARENA_PLAYERFILES", PROJECT.parent))
OUT_DIR = PROJECT / "Data" / "generated"

DECKS = {
    "deck1": {
        "name": "Blue-Eyes Dragon Guard",
        "csv": PLAYERFILES / "Deck 1" / "Deck_1.csv",
        "images": PLAYERFILES / "Deck 1" / "Card Images",
    },
    "deck2": {
        "name": "Fairy-Tail Tribute Guard",
        "csv": PLAYERFILES / "Deck 2" / "Deck_2.csv",
        "images": PLAYERFILES / "Deck 2" / "Card Images",
    },
}


def load_deck(path: Path) -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as fh:
        return [row for row in csv.DictReader(fh) if (row.get("Card Name") or "").strip()]


def main() -> int:
    official = json.loads(
        (PLAYERFILES / "Data" / "official_card_data.json").read_text(encoding="utf-8")
    )

    decks_out: dict[str, dict] = {}
    unique: dict[str, dict] = {}
    problems: list[str] = []

    for key, meta in DECKS.items():
        rows = load_deck(meta["csv"])
        slots = 0
        entries = []
        for row in rows:
            name = row["Card Name"].strip()
            qty = int(row["Quantity"])
            slots += qty
            entries.append({"name": name, "quantity": qty})

            rec = official.get(name)
            if rec is None:
                problems.append(f"{meta['name']}: '{name}' missing from official_card_data.json")
                passcode = None
            else:
                passcode = rec.get("id")

            u = unique.setdefault(
                name,
                {
                    "name": name,
                    "passcode": passcode,
                    "decks": [],
                    "total_copies": 0,
                    "csv_category": row.get("Category", "").strip(),
                    "csv_card_type": row.get("Card Type", "").strip(),
                    "csv_race": row.get("Monster Type / Race", "").strip(),
                    "csv_attribute": row.get("Attribute", "").strip(),
                    "csv_level": row.get("Level / Rank", "").strip(),
                    "csv_atk": row.get("ATK", "").strip(),
                    "csv_def": row.get("DEF", "").strip(),
                    "saved_type": (rec or {}).get("type"),
                    "saved_human_type": (rec or {}).get("humanReadableCardType"),
                    "saved_desc": (rec or {}).get("desc"),
                    "source_images": [],
                },
            )
            u["decks"].append(meta["name"])
            u["total_copies"] += qty
            for fn in (row.get("Source Image Filename(s)") or "").split(";"):
                fn = fn.strip()
                if fn:
                    u["source_images"].append(fn)

        decks_out[key] = {
            "deck_name": meta["name"],
            "unique_names": len(entries),
            "main_deck_slots": slots,
            "cards": entries,
        }
        if slots != 40:
            problems.append(f"{meta['name']}: expected 40 Main Deck slots, found {slots}")

    total_slots = sum(d["main_deck_slots"] for d in decks_out.values())
    shared = sorted(n for n, u in unique.items() if len(set(u["decks"])) > 1)

    result = {
        "decks": decks_out,
        "total_playable_slots": total_slots,
        "unique_playable_cards": len(unique),
        "shared_between_decks": shared,
        "problems": problems,
        "unique_cards": [unique[k] for k in sorted(unique)],
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "card_pool.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print(f"Deck 1 slots : {decks_out['deck1']['main_deck_slots']} "
          f"({decks_out['deck1']['unique_names']} unique names)")
    print(f"Deck 2 slots : {decks_out['deck2']['main_deck_slots']} "
          f"({decks_out['deck2']['unique_names']} unique names)")
    print(f"Total slots  : {total_slots}")
    print(f"Unique cards : {len(unique)}")
    print(f"Shared       : {shared}")
    missing_pass = [u["name"] for u in unique.values() if not u["passcode"]]
    print(f"Missing passcode: {len(missing_pass)} {missing_pass}")
    if problems:
        print("\nPROBLEMS:")
        for p in problems:
            print("  -", p)
    print(f"\nWrote {OUT_DIR / 'card_pool.json'}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

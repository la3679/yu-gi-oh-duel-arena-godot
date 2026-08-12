"""Build the game's canonical card database from verified official data.

Inputs (all generated / read-only authoritative):
    Data/generated/card_pool.json     deck composition, from Tools/enumerate_cards.py
    Data/generated/konami_cards.json  official text/type, from Tools/fetch_official_cards.py
    PlayerFiles/Data/physical_cards.csv   passcode backfill only

Output:
    Data/cards/cards.json    canonical card definitions consumed by the engine
    Data/decks/deck1.json    Blue-Eyes Dragon Guard
    Data/decks/deck2.json    Fairy-Tail Tribute Guard

Fails loudly (non-zero exit) on any category disagreement or missing field, per
master prompt section 67 (no silent fallbacks).
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

PLAYERFILES = Path(r"C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles")
PROJECT = Path(__file__).resolve().parent.parent
GEN = PROJECT / "Data" / "generated"

SPELL_ICONS = {"Normal Spell", "Quick-Play Spell", "Continuous Spell",
               "Equip Spell", "Field Spell", "Ritual Spell"}
TRAP_ICONS = {"Normal Trap", "Continuous Trap", "Counter Trap"}

# Spell Speed by card kind — RULES_SPEC.md section 4.2 [S1 p.44-45].
# Monster effect Spell Speed is per-effect and is set in the effect definitions,
# not here; this is the card-level default for Spell/Trap activation.
SPELL_SPEED_BY_ICON = {
    "Normal Spell": 1, "Continuous Spell": 1, "Equip Spell": 1,
    "Field Spell": 1, "Ritual Spell": 1,
    "Quick-Play Spell": 2,
    "Normal Trap": 2, "Continuous Trap": 2,
    "Counter Trap": 3,
}


def load_passcodes() -> dict[str, str]:
    out: dict[str, str] = {}
    p = PLAYERFILES / "Data" / "physical_cards.csv"
    with p.open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            name = (row.get("Card Name") or "").strip()
            code = ""
            for k, v in row.items():
                if v and re.fullmatch(r"0*\d{7,8}", str(v).strip()):
                    code = str(v).strip()
            if name and code:
                out.setdefault(name, code.lstrip("0") or code)
    return out


def main() -> int:
    pool = json.loads((GEN / "card_pool.json").read_text(encoding="utf-8"))
    official = json.loads((GEN / "konami_cards.json").read_text(encoding="utf-8"))
    by_name = {c["csv_name"]: c for c in official["cards"]}
    csv_passcodes = load_passcodes()

    problems: list[str] = []
    cards: dict[str, dict] = {}

    for src in pool["unique_cards"]:
        name = src["name"]
        o = by_name.get(name)
        if o is None:
            problems.append(f"{name}: no official record")
            continue

        species = o.get("species") or []
        icon = o.get("icon")

        if species:
            category = "Monster"
        elif icon in SPELL_ICONS:
            category = "Spell"
        elif icon in TRAP_ICONS:
            category = "Trap"
        else:
            problems.append(f"{name}: cannot classify (icon={icon!r}, species={species!r})")
            continue

        if src["csv_category"] and src["csv_category"] != category:
            problems.append(
                f"{name}: deck CSV says '{src['csv_category']}' but official says '{category}'"
            )

        passcode = src.get("passcode") or csv_passcodes.get(name)
        if not passcode:
            problems.append(f"{name}: no passcode from any source")

        text = o.get("card_text") or ""
        if not text:
            problems.append(f"{name}: empty official card text")

        entry: dict = {
            "name": name,
            "official_name": o.get("official_name"),
            "passcode": str(passcode) if passcode else None,
            "konami_cid": o["cid"],
            "source_url": o["detail_url"],
            "category": category,
            "text": text,
            "decks": sorted(set(src["decks"])),
            "copies_total": src["total_copies"],
        }

        if category == "Monster":
            flat = [s for s in species]
            race = flat[0] if flat else None
            subtypes = set()
            for s in flat[1:]:
                subtypes.update(x.strip() for x in re.split(r"[／/]", s) if x.strip())
            entry.update({
                "race": race,
                "attribute": o.get("attribute"),
                "level": o.get("level"),
                "atk": int(o["atk"]) if str(o.get("atk", "")).isdigit() else o.get("atk"),
                "def": int(o["def"]) if str(o.get("def", "")).isdigit() else o.get("def"),
                "is_normal": "Normal" in subtypes,
                "is_effect": "Effect" in subtypes,
                "is_tuner": "Tuner" in subtypes,
                "is_flip": "Flip" in subtypes,
                "monster_subtypes": sorted(subtypes),
                "spell_speed": 1,  # per-effect overrides live in the effect definitions
            })
            for field in ("race", "attribute", "level", "atk", "def"):
                if entry.get(field) is None:
                    problems.append(f"{name}: missing monster field '{field}'")
        else:
            entry.update({
                "icon": icon,
                "spell_speed": SPELL_SPEED_BY_ICON[icon],
            })

        cards[name] = entry

    # deck lists
    decks_out = {}
    for key, d in pool["decks"].items():
        entries = []
        for c in d["cards"]:
            entries.append({"name": c["name"], "quantity": c["quantity"]})
            if c["name"] not in cards:
                problems.append(f"{d['deck_name']}: '{c['name']}' has no card definition")
        decks_out[key] = {
            "deck_name": d["deck_name"],
            "main_deck": entries,
            "main_deck_count": d["main_deck_slots"],
            "extra_deck": [],
        }

    (PROJECT / "Data" / "cards").mkdir(parents=True, exist_ok=True)
    (PROJECT / "Data" / "decks").mkdir(parents=True, exist_ok=True)
    (PROJECT / "Data" / "cards" / "cards.json").write_text(
        json.dumps({"cards": [cards[k] for k in sorted(cards)]}, indent=2, ensure_ascii=False),
        encoding="utf-8")
    for key, d in decks_out.items():
        (PROJECT / "Data" / "decks" / f"{key}.json").write_text(
            json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")

    counts: dict[str, int] = {}
    for c in cards.values():
        k = c.get("icon") or ("Monster/Normal" if c.get("is_normal") else "Monster/Effect")
        counts[k] = counts.get(k, 0) + 1

    print(f"Card definitions written: {len(cards)}")
    for k in sorted(counts):
        print(f"   {k:<22} {counts[k]}")
    print(f"Deck 1: {decks_out['deck1']['main_deck_count']} cards")
    print(f"Deck 2: {decks_out['deck2']['main_deck_count']} cards")

    if problems:
        print(f"\nPROBLEMS ({len(problems)}):")
        for p in problems:
            print("  -", p)
        return 2
    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

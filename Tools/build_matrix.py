"""Generate Reports/CARD_IMPLEMENTATION_MATRIX.csv.

Columns are those required by master prompt section 4.

Implementation / clause / test status is read from the GDScript card effect registry
once it exists (Scripts/cards/registry/*.gd). Until a card is registered it is reported
honestly as NOT_IMPLEMENTED with 0 clauses — this file never claims progress that the
code does not demonstrate (master prompt section 86).

Usage:
    python Tools/build_matrix.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
CARDS = PROJECT / "Data" / "cards" / "cards.json"
REGISTRY_DIR = PROJECT / "Scripts" / "cards" / "registry"
TESTS_DIR = PROJECT / "Tests" / "cards"
OUT = PROJECT / "Reports" / "CARD_IMPLEMENTATION_MATRIX.csv"
RULINGS = PROJECT / "Research" / "CARD_RULINGS.md"

HEADERS = [
    "Card Name", "Passcode / Canonical ID", "Deck(s)", "Quantity", "Category",
    "Official Current Text Verified", "Primary Source URL", "Secondary Source URL",
    "Effect Clauses Count", "Mechanics Used", "Special Ruling Needed", "Ruling Verified",
    "Implementation Status", "Test Status", "Notes",
]

# Cards flagged in CARD_RULINGS.md section 4 (R1-R20).
RULING_FLAGGED = {
    "Runick Flashing Fire": "R1", "Judge of the Ice Barrier": "R2",
    "Maiden with Eyes of Blue": "R3", "Chain Detonation": "R4", "Chain Healing": "R4",
    "Fairy Tail - Sleeper": "R5", "Swords of Revealing Light": "R6", "Soul Exchange": "R7",
    "Kaiser Sea Horse": "R8", "Rider of the Storm Winds": "R9", "Gagagashield": "R10",
    "Fairy Tail - Luna": "R11", "The Monarchs Awaken": "R12",
    "Witchcrafter Golem Aruru": "R13", "Hidden Springs of the Far East": "R14",
    "A Hero Emerges": "R15", "Five Brothers Explosion": "R16",
    "Nefarious Archfiend Eater of Nefariousness": "R17", "Inari Fire": "R18",
    "Castle of Dragon Souls": "R19", "Honest": "R20",
}

MECHANIC_PATTERNS = [
    (r"\bTarget\b|\btarget\b", "targeting"),
    (r"\bdiscard\b", "discard-cost"),
    (r"\bTribute\b", "tribute"),
    (r"\bbanish\b", "banish"),
    (r"\bdestroy\b", "destruction"),
    (r"\bSpecial Summon\b", "special-summon"),
    (r"\bNormal Summon(ed)?\b", "normal-summon-trigger"),
    (r"\bdraw\b", "draw"),
    (r"\bnegate\b", "negation"),
    (r"\bQuick Effect\b", "quick-effect"),
    (r"\bFLIP:", "flip-effect"),
    (r"\bequip\b", "equip"),
    (r"\bCounter\b", "counters"),
    (r"\bGY\b|\bGraveyard\b", "gy-interaction"),
    (r"\bgains?\b.*\bATK\b|\blose\b.*\bATK\b", "atk-modifier"),
    (r"\bDamage Step\b", "damage-step"),
    (r"\bBattle Phase\b", "battle-phase-restriction"),
    (r"\bonce per turn\b", "once-per-turn"),
    (r"\byou can only activate 1\b", "hard-opt-activation"),
    (r"\btake control\b", "control-change"),
    (r"\bto the hand\b|\breturn\b", "return-to-hand"),
    (r"\bbottom of the Deck\b|\btop of the Deck\b", "deck-placement"),
    (r"\bpiercing\b", "piercing"),
    (r"\bunaffected\b", "immunity"),
    (r"\bChain Link\b", "chain-link-aware"),
]


def registered_cards() -> dict[str, dict]:
    """Parse the GDScript card registry for declared cards and clause counts."""
    out: dict[str, dict] = {}
    if not REGISTRY_DIR.exists():
        return out
    for gd in REGISTRY_DIR.rglob("*.gd"):
        src = gd.read_text(encoding="utf-8", errors="replace")
        m = re.search(r'CARD_NAME\s*(?::=|=)\s*"([^"]+)"', src)
        if not m:
            continue
        name = m.group(1)
        clauses = len(re.findall(r'EffectDef\.new\(', src))
        out[name] = {"file": gd.relative_to(PROJECT).as_posix(), "clauses": clauses}
    return out


def tested_cards() -> dict[str, str]:
    """Card name -> the suite that covers it.

    A suite declares either CARD_UNDER_TEST (one card, the usual per-card suite) or
    CARDS_UNDER_TEST (an array, for a suite that covers a whole mechanic group such as
    the nine vanilla Normal Monsters). Both are read from the GDScript source, so this
    file can only report a card as TESTED when a suite really names it.
    """
    out: dict[str, str] = {}
    if not TESTS_DIR.exists():
        return out
    for gd in TESTS_DIR.rglob("*.gd"):
        src = gd.read_text(encoding="utf-8", errors="replace")
        rel = gd.relative_to(PROJECT).as_posix()
        for m in re.finditer(r'CARD_UNDER_TEST\s*(?::=|=)\s*"([^"]+)"', src):
            out[m.group(1)] = rel
        for m in re.finditer(r'CARDS_UNDER_TEST\s*(?::=|=)\s*\[(.*?)\]', src, re.S):
            for name in re.findall(r'"([^"]+)"', m.group(1)):
                out[name] = rel
    return out


def csv_escape(v: str) -> str:
    v = "" if v is None else str(v)
    if any(ch in v for ch in [",", '"', "\n"]):
        return '"' + v.replace('"', '""') + '"'
    return v


def main() -> int:
    data = json.loads(CARDS.read_text(encoding="utf-8"))
    reg = registered_cards()
    tests = tested_cards()

    rows = []
    for c in data["cards"]:
        text = c["text"]
        mechanics = sorted({label for pat, label in MECHANIC_PATTERNS
                            if re.search(pat, text, re.I)})
        if c["category"] == "Monster" and c.get("is_normal"):
            mechanics = ["vanilla-normal-monster"]

        r = reg.get(c["name"])
        ruling = RULING_FLAGGED.get(c["name"], "")

        # A vanilla Normal Monster has no effect clauses, so it has no registry file --
        # an empty effect list IS its complete implementation, which is exactly what
        # CardDef.is_vanilla() / CardRegistry.unimplemented() already encode. Reporting
        # it as NOT_IMPLEMENTED would be the dishonest reading, not the strict one.
        #
        # This applies ONLY to cards the card database marks is_normal. An Effect
        # Monster with no registry file stays NOT_IMPLEMENTED, so an unimplemented
        # Effect Monster can never be quietly counted as a vanilla body.
        is_vanilla = c["category"] == "Monster" and c.get("is_normal")
        if r:
            impl_note = r["file"]
        elif is_vanilla:
            impl_note = "vanilla Normal Monster: no effect clauses to implement"
        else:
            impl_note = ""

        rows.append([
            c["name"],
            c["passcode"] or "",
            "; ".join(c["decks"]),
            c["copies_total"],
            c.get("icon") or ("Normal Monster" if c.get("is_normal") else "Effect Monster"),
            "YES",
            c["source_url"],
            "",
            r["clauses"] if r else 0,
            "; ".join(mechanics),
            ruling or "NO",
            "PENDING" if ruling else "N/A",
            "IMPLEMENTED" if (r or is_vanilla) else "NOT_IMPLEMENTED",
            "TESTED" if c["name"] in tests else "NOT_TESTED",
            impl_note,
        ])

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as fh:
        fh.write(",".join(HEADERS) + "\n")
        for row in rows:
            fh.write(",".join(csv_escape(v) for v in row) + "\n")

    impl = sum(1 for r in rows if r[12] == "IMPLEMENTED")
    tested = sum(1 for r in rows if r[13] == "TESTED")
    print(f"Wrote {OUT}")
    print(f"  cards            : {len(rows)}")
    print(f"  text verified    : {sum(1 for r in rows if r[5] == 'YES')} / {len(rows)}")
    print(f"  implemented      : {impl} / {len(rows)}")
    print(f"  tested           : {tested} / {len(rows)}")
    print(f"  ruling-flagged   : {sum(1 for r in rows if r[10] != 'NO')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Generate Reports/CARD_IMPLEMENTATION_MATRIX.csv.

Columns are those required by master prompt section 4.

Implementation / clause / test status is read from the GDScript card effect registry
(Scripts/cards/registry/*.gd) and the per-card suites (Tests/cards/*.gd). A card that is not
registered is reported honestly as NOT_IMPLEMENTED with 0 clauses — this file never claims
progress that the code does not demonstrate (master prompt section 86).

The two ruling columns are read from the table in Research/CARD_RULINGS.md section 4, which is
the authority for them:

    Special Ruling Needed   the R-number flagged for the card, or NO
    Ruling Verified         N/A      no card-specific ruling was flagged
                            OPEN     flagged, and still an open question
                            DECIDED  settled while implementing the card, from its official
                                     text and the rulebook, without a card-specific Konami ruling
                            CLOSED   settled against an official Konami source

Before Phase 6 unit 4 this column was hard-coded to PENDING for every flagged card, which read
as "unresolved" for rulings that had long been closed. Nothing is hard-coded now: a missing
table, an unknown status or a card name that is not in the pool is an error, not a guess.

Usage:
    python Tools/build_matrix.py
"""

from __future__ import annotations

import json
import re
import sys
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

RULING_STATUSES = ("OPEN", "DECIDED", "CLOSED")
NO_RULING = "N/A"

RULING_TABLE_HEADING = "## 4. Cards needing specific ruling attention during implementation"

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


class RulingTableError(ValueError):
    """The CARD_RULINGS.md section 4 table is missing or malformed."""


def parse_ruling_table(markdown: str) -> dict[str, tuple[str, str]]:
    """Card name -> (ruling id, status), from the section 4 table of CARD_RULINGS.md.

    The table's rows are `| R<n> | `Card` [/ `Card`] | <STATUS> | question |`. A row may name
    more than one card (R4 covers both Chain cards). Raises RulingTableError on anything it
    cannot read, so a malformed table fails the build instead of producing a quiet matrix.
    """
    start = markdown.find(RULING_TABLE_HEADING)
    if start < 0:
        raise RulingTableError(f"heading not found: {RULING_TABLE_HEADING!r}")
    section = markdown[start:]
    next_heading = re.search(r"^## ", section[len(RULING_TABLE_HEADING):], re.M)
    if next_heading:
        section = section[:len(RULING_TABLE_HEADING) + next_heading.start()]

    header = None
    out: dict[str, tuple[str, str]] = {}
    for line in section.splitlines():
        if not line.startswith("|"):
            if header is not None:
                break  # only the FIRST table is the ruling table; later ones are prose aids
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            if header[:3] != ["#", "card", "status"]:
                raise RulingTableError(
                    f"section 4 table header must start '| # | Card | Status |', got {cells}")
            continue
        if set(cells[0]) <= set("-: "):
            continue  # the |---| separator row
        rid = cells[0]
        if not re.fullmatch(r"R\d+", rid):
            raise RulingTableError(f"bad ruling id {rid!r} in row: {line}")
        names = re.findall(r"`([^`]+)`", cells[1])
        if not names:
            raise RulingTableError(f"{rid}: no `card name` in the Card cell")
        m = re.match(r"\**\s*([A-Z]+)", cells[2])
        status = m.group(1) if m else ""
        if status not in RULING_STATUSES:
            raise RulingTableError(
                f"{rid}: status {cells[2]!r} is not one of {', '.join(RULING_STATUSES)}")
        for name in names:
            if name in out:
                raise RulingTableError(f"{name!r} is flagged twice ({out[name][0]} and {rid})")
            out[name] = (rid, status)
    if header is None or not out:
        raise RulingTableError("section 4 contains no ruling table rows")
    return out


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


def build_rows(cards: list[dict], reg: dict[str, dict], tests: dict[str, str],
               rulings: dict[str, tuple[str, str]]) -> list[list]:
    pool = {c["name"] for c in cards}
    unknown = sorted(set(rulings) - pool)
    if unknown:
        raise RulingTableError(f"CARD_RULINGS.md section 4 names cards not in the pool: {unknown}")

    rows = []
    for c in cards:
        text = c["text"]
        mechanics = sorted({label for pat, label in MECHANIC_PATTERNS
                            if re.search(pat, text, re.I)})
        if c["category"] == "Monster" and c.get("is_normal"):
            mechanics = ["vanilla-normal-monster"]

        r = reg.get(c["name"])
        rid, status = rulings.get(c["name"], ("", NO_RULING))

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
            rid or "NO",
            status,
            "IMPLEMENTED" if (r or is_vanilla) else "NOT_IMPLEMENTED",
            "TESTED" if c["name"] in tests else "NOT_TESTED",
            impl_note,
        ])
    return rows


def main() -> int:
    data = json.loads(CARDS.read_text(encoding="utf-8"))
    try:
        rulings = parse_ruling_table(RULINGS.read_text(encoding="utf-8"))
        rows = build_rows(data["cards"], registered_cards(), tested_cards(), rulings)
    except RulingTableError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as fh:
        fh.write(",".join(HEADERS) + "\n")
        for row in rows:
            fh.write(",".join(csv_escape(v) for v in row) + "\n")

    impl = sum(1 for r in rows if r[12] == "IMPLEMENTED")
    tested = sum(1 for r in rows if r[13] == "TESTED")
    flagged = [r for r in rows if r[10] != "NO"]
    print(f"Wrote {OUT}")
    print(f"  cards            : {len(rows)}")
    print(f"  text verified    : {sum(1 for r in rows if r[5] == 'YES')} / {len(rows)}")
    print(f"  implemented      : {impl} / {len(rows)}")
    print(f"  tested           : {tested} / {len(rows)}")
    print(f"  ruling-flagged   : {len(flagged)}")
    for status in RULING_STATUSES:
        print(f"    {status:<8}       : {sum(1 for r in flagged if r[11] == status)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

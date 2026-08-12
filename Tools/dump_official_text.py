"""Print the full verified official text of the playable card pool.

Usage:
    python Tools/dump_official_text.py                 # all
    python Tools/dump_official_text.py --start 0 --count 40
    python Tools/dump_official_text.py --kind monster  # monster|spell|trap
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GEN = PROJECT / "Data" / "generated"


def kind_of(c: dict) -> str:
    if c.get("species"):
        return "monster"
    txt = json.dumps(c.get("texts", {})) + json.dumps(c.get("st_icon", []))
    name_blob = (c.get("spell_trap_kind") or "")
    if "Trap" in name_blob:
        return "trap"
    if "Spell" in name_blob:
        return "spell"
    return "unknown"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--count", type=int, default=1000)
    ap.add_argument("--kind", default=None)
    args = ap.parse_args()

    data = json.loads((GEN / "konami_cards.json").read_text(encoding="utf-8"))
    cards = sorted(data["cards"], key=lambda c: c["csv_name"])
    if args.kind:
        cards = [c for c in cards if kind_of(c) == args.kind]
    cards = cards[args.start:args.start + args.count]

    for i, c in enumerate(cards, args.start + 1):
        sp = "/".join(c.get("species") or [])
        icon = "/".join(c.get("st_icon") or [])
        bits = []
        if c.get("attribute"):
            bits.append(c["attribute"])
        if c.get("level"):
            bits.append(f"Lv{c['level']}")
        if c.get("atk") is not None:
            bits.append(f"{c.get('atk')}/{c.get('def')}")
        if sp:
            bits.append(sp)
        if icon:
            bits.append(f"[{icon}]")
        if c.get("spell_trap_kind"):
            bits.append(c["spell_trap_kind"])
        head = f"{i}. {c['official_name']}  (cid {c['cid']}, pass {c.get('passcode')})"
        print(head)
        print(f"   {' | '.join(bits)}   decks={c.get('decks')} x{c.get('total_copies')}")
        for title, body in (c.get("texts") or {}).items():
            print(f"   [{title}] {body}")
        print()
    print(f"--- {len(cards)} cards shown ---")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

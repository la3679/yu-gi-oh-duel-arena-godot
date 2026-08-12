"""Verify current official card text for every unique playable card.

Source of authority: the official Konami Yu-Gi-Oh! Card Database (Neuron),
https://www.db.yugioh-card.com/yugiohdb/ — see Research/RULES_SOURCES.md S4.

Reads : Data/generated/card_pool.json   (produced by Tools/enumerate_cards.py)
Writes: Data/generated/konami_cards.json
        Data/generated/konami_raw/<cid>.html   (cached detail pages)

Access notes:
  * neither www.db.yugioh-card.com nor www.yugioh-card.com publishes a robots.txt
    restricting this path (both return 404 / no rules) — checked 2026-08-12.
  * one request per unique card plus one search, rate limited, cached on disk so
    re-runs do not re-request. No access controls, CAPTCHAs, or anti-bot measures
    are bypassed.

Usage:
    python Tools/fetch_official_cards.py
    python Tools/fetch_official_cards.py --refresh      # ignore cache
"""

from __future__ import annotations

import argparse
import html as htmllib
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GEN = PROJECT / "Data" / "generated"
RAW = GEN / "konami_raw"

BASE = "https://www.db.yugioh-card.com"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")
DELAY = 1.5  # seconds between live requests — deliberately polite

# Deck-CSV name -> exact official database name, where the CSV uses a variant.
# Only added after a failed exact match is manually confirmed against the DB.
NAME_OVERRIDES: dict[str, str] = {}


def fetch(url: str, cache: Path | None, refresh: bool = False) -> str:
    if cache and cache.exists() and not refresh:
        return cache.read_text(encoding="utf-8")
    req = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept-Language": "en-US,en;q=0.9"}
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        text = resp.read().decode("utf-8", "replace")
    if cache:
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(text, encoding="utf-8")
    time.sleep(DELAY)
    return text


def clean(s: str) -> str:
    s = re.sub(r"<[^>]+>", "", s)
    s = htmllib.unescape(s)
    s = s.replace(" ", " ")
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\n\s*\n+", "\n", s)
    return s.strip()


def norm(s: str) -> str:
    """Loose comparison key: lowercase alphanumerics only."""
    return re.sub(r"[^a-z0-9]", "", s.lower())


def search_cids(name: str, refresh: bool = False) -> list[tuple[str, str]]:
    """Return [(cid, official_name), ...] for a keyword search."""
    url = (f"{BASE}/yugiohdb/card_search.action?ope=1&sess=1&rp=100&page=1"
           f"&keyword={urllib.parse.quote(name)}&stype=1&request_locale=en")
    cache = RAW / f"search_{norm(name)}.html"
    page = fetch(url, cache, refresh)
    cids = re.findall(r'class="link_value"[^>]*value="[^"]*?cid=(\d+)"', page)
    names = [clean(m) for m in
             re.findall(r'<span class="card_name">\s*(.*?)\s*</span>', page, re.S)]
    return list(zip(cids, names))


def card_region(page: str) -> str:
    """Slice out only the card's own data block.

    The full detail page also contains a search-filter sidebar that reuses the same
    CSS classes (including an "Icon" item_box). Parsing the whole page therefore picks
    up filter-panel values instead of the card's real type. The card's own data starts
    at the `cardname` heading and ends at the language switcher.
    """
    start = page.find('class="sp cardname"')
    if start == -1:
        start = page.find("class=\"cardname\"")
    if start == -1:
        return page
    end = page.find('class="CardLanguage', start)
    if end == -1:
        end = page.find('<div class="bottom"', start)
    return page[start:end if end != -1 else start + 20000]


def parse_detail(page: str) -> dict:
    out: dict = {}

    m = re.search(r'<div class="(?:sp )?cardname">\s*<h1>\s*(.*?)\s*</h1>', page, re.S)
    out["official_name"] = clean(m.group(1)) if m else None

    page = card_region(page)

    # Attribute / Level / ATK / DEF / Rank / Icon live in item_box pairs
    for title, value in re.findall(
        r'<span class="item_box_title">\s*(.*?)\s*</span>\s*'
        r'<span class="item_box_value">\s*(.*?)\s*</span>', page, re.S
    ):
        t, v = clean(title), clean(value)
        if not v:
            continue
        if re.fullmatch(r"(DARK|EARTH|FIRE|LIGHT|WATER|WIND|DIVINE)", v):
            out["attribute"] = v
        elif v.startswith("Level "):
            out["level"] = int(v.split()[1])
        elif v.startswith("Rank "):
            out["rank"] = int(v.split()[1])
        elif t == "ATK":
            out["atk"] = v
        elif t == "DEF":
            out["def"] = v
        elif t == "Icon":
            # e.g. "Normal Trap", "Quick-Play Spell", "Continuous Trap", "Counter Trap",
            # "Equip Spell", "Field Spell", "Normal Spell", "Ritual Spell"
            out["icon"] = v

    m = re.search(r'<p class="species">(.*?)</p>', page, re.S)
    if m:
        parts = [clean(x) for x in re.findall(r"<span>(.*?)</span>", m.group(1), re.S)]
        parts = [p for p in parts if p and p not in ("／", "/")]
        out["species"] = parts

    # Text blocks: "Card Text", "Monster Effect", "Pendulum Effect"
    texts: dict[str, str] = {}
    for blk in re.findall(r'<div class="item_box_text">(.*?)</div>\s*</div>', page, re.S):
        tm = re.search(r'<div class="text_title">\s*(.*?)\s*</div>', blk, re.S)
        title = clean(tm.group(1)) if tm else "Card Text"
        body = clean(re.sub(r'<div class="text_title">.*?</div>', "", blk, flags=re.S))
        if body:
            texts[title] = body
    if not texts:
        for m in re.finditer(
            r'<div class="text_title">\s*(.*?)\s*</div>(.*?)(?=<div class="(?:text_title|item_box|CardText))',
            page, re.S,
        ):
            body = clean(m.group(2))
            if body:
                texts[clean(m.group(1))] = body
    out["texts"] = texts
    out["card_text"] = texts.get("Monster Effect") or texts.get("Card Text") or ""
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--refresh", action="store_true")
    args = ap.parse_args()

    pool = json.loads((GEN / "card_pool.json").read_text(encoding="utf-8"))
    cards = pool["unique_cards"]
    print(f"Verifying {len(cards)} unique cards against the official Konami database\n")

    results, unmatched = [], []
    for i, c in enumerate(cards, 1):
        csv_name = c["name"]
        query = NAME_OVERRIDES.get(csv_name, csv_name)
        try:
            hits = search_cids(query, args.refresh)
        except Exception as exc:  # noqa: BLE001
            print(f"[{i:2}/{len(cards)}] SEARCH FAIL {csv_name}: {exc}")
            unmatched.append({"name": csv_name, "reason": f"search error: {exc}"})
            continue

        target = norm(query)
        cid = next((cid for cid, nm in hits if norm(nm) == target), None)
        if cid is None:
            # tolerate punctuation/dash variants by containment
            cand = [(cid, nm) for cid, nm in hits
                    if target in norm(nm) or norm(nm) in target]
            if len(cand) == 1:
                cid, matched = cand[0]
                print(f"[{i:2}/{len(cards)}] ~ '{csv_name}' -> '{matched}'")
            else:
                print(f"[{i:2}/{len(cards)}] !! NO EXACT MATCH '{csv_name}' "
                      f"(hits: {[n for _, n in hits][:6]})")
                unmatched.append({"name": csv_name,
                                  "reason": "no exact match",
                                  "hits": [n for _, n in hits][:10]})
                continue

        try:
            detail = fetch(
                f"{BASE}/yugiohdb/card_search.action?ope=2&cid={cid}&request_locale=en",
                RAW / f"{cid}.html", args.refresh,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"[{i:2}/{len(cards)}] DETAIL FAIL {csv_name}: {exc}")
            unmatched.append({"name": csv_name, "reason": f"detail error: {exc}"})
            continue

        d = parse_detail(detail)
        d.update({
            "csv_name": csv_name,
            "cid": cid,
            "passcode": c.get("passcode"),
            "decks": c.get("decks"),
            "total_copies": c.get("total_copies"),
            "saved_desc": c.get("saved_desc"),
            "detail_url": f"{BASE}/yugiohdb/card_search.action?ope=2&cid={cid}&request_locale=en",
        })
        results.append(d)
        if not d.get("card_text"):
            print(f"[{i:2}/{len(cards)}] !! EMPTY TEXT {csv_name} (cid={cid})")
        else:
            print(f"[{i:2}/{len(cards)}] ok  {d['official_name']}  (cid={cid})")

    GEN.mkdir(parents=True, exist_ok=True)
    (GEN / "konami_cards.json").write_text(
        json.dumps({"cards": results, "unmatched": unmatched}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"\nVerified : {len(results)} / {len(cards)}")
    print(f"Unmatched: {len(unmatched)}")
    for u in unmatched:
        print("   -", u["name"], "|", u["reason"])
    print(f"Wrote {GEN / 'konami_cards.json'}")
    return 0 if not unmatched else 2


if __name__ == "__main__":
    sys.exit(main())

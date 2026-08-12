# RULES_SOURCES

Authoritative sources used to establish the rules implemented by the Duel Arena engine.

Policy (master prompt §3):
* Primary authority = official Konami sources.
* Yugipedia and other secondary sources may be used **only** where an official source
  does not provide the needed detail, and must be marked as SECONDARY.
* Master Duel is **never** a rules source — aesthetic inspiration only.
* Nothing in the engine may be implemented from memory alone.

All dates accessed: **2026-08-12**.

---

## S1 — Official Rulebook Version 10 (PRIMARY)

| Field | Value |
|---|---|
| Title | Yu-Gi-Oh! TRADING CARD GAME **OFFICIAL RULEBOOK Version 10** |
| Publisher | Konami Digital Entertainment / Yu-Gi-Oh! TCG official website |
| Linked from | https://www.yugioh-card.com/en/rulebook/ |
| URL | https://www.yugioh-card.com/en/downloads/rulebook/SD_RuleBook_EN_10.pdf |
| Resolved URL (302) | https://img.yugioh-card.com/en/downloads/rulebook/SD_RuleBook_EN_10.pdf |
| Local cached copy | `Research/sources/SD_RuleBook_EN_10.pdf` |
| Size | 3,415,528 bytes |
| SHA-256 | `82BE14641B2B7940467034A5B14B0D4037835831866537738D34FD9DF5A0F444` |
| Pages | 31 (PDF), rulebook-numbered to p.53 |
| Date accessed | 2026-08-12 |

**Rules established by this source**

| Rule | Rulebook page |
|---|---|
| Deck 40–60 cards; max 3 copies per name | 2 |
| Field zones: 5 Main Monster Zones, 5 Spell & Trap Zones, Field Zone, GY, Deck, Extra Deck, Extra Monster Zone | 4–5 |
| Effect Monster categories: Continuous / Ignition / Quick / Trigger (incl. Flip) | 8–10 |
| Quick Effects are Spell Speed 2; all other monster effects Spell Speed 1 | 10 |
| Flip Effects are a subset of Trigger Effects; activate when flipped face-up by Flip Summon, by attack, or by card effect | 10 |
| Normal Summon: face-up Attack Position, once per turn (Normal Summon **or** Set) | 24 |
| Normal Set: face-down Defense Position; **not** considered Summoned | 24 |
| Cannot play a monster from hand in face-up Defense Position | 24 |
| Tribute Summon: Level 5–6 → 1 Tribute; Level 7+ → 2 Tributes | 24–25 |
| Tribute Set is not a Summon | 25 |
| Flip Summon: face-down DEF → face-up **Attack** Position only; not the turn it was Set | 24 |
| Special Summon: player's choice of face-up ATK or face-up DEF unless specified | 24 |
| Spell types: Normal, Ritual, Continuous, Quick-Play, Equip, Field | 26–29 |
| Quick-Play Spell: any phase of your turn; opponent's turn only if Set first; **cannot activate the turn it was Set** | 28 |
| Equip Spell destroyed when equipped monster is destroyed, flipped face-down, or leaves the field | 28 |
| Field Spell: 1 per player; replacing sends the old one to GY | 29 |
| Trap types: Normal, Continuous, Counter | 30 |
| Traps must be Set first; **cannot activate the same turn they were Set** | 30 |
| Set Spells (non Quick-Play) may still be activated the turn they were Set, but only during your Main Phase | 31 |
| Starting LP = **8000**; starting hand = **5 cards** | 32–33 |
| Victory: opponent LP 0 / opponent cannot draw / card effect win; simultaneous 0 LP = draw | 33 |
| Turn structure: Draw → Standby → Main 1 → Battle → Main 2 → End | 34 |
| **Player going first does not draw on their first Draw Phase** | 35 |
| **Player going first cannot conduct a Battle Phase on their first turn** | 37 |
| Battle Position change restrictions (played this turn / attacked then MP2 / already changed this turn) | 36 |
| Battle Phase steps: Start Step → Battle Step → Damage Step → (repeat) → End Step | 37 |
| Attack declaration, direct attack when opponent has no monsters, 1 attack per face-up ATK monster | 38 |
| **Replay rules** — when the monsters the opponent controls change before the Damage Step | 39 |
| End Phase: resolve "during the End Phase" effects; **hand size limit 6** | 40 |
| **Damage Step activation restriction**: only Counter Traps, or cards whose effects directly change a monster's ATK or DEF, and only up until the start of damage calculation | 41 |
| Attacking a face-down monster: flip face-up during the Damage Step, then calculate | 41 |
| Flip effects on an attacked monster resolve **after damage calculation**; cannot target a monster already destroyed in damage calculation | 41 |
| Damage calculation ATK-vs-ATK and ATK-vs-DEF outcome table | 42–43 |
| Direct attack damage = attacker's full ATK | 43 |
| Chain definition and reverse-order resolution | 44 |
| Spell Speed 1 / 2 / 3 definitions and which card categories map to each | 44–45 |
| Response requires Spell Speed ≥ 2 and ≥ the Spell Speed of the previous Chain Link | 44 |
| Chain Link numbering and resolution order example | 46–47 |
| Turn player priority; priority passes after an activation and at the end of each phase/step | 48–49 |
| **Simultaneous Spell Speed 1 activations ordering**: turn player's mandatory (any order) → opponent's mandatory (any order) → turn player's optional (any order) → opponent's optional (any order) | 51 |
| Simultaneous resolution: turn player resolves/selects first | 51 |
| 0 ATK monsters cannot destroy by battle | 51 |
| Card effects take precedence over basic rules | 51 |
| **Actions that cannot be Chained to**: Summoning, Tributing, changing battle position, paying costs | 51 |
| "Leaves the field" semantics | 51 |
| Glossary — **Destroy** (battle or destruction effect only; returned/cost/Tribute is NOT destroyed) | 52 |
| Glossary — **Discard** (hand → GY) | 52 |
| Glossary — **Send to the Graveyard** (destroy, discard, Tribute all count; banished→GY does NOT) | 53 |
| Glossary — **Tribute** (not treated as destroyed; face-up or face-down allowed unless specified) | 53 |
| Glossary — **Set** | 53 |
| Glossary — **Battle / Battled** (must reach damage calculation to have "battled") | 52 |
| Glossary — **Control / Possess**; cards always return to the **owner's** GY/hand/Deck | 52 |
| Glossary — **Banished** (separated from the field, not the GY) | 52 |
| Glossary — **Colon (:) and semi-colon (;)** PSCT structure | 52 |
| Public knowledge: hand counts, Deck counts, GY contents, LP | 50 |

---

## S2 — Official Fast Effect Timing chart (PRIMARY)

| Field | Value |
|---|---|
| Title | **Fast Effect Timing** |
| Publisher | Konami — Yu-Gi-Oh! TCG official website |
| Page URL | https://www.yugioh-card.com/en/play/fast-effect-timing/ |
| Chart image URL | https://www.yugioh-card.com/en/wp-content/uploads/2021/05/T-Flowchart_EN-US.jpg |
| Local cached copy | `Research/sources/FastEffectTiming_Flowchart_EN-US.jpg` |
| Size | 201,965 bytes |
| SHA-256 | `B1F78848CAB3D0288C1BA645D749971752F3BF53D27C6185CA2E2FEBCCBDFF08` |
| Date accessed | 2026-08-12 |

**Rules established:** the complete turn-flow state machine (boxes A–E) governing when each
player may act, when a trigger-check occurs, when fast effects may be activated, when a Chain
is built, and how play returns to an open game state. Transcribed in full in
`RULES_SPEC.md §3`. This is the authority for §11 of the master prompt and **supersedes the
older "Ignition Effect priority" model**, which is not implemented.

---

## S3 — Official Damage Step Rules (PRIMARY)

| Field | Value |
|---|---|
| Title | **Damage Step Rules** |
| Publisher | Konami — Yu-Gi-Oh! TCG official website (EU region portal) |
| URL | https://www.yugioh-card.com/eu/play/damage-step-rules/ |
| Date accessed | 2026-08-12 |

Note: the `/en/gameplay/damage_step/` URL printed in Rulebook v10 p.41 now returns **HTTP 404**.
The equivalent live official document is the EU portal page above. Both are Konami-operated
official TCG sites, so this remains a PRIMARY source. Discrepancy recorded here for audit.

**Rules established:** the five Damage Step sub-steps and what may be activated in each —
transcribed in `RULES_SPEC.md §7`.

---

## S4 — Official Yu-Gi-Oh! Card Database (Neuron) (PRIMARY)

| Field | Value |
|---|---|
| Title | Yu-Gi-Oh! Neuron — TRADING CARD GAME CARD DATABASE |
| Publisher | Konami Digital Entertainment |
| URL | https://www.db.yugioh-card.com/yugiohdb/ |
| Card detail URL pattern | `card_search.action?ope=2&cid=<cid>&request_locale=en` |
| Reachability verified | 2026-08-12 — returned official card text for a known cid |

**Used to establish:** the current official English card text, card type, Attribute, Level,
ATK/DEF, and errata status for each of the 77 unique playable cards. Per-card citations are
recorded in `CARD_RULINGS.md` and `Reports/CARD_IMPLEMENTATION_MATRIX.csv`.

---

## Local pre-existing data (INPUT, NOT AUTHORITY)

`PlayerFiles/Data/official_card_data.json` (225 entries, YGOPRODeck-derived) is used **only**
as a starting point for passcode/identity lookup. Where it disagrees with S4, **S4 wins** and
the discrepancy is recorded in `CARD_RULINGS.md`.

Known discrepancy already found in Phase 0:
* `Vampiric Koala` (Deck 1) is absent from `official_card_data.json`; the file instead contains
  a key `Vampire Koala`. `PlayerFiles/Data/physical_cards.csv` and `YuGiOh_Card_Inventory.csv`
  both record the physical card as **Vampiric Koala, ORCS-EN093, passcode 01371589**.
  Canonical name to be confirmed against S4 in Phase 2.

---

## Sources explicitly NOT used as rules authority

* Yu-Gi-Oh! Master Duel (aesthetic inspiration only — master prompt §6)
* Reddit, forums, deck profiles, fan videos
* AI-generated rules summaries
* Yugipedia / Fandom wiki — permitted only as clearly-labelled SECONDARY fallback where no
  official source covers a detail. Any such use is marked `[SECONDARY]` at the point of use.

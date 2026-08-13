# CARD_RULINGS — card-specific research notes

Authority: the official Konami Yu-Gi-Oh! Card Database (`RULES_SOURCES.md` S4).
Every one of the **77** unique playable cards was fetched individually and its current
official English text recorded. Per-card detail URLs are stored in
`Data/generated/konami_cards.json` and in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`.

Cached raw evidence: `Data/generated/konami_raw/<cid>.html` (one file per card).

---

## 1. Verification result

| Measure | Value |
|---|---|
| Unique playable cards | 77 |
| Verified against official database | **77 / 77** |
| Unmatched / ambiguous | 0 |
| Empty official text | 0 |
| Official name differs from deck CSV name | 0 |
| Category (Monster/Spell/Trap) disagreements with deck CSVs | **0** |

Composition of the verified pool:

| Kind | Count |
|---|---|
| Monster — Normal | 9 |
| Monster — Effect | 28 |
| Normal Spell | 13 |
| Quick-Play Spell | 3 |
| Continuous Spell | 1 |
| Field Spell | 1 |
| Normal Trap | 15 |
| Continuous Trap | 6 |
| Counter Trap | 1 |
| **Total** | **77** |

---

## 2. Data discrepancies resolved in favour of the official source

The locally saved `PlayerFiles/Data/official_card_data.json` (YGOPRODeck-derived) disagreed
with the official Konami database for **23 of 77** cards. All were resolved in favour of the
official source (master prompt §4 step 3). Most are terminology modernisation, but several are
**substantive errata that change gameplay** and are called out below.

### 2.1 Substantive — MUST be implemented per the official text

| Card | Saved text (superseded) | Official current text | Why it matters |
|---|---|---|---|
| **Straight Flush** | "Activate only when all of your opponent's Spell & Trap Card Zones are occupied. Destroy all cards in your opponent's Spell & Trap Card Zones." | "If your opponent controls a card in each of their Spell & Trap Zones: Destroy all cards in their Spell & Trap Zones." | Converted to PSCT. The condition is now a **PSCT activation condition** ("If … :"), not a legacy "Activate only when" timing restriction. Implemented as a condition check at activation. |
| **Aussa the Earth Charmer** | "FLIP: While this card is face-up on the field, take control of 1 EARTH monster your opponent controls." | "FLIP: **Target** 1 EARTH monster your opponent controls; take control of that monster while this card is face-up on the field." | Now **targets**. Target is locked at activation; target legality must be checked. Interacts with Fairy Tail - Rella's anti-targeting effect. |
| **Wynn the Wind Charmer** | (same non-targeting legacy wording) | "FLIP: **Target** 1 WIND monster your opponent controls; take control of that monster while this card is face-up on the field." | Same as Aussa. |
| **Eria the Water Charmer** | "FLIP: Target 1 **face-up** WATER monster …" | "FLIP: Target 1 WATER monster your opponent controls; take control of that monster while this card is face-up on the field." | The word "face-up" is **not** in the current text. All three Charmers now share identical wording modulo Attribute — they are implemented from one shared primitive. |
| **Apprentice Magician** | second clause "If this card is …" | "**When** this card is destroyed by battle: You can Special Summon 1 Level 2 or lower Spellcaster monster from your Deck in face-down Defense Position." | "When" vs "If" affects missing-the-timing behaviour. |
| **Champion's Vigilance** | "when a monster would be Summoned" | "when a **monster(s)** would be Summoned OR a Spell/Trap Card is activated" | Must handle simultaneous multi-monster summons. |
| **Birthright** | "Special Summon that target in **face-up** Attack Position" | "Special Summon that target in Attack Position" | Position wording normalised. |
| **Shining Angel** | "… from your Deck, in **face-up** Attack Position" | "… from your Deck in Attack Position" | Same. |
| **Hieratic Dragon of Tefnuit** | "This card cannot attack during the turn it is Special Summoned." | "**Cannot attack during the turn it is Special Summoned this way.**" | The restriction applies **only** when Special Summoned by its own effect, not by any other means (e.g. not when revived by Monster Reborn). |

### 2.2 Non-substantive terminology updates (official text still used verbatim)

"Graveyard" → "GY"; "Spellcaster-Type" → "Spellcaster"; "Spell Card" → "Spell";
bullet spacing in `Enemy Controller`, `Kunai with Chain`, `Runick Flashing Fire`;
`Spiritual Wind Art - Miyabi` "that card" → "that opponent's card";
`Damage Condenser`, `Kaiser Glider`, `Chiron the Mage`, `Fairy Tail - Sleeper`,
`Hidden Springs of the Far East`, `Inari Fire`, `Nefarious Archfiend Eater of Nefariousness`,
`A Hero Emerges`, `Spiritual Water Art - Aoi`.

### 2.3 `Vampiric Koala`

`official_card_data.json` had **no** entry for this card; it contained an unrelated key
`Vampire Koala`. The physical inventory records **Vampiric Koala, ORCS-EN093, passcode
01371589**. The official database confirms the card exists under the exact name
**Vampiric Koala** (cid 8858, EARTH / Level 4 / Beast / Effect / 1800 / 1500):

> "If this card inflicts battle damage to your opponent by battle with a monster: Gain LP
> equal to the battle damage inflicted."

Canonical name = **Vampiric Koala**. Passcode backfilled from `physical_cards.csv`.

### 2.4 `Phoenix Wing Wind Blast` — card type confirmed

This card is commonly assumed to be a Quick-Play Spell. The **official database records it as
a Normal Trap** (cid 6279), and both independent local sources agree: `Deck_2.csv` classifies
it as `Trap`, and the physical-card identification recorded it as a Trap. Three sources agree,
so it is implemented as a **Normal Trap (Spell Speed 2)**, subject to the Trap Set-turn rule.

This was found only because an initial parse of the official page accidentally read the
search-filter sidebar rather than the card's own data block; the parser now slices the card
region explicitly (`Tools/fetch_official_cards.py::card_region`) and every card type was
re-derived from the authoritative `Icon` field.

---

## 3. Mechanics the V1 card pool actually requires

Derived from the verified text of all 77 cards. This list supersedes the provisional
assumption in `RULES_SPEC.md §14` that counters would not be needed.

| Mechanic | Required by |
|---|---|
| **Counters** — Spell Counter | `Apprentice Magician` |
| **Counters** — Balloon Counter | `Wonder Balloons` |
| Equip Spell / equipped-card system | `Kunai with Chain` (Trap that equips), `Gagagashield` (Trap that equips), `Rider of the Storm Winds` (monster that equips itself), `Fairy Tail - Rella` (equips an Equip Spell) |
| Piercing battle damage | `Rider of the Storm Winds` |
| Destruction **replacement** ("destroy this card instead") | `Rider of the Storm Winds` |
| Destruction **prevention** ("cannot be destroyed", limited uses) | `Gagagashield` (twice per turn), `Kaiser Glider` (same-ATK battle) |
| Control change (continuous, tied to a source staying face-up) | `Aussa`, `Eria`, `Wynn` |
| Control change (until End Phase) | `Enemy Controller` |
| Temporary banish and return | `Interdimensional Matter Transporter` |
| Banish as cost | `Castle of Dragon Souls`, `Judge of the Ice Barrier`, `Junk Blader` |
| Excavate (look at top N, not a draw) | `Crystal Seer` |
| Place card on **top** of Deck | `Phoenix Wing Wind Blast` |
| Place card on **bottom** of Deck | `Spiritual Wind Art - Miyabi`, `Crystal Seer` |
| Shuffle into Deck | `Chain Detonation`, `Chain Healing`, `Judge of the Ice Barrier` |
| Return to hand | `Compulsory Evacuation Device`, `Kaiser Glider`, `A Wingbeat of Giant Dragon`, `Fairy Tail - Luna`, `Witchcrafter Golem Aruru`, `Honest`, `Fairy Tail - Rella` |
| Negate Summon | `Champion's Vigilance` |
| Negate activation + destroy | `Champion's Vigilance` |
| Negate monster effects continuously | `Fiendish Chain`, `The Monarchs Awaken` |
| "Unaffected by effects" | `The Monarchs Awaken` |
| Attack negation | `Maiden with Eyes of Blue` |
| Attack prevention (continuous) | `Swords of Revealing Light` |
| Trap activation lock during Battle Phase | `Mirage Dragon` |
| Targeting protection / redirect | `Fairy Tail - Rella` |
| **Chain-Link-position-aware effects** | `Chain Detonation`, `Chain Healing` (behave differently at CL2–3 vs CL4+) |
| Effect **replacement** of an opponent's activated effect | `Fairy Tail - Sleeper` |
| Deck search / Deck Special Summon | `Dragon Shrine`, `Dragonic Tactics`, `Damage Condenser`, `Shining Angel`, `Apprentice Magician`, `The White Stone of Legend`, `Fairy Tail - Luna`, `One for One` |
| Random selection from hand by the opponent | `A Hero Emerges` |
| Look at opponent's hand | `Spiritual Water Art - Aoi` |
| Skip next Battle Phase | `Runick Flashing Fire` |
| Cannot conduct Battle Phase this turn | `Soul Exchange` |
| Tribute substitution ("counts as 2 Tributes") | `Kaiser Sea Horse` |
| Forced Tribute target | `Soul Exchange` |
| Turn-counting continuous effect | `Swords of Revealing Light` (destroy during the End Phase of the opponent's 3rd turn) |
| Trap that becomes a Normal Monster | `The Phantom Knights of Shadow Veil` |
| Set ATK/DEF to a value | `Hieratic Dragon of Tefnuit` (make ATK/DEF 0) |
| GY-activated effects | `Judge of the Ice Barrier`, `Nefarious Archfiend Eater of Nefariousness`, `Inari Fire`, `The Phantom Knights of Shadow Veil`, `Castle of Dragon Souls` |

**Still not used by the V1 pool** (remain out of scope per master prompt §50):
Link, Pendulum, Xyz, Synchro, Fusion, Ritual Summoning; Extra Deck play; Tokens.

---

## 4. Cards needing specific ruling attention during implementation

These are recorded now and each must be resolved before its implementation is marked complete
in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`. **No effect may be approximated.**

| # | Card | Question to resolve |
|---|---|---|
| R1 | `Runick Flashing Fire` | Second bullet Special Summons a "Runick" monster **from the Extra Deck**. Both decks have an empty Extra Deck, so that branch can never have a legal target. It must still be implemented and must correctly report "no legal choice" rather than being omitted. Also: "skip your next Battle Phase" applies **on activation**, even if the chosen effect is later negated. |
| R2 | `Judge of the Ice Barrier` | All three effects reference "Ice Barrier" monsters. Judge is the only "Ice Barrier" card in either deck, so the first (continuous) and third (GY) effects can essentially never be live. Both must still be implemented exactly. Confirm whether Judge in the **GY** counts for "If you control an 'Ice Barrier' monster" — it does not (GY is not "control"). |
| R3 | `Maiden with Eyes of Blue` | "You can only use 1 'Maiden with Eyes of Blue' effect per turn, and only once that turn." — a combined restriction across **both** effects, per player, per name. |
| R4 | `Chain Detonation` / `Chain Healing` | Behaviour depends on the **Chain Link number at which the card was activated**. Chain Link position must be recorded on the Chain Link and readable at resolution. |
| R5 | `Fairy Tail - Sleeper` | "the activated effect **becomes** …" — this replaces the opponent's already-activated Normal Spell/Trap effect on the Chain. Needs an effect-substitution mechanism on the Chain Link, not a negate-then-add. |
| R6 | `Swords of Revealing Light` | "you must destroy it during the End Phase of your opponent's 3rd turn" — requires a per-card turn counter. Confirm exactly which End Phase counts as the 3rd. |
| R7 | `Soul Exchange` | "this turn, if you Tribute a monster, you must Tribute that target, as if you controlled it" — a forced-Tribute lingering restriction, plus "cannot conduct your Battle Phase". |
| R8 | `Kaiser Sea Horse` | "can be treated as 2 Tributes for the Tribute Summon of a LIGHT monster" — modifies the Tribute requirement computation. |
| R9 | `Rider of the Storm Winds` | Equips **itself** from hand or field; grants piercing; is a destruction **replacement** effect for the equipped monster. Also interacts with the rule that Equip Cards are destroyed when the equipped monster leaves the field. |
| R10 | `Gagagashield` | "Twice per turn, it cannot be destroyed by battle or card effects" — a counted prevention effect, resetting each turn. |
| R11 | `Fairy Tail - Luna` | Opponent may send a card with the targeted monster's name from Deck/Extra Deck to the GY **to negate this effect** — an opponent-side decision **during resolution**. |
| R12 | `The Monarchs Awaken` | "If you have no cards in your Extra Deck" is an activation condition; grants "unaffected by the effects of cards other than this card" — a broad immunity that must be applied in the rules layer. |
| R13 | `Witchcrafter Golem Aruru` | Trigger condition covers both "targets a Spellcaster monster(s) you control" and "targets it for an attack". No "Witchcrafter" Spells exist in the deck, so only the "1 card your opponent controls" branch is ever live. |
| R14 | `Hidden Springs of the Far East` | Field Spell whose once-per-turn effect may be activated by **the turn player**, i.e. by either player depending on whose turn it is, including the opponent of its controller. |
| R15 | `A Hero Emerges` | Opponent chooses a **random** card from your hand — must use the seeded deterministic RNG and must not leak hand contents. |
| R16 | `Five Brothers Explosion` | Second effect triggers only when the face-up card **you control** is sent to **your** GY **by your opponent's card effect** — a precise movement-reason + agent check. |
| R17 | `Nefarious Archfiend Eater of Nefariousness` | GY effect during the **opponent's** End Phase; destroys your own face-up monster as part of the effect ("destroy it, and if you do, Special Summon this card"). |
| R18 | `Inari Fire` | Revives itself "during your next Standby Phase after this face-up card on the field was destroyed by card effect and sent to the GY" — a delayed trigger with a specific destruction reason. |
| R19 | `Castle of Dragon Souls` | ATK boost persists "even if this card leaves the field"; second effect triggers when the face-up card **is sent to the GY** (any reason). |
| R20 | `Honest` | Quick Effect explicitly legal **during the Damage Step** ("During the Damage Step, when a LIGHT monster you control battles"). Confirms the need for the `UNTIL_DAMAGE_CALC` permission class in `RULES_SPEC.md §7.2` — it directly changes ATK. |

Resolution status for R1–R20 is tracked in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`
(`Special Ruling Needed` / `Ruling Verified` columns). Any question that cannot be settled from
an official source will be escalated rather than guessed (master prompt §86).

---

## 4A. Rulings decided during implementation

Recorded as each card was written, so a later session does not re-litigate them. Each entry
says what was decided, on what basis, and how confident that basis is.

### R16 — `Five Brothers Explosion`: does a face-down Set card count as "a Continuous Spell/Trap Card you control"?

**DECIDED: no — FACE-UP cards only.**

Basis: a face-down Set Spell/Trap Card has not been activated, applies none of its text, and
its *specific subtype* is not a property either player may act on. This is the same principle
that keeps a clause worded "1 Effect Monster on the field" (`Fiendish Chain`) from reaching a
face-down monster. The card's own first clause counts **itself**, because activating a
Spell/Trap is what places it face-up on the field [S1 p.28–30], and by the time the activation
resolves it is already there.

Confidence: the *general* face-down principle is well established; a card-specific Konami Q&A
for this card could **not** be retrieved — `db.yugioh-card.com/yugiohdb/faq_search.action`
redirects to the database homepage from this environment, and no unofficial source was accepted
in its place. The decision is therefore reasoned from the official rulebook rather than quoted
from a per-card ruling, and it is stated here rather than hidden. It is implemented in one
place (`EffectPrimitives.continuous_spell_traps_controlled()`) and tested in both directions
(`FiveBrothersExplosionTests :: a SET Continuous Trap is not counted`, which also carries the
positive control of the same card counting once it is face-up), so revisiting it is a one-line
change plus a test flip.

The second clause's counterpart question does not arise: "each Continuous Spell/Trap Card **in
your Graveyard**" needs no visibility filter, because every card in a Graveyard is public.

### R19 — `Castle of Dragon Souls`: does a face-down Set copy count for "You can only control 1"?

**DECIDED: no for a Spell/Trap; yes for a monster.** The limit is re-tested at the moment a
Spell/Trap is **activated**, which is when a second copy would actually reach the field face-up.

Basis: the alternative reading makes the restriction incoherent for a Trap — holding two Set
copies would forbid activating **either** of them, and the card would become unplayable the
moment a second copy was drawn. A face-down *monster*, by contrast, occupies a Monster Zone and
is unambiguously a monster you control, which is why `Inari Fire` and `Ranryu` are correctly
blocked by a Set copy and that behaviour is unchanged.

Both halves live in one place (`EffectPrimitives.controls_no_other_copy()`), and the enforcement
point for a Spell/Trap is `ActivationRules.can_activate()` — before this batch, **no route
checked the limit for a Spell/Trap at all**, which is recorded as an engine defect in
`Reports/TEST_RESULTS.md`.

### R19 (second part) — the ATK gain that outlives its source

"It gains 700 ATK until the end of this turn **(even if this card leaves the field)**" is
implemented as a turn-scoped modifier (`"end_of_turn"`), **not** as a continuous effect. A
continuous effect is state-derived and vanishes the moment its source stops applying, which is
precisely what the parenthesis forbids. `TurnFlow._end_of_turn_cleanup()` removes it from every
instance at the turn transition, whoever's turn it was.

---

## 5. Banlist note (master prompt §51)

These are fixed casual decks built from an owned physical collection. Current Forbidden/Limited
status is **not** enforced and must not block a duel from starting. No deck list is altered.

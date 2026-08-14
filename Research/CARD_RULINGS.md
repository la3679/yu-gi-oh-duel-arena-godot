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

### R4 — CLOSED (Phase 5 batch 7 unit C): the Chain Link number is read from the Chain Link

`Chain Detonation` and `Chain Healing` behave differently depending on the Chain Link position
they were **activated** at. The §4 flag asked for that position to be recorded on the Chain Link
and readable at resolution; it now is, and both cards read it.

`ChainLink.link_number` is 1-based authoritative state written when the link is created, and both
cards reach it through one shared primitive, `EffectPrimitives.activated_chain_link_number()`.
**Counting the chain array at resolution would give a different and wrong answer**, because a
Chain resolves in reverse: by the time Chain Link 2 resolves, Chain Link 3 above it has already
resolved. `ChainDetonationTests :: the branch is chosen from the ACTIVATION position recorded on
the Chain Link` builds exactly that three-link Chain and pins the difference down.

Two consequences of the printed text, both asserted on each card: **Chain Link 1 takes neither
conditional half** (the damage / LP gain still happens, and the Trap goes to the Graveyard the
ordinary way), and **"Chain Link 4 or higher" is open-ended** (Chain Link 5 behaves like 4).

Confidence: **HIGH** — this is the cards' own printed text, verified against the official
database, not an inference.

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

### R21 — `Apprentice Magician`: what is "a card you can place a Spell Counter on"?

**DECIDED: a card has that property only because some card TEXT grants it.** It is a property of
the TARGET, not of `Apprentice Magician`, and it is not "any face-up card".

Basis: the official text is "Target 1 face-up card on the field **that you can place a Spell
Counter on**". The qualifier would be meaningless under the wide reading, and the wide reading
would let the card put a Spell Counter on a `Blue-Eyes White Dragon`, which is not how Spell
Counters work — a card holds counters because a card allows it.

Implementation: `GameState.COUNTER_CAPACITY_EFFECT_ID`, a CONTINUOUS rules-query clause a card
declares about itself, asked through `GameState.can_place_counter()`. Deliberately NOT enforced
inside `place_counters()`: a clause that places a counter on one specific named card does so on
its own authority, which is exactly what `Wonder Balloons` already does.

**Consequence, reported rather than hidden: no card in the V1 pool declares Spell Counter
capacity**, so this clause has no legal target in a real duel between these two Decks and is
never activated. It is implemented in full and tested against a synthetic card that does declare
the capacity — the same treatment R1 requires for `Runick Flashing Fire`'s unreachable Extra
Deck branch.

Confidence: high on the reading. The pool consequence is a measured fact, asserted by
`ApprenticeMagicianTests :: NO card in the 77-card V1 pool declares Spell Counter capacity`.

### R22 — `Kunai with Chain`: does changing the ATTACKING monster to Defense Position stop the attack?

**DECIDED: no.** The attack continues, and damage calculation uses the attacking monster's ATK.

Basis: `RULES_SPEC.md §6.2` and §7.4 [S1 p.39, p.42]. An attack is cancelled only when the
ATTACKER leaves the field, and a Replay happens only when the set of monsters the opponent
controls changes; a battle position change is neither. The rulebook's damage-calculation table
is written as the attacker's ATK against the target's ATK or DEF, and the attacker's own battle
position is not an input to any of its six rows.

Also decided: the change is by a CARD EFFECT, so it neither spends nor is blocked by the
once-per-turn manual position-change allowance [S1 p.26], and it applies to a monster that has
already attacked.

Confidence: **medium-high.** It follows from rules this project has already implemented and
tested, not from a Konami ruling naming this card. It is isolated in one primitive and covered by
`KunaiWithChainTests :: the attacking monster is changed to Defense Position and the attack
CONTINUES`. Re-verify if a directly authoritative source becomes available.

### R23 — `Fairy Tail - Rella`: targeting protection, NOT a redirect

**DECIDED: the first clause is a flat CONTINUOUS restriction. There is no redirect mechanic.**

Basis: the verified official text is "Neither player can target monsters on the field with Spell
Cards or effects, except this one." The previous checkpoint's batch plan described this card as
needing "targeting protection / **redirect**"; the official text contains no redirect and **the
official text wins**. No redirect mechanic was invented.

Four things the wording fixes: it binds **both** players, including Rella's own controller; it
covers monsters **on the field** only, so "target 1 monster in either GY" is untouched; Rella
herself remains targetable; and it is about **Spell Cards and effects**, not attacks — an attack
is neither, and `BattleRules` builds its own target list [S1 p.38].

Implementation: the pre-existing `cannot_be_targeted` flag, which `ContinuousEffects` already
owned but which **nothing consumed**. It is now read once, in `ActivationRules.legal_targets()`,
the single funnel every candidate list passes through.

Also decided: the second clause cannot be activated with no Equip Spell in the hand, Deck or GY,
following the reading already applied to `Shining Angel`, `Kaibaman` and `Dragonic Tactics`.
**The V1 pool contains no Equip Spells at all**, so that clause is never live in a real duel; it
is implemented in full and tested against synthetic Equip Spells.

Confidence: high on the text; medium-high on the "cannot activate with nothing to fetch" reading,
which is consistent with three cards already shipped.

### R24 — `Champion's Vigilance`: two response categories, and the Flip Summon gap

**DECIDED: the one printed clause is two EffectDefs**, because it has two disjoint activation
timings resolved through two different engine paths. Negating a **Summon** answers a declaration
that is not on the Chain (`Zone.IN_TRANSIT` + `DuelEngine.negate_pending_summon()`); negating a
**Spell/Trap activation** answers a real Chain Link (`ChainManager.negate_activation()`). An
activated effect that WOULD Special Summon is the second case, never the first — when the
negation is activated, that effect has not resolved and no Summon has been declared.

Also decided: "a Spell/Trap **Card** is activated" is narrower than "an effect is activated" and
does not cover a monster's Ignition or Quick Effect, nor the activation of an effect of a
Continuous Spell/Trap already face-up on the field. "Negate the **activation**" does not refund a
cost the negated card already paid (`RULES_SPEC.md §10`). The field condition requires a
**face-up** monster, on the same reasoning as `controls_face_up_monster_of_race()`.

**The Flip Summon gap is CLOSED (batch 6).** It was recorded here at the batch-5 checkpoint as
a KNOWN GAP: a **Flip Summon is a Summon** [S1 p.24] and this card should be able to negate one,
but `SummonRules.flip_summon()` applied the flip immediately instead of splitting into
begin/complete like the other two routes, so no declaration window opened. That was an ENGINE
limitation, not a card one, and batch 6 fixed it generically rather than inside this card.

The fix is deliberately **not** the Normal/Special Summon mechanism reused unchanged. A Flip
Summon's monster does not move: it waits face-down in the Monster Zone it already occupies for
the whole declaration window, because entering `Zone.IN_TRANSIT` would be a departure from the
field and would destroy its Equip Cards and clear its per-instance state. Consequences, all
tested:

* a negated Flip Summon leaves the monster **face-down** — the position change WAS the Summon;
* **no** `FLIP_SUMMON_SUCCEEDED` event, so no successful-summon trigger is collected;
* **no Flip effect**, because a Flip effect keys on being flipped face-up and the monster never
  was (`AussaTheEarthCharmerTests :: a NEGATED Flip Summon never triggers it`);
* the Normal Summon allowance and the once-per-turn manual position change are both untouched.

"Is a Summon pending?" therefore stopped being answerable by scanning `in_transit`, which covers
only two of the three routes, and moved to `GameState.pending_summon_card_id`.
`ChampionsVigilanceTests :: it negates a Flip Summon` replaces the old KNOWN GAP test, with
`:: left unanswered, the same Flip Summon completes normally` as its positive control.

"monster(s)": the plural exists because one Summon can place several monsters at once. Nothing in
the V1 pool does, so there is one pending Summon record and negating it negates the whole Summon.
Not exercised beyond that, and said so.

### R25 — `Enemy Controller`: when exactly does "until the End Phase" end?

**DECIDED: control returns as the End Phase is ENTERED**, before anything else happens in it.

The official text gives a duration ("take control of that target until the End Phase") but not an
instant, and this engine's End Phase is deliberately **two steps** — the first performs the
hand-size discard, which happens at the *end* of the End Phase [S1 p.40], and the second ends the
turn (`PROJECT_STATE.md` design decision 3). A duration worded "until the End Phase" runs up TO
that phase, so it expires the moment the phase begins; anything later would let a borrowed monster
be Tributed for, or discarded to, an effect during a phase the card says the loan is already over.
Implemented in `TurnFlow.enter_phase()` and asserted against the event sequence numbers, not
merely against the final state (`EnemyControllerTests :: control expires as the End Phase is
ENTERED`).

**Confidence: reasonable, not certain.** No single official sentence names the instant, which is
recorded here rather than dressed up. What IS certain and is what the test pins down: it lasts the
whole of the controlling player's turn through Main Phase 2, and it is gone before the next turn.

Two further decisions on the same card:

* **"Tribute 1 monster" is a COST**, paid at activation and never refunded. Negate the activation
  afterwards and the Tribute stays paid. With no monster to Tribute the second bullet is not
  offered at all — a cost that cannot be paid blocks the ACTIVATION, it does not merely make the
  effect do nothing. The first bullet is unaffected, because the two bullets are independent
  activations of the same card ("Activate 1 of these effects").
* **Neither bullet is legal in the Damage Step.** [S1 p.41] permits only Counter Traps, effects
  that negate, and effects that directly change ATK/DEF. A battle position change is none of
  those, however tempting the timing looks. `RULES_SPEC.md §7.2`.
* The first bullet's position change is **by effect**, so it does not spend the monster's
  once-per-turn manual battle position change and is not subject to the three manual-change
  restrictions [S1 p.36] — those govern what a PLAYER may do in their Main Phase.

### R26 — the three Charmers share one implementation, and that is not over-generalisation

`Aussa the Earth Charmer`, `Eria the Water Charmer` and `Wynn the Wind Charmer` carry the current
official text **word for word apart from the Attribute** (§2.1), so the mechanics live in one
primitive, `EffectPrimitives.charmer_take_control()`. Each card still declares its own name,
Attribute and quoted text, and each has its own suite; if any one of them is errata'd apart from
the others it stops calling the primitive and writes its own clause.
`WynnTheWindCharmerTests :: the three Charmers are three cards` asserts on a real board that the
three Attribute filters genuinely differ, so the sharing cannot quietly collapse them into one.

**On Eria specifically:** the older printing said "1 **face-up** WATER monster" and the current
official text does not. Dropping the word changed nothing about what can be taken — a face-down
monster's Attribute is not a property either player may act on, so it cannot satisfy "1 WATER
monster" — and that is asserted in both directions rather than assumed
(`EriaTheWaterCharmerTests :: face-down is still not a target`). The restriction now comes from
the Attribute requirement instead of from a printed word.

**On the duration:** "while this card is face-up on the field" is a condition on the CHARMER, not
on the borrowed monster. Flip the Charmer face-down or remove it and control returns immediately;
turning the *borrowed* monster face-down changes nothing.

### R27 — `A Wingbeat of Giant Dragon`: the return is the EFFECT, and it gates activation

**Decided (Phase 5 batch 7).** Three separate questions, two settled from published rulings and
one reasoned.

1. **Cost or effect?** — **EFFECT.** The current PSCT text has neither a colon nor a semicolon
   ("Return 1 Level 5 or higher Dragon-Type monster you control to the hand, and if you do,
   destroy all Spell and Trap Cards on the field"), so everything in it happens at RESOLUTION,
   and the published rulings state directly that returning the monster is not a cost.
   *Confidence: HIGH.* Observable: the Dragon is still on the field while the Chain is being
   built, so a Chain Link 2 that removes it changes what this card does.
2. **Does it target?** — **NO.** The word "target" does not appear, and the rulings say so
   explicitly. The Dragon is chosen at resolution from whatever is legal then.
   *Confidence: HIGH.*
3. **Can it be activated with no Level 5 or higher Dragon?** — implemented as **NO**.
   *Confidence: MEDIUM.* No ruling was found stating it in those words. The reasoning is that
   the first action is mandatory and definite and "and if you do" makes every remaining word
   depend on it, so with no Dragon the card can do nothing whatever; the published rulings
   confirm the dependency direction (a chosen monster that fails to reach the hand — a Fusion
   Monster that goes to the Extra Deck instead, or one unaffected by Spell Cards — does **not**
   trigger the destruction). If this is ever shown to be wrong, the fix is to delete the
   clause's `condition`; nothing else depends on it.

*Sources:* Yugipedia / Yu-Gi-Oh! Wiki card-rulings pages for `A Wingbeat of Giant Dragon`
(community transcriptions of Konami rulings, **not** an S1–S4 official source — recorded here
with that caveat rather than presented as official). Consulted 2026-08-13.
*Tests:* `AWingbeatOfGiantDragonTests` — the clause shape, the resolution-time choice, the
"no return means no destruction" branch, and both negative candidate directions.

### R28 — a card that destroys "all Spell and Trap Cards on the field" does not destroy itself

**Decided (Phase 5 batch 7). Confidence: MEDIUM.**

`A Wingbeat of Giant Dragon` is a Normal Spell, and a Normal Spell is face-up **on the field**
while it resolves — the engine only moves it to the Graveyard afterwards, with
`MoveReason.RESOLVED_TO_GY`. So "destroy all Spell and Trap Cards on the field" raises the
question of whether it destroys itself.

Implemented as **NO**. Two reasons:

* The published rulings for `Heavy Storm`, whose effect is worded identically ("Destroy all
  Spell and Trap Cards on the field"), state that it does not destroy itself.
* Those same rulings state that `Heavy Storm` cannot be activated with no **other** card to
  destroy — which is only coherent if the card does not count itself. That internal consistency
  is the stronger half of the argument.

The difference is observable (`last_move_reason` becomes `DESTROYED_BY_EFFECT` instead of
`RESOLVED_TO_GY`, and a `CARD_DESTROYED` event appears), so it is asserted rather than assumed:
`AWingbeatOfGiantDragonTests :: it does not destroy itself`.

*Source:* community transcriptions of the `Heavy Storm` rulings, **not** an S1–S4 official
source. Consulted 2026-08-13. Recorded honestly as reasoned-from-precedent.

### R29 — "1 card your opponent controls" is re-checked for CONTROL at resolution

**Decided (Phase 5 batch 7 unit C). Confidence: MEDIUM.**

`Phoenix Wing Wind Blast` and `Spiritual Wind Art - Miyabi` both target "1 card **your opponent
controls**". If control of the target changes between activation and resolution — the V1 pool can
do this with `Enemy Controller` and the three Charmers — is the target still legal?

Implemented as **NO: the effect does not apply to it.** The reasoning, stated in order of
strength:

* **Miyabi's own resolution clause names it.** Its current official text is "place **that
  opponent's card** on the bottom of the Deck" (the older printing said "that card"; the
  discrepancy is recorded in §2.1 above and resolved in favour of the official source). The
  resolution sentence itself says whose card it must be, so for this card the re-check is
  textual and not merely inferred. This half is **HIGH** confidence.
* **The general targeting rule.** A target is chosen at activation and must still be a legal
  target when the effect resolves; one that no longer is, is not affected. `Phoenix Wing Wind
  Blast`'s resolution clause says only "place **that target** on the top of the Deck", so it
  rests on this general rule rather than on its own wording. This half is **MEDIUM**: no single
  S1–S4 sentence states the rule in the form "a targeting condition is re-evaluated at
  resolution", and the engine's own prior convention (`EffectPrimitives.surviving_target()`,
  design decision 16) had only ever re-checked the target's ZONE.
* **Uniformity.** The two cards publish the same candidate set with the same wording, so reading
  the clause one way on one card and the other way on the other would be worse than either
  reading applied consistently.

**What is NOT part of this ruling:** ownership. Control is what the text names, so a card the
effect's controller OWNS but the opponent CONTROLS remains a legal target, and a card the
opponent owns but the controller has borrowed does not. Both directions are asserted.

Implemented once, generically, as `EffectPrimitives.surviving_opponent_field_target()` — built on
`surviving_field_target()`, which is the other thing these two cards needed and the movement gate
did not have: "1 **card**" reaches a monster, a Set or face-up Spell/Trap and a Field Spell alike,
so the zone re-check has to be "still on the field" rather than "still in the Monster Zone".

*Source:* reasoned from the cards' own current official text (S-quality for the Miyabi half) plus
the general targeting rule as the engine already applies it. **Not** a quoted Konami ruling on
either card. Consulted 2026-08-13.
*Tests:* `MovementTests :: an opponent field target is re-checked for control` (generic, both
directions including the ownership mirror), plus
`PhoenixWingWindBlastTests :: a target that changed control` and
`SpiritualWindArtMiyabiTests :: a target that changed control`. A later correction therefore
fails loudly rather than drifting.

---

## 5. Banlist note (master prompt §51)

These are fixed casual decks built from an owned physical collection. Current Forbidden/Limited
status is **not** enforced and must not block a duel from starting. No deck list is altered.

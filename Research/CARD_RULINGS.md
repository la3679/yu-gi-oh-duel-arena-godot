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
| R6 | `Swords of Revealing Light` | **CLOSED — see R36.** "you must destroy it during the End Phase of your opponent's 3rd turn" — requires a per-card turn counter. The three counted turns are the opponent's three turns after activation, and the card is destroyed in the End Phase of the third; the controller's own turns never count, because a Normal Spell is only ever activated on its controller's turn [S1 p.31]. |
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

### R30 — what a TEMPORARY banishment returns, and under whose control

**Decided (Phase 5 batch 8 unit A). Confidence: MEDIUM overall; the parts differ and are
separated below.**

`Interdimensional Matter Transporter` — "Target 1 face-up monster you control; banish that target
until the End Phase" — is the V1 pool's only card with a stated return timing, and its text says
nothing about *how* the monster comes back. Four sub-questions had to be answered before the
generic `GameState.banish_leases` subsystem could be written. Each is recorded with its own
evidence quality rather than being folded into one confidence rating.

**(a) The return is NOT a Summon. Confidence: HIGH.** The card says "banish … until the End
Phase", not "Special Summon it". Nothing in [S1 p.31-33] makes a card re-entering the field a
Summon unless an effect Summons it, and PSCT is explicit whenever a Summon is meant. Consequences,
all asserted: no `NORMAL_SUMMON_SUCCEEDED` / `SPECIAL_SUMMON_SUCCEEDED` / `FLIP_SUMMON_SUCCEEDED`
/ `CARD_FLIPPED_FACE_UP` event is emitted, `pending_summon_card_id` is never set so a
Summon-negating card (`Champion's Vigilance`) has nothing to answer, and
`properly_special_summoned` is not set. Implemented as its own
`Enums.MoveReason.RETURNED_FROM_BANISHMENT`.

**(b) It returns in the battle position it left in. Confidence: MEDIUM.** No S1–S4 sentence states
this, and the card does not. It is implemented this way because the alternative — picking a
default position — would be an unstated choice the card never authorises, and because the lease
can simply record what was true. The position is captured **before** the move, since `move_card()`
normalises a banished card's position and the answer is unrecoverable afterwards. In practice the
card can only target a face-up monster, so only the two face-up positions are live; the face-down
case is covered generically anyway.

**(c) It returns under its OWNER's control, not under the control of whoever held it when it was
banished. Confidence: MEDIUM, reasoned rather than quoted.** This is *not* a special rule for
banishing — it falls out of two things the engine already does and R29 already relies on:
leaving the field ends every control lease on a card (`drop_control_leases_for()` inside
`move_card()`, RULES_SPEC.md §5.6), and the Banished zone is owner-bound like every other
non-field zone [S1 p.52]. After both, nothing remains that says any non-owner controls the card,
so there is nothing to restore. Ownership is never mutated at any point in the cycle. Asserted in
both directions: a borrowed monster banished temporarily comes back to its owner's Monster Zone,
and its `owner_id` is unchanged throughout.

**(d) If the return destination is full, the card stays banished. Confidence: MEDIUM.** The
owner's Monster Zones can fill while the card is away. The card then simply cannot come back; the
lease is discharged all the same so the return is not retried forever, and the failure is emitted
as a `CARD_RETURNED_FROM_BANISHMENT` event carrying `returned: false, no_free_zone: true`. This is
deliberately the identical shape `end_control_lease()` already uses when control cannot revert
because the original controller's field is full — one precedent, applied twice, rather than two
inconsistent answers to the same question.

**Timing.** "Until the End Phase" is the same moment R25 already fixed for
`Enemy Controller`'s control lease: the **entry** to the End Phase, before the hand-size discard.
The two expiries are called side by side in `TurnFlow.enter_phase()` precisely so they cannot
drift apart, control first (see the code comment there for why the order is fixed).

**(e) Known limitation, recorded rather than hidden: a card banished by an effect activated
DURING the End Phase does not come back until the NEXT turn's End Phase.** Expiry runs as the
phase is entered, so an activation later in the same phase has already missed it.
`Interdimensional Matter Transporter` is a Normal Trap and can be activated in the End Phase, so
this is reachable, and the real-world answer is probably that it should return during that same
End Phase. It is left as it is on purpose: `Enemy Controller`'s "until the End Phase" control
lease has exactly the same behaviour for exactly the same reason, R25 fixed that moment
deliberately, and making banishment differ from control would break the one invariant this
subsystem is built around. **Changing it must change both together**, and must revisit R25 —
it is not a banish-only fix. Recorded in `Reports/TEST_RESULTS.md` under not-yet-covered.

*Source:* the card's own current official text plus the general rules the engine already applies;
reasoned, **not** a quoted Konami ruling on this card. Consulted 2026-08-13.
*Tests:* `BanishTests` — the return timing, "the return is not a Summon", the position, the
owner's control, the full-zone case, the never-twice case and the stateless-return case are each
their own test — plus `InterdimensionalMatterTransporterTests` on the printed card. A later
correction therefore fails loudly rather than drifting.

---

### R31 — paying LIFE POINTS as an activation cost, and how "paid LP" is identified

**Decided (Phase 5 batch 8, the LP-cost unit). Confidence: the two parts differ and are
separated below.**

Required by `Judge of the Ice Barrier`'s first clause: "each time your opponent activates a
card or effect **by paying LP**, they lose 500 LP". Nothing in the V1 pool pays LP as a cost, so
neither the payment nor the observation existed in the engine before this batch.

**Part A — what counts as "paid LP". Confidence: HIGH.**
"Paid LP" is a property of an **activation**, never of an LP delta. The engine records the
payment on the activation's own cost payload (`EffectPrimitives.LP_COST_KEY`), which the
existing pipeline already copies into both the `COST_PAID` event and the `ChainLink`. A clause
asking "was this activated by paying LP?" reads that payload and nothing else. Consequently
**none** of the following counts, and each is asserted in both directions in
`LifePointCostTests` and again on the printed card in `JudgeOfTheIceBarrierTests`: effect
damage · battle damage · an arbitrary LP loss written by a resolving effect · an LP reduction
caused by another card resolving · **LP gain** · an activation whose cost is not LP. This part
is not a judgement call — it is what the wording says, and inferring a payment from a falling
LP total would be a straightforward misreading.

**Part B — affordability, and the exactly-zero edge. Confidence: LOW-MEDIUM on the edge,
HIGH on the rest.**
The uncontested rule: *"If paying LP is a requirement to activate a card or effect and the
player cannot, that card or effect cannot be activated."* The engine enforces that in
`EffectPrimitives.can_pay_life_points_cost()`, which is the **only** place the question is
answered.

The contested edge is paying LP **exactly equal** to your remaining LP. The sources disagree by
region: the OCG allows it (the player pays and loses the Duel), while the TCG is reported not to
allow a payment that would immediately lose the Duel. The project's primary rules source is the
TCG rulebook [S1], so the engine takes the **TCG reading — the payer must be left with at least
1 LP** — implemented as a strict inequality. **This is honestly weak evidence:** the OCG half is
documented on Yugipedia, the TCG half is attributed there to forum discussion rather than to a
quoted Konami ruling, and no official TCG text stating it was found.

It is isolated in one function precisely so a correction is a one-line change plus its test.
**Nothing in the V1 pool can reach this edge**, because no printed card pays LP at all, so the
decision affects no real duel. If stronger evidence appears, change
`can_pay_life_points_cost()` and the three assertions in `LifePointCostTests`
`_test_affordability_gates_the_activation`.

*Source:* Yugipedia, "Pay" and "Paying Life Point costs" (community wiki, consulted 2026-08-14);
the TCG/OCG split and the "cannot activate if you cannot pay" rule both come from there.
**Community source, not an official Konami ruling** — recorded as such rather than dressed up.
*Tests:* `LifePointCostTests` (109) is the generic gate; `JudgeOfTheIceBarrierTests` (154)
exercises the printed consumer.

---

### R32 — "skip your next Battle Phase": WHICH Battle Phase, and when it is spent

`Runick Flashing Fire` prints "Activate 1 of these effects, **but skip your next Battle Phase
after activation**". **R1** already fixes the part that matters most — the restriction applies
**on activation, even if the chosen effect is later negated** — and that half is official and
unchanged. R32 records the two questions R1 leaves open, because the implementation cannot avoid
answering them.

**Part A — which Battle Phase is "your next" one. Confidence: MEDIUM-HIGH.**
Decided at the moment the obligation is taken on, from turn state rather than guessed later:

| Activated… | Battle Phase it takes |
|---|---|
| in your own Main Phase 1, before your Battle Phase | **this turn's** |
| in your own Battle Phase or Main Phase 2 | a **later** turn's — you cannot skip one you are already conducting or have already had |
| during the opponent's turn (it is a Quick-Play at Spell Speed 2) | **your next turn's** |

`GameState.battle_phase_conducted_this_turn` is what separates rows 1 and 2, and it is already
authoritative state written by `TurnFlow.enter_phase()`. This reading is the plain one and needs
no special pleading; it is not marked HIGH only because no *official* Konami ruling was consulted
for the mid-Battle-Phase case.

**Part B — a turn that could not have had a Battle Phase does not spend the obligation.
Confidence: MEDIUM.**
The player who goes first cannot conduct a Battle Phase on their first turn [S1 p.37]. If that
player activates this card on turn 1, there is no Battle Phase there to skip, so the obligation is
**not** consumed and carries to the next turn that really offers one. The alternative reading —
that the obligation evaporates against a turn which never had a Battle Phase — would make
activating the card on your first turn **free**, which is the opposite of what the text is for.
The obligation is therefore spent only by a turn in which the player was the turn player *and*
was not barred by the turn-1 rule.

**Part C — two obligations cost two Battle Phases. Confidence: LOW-MEDIUM, and NEVER LIVE.**
Modelled as a counted list rather than a boolean, which is the strictly more general shape. It
**cannot occur in the physical pool**: there is one copy of `Runick Flashing Fire`, it is a
Quick-Play Spell that goes to the Graveyard on resolution, and "You can only activate 1 per turn"
caps it further — so a second outstanding obligation is unreachable. Recorded honestly at LOW-
MEDIUM and tested synthetically rather than asserted as settled rules.

*Basis:* the card text plus `RULES_SPEC.md §2` / §6 and [S1 p.37]. **No official Konami ruling was
found for Parts B or C** — recorded as such rather than dressed up. Do not promote the confidence
without a source.
*Implementation:* `PlayerState.battle_phase_skips`, `GameState.impose_battle_phase_skip()` /
`has_pending_battle_phase_skip()` / `consume_battle_phase_skip()`,
`TurnFlow.can_enter_battle_phase()` and `TurnFlow._spend_battle_phase_skip()`.
RULES_SPEC.md §2.4.
*Tests:* `BattlePhaseRestrictionTests` (53) is the generic gate; `RunickFlashingFireTests` (123)
exercises the printed consumer, including both negation cases R1 names.

---

### R33 — a Trap Monster's runtime identity is per-copy, and the printed card is untouched

`The Phantom Knights of Shadow Veil` Special Summons itself "as a Normal Monster
(Warrior/DARK/Level 4/ATK 0/DEF 300)". **Confidence: HIGH** — this is a direct consequence of
[S1 p.53] plus the engine's own invariant that a `CardDef` is immutable and shared.

The decision recorded here is **where the granted type line lives**. It cannot go on the
`CardDef`: that object is the canonical printed identity and is shared by every copy of the card,
so writing a temporary Level and ATK into it would rewrite the card for the whole duel and for
every other copy. It lives on the `CardInstance` instead, and is revoked the instant the card
leaves the Monster Zone — on every route out, including the negated-Summon path, where the card
never reached the field at all.

Two sub-questions, both settled by the text rather than by a general rule:

* **"(This card is NOT treated as a Trap.)"** is a statement this particular card makes. Most
  printed Trap Monsters remain Trap Cards while they are monsters, so the engine carries
  `treated_as_original_type` per card rather than assuming either answer.
* **"banish this card when it leaves the field"** replaces the DESTINATION and nothing else. The
  card really was destroyed / tributed / returned; it simply does not arrive where that normally
  sends it. Rewriting the movement REASON as well would silently delete the destruction and every
  trigger keyed on it, so the reason is left alone and a `CARD_BANISHED` event is emitted
  alongside.

*Implementation:* `CardInstance.monster_identity` and its accessors,
`GameState.BANISH_WHEN_LEAVING_FIELD_KEY`. RULES_SPEC.md §5.8.
*Tests:* `TrapMonsterTests` (192) is the generic gate;
`ThePhantomKnightsOfShadowVeilTests` (125) exercises the printed consumer.

### R34 — attack PREVENTION, attack NEGATION and a card-class activation lock are three things

Recorded by the **Phase 5 batch 9 unit A** gate, before any batch-9 card existed. This entry
covers the generic mechanisms only; the per-card questions **R3**, **R6**, **R7** and **R8**
remain **OPEN** and are settled when their cards are written.

**Part A — prevention is not negation. Confidence: HIGH.** Directly from [S1 p.38–39] plus the
plain wording of the two cards. "Monsters cannot declare an attack" (`Swords of Revealing
Light`) removes the *ability to declare*; "negate the attack" (`Maiden with Eyes of Blue`)
answers an attack that *has been* declared. The observable differences — whether
`ATTACK_DECLARED` happens, whether a response window opens, whether the monster has spent its
attack for the turn — follow from the wording and are asserted in both directions.

**Part B — negation is checked before the Replay. Confidence: MEDIUM-HIGH.** No single official
sentence names the ordering. It is reasoned: a Replay exists so the attacking player may choose
again when *the attack is still live and the board changed under it* [S1 p.39]; once the attack
has been negated there is no attack to replay, so the Replay condition is moot. The alternative
ordering has a concrete absurd consequence — `Maiden`'s own Special Summon would hand the
attacker a fresh declaration and undo the negation that had just been paid for. Recorded with
this reasoning and asserted directly, so a later correction fails loudly rather than drifting.

**Part C — the Damage Step is the boundary for negating an attack. Confidence: MEDIUM-HIGH.**
Rests on [S1 p.41]: from the start of the Damage Step only Counter Traps and cards that directly
change ATK/DEF may be activated. An effect that negates an attack is neither, so it cannot be
activated there, and `BattleRules.negate_attack()` refuses rather than half-applying.

**Part D — "cannot activate Trap Cards" locks activating a CARD, not activating an EFFECT of a
Trap already face-up on the field. Confidence: MEDIUM-HIGH — and this is the one part of R34
that a future session should re-check against an official source before relying on it further.**

The reasoning: PSCT distinguishes "activate a Trap Card" from "activate the effect of a card",
and the engine already carries the distinction structurally (`EffectType.CARD_ACTIVATION` versus
an `IGNITION`/`QUICK`/`TRIGGER` clause of a card on the field). A Continuous Trap sitting face-up
was *activated* on an earlier turn; using one of its effects now is not a second activation of
the Trap Card. **This is reasoned from the general rule and from PSCT, not from a quoted ruling
on `Mirage Dragon` itself, and no fresh research was done this session** — the confidence is
recorded honestly rather than inflated. The behaviour is isolated behind one generic predicate
(`ActivationRules.card_class_activation_ok()`) and asserted in both directions, so correcting it
later is a change in one place with a failing test to point at it.

**Part E — a per-card TURN COUNTER is not a game counter and not a once-per-turn flag.
Confidence: HIGH** (an engine-modelling decision, not a rules claim). See RULES_SPEC.md §11.2.

**Part F — two clauses may share ONE once-per-turn use. Confidence: HIGH** as a mechanism;
whether `Maiden with Eyes of Blue` actually has that shape is **R3** and is still open. The
mechanism is `EffectDef.restriction_group`, which had been declared since batch 5 with **zero
consumers** and is now consumed and tested. See RULES_SPEC.md §11.1.

*Implementation:* `ContinuousEffects.ATTACK_LOCK_KEY` / `ACTIVATION_LOCK_PREFIX`,
`BattleRules.negate_attack()`, `ActivationRules.card_class_activation_ok()`,
`CardInstance.turn_counters`, `EffectPrimitives` attack/turn-counter section.
RULES_SPEC.md §4.6, §6.4, §11.1, §11.2.
*Tests:* `AttackRestrictionTests` (229) — the generic gate. No printed card consumes it yet;
`Mirage Dragon` is the first and is the next step.

---

### R35 — `Mirage Dragon`, and what a card-class activation lock does NOT reach

Settled while implementing **`Mirage Dragon`** (cid 6196, verified official text: "Your
opponent cannot activate Trap Cards during the Battle Phase"). The generic mechanism is
**R34**; this entry records only what the printed card added, and one research result.

**Part A — the lock is per-PLAYER, per-CATEGORY and per-PHASE, and all three are read from
the board. Confidence: HIGH.** "Your opponent" is read from the card's CONTROLLER, so taking
control of `Mirage Dragon` turns the restriction around; "Trap Cards" covers all three printed
kinds — Normal, Continuous and **Counter** [S1 p.30] — and leaves Spells and monster effects
alone; "during the Battle Phase" is part of the lock key, so the same Set Trap is activatable
again in either Main Phase with the Dragon still face-up. Each direction is asserted.

**Part B — two copies apply as one lock, and removing one does not lift it. Confidence: HIGH**
(an engine-modelling consequence, not a rules claim). The restriction is recomputed from the
board on every `ContinuousEffects.recompute()` rather than reference-counted, so a second copy
adds nothing and a departure removes nothing while the other copy is still face-up. This is a
real board state: `Mirage Dragon` is one of only two quantity-2 cards in the V1 pool.

**Part C — the research result on R34 part D, recorded honestly.** The distinction between
activating a Trap **CARD** and activating an **EFFECT** of a Trap already face-up on the field
was re-checked against official sources while writing this card:

* the **official Konami card database has no Q&A entry for cid 6196** — there is no ruling on
  this card to quote;
* **[S1 p.30]** supports the distinction generally: "Continuous Trap Cards remain on the field
  once they are activated … Some Continuous Trap Cards have abilities similar to the Ignition
  Effects or Trigger Effects that can be found on Effect Monster Cards", and **[S1 p.53]**
  defines "the effect of a card" as the ability written on it, separate from the card;
* Yugipedia and the Fandom wiki were **unreachable** (HTTP 403 and 402 respectively), so no
  secondary source was consulted either.

**R34 part D therefore stays at MEDIUM-HIGH.** The rulebook now backs it more directly than
"PSCT alone" did, but it is still reasoned from the general rule rather than from a quoted
ruling on this card. It remains isolated behind one predicate
(`ActivationRules.card_class_activation_ok()`) and asserted in both directions.

*Implementation:* `Scripts/cards/registry/MirageDragon.gd` — one CONTINUOUS clause calling
`EffectPrimitives.forbid_card_activation()`. No engine change was needed.
*Tests:* `MirageDragonTests` (121).

### R36 — `Swords of Revealing Light`: which End Phase is the 3rd — **R6 is now CLOSED**

**R6 asked: "you must destroy it during the End Phase of your opponent's 3rd turn" — confirm
exactly which End Phase counts as the 3rd.** Settled while implementing the card
(cid 4354, verified official text).

**Part A — the three counted turns are the opponent's three turns AFTER activation, and the
card is destroyed in the End Phase of the third. Confidence: HIGH.** The reasoning is closed
by the card's own kind rather than by an inference about turn order: `Swords of Revealing
Light` is a **Normal Spell**, and a Normal Spell can only be activated during its controller's
own Main Phase [S1 p.31]. The controller's own turn therefore can never be one of the counted
turns, and "your opponent's 3rd turn" has exactly one reading in this pool. Asserted directly
in both directions — the opponent's End Phases advance the counter, the controller's do not,
and the destruction happens in the opponent's third turn and not in the second or the fourth.

**Part B — the counter is per-INSTANCE and does not survive leaving the field. Confidence:
HIGH** (an engine-modelling decision; see R34 part E and RULES_SPEC.md §11.2).
`CardInstance.on_leave_field()` clears `turn_counters`, so a second copy would count its own
turns from zero. There is only one copy in the pool, so this is a property of the mechanism
rather than a live interaction, and it is asserted so it cannot rot.

**Part C — "you must destroy it" is a real DESTRUCTION, and it is not a Trigger Effect.
Confidence: HIGH.** It puts no link on the Chain and is never offered as a choice, so it is a
CONTINUOUS clause responding to `PHASE_CHANGED`, the shape `Judge of the Ice Barrier` clause 1
established (R31). Modelling it as a TRIGGER would wrongly open a response window and wrongly
allow the destruction to be negated as an effect activation. The card goes through
`GameState.destroy()` with `DESTROYED_BY_EFFECT`, so a destruction-prevention or replacement
effect would legitimately see it.

**Part D — "If your opponent controls a face-down monster" is checked at RESOLUTION.
Confidence: HIGH.** It sits after the colon, so it is part of the effect and not an activation
condition [S1 p.51, PSCT]. The card is legal to activate against a board with no face-down
monster anywhere — it simply flips nothing, still stays on the field, and its attack lock
still applies. Making it an activation `condition` would forbid a legal play.

**Part E — flipping a monster face-up is not a Flip Summon. Confidence: HIGH** [S1 p.24, p.28].
No Summon event is emitted and the once-per-turn Normal Summon allowance is untouched, but
`CARD_FLIPPED_FACE_UP` is, so the Flip effects of the monsters turned over are collected at the
resulting trigger window and really resolve — asserted end to end, not merely by the event. A
face-down monster is in Defense Position and stays there: it becomes FACE_UP_DEFENSE, never
FACE_UP_ATTACK.

*Implementation:* `Scripts/cards/registry/SwordsOfRevealingLight.gd`;
`DuelEngine.REMAINS_ON_FIELD_EFFECT_ID` (the generic "it remains on the field" override, added
as its own unit before this card); `EffectPrimitives.flip_face_up()` /
`controls_a_face_down_monster()` / `count_turn_for()`; `EffectPrimitives.restrict_opponent_attacks()`.
*Tests:* `SwordsOfRevealingLightTests` (122); `SpellTrapTests` (49) for the generic override.

## 5. Banlist note (master prompt §51)

These are fixed casual decks built from an owned physical collection. Current Forbidden/Limited
status is **not** enforced and must not block a duel from starting. No deck list is altered.

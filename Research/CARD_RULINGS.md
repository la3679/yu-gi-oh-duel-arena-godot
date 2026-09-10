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
| R3 | `Maiden with Eyes of Blue` | **CLOSED — see R37.** "You can only use 1 'Maiden with Eyes of Blue' effect per turn, and only once that turn." — one allowance shared across **both** clauses, per player, per name: both carry `opt_named_effect()` and the same `in_group()` key, so using either locks out the other for the turn. Contrast `Judge of the Ice Barrier`, whose "each of the following effects … once per turn" gives one use per clause. |
| R4 | `Chain Detonation` / `Chain Healing` | Behaviour depends on the **Chain Link number at which the card was activated**. Chain Link position must be recorded on the Chain Link and readable at resolution. |
| R5 | `Fairy Tail - Sleeper` | "the activated effect **becomes** …" — this replaces the opponent's already-activated Normal Spell/Trap effect on the Chain. Needs an effect-substitution mechanism on the Chain Link, not a negate-then-add. |
| R6 | `Swords of Revealing Light` | **CLOSED — see R36.** "you must destroy it during the End Phase of your opponent's 3rd turn" — requires a per-card turn counter. The three counted turns are the opponent's three turns after activation, and the card is destroyed in the End Phase of the third; the controller's own turns never count, because a Normal Spell is only ever activated on its controller's turn [S1 p.31]. |
| R7 | `Soul Exchange` | **CLOSED — see R39.** "this turn, if you Tribute a monster, you must Tribute that target, as if you controlled it" — a turn-scoped lingering **material-choice constraint**, not a control change and not an extra Tribute: it binds *which* monster is chosen on both the Tribute Summon/Set route and the Tribute-**cost** route; it drops when the target leaves its Monster Zone, on a control change, on a face-up→face-down reset and at the exact end of the turn; and a still-affected target that becomes unsuitable **blocks** the Tribute rather than releasing the obligation. The Battle Phase sentence is an activation **condition**, confirmed when the Chain Link is processed — it survives EFFECT negation but not ACTIVATION negation. |
| R8 | `Kaiser Sea Horse` | **CLOSED — see R38.** "can be treated as 2 Tributes for the Tribute Summon of a LIGHT monster" — a rules QUERY on the Attribute of the monster being SUMMONED, not on this card; permission rather than compulsion; the Tribute Summon path only, never a Tribute paid as a cost; and worth 1 while face-down or negated. |
| R9 | `Rider of the Storm Winds` | Equips **itself** from hand or field; grants piercing; is a destruction **replacement** effect for the equipped monster. Also interacts with the rule that Equip Cards are destroyed when the equipped monster leaves the field. |
| R10 | `Gagagashield` | "Twice per turn, it cannot be destroyed by battle or card effects" — a counted prevention effect, resetting each turn. |
| R11 | `Fairy Tail - Luna` | **RESOLVED — see "R11 — `Fairy Tail - Luna`" below.** The original note (an opponent-side decision during resolution) was right but far from complete: cid 12952 also forbids activation **during the Damage Step**, makes the resolution-time re-check **both-or-nothing** over the MONSTER ZONE with no control re-check, offers the negation only while the target is **face-up** (a face-down target is still returned), returns each card to its **OWNER's** hand, and states that an **unaffected** target costs only itself. Q&A fid 20472 makes the send a **resolution process** whose legality is checked when reached, fid 11022 confirms ② is an ordinary Chain activation, and fid 262 permits a **Token** target. §8's claim that the negation branch is unreachable from the printed decks is **wrong** — both decks hold a duplicate. |
| R12 | `The Monarchs Awaken` | **RESOLVED — see "R12 — `The Monarchs Awaken`" below.** The original note (an Extra Deck activation condition; a broad immunity belonging in the rules layer) was right but far from complete: cid 10963 also forbids activation **during the Damage Step**, states the whole effect **does nothing** if the target is face-down at resolution, fixes the duration at **"as long as it is face-up in the Monster Zone"**, and permits a **Normal Monster** target. The general 「効果を受けない」 Q&A narrow the immunity to **application only** — targeting, resolution, costs, Tributes and battle are all untouched — and Q&A fid 20548 / 20533 overturn the engine's guess that a **Tribute Set** monster is not "Tribute Summoned". |
| R13 | `Witchcrafter Golem Aruru` | **RESOLVED — see "R13 — `Witchcrafter Golem Aruru`" below.** The original note (both trigger branches; the "Witchcrafter" Spell branch is never live) was right but far from complete: cid 14483 also forbids activation **during the Damage Step**, narrows the Spellcaster to **face-up in your Monster Zone**, restricts the targeting trigger to the **opponent's** activation, and states that a target that has left the field costs the bounce but **not** the Special Summon. |
| R14 | `Hidden Springs of the Far East` | Field Spell whose once-per-turn effect may be activated by **the turn player**, i.e. by either player depending on whose turn it is, including the opponent of its controller. |
| R15 | `A Hero Emerges` | **RESOLVED — see "R15 — `A Hero Emerges`" below.** The original note (a **random** choice from your hand, through the seeded RNG, leaking nothing) was right but far from complete: cid 5915 also forbids the activation entirely when your hand is empty **or holds no monster**, Q&A fid 12566 narrows that to "a monster this effect could actually Special Summon **right now**", and Q&A fid 8193 states that if the Special Summon has become impossible by resolution the effect is **not applied at all** — the random choice is not even made. |
| R16 | `Five Brothers Explosion` | Second effect triggers only when the face-up card **you control** is sent to **your** GY **by your opponent's card effect** — a precise movement-reason + agent check. |
| R17 | `Nefarious Archfiend Eater of Nefariousness` | GY effect during the **opponent's** End Phase; destroys your own face-up monster as part of the effect ("destroy it, and if you do, Special Summon this card"). |
| R18 | `Inari Fire` | Revives itself "during your next Standby Phase after this face-up card on the field was destroyed by card effect and sent to the GY" — a delayed trigger with a specific destruction reason. |
| R19 | `Castle of Dragon Souls` | ATK boost persists "even if this card leaves the field"; second effect triggers when the face-up card **is sent to the GY** (any reason). |
| R20 | `Honest` | **RESOLVED — see "R20 — `Honest`" below.** The original note (a Quick Effect legal during the Damage Step, needing `UNTIL_DAMAGE_CALC`) was right but incomplete: cid 7574 also forbids activation against a **0 ATK** monster, and states the effect is activated **in the hand**. |

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
were **OPEN** when this entry was written, to be settled when their cards were written. All four
are now **CLOSED** — **R37**, **R36**, **R39** and **R38** respectively.

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

### R37 — `Maiden with Eyes of Blue`: one allowance across two clauses — **R3 is now CLOSED**

**R3 asked: "You can only use 1 'Maiden with Eyes of Blue' effect per turn, and only once
that turn" — a combined restriction across BOTH effects, per player, per name.** Settled while
implementing the card (cid 10588, verified official text). The answer is yes, and the
mechanism is `EffectDef.restriction_group`.

**Part A — the two clauses spend ONE allowance between them. Confidence: HIGH.** The sentence
says "1 … effect per turn", not "each of the following effects once per turn" — contrast
`Judge of the Ice Barrier`, which prints "each of the following effects … once per turn" and
therefore gets one use **per clause** (R31). Both of Maiden's clauses carry
`opt_named_effect()` **and the same `in_group()` key**, so `EffectDef.named_key()` returns the
same key for both and one use locks out the other. Asserted in **both orderings**: Quick first
then Trigger, and Trigger first then Quick. A shared key that only worked one way round would
pass a one-directional test.

Two nearby models are wrong and are asserted against directly: `opt_instance()` is per COPY
rather than per name, and `opt_named_activation()` restricts activating the CARD rather than
using an EFFECT.

**Part B — clause 1 is a Quick Effect and clause 2 is not. Confidence: HIGH.** Only the first
prints "(Quick Effect)", so it is Spell Speed 2 and is chosen by its controller in the
response window; clause 2 is a Trigger Effect at Spell Speed 1, put on the Chain by the
trigger system when the attack is declared. The suite drives clause 1 as a real Chain Link 2
above the activation that targeted it.

**Part C — "a card or effect is activated that targets this card" is read from the CHAIN, not
from the trigger event. Confidence: HIGH** (an engine-modelling consequence). A Quick Effect is
offered by `DuelEngine._activation_actions()`, which asks `ActivationRules.can_activate()`
with **no event**; a condition reading `ctx.trigger_event` would therefore answer false at
exactly the moment the effect must be offered. `EffectPrimitives.is_targeted_by_a_live_activation()`
reads the unresolved Chain Links instead, which is also the honest model: the condition stays
true for the whole response window, and a link whose activation was negated no longer targets
anything.

**Part D — "and if you do" gates everything after it, and "then you can" is a SECOND optional
step. Confidence: HIGH.** If the negation does not actually happen there is no position change
and no Special Summon — proved by letting a different card negate the same attack as Chain
Link 2, so the Maiden's own link finds nothing left to negate. And the Special Summon is a
separate "you can", asked at RESOLUTION once the earlier steps have happened: declining it
leaves the negation and the position change standing. That inner question is
`EffectPrimitives.may()`, the pool's first optional step inside a resolving effect; like every
mid-resolution choice it goes through `ctx.ask()` so the replay payload carries it.

**Part E — the clause is genuinely LIVE in the V1 pool. Confidence: HIGH.** `Blue-Eyes White
Dragon` is in the same deck as the Maiden, so no R21/R23 synthetic treatment is needed —
asserted by reading both cards' deck lists from the verified database and checking they match.
All three printed zones (hand, Deck, GY) are exercised separately, because a hand-only
implementation would pass a hand-only test.

*Implementation:* `Scripts/cards/registry/MaidenWithEyesOfBlue.gd`;
`EffectPrimitives.is_targeted_by_a_live_activation()` / `own_cards_in_zones()` / `may()`;
`EffectPrimitives.negate_declared_attack()` and `is_current_attack_target()` from batch 9
unit A. RULES_SPEC.md §11.1.
*Tests:* `MaidenWithEyesOfBlueTests` (139).

### R38 — `Kaiser Sea Horse`: whose Attribute, and when the clause applies at all — **R8 is now CLOSED**

**R8 asked: "can be treated as 2 Tributes for the Tribute Summon of a LIGHT monster" —
modifies the Tribute requirement computation.** Settled while implementing the card
(cid 5409, verified official text).

**Part A — the Attribute condition is on the monster being SUMMONED, not on this card.
Confidence: HIGH**, directly from the wording. `Kaiser Sea Horse` is itself LIGHT, which is
exactly the coincidence that would let a wrong implementation pass every test that only ever
Summons a LIGHT monster — so the suite drives a synthetic DARK body carrying the same clause
(worth 2 for a LIGHT Summon) alongside the real LIGHT card Summoning a DARK monster (worth 1).

**Part B — it is a rules QUERY, not a modifier. Confidence: HIGH** (an engine-modelling
decision). The card declares a CONTINUOUS `EffectDef` carrying
`SummonRules.TRIBUTE_VALUE_EFFECT_ID` whose `condition` is a pure function of
`ctx.params["summoning_card"]`. It writes nothing to the board, which is why it legitimately
has no `apply_continuous` and is listed in `CardRegistry.RULES_QUERY_EFFECT_IDS`. A flat
numeric `tribute_value = 2` would be wrong for every non-LIGHT Summon.

**Part C — "CAN be treated as" is permission, not compulsion. Confidence: HIGH.** Tributing it
for a one-Tribute LIGHT Summon is still legal; `SummonRules.tributes_satisfy()` already lets a
card worth 2 overshoot a requirement of 1.

**Part D — the clause reaches the Tribute SUMMON only, never a Tribute paid as a COST.
Confidence: HIGH.** `tribute_value()` is consulted only on the Tribute Summon path; a cost
that says "Tribute 2 monsters" counts CARDS and goes through
`EffectPrimitives.pay_tribute_cost()`, which never asks. Asserted with a synthetic
Tribute-cost card, because the pool's own Tribute-cost cards name a Type (`Dragonic Tactics`
wants Dragons) or Tribute themselves (`Kaibaman`) and so cannot express the question about a
Sea Serpent.

**Part E — a FACE-DOWN copy is worth 1. Confidence: HIGH — and this was an engine DEFECT the
card's suite caught.** A face-down monster may still be Tributed [S1 p.53] and is a legal
`tribute_candidates()` entry, but it applies no effects while face-down — the same rule
`ContinuousEffects._continuous_sources()` enforces for every other continuous clause.
`SummonRules.tribute_value()` honoured `effects_are_negated()` but not face-orientation, so a
face-down `Kaiser Sea Horse` wrongly counted as two Tributes. Fixed, and the rule is now
asserted in the generic gate (`SummonTests`) as well as in the card's own suite.

**Part F — the clause is genuinely LIVE. Confidence: HIGH.** Its own deck holds
`Metaphys Armed Dragon` (Level 7 LIGHT, two copies) and `Witchcrafter Golem Aruru`
(Level 8 LIGHT), both needing two Tributes, which one `Kaiser Sea Horse` supplies alone. The
suite reads this from the verified database rather than asserting the card names, so it stays
true if a deck list changes.

*Implementation:* `Scripts/cards/registry/KaiserSeaHorse.gd`;
`SummonRules.TRIBUTE_VALUE_EFFECT_ID` / `tribute_value()` / `tributes_satisfy()`.
RULES_SPEC.md §5.2.
*Tests:* `KaiserSeaHorseTests` (57); `SummonTests` (88) owns the generic rule.

### R39 — `Soul Exchange`: the lingering material-choice constraint — **R7 is now CLOSED**

Current English text is unchanged from the cached cid 5099 text. Sources checked:
- TCG text: https://www.db.yugioh-card.com/yugiohdb/card_search.action?ope=2&cid=5099&request_locale=en
- Official OCG supplemental information, dated 2022-04-23:
  https://www.db.yugioh-card.com/yugiohdb/faq_search.action?ope=4&cid=5099&request_locale=ja
- Official OCG cost example (Paladin of Felgrand), fid 18452:
  https://www.db.yugioh-card.com/yugiohdb/faq_search.action?ope=5&fid=18452&request_locale=ja
- Official OCG double-Tribute example (Saqlifice), fid 13533:
  https://www.db.yugioh-card.com/yugiohdb/faq_search.action?ope=5&fid=13533&request_locale=ja
- Official OCG empty own field, fid 6070; Tribute prohibition chained, fid 6067;
  opponent's face-down identity unavailable for Ritual Tributes, fid 6284 (same URL format).

The four persisted questions, decided BEFORE code:
1. Includes Tribute costs and effect Tributes, not just Tribute Summons/Sets. The cost's
   qualifications still apply. A cost requiring THIS card cannot substitute a different
   monster. A typed cost cannot inspect an opponent's face-down Type/Attribute. HIGH for
   general coverage (18452); MEDIUM-HIGH for these applications of the current supplement.
2. Apply the permission/constraint at RESOLUTION. While its target remains in the opponent's
   Monster Zone, every relevant Tribute selection must include it. Leaving that zone or
   changing control ends applicability; returning never restores the old effect. Turning an
   affected face-up target face-down clears the effect; a target already face-down when the
   effect resolves can be used for an unrestricted Tribute. A still-affected target that
   becomes unsuitable BLOCKS that Tribute; it does not release the obligation. HIGH under
   the current OCG supplement; MEDIUM-HIGH for applying that guidance to this TCG project.
3. It substitutes a material, never grants a Summon, changes the Tribute count, or changes
   control/ownership. No own monster is necessary (6070). Unrelated actions remain legal.
4. A face-up, unnegated opponent-controlled Kaiser Sea Horse can supply two Tributes for a
   LIGHT Summon (13533 precedent + Kaiser text). Your own Kaiser alongside an ordinary forced
   target can count as ONE, giving two cards for a two-Tribute Summon. The old greedy maximum
   value test must not reject this optional-value combination. MEDIUM-HIGH for the analogy;
   HIGH for the optional 'can' wording. Face-down/negated Kaiser remains worth one.

The Battle Phase sentence is an activation CONDITION, not a negatable effect (supplement).
No activation after conducting a Battle Phase. Effect negation or an absent target does not
restore the Battle Phase; activation negation does. Use the existing THIS-TURN restriction,
not Runick's future skip. An unresolved Chain cannot conduct a phase; confirmation of the
activation restriction at link processing is sufficient and avoids rollback of other sources.

Historical Edison 'can Tribute' rulings were found but are NOT used for the current 'must'
text. The retired official fids 10307/10310 now return no data; the current supplement directly
states the face-down reset. No claim of a dedicated English TCG Q&A is made. Immunity cards
are outside the implemented pool; do not invent a full immunity subsystem in this unit.
R7 is decided with the per-part confidence above. **Implementation and tests are now complete**,
so R7 is CLOSED: `Scripts/cards/registry/SoulExchange.gd`, the generic gate
`ChoiceConstraintTests` (137/137) and the card suite `SoulExchangeTests` (174/174).
`RULES_SPEC.md` §5.9 is the normative statement of the mechanism.

### R40 — the DECK as a zone an effect may look through: SEARCH, MILL and an effect DRAW

Opened and closed by Phase 5 batch 10 unit A, **before** any batch-10 card was written. It is the
only ruling batch 10 opens; every batch-10 card carries `Special Ruling Needed = NO` in the matrix.

**Why it needed research at all.** `GameState`'s own comment above `reveal()` already separates
DRAW / REVEAL / EXCAVATE / SEARCH and records of the fourth: *"Nothing here does that;
`shuffle_deck()` is its tail."* Batch 10 builds the fourth. Three questions had to be settled
before the primitive could be written: what a search does to Deck knowledge, when a
search-shaped effect may be **activated** at all, and whether "draw 2" is legal on a short Deck.

**Sources.** All PRIMARY (official Konami), all re-fetched for this batch:

| Source | What it gives | Date on the page |
|---|---|---|
| [S1 p.5] and [S1 p.53] "Search your Deck" / "Reveal" — `Research/sources/SD_RuleBook_EN_10.pdf`, the cached copy already hashed in `RULES_SOURCES.md` | the general shuffle rule and the general search-activation restriction | rulebook v10 |
| `faq_search.action?ope=4&cid=10590&request_locale=ja` — `Dragon Shrine` supplemental information | the two sends, sequential, second optional, cap of 2 | 2024-03-23 |
| `faq_search.action?ope=5&fid=12831&request_locale=ja` — `Dragon Shrine` Q&A | the Normal-Monster test reads the GY, not the print | 2026-06-26 |
| `faq_search.action?ope=5&fid=22194&request_locale=ja` — `Dragon Shrine` Q&A | the two sends are not simultaneous | 2022-12-30 |
| `faq_search.action?ope=4&cid=7850&request_locale=ja` — `The White Stone of Legend` supplemental information | mandatory; activates with an empty search; Damage Step legal | 2024-03-23 |
| `faq_search.action?ope=4&cid=7248&request_locale=ja` — `Trade-In` supplemental information | Deck must hold 2+; the discard is a cost | 2021-02-06 |
| `faq_search.action?ope=4&cid=8656&request_locale=ja` — `Cards of Consonance` supplemental information | Deck must hold 2+; cost; does not target | 2020-08-29 |
| `faq_search.action?ope=4&cid=9138&request_locale=ja` — `White Elephant's Gift` supplemental information | cost; "non-Effect Monster" is wider than "Normal Monster" | 2021-04-01 |
| `faq_search.action?ope=4&cid=7246&request_locale=ja` — `Herald of Creation` supplemental information | Ignition; cost; a GY target must already exist | 2015-03-21 |
| `faq_search.action?ope=4&cid=9910&request_locale=ja` — `Divine Dragon Apocralyph` supplemental information | Ignition; Extra Deck target returns to the Extra Deck | 2016-09-01 |

**A methodology note that cost this session real time and must not be repeated.** The FIRST
fetches used `request_locale=en` and returned, for every cid, the database's generic marketing
boilerplate — byte-identical between two different cards. That was very nearly recorded as
"no official Q&A exists for these cards", which would have been **false**. `request_locale=ja`
returns the real supplemental information for all ten lookups above. **A generic-boilerplate
response from this database is evidence of a bad locale, not of an absent ruling.** Re-check any
earlier "no Q&A entry" conclusion in this file against the `ja` locale before relying on it.

#### Part A — a search shuffles; a draw does not. Confidence: HIGH.

[S1 p.5] requires that a Deck a card effect made you reveal from **or look through** be shuffled
and put back, and [S1 p.53] repeats it for searching and adds that the opponent may shuffle or
cut. `RULES_SPEC.md` §12.1 already keys the loss of `revealed_to` on the **shuffle**, so a search
clears Deck knowledge as a consequence of a rule already implemented; nothing new was needed
there. A DRAW is private and shuffles nothing; an EXCAVATE is public and shuffles nothing. The
three stay three. `RULES_SPEC.md` §8.4 is the normative statement.

A card **added to the hand** by a search is revealed to both players on its way — it must be
shown to prove it met the search's requirement — and then it is an ordinary private hand card.
The search's tail shuffle then clears `revealed_to` for everything still **in** the Deck, which
is the point — knowledge of the rest of the Deck ends. The card that LEFT keeps its reveal, and
correctly so: both players watched it go to the hand, so the opponent legally knows it is held.
Confidence HIGH for the reveal; it follows [S1 p.53]'s "Reveal" entry directly.

#### Part B — the general search-activation restriction. Confidence: HIGH, but it is GENERAL.

[S1 p.53] states that you cannot activate an effect **to search your Deck** for a card when no
card in your Deck meets the requirements. Implemented as `can_search_deck()` and consumed by the
`condition` of any card whose activation exists in order to search.

The sentence is worded for "add a card from your Deck to your hand, or Special Summon a monster
from your Deck". Whether it also governs a Deck→**GY** send is an **inference** (MEDIUM-HIGH),
and it is applied to `Dragon Shrine`: its first send is mandatory and unconditional, so an
activation with no Dragon monster in the Deck could not perform any part of its resolution. No
card-specific official statement on that point was found for cid 10590. Recorded as an inference,
not as an official ruling.

#### Part C — `The White Stone of Legend` is the EXCEPTION, not an instance. Confidence: HIGH.

**This reversed the first draft of the batch-10 plan and would otherwise have been a silent bug.**
The general rule in part B suggests a mandatory GY trigger should not activate with no
`Blue-Eyes White Dragon` in the Deck. The card-specific official supplement (cid 7850,
2024-03-23) says the opposite, explicitly:

* it is a Trigger Effect that activates **in the Graveyard**;
* it activates **necessarily** whenever its condition is met — **including when there is no
  `Blue-Eyes White Dragon` in the Deck**, in which case it resolves and adds nothing;
* it activates even when its condition is met **during the Damage Step**.

Card-specific official guidance outranks the general sentence, so the engine implements the
card's own rule. The general restriction stays as `can_search_deck()` for cards that are
activated *in order to* search; a mandatory trigger whose condition is "this card was sent to the
GY" is not such a card. Both halves are asserted directly in `TheWhiteStoneOfLegendTests`.

Consequences that follow and are also asserted: the trigger fires on **any** send to the GY —
Tributed, discarded, sent as a cost, destroyed by battle, destroyed by effect — because the
condition names none of them; and it is a `GRAVEYARD` activation location, so the card is already
in the GY when the effect activates.

#### Part D — "draw 2" cannot be activated on a Deck of fewer than 2. Confidence: HIGH (two cards), MEDIUM-HIGH (the third).

The engine's `GameState.draw()` correctly implements [S1 p.35]: a player who must draw and cannot
loses. From the general rules alone, activating `Trade-In` with 1 card in the Deck would draw 1
and lose the Duel. **That is not what the official supplements say.** Independently, for two
different cards:

* cid 7248 (`Trade-In`, 2021-02-06) — it can be activated in a situation where your Deck has
  **2 or more** cards;
* cid 8656 (`Cards of Consonance`, 2020-08-29) — it **cannot** be activated when your Deck has
  1 or fewer cards.

Two independent explicit statements, so HIGH. Implemented generically as `can_draw(ctx, pid, n)`
on the draw primitive rather than as a per-card constant, because the rule is plainly about
"draw N", not about these two card names.

`White Elephant's Gift` (cid 9138, 2021-04-01) draws 2 in the same wording but its supplement is
**silent** on the Deck requirement. Applying the same gate to it is an **inference by analogy**,
recorded at MEDIUM-HIGH. It is stated here as an inference and must not be quoted as an official
ruling for that card. The alternative — letting it deck the player out — is equally unsourced and
is inconsistent with the two cards that are sourced, so the consistent reading was chosen.

The deck-out path itself is **not** removed and is still tested: `draw_cards()` still loses the
Duel when it genuinely cannot complete, so a future card that draws without this activation gate
behaves correctly.

#### Part E — the payment is a COST in all five cards that have one. Confidence: HIGH.

Every relevant supplement says so in as many words (cid 7248, cid 8656, cid 9138, cid 7246, and
cid 9910 by the same "捨て…発動できる" construction). It is therefore `pay_cost`, never `resolve`,
and [S1 p.53, "Pay a Cost"] adds that it is not refunded when the activation is negated — which
the engine already implements and which batch 10 asserts again for the new cards.

Two distinctions inside that, both already modelled by separate primitives and both asserted:

* `Trade-In`, `Cards of Consonance`, `Herald of Creation` and `Divine Dragon Apocralyph`
  **discard** — hand → GY, `MoveReason.DISCARDED`, `pay_discard_cost()`;
* `White Elephant's Gift` **sends from the field** — `MoveReason.SENT_AS_COST`,
  `pay_send_to_gy_cost()`. It is not a discard and a future "if this card is discarded" clause
  must not see it.

`Cards of Consonance` additionally **does not target** (cid 8656), so its qualification lives in
the cost's candidate list and not in `legal_targets`.

#### Part F — "non-Effect Monster" is wider than "Normal Monster". Confidence: HIGH; never-live in V1.

cid 9138 states that non-Effect Monsters include not only Normal Monsters but also effectless
Ritual / Fusion / Synchro / Xyz / Link monsters, and that a monster which cannot be sent to the
GY (a Token, a Pendulum) may not pay the cost. Implemented as "is a monster **and** is not an
Effect Monster", not as "is a Normal Monster". Both Extra Decks are empty in V1 and the pool has
no Tokens or Pendulums, so the two sets coincide **in this pool** — asserted directly, the
R21 / R23 never-live treatment, so the fact cannot rot silently.

#### Part G — `Dragon Shrine`'s two sends. Confidence: HIGH.

cid 10590 (2024-03-23) plus two Q&As:

* the first send is performed, and **only if it succeeded in sending a Dragon Normal Monster**
  may the second be performed; the two are **explicitly not simultaneous** (fid 22194);
* the second send is **optional** — `may()`;
* the Normal-Monster test is applied to the monster **as it now sits in the Graveyard**, not to
  its printed identity: fid 12831 (2026-06-26) answers "yes, you can" for a card that is merely
  *treated as* a Normal Monster while in the GY. In the V1 pool nothing is treated-as, so the two
  readings coincide here — but the implementation reads the GY, because that is what is correct;
* **at most 2** Dragon monsters are sent by one `Dragon Shrine`: a Dragon Normal Monster sent by
  the SECOND send does not start a third.

#### Part H — `Herald of Creation` and `Divine Dragon Apocralyph`. Confidence: HIGH.

cid 7246 (2015-03-21) and cid 9910 (2016-09-01): both are **IGNITION** effects activatable from
the Monster Zone, both take the discard as a **COST**, and `Herald` cannot be activated unless a
legal target already exists in the GY — which is ordinary targeting and needs no special code.
Both note that a Level 7+ / Dragon **Extra Deck** monster in the GY may be targeted and would
return to the Extra Deck rather than the hand. Both Extra Decks are empty in V1, so that branch is
**never live**; it is asserted as impossible rather than implemented as a branch that can never
run.

**R40 is CLOSED.** `RULES_SPEC.md` §8.4 is the normative statement of the mechanism; the gate is
`Tests/rules/DeckAccessTests.gd`, written and green before any batch-10 card existed.

### R41 — the six batch-11 cards: destruction with a condition, an ATK boost, and a battle-damage trigger

Opened and closed by Phase 5 batch 11, **before** any batch-11 card was written. Batch 11 was
chosen precisely because §8 predicted it needed **no** new ruling; that prediction was wrong in
one direction and right in another, and both halves are recorded here honestly.

* It was **right** that none of the seven carried-over open rulings (R5, R11, R12, R13, R14, R15,
  R20) touches any of these six. None of them was reopened and none was consulted.
* It was **wrong** that no research was needed at all. Five of the six carry official supplemental
  information that **changes the implementation** from what the printed English text plus the
  general rules alone would have produced. Four of those five changes would otherwise have been
  silent bugs. They are Parts A–E below.

**Sources.** All PRIMARY (official Konami supplemental information), fetched 2026-09-06 with
`request_locale=ja` per R40's methodology note. Every response was verified card-specific by
diffing two of them against each other before any of it was relied on.

| Source | What it gives | Date on the page |
|---|---|---|
| `faq_search.action?ope=4&cid=5345&request_locale=ja` — `Stamping Destruction` | the damage is conditional on the destruction succeeding; the two are simultaneous; the Dragon is **not** re-checked at resolution | 2015-02-12 |
| `faq_search.action?ope=4&cid=6911&request_locale=ja` — `Straight Flush` | does not target; illegal in the Damage Step; an Equip Card **occupies** a Spell & Trap Zone; a **Trap Monster in a Monster Zone does not** | 2015-02-05 |
| `faq_search.action?ope=4&cid=5979&request_locale=ja` — `Burst Stream of Destruction` | cannot be activated if a `Blue-Eyes White Dragon` **already attacked** this turn; the ban covers **every** copy, including one Summoned later; it attaches at **activation** and is lifted **only** by activation negation; the `Blue-Eyes White Dragon` must be **face-up** | 2024-09-07 |
| `faq_search.action?ope=4&cid=5810&request_locale=ja` — `Chiron the Mage` | an **Ignition** effect on the field; it **does** target despite the "select" wording; the discard is a **cost** | 2020-04-01 |
| `faq_search.action?ope=4&cid=11848&request_locale=ja` — `Back-Up Rider` | targets a face-up monster in a **Monster Zone**, **either** player's; the gain is **not** original ATK; two copies on one monster **stack** to +3000 | 2015-04-25 |
| `faq_search.action?ope=4&cid=8858&request_locale=ja` — `Vampiric Koala` | a **Trigger** Effect; does not target; **mandatory**; fires **after damage calculation** of a battle **this card itself** fought against a monster | 2017-01-12 |

Both `Stamping Destruction` and `Straight Flush` return "このカードに関連するＱ＆Ａはありません"
— *this card has no related Q&A* — under the `ja` locale, which is the response shape R40 says a
genuine absence looks like, as distinct from the `en` boilerplate that is not evidence of anything.

#### Part A — `Stamping Destruction`: the damage is a CONSEQUENCE, the Dragon is not re-checked. Confidence: HIGH.

cid 5345 states three things, each of which the implementation encodes:

1. At resolution, "destroy that card" is performed, and **only if the destruction succeeded** is
   "inflict 500 damage to its controller" performed. This is the PSCT "and if you do" and it is
   the load-bearing branch: a target protected by `Gagagashield`'s counted prevention, or removed
   from the field in response, produces **no damage at all**.
2. The destruction and the damage are **treated as simultaneous**. Nothing in the V1 pool can
   observe the difference — there is no card that reacts between the two — so this is recorded
   rather than modelled, and asserted as "one resolution, no window".
3. **"If you control a Dragon monster" is NOT re-checked at resolution.** The supplement says so
   in as many words: 効果処理時に自分フィールドにドラゴン族モンスターが存在しなくなっている場合でも、
   効果処理は通常通り適用されます. This is RULES_SPEC.md §10's before-the-colon mapping confirmed
   on a real card, and it is the opposite of what §16's "re-check everything that made it legal"
   habit would have produced. Tributing the Dragon in response does **not** stop the card.

"its controller" is read **before** the destruction, not after: once the card is in the Graveyard
it is no longer controlled by anyone, and the text names the controller of the card that was
destroyed.

#### Part B — `Straight Flush`: which cards occupy a Spell & Trap Zone. Confidence: HIGH.

The activation condition counts **zone occupancy**, not cards, and cid 6911 settles the two cases
this pool can actually reach:

* an **Equip Card** equipped to a monster is still a card in a Spell & Trap Zone, so it fills one
  of the five and is destroyed by the resolution. `Gagagashield`, `Kunai with Chain` and
  `Castle of Dragon Souls` are all in the pool, so this is live, not theoretical;
* a **Trap Monster** that is in a **Monster Zone** by its own effect is **not** a card in a Spell
  & Trap Zone, and the supplement adds explicitly that `Straight Flush` then **cannot be
  activated at all**. `The Phantom Knights of Shadow Veil` is exactly that card, and this is the
  one place in the pool where §5.8's "one Monster Zone, no Spell & Trap Zone" rule is observable
  from another card.

It does **not** target, and it is **illegal in the Damage Step** — which is the engine default
(`DamageStepPermission.NONE`), so that half is asserted rather than implemented.

The Field Zone is **not** a Spell & Trap Zone, in either half of the card — it is neither counted
by the activation condition nor destroyed by the resolution.

**That distinction is LIVE, and the first draft of this note said it was not.** The claim
"nothing in the V1 pool is a Field Spell" was written from memory and was **false**: deck 2 holds
`Hidden Springs of the Far East`, a **Field Spell**, which is itself one of the ten cards still
unimplemented (it carries **R14**). The error was caught immediately, by the assertion written to
record it — `StampingDestructionTests` counts the pool's Field Spells rather than asserting the
claim in prose — which is the whole reason such assertions are written. Both cards therefore
branch on the Field Zone for real:

* `Stamping Destruction` targets "1 Spell/Trap **on the field**", which **includes** the Field
  Zone — a Field Spell is a Spell Card on the field, exactly as R28 reads it for
  `A Wingbeat of Giant Dragon`;
* `Straight Flush` names the "**Spell & Trap Zones**" specifically, which **excludes** the Field
  Zone from both its condition and its destruction.

The two cards printing different words and behaving differently is the point, and each is
asserted against a real Field Spell in the Field Zone rather than assumed.

#### Part C — `Burst Stream of Destruction`: the attack ban attaches at ACTIVATION. Confidence: HIGH.

cid 5979 (2024-09-07) is the reason this card needed the one piece of new engine surface batch 11
added, and every clause of the note matters:

* **It is also an activation restriction, backwards in time.** 既に「青眼の白龍」が１体でも攻撃を
  行っているターンには、このカードを発動できません — you cannot activate it on a turn in which a
  `Blue-Eyes White Dragon` has **already** attacked. Nothing in the printed English text says this;
  it is derived from the lingering sentence and would have been missed.
* **The ban covers every copy**, not the one you controlled at activation — 全ての「青眼の白龍」は
  攻撃を行うことができません — so a `Blue-Eyes White Dragon` Summoned **later that same turn** by
  `Kaibaman` or `Silver's Cry` is also banned. That is what forces a **name-keyed, player-scoped,
  turn-scoped** ban rather than a flag on the monsters present at resolution.
* **It attaches at activation, not at resolution**: このカードを発動した時点で、（実際に処理が行われ
  たかどうかにかかわらず、）— "regardless of whether the effect was actually carried out". So
  **effect** negation does not lift it.
* **Activation negation does lift it**: ただし、この効果の発動が無効になった場合、「青眼の白龍」が
  攻撃できる状態に戻ります.

Those last two together are *exactly* the semantics of the existing
`ActivationRules.ACTIVATION_CONDITION_EFFECT_ID` + `EffectDef.activation_confirmed` channel built
for R39, which fires only when `not link.activation_negated` and survives effect negation. No new
channel was needed — only somewhere for a **name-keyed turn-scoped attack ban** to live, because
the engine's two existing attack-prevention channels are both continuous (§6.1) and this one has
to outlive its source, which is a Normal Spell in the Graveyard by then.

Finally, the effect's own condition requires a **face-up** `Blue-Eyes White Dragon`
(自分フィールドに表側表示の「青眼の白龍」が存在する場合). The supplement adds that a face-up
`Blue-Eyes White Dragon` in your **Spell & Trap Zone** would also satisfy it; nothing in the V1
pool can put a monster in a Spell & Trap Zone face-up, so that branch is **never live** and is
asserted as unreachable rather than implemented — the R21 / R23 treatment.

#### Part D — `Chiron the Mage` DOES target. Confidence: HIGH.

The current official text reads "then target 1 Spell/Trap your opponent controls", and cid 5810
confirms it against the older "select" wording: 相手フィールドの魔法・罠カード１枚を対象に取る効果
です — an effect that targets — and 発動時にコストとして、手札の魔法カード１枚を捨てます — the
discard is a **cost** paid at activation. It is an **Ignition** effect activated on the field.
Nothing here contradicts the English text; it is recorded because "select" in the OCG print and
"target" in the TCG print are the kind of divergence that is worth having checked rather than
assumed.

#### Part E — `Back-Up Rider` stacks, and is not original ATK. Confidence: HIGH.

cid 11848 gives three facts and the implementation asserts all three:

* the target is a monster **face-up in a Monster Zone**, and **either** player's — the English
  "on the field" is not narrowed to your own side;
* the increase is **not** treated as the original ATK, so `Kaiser Sea Horse`-style clauses and
  `CardInstance.original_atk()` must not see it. The engine already separates these
  (`base_atk()` / `original_atk()` versus `current_atk()`), so this is an assertion, not a change;
* **two copies targeting the same monster in the same turn stack to +3000.** Deck 1 holds one
  copy, so this is asserted against a second synthetic copy rather than against the real deck —
  but it is the fact that proves the modifier is per-application and not a set-to-value.

#### Part F — `Vampiric Koala` triggers when it is ATTACKED too. Confidence: HIGH.

cid 8858: 「吸血コアラ」自身がモンスターと戦闘を行い、その戦闘で相手に戦闘ダメージを与えたダメージ
計算後に必ず発動する効果です — a **mandatory** Trigger Effect that fires **after damage
calculation** of a battle in which **this card itself** fought **a monster** and the **opponent**
took battle damage.

The subject of the sentence is 自身 — the card itself battling — and **not** "when this card
attacks". So the effect fires in **both** directions, and the defending direction is the half the
English text makes easy to miss:

| Situation | Triggers? |
|---|---|
| Koala attacks a weaker Attack Position monster | **yes** |
| Koala, in Attack Position, is attacked by a weaker monster | **yes** — the attacker's controller takes the damage |
| Koala, in Defense Position, is attacked by a monster with less ATK than Koala's DEF | **yes** |
| Koala attacks directly | **no** — 「モンスターとの戦闘」, a battle *with a monster* |
| Koala attacks a Defense Position monster and no damage is inflicted | **no** |
| Koala battles and **its own** controller takes the damage | **no** |

It does **not** target, and the amount gained is exactly the battle damage inflicted in that
battle — read from the `BATTLE_DAMAGE_INFLICTED` event, never recomputed from ATK values, because
a modifier applied inside the Damage Step would make the two disagree.

"After damage calculation" is Damage Step sub-step 4, so the clause carries
`DamageStepPermission.MANDATORY_TRIGGER` (RULES_SPEC.md §7.2) — without it a mandatory effect the
rules require to happen inside the Damage Step would never be collected.

#### Part G — can `Stamping Destruction` target ITSELF? Implemented as NO. Confidence: MEDIUM.

The one question in batch 11 that the official database does **not** answer: cid 5345 has no
related Q&A. A Normal Spell activated from the hand occupies a Spell & Trap Zone from the moment
it is activated, so at the instant targets are chosen `Stamping Destruction` is itself "1
Spell/Trap on the field".

Implemented as **NO**, for the same two reasons R28 gives for `A Wingbeat of Giant Dragon`, and
recorded at the same confidence and with the same honesty: this is **reasoned from precedent, not
an official ruling**.

* R28 already decided the non-targeting form of exactly this question for this project, from the
  published `Heavy Storm` rulings. A targeting form that answered differently would make the two
  cards disagree about whether an activating Spell is a legal object of its own effect.
* The published rulings for `Mystical Space Typhoon`, worded "Target 1 Spell/Trap on the field;
  destroy it" — the same clause, differing only in the Dragon condition and the burn — state that
  it cannot target itself.

The difference is observable (a self-target would destroy the card with `DESTROYED_BY_EFFECT`
instead of the ordinary `RESOLVED_TO_GY`, emit `CARD_DESTROYED`, and inflict 500 damage on its own
controller), so it is **asserted** rather than assumed:
`StampingDestructionTests :: it is not among its own legal targets`.

*Source:* community transcriptions of the `Mystical Space Typhoon` rulings plus this project's own
R28, **not** an S1–S4 official source and **not** the Konami database. Consulted 2026-09-06.

**R41 is CLOSED.** It opens nothing and blocks nothing. The seven rulings carried into batch 11 —
R5, R11, R12, R13, R14, R15, R20 — are all still **OPEN**, all still belong to the ten cards that
remain, and none of them was touched.

### R42 — the three batch-12 cards: a Tribute-cost burn, a look at the opponent's hand, and a Special Summon from the Deck

Opened and closed by Phase 5 batch 12, **before** any batch-12 card was written. §8 recommended
these three precisely because it believed they carried no open ruling. That belief was **half
right and half wrong**, in the same shape as R41's, and both halves are recorded here.

* It was **right** that none of the seven carried-over open rulings (R5, R11, R12, R13, R14, R15,
  R20) touches any of these three. None was reopened and none was consulted.
* It was **wrong** that `Damage Condenser` had only "two open questions". Its official supplement
  carries a **third** fact neither §8 nor the printed English text contains — a hard activation
  restriction — and that fact is the difference between a card that resolves for nothing and a
  card that cannot be activated at all. It is Part C below.
* It was also **wrong** in a claim of fact about the repository: §8 called `Damage Condenser`
  "the first Special Summon FROM THE DECK in the pool". It is not. `One for One` — implemented in
  batch 10, shipped and green — Special Summons "1 Level 1 monster from your hand **or Deck**".
  Part D records the correction and what it removes from batch 12's scope.

**Sources.** All PRIMARY (official Konami supplemental information), fetched 2026-09-06 with
`request_locale=ja` per R40's methodology note. Every response was verified card-specific by
diffing them against each other before any of it was relied on: the four differ in content, and
none is the `en` marketing boilerplate R40 warns about.

| Source | What it gives | Date on the page |
|---|---|---|
| `faq_search.action?ope=4&cid=6441&request_locale=ja` — `Spiritual Fire Art - Kurenai` | cannot be activated in the **Damage Step**; the Tribute is a **cost**; a **face-down** monster is a legal Tribute; the damage is the ATK **written on the card** | 2020-07-04 |
| `faq_search.action?ope=4&cid=6440&request_locale=ja` — `Spiritual Water Art - Aoi` | cannot be activated in the **Damage Step**; the Tribute is a **cost**; a **face-down** monster is a legal Tribute | 2020-07-04 |
| `faq_search.action?ope=4&cid=6582&request_locale=ja` — `Damage Condenser` | does **not** target; activates **after damage calculation**; the discard is a **cost**; **cannot be activated** with no qualifying monster in the Deck | 2017-04-20 |
| `faq_search.action?ope=4&cid=8197&request_locale=ja` — `One for One` (consulted as the precedent for Summoning out of the Deck) | the send is a **cost**; and a monster that is the **only** way to carry out the effect **cannot be used as the cost** | 2020-03-20 |

All four cards return `このカードに関連するＱ＆Ａはありません` — *this card has no related Q&A* —
for the Q&A section proper. That is the response shape R40 records for a genuine absence; the
supplemental information above is a different section of the same page and is present for all four.

#### Part A — `Kurenai`: the damage is the ATK PRINTED ON THE CARD. Confidence: HIGH.

cid 6441 states the payment and the measurement in one breath:

> ■このカードを発動する際にコストとして、自分のモンスターゾーンの炎属性モンスター１体をリリースします。（表示形式を問わずリリースできます。）
> ■コストとしてリリースしたモンスターの、**カードに記載されている攻撃力**分のダメージを与えます。

Three separable facts, each encoded:

1. **The Tribute is a COST**, paid at activation — `pay_tribute_cost()` in `pay_cost`, never in
   `resolve`, exactly as `Miyabi` does it. It is therefore **not refunded** when the activation or
   the effect is negated, and both directions are asserted.
2. **A face-down FIRE monster is a legal Tribute** — 表示形式を問わず, "regardless of display
   position". You know your own Set monster's Attribute, and the cost asks no one else to read it.
   This matches `Miyabi`'s already-shipped behaviour rather than departing from it.
3. **The damage is the ATK written on the card** — the printed value, which is what
   `CardInstance.original_atk()` answers and what the English "original ATK" means. This is the one
   trap in the card: `current_atk()` would be wrong, and after batch 11's `Back-Up Rider` the two
   demonstrably differ. A monster boosted +1500 by `Back-Up Rider` and then Tributed for `Kurenai`
   deals its **printed** ATK, not the boosted figure. Asserted directly, in both directions.

The damage is dealt **by the cost's payload**, not by a card still on the field: by the time the
link resolves the Tributed monster is in the Graveyard. `record_cost()` is what carries it across,
and `CardInstance.original_atk()` keeps answering in the Graveyard because it reads the definition.

A further consequence the supplement does not need to state and the implementation must not
forget: a FIRE monster with **0 printed ATK** is a legal Tribute and inflicts **0 damage**. The
card says "inflict damage equal to", not "inflict damage, if any"; there is no minimum, and no
clause forbids the cost. That path is asserted so it cannot silently become a no-op guard.

*Damage Step:* ダメージステップには発動できません — `DamageStepPermission.NONE`, which is the
default and is asserted rather than assumed.

#### Part B — `Aoi`: looking at the hand is an OPERATION, and the ACTIVATING PLAYER chooses. Confidence: HIGH for the cost and the Damage Step; MEDIUM-HIGH for who chooses.

cid 6440's supplement is the shorter of the pair and gives the same two structural facts as
`Kurenai` — Damage Step forbidden, Tribute is a cost, face-down legal. It says **nothing** about
the hand, which means the card's own English text and the general rules have to carry it:

> "Tribute 1 WATER monster; **look at** your opponent's hand, then **send 1 card from their hand**
> to the GY."

* **"Look at" is a reveal to ONE player, not to both.** [S1 p.50] makes the contents of a hand
  private; §12.1 already models legal knowledge as `CardInstance.revealed_to` and already ends it
  only at a shuffle. "Look at your opponent's hand" is therefore `reveal(card, [me])` for every
  card in that hand — additive, private, and permanent until a shuffle, which is exactly what the
  physical game gives you (you saw them; you remember). **Nothing is turned face-up and nothing
  moves.** This is an operation over an existing subsystem, not a new subsystem.
* **The knowledge SURVIVES the effect.** The engine has no "forget" and must not grow one for
  this: §12.1 keys the loss of `revealed_to` on the shuffle and on nothing else, and a hand is
  never shuffled. A card that was looked at and then stays in the hand is still legally known.
  Asserted.
* **The activating player chooses which card is sent.** The subject of every verb in the sentence
  is "you", and the sentence exists to be a discard-the-best-card effect; a random or
  opponent-made choice would make "look at your opponent's hand" pointless. Confidence
  **MEDIUM-HIGH**: reasoned from the text and from the contrast with `A Hero Emerges` (R15), whose
  text says "**at random**" precisely because that is the exception. It is recorded here as
  reasoned rather than as an official ruling, and it is **asserted** so it cannot drift.
* **The send is an effect, not a cost**, and it is **not a discard**: it is your opponent's card
  leaving their hand because of your card. `MoveReason.SENT_TO_GY` rather than `DISCARDED` —
  [S1 p.52-53] keeps the two apart, and R40 already made that separation load-bearing.
* **An empty opponent hand.** The supplement is silent, and the general rule decides: the clause
  that would be impossible is the *second* one, and the first ("look at") is still performable.
  Nothing in the card is an activation requirement — contrast `Damage Condenser` in Part C, whose
  supplement makes its Deck requirement explicit precisely because such a restriction is *not* the
  default. So `Aoi` **can** be activated against an empty hand and resolves having looked at
  nothing and sent nothing. Confidence MEDIUM-HIGH, reasoned from the absence rather than from a
  statement, recorded honestly, and asserted in both directions so the vacuous path is never
  mistaken for a passing test.

#### Part C — `Damage Condenser`: the Deck requirement is an ACTIVATION RESTRICTION. Confidence: HIGH.

The fact §8 did not know existed. cid 6582:

> ■自分のデッキに、『その時に受けたダメージの数値以下の攻撃力を持つモンスター』が存在しない場合、「ダメージ・コンデンサー」を発動する事はできません。

*If your Deck contains no monster with ATK less than or equal to the damage received at that
moment, `Damage Condenser` cannot be activated.*

This settles **both** of §8's questions and adds a third:

1. **The ATK compared is the ATK in the Deck** — necessarily, because the restriction is phrased
   as a property of monsters *in the Deck*, and a card in the Deck has no field, no modifiers and
   no controller. Printed = original = current there. `monster_filter(max_atk)` already reads
   `definition.base_atk` for exactly this reason and says so in its own comment. **Question one is
   answered YES**, and by an official source rather than by inference from "there is nothing else
   to read".
2. **It is an activation restriction, not a resolution filter.** The card cannot be activated at
   all with an empty qualifying Deck — so the clause consumes it in its `condition`, the way
   R40's general search restriction is consumed. This is the opposite of `One for One`, whose
   activation is legal and whose resolution may legitimately find nothing (Part D), and the two
   must not be made to share an implementation.
3. **The comparison is against the damage taken AT THAT MOMENT** — その時に受けた, the specific
   battle damage that triggered this activation, not a running total and not the controller's LP.
   Read from the triggering event through `battle_damage_just_inflicted_on()`, which batch 11
   built for `Vampiric Koala` and which exists precisely because a `ChainLink` does not carry the
   event that made it eligible.

Three more facts from the same page, each encoded:

* **It does not target** (対象を取る効果ではありません) — the monster is chosen at RESOLUTION,
  which it must be anyway since the candidates are in the hidden Deck. `targets` stays false.
* **It activates AFTER DAMAGE CALCULATION** (自分が戦闘ダメージを受けたダメージ計算後に発動します).
  That is a substep **of the Damage Step**, so this card needs a Damage Step permission — it is
  the opposite of `Kurenai` and `Aoi`, whose supplements forbid the Damage Step outright. All
  three are asserted, so the contrast cannot quietly collapse.
* **The discard is a COST** (発動する際に、コストとして、手札を1枚捨てます) — `pay_discard_cost()`,
  and `DISCARDED` rather than `SENT_AS_COST`, since the card says "Discard".

**The shuffle — question two — is answered by the general rule, not by this page.** cid 6582 is
silent on it. [S1 p.5] requires a Deck a card effect made you *look through* to be shuffled and
put back, RULES_SPEC §8.4 already records that as normative, and `One for One` — the pool's other
Deck Special Summon — already implements exactly that tail and cites the same line. `Damage
Condenser` follows the established precedent rather than inventing a second answer. Confidence
HIGH for the rule, and the honest note is that it is **general-rule-and-precedent, not
card-specific official guidance**. It is observable (a shuffle clears `revealed_to` for that Deck,
§12.1) and is therefore asserted.

#### Part D — a CORRECTION to shipped code: `One for One`'s cost cannot be the last enabler. Confidence: HIGH.

Consulted as precedent, cid 8197 turned out to correct a card that is already implemented,
already tested and already green — which is why it is recorded here rather than quietly fixed:

> ■処理を行えるようにコストのモンスターを墓地へ送る必要があります。レベル１のモンスターが自分のデッキに存在せず、自分の手札に１体のみ存在する状況では、そのモンスターをコストにできません。

*You must send the cost monster to the Graveyard in such a way that the effect can be carried
out. In a situation where no Level 1 monster is in your Deck and only one is in your hand, you
cannot use that monster as the cost.*

`Scripts/cards/registry/OneForOne.gd` detail 7 currently states the **opposite** in prose, and the
suite asserts it:

> "The cost is paid BEFORE the effect resolves, so a player who sends their only Level 1 monster
> as the cost, holding none in the Deck, legitimately resolves the card for nothing. The
> activation was still legal — the candidate check happens before the cost."

The activation being legal is correct and is not in question. What is wrong is the **cost
candidate list**: the official guidance removes from it any monster whose removal would leave the
effect unperformable. The observable difference is narrow but real — with exactly one Level 1
monster in hand, none in the Deck, and at least one non-Level-1 monster also in hand, the engine
currently offers that Level 1 monster as a legal cost and Konami does not.

This is an **authoritative correction to a previously-recorded conclusion**, so it is documented
here in full, with its source and its date, before anything is changed. It is **not** part of
batch 12 — `One for One` is not a batch-12 card, the fix inverts an existing shipped assertion,
and this project does not fold a correction to one card into another card's unit. It is recorded
in PROJECT_STATE §7 as an open defect and is carried into the batch-13 recommendation as its own
unit. **Nothing in batch 12 depends on it**, and no batch-12 card copies the behaviour it
corrects.

##### Part D is CLOSED — applied in Phase 5 batch 13 unit A

**The source was re-fetched and re-verified before anything was changed.** `faq_search.action`
`?ope=4&cid=8197&request_locale=ja` was requested again on 2026-09-08; the page still carries the
2020-03-20 supplement and the sentence above is character-for-character what it returns. The
correction therefore rests on the live official source, not on batch 12's transcription of it.

**Old behaviour (wrong).** `OneForOne.gd` detail 7 said a player "who sends their only Level 1
monster as the cost, holding none in the Deck, legitimately resolves the card for nothing", and
`OneForOneTests._test_paying_away_the_last_level_1_monster` asserted exactly that outcome.

**Corrected behaviour (authoritative).** That monster is **not a legal cost**. The restriction is
on the **cost candidate list** only:

* the activation stays legal whenever a Level 1 monster is in the hand or Deck — **unchanged**;
* the monster whose loss would leave nothing to Summon is removed from the candidates;
* when that empties the candidate list — the last enabler is also the only monster in hand —
  there is **no payable cost**, so the card is not offered at all, and it is `can_pay_cost` that
  refuses rather than the condition;
* a copy of a Level 1 monster in the **Deck**, or a **second** one in the hand, makes the hand
  copy spendable again. The rule must not over-apply.

**Which assertions changed, and why.** One test was retired and four of its assertions inverted;
every other assertion in the suite is untouched. Recorded exactly:

| Retired assertion (`_test_paying_away_the_last_level_1_monster`) | Now |
|---|---|
| `only_level_1.zone == GRAVEYARD` — it was spent as the cost | it is **not** a legal cost and is not spent |
| `monster_count() == 0` — nothing was Summoned | a monster **is** Summoned |
| `SPECIAL_SUMMON_SUCCEEDED == 0` | exactly **one** Special Summon occurs |
| the scripted cost choice was a valid answer | that choice is now **rejected** by the engine |
| *the activation is legal* | **kept, unchanged** — this was always right |
| *the Spell resolves and reaches the Graveyard* | **kept, unchanged** |

**Card-local or generic?** The **rule is generic** — the supplement states it as a requirement of
payment, not as a property of `One for One` — but the **defect it exposed is currently reachable
through exactly one card**. Every cost-paying card in the V1 pool was audited: the rule bites only
where the cost's material pool and the effect's candidate pool overlap in the **disabling**
direction, i.e. the cost removes a card from a zone the effect draws from and puts it somewhere
the effect does not. `One for One` (hand → GY; Summons from hand **or Deck**) is the only such
card. `Fairy Tail - Rella` overlaps too and is **not** affected, because its discard lands in the
Graveyard and the Graveyard is one of the three zones its effect equips from. Every other cost in
the pool draws from a zone the effect never reads.

It was therefore implemented at the **generic level**:
`EffectPrimitives.cost_candidates_keeping_effect_performable()`, next to
`exclude_required_tributes()`, with `RULES_SPEC.md` **§10.5** as its written contract and
`Tests/rules/CostLegalityTests.gd` as an engine-level gate built from **synthetic** cards — the
disabling shape and the harmless one, so the rule is proved not to over-apply. `OneForOneTests`
is then the card-level evidence that the printed card consumes it.

**Honest limit, recorded rather than hidden.** The filter tests each candidate alone. That is
exact for a payment of ONE card and not exact for a larger payment, where a pair may be illegal
though neither card is illegal by itself. A count other than 1 is refused loudly rather than
approximated, and this is asserted. No V1 card has a multi-card cost overlapping its own pool.

#### Part E — what batch 12 does NOT need, having looked. Confidence: HIGH.

Two subsystems §8 expected to be built are not needed, and each is recorded so the next session
does not build them speculatively:

* **"The first Special Summon from the Deck" does not exist to build.** `One for One` already
  Summons from the Deck through `special_summon_one_any_position()`, and
  `EffectPrimitives.special_summon_one()` already takes a fixed `Enums.Position`, which is what
  "in Attack Position" needs. `Damage Condenser` is a pure consumer of both plus batch 10's
  `monster_filter(max_atk)`. **No new Summon surface was added.**
* **"Look at the opponent's hand" is one function, not a subsystem.** `GameState.reveal()` already
  reveals to a named subset of players and already emits `private_to` for a partial reveal.
  The new `EffectPrimitives.look_at_hand()` is a loop over it, and the choice it feeds goes
  through the existing `choose_one()` so the duel stays replayable.

**R42 is CLOSED, Part D included.** It opened nothing that blocked a batch-12 card. It opened one
defect against already-shipped code (Part D), which batch 13 unit A **fixed, verified against the
live official source, and closed** — see "Part D is CLOSED" above. The seven rulings carried into batch 12 — R5, R11, R12, R13, R14, R15, R20 — are
all still **OPEN**, all still belong to the seven cards that remain after batch 12, and none of
them was touched.

### R20 — `Honest` — RESOLVED and CLOSED in Phase 5 batch 13 unit B

**R20 was carried OPEN across ten checkpoints.** It was opened in §4 with one line — "Quick
Effect explicitly legal during the Damage Step … confirms the need for the `UNTIL_DAMAGE_CALC`
permission class" — and that line turns out to have been **right but far from complete**. The
card carries an activation restriction the printed English text does not contain, and finding it
was the point of doing the research before writing the card. §8's standing warning — *look for an
activation restriction the printed English text does not carry* — has now been correct **three
batches in a row** (`Burst Stream of Destruction`, `Damage Condenser`, and now `Honest`).

**Sources.** All PRIMARY (official Konami), fetched **2026-09-08** with `request_locale=ja` per
R40's methodology note. None is the `en` boilerplate R40 warns about.

| Source | What it gives |
|---|---|
| `faq_search.action?ope=4&cid=7574&request_locale=ja` — card text + 補足情報, page dated **2024-04-01** | clause ① is an **Ignition** effect in the Monster Zone; clause ② is a **Quick Effect activated in the hand**; **cannot be activated against a 0 ATK monster**; legal whether your monster **attacks or is attacked** |
| `faq_search.action?ope=5&fid=19235` (2017-03-24) | the boosted monster's ATK is **recalculated** (再計算) — Honest's amount goes in as an **addition to the base**, and a continuous multiplier then applies on top |
| `faq_search.action?ope=5&fid=12970` (2017-03-24) | Honest is **not an effect the opponent's monster receives**, so a monster "unaffected by other cards' effects" can still be battled and Honest still applies |
| `faq_search.action?ope=5&fid=13385` (2017-03-24) | an activation-negating answer stops it in the ordinary way — no special interaction |
| `faq_search.action?ope=5&fid=14540` (2025-12-13) | lists `Honest` among the effects whose send to the GY is **a COST** |

Unlike the four cards in R42, cid 7574 **does** have a real Q&A section — **9 entries** — so the
「このカードに関連するＱ＆Ａはありません」 absence shape does not apply here.

**Official Japanese text.**

> ①：自分メインフェイズに発動できる。フィールドの表側表示のこのカードを手札に戻す。
> ②：自分の光属性モンスターが戦闘を行うダメージステップ開始時からダメージ計算前までに、このカードを手札から墓地へ送って発動できる。そのモンスターの攻撃力はターン終了時まで、戦闘を行う相手モンスターの攻撃力分アップする。

**Official supplement (補足情報), 2024-04-01.**

> 【①の効果について】■モンスターゾーンで発動できる起動効果です。
> 【②の効果について】■手札で発動できる誘発即時効果です。■**攻撃力０のモンスターと戦闘を行う際には発動できません。**■自分の光属性モンスターが攻撃する戦闘の際でも、自分の光属性モンスターが攻撃される戦闘の際でも発動できます。

#### Part A — the fact the English text does not carry: 0 ATK forbids the ACTIVATION. Confidence: HIGH.

> ■攻撃力０のモンスターと戦闘を行う際には発動できません。
> *It cannot be activated when battling a monster with 0 ATK.*

The printed English gives no minimum and would suggest a legal activation that adds +0. It is not
legal. This is an **activation restriction**, so it is consumed in `condition` and the effect is
never offered — the same shape as `Damage Condenser`'s Deck requirement (R42 Part C) and the
opposite of a resolution that legitimately finds nothing. Asserted in **both** directions: 0 ATK
is never offered, and 1 ATK is offered and adds exactly 1.

#### Part B — the SHAPE of each clause, stated officially rather than inferred. Confidence: HIGH.

* **Clause ① is 起動効果 — an IGNITION effect — activated モンスターゾーンで, in the Monster Zone.**
  Spell Speed 1, Main Phase only, from the field face-up. It is explicitly **not** a Quick Effect,
  which matters: it cannot be used to dodge anything mid-chain.
* **Clause ② is 誘発即時効果 — a QUICK EFFECT — activated 手札で, IN THE HAND.** Spell Speed 2 and
  `ActivationLocation.HAND`. This is the **pool's first monster effect activated from the hand**,
  and it required **no new engine surface**: `ActivationRules.location_ok()` already answered for
  `HAND`, and `DuelEngine._activation_actions()` already walks every instance in every zone and
  defers to that gate. §8's prediction that this card's only new surface would be a *location*
  was correct, and the location turned out to already exist.
* **The window is ダメージステップ開始時からダメージ計算前まで** — from the start of the Damage Step
  until before damage calculation, i.e. sub-steps **1 and 2**. That is exactly
  `DamageStepPermission.UNTIL_DAMAGE_CALC`, which §7.2 already documents as "an effect that
  directly changes ATK/DEF". No new permission value was added, and the suite asserts it is
  **never** offered in sub-step 4 or 5.
* **Both directions of the battle.** 攻撃する戦闘の際でも…攻撃される戦闘の際でも — attacking and
  being attacked. `EffectPrimitives.battle_opponent_of()` is symmetric and answers both from one
  reader, so this needed no branch. Both are asserted.

#### Part C — "During the Damage Step" is part of the TEXT, not only of the permission. Confidence: HIGH.

**A defect the tests caught before the card shipped, recorded because the mistake is easy to
repeat.** `ActivationRules.damage_step_ok()` returns `true` whenever the duel is *not* in the
Damage Step — it exists to restrict what may happen **inside** one. A first implementation that
relied on `UNTIL_DAMAGE_CALC` alone was therefore offered in the **attack-declaration window**,
which is the Battle Step, because `current_attacker` is already set there. The condition must
also require `state.battle_step == DAMAGE`. Asserted directly against `ActivationRules.can_activate()`
with the battle step put back where the declaration window has it, and as an invariant over the
whole battle: every window that offered Honest was in the Damage Step and no other.

#### Part D — cost, and what the cost does NOT change. Confidence: HIGH.

* **The send is a COST.** 「このカードを手札から墓地へ送って発動できる」, and fid 14540 lists Honest
  among the effects that send a card to the GY *as a cost*. Paid in `pay_cost`, **never refunded**
  when the activation or the effect is negated (RULES_SPEC.md §10). Asserted with a negator.
* **It is a SEND, not a discard** — `MoveReason.SENT_AS_COST`, the distinction `One for One`
  already draws [S1 p.52-53]. Asserted on the event's reason, not on the destination.
* **Honest is in the GRAVEYARD when its own effect resolves**, because its cost put it there.
  Nothing in the resolution reads its zone. This is the ordinary consequence of a cost.

#### Part E — what "that monster" is, and what the amount is. Confidence: HIGH for the addition; MEDIUM-HIGH for the read-at-resolution.

* **It does NOT target.** Neither text carries 対象 / "target". "That monster" is fixed by the
  battle **at activation**, and is recorded in `ctx.cost_payload` — the channel `Kurenai` already
  uses — rather than re-derived at resolution. Re-deriving would silently re-ask "is it LIGHT?",
  and that was an **activation** condition: a monster that stopped being LIGHT after a legal
  activation is still "that monster".
* **The amount is an ADDITION, not a set-to-value, and it goes in before any multiplier.**
  fid 19235: Palladium Oracle Mahad (2500 ATK, doubled to 5000 by its own continuous effect at the
  start of the Damage Step) battling F.G.D. (5000 ATK). With Honest, Mahad's ATK
  「再計算される」 — recalculated — as (2500 + 5000) × 2 = **15000**. `add_atk_modifier` plus
  `current_atk()` is exactly that shape, so the ordering is the engine's and not the card's.
  **Not reachable in the V1 pool**, which contains no ATK multiplier, so it is recorded as the
  reason the implementation is an additive modifier rather than tested directly.
* **The opponent's ATK is read at RESOLUTION.** The supplement does not say so; the general rule
  that a resolving effect reads the state at resolution does, and 再計算 is consistent with it.
  Confidence **MEDIUM-HIGH**, recorded as reasoned rather than as an official statement. The
  observable consequence is narrow: the value could only differ if something changed the opposing
  monster's ATK between activation and resolution, and the V1 pool has no card that can do that in
  the Damage Step.
* **"Until the end of this turn"**, not "until the end of the Damage Step". Asserted after the
  Damage Step has closed and again after the turn ends.

#### Part F — the opponent's monster is READ, never AFFECTED. Confidence: HIGH.

fid 12970: 「オネスト」の効果は、相手モンスターが受ける効果ではありません — *Honest's effect is not
an effect the opponent's monster receives*. A monster that is "unaffected by the effects of cards
other than this card" can still be battled and Honest still applies normally. So the **only** card
Honest affects is your own LIGHT monster, and the implementation consults no protection the
opposing monster carries. This is also a fact **R12** (`The Monarchs Awaken`, "unaffected by the
effects of cards other than this card") will need when that subsystem is built: being *read* for a
value is not being *affected*.

#### Part G — a face-down opposing monster. Confidence: MEDIUM. Reasoned, not officially stated.

Part A's restriction cannot be evaluated against a monster whose ATK is not legally knowable.
Answering it from an opposing **face-down** monster's real ATK would either leak hidden information
(RULES_SPEC.md §12.1) or make the restriction unenforceable; R39 already established that a typed
predicate may not inspect an opposing face-down monster's hidden identity. The condition therefore
requires the opposing battling monster to be **face-up**.

**No legal play is lost**, and that is what makes this safe rather than merely convenient: the
rules flip an attacked face-down monster face-up in **sub-step 2**, which is inside Honest's own
printed window, so the activation is offered one sub-step later instead of not at all. Asserted in
both directions — not offered in sub-step 1 against a Set monster, offered in sub-step 2, and the
boost uses the flipped monster's **ATK** and not its DEF. Recorded at MEDIUM confidence because it
is reasoned from the hidden-information model rather than stated by cid 7574.

#### Part H — no once-per-turn, and what that lets happen. Confidence: HIGH.

Neither text carries any per-turn wording, so none is declared. Two copies sent in the **same
battle** both apply and the gains **stack**, because each is a separate additive modifier. Deck 2
holds one copy, so this is exercised against a second instance and asserted.

**R20 is CLOSED.** It opened one fact the printed English text does not carry (Part A) and one
implementation defect the tests caught before the card shipped (Part C). It needed **no new engine
surface**: no new Damage Step permission, no new activation location, no new stat channel, and
emphatically no card-specific damage calculation. The six rulings that remain — **R5, R11, R12,
R13, R14, R15** — are all still **OPEN**, all still belong to the six cards that remain after
batch 13, and none of them was touched.

### R13 — `Witchcrafter Golem Aruru` — RESOLVED and CLOSED in Phase 5 batch 14

**R13 was carried OPEN across eleven checkpoints.** §4 opened it with one line — *"Trigger
condition covers both 'targets a Spellcaster monster(s) you control' and 'targets it for an
attack'. No 'Witchcrafter' Spells exist in the deck, so only the '1 card your opponent controls'
branch is ever live"* — and both halves of that line survive. What the line did **not** contain is
the set of facts below that change the implementation, three of which would have been silent bugs.

**§8's standing warning was right for a FOURTH batch in a row.** *Look for an activation
restriction the printed English text does not carry.* Aruru's is **「ダメージステップ中には発動できません」**
— it cannot be activated during the Damage Step. The printed English text says nothing about the
Damage Step at all. (`Burst Stream of Destruction`, `Damage Condenser`, `Honest`, now
`Witchcrafter Golem Aruru`.)

**Sources.** All PRIMARY (official Konami), fetched **2026-09-08** with `request_locale=ja` per
R40's methodology note. None is the `en` boilerplate R40 warns about. The raw captures are cached
under `Data/generated/konami_raw/` (untracked, per `.gitignore`).

| Source | What it gives | Date on the page |
|---|---|---|
| `faq_search.action?ope=4&cid=14483&request_locale=ja` — card text + 補足情報 | ① is a **Quick Effect activated in the hand**; the Spellcaster must be **face-up in your MONSTER ZONE**; the response chains **directly** to the opponent's activation; **cannot be activated during the Damage Step**; the Special Summon is performed **first** and the return happens **only if it succeeded**; the two are treated as **simultaneous**; a target that has **left the field** costs the return but **not** the Summon; ② is a **mandatory Trigger Effect in the Monster Zone**, once per **each** opponent Standby Phase | **2020-07-04** |
| `faq_search.action?ope=5&fid=22558&request_locale=ja` | an opponent effect that targets **two or more** cards makes ① legal as long as **one** of them is a face-up Spellcaster in your Monster Zone | **2022-12-30** |

cid 14483 has a real Q&A section with **1** entry, so the
「このカードに関連するＱ＆Ａはありません」 absence shape R40 records does not apply here.

**The English text was re-fetched from the live database on 2026-09-08 and diffed against the
persisted text in `Data/cards/cards.json`** — the same procedure batch 13 unit A used before it
inverted an assertion. It matches character for character, so nothing below rests on a stale
transcription.

**Official Japanese text.**

> このカード名の①の効果は１ターンに１度しか使用できない。
> ①：このカードが手札に存在し、自分フィールドの魔法使い族モンスターが相手の効果の対象になった時、または相手モンスターの攻撃対象に選択された時、相手フィールドのカード１枚または自分の墓地の「ウィッチクラフト」魔法カード１枚を対象として発動できる。このカードを特殊召喚し、対象のカードを手札に戻す。
> ②：相手スタンバイフェイズに発動する。フィールドのこのカードを手札に戻す。

**Official supplement (補足情報), 2020-07-04, quoted in full.**

> 【①の効果について】
> ■手札で発動できる誘発即時効果です。
> ■自分のモンスターゾーンの表側表示の魔法使い族モンスターを対象として相手が効果を発動した時、その発動に直接チェーンして発動できます。また、自分のモンスターゾーンの表側表示の魔法使い族モンスターが相手モンスターの攻撃対象に選択された時に発動できます。
> ■ダメージステップ中には発動できません。
> ■処理時に、『このカードを特殊召喚し』の処理を行います。特殊召喚に成功した場合、『そのカードを手札に戻す』処理を行います。
> ■特殊召喚の処理と手札に戻す処理は同時に行われたものとして扱います。
> ■処理時に、対象のカードがフィールドに存在しない場合、このカードを特殊召喚する処理のみを行います。
>
> 【②の効果について】
> ■モンスターゾーンで発動する誘発効果です。
> ■相手のスタンバイフェイズごとに１度、必ず発動します。

#### Part A — the fact the English text does not carry: the DAMAGE STEP is closed. Confidence: HIGH.

> ■ダメージステップ中には発動できません。
> *It cannot be activated during the Damage Step.*

The printed English text names no Damage Step restriction, and the card's own attack branch makes
one look unnecessary — an attack target is selected in the **Battle Step**, before the Damage Step
begins. The restriction is nevertheless real and it is **reachable**: an opponent's effect that
targets a Spellcaster you control and is itself legal inside the Damage Step would otherwise open
Aruru's window there.

Nothing was added to the engine for it. `EffectDef.damage_step_permission` defaults to
`DamageStepPermission.NONE`, and `ActivationRules.damage_step_ok()` answers **false** for `NONE`
whenever `state.battle_step == BattleStep.DAMAGE`. So the correct behaviour is the **default**
behaviour — which is exactly why it has to be asserted rather than assumed: a later change that
gave this clause a permission in order to reach some other window would silently break the ruling.
Asserted in both directions: offered in the Battle Step attack window, refused in the Damage Step
with the same board.

#### Part B — the SHAPE of each clause, stated officially rather than inferred. Confidence: HIGH.

* **① is 誘発即時効果 — a QUICK EFFECT — activated 手札で, IN THE HAND**, and it is **one clause
  covering both triggers**, not two. This is the point on which Aruru and `Maiden with Eyes of
  Blue` (R3 / R37) genuinely differ and must not be made to match: Maiden prints two sentences and
  only the first says "(Quick Effect)", so Maiden is a Quick Effect **plus** a Trigger Effect.
  Aruru prints one sentence carrying both triggers with a single "(Quick Effect)", and the
  supplement confirms it by describing ① as one 誘発即時効果 with two windows. **One `EffectDef`,
  two trigger events.**
* **② is 誘発効果 — a TRIGGER effect — activated モンスターゾーンで, in the Monster Zone**, and it is
  **必ず発動します — MANDATORY**. The English "Once per turn, during your opponent's Standby Phase:
  Return this card to the hand" carries no "You can", so English and Japanese agree; the supplement
  removes any doubt. `mandatory()` + `opt_instance()`.
* **相手のスタンバイフェイズごとに１度** — once per **each** opponent Standby Phase, which is once
  per turn on the turns that have one. `opt_instance()` is per copy per turn, which is the same
  thing given that a turn has at most one Standby Phase.

**No new engine surface was needed for either.** `ActivationLocation.HAND` for a monster's effect
was proved by `Honest` in batch 13 (`RULES_SPEC.md` §7.5) and is reused unchanged; the opponent
Standby Phase trigger is the `Nefarious Archfiend Eater of Nefariousness` shape
(`PHASE_CHANGED` + `event_is_phase_change_to(..., ctx.opponent_id())`) reused unchanged.

#### Part C — the trigger is narrower than the printed English text. Confidence: HIGH.

> ■自分のモンスターゾーンの表側表示の魔法使い族モンスターを対象として相手が効果を発動した時、その発動に直接チェーンして発動できます。

Three narrowings, each of which the English "a Spellcaster monster(s) you control" hides:

1. **モンスターゾーンの** — the Monster Zone, not "your field". A Spellcaster occupying a Spell &
   Trap Zone (a Trap Monster; the engine has them, `RULES_SPEC.md` §14 / R33) does not qualify.
2. **表側表示の** — **face-up**. A face-down Spellcaster does not qualify, and it could not: its
   Race is not a property either player may act on (the same rule R39 and `Honest` both rest on).
   The Race is read with `CardInstance.current_race()`, the field reader, per R33 — never the
   printed one.
3. **相手が効果を発動した時** — the **OPPONENT's** activation. Your own effect targeting your own
   Spellcaster does **not** open Aruru's window.
   `EffectPrimitives.is_targeted_by_a_live_activation()` (shipped for Maiden) does not ask **whose**
   activation it is, because Maiden's text does not care — so this needed the one genuinely new
   primitive in batch 14: `is_targeted_by_a_live_opponent_activation()`. It is the same Chain walk
   with the link's controller checked, written as a **sibling** rather than by changing the shipped
   function, in the same way `surviving_opponent_field_target()` is a sibling of
   `surviving_field_target()`.

**その発動に直接チェーンして** — *chaining directly to that activation* — means the window is the
response window that activation opened, which is what a Quick Effect keyed on `TARGET_SELECTED`
already gets from `DuelEngine._activation_actions()`. Nothing was built for the word "directly".

**The attack branch keys on `GameEvent.Kind.ATTACK_TARGET_SELECTED`**, which existed with **one
emitter and zero readers** — the same shape of dead vocabulary that batch 5 found in
`cannot_be_targeted` and batch 6 found in `CONTROL_CHANGED`. It is emitted only for a
**non-direct** attack, which is exactly the distinction 「攻撃対象に選択された時」 draws, so a direct
attack correctly opens no window.

#### Part D — a MULTI-target opponent effect qualifies if ONE of its targets is yours. Confidence: HIGH.

Q&A **fid 22558** (2022-12-30) asks exactly this and answers yes:

> 複数枚のカードを対象とする相手のカードの効果が発動した時にも、その対象となるカードの内１枚に自分のモンスターゾーンに表側表示で存在する魔法使い族モンスターが含まれるのであれば、自分は手札の「ウィッチクラフトゴーレム・アルル」のモンスター効果を発動する事ができます。

This falls out of the per-card Chain walk — `link.target_ids.has(card.id)` — rather than needing
anything of its own, but it is asserted against a synthetic two-target opponent Spell because an
implementation that compared the **whole** target set, or that took only the first target, would
pass every single-target test in this suite.

#### Part E — the RESOLUTION order, and the load-bearing fact that the Summon still happens. Confidence: HIGH.

> ■処理時に、『このカードを特殊召喚し』の処理を行います。特殊召喚に成功した場合、『そのカードを手札に戻す』処理を行います。
> ■特殊召喚の処理と手札に戻す処理は同時に行われたものとして扱います。
> ■処理時に、対象のカードがフィールドに存在しない場合、このカードを特殊召喚する処理のみを行います。

**This is the fact that could not have been guessed and that decides whether the card is right.**

* The Special Summon is performed **first**, and the return to the hand happens **only if the
  Special Summon succeeded** — the printed "and if you do". A full Monster Zone, or an Aruru that
  is no longer in the hand, therefore produces **no bounce at all**.
* **A target that is gone does NOT make the effect fizzle.** The ordinary reading of a
  single-target effect whose target has left is that the whole effect does nothing. Konami states
  the opposite here: 『このカードを特殊召喚する処理のみを行います』 — *only the Special Summon is
  performed*. The Summon is not conditional on the target. An implementation that returned early
  on a dead target would be wrong in a way no English-only reading would ever catch, and it is the
  single most valuable thing R13 bought.
* The two are **treated as simultaneous**, so nothing may observe the board between them: no
  trigger window opens inside the resolution, and anything watching either half sees both. The
  engine gives this for free — a Chain Link resolves without interruption and the events it emits
  are collected into one trigger check afterwards — so what is asserted is that no Chain Link forms
  between the Summon and the bounce.

#### Part F — which targets survive to resolution. Confidence: MEDIUM (inherited from R29).

The supplement addresses only 「フィールドに存在しない場合」 — the target having left the field. It
says nothing about control. `Witchcrafter Golem Aruru` targets **"1 card your opponent controls"**,
which is the exact wording R29 already decided for `Phoenix Wing Wind Blast` and
`Spiritual Wind Art - Miyabi`: the clause is re-checked for **control** at resolution, and R29's
third pillar is uniformity across the cards that print the same words. **R13 therefore inherits
R29 rather than reopening it**, and inherits its MEDIUM confidence with it. A target that changed
control keeps the Special Summon (Part E) and loses the bounce.

Implemented by re-running the clause's **own candidate builder** at resolution and asking whether
the chosen card is still in it, rather than by a hand-written second copy of the test. That is what
makes the field branch and the GY branch answer the same question — "is this still a legal target
for this clause?" — and makes drift between activation and resolution impossible.

**Ownership is not consulted**, exactly as R29 says. A card the opponent controls but Aruru's
controller **owns** is a legal target, and returning it puts it in its **owner's** hand — which is
its controller's opponent's hand. `GameState.move_card()` forces the owner's hand and the card
passes no `to_player`, the same as `Compulsory Evacuation Device`. Both directions are asserted.

#### Part G — the GY branch is NEVER live in the V1 pool, and is still implemented exactly. Confidence: HIGH.

`Witchcrafter Golem Aruru` is the **only** card with "Witchcrafter" in its name in either deck, and
it is a Monster, so **no "Witchcrafter" Spell exists in the V1 pool** and
「自分の墓地の「ウィッチクラフト」魔法カード１枚」 can never have a printed target. §4's original
R13 line said this and it is confirmed against `Data/cards/cards.json`.

It is implemented in full and tested against a **synthetic** "Witchcrafter" Spell, the treatment
R21 (`Apprentice Magician`'s Spell Counter clause) and R23 (`Fairy Tail - Rella`'s equip clause)
established, with a real-pool assertion in the opposite direction that no printed card can satisfy
it. The archetype test goes through `EffectPrimitives.name_matches_archetype()`, which already
exists for `Runick Flashing Fire`.

The English "1 'Witchcrafter' **Spell** in your GY" is a **Spell**, not a Spell or Trap, and the
Japanese 「「ウィッチクラフト」魔法カード」 agrees. A synthetic "Witchcrafter" **Trap** in the GY is
asserted **not** to be a legal target, so the category check is not vacuous.

#### Part H — what is live, so none of this suite is vacuous. Confidence: HIGH.

Aruru's own deck (`Fairy-Tail Tribute Guard`) holds **eight other Spellcaster monsters**
(`Apprentice Magician`, `Crystal Seer`, the three Charmers, and the three `Fairy Tail` monsters),
and the opposing deck (`Blue-Eyes Dragon Guard`) holds real cards that target a monster the
opponent controls — `Compulsory Evacuation Device`, `Fiendish Chain`, `Kunai with Chain`,
`Interdimensional Matter Transporter`. Both trigger branches and the field-target branch are
genuinely reachable with printed cards, and the suite drives the targeting branch with a **real**
opposing card (`Compulsory Evacuation Device`) as well as with fixtures.

**R13 is CLOSED.** It opened one fact the printed English text does not carry (Part A), one
narrowing of the trigger that needed the batch's single new primitive (Part C), and one resolution
rule that inverts the ordinary reading of a dead target (Part E). It needed **no new subsystem**:
one new `EffectPrimitives` sibling, no new event kind, no new activation location, no new
permission, no new zone. The five rulings that remain — **R5, R11, R12, R14, R15** — are all still
**OPEN**, all still belong to the five cards that remain after batch 14, and none of them was
touched.

### R15 — `A Hero Emerges` — RESOLVED and CLOSED in Phase 5 batch 15

**R15 was carried OPEN across twelve checkpoints.** §4 opened it with one line — *"Opponent
chooses a **random** card from your hand — must use the seeded deterministic RNG and must not leak
hand contents"* — and both halves of that line survive and are implemented exactly. What the line
did **not** contain is an **activation restriction the printed English text does not carry**, a
**narrowing** of that restriction that only the Q&A supplies, and a **resolution-time gate that
suppresses the random choice itself**. All three would have been silent bugs.

**§8's standing warning was right for a FIFTH batch in a row.** *Look for an activation
restriction the printed English text does not carry.* This card's is
**「自分の手札が0枚の場合や、自分の手札にモンスターカードがない場合、「ヒーロー見参」を発動する事自体ができません。」**
— with an empty hand, or with no monster in hand, it **cannot be activated at all**. The printed
English text says nothing about the hand as a requirement. (`Burst Stream of Destruction`,
`Damage Condenser`, `Honest`, `Witchcrafter Golem Aruru`, now `A Hero Emerges`.)

**Sources.** All PRIMARY (official Konami), fetched **2026-09-09** with `request_locale=ja` per
R40's methodology note. None is the `en` boilerplate R40 warns about. The raw captures are cached
under `Data/generated/konami_raw/` (untracked, per `.gitignore`).

| Source | What it gives | Date on the page |
|---|---|---|
| `faq_search.action?ope=4&cid=5915&request_locale=ja` — card text + 補足情報 | it does **not target**; it **cannot be activated** with an empty hand or with no monster card in hand; a randomly chosen monster this effect **cannot** Special Summon (a Spirit such as 「月読命」, a Special Summon Monster) is **not** Summoned and is **sent to the Graveyard** instead | **2015-03-26** |
| `faq_search.action?ope=5&fid=12566&request_locale=ja` — 「御前試合」 (*Gozen Match*) | the activation requirement is **not** "a monster card in your hand" but "**a monster in your hand that THIS EFFECT could actually Special Summon right now**": under Gozen Match with only LIGHT monsters on your field, a hand of DARK monsters makes the activation **illegal**; and a chosen card that fails the same test at resolution is **sent to the Graveyard** | **2017-03-24** |
| `faq_search.action?ope=5&fid=8193&request_locale=ja` — 「虚無空間」 (*Vanity's Emptiness*) | chained to this card's activation, Special Summoning becomes impossible and **the effect is not applied at all** — 「『自分の手札１枚を相手がランダムに選ぶ』事も行いません」, the random choice is **not even made** | **2017-03-24** |

cid 5915 has a real Q&A section with **2** entries, so the
「このカードに関連するＱ＆Ａはありません」 absence shape R40 records does not apply here. **Both
entries were read, and each settled a question the supplement does not answer** — which is the
third batch running in which the Q&A list, not the supplement, carried the decisive fact.

**The English text was re-fetched from the live database on 2026-09-09 and diffed against the
persisted text in `Data/cards/cards.json`** — the same procedure batches 13 and 14 used. It
matches character for character, so nothing below rests on a stale transcription.

**Official English text.**

> "When an opponent's monster declares an attack: Your opponent chooses 1 random card from your
> hand, then if it is a monster that can be Special Summoned, Special Summon it. Otherwise, send
> it to the GY."

**Official Japanese text.**

> ①：相手モンスターの攻撃宣言時に発動できる。自分の手札１枚を相手がランダムに選ぶ。それがモンスターだった場合、自分フィールドに特殊召喚し、違った場合は墓地へ送る。

**Official supplement (補足情報), 2015-03-26, quoted in full.**

> ■対象を取る効果ではありません。
> ■自分の手札が0枚の場合や、自分の手札にモンスターカードがない場合、「ヒーロー見参」を発動する事自体ができません。
> ■相手がランダムに選んだモンスターが「月読命」や特殊召喚モンスターなど、「ヒーロー見参」の効果によって特殊召喚できないモンスターだった場合には、特殊召喚できず、そのモンスターは墓地へ送られます。

**Official Q&A fid 12566 (2017-03-24), answer quoted in full.**

> 質問の状況の場合、「ヒーロー見参」の効果によって特殊召喚する事ができる光属性モンスターが自分の手札に存在するのであれば、「ヒーロー見参」を発動する事ができます。
> （例えば、質問の状況にて、自分の手札が闇属性のモンスターのみであった場合には、「ヒーロー見参」を発動する事はできません。）
> なお、その『自分の手札１枚を相手がランダムに選ぶ。それがモンスターだった場合、自分フィールドに特殊召喚し、違った場合は墓地へ送る』処理の際に、相手が選んだ手札が光属性のモンスターだった場合には通常通り特殊召喚されますが、相手が選んだ手札が光属性以外のモンスターまたは魔法・罠カードだった場合には、選んだカードは墓地へ送られます。

**Official Q&A fid 8193 (2017-03-24), answer quoted in full.**

> 質問の状況の場合、「虚無空間」の効果によってモンスターの特殊召喚を行う事ができなくなっていますので、「ヒーロー見参」の効果処理は適用されません。
> （『自分の手札１枚を相手がランダムに選ぶ』事も行いません。）

#### Part A — the fact the English text does not carry: the HAND gates the ACTIVATION. Confidence: HIGH.

> ■自分の手札が0枚の場合や、自分の手札にモンスターカードがない場合、「ヒーロー見参」を発動する事自体ができません。
> *If your hand is 0 cards, or if there is no monster card in your hand, you cannot activate "A
> Hero Emerges" at all.*

「発動する事自体ができません」 — *cannot activate it in the first place* — is the same construction
cid 6582 uses for `Damage Condenser` (R42 Part C), and it means the same thing: this is an
**activation restriction**, not a resolution filter. The printed English text carries no hand
requirement whatever, and an English-only implementation would have offered the card on an empty
hand and resolved it for nothing.

The restriction is not an accident of wording. The card exists to Special Summon; an effect that
could not possibly Special Summon anything has nothing to do, and the OCG makes that an activation
question here rather than letting the card be spent. Contrast `Spiritual Water Art - Aoi` (R42
Part B), which **can** be activated against an empty hand precisely because its supplement is
silent — the two are asserted against each other so neither can drift.

*Engine:* the whole restriction lives in `EffectDef.condition`, alongside the trigger read. No new
surface.

#### Part B — the requirement is narrower than "a monster card". Confidence: HIGH.

The supplement's second bullet, read alone, says "a monster card in your hand". The Gozen Match
Q&A (fid 12566) shows that is a simplification:

> …「ヒーロー見参」の効果によって特殊召喚する事ができる光属性モンスターが自分の手札に存在するのであれば、「ヒーロー見参」を発動する事ができます。
> （例えば…自分の手札が闇属性のモンスターのみであった場合には、「ヒーロー見参」を発動する事はできません。）
> *If a LIGHT monster **that can be Special Summoned by "A Hero Emerges"' effect** exists in your
> hand, you can activate it. (For example … if your hand were only DARK monsters, you could not.)*

So the real requirement is **"at least one card in your hand is a monster that THIS EFFECT could
legally Special Summon to your field at this moment"**. A hand full of monsters none of which
could be placed does **not** satisfy it. Gozen Match is not in the V1 pool, but the *shape* of the
restriction it demonstrates is entirely live here, because the engine already refuses a Special
Summon for two reasons that are present in this pool:

* **no free Monster Zone** — `PlayerState.has_free_monster_zone()`, checked by
  `SummonRules.begin_special_summon()`;
* **"You can only control 1 …"** — `SummonRules.control_limit_satisfied()`, which the V1 pool
  really carries (`Inari Fire`, `Nefarious Archfiend Eater of Nefariousness`,
  `Castle of Dragon Souls`).

Both are asserted, in both directions. The Nomi / Spirit dimension the supplement names
(「月読命」, 特殊召喚モンスター) is carried by the already-existing named predicate
`EffectPrimitives.revivable_monster()`, which RULES_SPEC §5.5 records as "any monster **for this
pool**, named rather than inlined so a later card that does carry the restriction has one place to
extend". This card is that place, and it now reads it.

**A full Monster Zone therefore forbids the ACTIVATION**, which is the same conclusion
`Damage Condenser` reached from a different direction and for a different reason. It is
**reasoned** from the Q&A's rule rather than stated for a full zone specifically — confidence
**HIGH** for the rule, **MEDIUM-HIGH** for that particular instance of it — and it is asserted in
both directions so it cannot silently invert.

#### Part C — the whole effect is gated at RESOLUTION, and the random choice is NOT made. Confidence: HIGH.

The single most valuable thing R15 bought, and the one no reading of the English text produces.
fid 8193:

> …「虚無空間」の効果によってモンスターの特殊召喚を行う事ができなくなっていますので、「ヒーロー見参」の効果処理は適用されません。
> （『自分の手札１枚を相手がランダムに選ぶ』事も行いません。）
> *…because Special Summoning monsters has become impossible, "A Hero Emerges"' effect processing
> is **not applied**. (The "your opponent randomly chooses 1 card from your hand" is **also not
> performed**.)*

The parenthesis is the ruling. The naive implementation — pick a card, then branch — is **wrong**,
and wrong in an observable way: it would send a Spell out of the hand to the Graveyard in a
situation where the official answer is that nothing happens at all. The correct order is

1. re-check Part B's requirement **at resolution**;
2. if it fails, the effect does nothing — **no pick, no reveal, no send**;
3. only then does the opponent choose a random card.

The card's own activation requirement is therefore re-checked at resolution, and it gates the
*first* sentence rather than only the Summon. This is **not** in tension with `RULES_SPEC.md`
§10.6 (*a dead target does not automatically kill the whole effect*), and the contrast is worth
stating because the two look superficially opposed: §10.6 is about a **target** that has left, and
each sentence of a resolution being performed on its own terms. Here the thing that has failed is
the effect's own **activation requirement**, which is not a sentence of the resolution at all — it
is the condition under which the OCG lets the card do anything. `Witchcrafter Golem Aruru` and
`A Hero Emerges` are asserted against each other so neither rule is generalised over the other.

Vanity's Emptiness is not in the V1 pool. The gate is nevertheless **fully live**, because the
same requirement fails for reasons the pool does supply — the last summonable monster leaves the
hand between activation and resolution, or the Monster Zone fills up. Both are driven with real
Chain interference.

#### Part D — it is RANDOM, it is the OPPONENT's, and it does not TARGET. Confidence: HIGH.

> ■対象を取る効果ではありません。 — *It is not an effect that targets.*

No `targets`, no `legal_targets`, no target re-check. The hand is hidden, so a target could not be
chosen there in the first place; the choice happens at **resolution**, which is what PSCT's
absence of the word "target" already means (RULES_SPEC §10).

「自分の手札１枚を**相手がランダムに選ぶ**」 — the opponent chooses, **at random**. Two consequences
the engine must respect, and both are asserted:

* **it goes through the seeded `Rng` and nowhere else.** `Rng.pick()` already exists, is already
  the only generator in the engine, and is already guarded by `ReplayTests`. A duel is
  reproducible from (Decks, seed, decisions); a pick taken from Godot's global RNG would silently
  destroy that, and no ordinary test would notice.
* **it is NOT a decision, and the chooser is asked nothing.** Routing "your opponent chooses"
  through `ctx.ask()` would hand the chooser a list of the cards in a hidden hand — the exact leak
  `RULES_SPEC.md` §12 exists to prevent. The chooser's `PlayerController` sees **no request at
  all**, which is asserted directly rather than inferred.

The word "chooses" is therefore agency without information, and in a two-player Duel it has **no
other observable consequence**: the distribution is uniform whoever is named. That is recorded
here honestly rather than dressed up as a testable fact, and the primitive still takes the chooser
explicitly so that the reveal and the log name the right player.

#### Part E — the "Otherwise" branch, and what it catches. Confidence: HIGH.

> ■相手がランダムに選んだモンスターが…特殊召喚できないモンスターだった場合には、特殊召喚できず、そのモンスターは墓地へ送られます。

The English "Otherwise, send it to the GY" is therefore **two** cases, not one:

* the chosen card is **not a monster** (a Spell or a Trap) — 「違った場合は墓地へ送る」;
* the chosen card **is** a monster but **this effect cannot Special Summon it** — a Spirit, a
  Special Summon Monster, or (fid 12566) a monster a lingering restriction forbids.

Both go to the Graveyard, and the Gozen Match answer states the second explicitly:
「相手が選んだ手札が光属性以外のモンスターまたは魔法・罠カードだった場合には、選んだカードは墓地へ送られます」
— *a non-LIGHT monster **or** a Spell/Trap card: the chosen card is sent to the Graveyard.*

**It is a SEND, not a discard.** 墓地へ送る is the send verb, and [S1 p.52-53] keeps "discard"
apart from "send to the Graveyard" — a separation R40 and R42 Part B have already made
load-bearing twice. `MoveReason.SENT_TO_GY_BY_EFFECT`, never `DISCARDED`, so a future card that
watches for a discard must not see this. Asserted in both directions.

Note the asymmetry this creates, which is the card's sharpest edge: the same Spell in the same
hand is **sent** when the effect resolves and **left alone** when Part C's gate fails. Nothing
about the English text hints at it.

#### Part F — whose field, whose Summon, and in what position. Confidence: HIGH for the field; MEDIUM-HIGH for the position.

「それがモンスターだった場合、**自分フィールドに**特殊召喚し」 — *Special Summon it to **your**
field.* The opponent chooses; **you** Special Summon, to your own Monster Zone, and you keep
control. Ownership never changes: the card came out of your own hand. The English "Special Summon
it" leaves the field implicit and the Japanese does not, which is why it is worth recording.

**The position is not named by either text**, so RULES_SPEC §5.5 [S1 p.24] applies and the
**summoning player** chooses face-up Attack or face-up Defense Position —
`EffectPrimitives.special_summon_one_any_position()`, not a fixed position. Confidence
**MEDIUM-HIGH**: reasoned from the general rule and from the contrast with `Damage Condenser`,
whose text *does* name "in Attack Position" and which is implemented with a fixed position for
exactly that reason. The two are asserted against each other.

#### Part G — the Damage Step, and an attack that is later negated. Confidence: MEDIUM. Reasoned, not officially stated.

The supplement is **silent** about the Damage Step, and that silence is recorded rather than
filled in. What is officially given is the window: 「相手モンスターの**攻撃宣言時**に発動できる」 —
at the opponent's monster's **attack declaration**, which is the Battle Step [S1 p.37-39]. The
Damage Step has not begun, so `Enums.DamageStepPermission.NONE` — the default — is correct, and
`ActivationRules.damage_step_ok()` answers **false** for `NONE` inside the Damage Step.

`RULES_SPEC.md` §10.7 says plainly that "never offered in the Damage Step" is **not** evidence
that the permission is enforced, because an effect declaring `trigger_events` is only ever offered
in a window whose events match, and `ATTACK_DECLARED` cannot occur inside the Damage Step. Batch
14 reached the enforceable case for `Witchcrafter Golem Aruru` because that card's other trigger
branch can open inside the Damage Step. **`A Hero Emerges` has no such branch, so the permission
is genuinely unreachable through the window machinery for this card** — and rather than write a
test that proves only the structural gate, the permission is asserted **directly** against
`ActivationRules.damage_step_ok()` with the Damage Step forced, next to the declaration assertion.
That is stated here so nobody later mistakes the direct assertion for a redundant one and deletes
it.

**An attack negated after this card is activated does not undo it.** A Chain resolves in reverse,
so an attack negation chained above `A Hero Emerges` resolves first; `A Hero Emerges` then resolves
on its own terms, because nothing in its resolution reads the attack — the attack appears only in
its activation timing. Reasoned from RULES_SPEC §4.1 and §6.4 rather than from an official
statement about this card; confidence **MEDIUM**, and asserted so it cannot drift.

#### Part H — what each player is allowed to see. Confidence: MEDIUM-HIGH. Reasoned from observability.

The supplement says nothing, and §8 predicted correctly that it must be settled anyway, because
"send it to the GY" is unobservable unless the chosen card becomes public.

**The chosen card is revealed to both players; nothing else about the hand is.** Both destinations
are public zones — a face-up Monster Zone or a Graveyard [S1 p.50] — so the chosen card becomes
public in **every** branch that happens at all, and revealing it at the moment of the choice
therefore gives away nothing the outcome does not already give. It is done explicitly rather than
left to the move, so that the branch the effect takes is verifiable by the opponent at the moment
it is taken.

**The controller learns nothing new** — it is their own hand. **The chooser learns exactly one
card**, the one that was chosen, and nothing whatever about the others: no `look_at_hand()`, no
decision request, no event naming an unchosen card. Asserted from both sides and against the
filtered `get_visible_state()` view, the way `RULES_SPEC.md` §12's own gate is.

When Part C's gate fails, **nothing is revealed at all**, because no card is chosen.

#### Part I — what is live in the V1 pool, so none of this suite is vacuous. Confidence: HIGH.

`A Hero Emerges` is in `Fairy-Tail Tribute Guard`, a deck of 39 entries holding **21 monsters**
and 18 Spells/Traps, so both resolution branches are reached constantly with printed cards, and
the opening hand of the real deck is a mixture. The opposing deck (`Blue-Eyes Dragon Guard`)
attacks with real monsters, so the trigger is ordinary play.

Live for the activation restriction: an **empty hand**, a hand of **Spells and Traps only**, and a
**full Monster Zone** are all reachable in a real Duel, and the last of them is the pool's live
instance of Part B's narrowing. Live for Part C with printed cards: the controller's own
`Birthright` — a Continuous Trap in the same deck, Spell Speed 2, which Special Summons a Normal
Monster from their Graveyard — can be chained **above** `A Hero Emerges` in the same window and
fill their last Monster Zone, after which nothing in the hand can be Special Summoned and the
whole effect is suppressed. The suite drives that shape with a fixture rather than with
`Birthright` itself, so the test stays about `A Hero Emerges`; the opposing deck
(`Blue-Eyes Dragon Guard`) holds no hand disruption, so the *other* route to the same gate — the
last summonable monster leaving the hand — is fixture-only and is marked as such.

Never live in the V1 pool, and implemented exactly anyway: the Nomi / Spirit exclusion (the pool
has no such monster — R40 Part F and RULES_SPEC §5.5 both already record this), and the
"You can only control 1" narrowing (the pool holds exactly one copy of each such card, so a copy
in hand while another is on the field cannot arise). Both are driven against synthetic cards and
are marked as such.

**R15 is CLOSED.** It opened one activation restriction the printed English text does not carry
(Part A), one narrowing of it that only the Q&A supplies (Part B), and one resolution-time gate
that suppresses the random choice itself (Part C). It needed **no new subsystem**: three new
`EffectPrimitives` functions over the existing seeded `Rng`, the existing `revealed_to` machinery
and the existing `SummonRules` legality checks, no new event kind, no new activation location, no new permission, no new zone, no new
Summon route. The four rulings that remain — **R5, R11, R12, R14** — are all still **OPEN**, all
still belong to the four cards that remain after batch 15, and none of them was touched.

---

### R12 — `The Monarchs Awaken` — RESOLVED and CLOSED in Phase 5 batch 16

**R12 was carried OPEN across thirteen checkpoints.** §4 opened it with one line — *"'If you have
no cards in your Extra Deck' is an activation condition; grants 'unaffected by the effects of
cards other than this card' — a broad immunity that must be applied in the rules layer"*. Both
halves survive and are implemented exactly. What the line did **not** contain is an **activation
restriction the printed English text does not carry**, a **resolution-time face-up gate that kills
both clauses at once**, an explicit **duration**, a general rule that makes the immunity far
**narrower** than the English phrase suggests, and an **authoritative correction to the engine's
own answer** about what "Tribute Summoned" means.

**§8's standing warning was right for a SIXTH batch in a row.** *Look for an activation
restriction the printed English text does not carry.* This card's is
**「ダメージステップには発動できません。」** — it cannot be activated during the Damage Step. The
printed English text says nothing about the Damage Step. (`Burst Stream of Destruction`,
`Damage Condenser`, `Honest`, `Witchcrafter Golem Aruru`, `A Hero Emerges`, now
`The Monarchs Awaken`.) Unlike the previous five, this one is satisfied by the engine's **default**
`DamageStepPermission.NONE` rather than by new machinery — but it is a fact about the card, it was
never asserted, and batch 16 asserts it.

**Sources.** All PRIMARY (official Konami), fetched **2026-09-09** with `request_locale=ja` per
R40's methodology note. None is the `en` boilerplate R40 warns about. The raw captures are cached
under `Data/generated/konami_raw/` (untracked, per `.gitignore`).

| Source | What it gives | Date on the page |
|---|---|---|
| `faq_search.action?ope=4&cid=10963&request_locale=ja` — card text + 補足情報 | it is **this card's activation-time effect**; it **cannot be activated in the Damage Step**; a Tribute Summoned **Normal Monster** is a legal target and still becomes unaffected; the state lasts **as long as the monster is face-up in the Monster Zone**; if the target is **face-down at resolution** neither clause applies | **2015-09-19** |
| `faq_search.action?ope=5&fid=11352&request_locale=ja` — 「帝王の凍志」 is named in its own answer | a monster that went **face-down and back face-up**, or was **temporarily banished and returned** to the Monster Zone, is **still treated as Tribute Summoned**; and a monster **Tribute Set** face-down that later turns face-up is too | **2026-01-23** |
| `faq_search.action?ope=5&fid=11871&request_locale=ja` — 「真紅眼の凶雷皇－エビル・デーモン」 | a Gemini monster treated as a Normal Monster is a legal target; the negation switches off even its *identity* effect; the immunity applies alongside — i.e. **this card's own negation is not blocked by the immunity it grants** | **2017-03-24** |
| `faq_search.action?ope=5&fid=20548&request_locale=ja` — 「真竜剣皇マスターP」 Tribute **Set** | a monster Tribute **Set** is 「アドバンス召喚されたカードとして扱われます」; once flipped face-up every "Advance Summoned" condition applies to it | **2017-03-24** |
| `faq_search.action?ope=5&fid=20533&request_locale=ja` — 「ドラゴニックD」 | the same, **while it is still face-down** — the property does not wait for the flip | **2017-03-24** |
| `faq_search.action?ope=5&fid=13065&request_locale=ja` — 「神竜騎士フェルグラント」, the **same construction** | the effect is **activated, targets and resolves normally**; only the sub-processes that **apply to that monster** are skipped; sub-processes of the same effect that apply to **another** card still happen | **2025-05-04** |
| `faq_search.action?ope=5&fid=17304&request_locale=ja` — 「真竜剣皇マスターP」 / 「無償交換」 | an immune monster's effect activation **cannot be negated** by a card it is immune to; the negating card still activates, still resolves, and its **other** processes still apply | **2017-04-20** |
| `faq_search.action?ope=5&fid=18199&request_locale=ja` — 「ヴェルズ・タナトス」 / 「月光舞猫姫」 | a **lingering protection** granted by another card does **not** reach an immune monster at the moment it would apply — it was destroyed by battle as normal | **2017-03-24** |
| `faq_search.action?ope=5&fid=13085&request_locale=ja` — 「マドルチェ・エンジェリー」 / 「神竜騎士フェルグラント」 | an effect that had **already applied** before the immunity began is **not** undone by it — the delayed return to the Deck still happens | **2017-03-24** |
| `faq_search.action?ope=5&fid=16491&request_locale=ja` — 「古代の機械魔神」 / 「アンクリボー」 | the same conclusion from a **permanent** immunity: "sent to the GY in the End Phase" was applied at the Special Summon and still happens | **2019-03-04** |
| `faq_search.action?ope=5&fid=298&request_locale=ja` — 「海亀壊獣ガメシエル」 | an immune monster **can be Tributed** by the opponent as part of a Summon procedure — 「相手モンスターに適用する効果として扱われません」 | **2026-03-20** |
| `faq_search.action?ope=5&fid=23510&request_locale=ja` — 「超融合」 | an immune monster **cannot be taken as Fusion Material by an opponent's effect**, and with no legal material set the activation itself is illegal | **2026-07-17** |

cid 10963 has a real Q&A section with **exactly 2** entries — confirmed twice, from the card page
and from a 「帝王の凍志」 Q&A-text search that returned 「検索結果 2件」 — so the
「このカードに関連するＱ＆Ａはありません」 absence shape R40 records does not apply here. **Both
entries were read, and each settled a question the supplement does not answer.** The remaining ten
sources are the **general** 「効果を受けない」 rulings, and they are what settle the question §8 said
"must be taken from the source, not from the phrase".

**The English text was re-fetched from the live database on 2026-09-09 and diffed against the
persisted text in `Data/cards/cards.json`** — the same procedure batches 13, 14 and 15 used. It
matches **character for character**, so nothing below rests on a stale transcription.

**Official English text.**

> "If you have no cards in your Extra Deck: Target 1 face-up Tribute Summoned monster you control;
> its effects are negated, also it is unaffected by the effects of cards other than this card."

**Official Japanese text.**

> ①：自分のエクストラデッキにカードが存在しない場合、自分フィールドのアドバンス召喚した表側表示モンスター１体を対象として発動できる。そのモンスターは効果が無効になり、このカード以外の効果を受けない。

**Official supplement (補足情報), 2015-09-19, quoted in full.**

> 【①の効果について】
> ■このカードの発動時の効果です。
> ■ダメージステップには発動できません。
> ■アドバンス召喚された通常モンスターを対象に発動することもできます。（その場合でも、対象のモンスターはこのカード以外の効果を受けなくなります。）
> ■この効果が適用されたモンスターはモンスターゾーンに表側表示で存在する限り、効果が無効になり、このカード以外のカードの効果を受けなくなります。
> ■処理時に、対象のモンスターが裏側守備表示の場合、効果は無効にならず、『このカード以外の効果を受けない』効果は適用されません。

#### Part A — the fact the English text does not carry: NO Damage Step activation. Confidence: HIGH.

> ■ダメージステップには発動できません。
> *It cannot be activated during the Damage Step.*

The printed English text carries no Damage Step wording at all. The engine's
`DamageStepPermission.NONE` is the default and already produces this behaviour, so — unlike the
five previous cards in this series — **no new machinery is needed**. That is precisely why it is
worth an explicit assertion: a default that happens to be right is indistinguishable from a
default nobody checked, and a later batch that reached for `UNTIL_DAMAGE_CALC` because the card
"changes a monster's state" would have broken it silently. `MonarchsAwakenTests` asserts it
directly, at the Damage Step sub-steps where a Trap could otherwise be offered.

#### Part B — what "unaffected by the effects of cards other than this card" actually reaches. Confidence: HIGH.

§8 asked the right question — *does it stop an effect from **targeting** the monster, from
**resolving** on it, or only from **applying** to it?* — and predicted Konami's answer would be
"narrower than English readers expect". **It is, and the answer is the third one.**

fid 13065 is the decisive source because it is the **same construction on another card**:
Divine Dragon Knight Felgrand reads 『選択したモンスターの効果は無効になり、このカード以外のカードの
効果を受けない』, which is `The Monarchs Awaken`'s second clause word for word. Genome Heritor then
targets a monster in that state:

> 「No.8 紋章王ゲノム・ヘリター」の『元々の攻撃力がそのモンスターの攻撃力と同じになり、そのモンスターの元々のカード名・効果と同じカード名・効果を得る』処理は、エンドフェイズまで通常通り適用されます。（対象のモンスターの攻撃力と同じになる処理や、カード名・効果を得る処理は、そのモンスターに適用する効果ではありません。）
> なお、『その後、対象のモンスターの攻撃力は０になり、効果は無効化される』効果は、そのモンスターに適用する効果ですので、モンスター効果を受けないモンスターには適用されません。

Three separate facts, and all three are load-bearing:

1. **Targeting is NOT blocked.** The opponent's effect targets the immune monster and is legally
   activated. Immunity is not targeting protection — the engine already has a *separate*
   `cannot_be_targeted` flag for that, and the two must not be conflated.
2. **Resolution is NOT blocked.** The Chain Link resolves.
3. **Only the sub-processes that APPLY TO THAT MONSTER are skipped**, one at a time. In the quoted
   answer the ATK-copy and name-copy processes apply (they apply to *Genome Heritor*), and the
   "that monster's ATK becomes 0 and its effects are negated" process does not (it applies to the
   immune monster). **One effect, two sub-processes, opposite answers.**

fid 17304 confirms 1–3 from the other direction: a Trap that would "negate that activation and
destroy it" fails to do either to a monster immune to Traps, the monster's own effect resolves as
normal, **and the Trap's unrelated "your opponent draws 1 card" process still applies**.

fid 298 draws the outer boundary: an immune monster **can be Tributed** by the opponent as part of
a Kaiju's Summon procedure, because 「相手モンスターに適用する効果として扱われません」 — that
Tribute is not an effect applied to the monster. **A cost is not an application.** The engine
already keeps these apart on purpose (batch 4: `pay_banish_cost()` vs `banish_target()`;
`pay_tribute_cost()` vs everything else), so the gate goes on the effect primitives and stays off
the cost primitives.

fid 23510 draws the boundary on the other side: an immune monster **cannot be taken as Fusion
Material by an opponent's effect** — there the effect really is being applied to it.

fid 18199 settles **battle**: an immune monster is destroyed by battle exactly as normal.
Battle destruction is not a card effect. What that Q&A actually shows is stronger and is recorded
in Part C.

**Summary of Part B, as implemented.** The immunity blocks an effect from **applying** to the
monster, and blocks nothing else:

| Category | Blocked? | Source |
|---|---|---|
| Being **targeted** / selected by an effect | **NO** | fid 13065 |
| The effect **activating** and **resolving** | **NO** | fid 13065, fid 17304 |
| Destruction **by a card effect** | **YES** | fid 13065 (general application rule) |
| Destruction **by battle** | **NO** | fid 18199 |
| Being **moved** by an effect (bounce, banish, send to GY) | **YES** | fid 23510 |
| **Control** change by an effect | **YES** | general application rule |
| **ATK/DEF** change by an effect | **YES** | fid 13065 (「攻撃力は０になり」) |
| Its effects being **negated** by another card | **YES** | fid 13065, fid 17304 |
| Its effect activation being **negated** by another card | **YES** | fid 17304 |
| A **restriction** (cannot attack, cannot be targeted, …) applied by another card | **YES** | fid 18199 |
| A **protection** granted by another card | **YES** — it does not receive it either | fid 18199 |
| Being **Tributed** as a cost or for a Summon procedure | **NO** | fid 298 |
| Sub-processes of the same effect that apply to **another** card | **NO** | fid 13065, fid 17304 |
| An effect that **already applied** before the immunity began | **NO** — not undone | fid 13085, fid 16491 |

**The immunity is a shield, not a blessing.** fid 18199 is the entry the phrase "unaffected"
misleads English readers about most: Lunalight Cat Dancer's *"your opponent's monsters are each
not destroyed by battle once this turn"* is a **benefit**, and the immune monster **does not get
it** and is destroyed by battle. Immunity does not filter for the monster's advantage; it refuses
everything from other cards, helpful or not.

#### Part C — WHEN an effect counts as "applying", and what "already applied" means. Confidence: HIGH.

Three Q&A entries look contradictory until the rule behind them is stated:

* fid 18199 — a lingering "not destroyed by battle once this turn" granted by another card's
  already-resolved effect **does not reach** the immune monster;
* fid 13085 — a lingering "return it to the Deck in the End Phase of your next turn" attached by
  another card's already-resolved effect **does reach** it;
* fid 16491 — the same as 13085, from a **permanent** immunity rather than a granted one.

The rule that produces all three: **an effect applies to a monster at a definite moment. If the
monster is immune at that moment, it does not apply. An application that COMPLETED before the
immunity began is not undone, even when its consequence lands later.**

Cat Dancer's protection has to apply *at the moment of battle destruction* — the immunity is
already up, so it does not. Madolche Anjelly's and Unclabby's clauses applied *at the moment of
the Special Summon* — before the immunity existed — and the later send is only the consequence
being collected. This is exactly the distinction the engine already draws between a **continuous
effect** (recomputed, therefore re-applied every time, therefore gated) and a **fact recorded on
the instance** (`banish_when_it_leaves_the_field`, `banish_leases`, `battle_phase_skips` — written
once, therefore not gated). No new concept is needed to honour it: gating the continuous layer and
leaving recorded obligations alone reproduces all three answers.

**A caution about a near-miss source.** fid 23491 (2026-07-17) answers that Skill Drain, Snatch
Steal and their kind **do** apply to a monster with 『発動した効果を受けない』, because those
effects "begin applying at the resolution of the chain block that activated the card and continue
to apply afterwards". **That entry is about a DIFFERENT, narrower immunity** — *unaffected by
**activated** effects* — and it does **not** govern `The Monarchs Awaken`, whose clause is the
unrestricted 『このカード以外の効果を受けない』. It is recorded here so that a later batch does not
find it, mistake it for this card's rule, and conclude that continuous effects pierce this
immunity. They do not: fid 18199 is the entry that governs, and it says the opposite for the broad
form. **Do not narrow Part B on the strength of fid 23491.**

#### Part D — "other than this card": the source is exempt, and it stays exempt from the Graveyard. Confidence: HIGH.

§8 flagged the exemption as load-bearing rather than decorative, because the first clause negates
the monster's effects and the immunity must not switch that negation off. **It does not**, and the
supplement says so twice over:

> ■この効果が適用されたモンスターはモンスターゾーンに表側表示で存在する限り、**効果が無効になり**、このカード以外のカードの効果を受けなくなります。

Both states are named in one sentence as coexisting. fid 11871 then shows them coexisting on a real
board: a Gemini monster treated as a Normal Monster is targeted, and 「そのデュアルモンスターの
『①：このカードはフィールド・墓地に存在する限り、通常モンスターとして扱う』効果が無効になり」 — the
negation reaches even the monster's *identity* effect — 「（結果的に、…『このカード以外のカードの効果
を受けない』状態になります。）」.

**And `The Monarchs Awaken` is a Normal Trap that is in the Graveyard by the time any of this
matters.** §8 asked whether an effect applied by a card that is no longer on the field still counts
as "this card". The supplement answers it by never mentioning the Trap again: the duration clause
is 「モンスターゾーンに表側表示で存在する限り」 — a statement about **the monster**, with no
condition on the Trap at all. The negation and the immunity both outlive their source. The engine
models this correctly already and for the right reason: `unaffected_by_effects` and
`effects_negated` are per-instance fields on `CardInstance`, **not** `ContinuousEffects` restriction
flags, so no recompute can wipe them when the source leaves.

The exemption is therefore an identity, not a zone test: the exempt card is **the specific
`The Monarchs Awaken` instance that applied the state**, wherever it now is. That is why the engine
records an exempt **instance id** and not a card name and not a "is the source still on the field"
check.

**The monster's own effects.** §8 asked whether the immunity covers them. Read literally it does —
the monster is not `The Monarchs Awaken`, so its own effects are "effects of cards other than this
card" — and the generic gate implements exactly that literal reading. The question is moot on this
card, because the first clause has already negated those effects, and it is recorded here only so
that a future card worded *"other than itself"* is given a **different exempt id** rather than
being assumed to share this one.

#### Part E — duration, and the resolution-time face-up gate. Confidence: HIGH.

§8 called the engine's reset points *"a guess baked into the engine"* and demanded they be confirmed
rather than trusted. **They are confirmed, and they are right.**

> ■この効果が適用されたモンスターはモンスターゾーンに表側表示で存在する限り、効果が無効になり、このカード以外のカードの効果を受けなくなります。
> *As long as the monster this effect applied to exists **face-up in the Monster Zone**, its effects are negated and it does not receive the effects of cards other than this card.*

Two end conditions, and exactly two: **leaving the Monster Zone** and **stopping being face-up**.
`CardInstance.on_leave_field()` and `on_flipped_face_down()` already clear both
`effects_negated` and `unaffected_by_effects`, which is precisely this rule.

Three things the duration is **not**, all of which the engine already gets right and none of which
was previously asserted:

* **not** "until the end of the turn" — it survives into later turns;
* **not** "while `The Monarchs Awaken` is on the field" — see Part D;
* **not** restored by flipping the monster face-up again. Once an end condition is met the state is
  gone; a later Flip Summon does not bring it back. This follows from 「限り」 naming a *state to be
  maintained*, and it is what `on_flipped_face_down()` clearing the field (with nothing that ever
  re-sets it) already does.

A **control change** is deliberately **not** an end condition. The supplement names the Monster
Zone and face-up-ness and nothing else, and a monster that changes control has not left the Monster
Zone. `MonarchsAwakenTests` asserts the state survives an `Enemy Controller` swap in both
directions.

**And the resolution-time gate is a separate, sharper fact:**

> ■処理時に、対象のモンスターが裏側守備表示の場合、効果は無効にならず、『このカード以外の効果を受けない』効果は適用されません。
> *If, at resolution, the target monster is face-down Defense Position, its effects are not negated and the "unaffected by the effects of cards other than this card" effect is not applied.*

The target is locked in at activation while face-up; if the opponent flips it face-down in response,
**both** clauses fail and the Trap is spent for nothing. Note what this is **not**: it is not
R10.8's "an activation requirement that fails by resolution kills the whole effect" — there is no
activation requirement in play here — and it is not a target that has ceased to exist. It is the
narrower, per-clause statement R10.6 established for `Witchcrafter Golem Aruru` — *a target that has
gone bad does not automatically kill the whole effect* — reached here by the card's own supplement
naming both clauses explicitly. `RULES_SPEC.md` §10.9 records it.

#### Part F — "Tribute Summoned": the AUTHORITATIVE correction to the engine's own answer. Confidence: HIGH.

§8 asked *"is a monster that was Tribute **Set** and later flipped face-up 'Tribute Summoned'?"* and
recorded the engine's current answer as **no** — `Enums.SummonKind` keeps `TRIBUTE` and
`TRIBUTE_SET` apart, and `_complete_flip_summon()` overwrites `summoned_by` with `FLIP`. §8 also
said the answer was **untested**.

**The engine's answer is WRONG.** fid 20548 could not be more direct:

> 「真竜剣皇マスターP」をアドバンス召喚する際に、モンスター2体をリリースして、裏側守備表示でセットしました。…
> 質問の状況の場合でも、「真竜剣皇マスターP」は**アドバンス召喚されたカードとして扱われます**ので、その後にリバースし、表側表示になった場合、…モンスター効果は適用され…

and fid 20533 extends it to the monster **while it is still face-down**: Dragonic D's *"Advance
Summoned 'True Draco' monsters are not destroyed by battle once per turn"* applies to a monster
that was Tribute Set and has not yet been flipped.

fid 11352 — which **names 「帝王の凍志」 in its own answer**, in the list of cards whose text is
conditioned on having been Advance Summoned — adds the two persistence cases:

> アドバンス召喚したモンスターが表側表示から裏側守備表示になった場合（その後、表側表示に戻った場合）や、一時的に除外されてモンスターゾーンに戻った場合でも、引き続きアドバンス召喚したモンスターとして扱われたままとなります。

So **all four** of these are "Tribute Summoned" for this card:

1. Tribute Summoned face-up — the obvious case;
2. Tribute **Set**, then flipped face-up — fid 20548;
3. Tribute Summoned, flipped face-down, flipped face-up again — fid 11352 (the `FLIP` overwrite must
   not erase it);
4. Tribute Summoned, **temporarily** banished, returned to the Monster Zone — fid 11352.

Case 4 is a genuine interaction with **R30**. R30 established that a temporarily banished monster
"genuinely left the field" and comes back without its equips, counters, modifiers or control
leases. That stands — but fid 11352 says the **Tribute Summoned property specifically survives the
round trip**. The two are not in conflict: R30 is about state applied *to* the monster, this is
about how the monster *arrived*. `Interdimensional Matter Transporter` is the pool card that makes
case 4 reachable, and `MonarchsAwakenTests` exercises it on real cards.

Case 5, stated for completeness and **not** covered by the above: a monster that leaves the field
**permanently** and is later summoned again is a new arrival and is **not** Tribute Summoned unless
it is Tribute Summoned again. `on_leave_field()` clears the property, which is right.

**What the correction changes.** `card.summoned_by` is read by exactly one card in the repository
(`RunickFlashingFire`, which asks for `SPECIAL`), so recording the Tribute-Summoned property
separately changes **no existing behaviour**. The new `CardInstance.tribute_summoned` is written by
`SummonRules` on both the `TRIBUTE` and `TRIBUTE_SET` routes, is **not** cleared by
`on_flipped_face_down()`, **is** cleared by `on_leave_field()`, and is carried across a temporary
banishment by the existing `banish_leases` record — the same mechanism that already carries the
return position and controller.

#### Part G — the activation condition, and the Normal Monster target. Confidence: HIGH for the target, MEDIUM for the check timing.

**"If you have no cards in your Extra Deck"** is an activation condition
(「自分のエクストラデッキにカードが存在しない場合、…発動できる」). No official source found in this
research states whether it is re-checked at resolution, and **both decks in the V1 pool have empty
Extra Decks, so it is never false** — the same never-false shape R1 records for
`Runick Flashing Fire`. It is implemented exactly anyway, as a condition checked **at activation**,
which is the default reading for a 「場合」 clause standing before 「発動できる」. It is tested against
a **synthetic** Extra Deck rather than against the pool, and the resolution-time behaviour is
deliberately **not** asserted, because no source settles it. **Confidence MEDIUM, and it is
recorded as MEDIUM rather than quietly promoted.**

**A Tribute Summoned Normal Monster is a legal target**, and the immunity still applies to it even
though the negation has nothing to negate:

> ■アドバンス召喚された通常モンスターを対象に発動することもできます。（その場合でも、対象のモンスターはこのカード以外の効果を受けなくなります。）

This matters because it forbids an "optimisation" that would look reasonable: refusing a target
whose effects cannot be negated. The V1 pool has nine vanillas and several are Level 5+, so this is
live on real cards, not synthetic ones. fid 11871 is the same point from the other end — a Gemini
monster *treated as* a Normal Monster is also a legal target, and there the negation is very far
from vacuous.

#### What R12 leaves OPEN

**Nothing that blocks the card.** One item is recorded as MEDIUM rather than HIGH and is named
above: whether the Extra Deck condition is re-checked at resolution. It cannot be reached in the V1
pool from either deck.

---

### R11 — `Fairy Tail - Luna` — RESOLVED and CLOSED in Phase 5 batch 17

**Opened** in §4 as *"Opponent may send a card with the targeted monster's name from Deck/Extra
Deck to the GY **to negate this effect** — an opponent-side decision **during resolution**."* That
was right about the shape and, as usual, nowhere near complete.

#### Sources — all PRIMARY (official Konami), all fetched for this batch under `request_locale=ja`

| Source | What it gives | Date on the page |
|---|---|---|
| `card_search.action?ope=2&cid=12952&request_locale=en` — the live **English** text | re-fetched and diffed **character for character** against `Data/cards/cards.json` and `Data/generated/konami_cards.json`: **identical, 378 characters**, no drift | fetched 2026-09-09 |
| `card_search.action?ope=2&cid=12952&request_locale=ja` — the live **Japanese** text | 「①：このカードが召喚した時に発動できる。デッキから攻撃力１８５０の魔法使い族モンスター１体を手札に加える。②：自分・相手ターンに１度、相手フィールドの表側表示モンスター１体を対象として発動できる。相手はそのモンスターの同名カード１枚を自身のデッキ・EXデッキから墓地へ送ってこの効果を無効にできる。墓地へ送らなかった場合、このカードと対象のモンスターを手札に戻す。」 | fetched 2026-09-09 |
| `faq_search.action?ope=4&cid=12952&request_locale=ja` — 補足情報, **eight** bullets | effect kinds; the Damage Step ban; the both-or-nothing resolution re-check; the face-up requirement for the offer; the face-down case; the unaffected case | **2022-03-26** |
| `faq_search.action?ope=5&fid=11022&request_locale=ja` | 「灰流うらら」 may be chained to clause ②'s activation — ② is an ordinary activation on the Chain and the opponent's send is **not** a Chain Link | 2017-09-28 |
| `faq_search.action?ope=5&fid=20472&request_locale=ja` | under 「マクロコスモス」 the opponent **cannot perform** the send at all — 「同名カードが存在していたとしても、その同名カードをデッキから選ぶこと自体ができません」 — and the return then happens | **2024-06-23** |
| `faq_search.action?ope=5&fid=262&request_locale=ja` | a **Monster Token** is a legal target; it ceases to exist on leaving the field and Luna 「自身は通常通り持ち主の手札に戻る」 | 2017-03-24 |

None is the `en` boilerplate R40's methodology note warns about; each response is card-specific and
names 「妖精伝姫－カグヤ」 in its own text. The card has three related Q&A entries and all three were
read, so the 「このカードに関連するＱ＆Ａはありません」 absence shape R40 records does not apply.

#### Part A — clause ② CANNOT be activated during the Damage Step. Confidence: HIGH.

「■ダメージステップ中には発動できません。」 **The printed English text says nothing about the Damage
Step.** That is now **seven batches running** in which the official supplement carried an activation
restriction the English print does not (`Burst Stream of Destruction`, `Damage Condenser`, `Honest`,
`Witchcrafter Golem Aruru`, `A Hero Emerges`, `The Monarchs Awaken`, and now this).

As with `The Monarchs Awaken`, the restriction is satisfied by the engine's **default**
(`DamageStepPermission.NONE`), so it needed no machinery. It is written out on the clause anyway and
asserted directly against `ActivationRules.damage_step_ok()` at all five Damage Step sub-steps, with
a control clause that IS permitted in one of them — a default that happens to be right is
indistinguishable from a default nobody checked.

Both clauses' effect kinds come from the same source: 「■モンスターゾーンで発動できる誘発効果です。」
for ①, 「■モンスターゾーンで発動できる誘発即時効果です。」 for ②. So ① is a Trigger Effect and ② a
Quick Effect, both activated **face-up in the Monster Zone** and nowhere else.

#### Part B — "from their Deck or Extra Deck". Confidence: HIGH; the Extra Deck half is NEVER LIVE.

Two zones and only two — not the hand, not the Graveyard. Both are private to the deciding player,
which is what makes this a hidden-information operation and not merely a routing one.

**Both V1 Extra Decks are empty**, asserted directly from `Data/decks/deck1.json` and `deck2.json`,
so the Extra Deck half can never be live in a real duel between these decks. It is implemented in
full and exercised against a synthetic Extra Deck card, and the test says so out loud — the
R1 / R21 / R23 treatment.

**§8's prediction that the whole negation branch is unreachable is WRONG, and this is the
correction.** §8 reasoned that "deck 2 holds one copy of each card, so a card with the same name as
a monster on the field cannot also be in the Deck". Both decks do in fact hold a duplicate:
`Blue-Eyes Dragon Guard` runs **two `Mirage Dragon`** and `Fairy-Tail Tribute Guard` runs **two
`Metaphys Armed Dragon`**. A deck-2 `Fairy Tail - Luna` targeting a deck-1 `Mirage Dragon` therefore
faces an opponent who really can send the second copy, and the negation is tested on exactly that
board with the duplicate count asserted against `Data/cards/cards.json`.

#### Part C — "1 card with that monster's name" is the CURRENT name. Confidence: HIGH; never live.

Implemented as `EffectPrimitives.has_name_of()`, reading `CardInstance.card_name()`. **Nothing in
the V1 pool is ever treated as having another card's name**, so the current name and the printed
name coincide here; the coincidence is asserted against the real pool so it cannot rot silently.
This is the same treatment R40 Part F gives "non-Effect Monster" and the same reading R40 Part G
took for `Dragon Shrine` — the test is applied to the card **as it is now**, not to its print.

The check is on the NAME and on nothing else: a different copy with different Level and ATK matches,
and the targeted monster's own instance is not special.

#### Part D — the offer exists only while the target is FACE-UP; a face-down target is still returned. Confidence: HIGH.

Two bullets, from both directions:

> ■処理時に、このモンスターと対象のモンスターがモンスターゾーンに存在する場合、『このカードと対象の
> モンスターを持ち主の手札に戻す』処理を行います。**ただし、対象のモンスターがモンスターゾーンに表側
> 表示で存在する場合**、相手はその同名カード１枚を自身のデッキやエクストラデッキから墓地へ送ることで
> この効果を無効にできます。

> ■処理時に、**対象のモンスターが裏側守備表示になった場合**、相手は対象の同名カードを墓地へ送ること
> ができず、『このカードと対象のモンスターを持ち主の手札に戻す』処理を行います。

So a target flipped face-down between activation and resolution **is still returned** — it is still
in the Monster Zone — and its controller simply loses the chance to stop it. The obvious
implementation, `surviving_target()` plus "is it still face-up", would have been wrong in **both**
directions: it would have dropped a return the card performs, and it would have offered a negation
the card does not.

#### Part E — the resolution-time re-check is BOTH-OR-NOTHING and names the MONSTER ZONE. Confidence: HIGH for the zone, MEDIUM for the absence of a control re-check.

> ■処理時に、このカードと対象のモンスターのうち**少なくとも片方**がモンスターゾーンに存在しなくなった
> 場合、**処理は行われません**（相手は対象の同名カードを墓地へ送ることもできません）。

If **either** card has left the Monster Zone, **nothing happens at all**: no partial return of the
survivor, and the opponent is not even offered the negation. Both directions are asserted, and each
is driven by a real **Chain Link 2** the opponent activates in response rather than by poking the
board after the Chain has already resolved — the vacuous shape batch 16's mutation M15 exposed.

This is the case `RULES_SPEC.md` **§10.6** does not cover, and it sits alongside §10.8 and §10.9 as
a fourth answer to "what does a failure at resolution cost?":

* **§10.6** — a dead **TARGET** costs only the sentences that name it;
* **§10.8** — a failed **ACTIVATION REQUIREMENT** costs the **entire** resolution;
* **§10.9** — a **property of the target the text names**, failing at resolution, costs exactly the
  clauses the card's own supplement says it costs;
* **§10.10** (new) — a clause worded **"both X and Y"** is ONE process over two cards, and a card's
  own supplement may make it **all or none**. "Both … and …" is not two sentences.

**This card does NOT inherit R29, and that is the one MEDIUM item here.** R29 decided that "1 card
your opponent controls" is re-checked for **control** at resolution. It is MEDIUM confidence and
rests mostly on `Spiritual Wind Art - Miyabi`'s own resolution sentence ("place that **opponent's**
card…"). Luna's resolution sentence names no controller — 「このカードと対象のモンスターを持ち主の
手札に戻す」 — and its supplement **enumerates the resolution-time cases in full** and names only
presence in a Monster Zone. Card-specific official guidance outranks a general inference, which is
the precedent **R40 Part C** already made load-bearing.

Recorded at MEDIUM because the evidence is an exhaustive-looking enumeration that is *silent* on
control rather than a sentence that *denies* a control re-check. It is live in the V1 pool
(`Enemy Controller` and the three Charmers can move control mid-Chain), it is asserted in both
directions, and the mutation that makes Luna inherit R29 is caught. **R29 itself is NOT reopened and
is unchanged for the two cards it was written for.**

#### Part F — the send is a RESOLUTION PROCESS, not a cost, and it can be legally impossible. Confidence: HIGH.

fid 20472 settles it. Under a 「墓地へ送られるカードは墓地へは行かず除外される」 effect the opponent
cannot perform the send **at all**, and 「自身のデッキやエクストラデッキに同名カードが存在していたと
しても、その同名カードをデッキから選ぶこと自体ができません」 — they cannot even *choose* it. The
return then happens.

Three consequences, each implemented and asserted:

* it is **not a cost**. Nothing is paid at activation, nothing is refunded, and no `COST_PAID` event
  names this card. It is a step inside the resolving effect whose legality is checked when reached;
* it is an **ordinary send to the Graveyard** (`MoveReason.SENT_TO_GY_BY_EFFECT`), so a "when this
  card is sent to the GY" trigger sees it;
* the official wording is 「**墓地へ送らなかった場合**」 — *if they did not send it*. So declining,
  having nothing to send, and a send that cannot be carried out are **the same case**, and all three
  reach the return. The engine must never distinguish "refused" from "could not".

`Macro Cosmos` is not in the V1 pool, so the third bullet's dramatic case is not live; the rule it
establishes is, and it is what makes "did not send" the right thing to measure.

#### Part G — an UNAFFECTED target costs only itself. Confidence: HIGH.

> ■『このカードと対象のモンスターを持ち主の手札に戻す』処理を行う際に、**対象のカードがこの効果を
> 受けない場合、このカードだけが手札に戻ります。**

This is batch 16's `EffectImmunity` gate seen from a second card, and it needed **no code in this
card at all**: the gate lives inside `GameState.move_card()`, so the target's return is refused and
Luna's is not. It is asserted directly, with a control board that has no immunity and returns both —
a behaviour that falls out of a shipped gate is exactly the kind that looks tested and is not.

It also confirms §18's central claim from a new angle: the effect still **activated**, still
**targeted** the immune monster, still **resolved**, and the half aimed at another card still
applied. One effect half-applies.

#### Part H — clause ①: an Advance Summon IS a Normal Summon, and the empty-search rule applies. Confidence: HIGH.

「①：このカードが**召喚**した時に発動できる」. 召喚 covers a Normal Summon with or without Tributes
[S1 p.22-23]; a Flip Summon and a Special Summon are different words and different events. The
engine already gets this right for free — `SummonRules._complete_summon()` emits
`NORMAL_SUMMON_SUCCEEDED` for both `SummonKind.NORMAL` and `SummonKind.TRIBUTE`, splitting only FLIP
and SPECIAL off — and both halves are asserted rather than assumed: that a real Tribute Summon emits
that event, and that clause ①'s own condition accepts it (evaluated directly with a
TRIBUTE-flavoured trigger event, so a condition that started filtering on `summon_kind` would fail
even though the event kind still matched).

The supplement is **silent** on whether the clause may be activated with no qualifying card in the
Deck, so the general rule applies: [S1 p.53] forbids activating an effect **in order to search** the
Deck when nothing in it meets the requirement. This clause exists to search and does nothing else,
so `EffectPrimitives.can_search_deck()` gates it — **R40 Part B**. (`The White Stone of Legend` is
the exception R40 Part C records, and it is an exception because its **own** supplement says so.)

**Clause ① is LIVE on real pool cards, which is rare.** Exactly three Spellcaster monsters with
exactly 1850 ATK exist in the pool — `Fairy Tail - Luna`, `Fairy Tail - Rella` and
`Fairy Tail - Sleeper` — and all three are in `Fairy-Tail Tribute Guard`. The filter is an **exact**
ATK and a race, so `monster_filter()`'s `max_atk` cap would have matched 1800 and 100 and
`monster_with_stats()` would have added a DEF requirement the text does not print;
`monster_with_exact_atk()` is the new sibling and the mutation that turns it back into a cap is
caught.

#### Part I — the decision-routing mechanism itself. Confidence: N/A (engineering, not a ruling).

Recorded here because the ruling is what forced it. Before batch 17, `EffectContext` had exactly one
`decider` and it was always the resolving link's controller. The generic answer is
`EffectContext.ask_player(pid, request)` over the engine's controller **table**, with
`ask()` redefined as `ask_player(controller_id, …)` — so every existing card is unchanged, which the
9459 preserved assertions demonstrate. `RULES_SPEC.md` **§12.4** is the normative statement, and the
gate is the opponent-decision section of `HiddenInfoTests`, written and green before this card
existed.

The hidden-information half is the part that is easy to get wrong twice:

* a player with **no legal payment is not asked at all**. A prompt with zero options would announce
  that their Deck holds no copy — and so, equally, would a "declined" written into the replay
  payload on behalf of somebody who was never offered anything. Both are asserted absent;
* the deciding player's Deck is **shuffled either way** [S1 p.5], whether or not they had a copy and
  whether or not they sent it. Shuffling only when a candidate existed would leak the same fact
  through a public event, and the mutation that does exactly that is caught.

#### What R11 leaves OPEN

**Nothing that blocks the card.** One item is MEDIUM and is named in Part E: the absence of a
resolution-time control re-check, taken from a supplement that enumerates the other cases and is
silent on this one. Two branches are never live in the V1 pool and are recorded rather than hidden —
the **Extra Deck** half of the payment (both Extra Decks are empty) and a **Monster Token** target
(the pool has no Tokens). A third is unreachable for an ENGINE-adjacent reason and is also recorded:
**no card in the V1 pool can negate a monster effect's ACTIVATION**, so that branch is exercised
against a synthetic negator, with the never-live claim itself asserted behaviourally —
`Champion's Vigilance` does listen to `EFFECT_ACTIVATED`, so only its refusal to be *offered* proves
it.

---

## 5. Banlist note (master prompt §51)

These are fixed casual decks built from an owned physical collection. Current Forbidden/Limited
status is **not** enforced and must not block a duel from starting. No deck list is altered.

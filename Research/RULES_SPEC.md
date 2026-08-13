# RULES_SPEC — Implementable specification of the current TCG rules

Every statement here is traceable to a source in `RULES_SOURCES.md` (S1–S4).
Citation format: `[S1 p.41]` = Official Rulebook v10, rulebook page 41.

This document is the contract the engine implements. Where the engine deviates for a
card-specific reason, that reason is recorded in `CARD_RULINGS.md`.

---

## 1. Duel setup

| Rule | Value | Source |
|---|---|---|
| Starting LP | 8000 | [S1 p.32] |
| Starting hand | 5 cards, drawn after shuffling | [S1 p.33] |
| Main Deck size | 40–60 (both project decks are exactly 40) | [S1 p.2] |
| Copies per name | max 3 | [S1 p.2] |
| Who goes first | decided by a fair random method; winner chooses | [S1 p.33] |
| Extra Deck | 0–15; **both project decks have 0** | [S1 p.2] |

Engine: shuffling uses the seeded deterministic RNG (`Rng`), and the seed is written to the
duel log before the first draw.

---

## 2. Turn structure

Order [S1 p.34]:

```
Draw Phase → Standby Phase → Main Phase 1 → [Battle Phase] → [Main Phase 2] → End Phase
```

* Battle Phase is optional. If it is not conducted, the turn goes Main Phase 1 → End Phase
  (Main Phase 2 exists only after a Battle Phase). [S1 p.34, p.40]

### 2.1 Draw Phase [S1 p.35]
* Turn player draws 1.
* **The player who goes first does not draw during the Draw Phase of their first turn.**
* A player who must draw and cannot **loses the Duel**. [S1 p.33, p.35]

### 2.2 Standby Phase [S1 p.34]
* Resolve effects that activate in the Standby Phase.
* Fast effects may be activated.

### 2.3 Main Phase 1 / Main Phase 2 [S1 p.36, p.40]
Permitted actions:
* Normal Summon **or** Normal Set — **once per turn total**. [S1 p.24]
* Flip Summon (unlimited count). [S1 p.24]
* Special Summon (unlimited count, subject to card conditions). [S1 p.24]
* Manual battle position change (see §5.3).
* Activate cards/effects.
* Set Spell/Trap cards.

Main Phase 2 restriction: any per-turn allowance already consumed in Main Phase 1 is still
consumed. [S1 p.40]

### 2.4 Battle Phase [S1 p.37]
* **The player who goes first cannot conduct a Battle Phase on their first turn.**
* Steps: Start Step → (Battle Step → Damage Step)* → End Step. [S1 p.37]

### 2.5 End Phase [S1 p.40]
* Resolve "during the End Phase" effects.
* **Hand size limit 6** — discard down to 6 at the end of the phase.
* Fast effects may be activated.

---

## 3. Fast Effect Timing state machine [S2]

Transcribed from the official flowchart. This is the engine's master control loop.
The engine implements this literally as a state machine; it does **not** implement the
obsolete Ignition-Effect-priority model.

### Box A — Open game state
> "The game state is open. The turn player may perform any appropriate action.
> (Every Phase and Step begins here.)"

From A the turn player takes exactly one of three branches:

| Branch | Meaning |
|---|---|
| A1 | Turn player takes an action that does **NOT** start a Chain — Normal Summon/Set, Set a card, Special Summon that does not start a Chain, declare an attack, change battle position, etc. |
| A2 | Turn player activates a card or card effect that **starts a Chain** — Spells, Traps, Spell/Trap effects, or Monster Card effects of any Spell Speed. → go to **D** |
| A3 | Turn player passes. → go to **E** |

### A1 branch — trigger check
> "Does this activate a triggered effect? (Monster Trigger Effects, Continuous Spells/Traps
> that trigger)"

* **YES** → go to **D** (the triggered effects form the start of the Chain).
* **NO** → go to **B**.

### Box B — Turn player may activate a fast effect
* If the turn player **activates** → go to **D**.
* If the turn player **passes** → go to **C**.

### Box C — Opponent may activate a fast effect
* If the opponent **activates** → go to **D**.
* If the opponent **passes** → return to **A** (open game state).

### Box D — Chain rules
> "Build, then resolve, the Chain. The effects that started the Chain go at the bottom of the
> Chain. Build the Chain from there, starting with the player who did NOT activate the most
> recent Chain Link. As you build the Chain, players may add to the Chain, or pass. If both
> players pass in a row, resolve the Chain."

After the Chain resolves → return to the **A1 trigger-check node** (labelled
"After a Chain Resolves" in the chart), i.e. newly created triggers are collected and may form
a new Chain; if none, flow proceeds to **B**.

### Box E — Turn player passed
* Opponent may activate a fast effect. If they **activate** → go to **D**.
* If they **pass** → "Do both players agree to move to the next Phase/Step?"
  * **NO** → return to **A**.
  * **YES** → "End of Phase/Step. Proceed to the next Phase/Step." (If the End Phase just
    ended, it becomes the opponent's turn, starting with the Draw Phase.)

### Engine consequences
1. A response window is offered **whenever a player has at least one legal fast effect**
   (Full Response Mode, master prompt §11). Passing is always legal.
2. A summon never returns straight to an open game state while pending triggers or legal
   responses exist (master prompt §23) — this falls out of the A1 → trigger-check → D/B/C path.
3. Chain building alternates starting from the player who did **not** activate the most recent
   Chain Link, and closes only after **two consecutive passes**.
4. New Chains are never started mid-resolution; events raised during resolution are queued and
   processed at the "After a Chain Resolves" node. (master prompt §45)

---

## 4. Chains and Spell Speed

### 4.1 Chain construction [S1 p.44, p.46; S2]
* Chain Link 1 = first activation. Each subsequent activation is the next Chain Link.
* To respond, an effect must be **Spell Speed ≥ 2** **and** **≥ the Spell Speed of the previous
  Chain Link**. [S1 p.44]
* The Chain closes when both players pass consecutively.
* Resolution is **strictly reverse order**: highest Chain Link first, down to Chain Link 1.
  [S1 p.46–47]

### 4.2 Spell Speed table [S1 p.44–45]

| Spell Speed | Card / effect categories |
|---|---|
| 1 | Spells (Normal, Equip, Continuous, Field, Ritual); Effect Monster **Ignition**, **Trigger**, and **Flip** effects |
| 2 | Traps (Normal, Continuous); Quick-Play Spells; Effect Monster **Quick Effects** |
| 3 | **Counter Traps** |

Rules:
* Spell Speed 1 cannot be activated in response to anything. It can only be Chain Link 2+ when
  multiple Spell Speed 1 effects are activated **simultaneously**. [S1 p.44]
* Only Spell Speed 3 may respond to Spell Speed 3. [S1 p.45]

Engine note (master prompt §13): Spell Speed is stored **per effect definition**, not inferred
from the card's category, because a monster's Quick Effect is Spell Speed 2 while that same
monster's other effects are Spell Speed 1.

### 4.3 Actions that cannot be Chained to [S1 p.51]
Summoning a monster, Tributing, changing a monster's battle position, and paying costs are
**not** effect activations and cannot be responded to as such. (Responses may still occur at
the resulting trigger-check window — see §3.)

### 4.4 Simultaneous Spell Speed 1 activations [S1 p.51]
When multiple Spell Speed 1 effects trigger off the same event, the Chain is built in this
fixed order, with the player choosing the internal order within each group:

1. Turn player's **mandatory** effects (any order chosen by turn player)
2. Opponent's **mandatory** effects (any order chosen by opponent)
3. Turn player's **optional** effects (any order chosen by turn player)
4. Opponent's **optional** effects (any order chosen by opponent)

The engine prompts for ordering whenever a group contains 2+ effects.
Optional effects are never auto-activated — the owner is asked (master prompt §24).

### 4.5 Simultaneous resolution [S1 p.51]
Where both players resolve/select at the same time, the **turn player selects first**.

---

## 5. Summoning

### 5.1 Normal Summon / Normal Set [S1 p.24]
* One Normal Summon **or** Normal Set per turn (Tribute Summon counts against this).
* Normal Summon → face-up **Attack Position**.
* Normal Set → face-down **Defense Position**; a Normal Set monster is **not "Summoned"**.
* A monster **cannot** be played from the hand in face-up Defense Position.
* Requires a free Main Monster Zone.

### 5.2 Tribute Summon / Tribute Set [S1 p.24–25]

| Level | Tributes required |
|---|---|
| 1–4 | 0 |
| 5–6 | 1 |
| 7 or higher | 2 |

* Tributes are chosen from monsters **you control**; face-up or face-down both allowed unless
  card text specifies. [S1 p.53]
* Tribute Set is not a Summon.
* Tributing is **not** destruction. [S1 p.52–53]
* Card text may modify the requirement (e.g. a monster that counts as two Tributes). Card
  effects take precedence over basic rules. [S1 p.51]

### 5.3 Battle position changes [S1 p.36]
Manual position change is legal in either Main Phase **except**:
1. the monster was played onto the field **this turn**;
2. it is Main Phase 2 and the monster **attacked** during the Battle Phase;
3. its battle position has already been changed **once this turn**.

Effect-driven position changes are not bound by these manual restrictions.

### 5.4 Flip Summon [S1 p.24]
* face-down Defense → face-up **Attack Position only**.
* Not legal the same turn the monster was Set.
* Counts as a Summon (unlimited per turn).

### 5.5 Special Summon [S1 p.24]
* Unlimited per turn.
* Default position: the summoning player's choice of face-up Attack or face-up Defense, unless
  the card specifies.
* A monster that must first be properly Special Summoned cannot be Special Summoned from
  hand/Deck/GY by another card's effect until it has been. (Not exercised by the V1 pool —
  no Extra Deck monsters — but the restriction flag is modelled.)

---

## 6. Battle Phase

### 6.1 Steps [S1 p.37–39]
```
Start Step → ( Battle Step → Damage Step )* → End Step
```
* Each face-up Attack Position monster gets **1 attack per turn** by default. [S1 p.38]
* Direct attack is legal only when the opponent controls **no** monsters. [S1 p.38]
* An attack does not have to be declared.

### 6.2 Attack replay [S1 p.39]
A **Replay** occurs when, after an attack has been declared but **before the Damage Step**,
the set of monsters the opponent controls changes (target removed, or a new monster is played
onto the opponent's field).

On a Replay the attacking player may:
* attack again with the **same** monster (re-selecting a target), or
* attack with a **different** monster, or
* **not attack at all**.

If they attack with a different monster, the original monster is still treated as having
declared an attack and **cannot attack again this turn**. [S1 p.39]

### 6.3 A monster has "battled" [S1 p.52]
Only if the attack reached **damage calculation**. If the attack is stopped before damage
calculation the monster did not "battle" — but the attack was still declared, so it generally
cannot attack again.

---

## 7. Damage Step [S1 p.41; S3]

### 7.1 Sub-steps [S3]

| # | Sub-step | What happens |
|---|---|---|
| 1 | **Start of the Damage Step** | Effects that activate "at the start of the Damage Step" |
| 2 | **Before damage calculation** | Face-down attacked monsters are flipped face-up; effects that modify ATK/DEF may activate; **flip trigger effects do not activate yet** |
| 3 | **During damage calculation** | Effects activating "during damage calculation" resolve first, then ATK/DEF comparison and battle damage; destruction is *determined* but cards are not yet sent to the GY |
| 4 | **After damage calculation** | Battle-related triggers ("when this card battles", "when battle damage is inflicted"); **Flip effects of monsters flipped face-up in sub-step 2 activate here** |
| 5 | **End of the Damage Step** | Monsters destroyed by battle are **sent to the GY**; "destroyed by battle and sent to the GY" triggers activate; "until the end of the Damage Step" modifiers expire; return to Battle Step or proceed to End Step |

### 7.2 Activation restriction [S1 p.41] — CRITICAL
> "During the Damage Step, you can only activate **Counter Trap Cards**, or **cards with
> effects that directly change a monster's ATK or DEF**. Also, these cards can only be
> activated **up until the start of damage calculation**."

Engine model: every effect definition carries an explicit `damage_step_permission` field:

| Value | Meaning |
|---|---|
| `NONE` | never activatable in the Damage Step (default) |
| `UNTIL_DAMAGE_CALC` | Counter Trap, or an effect that directly changes ATK/DEF — legal in sub-steps 1–2 only |
| `MANDATORY_TRIGGER` | triggers whose rules-mandated **timing** falls inside the Damage Step (e.g. destroyed-by-battle triggers in sub-step 5) — these are not "activated by choice" and are collected by the trigger system, not offered as a fast-effect option |

**Clarification (added when the Damage Step was implemented):** `MANDATORY_TRIGGER`
describes the *timing*, not the *optionality*. `Shining Angel`'s "when this card is
destroyed by battle and sent to the GY: You can Special Summon…" is an **optional**
Trigger Effect whose window is nevertheless inside the Damage Step, and its controller is
still asked whether to use it. The engine therefore gates this permission on the effect
being trigger-collected, not on `Optionality.MANDATORY`.

An effect with `NONE` is never surfaced during the Damage Step. There is no generic
"allow everything" path (master prompt §33).

### 7.3 Flip during battle [S1 p.41]
Attacking a face-down Defense Position monster flips it face-up in sub-step 2, DEF becomes
visible, then damage is calculated. Its Flip effect resolves in sub-step 4, and **may not
target a monster already destroyed during damage calculation**.

### 7.4 Damage calculation outcomes [S1 p.42–43]

Attacker ATK vs **Attack Position** defender ATK:

| Comparison | Result |
|---|---|
| attacker ATK > defender ATK | defender destroyed; defender's controller takes (attacker ATK − defender ATK) |
| attacker ATK = defender ATK | **both** destroyed; no damage |
| attacker ATK < defender ATK | attacker destroyed; attacker's controller takes (defender ATK − attacker ATK) |

Attacker ATK vs **Defense Position** defender DEF:

| Comparison | Result |
|---|---|
| attacker ATK > defender DEF | defender destroyed; **no damage** |
| attacker ATK = defender DEF | neither destroyed; no damage |
| attacker ATK < defender DEF | neither destroyed; attacker's controller takes (defender DEF − attacker ATK) |

Piercing damage exists only if a card grants it (none by default).

Direct attack: opponent takes damage equal to the attacker's full ATK. [S1 p.43]

**0 ATK monsters cannot destroy anything by battle.** Two 0-ATK Attack Position monsters
battling each other destroy neither. [S1 p.51]

---

## 8. Card movement semantics [S1 p.52–53]

The engine models a distinct `MoveReason` on every zone change (master prompt §19).

| Reason | Definition | "Destroyed"? | "Sent to GY"? |
|---|---|---|---|
| `DESTROYED_BY_BATTLE` | destroyed by monster battle | YES | YES |
| `DESTROYED_BY_EFFECT` | destroyed by a destruction effect | YES | YES |
| `SENT_TO_GY_BY_EFFECT` | sent by an effect without destroying | NO | YES |
| `TRIBUTED` | Tributed as cost / for a Summon | **NO** | YES |
| `DISCARDED` | hand → GY | NO | YES |
| `SENT_AS_COST` | sent to GY to pay a cost | NO | YES |
| `BANISHED` | separated from the field, not the GY | NO | **NO** |
| `RETURNED_TO_HAND` | field/GY → hand | **NO** | NO |
| `RETURNED_TO_DECK` | → Deck (top/bottom/shuffle) | **NO** | NO |
| `RULE` | rules-driven move (e.g. Equip destroyed when its target leaves) | depends | depends |

Key rulings encoded:
* A card returned from field to hand/Deck, or sent to the GY as a **cost** or **Tribute**, is
  **NOT** "destroyed". [S1 p.52]
* Destroy, discard, and Tribute **all** count as "sent to the Graveyard" for triggers. [S1 p.53]
* A **banished** card later moved to the GY is **NOT** "sent to the Graveyard". [S1 p.53]
* "Leaves the field" triggers do **not** fire when a field monster is shuffled into the Main
  Deck or becomes material. [S1 p.51]

### 8.1 When a Continuous Spell/Trap's continuous effect begins applying — **DECIDED**

Recorded as an open question during Phase 4b and resolved in Phase 4c (2026-08-12).

**Rule: a Continuous Spell/Trap's continuous effect begins applying only once that card's
own activation has RESOLVED — not at the moment of activation.**

The rulebook states that Continuous Spell Cards "remain on the field once they are
activated, and their effect continues while the card stays face-up on the field"
[S1 p.17], and says the same of Continuous Trap Cards [S1 p.18]. That sentence fixes the
*end* of the window (the card leaving the field or being turned face-down) but is written
for a beginner and does not by itself separate activation from resolution.

The separation comes from the general activation rules: activating a card places it
face-up on the field, but an activation produces no effect until its Chain Link resolves,
and resolution is strictly reverse order [S1 p.44–47]. A Continuous Spell/Trap that is
removed from the field after activation but before resolution therefore resolves without
effect. Applying the continuous clause from the moment of activation would let it affect
the resolution of Chain Links *above* it, which is exactly what the Chain rules forbid.

**Honest note on the source:** no single official sentence states the start point
verbatim. The decision rests on the rulebook's activation-vs-resolution separation
[S1 p.44–47] rather than on a quotable one-liner; the reading is the stricter of the two
candidates and is the one consistent with the Chain rules the engine already implements.

*Engine:* `ContinuousEffects._continuous_sources()` excludes a card whose own
`CARD_ACTIVATION` Chain Link is still unresolved (`activation_unresolved()`).
*Tests:* `RulesQuestionTests` — the buff is absent while Chain Link 1 is open and present
the moment it resolves.

---

## 9. Ownership vs control [S1 p.52]
* `owner` never changes.
* `controller` may change by effect; the card physically moves to the new controller's field.
* When sent to the GY or returned to hand/Deck, a card **always** goes to its **owner's**
  GY/hand/Deck.

---

## 10. PSCT semantics [S1 p.52]

> "Text before the colon gives information on conditions to activate the effect, and timing on
> when it happens. Text before a semi-colon is what you do when the effect is activated. Text
> at the end of a sentence, after all colons and semi-colons, is what you do at resolution."

Engine mapping:

| Text region | Engine stage |
|---|---|
| before `:` | **activation condition / timing** — evaluated by `can_activate` |
| between `:` and `;` | **cost + targeting** — paid/chosen at activation, before the Chain Link is created |
| after `;` | **resolution** — runs when the Chain Link resolves |

Costs are paid at **activation**, not resolution, and are **not refunded** if the activation is
negated, unless an explicit rule or card says otherwise (master prompt §16).

Additional distinctions the engine models explicitly (master prompt §15): `target` vs
`choose/select` (non-targeting), `then` vs `and if you do` vs `also` vs `after that`,
"negate the activation" vs "negate the effect", and the three once-per-turn text forms in §11.

---

## 11. Once-per-turn tracking (master prompt §47)

| Text form | Key scope | Reset |
|---|---|---|
| "Once per turn" (on the card) | per **card instance** | at the end of each turn |
| "You can only use this effect of *[name]* once per turn" | per **player + card name + effect id** | at the end of each turn |
| "You can only use each effect of *[name]* once per turn" | per **player + card name**, one slot per effect id | at the end of each turn |
| "You can only activate 1 *[name]* per turn" | per **player + card name**, activation-count | at the end of each turn |
| "Once while face-up on the field" | per **card instance**, cleared when it leaves the field or is flipped face-down | on leaving field / flip down |

Per-instance usage flags are cleared when the card changes zone or is flipped face-down unless
the specific text says otherwise (master prompt §48). Named hard-once-per-turn counters live on
the **player**, not the instance, so they survive the card leaving the field.

---

## 12. Hidden information [S1 p.50]

| Public | Private |
|---|---|
| face-up cards on the field | contents of either hand |
| both Graveyards (contents, order preserved) | identity of face-down cards |
| face-up banished cards | Deck order and contents |
| hand **counts**, Deck **counts**, LP | — |

The engine knows all state internally; `get_visible_state(viewer_id)` filters it. The UI is
only ever given a filtered view (master prompt §40).

### 12.1 `revealed_to` and the Deck — **DECIDED**

Recorded as an open question during Phase 4b and resolved in Phase 4c (2026-08-12).

`CardInstance.revealed_to` records which players have legally seen a hidden card.

**Rule: a card SHUFFLED into the Deck loses `revealed_to`. A card placed on the top or
bottom of the Deck WITHOUT a shuffle keeps it.**

The Deck is placed face-down and is never public information — only the number of cards in
it is [S1 p.5, p.28]. The rulebook requires that "if a card effect requires you to reveal
cards from your Deck, or look through it, shuffle it and put it back" [S1 p.5]: the shuffle
exists precisely so that what was seen stops being usable knowledge of where anything is.

The distinction is deliberate and is keyed on the **shuffle**, not on the Deck. A card
placed on top of the Deck without shuffling has a known position, and both players
legitimately retain what they saw, so clearing the record there would model *less*
information than the physical game gives.

*Engine:* `GameState.shuffle_deck()` clears `revealed_to` for every card in that Deck, and
`GameState.move_card()` clears it for a move whose reason is `SHUFFLED_INTO_DECK`.
*Tests:* `RulesQuestionTests` — both directions.

---

## 13. Victory conditions [S1 p.33]
* Opponent's LP reaches 0.
* Opponent must draw and cannot (deck-out).
* A card effect declares a win.
* **Both players reach 0 LP simultaneously → draw.**
* Surrender is supported as a UI action (master prompt §10).

---

## 14. Explicitly out of scope for V1 (master prompt §50)

Not implemented as player-facing features, because **no card in either deck uses them**:
Link Summoning, Pendulum Summoning, Xyz/Synchro/Fusion/Ritual Summoning, Extra Deck play,
Tokens, Xyz Materials, counters (unless a researched card requires them — re-checked in Phase 2).

The zone model and effect system still reserve Extra Deck / Extra Monster Zone slots so these
can be added later without architectural change (master prompt §49).

This is **not** a universal Yu-Gi-Oh engine. Scope statement:
**all current core TCG rules and card interactions required to play these exact two decks correctly.**

---

## 15. Facts that must outlive a card leaving the field

Per-instance state (`CardInstance.flags`, `effect_usage`, counters, modifiers) is cleared by
`on_leave_field()` [S1 p.28 model; master prompt §48]. Two families of clause in the V1 pool
need information that is destroyed by exactly the movement that makes the clause relevant, so
the engine carries it elsewhere:

**15.1 The last completed move.** `GameState.move_card()` records
`last_move_reason` / `last_move_from_zone` / `last_move_was_face_up` / `last_move_turn` /
`last_move_turn_player_id` on the instance **after** `on_leave_field()` runs, and captures the
face-up state **before** the move (a card sent to the GY is turned face-up by the move itself,
so asking afterwards answers about the destination). `Inari Fire` reads all five: "during your
next Standby Phase after this **face-up card on the field** was **destroyed by card effect**
and sent to the GY".

*"Your next Standby Phase"* is computed from `last_move_turn` and `last_move_turn_player_id`:
turns strictly alternate between two players in V1, so the qualifying turn number is
`last_move_turn + 2` when the card left on its controller's own turn and `+ 1` otherwise. If
that Standby Phase passes without the effect resolving, the window is gone — the clause names
one Standby Phase, not any later one.

**15.2 Links between two cards.** `GameState.card_memory` holds `"<key>::<card_id>" -> value`
and is not touched by any zone change. `Birthright` and `Call of the Haunted` both need to know
which monster they Special Summoned **at the moment they leave the field**, which is when
`flags` has already been cleared. `EffectPrimitives.REVIVED_MONSTER_KEY` is the key; the link is
written when the revival resolves and cleared by whichever of the two mutual triggers fires
first, so neither can fire twice off a stale reference.

---

## 16. Equip Cards [S1 p.29, p.53, p.55]

> "These cards give an extra effect to 1 **face-up** monster of your choice … The Equip Spell
> Card affects only 1 monster (called the equipped monster), but **still occupies one of your
> Spell & Trap Zones**. If the equipped monster is **destroyed, flipped face-down, or removed
> from the field**, its Equip Cards are destroyed." [S1 p.29]

> "The term 'Equip Card' includes all 3 kinds (standard Equip Spells, equipped Traps, and
> monsters equipped to other monsters). If a Monster Card is equipped to another monster, it
> remains equipped to that monster and **cannot be moved to a different target**." [S1 p.53]

Implemented in `GameState.equip_to()` / `_detach_equips()`:

| Rule | Where |
|---|---|
| The host must be a **face-up monster on the field** | `equip_to()` rejects anything else |
| The Equip Card occupies a **Spell & Trap Zone**, whatever kind of card it is | `equip_to()` moves it there face-up; no free zone ⇒ the equip fails |
| It equips to exactly one monster and **cannot be moved** | `equip_to()` refuses an already-equipped card |
| Host **leaves the field** ⇒ its Equip Cards are destroyed | `move_card()`, after the host's own events, so the log reads in causal order |
| Host **flipped face-down** ⇒ same | `set_battle_position()` — the host never moves, so `move_card()` never sees this case |
| That destruction is by the **rules**, not by a card | `Enums.MoveReason.DESTROYED_BY_RULE`, so a clause worded "destroyed by battle or card effect" does not see it |
| An **Equip Spell that resolves without equipping** does not stay on the field | `DuelEngine._cleanup_resolved_spell_traps()` |
| An Equip **Trap** that DID equip stays, despite its card kind | same place — the equip relationship wins over `Enums.stays_on_field()` |
| An Equip Card's granted effect is a **continuous** effect of the Equip Card, applied to the host | ordinary `ContinuousEffects` recompute; it ends with the Equip Card |
| "Original ATK … does not include an increase from an Equip Spell Card" [S1 p.55] | modifiers, never `base_atk` |

---

## 17. Destruction: prevention and replacement

One entry point, `GameState.destroy()`, so that "cannot be destroyed" and "destroy this card
instead" are honoured no matter who asked. It is two separable steps:

1. **`destruction_prevented(card, reason)`** — the uncounted continuous flags
   (`cannot_be_destroyed_by_battle` / `cannot_be_destroyed_by_effect`, owned by
   `ContinuousEffects`), then any **counted** prevention clause. A counted clause declares
   `EffectDef.uses_per_turn`; the rules layer spends the use, so the card's own query stays a
   pure function. `Gagagashield`: "**Twice per turn**, it cannot be destroyed by battle or card
   effects".
2. **`carry_out_destruction(card, reason, source_id)`** — any **replacement** clause, which
   returns a substitute to destroy instead. `Rider of the Storm Winds`: "If a monster equipped
   with this card would be destroyed, **destroy this card instead**." A replacement is not a
   prevention: something is still destroyed, and the substitute gets its own full check.

**Where each is asked during battle.** Destruction by battle is *determined* during damage
calculation and *carried out* at the end of the Damage Step [S3]. Prevention is asked at
**determination**, because a monster that cannot be destroyed was never determined to be
destroyed at all and must not appear in the `DAMAGE_CALCULATED` payload. Replacement is asked
at **carry-out**, because that is the moment the card "would be destroyed". Battle damage is
computed from the ATK/DEF and is unaffected by either.

Clauses that answer a rules-layer question rather than applying a modifier are recognised by
**effect id**, never by reading card text: `SummonRules.TRIBUTE_VALUE_EFFECT_ID`,
`SummonRules.CONTROL_LIMIT_EFFECT_ID`, `GameState.DESTRUCTION_PREVENTION_EFFECT_ID` and
`GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID`, listed in
`CardRegistry.RULES_QUERY_EFFECT_IDS`. Such a clause legitimately has no `apply_continuous()`,
but the registry still rejects one that answers nothing.

**"You can only control 1 …"** is enforced on **every** route onto the field — Normal Summon,
Normal Set, a summoning procedure and a Special Summon by another card — because the limit is
on what you *control* [S1 p.53], not on how the copy arrived.

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

**Three separate ways a player can be barred from conducting one**, with three different
lifetimes. They must not be collapsed into each other, and `TurnFlow.can_enter_battle_phase()`
asks all three:

| Mechanism | Lifetime | Owner | Printed by |
|---|---|---|---|
| the turn-1 rule above | the first turn only | the rules | — |
| `skip_battle_phase_this_turn` | THIS turn; wiped by `_end_of_turn_cleanup()` | a resolving effect | `Soul Exchange` ("cannot conduct your Battle Phase this turn") |
| `continuous:cannot_conduct_battle_phase` | while its face-up source applies; rebuilt on every `ContinuousEffects.recompute()` | the continuous system | a continuous source |
| `PlayerState.battle_phase_skips` | acquired at one moment, owed against a specific FUTURE turn, survives every turn boundary until then, **consumed** by the Battle Phase it costs | authoritative turn state | `Runick Flashing Fire` ("skip your next Battle Phase after activation") |

The fourth is the one added in batch 8, and it is genuinely a third shape: a turn-scoped flag
would evaporate before the turn it applies to, and a continuous restriction would lift the moment
its source left the field — and its source is a Quick-Play Spell that is in the Graveyard
immediately. **It is never a UI timer and no card polls it.**

*Which* Battle Phase it takes is decided once, when the obligation is taken on: this turn's when
the acquiring player is the turn player and their Battle Phase is still ahead of them, and from
the next turn onward otherwise (`battle_phase_conducted_this_turn` separates the two). It is spent
by `TurnFlow._spend_battle_phase_skip()` at the end of a turn in which that player was the turn
player and was not barred by the turn-1 rule — so a turn that never offered a Battle Phase does
not consume it. **CARD_RULINGS.md R1 and R32** record the whole decision with per-part confidence;
R1's "applies on activation even if the effect is negated" is why the card applies it in
`pay_cost` rather than in `resolve`.

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

### 4.6 Locking a CLASS of card for the duration of a phase — **DECIDED** (Phase 5 batch 9)

"Your opponent cannot activate Trap Cards during the Battle Phase." (`Mirage Dragon`)

Modelled as an authoritative, state-derived restriction keyed by **card category** and
**phase**, written by whatever continuous clause imposes it
(`ContinuousEffects.restrict_card_activation()`) and asked once, generically, by
`ActivationRules.card_class_activation_ok()`. **No card name appears in the legality gate** —
the same discipline as `CONTROL_LIMIT_EFFECT_ID` and `TRIBUTE_VALUE_EFFECT_ID`.

Four properties the gate pins down:

* it names a **player**: the imposing card's own controller is unaffected;
* it names a **phase**: the identical lock does not apply in Main Phase 2;
* it names a **category**: a Trap lock leaves Spells alone;
* it is **state-derived**: it lifts the instant its source leaves the field, is flipped
  face-down, or has its effects negated.

It gates **activation, not resolution.** A Chain Link created before the lock came into force
resolves normally — the restriction is asked when an activation is offered and again when it is
committed, and never afterwards.

**It locks activating a CARD, not activating an EFFECT of a card of that category.** See
`CARD_RULINGS.md` **R6 part B**, which records the reasoning and its confidence. The engine
already carries the distinction structurally: `EffectType.CARD_ACTIVATION` is the activation of
the Spell/Trap card itself, while an `IGNITION` / `QUICK` / `TRIGGER` clause of a card already
face-up on the field is the activation of an effect. The **printed** category is what counts
(`CardInstance.original_card_category()`), so a Trap currently carrying a Trap-Monster identity
(§5.8) is still a Trap for this purpose and cannot slip a card activation past the lock.

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
* A "can be treated as 2 Tributes" clause is **permission, not compulsion**, so the selection is
  validated by **enumerating complete legal combinations** rather than by computing a greedy
  maximum value and rejecting whatever looks surplus: a double-Tribute monster may count as one
  when the player needs the second card. A legal set contains at most the required number of
  cards, no duplicates, only current `tribute_candidates()`, and enough available value.
* Card text may also add a monster you do **not** control to your candidate set for the turn
  without changing control — see §5.9.

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

### 6.4 Attack PREVENTION vs attack NEGATION — **DECIDED** (Phase 5 batch 9)

Two different rules operations that must never be collapsed into one "the attack is blocked"
flag. The V1 pool contains one card of each, and they behave differently in ways a duel can
observe. Proved generically by `Tests/rules/AttackRestrictionTests.gd` before either card was
written.

| | **PREVENTION** | **NEGATION** |
|---|---|---|
| Card | `Swords of Revealing Light` ("your opponent's monsters cannot declare an attack") | `Maiden with Eyes of Blue` ("you can negate the attack") |
| When | asked **before** declaration | applies **after** a legal declaration |
| `ATTACK_DECLARED` | never emitted | **emitted** — the attack really happened |
| Response window | never opens | opens, and is where the negating effect is activated |
| `has_attacked_this_turn` | unchanged — the monster keeps its attack | **set** — the attack is spent |
| Where it lives | `BattleRules.can_declare_attack()` | `BattleRules.negate_attack()` |

**Prevention must happen before declaration**, not as a declaration that is immediately
cancelled: a cancelled declaration would emit `ATTACK_DECLARED`, open a window, and spend the
monster's attack, all three of which are wrong. It has **two channels**, and neither is
expressed in terms of the other:

* **per CARD** — the `cannot_attack` flag (`Fiendish Chain`, `Hieratic Dragon of Tefnuit`).
  It names one monster and travels with it.
* **per PLAYER** — `ContinuousEffects.ATTACK_LOCK_KEY` (`Swords of Revealing Light`). It names
  a player, so it covers monsters that reach that player's field *after* the source resolved,
  and monsters whose control moved into their hands. Flagging the monsters present at recompute
  time would answer correctly for the board as it stands and wrongly for the next monster.

**Negation is not a Replay.** A Replay hands the choice back — the attacker may re-declare with
the same or a different monster [S1 p.39]. A negated attack is spent. `begin_replay()` clears
`has_attacked_this_turn`; the negation path deliberately does not.

**Negation is checked BEFORE the Replay check**, and the order is load-bearing. `Maiden with
Eyes of Blue` negates the attack and then Special Summons to the *defending* field, which
changes the set of monsters the attacker faces — the textbook Replay condition. Asking about a
Replay first would turn a spent attack back into a fresh declaration and undo the negation.

**The Damage Step is the boundary.** `negate_attack()` refuses once the Damage Step has begun:
"negate the attack" belongs to the Battle Step window the declaration opened, and from the start
of the Damage Step the effects that are legal change ATK/DEF instead [S1 p.41]. It refuses
rather than silently doing nothing, so a card asking at the wrong moment fails visibly.

The battle pipeline is otherwise unchanged: no replay semantics were modified to support
negation.

### 6.5 Attack prevention, THIRD channel: a turn-scoped ban by card NAME (Phase 5 batch 11)

Added for `Burst Stream of Destruction` — *"'Blue-Eyes White Dragon' you control cannot attack
the turn you activate this card."* `CARD_RULINGS.md` **R41 Part C**.

§6.4's two prevention channels are both **continuous**: they are wiped and rebuilt by
`ContinuousEffects.recompute()`, so both lift the instant their source stops applying. This
restriction is neither. It is acquired at one moment, it belongs to **the rest of that turn**, and
its source is a **Normal Spell that is in the Graveyard** before the first attack it forbids could
ever be declared. Expressing it as either existing channel would lift it immediately.

It is also **not** per-monster. The official supplement says every copy of the named card is
banned, including one Summoned **after** the activation — which `Kaibaman` and `Silver's Cry` can
both do in this pool — so flagging the monsters present at resolution would answer correctly for
the board as it stands and wrongly for the next one. This is §6.4's per-CARD-versus-per-PLAYER
argument a second time, and it lands on neither: the ban names **a player, a card NAME and a
turn**.

| | per CARD (§6.4) | per PLAYER (§6.4) | **per NAME + TURN (this)** |
|---|---|---|---|
| Card | `Fiendish Chain` | `Swords of Revealing Light` | `Burst Stream of Destruction` |
| Lifetime | while the source applies | while the source applies | **the rest of this turn** |
| Survives the source leaving the field | no | no | **yes** |
| Reaches a monster that arrives later | no | yes | **yes, if it has the name** |
| Storage | `CardInstance.flags["cannot_attack"]` | `ContinuousEffects.ATTACK_LOCK_KEY` | `PlayerState.attack_bans_by_name` |

`PlayerState.ban_attacks_by_name()` / `attacks_banned_by_name()` are the only writer and reader,
and the value stored is the **turn number**, exactly as `named_effect_usage` stores it (§11): the
ban therefore **self-expires** at the turn boundary and no cleanup hook has to remember it.
`BattleRules.can_declare_attack()` asks all three channels, none expressed in terms of another.

**The ban attaches at ACTIVATION, not at resolution**, and survives **effect** negation while
being lifted by **activation** negation. That is precisely the existing
`ActivationRules.ACTIVATION_CONDITION_EFFECT_ID` + `EffectDef.activation_confirmed` channel from
§5.9 / R39, which runs only when `not link.activation_negated`; nothing new was needed for the
timing. Firing it as the Chain Link is processed rather than at the literal instant of activation
is unobservable, because no attack can be declared while a Chain is unresolved.

The **matching activation restriction** — "you cannot activate this card on a turn in which a
monster with that name already attacked" — reads the authoritative **event log**
(`ATTACK_DECLARED` entries of the current turn) through the single primitive
`EffectPrimitives.named_monster_attacked_this_turn()`, and deliberately **not**
`CardInstance.has_attacked_this_turn`: `on_leave_field()` clears that flag, so a monster that
attacked and was then destroyed, Tributed or bounced would silently stop counting. This is §15's
"facts that must outlive a card leaving the field" applied to an attack rather than to a card.

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
| `AFTER_DAMAGE_CALC` | an effect whose rules-mandated window is **sub-step 4** — "when this card battles", "when you take battle damage". Legal in sub-step 4 and in no other sub-step |

**Clarification (added when the Damage Step was implemented):** `MANDATORY_TRIGGER`
describes the *timing*, not the *optionality*. `Shining Angel`'s "when this card is
destroyed by battle and sent to the GY: You can Special Summon…" is an **optional**
Trigger Effect whose window is nevertheless inside the Damage Step, and its controller is
still asked whether to use it. The engine therefore gates this permission on the effect
being trigger-collected, not on `Optionality.MANDATORY`.

**`AFTER_DAMAGE_CALC` (added in Phase 5 batch 12, `CARD_RULINGS.md` R42 Part C).** §7.1
sub-step 4 already named "when battle damage is inflicted" as a window, but no permission
value could give it to a **card activation**, and that is why the value exists rather than
because a fourth is tidier:

* `UNTIL_DAMAGE_CALC` is sub-steps 1–2 — the *earlier* window, and the wrong answer rather
  than a near-enough one;
* `MANDATORY_TRIGGER` is gated on `TriggerCollector._is_collectable()`, which answers true
  only for `EffectType.TRIGGER` and `FLIP`. A Normal Trap's own activation is
  `EffectType.CARD_ACTIVATION` — that is what flips it face-up and sends it to the
  Graveyard afterwards — so the permission can never apply to it.

`Damage Condenser` (cid 6582, 「ダメージ計算後に発動します」) is the pool's only consumer.
Both exclusions above are asserted in `DamageStepTests` so the reason the value exists
cannot quietly stop being true.

**A card activation in this window may not read `ctx.trigger_event`.** A `CARD_ACTIVATION`
carrying `trigger_events` is offered by `DuelEngine._activation_actions()` as a response in
a matching window, and that path calls `ActivationRules.can_activate(..., null)` — so the
event is null in the condition, and `ActivationRules.make_context()` attaches no engine
either. A condition that needs the battle's numbers reads the **event log** instead, through
`EffectPrimitives.battle_damage_taken_in_this_battle()`, bounded backwards to the most
recent `ATTACK_DECLARED`. Resolution keeps using `battle_damage_just_inflicted_on()`, where
the engine is attached. The two readers are deliberate and neither can answer for the other.

An effect with `NONE` is never surfaced during the Damage Step. There is no generic
"allow everything" path (master prompt §33).

**`UNTIL_DAMAGE_CALC` is a PERMISSION, not a schedule (added in Phase 5 batch 13,
`CARD_RULINGS.md` R20 Part C).** `ActivationRules.damage_step_ok()` answers `true` whenever
the duel is **not** in the Damage Step — its whole job is to restrict what may happen inside
one. So a card whose printed text says "**During the Damage Step**" must carry that in its
own `condition` as well: the permission alone leaves it activatable in the Battle Step, and
the attack-declaration window is the Battle Step with `current_attacker` already set.
`Honest`'s first implementation was offered there and its suite caught it. Any future card
whose window is a *named* part of the Battle Phase must state that named part itself.

### 7.5 A Quick Effect activated FROM THE HAND

Added in Phase 5 batch 13 for `Honest` (cid 7574). `CARD_RULINGS.md` **R20 Part B**.

「手札で発動できる誘発即時効果です」 — *a Quick Effect that can be activated in the hand*. This
is the pool's first **monster** effect activated from a zone other than the field, and it
needed **no new engine surface**. It is recorded here because the absence of new machinery is
the fact worth keeping, not because anything changed:

* `EffectDef.activation_locations` already carries `ActivationLocation.HAND`, and
  `ActivationRules.location_ok()` already answers for it. The value was never restricted to
  Spells and Traps — nothing in the gate reads the card's category.
* `DuelEngine._activation_actions()` already iterates `state.all_instances()` regardless of
  zone and defers every zone question to that gate, so a monster in the hand was always
  reachable; no card had asked before.
* Spell Speed comes from `EffectType.QUICK` via `Enums.spell_speed_for_effect()`, and
  `ActivationRules.is_fast_effect()` is `starts_chain and spell_speed >= SS2` — it reads the
  effect, never the card type. A monster's Quick Effect is therefore a legal response
  wherever a Spell Speed 2 window is open.

The consequence a card must not forget: a Quick Effect in the **hand** has no `is_on_field()`
to protect it, so anything its resolution needs about its own source must be read from the
**cost payload** rather than from `ctx.source`'s zone — which for `Honest` is the Graveyard
by the time the effect resolves, because its own cost put it there.

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
| `ADDED_TO_HAND` | Deck/GY/excavation → hand, "**add** to your hand" | **NO** | NO |
| `RETURNED_TO_DECK_TOP` / `_BOTTOM` / `SHUFFLED_INTO_DECK` | → Deck; see §8.2 | **NO** | NO |
| `EXCAVATED` | top of Deck → excavation holding area; see §8.2 | **NO** | NO |
| `RULE` | rules-driven move (e.g. Equip destroyed when its target leaves) | depends | depends |

Key rulings encoded:
* A card returned from field to hand/Deck, or sent to the GY as a **cost** or **Tribute**, is
  **NOT** "destroyed". [S1 p.52]
* Destroy, discard, and Tribute **all** count as "sent to the Graveyard" for triggers. [S1 p.53]
* A **banished** card later moved to the GY is **NOT** "sent to the Graveyard". [S1 p.53]
* "Leaves the field" triggers do **not** fire when a field monster is shuffled into the Main
  Deck or becomes material. [S1 p.51]

### 8.2 Deck placement, revealing and excavating — **DECIDED** (Phase 5 batch 7)

**The three ways a card reaches the Deck are three different rules, not one with a flag.**

| Instruction | Where it lands | Shuffles? | `revealed_to` |
|---|---|---|---|
| "place it on the **top** of the Deck" | index 0, exactly | **no** | **kept** |
| "place it on the **bottom** of the Deck" | last index, exactly | **no** | **kept** |
| "**shuffle** it into the Deck" | unspecified | **yes** | **cleared** |

The end of the Deck is derived from the `MoveReason` (`Enums.deck_position_for()`), never
supplied as a separate option, so the two can never disagree. A top or bottom placement is
**not** implemented as "insert, then shuffle": the Deck above and below the inserted card
keeps its exact order, which is observable on the very next draw. See §12.1 for why only
the shuffle ends what the players legally know.

**Revealing** shows a hidden card without moving it (`GameState.reveal()`). A reveal to one
player is a **private** event, exactly like a draw; a reveal to both is public.

**Excavating** (`GameState.excavate()`) takes cards off the **top** of the Deck into
`Zone.EXCAVATED` — not the hand, not the field, not the Deck — and reveals them to **both**
players. It is deliberately none of the four things it resembles:

* not a **draw** — nothing reaches the hand, no `CARD_DRAWN` is emitted, and a Deck with
  fewer cards than asked simply yields fewer. An excavate can never deck a player out,
  because the deck-out rule is written about *drawing* [S1 p.35].
* not a **search** — a search looks *through* the Deck privately and ends in a shuffle
  [S1 p.5]; an excavate takes from the top and reveals.
* not a **reveal** on its own — the cards leave the Deck.
* not a **mill** — nothing is sent to the Graveyard unless the card text says so.

The excavating card's own text states where every excavated card goes, and in what order.
Nothing is left in `Zone.EXCAVATED` when the effect finishes, and nothing is shuffled
unless the text says "shuffle".

`Zone.EXCAVATED` is deliberately separate from `Zone.IN_TRANSIT`: the latter means
"mid-Summon / mid-activation" and is the one non-field zone
`GameState._is_destroyable_zone()` accepts, so sharing it would let a Summon-negation card
destroy a card sitting in somebody's excavation.

*Engine:* `Enums.Zone.EXCAVATED`, `Enums.MoveReason.ADDED_TO_HAND` / `EXCAVATED`,
`Enums.deck_position_for()`, `GameState.reveal()` / `excavate()` / `excavated_cards()`,
`EffectPrimitives` movement + excavation sections.
*Tests:* `MovementTests` (the movement gate), then `CrystalSeerTests`,
`PhoenixWingWindBlastTests`, `SpiritualWindArtMiyabiTests`, `ChainDetonationTests`,
`ChainHealingTests`.

### 8.3 Banishment and TEMPORARY removal — **DECIDED** (Phase 5 batch 8)

Banishing separates a card from the field, the hand, the Deck or the Graveyard without sending
it anywhere those words describe [S1 p.53]. Three consequences the engine enforces:

* it is **not** a destruction — no `CARD_DESTROYED`;
* it is **not** "sent to the Graveyard" — no `CARD_SENT_TO_GY`, and a card *later* moved from
  the Banished zone to the Graveyard is still not "sent to the Graveyard" from the field;
* a banished card is reachable by clauses that say "banished" and by nothing else.

**Face-up vs face-down.** A face-up banished card is public information; a face-down one is not
(§12). The two are different states and the engine keeps them apart. Every card in the V1 pool
banishes face-up; the face-down path exists so the distinction cannot be silently lost.

**COST vs EFFECT** stays exactly as batch 4 built it: `EffectPrimitives.pay_banish_cost()` is
paid at activation and is all-or-nothing, never refunded when the effect is later negated;
`banish_target()` runs at resolution and re-checks the target first. They are two primitives, not
one call with a flag.

**Banishing the top N of a Deck** (`banish_top_of_deck()`) is its own primitive and is *not* an
excavation, a draw, a mill or a search — none of those events is emitted. It takes cards from the
top one at a time in a fixed order, so a replay reproduces it; a Deck holding fewer than N loses
what it has, which is not a loss condition, because decking out is a failure to **draw**
[S1 p.35].

**Temporary removal is a LEASE.** A card whose text states a return timing — in the V1 pool only
`Interdimensional Matter Transporter`, "until the End Phase" — is registered in
`GameState.banish_leases` in exactly the shape `control_leases` uses (§5.6), and expires through
`expire_banish_leases()`, called from the same two places `expire_control_leases()` is called
from. The authoritative state, not the card's script, records which card is away, what banished
it, when it is due, where and in what position it returns, and under whose control. Consequences
— the return is **not a Summon**, the position is the one it left in, it comes back under its
**owner's** control, and a full destination leaves it banished — are all reasoned in
CARD_RULINGS.md **R30**, with per-part confidence. A card moved out of the Banished zone by any
other effect loses its lease at that moment, so a return can never happen twice.

*Engine:* `Enums.BanishDuration`, `Enums.MoveReason.RETURNED_FROM_BANISHMENT`,
`GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT`, `GameState.banish_temporarily()` /
`banish_leases` / `banish_leases_for()` / `is_temporarily_banished()` / `end_banish_lease()` /
`drop_banish_leases_for()` / `expire_banish_leases()`,
`EffectPrimitives.banish_target_temporarily()` / `banish_top_of_deck()`.
*Tests:* `BanishTests` (the banish gate), then the batch-8 cards.

### 8.4 The Deck as a zone an effect may look through — SEARCH, MILL and an effect DRAW — **DECIDED** (Phase 5 batch 10)

Decided in CARD_RULINGS.md **R40**, from [S1 p.5], [S1 p.53] and eight official Konami
card supplements. This section is the normative statement; R40 carries the sourcing and the
per-part confidence.

**There are now FOUR ways an effect reaches the Deck, and they stay four.** §8.2 already
separated DRAW, REVEAL and EXCAVATE and recorded that nothing implemented the fourth. Batch 10
implements it.

| | Moves what, where | Public? | Shuffles? | Can lose the Duel? |
|---|---|---|---|---|
| **DRAW** | top of Deck → hand, in order | private to the drawer | **no** | **yes** — a player who must draw and cannot loses [S1 p.35] |
| **REVEAL** | nothing moves | to the stated viewers | no | no |
| **EXCAVATE** | top N → `Zone.EXCAVATED`, in order | to **both** players | no | no |
| **SEARCH** | any card in the Deck → hand (or GY), by predicate | the **chosen** card is revealed; the rest of the Deck is not | **yes, always** | no |

**A search shuffles, and the shuffle is the search's tail, not the card's choice.** [S1 p.5]
requires a Deck that a card effect made you reveal from **or look through** to be shuffled and put
back; [S1 p.53] repeats it for searching and lets the opponent shuffle or cut. Because §12.1 keys
the loss of `revealed_to` on the shuffle, a search therefore also **ends all legal knowledge of
where anything in that Deck is** — including of the card it just took. This falls out of a rule
already implemented; no new knowledge mechanism was added.

**A card added to the hand by a search is revealed to both players on the way.** It must be shown
to prove it met the search's requirement [S1 p.53, "Reveal"]. It is out of the Deck before the
tail shuffle runs, so it **keeps** `revealed_to`: the opponent legally knows the searcher holds
it. Only knowledge of the cards still in the Deck is ended by the shuffle.

**A MILL — Deck → Graveyard by choice — is a search too.** It looks through the Deck, so it
shuffles. It is public on arrival because the Graveyard is public knowledge [S1 p.5]. It emits an
ordinary send-to-GY, so "if this card is sent to the GY" triggers see it. It can **never** deck a
player out: decking out is a failure to **draw** [S1 p.35], and a mill is not a draw.

**Activation restriction (the GENERAL rule).** You cannot activate an effect **to search your
Deck** for a card when no card in your Deck meets the requirements [S1 p.53]. `can_search_deck()`
implements it and a card whose activation exists in order to search consumes it in its
`condition`.

**Two card-specific official exceptions to the general shape, both load-bearing:**

1. **A mandatory trigger whose condition is not "search" still activates on an empty search.**
   `The White Stone of Legend` (cid 7850) activates whenever it is sent to the GY — *including*
   with no `Blue-Eyes White Dragon` in the Deck, resolving and adding nothing — and activates in
   the Damage Step. Card-specific official guidance outranks the general sentence. The general
   restriction is for effects activated *in order to* search; a trigger whose condition is "this
   card was sent to the GY" is not one.
2. **"Draw 2" carries its own activation requirement.** A card that says "draw N" cannot be
   activated unless the Deck holds N (cid 7248, cid 8656, each explicit). `can_draw()` implements
   it generically. The deck-out path in `GameState.draw()` is **unchanged and still reachable** —
   a future card that draws without this gate must still lose the Duel correctly.

**A qualified COST is a candidate-list question, not a new primitive.** "Discard 1 *Level 8
monster*", "discard 1 *Dragon Tuner with 1000 or less ATK*", "send 1 face-up *non-Effect Monster
you control*" are the existing `pay_discard_cost()` and `pay_send_to_gy_cost()` given a filtered
candidate list. **Discarding and sending stay distinct** [S1 p.52-53]: a discard is specifically
hand → GY (`MoveReason.DISCARDED`), a send from the field is `MoveReason.SENT_AS_COST`, and a
clause worded for one must never see the other.

*Engine:* `EffectPrimitives.draw_cards()` / `can_draw()` / `deck_search_candidates()` /
`can_search_deck()` / `search_deck_to_hand()` / `send_from_deck_to_gy()` /
`qualified_hand_cards()` / `qualified_own_field_monsters()`, over the existing
`GameState.draw()`, `GameState.reveal()`, `GameState.shuffle_deck()` and `GameState.move_card()`.
Nothing in `GameState` was reshaped for this: the subsystem is a card-facing layer over four
primitives that were already correct.
*Tests:* `DeckAccessTests` (the gate, written and green before any card), then the batch-10 cards.

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

### 10.6 A dead TARGET does not automatically kill the whole effect — **DECIDED** (Phase 5 batch 14)

Added for `Witchcrafter Golem Aruru`. `CARD_RULINGS.md` **R13 Part E**; official supplement for
cid 14483, 2020-07-04.

The engine's working assumption up to batch 13 was the ordinary one: an effect that targets one
card and finds that card gone at resolution does nothing. Every card that reached the library
before batch 14 happened to be shaped that way, so the assumption was never tested against a card
that says otherwise. **It is not a rule.** Konami states the opposite for cid 14483:

> 処理時に、対象のカードがフィールドに存在しない場合、このカードを特殊召喚する処理のみを行います。
> *At resolution, if the targeted card is not on the field, only "Special Summon this card" is
> performed.*

The rule is: **each sentence of the resolution is performed on its own terms.** A sentence that
does not refer to the target is not conditional on the target, and a target that is gone removes
only the sentences that name it. What links two sentences is the PSCT connective — "and if you do"
makes the second conditional on the FIRST SUCCEEDING, which is a different question from whether
the target survived. `Witchcrafter Golem Aruru` carries both in one clause and the two are
independent:

| At resolution | The Special Summon | The return to the hand |
|---|---|---|
| everything is still legal | happens | happens |
| the **target** has left the field / changed control | **still happens** | does not |
| the **Special Summon** fails (no free Monster Zone; the card is no longer in the hand) | does not | **does not** — "and if you do" |

**This is NOT the same question as §10.8**, which was added a batch later and which does gate a
whole resolution: there the thing that failed is the card's own **activation requirement**, not a
target. Read the two together; neither generalises over the other.

**Consequence for anyone writing a card.** Do not begin a `resolve` with a target re-check that
returns early unless the card's text really makes every sentence depend on the target. Re-check
the target immediately before the sentence that USES it. A card whose whole resolution is one
sentence about the target is unaffected by this and keeps the earlier shape.

**How the re-check itself is written.** The clause's `legal_targets` builder is re-run at
resolution and the chosen card is tested for membership, rather than a second, hand-written copy
of the same conditions. That is what keeps a heterogeneous target pool ("1 card your opponent
controls, **or** 1 archetype Spell in your GY") answering one question — *is this still a legal
target for this clause?* — instead of two that can drift apart. `surviving_target()`,
`surviving_field_target()` and `surviving_opponent_field_target()` remain correct for the single-
pool clauses that already use them and were not touched.

### 10.7 Two independent gates keep a Quick Effect out of a window, and both must be declared

Found while testing `Witchcrafter Golem Aruru`'s Damage Step restriction (R13 Part A), and
recorded because it changes what a test can prove.

An effect that declares `trigger_events` is offered by `DuelEngine._activation_actions()` **only
in a window whose events match one of them** (`_window_matches()`), *and* only when
`ActivationRules.damage_step_ok()` allows it. These are independent:

* an ordinary Damage Step sub-step window carries `DAMAGE_SUBSTEP_CHANGED`, not `TARGET_SELECTED`
  or `ATTACK_TARGET_SELECTED`, so such an effect is absent from it **whatever** its Damage Step
  permission says;
* the permission is what bites when the opponent's own **targeting activation happens inside the
  Damage Step**, because that window does carry `TARGET_SELECTED`.

So "it is never offered in the Damage Step" is **not** by itself evidence that the permission is
being enforced. A card whose printed text forbids the Damage Step must (a) declare
`DamageStepPermission.NONE` — the default — and (b) be tested against an opponent activation that
really happens inside a Damage Step, or the assertion is passing on the window-event gate alone.
`WitchcrafterGolemAruruTests` drives both, and mutation-testing the permission proved the second
is what makes the first meaningful.

### 10.8 An ACTIVATION REQUIREMENT that fails by resolution kills the WHOLE effect — **DECIDED** (Phase 5 batch 15)

Decided in `CARD_RULINGS.md` **R15 Part C**, from official Q&A fid 8193 for `A Hero Emerges`.
Read it **next to §10.6**, which it looks opposed to and is not.

**Rule: when a card's own ACTIVATION requirement has stopped being satisfied by the time the
Chain Link resolves, the effect is not applied at all — including the sentences that come
*before* the part which became impossible.**

The official case: `A Hero Emerges` may only be activated while your hand holds a monster this
effect could Special Summon. `Vanity's Emptiness` chained above it makes every Special Summon
impossible, and Konami's answer is
「ヒーロー見参」の効果処理は適用されません。（『自分の手札１枚を相手がランダムに選ぶ』事も行いません。）
— the effect is not applied, **and the random choice is not even performed**, although the random
choice is the card's *first* sentence and nothing about it needs a Special Summon.

**How this differs from §10.6, in one line each:**

| | §10.6 | §10.8 |
|---|---|---|
| what failed | a **target** the clause chose at activation | the card's own **activation requirement** |
| what it costs | only the sentences that name that target | the **entire** resolution, first sentence included |
| why | each sentence is performed on its own terms | the requirement is the condition under which the card may do anything at all |

Both are real, both are official, and neither generalises over the other. A clause has a §10.8
gate only when its **activation** is restricted by something the resolution could invalidate —
which is why `Damage Condenser` (R42 Part C) and `A Hero Emerges` (R15 Part A) have one and
`Spiritual Water Art - Aoi` (R42 Part B), whose supplement is deliberately silent, does not.

*Engine:* the requirement is written **once**, as a named `EffectPrimitives` query, and called
from both `EffectDef.condition` and the first line of `EffectDef.resolve`. Two separately written
checks would drift, and the resolution-time one would be the copy nothing ever reached.
*Tests:* `AHeroEmergesTests` drives it by both routes the V1 pool supplies — the last summonable
monster leaves the hand while the Chain is still building, and the Monster Zone fills up above it
— and asserts in each case that **nothing** was chosen, nothing was revealed and nothing moved,
with the identical un-interfered board as the control. Mutating the ordering so the pick happens
before the gate is caught.

### 10.4 Paying LIFE POINTS as a cost, and identifying that it happened

Added in Phase 5 batch 8 for `Judge of the Ice Barrier`. `CARD_RULINGS.md` **R31**.

An LP payment is an ordinary activation cost and obeys §10 unchanged: paid at **activation**,
all-or-nothing, and **never refunded** — not when the activation is negated and not when the
effect is negated. `EffectPrimitives.pay_life_points_cost()` is the only way to make one, and
`can_pay_life_points_cost()` is the only place affordability is decided (R31 part B fixes the
exactly-zero edge and isolates it there).

What is genuinely new is that a clause can ask **"was this card or effect activated by paying
LP?"**. That question is answered from the **activation**, never from an LP delta:

* `pay_life_points_cost()` writes the amount into `ctx.cost_payload` under
  `EffectPrimitives.LP_COST_KEY`;
* `DuelEngine._perform_activation()` already copies the payload into **both** the `COST_PAID`
  event and the `ChainLink`, so no engine change was needed to carry it;
* `cost_event_paid_life_points()` / `activation_paid_life_points()` / `life_points_paid_in()`
  are the only supported readers.

The provenance is therefore **per Chain Link**, so a Chain carrying several activations can
never attribute one player's payment to another link. Because the answer comes from the cost
channel and not from `LP_CHANGED`, **none** of these counts as a payment: effect damage, battle
damage, an arbitrary LP loss, an LP reduction caused by another resolving effect, LP **gain**,
or an activation whose cost is something other than LP. `LP_CHANGED` does carry a
`LP_COST_REASON` tag, but that is for the log — a card must not key on it.

Note that §4.3 already settles the timing question this raises: **paying a cost is not an
activation and cannot be chained to**, so nothing may respond to the payment itself.

### 5.7 Continuous clauses that react to a discrete event

Also added in batch 8, and the shape `Judge of the Ice Barrier`'s first clause needs.

"While you control another 'Ice Barrier' monster, **each time** your opponent activates a card
or effect by paying LP, they lose 500 LP" is a **continuous effect**, not a Trigger Effect: it
applies the instant the event happens, it puts **no link on the Chain**, and it is never offered
as a choice. §4.3 is what forces this — the payment cannot be chained to, so a Trigger Effect
could not express it — and `ContinuousEffects.recompute()` cannot either, because a recompute
runs many times and an LP loss applied on each would fire without bound for one event.

The mechanism is `EffectDef.respond_to_event` (with `trigger_events` naming the events and
`condition` gating it) dispatched by `ContinuousEffects.respond_to()`. Its sources are exactly
the set `recompute()` uses — face-up, on the field, not negated, own activation resolved — so
such a clause switches itself off under precisely the conditions its continuous stat modifiers
would. `DuelEngine` feeds it from a **non-reentrant queue**: a response changes state and so
emits events of its own, and queueing rather than recursing keeps application order equal to
emission order, which is what makes a replay reproduce it.

`CardRegistry` rejects a `respond_to_event` clause that is not CONTINUOUS or that names no
event, so one cannot be added and silently never fire.

### 5.8 Trap Monsters — a card with two identities [S1 p.53]

Added in batch 8, for `The Phantom Knights of Shadow Veil`: a **Normal Trap** that Special
Summons itself "as a Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300)".

**The printed identity and the runtime identity are two different things and are stored
separately.** `CardDef` is the immutable canonical definition and is **shared by every copy** of
that card, so a temporary type line may never be written into it — doing so would rewrite the
card for the whole duel and for every other copy. The runtime identity lives on the
`CardInstance` as `monster_identity`, granted by `become_monster()` and revoked by
`clear_monster_identity()`.

| Question | While in a Monster Zone | Everywhere else |
|---|---|---|
| `is_monster()` | **yes** | printed answer |
| `is_trap()` | only if the text says it is still a Trap | printed answer |
| `current_level()` / `current_attribute()` / `current_race()` | from the granting effect | from `CardDef` |
| `base_atk()` / `base_def()` / `original_atk()` | from the granting effect | from `CardDef` |
| `original_card_category()` | **TRAP** — always | TRAP |
| Zone occupancy | one **Monster** Zone, no Spell & Trap Zone | — |

Three rules the implementation is built on:

1. **The Summon goes through the ordinary Special Summon route**, not around it.
   `SummonRules.begin_special_summon()` refuses a card that is not a monster, so the identity is
   granted *first* and revoked again if the Summon does not happen. The result is a real Special
   Summon with real `SPECIAL_SUMMON_DECLARED` / `SPECIAL_SUMMON_SUCCEEDED` events, subject to
   the free-Monster-Zone and control-limit checks, negatable like any other.
2. **Leaving the Monster Zone revokes the identity**, on every route out — destroyed, banished,
   returned to hand or Deck, sent to the Graveyard, tributed, or put back because the effect was
   negated. `GameState.move_card()` owns this, in one place, and deliberately *not* inside
   `on_leave_field()`: that runs only when the card was on the field, and a negated Summon never
   gets there, which would strand a Trap in the Graveyard still answering `is_monster()`.
   `Zone.IN_TRANSIT` keeps the identity, because that is mid-Summon.
3. **"(This card is NOT treated as a Trap.)" is text, not a rule.** Most printed Trap Monsters
   remain Traps; this one does not. `treated_as_original_type` carries what the card says.

**"Banish this card when it leaves the field" is a DESTINATION replacement**, and a different
mechanism from the destruction replacement of §17: that one swaps *which card* is destroyed,
this one swaps *where this card ends up*, and it applies to every departure the clause names
rather than to destruction alone. It is held in `card_memory`
(`GameState.BANISH_WHEN_LEAVING_FIELD_KEY`) rather than in `CardInstance.flags`, for the reason
§15 gives: `on_leave_field()` clears the flags during the very move that has to honour the
obligation. **Only the destination changes; the reason does not** — a redirected destruction is
still a destruction and still fires `CARD_DESTROYED`, so a clause worded "when this card is
destroyed" still sees it. The obligation is consumed the moment it fires.

### 10.5 A cost must be paid in a way that leaves the effect PERFORMABLE

Added in Phase 5 batch 13 unit A, as an **authoritative correction to shipped, green code**.
`CARD_RULINGS.md` **R42 Part D**. Official Konami supplemental information for `One for One`
(cid 8197, dated 2020-03-20 on the page, `request_locale=ja`, re-fetched and re-verified
against the live source in batch 13 before anything was changed):

> ■処理を行えるようにコストのモンスターを墓地へ送る必要があります。レベル１のモンスターが自分のデッキに存在せず、自分の手札に１体のみ存在する状況では、そのモンスターをコストにできません。

> *You must send the cost monster to the Graveyard in such a way that the effect can be carried
> out. Where no Level 1 monster is in your Deck and only one is in your hand, that monster
> cannot be used as the cost.*

The supplement states this as a **requirement of payment**, not as a quirk of one card, so it is
recorded here as a general rule of §10 rather than in that card's file.

**What it restricts.** The **cost candidate list**, and nothing else. §10's ordering is unchanged:
the activation condition is still evaluated over the pool as it stands **before** any payment,
and this rule never widens or narrows it. An activation that is legal stays legal; what shrinks
is the set of materials that may be **spent**. Only when that set shrinks to **empty** does the
card stop being offered — and then it is `can_pay_cost` refusing, not the condition. The two
checks can therefore legitimately disagree, and `Tests/rules/CostLegalityTests.gd` asserts a
state in which they do.

**When it bites.** Only where the cost's material pool and the effect's candidate pool overlap in
the **disabling** direction: the cost takes a card **out of** a zone the effect draws from and
puts it somewhere the effect does **not** draw from.

| Card | Cost pool → destination | Effect pool | Bites? |
|---|---|---|---|
| `One for One` | hand → GY | hand **or Deck** | **YES** — the GY is outside the effect's pool |
| `Fairy Tail - Rella` | hand → GY | hand, Deck **or GY** | no — the destination is inside the pool |
| every other cost in the V1 pool | — | — | no — the pools do not intersect |

Every cost-paying card in the pool was audited against that table when the rule was written.
`One for One` is the **only** card it currently changes. Over-applying it would silently forbid
legal plays, so the non-biting shape is a test (`harmless_overlap_spell()`) and not a comment.

**Where it lives.** `EffectPrimitives.cost_candidates_keeping_effect_performable()`, alongside
`exclude_required_tributes()` — the file already owns generic filters over cost material. The
card supplies the predicate, because only the card knows what "carried out" means for its own
clause, and a card must feed the **same** predicate its `condition` uses so the two cannot drift.

**Honest limit.** The filter tests each candidate **alone**, which is exact for a payment of one
card and **not** exact for a larger one — a pair can be an illegal payment though neither card is
illegal by itself. A count other than 1 is therefore **refused loudly** rather than answered
approximately, and the predicate is not even consulted. No card in the V1 pool has a multi-card
cost that overlaps its own effect's pool; the day one does, the set-level check is the work.

---

### 10.9 A card may state its OWN resolution-time condition, per clause — **DECIDED** (Phase 5 batch 16)

Decided in `CARD_RULINGS.md` **R12 Part E**, from the official supplement to
`The Monarchs Awaken` (cid 10963, 2015-09-19). Read it **next to §10.6 and §10.8**, which it
sits between.

**Rule: when a card's supplement names a state its target must be in AT RESOLUTION, that
condition is checked at resolution and governs exactly the clauses the supplement says it
governs — no more and no less. It is not an activation requirement (§10.8) and it is not the
target ceasing to exist (§10.6).**

The official case:

> ■処理時に、対象のモンスターが裏側守備表示の場合、効果は無効にならず、『このカード以外の効果を受けない』効果は適用されません。
> *If, at resolution, the target monster is face-down Defense Position, its effects are not
> negated and the "unaffected by the effects of cards other than this card" effect is not
> applied.*

The target is still on the field and is still the card that was targeted, so §10.6's "the
target is gone" does not describe it. Nothing about the card's *activation* has stopped being
true, so §10.8 does not either. What has changed is a property the printed text asks for —
"**face-up** Tribute Summoned monster" — and the supplement states the consequence directly:
both clauses are skipped, and the card is still spent.

**How this differs from §10.6 and §10.8, in one line each:**

| | §10.6 | §10.8 | §10.9 |
|---|---|---|---|
| what failed | a **target** the clause chose | the card's own **activation requirement** | a **property of the target** the text names |
| what it costs | only the sentences naming that target | the **entire** resolution | exactly the clauses the supplement names |
| where the answer comes from | the general rule | the card's supplement | the card's supplement |

**Implementation.** `EffectPrimitives.surviving_own_monster_target(ctx, true)` already asks all
three of "face-up", "monster" and "you control" at resolution (R29), so the rule needs no new
machinery — only that a card whose supplement states it actually passes `true`. The defence
against the obvious mistake is a test: `MonarchsAwakenTests` flips the target face-down on a
real **Chain Link 2** rather than by touching the board after the fact, because a post-hoc flip
would clear the states anyway and the test would pass whatever the card did.

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

### 11.1 Two effects SHARING one use — **DECIDED** (Phase 5 batch 9)

"You can only use 1 *[name]* effect per turn, and only once that turn." (`Maiden with Eyes of
Blue`, `CARD_RULINGS.md` **R3**) is a **sixth** form and is none of the five above: it is a
single use shared *across* two different clauses, per player, per card name. Using either clause
spends the one use and locks out both.

Expressed with `EffectDef.restriction_group` — both clauses declare `opt_named_effect()` and the
**same** `in_group("…")` key, so `named_key()` returns the shared key and the existing
player-level named-effect ledger does the work. Nothing new was needed in the bookkeeping.

It is deliberately **not**:

* `opt_named_effect()` on each clause with its own id — that gives each clause its own use, so
  a player could use both in one turn;
* `opt_instance()` — that is per copy, so a second copy of the card would be unrestricted, and
  the printed restriction names the card, not the copy.

Both orderings are asserted (A-then-B and B-then-A), because a shared key implemented as
"mark A, check A" passes only one of them.

### 11.2 Per-card TURN COUNTERS — **DECIDED** (Phase 5 batch 9)

"You must destroy it during the End Phase of your opponent's 3rd turn" (`Swords of Revealing
Light`, **R6**) needs a card to count **turns**, which is a third kind of bookkeeping and is
folded into neither of the existing two:

* `CardInstance.counters` holds **game** counters (Spell Counter, Balloon Counter). Those are
  placed by effects and are readable and requirable by other cards; a turn tally is none of
  those things, and putting it there would expose it to `Wonder Balloons`.
* `effect_usage` / `effect_use_counts` self-expire by comparing against the **current** turn
  number, which is exactly wrong for a tally that must survive every turn boundary until it
  reaches its limit.

So: `CardInstance.turn_counters`, keyed by a card-chosen string, recording `{count, last_turn}`.
Advancing twice within one turn number counts once, so a re-entered phase or a repeated
recompute cannot double-count. It is **per instance** and is cleared with the rest of the
per-instance state on leaving the field or being flipped face-down — a card that left and came
back starts over.

The lifetime is expressed in **authoritative duel/turn state only**: the counter advances from
`PHASE_CHANGED → END` while the named player is the turn player. No wall-clock time, frame
count or UI state is involved anywhere. The player whose turns are counted is a parameter rather
than "the other one", so the primitive does not encode the inference that turns strictly
alternate.

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

### 12.2 Looking at a hidden zone — **DECIDED** (Phase 5 batch 12)

Decided in `CARD_RULINGS.md` **R42 Part B**, for `Spiritual Water Art - Aoi`'s "look at your
opponent's hand". This is an **operation** over §12.1, not a new subsystem.

**Rule: "look at" is a REVEAL TO ONE PLAYER. Nothing moves, nothing is turned face-up, and
the knowledge is kept until a shuffle — which for a hand means forever.**

A hand is private [S1 p.50] and §12.1 already models legal knowledge as
`CardInstance.revealed_to`, ends it only at a shuffle, and already marks a partial reveal
`private_to` so the public log never carries what one player alone may see. Looking at a
hand is therefore `reveal(card, [looker])` per card. Three things it deliberately is not:

* **not a reveal to both** — the clause names one player, and passing only that player is
  the whole difference;
* **not a move** — a clause that looks and then sends does the sending separately, and the
  two stay separable, because a look may find nothing to send;
* **not forgotten** — there is no "forget", and none may be added for this. A hand is never
  shuffled, so a card looked at and kept is still legally known, which is what the physical
  game gives you.

**Sending a card out of an opponent's hand is a SEND, never a DISCARD.** "Discard" is a
player's own hand [S1 p.52-53]; `MoveReason.SENT_TO_GY_BY_EFFECT` keeps a future
discard-trigger from seeing it. R40 already made that separation load-bearing.

*Engine:* `EffectPrimitives.look_at_hand()` and `send_from_hand_to_gy()`, over the existing
`GameState.reveal()` and `GameState.move_card()`. Nothing in `GameState` was reshaped.
*Tests:* `HiddenInfoTests` — the gate, written and green before `Aoi` existed.

---

### 12.3 A RANDOM choice out of a hidden zone — **DECIDED** (Phase 5 batch 15)

Decided in `CARD_RULINGS.md` **R15 Parts D and H**, for `A Hero Emerges`' "your opponent chooses
1 random card from your hand". Like §12.2 this is an **operation** over subsystems that already
exist — §12.1's `revealed_to`, and the seeded `Rng` §8 of the master prompt requires — and not a
new subsystem.

**Rule: a card chosen "at random" from a hidden zone is chosen by the SEEDED generator, is never
put to a player as a decision, and reveals exactly the card that was chosen — to both players,
and nothing else.**

Three things, each of which would be a silent defect on its own:

* **the seeded generator, and nothing else.** A duel is reproducible from (Decks, RNG seed,
  player decisions) and from nothing else (§ master prompt 8 / 70). `Rng.pick()` counts every
  draw, so a divergent replay shows up in the call count rather than only in the outcome. Godot's
  `Array.pick_random()` and `Array.shuffle()` use the **global** generator and must never appear
  in engine or card code.
* **it is not a decision.** "Your opponent chooses" names an *agent*, not an informed choice:
  routing it through `ctx.ask()` would hand that player the list of cards in a hidden hand, which
  is precisely the leak §12 exists to prevent. The chooser's `PlayerController` is asked nothing
  at all, and the replay payload records no decision for them. In a two-player Duel the chooser's
  identity has no other mechanical consequence — the distribution is uniform whoever is named —
  and that is recorded honestly rather than dressed up as behaviour.
* **the reveal is part of the operation, not of the caller.** The chosen card is revealed to
  **both** players, so the `CARD_REVEALED` event is public — the exact opposite of §12.2's look,
  which is `private_to` one player. That is right because every branch that follows a real choice
  puts the chosen card into a public zone anyway (a face-up Monster Zone, or a Graveyard
  [S1 p.50]); revealing it at the moment of the choice gives away nothing the outcome does not,
  and it makes the branch the effect takes verifiable when it is taken. **The cards that were not
  chosen are revealed to nobody**, which is the whole difference between this and a look.

When the effect does not resolve — §10.8's gate, an activation negation, or an effect negation —
**no pick is made and nothing is revealed at all.**

*Engine:* `EffectPrimitives.random_hand_card_chosen_by()`, over `GameState.rng` and
`GameState.reveal()`. Nothing in `GameState`, `Rng` or `DecisionRequest` was reshaped.
*Tests:* `HiddenInfoTests` — the gate, written and green before `A Hero Emerges` existed. It
proves the same seed picks the same card, that a sweep of seeds reaches every card in the hand
(so "deterministic" is not "always index 0"), that exactly one value is drawn from the duel's own
generator, that neither controller is asked anything, that exactly one card is revealed and the
rest stay hidden in the filtered view, and that nothing moves.

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

### 5.9 Lingering material-choice constraints (R39; S1 pp.24-25, 51-53)

A resolved effect may require a particular opposing monster in a future Tribute selection
this turn, granting only permission to use it. Store player, scope, source, target and turn
in GameState; no control mutation. Drop on target departure from its Monster Zone, control
change, face-up to face-down reset, and exact end of turn. Ineligibility without such a reset
blocks the relevant Tribute. Validate complete sets before any payment; every required target
must be included. Both Summon/Set and cost routes consume this gate. Unrelated actions do not.
Optional Tribute value permits counting a double-Tribute monster as one; a valid set has at
most the required number of cards and enough available value. Opponent-only Tributes do not
free your Monster Zone. Costs count cards, not Tribute value, and retain their own filters.

Battle Phase activation conditions are checked before offering a card; their consequence is
confirmed when its Chain Link is processed even if its EFFECT is negated, but never if its
ACTIVATION is negated. No phase can begin while the Chain is pending. The consequence uses
skip_battle_phase_this_turn and expires in the existing end-of-turn cleanup. R39 sources and
confidence are authoritative for this decision.

## 18. "Unaffected by the effects of cards other than this card"

Decided in `CARD_RULINGS.md` **R12 Parts B–E**, from official Konami Q&A — principally fid
13065, which answers the question on the *same card wording*, plus fid 17304, fid 18199, fid
13085, fid 16491, fid 298 and fid 23510. The English phrase is far broader than the rule, so
none of this may be reasoned from the words.

**Rule: an effect applies to a card at a definite MOMENT. If the card is immune at that
moment, that one application does not happen. Nothing else about the effect changes.**

The effect is still activated, still targets the immune card, still resolves, and every part
of it aimed at some **other** card still applies. Only the individual sub-process aimed at the
immune card is skipped, so one effect can half-apply — and does: fid 13065 has an effect whose
ATK-copy applies and whose ATK-zeroing does not.

**Blocked**, each being an effect applied to the card: destruction by a card effect; being
moved by an effect (bounce, banish, send to GY); a control change; an ATK or DEF modifier; a
battle-position change by an effect; having its effects negated; having a restriction flag set
on it; having a **protection or benefit** granted to it; counters placed by an effect.

**Not blocked**, each a deliberate hole with a source behind it:

* **targeting and selection** (fid 13065). That is the separate `cannot_be_targeted()` flag.
  Conflating the two is the commonest misreading of "unaffected";
* **activation and resolution** of the effect (fid 13065, fid 17304);
* **costs, and Tributes for a Summon procedure** (fid 298 —
  「相手モンスターに適用する効果として扱われません」). The engine already separates cost
  primitives from effect primitives, and the gate goes only on the effect side;
* **battle** (fid 18199). An immune monster is destroyed by battle as normal;
* **the game rules** — a source id of `-1` is never blocked;
* **an application that already COMPLETED** before the immunity began (fid 13085, fid 16491).
  Nothing is undone retroactively.

That last one falls out of the design rather than being coded: a **continuous** effect is
re-applied on every recompute and so is asked every time, while an obligation **recorded once**
on the instance or in a lease is never re-applied and so is never asked.

**The immunity is a shield, not a blessing.** It refuses helpful effects too — fid 18199 has an
immune monster destroyed by battle precisely because it did not receive the "cannot be
destroyed by battle" its opponent's card was handing out.

**Where the state lives, and why not in `ContinuousEffects`.** `CardInstance.unaffected_by_effects`
is a plain per-instance field with `unaffected_exempt_source_ids` alongside it. The official
duration is "as long as the monster is face-up in the Monster Zone" — a statement about the
**monster**, with no condition on the source — and the source in the V1 pool is a Normal Trap
that is in the Graveyard before the state matters. A `ContinuousEffects` restriction flag is
wiped and rebuilt from the board on every recompute and would switch off instantly. The state
ends at exactly the two things the ruling names, both already in `CardInstance`:
`on_leave_field()` and `on_flipped_face_down()`. A control change is **not** an end condition.
Once an end condition is met the state is gone for good; flipping the monster face-up again
does not restore it.

**The exemption is an INSTANCE, not a card name and not a zone test.** "Other than **this**
card" means the specific instance that applied the state, wherever it now is — which is what
lets the same card's negation coexist with the immunity it granted (fid 11871). A second copy
of the very same printed card is **not** exempt.

**Where the gate is asked.** `Scripts/rules/EffectImmunity.gd` holds the predicate; the call
sites are `GameState.destroy()`, `GameState.move_card()` (for the reasons listed in
`EFFECT_APPLICATION_MOVE_REASONS` and no others), `GameState.change_control()`,
`GameState.set_battle_position()` when `by_effect`, `GameState.place_counters()`,
`CardInstance.add_atk_modifier()` / `add_def_modifier()`, and `ContinuousEffects.restrict()` /
`negate_effects()` when given a source.

`destroy()` asks **before** `destruction_prevented()`, and that order is load-bearing rather
than tidy: an immune monster is not *protected from* the destruction, the effect never applied
to it, so a **counted** prevention (`Gagagashield`'s twice-per-turn) must not be spent and a
destruction **replacement** must not consume a substitute. Both are asserted in `ImmunityTests`
with a control that proves the probe fires for an ordinary monster.

`remove_counters()` is deliberately **not** gated: removing counters is most often a cost, the
call site cannot tell a cost from an effect, and blocking a cost would contradict fid 298.

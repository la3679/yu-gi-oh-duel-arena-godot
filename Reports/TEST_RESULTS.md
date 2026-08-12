# TEST_RESULTS

**Last run:** 2026-08-12
**Engine:** Godot 4.7.1.stable.official.a13da4feb (headless)

Command:

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests 300
```

`Tools/run_tests.ps1` wraps the raw Godot invocation. It exists for two measured reasons,
both of which cost time before it was written:

1. Godot writes heavily to stderr (every `push_error` prints a full GDScript backtrace).
   Piping stdout+stderr through PowerShell can block on a full pipe, so the runner
   redirects to files and prints them afterwards.
2. A suite that fails to **compile** makes `RunTests._initialize()` throw before it can
   call `quit()`, which leaves the headless SceneTree running forever. The runner does a
   `--check-only` parse pass first, so a compile error is an immediate readable failure
   rather than a hang.

The raw command still works and produces the same numbers:

```bash
"C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --headless --path "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame" --script res://Scripts/tests/RunTests.gd
```

---

## Summary — actual measured results

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules tests | 13 | 630 | **630** | 0 |
| Per-card tests | 1 | 43 | **43** | 0 |
| Interaction tests | 0 | 0 | 0 | 0 |
| Scripted duel tests | 0 | 0 | 0 | 0 |
| **TOTAL** | **14** | **673** | **673** | **0** |

Card library: **1 / 77 implemented, 1 / 77 tested** — computed by `Tools/build_matrix.py`
from `Scripts/cards/registry/*.gd` and `Tests/cards/*.gd`, never by hand.

`RESULT: PASS`, exit code 0.

Separately, `Scripts/tests/SmokeCheck.gd` passes (data load + RNG determinism); it is a
load check, not part of the rules suite count above.

**No suite reports success with zero executed assertions.** `RunTests.gd` treats a
zero-assertion suite as an explicit failure; that guard is load-bearing and must not be
removed.

---

## Suites

| Suite | Assertions | Rules |
|---|---:|---|
| `ChainTests` | 27 | `RULES_SPEC.md §4` |
| `TimingTests` | 37 | `RULES_SPEC.md §3`, `§4.4` |
| `TurnFlowTests` | 40 | `RULES_SPEC.md §1, §2, §13` |
| `SummonTests` | 45 | `RULES_SPEC.md §5` |
| `SpellTrapTests` | 27 | `RULES_SPEC.md §4.2` |
| `BattleTests` | 72 | `RULES_SPEC.md §6` |
| `DamageStepTests` | 86 | `RULES_SPEC.md §7` |
| `ContinuousTests` | 52 | `RULES_SPEC.md §4.2/§8`, master prompt §25 |
| `CounterTests` | 44 | `RULES_SPEC.md §14`, `CARD_RULINGS.md` |
| `HiddenInfoTests` | 76 | `RULES_SPEC.md §9, §12` |
| `SpecialSummonTests` | 54 | `RULES_SPEC.md §5.5` |
| `RulesQuestionTests` | 37 | `RULES_SPEC.md §8.1, §12.1`, `§6/§7`, `§2.3` |
| `ReplayTests` | 33 | master prompt §8 / §70 |

### ChainTests — 27/27
`Tests/rules/ChainTests.gd`. Rules: `RULES_SPEC.md §4` (Rulebook v10 pp.44–47, 51).

| Test | Asserts | Rule verified |
|---|---:|---|
| spell speed response legality | 8 | SS1 may be Chain Link 1; SS1 cannot respond; SS2/SS3 may [S1 p.44] |
| chain link numbering | 4 | activations become Chain Link 1, 2, 3 in order |
| reverse chain resolution | 3 | resolves highest link first; chain cleared [S1 p.46-47] |
| negate activation vs negate effect | 8 | the two negation kinds are distinct (master prompt §18) |
| counter trap response restriction | 3 | only SS3 may respond to SS3 [S1 p.45] |
| chain link number readable at resolution | 1 | needed by Chain Detonation / Chain Healing (R4) |
| unimplemented effect fails loudly | 1 | a missing `resolve()` errors instead of being skipped (§67) |

### TimingTests — 37/37
`Tests/rules/TimingTests.gd`. Rules: `RULES_SPEC.md §3` (official Fast Effect Timing
chart, S2) and `§4.4` [S1 p.51].

| Test | Asserts | Rule verified |
|---|---:|---|
| summon opens a response window | 6 | a Summon does not return to an open game state while a legal response exists (master prompt §23) |
| optional trigger requires consent | 6 | an optional Trigger Effect is offered, and answering "no" does not activate it (§24) |
| mandatory trigger is not asked | 2 | a mandatory trigger fires and is never presented as a choice |
| simultaneous trigger group order | 1 | Chain built TP-mandatory → opp-mandatory → TP-optional → opp-optional [S1 p.51] |
| within-group order is asked | 2 | the owning player chooses the order inside their own group |
| Spell Speed 1 never offered as a response | 2 | a Normal Spell is not a fast effect [S1 p.44] |
| Quick Effect offered in a response window | 4 | a monster Quick Effect is Spell Speed 2 and usable in a window |
| two consecutive passes close the chain | 7 | one pass does not close it; responses alternate [S2 box D] |
| triggers during resolution wait | 2 | a trigger raised mid-resolution becomes a Chain Link only after `CHAIN_RESOLVED` (master prompt §45) |
| summon negation | 6 | a negated Summon never occupies a Monster Zone; the allowance is still spent |

### TurnFlowTests — 40/40
`Tests/rules/TurnFlowTests.gd`. Rules: `RULES_SPEC.md §1, §2, §13`.

Covers 8000 starting LP, the 5-card opening hand, the first player's skipped turn-1 draw,
the turn-1 Battle Phase prohibition, Draw→Standby→Main 1→End ordering, Battle Phase→Main
Phase 2, the Normal Summon allowance resetting each turn, the 6-card hand-size discard at
the end of the End Phase, and losing by deck-out.

### SummonTests — 45/45
`Tests/rules/SummonTests.gd`. Rules: `RULES_SPEC.md §5`.

Covers one Normal Summon **or** Set per turn, Normal Summon in face-up Attack vs Set in
face-down Defense, a Normal Set not being a Summon, Tribute counts by Level (0/1/2), a
Tribute not being a destruction but still being "sent to the GY", a card that counts as
two Tributes for a LIGHT Summon (the `Kaiser Sea Horse` mechanic), a full Monster Zone
blocking a 0-Tribute Summon while still allowing a Tribute Summon, Flip Summon being
illegal the turn a monster was Set and legal later, and the three manual
position-change restrictions.

### SpellTrapTests — 27/27
`Tests/rules/SpellTrapTests.gd`. Rules: `RULES_SPEC.md §4.2` and [S1 p.28–31].

Covers the Trap Set-turn restriction, a Set Normal Spell being activatable the same turn,
the Quick-Play exception to that, which cards a player may activate on the opponent's turn
(Set Quick-Play yes, Set Normal Spell no), a Normal Spell going to the GY after resolving,
a Continuous Spell staying on the field, and a new Field Spell replacing the old one.

### BattleTests — 72/72
`Tests/rules/BattleTests.gd`. Rules: `RULES_SPEC.md §6` [S1 p.37–39, 52].

| Test | Asserts | Rule verified |
|---|---:|---|
| Start Step is a real response window | 8 | the phase does not change until box E closes; the Battle Phase then opens in its Start Step, which is itself a window [S1 p.37; S2 box E] |
| no attacks outside the Battle Step | 4 | attacks are offered in the Battle Step only, not Main 1 or Main 2 |
| which monsters may attack | 7 | face-up Attack Position, turn player's own, on the field; not Defense, not face-down, not the opponent's [S1 p.38] |
| one attack per monster per turn | 5 | the used attacker is withdrawn, others remain, and the allowance returns next turn [S1 p.38] |
| `cannot_attack` restriction honoured | 3 | a continuous restriction removes the attack, and lifts with its source |
| direct attack legality | 6 | rejected while the opponent controls a monster; legal and full-ATK once the field is empty [S1 p.38, p.43] |
| attack target validation | 5 | targets are exactly the opponent's monsters (face-down included); a monster you control is rejected |
| declaration opens a window | 7 | ATTACK_DECLARED / ATTACK_TARGET_SELECTED emitted, opponent gets the window, no Damage Step sub-step entered until it closes |
| attacker leaving cancels the attack | 7 | no damage calculation, no Damage Step, target untouched, nobody "battled" [S1 p.52] |
| **removing the target causes a Replay** | 8 | a removed target is a Replay, not a cancelled attack; the attack is not spent and may be re-declared [S1 p.39] |
| replay with a different monster | 6 | the original monster is still treated as having declared an attack and cannot attack again [S1 p.39] |
| Battle Phase ends into Main Phase 2 | 6 | passes through the End Step, reaches Main Phase 2, leaves no battle state behind [S1 p.37, p.40] |

### DamageStepTests — 86/86
`Tests/rules/DamageStepTests.gd`. Rules: `RULES_SPEC.md §7` [S1 p.41–43, 51–52; S3].

| Test | Asserts | Rule verified |
|---|---:|---|
| sub-steps run in order | 4 | all five sub-steps in the [S3] order; Battle Step handed over and back; no sub-step left set |
| Attack vs Attack Position calculation | 11 | all three rows of §7.4, damage direction and amount, DEF not involved [S1 p.42] |
| Attack vs Defense Position calculation | 11 | all three rows: destroyed with no damage, neither destroyed, attacker's controller takes DEF−ATK [S1 p.42] |
| 0 ATK destroys nothing | 5 | two 0-ATK monsters destroy neither; a real attacker still destroys a 0-ATK monster [S1 p.51] |
| destruction determined before the GY | 6 | destruction decided during damage calculation, card sent only in sub-step 5 — asserted from event order [S3] |
| battle destruction is semantically distinct | 7 | `DESTROYED_BY_BATTLE` reason, `CARD_DESTROYED` **and** `CARD_SENT_TO_GY`, never a Tribute, into the **owner's** GY [S1 p.52–53] |
| face-down target flip timing | 8 | flipped in sub-step 2, Flip effect becomes a Chain Link only in sub-step 4 [S1 p.41] |
| activation restriction (rule) | 7 | `NONE` illegal in all five sub-steps; `UNTIL_DAMAGE_CALC` legal in 1–2 and illegal from 3 on; `MANDATORY_TRIGGER` is about timing, not optionality [S1 p.41] |
| activation restriction (live Damage Step) | 6 | both traps offered before the Damage Step; inside it the `NONE` trap is never offered and the permitted one only up to damage calculation |
| optional battle-destruction trigger declined | 5 | the `Shining Angel` shape is **optional**: its controller is asked exactly once, and "no" activates nothing |
| optional battle-destruction trigger accepted | 8 | becomes a Chain Link in sub-step 5 after the card reached the GY, over candidates filtered by the card's own restriction |
| no trigger without battle destruction | 6 | a real activation sends the same card to the GY by effect; the destroyed-by-battle trigger does not fire and its controller is never asked |
| battle damage to 0 LP ends the Duel | 6 | LP floored at 0, result, end reason, timing machine, no further legal action [S1 p.33] |

### ContinuousTests — 52/52
`Tests/rules/ContinuousTests.gd`. Rules: `RULES_SPEC.md §4.2/§8`, master prompt §25.

| Test | Asserts | Rule verified |
|---|---:|---|
| ATK/DEF modifiers apply | 5 | continuous modifiers apply; the printed values and "original ATK" are untouched |
| recompute rebuilds, never accumulates | 4 | five recomputes equal one; exactly one modifier entry; playing on does not inflate it |
| source leaving the field | 4 | the modifier disappears with its source, leaving no stale entry |
| source flipped face-down | 3 | a face-down source applies nothing, and applies again when flipped back up |
| negated source | 3 | a negated source applies nothing, and resumes when the negation ends |
| restriction flags owned by the system | 4 | an unsourced restriction flag does not survive a recompute; unrelated flags are untouched; an unknown flag is rejected loudly |
| multiple simultaneous modifiers | 5 | two sources apply together as separate entries and leave independently |
| counter-scaled modifier | 6 | the `Wonder Balloons` shape follows counters up and down exactly, and ATK floors at 0 |
| `cannot_be_destroyed_by_battle` | 4 | survives damage calculation while battle damage is still inflicted; removing the source restores normal destruction |
| never starts a Chain | 6 | `starts_chain` false, no `resolve()`, never offered as an action, no Chain Link or activation event |
| applies once its source is on the field | 4 | nothing while in the hand; applying after the activation resolved |
| player-level restrictions | 5 | namespaced under `continuous:`, per player, cleared on recompute, unrelated restrictions untouched |

### CounterTests — 44/44
`Tests/rules/CounterTests.gd`. Rules: `RULES_SPEC.md §14`, `Research/CARD_RULINGS.md`.

Generic counter primitives for the two V1 cards that need them (`Apprentice Magician` —
Spell Counter, `Wonder Balloons` — Balloon Counter). Covers placing and reading, counters
tracked per kind and per instance, all-or-nothing removal (removal is used as a **cost**,
so a partial payment must be impossible), counts never going negative, counters only being
placeable on a face-up card on the field, `COUNTER_PLACED` / `COUNTER_REMOVED` carrying
kind/amount/total, a rejected removal emitting nothing, counters cleared when the card
leaves the field and not restored when it returns, and counters on a face-up card being
public to both players.

### HiddenInfoTests — 76/76
`Tests/rules/HiddenInfoTests.gd`. Rules: `RULES_SPEC.md §9, §12` [S1 p.50, p.52].

Every leak test runs from **both** sides. Covers: hand contents private to their owner
while the card's presence is public; face-down field cards hidden by identity but public
by position, with no ATK/Level leak, and public once flipped; Deck contents and order
exposed to nobody (asserted by walking every string in the whole view against the
opponent's Deck); face-up field, both Graveyards, face-up banished cards and LP public to
both; hand/Deck/GY/banished counts and the Normal Summon allowance public; a card legally
revealed to one player visible to that player only, per card; private draw events filtered
out of the public log while a player's own draws stay in their own log; Chain contents
public to both while a Chain is open; and owner reported separately from controller, with
a card whose control changed still going to its **owner's** Graveyard.

---

### SpecialSummonTests — 54/54
`Tests/rules/SpecialSummonTests.gd`. Rules: `RULES_SPEC.md §5.5` [S1 p.24].

This was the last UNVERIFIED path in the rules engine: `SummonRules.begin_special_summon()`
compiled but nothing reached it. 22 of the 77 V1 cards Special Summon something.

| Test | Asserts | Rule verified |
|---|---:|---|
| procedure Summon declares then succeeds | 9 | DECLARED precedes SUCCEEDED; `summoned_by = SPECIAL`; properly Special Summoned; not a Normal Summon |
| declaration window opens first | 6 | the monster waits in `IN_TRANSIT`, controls no zone, and no success event fires until the window closes |
| a negated Special Summon | 5 | `SUMMON_NEGATED` emitted, **no** `SPECIAL_SUMMON_SUCCEEDED`, the card returns to the hand rather than being destroyed |
| the Normal Summon allowance | 5 | a Special Summon does not spend it; a Normal Summon is still legal in the same turn [S1 p.24] |
| a full Monster Zone | 5 | the procedure is not offered, the engine hook returns false, the card does not move, nothing is announced |
| Special Summon from the Deck mid-resolution | 7 | the `Shining Angel` shape: summoned during resolution, left the Deck, in the effect's position |
| Special Summon from the GY mid-resolution | 5 | returns from the GY in the chosen position under its controller |
| position is the player's choice | 6 | both face-up positions offered; a face-down choice the card did not grant is rejected and changes nothing |

### RulesQuestionTests — 37/37
`Tests/rules/RulesQuestionTests.gd`. The four questions Phase 4b recorded rather than
guessed, each now decided against an official source and pinned down.

| Test | Asserts | Rule verified |
|---|---:|---|
| a Continuous Trap waits for its own activation | 8 | the continuous clause does **not** apply while its activation is an unresolved Chain Link, and applies the moment it resolves — `RULES_SPEC.md §8.1` [S1 p.17, p.18 with p.44–47] |
| and keeps applying while face-up | 4 | recomputes do not stack it; it ends with its source |
| shuffled into the Deck | 4 | `revealed_to` is cleared by a shuffle, and by `shuffle_deck()` for every card — `RULES_SPEC.md §12.1` [S1 p.5, p.28] |
| placed on the Deck without a shuffle | 3 | `revealed_to` survives: the position is still known, so the rule is keyed on the shuffle |
| continuous player restriction | 6 | `TurnFlow.can_enter_battle_phase()` now consumes `continuous:cannot_conduct_battle_phase`, the action disappears, and it lifts with its source |
| turn-scoped restriction | 6 | `skip_battle_phase_this_turn` survives a recompute, blocks the Battle Phase, and expires at end of turn — the two restrictions stay independent |
| piercing battle damage | 5 | ATK − DEF is inflicted when a Defense Position monster is destroyed [S1 p.42] |
| no piercing without the flag | 3 | the defender still dies but no damage is inflicted — piercing is never the default |

### ReplayTests — 33/33
`Tests/rules/ReplayTests.gd`. Master prompt §8 / §70.

| Test | Asserts | Property verified |
|---|---:|---|
| the payload records the inputs | 8 | seed, first player, every submitted action with its turn/phase, strictly increasing and collision-free sequence numbers shared with the decision stream |
| the payload carries the Deck contents | 6 | `deck_lists` holds both 40-card Decks in **pre-shuffle** order |
| every decision is recorded | 5 | the log holds exactly as many decisions as the players were asked, including optional-trigger consent |
| **replay reproduces the duel** | 11 | rebuilt from the payload alone, the replayed duel produces an **identical event stream**, LP, hand, board, turn number and Deck order |
| a replayed action is re-validated | 5 | `DuelAction.from_dict()` round-trips, a forged action is rejected, and a rejected action is never logged |

---

## Defects found and fixed by these tests

### This milestone (Phase 4c — the generic-engine gate)

1. **`SummonRules.begin_special_summon()` was unreachable from the engine.** It existed and
   compiled, but no engine path called it, so "Special Summon" was not a capability the
   engine actually had. Two paths were added and tested: `DuelEngine.special_summon()` for
   the resolution-time case (the `Shining Angel` family) and the
   `SPECIAL_SUMMON_PROCEDURE` action for the open-game-state case (`Hieratic Dragon of
   Tefnuit`, `Inari Fire`, `Ranryu`, `Nefarious Archfiend`), the latter opening a real
   declaration window so a Summon negation can answer it.
2. **The replay payload could not reproduce a duel.** It carried the Deck *names* but not
   the Deck *contents*, and the seed only determines how a **known** Deck is shuffled.
   `deck_lists` (pre-shuffle order) was added.
3. **Most player decisions were never recorded.** Only `DuelEngine`'s target selection went
   into the log; optional-trigger consent, trigger ordering, the End Phase hand-size
   discard and every mid-resolution `EffectContext.ask()` were lost, so any duel
   containing one of them was unreplayable. `TriggerCollector`, `TurnFlow` and
   `EffectContext` now record through the same log.
4. **A Continuous Spell/Trap applied its continuous effect one step too early.** It applied
   as soon as the card was face-up, i.e. from activation, which would let it affect the
   resolution of Chain Links above it. It now waits for its own activation to resolve.
5. **Player-level continuous restrictions were consumed by nothing.** `restrict_player()`
   round-tripped but `TurnFlow.can_enter_battle_phase()` only read the separate
   un-namespaced key. It now honours both, and the two are documented as having
   deliberately different lifetimes.
6. **Piercing was wrongly believed to be unexercised by the V1 pool.** `Rider of the Storm
   Winds` grants it ("If a monster equipped with this card attacks a Defense Position
   monster, inflict piercing battle damage"), so the branch is required and is now tested
   in both directions.

No test expectation was weakened to make the implementation pass, and none of the 506
earlier assertions was retargeted or deleted.

### Previous milestone (Phase 4b-3)

1. **Removing the attack TARGET cancelled the attack instead of causing a Replay.**
   `DuelEngine._advance_battle()` called `BattleRules.attack_still_valid()` — which
   checked the attacker *and* the target — before `replay_required()`, so a destroyed
   target silently swallowed the Replay. `RULES_SPEC.md §6.2` [S1 p.39] is explicit that a
   removed target **is** a Replay. Fixed by splitting the check into
   `attacker_still_valid()` / `target_still_valid()` and running the Replay check first.
   Caught by `BattleTests :: removing the attack target causes a Replay`.
2. **`get_visible_state()` ignored `revealed_to` for cards in the opponent's hand.**
   `CardInstance.revealed_to` is documented as the record of who has legally seen a hidden
   card, and `_visible_card()` honours it — but the opponent's hand was mapped straight to
   `_hidden_card_stub()`, bypassing it. A card revealed to a player stayed invisible to
   them. Fixed by routing the opponent's hand through `_visible_card()`, which still
   returns a stub in every other case. Caught by
   `HiddenInfoTests :: a card revealed to a player stays visible to that player only`.
3. **Two test-harness gaps that would have silently weakened later tests.**
   `TestFixtures.end_turn()` and `advance_to_phase()` both looked for `END_PHASE`, which
   the Battle Phase does not offer (it offers `END_BATTLE_PHASE`), so any duel that
   reached the Battle Phase could not be advanced and the helper returned `false`
   unnoticed. Both now fall back correctly.

No test expectation was weakened to make the implementation pass.

### Earlier milestones

1. **`RunTests.gd` reported PASS for a suite that ran zero assertions.** When `TimingTests`
   failed to compile, the runner printed `TimingTests: 0/0 passed` and still exited 0.
   Fixed: a suite with zero assertions is now an explicit failure. This remains the most
   important guard in the harness — without it a green run proves nothing.
2. **Repeated `:=` type-inference compile failures.** GDScript cannot infer through a
   `Variant` (an untyped `Array` element, or a function declared `-> Variant`). This bit
   again this milestone in `BattleTests`, `DamageStepTests` and `HiddenInfoTests`.
   Annotate explicitly.
3. **`project.godot` pointed `run/main_scene` at `res://Scenes/ui/Boot.tscn`, which does
   not exist yet**, so every headless run logged a resource load error. Unset until the
   Phase 7 UI exists.

## Known issues in the harness (not rules defects)

* The run reports `~24500 ObjectDB instances were leaked at exit`. These are RefCounted
  reference cycles between `GameState`, `DuelLog` (connected signal) and the closures the
  tests capture. The count grows with the number of duels the suite builds. It does not
  affect any rules outcome and does not fail the suite, but it must be cleaned up before
  the UI keeps a duel alive for a long session.
* The run prints two `SCRIPT ERROR` lines from `push_error`. Both are **intentional** and
  are what the corresponding assertions require:
  `ChainTests` proves a missing `resolve()` fails loudly, and `ContinuousTests` proves an
  unknown restriction flag is rejected rather than silently written.
* A GDScript single-line lambda ends at the newline. A wrapped lambda body inside a call
  needs an explicit `\` continuation or it is a parse error with no line number.

---

## Not yet covered (required by master prompt §64 — tracked, not claimed)

**A. Core rules** — still missing: GY-activated effects beyond the destroyed-by-battle
shape, equip mechanics (the `MoveReason.RULE` unequip path runs but nothing asserts it),
and simultaneous-LP-zero draws. Special Summon execution, piercing battle damage and the
duel log / replay payload were the other three and are now covered.

**B. Per-card** — **1 of 77** cards implemented and tested (`Shining Angel`). The other 76
are honestly reported as `NOT_IMPLEMENTED` / `NOT_TESTED` in
`Reports/CARD_IMPLEMENTATION_MATRIX.csv`.

### ShiningAngelTests — 43/43
`Tests/cards/ShiningAngelTests.gd`. The first per-card suite, and the shape every later
one follows: the clause is exercised **positively and negatively**, and the negatives are
where the value is.

| Test | Asserts | What it proves |
|---|---:|---|
| the registry loads cleanly | 5 | all 77 definitions load, the registry reports no errors, one `EffectDef` per official clause, and the card name is stamped onto the effect |
| the clause shape | 9 | optional Trigger Effect, Spell Speed 1, Damage Step window as a *timing* permission, activates from the GY, and **does not target** — the official text has no "target", so the monster is chosen at resolution |
| destroyed by battle | 12 | a LIGHT monster with ≤1500 ATK arrives from the Deck in Attack Position by Special Summon; the controller is asked exactly once; **every candidate offered passes the clause's own filter** while the too-strong LIGHT copies in the same Deck are excluded |
| declining | 6 | asked, said no, nothing Summoned, Deck untouched |
| destroyed by a card effect | 3 | not destroyed *by battle*, so nobody is asked [S1 p.52–53] |
| Tributed | 3 | a Tribute **is** "sent to the GY" and the trigger event does fire, but the clause still does not — destruction by battle is what it requires |
| no legal monster in the Deck | 3 | the controller is not asked a question with no possible answer |
| a full Monster Zone | 4 | the zone the Angel itself vacated is available, so the recruit legitimately fills it |

**C. Interaction** — none yet.

**D. Scripted full duels** — none yet.

### Open rules questions — all four now RESOLVED (Phase 4c)

* **When a Continuous Spell/Trap's continuous effect begins applying.** DECIDED: only once
  its own activation resolves. `RULES_SPEC.md §8.1` [S1 p.17, p.18 with p.44–47]. The
  section records honestly that no single official sentence states the start point
  verbatim and that the decision rests on the rulebook's activation-vs-resolution
  separation.
* **Whether `revealed_to` survives a shuffle into the Deck.** DECIDED: no — but it *does*
  survive a placement on top/bottom without a shuffle, because the position is still
  known. `RULES_SPEC.md §12.1` [S1 p.5, p.28].
* **Player-level continuous restrictions.** RESOLVED: `TurnFlow.can_enter_battle_phase()`
  now consumes `continuous:cannot_conduct_battle_phase` as well as the turn-scoped
  `skip_battle_phase_this_turn`. Both are kept because their lifetimes differ — one is
  rebuilt on every recompute, the other must survive one.
* **Piercing battle damage.** The earlier note that no V1 card requires it was WRONG:
  `Rider of the Storm Winds` grants piercing. Both branches are now tested.

Coverage is reported honestly here and in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`
(**1 / 77 implemented, 1 / 77 tested**). No test result in this file is estimated or
projected.

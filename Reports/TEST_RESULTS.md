# TEST_RESULTS

**Last run:** 2026-08-12 (Phase 5 batch 3)
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
| Core rules tests | 14 | 713 | **713** | 0 |
| Per-card tests | 15 | 801 | **801** | 0 |
| Interaction tests | 1 | 46 | **46** | 0 |
| Scripted duel tests | 0 | 0 | 0 | 0 |
| **TOTAL** | **30** | **1560** | **1560** | **0** |

Per-test assertion counts in this file are **measured**, not counted by hand from source:
`TestCase` records them per test and `Scripts/tests/DumpAssertionCounts.gd` prints them.
A suite that loops over nine cards runs many more assertions than it has `t.` call sites,
and the earlier hand-written `ShiningAngelTests` breakdown was wrong for exactly that
reason — it has been corrected against the measurement.

Card library: **23 / 77 implemented, 23 / 77 tested** — computed by `Tools/build_matrix.py`
from `Scripts/cards/registry/*.gd`, the card database's `is_normal` flag and
`Tests/cards/*.gd`, never by hand.

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
| `EquipTests` | 83 | `RULES_SPEC.md §16, §17` [S1 p.29, p.53, p.55] |
| `ShiningAngelTests` | 43 | per-card |
| `NormalMonsterTests` | 76 | per-card (9 cards) |
| `MonsterRebornTests` | 48 | per-card |
| `SilversCryTests` | 47 | per-card |
| `KaibamanTests` | 47 | per-card |
| `DragonicTacticsTests` | 39 | per-card |
| `OneForOneTests` | 40 | per-card |
| `BirthrightTests` | 59 | per-card |
| `CallOfTheHauntedTests` | 48 | per-card |
| `HieraticDragonOfTefnuitTests` | 67 | per-card |
| `InariFireTests` | 65 | per-card |
| `RanryuTests` | 49 | per-card |
| `NefariousArchfiendTests` | 44 | per-card |
| `GagagashieldTests` | 63 | per-card |
| `RiderOfTheStormWindsTests` | 66 | per-card |
| `SpecialSummonInteractionTests` | 46 | interaction |

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

### EquipTests — 83/83
`Tests/rules/EquipTests.gd`. Rules: `RULES_SPEC.md §16, §17` [S1 p.29, p.53, p.55].

This suite is the **Equip gate**: before it existed, equip mechanics had **zero** assertions
while `GameState._unequip_all()` quietly ran on every field departure. It is a RULES suite
built from synthetic cards, so what it proves is that the ENGINE is right rather than that one
printed card happens to work. `Gagagashield` and `Rider of the Storm Winds` were only written
once it passed.

| Test | Asserts | Rule verified |
|---|---:|---|
| equipping attaches to one face-up monster | 10 | both sides of the relationship, a real Spell & Trap Zone slot, one `CARD_EQUIPPED` event [S1 p.29] |
| only a legal host can be equipped | 8 | face-down / off-field / itself all rejected; an equipped card "cannot be moved to a different target" [S1 p.53] |
| the granted effect follows the host | 7 | the modifier applies to the host, the printed and **original** ATK are untouched, five recomputes equal one [S1 p.55] |
| **the host leaving the field destroys the Equip Card** | 8 | destroyed with `MoveReason.DESTROYED_BY_RULE`, **not** `DESTROYED_BY_EFFECT`, plus a `CARD_UNEQUIPPED` event [S1 p.29] |
| **the host flipped face-down destroys it** | 5 | the monster never moves, so `move_card()` never sees this — it is handled in `set_battle_position()` [S1 p.29, p.55] |
| the Equip Card leaving takes its effect with it | 6 | the monster survives, with no stale modifier and no stale relationship |
| **battle is recalculated from the equipped ATK** | 7 | a 1000 ATK attacker that would lose beats a 1500 ATK defender once equipped, for 200 damage [S1 p.42] |
| an Equip Spell that resolves without equipping | 8 | no host, so it does not stay on the field, and no `CARD_EQUIPPED` was ever emitted [S1 p.29] |
| a target that became illegal | 8 | still on the field but no longer face-up so it is not equipped to |
| **a counted destruction prevention** | 9 | exactly N destructions per turn are stopped, the N+1th lands, uncovered cards were never protected, and the count returns next turn |
| **a destruction replacement** | 7 | the substitute is destroyed instead — a replacement is not a prevention — and with the substitute gone the next destruction lands |

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

### This milestone (Phase 5 batch 3 — Continuous-Trap revival, summoning procedures, Equip)

Three defects, two of them in engine code written during this batch and caught before the
cards that depend on it were written, one a genuine gap in the pre-existing engine.

1. **`GameState.move_card()` captured "was this card face-up?" AFTER the move had already
   rewritten the position.** The new `last_move_was_face_up` record (RULES_SPEC.md §15.1) was
   read after `_attach()` and the position-handling block, and those overwrite
   `card.position`: a card sent to the Graveyard is turned FACE_UP by the move itself, and one
   returned to the hand is turned FACE_DOWN. So the flag answered a question about the
   DESTINATION rather than about where the card came from — it would have read `true` for every
   card sent to the GY, including one destroyed while face-down, and `false` for a face-up card
   bounced to the hand. `Inari Fire`'s "after this **face-up card on the field** was destroyed
   by card effect" depends entirely on it. Fixed by capturing `was_face_up` at the top of
   `move_card()` alongside `was_on_field`, before `_detach()`. Covered by
   `InariFireTests :: the Standby revival`.
2. **`CARD_DESTROYED` was not emitted for a rules destruction.** `Enums.MoveReason` gained
   `DESTROYED_BY_RULE` this batch (an Equip Card losing its host is destroyed by the game rules,
   not by a card effect [S1 p.29, p.55]), and `Enums.is_destruction()` was updated — but the
   `match reason:` block in `move_card()` that emits the semantic event was not, so an Equip
   Card was silently sent to the Graveyard with no `CARD_DESTROYED` event at all. Any future
   "when a card is destroyed" trigger would have missed it. Caught by
   `EquipTests :: the host leaving the field destroys the Equip Card` on its first run.
3. **`DuelEngine._cleanup_resolved_spell_traps()` decided what stays on the field from the card
   KIND alone.** That is wrong in both directions once Equip Cards exist: a NORMAL Trap that
   equipped (`Gagagashield`) must stay, and an Equip Spell that resolved without equipping must
   not. The equip relationship now takes precedence over `Enums.stays_on_field()`. Covered by
   `GagagashieldTests :: a Normal Trap that stays on the field` and
   `EquipTests :: an Equip Spell that resolves without equipping`.

**No pre-existing rules defect was found by the 544 new assertions beyond item 3**, and that is
reported as-is. All 1016 assertions from the previous milestone still pass unchanged; none was
weakened, retargeted or deleted.

Two test-authoring mistakes are worth recording because they cost a cycle and will recur:

* A test that mutates the board by calling `GameState.move_card()` / `destroy()` directly does
  **not** reach a trigger check — those events never enter `_pending_events`. A trigger effect
  can only be observed if the change travels through the timing machine, i.e. through a real
  card effect resolving. `TestFixtures.interferer()` exists for exactly this.
* The engine resolves a whole Chain inside one `submit_action()` when nobody holds a legal
  response, so a test that needs to change the board BETWEEN an activation and its resolution
  must give the opponent a real Spell Speed 2 effect. Two `EquipTests` cases were written
  without one and silently tested nothing until they failed.

### Previous milestone (Phase 5 batch 1+2)

**No rules-engine defect was found by this batch, and that is reported as-is rather than
dressed up.** Every one of the 343 new assertions passed against the engine as Gate B
left it, which is the outcome Gate B was supposed to produce. Three real problems were
found and fixed, none of them in the rules:

1. **`Tools/build_matrix.py` could never report a vanilla Normal Monster as implemented.**
   It derived implementation status purely from the presence of a registry file, but a
   card with no effect text correctly has no registry file — `CardDef.is_vanilla()` and
   `CardRegistry.unimplemented()` already treated an empty effect list as the complete
   implementation, so the matrix and the engine disagreed. The matrix now counts a card
   as implemented when it has a registry file **or** when the card database marks it
   `is_normal`, and `NormalMonsterTests` asserts the shortcut cannot be abused: no Effect
   Monster satisfies `is_vanilla()`, and every non-vanilla card without effects is still
   on the honest unimplemented list.
2. **A suite could not report covering more than one card.** `tested_cards()` read only
   the singular `CARD_UNDER_TEST`, so a mechanic-group suite could not mark its cards
   TESTED without nine near-identical files. It now also reads a `CARDS_UNDER_TEST`
   array. An interaction suite declares neither marker, so a card is still only ever
   counted as TESTED because it has its own suite.
3. **The per-test assertion counts in this file were estimates, and at least one was
   wrong.** The published `ShiningAngelTests` breakdown summed to 45 against a suite that
   runs 43. `TestCase` now records assertions per test and
   `Scripts/tests/DumpAssertionCounts.gd` prints them, so every per-test number in this
   file is measured. The `ShiningAngelTests` table has been corrected.

One test was also strengthened after measurement showed it was thin:
`DragonicTacticsTests :: a Level 7 Wyrm does not qualify` ran a single assertion, so a
positive control was added — adding a Level 8 Dragon to the same Deck makes the card
activatable — which turns the negative from "something blocked it" into "the filter
blocked it".

### Earlier milestone (Phase 4c — the generic-engine gate)

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

### Earlier milestone (Phase 4b-3)

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

* The run reports `50075 ObjectDB instances were leaked at exit`. These are RefCounted
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

**A. Core rules** — still missing: **simultaneous-LP-zero draws**. Equip mechanics were
on this list and are now covered end to end by `EquipTests` (83 assertions), together with
destruction prevention and destruction replacement. GY-activated effects were on it too and
are now exercised by `Inari Fire`, `Ranryu` and `Nefarious Archfiend Eater of
Nefariousness`. Special Summon execution, piercing battle damage and the duel log / replay
payload were covered in the previous milestone.

**B. Per-card** — **23 of 77** cards implemented and tested: the 9 vanilla Normal
Monsters, `Shining Angel`, the first Special Summon batch (`Monster Reborn`,
`Silver's Cry`, `Kaibaman`, `Dragonic Tactics`, `One for One`) and batch 3 (`Birthright`,
`Call of the Haunted`, `Hieratic Dragon of Tefnuit`, `Inari Fire`, `Ranryu`,
`Nefarious Archfiend Eater of Nefariousness`, `Gagagashield`,
`Rider of the Storm Winds`). The other 54 are honestly reported as `NOT_IMPLEMENTED` /
`NOT_TESTED` in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`.

### ShiningAngelTests — 43/43
`Tests/cards/ShiningAngelTests.gd`. The first per-card suite, and the shape every later
one follows: the clause is exercised **positively and negatively**, and the negatives are
where the value is.

| Test | Asserts | What it proves |
|---|---:|---|
| the registry loads cleanly | 5 | all 77 definitions load, the registry reports no errors, one `EffectDef` per official clause, and the card name is stamped onto the effect |
| the clause shape | 9 | optional Trigger Effect, Spell Speed 1, Damage Step window as a *timing* permission, activates from the GY, and **does not target** — the official text has no "target", so the monster is chosen at resolution |
| destroyed by battle | 11 | a LIGHT monster with ≤1500 ATK arrives from the Deck in Attack Position by Special Summon; the controller is asked exactly once; **every candidate offered passes the clause's own filter** while the too-strong LIGHT copies in the same Deck are excluded |
| declining | 5 | asked, said no, nothing Summoned, Deck untouched |
| destroyed by a card effect | 3 | not destroyed *by battle*, so nobody is asked [S1 p.52–53] |
| Tributed | 3 | a Tribute **is** "sent to the GY" and the trigger event does fire, but the clause still does not — destruction by battle is what it requires |
| no legal monster in the Deck | 3 | the controller is not asked a question with no possible answer |
| a full Monster Zone | 4 | the zone the Angel itself vacated is available, so the recruit legitimately fills it |

### NormalMonsterTests — 76/76
`Tests/cards/NormalMonsterTests.gd`. Covers all nine vanilla Normal Monsters at once via
`CARDS_UNDER_TEST`, because their implementation is shared: an EMPTY effect list is the
correct and complete implementation of a card with no effect text.

| Test | Asserts | What it proves |
|---|---:|---|
| all nine are vanilla | 38 | exactly nine cards in the pool satisfy `is_vanilla()`, and each is a Normal Monster with zero `EffectDef`s |
| Tribute requirement follows Level | 9 | 0 / 1 / 2 Tributes by printed Level, on the real cards [S1 p.24-25] |
| Normal Summon a real vanilla | 9 | Sabersaurus reaches a Monster Zone face-up in Attack Position with its printed 1900/500, spending the turn's one Normal Summon |
| Tribute Summon a real vanilla | 8 | Blue-Eyes White Dragon needs two Tributes, both reach the Graveyard, and only the Summoned monster remains |
| a vanilla battles on printed stats | 4 | Alexandrite Dragon 2000 beats Sabersaurus 1900; 100 battle damage [S1 p.42] |
| offers no effect to activate | 4 | no `ACTIVATE_EFFECT` / `ACTIVATE_CARD` / summon procedure is offered, and a hand-built activation is rejected |
| **no Effect Monster is treated as vanilla** | 4 | `is_vanilla()` is false for every Effect Monster; every non-vanilla card with no effects is still on `CardRegistry.unimplemented()`; the two categories never overlap, and that list is genuinely non-empty |

The last test is the load-bearing one: it is what stops "vanilla counts as implemented"
from becoming a way to over-report an unimplemented Effect Monster.

### MonsterRebornTests — 48/48
`Tests/cards/MonsterRebornTests.gd`. "Target 1 monster in either GY; Special Summon it."

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 9 | Spell Speed 1 card activation, targets exactly 1, activatable from hand or a Set copy, no invented once-per-turn |
| revives from your own GY | 8 | the target leaves the GY, is properly Special Summoned, the Spell goes to the GY, and the Normal Summon is untouched |
| the player chooses the position | 4 | face-up Defense is honoured; face-down is never offered (RULES_SPEC.md 5.5) |
| revives from the OPPONENT's GY | 9 | you control it, the OWNER is unchanged, and it returns to the **owner's** Graveyard when it later leaves the field [S1 p.52] |
| a Trap in the GY is not a target | 5 | only monsters are candidates; a hand-built activation targeting a Trap is rejected |
| empty Graveyard | 4 | an effect that targets with no legal target cannot be activated (master prompt 17) |
| a full Monster Zone | 2 | not offered — unlike Kaibaman, nothing here frees a zone |
| **a target that left the GY** | 7 | a Chain Link 2 that banishes the target resolves first, and Monster Reborn then Summons nothing while still resolving to the GY (master prompt 44) |

### SilversCryTests — 47/47
`Tests/cards/SilversCryTests.gd`. Quick-Play, targeting, hard once-per-turn.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | Spell Speed 2, a real fast effect, targets 1, hard OPT on the NAME rather than the copy |
| revives a Dragon Normal Monster | 6 | the target arrives at full printed ATK; the Quick-Play does not stay on the field [S1 p.29] |
| the target filter | 7 | "Dragon Normal Monster" is both halves: a Dragon **Effect** Monster, a Normal **Wyrm** and a Normal Dinosaur are all rejected, on the real cards |
| only your own Graveyard | 4 | a legal-looking Dragon in the opponent's GY does not enable it |
| hard once-per-turn | 7 | a SECOND COPY is blocked in the same turn, the restriction is recorded against the card name, and it expires by that player's next turn |
| cannot be activated the turn it was Set | 5 | the Quick-Play exception to the "Spells may be activated the turn they are Set" rule [S1 p.31] |
| a Set copy on the opponent's turn | 7 | offered in a response window during the opponent's turn and resolves there |

### KaibamanTests — 47/47
`Tests/cards/KaibamanTests.gd`. The cost/effect split lives or dies here.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | a non-targeting Ignition Effect, Spell Speed 1, never a fast effect, field face-up only, Main Phases only, with a real `pay_cost` |
| Tributes itself and Summons | 10 | `CARD_TRIBUTED` and no `CARD_DESTROYED` — a Tribute is not a destruction [S1 p.53]; Blue-Eyes fills the zone Kaibaman vacated |
| **the cost survives negation** | 10 | the Tribute is already paid before any response window opens, and stays paid when Chain Link 2 negates the effect — the single most important cost assertion in the library |
| no Blue-Eyes in hand | 4 | not offered, a hand-built activation is rejected and pays nothing, and a copy in the GY does not count |
| only Blue-Eyes qualifies | 5 | other Level 8 LIGHT Dragons in hand do not satisfy a clause that names one card |
| from the hand or face-down | 3 | usable only from a face-up field position, and turning the same copy face-up enables it |
| outside the Main Phases | 4 | absent in the Battle Phase, present again in Main Phase 2 [S1 p.10] |

### DragonicTacticsTests — 39/39
`Tests/cards/DragonicTacticsTests.gd`. The first two-card cost and the first Deck Summon.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 8 | non-targeting Normal Spell activation with both a cost check and a cost payment |
| two Dragons for a Level 8 Dragon | 11 | both Tributes happen at activation, the Deck loses exactly one card, two `CARD_TRIBUTED` and zero `CARD_DESTROYED` |
| the Tribute candidates | 10 | the three Dragons you control are offered; the Dinosaur, the **Wyrm** and the opponent's Dragon are not |
| only one Dragon | 4 | an unpayable cost blocks the activation, a hand-built one is rejected, nothing is Tributed, and a second Dragon fixes it |
| no Level 8 Dragon in the Deck | 2 | one in the HAND does not count; putting one in the Deck enables it |
| a Level 7 Wyrm does not qualify | 4 | "Level 8 Dragon monster" is an exact Level **and** the race, with a positive control so the negative is not vacuous |

### OneForOneTests — 40/40
`Tests/cards/OneForOneTests.gd`.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 8 | non-targeting Normal Spell activation with a send-from-hand cost |
| sends and Summons from the Deck | 7 | the cost is paid before any response window; the Level 1 monster arrives and the Deck shrinks by one |
| **a send is not a discard** | 5 | the move reason is `SENT_AS_COST`, explicitly not `DISCARDED`, while still counting as "sent to the GY" and not as a destruction [S1 p.52-53] |
| "hand or Deck" is both zones | 6 | both candidates are offered and the hand copy can be the one Summoned |
| no monster in hand | 3 | a Spell in hand is not "a monster"; adding one makes the cost payable |
| no Level 1 monster anywhere | 2 | one in the GY, or one the opponent holds, does not count |
| a full Monster Zone | 2 | unlike Kaibaman, nothing here frees a zone |
| **paying away the last Level 1 monster** | 7 | the activation is legal because the candidate check precedes the cost; the card then legitimately resolves for nothing |

---

## Phase 5 batch 3 — per-card suites

### BirthrightTests — 59/59
`Tests/cards/BirthrightTests.gd`. The first Continuous Trap in the library.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 14 | three EffectDefs, Spell Speed 2, targets 1, Set-card activation, two MANDATORY triggers, the third keyed on `CARD_MOVED` |
| revives in Attack Position | 9 | the position is FIXED by the card, so **nobody is asked** — unlike `Monster Reborn`; the Trap stays on the field and remembers what it Summoned |
| the target filter | 6 | "1 **Normal** Monster" excludes an Effect Monster and a Spell; a hand-built activation on the Effect Monster is rejected |
| only your own Graveyard | 2 | with a positive control, so the negative is not vacuous |
| not the turn it was Set | 2 | [S1 p.30] |
| a full Monster Zone | 2 | nothing here frees a zone |
| **this card leaving destroys the monster** | 6 | mandatory, by card effect, and the link is cleared so nothing fires twice |
| **the monster LEAVING THE FIELD destroys this card** | 5 | **banished counts** — the clause says "leaves the field", and this is where `Call of the Haunted` disagrees |
| destruction also triggers it | 4 | destruction is one way of leaving the field; exactly one Special Summon in the whole duel, so nothing looped |
| a failed revival links nothing | 9 | a Chain Link 2 removes the target; the Trap resolves, stays on the field, and is linked to nothing |

### CallOfTheHauntedTests — 48/48
`Tests/cards/CallOfTheHauntedTests.gd`.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 12 | three EffectDefs; the third listens for `CARD_DESTROYED`, and the suite asserts directly that the two cards' third clauses listen to **different events** |
| revives in Attack Position | 5 | fixed position, Continuous Trap stays, link recorded |
| an Effect Monster is a legal target | 7 | and the same board offers `Birthright` only **one** of the two monsters — the two filters are genuinely different |
| only your own Graveyard | 2 | with a positive control |
| this card leaving destroys the monster | 4 | the clause shared verbatim with `Birthright` |
| **the monster being DESTROYED destroys this card** | 3 | |
| **the monster being BANISHED does NOT** | 8 | the single most important difference from `Birthright`; the link survives and the banished monster is not dragged back |
| destruction by battle | 7 | fires inside the Damage Step, and battle damage is inflicted normally [S1 p.41-42] |

### HieraticDragonOfTefnuitTests — 67/67
`Tests/cards/HieraticDragonOfTefnuitTests.gd`. The first card to use a summoning PROCEDURE.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | `SUMMON_PROCEDURE` + `CONTINUOUS` + `TRIGGER`; the procedure starts no Chain |
| the procedure Summons from the hand | 8 | properly Special Summoned, `summoned_by_procedure_id` recorded, Normal Summon untouched |
| **the procedure is not an activation** | 6 | never offered as `ACTIVATE_CARD` / `ACTIVATE_EFFECT` / a response; **no Chain Link created**, but the Summon IS declared so a negation can still answer it |
| "only your opponent controls a monster" | 6 | both halves; a face-down monster still counts as one they control; a forged action naming a non-existent effect is rejected |
| **cannot attack the turn Summoned this way** | 8 | the restriction applies, another monster attacks freely as a positive control, a hand-built attack is refused, and it lifts next turn |
| **a copy Summoned another way may attack** | 7 | revived by `Monster Reborn` it has no `summoned_by_procedure_id`, so "this way" does not apply — CARD_RULINGS.md §2.1 |
| the Tribute trigger | 9 | a Tribute is not a destruction; the Dragon arrives with ATK/DEF 0 while the **printed** and **original** ATK stay 3000 [S1 p.55] |
| the Tribute trigger filter | 7 | hand + Deck + GY all reachable; a Dragon Effect Monster, a Normal **Wyrm** and a card the opponent holds are all excluded |
| destroyed rather than Tributed | 5 | no `CARD_TRIBUTED`, no Special Summon [S1 p.53] |

### InariFireTests — 65/65
`Tests/cards/InariFireTests.gd`. Research/CARD_RULINGS.md R18.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 14 | a control-limit rules query, a procedure, and a once-per-turn mandatory Standby trigger traced to R18 |
| the procedure needs a face-up Spellcaster | 8 | the opponent's Spellcaster, another race, and a **face-down** Spellcaster all fail; flipping the same monster face-up enables it |
| you can only control 1 | 7 | a second copy's procedure is refused and a hand-built one rejected; a copy the OPPONENT controls does not restrict you |
| **the limit applies to every route** | 6 | Normal Summon and Normal Set are both refused, and `Monster Reborn` activates but Special Summons nothing |
| **the Standby revival** | 12 | the `last_move_*` record survives `on_leave_field()`; the **opponent's** Standby Phase does not count; your own does |
| destroyed by battle does not revive | 6 | "destroyed by **card effect**" is narrower [S1 p.52-53] |
| Tributed does not revive | 6 | |
| **only the NEXT Standby Phase** | 6 | blocked once by a full field, the window is gone — a later Standby Phase does not resurrect it |

### RanryuTests — 49/49
`Tests/cards/RanryuTests.gd`.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 12 | optional, targets, activates from the GY, Damage Step timing permitted, and **no invented once-per-turn** |
| the procedure and the control limit | 8 | a face-up Spellcaster is required; a second copy is refused by both the procedure and a Normal Summon |
| destroyed by battle | 8 | the controller is asked exactly once, and the 1500/200 monster arrives |
| destroyed by card effect | 4 | both branches of "by battle or card effect" are live |
| declining | 4 | asked, said no, nothing Summoned |
| **the target filter** | 8 | exact printed 1500/200; a 1900/500 monster excluded; **another copy of `Ranryu` excluded BY NAME**; the opponent's GY out of reach |
| Tributed does not fire | 5 | and the controller is never asked a question with no basis |

### NefariousArchfiendTests — 44/44
`Tests/cards/NefariousArchfiendTests.gd`. Research/CARD_RULINGS.md R17.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | optional, once per turn, End Phase only, targets, activates from the GY |
| the procedure and the control limit | 5 | |
| **the opponent's End Phase revival** | 8 | its controller acts on a turn that is **not theirs**: it destroys its own face-up monster and Special Summons itself |
| not during your own End Phase | 5 | the controller is never asked |
| declining | 4 | your own monster is NOT destroyed |
| no face-up monster to target | 5 | a face-down monster of yours and a face-up one of theirs are both illegal targets |
| **"and if you do"** | 6 | with the target protected from destruction, the effect activates, destroys nothing, and Summons nothing — the two halves are not independent |

### GagagashieldTests — 63/63
`Tests/cards/GagagashieldTests.gd`. Research/CARD_RULINGS.md R10.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 12 | a **NORMAL Trap**, Spell Speed 2, targets 1; the protection declares `uses_per_turn = 2` |
| a Normal Trap that stays on the field | 6 | its card KIND alone would have sent it to the GY — the equip is what keeps it [S1 p.30, p.53] |
| the target filter | 7 | Spellcaster, yours, face-up; the opponent's is rejected even hand-built |
| **twice per turn vs card effects** | 7 | two prevented, the third lands, and the shield follows its host to the GY |
| the count resets next turn | 7 | |
| **battle destruction is prevented too** | 7 | the monster survives while battle damage is still inflicted, and one use is still left that turn |
| the equipped monster leaving | 4 | `DESTROYED_BY_RULE` [S1 p.29, p.55] |
| the shield leaving | 5 | the card is not protected by its own clause; the monster is then destroyed normally |
| resolving without equipping | 8 | the target is banished by Chain Link 2; nothing equips and the Normal Trap goes to the GY |

### RiderOfTheStormWindsTests — 66/66
`Tests/cards/RiderOfTheStormWindsTests.gd`. Research/CARD_RULINGS.md R9. The pool's only
monster that equips **itself**.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 13 | an Ignition effect (Spell Speed 1, never a fast effect, Main Phases only) from **hand or field**, plus a continuous grant and a destruction replacement |
| equips itself from the hand | 8 | it lands in a **Spell & Trap Zone**, occupies no Monster Zone, was never Summoned, and cannot be re-equipped [S1 p.53] |
| equips itself from the field | 7 | it vacates its Monster Zone and nothing is destroyed on the way |
| the target filter | 8 | "Dragon **Normal** Monster you control": a Dragon Effect Monster, a non-Dragon vanilla, a face-down one and the opponent's are all excluded |
| no free Spell & Trap Zone | 5 | not offered, hand-built rejected, and it never leaves the hand [S1 p.29] |
| **it grants piercing** | 6 | the flag is on the EQUIPPED monster, not on the Equip Card; 1900 − 1000 pierces through [S1 p.42] |
| **destruction replacement by card effect** | 9 | exactly one card is destroyed and it is Rider, carrying the ORIGINAL reason; the piercing goes with it; the next destruction then lands |
| **destruction replacement in battle** | 6 | the equipped monster survives a losing battle and the battle damage is still inflicted |
| the host leaving the field | 4 | banished host ⇒ Rider destroyed by `DESTROYED_BY_RULE`, not by the replacement clause |

**C. Interaction** — `SpecialSummonInteractionTests` (46). Everything else, not yet.

### SpecialSummonInteractionTests — 46/46
`Tests/cards/SpecialSummonInteractionTests.gd`. Declares no card-under-test marker on
purpose: a card is only counted as TESTED because it has its own suite.

| Test | Asserts | What it proves |
|---|---:|---|
| Kaibaman then Silver's Cry | 10 | the deck's real line: Kaibaman fetches Blue-Eyes, Silver's Cry has no target while it lives, and recovers the very same copy once it is in the GY |
| two revivals in one Chain | 10 | Silver's Cry (SS2) legally chains to Monster Reborn (SS1); both resolve, and the `SPECIAL_SUMMON_SUCCEEDED` order proves reverse resolution [S1 p.46-47] |
| the last zone goes to Chain Link 2 | 9 | with one free zone both activations are legal, Chain Link 2 takes it, and Chain Link 1 re-checks the board at RESOLUTION and Summons nothing |
| revived monsters can be Tributed | 8 | a monster Special Summoned this turn is an ordinary monster and may pay Dragonic Tactics' cost |
| none spend the Normal Summon | 9 | two Special Summons later the Normal Summon is still available, and only a real Normal Summon spends it [S1 p.24] |

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
(**23 / 77 implemented, 23 / 77 tested**). No test result in this file is estimated or
projected.

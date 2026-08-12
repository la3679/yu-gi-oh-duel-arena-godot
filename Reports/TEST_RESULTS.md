# TEST_RESULTS

**Last run:** 2026-08-12
**Engine:** Godot 4.7.1.stable.official.a13da4feb (headless)

Command:

```bash
"C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --headless --path "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame" --script res://Scripts/tests/RunTests.gd
```

---

## Summary — actual measured results

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules tests | 5 | 176 | **176** | 0 |
| Per-card tests | 0 | 0 | 0 | 0 |
| Interaction tests | 0 | 0 | 0 | 0 |
| Scripted duel tests | 0 | 0 | 0 | 0 |
| **TOTAL** | **5** | **176** | **176** | **0** |

`RESULT: PASS`, exit code 0.

Separately, `Scripts/tests/SmokeCheck.gd` passes (data load + RNG determinism); it is a
load check, not part of the rules suite count above.

**This is still an early-stage suite.** The counts above are the real current numbers.
Battle Phase, Damage Step, continuous effects and all 77 card behaviours are not yet
covered — see "Not yet covered" below.

---

## Suites

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

---

## Defects found and fixed by these tests

1. **`RunTests.gd` reported PASS for a suite that ran zero assertions.** When `TimingTests`
   failed to compile, the runner printed `TimingTests: 0/0 passed` and still exited 0.
   Fixed: a suite with zero assertions is now an explicit failure. This is the most
   important fix in this milestone — without it a green run proved nothing.
2. **Three `:=` type-inference compile failures** (`TriggerCollector.gd`,
   `DuelEngine.gd`, `SummonRules.gd`) silently broke whole classes, exactly as in the
   previous milestone. GDScript cannot infer through a `Variant` (an untyped `Array`
   element, or a function declared `-> Variant`). Annotate explicitly.
3. **`project.godot` pointed `run/main_scene` at `res://Scenes/ui/Boot.tscn`, which does
   not exist yet**, so every headless run logged a resource load error. Unset until the
   Phase 7 UI exists.

## Known issues in the harness (not rules defects)

* The run reports `~7190 ObjectDB instances were leaked at exit`. These are RefCounted
  reference cycles between `GameState`, `DuelLog` (connected signal) and the closures the
  tests capture. It does not affect any rules outcome and does not fail the suite, but it
  should be cleaned up before the UI keeps a duel alive for a long session.
* The run prints one `SCRIPT ERROR` from `push_error`. That is **intentional** — it is the
  loud failure the "unimplemented effect fails loudly" test asserts must occur.

---

## Not yet covered (required by master prompt §64 — tracked, not claimed)

**A. Core rules** — still missing: Battle Phase, attack declaration and responses, attack
replay, the Damage Step sub-steps and its activation restriction, damage calculation,
battle damage, battle destruction, piercing, continuous effects as state-derived
modifiers, counters placed/removed by effects, GY-activated effects, 0-LP victory,
hidden-information filtering assertions.

**B. Per-card** — 0 of 77 cards have tests.

**C. Interaction** — none yet.

**D. Scripted full duels** — none yet.

Coverage is reported honestly here and in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`
(0 / 77 implemented, 0 / 77 tested). No test result in this file is estimated or projected.

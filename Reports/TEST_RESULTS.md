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
| Core rules tests | 1 | 27 | **27** | 0 |
| Per-card tests | 0 | 0 | 0 | 0 |
| Interaction tests | 0 | 0 | 0 | 0 |
| Scripted duel tests | 0 | 0 | 0 | 0 |
| **TOTAL** | **1** | **27** | **27** | **0** |

`RESULT: PASS`, exit code 0.

Separately, `Scripts/tests/SmokeCheck.gd` passes (data load + RNG determinism); it is a
load check, not part of the rules suite count above.

**This is an early-stage suite.** The counts above are the real current numbers, not a
target. The great majority of required coverage (master prompt §64 A–D) does not exist yet —
see "Not yet covered" below.

---

## Suite: ChainTests (27/27)

Source: `Tests/rules/ChainTests.gd`. Rules under test: `Research/RULES_SPEC.md §4`,
traceable to Official Rulebook v10 pp.44–47, 51 and the official Fast Effect Timing chart.

| Test | Asserts | Rule verified |
|---|---:|---|
| spell speed response legality | 8 | Spell Speed 1 may be Chain Link 1; SS1 cannot respond to an existing link; SS2/SS3 may respond to SS1; SS2/SS3 may respond to SS2 [S1 p.44] |
| chain link numbering | 4 | activations become Chain Link 1, 2, 3 in order |
| reverse chain resolution | 3 | Chain resolves highest link first (CL3→CL2→CL1); chain cleared afterwards; resolving flag cleared [S1 p.46-47] |
| negate activation vs negate effect | 8 | the two negation kinds are distinct and independent; a negated link does not resolve; the non-negated link still does (master prompt §18) |
| counter trap response restriction | 3 | only Spell Speed 3 may respond to Spell Speed 3 [S1 p.45] |
| chain link number readable at resolution | 1 | an effect can read its own Chain Link number at resolution — required by `Chain Detonation` / `Chain Healing` (CARD_RULINGS.md R4) |
| unimplemented effect fails loudly | 1 | a missing `resolve()` emits an error event instead of being silently skipped (master prompt §67) |

Note: the run prints one `SCRIPT ERROR` from `push_error`. That is **intentional** — it is the
loud failure that the "unimplemented effect fails loudly" test asserts must occur.

---

## Defects found and fixed by these tests

1. **`GameState.gd` failed to compile** — `var p0_out := players[0].life_points <= 0`
   could not be type-inferred because `players` is an untyped `Array`, so the whole class
   failed to load and every `GameState.new()` returned null. The suite reported 9 failures
   rather than passing on a broken engine. Fixed by annotating the locals as `bool`.
2. `SmokeCheck.gd` had two identical inference failures on JSON loads (`var x := _load_json(...)`),
   fixed the same way.

---

## Not yet covered (required by master prompt §64 — tracked, not claimed)

**A. Core rules** — still missing: initial setup, opening hands, first-turn draw rule,
first-turn Battle Phase rule, turn/phase progression, one Normal Summon per turn, Tribute
requirements, Set rules, manual position-change rules, Trap Set-turn restriction, Quick-Play
Set-turn restriction, Spell activation timing, target legality, costs, Fast Effect Timing
windows, trigger effects, optional triggers, simultaneous trigger ordering, continuous effects,
GY triggers, battle, attack-declaration responses, Damage Step restrictions, battle damage,
battle destruction, deck-out, 0-LP victory, hidden-information filtering.

**B. Per-card** — 0 of 77 cards have tests. Required: every effect clause of every card,
including negative cases, illegal targets, costs, and once-per-turn restrictions.

**C. Interaction** — none yet.

**D. Scripted full duels** — none yet.

Coverage is reported honestly here and in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`
(0 / 77 implemented, 0 / 77 tested). No test result in this file is estimated or projected.

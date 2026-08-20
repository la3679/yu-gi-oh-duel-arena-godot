# Testing

The test suite is as much the deliverable as the engine is. This document explains how it is
organised, how to run it, how to add to it correctly, and the harness pitfalls that have cost
real time.

Measured at the current checkpoint (Phase 5, batch 9 partial):

| | |
|---|---|
| **Assertions** | **5,509 passed / 0 failed** |
| **Suites** | **63** — 21 core-rules, 41 per-card, 1 interaction |
| **SmokeCheck** | **PASS** |
| **Engine** | Godot `4.7.1.stable.official.a13da4feb`, headless |
| **ObjectDB at exit** | 164,444 leaked instances (known, tracked — see [below](#known-harness-pitfalls)) |

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules | 21 | 1,797 | 1,797 | 0 |
| Per-card | 41 | 3,666 | 3,666 | 0 |
| Interaction | 1 | 46 | 46 | 0 |
| **Total** | **63** | **5,509** | **5,509** | **0** |

The per-suite breakdown, and **every defect the tests have caught**, milestone by milestone,
is in [`../Reports/TEST_RESULTS.md`](../Reports/TEST_RESULTS.md). That file is the detailed
record; this one is the guide.

---

## Contents

- [Running the tests](#running-the-tests)
- [Test organisation](#test-organisation)
- [Generic rules tests and mechanic gates](#generic-rules-tests-and-mechanic-gates)
- [Per-card suites](#per-card-suites)
- [Interaction suites](#interaction-suites)
- [The regression suite](#the-regression-suite)
- [SmokeCheck](#smokecheck)
- [How assertions are measured](#how-assertions-are-measured)
- [False-positive-path detection](#false-positive-path-detection)
- [Determinism](#determinism)
- [How to add a test correctly](#how-to-add-a-test-correctly)
- [Known harness pitfalls](#known-harness-pitfalls)

---

## Running the tests

Both runners take the name of an entry script in `Scripts/tests/` and default to `RunTests`.
Both locate Godot via `-GodotPath` / `$GODOT_BIN` / `$GODOT` / `PATH`, and **both exit 0 on
pass and 1 on failure**.

### Windows (PowerShell) — the validated environment

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests
```

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 SmokeCheck
```

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 -Import
```

### Linux / macOS / CI

```bash
./Tools/run_tests.sh RunTests
```

```bash
./Tools/run_tests.sh SmokeCheck
```

```bash
./Tools/run_tests.sh --import
```

### Reporting tools

Per-test assertion counts for the Phase 5 suites, which is where the numbers quoted in
`TEST_RESULTS.md` come from:

```bash
godot --headless --path . --script res://Scripts/tests/DumpAssertionCounts.gd
```

The card implementation matrix, which computes the card counts from the code:

```bash
python Tools/build_matrix.py
```

### What a passing run looks like

```
=======================================
TOTAL: 5509 passed, 0 failed (5509 assertions across 63 suite(s))
=======================================
RESULT: PASS
RUNNER: PASS
```

### Why the wrapper scripts exist

Use them rather than the raw Godot command. Both guards were added after the raw command cost
time:

1. **Godot writes heavily to stderr** — every `push_error` prints a full GDScript backtrace.
   Piping stdout and stderr through a shell can block on a full pipe, so the runners redirect
   to files and print them afterwards.
2. **A suite that fails to *compile* hangs forever.** `RunTests._initialize()` throws before it
   can call `quit()`, leaving the headless `SceneTree` running. The runners do a `--check-only`
   parse pass first, so a compile error is an immediate, readable failure instead of a hang.
   The POSIX runner additionally bounds the run with `timeout`, and treats a timeout as a
   failure even if a PASS line was printed before the hang.

The Godot binary does not return a usable exit code for a `--script` run, so success is decided
by the `RESULT: PASS` / `SMOKE CHECK: PASS` line the suite prints, and the runner converts that
into its own exit code.

---

## Test organisation

```
Tests/
├── rules/          21 suites — generic rules tests and mechanic gates
├── cards/          41 per-card suites + 1 interaction suite
├── support/
│   └── TestFixtures.gd   duel builders and synthetic cards
├── interactions/   reserved for further cross-card interaction suites
└── integration/    reserved for Phase 6 scripted duels

Scripts/tests/
├── RunTests.gd            the pass/fail authority; suites registered explicitly
├── SmokeCheck.gd          card DB loads, decks build, a duel constructs
├── TestCase.gd            the assertion harness
└── DumpAssertionCounts.gd per-test assertion reporting (not a test)
```

**There is no third-party test plugin.** The engine is headless-testable by design, so a small
in-repo harness (`TestCase.gd`) keeps the dependency surface at zero and runs under
`godot --headless --script`.

`TestCase` offers `start(name)`, `check`, `eq`, `ne`, `is_true`, `is_false`, `is_null`,
`not_null`, and `total()`. A suite is a `class_name` with `static func run() -> TestCase`.

---

## Generic rules tests and mechanic gates

`Tests/rules/` proves the rules engine obeys the rulebook **independently of any real card**,
using synthetic cards from `TestFixtures`. A generic rules test that depended on a real card
would stop being generic.

### What a mechanic gate is

A **mechanic gate** is a generic suite for a whole mechanic, written and passing *before* the
first real card that needs it exists.

### Why gates come before the cards that depend on them

Three concrete reasons, all of which have paid off in this repository:

1. **The card has nothing left to invent.** It composes a mechanism already proven correct in
   isolation, so the card file stays a declaration of its clauses rather than a place where a
   subsystem accidentally gets designed.
2. **A later bug is unambiguous.** It is either "the mechanic" or "this card", never an
   argument about both at once.
3. **It forces the distinctions out into the open early.** `AttackRestrictionTests` (229
   assertions) established that attack **prevention**, attack **negation** and a card-class
   **activation lock** are three different things — *before* any card in that group existed.
   Had the first card been written first, the natural shortcut would have been a single
   `attack_blocked` boolean, and unpicking that later would have touched every card that used
   it.

A gate is also where the engine vocabulary a mechanic needs gets added and **consumed**, so
nothing is left declared-but-unused. Unit A of batch 9 deliberately consumed two pieces of
vocabulary that had had zero consumers since earlier phases.

### The gates that exist

| Suite | Mechanic |
|---|---|
| `ChainTests` | Chain construction, reverse-order resolution, loud failure on a missing `resolve()` |
| `TimingTests` | Fast Effect Timing, boxes A–E |
| `TurnFlowTests` | Phase progression |
| `SummonTests` | Normal / Tribute / Flip Summon and Set |
| `SpecialSummonTests` | Special Summon paths |
| `SpellTrapTests` | Spell/Trap activation legality |
| `BattleTests` | Attack declaration, replay, damage |
| `DamageStepTests` | The five sub-steps and the Damage Step activation restriction |
| `AttackRestrictionTests` | Attack prevention vs attack negation vs activation lock |
| `BattlePhaseRestrictionTests` | "Skip your next Battle Phase" as turn state |
| `EquipTests` | The Equip subsystem |
| `ControlTests` | Owner vs controller, control leases |
| `MovementTests` | Movement, Deck placement, excavation |
| `BanishTests` | Permanent and temporary banishment, return leases |
| `TrapMonsterTests` | A Trap that becomes a monster |
| `LifePointCostTests` | Paying LP as an activation cost |
| `CounterTests` | Counters |
| `ContinuousTests` | Continuous effects, restriction flags, loud failure on an unknown flag |
| `HiddenInfoTests` | Per-viewer visibility |
| `ReplayTests` | Determinism and replay |
| `RulesQuestionTests` | Assorted rules questions settled against the sources |

---

## Per-card suites

One suite per implemented card, in `Tests/cards/`, named `<CardName>Tests.gd`.

Required shape:

```gdscript
class_name ShiningAngelTests
extends RefCounted

const CARD_UNDER_TEST := "Shining Angel"

static func run() -> TestCase:
    var t := TestCase.new("ShiningAngelTests")
    _test_registry_loads_cleanly(t)
    _test_clause_shape(t)
    # ... one function per behaviour, positive and negative
    return t
```

**Every clause is exercised positively *and* negatively, and the negatives are the point.**
`ShiningAngelTests` is the template: its clause is a battle-destruction trigger, so the suite
proves it fires on battle destruction *and* proves it does **not** fire when the same card
reaches the Graveyard by an effect, or by being Tributed, and that it is not even offered
without a legal monster or with a full Monster Zone.

The `CARD_UNDER_TEST` marker matters beyond documentation: `Tools/build_matrix.py` reads it,
so a card can only be reported as TESTED because this file exists and passes.

A suite covering a whole mechanic **group** declares `const CARDS_UNDER_TEST := ["…", "…"]`
instead of the singular marker.

---

## Interaction suites

Interaction suites prove cards behave correctly *against each other* — the negations,
destructions, movements and control changes that only appear when two real cards meet.

**An interaction suite declares neither marker.** That is deliberate: a card is only ever
counted as TESTED because it has its own suite, so an interaction suite can never inflate the
matrix.

There is currently **one** (`SpecialSummonInteractionTests`, 46 assertions). This is the
thinnest area of coverage in the project and the most valuable place for a new contributor to
work.

---

## The regression suite

`Scripts/tests/RunTests.gd` is the pass/fail authority. It runs every suite, every time, and
is green only at **0 failures**.

**Suites are registered explicitly**, by hand, in `_initialize()`. A discovered-by-scan list
would silently skip a suite that failed to load; an explicit list makes that a hard error.
(Note the contrast with `CardRegistry`, which *does* scan — there, a hand-written list could
drift from the matrix. The two choices point in opposite directions for the same reason: pick
whichever one turns a mistake into a loud failure.)

The full suite currently takes a couple of minutes headless.

---

## SmokeCheck

`Scripts/tests/SmokeCheck.gd` is the fast health check: it loads the card database, builds both
decks, and constructs a duel.

```
  card definitions: 37 monsters / 18 spells / 22 traps
  deck1.json -> 'Blue-Eyes Dragon Guard' 40 cards
  deck2.json -> 'Fairy-Tail Tribute Guard' 40 cards

SMOKE CHECK: PASS
```

It catches data-level breakage — a malformed `cards.json`, a deck referencing a missing card, a
registry file that fails to load — in seconds rather than after a full regression run. Run it
first when something looks broken.

---

## How assertions are measured

Assertion counts are **measured by the harness, never counted by hand from the source.**

`TestCase` records `test_counts` per test name in declaration order, and `total()` is the sum.
This matters because call sites are not assertions: a suite that loops over the nine vanilla
Normal Monsters runs many more assertions than it has `t.` call sites, and hand-counting would
understate it badly.

`DumpAssertionCounts.gd` prints the per-test numbers that `TEST_RESULTS.md` quotes. It is a
**reporting tool, not a test** — `RunTests.gd` remains the pass/fail authority.

The project convention when reporting a checkpoint is to state the total, and to confirm that
**every pre-existing suite reports exactly its previous count**. That is what proves new work
added assertions rather than quietly changing old ones. For example, at the batch 9 unit A
checkpoint: 5,509 − 5,280 = 229, precisely the size of the new suite, and no other suite moved.

---

## False-positive-path detection

The harness assumes that a test which *looks* like it passes might not be testing anything.
These guards all exist because that risk is real:

| Guard | What it prevents |
|---|---|
| **A zero-assertion suite is a failure** | A suite whose script failed to compile reports "0/0 passed" and the run claims PASS while testing nothing. **This happened once during development.** |
| **Explicit suite registration** | A suite that fails to load is a hard error, not a silently skipped file. |
| **`--check-only` parse pass** | A compile error becomes a readable failure instead of an infinite hang. |
| **`ChainManager` fails loudly on a missing `resolve()`** | A placeholder effect that silently does nothing. Asserted by `ChainTests`. |
| **`ContinuousEffects` rejects an unknown restriction flag** | A typo'd flag being silently written and never applied. Asserted by `ContinuousTests`. |
| **`ScriptedController.errors` asserted empty** | A queued answer going to a different prompt than the test meant — the controller's default policy would silently answer instead. |
| **Counts computed by `build_matrix.py`** | A card being claimed as implemented because it loads. |
| **Interaction suites declare no card marker** | The tested count being inflated by suites that do not fully cover a card. |

Two `SCRIPT ERROR` lines are therefore **expected on every run**. They come from the two loud
failure tests above. A run *without* them means those guards have stopped working.

---

## Determinism

Every test is deterministic:

* the RNG is explicitly seeded, and never reseeded from the system clock;
* `ScriptedController` answers from an explicit queue, so a test states exactly what a player
  chooses;
* where a scenario could plausibly be order-dependent, the suite runs it **twice** and asserts
  identical results, so a non-deterministic regression fails immediately rather than becoming a
  flaky test.

`ReplayTests` proves a recorded duel replays to an identical state from its seed and decision
list.

---

## How to add a test correctly

1. **Build duels through `Tests/support/TestFixtures.gd`. Never hand-roll a duel.** It has
   `new_duel()`, `battle_duel()` (turn 2, player 0 attacking, already past the turn-1 Battle
   Phase prohibition), `pass_until_open()`, `advance_to_phase()`, `end_turn()`, `attack()`,
   `events_of()`, `count_events()`, `first_event_index()`, `count_events_for()`, synthetic card
   builders (`monster()`, `trap_monster()`, `flip_effect_monster()`), and interference helpers
   (`interferer()`, `summon_negator()`, `effect_negator()`, `build_chain_to_depth()`,
   `activate_card()`, `activate_effect()`, `give_to_hand()`).
2. **Put it in the right place**: `Tests/rules/` for anything generic, `Tests/cards/` for a
   specific card.
3. **Declare the right marker** — `CARD_UNDER_TEST`, `CARDS_UNDER_TEST`, or neither for an
   interaction suite.
4. **Give it a `class_name` and `static func run() -> TestCase`.**
5. **Register it in `Scripts/tests/RunTests.gd`.**
6. **Cover the negatives.** For every "it does X when Y", write "it does **not** do X when
   not-Y", and "it is not even offered when it cannot legally happen".
7. **Run the import pass as its own command**, then the suite, then the full regression.
8. **Record the measured count** in `Reports/TEST_RESULTS.md`, along with any defect the test
   caught.

**Never weaken, retarget or delete an existing assertion to make new behaviour pass.** If your
change makes an existing test fail, either the change is wrong or the test encodes a rules
error — and which one it is gets decided from `RULES_SPEC.md` and the sources, in the pull
request description.

---

## Known harness pitfalls

Collected from real time lost. Reading these will save you a cycle.

### Godot / GDScript

* **Run `--import` as its own command after adding any `class_name`.** Chaining it into the
  test run is not enough: the parse check still reads the stale
  `.godot/global_script_class_cache.cfg` and fails with `Identifier "<YourNewClass>" not
  declared in the current scope`, which looks like a syntax error in a file that is fine.
  Confirm with a search for your class name inside that cache file.
* **Never use `:=` where the right-hand side is a `Variant`** — an untyped `Array` element such
  as `some_def.effects[0]`, or a function declared `-> Variant`. It is a hard compile error, and
  a failed compile takes the whole dependent class down with it. It bites **transitively**:
  `var a = find_action(...)` then `var b := a.with_choices({...})` fails too, even though
  `with_choices()` is typed.
* **A single-line lambda ends at the newline.** A wrapped lambda body inside a call argument
  needs an explicit `\` continuation, or you get `Expected closing ")" after call arguments`
  **with no line number**.

### Engine behaviour that surprises tests

* **`get_legal_actions(pid)` returns nothing unless the engine is open *and* `pid` is the turn
  player.** An interferer meant to fire in an open game state must therefore belong to the
  **turn player**; a Chain Link 2 goes through `get_legal_responses()` instead. Neither mistake
  fails loudly — the helper just returns false.
* **The engine does not pause when nobody holds a legal response.** It auto-passes and resolves
  the whole attack, chain or Damage Step inside one `submit_action()`. To observe an
  intermediate state, read the event log or give a player a genuine fast effect so a window
  actually opens.
* **A phase change is a declaration first.** After `submit_action(ENTER_BATTLE_PHASE)` the phase
  has **not** changed yet if the opponent holds a response.
* **Continuous effects are recomputed at engine timing points**, not when a test arranges the
  board. A baseline assertion taken straight after `TestFixtures.give_*` reads the un-recomputed
  value. Run an explicit `ContinuousEffects.new(state).recompute()` first, or take an engine
  action.
* **`GameState.destroy()` correctly refuses a card that is not on the field**, so
  `interferer(..., "destroy")` cannot move a card out of the hand. Use the `"send_to_gy"` mode.
* **`TestFixtures.activate_card()` finds an `ACTIVATE_CARD` action only.** An effect activated
  from a card already on the field is an `ACTIVATE_EFFECT` action — use
  `TestFixtures.activate_effect()`.

### Prompts and choices

* **`EffectPrimitives.choose_n()` / `choose_one()` do not ask when the number of candidates
  equals the number required** — there is nothing to decide. A test that asserts on the offered
  option list must set up **more** candidates than the clause consumes, or the prompt never
  happens and the assertion fails confusingly.
* **`ScriptedController`'s default answer is "the first `min_count` options"**, which is rarely
  the card a test means. Any test that cares which card pays a cost must `queue_for(...)` it
  explicitly, and should then assert `controller.errors == []` — that is what proves the queued
  answer reached the prompt the test thought it did.

### ObjectDB growth

Every full run ends with a warning like:

```
WARNING: 164444 ObjectDB instances were leaked at exit
```

This is **known, tracked, and not a rules defect.** They are RefCounted reference cycles
between `GameState`, the `DuelLog` signal and the closures tests capture, and the count grows
with the number of duels the suite builds.

* It causes **no test failure, hang, memory pressure or unreliable result**, and no rules
  outcome changes — which is why it has not been allowed to derail card work.
* It **must be characterised or fixed before Phase 7**, when a UI keeps a single duel alive for
  a long session.
* `Reports/TEST_RESULTS.md` records the figure and the per-assertion ratio at **every**
  checkpoint, deliberately reporting it as measured rather than explaining it away. Where the
  cause is not known, that file says the reading is inference rather than measurement. Please
  keep that convention: it is the only reason the trend is still readable.

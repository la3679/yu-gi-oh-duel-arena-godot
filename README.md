# Duel Arena

[![tests](https://github.com/la3679/yu-gi-oh-duel-arena-godot/actions/workflows/tests.yml/badge.svg)](https://github.com/la3679/yu-gi-oh-duel-arena-godot/actions/workflows/tests.yml)
[![Godot](https://img.shields.io/badge/Godot-4.7.1-478cbf)](https://godotengine.org/)
[![cards](https://img.shields.io/badge/cards-49%2F77-orange)](Reports/CARD_IMPLEMENTATION_MATRIX.csv)
[![assertions](https://img.shields.io/badge/assertions-5509%20passing-brightgreen)](docs/TESTING.md)

A deterministic, rules-aware Yu-Gi-Oh! duel engine written in GDScript for Godot 4, plus the
local two-player duel arena that will eventually sit on top of it.

> **Status: active development. Engine-first, and not yet playable by a human.**
> Phase 5 of 11 — the card effect library. **49 of 77** cards in the target pool are
> implemented and tested; **28 remain**. There is no player-facing UI yet, no CPU opponent,
> and no 3D presentation. What exists is a headless rules engine with **5,509 assertions
> passing across 63 suites**, and the research trail behind every rule it enforces.

---

## Table of contents

- [What this is](#what-this-is)
- [Why this project exists](#why-this-project-exists)
- [Current status](#current-status)
- [Technology stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Local setup](#local-setup)
- [Running the project](#running-the-project)
- [Running the tests](#running-the-tests)
- [Architecture](#architecture)
- [Repository structure](#repository-structure)
- [How cards are implemented](#how-cards-are-implemented)
- [Testing strategy](#testing-strategy)
- [Where the rules come from](#where-the-rules-come-from)
- [Determinism and replay](#determinism-and-replay)
- [Hidden information](#hidden-information)
- [Card coverage](#card-coverage)
- [Development workflow](#development-workflow)
- [Roadmap](#roadmap)
- [Known limitations](#known-limitations)
- [Design principles](#design-principles)
- [Contributing](#contributing)
- [Card images and assets](#card-images-and-assets)
- [Licence](#licence)
- [Disclaimer](#disclaimer)

---

## What this is

Duel Arena is an attempt to build a Yu-Gi-Oh! duel engine that actually **understands the
rules**, rather than a card table that lets two people move images around and settle
arguments themselves.

The engine is authoritative. It owns the game state, decides what is legal, builds and
resolves Chains, runs the Damage Step sub-step by sub-step, and emits a stream of semantic
events describing what happened. A user interface — when one exists — will render those
events and submit actions the engine has already declared legal. **The UI is never the
source of truth and never decides legality.**

The card pool is deliberately bounded: two real 40-card decks, **80 deck slots, 77 unique
card names**. That is small enough to finish honestly and broad enough to force the engine
through Equip Spells, Continuous Traps, Counter Traps, Flip Effects, control changes,
temporary banishment, Trap Monsters, counters, and chain-position-dependent effects.

The order of work is deliberate:

```
rules -> card effects -> tests -> interaction coverage -> playable UI -> presentation
```

Correctness first. Everything visual is Phase 7 and later, and is not started.

---

## Why this project exists

The interesting part of Yu-Gi-Oh! is not drawing the cards — it is that the rules are a
genuinely intricate timing system, and most hobby implementations quietly approximate it.
This project's goal is to *not* approximate it: to convert official rules text into
deterministic code, one documented decision at a time.

Concretely, the engine models these as distinct concepts rather than collapsing them:

**Implemented and under test**

| Area | What is modelled |
|---|---|
| Turn structure | Draw → Standby → Main 1 → Battle → Main 2 → End; first turn draws nothing and has no Battle Phase |
| Summoning | Normal Summon, Normal Set, Tribute Summon/Set, Flip Summon, Special Summon, summoning procedures |
| Summon declaration | A Summon is a *declaration* that can be responded to and **negated** — including a Flip Summon |
| Chains | Chain Links, reverse-order resolution, Chain Link position readable by a card effect |
| Spell Speed | SS1 / SS2 / SS3, and the "≥ 2 and ≥ the previous link" response rule |
| Fast Effect Timing | The official boxes A–E state machine, transcribed rather than reinvented |
| Effect categories | Trigger, Quick, Ignition, Continuous, Flip |
| Costs vs effects | A cost is paid at activation, is not an effect, and cannot be negated as one |
| Targeting | Targets fixed at activation, **re-validated at resolution** (field presence *and* control) |
| Negation | Effect negation, activation negation, Summon negation and continuous negation — all separate |
| Damage Step | Five sub-steps, and the restriction on what may activate inside it |
| Battle | Attack declaration, attack replay, damage calculation, direct attacks, the 0-ATK rule |
| Attack restriction | Attack **prevention**, attack **negation** and a card-class **activation lock** are three different things |
| Control changes | Owner vs controller, control leases with explicit durations |
| Equip | Equip relationships, and the destruction rules that follow the host |
| Banishment | Permanent and temporary banishment, with return leases |
| Trap Monsters | A Trap that becomes a monster without ever mutating the shared card definition |
| Counters | Counter placement and consumption |
| Once-per-turn | Per-instance, per-named-effect and per-named-activation tracking, kept separate |
| Continuous effects | Recomputed from the board, so they switch off by themselves |
| Hidden information | Per-viewer state views, reveal tracking, shuffling clearing known information |
| Determinism | Seeded RNG, an action log, and replay |

**Not implemented yet** — Pendulum, Link, Xyz, Synchro and Ritual summoning; the Extra Deck
is modelled in the data structures but the current pool contains no Extra Deck cards.
A simultaneous-LP-zero draw is a known, documented gap (see
[Known limitations](#known-limitations)).

---

## Current status

Every number below is **measured**, not asserted by hand. The card counts come from
`python Tools/build_matrix.py`, which reads the registry and the test suites; the assertion
counts come from the last full run of the suite.

| | |
|---|---|
| **Phase** | 5 of 11 — the card effect library |
| **Batch** | 9, **partial**: the generic attack-restriction / attack-negation gate is complete; no batch-9 card is started |
| **Cards implemented** | **49 / 77** |
| **Cards tested** | **49 / 77** |
| **Cards remaining** | **28** |
| **Official text verified** | **77 / 77** |
| **Assertions** | **5,509 passed / 0 failed** |
| **Suites** | **63** — 21 core-rules, 41 per-card, 1 interaction |
| **SmokeCheck** | **PASS** |
| **Engine** | Godot `4.7.1.stable.official.a13da4feb`, headless |
| **CI** | Green — the full suite runs on Ubuntu on every push and reproduces these numbers exactly |
| **Gate A** — research complete | **MET** |
| **Gate B** — core rules engine complete | **MET** |
| **Gate C** — card library complete | not met |
| **Gate D** — playable prototype | not met |

Assertion breakdown:

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules | 21 | 1,797 | 1,797 | 0 |
| Per-card | 41 | 3,666 | 3,666 | 0 |
| Interaction | 1 | 46 | 46 | 0 |
| **Total** | **63** | **5,509** | **5,509** | **0** |

**Complete engine subsystems:** turn flow, summoning (all kinds in the pool, plus Summon
negation), the Chain and Fast Effect Timing state machine, activation legality, the Damage
Step, battle and attack replay, continuous effects and continuous negation, the Equip
subsystem, counters, control changes, movement and excavation, banishment and return leases,
LP payment as a cost, Trap Monsters, Battle-Phase-skip as turn state, attack restriction and
attack negation, hidden information, and deterministic replay.

**Major remaining work:** the last 28 cards and their interaction coverage, then Phase 6
scripted-duel acceptance, then the Phase 7 playable UI. See [Roadmap](#roadmap).

The authoritative internal state files, kept in the repository and updated at every
checkpoint, are [`PROJECT_STATE.md`](PROJECT_STATE.md),
[`Reports/TEST_RESULTS.md`](Reports/TEST_RESULTS.md) and
[`Reports/CARD_IMPLEMENTATION_MATRIX.csv`](Reports/CARD_IMPLEMENTATION_MATRIX.csv). A
public-facing summary lives in [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md).

---

## Technology stack

| Technology | Version | Role |
|---|---|---|
| **Godot Engine** | 4.7.1 stable (tested) | Runtime and, later, the 3D arena. Today it is used **headless** as the GDScript host for the engine and the test suite. |
| **GDScript** | Godot 4 dialect | The entire engine, card library and test suite. |
| **Python** | 3.11 (developed against) | Build-time helper tooling only, in `Tools/` — card database generation, the implementation matrix, card-text diffing. **Not a runtime dependency.** |
| **PowerShell / Bash** | — | The two headless test runners. |
| **Git / GitHub** | — | History and CI. |

**Why Godot.** The project needs one process that can host a pure, testable, dependency-free
rules engine *and* later render a 3D arena with card movement and effects, without rewriting
the engine or introducing an IPC boundary. Godot 4 runs GDScript headless from the command
line (`--headless --script`), which is what makes a 5,500-assertion suite practical in CI,
and it ships the 3D renderer the later phases need. The engine is written in plain
`RefCounted` classes with no `Node`, no scene tree and no signals into a UI, so it can be
exercised entirely without a display.

**Why the engine is separate from presentation.** The engine directories
(`Scripts/engine/`, `Scripts/rules/`, `Scripts/cards/`) contain nothing that draws, animates
or waits for a frame. Presentation reads a semantic event stream and submits actions. That
boundary is what allows the whole rules system to be tested headlessly and deterministically,
and it is the same boundary a future CPU player will sit behind.

**A note on Graphify.** [Graphify](https://github.com/Graphify-Labs/graphify) was evaluated
as a code-navigation aid during Phase 0 and **indexes only the Python files in `Tools/`** —
it supports 36 tree-sitter grammars and **GDScript is not among them**, so it cannot see the
engine at all. It is **not a dependency of anything**: not of the runtime, not of the build,
not of the tests. `.graphifyignore` is a leftover configuration file, retained only so the
evaluation stays on the record.

---

## Prerequisites

| | Required | Notes |
|---|---|---|
| **Git** | yes | To clone. |
| **Godot 4.7.x** | yes | The **standard** build, not .NET/Mono — the project contains no C#. Tested against `4.7.1.stable.official.a13da4feb`. Other 4.x versions will probably work but are untested. |
| **Python 3.11+** | optional | Only to re-run the helpers in `Tools/`. You do **not** need Python to build, run or test the project. |
| **PowerShell 5.1+** | Windows only | Ships with Windows. |

**Platforms.** The engine is plain GDScript with no platform-specific code. Development
happens on **Windows 11**, and CI runs the full suite on **Ubuntu** on every push. Both
produce **identical** results — 5,509 assertions, 0 failures, and even the same ObjectDB
count at exit — which is a useful independent check on the engine's determinism. **macOS is
untested**: `Tools/run_tests.sh` should work there, but nobody has run it.

There are **no package dependencies to install**, no lockfile, no `.env` file and no
environment variables required. The only optional environment variables are conveniences:

| Variable | Used by | Purpose |
|---|---|---|
| `GODOT_BIN` (or `GODOT`) | both test runners | Path to the Godot executable, if it is not on `PATH`. |
| `DUEL_ARENA_PLAYERFILES` | `Tools/build_card_db.py`, `Tools/enumerate_cards.py` | Path to the private physical-collection inputs, which are **not** in this repository. Defaults to the repository's parent directory. |

---

## Local setup

```bash
git clone https://github.com/la3679/yu-gi-oh-duel-arena-godot.git
```

```bash
cd yu-gi-oh-duel-arena-godot
```

That is the whole setup. There is nothing to install and nothing to configure.

`project.godot` is at the **repository root**, so the repository root *is* the Godot project
directory. Open that folder in Godot 4.7.x — either from the Godot Project Manager
("Import", then select the cloned folder) or from the command line:

```bash
godot --editor --path .
```

The first open triggers Godot's import pass and creates a local `.godot/` cache directory,
which is ignored by Git.

---

## Running the project

**There is no playable scene yet.** `project.godot` deliberately leaves `run/main_scene`
unset:

```ini
; run/main_scene is intentionally unset until the Phase 7 playable UI exists. Pointing it
; at a scene that has not been built yet makes every headless run report a load error.
```

Pressing **F5** in the editor will therefore ask you to pick a main scene — there is not yet
one to pick. This is expected, not a broken checkout. Until Phase 7, the way to "run" the
project is to run the engine headlessly.

The smoke check is the quickest proof that a checkout is healthy. It loads the card database,
builds both decks, and constructs a duel:

```bash
godot --headless --path . --script res://Scripts/tests/SmokeCheck.gd
```

Expected output:

```
  card definitions: 37 monsters / 18 spells / 22 traps
  deck1.json -> 'Blue-Eyes Dragon Guard' 40 cards
  deck2.json -> 'Fairy-Tail Tribute Guard' 40 cards

SMOKE CHECK: PASS
```

Prefer the wrapper scripts below over the raw command — they add a parse-check pass and a
real exit code, for the reasons in [Running the tests](#running-the-tests).

---

## Running the tests

Both runners take the name of an entry script in `Scripts/tests/` and default to `RunTests`.
Both locate Godot via `-GodotPath` / `$GODOT_BIN` / `$GODOT` / `PATH`. **Both exit 0 on pass
and 1 on failure**, so they can be used directly in CI.

### Windows (PowerShell)

Full regression suite:

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests
```

Smoke check:

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 SmokeCheck
```

Refresh the class cache after adding a new `class_name`:

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

### Reporting helpers (Python, optional)

Regenerate the implementation matrix — this is what produces the card counts, and they are
never written by hand:

```bash
python Tools/build_matrix.py
```

Regenerate the canonical card database from the verified research data:

```bash
python Tools/build_card_db.py
```

### What a passing run looks like

```
=======================================
TOTAL: 5509 passed, 0 failed (5509 assertions across 63 suite(s))
=======================================
RESULT: PASS
RUNNER: PASS
```

**Two `SCRIPT ERROR` lines on stderr are expected and are not failures.** They are printed by
`push_error` from two tests that deliberately prove the engine fails *loudly*: `ChainTests`
proves a missing `resolve()` is a hard error rather than a silent no-op, and
`ContinuousTests` proves an unknown restriction flag is rejected rather than silently
written. A run without them would mean those guards had stopped working.

You will also see `WARNING: ... ObjectDB instances were leaked at exit`. That is a known,
tracked harness issue — see [Known limitations](#known-limitations).

### Why the wrapper scripts exist

Both were written after the raw command cost real time, and both guards are worth keeping:

1. **Godot writes heavily to stderr** — every `push_error` prints a full GDScript backtrace.
   Piping stdout and stderr through a shell can block on a full pipe, so the runners redirect
   to files and print them afterwards.
2. **A suite that fails to *compile* hangs forever.** `RunTests._initialize()` throws before
   it can call `quit()`, leaving the headless `SceneTree` running. The runners do a
   `--check-only` parse pass first, so a compile error is an immediate, readable failure
   instead of a hang. The POSIX runner additionally bounds the run with `timeout`.

The Godot binary does not return a usable exit code for a `--script` run, so success is
decided by the `RESULT: PASS` / `SMOKE CHECK: PASS` line the suite prints — and the runner
turns that into its own exit code.

---

## Architecture

The engine is layered, and each layer only knows about the ones above it:

```
                 Data/cards/cards.json          (verified official card data)
                            |
                            v
   GameState  ----------------------------  authoritative duel state
      |                                      zones, LP, control, leases, counters
      v
   Rules queries  ------------------------  SummonRules, BattleRules,
      |                                     ActivationRules, ContinuousEffects
      v
   Timing + Chain  -----------------------  DuelEngine (Fast Effect Timing A-E),
      |                                     ChainManager, ChainLink, TriggerCollector
      v
   Card effects  -------------------------  EffectDef + EffectPrimitives,
      |                                     Scripts/cards/registry/<CardName>.gd
      v
   Semantic events  ----------------------  GameEvent stream + DuelLog
      |
      v
   Presentation  -------------------------  (Phase 7+, not built)
```

### The public surface

Everything a player — human, scripted test, or future CPU — can do goes through four calls on
`DuelEngine`:

| Call | Meaning |
|---|---|
| `get_legal_actions(pid)` | What the turn player may do in an open game state. |
| `get_legal_responses(pid)` | What a player may activate in a response window. |
| `submit_action(action)` | Submit one action. **Re-validated on submit**, so a hand-built action cannot bypass the rules. |
| `get_visible_state(viewer_id)` | The board **as that player is allowed to see it**. |

A controller can only ever choose from actions the engine has already declared legal, and the
engine re-checks anyway. There is deliberately no second, looser path into state mutation.

### Key modules

**`Scripts/engine/` — state and the public API**

| File | Role |
|---|---|
| `GameState.gd` | The single source of truth. All card movement goes through `move_card()` with an explicit `MoveReason`, which is what makes "destroyed" distinguishable from "returned", "Tributed" or "sent as a cost". Owns control leases, banish leases and counters. |
| `PlayerState.gd` | Per-player zones. Ordered zones are fixed-size arrays with `null` for empty slots, so a card's `zone_index` is stable. |
| `CardDef.gd` | The immutable, shared identity of a card, loaded from `cards.json`. **Never written to** — a Trap Monster gains a monster identity on the *instance*, not on the definition. |
| `CardInstance.gd` | One runtime copy. Two copies of the same card are distinct instances with distinct ids; nothing in the engine identifies a card by name alone. |
| `DuelEngine.gd` | The authoritative API and the Fast Effect Timing state machine (boxes A–E). |
| `DuelAction.gd` | One structured, engine-validated action. |
| `DecisionRequest.gd` | A structured question the engine asks a player. Only legal choices are ever offered; an illegal answer is a hard error. |
| `GameEvent.gd` | Semantic events. An event states that something **already happened** in authoritative state, so consuming one can never change a rules outcome. |
| `DuelLog.gd` | The action / replay log. |
| `Rng.gd` | Explicitly seeded, never reseeded from the clock. |
| `PlayerController.gd` | The abstraction every player sits behind — local human, future CPU, future network. |
| `ScriptedController.gd` | The deterministic controller the test suite drives. |
| `Enums.gd` | Every enumeration, each value mapping to a documented rule. The engine never uses bare strings for these concepts. |

**`Scripts/rules/` — the rules themselves**

| File | Role |
|---|---|
| `SummonRules.gd` | Normal / Tribute / Flip / Special Summon, and the two-step declaration that makes a Summon negatable. |
| `BattleRules.gd` | Battle Phase, attack declaration, attack replay, and the five-sub-step Damage Step. |
| `ActivationRules.gd` | Shared activation legality. The trigger system and the player-facing API funnel through the same `can_activate()`. |
| `ChainManager.gd` | Chain construction and reverse-order resolution. Fails loudly on a missing `resolve()`. |
| `ChainLink.gd` | One link. Targets and costs are fixed at activation and stored here; resolution reads them back and **re-checks** them. |
| `TriggerCollector.gd` | Gathers effects whose trigger conditions have been met, in the official simultaneous-activation order. |
| `ContinuousEffects.gd` | Recomputes state-derived effects from the current board, so an effect switches off by itself when its source leaves, is flipped face-down, or is negated. |
| `TurnFlow.gd` | Phase progression, including Battle-Phase skips. |

**`Scripts/cards/` — the card layer**

| File | Role |
|---|---|
| `CardRegistry.gd` | **Scans** `registry/` rather than reading a hand-written list, so it can never drift from the matrix. Rejects a chain-starting effect with no `resolve()`. |
| `EffectDef.gd` | The declarative description of one official effect clause. |
| `EffectContext.gd` | What a clause's callables receive: state, controller, chain link, cost payload. |
| `EffectPrimitives.gd` | The shared mechanic library — the reusable, tested primitives that card files compose. |
| `registry/<CardName>.gd` | One file per card. |

A full write-up — system boundaries, state ownership, the Chain/timing architecture, the
event system, deterministic replay, test architecture, and the presentation and CPU
boundaries — is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Repository structure

```
.
├── project.godot                  Godot 4.7 project (config_version=5); repo root IS the project root
├── icon.svg                       project icon (original artwork)
├── README.md                      this file
├── CONTRIBUTING.md                how to work on this project
├── PROJECT_STATE.md               authoritative internal resume / checkpoint file
├── .gitattributes  .gitignore  .graphifyignore
│
├── Scripts/
│   ├── engine/                    authoritative state and the public API
│   │   ├── GameState.gd           the single source of truth
│   │   ├── PlayerState.gd         per-player zones
│   │   ├── CardDef.gd             immutable shared card identity
│   │   ├── CardInstance.gd        one runtime copy of a card
│   │   ├── DuelEngine.gd          public API + Fast Effect Timing state machine
│   │   ├── DuelAction.gd          one validated action
│   │   ├── DecisionRequest.gd     a structured question to a player
│   │   ├── GameEvent.gd           semantic event vocabulary
│   │   ├── DuelLog.gd             action / replay log
│   │   ├── Rng.gd                 seeded deterministic RNG
│   │   ├── PlayerController.gd    the player abstraction
│   │   ├── ScriptedController.gd  deterministic controller for tests
│   │   └── Enums.gd               every enumeration in the engine
│   ├── rules/                     SummonRules, BattleRules, ActivationRules,
│   │                              ChainManager, ChainLink, TriggerCollector,
│   │                              ContinuousEffects, TurnFlow
│   ├── cards/
│   │   ├── CardRegistry.gd        scans and validates the registry
│   │   ├── EffectDef.gd           one official clause, declaratively
│   │   ├── EffectContext.gd       what a clause's callables receive
│   │   ├── EffectPrimitives.gd    the shared, tested mechanic library
│   │   └── registry/              one .gd file per implemented card
│   ├── tests/
│   │   ├── RunTests.gd            headless entry point; suites registered explicitly
│   │   ├── SmokeCheck.gd          load card DB, build decks, construct a duel
│   │   ├── TestCase.gd            the assertion harness
│   │   └── DumpAssertionCounts.gd per-suite assertion reporting
│   ├── ui/                        empty — Phase 7
│   ├── presentation/              empty — Phase 8
│   └── tools/                     empty
│
├── Tests/
│   ├── rules/                     21 generic rules + mechanic-gate suites
│   ├── cards/                     41 per-card suites + 1 interaction suite
│   ├── support/TestFixtures.gd    duel builders; never hand-roll a duel
│   ├── interactions/              reserved for cross-card interaction suites
│   └── integration/               reserved for Phase 6 scripted duels
│
├── Data/
│   ├── cards/cards.json           77 canonical card definitions (verified official text)
│   ├── decks/deck1.json           Blue-Eyes Dragon Guard — 40 cards
│   ├── decks/deck2.json           Fairy-Tail Tribute Guard — 40 cards
│   ├── generated/card_pool.json   deck composition, from Tools/enumerate_cards.py
│   ├── generated/konami_cards.json official text / type capture
│   ├── card_art/                  empty — you supply images locally (see below)
│   └── provenance/                data provenance records
│
├── Research/                      the rules trail — read before changing a rule
│   ├── RULES_SPEC.md              the implementable rules contract (§1–§17)
│   ├── RULES_SOURCES.md           source register S1–S4: URLs, hashes, page numbers
│   ├── CARD_RULINGS.md            per-card ruling decisions R1–R34, with confidence
│   └── sources/README.md          how to fetch the primary documents (not vendored)
│
├── Reports/
│   ├── TEST_RESULTS.md            per-suite results, and every defect the tests caught
│   └── CARD_IMPLEMENTATION_MATRIX.csv  authoritative per-card status (generated)
│
├── Tools/
│   ├── run_tests.ps1              headless runner (Windows)
│   ├── run_tests.sh               headless runner (Linux / macOS / CI)
│   ├── build_matrix.py            generates the implementation matrix
│   ├── build_card_db.py           generates cards.json + the deck files
│   ├── enumerate_cards.py         enumerates the pool from the deck CSVs
│   ├── fetch_official_cards.py    captures official card text
│   ├── dump_official_text.py      prints captured text for review
│   └── diff_card_text.py          diffs implemented text against captured text
│
├── Scenes/                        empty scaffolding — Phases 7–10
├── Assets/                        empty scaffolding — Phases 8–10
├── .github/workflows/tests.yml    headless Godot CI
└── docs/
    ├── ARCHITECTURE.md            system boundaries, layers, chain/timing, event system
    ├── TESTING.md                 test organisation, gates, harness pitfalls
    ├── RULES_AND_RULINGS.md       the source hierarchy and confidence handling
    └── PROJECT_STATUS.md          public-facing status summary
```

---

## How cards are implemented

A card is a **declarative description of its official clauses**, not a script that mutates the
board. `Scripts/cards/registry/ShiningAngel.gd` is the template — read it first.

Each registry file:

* `extends RefCounted` with **no `class_name`** (77 of them would pollute the global class
  list; the registry loads by path);
* declares `const CARD_NAME := "..."`;
* quotes the **verified official text** in a comment or constant;
* returns **one `EffectDef` per official effect clause** from `func effects() -> Array`.

An `EffectDef` declares what the rules engine needs in order to judge the clause, rather than
imperative steps:

| Field | What it declares |
|---|---|
| `effect_type` | Trigger / Quick / Ignition / Continuous / Flip |
| `optionality` | "You can" is optional; silence is never taken as yes |
| `spell_speed` | SS1 / SS2 / SS3 |
| `activation_locations` | Hand, field face-up, Graveyard, … |
| `trigger_events` | Which `GameEvent.Kind`s open its window |
| `legal_phases` | Phase restrictions |
| `damage_step_permission` | Whether it may activate inside the Damage Step |
| `targets`, `target_count_min/max` | Whether the printed text says "target" |
| `once_per_turn_instance` / `_named_effect` / `_named_activation` | Which of the three distinct once-per-turn rules applies |
| `negates_effects`, `restriction_group` | Negation and restriction semantics |
| `condition` | May it activate at all? |
| `can_pay_cost` / `pay_cost` | The cost, kept strictly separate from the effect |
| `legal_targets` / `targets_valid` | Targeting, and **re-validation at resolution** |
| `resolve` | What happens when the link resolves |
| `apply_continuous` | For continuous clauses, recomputed from the board |
| `respond_to_event` | A continuous clause reacting to a discrete event |
| `destruction_substitute` | Destruction replacement |
| `ruling_ref` | The `CARD_RULINGS.md` entry justifying a non-obvious decision |

Behaviour is composed from `EffectPrimitives.gd`, the shared mechanic library, rather than
re-implemented per card. When two cards mean the same thing, they call the same primitive —
so a rules correction lands in one place.

### The definition of "implemented"

**A card is not implemented because it loads.** The project's rule is:

> A card is complete only when **every** relevant clause of its official text is implemented,
> and deterministic tests covering those clauses — positively **and** negatively — pass.

`Tools/build_matrix.py` enforces the honest version of this by *computing* the counts: it
reads `const CARD_NAME` from the registry and `const CARD_UNDER_TEST` from the test suites. A
card counts as **tested** only when it has its own suite. An interaction suite declares
neither marker, so it can never inflate the count, and a suite covering a whole mechanic
group declares `const CARDS_UNDER_TEST := [...]` instead. **The matrix therefore cannot
over-report**, and the counts are never written by hand.

Two deliberate exceptions, both documented: a vanilla Normal Monster has no registry file and
is counted from the card database's `is_normal` flag; and two clauses in the pool
(`Apprentice Magician`'s Spell Counter clause, `Fairy Tail - Rella`'s equip clause) can never
be live in a real duel with this card pool. Both are implemented in full and tested against
synthetic cards, **and** asserted against the real library so the fact cannot rot.

---

## Testing strategy

The suite is the product as much as the engine is. Full detail is in
[`docs/TESTING.md`](docs/TESTING.md).

### Layers

| Layer | Where | What it proves |
|---|---|---|
| **Generic rules tests** | `Tests/rules/` | The rules engine obeys the rulebook independently of any specific card, using synthetic cards from `TestFixtures`. |
| **Mechanic gates** | `Tests/rules/` | A whole generic mechanic works **before** any card depends on it. |
| **Per-card suites** | `Tests/cards/` | Every clause of one card, positively and negatively. |
| **Interaction suites** | `Tests/cards/`, `Tests/interactions/` | Cards behaving correctly *against each other*. |
| **Regression** | `RunTests.gd` | Everything, every time. A run is only green at **0 failures**. |
| **SmokeCheck** | `SmokeCheck.gd` | The card database loads, both decks build, a duel constructs. |

### Mechanic gates, and why they come first

A **mechanic gate** is a generic test suite for a whole mechanic, written and passing *before*
the first card that needs it exists. The card then has nothing left to invent — it composes a
mechanism already proven correct in isolation, and a bug is unambiguously either "the
mechanic" or "this card", never both.

Gates in the repository today:

| Gate suite | Mechanic |
|---|---|
| `EquipTests` | The Equip subsystem |
| `ControlTests` | Owner vs controller, control leases |
| `MovementTests` | Movement, Deck placement and excavation |
| `BanishTests` | Permanent and temporary banishment, return leases |
| `TrapMonsterTests` | A Trap that becomes a monster |
| `BattlePhaseRestrictionTests` | "Skip your next Battle Phase" as turn state |
| `LifePointCostTests` | Paying LP as an activation **cost** |
| `AttackRestrictionTests` | Attack prevention vs attack negation vs activation lock |
| `CounterTests` | Counters |
| `DamageStepTests` | The five Damage Step sub-steps and their activation restriction |
| `TimingTests`, `ChainTests` | Fast Effect Timing and Chain construction |
| `HiddenInfoTests` | Per-viewer visibility |
| `ReplayTests` | Determinism and replay |

The pattern has paid off on every batch that used it. `AttackRestrictionTests` alone (229
assertions) established that attack **prevention**, attack **negation** and a card-class
**activation lock** are three different things — before a single card in that group was
written, which is what stopped them collapsing into one `attack_blocked` boolean.

### Determinism and harness guards

Every test is deterministic: a seeded `Rng`, and a `ScriptedController` that answers from an
explicit queue so a test states exactly what a player chooses.

The harness actively guards against tests that only **look** like they pass:

* **A suite that runs zero assertions is a failure.** Without this, a suite whose script
  failed to compile reports "0/0 passed" and the run claims PASS while testing nothing. This
  happened once during development and must never be possible again.
* **Suites are registered explicitly** in `RunTests.gd`, so a suite that fails to load is a
  hard error rather than a silently skipped file.
* **The engine fails loudly, and tests prove it does**: `ChainManager` rejects a
  chain-starting effect with no `resolve()`, and `ContinuousEffects` rejects an unknown
  restriction flag. Both are asserted.
* **`ScriptedController.errors` is asserted empty** by any test that cares which card paid a
  cost — that is what proves a queued answer actually reached the prompt the test meant.
* **A parse check runs before the suite**, so a compile error is a readable failure, not a
  hang.

`Reports/TEST_RESULTS.md` records not just the results but **every defect the tests caught**,
milestone by milestone — including defects in the test harness itself.

---

## Where the rules come from

**Nothing in this engine is implemented from memory.** Every rule traces to a recorded source.
See [`docs/RULES_AND_RULINGS.md`](docs/RULES_AND_RULINGS.md) for the full policy.

| Document | Role |
|---|---|
| [`Research/RULES_SOURCES.md`](Research/RULES_SOURCES.md) | The **source register**. For each source S1–S4: title, publisher, canonical URL, byte size, SHA-256, date accessed, and the exact list of rules it establishes, with page numbers. |
| [`Research/RULES_SPEC.md`](Research/RULES_SPEC.md) | The **implementable rules contract**, §1–§17. Every section cites the source it came from (`[S1 p.44]`). Engine code cites these section numbers in comments. |
| [`Research/CARD_RULINGS.md`](Research/CARD_RULINGS.md) | Per-card ruling decisions **R1–R34**, each with an explicit confidence level and the reasoning behind it. |

### Source hierarchy

1. **Primary — official Konami sources only.** The Official Rulebook v10 (S1), the official
   Fast Effect Timing chart (S2), the official Damage Step rules (S3), and the official
   Yu-Gi-Oh! Card Database (S4).
2. **Secondary — clearly marked as such.** Community sources may be used *only* where an
   official source does not provide the needed detail, and are recorded as SECONDARY. **They
   are never described as official.**
3. **Never a rules source: Master Duel.** It is presentation inspiration only. The project
   makes no claim of affiliation with it or with any Konami product.

### Confidence is recorded, not faked

Where a ruling is a reasoned decision rather than a quoted official sentence, it is recorded
as exactly that, with its confidence level and the reasoning. Examples currently on the
record: **R34 part D** is MEDIUM-HIGH and explicitly flagged for re-checking against an
official source; **R29** is MEDIUM overall (HIGH for one card, MEDIUM for the other, and the
difference is explained); **R27** and **R28** rest on community-transcribed rulings and say
so; **R25** is a reasoned decision about an instant that no official sentence names.

Each of these is **asserted in tests and isolated behind a single predicate**, so a later
correction fails loudly and lands in one place rather than drifting silently. Four rulings —
**R3, R6, R7 and R8** — are still **OPEN**, and are listed as open.

The primary source documents themselves are **not redistributed** in this repository; see
[`Research/sources/README.md`](Research/sources/README.md) for how to fetch each one from
Konami's site and verify it against the recorded SHA-256.

---

## Determinism and replay

A duel is a pure function of `(decks, RNG seed, the ordered list of player decisions)`.
Nothing in the engine reads the clock, the frame counter, or unseeded randomness.

| Piece | What it does |
|---|---|
| `Rng.gd` | Explicitly seeded, never reseeded from the system clock. |
| `DuelLog.gd` | Records the seed plus every submitted action and decision answer, in order. |
| `GameEvent` stream | A semantic description of everything that happened, with its cause. |
| `ReplayTests` | Proves a recorded duel replays to an identical state. |

This is not a feature for its own sake — it is the debugging tool. A rules interaction that
goes wrong is a **reproducible** artefact rather than an anecdote: re-run the seed and the
decision list and you get the same duel, every time, on any machine. Several tests
deliberately run the same scenario twice and assert the results are identical, so a
non-deterministic regression fails immediately instead of becoming a flaky test.

The semantic event stream is also what keeps presentation honest: an event says something
*already happened* in authoritative state, so a renderer consuming one cannot change a rules
outcome.

---

## Hidden information

The engine models visibility rather than assuming an omniscient viewer.
`DuelEngine.get_visible_state(viewer_id)` returns the board **as that player is allowed to see
it** — your own hand by name, your opponent's as anonymous cards, face-down cards concealed.
This is covered by `HiddenInfoTests` (76 assertions).

Implemented today:

* per-viewer state views for hands, Deck and face-down cards;
* **reveal tracking** — a card revealed to a specific player is recorded as revealed *to that
  player*, via `revealed_to`, not globally;
* **shuffling clears known information** about Deck contents and order;
* **known top/bottom placement** — a card deliberately placed on top of or beneath the Deck
  stays known to whoever is entitled to know it;
* the `CARD_REVEALED` event, so presentation can show a reveal without inferring it.

**Planned, not built:** the Phase 9 pass-and-play privacy UX — the handoff screen that hides
one player's hand while the other takes their turn on the same PC. The engine-side groundwork
above exists specifically so that UI will have correct data to render, but **the UI does not
exist yet**.

---

## Card coverage

**49 / 77 implemented, 49 / 77 tested, 28 remaining.** Official text is verified for all 77.

The **authoritative per-card status** is
[`Reports/CARD_IMPLEMENTATION_MATRIX.csv`](Reports/CARD_IMPLEMENTATION_MATRIX.csv) —
generated by `python Tools/build_matrix.py`, never hand-edited. It carries, per card:
passcode, deck(s), quantity, category, whether official text was verified, primary and
secondary source URLs, effect clause count, mechanics used, whether a special ruling was
needed and whether it was verified, implementation status, test status, and notes.

Cards are implemented in **mechanic groups**, not alphabetically, so each batch completes a
subsystem:

| Batch | Group | Status |
|---|---|---|
| 1 | The 9 vanilla Normal Monsters | complete |
| 2 | Resolution-time Special Summon family | complete |
| 3 | Continuous-Trap revival, summoning procedures, first Equip group | complete |
| 4 | Remaining Continuous Traps + the Continuous Spell — **completes the Continuous group** | complete |
| 5 | The counter monster, second Equip group, negation — **completes the Equip group** | complete |
| 6 | Flip Summon negation + control change — **completes the control-change group** | complete |
| 7 | Movement and excavation, in four units — **completes the movement group** | complete |
| 8 | Banishment, LP costs, Trap Monsters, Battle-Phase restriction | complete |
| 9 | Attack restriction / negation | **unit A (the gate) only; no card started** |

The 28 remaining cards: `A Hero Emerges`, `Back-Up Rider`, `Burst Stream of Destruction`,
`Cards of Consonance`, `Chiron the Mage`, `Damage Condenser`, `Divine Dragon Apocralyph`,
`Dragon Shrine`, `Fairy Tail - Luna`, `Fairy Tail - Sleeper`, `Herald of Creation`,
`Hidden Springs of the Far East`, `Honest`, `Kaiser Sea Horse`, `Maiden with Eyes of Blue`,
`Mirage Dragon`, `Soul Exchange`, `Spiritual Fire Art - Kurenai`, `Spiritual Water Art - Aoi`,
`Stamping Destruction`, `Straight Flush`, `Swords of Revealing Light`, `The Monarchs Awaken`,
`The White Stone of Legend`, `Trade-In`, `Vampiric Koala`, `White Elephant's Gift`,
`Witchcrafter Golem Aruru`.

The next card is `Mirage Dragon`, and its plan is written out in `PROJECT_STATE.md` §8.

---

## Development workflow

The established per-card process. It is deliberately slow at the front and fast at the back.

1. **Verify the official card text**, from the official card database (S4). Never from
   memory, and never from a wiki without marking it SECONDARY.
2. **Enumerate the effect clauses.** One `EffectDef` per official clause. Write them down
   before writing code.
3. **Identify the generic mechanics** the clauses need.
4. **If a generic mechanic does not exist yet, build its gate first** — a generic suite,
   written and passing against synthetic cards, *before* the card exists.
5. **Implement the reusable primitive** in `EffectPrimitives.gd`, not in the card file, if any
   other card could mean the same thing.
6. **Implement the card** in `Scripts/cards/registry/<CardName>.gd`.
7. **Write the per-card suite** in `Tests/cards/<CardName>Tests.gd` with
   `const CARD_UNDER_TEST`, covering every clause **positively and negatively**. The negatives
   are where the value is.
8. **Write interaction tests** against cards the new one meaningfully touches.
9. **Register the suite** in `Scripts/tests/RunTests.gd`.
10. **Run `--import`, then the suite, then the full regression.** A new `class_name` is
    invisible until the class cache is rebuilt, and the import must be its **own** command —
    chaining it into the test run still reads the stale cache and fails with a misleading
    "Identifier not declared" error.
11. **Update the durable state**: `python Tools/build_matrix.py` (never hand-edit the counts),
    then `Reports/TEST_RESULTS.md` and `PROJECT_STATE.md`.
12. **Commit**, with a message that says what was proven, not just what was added.

Any non-obvious rules decision gets an entry in `CARD_RULINGS.md` **with its confidence
level**, a `ruling_ref` on the `EffectDef`, and an assertion that pins it — so that if it is
later found wrong, the test fails loudly instead of the behaviour drifting.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full expectations.

---

## Roadmap

Honest progression. Only the first five rows are done, and the fifth is in progress.

| Phase | Goal | Status |
|---|---|---|
| 0 | Data inspection, Godot install and verification | **complete** |
| 1 | Authoritative TCG rules research | **complete** |
| 2 | Per-card official text and rulings research (77 cards) | **complete** |
| 3 | Architecture and scaffolding | **complete** |
| 4 | Core rules engine | **complete** — Gate B met |
| **5** | **Card effect library — all 77 cards + interaction coverage** | **in progress — 49/77** |
| 6 | Backend acceptance: full rules/card integration and scripted duel coverage | not started |
| 7 | Local Human vs Human — same-PC / pass-and-play duel UI | not started |
| 8 | Arena presentation — 3D arena, card movement, holographic / 2.5D monsters, effects, audio | not started |
| 9 | Privacy UX — the hidden-hand handoff flow | not started |
| 10 | Asset polish and Windows build / export packaging | not started |
| 11 | Full acceptance | not started |
| later | CPU player, built on the same `get_legal_actions()` API | not started |

**None of Phases 6–11 is started, and nothing in this repository should be read as claiming
otherwise.**

---

## Known limitations

Current and honest, taken from the internal checkpoint:

* **Card coverage is incomplete.** 28 of 77 cards are `NOT_IMPLEMENTED`, and the matrix says
  so rather than rounding up.
* **Batch 9 is partial.** The generic gate is done; no batch-9 card is started.
* **No playable UI.** `run/main_scene` is intentionally unset; pressing F5 will not start a
  game. That is Phase 7.
* **No CPU opponent.** The `PlayerController` abstraction exists for one, but none is written.
* **No 3D presentation, animation or audio.** `Scenes/` and `Assets/` are empty scaffolding.
* **ObjectDB growth under the full suite.** The last run reported **164,444 leaked ObjectDB
  instances at exit** — RefCounted reference cycles between `GameState`, the `DuelLog` signal
  and test closures. It grows with the number of duels the suite builds. It causes **no test
  failure, hang, memory pressure or unreliable result**, and no rules outcome changes, so it
  was not allowed to derail card work — but it is **scheduled to be characterised or fixed
  before Phase 7**, when a UI keeps one duel alive for a long session. The trend is recorded
  checkpoint by checkpoint in `Reports/TEST_RESULTS.md` rather than explained away.
* **Simultaneous-LP-zero (a draw) is unexercised.** This is the only remaining item on the
  core-rules coverage list. It is a *reachability* gap rather than a missing implementation:
  no card in this 77-card pool can drive both players to 0 LP at once. This was **checked, not
  assumed** — `ChainDetonationTests` proves its burn ends the duel with a single winner
  (`PLAYER_0_WINS`, not `DRAW`), and `ChainHealingTests` proves the healing card cannot end a
  duel at all.
* **Two clauses in the pool can never be live** with this card pool (`Apprentice Magician`'s
  Spell Counter clause, `Fairy Tail - Rella`'s equip clause). Both are fully implemented and
  tested against synthetic cards, and asserted against the real library so the fact cannot
  rot.
* **Four rulings are open** — R3, R6, R7, R8 — and **R34 part D is MEDIUM-HIGH**, reasoned
  from Problem-Solving Card Text rather than a quoted ruling, and explicitly flagged for
  re-checking. It is isolated behind one predicate
  (`ActivationRules.card_class_activation_ok()`), so correcting it is a one-place change.
* **An End-Phase banish edge case is deliberately left open**: a card banished by an effect
  activated *during* the End Phase does not return until the *next* turn's End Phase, because
  expiry runs as the phase is entered.
* **macOS is untested.** Windows 11 and Ubuntu (in CI) both run the full suite to identical
  results; nobody has run it on macOS.
* **No Extra Deck mechanics.** Xyz, Synchro, Link, Pendulum and Ritual summoning are not
  implemented; the current pool contains no such cards, though the zones exist in the model.

---

## Design principles

These are the rules the project holds itself to, and why it is structured this way.

1. **The rules engine is authoritative.** `GameState` is the single source of truth.
2. **Presentation never decides legality.** It renders what the engine declares legal and
   submits actions the engine re-validates.
3. **No runtime interpretation of card text.** Cards are compiled, reviewed code — not text
   parsed at runtime, and not an LLM reading card text during a duel. Official text is
   converted into deterministic code by a human-reviewed process, once.
4. **Nothing is implemented from memory.** Every rule cites a recorded source.
5. **Generic mechanic gates come before the cards that depend on them.**
6. **Deterministic tests before visuals.** Every phase before 7 is headless.
7. **Card effects reuse shared primitives** wherever the semantics genuinely match, so a rules
   correction lands in one place.
8. **Ambiguous rulings are documented with their confidence** and pinned by an assertion —
   never silently guessed.
9. **Fail loudly.** A missing `resolve()`, an unknown restriction flag, an illegal controller
   answer and a zero-assertion suite are all hard errors.
10. **Never weaken a test to make behaviour pass.** If a test and the engine disagree, one of
    them is wrong, and the answer comes from the rules trail.
11. **Counts are computed, never claimed.** The matrix reads the code.
12. **Distinct concepts stay distinct.** Attack prevention is not attack negation. A cost is
    not an effect. An owner is not a controller.

---

## Contributing

Contributions are welcome, with the caveat that this is an engine-correctness project and the
bar for a card is deliberately high. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) first — it
covers setup, the new-card workflow, rules-verification expectations, test requirements and
pull-request expectations.

Three things will get a change rejected regardless of how good the code is:

* **copyrighted or ripped assets** of any kind;
* **weakening, retargeting or deleting an existing assertion** to make new behaviour pass;
* **an undocumented ruling decision** — if the official text is ambiguous, say so in
  `CARD_RULINGS.md`, with a confidence level.

---

## Card images and assets

**This repository contains no card images, no game art, no ripped assets and no audio.**
`Data/card_art/` and `Assets/` are empty scaffolding, and `.gitignore` keeps card art out.

Nothing in the engine or the test suite needs an image: cards are identified by name and
passcode, and the entire suite runs headless. If you want art locally for future UI work,
supply your **own** legally obtained images and place them in `Data/card_art/`. That directory
is gitignored, so local images cannot be committed by accident. Do not add images ripped from
Master Duel or any other Konami product to this repository.

The official Konami rules documents the engine was built from are likewise **not** vendored
here — see [`Research/sources/README.md`](Research/sources/README.md) to fetch and verify them
yourself.

Card **names and official card text** appear in `Data/cards/cards.json` because a rules engine
cannot function without knowing what each card does. Each entry records the official source
URL it was verified against. This is unofficial fan use; see the disclaimer below.

---

## Licence

**This project currently has no open-source licence.**

Being publicly readable on GitHub does **not** grant reuse rights. Without a licence, default
copyright applies: you may view and fork the repository through GitHub's own interface, but no
rights to use, modify, redistribute or build upon the code are granted. If you would like to
use any of it, please open an issue and ask.

A licence may be added later. Until a `LICENSE` file exists in this repository, assume none.

---

## Disclaimer

This is an **unofficial, non-commercial fan project**, built as a technical exercise in rules
engine design.

It is **not affiliated with, endorsed by, sponsored by, or approved by Konami Digital
Entertainment** or any of its subsidiaries or affiliates.

*Yu-Gi-Oh!* and all related names, marks, card names, card text and imagery are trademarks
and/or copyrights of their respective rights holders. Card names and official card text are
referenced here solely to implement and document game rules for a non-commercial fan project.
Master Duel is referenced only as general presentation inspiration for a future phase; no
Master Duel asset, resource or code is used, included or redistributed.

No copyrighted game assets are distributed in this repository.

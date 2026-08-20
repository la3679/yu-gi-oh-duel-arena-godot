# Contributing to Duel Arena

Thanks for your interest. This document is longer than most `CONTRIBUTING.md` files because
this project has an unusual bar: it is a **rules-correctness** project, and a card that "works
in the cases I tried" is not a card that is done.

Please read [`README.md`](README.md) first for what the project is and where it currently
stands.

> **Licence note.** This repository currently has **no open-source licence**, so no reuse
> rights are granted by default. By opening a pull request you are offering your contribution
> for inclusion in this project. If you are not comfortable with that, please open an issue to
> discuss before writing code.

---

## Table of contents

- [Development setup](#development-setup)
- [Before you start](#before-you-start)
- [Coding expectations](#coding-expectations)
- [Rules-verification expectations](#rules-verification-expectations)
- [Test requirements](#test-requirements)
- [The new-card workflow](#the-new-card-workflow)
- [Adding a generic mechanic gate](#adding-a-generic-mechanic-gate)
- [Updating the durable state files](#updating-the-durable-state-files)
- [Commit messages](#commit-messages)
- [Pull request expectations](#pull-request-expectations)
- [Things that will get a change rejected](#things-that-will-get-a-change-rejected)
- [Traps that cost previous contributors time](#traps-that-cost-previous-contributors-time)

---

## Development setup

You need **Git** and **Godot 4.7.x** (the standard build — the project contains no C#, so do
not use the .NET/Mono build). Python 3.11+ is optional, and only for the helpers in `Tools/`.

```bash
git clone https://github.com/la3679/yu-gi-oh-duel-arena-godot.git
```

```bash
cd yu-gi-oh-duel-arena-godot
```

There is nothing to install: no package manager, no lockfile, no `.env`, no required
environment variables. `project.godot` is at the repository root, so the repository root *is*
the Godot project directory.

Confirm your checkout is healthy before changing anything:

```bash
./Tools/run_tests.sh SmokeCheck
```

```bash
./Tools/run_tests.sh RunTests
```

On Windows:

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 SmokeCheck
```

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests
```

If Godot is not on your `PATH`, set `GODOT_BIN` (or pass `-GodotPath` on Windows).

**A clean baseline is `5509 passed, 0 failed` across 63 suites, and `RESULT: PASS`.** If your
baseline is not green *before* you change anything, stop and open an issue — do not build on
top of a red suite.

Two `SCRIPT ERROR` lines and an `ObjectDB instances were leaked at exit` warning are
**expected**. See [README → Running the tests](README.md#running-the-tests).

---

## Before you start

**Open an issue first** for anything larger than a typo. Card implementations in particular
are done in deliberate **mechanic groups** rather than alphabetically, and
[`PROJECT_STATE.md`](PROJECT_STATE.md) §8 names the exact next card and its plan. A card
implemented out of order may need a generic mechanic that does not exist yet, and will be
asked to build the gate first anyway.

Good first contributions, roughly in order of difficulty:

* documentation corrections, especially anywhere the docs and the code disagree;
* an **interaction test** between two cards that are both already implemented — the project
  wants far more of these;
* a card from the remaining 28 whose mechanics are all already gated;
* a generic mechanic gate for a mechanic none of the implemented cards needed yet.

---

## Coding expectations

**Match the surrounding code.** It has a consistent style, and the existing files are the
specification for it.

* **GDScript, statically typed.** Use `:=` inference and explicit `-> ReturnType` annotations
  the way the existing files do.
* **Comments explain *why*, and cite the rule.** Every rules-bearing piece of code cites the
  `RULES_SPEC.md` section it implements, and rulings cite `CARD_RULINGS.md` — for example
  `# RULES_SPEC.md §7.2 [S1 p.41]`. A reviewer must be able to check your code against the
  rule without re-deriving it.
* **Engine code has no presentation.** Nothing in `Scripts/engine/`, `Scripts/rules/` or
  `Scripts/cards/` may draw, animate, `await` a frame, touch a `Node`, or read input. These
  are plain `RefCounted` classes so the whole system stays headlessly testable.
* **No bare strings for concepts that have an enum.** Add to `Enums.gd` instead.
* **All card movement goes through `GameState.move_card()`** with an explicit
  `Enums.MoveReason`. That reason is what makes "destroyed" distinguishable from "returned",
  "Tributed" or "sent as a cost", and card effects depend on the difference.
* **Never write to `CardDef`.** It is the shared, immutable identity of a card; every copy on
  the field points at the same instance. Per-copy mutable state belongs on `CardInstance`.
* **Fail loudly.** No silent fallbacks, no placeholder `resolve()` that does nothing, no
  swallowing an unexpected value. If something is unimplemented, `push_error` and make it a
  hard error. The engine already enforces some of this: `ChainManager` rejects a chain-starting
  effect with no `resolve()`, and `ContinuousEffects` rejects an unknown restriction flag.
* **Prefer a shared primitive.** If another card could plausibly mean the same thing, the
  behaviour belongs in `EffectPrimitives.gd`, not in the card file. Check whether the primitive
  you want already exists — `EffectPrimitives.gd` is large, and `PROJECT_STATE.md` lists the
  primitives each batch added.
* **Keep distinct concepts distinct.** Attack prevention is not attack negation is not a
  card-class activation lock. A cost is not an effect. An owner is not a controller. The engine
  has been careful about this and collapsing two concepts into one boolean will be rejected
  even if the tests pass today.

---

## Rules-verification expectations

**Nothing in this engine may be implemented from memory, including yours.**

1. **Official Konami sources are primary**: the Official Rulebook v10 (S1), the official Fast
   Effect Timing chart (S2), the official Damage Step rules (S3), and the official Yu-Gi-Oh!
   Card Database (S4). They are registered in
   [`Research/RULES_SOURCES.md`](Research/RULES_SOURCES.md) with URLs, hashes and page numbers.
2. **Secondary sources must be marked SECONDARY.** A wiki or a community ruling compilation
   may be used *only* where an official source does not provide the needed detail, and must be
   recorded as secondary. **Never describe a community source as official** — this is the
   single most damaging thing you can do to the project's rules trail.
3. **Master Duel is never a rules source.** It is presentation inspiration only.
4. **Card text comes from the official card database**, not from a wiki and not from the
   printed card in your hand, which may be an outdated printing.

If your change depends on a rule that `RULES_SPEC.md` does not yet cover, add the section,
cite the source, and register the source in `RULES_SOURCES.md` if it is new. The source
documents themselves are not vendored — see
[`Research/sources/README.md`](Research/sources/README.md).

### Ambiguous rulings

Sometimes the official text genuinely does not settle a question. That is fine. What is not
fine is guessing silently. When it happens:

1. add an entry to [`Research/CARD_RULINGS.md`](Research/CARD_RULINGS.md) with the next `R`
   number;
2. state the question, the decision, **the reasoning**, and an explicit **confidence level**
   (HIGH / MEDIUM-HIGH / MEDIUM / LOW) — and say plainly what the decision rests on, for
   example "reasoned from Problem-Solving Card Text, not from a quoted ruling";
3. set `ruling_ref` on the affected `EffectDef` to that `R` number;
4. **isolate the decision behind a single predicate** wherever you can, so that a later
   correction is a one-place change;
5. **assert the behaviour in a test**, so that if the decision turns out to be wrong the suite
   fails loudly instead of the behaviour quietly drifting.

Recording a MEDIUM-confidence decision honestly is a *contribution*. Recording a
MEDIUM-confidence decision as if it were certain is a defect.

---

## Test requirements

**Every behavioural change needs tests, and the full suite must be green.**

* **Cover every clause positively *and* negatively.** The negatives are where the value is: a
  test proving an effect *cannot* be activated when its condition is unmet catches far more
  real bugs than one proving it can when it is met.
* **Build duels through `Tests/support/TestFixtures.gd`.** It has `new_duel()`,
  `battle_duel()` (turn 2, player 0 attacking, past the turn-1 Battle Phase prohibition),
  `pass_until_open()`, `advance_to_phase()`, `end_turn()`, `attack()`, `events_of()`,
  `count_events()`, `first_event_index()`, synthetic card builders, and helpers such as
  `interferer()`, `summon_negator()`, `effect_negator()` and `build_chain_to_depth()`. **Do
  not hand-roll a duel.**
* **Register your suite explicitly** in `Scripts/tests/RunTests.gd`. Suites are listed by hand
  on purpose, so that a suite which fails to load is a hard error and not a silently skipped
  file.
* **Declare the right marker.** A per-card suite declares `const CARD_UNDER_TEST := "..."`. A
  suite covering a whole mechanic group declares `const CARDS_UNDER_TEST := ["...", "..."]`. An
  **interaction suite declares neither** — a card is only ever counted as tested because it has
  its own suite, which is what stops the matrix over-reporting.
* **Assert `controller.errors == []`** in any test that queues a specific answer. That is what
  proves the answer reached the prompt you thought it did, rather than silently defaulting.
* **Determinism.** Use the seeded RNG and an explicit `ScriptedController` queue. If a scenario
  could plausibly be order-dependent, run it twice and assert the results are identical.

### What you must never do

* **Never weaken, retarget or delete an existing assertion to make new behaviour pass.** If
  your change makes an existing test fail, then either your change is wrong or the existing
  test encodes a rules error. Both are real possibilities — but which one it is gets decided by
  going back to `RULES_SPEC.md` and the sources, and the answer belongs in the pull request
  description. Silently adjusting the old test is the one thing that would let this project rot
  without anyone noticing.
* **Never let a suite report zero assertions.** The harness already treats that as a failure,
  because a suite whose script failed to compile otherwise reports "0/0 passed" and the run
  claims PASS while testing nothing. This happened once during development. Do not disable that
  check.

---

## The new-card workflow

The established order. It is deliberately slow at the front.

1. **Verify the official card text** from the official card database (S4). Record the source
   URL.
2. **Enumerate the effect clauses** in writing, before any code. One `EffectDef` per official
   clause.
3. **Identify the generic mechanics** each clause needs.
4. **If a generic mechanic does not exist, build its gate first** — see below. Do not build the
   mechanic inside the card.
5. **Implement the reusable primitive** in `EffectPrimitives.gd` if any other card could mean
   the same thing.
6. **Write `Scripts/cards/registry/<CardName>.gd`.** Copy the shape of
   `Scripts/cards/registry/ShiningAngel.gd`: `extends RefCounted`, **no `class_name`**,
   `const CARD_NAME := "..."`, the verified official text quoted in a comment or constant, and
   `func effects() -> Array` returning one `EffectDef` per clause.
7. **Write `Tests/cards/<CardName>Tests.gd`** with `const CARD_UNDER_TEST`, a `class_name`, and
   `static func run() -> TestCase`. Every clause, positively and negatively.
8. **Write interaction tests** against cards the new one meaningfully touches — especially any
   card that negates, destroys, moves or changes control of it.
9. **Register the suite** in `Scripts/tests/RunTests.gd`.
10. **Run the import pass as its own command**, then your suite, then the full regression:

    ```bash
    ./Tools/run_tests.sh --import
    ```

    ```bash
    ./Tools/run_tests.sh RunTests
    ```

11. **Update the durable state files** (see below).
12. **Commit.**

---

## Adding a generic mechanic gate

A **mechanic gate** is a generic suite for a whole mechanic, written and passing against
synthetic cards *before* the first real card that needs it exists.

This is not ceremony. It means the card has nothing left to invent — it composes a mechanism
already proven correct in isolation — and it means a later bug is unambiguously either "the
mechanic" or "this card", never an argument about both. The pattern has paid off on every
batch that used it, and the gates that exist today are listed in
[README → Testing strategy](README.md#testing-strategy).

To add one:

1. put the suite in `Tests/rules/`, named for the mechanic (`BanishTests`, `EquipTests`,
   `AttackRestrictionTests`, …);
2. build it entirely from **synthetic** cards via `TestFixtures` — a gate must not depend on
   any real card, or it stops being generic;
3. cover the mechanic's boundaries, not just its happy path: what ends it, what does *not* end
   it, what interacts with it, and what must stay unaffected;
4. add any engine vocabulary the mechanic needs (`Enums`, `GameEvent.Kind`,
   `GameState` methods) **as part of the gate**, so nothing is declared-but-unconsumed;
5. document the mechanic in `RULES_SPEC.md` with its source citations;
6. only then implement the cards that use it.

---

## Updating the durable state files

Three files carry the project's state across sessions, and a pull request that changes
behaviour should update them:

| File | What to update |
|---|---|
| [`Reports/CARD_IMPLEMENTATION_MATRIX.csv`](Reports/CARD_IMPLEMENTATION_MATRIX.csv) | **Never by hand.** Run `python Tools/build_matrix.py`, which computes the counts from the code. |
| [`Reports/TEST_RESULTS.md`](Reports/TEST_RESULTS.md) | Your suite's measured assertion count, and **every defect your tests caught** — including defects in the harness. This file is a record of what testing actually found, not a scoreboard. |
| [`PROJECT_STATE.md`](PROJECT_STATE.md) | The checkpoint: what is complete, what is partial, what is next. Be explicit about partial work rather than rounding it up. |

Report numbers as **measured**. If the ObjectDB leak count moved, record the new figure and the
per-assertion ratio; if you do not know why it moved, say that you do not know rather than
offering an explanation you have not measured. That convention is why the trend in
`TEST_RESULTS.md` is still readable.

---

## Commit messages

Write a subject line that says **what was proven**, not just what was added, then a body that
explains the reasoning. Look at `git log` — the existing messages are the standard, and they
are deliberately substantial.

A good message states:

* what mechanic or card is now complete, and what is deliberately still partial;
* the measured assertion count, and confirmation that pre-existing assertions still pass
  unchanged;
* any rules decision made, with its confidence and its `R` number;
* any defect found, in the engine or the harness.

---

## Pull request expectations

Please include:

1. **What changed and why**, in prose.
2. **The rules basis** — the `RULES_SPEC.md` sections and `[S…]` sources involved, and the
   `CARD_RULINGS.md` entry for any non-obvious decision, with its confidence level.
3. **Test evidence**: the full-suite result before and after, as printed —
   `TOTAL: N passed, 0 failed (N assertions across M suite(s))`. State the new suite's own
   count, and confirm that **no pre-existing suite changed its count**. If one did, explain
   exactly why.
4. **Platform**, since only Windows is currently a validated environment.
5. **Anything you were unsure about.** A PR that flags its own weakest assumption is much
   easier to review than one that hides it.

Scope: one card, one mechanic gate, or one coherent fix per PR. Please do not mix a rules
change with a refactor — they need different kinds of review.

Every PR runs the headless suite in CI (`.github/workflows/tests.yml`). A red suite will not be
merged.

---

## Things that will get a change rejected

* **Copyrighted or ripped assets of any kind** — Master Duel rips, card images, official UI
  art, audio, or any proprietary game resource. This repository ships none, and will not start.
  Redistributing the official Konami rules documents is included in this: cite and hash them
  instead, as `Research/sources/README.md` does.
* **Weakening, retargeting or deleting an existing assertion** to make new behaviour pass.
* **An undocumented ruling decision** where the official text is ambiguous.
* **Presenting a community source as official.**
* **Runtime interpretation of card text** — a text parser, or an LLM reading card text during a
  duel. Cards are compiled, reviewed code. Using an LLM as a *research or authoring aid* is
  fine; shipping one inside the resolution path is not.
* **Presentation logic in the engine layer**, or any engine code that decides legality
  somewhere other than the rules layer.
* **A card that "loads" but whose clauses are not all implemented and tested.** The matrix
  counts implemented and tested separately for exactly this reason.
* **Committing generated or local-only files**: `.godot/`, build output, test scratch output,
  card art, or anything embedding an absolute local path.

---

## Traps that cost previous contributors time

Collected from `PROJECT_STATE.md`. Reading these will save you a cycle.

* **Run `--import` as its own command after adding any `class_name`.** Chaining it into the
  test run is not enough: the parse check still reads the stale
  `.godot/global_script_class_cache.cfg` and fails with `Identifier "<YourNewClass>" not
  declared in the current scope` — which looks like a syntax error in a file that is fine.
* **Never use `:=` where the right-hand side is a `Variant`** — an untyped `Array` element such
  as `some_def.effects[0]`, or a function declared `-> Variant`. It is a hard compile error, and
  a failed compile takes the whole dependent class down with it. It also bites *transitively*.
* **A GDScript single-line lambda ends at the newline.** A wrapped lambda body inside a call
  argument needs an explicit `\` continuation, or you get `Expected closing ")" after call
  arguments` **with no line number**.
* **`EffectPrimitives.choose_n()` / `choose_one()` do not ask when candidates == required** —
  there is nothing to decide. A test asserting on the offered options must set up **more**
  candidates than the clause consumes, or the prompt never happens.
* **`ScriptedController`'s default answer is "the first `min_count` options"**, which is rarely
  the card your test means. `queue_for(...)` it explicitly, then assert `controller.errors == []`.
* **`get_legal_actions(pid)` returns nothing unless the engine is open *and* `pid` is the turn
  player.** An interferer meant to fire in an open game state must belong to the turn player; a
  Chain Link 2 goes through `get_legal_responses()` instead. Neither mistake fails loudly.
* **`GameState.destroy()` correctly refuses a card that is not on the field**, so
  `interferer(..., "destroy")` cannot move a card out of the hand. Use the `"send_to_gy"` mode.
* **Continuous effects are recomputed at engine timing points**, not when a test arranges the
  board. A baseline assertion taken straight after `TestFixtures.give_*` reads the un-recomputed
  value. Run an explicit `ContinuousEffects.new(state).recompute()` first, or take an engine
  action.
* **The engine does not pause when nobody holds a legal response.** It auto-passes and resolves
  the whole attack, chain or Damage Step inside one `submit_action()`. To observe an intermediate
  state, read the event log or give a player a genuine fast effect.
* **A phase change is a declaration first.** After `submit_action(ENTER_BATTLE_PHASE)` the phase
  has not changed yet if the opponent holds a response.
* **`TestFixtures.activate_card()` finds an `ACTIVATE_CARD` action only.** An effect activated
  from a card already on the field is an `ACTIVATE_EFFECT` action — use
  `TestFixtures.activate_effect()`.

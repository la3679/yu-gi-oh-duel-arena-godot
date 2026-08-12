# PROJECT_STATE — Duel Arena

> Persistent resume file. A new Claude Code session should read **this file first**,
> then read only the targeted files named in §8. Do **not** recursively reread the repository.

**Last updated:** 2026-08-12
**Current phase:** Phase 4 — Core rules engine. Phases 0–3 complete. Phase 4b-1/4b-2/4b-3
complete and tested. **Phase 4c is now complete: the generic-engine gate (Gate B) is
MET.** Special Summon execution, the DuelLog replay payload, piercing damage, the
player-level continuous restriction path and both open rules questions are all resolved
and tested.
**Overall status:** IN PROGRESS — **not** acceptance-complete. **Phase 5 (the 77 cards)
may now begin.**
**HEAD at checkpoint:** `9b12742` (the Phase 4c commit follows it)
**Measured suite at checkpoint:** **630 passed / 0 failed** across **13 suites**;
SmokeCheck **PASS**.

---

## 1. Fixed project facts

| Item | Value |
|---|---|
| Project root | `C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame` |
| Authoritative read-only input | `C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles` |
| Master specification | `PlayerFiles\CLAUDE_DUEL_ARENA_MASTER_PROMPT_v3_GRAPHIFY.md` (3188 lines, read in full) |
| Deck 1 | Blue-Eyes Dragon Guard — 40 Main Deck cards, 39 unique names |
| Deck 2 | Fairy-Tail Tribute Guard — 40 Main Deck cards, 39 unique names |
| Shared card | `Shining Angel` (1 copy in each deck) |
| **Playable deck slots** | **80** |
| **Unique playable cards** | **77** |
| Verified pool composition | 9 Normal Monsters, 28 Effect Monsters, 13 Normal Spells, 3 Quick-Play Spells, 1 Continuous Spell, 1 Field Spell, 15 Normal Traps, 6 Continuous Traps, 1 Counter Trap |
| Extra Deck / Link / Pendulum | none in either deck |
| Quantity-2 cards | `Mirage Dragon` (D1), `Metaphys Armed Dragon` (D2) |

The 251-image identification pass is **complete and must not be redone**.

---

## 2. Environment

### Godot — INSTALLED THIS PROJECT

| Field | Value |
|---|---|
| Already installed beforehand | **NO** |
| Install method | `winget install --id GodotEngine.GodotEngine --version 4.7.1 --source winget --scope user` |
| Publisher verified | Godot Engine, `https://godotengine.org/` |
| Installer source verified | `https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_win64.exe.zip` |
| Installer SHA256 (winget-verified) | `c7a289051eaefb460b0106b60e9cd5bee0ef55fd102dcb2bed1eb356cf3d90a1` |
| **Verified version** | `4.7.1.stable.official.a13da4feb` |
| **Executable path** | `C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe` |
| PATH alias | `godot` (needs a fresh shell); scripts use the absolute path |
| Headless verified | YES |
| Admin required / security disabled | NO / NONE |
| Language | GDScript |

**Canonical commands**

```bash
# import / parse check
"C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --headless --path "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame" --import

# run a headless script
"C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --headless --path "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame" --script res://Scripts/tests/SmokeCheck.gd
```

### Graphify — INSTALLED, BUT DOES NOT SUPPORT GDSCRIPT

| Field | Value |
|---|---|
| Identified official tool | **Graphify** — codebase → queryable knowledge graph for AI coding agents |
| PyPI distribution | `graphifyy` (double `y`) — command `graphify` |
| Owner / publisher | Graphify Labs — author Safi Shamsi (`captainturbo`) |
| Official source URL | https://github.com/Graphify-Labs/graphify |
| Official site / PyPI | https://graphify.com · https://pypi.org/project/graphifyy/ |
| License | Apache-2.0 |
| Already installed | **YES** (0.9.25) — upgraded via `pip install --upgrade graphifyy` |
| **Verified version** | **0.9.41** (`graphify --version`) |
| Command path | `C:\Users\lovea\.pyenv\pyenv-win\shims\graphify.bat` |
| **Local-only** | **YES** — indexed with `--code-only`, local tree-sitter AST, no API key, **nothing uploaded** |
| Repository indexed | **YES** |
| Indexed root | `C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame` |
| Index result | 37 nodes, 75 edges, from 6 Python tool files |
| Exclusions | `.graphifyignore` at project root |
| Last index refresh | 2026-08-12 |
| Runtime dependency of the game | **NO — development tool only** |

**Index / refresh command**

```bash
graphify extract "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame" --code-only --no-cluster
```

#### KNOWN ISSUE — Graphify does not index GDScript

Graphify supports **36 tree-sitter grammars**; **`.gd` is not among them**
(verified against the official repository's documented extension list, 2026-08-12).

Observed directly: the extract run classified `9` files as code (6 Python tools + 3 JSON data
files) and placed all `.gd` files in the "not classified (no supported extension or shebang)"
bucket. The resulting graph contains **zero** GDScript symbols — `graphify god-nodes` returns
only Python functions from `Tools/`.

**Consequence and fallback (master prompt §2A "FAILURE / FALLBACK"):**
* Graphify is **retained** and is genuinely useful for the `Tools/` Python research pipeline.
* For the GDScript engine — which is the bulk of the codebase — Graphify provides no
  navigation value, so targeted native search (Grep/Glob on `Scripts/`, `Tests/`) is used
  instead, guided by the architecture map in §8 of this file.
* This is **not** a correctness dependency. Nothing about rules or testing is weakened.
* Graphify is **not** added to the game runtime.

Useful Graphify commands **for the Python tooling only**:

```bash
graphify query "how is the card database built"
graphify affected "parse_detail" --depth 2
graphify god-nodes --top 10
```

### Other tooling

| Tool | Version |
|---|---|
| winget | v1.29.280 |
| git | 2.42.0.windows.2 (repo initialised in `DuelArenaGame`) |
| Python | 3.11.9 (pyenv-win) |
| Node / npm | v22.19.0 / 11.6.0 |
| pypdf | 6.14.2 (used to read the official rulebook PDF) |

### Connectivity — all verified working 2026-08-12

| Check | Result |
|---|---|
| Internet access | WORKING |
| Official Rulebook v10 PDF | REACHABLE — downloaded and hashed |
| Official Fast Effect Timing chart | REACHABLE — downloaded and hashed |
| Official Damage Step rules page | REACHABLE (EU portal; the `/en/gameplay/damage_step/` URL printed in the rulebook now 404s) |
| Official Konami Card Database | REACHABLE — **all 77 cards fetched individually** |

---

## 3. Research status — Gate A

| Requirement | Status |
|---|---|
| Current rules sources recorded | **DONE** — `Research/RULES_SOURCES.md` (S1–S4, with URLs, dates, SHA-256) |
| Fast Effect Timing source recorded | **DONE** — official chart cached + transcribed in `RULES_SPEC.md §3` |
| Every unique card text verified | **DONE — 77 / 77**, 0 unmatched, 0 empty |
| Unresolved rulings documented | **DONE** — 21 cards flagged R1–R20 in `Research/CARD_RULINGS.md §4` |

**Gate A: MET.**

Key research outputs:
* `Research/RULES_SOURCES.md` — source register with hashes
* `Research/RULES_SPEC.md` — the implementable rules contract (turn flow, Fast Effect Timing
  state machine A–E, chains, Spell Speed, summoning, battle, Damage Step sub-steps + the
  §7.2 activation restriction, movement semantics, PSCT mapping, once-per-turn model,
  hidden information, victory)
* `Research/CARD_RULINGS.md` — 23 official-vs-saved text discrepancies resolved, the
  mechanics the V1 pool actually requires, and 21 flagged card-specific rulings
* `Research/sources/` — cached official rulebook PDF + Fast Effect Timing chart

### Notable research findings
1. **23 of 77** saved card texts disagreed with the official database; all resolved
   in favour of the official source. Substantive errata: `Straight Flush` (now PSCT
   condition-based), `Aussa` / `Wynn` (now **target**), `Eria` ("face-up" removed),
   `Hieratic Dragon of Tefnuit` ("this way" restriction), `Champion's Vigilance` ("monster(s)").
2. `Vampiric Koala` was **missing** from `official_card_data.json` (which had an unrelated
   `Vampire Koala` key). Confirmed official (cid 8858); passcode 01371589 backfilled.
3. `Phoenix Wing Wind Blast` is a **Normal Trap** per the official database — confirmed by
   the deck CSV and the physical identification. (Commonly misremembered as a Quick-Play Spell.)
4. **Counters ARE required** by the V1 pool — Spell Counter (`Apprentice Magician`) and
   Balloon Counter (`Wonder Balloons`). `RULES_SPEC.md §14` was corrected accordingly.

---

## 4. Build/verification status

Last verified run (2026-08-12, at commit `9b12742` plus the Phase 4c work):

```
powershell -File Tools\run_tests.ps1 SmokeCheck  -> SMOKE CHECK: PASS
powershell -File Tools\run_tests.ps1 RunTests
  ChainTests:          27/27 passed
  TimingTests:         37/37 passed
  TurnFlowTests:       40/40 passed
  SummonTests:         45/45 passed
  SpellTrapTests:      27/27 passed
  BattleTests:         72/72 passed
  DamageStepTests:     86/86 passed
  ContinuousTests:     52/52 passed
  CounterTests:        44/44 passed
  HiddenInfoTests:     76/76 passed
  SpecialSummonTests:  54/54 passed
  RulesQuestionTests:  37/37 passed
  ReplayTests:         33/33 passed
  TOTAL: 630 passed, 0 failed (630 assertions across 13 suites)
  RESULT: PASS
```

**630 / 630 passing. These numbers were actually produced by the command above; they are
not estimates.** All 506 earlier assertions still pass unchanged — none was weakened,
retargeted or deleted. Per-suite detail and the honest not-yet-covered list live in
`Reports/TEST_RESULTS.md`.

SmokeCheck remains a load/determinism check, not part of the rules suite count.

### Use `Tools/run_tests.ps1`, not the raw command

Two things it handles that cost real time to discover:

1. Godot writes heavily to stderr (every `push_error` prints a full GDScript backtrace).
   Piping stdout+stderr through PowerShell can block on a full pipe and appear to hang.
   The runner redirects to files and prints them afterwards.
2. A suite that fails to **compile** makes `RunTests._initialize()` throw before it can
   call `quit()`, so the headless SceneTree runs forever at near-zero CPU. The runner does
   a `--check-only` parse pass first, turning that hang into an immediate readable error.

### Defects the Phase 4c tests caught

1. **`SummonRules.begin_special_summon()` was unreachable from the engine.** It compiled
   but no engine path called it, so Special Summoning was not a capability the engine
   actually had. Two paths now exist: `DuelEngine.special_summon()` for the
   resolution-time case, and the `SPECIAL_SUMMON_PROCEDURE` box A1 action for the
   open-game-state case, which opens a real declaration window.
2. **The replay payload could not reproduce a duel.** It carried the Deck *names* but not
   the Deck *contents*; the seed only says how a **known** Deck is shuffled. Fixed with
   `DuelLog.deck_lists` (pre-shuffle order) plus `DuelAction.from_dict()`.
3. **Most player decisions were never recorded.** Only target selection reached the log;
   optional-trigger consent, trigger ordering, the hand-size discard and every
   mid-resolution `EffectContext.ask()` were lost. `TriggerCollector`, `TurnFlow` and
   `EffectContext` now record through the same log.
4. **A Continuous Spell/Trap applied its continuous effect from activation** rather than
   from resolution, which would let it affect Chain Links resolving above it.
5. **`ContinuousEffects.restrict_player()` was consumed by no rules path.**
6. **Piercing was wrongly recorded as unexercised by the V1 pool** — `Rider of the Storm
   Winds` grants it.

### Defects the Phase 4b-3 tests caught

1. **Removing the attack TARGET cancelled the attack instead of causing a Replay.**
   `DuelEngine._advance_battle()` checked `BattleRules.attack_still_valid()` — which
   covered the attacker *and* the target — before `replay_required()`. `RULES_SPEC.md §6.2`
   [S1 p.39] is explicit that a removed target **is** a Replay. Split into
   `attacker_still_valid()` / `target_still_valid()`, Replay check first.
2. **`get_visible_state()` ignored `revealed_to` for the opponent's hand.** The hand was
   mapped straight to `_hidden_card_stub()`, bypassing the `revealed_to` check that
   `_visible_card()` already implements, so a legally revealed card stayed invisible.
3. **Two harness gaps:** `TestFixtures.end_turn()` and `advance_to_phase()` both looked
   only for `END_PHASE`, which the Battle Phase does not offer, so any duel that reached
   the Battle Phase silently failed to advance.

### Defects earlier milestones caught (still relevant)

1. **`RunTests.gd` reported `RESULT: PASS` for a suite that ran zero assertions.** A
   zero-assertion suite is now an explicit failure. Any future session that adds a suite
   inherits this guard — **do not remove it**.
2. **`:=` type-inference compile failures.** **GDScript cannot infer through a `Variant`**
   — an element of an untyped `Array`, or the return of any function declared
   `-> Variant`. This bit again in all three new suites. Annotate explicitly. Always
   re-run `--import` after adding a `class_name` script.
3. **`project.godot` pointed `run/main_scene` at `res://Scenes/ui/Boot.tscn`**, which does
   not exist yet, so every headless run logged a resource-load error. The setting is
   commented out until the Phase 7 UI exists — restore it then.

### Known harness issues (not rules defects)

* The run reports `~20000 ObjectDB instances were leaked at exit`, up from ~7265 simply
  because the suite now builds far more duels. These are RefCounted reference cycles
  between `GameState`, the `DuelLog` signal connection and test closures. It changes no
  rules outcome and fails nothing, but it must be cleaned up before the UI keeps a single
  duel alive for a long session.
* The run prints **two** `SCRIPT ERROR` lines from `push_error`. Both are **intentional**:
  `ChainTests` requires a missing `resolve()` to fail loudly, and `ContinuousTests`
  requires an unknown restriction flag to be rejected rather than silently written.
* A GDScript single-line lambda ends at the newline. A wrapped lambda body inside a call
  argument needs an explicit `\` continuation, or it is a parse error reported with **no
  line number**.

---

## 5. Phase progress

| Phase | Description | Status |
|---|---|---|
| 0 | Inspect data, install/verify Godot + Graphify | **COMPLETE** |
| 1 | Authoritative TCG rules research | **COMPLETE** |
| 2 | Per-card official text + rulings research (77 cards) | **COMPLETE** |
| 3 | Architecture / scaffolding + Graphify index | **COMPLETE** |
| 4 | Core rules engine | **COMPLETE** — 4b-1/4b-2/4b-3/4c done+tested |
| 5 | Card effect library (77 cards) | NOT STARTED — **unblocked** |
| 6 | Automated tests | NOT STARTED |
| 7 | Basic playable UI | NOT STARTED |
| 8 | Arena / presentation | NOT STARTED |
| 9 | Local privacy UX | NOT STARTED |
| 10 | Asset polish | NOT STARTED |
| 11 | Full acceptance | NOT STARTED |

| Gate | Status |
|---|---|
| A — Research complete | **MET** |
| B — Core engine complete | **MET** — every subsystem in §6a is DONE+TESTED; 630 assertions, 0 failures |
| C — Card library complete | NOT MET |
| D — Playable prototype | NOT MET |
| E — Presentation complete | NOT MET |
| F — Final acceptance | NOT MET |

---

## 6. Files that exist

```
DuelArenaGame/
├── project.godot                      Godot 4.7 project (config_version=5)
├── PROJECT_STATE.md                   this file
├── .gitignore  .graphifyignore
├── Research/
│   ├── RULES_SOURCES.md               source register (S1-S4) + hashes
│   ├── RULES_SPEC.md                  implementable rules contract
│   ├── CARD_RULINGS.md                card research, discrepancies, R1-R20
│   └── sources/
│       ├── SD_RuleBook_EN_10.pdf                  official Rulebook v10
│       └── FastEffectTiming_Flowchart_EN-US.jpg   official chart
├── Data/
│   ├── cards/cards.json               77 verified canonical card definitions
│   ├── decks/deck1.json, deck2.json   40 cards each
│   └── generated/
│       ├── card_pool.json             deck enumeration
│       ├── konami_cards.json          official per-card data + source URLs
│       └── konami_raw/*.html          cached evidence (git-ignored)
├── Scripts/
│   ├── engine/
│   │   ├── Enums.gd                   zones, phases, damage sub-steps, move reasons,
│   │   │                              spell speeds, damage-step permissions + classifiers
│   │   ├── Rng.gd                     deterministic seeded RNG (Fisher-Yates)
│   │   ├── CardDef.gd                 immutable canonical definition
│   │   ├── CardInstance.gd            per-copy runtime state, stats, counters, usage
│   │   ├── GameEvent.gd               semantic event vocabulary (master prompt 63)
│   │   ├── PlayerState.gd             per-player zones, LP, allowances, named OPT
│   │   ├── GameState.gd               authoritative state, move_card, counters,
│   │   │                              position changes, hidden-info filter
│   │   ├── DuelAction.gd              one validated action + its candidate sets
│   │   ├── DecisionRequest.gd         structured prompt + answer validation
│   │   ├── PlayerController.gd        abstraction (local human / future CPU / network)
│   │   ├── ScriptedController.gd      deterministic controller for the test suite
│   │   ├── DuelLog.gd                 action / decision / event log + replay payload
│   │   └── DuelEngine.gd              Fast Effect Timing machine + legal-action API
│   ├── rules/
│   │   ├── ChainLink.gd               one chain link
│   │   ├── ChainManager.gd            chain build / negate / reverse resolve
│   │   ├── ActivationRules.gd         the single activation legality gate
│   │   ├── TriggerCollector.gd        trigger collection + simultaneous ordering
│   │   ├── SummonRules.gd             summons, tributes, flip, position changes
│   │   ├── TurnFlow.gd                phase order, draws, hand size, turn transition
│   │   ├── BattleRules.gd             battle + Damage Step (tested)
│   │   └── ContinuousEffects.gd       state-derived modifiers (tested)
│   └── tests/
│       ├── SmokeCheck.gd              headless load/determinism check
│       ├── TestCase.gd                assertion harness
│       └── RunTests.gd                entry point; a 0-assertion suite is a FAILURE
├── Tests/
│   ├── support/TestFixtures.gd        synthetic cards, duel builder, engine drivers
│   └── rules/
│       ├── ChainTests.gd        27 assertions
│       ├── TimingTests.gd       37 assertions
│       ├── TurnFlowTests.gd     40 assertions
│       ├── SummonTests.gd       45 assertions
│       ├── SpellTrapTests.gd    27 assertions
│       ├── BattleTests.gd       72 assertions
│       ├── DamageStepTests.gd   86 assertions
│       ├── ContinuousTests.gd   52 assertions
│       ├── CounterTests.gd      44 assertions
│       ├── HiddenInfoTests.gd   76 assertions
│       ├── SpecialSummonTests.gd  54 assertions
│       ├── RulesQuestionTests.gd  37 assertions
│       └── ReplayTests.gd         33 assertions
├── Tools/                             Python research + data pipeline (dev only)
│   ├── run_tests.ps1                  headless test runner (parse-check + no pipe stall)
│   ├── enumerate_cards.py             deck CSVs -> card_pool.json
│   ├── fetch_official_cards.py        official Konami DB -> konami_cards.json
│   ├── diff_card_text.py              official vs saved text diff
│   ├── dump_official_text.py          human-readable card text dump
│   ├── build_card_db.py               -> Data/cards/cards.json + deck lists
│   └── build_matrix.py                -> Reports/CARD_IMPLEMENTATION_MATRIX.csv
├── Reports/CARD_IMPLEMENTATION_MATRIX.csv   77 rows, text verified, 0 implemented
└── graphify-out/graph.json            dev index (git-ignored)
```

Empty scaffold directories also exist per master prompt §1 (`Scenes/`, `Assets/`, `Tests/`,
`Scripts/rules|cards|presentation|ui|tools`, `build/`).

**Not yet written:** `README.md`, `ARCHITECTURE.md`, `KNOWN_LIMITATIONS.md`,
`Research/RULES_COMPLIANCE_MATRIX.md`, `Reports/RULES_AUDIT.md`,
`Reports/ASSET_PROVENANCE.md`, `Reports/FINAL_ACCEPTANCE.md`. These are deliberately deferred
until they can contain real results rather than placeholders.

---

## 6a. Phase 4b subsystem status — read this before touching the engine

Legend: **DONE+TESTED** = implemented and covered by passing assertions ·
**UNVERIFIED** = code exists, compiles, but **no test exercises it** ·
**NOT STARTED**.

| Subsystem | Status | Where | Evidence |
|---|---|---|---|
| Fast Effect Timing state machine (boxes A/B/C/D/E) | **DONE+TESTED** | `Scripts/engine/DuelEngine.gd` `_advance()` | TimingTests |
| `DuelEngine` legal-action API (`get_legal_actions`, `get_legal_responses`, `submit_action`, `get_pending_decision`, `get_visible_state`, `get_public_log`) | **DONE+TESTED** | `Scripts/engine/DuelEngine.gd` | all 4 new suites drive the engine only through this API |
| Shared activation legality gate | **DONE+TESTED** | `Scripts/rules/ActivationRules.gd` | SpellTrapTests, TimingTests |
| Trigger collection integrated with `ChainManager` | **DONE+TESTED** | `Scripts/rules/TriggerCollector.gd` | TimingTests |
| Mandatory Trigger Effects | **DONE+TESTED** | ditto | TimingTests "mandatory trigger is not asked" |
| Optional Trigger Effects (explicit consent, never auto-fired) | **DONE+TESTED** | ditto | TimingTests "optional trigger requires consent" |
| Simultaneous trigger ordering (TP mandatory → opp mandatory → TP optional → opp optional, [S1 p.51]) | **DONE+TESTED** | `TriggerCollector.order_activations()` | TimingTests group-order + within-group-order |
| Fast Effect response windows (Full Response Mode) | **DONE+TESTED** | `DuelEngine.get_legal_responses()` | TimingTests, SpellTrapTests |
| Quick Effects | **DONE+TESTED** | per-effect Spell Speed on `EffectDef` | TimingTests |
| Spell Speed response legality | **DONE+TESTED** | `ChainManager.can_respond_with_spell_speed()` | ChainTests, TimingTests |
| Consecutive-pass behaviour and Chain closure | **DONE+TESTED** | `DuelEngine._on_pass()` / `_advance()` | TimingTests "two consecutive passes" |
| Reverse Chain resolution | **DONE+TESTED** | `ChainManager.resolve_chain()` | ChainTests, TimingTests |
| Events during resolution deferred to the next timing point | **DONE+TESTED** | `DuelEngine._resolve_current_chain()` (event-slice, not a side list) | TimingTests "triggers during resolution wait" |
| Turn / phase progression | **DONE+TESTED** | `Scripts/rules/TurnFlow.gd` | TurnFlowTests |
| Normal Summon / Normal Set / Tribute Summon / Tribute Set | **DONE+TESTED** | `Scripts/rules/SummonRules.gd` | SummonTests |
| Summon declaration → response window → complete/abort (summon negation) | **DONE+TESTED** | `SummonRules.begin_*` + `DuelEngine._close_window()` | TimingTests "summon negation" |
| Flip Summon | **DONE+TESTED** | `SummonRules.flip_summon()` | SummonTests |
| Manual battle position changes (3 restrictions) | **DONE+TESTED** | `SummonRules.can_change_position()` | SummonTests |
| Spell/Trap framework + Set-turn restrictions | **DONE+TESTED** | `ActivationRules.set_turn_ok()` / `card_activation_timing_ok()` | SpellTrapTests |
| Counter engine (place/remove/read/clear + events) | **DONE+TESTED** | `GameState.place_counters()` / `remove_counters()` | CounterTests |
| **Battle Phase / attack declaration / replay** | **DONE+TESTED** | `Scripts/rules/BattleRules.gd` | BattleTests |
| **Damage Step (5 sub-steps)** | **DONE+TESTED** | `BattleRules` + `DuelEngine._advance_battle()` | DamageStepTests |
| **Damage Step activation restriction (§7.2)** | **DONE+TESTED** | `ActivationRules.damage_step_ok()` | DamageStepTests (rule table + live Damage Step) |
| **Damage calculation (all 6 rows of §7.4 + direct)** | **DONE+TESTED** | `BattleRules.step_damage_calculation()` | DamageStepTests |
| **Battle destruction semantics** | **DONE+TESTED** | `GameState.move_card()` + `MoveReason` | DamageStepTests |
| **Continuous effects** | **DONE+TESTED** | `Scripts/rules/ContinuousEffects.gd` | ContinuousTests |
| **Hidden information filtering** | **DONE+TESTED** | `GameState.get_visible_state()` / `get_log_for()` | HiddenInfoTests |
| **Owner vs controller** | **DONE+TESTED** | `GameState.move_card()` owner-bound zones | HiddenInfoTests |
| Victory by 0 LP from battle damage | **DONE+TESTED** | `GameState.check_life_point_loss()` | DamageStepTests |
| **Special Summon (resolution-time)** | **DONE+TESTED** | `DuelEngine.special_summon()` → `SummonRules.begin_special_summon()` + `complete_summon()` | SpecialSummonTests |
| **Special Summon (summoning procedure)** | **DONE+TESTED** | `Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE`, `ActivationRules.can_use_summon_procedure()` | SpecialSummonTests |
| **Special Summon negation** | **DONE+TESTED** | `_pending_summon` + `negate_pending_summon()` | SpecialSummonTests |
| **Piercing battle damage** | **DONE+TESTED** — required after all by `Rider of the Storm Winds` | `BattleRules.step_damage_calculation()` | RulesQuestionTests |
| **Player-level continuous restrictions** | **DONE+TESTED** | `ContinuousEffects.restrict_player()` consumed by `TurnFlow.can_enter_battle_phase()` | RulesQuestionTests |
| `PlayerController` abstraction | **DONE+TESTED** (`ScriptedController`); no UI implementation yet | `Scripts/engine/PlayerController.gd` | used by every suite |
| **Duel log / replay payload** | **DONE+TESTED** — a payload now round-trips to an identical event stream | `Scripts/engine/DuelLog.gd`, `DuelAction.from_dict()` | ReplayTests |

### Design decisions a future session must not silently reverse

1. **Actions carry their own choices.** Targets, Tributes, the attack target and the
   summon position are fields of `DuelAction`, not mid-action prompts. The engine
   publishes the candidate sets on the offered action and re-validates the submitted
   selection in `_choices_valid()`. This is what keeps the engine fully synchronous and
   deterministic, and it matches RULES_SPEC §10 (targets and costs are fixed at
   activation).
2. **`PlayerController.decide()` is synchronous.** It answers the questions the engine
   raises at its own boundaries (optional trigger yes/no, trigger ordering, hand-size
   discard, mid-resolution card choices). `get_pending_decision()` reports *who must act
   and what they may do*; the answer comes back through `submit_action()`.
   **Open item for Phase 7:** the interactive UI needs a controller that bridges
   `decide()` to on-screen prompts. A coroutine-backed controller is the intended
   approach; nothing in the rules layer needs to change for it.
3. **Two `END_PHASE` actions are required to leave the End Phase.** The first performs
   the hand-size discard, the second ends the turn. This is deliberate: the discard
   happens at the *end* of the End Phase [S1 p.40], so anything it triggers must still
   resolve during that End Phase rather than on the next player's turn. The action
   labels distinguish them ("Finish the End Phase" / "End your turn").
4. **A negated Summon is possible because the monster waits in `Zone.IN_TRANSIT`.**
   `Champion's Vigilance` is in the V1 pool ("when a monster(s) would be Summoned:
   Negate the Summon"), so a monster must never be placed in a Monster Zone before its
   declaration window closes. Card effects reach this through
   `EffectContext.engine.negate_pending_summon()`.
5. **`DamageStepPermission.MANDATORY_TRIGGER` means the rules-mandated *timing*, not
   optionality.** `Shining Angel`'s destroyed-by-battle effect is optional yet its window
   is inside the Damage Step. RULES_SPEC §7.2 carries a clarification note.
6. **Continuous effects are recomputed from scratch** at the top of every `_advance()`
   iteration and are tagged (`duration = "continuous"`, `ContinuousEffects.RESTRICTION_FLAGS`)
   so they can be wiped and rebuilt. Nothing else may write those flags.
   *Proven by ContinuousTests: five recomputes give the same value as one, and an
   unsourced restriction flag does not survive a recompute.*
7. **A removed attack TARGET is a Replay, not a cancelled attack.** Only the ATTACKER
   leaving the field cancels an attack. `attacker_still_valid()` and
   `target_still_valid()` are deliberately separate, and `_advance_battle()` runs the
   Replay check **before** the target check. Merging them back re-introduces the defect
   Phase 4b-3 fixed. [S1 p.39, RULES_SPEC.md §6.2]
8. **`CardInstance.revealed_to` is honoured everywhere a hidden card can be seen**,
   including the opponent's hand, which goes through `_visible_card()` rather than
   straight to `_hidden_card_stub()`.
9. **There are two Special Summon paths and they are not interchangeable.**
   `DuelEngine.special_summon()` is the RESOLUTION-time path: it declares and completes in
   one step, because no new Chain starts mid-resolution. The
   `SPECIAL_SUMMON_PROCEDURE` action is the OPEN-game-state path and opens a real
   declaration window, because there is no activation for a negation card to answer
   instead. Collapsing them either loses summon negation or invents a mid-resolution
   Chain. `RULES_SPEC.md §5.5`.
10. **A Continuous Spell/Trap's continuous effect starts on RESOLUTION, not activation.**
    `ContinuousEffects.activation_unresolved()` is what enforces it. `RULES_SPEC.md §8.1`.
11. **`revealed_to` is cleared by a SHUFFLE, not by the Deck.** A card placed on top or
    bottom without a shuffle keeps it — its position is still known. `RULES_SPEC.md §12.1`.
12. **The two Battle Phase restrictions are deliberately separate.**
    `skip_battle_phase_this_turn` is turn-scoped and must survive a continuous recompute;
    `continuous:cannot_conduct_battle_phase` is state-derived and must not. Neither may be
    expressed in terms of the other.
13. **Every question put to a player is a duel input and must be logged.**
    `TriggerCollector`, `TurnFlow` and `EffectContext.ask()` all record through
    `DuelLog.record_decision()`. A new decision point that skips this silently breaks
    replay, and `ReplayTests` will catch it (it compares the recorded count against what
    the controllers were actually asked).

---

## 7. Blockers

None.

### Phase 4 work — all closed (honest list)

Everything previously listed here is now done and tested; see §6a and
`Reports/TEST_RESULTS.md`. For the record, the four open rules questions were resolved as:

* **Continuous Spell/Trap start timing** → on RESOLUTION of its own activation.
  `RULES_SPEC.md §8.1` [S1 p.17, p.18 with p.44–47]. The section states honestly that no
  single official sentence gives the start point verbatim.
* **`revealed_to` and the Deck** → cleared by a SHUFFLE; kept for an unshuffled
  top/bottom placement. `RULES_SPEC.md §12.1` [S1 p.5, p.28].
* **`ContinuousEffects.restrict_player()`** → consumed by
  `TurnFlow.can_enter_battle_phase()`, alongside the separate turn-scoped key.
* **Piercing** → the earlier claim that no V1 card requires it was wrong. `Rider of the
  Storm Winds` grants it; both branches are tested.

### Genuinely still open (carried into Phase 5, not hidden)

* **No card in `Data/cards/cards.json` has an `EffectDef` yet.** The engine has been
  exercised only against synthetic cards from `Tests/support/TestFixtures.gd`. That was
  intentional for Phase 4 and is exactly what Phase 5 changes.
* **Equip mechanics have no assertions.** `GameState._unequip_all()` runs but nothing
  tests it. `Rider of the Storm Winds` and `Castle of Dragon Souls` will force this.
* **Simultaneous-LP-zero (a draw) is unexercised.**
* **GY-activated effects** beyond the destroyed-by-battle shape are untested.
* **~24500 leaked ObjectDB instances at exit** — RefCounted cycles between `GameState`,
  the `DuelLog` signal and test closures. Harmless to rules outcomes, but it must be
  cleaned up before the UI keeps one duel alive for a long session.

---

## 8. Next step and architecture map for resumption

### How to resume in one paragraph

**Phase 4 is complete and Gate B is MET.** The generic rules engine is tested end to end:
Fast Effect Timing, the `DuelEngine` legal-action API, trigger collection and ordering,
Normal/Tribute/Flip **and Special** Summons (including summon negation on both paths),
turn/phase flow, the Spell/Trap framework, the Battle Phase, the Damage Step and its
activation restriction, damage calculation **including piercing**, battle destruction
semantics, continuous effects (with the correct resolution-time start), the counter engine,
hidden-information filtering and the **DuelLog replay payload** all pass — **630 assertions
across 13 suites, 0 failures**, SmokeCheck PASS. Read §6a for per-subsystem status and the
**thirteen** design decisions that must not be reversed, and §7 for what is genuinely still
open. Do **not** re-read the whole repository, re-run research, or re-derive rules.

### Immediately next — Phase 5, the 77 card implementations

There is no remaining generic-engine prerequisite. Cards go in
`Scripts/cards/registry/<CardName>.gd`, one file per card, each declaring
`const CARD_NAME := "..."` and one `EffectDef.new(...)` per official effect clause —
`Tools/build_matrix.py` reads those two markers, so
`Reports/CARD_IMPLEMENTATION_MATRIX.csv` can never over-report. A per-card test suite goes
alongside, and the matrix is updated only **after** a card passes its own tests.

Group the work by reusable mechanic rather than alphabetically, and build the shared
primitives before the cards that need them. From the pool scan (22 of 77 cards Special
Summon; 1 grants piercing):

1. **Primitives first** — search-and-Special-Summon from Deck/GY/hand; targeted
   destruction; ATK/DEF modification with a stated duration; banish; return-to-hand;
   draw; discard as cost; the equip mechanic (untested — `Rider of the Storm Winds`,
   `Castle of Dragon Souls`).
2. `Shining Angel` — in **both** decks, and the optional destroyed-by-battle
   Special Summon the engine is now proven to support end to end.
3. The 9 Normal Monsters (no effects; they validate the loader and the matrix).
4. The Special-Summon family, then the Spells/Traps by kind.
5. The counter cards (`Apprentice Magician`, `Wonder Balloons`).
6. The negation cards (`Champion's Vigilance`) last — they exercise the most machinery.

Maintain computed **X/77 implemented** and **X/77 tested** counts from the matrix, never by
hand. No placeholders, and never silently drop an effect clause: `ChainManager` deliberately
fails loudly on a missing `resolve()` (`ChainTests` proves it).

**Do not start presentation work** (3D arena, holographic monsters, summon/attack
animations, particles, audio, cinematic camera, UI polish). Those are Phases 7–10.

### Reminders that cost time — read before writing a test

* **Use `Tools/run_tests.ps1`**, not the raw Godot command. See §4 for the two reasons.
* Run `--import` after adding any `class_name` script, or Godot will not register it.
* Never use `:=` where the right-hand side is a `Variant` (an untyped `Array` element such
  as `some_def.effects[0]`, or a function declared `-> Variant` such as
  `TestFixtures.find_action()`). It is a hard compile error, and a failed compile takes
  the whole dependent class down with it.
* **A GDScript single-line lambda ends at the newline.** A wrapped lambda body inside a
  call argument needs an explicit `\` continuation, or you get
  `Expected closing ")" after call arguments` with **no line number**.
* Build tests through `Tests/support/TestFixtures.gd` — synthetic card builders,
  `new_duel()`, `battle_duel()` (turn 2, player 0 attacking, past the turn-1 Battle Phase
  prohibition), `pass_until_open()`, `advance_to_phase()`, `end_turn()`, `attack()`,
  `events_of()`, `count_events()`, `first_event_index()`. Do not hand-roll a duel.
* The engine does **not** pause when nobody holds a legal response: it auto-passes and
  resolves the whole attack, chain or Damage Step inside one `submit_action()`. To observe
  an intermediate state, either read the event log or give a player a fast effect so the
  window genuinely opens.
* A phase change is a box-E declaration first: after `submit_action(ENTER_BATTLE_PHASE)`
  the phase has **not** changed yet if the opponent holds a response.

**Where the rules live:** every subsystem above must cite `Research/RULES_SPEC.md` section
numbers in comments, and those trace to `RULES_SOURCES.md` S1–S4. Do not re-derive rules.

**Card implementation (Phase 5)** goes in `Scripts/cards/registry/<CardName>.gd`, one file
per card, each declaring `const CARD_NAME := "..."` and one `EffectDef.new(...)` per official
effect clause — `Tools/build_matrix.py` reads those two markers to compute the implementation
matrix, so the matrix can never over-report.

**Re-verify after any change:**

```bash
python Tools/build_card_db.py && python Tools/build_matrix.py
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 SmokeCheck
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests
```

**Do not:** re-run the 251-image identification; re-fetch the 77 card pages (they are cached
in `Data/generated/konami_raw/`); re-derive the rules from memory; or use Graphify for
GDScript navigation (unsupported — see §2).

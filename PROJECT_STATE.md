# PROJECT_STATE — Duel Arena

> Persistent resume file. A new Claude Code session should read **this file first**,
> then read only the targeted files named in §8. Do **not** recursively reread the repository.

**Last updated:** 2026-08-12
**Current phase:** Phase 4 — Core rules engine. Phases 0–3 complete. Phase 4b-1
(Fast Effect Timing, DuelEngine API, summons, Spell/Trap framework) complete **and
tested**. Phase 4b-2 (Battle Phase / Damage Step / continuous effects) committed as
**UNVERIFIED SCAFFOLDING — zero test coverage**.
**Overall status:** IN PROGRESS — **not** acceptance-complete
**HEAD at checkpoint:** `117ec30` (this documentation commit follows it)

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

Last verified run (2026-08-12, at commit `117ec30`):

```
godot --headless --path <project> --import                  -> clean, no parse errors
godot --headless --script res://Scripts/tests/SmokeCheck.gd -> SMOKE CHECK: PASS, exit 0
godot --headless --script res://Scripts/tests/RunTests.gd
  ChainTests:      27/27 passed
  TimingTests:     37/37 passed
  TurnFlowTests:   40/40 passed
  SummonTests:     45/45 passed
  SpellTrapTests:  27/27 passed
  TOTAL: 176 passed, 0 failed (176 assertions across 5 suites)
  RESULT: PASS, exit 0
```

**176 / 176 passing. This number was actually produced by the command above; it is not an
estimate.** Per-suite detail and the honest not-yet-covered list live in
`Reports/TEST_RESULTS.md`.

SmokeCheck remains a load/determinism check, not part of the rules suite count.

### Defects these tests caught this milestone

1. **`RunTests.gd` reported `RESULT: PASS` for a suite that ran zero assertions.** When
   `TimingTests` failed to compile, the runner printed `TimingTests: 0/0 passed` and
   exited 0. A zero-assertion suite is now an explicit failure. Any future session that
   adds a suite inherits this guard — do not remove it.
2. **Three more `:=` type-inference compile failures** (`TriggerCollector`, `DuelEngine`,
   `SummonRules`), same root cause as the Phase 4a defects. **GDScript cannot infer
   through a `Variant`** — that includes an element of an untyped `Array` and the return
   of any function declared `-> Variant`. Annotate explicitly. Always re-run `--import`
   after adding a `class_name` script.
3. **`project.godot` pointed `run/main_scene` at `res://Scenes/ui/Boot.tscn`**, which does
   not exist yet, so every headless run logged a resource-load error. The setting is
   commented out until the Phase 7 UI exists — restore it then.

### Known harness issue (not a rules defect)

The run reports `~7265 ObjectDB instances were leaked at exit`. These are RefCounted
reference cycles between `GameState`, the `DuelLog` signal connection and test closures.
It changes no rules outcome and fails nothing, but it must be cleaned up before the UI
keeps a single duel alive for a long session.

The run also prints one `SCRIPT ERROR` from `push_error`. That is **intentional** — it is
the loud failure the "unimplemented effect fails loudly" test asserts must occur.

---

## 5. Phase progress

| Phase | Description | Status |
|---|---|---|
| 0 | Inspect data, install/verify Godot + Graphify | **COMPLETE** |
| 1 | Authoritative TCG rules research | **COMPLETE** |
| 2 | Per-card official text + rulings research (77 cards) | **COMPLETE** |
| 3 | Architecture / scaffolding + Graphify index | **COMPLETE** |
| 4 | Core rules engine | **IN PROGRESS** — 4b-1 done+tested; 4b-2 untested |
| 5 | Card effect library (77 cards) | NOT STARTED |
| 6 | Automated tests | NOT STARTED |
| 7 | Basic playable UI | NOT STARTED |
| 8 | Arena / presentation | NOT STARTED |
| 9 | Local privacy UX | NOT STARTED |
| 10 | Asset polish | NOT STARTED |
| 11 | Full acceptance | NOT STARTED |

| Gate | Status |
|---|---|
| A — Research complete | **MET** |
| B — Core engine complete | NOT MET |
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
│   │   ├── BattleRules.gd             UNVERIFIED — battle + Damage Step
│   │   └── ContinuousEffects.gd       UNVERIFIED — state-derived modifiers
│   └── tests/
│       ├── SmokeCheck.gd              headless load/determinism check
│       ├── TestCase.gd                assertion harness
│       └── RunTests.gd                entry point; a 0-assertion suite is a FAILURE
├── Tests/
│   ├── support/TestFixtures.gd        synthetic cards, duel builder, engine drivers
│   └── rules/
│       ├── ChainTests.gd       27 assertions
│       ├── TimingTests.gd      37 assertions
│       ├── TurnFlowTests.gd    40 assertions
│       ├── SummonTests.gd      45 assertions
│       └── SpellTrapTests.gd   27 assertions
├── Tools/                             Python research + data pipeline (dev only)
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
| Counter support (place/remove + events) | **DONE, NOT TESTED** | `GameState.place_counters()` / `remove_counters()` | plumbing only; no assertion yet |
| **Battle Phase / attack declaration / replay** | **UNVERIFIED** | `Scripts/rules/BattleRules.gd` | **none** |
| **Damage Step (5 sub-steps)** | **UNVERIFIED** | `BattleRules` + `DuelEngine._advance_battle()` | **none** |
| **Continuous effects** | **UNVERIFIED** | `Scripts/rules/ContinuousEffects.gd` | **none** |
| Special Summon execution | partial — `SummonRules.begin_special_summon()` exists, **UNVERIFIED**, and no card yet calls it | | |
| `PlayerController` abstraction | **DONE+TESTED** (`ScriptedController`); no UI implementation yet | `Scripts/engine/PlayerController.gd` | used by every suite |
| Duel log / replay | **DONE, NOT TESTED** | `Scripts/engine/DuelLog.gd` | records actions, decisions, events, seed |

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

---

## 7. Blockers

None.

### Unfinished Phase 4b work (honest list)

* `BattleRules.gd`, `ContinuousEffects.gd` and `DuelEngine._advance_battle()` are
  **committed but completely untested**. Treat every claim in them as unproven.
* Counters, `DuelLog` and `begin_special_summon()` have no assertions.
* `DuelEngine._advance_battle()` calls `battle._clear_battle()`, reaching into an
  underscore-prefixed method from outside the class. Give it a public name when the
  battle tests are written.
* Attack replay is implemented from [S1 p.39] but the "attack with a different monster
  spends the original's attack" branch has never been executed.
* No card in `Data/cards/cards.json` has any `EffectDef` yet, so the engine has been
  exercised only against synthetic cards built by `Tests/support/TestFixtures.gd`. That
  is intentional for Phase 4 — the rules engine must be right before the 77 cards land.

---

## 8. Next step and architecture map for resumption

### How to resume in one paragraph

Phase 4b-1 is done and proven: the Fast Effect Timing machine, the `DuelEngine`
legal-action API, trigger collection with simultaneous ordering, summons (including
summon negation), turn/phase flow and the Spell/Trap framework all pass 176 assertions.
Phase 4b-2 code for the Battle Phase, Damage Step and continuous effects is **written and
committed but has never been tested**. The next session's job is to test it, fix what
fails, and only then move on. Read §6a for per-subsystem status and the design decisions
that must not be reversed. Do **not** re-read the whole repository, re-run research, or
re-derive rules.

### Immediately next — Phase 4b-3, in this exact order

1. **`Tests/rules/BattleTests.gd`** — write against the existing untested
   `Scripts/rules/BattleRules.gd`. Expect failures; fix the implementation, not the test,
   unless the test misstates the rule. Cover, all from `RULES_SPEC.md §6`:
   * attack declaration is offered only in the Battle Step, only for a face-up Attack
     Position monster the turn player controls;
   * one attack per monster per turn;
   * a direct attack is legal only when the opponent controls no monsters [S1 p.38];
   * the response window after `ATTACK_DECLARED` really opens, and the Damage Step does
     not begin until it closes;
   * an attack whose attacker or target left the field before damage calculation simply
     does not happen;
   * **attack replay** [S1 p.39] — including the untested branch where attacking with a
     *different* monster spends the original monster's attack.
2. **`Tests/rules/DamageStepTests.gd`** — `RULES_SPEC.md §7`. Cover:
   * all six rows of the damage-calculation table in §7.4 (ATK>, ATK=, ATK< against both
     Attack and Defense Position), plus the direct attack;
   * the 0-ATK rule: two 0-ATK Attack Position monsters destroy neither [S1 p.51];
   * destruction is *determined* in sub-step 3 but the card is only **sent to the GY in
     sub-step 5** — assert the ordering from the event log;
   * a monster attacked while face-down is flipped in sub-step 2 but its **Flip effect
     activates in sub-step 4** (the `_carried_events` mechanism in
     `DuelEngine._advance_battle()`);
   * the §7.2 activation restriction: an effect with `DamageStepPermission.NONE` is never
     offered anywhere in the Damage Step; one with `UNTIL_DAMAGE_CALC` is offered in
     sub-steps 1–2 and **not** from sub-step 3 onward;
   * an optional destroyed-by-battle trigger (the `Shining Angel` shape) is still offered
     to its controller in sub-step 5;
   * battle damage reaching 0 LP ends the Duel.
3. **`Tests/rules/ContinuousTests.gd`** — `RULES_SPEC.md`/master prompt §25. Cover: a
   continuous ATK modifier applying and disappearing when its source leaves the field, is
   flipped face-down, or is negated; a `cannot_attack` restriction removing the attack
   from `get_legal_actions`; `cannot_be_destroyed_by_battle` surviving damage
   calculation; and a counter-scaled modifier (the `Wonder Balloons` shape) recomputing
   as counters change.
4. **`Tests/rules/CounterTests.gd`** — placing/removing Spell Counters and Balloon
   Counters, the `COUNTER_PLACED` / `COUNTER_REMOVED` events, that counters may only go
   on a face-up card on the field, that removal is all-or-nothing (it is used as a cost),
   and that counters are cleared when the card leaves the field.
5. Rename `BattleRules._clear_battle()` to a public name once its callers are covered.
6. **`Tests/rules/HiddenInfoTests.gd`** — `get_visible_state(viewer)` never leaks the
   opponent's hand, a face-down card's identity, or Deck order; counts remain public
   (`RULES_SPEC.md §12`).
7. Register every new suite explicitly in `Scripts/tests/RunTests.gd`.
8. Update `Reports/TEST_RESULTS.md` and this file with the **actually measured** numbers,
   then commit.

Only once all of the above passes should Phase 5 (the 77 card implementations) begin.

### Reminders that cost time last session

* Run `--import` after adding any `class_name` script, or Godot will not register it.
* Never use `:=` where the right-hand side is a `Variant` (an untyped `Array` element, or
  a function declared `-> Variant`). It is a hard compile error, and a failed compile
  takes the whole dependent class down with it.
* Build tests through `Tests/support/TestFixtures.gd` — it has synthetic card builders,
  a duel builder, `pass_until_open()`, `advance_to_phase()`, `end_turn()` and event
  helpers. Do not hand-roll a duel.
* The engine does **not** pause when nobody holds a legal response: it auto-passes and
  resolves. Assertions about intermediate states must read the event log, not the live
  card. This caused the one test failure of the last session.

**Where the rules live:** every subsystem above must cite `Research/RULES_SPEC.md` section
numbers in comments, and those trace to `RULES_SOURCES.md` S1–S4. Do not re-derive rules.

**Card implementation (Phase 5)** goes in `Scripts/cards/registry/<CardName>.gd`, one file
per card, each declaring `const CARD_NAME := "..."` and one `EffectDef.new(...)` per official
effect clause — `Tools/build_matrix.py` reads those two markers to compute the implementation
matrix, so the matrix can never over-report.

**Re-verify after any change:**

```bash
python Tools/build_card_db.py && python Tools/build_matrix.py
"<godot>" --headless --path "<project>" --script res://Scripts/tests/SmokeCheck.gd
```

**Do not:** re-run the 251-image identification; re-fetch the 77 card pages (they are cached
in `Data/generated/konami_raw/`); re-derive the rules from memory; or use Graphify for
GDScript navigation (unsupported — see §2).

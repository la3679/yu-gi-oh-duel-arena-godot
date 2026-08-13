# PROJECT_STATE — Duel Arena

> Persistent resume file. A new Claude Code session should read **this file first**,
> then read only the targeted files named in §8. Do **not** recursively reread the repository.

**Last updated:** 2026-08-13
**Current phase:** **Phase 5 — the card effect library.** Phases 0–4 are complete and
Gate B (the generic rules engine) is MET; nothing in Phase 4 needs revisiting.
**Phase 5 progress:** batches 1-4 are complete — the registry and effect primitives,
`Shining Angel`, the **9 vanilla Normal Monsters**, the **resolution-time Special Summon
batch** (`Monster Reborn`, `Silver's Cry`, `Kaibaman`, `Dragonic Tactics`, `One for One`),
**batch 3**: the two Continuous-Trap revivals (`Birthright`, `Call of the Haunted`),
the four summoning-procedure monsters (`Hieratic Dragon of Tefnuit`, `Inari Fire`,
`Ranryu`, `Nefarious Archfiend Eater of Nefariousness`) and the first Equip-card group
(`Gagagashield`, `Rider of the Storm Winds`), and **batch 4**: the remaining Continuous
Traps and the Continuous Spell (`Castle of Dragon Souls`, `Fiendish Chain`,
`Five Brothers Explosion`, `Sealing Ceremony of Suiton`, `Wonder Balloons`)
— **28 / 77 implemented, 28 / 77 tested**.
**Nothing in batch 4 is partial, unverified or approximated:** every card listed above has
its own suite and passes it in full. **49 unique playable cards remain.**
With batch 4 the pool's **Continuous Spell/Trap group is complete** (all 6 Continuous Traps
plus the single Continuous Spell).
**Overall status:** IN PROGRESS — **not** acceptance-complete.
**HEAD at checkpoint:** `565ae0c` (the Phase 5 batch-4 commit follows it)
**Measured suite at checkpoint:** **1968 passed / 0 failed** across **35 suites**
(713 core rules + 1209 per-card + 46 interaction); SmokeCheck **PASS**.

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

Last verified run (2026-08-13, at commit `565ae0c` plus the Phase 5 batch-4 work):

```
powershell -File Tools\run_tests.ps1 SmokeCheck  -> SMOKE CHECK: PASS
powershell -File Tools\run_tests.ps1 RunTests
  ChainTests:          27/27      DamageStepTests:      86/86
  TimingTests:         37/37      ContinuousTests:      52/52
  TurnFlowTests:       40/40      CounterTests:         44/44
  SummonTests:         45/45      HiddenInfoTests:      76/76
  SpellTrapTests:      27/27      SpecialSummonTests:   54/54
  BattleTests:         72/72      RulesQuestionTests:   37/37
  EquipTests:          83/83      ReplayTests:          33/33
  --- per-card (Phase 5) ---
  ShiningAngelTests:   43/43      BirthrightTests:              59/59
  NormalMonsterTests:  76/76      CallOfTheHauntedTests:        48/48
  MonsterRebornTests:  48/48      HieraticDragonOfTefnuitTests: 67/67
  SilversCryTests:     47/47      InariFireTests:               65/65
  KaibamanTests:       47/47      RanryuTests:                  49/49
  DragonicTacticsTests:39/39      NefariousArchfiendTests:      44/44
  OneForOneTests:      40/40      GagagashieldTests:            63/63
                                  RiderOfTheStormWindsTests:    66/66
  --- batch 4 (Phase 5) ---
  CastleOfDragonSoulsTests:     109/109   SealingCeremonyOfSuitonTests: 73/73
  FiendishChainTests:            74/74    WonderBalloonsTests:          85/85
  FiveBrothersExplosionTests:    67/67
  --- interaction (Phase 5) ---
  SpecialSummonInteractionTests: 46/46
  TOTAL: 1968 passed, 0 failed (1968 assertions across 35 suites)
  RESULT: PASS
```

**1968 / 1968 passing. These numbers were actually produced by the command above; they
are not estimates.** All 1560 earlier assertions still pass unchanged — none was weakened,
retargeted or deleted. Per-suite detail and the honest not-yet-covered list live in
`Reports/TEST_RESULTS.md`.

Per-test assertion counts quoted in `Reports/TEST_RESULTS.md` are **measured**:
`TestCase` records them per test and `Scripts/tests/DumpAssertionCounts.gd` prints them.
Run it directly (it is a reporting tool, not a suite, so `run_tests.ps1` will print
`RUNNER: FAIL` for it — it looks for a `RESULT: PASS` line that this script does not
emit):

```bash
"…\Godot_v4.7.1-stable_win64.exe" --headless --path "…\DuelArenaGame" --script res://Scripts/tests/DumpAssertionCounts.gd
```

SmokeCheck remains a load/determinism check, not part of the rules suite count.

### Use `Tools/run_tests.ps1`, not the raw command

Two things it handles that cost real time to discover:

1. Godot writes heavily to stderr (every `push_error` prints a full GDScript backtrace).
   Piping stdout+stderr through PowerShell can block on a full pipe and appear to hang.
   The runner redirects to files and prints them afterwards.
2. A suite that fails to **compile** makes `RunTests._initialize()` throw before it can
   call `quit()`, so the headless SceneTree runs forever at near-zero CPU. The runner does
   a `--check-only` parse pass first, turning that hang into an immediate readable error.

### Defects the Phase 5 batch-4 tests caught

All three are **pre-existing gaps**, each surfaced because a batch-4 card is the first card in
the pool that needs the behaviour. Full write-up in `Reports/TEST_RESULTS.md`.

1. **A resolving effect could not see what its own cost had paid.**
   `ChainManager._resolve_link()` built the resolution `EffectContext` without copying
   `ChainLink.cost_payload`, so `ctx.cost_payload` was always empty at resolution. Every card
   before this batch had a cost whose size the CARD fixed, so nothing noticed.
   `Wonder Balloons` — "place 1 Balloon Counter **for each card sent to the GY**" — cannot be
   resolved without it, and recounting from the Graveyard is impossible. Fixed by carrying the
   payload forward. `EffectPrimitives.cost_card_count()` is the read side.
2. **"You can only control 1" was never checked on any route a SPELL/TRAP takes onto the
   field.** `SummonRules.control_limit_satisfied()` was consumed only by the three MONSTER
   routes, so `Castle of Dragon Souls` — the pool's only Spell/Trap carrying the restriction
   — was unrestricted and a second copy could be activated freely. Now asked in
   `ActivationRules.can_activate()` for a non-monster card activation. This gap was predicted in
   the previous checkpoint's batch-4 plan and is now closed.
3. **A continuously-applied negation had no system-owned channel, and would have depended on
   board iteration order.** `CardInstance.effects_negated` was a plain flag that
   `ContinuousEffects` neither wrote nor cleared, so a card setting it directly would have
   negated a monster forever, outliving its own source. Worse, since `_continuous_sources()`
   skips negated cards, a single-pass recompute gave a different answer depending on which card
   was walked first. Fixed with `ContinuousEffects.NEGATION_FLAG` +
   `CardInstance.effects_are_negated()` + a **two-pass** `recompute()` ordered by the
   declarative `EffectDef.negates_effects` marker.

### Defects the Phase 5 batch-3 tests caught

1. **`GameState.move_card()` read "was this card face-up?" AFTER the move rewrote the
   position.** `_attach()` and the position-handling block turn a card sent to the GY
   FACE_UP and one returned to the hand FACE_DOWN, so the new `last_move_was_face_up`
   record answered a question about the DESTINATION. `Inari Fire`'s "after this **face-up
   card on the field** was destroyed by card effect" depends on it entirely. Fixed by
   capturing it at the top of `move_card()`, next to `was_on_field`, before `_detach()`.
2. **`CARD_DESTROYED` was not emitted for `MoveReason.DESTROYED_BY_RULE`.** The new reason
   was added to `Enums.is_destruction()` but not to the `match reason:` block that emits
   the semantic event, so an Equip Card that lost its host went to the Graveyard with no
   destruction event at all. Caught by `EquipTests` on its first run.
3. **`_cleanup_resolved_spell_traps()` decided what stays on the field from the card KIND
   alone.** Wrong in both directions once Equip Cards exist: a NORMAL Trap that equipped
   (`Gagagashield`) must stay, and an Equip Spell that resolved WITHOUT equipping must not.
   The equip relationship now takes precedence over `Enums.stays_on_field()`.

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
| 5 | Card effect library (77 cards) | **IN PROGRESS** — **28 / 77** implemented and tested (batches 1-4) |
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
│   ├── RULES_SPEC.md                  implementable rules contract (§1-§17)
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
│   ├── cards/
│   │   ├── EffectDef.gd               one official effect clause, declaratively
│   │   ├── EffectContext.gd           everything an effect callable can reach
│   │   ├── CardRegistry.gd            scans registry/, validates, attaches to CardDefs
│   │   ├── EffectPrimitives.gd        reusable mechanics shared by the card library
│   │   └── registry/                  6 effect cards; the 9 vanillas need no file
│   │       ├── ShiningAngel.gd        the template for every other card
│   │       ├── MonsterReborn.gd       target 1 monster in either GY
│   │       ├── SilversCry.gd          Quick-Play + hard once-per-turn on the name
│   │       ├── Kaibaman.gd            Tribute-self COST + named-card Summon
│   │       ├── DragonicTactics.gd     two-Tribute COST + Deck Summon
│   │       ├── OneForOne.gd           send-from-hand COST + hand-or-Deck Summon
│   │       ├── Birthright.gd          Continuous Trap revival; mutual link on LEAVES FIELD
│   │       ├── CallOfTheHaunted.gd    the same shape, third clause on IS DESTROYED
│   │       ├── HieraticDragonOfTefnuit.gd  summon procedure + "this way" + Tribute trigger
│   │       ├── InariFire.gd           control limit + procedure + delayed Standby revival
│   │       ├── Ranryu.gd              control limit + procedure + optional targeting revival
│   │       ├── NefariousArchfiendEaterOfNefariousness.gd  opponent's End Phase GY effect
│   │       ├── Gagagashield.gd        Trap that equips + COUNTED destruction prevention
│   │       ├── RiderOfTheStormWinds.gd  monster that equips itself + piercing + replacement
│   │       ├── CastleOfDragonSouls.gd  banish as COST + ATK gain that outlives the source
│   │       ├── FiendishChain.gd       continuous NEGATION + attack lock + mutual destruction
│   │       ├── FiveBrothersExplosion.gd  LP gain on activation + opponent-agent burn trigger
│   │       ├── SealingCeremonyOfSuiton.gd  send-from-hand COST + banish from their GY
│   │       └── WonderBalloons.gd      the Continuous Spell: variable cost + Balloon Counters
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
│       ├── TestCase.gd                assertion harness (+ measured per-test counts)
│       ├── DumpAssertionCounts.gd     reporting tool: per-test counts for TEST_RESULTS
│       └── RunTests.gd                entry point; a 0-assertion suite is a FAILURE
├── Tests/
│   ├── support/TestFixtures.gd        synthetic cards, duel builder, engine drivers
│   └── rules/
│       ├── EquipTests.gd        83 assertions (the Equip gate)
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
├── Tests/cards/
│   ├── ShiningAngelTests.gd              43   (declares CARD_UNDER_TEST)
│   ├── NormalMonsterTests.gd             76   (declares CARDS_UNDER_TEST — 9 cards)
│   ├── MonsterRebornTests.gd             48
│   ├── SilversCryTests.gd                47
│   ├── KaibamanTests.gd                  47
│   ├── DragonicTacticsTests.gd           39
│   ├── OneForOneTests.gd                 40
│   ├── BirthrightTests.gd                59
│   ├── CallOfTheHauntedTests.gd          48
│   ├── HieraticDragonOfTefnuitTests.gd   67
│   ├── InariFireTests.gd                 65
│   ├── RanryuTests.gd                    49
│   ├── NefariousArchfiendTests.gd        44
│   ├── GagagashieldTests.gd              63
│   ├── RiderOfTheStormWindsTests.gd      66
│   ├── CastleOfDragonSoulsTests.gd      109
│   ├── FiendishChainTests.gd             74
│   ├── FiveBrothersExplosionTests.gd     67
│   ├── SealingCeremonyOfSuitonTests.gd   73
│   ├── WonderBalloonsTests.gd            85
│   └── SpecialSummonInteractionTests.gd  46   (no card-under-test marker, on purpose)
├── Tools/                             Python research + data pipeline (dev only)
│   ├── run_tests.ps1                  headless test runner (parse-check + no pipe stall)
│   ├── enumerate_cards.py             deck CSVs -> card_pool.json
│   ├── fetch_official_cards.py        official Konami DB -> konami_cards.json
│   ├── diff_card_text.py              official vs saved text diff
│   ├── dump_official_text.py          human-readable card text dump
│   ├── build_card_db.py               -> Data/cards/cards.json + deck lists
│   └── build_matrix.py                -> Reports/CARD_IMPLEMENTATION_MATRIX.csv
├── Reports/CARD_IMPLEMENTATION_MATRIX.csv   77 rows, text verified, 28 implemented
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
| **Equip Cards (equip / unequip, zone occupancy, host leaves, host flipped face-down, granted continuous effects, battle recalculation)** | **DONE+TESTED** | `GameState.equip_to()` / `_detach_equips()`, `DuelEngine._cleanup_resolved_spell_traps()` | EquipTests (83) |
| **Destruction prevention (uncounted and COUNTED) and destruction REPLACEMENT** | **DONE+TESTED** | `GameState.destruction_prevented()` / `carry_out_destruction()` / `destroy()` | EquipTests, GagagashieldTests, RiderOfTheStormWindsTests |
| **Per-card facts that outlive the field (`last_move_*`, `card_memory`)** | **DONE+TESTED** | `GameState.move_card()`, `GameState.remember/recall/forget` | InariFireTests, BirthrightTests, CallOfTheHauntedTests |
| **"You can only control 1 …" on every route onto the field** | **DONE+TESTED** | `SummonRules.control_limit_satisfied()`, consumed by `can_normal_summon_or_set`, `begin_special_summon`, `ActivationRules.can_use_summon_procedure` | InariFireTests, RanryuTests, NefariousArchfiendTests |
| **Continuous NEGATION of another card's effects** | **DONE+TESTED** | `ContinuousEffects.NEGATION_FLAG` / `negate_effects()` / two-pass `recompute()`, read via `CardInstance.effects_are_negated()` | FiendishChainTests |
| **A cost's payload readable at RESOLUTION** | **DONE+TESTED** | `ChainManager._resolve_link()` copies `ChainLink.cost_payload`; `EffectPrimitives.cost_card_count()` | WonderBalloonsTests |
| **Banish as a COST (vs. banish as an effect)** | **DONE+TESTED** | `EffectPrimitives.pay_banish_cost()` vs `banish_target()` | CastleOfDragonSoulsTests, SealingCeremonyOfSuitonTests |
| **Turn-scoped ATK modifier that outlives its source** | **DONE+TESTED** | `EffectPrimitives.gain_atk_until_end_of_turn()` + `TurnFlow._end_of_turn_cleanup()` | CastleOfDragonSoulsTests |
| **Effect damage / LP gain (not battle damage)** | **DONE+TESTED** | `GameState.change_life_points()` + an explicit `check_life_point_loss()` by the caller | FiveBrothersExplosionTests |
| **Counters driven by a real card** | **DONE+TESTED** | `GameState.place_counters()` consumed by `Wonder Balloons` | WonderBalloonsTests |
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
13. **A vanilla Normal Monster is IMPLEMENTED and has no registry file.** An empty
    `CardDef.effects` array IS the complete implementation of a card with no effect text,
    which is what `CardDef.is_vanilla()` and `CardRegistry.unimplemented()` already
    encode. `Tools/build_matrix.py` therefore counts a card as implemented when it has a
    registry file **or** when the card database marks it `is_normal` — and only then.
    The guard against abusing that shortcut is
    `NormalMonsterTests :: no Effect Monster is silently treated as a vanilla card`,
    which asserts that `is_vanilla()` is false for every Effect Monster and that every
    non-vanilla card without effects is still on the honest unimplemented list. Do not
    widen the `is_normal` condition, and do not delete that test.
14. **A cost is paid inside `pay_cost`, at activation, through an `EffectPrimitives.pay_*`
    helper.** `DuelEngine._perform_activation()` runs `pay_cost` before the Chain Link
    exists and with the controller attached, so a cost that needs a choice asks for it
    there (`choose_n`, logged like every other decision) and records what it consumed in
    `ctx.cost_payload`. A cost is never re-checked or refunded at resolution:
    `KaibamanTests :: the Tribute is a COST` proves it survives the effect being negated.
    Costs are all-or-nothing — `choose_n` returns `[]` rather than a partial selection.
15. **"Special Summon 1 …" with no position named asks the summoning player.**
    `EffectPrimitives.choose_face_up_position()` offers face-up Attack and face-up
    Defense and **never** face-down: a Special Summon is face-up unless the card says
    otherwise (`Apprentice Magician` does, and says so). The card is chosen first and the
    position second. RULES_SPEC.md 5.5.
16. **A resolving effect re-checks its own target and its own room.** Activation legality
    is not carried forward to resolution: `EffectPrimitives.surviving_target()` drops a
    target that left the required zone, and every Special Summon primitive re-tests
    `has_free_monster_zone()`. Both branches are covered
    (`MonsterRebornTests :: a target that left the Graveyard`,
    `SpecialSummonInteractionTests :: the last zone goes to Chain Link 2`). Master
    prompt 44.
17. **Every question put to a player is a duel input and must be logged.**
    `TriggerCollector`, `TurnFlow` and `EffectContext.ask()` all record through
    `DuelLog.record_decision()`. A new decision point that skips this silently breaks
    replay, and `ReplayTests` will catch it (it compares the recorded count against what
    the controllers were actually asked).

18. **A fact that must survive a card leaving the field does NOT live in
    `CardInstance.flags`.** `on_leave_field()` clears `flags` during the very move that
    makes such a clause relevant. Two engine facilities exist instead and neither may be
    replaced by a per-card hack: `CardInstance.last_move_*` (the last completed move,
    recorded AFTER `on_leave_field()`, with `was_face_up` captured BEFORE the move) and
    `GameState.card_memory` (a persistent link between two instances). `RULES_SPEC.md §15`.
19. **There is ONE destruction entry point.** `GameState.destroy()` = prevention check then
    carry-out; `carry_out_destruction()` alone is for a destruction whose prevention was
    already asked. Battle asks prevention at DAMAGE CALCULATION (a monster that cannot be
    destroyed was never determined to be destroyed, so it must not appear in
    `DAMAGE_CALCULATED`) and replacement at the END OF THE DAMAGE STEP (that is when it
    "would be destroyed"). Do not merge the two steps. `RULES_SPEC.md §17`.
20. **A clause that answers a rules-layer QUESTION is found by effect id, never by reading
    card text.** `SummonRules.TRIBUTE_VALUE_EFFECT_ID`, `SummonRules.CONTROL_LIMIT_EFFECT_ID`,
    `GameState.DESTRUCTION_PREVENTION_EFFECT_ID`, `GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID`,
    listed in `CardRegistry.RULES_QUERY_EFFECT_IDS`. Such a clause is CONTINUOUS with no
    `apply_continuous()`, and the registry still rejects one that answers nothing. The query
    itself is PURE — a counted clause declares `EffectDef.uses_per_turn` and the rules layer
    spends the use, so the card never has a side effect inside a condition.
21. **An Equip Card is not "an Equip Spell".** [S1 p.53] includes equipped Traps and monsters
    equipped to monsters, and the V1 pool's only two equippers are exactly those. Whether a
    card stays on the field after resolving is decided by the **equip relationship first** and
    the card kind second — a `Gagagashield` that equipped stays despite being a Normal Trap,
    and an Equip Spell that equipped nothing leaves despite `Enums.stays_on_field()`.
22. **`Birthright` and `Call of the Haunted` are NOT one implementation.** They share clauses 1
    and 2 (via `EffectPrimitives.revive_target_in_attack_position` /
    `destroy_linked_monster`) and disagree on clause 3: `Birthright` destroys itself when the
    revived monster **leaves the field**, `Call of the Haunted` only when it **is destroyed**.
    Banish or bounce the monster and the two behave differently. Each writes its own trigger
    condition, and `CallOfTheHauntedTests :: the clause shape` asserts directly that the two
    listen to different events. Do not "simplify" this.
23. **"Special Summoned THIS WAY" is narrower than "Special Summoned".**
    `CardInstance.summoned_by_procedure_id` records which summoning PROCEDURE a monster used on
    itself, written by `SummonRules.complete_summon()` from the pending record. A
    `Hieratic Dragon of Tefnuit` revived by `Monster Reborn` may attack; one that used its own
    procedure may not. CARD_RULINGS.md §2.1.

24. **`CardInstance.effects_negated` is never read directly.** Every rules-layer question about
    negation goes through `CardInstance.effects_are_negated()`, which ORs the one-shot flag with
    the continuous system's `ContinuousEffects.NEGATION_FLAG`. The two channels have different
    lifetimes on purpose: the flag is cleared only when a card leaves the field or is flipped
    face-down, while the continuous one is wiped and rebuilt on every recompute so it switches
    off by itself with its source. Writing `effects_negated = true` from a card would recreate
    exactly the bug the continuous system exists to prevent.
25. **`ContinuousEffects.recompute()` is TWO passes and must stay two.** A clause that negates
    is declared with `EffectDef.negates_effects` (fluent: `negating()`) and runs in pass 1;
    everything else runs in pass 2, by which time "is this source negated?" has a stable answer.
    Collapsing them makes the result depend on the order the board is walked in — a monster
    processed before `Fiendish Chain` would apply its own continuous effect and one processed
    after it would not. `FiendishChainTests :: it negates a CONTINUOUS effect` is the guard.
26. **A cost's payload reaches resolution, and an effect measured by its own cost reads it from
    there.** `ChainManager._resolve_link()` copies `ChainLink.cost_payload` onto the resolution
    context. `Wonder Balloons` places one counter per card its cost sent; recounting the
    Graveyard is not an alternative, because the sent cards are indistinguishable from
    everything already there. Costs are still never re-checked or refunded.
27. **"Banish as a cost" and "banish as an effect" are separate primitives and must stay
    separate.** `pay_banish_cost()` runs at activation and is never refunded
    (`Castle of Dragon Souls`); `banish_target()` runs at resolution and re-checks the target
    first (`Sealing Ceremony of Suiton`). Neither is "a move to the banished zone" with a
    different caller — the difference is when it happens and whether it can fail.
28. **"You can only control 1" counts a face-down MONSTER but not a face-down SPELL/TRAP.**
    A Set Spell/Trap has not been activated and is not yet in play as that card; the limit is
    re-tested when it IS activated, in `ActivationRules.can_activate()`. The other reading makes
    the restriction incoherent for a Trap — two Set copies would forbid activating either.
    Reasoning and confidence recorded in `Research/CARD_RULINGS.md` §4A (R19).
29. **A Continuous Spell/Trap with no printed activation effect still gets a real
    `CARD_ACTIVATION` EffectDef** whose resolution is an honest no-op with a log note. It is not
    a placeholder: activating the card is what puts it face-up on the field, which is what makes
    its other clauses reachable. `Castle of Dragon Souls`, `Sealing Ceremony of Suiton` and
    `Wonder Balloons` each carry one, which is why their EffectDef counts exceed their printed
    clause counts. The per-card suites assert the count and say why.

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

### Genuinely still open (carried through Phase 5, not hidden)

* **49 of 77 cards are not implemented yet.** They are honestly `NOT_IMPLEMENTED` in the
  matrix; see §8 for the next batch.
* **Simultaneous-LP-zero (a draw) is unexercised.** This is now the ONLY item left on the
  core-rules "not yet covered" list in `Reports/TEST_RESULTS.md`.
* **`Castle of Dragon Souls` was mis-grouped as an Equip card** in an earlier checkpoint's
  §8 plan. **CLOSED in batch 4.** It is a **Continuous Trap with a temporary ATK boost**, it
  equips nothing, and it is implemented and tested as one (109 assertions). Preserve this
  correction: it must never be moved back into an Equip group.
* **`Kunai with Chain` and `Fairy Tail - Rella` still exercise Equip mechanics** and are not
  implemented yet. The generic subsystem they need now exists and is tested; they still need
  their own per-card work.
* **61457 leaked ObjectDB instances at exit** (measured on this run, up from 50075 — it grows
  with the number of duels the suite builds) — RefCounted cycles between `GameState`, the
  `DuelLog` signal and test closures. Harmless to rules outcomes, but it must be cleaned up
  before the UI keeps one duel alive for a long session.

---

## 8. Next step and architecture map for resumption

### How to resume in one paragraph

**Phase 4 is complete and Gate B is MET; Phase 5 is 28 / 77 of the way through.** The generic
rules engine is tested end to end (Fast Effect Timing, the `DuelEngine` legal-action API,
trigger collection and ordering, Normal/Tribute/Flip **and Special** Summons including summon
negation on both paths, turn/phase flow, the Spell/Trap framework, the Battle Phase, the Damage
Step and its activation restriction, damage calculation including piercing, battle destruction
semantics, continuous effects, the counter engine, hidden-information filtering, the DuelLog
replay payload, and — new in batch 3 — **Equip Cards, destruction prevention/replacement,
per-card facts that outlive the field, and the "you can only control 1" limit**). On top of it
the card library has the 9 vanillas, `Shining Angel`, the resolution-time Special Summon batch,
all of batch 3, and all of batch 4 — which completes the pool's **Continuous Spell/Trap
group** and adds continuous NEGATION, banish-as-a-cost, an ATK gain that outlives its source,
effect damage, and the first real use of the counter engine — **1968 assertions across 35
suites, 0 failures**, SmokeCheck PASS. Read §6a for per-subsystem status and the
**twenty-nine** design decisions that must not be reversed, and §7 for what is genuinely still
open. Do **not** re-read the whole repository,
re-run research, or re-derive rules.

### Batch 3 — COMPLETE (nothing partial, nothing unverified)

| Card | Clauses | Suite | Result |
|---|---:|---|---|
| `Birthright` | 3 | `BirthrightTests` | 59/59 |
| `Call of the Haunted` | 3 | `CallOfTheHauntedTests` | 48/48 |
| `Hieratic Dragon of Tefnuit` | 3 | `HieraticDragonOfTefnuitTests` | 67/67 |
| `Inari Fire` | 3 | `InariFireTests` | 65/65 |
| `Ranryu` | 3 | `RanryuTests` | 49/49 |
| `Nefarious Archfiend Eater of Nefariousness` | 3 | `NefariousArchfiendTests` | 44/44 |
| `Gagagashield` | 2 | `GagagashieldTests` | 63/63 |
| `Rider of the Storm Winds` | 3 | `RiderOfTheStormWindsTests` | 66/66 |

Generic mechanics completed and tested in this batch — none is left UNVERIFIED:

* **Equip Cards** — `GameState.equip_to()` / `_detach_equips()` / `equipped_cards()`, the
  `CARD_EQUIPPED` / `CARD_UNEQUIPPED` events, Spell & Trap Zone occupancy, host leaves the
  field, host flipped face-down, an Equip Spell that equipped nothing, and battle
  recalculation from the equipped ATK. `EquipTests` (83). **This was the Equip gate and it was
  written and passing BEFORE either Equip card was implemented.**
* **Destruction** — one entry point (`destroy()` = `destruction_prevented()` then
  `carry_out_destruction()`), uncounted and COUNTED prevention, and destruction REPLACEMENT,
  with `Enums.MoveReason.DESTROYED_BY_RULE` for a rules destruction. `RULES_SPEC.md §17`.
* **Facts that outlive the field** — `CardInstance.last_move_*` and `GameState.card_memory`.
  `RULES_SPEC.md §15`.
* **"You can only control 1 …"** — `SummonRules.control_limit_satisfied()`, enforced on every
  route onto the field.
* **"Special Summoned this way"** — `CardInstance.summoned_by_procedure_id`.

Cards started but unfinished: **none.** Mechanics still unverified from this batch: **none.**

### Batch 4 — COMPLETE (nothing partial, nothing unverified)

**The remaining Continuous Traps and the Continuous Spell.** The pool's Continuous
Spell/Trap group is now finished: 6 Continuous Traps + 1 Continuous Spell, all implemented
and all tested.

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Castle of Dragon Souls` | 4 | `CastleOfDragonSoulsTests` | 109/109 |
| `Fiendish Chain` | 3 | `FiendishChainTests` | 74/74 |
| `Five Brothers Explosion` | 2 | `FiveBrothersExplosionTests` | 67/67 |
| `Sealing Ceremony of Suiton` | 2 | `SealingCeremonyOfSuitonTests` | 73/73 |
| `Wonder Balloons` | 3 | `WonderBalloonsTests` | 85/85 |

Generic mechanics completed and tested in this batch — none is left UNVERIFIED:

* **Continuous NEGATION** — `ContinuousEffects.NEGATION_FLAG` / `negate_effects()`, read
  everywhere through `CardInstance.effects_are_negated()`, applied by a **two-pass**
  `recompute()` ordered by the declarative `EffectDef.negates_effects` marker.
* **Banish as a COST vs. banish as an EFFECT** — `pay_banish_cost()` and `banish_target()`,
  deliberately two primitives.
* **A cost's payload readable at RESOLUTION** — `ChainManager._resolve_link()` +
  `EffectPrimitives.cost_card_count()`, for a clause measured by its own cost.
* **A variable-size cost** — `pay_send_any_number_to_gy_cost()`, minimum one.
* **A turn-scoped ATK modifier that outlives its source** —
  `gain_atk_until_end_of_turn()`, expiring in `TurnFlow._end_of_turn_cleanup()`.
* **Effect damage and LP gain** — including a Duel ending at 0 LP from a card effect.
* **The control limit on a Spell/Trap** — enforced in `ActivationRules.can_activate()`.
* **Counters driven by a real card** — `Wonder Balloons` is the first consumer of the
  counter engine `CounterTests` built.

Cards started but unfinished: **none.** Mechanics still unverified from this batch: **none.**

### The NEXT batch (batch 5) — start here

**The counter monster, then the second Equip group, then negation.** Continue the
mechanic-grouped ordering; do not switch to alphabetical.

1. **`Apprentice Magician`** — the pool's remaining counter card (Spell Counter). The counter
   engine is built and tested (`CounterTests`, 44) and now has one real consumer
   (`Wonder Balloons`), so this is ordinary per-card work with one exception: it Special
   Summons in **face-down Defense Position**, which is the one case
   `EffectPrimitives.choose_face_up_position()` deliberately does not offer. It must pass the
   position explicitly rather than widening that primitive.
2. **`Kunai with Chain` and `Fairy Tail - Rella`** — the second Equip group. The generic Equip
   subsystem exists and is tested (`EquipTests`, 83). `Fairy Tail - Rella` additionally needs
   **targeting protection / redirect** (`Research/CARD_RULINGS.md` §3), which nothing implements
   yet — expect that to be the real work, not the equipping.
3. **The negation cards** (`Champion's Vigilance`) **last** — they exercise the most machinery,
   including `negate_pending_summon()` on **both** Summon paths, and "negate the activation and
   destroy that card", which is distinct from the continuous negation batch 4 added
   (`ChainTests :: negate activation vs negate effect` already pins the distinction).

After those, the remaining unimplemented cards are mostly Normal Spells/Traps with
movement effects (return to hand, place on top/bottom of Deck, shuffle into Deck, excavate)
and the charmer control-change group — group them by those mechanics, not by card type.

### Phase 5 — how the card library is built (the pattern is now established)

**Read `Scripts/cards/registry/ShiningAngel.gd` and `Tests/cards/ShiningAngelTests.gd`
first. They are the template; copy their shape.**

The machinery already exists and does not need to be re-invented:

| Piece | File | What it does |
|---|---|---|
| Registry loader | `Scripts/cards/CardRegistry.gd` | **Scans** `Scripts/cards/registry/` (never a hand-written list, so it cannot drift from the matrix), validates each file, attaches effects to the canonical `CardDef`s. `load_library()` returns `{"cards": name -> CardDef, "errors": Array}`. |
| Reusable mechanics | `Scripts/cards/EffectPrimitives.gd` | `own_cards_in()`, `monster_filter()`, `choose_one()` (resolution-time choice for non-targeting clauses), `special_summon_one()`, `destroyed_by_battle_condition()`. |

Per card, in order:

1. Write `Scripts/cards/registry/<CardName>.gd` — `extends RefCounted`, no `class_name`
   (77 of them would pollute the global class list; the loader loads by path).
   Declare `const CARD_NAME := "..."` and `func effects() -> Array`, with **one
   `EffectDef.new(...)` per official effect clause**, quoting the verified official text.
2. Write `Tests/cards/<CardName>Tests.gd` with `const CARD_UNDER_TEST := "..."`, a
   `class_name`, and a `static func run() -> TestCase`. Cover every clause **positively
   and negatively** — the negatives are where the value is.
3. Register the suite in `Scripts/tests/RunTests.gd` under the per-card section.
4. Re-run `--import` (a new `class_name` is not visible until the class cache is
   rebuilt — see the reminders below), then the suite.
5. Only once it passes: `python Tools/build_matrix.py`. The counts are computed, never
   written by hand.

Cards are done in **mechanic** groups, not alphabetically. Batches completed so far:

* **Batch 1 — the 9 vanilla Normal Monsters.** No registry files; see design decision 13.
* **Batch 2 — the resolution-time Special Summon family**: `Monster Reborn`,
  `Silver's Cry`, `Kaibaman`, `Dragonic Tactics`, `One for One`. Between them they
  introduced targeting at activation, "either GY", the self-Tribute cost, the two-Tribute
  cost, the send-from-hand cost, Deck Summons, and player-chosen summon positions.
* **Batch 3 — Continuous-Trap revival, summoning procedures, and the first Equip group**:
  `Birthright`, `Call of the Haunted`, `Hieratic Dragon of Tefnuit`, `Inari Fire`, `Ranryu`,
  `Nefarious Archfiend Eater of Nefariousness`, `Gagagashield`, `Rider of the Storm Winds`.
  Between them they introduced the Equip subsystem, destruction prevention and replacement,
  the "control limit", persistent per-card facts, and the first real use of the summoning
  procedure path.
* **Batch 4 — the remaining Continuous Traps and the Continuous Spell**:
  `Castle of Dragon Souls`, `Fiendish Chain`, `Five Brothers Explosion`,
  `Sealing Ceremony of Suiton`, `Wonder Balloons`. Between them they introduced continuous
  NEGATION and the two-pass recompute, banish as a COST (as distinct from banish as an
  effect), a variable-size cost, a cost payload readable at resolution, a turn-scoped ATK
  modifier that outlives its source, effect damage and LP gain, the control limit on a
  Spell/Trap, and the first real consumer of the counter engine. This batch **completes the
  pool's Continuous Spell/Trap group**.

The batch to do next is spelled out under **"The NEXT batch (batch 5)"** above.

Primitives added by batch 2, in `Scripts/cards/EffectPrimitives.gd` — reuse these rather
than re-inventing them: `cards_in()`, `cards_in_either_graveyard()`, `monster_of_level()`,
`monster_named()`, `revivable_monster()`, `choose_n()`, `choose_face_up_position()`,
`special_summon_one_any_position()`, `special_summon_target()`, `surviving_target()`,
`pay_tribute_cost()`, `pay_send_to_gy_cost()`, `record_cost()`.

Primitives added by batch 3: `monster_with_stats()`, `event_is_leaving_the_field()`,
`event_is_destruction_of()`, `event_is_phase_change_to()`, `link_revived_monster()`,
`revived_monster()`, `clear_revival_link()`, `revive_target_in_attack_position()`,
`destroy_linked_monster()`, `destroy_self()`, `controls_no_other_copy()`,
`controls_face_up_monster_of_race()`, `summoned_this_way_this_turn()`,
`special_summon_self()`, `set_atk_and_def()`, `equip_source_to_target()`,
`equipped_host()`. Test-side: `TestFixtures.interferer()` and
`TestFixtures.activate_card()`.

Primitives added by batch 4: `pay_banish_cost()`, `pay_send_any_number_to_gy_cost()`,
`cost_card_count()`, `banish_target()`, `gain_atk_until_end_of_turn()`,
`event_is_sent_to_gy_from_face_up_field()`, `event_caused_by_effect_of()`,
`is_continuous_spell_or_trap()`, `continuous_spell_traps_controlled()`,
`continuous_spell_traps_in_graveyard()`, `link_afflicted_monster()`, `afflicted_monster()`,
`clear_afflicted_link()`. Test-side: `TestFixtures.activate_effect()` (for an
`ACTIVATE_EFFECT` action, which `activate_card()` does not find) and the `interferer()`
`"send_to_gy"` mode.

No placeholders, and never silently drop a clause: `ChainManager` fails loudly on a
missing `resolve()` and `CardRegistry` rejects a chain-starting effect that has none.

**Do not start presentation work** (3D arena, holographic monsters, summon/attack
animations, particles, audio, cinematic camera, UI polish). Those are Phases 7–10.

### Reminders that cost time — read before writing a test

* **Use `Tools/run_tests.ps1`**, not the raw Godot command. See §4 for the two reasons.
* Run `--import` after adding any `class_name` script, or Godot will not register it —
  and run it as its **own command, before** the test run. Chaining `--import` and the test
  run in one shell invocation is not enough: the parse check still sees the stale
  `.godot/global_script_class_cache.cfg` and fails with
  `Identifier "<YourNewClass>" not declared in the current scope`, which looks like a
  syntax error in a file that is actually fine. Confirm with:
  `Select-String .godot\global_script_class_cache.cfg -Pattern YourNewClass`.
* Never use `:=` where the right-hand side is a `Variant` (an untyped `Array` element such
  as `some_def.effects[0]`, or a function declared `-> Variant` such as
  `TestFixtures.find_action()`). It is a hard compile error, and a failed compile takes
  the whole dependent class down with it. This bites **transitively**: `find_action()`
  returns a Variant, so `var a = find_action(...)` then `var b := a.with_choices({...})`
  fails too, even though `with_choices()` is typed. It cost a parse-check cycle in
  batch 2.
* `EffectPrimitives.choose_n()` / `choose_one()` do **not** ask when the number of
  candidates equals the number required — there is nothing to decide. A test that
  asserts on the offered option list must therefore set up **more** candidates than the
  clause consumes, or the prompt never happens and the assertion fails confusingly.
* `ScriptedController`'s default answer for a selection is "the first `min_count`
  options", which is rarely the card a test means. Any test that cares which card pays a
  cost must `queue_for(...)` it explicitly, and should then assert
  `controller.errors == []` — that is what proves the queued answer went to the prompt
  the test thought it did.
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
* `TestFixtures.activate_card()` finds an `ACTIVATE_CARD` action only. An effect activated
  from a card already on the field is an `ACTIVATE_EFFECT` action — use
  `TestFixtures.activate_effect()`.
* **`get_legal_actions(pid)` returns nothing unless the engine is OPEN *and* `pid` is the turn
  player.** An interferer meant to fire in an open game state must therefore belong to the TURN
  PLAYER; a Chain Link 2 goes through `get_legal_responses()` instead. Both mistakes cost a
  cycle in batch 4 and neither fails loudly — the helper just returns false.
* **`GameState.destroy()` correctly refuses a card that is not on the field**, so
  `interferer(..., "destroy")` cannot move a card out of the hand. Use the `"send_to_gy"` mode.
* **Continuous effects are recomputed at engine timing points, not when a test arranges the
  board.** A baseline assertion about a continuous effect taken straight after
  `TestFixtures.give_*` reads the un-recomputed value. Run one explicit
  `ContinuousEffects.new(state).recompute()` first, or take an engine action.
* A phase change is a box-E declaration first: after `submit_action(ENTER_BATTLE_PHASE)`
  the phase has **not** changed yet if the opponent holds a response.

**Where the rules live:** every subsystem above must cite `Research/RULES_SPEC.md` section
numbers in comments, and those trace to `RULES_SOURCES.md` S1–S4. Do not re-derive rules.

**Card implementation (Phase 5)** goes in `Scripts/cards/registry/<CardName>.gd`, one file
per card, each declaring `const CARD_NAME := "..."` and one `EffectDef.new(...)` per official
effect clause — `Tools/build_matrix.py` reads those two markers to compute the implementation
matrix, so the matrix can never over-report. Two additions from batch 1/2:
a **vanilla Normal Monster has no registry file** and is counted as implemented from the
card database's `is_normal` flag alone (design decision 13), and a suite covering a whole
mechanic group declares `const CARDS_UNDER_TEST := ["…", "…"]` instead of the singular
marker. An interaction suite declares **neither**, so a card is only ever counted as
TESTED because it has its own suite.

**Re-verify after any change:**

```bash
python Tools/build_card_db.py && python Tools/build_matrix.py
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 SmokeCheck
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests
```

**Do not:** re-run the 251-image identification; re-fetch the 77 card pages (they are cached
in `Data/generated/konami_raw/`); re-derive the rules from memory; or use Graphify for
GDScript navigation (unsupported — see §2).

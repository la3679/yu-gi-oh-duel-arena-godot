# PROJECT_STATE — Duel Arena

> Persistent resume file. A new Claude Code session should read **this file first**,
> then read only the targeted files named in §8. Do **not** recursively reread the repository.

**Last updated:** 2026-08-12
**Current phase:** Phase 4 — Core rules engine (Phases 0–3 complete)
**Overall status:** IN PROGRESS — **not** acceptance-complete

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

Last verified run (2026-08-12):

```
godot --headless --path <project> --import                     -> exit 0, no script parse errors
godot --headless --script res://Scripts/tests/SmokeCheck.gd    -> SMOKE CHECK: PASS, exit 0
  card definitions: 37 monsters / 18 spells / 22 traps
  deck1.json -> 'Blue-Eyes Dragon Guard' 40 cards
  deck2.json -> 'Fairy-Tail Tribute Guard' 40 cards
```

SmokeCheck currently asserts: RNG determinism (same seed → same sequence; different seed →
different sequence; deterministic 40-card shuffle), all 77 card definitions load with
non-empty official text and valid subtypes, both decks total exactly 40, Spell Speed
classification, destruction-vs-sent-to-GY semantics, and that stat modifiers do not leak
into `CardDef`.

**This is a load/determinism check, not the rules test suite.** The full suite (Phase 6)
does not exist yet.

---

## 5. Phase progress

| Phase | Description | Status |
|---|---|---|
| 0 | Inspect data, install/verify Godot + Graphify | **COMPLETE** |
| 1 | Authoritative TCG rules research | **COMPLETE** |
| 2 | Per-card official text + rulings research (77 cards) | **COMPLETE** |
| 3 | Architecture / scaffolding + Graphify index | **COMPLETE** |
| 4 | Core rules engine | **IN PROGRESS** |
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
│   │   └── CardInstance.gd            per-copy runtime state, stats, counters, usage
│   └── tests/SmokeCheck.gd            headless load/determinism check
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
`Research/RULES_COMPLIANCE_MATRIX.md`, `Reports/TEST_RESULTS.md`, `Reports/RULES_AUDIT.md`,
`Reports/ASSET_PROVENANCE.md`, `Reports/FINAL_ACCEPTANCE.md`. These are deliberately deferred
until they can contain real results rather than placeholders.

---

## 7. Blockers

None.

---

## 8. Next step and architecture map for resumption

**Immediately next (Phase 4):** build the core rules engine in `Scripts/engine/` and
`Scripts/rules/`, in this order:

1. `Scripts/engine/GameEvent.gd` — the semantic event vocabulary from master prompt §63.
2. `Scripts/engine/GameState.gd` — authoritative state (master prompt §7A): players, LP,
   turn, phase, all zones, chain state, pending triggers, per-turn counters, RNG, win state.
   Must expose `get_visible_state(viewer_id)` for hidden-information filtering.
3. `Scripts/engine/DuelLog.gd` — action/replay log (master prompt §8).
4. `Scripts/cards/EffectDef.gd` — the effect definition record (master prompt §43), carrying
   effect id, type, Spell Speed, activation locations, timing, condition/cost/target/resolve
   callables, once-per-turn key, and `damage_step_permission`.
5. `Scripts/rules/ChainManager.gd` — chain build/resolve, implementing `RULES_SPEC.md §4`.
6. `Scripts/rules/TurnFlow.gd` — the Fast Effect Timing state machine, boxes A–E,
   implementing `RULES_SPEC.md §3` literally.
7. `Scripts/rules/SummonRules.gd`, `BattleRules.gd`, `DamageStep.gd`, `ContinuousEffects.gd`.
8. `Scripts/engine/DuelEngine.gd` — the public API from master prompt §68:
   `get_legal_actions`, `get_legal_responses`, `submit_action`, `get_pending_decision`,
   `submit_decision`, `get_visible_state`, `get_public_log`.

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

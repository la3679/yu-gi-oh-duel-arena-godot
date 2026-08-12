# PROJECT_STATE — Duel Arena

> Persistent resume file. A new Claude Code session should read **this file first**,
> then use Graphify targeted queries (see below) to recover architectural context.
> Do **not** recursively reread the whole repository.

**Last updated:** 2026-08-12
**Current phase:** Phase 1 — Rules research (Phase 0 complete)
**Overall status:** IN PROGRESS — not acceptance-complete

---

## 1. Fixed project facts

| Item | Value |
|---|---|
| Project root | `C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame` |
| Authoritative read-only input | `C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles` |
| Master specification | `PlayerFiles\CLAUDE_DUEL_ARENA_MASTER_PROMPT_v3_GRAPHIFY.md` |
| Deck 1 | Blue-Eyes Dragon Guard — 40 Main Deck cards, 39 unique names |
| Deck 2 | Fairy-Tail Tribute Guard — 40 Main Deck cards, 39 unique names |
| Shared card between decks | `Shining Angel` (1 copy in each deck) |
| **Total playable deck slots** | **80** |
| **Total unique playable cards** | **77** |
| Extra Deck | none in either deck |
| Link Monsters | 0 |
| Pendulum Monsters | 0 |
| Cards with quantity 2 | `Mirage Dragon` (Deck 1), `Metaphys Armed Dragon` (Deck 2) |

The 251-image identification pass is **complete and must not be redone**.

### How the 77 was computed
`Deck 1\Deck_1.csv` = 39 data rows, quantities sum to 40.
`Deck 2\Deck_2.csv` = 39 data rows, quantities sum to 40.
Union of the two name sets = 77 (39 + 39 − 1 shared name).
Script: `Tools/enumerate_cards.py`.

---

## 2. Environment

### Godot

| Field | Value |
|---|---|
| Already installed before this project | **NO** |
| Action taken | Installed during Phase 0 |
| Installation method | `winget install --id GodotEngine.GodotEngine --version 4.7.1 --source winget --scope user` |
| Package publisher | Godot Engine (`https://godotengine.org/`) |
| Installer source verified | `https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_win64.exe.zip` |
| Installer SHA256 verified by winget | `c7a289051eaefb460b0106b60e9cd5bee0ef55fd102dcb2bed1eb356cf3d90a1` |
| **Verified version string** | `4.7.1.stable.official.a13da4feb` |
| **Executable path** | `C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe` |
| PATH alias | `godot` (via `%LOCALAPPDATA%\Microsoft\WinGet\Links`) — requires a fresh shell |
| Headless verified | YES — `--headless --version` returns `4.7.1.stable.official.a13da4feb` |
| Admin privileges required | NO (user-scope install) |
| Security protections disabled | NONE |
| Build channel | stable (not alpha/beta/rc/nightly/fork) |
| Language | GDScript |

Confirmed latest stable on the official download page at execution time: **4.7.1** (released 2026-07-14).

**Canonical invocation used by scripts/tests** (absolute path, because `godot` alias needs a new shell):

```
"C:\Users\lovea\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" --headless --path "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame"
```

### Graphify

| Field | Value |
|---|---|
| Identified official tool | **Graphify** — codebase → queryable knowledge-graph skill for AI coding agents |
| PyPI distribution name | `graphifyy` (note the double `y`) |
| Console command | `graphify` |
| Owner / publisher | Graphify Labs — author Safi Shamsi (`captainturbo`) |
| Official source URL | https://github.com/Graphify-Labs/graphify |
| Official site | https://graphify.com |
| PyPI page | https://pypi.org/project/graphifyy/ |
| License | Apache-2.0 |
| Already installed | **YES** — version 0.9.25 was present via pyenv Python 3.11.9 |
| Action taken | Upgraded to latest: `pip install --upgrade graphifyy` |
| **Verified version** | **0.9.41** (`graphify --version`) |
| Command path | `C:\Users\lovea\.pyenv\pyenv-win\shims\graphify.bat` |
| Verification command | `graphify --version` → `graphify 0.9.41` |
| **Local-only mode** | **YES** — `graphify extract <path> --code-only` uses local tree-sitter AST parsing with no API key and sends nothing externally |
| Repository indexed | NO — pending (Phase 3, after scaffold has real source) |
| Indexed root | `C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame` |
| Runtime dependency of the game | **NO — development tool only**, never referenced by exported game code |
| Current known issue | none |

**Identity disambiguation performed** (required by master prompt §2A): the installed `graphify`
command was traced to PyPI distribution `graphifyy`, whose project metadata names
`github.com/Graphify-Labs/graphify` and describes exactly the required capability set
(tree-sitter AST codebase graphs, `query` / `affected` / `path` / `explain` / `god-nodes`
navigation, agent-context token reduction). No similarly named package was installed on
name match alone.

**Planned index command** (local-only, no LLM backend, no upload):

```
graphify extract "C:\Users\lovea\Pictures\Yu Gi Oh\PlayerFiles\DuelArenaGame" --code-only --no-cluster
```

**Planned exclusions** — via `.graphifyignore` at project root:
`.git/`, `build/`, `.godot/`, `Assets/cards/`, `Data/card_art/`, `Data/generated/`,
`*.import`, `*.exe`, `*.zip`, `*.pck`, `graphify-out/`, and the original 251-photo
collection (which lives outside the project root and is therefore never in scope).

### Other tooling present

| Tool | Version |
|---|---|
| winget | v1.29.280 |
| git | 2.42.0.windows.2 |
| Python | 3.11.9 (pyenv-win) |
| Node | v22.19.0 |
| npm | 11.6.0 |

### Connectivity

| Check | Result |
|---|---|
| Internet access | **WORKING** |
| Official Konami rulebook portal (`yugioh-card.com/en/rulebook/`) | **REACHABLE** |
| Official Konami Card Database (`db.yugioh-card.com`) | **REACHABLE** — returns official card text |
| Godot official download page | **REACHABLE** |
| PyPI | **REACHABLE** |

---

## 3. Graphify usage contract for future sessions

Once `graphify-out/graph.json` exists, prefer these over broad file reads:

```
graphify query "where is chain resolution implemented"      # BFS over the graph
graphify affected "ChainManager" --depth 2                  # reverse deps before editing
graphify path "GameState" "BattleResolver"                  # how two systems connect
graphify explain "EffectRegistry"                           # node + neighbours
graphify god-nodes --top 10                                 # architectural hubs
graphify update "<project root>"                            # refresh after major changes
```

Rule: query the graph → identify the smallest relevant file set → read only those files.
Never dump the whole graph into context.

---

## 4. Phase progress

| Phase | Description | Status |
|---|---|---|
| 0 | Inspect data, install/verify Godot + Graphify | **COMPLETE** |
| 1 | Authoritative TCG rules research | IN PROGRESS |
| 2 | Per-card official text + rulings research (77 cards) | NOT STARTED |
| 3 | Architecture / scaffolding + Graphify index | PARTIAL (directory tree + `project.godot` created) |
| 4 | Core rules engine | NOT STARTED |
| 5 | Card effect library | NOT STARTED |
| 6 | Automated tests | NOT STARTED |
| 7 | Basic playable UI | NOT STARTED |
| 8 | Arena / presentation | NOT STARTED |
| 9 | Local privacy UX | NOT STARTED |
| 10 | Asset polish | NOT STARTED |
| 11 | Full acceptance | NOT STARTED |

### Gates

| Gate | Status |
|---|---|
| A — Research complete | NOT MET |
| B — Core engine complete | NOT MET |
| C — Card library complete | NOT MET |
| D — Playable prototype | NOT MET |
| E — Presentation complete | NOT MET |
| F — Final acceptance | NOT MET |

---

## 5. Files created so far

```
DuelArenaGame/
├── project.godot                 Godot 4.7 project (config_version=5)
├── PROJECT_STATE.md              this file
└── <empty scaffold directories per master prompt §1>
```

---

## 6. Blockers

None.

---

## 7. Next step

Phase 1: fetch and record the current official TCG rulebook + Fast Effect Timing sources
into `Research/RULES_SOURCES.md`, then write `Research/RULES_SPEC.md`.

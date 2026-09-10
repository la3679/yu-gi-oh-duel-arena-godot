# PROJECT_STATE — Duel Arena

> Persistent resume file. A new Claude Code session should read **this file first**,
> then read only the targeted files named in §8. Do **not** recursively reread the repository.

**Last updated:** 2026-09-09 (batch 16 complete)
**Current phase:** **Phase 5 — the card effect library.** Phases 0–4 are complete and
Gate B (the generic rules engine) is MET; nothing in Phase 4 needs revisiting.

---

## 0. READ THIS FIRST — the CARD IMPLEMENTATION PHASE is COMPLETE (77 / 77)

**Batches 1–18 are complete. Nothing in batch 18 is partial or unverified. There is no card
left to implement.**

| Batch 18 unit | Status |
|---|---|
| 0 — **R5** and **R14** research, and the batch-18 plan, committed BEFORE any code | **COMPLETE** — both CLOSED |
| A — the Chain-Link **substitution** gate + `RULES_SPEC.md` **§10.11**, in `ChainTests` (27 → **72**), green BEFORE the card | **COMPLETE** |
| A — `Fairy Tail - Sleeper` (`FairyTailSleeperTests`, **113**) | **COMPLETE** |
| B — the **negation-immunity** gate + the **turn-player activation** route + `RULES_SPEC.md` **§19**, in `NegationImmunityTests` (**72**), green BEFORE the card | **COMPLETE** |
| B — `Hidden Springs of the Far East` (`HiddenSpringsOfTheFarEastTests`, **103**) | **COMPLETE** |

**Measured at this checkpoint: 10087 passed / 0 failed across 96 suites; SmokeCheck PASS; 0
`SCRIPT ERROR`; 77 / 77 implemented, 77 / 77 tested, 0 remaining** (counts computed by
`python Tools/build_matrix.py`, never written by hand). ObjectDB at exit: **347433** — +13093 over
batch 17, ~187 per duel against the 187 measured in each of batches 16 and 17, i.e. the known
linear behaviour and **not** a regression. **Previous clean HEAD:** `01fe26f` (unit A).

### ✅ CARD IMPLEMENTATION PHASE COMPLETE

**All 77 cards of the V1 pool are implemented and tested.** Every card's official text was
verified against the live Konami database; every ruling that blocked a card has been settled from
primary Japanese sources and CLOSED. **The next phase is NOT a card phase** — it is full
integration, scripted duels and backend acceptance, and it is specified in §8 under
**"NEXT PHASE — integration, scripted duels, backend acceptance"**.

**Do not start that phase in the same session that finished this one.**

### Every one of the previous checkpoint's 9752 assertions passes — with ONE documented retargeting

10087 − 9752 = **335** = 113 (`FairyTailSleeperTests`) + 103 (`HiddenSpringsOfTheFarEastTests`)
+ 72 (`NegationImmunityTests`) + 45 (`ChainTests`, 27 → 72) + 2 (`NormalMonsterTests`).

**The one changed assertion, stated plainly because it is the only one in eighteen batches:**
`NormalMonsterTests` carried a non-vacuity guard asserting `unimplemented.size() > 0`. It **failed
in batch 18 for the best possible reason — the list is now empty.** It was not deleted and not
weakened: what it protected (that the checks beside it examined a non-empty population) is now
asserted **directly**, against the counts of Effect Monsters and vanilla bodies, which is stronger
and does not expire. `unimplemented == []` records the completion in its place.

### §8's Damage Step warning was right EIGHT batches running — and this time it INVERTED

`Fairy Tail - Sleeper` clause ①: 「ダメージステップ中に条件を満たした場合でも発動できます。」 — it **CAN**
be activated during the Damage Step. Seven previous cards' supplements each carried a Damage Step
**restriction** the English omitted; this one carries a **permission**, and taking the engine's
default would have been **wrong**. It is not a quirk: the ordinary way a Flip monster is turned
face-up is by being attacked. Clause ② carries the usual refusal, and the two are asserted against
the same gate at the same sub-step so neither answer can be the gate replying uniformly.

### §8 was wrong about SCOPE twice more — in BOTH directions, for the eighth batch running

* **optimistically:** §8 said `Fairy Tail - Sleeper` needed no research beyond its mechanism. The
  supplement and **four** Q&A entries settled six facts the English does not state — including
  which side of the field the card actually hits;
* **pessimistically, for the first time:** §8 called `Hidden Springs of the Far East` "three or
  four subsystems in one card" and led with **the Field Spell Zone**. The Field Zone, Main Phase 2,
  the LP gain and both once-per-turn shapes **all already existed**. Two things were new, not four.

**Treat every §8 scope claim as a hypothesis. It has now been wrong in eight consecutive batches.**

### The two facts worth carrying forward

**1. Substitution is a THIRD operation on a Chain Link** (`RULES_SPEC.md` **§10.11**). Not
activation negation, not effect negation: the card still activated, still occupies its link, still
resolves, and a Normal Spell still reaches the Graveyard as a **resolved** card. Only the text is
different.

> The replacement becomes the **substituted card's** text and is carried out by **its**
> controller — so a replacement worded "your opponent" means the opponent **of the substituted
> card's controller**. `Fairy Tail - Sleeper` therefore flips a monster on its **OWN** side.

That reads like a bug and is not; it is confirmed three ways (the supplement's 「自分フィールド」, Q&A
fid 9677's 「相手プレイヤーに…させる」, and the card being a FLIP monster for which re-arming clause ①
is the payoff). **And what survives a substitution is decided by one design decision:**
`ChainLink.effect` is deliberately **not** overwritten, so `_resolve_link()` still runs the card's
`activation_confirmed` clauses off its own definition. That is exactly why fid 8714's in-effect
restriction is replaced away while fid 19695's activation restriction survives — **both official,
both asserted, and opposite in outcome.**

**2. The eligible ACTIVATOR is not always the controller** (`RULES_SPEC.md` **§19.1**).
「お互いのプレイヤーは、自身のメインフェイズ２に…発動できます。」 The turn player may activate
`Hidden Springs of the Far East`'s effect **even when the opponent controls it**, and 「自分」
throughout that clause means *the player who activated it*. **This is NOT batch 17's mechanism:**
§12.4 routes a **decision during resolution** to a named player; this routes **eligibility to
activate**. Do not merge them.

A rules consequence that makes the card unusable for a whole turn, and is asserted: **Main Phase 2
is reachable only through the Battle Phase**, and the player who goes first has no Battle Phase on
turn 1 [S1 p.37] — so on turn 1 the first player has no Main Phase 2 and this effect cannot be
activated at all.

### Mutation testing: 35 mutations, ONE survivor, and it found a real gap

**Unit A: 16 mutations, 16 caught, zero survivors.** **Unit B: 19 mutations, 18 caught on the
first pass.** The survivor mattered:

> **M15** — removing the `activated_by_turn_player` check from
> `DuelEngine._activation_actions()` left the whole suite green. Nothing asserted that an
> **unmarked** effect on a foreign card stays unavailable, so an engine offering the turn player
> **every one of their opponent's effects** would have passed — a far worse bug than the one the
> marker enables.

A negative control was added and M15 is now caught. **Third batch running in which the mutation
pass found the weakness in the TESTS rather than the code.** It is not optional.

### The three protections are VACUOUS-PATH HAZARDS, and the suite is built around that

Each of `Hidden Springs of the Far East`'s protections is observable only when something is
actually trying to do what it prevents — "the Summon succeeded" is also what an engine that never
negates anything reports. **Every positive assertion in `NegationImmunityTests` is paired with a
control proving the same action IS negated, targeted or destroyed without the protection**, and
the negators are really **activated** rather than merely Set: activation is an *action*, not a
decision, and a `ScriptedController` never performs one on its own. That last point cost a full
debugging pass and is worth remembering.

### ObjectDB — the linear model holds for a FOURTH batch, and the FIX is still owed

**347433 at exit**, +13093 over batch 17's 334340, ~**187 per duel** against 187 (batch 17), 187
(batch 16) and 188 (batch 15). Nothing new is leaking. What remains is the **fix** — breaking the
reference cycle at the `DuelEngine` / `GameState` root — which **must land before Phase 7** and
which batch 18 again did not have room for and does not claim. **It is now the single highest
non-card priority.**

### Rulings

**R5 and R14 are CLOSED.** **R11, R12, R13, R15, R20 and R42 Part D remain CLOSED** and were not
reopened.

**No ruling that blocks a card remains open.** **R1 and R2 remain OPEN** and belong to cards that
are already implemented and tested; they are carried as recorded questions, not as blockers.

**There is no known-incorrect card left in the library.**

**R35 / `Mirage Dragon` was NOT re-checked against the `ja` locale.** Carried across **nine**
checkpoints unclaimed. Batch 18 did not have the room and does not claim it. **With no card unit
left to derail, this is now a cheap and obvious thing to close.**

---

## 0a. The record of batch 9 and batch 8 — COMPLETE

**Batches 1–8 are complete.** Every unit is done, tested and committed. Nothing is partial and
nothing is left UNVERIFIED.

| Batch 8 unit | Status |
|---|---|
| Unit A — the generic banish / temporary-removal gate (`BanishTests`, 158) | **COMPLETE** |
| `Interdimensional Matter Transporter` (`InterdimensionalMatterTransporterTests`, 175) | **COMPLETE** |
| The generic LP-payment-as-cost unit (`LifePointCostTests`, 109) | **COMPLETE** |
| `Judge of the Ice Barrier` (`JudgeOfTheIceBarrierTests`, 154) | **COMPLETE** |
| `Junk Blader` (`JunkBladerTests`, 73) | **COMPLETE** |
| The generic **Trap-Monster** gate (`TrapMonsterTests`, 192) | **COMPLETE** |
| `The Phantom Knights of Shadow Veil` (`ThePhantomKnightsOfShadowVeilTests`, 125) | **COMPLETE** |
| The generic **Battle-Phase-restriction** gate (`BattlePhaseRestrictionTests`, 53) | **COMPLETE** |
| `Runick Flashing Fire` (`RunickFlashingFireTests`, 123) | **COMPLETE** |

**Measured at the batch-8 checkpoint: 5280 passed / 0 failed across 62 suites; SmokeCheck PASS;
49 / 77 implemented, 49 / 77 tested, 28 remaining** (counts computed by
`python Tools/build_matrix.py`, never written by hand). **All 4787 assertions from the previous
checkpoint pass unchanged** — none was weakened, retargeted or deleted, and no existing suite
changed its count; the LP-cost suite is still exactly 109. ObjectDB at exit: **154223**.
**HEAD at checkpoint:** `8544fe3` (the last code commit; this commit records the hash).

Batch 8 completes the pool's **banishment group**, adds the pool's only **Trap Monster**, and
adds the only card that **restricts a future Battle Phase**. Each of the last two cards got its
**generic gate first**, written and passing before the card existed — the pattern that has now
paid off six times.

**Batch 9 is NOT started.** Its exact plan is in §8.

**Generic mechanics added by batch 8 — none left UNVERIFIED:**

* **Trap Monsters** (`RULES_SPEC.md §5.8`, **R33**) — `CardInstance.monster_identity` and its
  accessors (`become_monster()`, `clear_monster_identity()`, `has_monster_identity()`,
  `original_card_category()`, `current_level()`, `current_attribute()`, `current_race()`,
  `is_normal_monster()`), with `is_monster()` / `is_trap()` / `is_spell()` / `base_atk()` /
  `base_def()` answering from it. **The shared, immutable `CardDef` is never written to.**
  `GameState.move_card()` revokes the identity on every departure from a Monster Zone, in one
  place — deliberately NOT inside `on_leave_field()`, which never runs on the negated-Summon path;
* **a DESTINATION replacement** — `GameState.BANISH_WHEN_LEAVING_FIELD_KEY` +
  `EffectPrimitives.banish_when_it_leaves_the_field()`. Changes only where a card goes, never the
  reason, so a redirected destruction still fires `CARD_DESTROYED`;
* **"skip your next Battle Phase" as authoritative turn state** (`RULES_SPEC.md §2.4`, **R32**) —
  `PlayerState.battle_phase_skips`, `GameState.impose_battle_phase_skip()` /
  `has_pending_battle_phase_skip()` / `consume_battle_phase_skip()`, the
  `BATTLE_PHASE_SKIP_IMPOSED` / `BATTLE_PHASE_SKIPPED` events, and
  `TurnFlow._spend_battle_phase_skip()`. A genuinely **third** lifetime;
* **a gain with no printed duration** — `EffectPrimitives.gain_atk_and_def_permanently()`;
* **a Special Summon to the EXTRA Monster Zone** — a `to_zone` on
  `SummonRules.begin_special_summon()` / `complete_summon()` / `DuelEngine.special_summon()`,
  and `PlayerState.monsters()` now counting the Extra Monster Zone;
* `EffectPrimitives.extra_deck_monsters()` / `special_summon_from_extra_deck()` /
  `skip_your_next_battle_phase()` / `trap_monster_identity()` /
  `special_summon_self_as_trap_monster()`; test-side `TestFixtures.trap_monster()`;

**and, from earlier in the batch:**

* the whole banish / temporary-removal subsystem (`Enums.BanishDuration`,
  `MoveReason.RETURNED_FROM_BANISHMENT`, `GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT`,
  `GameState.banish_leases` and its six methods, `EffectPrimitives.banish_target_temporarily()`
  / `banish_top_of_deck()` / `own_monsters()` / `surviving_own_monster_target()`);
* **paying LP as an activation cost** — `EffectPrimitives.LP_COST_KEY` / `LP_COST_REASON`,
  `can_pay_life_points_cost()`, `pay_life_points_cost()`, `life_points_paid_in()`,
  `activation_paid_life_points()`, `cost_event_paid_life_points()`. "Paid LP" is a property of
  an **activation**, never of an LP delta. **No engine change was needed to carry it**:
  `_perform_activation()` already copied `ctx.cost_payload` into both the `COST_PAID` event and
  the `ChainLink`, so the payment rides the cost channel batch 4 built;
* **a CONTINUOUS clause that reacts to a discrete event** — `EffectDef.respond_to_event` +
  `ContinuousEffects.respond_to()`, dispatched from a non-reentrant queue in `DuelEngine`;
* **archetype membership by quoted name** — `name_matches_archetype()`, `archetype_monster()`,
  `controls_archetype_monster()`;
* **`chain_link_below()`** — negation that does not care what kind of card the link below is.

New rulings: **R30** (five parts), **R31** (two parts — part B rests on weak community evidence
and is unreachable in the V1 pool), **R32** (three parts, honest per-part confidence: A
MEDIUM-HIGH, B MEDIUM, C LOW-MEDIUM and never-live) and **R33** (HIGH).
New spec sections: **`RULES_SPEC.md §8.3`, `§10.4`, `§5.7`, `§5.8`**, and the rewritten **`§2.4`**.

**No engine defect was found in the whole of batch 8** — every gate was written and green before
the card that needed it, so each card landed on an already-exercised API. Six test-side defects
were found and fixed across the batch; they are written up in `Reports/TEST_RESULTS.md`. Two from
this session are worth carrying forward because they are the exact shapes §12 warns about:

1. a `TrapMonsterTests` negation test that used the **wrong negator fixture** for a Graveyard
   Ignition *and* drove the Chain through a helper that auto-passes the response window — it
   would have passed against a broken implementation, and was caught by its **own path
   assertion** on `EFFECT_NEGATED` rather than by its conclusions;
2. a shape assertion reading `EffectDef.optional`, which does not exist (the field is
   `optionality`), producing a **`SCRIPT ERROR` that aborted the test after its passing
   assertions** — the same class as batch 8's earlier `copies_total` access.

**Both are why the run is checked for `SCRIPT ERROR` lines and not for `RESULT: PASS` alone.**
The only stderr in a clean run is the **two intentional** `push_error` lines from `ChainTests`
and `ContinuousTests`.

---

**Phase 5 progress (batch 7 and earlier, kept for the record):** **Batch 7 is COMPLETE — all four units.**
Unit A built the generic **movement / excavation gate** (`MovementTests`, written and passing
before any batch-7 card) and closed two live engine defects in the movement API; unit B added
`Compulsory Evacuation Device`, `Kaiser Glider` and `A Wingbeat of Giant Dragon`; **unit C** added
`Phoenix Wing Wind Blast`, `Spiritual Wind Art - Miyabi`, `Chain Detonation` and `Chain Healing`;
**unit D** added `Crystal Seer` — **44 / 77 implemented, 44 / 77 tested, 33 remaining**.
Batch 7 completes the pool's **movement group**: every card in the V1 pool that returns a card to
the hand, places one on the Deck, shuffles one in, or excavates is implemented and tested.
**Nothing in batch 7 is partial or unverified, and §7 carries no open engine gap.**
**Measured suite: 4118 passed / 0 failed across 53 suites; SmokeCheck PASS.**
**Units C and D found NO engine defect** — the unit-A gate had already flushed the movement API's
two real defects out before any card depended on it. One new ruling was recorded: **R29**.
**Batch 8 is PARTIAL — see §0 above**; the remainder is specified in §8.

The description of batch 6 below is unchanged and kept for the record: **batch 6** closed the
Flip Summon negation engine gap and added `Aussa the Earth Charmer`, `Eria the Water Charmer`,
`Wynn the Wind Charmer` and `Enemy Controller` — 36 / 77 implemented and tested — completing the
pool's **control-change group**, and completing `Champion's Vigilance`, every part of whose
printed text is now reachable.

The description of batch 5 below is unchanged and kept for the record: batch 5 added
`Apprentice Magician`, `Kunai with Chain`, `Fairy Tail - Rella` and `Champion's Vigilance` —
32 / 77 implemented and tested — completing the pool's **Equip group** (all four equippers) and
its **single Counter Trap**.

The description of batches 1-4 below is unchanged and kept for the record:
batches 1-4 are complete — the registry and effect primitives,
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
**HEAD at checkpoint:** `2ae1298` (Phase 5 batch 7 units C and D — batch 7 COMPLETE).
**Measured suite at checkpoint:** **4118 passed / 0 failed** across **53 suites**
(1056 core rules + 3016 per-card + 46 interaction); SmokeCheck **PASS**.
**Every assertion from the previous checkpoint passes unchanged.** Batch 7 changed no existing
test expectation at all: it only added suites, plus two new generic tests appended to
`MovementTests` (194 → **210**), which grew that suite rather than rewriting any part of it.
Per-suite detail and the honest not-yet-covered list live in `Reports/TEST_RESULTS.md`.

---

## 1. Fixed project facts

| Item | Value |
|---|---|
| Project root | `<repo>` |
| Authoritative read-only input | `<repo-parent>` |
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
| **Executable path** | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe` |
| PATH alias | `godot` (needs a fresh shell); scripts use the absolute path |
| Headless verified | YES |
| Admin required / security disabled | NO / NONE |
| Language | GDScript |

**Canonical commands**

```bash
# import / parse check
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe" --headless --path "<repo>" --import

# run a headless script
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe" --headless --path "<repo>" --script res://Scripts/tests/SmokeCheck.gd
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
| Command path | `%LOCALAPPDATA%\...\pyenv-win\shims\graphify.bat` |
| **Local-only** | **YES** — indexed with `--code-only`, local tree-sitter AST, no API key, **nothing uploaded** |
| Repository indexed | **YES** |
| Indexed root | `<repo>` |
| Index result | 37 nodes, 75 edges, from 6 Python tool files |
| Exclusions | `.graphifyignore` at project root |
| Last index refresh | 2026-08-12 |
| Runtime dependency of the game | **NO — development tool only** |

**Index / refresh command**

```bash
graphify extract "<repo>" --code-only --no-cluster
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

> **The current measured numbers are in §0 above: 10087 / 10087 across 96 suites, SmokeCheck
> PASS, 0 `SCRIPT ERROR`, 77 / 77.** The batch-4 run reproduced below is kept only as a historical record of the format;
> `Reports/TEST_RESULTS.md` is the authoritative per-suite breakdown.

Historical run (2026-08-13, at commit `565ae0c` plus the Phase 5 batch-4 work):

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

### Defects the Phase 5 batch-8 work caught (unit A + the first card)

Three, in three different categories, **none of them a pre-existing engine defect** — the banish
subsystem is new this batch, so the two engine-side findings are defects in code written this
batch and caught before any card depended on it. Full write-up in `Reports/TEST_RESULTS.md`.

1. **`GameState.banish_temporarily()` dropped its `face_up` argument on the PERMANENT path**, so
   a face-down banishment silently became face-up — a card the rules keep hidden [S1 p.53] would
   have become public. Found by the gate on its first run, before any card existed. Nothing in
   the V1 pool banishes face-down, so only a generic assertion could ever have caught it.
2. **The lease recorded a `return_index` that nothing read** — the same shape as batch 5's
   `cannot_be_targeted` and batch 6's `CONTROL_CHANGED`. Found by re-reading the committed code,
   not by a test. **Removed rather than consumed**, and that direction matters: nothing in the
   rules reserves the Monster Zone slot a banished monster left, so consuming it would have
   encoded a rule that does not exist.
3. **A test-harness false pass.** The `Interdimensional Matter Transporter`
   rescue-from-destruction test put the interferer on the **non-turn player**, so
   `get_legal_actions()` returned nothing, the test took a fallback branch, and it passed while
   never building the two-link Chain it claimed to test. Rewritten so the Chain is real. The
   §8 reminder about `get_legal_actions()` is what identified it.

### Defects the Phase 5 batch-7 unit C+D tests caught

**No engine defect.** That is a result, not an omission: the unit-A gate had already flushed the
movement API's two real defects out (below) before any card depended on them, so the five cards
written in units C and D landed on an API that was already correct. One **test-harness** defect
was found and fixed — `TestFixtures.card_activation()` allows `FIELD_FACE_UP`, which a real Normal
Trap does not, so an already-activated synthetic spacer Trap was offered again from its own
face-up position, the engine never auto-passed that side, and a Chain built to an exact depth
stalled one link short. It produced a convincing wrong answer (Chain Link 2, 3 and 5 tests passing
while Chain Link 4 failed) rather than an error. Fixed in `TestFixtures.build_chain_to_depth()`;
no engine behaviour and no rules expectation was involved. Full write-up in
`Reports/TEST_RESULTS.md`.

### Defects the Phase 5 batch-7 unit A+B tests caught

Two **pre-existing engine defects** in the movement API, both live since it was written and both
found by the generic gate before any card relied on them, plus one defect in a card written this
batch. Full write-up in `Reports/TEST_RESULTS.md`.

1. **`RETURNED_TO_DECK_BOTTOM` did not place the card on the bottom of the Deck.**
   `move_card()` took the end of the Deck from a `deck_position` option that **no caller anywhere
   in the repository passed**, defaulting to `"top"` — so every bottom placement would have gone
   to the exactly-wrong end while the MoveReason claimed otherwise. The end is now derived from
   the reason itself (`Enums.deck_position_for()`), so the two can never disagree.
2. **`SHUFFLED_INTO_DECK` never shuffled the Deck.** It cleared `revealed_to`, so the
   hidden-information half was right, but the card was inserted on top and the Deck was left in
   its old order — the next draw returned it. `RulesQuestionTests` missed it because it only
   asserted the `revealed_to` half. `move_card()` now performs the shuffle for that reason.
3. **`Compulsory Evacuation Device` was written at Spell Speed 1.** `of_type()` derives Spell
   Speed from the EFFECT category (SS1 for everything but a Quick Effect), so a Trap's CARD-level
   Spell Speed [S1 p.44-45] must be stated — every other Trap in the registry does. Left as it
   was, the card would never have been offered in a response window.

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

* The run reports **`164444 ObjectDB instances were leaked at exit`** (measured at this
  batch-9-unit-A checkpoint; 154223 at batch-8-COMPLETE, 135266 at the partial batch-8
  checkpoint, 123104 before it, 113897 at batch 7, 97559 at units A+B, 85668 at batch 6, 74049 at
  batch 5, 61457 at batch 4). At **~44.6 per new assertion** this is the **fifth consecutive
  rise** and again the highest per-assertion figure so far. **No explanation may be recorded for
  it that has not been measured.** The superseded batch-8 note is kept below for the trend.

* Superseded: **`123104 ObjectDB instances were leaked at exit`**. At **~27.6 per new assertion**
  this was the highest per-assertion figure at the time,
  modestly above the previous high — reported as such rather than as "in band". The likely
  reading is that the two new suites build many small duels rather than that `banish_leases`
  retains anything, but **that is inference, not measurement**, and confirming it belongs to the
  characterisation task. It keeps growing
  purely with the number of duels the suite
  builds. It causes **no** test failures, hangs, memory pressure or unreliable results, so it was
  correctly not allowed to derail batch 5 — but it **must be characterised or fixed before Phase
  7**, when the UI keeps a single duel alive for a long session. These are RefCounted
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
| 5 | Card effect library (77 cards) | **COMPLETE** — **77 / 77** implemented and tested (batches 1-18 all complete). The next phase is integration / scripted duels / backend acceptance, specified in §8. |
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
| C — Card library complete | **MET** — 77 / 77 implemented and tested, 10087 assertions across 96 suites, 0 failures, SmokeCheck PASS, 0 `SCRIPT ERROR` |
| D — Playable prototype | NOT MET |
| E — Presentation complete | NOT MET |
| F — Final acceptance | NOT MET |

---

## 6. Files that exist

> **This tree is a SNAPSHOT and it LAGS.** It was last grown wholesale around batch 9/10 and
> batches 11 to 15 did not extend it card by card; the per-suite assertion counts in it are
> likewise frozen at that point (`DamageStepTests` reads 86 and is now 98, `HiddenInfoTests`
> reads 76 and is now 156, `OneForOneTests` reads 40 and is now 70). **Do not use it as the
> authority for what exists or for how large a suite is.** The authorities are the filesystem,
> `Scripts/tests/RunTests.gd` (which registers every suite explicitly, so a missing suite is a
> hard error), `Reports/CARD_IMPLEMENTATION_MATRIX.csv` for the card library, and
> `Reports/TEST_RESULTS.md` for the measured counts. It is kept because the ONE-LINE
> DESCRIPTIONS of what each file is for are still accurate and still useful.
>
> **Files added since the snapshot that are worth naming here** (batch 11 onward):
> `Scripts/cards/registry/` gained `VampiricKoala.gd`, `BackUpRider.gd`, `ChironTheMage.gd`,
> `BurstStreamOfDestruction.gd`, `StraightFlush.gd`, `StampingDestruction.gd`,
> `SpiritualFireArtKurenai.gd`, `SpiritualWaterArtAoi.gd`, `DamageCondenser.gd`, and — batch 13
> — **`Honest.gd`** (the pool's first monster effect activated FROM THE HAND, and its first Quick
> Effect inside the Damage Step), batch 14's **`WitchcrafterGolemAruru.gd`**, and batch 15's
> **`AHeroEmerges.gd`** (the pool's only effect whose choice is made at RANDOM by the opponent out
> of a hidden hand). `Tests/rules/` gained **`CostLegalityTests.gd`** (batch 13, the synthetic-card
> gate for `RULES_SPEC.md` §10.5) alongside `DeckAccessTests.gd`; batch 15's random-choice gate was
> **added to `HiddenInfoTests.gd`** rather than to a new file, for the reason batch 12 recorded.
> `Tests/cards/` gained the matching per-card suites including **`HonestTests.gd`** (125),
> **`WitchcrafterGolemAruruTests.gd`** (312) and **`AHeroEmergesTests.gd`** (197). `Scripts/tests/`
> holds the targeted runners `RunBatch12Tests.gd`, `RunBatch14Tests.gd` and **`RunBatch15Tests.gd`**.

```
DuelArenaGame/
├── project.godot                      Godot 4.7 project (config_version=5)
├── PROJECT_STATE.md                   this file
├── .gitignore  .graphifyignore
├── Research/
│   ├── RULES_SOURCES.md               source register (S1-S4) + hashes
│   ├── RULES_SPEC.md                  implementable rules contract (§1-§17)
│   ├── CARD_RULINGS.md                card research, discrepancies, R1-R42
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
│   │       ├── WonderBalloons.gd      the Continuous Spell: variable cost + Balloon Counters
│   │       ├── AussaTheEarthCharmer.gd  FLIP + target + take control while face-up (EARTH)
│   │       ├── EriaTheWaterCharmer.gd   the same, WATER — current text, "face-up" removed
│   │       ├── WynnTheWindCharmer.gd    the same, WIND
│   │       ├── EnemyController.gd       Quick-Play, two bullets: change battle position, or
│   │       │                            Tribute then take control until the End Phase
│   │       ├── CompulsoryEvacuationDevice.gd  the plainest bounce; targets any monster
│   │       ├── KaiserGlider.gd          conditional battle protection + GY bounce trigger
│   │       ├── AWingbeatOfGiantDragon.gd  non-targeting return + "and if you do" backrow wipe
│   │       ├── PhoenixWingWindBlast.gd   discard COST + place the target on TOP of the Deck
│   │       ├── SpiritualWindArtMiyabi.gd WIND Tribute COST + the BOTTOM of the Deck
│   │       ├── ChainDetonation.gd        500 burn + self-return by Chain Link position (R4)
│   │       ├── ChainHealing.gd           500 LP gain + the same self-return, its own first half
│   │       ├── CrystalSeer.gd            FLIP: excavate 2, add 1, place the other on the bottom
│   │       ├── JudgeOfTheIceBarrier.gd    the continuous LP-payment tax + two Ignition
│   │       │                              effects, each once per turn on the name
│   │       ├── JunkBlader.gd              banish a "Junk" monster as COST, +400 ATK
│   │       ├── ThePhantomKnightsOfShadowVeil.gd  the pool's only TRAP MONSTER: a Normal
│   │       │                              Trap that Special Summons itself as a monster
│   │       ├── RunickFlashingFire.gd       Quick-Play, two bullets + "skip your next
│   │       │                              Battle Phase" applied at ACTIVATION (R1)
│   │       ├── InterdimensionalMatterTransporter.gd  banish your own monster until the End
│   │       │                             Phase — the pool's only stated return timing
│   │       ├── MirageDragon.gd         one CONTINUOUS clause on the batch-9 unit-A gate
│   │       ├── SwordsOfRevealingLight.gd  three clauses, incl. the remains-on-field override
│   │       ├── MaidenWithEyesOfBlue.gd  two clauses sharing ONE once-per-turn allowance
│   │       ├── KaiserSeaHorse.gd       rules QUERY: counts as 2 Tributes for a LIGHT Summon
│   │       └── SoulExchange.gd         the lingering material-choice constraint (R39) +
│   │                                     the Battle Phase activation CONDITION
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
│       ├── RunChoiceConstraintTests.gd  single-suite entry point (targeted runs)
│       ├── RunSoulExchangeTests.gd      single-suite entry point (targeted runs)
│       └── RunTests.gd                entry point; a 0-assertion suite is a FAILURE
├── Tests/
│   ├── support/TestFixtures.gd        synthetic cards, duel builder, engine drivers
│   └── rules/
│       ├── EquipTests.gd        83 assertions (the Equip gate)
│       ├── ControlTests.gd      93 assertions (the CONTROL gate)
│       ├── MovementTests.gd    210 assertions (the MOVEMENT / EXCAVATION gate)
│       ├── BanishTests.gd      158 assertions (the BANISH / TEMPORARY-REMOVAL gate)
│       ├── LifePointCostTests.gd 109 assertions (the LP-COST gate)
│       ├── TrapMonsterTests.gd  192 assertions (the TRAP-MONSTER gate)
│       ├── BattlePhaseRestrictionTests.gd 53 (the BATTLE-PHASE-RESTRICTION gate)
│       ├── AttackRestrictionTests.gd 229 (the ATTACK-RESTRICTION / NEGATION gate)
│       ├── ChoiceConstraintTests.gd 137 (the MATERIAL-CHOICE-CONSTRAINT gate, §5.9)
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
│   ├── AussaTheEarthCharmerTests.gd     107  (the full Charmer clause enumeration)
│   ├── EriaTheWaterCharmerTests.gd       36
│   ├── WynnTheWindCharmerTests.gd        48
│   ├── EnemyControllerTests.gd          127
│   ├── CompulsoryEvacuationDeviceTests.gd  88
│   ├── KaiserGliderTests.gd              93
│   ├── AWingbeatOfGiantDragonTests.gd    87
│   ├── PhoenixWingWindBlastTests.gd     162
│   ├── SpiritualWindArtMiyabiTests.gd   150
│   ├── ChainDetonationTests.gd          168
│   ├── ChainHealingTests.gd             147
│   ├── CrystalSeerTests.gd              151
│   ├── InterdimensionalMatterTransporterTests.gd  175
│   ├── JudgeOfTheIceBarrierTests.gd      154
│   ├── JunkBladerTests.gd                 73
│   ├── ThePhantomKnightsOfShadowVeilTests.gd 125  (the pool's only Trap Monster)
│   ├── RunickFlashingFireTests.gd        123  (both bullets; bullet 2 never-live, R1)
│   ├── MirageDragonTests.gd              121
│   ├── SwordsOfRevealingLightTests.gd    122
│   ├── MaidenWithEyesOfBlueTests.gd      139
│   ├── KaiserSeaHorseTests.gd             57
│   ├── SoulExchangeTests.gd              174  (real pool; reuses the §5.9 gate fixture)
│   └── SpecialSummonInteractionTests.gd  46   (no card-under-test marker, on purpose)
├── Tools/                             Python research + data pipeline (dev only)
│   ├── run_tests.ps1                  headless test runner (parse-check + no pipe stall)
│   ├── enumerate_cards.py             deck CSVs -> card_pool.json
│   ├── fetch_official_cards.py        official Konami DB -> konami_cards.json
│   ├── diff_card_text.py              official vs saved text diff
│   ├── dump_official_text.py          human-readable card text dump
│   ├── build_card_db.py               -> Data/cards/cards.json + deck lists
│   └── build_matrix.py                -> Reports/CARD_IMPLEMENTATION_MATRIX.csv
├── Reports/CARD_IMPLEMENTATION_MATRIX.csv   77 rows, text verified, 54 implemented
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
| Flip Summon (declaration → response window → complete/negate) | **DONE+TESTED** | `SummonRules.begin_flip_summon()` / `_complete_flip_summon()`, `GameEvent.Kind.FLIP_SUMMON_DECLARED` | SummonTests, ChampionsVigilanceTests |
| **Change of CONTROL (owner vs controller, leases, durations, expiry)** | **DONE+TESTED** | `GameState.change_control()` / `control_leases` / `expire_control_leases()`, `Enums.ControlDuration` | ControlTests (93) |
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
| **Card MOVEMENT: return to hand / add to hand / Deck top / Deck bottom / shuffle into Deck** | **DONE+TESTED** | `GameState.move_card()`, `Enums.deck_position_for()` / `is_return_to_deck()`, `MoveReason.ADDED_TO_HAND`, `GameEvent.Kind.CARD_ADDED_TO_HAND` | MovementTests (194) |
| **REVEALING a hidden card without moving it** | **DONE+TESTED** | `GameState.reveal()`, `GameEvent.Kind.CARD_REVEALED` (private to one viewer, public to both) | MovementTests |
| **EXCAVATION** | **DONE+TESTED** | `Enums.Zone.EXCAVATED`, `GameState.excavate()` / `excavated_cards()`, `PlayerState.excavated`, `EffectPrimitives.excavate()` / `return_excavated()` | MovementTests |
| **A conditional destruction prevention that depends on the OTHER battling monster** | **DONE+TESTED** | `EffectPrimitives.battle_opponent_of()` reading `GameState.current_attacker` / `current_attack_target` at damage calculation | KaiserGliderTests |
| **Resolution-time target re-check across the whole FIELD** (not one named zone) | **DONE+TESTED** | `EffectPrimitives.surviving_field_target()` | MovementTests (210), PhoenixWingWindBlastTests, SpiritualWindArtMiyabiTests |
| **Resolution-time re-check of CONTROL for "1 card your opponent controls"** (ownership never consulted) | **DONE+TESTED** | `EffectPrimitives.surviving_opponent_field_target()`, `CARD_RULINGS.md` R29 | MovementTests, PhoenixWingWindBlastTests, SpiritualWindArtMiyabiTests |
| **A card reading its own CHAIN LINK POSITION** | **DONE+TESTED** | `EffectPrimitives.activated_chain_link_number()` / `return_self_by_chain_link()` reading `ChainLink.link_number`; `CARD_RULINGS.md` R4 | ChainDetonationTests, ChainHealingTests |
| **A resolving Spell/Trap that moves ITSELF off the field** (and is not then swept to the GY) | **DONE+TESTED** | `DuelEngine._cleanup_resolved_spell_traps()` skipping a card no longer on the field | ChainDetonationTests, ChainHealingTests |
| **EXCAVATION driven by a real card** | **DONE+TESTED** | `GameState.excavate()` consumed by `Crystal Seer`; the `revealed_to`-KEPT branch of design decision 11 | CrystalSeerTests |
| **BANISHMENT as a subsystem** (face-up vs face-down; from field / GY / hand / Deck; the top N of a Deck as a primitive distinct from excavate, draw, mill and search) | **DONE+TESTED** | `EffectPrimitives.banish_top_of_deck()`, `Enums.MoveReason.BANISHED`, `RULES_SPEC.md §8.3` | BanishTests (158) |
| **TEMPORARY removal with a stated return timing** (a LEASE, the same shape as `control_leases`) | **DONE+TESTED** | `Enums.BanishDuration`, `GameState.banish_leases` / `banish_temporarily()` / `end_banish_lease()` / `expire_banish_leases()`, `MoveReason.RETURNED_FROM_BANISHMENT`, `GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT`; `CARD_RULINGS.md` R30 | BanishTests, InterdimensionalMatterTransporterTests |
| **A return to the field that is NOT a Summon** (no Summon event, nothing pending for a Summon-negating card to answer) | **DONE+TESTED** | `end_banish_lease()` moving the card with its own MoveReason rather than through any Summon path | BanishTests, InterdimensionalMatterTransporterTests |
| **Resolution-time re-check of "1 face-up monster YOU control"** (zone + control + face, the mirror of R29) | **DONE+TESTED** | `EffectPrimitives.own_monsters()` / `surviving_own_monster_target()` | InterdimensionalMatterTransporterTests |

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
30. **A card can hold a counter only because some card TEXT says so, and that question belongs to
    the rules layer.** `GameState.COUNTER_CAPACITY_EFFECT_ID` is a pure CONTINUOUS rules query
    (design decision 20's shape), asked through `GameState.can_place_counter()`. It is
    deliberately **not** enforced inside `place_counters()`: a clause that places a counter on one
    specific named card does so on its own authority, which is what `Wonder Balloons` does and why
    it needs no capacity declaration. Only a clause that SEARCHES for a legal recipient asks the
    query. Widening `place_counters()` would break `Wonder Balloons`. `CARD_RULINGS.md` R21.
31. **`ActivationRules.legal_targets()` is the ONE place a targeting restriction is applied.**
    Both `DuelEngine._activation_actions()` (which publishes candidates) and `_choices_valid()`
    (which re-validates a submitted selection) pass through it, so one filter covers the offering
    and the validation path. `cannot_be_targeted` is read there and nowhere else, via
    `CardInstance.cannot_be_targeted()`. It deliberately does **not** reach attack target
    selection: an attack is neither a Spell Card nor an effect, and `BattleRules` builds its own
    list [S1 p.38]. Do not scatter the check into the per-card `legal_targets` callables.
32. **A heterogeneous target selection needs the clause's own validation.**
    `EffectDef.targets_valid` exists because candidate membership plus a count cannot express
    "exactly one of these two must be the attacking monster" — `Kunai with Chain` in "both" mode
    would otherwise accept two of your own monsters. It is optional and unset on every other
    card, which is the correct default.
33. **"Activate 1 or both of these effects" is modelled as separate ACTIONS, not a hidden mode
    flag.** `Kunai with Chain` declares three CARD_ACTIVATION EffectDefs — bullet 1, bullet 2, and
    both simultaneously — because the engine publishes legal actions and re-validates the
    submitted one (design decision 1). A mode that is not part of an action is a mode the engine
    cannot check. The same reasoning splits `Champion's Vigilance` into two EffectDefs: its two
    response categories have disjoint timings and resolve through different engine paths (a
    declared Summon in `Zone.IN_TRANSIT` versus a Chain Link), and collapsing them would either
    invent a Summon that has not happened or lose Summon negation. `CARD_RULINGS.md` R24.

34. **A Flip Summon declares like the other two routes, but does NOT use `Zone.IN_TRANSIT`.**
    All three Summon routes now split into begin/complete so a Summon negation can answer any of
    them. The Normal and Special routes park the monster in `IN_TRANSIT`; a Flip Summon must not,
    because its monster is already on the field and `IN_TRANSIT` is a DEPARTURE from the field —
    it would destroy the monster's Equip Cards and clear its per-instance state, neither of which
    a Flip Summon does. The monster therefore waits **face-down in its Monster Zone** for the whole
    window, which is also why a negated Flip Summon leaves it face-down (the position change WAS
    the Summon) and why no Flip effect triggers. The consequence for card code:
    **"is a Summon pending?" is `GameState.pending_summon_card_id`, never a scan of
    `PlayerState.in_transit`** — the scan answers for two routes out of three, and it silently
    answered "no" for a Flip Summon that had genuinely been declared. `CARD_RULINGS.md` R24.

35. **CONTROL is authoritative state, and it is never OWNERSHIP.** `GameState.change_control()` is
    the only channel. It moves a monster between the two players' Monster Zone arrays and rewrites
    `CardInstance.controller_id`; it never touches `owner_id`, which is what keeps
    `move_card()` sending the card to its OWNER's Graveyard, hand or Deck. Control is not a
    presentation property and must never be re-derived in the UI layer. `RULES_SPEC.md §5.6`
    [S1 p.52].

36. **A control change is not a `move_card()`.** The card does not leave the field, so
    `on_leave_field()` must not run, Equip Cards must not be destroyed, and `last_move_*` must not
    be rewritten to describe a move that did not happen. `_transfer_control()` does the array work
    directly for exactly this reason. `ControlTests :: a control change is not a MOVE` probes it
    with a real Equip Card on the stolen monster, which would die if this were ever "simplified"
    into a move.

37. **Every control change is a LEASE with an explicit end condition, and leases stack.**
    `Enums.ControlDuration` names the three durations the rules recognise; `GameState.control_leases`
    holds those in force, oldest first, per card. Ending a lease that is NOT the newest does not
    move the card — it hands its `from_controller` down to the next lease — so control still
    returns all the way to where it started rather than stopping at an intermediate controller.
    Expiry runs at exactly two named points and nowhere else: `DuelEngine._advance()` (the same
    cadence as the continuous recompute, but deliberately OUTSIDE `recompute()` because it is a
    state mutation rather than a derived flag) and `TurnFlow.enter_phase()` on entering the End
    Phase. **No timers, no polling, no per-card bookkeeping.** `CARD_RULINGS.md` R25.

38. **The end of the Deck comes from the MOVE REASON, never from a separate option.**
    `Enums.deck_position_for()` maps `RETURNED_TO_DECK_TOP` / `_BOTTOM` to the end, and
    `move_card()` overrides any caller-supplied `deck_position` for those reasons. The two
    cannot then disagree — which they did, silently and in the wrong direction, until batch 7.
    The `deck_position` option survives only for a `RULE` move that names no end.
    `RULES_SPEC.md §8.2`.

39. **"Shuffle it into the Deck" performs the shuffle inside `move_card()`.** It is one
    instruction, not "insert, and separately remember to shuffle": a caller that forgot left the
    card sitting deterministically on top with a MoveReason claiming otherwise. This is also the
    single place `revealed_to` is cleared for that reason, so the shuffle and the loss of
    information can never come apart. A top or bottom placement is **not** implemented by
    shuffling afterwards, and must never be. `RULES_SPEC.md §8.2, §12.1`, design decision 11.

40. **"Add to your hand" and "return to the hand" are two different moves.**
    `MoveReason.ADDED_TO_HAND` / `CARD_ADDED_TO_HAND` versus `RETURNED_TO_HAND` /
    `CARD_RETURNED_TO_HAND`. PSCT separates them and so does the engine: a bounce trigger must
    not see a search, and a search trigger must not see a bounce. Neither is a destruction and
    neither is a send to the Graveyard.

41. **`Zone.EXCAVATED` is not `Zone.IN_TRANSIT`.** `IN_TRANSIT` means "mid-Summon or
    mid-activation" and is the one non-field zone `GameState._is_destroyable_zone()` accepts, so
    sharing it would let a Summon-negation card destroy a card sitting in somebody's excavation.
    Excavation is also none of draw / search / reveal / mill: it takes from the **top**, reveals
    to **both** players, and an empty Deck yields fewer cards rather than losing the Duel,
    because the deck-out rule is written about *drawing* [S1 p.35]. The excavating card's text
    states where every excavated card goes and in what order; nothing is left in the zone when
    the effect finishes, and nothing is shuffled unless the text says so. `RULES_SPEC.md §8.2`.

42. **A Trap or Quick-Play card's CARD-level Spell Speed must be stated on its EffectDef.**
    `EffectDef.of_type()` derives Spell Speed from the EFFECT category, which is Spell Speed 1
    for everything except a Quick Effect. A `CARD_ACTIVATION` clause on a Normal/Continuous Trap
    therefore needs an explicit `with_spell_speed(SS2)` (and `SS3` for the Counter Trap), or the
    card is silently never offered in a response window. Every Trap in the registry does this;
    `Compulsory Evacuation Device` was written without it and its own clause-shape test caught
    it. **Assert the Spell Speed directly in every new Trap's suite.** [S1 p.44-45]

---

## 7. Blockers

None that stop work.

### CLOSED in batch 13 unit A — `One for One`'s cost candidate list (found in batch 12)

**Fixed, verified against the live official source, and closed.** Full record in
`CARD_RULINGS.md` **R42 Part D** ("Part D is CLOSED") and `RULES_SPEC.md` **§10.5**.

The source was **re-fetched before anything was changed** — `faq_search.action?ope=4&cid=8197`
`&request_locale=ja`, requested again on 2026-09-08 — and the 2020-03-20 supplement returns
batch 12's quoted sentence character-for-character. The correction rests on the live official
page, not on a transcription of it.

* **Old (wrong):** sending your only Level 1 monster as the cost was legal and "legitimately
  resolved for nothing".
* **Corrected (authoritative):** that monster is **not a legal cost**. The restriction is on the
  **cost candidate list** only — the activation stays legal, and only when the candidate list
  empties does `can_pay_cost` (never the condition) refuse the activation.
* **Assertions changed:** one test retired, **four** assertions inverted, **two** kept unchanged
  because they were always right (the activation is legal; the Spell still resolves to the GY).
  The exact before/after table is in R42 Part D. Nothing else in the suite was touched.
* **Card-local or generic?** The **rule is generic**; the **defect was reachable through exactly
  one card**. Every cost-paying card in the pool was audited — the rule bites only where the cost
  removes a card from a zone the effect draws from and puts it somewhere the effect does not.
  `One for One` is the only one. `Fairy Tail - Rella` overlaps and is **not** affected, because
  its discard lands in the GY and the GY is one of its effect's source zones.
* **Implemented at the generic level:**
  `EffectPrimitives.cost_candidates_keeping_effect_performable()`, next to
  `exclude_required_tributes()`, with a synthetic-card engine gate in
  `Tests/rules/CostLegalityTests.gd` (both the biting shape and the harmless one, so the rule is
  proved not to over-apply) and `OneForOneTests` as the card-level evidence.
* **Honest limit:** the per-candidate filter is exact for a payment of ONE card only. A larger
  count is refused loudly rather than approximated, and that refusal is asserted.

**There is no known-incorrect card left in the library.**

### NOT A DEFECT, but recorded so it is not rediscovered — `Miyabi` reads the printed Attribute

`Spiritual Wind Art - Miyabi` (batch 7) filters its Tribute candidates with
`monster_filter(WIND)`, which reads `definition.attribute`. Batch 12 established that on the
**field** the correct reader is `CardInstance.current_attribute()`, and `Kurenai` and `Aoi` use
the new `field_monster_of_attribute()` for exactly that reason. `Miyabi` therefore would not
offer a **WIND Trap Monster** as a Tribute.

It is **never live in the V1 pool** — the pool's only Trap Monster is
`The Phantom Knights of Shadow Veil` — so this is a latent divergence rather than a reachable
bug, and it was deliberately not changed in batch 12: `Miyabi` is stable shipped code and this
batch had no card that needed it. A batch that touches `Miyabi` for any other reason should fix
it then.

### CLOSED in batch 6 — Flip Summon negation (found in batch 5)

**There is no open engine gap.** The one batch 5 recorded here is fixed.

A **Flip Summon is a Summon** [S1 p.24], so `Champion's Vigilance` ("when a monster(s) would be
Summoned") must be able to negate one. It could not, because `SummonRules.flip_summon()` applied
the flip immediately and emitted `FLIP_SUMMON_SUCCEEDED` instead of splitting into begin/complete
the way the other two routes do. `SummonRules` now has `begin_flip_summon()` /
`_complete_flip_summon()`, and `Champion's Vigilance` listens for `FLIP_SUMMON_DECLARED` along
with the other two declarations. Every part of its printed text is now reachable.

The one thing a future session must not "simplify": **a Flip Summon does not use
`Zone.IN_TRANSIT`.** Its monster waits face-down in the Monster Zone it already occupies, because
entering `IN_TRANSIT` is a departure from the field and would destroy its Equip Cards and clear
its per-instance state — neither of which a Flip Summon does. That is why
`GameState.pending_summon_card_id` exists: "is a Summon pending?" cannot be answered by scanning
`in_transit`, which covers only two of the three routes. See design decision 34.

Proved by `SummonTests` (four new cases) and `ChampionsVigilanceTests :: it negates a Flip Summon`
together with its positive control. `CARD_RULINGS.md` R24 is updated.

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

* **23 of 77 cards are not implemented yet.** They are honestly `NOT_IMPLEMENTED` in the
  matrix, which is the authoritative list; do not work from memory.
* **Batch 9 is COMPLETE. Batch 10 is NOT planned yet** — plan it from the matrix. Nothing is
  half-finished and there is no partial unit to resume.
* **R1 and R2 remain open.** Both belong to cards that are already implemented, and both are
  unreachable in these two decks (an empty Extra Deck; the only "Ice Barrier" card in either
  deck). They are recorded questions, not gaps.
* **R3, R6, R7 and R8 are CLOSED**, settled while implementing their cards and recorded as
  **R37**, **R36**, **R39** and **R38** respectively. Do not reopen them.
* **R34 part D was re-checked and is still MEDIUM-HIGH.** That "cannot activate Trap Cards"
  locks activating a Trap CARD but not activating an EFFECT of an already-face-up Trap. The
  research was done: the official Konami database has **no Q&A entry for cid 6196**, and
  Yugipedia and the Fandom wiki were unreachable (HTTP 403 / 402). [S1 p.30] and [S1 p.53] now
  back it generally — better than "PSCT alone" — but it is still not a quoted ruling on
  `Mirage Dragon`. Recorded honestly in **R35**, and still isolated behind one predicate
  (`ActivationRules.card_class_activation_ok()`) so correcting it is a one-place change.
* **Two real engine defects were found and fixed in batch 9.** (1)
  `SummonRules.tribute_value()` honoured `effects_are_negated()` but not face-orientation, so a
  face-down `Kaiser Sea Horse` wrongly counted as two Tributes. Fixed, and the rule is now
  asserted in the generic gate (`SummonTests`) as well as in the card's own suite. (2)
  `SummonRules.tributes_satisfy()` was a **greedy maximum-value** check that rejected any
  material it judged unnecessary — wrong for an **optional** double-Tribute clause, because a
  double-Tribute monster **may** count as one. It now enumerates complete legal combinations
  (`tribute_combinations()`). Do not reintroduce either.
* **A Tribute selection is validated as a COMPLETE SET before anything is paid, and the engine
  rejects a forged payload rather than merely not offering it.** `tribute_combinations()` is
  published on the action (`DuelAction.tribute_combinations`) so a UI never re-derives it. The
  material-choice constraint (§5.9 of `RULES_SPEC.md`, R39) is consumed on **both** the
  Summon/Set route and the Tribute-**cost** route; adding a third Tribute channel means calling
  it there too, not special-casing a card.
* **Batch 7 is COMPLETE** — all four units, tested and committed. **Batches 8 and 9 are
  COMPLETE.**
* **R29 is a reasoned decision resting partly on a general rule, not a quoted ruling on either
  card.** "1 card your opponent controls" (`Phoenix Wing Wind Blast`,
  `Spiritual Wind Art - Miyabi`) is re-checked for CONTROL at resolution, so a target the
  activating player has since taken control of is dropped. Confidence **MEDIUM** overall: HIGH for
  `Miyabi`, whose own official resolution clause says "that **opponent's** card", and MEDIUM for
  `Phoenix Wing Wind Blast`, which says only "that target" and therefore rests on the general
  targeting rule. Ownership is deliberately NOT part of it. Recorded with that caveat in
  `CARD_RULINGS.md` R29 and asserted generically in `MovementTests` plus both card suites, so a
  later correction fails loudly rather than drifting.
* **R27 and R28 are reasoned decisions resting on community-transcribed rulings, not on an
  S1–S4 official source.** R27: `A Wingbeat of Giant Dragon` cannot be activated without a
  Level 5 or higher Dragon to return (MEDIUM confidence; the cost-vs-effect and non-targeting
  halves of R27 are HIGH and are directly sourced). R28: a card that destroys "all Spell and
  Trap Cards on the field" does not destroy itself (MEDIUM, reasoned from the `Heavy Storm`
  precedent). Both are recorded with that caveat stated in `CARD_RULINGS.md`, and both are
  asserted in `AWingbeatOfGiantDragonTests` so a later correction fails loudly rather than
  drifting.
* **R25 is a reasoned decision, not a quoted rule.** "Take control until the End Phase"
  (`Enemy Controller`) is implemented as expiring the instant the End Phase is ENTERED, before
  either step of this engine's two-step End Phase. No single official sentence names the instant.
  What is certain and is what the tests pin down: control lasts the whole of the controlling
  player's turn through Main Phase 2, and is gone before the next turn. `CARD_RULINGS.md` R25.
* **Two clauses in the pool can never be live in a real duel**, both implemented in full and
  tested against synthetic cards, both asserted against the real library so the fact cannot rot:
  `Apprentice Magician`'s Spell Counter clause (no card in the pool can hold a Spell Counter —
  R21) and `Fairy Tail - Rella`'s equip clause (the pool has no Equip Spells — R23). This is the
  same situation as R1's unreachable Extra Deck branch.
* **Simultaneous-LP-zero (a draw) is unexercised.** This is still the ONLY item left on the
  core-rules "not yet covered" list in `Reports/TEST_RESULTS.md`. Batch 7 unit C was the obvious
  chance to make it reachable and **did not**: `Chain Detonation` damages only the opponent and
  `Chain Healing` only gains LP, so no card in the pool can take both players to 0 at once
  through them. That was checked rather than assumed — `ChainDetonationTests :: it can end the
  duel` proves the burn ends the Duel with a single winner (`PLAYER_0_WINS`, not `DRAW`), and
  `ChainHealingTests :: it cannot end the duel` runs with both players on 100 LP and proves
  nothing ends. Preserved as a known future gap, deliberately and with evidence.
* **`Castle of Dragon Souls` was mis-grouped as an Equip card** in an earlier checkpoint's
  §8 plan. **CLOSED in batch 4.** It is a **Continuous Trap with a temporary ATK boost**, it
  equips nothing, and it is implemented and tested as one (109 assertions). Preserve this
  correction: it must never be moved back into an Equip group.
* **`Kunai with Chain` and `Fairy Tail - Rella` still exercise Equip mechanics** and are not
  implemented yet. The generic subsystem they need now exists and is tested; they still need
  their own per-card work.
* **The ObjectDB figure is CHARACTERISED as of batch 15 (2026-09-09).** A direct probe measured
  **188 leaked objects per duel CONSTRUCTED** (exactly linear over 0 / 50 / 100 / 200 duels,
  intercept 17), **~6 more per turn PLAYED**, and **zero** for any number of
  `CardRegistry.load_library()` calls. 188 is close to one duel's entire object graph, so what is
  retained at exit is every duel a run ever built, held by a reference cycle at the `DuelEngine` /
  `GameState` root. **The count tracks DUELS BUILT and has no relationship to assertion counts**,
  which is why eight checkpoints produced four falls and four rises with no trend — the
  per-assertion series was measuring the wrong quantity and is retired. It causes no test failure,
  hang, memory pressure or unreliable result. What remains is a **FIX** — break the cycle — and it
  is still required **before Phase 7**, when the UI keeps one duel alive for a long session. The
  bullet below is kept verbatim for the record; its "no explanation has been measured" is
  superseded.
* **Superseded, kept for the record: 204316 leaked ObjectDB instances at exit** (measured at the **batch 10** checkpoint, up
  from 187347 at batch 9, 180615 at batch 9 unit A, 164444 earlier in batch 9, 154223 at batch
  8 and 113897 at batch 7) — RefCounted cycles between `GameState`, the `DuelLog` signal and
  test closures. It grows in proportion to the number of duels the suite builds. Batch 10 added
  **16969 for 630 assertions, about 26.9 each**, against 21.6 at batch 9, 34.9 before that and
  44.6 before that. The per-assertion figure has now fallen twice, risen once and fallen once
  across four checkpoints. **No explanation for any of that is recorded, because none has been
  measured**, and none may be recorded until one is. It causes no test failure, hang, memory
  pressure or unreliable result, so it was correctly not allowed to derail a card unit, but it
  must be characterised or cleaned up **before Phase 7**, when the UI keeps one duel alive for a
  long session. This is a harness / object-lifetime issue and is **not** a rules correctness
  failure.
* **Five per-card rulings are OPEN**, three of them blocking a card among the three that remain:
  **R5** (`Fairy Tail - Sleeper`), **R11** (`Fairy Tail - Luna`) and **R14**
  (`Hidden Springs of the Far East`). **R12** (`The Monarchs Awaken`) was CLOSED in batch 16,
  **R15** (`A Hero Emerges`) in batch 15, **R13** (`Witchcrafter Golem Aruru`) in batch 14,
  and **R20** (`Honest`) plus **R42 Part D** in batch 13.
  **R1** and **R2** belong to cards that are already implemented and are carried as recorded
  questions, not as gaps. Settle each one BEFORE writing its card, and use `request_locale=ja`
  on the Konami database — see the methodology note in **R40**.
* **An earlier "no official Q&A exists" conclusion has NOT been re-checked and may be wrong.**
  **R35** records that the Konami database has no Q&A entry for cid 6196 (`Mirage Dragon`),
  which is why R34 part D stayed at MEDIUM-HIGH. That conclusion was reached with
  `request_locale=en`, which batch 10 discovered returns generic boilerplate for every card.
  The `ja` lookup was **not** performed for cid 6196 in batch 10 and no claim is made about
  what it would return. Re-check it before relying on R35's negative result again.

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
suites, 0 failures**, SmokeCheck PASS. **Batch 5 then added `Apprentice Magician`,
`Kunai with Chain`, `Fairy Tail - Rella` and `Champion's Vigilance`, taking the measured suite to
2397 assertions across 39 suites and the library to 32 / 77. Batch 6 closed the Flip Summon
negation gap, added the generic CONTROL subsystem, and implemented the three Charmers and
`Enemy Controller` — 2862 assertions across 44 suites, 36 / 77.** Read §6a for per-subsystem status
and the **thirty-seven** design decisions that must not be reversed, and §7 for what is genuinely
still open — which no longer includes any engine gap. Do **not** re-read the whole repository,
re-run research, or re-derive rules.

> **Start here instead of reading this section top to bottom.** Everything below the "How to
> resume" paragraph is historical. The current state is §0; the next thing to do is
> **"NEXT PHASE — integration, scripted duels, backend acceptance"** further down this section.
>
> **Measured now: 10087 / 10087 across 96 suites, SmokeCheck PASS, 0 `SCRIPT ERROR`, 77 / 77
> implemented and tested, NONE remaining — the CARD IMPLEMENTATION PHASE is COMPLETE — ObjectDB
> 347433 (the known linear per-duel behaviour — see §0).** Batch 18 closed **R5** and **R14** and
> produced `RULES_SPEC.md` **§10.11** (substitution is a THIRD operation on a Chain Link) and
> **§19** (negation immunity, and an effect activated by the TURN PLAYER). Batch 16 closed **R12** (`The Monarchs Awaken`) and produced `RULES_SPEC.md`
> **§18** — *"unaffected" gates effect APPLICATION only; targeting, resolution, costs and battle
> are all untouched* — and **§10.9**, a card stating its own resolution-time condition per clause.
> Batch 15 closed **R15** and produced **§10.8** — *an activation requirement that fails by
> resolution kills the WHOLE effect, first sentence included* — and **§12.3**. Batch 14 closed
> **R13** and produced §10.6 — *a dead target does not automatically kill the whole effect* —
> which §10.8 and §10.9 must both be read next to. Batch 13 closed **R42 Part D** and **R20**.

**Where that paragraph now ends: batches 7, 8 and 9 are all COMPLETE.** Batch 9 added the
generic attack-restriction / attack-negation gate (`AttackRestrictionTests`, 229), then
`Mirage Dragon`, the generic "it remains on the field" override, `Swords of Revealing Light`,
`Maiden with Eyes of Blue`, `Kaiser Sea Horse`, the generic lingering material-choice constraint
(`ChoiceConstraintTests`, 137) and finally `Soul Exchange` (`SoulExchangeTests`, 174) —
**6284 assertions across 69 suites, 0 failures, 54 / 77**, with **R3, R6, R7 and R8 closed** and
**two** real engine defects found and fixed. Read §0 first, then this section's "NEXT step"
heading. The paragraph below is kept for the record.

**Historical (through batch 7): batch 7 is COMPLETE.** Unit A added the generic MOVEMENT and
EXCAVATION subsystem (`MovementTests`, written before any card) and fixed two live movement
defects; unit B added `Compulsory Evacuation Device`, `Kaiser Glider` and `A Wingbeat of Giant
Dragon`; unit C added `Phoenix Wing Wind Blast`, `Spiritual Wind Art - Miyabi`, `Chain Detonation`
and `Chain Healing`; unit D added `Crystal Seer` — **4118 assertions across 53 suites, 0 failures,
44 / 77**. There are now **forty-two** design decisions that must not be reversed. **Batch 8 is
the next thing to do and is specified below. Do not start it before reading §7.**

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

### Batch 5 — COMPLETE (nothing partial, nothing unverified)

**The counter monster, the second Equip group, and negation.** This batch completes the pool's
**Equip group** (all four equippers) and its **single Counter Trap**.

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Apprentice Magician` | 2 | `ApprenticeMagicianTests` | 92/92 |
| `Kunai with Chain` | 4 | `KunaiWithChainTests` | 117/117 |
| `Fairy Tail - Rella` | 3 | `FairyTailRellaTests` | 106/106 |
| `Champion's Vigilance` | 2 | `ChampionsVigilanceTests` | 114/114 |

Per-card status, stated explicitly:

* **`Apprentice Magician` — IMPLEMENTED + TESTED.** Both clauses. The Spell Counter clause has
  **no legal target anywhere in the V1 pool** (R21) and is tested against a synthetic card that
  declares the capacity; the face-down Defense Position recruit is tested on real cards.
* **`Kunai with Chain` — IMPLEMENTED + TESTED.** All three legal activations ("1 or both") plus
  the granted +500 ATK.
* **`Fairy Tail - Rella` — IMPLEMENTED + TESTED.** Both clauses plus the delayed End Phase
  return. The equip clause is **never live in the V1 pool** (no Equip Spells exist, R23) and is
  tested against synthetic Equip Spells.
* **`Champion's Vigilance` — IMPLEMENTED + TESTED**, with one part of its text unreachable for an
  ENGINE reason recorded in §7: Flip Summon negation. Both Summon routes that open a declaration
  window are negated correctly, as is a Spell/Trap card activation.

Generic mechanics completed and tested in this batch — none is left UNVERIFIED:

* **Counter CAPACITY as a rules query** — `GameState.COUNTER_CAPACITY_EFFECT_ID`,
  `can_place_counter()`, `cards_that_can_receive_counter()`, in
  `CardRegistry.RULES_QUERY_EFFECT_IDS`. Not enforced by `place_counters()` — see R21.
* **`cannot_be_targeted` is finally CONSUMED** — read once in `ActivationRules.legal_targets()`
  through `CardInstance.cannot_be_targeted()`. It had been declared and rebuilt by
  `ContinuousEffects` with **zero readers**; that is the batch's one engine defect.
* **`EffectDef.targets_valid`** — optional per-clause validation of the chosen target SET,
  enforced by `DuelEngine._choices_valid()` via `ActivationRules.target_selection_ok()`. For
  heterogeneous targets, where candidate membership plus a count is not enough.
* **`EffectPrimitives.pay_discard_cost()`** — "discard", distinct from "send from hand to GY".
* **`GameState.destroy()` accepts `Zone.IN_TRANSIT`** — so "negate the Summon, and if you do,
  destroy that card" uses the ONE destruction entry point (design decision 19 preserved).
* **Negation primitives** — `summon_is_pending()`, `negate_summon_and_destroy()`,
  `spell_trap_activation_below()`, `negate_activation_and_destroy()`.
* **`equip_card_to_source()`** plus `EQUIPPED_BY_EFFECT_KEY` / `EQUIPPED_BY_EFFECT_TURN_KEY`.
* Test-side: `TestFixtures.counter_holder()`, `equip_spell()`, `activation_negator()`.

Cards started but unfinished: **none.** Mechanics still unverified from this batch: **none.**

### Batch 6 — COMPLETE (nothing partial, nothing unverified)

**The Flip Summon negation gap, and the control-change group.** Done in three units, each tested
and committed before the next began. This batch completes the pool's **control-change group** —
every card in the V1 pool that changes control is implemented and tested — and completes
`Champion's Vigilance`, whose Flip Summon branch was the only unreachable text in the library.

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Aussa the Earth Charmer` | 1 | `AussaTheEarthCharmerTests` | 107/107 |
| `Eria the Water Charmer` | 1 | `EriaTheWaterCharmerTests` | 36/36 |
| `Wynn the Wind Charmer` | 1 | `WynnTheWindCharmerTests` | 48/48 |
| `Enemy Controller` | 2 | `EnemyControllerTests` | 127/127 |

Generic mechanics completed and tested in this batch — none is left UNVERIFIED:

* **The Flip Summon declaration architecture** — `SummonRules.begin_flip_summon()` /
  `_complete_flip_summon()`, `GameEvent.Kind.FLIP_SUMMON_DECLARED`, and
  `GameState.pending_summon_card_id` as the one authoritative answer to "what would be Summoned?"
  across all three routes. See §7 and design decision 34.
* **Change of CONTROL** — `GameState.change_control()` / `can_change_control()` /
  `end_control_lease()` / `drop_control_leases_for()` / `expire_control_leases()`, the
  `control_leases` register and `Enums.ControlDuration`. `ControlTests` (93) is the **control
  gate** and was written and passing before any Charmer existed. Design decisions 35-37.
* **Card-facing control primitives** — `EffectPrimitives.opponent_monsters()`,
  `take_control_of_target()`, `charmer_take_control()`.
* **`SummonRules.opposite_face_up_position_of()`** — the battle-position toggle as a static, for a
  card effect that changes a position rather than a player doing it manually.
* Test-side: `TestFixtures.flip_effect_monster()`, `summon_negator()`, `count_events_for()`.

Engine defects found and fixed: the Flip Summon declaration gap and its `summon_is_pending()`
consequence (unit A); **`GameEvent.Kind.CONTROL_CHANGED` had zero emitters** — declared vocabulary
that did nothing, the same failure shape as batch 5's `cannot_be_targeted` (unit B); and
`CardRegistry` reporting a script that failed to COMPILE as `"declares no CARD_NAME"`.

Cards started but unfinished: **none.** Mechanics still unverified from this batch: **none.**

### Batch 7 — COMPLETE, all four units (nothing partial, nothing unverified)

**The movement group.** Done in units, each tested and committed before the next began.

**Unit A — the generic movement / excavation gate.** `MovementTests` (194 assertions) was
written and passing **before any batch-7 card existed**, the way `EquipTests` and `ControlTests`
were. It asserts that these are NOT one operation with a destination argument: return to hand ·
add to hand · top of Deck · bottom of Deck · shuffle into Deck · send to GY · banish · excavate ·
reveal. It found the two pre-existing movement defects listed in §4. New generic mechanics:

* `Enums.Zone.EXCAVATED` (deliberately **not** `IN_TRANSIT` — see `RULES_SPEC.md §8.2`),
  `MoveReason.ADDED_TO_HAND` / `EXCAVATED`, `Enums.is_return_to_deck()` / `deck_position_for()`.
* `GameEvent.Kind.CARD_ADDED_TO_HAND` / `CARD_REVEALED` / `CARD_EXCAVATED`.
* `GameState.reveal()` / `excavate()` / `excavated_cards()`, `PlayerState.excavated`.
* `EffectPrimitives` movement + excavation sections: `cards_on_field()`,
  `opponent_field_cards()`, `return_to_hand()`, `return_target_to_hand()`, `place_on_deck()`,
  `place_target_on_deck()`, `shuffle_into_deck()`, `add_to_hand()`, `excavate()`,
  `return_excavated()`.
* `RULES_SPEC.md §8.2` records the whole decision.

**Unit B — the return-to-hand group.**

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Compulsory Evacuation Device` | 1 | `CompulsoryEvacuationDeviceTests` | 88/88 |
| `Kaiser Glider` | 2 | `KaiserGliderTests` | 93/93 |
| `A Wingbeat of Giant Dragon` | 1 | `AWingbeatOfGiantDragonTests` | 87/87 |

Generic mechanics added by unit B: `EffectPrimitives.battle_opponent_of()` (a destruction
prevention conditional on the OTHER battling monster) and
`EffectPrimitives.destroyed_and_sent_to_gy_condition()`. New rulings: **R27**, **R28**.

Cards started but unfinished: **none.** Mechanics still unverified: **none.**

**Unit C — Deck placement (top / bottom / shuffle), and Chain-Link-position-aware effects.**

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Phoenix Wing Wind Blast` | 1 | `PhoenixWingWindBlastTests` | 162/162 |
| `Spiritual Wind Art - Miyabi` | 1 | `SpiritualWindArtMiyabiTests` | 150/150 |
| `Chain Detonation` | 1 | `ChainDetonationTests` | 168/168 |
| `Chain Healing` | 1 | `ChainHealingTests` | 147/147 |

**Unit D — Excavation.**

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Crystal Seer` | 1 | `CrystalSeerTests` | 151/151 |

Generic mechanics added by units C and D — none is left UNVERIFIED:

* **A resolution-time target re-check across the whole FIELD** —
  `EffectPrimitives.surviving_field_target()`. The gate's `surviving_target()` takes ONE zone,
  which is right for "1 monster on the field" but silently drops every Spell/Trap a clause worded
  "1 **card** your opponent controls" legally chose. Covered generically by `MovementTests`.
* **A resolution-time re-check of CONTROL** — `surviving_opponent_field_target()`. Ownership is
  never consulted; control is what the text names. This is a **ruling**, `CARD_RULINGS.md` **R29**,
  MEDIUM confidence, recorded with its reasoning and asserted in both directions.
* **A card-facing reader for its own Chain Link position** —
  `EffectPrimitives.activated_chain_link_number()` reading `ChainLink.link_number`, plus
  `return_self_by_chain_link()` for the sentence pair `Chain Detonation` and `Chain Healing` print
  identically. `CARD_RULINGS.md` **R4** is closed by this. **Never count the chain array at
  resolution** — a Chain resolves in reverse, so the links above are already gone.
* Test-side: `TestFixtures.effect_negator()` (negating an EFFECT, the counterpart of the existing
  `activation_negator()`) and `TestFixtures.build_chain_to_depth()` (a Chain built to an exact
  depth, shared by the two Chain cards).

Engine defects found by units C or D: **none.** The unit-A gate had already flushed the movement
API's two real defects out before any card depended on it. One **test-harness** defect was found
and fixed and is written up in `Reports/TEST_RESULTS.md`: `TestFixtures.card_activation()` allows
`FIELD_FACE_UP`, so an already-activated synthetic spacer Trap was offered again from its own
face-up position, the engine never auto-passed that side, and a Chain built for a depth test
stalled one link short — which looked exactly like a card bug and was not one.

Cards started but unfinished: **none.** Mechanics still unverified: **none.**

The unit C / D specification below is kept for the record; it is **done**, not a plan.

**UNIT C — Deck placement (top / bottom / shuffle).** Four cards, in this order:

| Card | Official text (verified — `Data/cards/cards.json`) |
|---|---|
| `Phoenix Wing Wind Blast` | "Discard 1 card, then target 1 card your opponent controls; place that target on the top of the Deck." |
| `Spiritual Wind Art - Miyabi` | "Tribute 1 WIND monster, then target 1 card your opponent controls; place that opponent's card on the bottom of the Deck." |
| `Chain Detonation` | "Inflict 500 damage to your opponent. If this card was activated as Chain Link 2 or 3, add this card to the Deck and shuffle it. If this card was activated as Chain Link 4 or higher, return this card to the hand." |
| `Chain Healing` | "Gain 500 Life Points. If this card was activated as Chain Link 2 or 3, add this card to the Deck and shuffle it. If this card was activated as Chain Link 4 or higher, return this card to the hand." |

Notes that will otherwise cost a cycle:

* Both `Phoenix Wing Wind Blast` and `Miyabi` put their payment **before a comma and "then"**,
  which is PSCT for a **COST** — use `EffectPrimitives.pay_discard_cost()` and
  `pay_tribute_cost()` respectively, in `pay_cost`, not in `resolve`. Contrast
  `A Wingbeat of Giant Dragon`, whose return is the effect (R27).
* Both target "1 card your opponent controls" — **any** card, not just a monster, and
  face-down is legal. `EffectPrimitives.opponent_field_cards()` is exactly that candidate set.
  Neither may target the controller's own cards.
* Use `place_target_on_deck(ctx, to_bottom)` with the correct end. **Do not** implement either
  by calling shuffle afterwards — the text says top/bottom, so nothing is shuffled, and
  `revealed_to` is kept.
* `Chain Detonation` / `Chain Healing` are **CARD_RULINGS.md R4**: behaviour depends on the
  Chain Link number the card was activated at. `ChainLink.link_number` already exists and is
  already 1-based authoritative state, so read it from `ctx.link.link_number` — do not count
  the chain array. Chain Link 1 gets neither of the two conditional halves; the damage / LP
  gain always happens. These two are **the only cards in the pool that shuffle into the Deck**,
  so they are what finally exercises the `revealed_to`-cleared branch with a printed card. They
  are the same shape as each other but are **NOT one implementation** — see design decision 22
  about `Birthright` / `Call of the Haunted`; each writes its own first half.
* "add this card to the Deck and shuffle it" moves the resolving card itself from the field —
  which means `DuelEngine._cleanup_resolved_spell_traps()` must not then also send it to the
  Graveyard. Check that path explicitly; it is the one genuinely new interaction in unit C.

**UNIT D — Excavation.** One card:

| Card | Official text (verified) |
|---|---|
| `Crystal Seer` | "FLIP: Excavate the top 2 cards of your Deck, then add 1 of them to your hand, then place the other on the bottom of your Deck." |

* WATER / Spellcaster / Level 1 / 100 ATK / 100 DEF. A **FLIP** effect, so it keys on
  `CARD_FLIPPED_FACE_UP` (a Flip Summon, an attack, or a card effect all turn it face-up) —
  copy the trigger shape from the three Charmers. No "You can", so **MANDATORY**.
* `EffectPrimitives.excavate(ctx, 2)` → `add_to_hand()` for the chosen one →
  `return_excavated(ctx, rest, true)` for the other. The player chooses **which** goes to hand,
  so that is a logged `choose_one`. Nothing is shuffled: the text says "place", so the card
  left on the bottom **keeps** `revealed_to` — this is the printed-card exercise of design
  decision 11's "keeps it" branch, and it must be asserted.
* Fewer than 2 cards in the Deck excavates fewer; it is **not** a draw and must not deck the
  player out. Assert that branch.

**Batch 7 was then closed** with a full regression, SmokeCheck and `python Tools/build_matrix.py`.
Measured at that checkpoint: **44 / 77 implemented and tested, 33 remaining** — the predicted
number, computed and not assumed.

### Batch 8 — FOUR units are DONE (nothing partial in them)

**Done and committed:** unit A (the banish gate, `BanishTests` 158) ·
`Interdimensional Matter Transporter` (175) · the generic LP-payment-as-cost unit
(`LifePointCostTests` 109) · `Judge of the Ice Barrier` (154) · `Junk Blader` (73).
**Remaining:** `The Phantom Knights of Shadow Veil` · `Runick Flashing Fire`.

The unit-A description below is kept for the record.


**Unit A — the generic banish / temporary-removal gate.** `BanishTests` (158 assertions) was
written and passing **before any batch-8 card existed**, the way `EquipTests`, `ControlTests` and
`MovementTests` were. New generic mechanics, none left UNVERIFIED:

* `Enums.BanishDuration` (`UNTIL_END_PHASE` / `PERMANENT`),
  `Enums.MoveReason.RETURNED_FROM_BANISHMENT`,
  `GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT`.
* `GameState.banish_leases` + `can_banish_temporarily()` / `banish_temporarily()` /
  `banish_leases_for()` / `is_temporarily_banished()` / `end_banish_lease()` /
  `drop_banish_leases_for()` / `expire_banish_leases()` — **the same lease shape as
  `control_leases`**, expired from the same two call sites (`DuelEngine._advance()` and
  `TurnFlow.enter_phase()` at the End Phase), control first. Do not invent a second mechanism.
* `move_card()` drops a temporary-banish lease the instant the card leaves the Banished zone by
  any other route, so a return can never happen twice.
* `EffectPrimitives.banish_target_temporarily()` (takes an **already re-checked** target),
  `banish_top_of_deck()`, `own_monsters()`, `surviving_own_monster_target()`.
* `RULES_SPEC.md §8.3` and `CARD_RULINGS.md` **R30** record the whole decision, per-part.

**Unit B, card 1 — `Interdimensional Matter Transporter`.** 1 EffectDef,
`InterdimensionalMatterTransporterTests` **175/175**.

Defects: two in unit-A code, caught before any card depended on it (the dropped `face_up` on the
permanent path; the `return_index` with no reader, removed rather than consumed), plus one
test-harness false pass. All three are written up in `Reports/TEST_RESULTS.md`.

### Batch 8 is COMPLETE — the two final units, for the record

**`The Phantom Knights of Shadow Veil` and `Runick Flashing Fire` are done**, each behind its own
generic gate written and passing first. Neither is partial and neither has an unimplemented
clause. What follows is the record; the plan for what to do NEXT is under
**"The NEXT step — batch 9"** below.

| Unit | Suite | Result |
|---|---|---|
| the generic Trap-Monster gate | `TrapMonsterTests` | 192/192 |
| `The Phantom Knights of Shadow Veil` (2 EffectDefs, 3 clauses) | `ThePhantomKnightsOfShadowVeilTests` | 125/125 |
| the generic Battle-Phase-restriction gate | `BattlePhaseRestrictionTests` | 53/53 |
| `Runick Flashing Fire` (2 EffectDefs, both bullets) | `RunickFlashingFireTests` | 123/123 |

Decisions in these two units that must not be reversed:

* **A Trap Monster's runtime type line is per-INSTANCE.** `CardDef` is immutable and shared by
  every copy; writing a Level or an ATK into it would rewrite the card for the whole duel. See
  **R33** and `RULES_SPEC.md §5.8`.
* **The Summon goes THROUGH `SummonRules.begin_special_summon()`.** That gate refuses a
  non-monster, so the identity is granted first and revoked again if the Summon does not happen.
  Do not add a bespoke placement path.
* **The identity is revoked in `GameState.move_card()`, in one place, and NOT in
  `on_leave_field()`** — that never runs on the negated-Summon path and would strand a Trap in
  the Graveyard still answering `is_monster()`.
* **"Banish this card when it leaves the field" changes only the DESTINATION, never the reason.**
  A redirected destruction is still a destruction.
* **Phantom Knights' ATK/DEF gain has NO printed duration**, so it is neither end-of-turn nor
  tied to its source. `gain_atk_and_def_permanently()`.
* **Runick's Battle Phase skip is applied in `pay_cost`, at ACTIVATION** — **R1** requires it to
  apply even when the effect is negated — and it is **authoritative turn state**, never a
  card-local flag and never UI. See **R32** and `RULES_SPEC.md §2.4`.
* **Runick's bullet 2 is never live** (both Extra Decks are empty) but is fully implemented and
  reports "no legal choice", with a real-pool assertion — the R21/R23/R2 treatment, now used five
  times.

### Batch 11 — COMPLETE. All six planned cards are implemented and tested.

**Verified from disk on 2026-09-06 before anything was written**, exactly as the resumption
instructions require: `HEAD` was `f45b2f3` on `main`, tree clean, local `HEAD` == `origin/main`,
the full suite measured **6914 / 6914 across 77 suites** with `RESULT: PASS`, `SmokeCheck: PASS`,
**no `SCRIPT ERROR`** (the two `ERROR:` lines on stderr are the two deliberate fail-loudly negative
tests, unchanged), ObjectDB **204316** at exit, and
`Reports/CARD_IMPLEMENTATION_MATRIX.csv` reporting **61 / 77 implemented, 61 / 77 tested,
16 remaining**. Every number in §0 reproduced.

**The recommendation below was re-derived from the matrix and still holds.** All six recommended
cards are still `NOT_IMPLEMENTED / NOT_TESTED` in the matrix, all six carry
`Special Ruling Needed = NO`, and none of them touches any of the seven carried-over open rulings.
Batch 11 is therefore **exactly** the recommended six:

| Unit | Card | Why it is here |
|---|---|---|
| A | `Stamping Destruction` | destruction of a TARGET, with a consequence conditional on it |
| A | `Straight Flush` | non-targeting destruction of a whole ZONE, on a board condition |
| B | `Burst Stream of Destruction` | non-targeting mass destruction + a lingering attack ban |
| B | `Chiron the Mage` | a qualified discard COST + targeted destruction, once per turn |
| C | `Back-Up Rider` | ATK modification until the end of the turn |
| D | `Vampiric Koala` | a trigger on battle damage |

**The four destruction cards are NOT four instances of one mechanic**, and the plan does not treat
them as one. They differ in every axis that matters, which is why they were read individually
before any of them was written:

| | `Stamping Destruction` | `Straight Flush` | `Burst Stream` | `Chiron the Mage` |
|---|---|---|---|---|
| Targets? | **yes**, 1 | no | no | **yes**, 1 |
| What is destroyed | the target only | every card in the opponent's five Spell & Trap Zones | every monster the opponent controls | the target only |
| Activation condition | you control a Dragon | all five of the opponent's Spell & Trap Zones are occupied | you control a face-up `Blue-Eyes White Dragon` **and** no `Blue-Eyes White Dragon` has attacked this turn | none (a once-per-turn Ignition) |
| Re-checked at resolution? | **NO** — R41 Part A says so outright | not re-checked; it destroys what is there | not re-checked | the target is, as every targeting clause is |
| Cost | none | none | none | **a qualified discard** (1 Spell), batch 10's `qualified_hand_cards()` |
| Consequence after the destruction | 500 damage, **only if the destruction succeeded** | none | a turn-scoped attack ban acquired at **activation** | none |

**ONE new piece of generic engine surface, and only because the engine could not express the
card**: a **turn-scoped attack ban keyed by card NAME** (`RULES_SPEC.md` §6.5,
`PlayerState.ban_attacks_by_name()`), plus the single primitive
`EffectPrimitives.named_monster_attacked_this_turn()`. §6.4's two existing prevention channels are
both continuous and both lift when their source stops applying; `Burst Stream of Destruction` is a
Normal Spell that is in the Graveyard before the first attack it forbids. Nothing else was added,
nothing was refactored, and no working architecture was reshaped — every other clause of all six
cards is built from primitives that already existed.

**R41 was opened and CLOSED before any card was written**, against PRIMARY Konami supplemental
information fetched with `request_locale=ja` per R40's methodology note. §8's prediction that
batch 11 needed no research was **wrong**, and honestly so: five of the six cards carry official
notes that change the implementation, four of which would otherwise have been silent bugs — most
sharply `Burst Stream of Destruction`, which turns out to carry an activation restriction that
appears nowhere in its printed English text, and `Vampiric Koala`, which triggers when it is
**attacked** as well as when it attacks. R41 Part G is the one question the database does not
answer and is recorded as reasoned-from-precedent at MEDIUM, not as an official ruling.

**R5, R11, R12, R13, R14, R15 and R20 remain OPEN**, all belong to cards batch 11 does not touch,
and none was consulted. **R35 / `Mirage Dragon` was NOT re-checked** — that cleanup item is still
outstanding and is not claimed.

**Two things the batch found that are NOT about batch 11 and must not be lost:**

* **A claim asserted as prose would have shipped false.** R41 Part B's first draft said the pool
  had no Field Spell; it was written as a COUNT in `StampingDestructionTests`, the count failed,
  and deck 2's `Hidden Springs of the Far East` is a Field Spell. Both cards genuinely branch on
  the Field Zone and each is now tested against a real one. Write such claims as measurements.
* **Redundant code is untestable code.** `Chiron the Mage`'s "your opponent controls" check was
  duplicated between the candidate loop's scope and the predicate, so a mutation breaking the
  predicate half SURVIVED. Mutation testing found it; reading it had not. The clause now lives in
  exactly one place and answers identically at activation and at resolution.

### Batch 18 — COMPLETE. It was the final card batch. (kept for the record; it is done, not a plan)

Two cards, two units, deliberately not grouped. `Fairy Tail - Sleeper` (R5) in unit A with the
Chain-Link substitution gate; `Hidden Springs of the Far East` (R14) in unit B with the
negation-immunity gate and the turn-player activation route. **77 / 77.** The full record is in
§0 and in `Reports/TEST_RESULTS.md`.

---

## NEXT PHASE — integration, scripted duels, backend acceptance

**Read §0 first. The card implementation phase is COMPLETE and this is what follows it.**
Nothing below is started. **Do not begin it in the same session that finished batch 18.**

### What is TRUE right now, so the next session does not re-derive it

| Fact | Value |
|---|---|
| Cards implemented / tested | **77 / 77** |
| Full suite | **10087 / 10087 across 96 suites**, 0 failed |
| SmokeCheck | **PASS** |
| `SCRIPT ERROR` occurrences | **0** |
| Scripted duel tests | **0** — the row has been zero in every checkpoint since Phase 5 began |
| Rulings blocking a card | **none** |
| ObjectDB at exit | **347433**, ~187 per duel, linear for four batches |
| Targeted runner | `./Tools/run_tests.sh RunBatch18Tests` (1692 across 16 suites) |

**The engine has never played a whole duel end to end in a test.** Every one of the 96 suites
builds a board, exercises a mechanism and stops. That is the gap this phase exists to close, and
it is the reason "the card library is finished" is **not** the same as "the game works".

### Unit 1 — the ObjectDB reference-cycle FIX. Do this FIRST.

**This is the highest non-card priority and it has been carried, unclaimed, since batch 15.**

* it is a **fix**, not a characterisation. The measurement (~187 objects leaked per duel built,
  stable across batches 15–18) is already done and is **not** the deliverable;
* the cycle is at the **`DuelEngine` / `GameState` root**. `GameState` holds `players`,
  `chain`, instances and the event signal; `DuelEngine` holds `state`, `chain`, `triggers`,
  `summons`, `battle`, `continuous`, `flow`, `log`, and every one of those subsystems holds
  `state` back. `state.event_emitted` is connected to two `DuelEngine`-owned receivers;
* **it must land before Phase 7**, and it must land before the scripted-duel work below, because
  that work multiplies the number of duels built per run by a large factor. Fixing it afterwards
  means re-measuring everything;
* the acceptance test is a new one: build N duels, drop every reference, and assert the ObjectDB
  count returns to its baseline. Write that test **before** the fix, the way every gate in this
  project has been written.

### Unit 2 — scripted duels: the row that has always read zero

A **scripted duel** is a full duel driven end to end by seeded `ScriptedController`s, asserted on
its final state and on its `DuelLog` replay payload. The infrastructure already exists and is
tested — `TestFixtures.new_duel()`, `ScriptedController`, `DuelLog`, `ReplayTests` — so this is
**assembly, not new engine work**, and any new engine work it turns up is a finding worth recording
rather than a task to absorb silently.

What each scripted duel must assert, at minimum:

1. it **ends**, by a real win condition, inside a bounded number of turns — no hangs, no
   force-quits, and a turn cap that fails loudly rather than passing quietly;
2. **0 `SCRIPT ERROR`** across the whole duel;
3. the `DuelLog` replay payload **reproduces the duel exactly** from the same seed and the same
   controller script — same events, same order, same final board. `ReplayTests` proves the payload
   is complete for a fragment; this proves it for a whole game;
4. no illegal action was ever offered: assert against `get_legal_actions()` / `get_legal_responses()`
   rather than against the board alone.

**Use the two REAL decks** (`Blue-Eyes Dragon Guard` and `Fairy-Tail Tribute Guard`) rather than
filler decks. That is the whole point: it is the first time the 77 cards meet each other with no
test arranging the board.

**Expect this to find real defects, and budget for them.** Nothing in the library has ever been
exercised in an unarranged sequence. Cards that pass in isolation can still interact wrongly, and
that is what this unit is for.

### Unit 3 — backend acceptance

The `DuelEngine` API is already the only way anything reaches the rules, which is what makes this
tractable. What is owed:

* a **headless acceptance entry point** that a backend can call without the Godot scene tree, and
  a documented contract for it;
* **hidden-information filtering asserted at the API boundary** for a whole duel, not per
  operation. `HiddenInfoTests` proves each operation filters; this must prove nothing leaks across
  a full game — including the batch-17 case where "you were not asked" would itself leak that a
  player's Deck held no copy;
* **determinism across processes**: the same seed and script, run twice in separate invocations,
  must produce byte-identical logs. Same-process determinism is already asserted per card;
* the **CI wiring** in `.github/` extended to run the scripted duels, with the runner's exit code
  authoritative (`Tools/run_tests.sh` already guarantees that).

### Unit 4 — the cleanup items, none of which is now blocked by anything

With no card unit left to derail, these are cheap and should simply be done:

* **`R35` / `Mirage Dragon` has never been re-checked against the `ja` locale.** Carried across
  **nine** checkpoints. The recorded conclusion — "the official database has no Q&A entry for cid
  6196" — was reached the `en` way that R40's methodology note explicitly warns about. **This is
  the last piece of unverified research in the project.**
* **`Tools/build_matrix.py` hard-codes "Ruling Verified" to `PENDING`** for every card carrying a
  ruling reference (`"PENDING" if ruling else "N/A"`). The column means *"this card carries a
  flagged ruling"*, not *"the ruling is unresolved"* — which is why 21 cards read `PENDING`
  although every ruling that blocks a card is CLOSED. It was left alone through batches 13–18
  because changing the tool's semantics mid-batch would move numbers a checkpoint was reporting.
  **That reason has now expired.** `Research/CARD_RULINGS.md` is the authority.
* **`docs/PROJECT_STATUS.md` is stale** and has been since before batch 13. Not read by any tool;
  it contradicts §0, which is the authority. Delete it or regenerate it from the matrix.
* **`Spiritual Wind Art - Miyabi` reads the printed Attribute** where batch 12 established the
  field reader is correct. Never live in the V1 pool; fix it when touching that card for any other
  reason.

### The order, and the one rule that has held for eighteen batches

**Unit 1, then unit 2, then unit 3.** Unit 4 is independent and can be taken whenever there is
room. Do not start unit 2 before unit 1 lands.

**And the rule that produced every clean batch in this project: build the gate first, from
synthetic cases, and make it green BEFORE the thing that needs it.** `EquipTests`, `ControlTests`,
`MovementTests`, `DeckAccessTests`, `CostLegalityTests`, `ImmunityTests`, the batch-17
opponent-decision gate, batch 18's `ChainTests` substitution section and `NegationImmunityTests`
were all written that way. **Every mutation survivor in the last four batches was a missing test,
not a broken implementation** — so the mutation pass stays non-optional, and a survivor is a
finding about coverage.

### Batch 16 — COMPLETE (kept for the record; it is done, not a plan)

One unit, one card. §8 recommended `The Monarchs Awaken` and predicted its subsystem would be
the declared-but-dead `CardInstance.unaffected_by_effects`, with six open questions. **That
prediction was right and, as usual, incomplete** — the bare `bool` could not express "other than
**this card**", and the research turned up an activation restriction the English text does not
carry (**six for six**) plus an authoritative correction to what the engine believed "Tribute
Summoned" meant. The full record is in §0 and in `Reports/TEST_RESULTS.md`.

| Unit | What it was | Result |
|---|---|---|
| A | **R12** research: cid 10963 supplement (2015-09-19) + both Q&A entries (fid 11352, fid 11871) + **ten** general 「効果を受けない」 rulings, `request_locale=ja`, plus a live re-fetch and character-for-character diff of the **English** text | **COMPLETE** — R12 CLOSED |
| A | the immunity gate (`EffectImmunity` + `ImmunityTests`, 250) + `RULES_SPEC.md` §18 and §10.9 | **COMPLETE** |
| A | the "Tribute Summoned" correction (`CardInstance.tribute_summoned`, `SummonRules`, the banish lease) | **COMPLETE** |
| A | `The Monarchs Awaken` (`MonarchsAwakenTests`, 177) | **COMPLETE** |

**What batch 16 proved about §8's own predictions, kept because the pattern is now six deep:**

* §8 predicted the declared vocabulary would be right and said to *verify it rather than assuming*.
  Verifying is what found the gap: the field's SHAPE was right, its TYPE was not enough.
* §8 predicted "Konami's general answer for 'unaffected' is narrower than English readers expect
  and it must be taken from the source, not from the phrase". **Exactly right**, and the source
  turned out to be ten Q&A entries attached to entirely different cards.
* §8 flagged the engine's reset points as "a guess baked into the engine" and demanded they be
  confirmed. They were confirmed **and they were right** — the first time in this series that a
  challenged guess survived unchanged.
* §8 asked whether a Tribute **Set** monster counts as "Tribute Summoned" and recorded the
  engine's answer as no. **The engine was wrong**, and three official Q&A entries say so.

---

### Batch 15 — COMPLETE (kept for the record; it is done, not a plan)

One unit, one card. §8 recommended `A Hero Emerges` and predicted its subsystem would be "a random
choice made by the OPPONENT from your hand, through the seeded `Rng` so replay survives", with
five open questions. **That prediction was right and, as usual, incomplete.**

| Unit | What it was | Result |
|---|---|---|
| A | **R15** research: cid 5915 supplement (2015-03-26) + **both** Q&A entries (fid 12566 「御前試合」, fid 8193 「虚無空間」, both 2017-03-24), `request_locale=ja`, plus a live re-fetch and character-for-character diff of the **English** text against `Data/cards/cards.json` | **COMPLETE** — R15 CLOSED |
| A | the random-choice gate (`HiddenInfoTests` 116 → 156) + `RULES_SPEC.md` §10.8 and §12.3 + three `EffectPrimitives` functions | **COMPLETE** |
| A | `A Hero Emerges` (`AHeroEmergesTests`, 197) | **COMPLETE** |

**What batch 15 proved about §8's own predictions, kept because the pattern is now five deep:**

* §8 predicted the randomness must go through the seeded `Rng` "and nowhere else, or the duel stops
  being replayable". **Correct**, and mutation M10 (swap in Godot's global RNG) proves the suite
  would notice.
* §8 predicted "one generic primitive with its own gate". **Nearly correct — it was three**, and
  the two it did not predict are the ones that carry the ruling.
* §8 predicted no new engine surface. **Correct** — no new event kind, location, permission, zone,
  Summon route or decision kind.
* §8 predicted an activation restriction the printed English text does not carry. **Correct for
  the fifth batch running.**
* §8 asked five open questions and **every one was answered from an official source.** It did
  **not** predict the fact that mattered most — that a resolution-time failure of the activation
  requirement suppresses the random choice **itself**. It is now `RULES_SPEC.md` **§10.8**.

**Twenty-one mutations, zero survivors** — the first batch in this project with no survivor on the
first pass. `Reports/TEST_RESULTS.md` carries the table and the three test-design rules that made
the difference, all of them learned from the survivors of batches 13 and 14.

---

### Batch 14 — COMPLETE (kept for the record; it is done, not a plan)

One unit, one card. §8 recommended `Witchcrafter Golem Aruru` and predicted its subsystem would be
"a Quick Effect that answers being targeted, including by an attack" with the open question being
whether an attack declaration counts. **That prediction was right and, as usual, incomplete.**

| Unit | What it was | Result |
|---|---|---|
| A | **R13** research: cid 14483 supplement (2020-07-04) + Q&A fid 22558 (2022-12-30), `request_locale=ja`, plus a live re-fetch and character-for-character diff of the **English** text against `Data/cards/cards.json` | **COMPLETE** — R13 CLOSED |
| A | `EffectPrimitives.is_targeted_by_a_live_opponent_activation()` (the batch's one new primitive) + `RULES_SPEC.md` §10.6 and §10.7 | **COMPLETE** |
| A | `Witchcrafter Golem Aruru` (`WitchcrafterGolemAruruTests`, 312) | **COMPLETE** |

**What batch 14 proved about §8's own predictions, kept because the pattern is now four deep:**

* §8 predicted the attack question was "a bounded question with an official answer". **Correct** —
  an attack declaration does count, and `GameEvent.Kind.ATTACK_TARGET_SELECTED` already existed
  and was already right.
* §8 predicted no new engine surface would be needed, on `Honest`'s precedent. **Correct** — one
  ten-line sibling primitive, and nothing else.
* §8 predicted an activation restriction the printed English text does not carry. **Correct for
  the fourth batch running**: the Damage Step is closed.
* §8 did **not** predict the fact that mattered most — that a dead target costs only the bounce
  and not the Special Summon. Nothing about the card's English text hints at it, and it inverts
  the shape every previous targeting card in the library happens to have. It is now
  `RULES_SPEC.md` §10.6.

**The two mutations that SURVIVED the first pass** are the batch's real finding and are recorded
in `Reports/TEST_RESULTS.md` in full: a negative test that asserted on the OUTCOME of an optional
effect instead of on the OFFER proves nothing, and a resolution-time re-check that nothing ever
reaches is not tested. Both were fixed by making the test harder, never by weakening the card.

---

### Batch 13 — COMPLETE (kept for the record; it is done, not a plan)

Two units. **Unit A was not a new card at all** — it was the authoritative correction §7 had
carried as an open defect against shipped, green code across two checkpoints.

| Unit | What it was | Result |
|---|---|---|
| A | re-fetch cid 8197 from the live official database and diff it against R42 Part D | matches character-for-character; the correction rests on the live source |
| A | the generic cost-legality rule + `RULES_SPEC.md` §10.5 + `CostLegalityTests` (56, NEW) | **COMPLETE** |
| A | the `One for One` correction (`OneForOneTests` 40 → 70) | **COMPLETE** — commit `26ef751` |
| B | **R20** research: cid 7574 supplement + Q&A fids 19235, 12970, 13385, 14540 | **COMPLETE** |
| B | `Honest` (`HonestTests`, 125) | **COMPLETE** — commit `00d3b97` |

**What batch 13 proved about §8's own predictions, kept because the pattern is now three deep:**

* §8 predicted `Honest`'s only new surface would be a **location** (`ActivationLocation.HAND` for
  a monster's effect). **Correct — and the location already existed.** No engine surface was
  added at all. RULES_SPEC §7.5 records why, so nobody builds it speculatively.
* §8 predicted an activation restriction the printed English text does not carry. **Correct**:
  0 ATK forbids the activation.
* §8 called unit A "the cheapest coherent unit in the repository". **It was not the cheapest** —
  doing it properly meant auditing every cost-paying card in the pool to decide whether the rule
  was card-local or generic, and building a synthetic-card gate for both the shape it bites and
  the shape it must not. It **was** the right one to do first: batch 13 started from a library
  with no known-incorrect card in it, which is what §8 actually wanted.

**The one defect the tests caught before shipping**, recorded so the mistake is not repeated:
`ActivationRules.damage_step_ok()` returns `true` **outside** the Damage Step by design, so
`DamageStepPermission.UNTIL_DAMAGE_CALC` alone does **not** mean "during the Damage Step". A card
whose printed window is a *named* part of the Battle Phase must state that in its own `condition`.
`RULES_SPEC.md` §7.2, `CARD_RULINGS.md` R20 Part C.

---

### Batch 12 — COMPLETE (kept for the record; it is done, not a plan)

> **Read this before the table below.** The plan is preserved verbatim because the work of
> reading every remaining card was paid for once. **Two of its claims were proved WRONG by R42
> and must not be re-used:**
>
> * `Damage Condenser` is **not** "the first Special Summon FROM THE DECK in the pool" —
>   `One for One` has done that since batch 10, and no new Summon surface was built (R42 Part E);
> * `Damage Condenser` did **not** have only two open questions — cid 6582 carries a hard
>   ACTIVATION restriction the printed English text does not mention (R42 Part C).
>
> The counts below ("Ten cards remain") are the batch-11 counts. The current counts are in §0
> and in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`: **70 / 77, seven remaining.**

**Ten cards remain**, and `Reports/CARD_IMPLEMENTATION_MATRIX.csv` is the authoritative list.
**Seven of the ten are blocked on an OPEN ruling and each needs a DIFFERENT new subsystem.**
Exactly **three** are ruling-free, and they are the recommended batch 12:

| Card | cid | Official text | New engine surface |
|---|---|---|---|
| `Spiritual Fire Art - Kurenai` | 6441 | "Tribute 1 FIRE monster; inflict damage to your opponent equal to that monster's original ATK." | **none** |
| `Spiritual Water Art - Aoi` | 6440 | "Tribute 1 WATER monster; look at your opponent's hand, then send 1 card from their hand to the GY." | **one small hidden-information operation** (§12) |
| `Damage Condenser` | 6582 | "When you take battle damage: Discard 1 card; Special Summon 1 monster from your Deck with ATK less than or equal to the battle damage you took, in Attack Position." | **the first Special Summon FROM THE DECK in the pool** |

**Why these three, and why in this order:**

* **`Kurenai` first, because it needs nothing new.** `EffectPrimitives.pay_tribute_cost()` /
  `can_pay_tribute_cost()` already exist and already carry a qualification predicate;
  `CardInstance.original_atk()` already answers "that monster's ORIGINAL ATK" — which is the one
  trap in the card, because `current_atk()` would be wrong and `Back-Up Rider` (batch 11) now
  proves the two really do differ. The damage is `change_life_points()` plus
  `check_life_point_loss()`, the shape `Chain Detonation` and `Judge of the Ice Barrier` use.
  It should be a pure consumer of existing primitives.
* **`Aoi` second, because it is `Kurenai` plus exactly one new thing.** The Tribute cost is the
  same mechanism with a different Attribute; what is genuinely new is **looking at the opponent's
  hand**, which `RULES_SPEC.md` §12 governs and which nothing in the pool has done. That is a
  hidden-information OPERATION, not a subsystem: the hand is already private state with a
  `private_to` convention on events, and what is missing is a revealed-to-one-player read plus a
  choice made from it. Build it as its own unit with its own tests **before** the card, the way
  every batch since 7 has done, and be careful that the choice goes through `ctx.ask()` so the
  duel stays replayable.
* **`Damage Condenser` third, because batch 11 just built the ground under it.** It is a Trigger
  Effect on `BATTLE_DAMAGE_INFLICTED` — the exact event `Vampiric Koala` now uses — but keyed on
  damage taken by its OWN controller rather than the opponent, so the two are mirror images and
  each is a control on the other. Its Damage Step timing is the `MANDATORY_TRIGGER` permission
  batch 11 exercised. What is new is that it Special Summons **from the Deck**, which nothing in
  the pool does: batch 10's DECK-ACCESS layer supplies the Deck read, and the ordinary Special
  Summon route supplies the rest, but the combination needs its own unit and its own shuffle
  question ([S1 p.5] — does a Deck looked through get shuffled when the Summon happens?).

**Settle Damage Condenser's two questions BEFORE writing it, with `request_locale=ja`:**
whether the ATK comparison uses the monster's ATK in the Deck (it must — there is nothing else to
read), and whether the Deck is shuffled afterwards. Neither is currently recorded.

**The seven that remain after batch 12, one subsystem each, all ruling-blocked:**

| Card | Ruling | The subsystem it needs |
|---|---|---|
| `Honest` | **R20** | a Quick Effect activated **from the HAND** during the **Damage Step** |
| `A Hero Emerges` | **R15** | a **RANDOM choice made by the OPPONENT** from your hand, through the seeded `Rng` so replay survives |
| `The Monarchs Awaken` | **R12** | "unaffected by the effects of cards other than this card" — `CardInstance.unaffected_by_effects` exists as a field with no subsystem behind it |
| `Fairy Tail - Sleeper` | **R5** | an effect that **REPLACES another effect's text** |
| `Hidden Springs of the Far East` | **R14** | Summons and activations that **cannot be negated**, plus targeting/destruction protection for Set cards. It is also the pool's **only Field Spell**, which batch 11 proved is a live distinction |
| `Witchcrafter Golem Aruru` | **R13** | a Quick Effect that answers **being targeted**, including by an attack |
| `Fairy Tail - Luna` | **R11** | an effect the **OPPONENT may pay to negate** |

Do them **one subsystem per unit**, and settle each ruling before the card, not after.

---

### The plan batch 11 was chosen from — kept for the record

**Batch 10 is CLOSED. Do not reopen any of it, and do not rewrite any gate.** Ten gates plus
four generic units are green and must stay so: `EquipTests`, `ControlTests`, `MovementTests`,
`BanishTests`, `LifePointCostTests`, `TrapMonsterTests`, `BattlePhaseRestrictionTests`,
`AttackRestrictionTests`, `ChoiceConstraintTests`, `DeckAccessTests`, the remains-on-field
override in `SpellTrapTests`, the tribute-value rule in `SummonTests`, the combination
enumeration in `SummonRules.tribute_combinations()`, and `DuelEngine._cost_events`.

**16 cards remain.** `Reports/CARD_IMPLEMENTATION_MATRIX.csv` is the authoritative list; do not
work from memory and do not plan from this file's prose. **Batch 11 is not planned yet.** Plan it
from the matrix, group it the way every batch since 7 has been grouped — a generic subsystem
unit with its own tests FIRST, then the cards that consume it — and settle any per-card ruling
**before** writing the card, not after.

The grouping below was produced by inspecting all 23 remaining cards at the start of batch 10.
Seven of them are now done; the rest is **still current** and is the starting point for batch 11.
**Re-derive it from the matrix rather than trusting this table blindly**, but do not throw it
away — the work of reading every remaining card has already been paid for once.

| Group | Cards still remaining | Needs a NEW engine subsystem? |
|---|---|---|
| ~~DECK ACCESS + qualified cost~~ | **DONE in batch 10** — all seven | the DECK-ACCESS layer, built |
| DESTRUCTION with an activation condition | `Stamping Destruction`, `Straight Flush`, `Burst Stream of Destruction`, `Chiron the Mage` | **no** — destruction + targeting already exist; `Burst Stream`'s "cannot attack this turn" is the existing attack restriction, and `Chiron`'s cost is a **qualified discard**, which batch 10 built. This is the cheapest coherent next batch. |
| ATK modification | `Back-Up Rider`, `Honest` (**R20**) | `Back-Up Rider` no — `gain_atk_until_end_of_turn()` exists. `Honest` **yes**: a Quick Effect activated **from the HAND** during the **Damage Step**, which nothing in the pool does. |
| Tribute-as-cost Spiritual Arts | `Spiritual Fire Art - Kurenai`, `Spiritual Water Art - Aoi` | mostly no — `pay_tribute_cost()` exists and `Kurenai` reads an **original** ATK, which `CardInstance.original_atk()` already answers. `Aoi` needs a **look at the opponent's hand**, which is a new hidden-information operation (§12) rather than a new subsystem. |
| Special Summon from a private zone | `Damage Condenser`, `A Hero Emerges` (**R15**) | partly — both Special Summon out of a hidden zone, and batch 10's Deck layer helps `Damage Condenser`. `A Hero Emerges` needs a **RANDOM choice made by the OPPONENT** from your hand, which the engine has never done; [S1 p.53] "Random" says only that neither player may know which card is chosen, so it must go through the seeded `Rng` to stay replayable. |
| LP gain on battle damage | `Vampiric Koala` | **no** — a trigger on battle damage plus `change_life_points()`. |
| Genuinely new subsystems, each a DIFFERENT one | `The Monarchs Awaken` (**R12** — "unaffected by the effects of cards other than this card"), `Fairy Tail - Sleeper` (**R5** — an effect that REPLACES another effect's text), `Hidden Springs of the Far East` (**R14** — Summons and activations that **cannot be negated**, plus targeting/destruction protection for Set cards), `Witchcrafter Golem Aruru` (**R13** — a Quick Effect that answers *being targeted*, including by an attack), `Fairy Tail - Luna` (**R11** — an effect the OPPONENT may pay to negate) | **yes**, and no two of them share one. `CardInstance.unaffected_by_effects` exists as a field but has no subsystem behind it; treat R12 as the place to build one. |

**Recommended shape for batch 11, if the matrix still agrees when you re-read it:** take the
**DESTRUCTION-with-a-condition group** (`Stamping Destruction`, `Straight Flush`,
`Burst Stream of Destruction`, `Chiron the Mage`) plus `Back-Up Rider` and `Vampiric Koala`.
Six cards, **no new subsystem at all**, every one of them `Special Ruling Needed = NO`, and it
would take the library to 67 / 77 while leaving all five genuinely-new-subsystem cards and the
four ruling-blocked ones to be tackled one subsystem per unit afterwards. That ordering is a
recommendation, not a decision — make it from the matrix.

**Seven rulings are still OPEN and each blocks its own card: R5, R11, R12, R13, R14, R15, R20.**
Two more, **R1 and R2**, belong to cards that are already implemented and are carried as
recorded questions, not as gaps. When settling any of them, **use `request_locale=ja`** on the
Konami database — see R40's methodology note, which cost this session real time.

**Also scheduled and NOT optional:** the **ObjectDB characterisation task** (§7). It is now at
**204316 at exit, ~26.9 per new assertion** — up from the previous checkpoint's ~21.6, and
below the ~34.9 and ~44.6 before that. That is now three falls and one rise inside five
checkpoints, which is still not a trend and still has **no measured explanation**; none may be
recorded until one is measured. It fails nothing, so it must not derail a card unit, but it
**must be characterised or fixed before Phase 7**.

**Also worth one cheap unit at some point:** re-check the `request_locale=en` conclusions
already recorded in `CARD_RULINGS.md` against the `ja` locale — specifically **R35**'s "the
official Konami database has no Q&A entry for cid 6196". That claim was reached the same way
this session's near-miss was, and it has NOT been re-checked. Do not silently upgrade R34
part D's confidence without doing the lookup.

---

The specifications below are kept for the record; they are **done**, not a plan.

#### DONE — the generic lingering material-choice constraint (`ChoiceConstraintTests` 137/137)

`GameState.choice_constraints` with `require_choice_this_turn()` / `required_choice_ids()` /
`choice_selection_ok()` / `clear_choice_constraints_for()`, normatively stated in
`RULES_SPEC.md` §5.9 and decided in **R39**. Keyed by (player, scope, target, turn); it changes
no control and no ownership. Consumed on **both** Tribute channels —
`SummonRules.tributes_satisfy()` / `tribute_combinations()` for Summons and Sets, and
`EffectPrimitives.can_pay_tribute_cost()` / `pay_tribute_cost()` for costs. Cleared by
`GameState.move_card()` (leaving a Monster Zone), `_transfer_control()`,
`set_battle_position()` (face-up → face-down) and `TurnFlow._end_of_turn_cleanup()`. Written and
green against a synthetic grant Spell, from both seats, before `Soul Exchange` existed.

Two supporting mechanisms landed with it and are equally generic:
`EffectDef.activation_confirmed` + `ActivationRules.ACTIVATION_CONDITION_EFFECT_ID` (a
consequence of a confirmed CARD activation that survives EFFECT negation but not ACTIVATION
negation, fired when the Chain Link is processed), and `CardInstance.field_revision` +
`ChainLink.target_field_revisions` + `EffectPrimitives.target_kept_field_identity()` (a target
that left and returned is a different stay on the field, which a zone check alone cannot tell).

#### DONE — `Soul Exchange` (`SoulExchangeTests` 174/174)

Two clauses, exactly as specified below and with **R7 now CLOSED as R39**. The permission clause
targets one opposing monster and calls `require_choice_this_turn()` at **resolution**, after a
`target_kept_field_identity()` re-check. The Battle Phase sentence is an activation
**condition** using the existing turn-scoped `skip_battle_phase_this_turn` restriction — not
`battle_phase_skips`, which has a different lifetime and belongs to `Runick Flashing Fire`. All
four questions the specification below said had to be settled first were settled first, in R39,
with per-part confidence recorded: costs **are** covered (keeping their own qualifications), the
constraint applies at resolution and is re-checked when it matters, it substitutes a material
rather than granting a Summon or changing the count, and an opposing `Kaiser Sea Horse` can
supply two Tributes while your own can count as one.

The original specification is kept verbatim immediately below, as the record of what was
asked for and of the fact that R7 really was settled before any code was written.

**`Soul Exchange` is the ONLY card left in batch 9.** Verified official text
(`Data/cards/cards.json`, cid 5099), **Normal Spell**, one copy, deck 2:

> "Target 1 monster your opponent controls; this turn, if you Tribute a monster, you must
> Tribute that target, as if you controlled it. You cannot conduct your Battle Phase the turn
> you activate this card."

**Two clauses.** `Research/CARD_RULINGS.md` **R7**, which is still **OPEN** and must be settled
before the card is written.

**Do the generic FORCED-TRIBUTE unit first, as its own unit with its own tests**, the way the
remains-on-field override was done this session and the way `BanishTests`,
`LifePointCostTests`, `TrapMonsterTests` and `BattlePhaseRestrictionTests` were. What is
genuinely new is a **turn-scoped lingering restriction that CONSTRAINS a future choice** rather
than forbidding an action outright: every other restriction in the engine answers "may I?",
and this one answers "if you do, it must be THIS card". Nothing in the engine has that shape
yet, so it needs building and testing before the card exists.

Things already established that must NOT be re-derived:

| You need | Use this — it exists and is green | Do NOT |
|---|---|---|
| "you cannot conduct your Battle Phase THE TURN you activate this card" | the existing turn-scoped `skip_battle_phase_this_turn` restriction, already consumed by `TurnFlow.can_enter_battle_phase()` | the `battle_phase_skips` list — a **different** lifetime, and the one `Runick Flashing Fire` uses (see §2.4 and R32) |
| "as if you controlled it" | **nothing** — it changes no control and no ownership | `GameState.change_control()`. The card permits the Tribute and nothing else; the monster goes to its **OWNER's** Graveyard [S1 p.52] |
| the monsters a player may Tribute | `SummonRules.tribute_candidates()` | a new candidate list |
| how much a Tribute is worth | `SummonRules.tribute_value()` — and note it now correctly answers 1 for a face-down or negated card | re-deriving it |

The hard parts to settle before writing anything, and the reason **R7 must be closed first**:

* **Which Tributes does "if you Tribute a monster" cover?** A Tribute Summon certainly. Does it
  also cover a Tribute paid as an activation **COST** (`Kaibaman`, `Dragonic Tactics`)? Those
  are two different channels in this engine — `SummonRules.tributes_satisfy()` versus
  `EffectPrimitives.pay_tribute_cost()` — and the answer decides whether the restriction lives
  in one place or two. **Settle it against a source, do not guess**, and record the confidence.
* **What happens when the target leaves the field**, or stops being Tributable, before any
  Tribute is attempted? The restriction is acquired at activation and targets at activation, so
  the target is fixed then and re-checked when it matters.
* **Is it a restriction or a substitution?** "You must Tribute that target" constrains WHICH
  monster is chosen; it does not add a Tribute or change how many are needed. A Level 6 monster
  still needs exactly one Tribute, and that one must be the target.
* **`Kaiser Sea Horse` interacts with it directly** — both cards are in deck 2, and the
  combination (Tribute the opponent's monster for a Level 7+ LIGHT Summon) is a real deck line.
  Test it, because it is the reason both cards are in the same deck.

Both bullets must be implemented and the card must be tested against the **real pool**, not
only synthetically: the opponent's monsters are real, and deck 2 holds `Metaphys Armed Dragon`
and `Witchcrafter Golem Aruru` for the Summon to aim at.

The specifications below are kept for the record; they are **done**, not a plan.

#### DONE — `Mirage Dragon` (`MirageDragonTests` 121/121)

One CONTINUOUS clause calling
`forbid_card_activation(ctx, ctx.opponent_id(), Category.TRAP, Phase.BATTLE)`, and that is the
whole implementation — the work was done in unit A before the card existed. No card-specific
state and no card name in `ActivationRules`. Recorded as **R35**, including the honest research
result on R34 part D.

#### DONE — the generic "it remains on the field" override (`SpellTrapTests` 27 → 49)

`DuelEngine.REMAINS_ON_FIELD_EFFECT_ID`, a declarative marker in the shape
`SummonRules.CONTROL_LIMIT_EFFECT_ID` already uses. Asked AFTER the kind question, so it can
only ever KEEP a card; **not** negation-aware, because negation does not send a card to the
Graveyard.

#### DONE — `Swords of Revealing Light` (`SwordsOfRevealingLightTests` 122/122)

Three clauses of three different shapes. **R6 is CLOSED as R36.**

#### DONE — `Maiden with Eyes of Blue` (`MaidenWithEyesOfBlueTests` 139/139)

Two clauses sharing ONE once-per-turn allowance. **R3 is CLOSED as R37.** Added
`EffectPrimitives.may()`, the pool's first optional step inside a resolving effect.

#### DONE — `Kaiser Sea Horse` (`KaiserSeaHorseTests` 57/57)

One rules-query clause. **R8 is CLOSED as R38**, and the card's suite caught a real engine
defect in `SummonRules.tribute_value()` (face-down cards were still worth 2).

#### The original UNIT C plan, kept for the record — `Kaiser Sea Horse` is now DONE

`Soul Exchange` (**R7**) and `Kaiser Sea Horse` (**R8**). Two things already established that
must not be re-derived:

* **`SummonRules.TRIBUTE_VALUE_EFFECT_ID` (`"counts_as_two_tributes"`) already exists** and
  `tribute_value()` already consults it with `ctx.params["summoning_card"]` set. `Kaiser Sea
  Horse` declares a CONTINUOUS `EffectDef` with that id whose `condition` returns true only for
  the Tribute Summon of a **LIGHT** monster. **Do not globally set a numeric `tribute_value = 2`.**
* **`Soul Exchange` needs the turn-scoped `skip_battle_phase_this_turn` restriction that already
  exists** — **not** the `battle_phase_skips` list `Runick Flashing Fire` uses. Those are
  different lifetimes and §2.4 says why. And **do not implement it by taking control of the
  opponent's monster**: the text says "as if you controlled it", which permits the Tribute and
  changes nothing about control or ownership. The card goes to its **owner's** Graveyard.

Read `Reports/CARD_IMPLEMENTATION_MATRIX.csv` for the authoritative list of the 28 remaining
cards; do not work from memory.

**Also scheduled and NOT optional:** the **ObjectDB characterisation task** (§7). It is now at
**164444 at exit, ~44.6 per new assertion — the FIFTH consecutive rising checkpoint** and again
the highest per-assertion figure so far. It still fails nothing, so it must not derail a card
unit, but it **must be characterised or fixed before Phase 7**, and no explanation may be
recorded for it that has not been measured.

#### 1. `The Phantom Knights of Shadow Veil` — Trap Monsters first

Verified official text (`Data/cards/cards.json`, cid 11404), **Normal Trap**, Spell Speed 2:

> "Target 1 face-up monster you control; it gains 300 ATK/DEF. When an opponent's monster
> declares a direct attack while this card is in your GY: Special Summon this card in Defense
> Position as a Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300). (This card is NOT treated as
> a Trap.) If Summoned this way, banish this card when it leaves the field."

**Three clauses — implement all three, not only the banish one.**

| # | Clause | Type | Notes |
|---|---|---|---|
| 1 | "Target 1 face-up monster you control; it gains 300 ATK/DEF." | CARD_ACTIVATION (Normal Trap) | Reuse `own_monsters()` / `surviving_own_monster_target()` from unit A. It is ATK **and** DEF, and **no duration is printed**, so it is *not* an end-of-turn modifier — do not reach for `gain_atk_until_end_of_turn()`. |
| 2 | "When an opponent's monster declares a direct attack while this card is in your GY: Special Summon this card in Defense Position as a Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300). (This card is NOT treated as a Trap.)" | TRIGGER, from `GRAVEYARD` | Keys on `ATTACK_DECLARED` with `attack_is_direct`. **This is the Trap-Monster unit.** |
| 3 | "If Summoned this way, banish this card when it leaves the field." | replacement | Conditional on the summon marker; use the existing `card_memory` / `summoned_by_procedure_id` channel rather than a new flag. |

**Do the generic Trap-Monster gate first, as its own unit with its own tests**, the way
`BanishTests` and `LifePointCostTests` were. What is genuinely new: a card that is a **Trap in
the Graveyard and a MONSTER while in the Monster Zone**, with an **overridden type line** the
printed `CardDef` does not have. Its Trap-card identity and its monster identity must be kept
distinct — do **not** fake it as an ordinary monster, and do **not** mutate the shared `CardDef`
(it is the immutable canonical definition and is shared by every copy). The gate must pin down:
which zone it occupies, what `is_monster()` answers in each, the overridden Level / Attribute /
Type / ATK / DEF, that it is **not** treated as a Trap while summoned, what happens when it
leaves the Monster Zone, and that the Special Summon emits real summon events and opens a real
summon-response window (so it can be negated). `SummonRules.begin_special_summon()` +
`complete_summon()` is the existing route — go through it, do not bypass it.

#### 2. `Runick Flashing Fire` — the Battle Phase restriction first

Verified official text (`Data/cards/cards.json`, cid 17374), **Quick-Play Spell**, Spell Speed 2:

> "Activate 1 of these effects, but skip your next Battle Phase after activation;●Target 1
> Special Summoned monster your opponent controls; destroy it, then banish the top 2 cards of
> your opponent's Deck.●Special Summon 1 "Runick" monster from your Extra Deck to the Extra
> Monster Zone.You can only activate 1 "Runick Flashing Fire" per turn."

**R1 governs it and must be honoured, not replaced by an assumption.** R1 fixes the hard part:
**"skip your next Battle Phase" applies ON ACTIVATION, even if the chosen effect is later
negated** — so it is paid at activation, not in `resolve`.

**Do the generic Battle-Phase-restriction unit first**, as authoritative turn state, **never in
the UI**. `ContinuousEffects.restrict_player()` is already consumed by
`TurnFlow.can_enter_battle_phase()` (see §6a), but a *continuous* restriction is the wrong shape
here: this one is acquired at a moment, belongs to a specific future turn, and is **consumed**.
Model it as authoritative state on `PlayerState` in the shape the **leases** use, and test:
acquisition · exactly which Battle Phase is affected · turn ownership · next-turn semantics ·
what happens if that turn would not have had a Battle Phase anyway (turn 1) · consumption and
reset · two activations across turns · replay determinism.

Then the card. Both bullets must be implemented. Bullet 2 can **never** have a legal target —
both Extra Decks are empty — so it must report "no legal choice" rather than being omitted, and
must be tested synthetically with a real-pool assertion, the R21/R23/R2 treatment now used four
times. Bullet 1 targets a **Special Summoned** monster specifically; `banish_top_of_deck()`
already exists from unit A and already handles a Deck shorter than 2. "You can only activate 1
per turn" is `opt_named_activation()`, which is a **different** restriction from
`opt_named_effect()`.

---

The two completed cards below are kept for the record; they are **done**, not a plan.

#### DONE — `Junk Blader` (`JunkBladerTests` 73/73)

One clause, banish as a COST, `gain_atk_until_end_of_turn()`. **No once-per-turn is printed and
none was added** — the limit is the cost running out. Never live in the pool: it is the only
"Junk" card and there is one copy, so the only card that could pay the cost is the one that has
to be face-up on the field to activate.

#### DONE — `Judge of the Ice Barrier` (`JudgeOfTheIceBarrierTests` 154/154)

All three clauses. Clause 1 is CONTINUOUS (`respond_to_event`), not a Trigger Effect. R2 honoured
including its sub-question — Judge in the GY does **not** satisfy "if you control an 'Ice
Barrier' monster". Clause 2 uses `EffectDef.targets_valid` for its heterogeneous target set;
clause 3's banish is a COST. The clause enumeration that was persisted here has been consumed and
is left below for reference.

#### Reference — the persisted `Judge of the Ice Barrier` enumeration (CONSUMED)

Verified official text (`Data/cards/cards.json`), WATER / Warrior / Level 4 / 1800 ATK / 900 DEF:

> "While you control another "Ice Barrier" monster, each time your opponent activates a card or
> effect by paying LP, they lose 500 LP. You can only use each of the following effects of "Judge
> of the Ice Barrier" once per turn. You can target 1 or 2 "Ice Barrier" monsters in your GY and
> 1 or 2 cards in your opponent's GY; shuffle them into the Deck. If you control an "Ice Barrier"
> monster: You can banish this card from your GY, then target 1 Attack Position monster on the
> field; change it to Defense Position."

**Three effect clauses**, plus a restriction sentence that governs two of them:

| # | Clause | Type | Notes |
|---|---|---|---|
| 1 | "While you control **another** 'Ice Barrier' monster, each time your opponent activates a card or effect **by paying LP**, they lose 500 LP." | CONTINUOUS | "another" excludes Judge itself. **Needs a new engine concept** — see below. |
| 2 | "You can target 1 or 2 'Ice Barrier' monsters in your GY **and** 1 or 2 cards in your opponent's GY; shuffle them into the Deck." | IGNITION, from `FIELD_FACE_UP` | Heterogeneous target set → use `EffectDef.targets_valid` (the batch-5 mechanism), **not** a flat candidate list plus a count. Both groups are required ("and"), 1–2 from each, so 2–4 targets. "Shuffle into the Deck" → `shuffle_into_deck()`, which clears `revealed_to`. |
| 3 | "If you control an 'Ice Barrier' monster: You can **banish this card from your GY**, then target 1 Attack Position monster on the field; change it to Defense Position." | IGNITION, from `GRAVEYARD` | The banish is a **COST** (it sits before "then target"): `pay_banish_cost()` in `pay_cost`, never in `resolve`. Targets **either** player's Attack Position monsters. |
| — | "You can only use **each** of the following effects … **once per turn**." | restriction | A hard once-per-turn on the **name**, applying to clauses 2 and 3 **separately**. Use `opt_named_effect()` on each — not `opt_instance()`, and not one shared key. |

**R2 governs this card and must be preserved, not reinterpreted.** All three clauses are
essentially **never live in the V1 pool**: Judge is the only "Ice Barrier" card in either deck.
Handle exactly the way `Apprentice Magician`'s Spell Counter clause (R21) and
`Fairy Tail - Rella`'s Equip clause (R23) were — implement in full, test against a **synthetic**
"Ice Barrier" monster that can satisfy the clause, and assert against the **real pool** that no
card can, so the fact cannot rot silently. **R2 also fixes one sub-question: Judge sitting in the
GY does NOT satisfy "if you control an 'Ice Barrier' monster" — the GY is not "control".** Clause
3 therefore needs a *different* Ice Barrier monster on the field, which is why it too is
never-live. Assert that negative directly.

**Clause 1 needs an engine addition and is why this session stopped here.** The engine has no
notion of "a card or effect activated **by paying LP**": no card in the V1 pool pays LP as a
cost, so the trigger source does not exist either. Doing it properly means a minimal generic
LP-cost concept — a way for an activation to record that its cost included LP, carried on the
existing `COST_PAID` event / `ChainLink.cost_payload` channel — and then a synthetic card that
pays LP so the clause can actually be observed firing. **Treat that as its own sub-unit, with its
own targeted test, before writing the card**, exactly as unit A was done before the cards. Do not
fake it with a flag only Judge reads, and do not skip the clause.

#### Reference (CONSUMED) — `Junk Blader`

> "You can banish 1 "Junk" monster from your Graveyard; this card gains 400 ATK until the end of
> this turn."

EARTH / Warrior / Level 4 / 1800 ATK / 1000 DEF. One clause, an **IGNITION** effect from
`FIELD_FACE_UP`. The banish is a **COST** (before the semicolon): `pay_banish_cost()` in
`pay_cost`. The gain is `gain_atk_until_end_of_turn()` (batch 4), which already expires in
`TurnFlow._end_of_turn_cleanup()` and already outlives its source. **No once-per-turn is
printed** — do not add one. Check whether any "Junk" monster exists in either deck; if none does,
this is another never-live cost and needs the R21/R23 synthetic treatment plus a real-pool
assertion.

#### Reference (STILL TO DO — see the plan above) — `The Phantom Knights of Shadow Veil`

> "Target 1 face-up monster you control; it gains 300 ATK/DEF. When an opponent's monster declares
> a direct attack while this card is in your GY: Special Summon this card in Defense Position as a
> Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300). (This card is NOT treated as a Trap.) If
> Summoned this way, banish this card when it leaves the field."

Normal Trap. **Three clauses, and the banish is only one of them — implement all three.**
(a) the Trap activation, targeting "1 face-up monster you control" — reuse
`own_monsters()` / `surviving_own_monster_target()`, both added this batch; note it is
ATK **and** DEF, and no duration is printed, so it is not an end-of-turn modifier.
(b) the GY trigger on an opponent's monster declaring a **direct** attack (`ATTACK_DECLARED` with
`attack_is_direct`), Special Summoning **itself from the GY** as a Normal Monster with an
overridden type line — the card becomes a monster and is **not** a Trap while on the field, so
its Trap-card state and its monster state must be kept distinct.
(c) "if Summoned this way, banish this card when it leaves the field" — a **replacement** for the
usual departure, conditional on `summoned_by_procedure_id` / a card-memory marker, using the
existing `card_memory` channel rather than a new flag.

#### Reference (STILL TO DO — see the plan above) — `Runick Flashing Fire`

> "Activate 1 of these effects, but skip your next Battle Phase after activation;●Target 1 Special
> Summoned monster your opponent controls; destroy it, then banish the top 2 cards of your
> opponent's Deck.●Special Summon 1 "Runick" monster from your Extra Deck to the Extra Monster
> Zone.You can only activate 1 "Runick Flashing Fire" per turn."

Quick-Play Spell, Spell Speed 2. **R1 governs it and must be honoured, not replaced by an
assumption.** Both bullets must be implemented even though the second can never have a legal
target (both Extra Decks are empty) — it must report "no legal choice" rather than being omitted,
and must be tested synthetically with a real-pool assertion that no legal target exists. **R1 also
fixes the hard part: "skip your next Battle Phase" applies ON ACTIVATION, even if the chosen
effect is later negated** — so it is paid at activation, not in `resolve`. Also: bullet 1 targets
a **Special Summoned** monster specifically; `banish_top_of_deck()` already exists from unit A and
already handles a Deck shorter than 2; and "You can only activate 1 per turn" is
`opt_named_activation()`, which is a different restriction from `opt_named_effect()`.

---

The unit-A specification below is kept for the record; it is **done**, not a plan.

**UNIT A — write the generic gate FIRST, before any card.** This is the pattern that has now paid
off three times (`EquipTests`, `ControlTests`, `MovementTests`), and in batch 7 it is the reason
units C and D found no engine defect at all: the gate had already flushed them out. Add
`Tests/rules/BanishTests.gd` and make it pass before writing a single batch-8 card.

What is genuinely new is **TEMPORARY banishing with a stated return timing**. Banish as a COST and
banish as an EFFECT are already two separate primitives (batch 4, `pay_banish_cost()` vs
`banish_target()`) and must stay two. What does not exist is "banished until the End Phase, then
returned" — which needs the same **lease-with-an-end-condition** shape `Enums.ControlDuration` and
`GameState.control_leases` use for control, expiring through the same kind of hook
`expire_control_leases()` uses. Do **not** invent a second, differently-shaped mechanism; read
`ControlTests` and `GameState.change_control()` first and mirror them. The gate must also pin down
face-up vs face-down banishing (a face-up banished card is public, `RULES_SPEC.md §12`), that a
returning monster comes back as a **Special Summon** or not according to each card's own text, and
that a card banished from the field loses its Equip Cards and control leases exactly as any other
departure does.

**UNIT B onwards — the cards.** Five, all needing the above:

| Card | Note |
|---|---|
| `Interdimensional Matter Transporter` | banish own monsters until the End Phase — the card the temporary-banish lease exists for |
| `Judge of the Ice Barrier` | **R2** — all three effects reference "Ice Barrier" monsters and Judge is the only one in either deck, so the 1st and 3rd are essentially never live. Implement them in full anyway. Confirm Judge in the **GY** does not satisfy "if you control an 'Ice Barrier' monster" — the GY is not "control". |
| `Junk Blader` | banish as a cost |
| `The Phantom Knights of Shadow Veil` | |
| `Runick Flashing Fire` | **R1** — its second bullet Special Summons from the **Extra Deck**, which is empty in both decks, so that branch can never have a legal target. It must still be implemented and must report "no legal choice" rather than being omitted. Also: "skip your next Battle Phase" applies **on activation**, even if the chosen effect is later negated. |

Two cards in this group have never-live clauses (R1, R2). Handle them the way
`Apprentice Magician`'s Spell Counter clause (R21) and `Fairy Tail - Rella`'s Equip clause (R23)
were: implement in full, test against a **synthetic** card that can satisfy the clause, and assert
against the **real pool** that no card can — so the fact cannot rot silently.

**Also scheduled and not forgotten:** the ObjectDB leak (§7) must be characterised or fixed
before Phase 7. It is a harness/object-lifetime issue, not a rules failure, and it does not
belong inside a card batch.

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

* **Batch 5 — the counter monster, the second Equip group, and negation**: `Apprentice Magician`,
  `Kunai with Chain`, `Fairy Tail - Rella`, `Champion's Vigilance`. Completes the pool's Equip
  group and its single Counter Trap.
* **Batch 6 — Flip Summon negation and the control-change group**: `Aussa the Earth Charmer`,
  `Eria the Water Charmer`, `Wynn the Wind Charmer`, `Enemy Controller`. Between them they
  required the Flip Summon declaration architecture and the whole owner-vs-controller subsystem.
  This batch **completes the pool's control-change group**.
* **Batch 7 — the movement group, in four units**: the generic movement/excavation gate (unit A),
  then `Compulsory Evacuation Device`, `Kaiser Glider`, `A Wingbeat of Giant Dragon` (unit B),
  `Phoenix Wing Wind Blast`, `Spiritual Wind Art - Miyabi`, `Chain Detonation`, `Chain Healing`
  (unit C) and `Crystal Seer` (unit D). Between them they introduced the whole movement and
  excavation subsystem, resolution-time target re-checks across the field and for control, and
  the first card-facing read of the Chain Link position. This batch **completes the pool's
  movement group**.

The step to do next is spelled out under **"The NEXT step — batch 8"** above.

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

Primitives added by batch 7 units C+D: `surviving_field_target()`,
`surviving_opponent_field_target()`, `activated_chain_link_number()`,
`return_self_by_chain_link()`. Test-side: `TestFixtures.effect_negator()` and
`TestFixtures.build_chain_to_depth()`.

Primitives added by batch 7 (units A+B): `cards_on_field()`, `opponent_field_cards()`,
`return_to_hand()`, `return_target_to_hand()`, `place_on_deck()`, `place_target_on_deck()`,
`shuffle_into_deck()`, `add_to_hand()`, `excavate()`, `return_excavated()`,
`battle_opponent_of()`, `destroyed_and_sent_to_gy_condition()`. Engine-side:
`Enums.Zone.EXCAVATED`, `Enums.MoveReason.ADDED_TO_HAND` / `EXCAVATED`,
`Enums.is_return_to_deck()` / `deck_position_for()`, `GameState.reveal()` / `excavate()` /
`excavated_cards()`, `PlayerState.excavated`, and the `CARD_ADDED_TO_HAND` / `CARD_REVEALED` /
`CARD_EXCAVATED` events.

Primitives added by batch 6: `opponent_monsters()`, `take_control_of_target()`,
`charmer_take_control()`. Engine-side: `GameState.change_control()`, `can_change_control()`,
`control_leases_for()`, `end_control_lease()`, `drop_control_leases_for()`,
`expire_control_leases()`, `GameState.pending_summon_card_id`,
`SummonRules.begin_flip_summon()`, `SummonRules.opposite_face_up_position_of()`.
Test-side: `TestFixtures.flip_effect_monster()`, `summon_negator()`, `count_events_for()`.

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

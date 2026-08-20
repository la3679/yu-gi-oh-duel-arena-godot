# Project status

A public-facing summary of where Duel Arena stands, synchronised from the authoritative
internal checkpoint.

**Checkpoint date:** 2026-08-14 · **Phase 5, batch 9 — PARTIAL (unit A only)**

> **Sources of truth.** The numbers below are copied from
> [`../PROJECT_STATE.md`](../PROJECT_STATE.md),
> [`../Reports/TEST_RESULTS.md`](../Reports/TEST_RESULTS.md) and
> [`../Reports/CARD_IMPLEMENTATION_MATRIX.csv`](../Reports/CARD_IMPLEMENTATION_MATRIX.csv),
> which are updated at every checkpoint. **If this file and those disagree, they are right and
> this file is stale.** Card counts are computed by `python Tools/build_matrix.py` and are never
> written by hand.

---

## Headline

| | |
|---|---|
| **Phase** | 5 of 11 — the card effect library |
| **Batch** | 9 — **partial**: the generic gate is complete, no batch-9 card is started |
| **Cards implemented** | **49 / 77** |
| **Cards tested** | **49 / 77** |
| **Cards remaining** | **28** |
| **Official text verified** | **77 / 77** |
| **Assertions** | **5,509 passed / 0 failed** |
| **Suites** | **63** |
| **SmokeCheck** | **PASS** |
| **Engine** | Godot `4.7.1.stable.official.a13da4feb`, headless |
| **ObjectDB at exit** | 164,444 leaked instances — known, tracked, not a rules defect |

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules | 21 | 1,797 | 1,797 | 0 |
| Per-card | 41 | 3,666 | 3,666 | 0 |
| Interaction | 1 | 46 | 46 | 0 |
| Scripted duel | 0 | 0 | 0 | 0 |
| **Total** | **63** | **5,509** | **5,509** | **0** |

---

## Phases and gates

| Phase | Goal | Status |
|---|---|---|
| 0 | Data inspection, Godot install and verification | **complete** |
| 1 | Authoritative TCG rules research | **complete** |
| 2 | Per-card official text and rulings research (77 cards) | **complete** |
| 3 | Architecture and scaffolding | **complete** |
| 4 | Core rules engine | **complete** |
| **5** | **Card effect library** | **in progress — 49/77** |
| 6 | Automated acceptance / scripted duel coverage | not started |
| 7 | Basic playable UI (local human vs human) | not started |
| 8 | Arena and presentation | not started |
| 9 | Local privacy UX (pass-and-play handoff) | not started |
| 10 | Asset polish and packaging | not started |
| 11 | Full acceptance | not started |

| Gate | Status |
|---|---|
| A — research complete | **MET** |
| B — core engine complete | **MET** |
| C — card library complete | not met |
| D — playable prototype | not met |
| E — presentation complete | not met |
| F — final acceptance | not met |

---

## What is complete

**Engine subsystems** — all done and under test:

turn flow · Normal / Tribute / Flip / Special Summon · Summon declaration and **Summon
negation** (including Flip Summons) · the Chain and Fast Effect Timing state machine (boxes
A–E) · Spell Speed and the response rule · activation legality · costs kept separate from
effects · targeting with **resolution-time re-validation** · effect / activation / continuous
negation · the five-sub-step Damage Step and its activation restriction · battle, attack
declaration and attack replay · attack **prevention** vs attack **negation** vs card-class
**activation lock** · Battle-Phase skip as turn state · continuous effects and the two-pass
recompute · the Equip subsystem · counters · owner-vs-controller and control leases · movement,
Deck placement and excavation · permanent and temporary banishment with return leases · LP
payment as a cost · Trap Monsters · hidden information · seeded RNG, action logging and
deterministic replay.

**Card batches:**

| Batch | Group | Status |
|---|---|---|
| 1 | The 9 vanilla Normal Monsters | complete |
| 2 | Resolution-time Special Summon family | complete |
| 3 | Continuous-Trap revival, summoning procedures, first Equip group | complete |
| 4 | Remaining Continuous Traps + the Continuous Spell — completes the Continuous group | complete |
| 5 | Counter monster, second Equip group, negation — completes the Equip group | complete |
| 6 | Flip Summon negation + control change — completes the control-change group | complete |
| 7 | Movement and excavation (four units) — completes the movement group | complete |
| 8 | Banishment, LP costs, Trap Monsters, Battle-Phase restriction | complete |
| 9 | Attack restriction / negation | **unit A only** |

**Batch 9 unit A** added the generic attack-restriction / attack-negation gate
(`AttackRestrictionTests`, 229 assertions). It established that attack prevention, attack
negation and a card-class activation lock are three separate things, consumed two pieces of
previously unused engine vocabulary, added `RULES_SPEC.md §4.6, §6.4, §11.1, §11.2` and ruling
**R34**, and caught three test-harness defects. **No engine defect was found and none was
introduced.** All 5,280 assertions from the previous checkpoint pass unchanged, and
5,509 − 5,280 = 229 is exactly the new suite.

---

## What remains

**28 cards**, not yet implemented and honestly reported as `NOT_IMPLEMENTED` in the matrix:

`A Hero Emerges` · `Back-Up Rider` · `Burst Stream of Destruction` · `Cards of Consonance` ·
`Chiron the Mage` · `Damage Condenser` · `Divine Dragon Apocralyph` · `Dragon Shrine` ·
`Fairy Tail - Luna` · `Fairy Tail - Sleeper` · `Herald of Creation` ·
`Hidden Springs of the Far East` · `Honest` · `Kaiser Sea Horse` · `Maiden with Eyes of Blue` ·
`Mirage Dragon` · `Soul Exchange` · `Spiritual Fire Art - Kurenai` ·
`Spiritual Water Art - Aoi` · `Stamping Destruction` · `Straight Flush` ·
`Swords of Revealing Light` · `The Monarchs Awaken` · `The White Stone of Legend` · `Trade-In` ·
`Vampiric Koala` · `White Elephant's Gift` · `Witchcrafter Golem Aruru`

**The next step is `Mirage Dragon`**, batch 9 unit B card 1. Its full plan is in
`PROJECT_STATE.md` §8.

Beyond Phase 5: scripted-duel acceptance coverage (Phase 6), then the playable UI (Phase 7),
then presentation (Phase 8+). None of these is started.

---

## Open questions and known gaps

| Item | Status |
|---|---|
| **R3, R6, R7, R8** | **OPEN** rulings, for `Maiden with Eyes of Blue`, `Swords of Revealing Light`, `Soul Exchange` and `Kaiser Sea Horse`. Batch 9 unit A settled the generic mechanisms these cards will use, not the per-card questions. |
| **R34 part D** | **MEDIUM-HIGH**, reasoned from Problem-Solving Card Text rather than a quoted ruling, and explicitly flagged for re-checking against an official source. Isolated behind one predicate, so a correction is a one-place change. |
| **Simultaneous-LP-zero (a draw)** | **Unexercised** — the only remaining item on the core-rules coverage list. A *reachability* gap, not a missing implementation: no card in this 77-card pool can drive both players to 0 LP at once. Checked rather than assumed, with two suites proving it. |
| **End-Phase banish edge case** | Deliberately open: a card banished by an effect activated *during* the End Phase does not return until the *next* turn's End Phase, because expiry runs as the phase is entered. |
| **Two never-live clauses** | `Apprentice Magician`'s Spell Counter clause and `Fairy Tail - Rella`'s equip clause cannot be live with this card pool. Both fully implemented, tested against synthetic cards, and asserted against the real library so the fact cannot rot. |
| **ObjectDB growth** | 164,444 leaked instances at exit, rising with the number of duels the suite builds. Causes no test failure, hang, memory pressure or unreliable result. **Scheduled to be characterised or fixed before Phase 7.** The trend is recorded at every checkpoint rather than explained away. |
| **Interaction coverage** | Thin — one interaction suite. The most valuable area for new contribution. |
| **Platform validation** | Windows 11 only. CI exercises the POSIX runner, but the published assertion counts were measured on Windows. |

---

## Not claimed

To be explicit about what this project does **not** yet have:

* no playable UI — `run/main_scene` is intentionally unset, and F5 will not start a game;
* no CPU opponent;
* no 3D arena, card movement, animation, particles or audio;
* no packaged build or export;
* no Extra Deck mechanics (Xyz, Synchro, Link, Pendulum, Ritual) — the pool contains no such
  cards, though the zones exist in the model;
* no open-source licence (see [README → Licence](../README.md#licence)).

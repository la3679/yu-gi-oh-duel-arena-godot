# Project status

A public-facing summary of where Duel Arena stands, synchronised from the authoritative
internal checkpoint.

**Checkpoint date:** 2026-09-10 · **Phase 6 COMPLETE — the backend is finished. Phase 7 (the
playable UI) has NOT started.**

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
| **Phase** | 6 of 11 — integration, scripted full duels, backend acceptance — **COMPLETE** |
| **Cards implemented** | **77 / 77** |
| **Cards tested** | **77 / 77** |
| **Official text verified** | **77 / 77** |
| **Assertions** | **10,433 passed / 0 failed** |
| **Suites** | **99** |
| **SmokeCheck** | **PASS** |
| **`SCRIPT ERROR` in the full run** | **0** |
| **Scripted full duels** | **24** between the two real 40-card decks, every one to a legitimate game over (LP 0, deck-out, surrender) and rebuilt exactly from its replay payload |
| **Cross-process determinism** | **PASS** — the same duels played in two separate processes are byte-identical (`Tools/check_determinism.*`, in CI) |
| **ObjectDB at exit** | **no leak warning** — the reference cycle was found and fixed in Phase 6 (it was 347,433 at exit) |
| **Engine** | Godot `4.7.1.stable.official.a13da4feb`, headless |
| **CI** | the full suite, SmokeCheck, cross-process determinism and the matrix check run on Ubuntu on every push |

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules | 26 | 2,747 | 2,747 | 0 |
| Per-card | 69 | 7,328 | 7,328 | 0 |
| Interaction | 1 | 46 | 46 | 0 |
| Integration — lifetime, scripted full duels, backend acceptance | 3 | 312 | 312 | 0 |
| **Total** | **99** | **10,433** | **10,433** | **0** |

---

## Phases and gates

| Phase | Goal | Status |
|---|---|---|
| 0 | Data inspection, Godot install and verification | **complete** |
| 1 | Authoritative TCG rules research | **complete** |
| 2 | Per-card official text and rulings research (77 cards) | **complete** |
| 3 | Architecture and scaffolding | **complete** |
| 4 | Core rules engine | **complete** |
| 5 | Card effect library | **complete — 77 / 77** |
| 6 | Integration, scripted full duels, backend acceptance | **complete — acceptance gate MET** |
| **7** | **Local Human-v-Human playable UI** | **not started — planned in `PROJECT_STATE.md` §8** |
| 8 | Arena and presentation | not started |
| 9 | Local privacy UX (pass-and-play handoff) polish | not started |
| 10 | Asset polish and packaging | not started |
| 11 | Full acceptance | not started |

| Gate | Status |
|---|---|
| A — research complete | **MET** |
| B — core engine complete | **MET** |
| C — card library complete | **MET** |
| Backend acceptance (Phase 6) | **MET** |
| D — playable prototype | not met — Phase 7 |
| E — presentation complete | not met |
| F — final acceptance | not met |

---

## What is complete

**The rules engine** — turn flow · Normal / Tribute / Flip / Special Summon · Summon declaration
and Summon negation · the Chain and Fast Effect Timing state machine (boxes A–E) · Spell Speed ·
activation legality · costs kept separate from effects · targeting with resolution-time
re-validation · effect / activation / continuous negation · the Damage Step and its activation
restriction · battle and attack replay · attack prevention vs attack negation vs a card-class
activation lock · continuous effects · Equip · counters · control changes · movement, Deck
placement and excavation · banishment and return leases · LP costs · Trap Monsters · immunity ·
Chain-Link substitution · hidden information · seeded RNG, action logging and deterministic
replay.

**The card library** — all 77 unique cards (80 deck slots) implemented, each with its own suite.

**Phase 6 — the game works end to end, headlessly:**

* **ObjectDB reference cycle fixed.** The cycle was one strong back-pointer
  (`ChainManager.engine`); it is now a `WeakRef`. `LifetimeTests` proves a dropped duel frees
  everything and that ObjectDB does not grow per duel.
* **Scripted full duels.** `Tests/support/DuelDriver.gd` plays a whole duel through the public
  API only — every action taken from `get_legal_actions()` / `get_legal_responses()` — and checks
  zone integrity, LP accounting, both players' hidden-information views and every move event's
  privacy after every step.
* **Backend acceptance gate MET** — both decks instantiate, every card resolves through an
  implemented path, no TODO paths, full regression, 24 scripted duels, deterministic replay
  (including a JSON round trip), cross-process determinism, hidden information over a whole game,
  0 `SCRIPT ERROR`, no ObjectDB leak, and games reaching LP 0, deck-out and surrender.
* **Cleanup (unit 4).** `R35` / `Mirage Dragon` re-checked with the Konami database's `ja` locale
  (an official supplement exists and agrees with the shipped card; R34 part D is now HIGH);
  `Tools/build_matrix.py` now reads each ruling's status from `Research/CARD_RULINGS.md` instead of
  printing `PENDING` for every flagged card; `Spiritual Wind Art - Miyabi` reads the field
  Attribute like its two sibling cards; this file was regenerated.

---

## What remains

**Phase 7 — a functional local Human-v-Human interface, before any visual polish.** It will sit
on the existing public API — UI → legal-action API → `DuelEngine` → semantic events →
presentation — and **never** decide legality itself. The unit-by-unit plan, with acceptance
criteria, is in `PROJECT_STATE.md` §8. **Nothing in Phase 7 is started.**

---

## Open questions and known gaps

| Item | Status |
|---|---|
| **R1, R2** | **OPEN**, recorded questions about branches never live in these decks (`Runick Flashing Fire`'s Extra Deck bullet; `Judge of the Ice Barrier`'s "Ice Barrier" clauses). Both cards are implemented and tested; neither blocks anything. |
| **Simultaneous-LP-zero (a draw)** | **Unexercised** — a reachability gap, not a missing implementation: no card in this pool can take both players to 0 LP at once. |
| **End-Phase banish edge case** | Deliberately open: a card banished by an effect activated *during* the End Phase returns at the *next* End Phase, because expiry runs as the phase is entered. |
| **Never-live clauses** | `Apprentice Magician`'s Spell Counter clause, `Fairy Tail - Rella`'s equip clause and `Runick Flashing Fire`'s Extra Deck bullet cannot be live with this pool. All implemented, tested against synthetic cards, and asserted against the real library. |
| **Unarranged coverage** | The scripted duels activated 45 distinct cards' effects in unarranged play; the rest are proven by their own suites. A deterministic policy will not find every card's window. |
| **Platform validation** | Windows 11 (development) and Ubuntu (CI) run the full suite to identical results. **macOS is untested.** |

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

# TEST_RESULTS

**Last run:** 2026-09-09 (Phase 5 **batch 15 COMPLETE**: `A Hero Emerges`, the pool's first
effect whose choice is made **at random by the opponent out of a hidden hand**, and its first
clause whose own activation requirement, re-checked at resolution, **suppresses the whole
effect including its first sentence**. **R15** is now CLOSED.)
**Engine:** Godot 4.7.1.stable.official.a13da4feb (headless)

Command:

```bash
powershell -ExecutionPolicy Bypass -File Tools\run_tests.ps1 RunTests 300
```

`Tools/run_tests.ps1` wraps the raw Godot invocation. It exists for two measured reasons,
both of which cost time before it was written:

1. Godot writes heavily to stderr (every `push_error` prints a full GDScript backtrace).
   Piping stdout+stderr through PowerShell can block on a full pipe, so the runner
   redirects to files and prints them afterwards.
2. A suite that fails to **compile** makes `RunTests._initialize()` throw before it can
   call `quit()`, which leaves the headless SceneTree running forever. The runner does a
   `--check-only` parse pass first, so a compile error is an immediate readable failure
   rather than a hang.

The raw command still works and produces the same numbers:

```bash
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe" --headless --path "<repo>" --script res://Scripts/tests/RunTests.gd
```

`Tools/run_tests.sh` is the POSIX twin and takes an entry-script name, so a single unit can be
driven without the full run: `./Tools/run_tests.sh RunBatch15Tests`. The full suite remains the
authority for every number below.

---

## Summary — actual measured results

| Category | Suites | Assertions | Passed | Failed |
|---|---:|---:|---:|---:|
| Core rules tests | 24 | 2289 | **2289** | 0 |
| Per-card tests | 65 | 6697 | **6697** | 0 |
| Interaction tests | 1 | 46 | **46** | 0 |
| Scripted duel tests | 0 | 0 | 0 | 0 |
| **TOTAL** | **90** | **9032** | **9032** | **0** |

Previous clean commit: **`6a98eae`**. SmokeCheck: **PASS**. `SCRIPT ERROR` occurrences in the
full run: **0**. Matrix: **73 / 77 implemented, 73 / 77 tested, 4 remaining** (computed by
`python Tools/build_matrix.py`, not written by hand). ObjectDB at exit: **308910** — and that
number is **finally characterised**; see the batch-15 ObjectDB note below.

## Batch 15 — COMPLETE. Nothing in it is partial or unverified.

One card, one unit, three new `EffectPrimitives` functions and **no new engine surface at all**.
**Every one of the previous checkpoint's 8795 assertions passes unchanged** — no existing
assertion was retired, weakened or retargeted. The one pre-existing suite that grew,
`HiddenInfoTests`, grew only by **addition**: its 116 batch-14 assertions are byte-for-byte the
same and 40 new ones were appended, which is exactly what batch 12 did to the same file when it
added the `look_at_hand` gate.

The arithmetic is checked rather than asserted:

9032 − 8795 = **237** = 197 (`AHeroEmergesTests`, new) + 40 (`HiddenInfoTests`, 116 → 156). The
5509 → 5973 → 6284 → 6914 → 7725 → 8272 → 8483 → 8795 → **9032** chain is unbroken.

| Unit | What it was | Result |
|---|---|---|
| A | **R15** research: cid 5915 supplement (2015-03-26) + **both** Q&A entries (fid 12566 「御前試合」, fid 8193 「虚無空間」, both 2017-03-24), `request_locale=ja`, plus a live re-fetch and character-for-character diff of the **English** text against `Data/cards/cards.json` | **COMPLETE** — R15 CLOSED |
| A | the random-choice gate (`HiddenInfoTests`, 116 → **156**) + `RULES_SPEC.md` **§10.8** and **§12.3** | **COMPLETE** — written and green BEFORE the card |
| A | `A Hero Emerges` (`AHeroEmergesTests`, **197**) | **COMPLETE** |

### The three facts the printed English text does not carry

All three would have been silent bugs, and none is reachable by reading the English text.

1. **The hand gates the ACTIVATION** (R15 Part A).
   「自分の手札が0枚の場合や、自分の手札にモンスターカードがない場合、「ヒーロー見参」を発動する事自体ができません。」
   An empty hand — or a hand with no monster in it — makes the card unactivatable. The printed
   English text carries no hand requirement at all. **This is the fifth batch in a row in which
   §8's standing warning about a missing activation restriction was right**
   (`Burst Stream of Destruction`, `Damage Condenser`, `Honest`, `Witchcrafter Golem Aruru`, now
   this).
2. **The requirement is narrower than "a monster card"** (R15 Part B). Q&A fid 12566 asks for a
   monster **this effect could actually Special Summon right now**, so a lingering restriction
   that would make the placement illegal removes the card from the count. In this pool that means
   a **full Monster Zone** and the **"You can only control 1 …"** limit both forbid the
   activation, with a hand full of monsters.
3. **The whole effect is re-gated at RESOLUTION, and the random choice is suppressed with it**
   (R15 Part C). Q&A fid 8193, verbatim:
   「ヒーロー見参」の効果処理は適用されません。（『自分の手札１枚を相手がランダムに選ぶ』事も行いません。）
   The pick is *not even made*. The obvious implementation — pick, then branch — is observably
   wrong: it would send a Spell out of the hand in a situation whose official answer is that
   nothing happens. This is now `RULES_SPEC.md` **§10.8**, and it is deliberately written next to
   §10.6 because the two look opposed and are not.

### Mutation testing: twenty-one mutations, twenty-one caught, ZERO survivors

Run against `RunBatch15Tests` (the new suite plus `HiddenInfoTests`, `ReplayTests`,
`SpecialSummonTests` and the three neighbouring cards), each mutation applied on its own and
reverted afterwards.

| # | Mutation | Result |
|---|---|---|
| M1 | drop the OPPONENT narrowing on the attacker | caught |
| M2 | drop the activation restriction entirely (Part A) | caught |
| M3 | weaken the activation restriction to "any monster card" (Part B) | caught |
| M4 | drop the resolution-time gate (Part C) | caught |
| M5 | branch on "is a monster" instead of "can be Special Summoned" (Part E) | caught |
| M6 | Special Summon in a FIXED Attack Position (Part F) | caught |
| M7 | make the CONTROLLER the chooser instead of the opponent (Parts D/H) | caught |
| M8 | open the Damage Step (Part G) | caught |
| M9 | drop the `trigger_events` declaration | caught |
| M10 | pick with Godot's GLOBAL RNG instead of the seeded one (Part D) | caught |
| M11 | always pick the first card in the hand | caught |
| M12 | reveal the chosen card to nobody (Part H) | caught |
| M13 | reveal the WHOLE hand to the chooser (Part H) | caught |
| M14 | drop the free-Monster-Zone half of the summonable question (Part B) | caught |
| M15 | drop the control-limit half of the summonable question (Part B) | caught |
| M16 | make the summonable-hand list ignore its `pid` argument | caught |
| M17 | pick FIRST and gate afterwards — the exact order Part C forbids | caught |
| M18 | make the "Otherwise" send a DISCARD (Part E) | caught |
| M19 | reveal the chosen card to the chooser only, so the event is private (Part H) | caught |
| M20 | never re-test the chosen card — always Special Summon it | caught |
| M21 | let "a monster that can be Special Summoned" accept non-monsters | caught |

**Nothing survived the first pass**, which is a first for this project — batch 14 had two
survivors on its first pass and batch 12 two. Three things are worth recording about *why*,
because they are what the previous batches' survivors taught:

* **Every negative test asserts on the OFFER, not on the outcome.** Batch 14's first survivor was
  a negative test that asserted on an optional effect's outcome, which is true whether or not the
  effect was ever offered. Every activation-legality test here asserts `_response(...) == null`
  and pairs it with a **separate board** on which the same query returns an action.
* **Every "not offered" assertion has a live control built on the same seed.** A response window
  that neither player can answer is auto-passed and closed by the engine, so a control added to a
  board *after* the refusal proves nothing — the first draft of five of these tests did exactly
  that and failed loudly. They are now separate boards, and the comment in each says why.
* **The randomness is swept, not sampled.** Two tests run a fixed range of seeds and assert that
  **both** branches occurred and that every card in the hand is reachable. Without that, "the
  chosen card was a monster" would pass equally well against an implementation that always picks
  index 0 — which is mutation M11, and it is the sweep that catches it.

### What batch 15 proved about §8's own predictions, kept because the pattern is now five deep

* §8 predicted the subsystem would be "a random choice made by the OPPONENT from your hand,
  through the seeded `Rng` so replay survives". **Correct, and complete as far as it went.**
* §8 predicted "one generic primitive with its own gate". **Nearly correct — it was three**, and
  the two it did not predict are the ones that carry the ruling: "can this be Special Summoned
  right now?" and the hand list built from it.
* §8 predicted an activation restriction the printed English text does not carry. **Correct for
  the fifth batch running.**
* §8 asked five open questions and every one was answered from an official source. **It did not
  predict the fact that mattered most** — that a resolution-time failure suppresses the random
  choice itself. Nothing in the English text hints at it, and it is the only one of the three new
  facts that changes the order of operations rather than a condition.
* §8 was **right** that no new subsystem was needed: no new event kind, no new activation
  location, no new Damage Step permission, no new zone, no new Summon route, no new decision kind.

### `AHeroEmergesTests` — 197/197

`Tests/cards/AHeroEmergesTests.gd`. Rules: `RULES_SPEC.md §5.5, §7.2, §10, §10.7, §10.8, §12,
§12.3`, `CARD_RULINGS.md R15`.

| Test | Asserts | What it proves |
|---|---:|---|
| clause shape | 14 | one printed clause, one EffectDef; Normal Trap, Spell Speed 2, Set-only, `ATTACK_DECLARED`, no once-per-turn, official text verbatim |
| it does not target | 7 | 対象を取る効果ではありません — no `targets`, no `legal_targets`, no `targets_valid`, and the offered action carries no candidates |
| the Damage Step is closed | 8 | `DamageStepPermission.NONE` asserted **directly** against `ActivationRules.damage_step_ok()` in all five sub-steps, with a permitted clause as the control (R15 Part G, RULES_SPEC §10.7) |
| offered only in the attack-declaration window | 4 | not before the declaration, offered after it, gone again in an open game state |
| not offered when YOU are the attacker | 3 | with an identical copy in the identical window on the opponent's side as the live control |
| a direct attack opens it too | 5 | `direct` is true on the event and the Trap is still offered |
| not the turn it was Set | 3 | with an earlier-Set copy on the same board as the control |
| an EMPTY hand forbids the activation | 5 | R15 Part A, with a one-monster board as the control |
| a hand with no monster forbids the activation | 5 | R15 Part A, three Spells/Traps vs the same three plus one monster |
| a full Monster Zone forbids the activation | 7 | R15 Part B, five occupied zones vs four |
| only an unsummonable monster forbids the activation | 6 | R15 Part B, the Gozen Match shape, driven by "You can only control 1" |
| one summonable monster is enough | 6 | and the candidate list really is the one card |
| a chosen monster is Special Summoned | 11 | to the controller's own field, face-up, properly Special Summoned, nothing sent |
| a chosen Spell/Trap is sent to the GY | 8 | R15 Part E, swept until the pick lands on the Spell |
| both branches are reached across seeds | 3 | 60 seeds, both outcomes present, every run took exactly one branch |
| a chosen monster that CANNOT be Summoned is sent to the GY | 6 | R15 Part E's hidden half, with the ordinary monster in the same hand as its control |
| the send is not a discard | 3 | `SENT_TO_GY_BY_EFFECT`, never `DISCARDED` [S1 p.52-53] |
| the position is the summoning player's choice | 9 | R15 Part F — a scripted Defense Position is honoured and the default lands in Attack Position |
| ownership and control stay with the Trap's controller | 8 | 自分フィールドに特殊召喚; the Summon is announced as theirs and attributed to the Trap |
| losing the last summonable monster suppresses everything | 10 | **R15 Part C** — nothing chosen, nothing revealed, the Spell still in the hand, with the un-interfered board as the control |
| filling the Monster Zone suppresses everything | 8 | R15 Part C by the other live route |
| only the chosen card becomes public | 13 | one public reveal; three hand cards still hidden; the filtered `get_visible_state()` view names nothing else |
| the chooser is asked nothing | 6 | no selection request, no replay decision for that player — and the controller IS asked a position, so the run really reached the Summon |
| the Special Summon is announced and can be responded to | 8 | `SPECIAL_SUMMON_SUCCEEDED` once, a mandatory Trigger Effect watching for it fires, one declaration for the right player |
| activation negated | 9 | nothing chosen, nothing revealed, hand untouched, the Trap destroyed |
| effect negated | 9 | the activation DID happen and is announced; nothing the effect would do happens |
| an attack negated above it does not undo it | 6 | R15 Part G — the attack is negated first and the card still resolves |
| the same seed replays to the same card | 8 | same card, same zone, same RNG call count, identical event stream; 40 seeds reach all four hand cards |

### `HiddenInfoTests` — 116 → 156 (+40): the random-choice gate

`Tests/rules/HiddenInfoTests.gd`. Rules: `RULES_SPEC.md §9, §12, §12.2, §12.3`, R15 Parts B, D
and H. Written and passing **before** `A Hero Emerges` existed, the way the batch-12
`look_at_hand` gate in the same file, the batch-7 movement gate and the batch-6 control gate
were. It lives here rather than in a new suite for the reason batch 12 recorded: a random pick
out of a hidden hand is an **operation** over the hidden-information subsystem this file already
owns, plus the seeded `Rng` that `ReplayTests` already owns — neither is a new subsystem, and
splitting one primitive's gate across two suites would leave both halves incomplete.

| Test | Asserts | What it proves |
|---|---:|---|
| a random pick is seeded and repeatable | 6 | three runs on one seed choose the same card; across 64 seeds all five hand cards are reachable, so "deterministic" is not "always index 0" |
| a random pick consumes the duel RNG | 3 | exactly one counted draw from `GameState.rng`; an empty hand consumes none, so a no-op cannot desynchronise a replay |
| the chooser is asked nothing | 3 | neither controller sees a `DecisionRequest` — a SELECT here would have listed a hidden hand |
| only the chosen card is revealed | 11 | one PUBLIC reveal; the other four cards hidden from the chooser; the filtered view names the chosen card and nothing else |
| a random pick moves nothing | 5 | choosing is not moving; the caller's own text decides where the card goes |
| `can_be_special_summoned_now()` | 6 | monster vs Spell vs Trap vs null, and the same monster flipping to "no" when the Monster Zone fills |
| the control limit is part of the question | 3 | a copy on the field makes the hand copy unsummonable, and it is summonable again once that copy leaves |
| the summonable-hand list | 6 | empty hand, Spells-and-Traps-only hand, one monster; and it reads the hand of the player it is asked about |

### Nothing else changed

`ReplayTests` (33), `SpecialSummonTests` (54), `KunaiWithChainTests` (117),
`MaidenWithEyesOfBlueTests` (139) and `DamageCondenserTests` (156) — the suites nearest to this
card's window, its Summon route and its randomness — are all byte-for-byte green at their
batch-14 counts, and were run together with the new suite as `RunBatch15Tests` before every
mutation as well as after.

### ObjectDB — the characterisation task is DONE, and the per-assertion ratio was measuring the wrong thing

**261302 → 308910**, a rise of 47608 against 237 new assertions — **~200.9 per new assertion**,
four times the highest figure ever recorded and far outside the ~21.6 … ~44.6 band eight previous
checkpoints sat in. That anomaly is what finally made the number cheap to characterise, and
**batch 15 characterised it** with a throwaway probe (`Scripts/tests/ObjDbProbe.gd`, deliberately
**not** committed) that does nothing but construct objects and exit.

| Probe | Duels built | Leaked at exit |
|---|---:|---:|
| `duels 0` | 0 | **no warning at all** |
| `duels 50` | 50 | 9417 |
| `duels 100` | 100 | 18817 |
| `duels 200` | 200 | 37617 |
| `played 50` | 50, each advanced a phase and ended a turn | 9717 |
| `played 100` | 100, same | 19417 |
| `library 1` / `library 10` / `library 20` | 0 (only `CardRegistry.load_library()`, 1/10/20 times) | **no warning at all** |

The measurement is exact and linear:

* **188 objects per duel CONSTRUCTED**, with an intercept of 17.
  (18817 − 9417) / 50 = 188.0; (37617 − 18817) / 100 = 188.0; 9417 = 50 × 188 + 17.
* **~6 more per turn PLAYED** — 9717/50 = 194.3, (19417 − 9717)/50 = 194.0. Playing a duel is
  almost free; **building** one is the whole cost.
* **Zero for the card registry.** Twenty full `load_library()` calls leak nothing, so the 77-card
  library, its `EffectDef`s and its `Callable`s are not the source. That was worth ruling out
  explicitly, because it was the other obvious candidate.

**Conclusion, now measured rather than inferred: the figure counts DUELS BUILT, not assertions
run.** 188 is very close to the size of one duel's whole object graph — 80 `CardDef`s + 80
`CardInstance`s for two 40-card filler decks, plus the engine, the `GameState`, two
`PlayerState`s, the rules objects, the `DuelLog`, the two controllers and the setup
`GameEvent`s — so what is retained at exit is the entire graph of every duel a run ever created,
held by a reference cycle at the `DuelEngine` / `GameState` root. Every object involved is
`RefCounted`, which is why Godot reports them as leaked rather than freeing them.

**This retires the "per new assertion" ratio.** It was never a meaningful quantity: a batch whose
tests build many small duels raises the number and a batch whose tests build few large ones does
not, which is exactly why eight checkpoints produced four falls and four rises with no trend.
Batch 15's own spike is fully explained by its seed sweeps — the branch-coverage and replay tests
deliberately build several hundred one-shot duels in order to prove that a random effect reaches
every branch, and at 188 apiece that is essentially all of the 47608.

**It still fails nothing** — no hang, no memory pressure, no unreliability, and it is a
process-exit artefact of a headless test run rather than anything a played duel accumulates. What
remains is a **fix**, not a characterisation: find the cycle at the `DuelEngine` / `GameState`
root and break it. That is a self-contained non-card unit, it is now the second-cheapest one in
the repository after the `build_matrix.py` column, and it is **still required before Phase 7**.

---

## Batch 14 — COMPLETE. Nothing in it is partial or unverified.

One card, one unit, one new `EffectPrimitives` sibling. **Every one of the previous checkpoint's
8483 assertions passes unchanged** — no suite other than the new one was touched, nothing was
retired, weakened or retargeted, and the batch-13 `One for One` correction stands exactly as it
was left.

The arithmetic is checked rather than asserted:

8795 − 8483 = **312** = the whole of `WitchcrafterGolemAruruTests`. The
5509 → 5973 → 6284 → 6914 → 7725 → 8272 → 8483 → **8795** chain is unbroken.

### `WitchcrafterGolemAruruTests` — NEW, 312 assertions, 40 tests

R13 was settled from official Konami sources **before a line of the card was written**: cid
14483's 補足情報 (2020-07-04) and Q&A fid 22558 (2022-12-30), both fetched with
`request_locale=ja` per R40's methodology note, plus a re-fetch of the **English** text from the
live database and a character-for-character diff against `Data/cards/cards.json`. The full record
is `CARD_RULINGS.md` **R13**.

**Four facts the printed English text does not carry**, each of which changes the implementation:

| Fact | Where it lives in the code | Where it is asserted |
|---|---|---|
| **cannot be activated during the Damage Step** (ダメージステップ中には発動できません) | the DEFAULT `DamageStepPermission.NONE` — no code at all | the shape test **and** an opponent activation that really happens inside a Damage Step |
| the Spellcaster must be **face-up in your MONSTER ZONE**, not merely "on your field" | `PlayerState.face_up_monsters()` + `current_race()` | face-down in both windows; a Spellcaster in the hand and in the GY |
| the targeting trigger is the **OPPONENT's** activation only | `is_targeted_by_a_live_opponent_activation()`, the batch's one new primitive | your own Spell on your turn, and your own Trap on theirs |
| a target that has **left the field** costs the bounce and **NOT** the Special Summon | the resolution performs the Summon first and unconditionally | a banished target, and a target that changed control |

The last of those is the one the research existed to buy. The ordinary reading of a single-target
effect is that a dead target kills the whole thing; Konami says
『このカードを特殊召喚する処理のみを行います』 — *only the Special Summon is performed*. An
English-only implementation would have returned early and no test written from the English text
would ever have caught it. `RULES_SPEC.md` **§10.6** now states the general rule.

Also covered: the multi-target Q&A (fid 22558, with the Spellcaster deliberately the **second**
of two targets so an implementation reading `target_ids[0]` fails); "1 **card**" reaching a Set
Spell/Trap; the bounce reaching the **owner** rather than the controller; the bounce not being a
destruction or a send to the GY; the Special Summon and the bounce being one uninterrupted
resolution with no Chain Link between them; both negation kinds with the once-per-turn use still
spent; the per-NAME once-per-turn locking a second copy; the mandatory opponent-Standby-Phase
return with its own resolution-time re-check; and a deterministic replay of the whole line.

**The GY branch is never live in the V1 pool** — `Witchcrafter Golem Aruru` is the only
"Witchcrafter" card printed in either deck and it is a Monster — so it gets the R21 / R23
synthetic treatment: a synthetic "Witchcrafter" Spell proves it works, a synthetic "Witchcrafter"
**Trap**, a non-archetype Spell and the **opponent's** copy each prove it is not over-wide, and a
real-pool assertion proves no printed card can satisfy it.

**Nothing in this suite is vacuous.** Every "not offered" assertion is preceded by an assertion
that the player really has a response window, and the targeting branch is driven once with the
real opposing `Compulsory Evacuation Device` against the real `Apprentice Magician`.

### Mutation testing — sixteen mutations, all caught, none by fewer than two assertions

Every load-bearing condition in the card was inverted or deleted and the unit re-run. A mutation
caught by only one assertion was **strengthened**, not accepted.

| Mutation | First pass | After strengthening |
|---|---|---|
| drop the opponent-only narrowing (use Maiden's primitive) | **SURVIVED** | caught by 2 |
| read every monster, not only the face-up ones | 1 | **2** |
| drop the Spellcaster Race check | 2 | 2 |
| fizzle the whole effect when the target is gone | 3 | 3 |
| bounce even when the Special Summon failed | 2 | 2 |
| re-check only the zone, not the control (R29 dropped) | 3 | 3 |
| grant clause ① a Damage Step permission | 1 | **2** |
| clause ② reads its own controller's Standby Phase | 8 | 8 |
| drop the attack window | 5 | 5 |
| once per turn per COPY instead of per NAME | 5 | 5 |
| the GY branch accepts a Trap as well as a Spell | 1 | **2** |
| the GY branch reads the opponent's Graveyard | 7 | 7 |
| the attack branch ignores whether it is an attack TARGET | 1 | **2** |
| the opponent's field pool becomes the whole field | 6 | 6 |
| clause ② drops its resolution-time re-check | **SURVIVED** | caught by 2 |
| clause ① may also be activated from the field | 1 | **2** |

**Two mutations SURVIVED the first pass and both were real gaps in the tests, not in the card.**

1. *Dropping the opponent-only narrowing.* The negative test asserted on the OUTCOME — Aruru was
   still in the hand — which is true either way, because the effect is optional and the test never
   activated it. It now asserts on the **offer**, inside a response window the test proves player 0
   is really being given, with the same board and the opponent as the activator as its control.
2. *Dropping clause ②'s resolution-time re-check.* Nothing destroyed Aruru while its own mandatory
   trigger was waiting, so the re-check was never reached. There is now a test that chains a
   destruction above the Standby Phase trigger and asserts the clause returns **nothing** — a
   missing re-check would drag Aruru out of the Graveyard and into the hand.

**One measurement fact worth keeping, recorded in `RULES_SPEC.md` §10.7.** Mutating the Damage
Step permission was caught only by the declaration assertion on the first pass, and the reason is
structural: an effect that declares `trigger_events` is offered only in a window whose events
match, so an ordinary Damage Step sub-step window would never carry it **whatever** its permission
said. The restriction is observable only where the opponent's own **targeting** activation happens
inside the Damage Step. That case is now driven, with the identical card and target outside the
Damage Step as its control. "Never offered in the Damage Step" is not, on its own, evidence that
the permission is being enforced.

### Engine defects found by this unit: none

The card needed **no new subsystem**: one new `EffectPrimitives` sibling
(`is_targeted_by_a_live_opponent_activation()`, ten lines, written next to the shipped
`is_targeted_by_a_live_activation()` rather than by changing it, in the same relation
`surviving_opponent_field_target()` has to `surviving_field_target()`), no new event kind, no new
activation location, no new Damage Step permission, no new zone, no new summon route. Everything
else is `Honest`'s hand activation (RULES_SPEC §7.5), `Maiden with Eyes of Blue`'s chain read,
`Nefarious Archfiend`'s opponent-phase trigger, and the shipped movement and Special Summon
primitives.

`GameEvent.Kind.ATTACK_TARGET_SELECTED` had **one emitter and zero readers** before this card —
the dead-vocabulary shape batch 5 found in `cannot_be_targeted` and batch 6 in `CONTROL_CHANGED`.
It is now consumed, and it was already correct: it is emitted only for a non-direct attack, which
is exactly 「攻撃対象に選択された時」.

**No `SCRIPT ERROR` appeared in the final run**, and none appeared in the SmokeCheck. One appeared
during development (`Nonexistent function 'with_choices' in base 'Nil'`, from a test helper that
assumed a response was offered) and was fixed by making the helper prove the window exists before
using it — which is the same class of test bug the runner's `SCRIPT ERROR` check exists to catch.

Stderr still carries exactly the **five** deliberate `push_error` lines batch 13 recorded. This
batch added none.

### ObjectDB — batch 14

**249757 → 261302**, a rise of 11545 against 312 new assertions: **~37.0 per new assertion**, up
from batch 13's ~35.2 and inside the ~21.6 / ~26.9 / ~28.4 / ~34.9 / ~44.6 range seen before. That
is four falls and four rises across eight checkpoints, which is **still not a trend and still has
no measured explanation**; none may be recorded until one is measured. It fails nothing. It must
be characterised or fixed before Phase 7.

---

## Batch 13 — COMPLETE (kept for the record). Nothing in it is partial or unverified.

### The one place this project has ever inverted an assertion — read this before the arithmetic

**8271 of the previous checkpoint's 8272 assertions pass unchanged.** The exception is
deliberate, is the whole point of batch 13 unit A, and is stated here rather than buried:
**`OneForOneTests._test_paying_away_the_last_level_1_monster` was RETIRED and four of its
assertions INVERTED**, because official Konami supplemental information (cid 8197, 2020-03-20,
`request_locale=ja` — **re-fetched from the live database on 2026-09-08 before anything was
changed**) says the opposite of what this repository shipped.

| Retired assertion | Was | Now |
|---|---|---|
| the cost monster's zone | `GRAVEYARD` — it was spent | it is **not a legal cost** and is not spent |
| monsters on the field after resolution | 0 | **1** |
| `SPECIAL_SUMMON_SUCCEEDED` events | 0 | **1** |
| the scripted cost choice | valid | **rejected by the engine** |
| *the activation is legal* | — | **kept, unchanged; it was always right** |
| *the Spell resolves and reaches the GY* | — | **kept, unchanged** |

Nothing else anywhere was weakened, retargeted or deleted, and no other suite lost an
assertion. Full record in `CARD_RULINGS.md` **R42 Part D** and `RULES_SPEC.md` **§10.5**.

### What grew, and why

* **`CostLegalityTests` — NEW, 56.** The engine-level gate for the corrected rule, built from
  **synthetic** cards so what it proves is that the engine is right rather than that one
  printed card happens to work. It carries **both** shapes: the one the rule bites
  (cost leaves a zone the effect reads, for a zone it does not) and the one it must **not**
  (`Fairy Tail - Rella`'s, where the cost lands inside the effect's own pool). Over-applying
  the rule would silently forbid legal plays, which is why that is a test and not a comment.
* **`OneForOneTests` 40 → 70 (+30).** One test retired, four replacing it: the last enabler is
  not offered as a cost; no payable cost blocks the activation entirely (and it is
  `can_pay_cost`, not the condition, that refuses); a Deck copy makes the hand copy spendable
  again; two Level 1 monsters in hand are each spendable.
* **`HonestTests` — NEW, 125.** Both clauses, the 0-ATK activation restriction the printed
  English text does not carry, both directions of the battle, the sub-step boundaries, the
  cost's non-refund, the stacking of two copies, and the face-down deferral.

No pre-existing suite other than `OneForOneTests` changed at all.

The arithmetic is checked rather than asserted:

8483 − 8272 = 211 = 56 (`CostLegalityTests`) + 30 (`OneForOneTests` 40 → 70)
+ 125 (`HonestTests`). The 5509 → 5973 → 6284 → 6914 → 7725 → 8272 → 8483 chain is therefore
unbroken, with the single documented inversion above accounted for inside the +30.

**No `SCRIPT ERROR` appeared in the final run.** One DID appear during development —
`Invalid access to property or key 'is_effect' on a base object of type CardDef` in
`HonestTests._test_printed_stats` — and it is recorded because it is exactly why the runner
checks for `SCRIPT ERROR` lines and not for `RESULT: PASS` alone: the suite reported
110/114 passed and the run would otherwise have looked merely incomplete. The field is
`is_effect_monster`; fixed.

Stderr carries **five** deliberate `push_error` lines, up from two. The two pre-existing ones
are unchanged (`ChainTests._test_unimplemented_effect_fails_loudly`,
`ContinuousTests._test_restriction_flags_are_owned_by_this_system`). The three new ones are
one assertion each in
`CostLegalityTests._test_a_multi_card_payment_is_refused_rather_than_approximated`, which
proves the cost filter **refuses** a payment size its per-card check cannot answer instead of
approximating it. They are expected, and the guard is load-bearing: silently approximating
would be a real defect.

### Mutation testing — what was deliberately broken, and how loudly it failed

Every load-bearing condition added this batch was inverted or deleted and the suite re-run.
A mutation caught by only one assertion was **strengthened**, not accepted.

| Mutation | Assertions that failed | Tests that failed |
|---|---:|---:|
| `One for One` bypasses the cost filter entirely (the pre-correction behaviour) | 4 | 2 |
| the cost primitive ignores its predicate and keeps every candidate | 12 | 5 |
| the primitive's multi-card guard removed, so it approximates | 1 → **strengthened to 4** | 1 |
| `Honest` drops the 0-ATK activation restriction | 1 → **strengthened to 3** | 1 |
| `Honest` drops the LIGHT check | 2 | 1 |
| `Honest` boosts "until the end of the Damage Step" instead of the turn | 7 | 5 |
| `Honest` allows a face-down opposing monster | 2 | 1 |

Two of the seven were caught by a single assertion on the first pass and both were
strengthened before the mutation was reverted: the multi-card guard now asserts counts 0, 2
and 3 **and** that the predicate is never consulted for any of them, and the 0-ATK test now
activates at the first window that offers it rather than only watching, so a regression fails
on the outcome as well as on the offer.

**One real defect was found by the tests before the card shipped**, and it is recorded in
`CARD_RULINGS.md` R20 Part C rather than quietly fixed: `Honest`'s first implementation relied
on `DamageStepPermission.UNTIL_DAMAGE_CALC` alone, and `ActivationRules.damage_step_ok()`
answers `true` **outside** the Damage Step by design — so the effect was offered in the
attack-declaration window, which is the Battle Step. "During the Damage Step" had to be in the
card's own `condition` as well. `RULES_SPEC.md` §7.2 now says so for the next card.

---

## Batch 12 — COMPLETE. Nothing in it is partial or unverified.

| Batch 12 unit | Status |
|---|---|
| Unit A — **R42** research (cids 6441, 6440, 6582, 8197, `request_locale=ja`) | **COMPLETE** |
| Unit A — `Spiritual Fire Art - Kurenai` (`SpiritualFireArtKurenaiTests`, 160) | **COMPLETE** |
| Unit B — the generic **look-at-a-hidden-zone operation** (`HiddenInfoTests` 76 → 116, +40) | **COMPLETE** |
| Unit B — `Spiritual Water Art - Aoi` (`SpiritualWaterArtAoiTests`, 179) | **COMPLETE** |
| Unit C — the generic **`AFTER_DAMAGE_CALC` permission** (`DamageStepTests` 86 → 98, +12) | **COMPLETE** |
| Unit C — `Damage Condenser` (`DamageCondenserTests`, 156) | **COMPLETE** |

### Two generic units, both forced rather than chosen

Each was built as its own unit with its own tests **before** the card that needed it, and each
went into the suite that already owns its subsystem rather than into a new one.

1. **`EffectPrimitives.look_at_hand()` / `send_from_hand_to_gy()`** — an OPERATION over the
   hidden-information subsystem, not a subsystem of its own. `GameState.reveal()` already
   revealed to a named subset of players and already marked a partial reveal `private_to`;
   what was missing was the card-facing loop and the send that is deliberately **not** a
   discard. `RULES_SPEC.md` §12.2.
2. **`Enums.DamageStepPermission.AFTER_DAMAGE_CALC`** — the engine **could not express**
   `Damage Condenser` without it. §7.1 sub-step 4 already named "when battle damage is
   inflicted" as a window, but `UNTIL_DAMAGE_CALC` is the earlier window and
   `MANDATORY_TRIGGER` is gated on the effect being trigger-COLLECTED, which a Trap's own
   `CARD_ACTIVATION` never is. Both exclusions are asserted, so the reason the value exists
   cannot quietly stop being true. `RULES_SPEC.md` §7.2.

A third, smaller addition was also forced: **`battle_damage_taken_in_this_battle()`**, which
reads the event log. `ActivationRules.make_context()` attaches no engine and passes a null
trigger event, so neither `ctx.trigger_event` nor `BattleRules.last_damage` is available in an
activation CONDITION — a condition written against either is silently false and the card is
never offered. Two successive drafts of `Damage Condenser` got this wrong and its own suite
caught both, each time by failing every positive test at once.

### Mutation testing: 44 mutations, 42 caught, 2 SURVIVED with measured explanations

Kurenai 13, Aoi 15, `Damage Condenser` and its gate 16. Four mutations initially survived and
**three of them were closed by writing the test that was missing**, not by weakening anything:

* **K13** — `field_monster_of_attribute()` dropping its `is_monster()` half. Closed by a
  direct unit test of the predicate against a Trap that merely *carries* an Attribute.
* **A15** — deleting `Aoi`'s empty-hand branch. It changed no board state, because
  `choose_one()` on an empty candidate list already returns null. The branch is still not
  redundant: it makes the duel log say *which* vacuous outcome happened, and "looked at an
  empty hand" and "no card could be chosen" are different facts about the same board. The
  test now asserts the resolution note carried by `CHAIN_LINK_RESOLVED`.
* **D2** — dropping the resolution-side ATK ceiling. It survived because the *activation*
  restriction already guarantees a qualifying monster exists. Closed by a test that puts an
  over-ceiling monster first in the Deck and primes the controller to ask for it.
* **G3** — dropping the event-log reader's `ATTACK_DECLARED` boundary. It survived because
  the `trigger_events` window gate shadows it in the obvious two-battle case. The boundary is
  genuinely load-bearing in a narrower one — a second battle that damages the **opponent**
  opens the window, and only the boundary stops the reader reaching back into the first
  battle's damage — and that is now the test.

**The one that still survives is a redundancy in the CODE, not a gap in the tests, and it has
a measured explanation rather than a guess:**

* **K8** — deleting `Kurenai`'s `check_life_point_loss()` call changes nothing, because
  `DuelEngine._resolve_current_chain()` already calls it after every Chain resolution and this
  damage is always dealt inside one. The call is kept for consistency with the pool's four
  other damage-dealing cards (`Chain Detonation`, `Five Brothers Explosion`, `Judge of the Ice
  Barrier`, `Stamping Destruction`), and the card's comment — which had claimed the call was
  what ends the Duel — was corrected to say the engine is. Removing it from all five would be
  a refactor of stable, shipped code and was deliberately not done.

One further mutation, **A4**, was initially a HARNESS error rather than a result: its anchor
matched two places in `EffectPrimitives.gd`. It was re-specified with a unique anchor and
re-run, and is caught. A mutation that never applied would otherwise look exactly like one
that was caught, which is why the harness reports that case separately.

### One test of my own was wrong, and the suite caught it

`Aoi`'s "the card reaches its owner's Graveyard" test asserted the controller's Graveyard grew
by one. It grows by **two** on a normal resolution — the Tributed WATER monster (the cost) and
the resolved Trap — and the assertion now names both, which is a stronger statement than the
one it replaced.

### An authoritative correction to shipped code was found and is NOT hidden

`One for One` (cid 8197) was consulted only as the precedent for Summoning out of the Deck, and
its official supplement contradicts a conclusion `OneForOne.gd` states in prose and its suite
asserts: a monster that is the **only** way to carry out the effect may not be used as the
cost. `CARD_RULINGS.md` **R42 Part D** records it in full with its source and date. It is
**not** part of batch 12 — it is another card, and the fix inverts an existing shipped
assertion — and is carried into PROJECT_STATE §7 and the batch-13 recommendation as its own
unit. Nothing in batch 12 depends on it.

---

## Batch 11 — COMPLETE. Nothing in it is partial or unverified.

| Batch 11 unit | Status |
|---|---|
| Unit A — `Stamping Destruction` (`StampingDestructionTests`, 134) | **COMPLETE** |
| Unit A — `Straight Flush` (`StraightFlushTests`, 143) | **COMPLETE** |
| Unit B — the generic **name-keyed turn-scoped attack ban** (`AttackRestrictionTests` 229 → 272) | **COMPLETE** |
| Unit B — `Burst Stream of Destruction` (`BurstStreamOfDestructionTests`, 128) | **COMPLETE** |
| Unit B — `Chiron the Mage` (`ChironTheMageTests`, 113) | **COMPLETE** |
| Unit C — `Back-Up Rider` (`BackUpRiderTests`, 115) | **COMPLETE** |
| Unit D — `Vampiric Koala` (`VampiricKoalaTests`, 131) | **COMPLETE** |

**All 6914 assertions from the batch-10 checkpoint pass unchanged** — none was weakened,
retargeted or deleted. **Exactly one pre-existing suite moved:** `AttackRestrictionTests`
**grew** 229 → 272, because the new prevention channel's gate was added to it, which is where
every generic unit since batch 7 has gone. Nothing in it was rewritten.

7725 − 6914 = **811** = 43 (the gate) + 134 + 143 + 128 + 113 + 115 + 131 + 4. The final 4 are
assertions added while **strengthening** tests that mutation testing showed were carried by a
single assertion; they are listed in the mutation table below.

### The new generic subsystem — a THIRD attack-prevention channel

`RULES_SPEC.md` **§6.5**. `PlayerState.ban_attacks_by_name()` / `attacks_banned_by_name()`, asked
by `BattleRules.can_declare_attack()` alongside the two channels §6.4 already had, plus the single
reader `EffectPrimitives.named_monster_attacked_this_turn()`.

It exists because the engine **could not express the card**. §6.4's two channels are both
continuous — wiped and rebuilt by `ContinuousEffects.recompute()` — so both lift the instant their
source stops applying. `Burst Stream of Destruction` is a Normal Spell that is in the Graveyard
before the first attack it forbids could be declared, and its ban has to reach a
`Blue-Eyes White Dragon` Summoned **later in the same turn**. Neither existing channel can do
both.

| | per CARD (§6.4) | per PLAYER (§6.4) | **per NAME + TURN (new)** |
|---|---|---|---|
| Card | `Fiendish Chain` | `Swords of Revealing Light` | `Burst Stream of Destruction` |
| Lifetime | while the source applies | while the source applies | **the rest of this turn** |
| Survives the source leaving the field | no | no | **yes** |
| Reaches a monster that arrives later | no | yes | **yes, if it has the name** |

The stored value is the **turn number**, so the ban self-expires at the turn boundary exactly the
way `named_effect_usage` does; nothing has to remember to clear it. The gate — 43 assertions in
`AttackRestrictionTests` — was written and green **against synthetic drivers, before
`Burst Stream of Destruction` existed**, and it asserts the three-way independence directly:
lifting any one channel leaves the other two refusing.

### The one place a card reads the event log, and why

`EffectPrimitives.named_monster_attacked_this_turn()` answers "has a monster of this name already
attacked this turn?" from `GameState.events`, and **deliberately not** from
`CardInstance.has_attacked_this_turn`. `on_leave_field()` clears that flag, so a monster that
attacked and was then destroyed, Tributed or bounced would silently stop counting — and the
activation the gate exists to forbid would quietly become legal. This is `RULES_SPEC.md` §15's
"facts that must outlive a card leaving the field", applied to an attack rather than to a card.
It is asserted twice: generically in `AttackRestrictionTests`, and on the real card in
`BurstStreamOfDestructionTests`.

Similarly `EffectPrimitives.battle_damage_just_inflicted_on()` reads `BattleRules.last_damage`
rather than `ctx.trigger_event`, because a `ChainLink` does not carry the event that made it
eligible — `ctx.trigger_event` is null by the time a Trigger Effect resolves. The event is the
right source in a `condition`, which runs while it is still available; the battle record is the
right source at resolution.

### R41 — and the FIVE places the research changed the implementation

§8 predicted batch 11 needed no research. That was **wrong**, and honestly so. All six cards were
looked up with `request_locale=ja`; five carry official notes that change what the code does, and
four of those would otherwise have been silent bugs.

| Card | cid | What the supplement changed |
|---|---|---|
| `Burst Stream of Destruction` | 5979 | an **activation restriction that is nowhere in the printed English**: not activatable on a turn a `Blue-Eyes White Dragon` already attacked. Plus: the ban covers every copy; it attaches at activation; activation negation lifts it |
| `Vampiric Koala` | 8858 | it triggers when **ATTACKED** as well as when attacking — the subject is 自身, *this card itself battles* |
| `Stamping Destruction` | 5345 | the activation condition is **NOT re-checked at resolution** — the opposite of this engine's usual habit |
| `Straight Flush` | 6911 | an **Equip Card** fills one of the five zones; a **Trap Monster in a Monster Zone** does not, and the card then cannot be activated at all |
| `Back-Up Rider` | 11848 | **either player's** monster; the gain is **not** original ATK; two copies **stack** to +3000 |
| `Chiron the Mage` | 5810 | confirms the TCG reading against the OCG "select" print: it really **targets**, the discard is a real **cost**, it is an **Ignition** effect |

Both `Stamping Destruction` and `Straight Flush` return
「このカードに関連するＱ＆Ａはありません」 — *this card has no related Q&A* — which is what a genuine
absence looks like under the `ja` locale, as distinct from the `en` boilerplate R40 warns about.

**R41 Part G** is the one question the database does not answer: whether `Stamping Destruction`
can target itself. Implemented as **NO**, at MEDIUM, from R28's precedent plus the
`Mystical Space Typhoon` rulings, and recorded as reasoned-from-precedent, not as official.

### A FALSE CLAIM caught by its own assertion

The first draft of R41 Part B stated that "nothing in the V1 pool is a Field Spell" and asserted
it as a **count** in `StampingDestructionTests`. The count **failed**: deck 2 holds
`Hidden Springs of the Far East`, a Field Spell — itself one of the ten cards still
unimplemented. The claim was written from memory and was false.

The correction mattered, because the two cards really do differ on it:

* `Stamping Destruction` targets "1 Spell/Trap **on the field**", which **includes** the Field
  Zone;
* `Straight Flush` names the "**Spell & Trap Zones**", which **excludes** it.

Each now has its own test against a real Field Spell placed in a real Field Zone. Had the claim
been left as prose, both branches would have shipped untested and one of them was wrong.

### A REDUNDANCY found by mutation testing rather than by reading

`Chiron the Mage`'s "your opponent controls" check was duplicated — once in the scope of the
candidate loop and once inside the predicate — so a mutation that broke the predicate half
**survived**. Redundancy is not harmless: it made half the clause untestable. The candidate list
now scans the whole field and filters by the single predicate, so every word of the clause lives
in one place and answers identically at activation and at resolution. Re-mutated: caught by two
assertions.

### Mutation checks — the new suites are not vacuous

Every mutation below was applied to the SHIPPED code, the full suite was run, and the code was
restored from a byte-exact backup.

**All 44 were caught.** A mutation caught by only one assertion was treated as a weakness in the
test, not as a pass: **five** were, every one of those suites was strengthened, and all five were
re-run — that is where most of the difference between the first-draft suite sizes and the shipped
ones comes from.

| # | Mutation | Result |
|---|---|---:|
| S1 | `Stamping Destruction`: the damage is NOT conditional on the destruction | 1 → **2** after strengthening |
| S2 | `Stamping Destruction`: it IS among its own targets | 2 failed |
| S3 | `Stamping Destruction`: the Dragon IS re-checked at resolution | 3 failed |
| S4 | `Stamping Destruction`: resolution asks only `is_on_field()`, not the zone | 5 failed |
| S5 | `Stamping Destruction`: the damage always goes to the opponent | 2 failed |
| S6 | `Stamping Destruction`: a face-DOWN Dragon satisfies the condition | 1 → **2** after strengthening |
| S7 | `Stamping Destruction`: the Field Zone is not "on the field" | 5 failed |
| F1 | `Straight Flush`: the condition counts controlled CARDS, not occupied zones | 4 failed |
| F2 | `Straight Flush`: the condition needs only FOUR zones | 5 failed |
| F3 | `Straight Flush`: the resolution reaches the Field Zone too | 3 failed |
| F4 | `Straight Flush`: the resolution destroys the CONTROLLER's zones | 44 failed |
| F5 | `Straight Flush`: the condition IS re-checked at resolution | 5 failed |
| F6 | `Straight Flush`: it is legal in the Damage Step | 2 failed |
| P1 | **`named_monster_attacked_this_turn()` reads the instance flag, not the event log** | 2 failed — one in the gate, one on the real card |
| B1 | `Burst Stream`: no activation restriction from a prior attack | 3 failed |
| B2 | `Burst Stream`: the ban is aimed at the opponent | 13 failed |
| B3 | `Burst Stream`: the ban is per-INSTANCE, not per-name | 12 failed |
| B4 | **`Burst Stream`: the ban is applied at RESOLUTION rather than at activation** | 2 failed |
| B5 | `Burst Stream`: a face-DOWN Blue-Eyes satisfies the condition | 1 → **2** after strengthening |
| B6 | `Burst Stream`: it wipes the CONTROLLER's monsters | 13 failed |
| B7 | `Burst Stream`: the condition IS re-checked at resolution | 2 failed |
| C1 | `Chiron the Mage`: the cost is any card, not a Spell | 14 failed |
| C2 | `Chiron the Mage`: the discard is not paid at all | 11 failed |
| C3 | **`Chiron the Mage`: targets are not restricted to the opponent** | **SURVIVED** → the CODE was fixed → 2 failed |
| C4 | `Chiron the Mage`: resolution asks only `surviving_field_target()` | 4 failed |
| C5 | `Chiron the Mage`: it is not once per turn | 4 failed |
| C6 | `Chiron the Mage`: the Field Zone is not reachable | 3 failed |
| C7 | `Chiron the Mage`: once-per-turn is per NAME, not per instance | 4 failed |
| R1 | `Back-Up Rider`: the gain is PERMANENT, not until the end of the turn | 6 failed |
| R2 | `Back-Up Rider`: the gain OVERRIDES the ATK instead of adding to it | 5 failed |
| R3 | `Back-Up Rider`: the amount is 1000, not 1500 | 17 failed |
| R4 | `Back-Up Rider`: only your OWN monsters are candidates | 5 failed |
| R5 | `Back-Up Rider`: face-DOWN monsters are candidates too | 3 failed |
| R6 | `Back-Up Rider`: the face-up re-check at resolution is dropped | 2 failed |
| R7 | `Back-Up Rider`: it modifies DEF as well as ATK | 2 failed |
| K1 | `Vampiric Koala`: it fires on ANY battle, not only its own | 5 failed |
| K2 | `Vampiric Koala`: a DIRECT attack triggers it | 3 failed |
| K3 | `Vampiric Koala`: damage to its OWN controller triggers it | 1 → **3** after strengthening |
| K4 | `Vampiric Koala`: it LOSES LP instead of gaining | 7 failed |
| K5 | `Vampiric Koala`: the OPPONENT gains the LP | 8 failed |
| K6 | `Vampiric Koala`: the amount is the printed ATK, not the damage inflicted | 7 failed |
| K7 | `Vampiric Koala`: it is OPTIONAL, not mandatory | 16 failed |
| K8 | `Vampiric Koala`: it is not legal in the Damage Step | 15 failed |
| K9 | `Vampiric Koala`: it triggers from the Graveyard too | 1 (shape only) → **2** after strengthening |

**C3 is the one that mattered most, and it did not point at a weak test — it pointed at weak
code.** `Chiron the Mage`'s "your opponent controls" check was written twice, once as the scope
of the candidate loop and once inside the predicate, so breaking the predicate half changed
nothing. The candidate list now scans the whole field and filters by the single predicate, which
makes the clause live in exactly one place and answer identically at activation and at
resolution. **Redundant code is untestable code**, and the only reason this was found is that a
mutation was written for it.

**K9 is the second lesson.** It was caught only by the `activation_locations` equality assertion —
a SHAPE check — while the behavioural test that looked like it covered the same ground was
refused for an unrelated reason. The location restriction's genuinely load-bearing case is a
Koala that DID battle and has since left the field, which no card in the pool can produce, so it
is now put to `ActivationRules.can_activate()` directly with exactly that state.

**B4's first version was mis-written** and is recorded as such rather than quietly dropped: it
*added* the ban at resolution while leaving `activation_confirmed` in place, so the ban was
applied twice and the mutation was inert. Re-specified as a genuine relocation, it is caught by
the effect-negation test — which is the assertion that proves the ban survives EFFECT negation.

### ObjectDB at exit — batch 11

**226705**, up from 204316. That is **22389 for 811 new assertions — about 27.6 each**, against
the previous checkpoint's ~26.9, and the ~21.6 / ~34.9 / ~44.6 before that. The per-assertion
figure has now risen once, fallen three times and risen again inside six checkpoints, which is
**still not a trend and still has no measured explanation**. None is recorded here, because none
has been measured; this session did not investigate it either, and must not have been expected
to — it fails nothing, hangs nothing and makes no test unreliable. The characterisation task in
`PROJECT_STATE.md` §7 is unchanged and still **must be done before Phase 7**.

### Test-harness lessons this batch paid for

1. **`get_legal_actions(pid)` returns nothing for a player who is not the turn player**, and the
   failure is silent. Driving the OPPONENT's Quick Effect needs a real response window, which
   means the turn player must activate something first — a bait Trap with a no-op
   `card_activation()` effect is the cheapest way to open one. This is the same trap batch 10
   recorded, hit from a third direction.
2. **The engine does not pause when nobody holds a legal response.** It auto-passes and resolves
   the whole Chain inside one `submit_action()`, so "the cost is already paid while the Chain is
   still being built" cannot be observed unless some card could legally respond. Giving the
   opponent a Spell Speed 2 bait is what makes that assertion real rather than vacuous.
3. **`change_control()` accepts monsters only**, by design — no V1 card can move control of a
   Spell/Trap. A "the target changed hands" test for a Spell/Trap-targeting clause is therefore
   not constructible from the pool's mechanics, and the honest substitute is a Trap Monster that
   Summons itself out of its Spell & Trap Zone: still on the field, still theirs, no longer a
   Spell/Trap.
4. **Nothing can chain-negate a Damage Step trigger.** A Chain formed in sub-step 4 admits only
   `MANDATORY_TRIGGER` effects, and every negator fixture is `UNTIL_DAMAGE_CALC`, which
   `ActivationRules.damage_step_ok()` refuses there. A negation test for such a trigger written
   with a chained negator passes **vacuously** — the first draft of the `Vampiric Koala` negation
   test did exactly that and was rewritten to use continuous effect negation, which is the real
   route.
5. **A mutation caught only by a SHAPE assertion is a warning, not a pass.** The
   `Vampiric Koala` "it triggers from the Graveyard too" mutation was caught only by the
   `activation_locations` equality check; the behavioural test that looked like it covered the
   same ground was refused for an unrelated reason. The location restriction's genuinely
   load-bearing case — a Koala that DID battle and has since left the field — cannot be reached
   through the pool's cards, so it is now put to `ActivationRules.can_activate()` directly with
   exactly that state.

---

## Batch 10 — COMPLETE. Nothing in it is partial or unverified.

| Batch 10 unit | Status |
|---|---|
| **Unit A — the generic DECK-ACCESS gate (`DeckAccessTests`, 139)**, plus **R40** and `RULES_SPEC.md` §8.4 | **COMPLETE** |
| **Unit B — `Trade-In` (`TradeInTests`, 70)** | **COMPLETE** |
| **Unit B — `Cards of Consonance` (`CardsOfConsonanceTests`, 63)** | **COMPLETE** |
| **Unit B — `White Elephant's Gift` (`WhiteElephantsGiftTests`, 64)** | **COMPLETE** |
| **Unit C — `Herald of Creation` (`HeraldOfCreationTests`, 73)** | **COMPLETE** |
| **Unit C — `Divine Dragon Apocralyph` (`DivineDragonApocralyphTests`, 65)** | **COMPLETE** |
| **Unit D — `Dragon Shrine` (`DragonShrineTests`, 78)** | **COMPLETE** |
| **Unit D — `The White Stone of Legend` (`TheWhiteStoneOfLegendTests`, 78)** | **COMPLETE** |

### The new generic subsystem — the DECK as a zone an effect may look THROUGH

`RULES_SPEC.md` §8.4 is the normative statement; `CARD_RULINGS.md` **R40** carries the sourcing.
§8.2 already separated DRAW / REVEAL / EXCAVATE and `GameState`'s own comment recorded that
nothing implemented the fourth — *"SEARCH … Nothing here does that; `shuffle_deck()` is its
tail."* Batch 10 implements the fourth, and the gate was written and green **before any card**.

New primitives, all in `EffectPrimitives`, all over `GameState` methods that already existed and
were already correct (`draw()`, `reveal()`, `shuffle_deck()`, `move_card()`): `draw_cards()`,
`can_draw()`, `deck_search_candidates()`, `can_search_deck()`, `search_deck_to_hand()`,
`send_from_deck_to_gy()`, `qualified_hand_cards()`, `qualified_own_field_monsters()`, plus the
`non_effect_monster()`, `tuner_monster()` and `monster_of_level_at_least()` predicates.
**Nothing in `GameState` was reshaped for this.**

Two new `TestFixtures` helpers: `give_to_deck()` and `clear_deck()`. A test that asserts on
deck-out or on "the Deck must hold 2" cannot start from the 40-card filler deck.

### The engine defect batch 10 found and fixed

**Events raised by paying an activation COST never reached the trigger check.**
`DuelEngine._resolve_current_chain()` takes its event mark at the start of chain RESOLUTION,
but a cost is paid during chain BUILDING, long before that mark. So a card **discarded as a
cost** could never fire its own "If this card is sent to the GY" trigger. No card in the pool
triggered off a cost before batch 10, so nothing had exercised the path.

Fixed with `DuelEngine._cost_events`, deliberately in the **same shape** `_carried_events`
already uses to withhold the Damage Step's flip for sub-step 4: the events are **held**, not
acted on immediately, because a Trigger Effect that meets its condition while a Chain is being
built does not interrupt it — it activates after that Chain finishes resolving (master prompt
45). The cost events are placed **before** the resolution's own events in the batch, because
they happened first and a batch's order decides the order simultaneous triggers are offered in.

`DeckAccessTests` asserts the path generically (a synthetic discard-engine Spell firing a
synthetic GY searcher) and `TheWhiteStoneOfLegendTests` asserts it on the real cards
(`Cards of Consonance` discarding `The White Stone of Legend`). Both suites failed before the
fix and pass after it.

### R40 — and the two places the research CHANGED THE PLAN

R40 is the only ruling batch 10 opened, and it is CLOSED. Every batch-10 card carries
`Special Ruling Needed = NO` in the matrix; that was a deliberate criterion for choosing the
batch. The research was done **before** any card was written, and it contradicted the plan
twice:

1. **`The White Stone of Legend` is the EXCEPTION to [S1 p.53]'s search-activation restriction,
   not an instance of it.** The general rule says you cannot activate an effect to search your
   Deck when nothing qualifies; the first draft of the batch-10 plan applied it to this card.
   The official supplement (cid 7850, 2024-03-23) says the opposite in as many words: it is a
   mandatory GY Trigger Effect, it **must** activate whenever its condition is met, and it
   **activates even with no `Blue-Eyes White Dragon` in the Deck**, resolving and adding
   nothing. It also activates during the Damage Step. Card-specific official guidance outranks
   the general sentence. Asserted directly, in both directions.
2. **A "draw 2" cannot be activated on a Deck of fewer than 2.** The general rules alone would
   have let a player activate `Trade-In` on a one-card Deck, draw 1 and lose by deck-out. The
   supplements for cid 7248 (`Trade-In`) and cid 8656 (`Cards of Consonance`) each state the
   restriction explicitly and independently. Implemented generically as `can_draw()`, not as
   per-card constants. `White Elephant's Gift`'s own supplement (cid 9138) is silent, so the
   same gate is applied to it **by analogy** and is recorded as an inference at MEDIUM-HIGH —
   not as an official ruling for that card.

**A research-methodology defect was found and is recorded in R40.** The first fetches used
`request_locale=en` and returned the database's generic marketing boilerplate for every cid —
byte-identical between two different cards. That was very nearly written down as "no official
Q&A exists for these cards", which would have been **false**. `request_locale=ja` returns the
real supplemental information for all ten lookups. A generic-boilerplate response from that
database is evidence of a bad locale, not of an absent ruling.
### Mutation checks — the new suites are not vacuous

Every mutation below was applied to the SHIPPED code, the full suite was run, and the code was
restored from a byte-exact backup. **All 31 were caught.** A mutation caught by only one
assertion was treated as a weakness in the test, not as a pass: **D1** and **W1** were each
caught by a single assertion on the first pass, both suites were strengthened, and both were
re-run — that is where the last 4 assertions of the 6914 came from.

| # | Mutation | Result |
|---|---|---:|
| M1 | drop the search's tail shuffle | 2 failed |
| M2 | drop the reveal on a search | 4 failed |
| M3 | `can_draw()` always true | 2 failed |
| M4 | `can_search_deck()` always true | 2 failed |
| M5 | mill via `draw()` instead of a send | 2 failed |
| T1 | `Trade-In` accepts Level 7 | 13 failed |
| T2 | `Trade-In` drops the Deck gate | 5 failed |
| T3 | `Trade-In` draws 1 | 5 failed |
| C1 | `Cards of Consonance` ignores the race | 4 failed |
| C2 | `Cards of Consonance` ignores the ATK cap | 4 failed |
| C3 | `Cards of Consonance` sends instead of discarding | 3 failed |
| W1g | `White Elephant's Gift` accepts face-down monsters | 3 failed |
| W2g | `White Elephant's Gift` accepts Effect Monsters | 4 failed |
| W3g | `White Elephant's Gift` drops the Deck gate | 3 failed |
| H1 | `Herald` floor becomes 6 | 3 failed |
| H2 | `Herald` floor becomes an exact match | 9 failed |
| H3 | `Herald` once-per-turn dropped | 2 failed |
| H4 | `Herald` target chased instead of dropped | 2 failed |
| H5 | `Herald` reaches either Graveyard | 2 failed |
| A1 | `Apocralyph` race ignored | 5 failed |
| A2 | `Apocralyph` once-per-turn dropped | 2 failed |
| A3 | `Apocralyph` reaches either Graveyard | 2 failed |
| D1 | `Dragon Shrine` second send always unlocked | 1 → **4** failed after strengthening |
| D2 | `Dragon Shrine` second send not optional | 6 failed |
| D3 | `Dragon Shrine` named ACTIVATION → named EFFECT | 2 failed |
| D4 | `Dragon Shrine` activation gate dropped | 2 failed |
| D5 | `Dragon Shrine` race ignored | 10 failed |
| W1 | **`The White Stone of Legend` gated on `can_search_deck()`** — i.e. the general [S1 p.53] rule re-applied, the exact mistake R40 corrects | 1 → **3** failed after strengthening |
| W2 | `The White Stone of Legend` mandatory → optional | 16 failed |
| W3 | `The White Stone of Legend` keys on destruction, not a send | 7 failed |
| W4 | `The White Stone of Legend` fires on ANY card's send | 2 failed |

**W1 is the one that mattered most.** It re-introduces exactly the reading that the first draft
of the batch-10 plan had, and that the official supplement for cid 7850 contradicts. It is now
caught by three assertions, including one that checks the stone's OWN Chain Link by card id
rather than counting links.

### Test-harness lessons this batch paid for (all recorded in the suites themselves)

1. **An unqualified "discard 1 card" makes the whole hand a candidate**, including the five
   opening-hand cards. `ScriptedController`'s default answer is "the first option", which is
   almost never the card a test means. Queue it with `queue_for()` and then assert
   `controller.errors == []` — that is what proves the queued answer reached the intended prompt.
2. **`TestFixtures.activation_negator()` only answers Spell/Trap activations** (it asks
   `spell_trap_activation_below()`). Holding a window open against a monster's Ignition Effect
   needs `interferer()` or `any_effect_negator()`.
3. **An interferer must belong to the TURN PLAYER.** `get_legal_actions(pid)` returns nothing
   for a player who is not the turn player, and the failure is silent — the helper just returns
   false. This cost a cycle; it is the same trap §8's reminders already record, hit from a new
   direction.
4. **`TestFixtures.end_turn()` leaves the engine in the DRAW phase**, not Main Phase 1. A
   once-per-turn reset test for a **Spell** must `advance_to_phase(MAIN_1)` afterwards; a monster
   Ignition Effect happens not to need it, which is exactly why the Spell case was the one that
   failed.
5. **Event counts must be read as DELTAS.** A duel has already drawn two opening hands before any
   test starts, so an absolute `count_events(CARD_DRAWN)` measures the setup. And a Normal Spell's
   own trip to the GY after resolving is a real `CARD_SENT_TO_GY`, so "the milled card was sent"
   is `count_events_for(..., card_id)`, never a bare count.

---

## Batch 9 — COMPLETE. Nothing in it is partial or unverified.

| Batch 9 unit | Status |
|---|---|
| **Unit A — the generic attack-restriction / attack-negation gate (`AttackRestrictionTests`, 229)** | **COMPLETE** (previous session) |
| **Unit B card 1 — `Mirage Dragon` (`MirageDragonTests`, 121)** | **COMPLETE** |
| **The generic "it remains on the field" override (`SpellTrapTests` 27 → 49)** | **COMPLETE** |
| **Unit B card 2 — `Swords of Revealing Light` (`SwordsOfRevealingLightTests`, 122)** | **COMPLETE** |
| **Unit B card 3 — `Maiden with Eyes of Blue` (`MaidenWithEyesOfBlueTests`, 139)** | **COMPLETE** |
| **Unit C card 1 — `Kaiser Sea Horse` (`KaiserSeaHorseTests`, 57)** | **COMPLETE** |
| **The generic lingering material-choice constraint (`ChoiceConstraintTests`, 137)** | **COMPLETE** |
| **Unit C card 2 — `Soul Exchange` (`SoulExchangeTests`, 174)** | **COMPLETE** |

Batch 9 completes the pool's **attack- and battle-modification group** and its
**Tribute-modification group**. Four per-card rulings were **closed** by this work — **R3**,
**R6**, **R7** and **R8** — and three new generic mechanisms were built, each as its own unit
with its own tests before the card that needed it.

### Rulings closed this session

| Was | Now | Recorded as |
|---|---|---|
| **R6** — which End Phase is `Swords of Revealing Light`'s 3rd? | **CLOSED.** The opponent's three turns AFTER activation; destroyed in the End Phase of the third. A Normal Spell is only ever activated on its controller's own turn [S1 p.31], so the controller's turns can never be counted. | **R36** |
| **R3** — is `Maiden with Eyes of Blue`'s restriction shared across both clauses? | **CLOSED.** Yes — ONE allowance, `opt_named_effect()` plus the same `in_group()` key on both. Contrast `Judge of the Ice Barrier`, whose "each of the following effects" gets one use per clause. | **R37** |
| **R8** — how does `Kaiser Sea Horse` modify the Tribute computation? | **CLOSED.** A rules QUERY on the Attribute of the monster being SUMMONED; permission not compulsion; the Tribute Summon path only; worth 1 while face-down or negated. | **R38** |
| **R7** — what exactly does `Soul Exchange` constrain? | **CLOSED.** A turn-scoped lingering **material-choice constraint** — no control change, no extra Tribute, no changed Tribute count. It binds which monster is chosen on **both** the Tribute Summon/Set route and the Tribute-**cost** route. It drops on the target leaving its Monster Zone, on a control change, on a face-up→face-down reset and at the exact end of turn; a still-affected target that becomes unsuitable **blocks** the Tribute instead of releasing it. The Battle Phase sentence is an activation **condition**, confirmed at Chain Link processing: it survives EFFECT negation, not ACTIVATION negation. | **R39** |

**R34 part D was re-checked, not closed.** The official Konami database has **no Q&A entry for
cid 6196** (`Mirage Dragon`), and Yugipedia and the Fandom wiki were unreachable (HTTP 403 and
402). [S1 p.30] and [S1 p.53] back the card-versus-effect distinction generally, which is
better sourcing than "PSCT alone", but it is still not a quoted ruling on the card. **Part D
stays MEDIUM-HIGH** and is recorded as such in **R35**.

**R1 and R2 remain OPEN.** They belong to cards that are already implemented and are carried
forward as recorded questions, not as gaps in this batch. **R7 is now CLOSED (R39).**

### Generic mechanics added — none left UNVERIFIED

* **The lingering material-choice constraint** (`GameState.choice_constraints`,
  `require_choice_this_turn()` / `required_choice_ids()` / `choice_selection_ok()` /
  `clear_choice_constraints_for()`; `RULES_SPEC.md` §5.9). Every other restriction in the engine
  answers *"may I?"*; this one answers *"if you do, it must be THIS card"* — a shape nothing in
  the engine had. Written and passing against a **synthetic** grant Spell in
  `ChoiceConstraintTests` (137) before `Soul Exchange` existed, and driven from **both seats**,
  so the constraint cannot pass by being hard-wired to player 0. It is keyed by
  (player, scope, target, turn), which is why the suite can assert that an unrelated scope and
  the opponent's own selections are untouched. Two consequences fell out of building it
  generically and are pinned by tests rather than left to be inferred:
  `SummonRules.tributes_satisfy()` had to stop being a **greedy maximum-value** check and start
  **enumerating complete combinations** (`tribute_combinations()`, published on the action as
  `tribute_combinations` so a UI never has to re-derive them); and the engine now **rejects a
  forged own-only Tribute payload** rather than merely not offering it — asserted by submitting
  one and checking that nothing was paid.
* **`EffectPrimitives.can_pay_tribute_cost()` / `tribute_cost_candidates()` /
  `exclude_required_tributes()`.** The Tribute-**cost** route is a genuinely different channel
  from the Summon route, so the constraint had to be taught to both. The cost route keeps its
  own filters: a cost that requires **this** card cannot substitute another monster
  (`Kaibaman`), and a **typed** cost cannot inspect an opponent's face-down Type or Attribute
  (`Dragonic Tactics`, `Spiritual Wind Art - Miyabi`) — the `requires_identity` flag exists for
  exactly that and is asserted, not assumed. `exclude_required_tributes()` stops a mandatory
  cost material from also being the effect's target, because the material is gone before
  targeting happens (`Enemy Controller`, `Spiritual Wind Art - Miyabi`).
* **`EffectDef.activation_confirmed` + `ActivationRules.ACTIVATION_CONDITION_EFFECT_ID`.** A
  consequence of a confirmed CARD activation that must survive **effect** negation while still
  being undone by **activation** negation. It fires when the Chain Link is processed, which is
  safe precisely because no phase can be conducted while a Chain is unresolved — so no rollback
  of other sources is needed. Both negation paths are asserted with a real two-link Chain and a
  real negator card, not by poking the flag.
* **`CardInstance.field_revision` + `EffectPrimitives.target_kept_field_identity()`.** A target
  that left the field and came back is a **different stay on the field**. The revision is
  snapshotted into `ChainLink.target_field_revisions` at activation, so a resolution-time
  re-check can tell "still there" from "left and returned" — which a zone check alone cannot.
* **The card-declared "it remains on the field" override.**
  `DuelEngine.REMAINS_ON_FIELD_EFFECT_ID` + `card_remains_on_field_after_activation()`,
  consumed by `_cleanup_resolved_spell_traps()`. Written and passing against a SYNTHETIC card
  before `Swords of Revealing Light` existed. Two decisions are pinned down by tests rather
  than left to be inferred: it is a **second** question asked AFTER the kind question, so it
  can only ever KEEP a card and never send one to the GY that the rules say stays; and it is
  **deliberately not negation-aware**, because negation does not send a card to the Graveyard.
  The fixture takes the card kind as a parameter and the suite drives it as a Normal TRAP too,
  so the override cannot pass by quietly special-casing Normal Spells.
* **`EffectPrimitives.flip_face_up()` / `controls_a_face_down_monster()`.** Flipping is not a
  Flip Summon [S1 p.24, p.28]: no Summon event and the Normal Summon allowance untouched, but
  `CARD_FLIPPED_FACE_UP` is emitted, so the Flip effects of the monsters turned over really
  are collected and really resolve — asserted end to end by the opponent actually drawing, not
  merely by the event.
* **`EffectPrimitives.is_targeted_by_a_live_activation()`.** "A card or effect is activated
  that targets this card", read from the CHAIN rather than from the trigger event. That is
  forced rather than stylistic: a Quick Effect is offered by
  `DuelEngine._activation_actions()`, which asks `ActivationRules.can_activate()` with **no
  event**, so a condition reading `ctx.trigger_event` would answer false at exactly the moment
  the effect must be offered.
* **`EffectPrimitives.own_cards_in_zones()`.** "From your hand, Deck, or GY" as one candidate
  list. The zones are an argument, so a card that says "hand or GY" cannot quietly also search
  the Deck.
* **`EffectPrimitives.may()`.** The pool's first **optional step INSIDE a resolving effect** —
  the second "you can" in `Maiden with Eyes of Blue`. It goes through `ctx.ask()` like every
  other mid-resolution choice, so the replay payload carries it and the duel stays
  reproducible. A controller that cannot answer is treated as declining, because doing nothing
  is always a legal outcome of a "you can".

### What the two new suites pin down

**`ChoiceConstraintTests` — 137/137.** The generic gate, written against a synthetic grant
Spell before `Soul Exchange` existed, and run from **both seats**. It asserts that the
constraint is created at **resolution** and not at activation — proved by holding the Chain
open with a real opposing response card and checking that `choice_constraints` is still empty
while the window is open; that it belongs to the activating seat only, that an unrelated
**scope** is untouched, and that ownership and control never change (`CONTROL_CHANGED` is
asserted to fire **zero** times, which is the whole "as if you controlled it" question); that
the complete set of legal combinations is enumerated and **published on the action**
(`tribute_combinations`), with own-only, insufficient-value and duplicate selections each
refused individually; that a **forged** own-only payload submitted straight to the engine is
rejected and pays nothing; that a paid material stays in its **owner's** Graveyard even when
the Summon is then **negated** by a real negator card; that four separate invalidation routes
(target leaves, target banished and returned, control changed, flipped face-down) each clear
the constraint permanently and restore the player's own free choice; that an unsuitable target
**blocks** the Tribute without lifting the obligation, while unrelated actions stay legal; that
optional double-Tribute value can be **declined** so a double-value monster may count as one,
that an opponent-only Tribute does **not** free your Monster Zone, and that a face-down double
is worth one; that the constraint expires at the **exact** turn boundary and not on End Phase
entry; that two simultaneous constraints must **both** be satisfied; that the cost route
enforces its own qualifications and pays the whole selection or nothing; and that the whole
sequence **replays deterministically** from the recorded action payloads to an identical event
stream and an identical constraint state.

**`SoulExchangeTests` — 174/174.** The printed card against the **real pool**, not a synthetic
stand-in: `Alexandrite Dragon` as the opponent's target, `Metaphys Armed Dragon` and
`Witchcrafter Golem Aruru` as the Summon to aim at, and the real `Kaiser Sea Horse`,
`Kaibaman` and `Dragonic Tactics`. It asserts the clause shape off the registry (two clauses,
Normal Spell, Spell Speed 1, exactly one target, and the permission is **not** a cost); that
the target must be an opposing **monster** — an own monster, a Spell and an empty selection are
each **rejected by the engine**, not merely unoffered; the four timing refusals (opponent's
turn, during the Battle Phase, after a Battle Phase has been conducted, and no opposing
monster); that the permission actually **binds** the Summon, so an own-only combination is
refused while it stands and the granted opposing material completes it; and that the Battle
Phase lock lands on the **activating** player, not the opponent, and resets exactly at end of
turn. Seven **real two-link Chains** cover the interesting cases: activation negation lifts the
Battle Phase condition and grants nothing, **effect** negation grants nothing but the Battle
Phase condition **stands**, and the target leaving, leaving and **returning**, changing
control, being flipped face-down, or `Soul Exchange` itself being destroyed each produce the
right answer — with the face-down and destroyed-source cases going on to complete the Summon,
so the negatives are not passing on a broken board. Both `Kaiser Sea Horse` placements are
driven (an opposing Kaiser supplying two Tributes; your own Kaiser counting as one alongside
the forced material), the Tribute-**cost** route is driven through two real cards,
`ScriptedController.errors` is asserted empty so no prompt was silently defaulted, and the card
replays deterministically.

### Engine defects found

**One, and it was real.** `SummonRules.tribute_value()` honoured `effects_are_negated()` but
**not face-orientation**, so a **face-down `Kaiser Sea Horse` wrongly counted as two
Tributes**. A face-down monster may still be Tributed [S1 p.53] and is a legal
`tribute_candidates()` entry, but it applies no effects while face-down — the same rule
`ContinuousEffects._continuous_sources()` enforces for every other continuous clause. Found by
`KaiserSeaHorseTests`; fixed in the rules layer; and the rule is now asserted in the **generic
gate** (`SummonTests` 85 → 88) as well as in the card's own suite, because it belongs there.

**A second one, found by the material-choice unit and equally real.**
`SummonRules.tributes_satisfy()` computed a **greedy maximum** Tribute value and then rejected
any material it judged unnecessary. That is wrong for an **optional** double-Tribute clause: a
double-Tribute monster **may** count as one when the player needs it to, so a legal two-card
selection for a two-Tribute Summon was refused whenever one of the two happened to be a
`Kaiser Sea Horse`. It is now an enumeration of complete legal combinations
(`tribute_combinations()`), and the rule is asserted in the generic gate as well as in
`SoulExchangeTests`. `SummonRules.tribute_candidates()` also silently returned non-monsters and
ignored `cannot_be_tributed`; both are now filtered at the single source.

The other three cards found **no** engine defect, which is the expected result: unit A had
already flushed their machinery out, and the new generic units were each written and made
to pass before the card that needed them.

### Test-harness defects found and fixed in this session

**One, in this session's own new suite, and it is the batch-8 pattern again.**
`SwordsOfRevealingLightTests` indexed its turn-trace array directly. A wrong implementation
ends the countdown early and so makes the trace SHORTER, and a raw out-of-range index **aborts
the test after its passing assertions instead of failing it** — silently dropping every claim
after it. Reading through a guarded accessor turned the R6 mutation from **4 failures into 8**.
This is the same class of defect batch 8 recorded against `JunkBladerTests`, and it is the
reason every new suite should route indexed reads through a helper that returns a sentinel.

One more wrong test was caught by the engine rather than by inspection:
`MaidenWithEyesOfBlueTests` first tried to make the Maiden's negation fail by calling
`BattleRules.negate_attack()` by hand after the attack — but the Maiden's own trigger has
already resolved by then, so the call raced it and the test was measuring the wrong thing.
Rewritten to let a **different card** negate the same attack as Chain Link 2, which is the only
honest way to make the Maiden's own link find nothing left to negate.

### Every card suite was mutation-checked, not trusted for passing

A suite that passes first try is not evidence that it bites. Each card's load-bearing claim was
broken on purpose and the failure count measured:

| Card | Mutation | Assertions that failed |
|---|---|---:|
| `Mirage Dragon` | aim the lock at the controller instead of the opponent | **39** |
| `Mirage Dragon` | drop the phase scoping (lock every phase) | **6** |
| the remains-on-field override | drop the call site in `_cleanup_resolved_spell_traps()` | **4** |
| `Swords of Revealing Light` | count the controller's turns instead of the opponent's | **8** |
| `Maiden with Eyes of Blue` | give each clause its own once-per-turn group | **5** |
| `Maiden with Eyes of Blue` | drop the "and if you do" gate | **2** |
| `Maiden with Eyes of Blue` | search only the hand, not hand + Deck + GY | **2** |
| `Kaiser Sea Horse` | read the Attribute off its own card | **5** |
| the material-choice constraint | drop `choice_selection_ok()` from `tributes_satisfy()` | **12** in `ChoiceConstraintTests` |
| the material-choice constraint | no-op `clear_choice_constraints_for()` (the constraint never expires) | **6** in `ChoiceConstraintTests` |
| `Soul Exchange` | drop the `activation_confirmed` call in `ChainManager` | **8** |
| `Soul Exchange` | bypass the `CARD_ACTIVATION` condition gate in `ActivationRules` | **1** |
| `Soul Exchange` | drop the `target_kept_field_identity()` re-check | **1** |

Every mutation was reverted and the suite re-run green before the work was committed; the tree
was then compared byte-for-byte against a pre-mutation snapshot to prove nothing was left behind.

**Two of these mutations exposed a real hole in `SoulExchangeTests`, and it was fixed.** The
two constraint mutations were caught by the generic gate but **not** by the card's own suite:
`SoulExchangeTests` drove only the *legal* Tribute Summon through the engine, so it never
asserted that the permission actually **binds** the selection. Two assertions were added per
seat — an own-only combination is refused while the permission stands, and the granted opposing
material completes the Summon — taking the suite from 170 to **174**. Re-running the first
mutation now fails it in **2** places. The cost route was already covered: the "self-Tribute
cannot omit required opponent" assertion reads `can_pay_tribute_cost()` directly and survived
that mutation for the right reason.

The two mutations that score **1** score it honestly. Bypassing the activation-condition gate
only breaks "after Battle Phase refused"; the other two refusals in that block ("Battle Phase
refused", "opponent turn timing refused") are enforced by the **generic** Normal Spell timing
rules, so they correctly keep passing. Dropping the field-identity re-check breaks exactly one
case — the "left and returned" Chain mode — which is the only case it exists for.

### ObjectDB at exit

**187347**, up from 180615. That is **6732 for 311 new assertions — about 21.6 each, LOWER
again than the previous checkpoint's 34.9, which was itself lower than the 44.6 before it.**
Two consecutive falls now follow the run of five consecutive rises. **No explanation for that
is recorded here, because none has been measured** — this session did not investigate it
either, and two data points are not a trend. The characterisation task is unchanged and still
**must be done before Phase 7**.

### Batch 8 — COMPLETE. Nothing in it is partial or unverified.

All six units are done, tested and committed. Both remaining cards were finished in this session,
each behind its own generic gate written and passing first.

This session added **493** assertions and changed **no existing test expectation at all**. **All
4787 assertions from the previous checkpoint pass unchanged** — none was weakened, retargeted or
deleted. Every pre-existing suite reports exactly its previous count; no suite was rewritten.

* New core-rules suites: `TrapMonsterTests` **192** — the **Trap-Monster gate** — and
  `BattlePhaseRestrictionTests` **53** — the **Battle-Phase-restriction gate**. Both were written
  and passing **before** the card that needed them, the way `EquipTests`, `ControlTests`,
  `MovementTests`, `BanishTests` and `LifePointCostTests` were.
* New per-card suites: `ThePhantomKnightsOfShadowVeilTests` **125**,
  `RunickFlashingFireTests` **123**.

| Batch 8 unit | Suite | Result |
|---|---|---|
| the generic banish / temporary-removal gate | `BanishTests` | 158/158 |
| `Interdimensional Matter Transporter` | `InterdimensionalMatterTransporterTests` | 175/175 |
| the generic LP-payment-as-cost gate | `LifePointCostTests` | 109/109 |
| `Judge of the Ice Barrier` | `JudgeOfTheIceBarrierTests` | 154/154 |
| `Junk Blader` | `JunkBladerTests` | 73/73 |
| **the generic Trap-Monster gate** | `TrapMonsterTests` | **192/192** |
| **`The Phantom Knights of Shadow Veil`** | `ThePhantomKnightsOfShadowVeilTests` | **125/125** |
| **the generic Battle-Phase-restriction gate** | `BattlePhaseRestrictionTests` | **53/53** |
| **`Runick Flashing Fire`** | `RunickFlashingFireTests` | **123/123** |

The LP-cost suite is **unchanged at 109**, as required. Cards started but unfinished: **none.**
Mechanics left UNVERIFIED: **none.**

#### Generic mechanics added by the final two units

* **Trap Monsters — a card with two identities.** `CardInstance.monster_identity` plus
  `become_monster()` / `clear_monster_identity()` / `has_monster_identity()` /
  `original_card_category()` / `current_level()` / `current_attribute()` / `current_race()` /
  `is_normal_monster()`, with `is_monster()` / `is_trap()` / `is_spell()` / `base_atk()` /
  `base_def()` answering from the runtime identity when one is held. The immutable, **shared**
  `CardDef` is never written to — asserted by keeping a second copy of the same definition in the
  Graveyard and proving it stays a Trap. `GameState.move_card()` revokes the identity on every
  departure from a Monster Zone, in one place. New spec section `RULES_SPEC.md §5.8`; new ruling
  **R33**.
* **A DESTINATION replacement** — `GameState.BANISH_WHEN_LEAVING_FIELD_KEY` and
  `EffectPrimitives.banish_when_it_leaves_the_field()`. Distinct from the destruction replacement
  of §17: that one swaps *which card* is destroyed, this one swaps *where this card ends up*, and
  it applies to every departure rather than to destruction alone. **Only the destination changes;
  the reason does not**, so a redirected destruction still fires `CARD_DESTROYED`.
* **"Skip your next Battle Phase" as authoritative turn state** — `PlayerState.battle_phase_skips`,
  `GameState.impose_battle_phase_skip()` / `has_pending_battle_phase_skip()` /
  `consume_battle_phase_skip()`, the `BATTLE_PHASE_SKIP_IMPOSED` / `BATTLE_PHASE_SKIPPED` events,
  and `TurnFlow._spend_battle_phase_skip()`. A genuinely **third** lifetime alongside the
  turn-scoped and continuous restrictions that already existed — see the table in
  `RULES_SPEC.md §2.4`. New ruling **R32**, with honest per-part confidence.
* **A gain with NO printed duration** — `EffectPrimitives.gain_atk_and_def_permanently()`. The
  absence of a duration is the specification: not end-of-turn, and not tied to a source that is in
  the Graveyard moments later.
* **A Special Summon to the EXTRA Monster Zone** — a `to_zone` on
  `SummonRules.begin_special_summon()` / `complete_summon()` / `DuelEngine.special_summon()`, plus
  `PlayerState.monsters()` now counting the Extra Monster Zone. `Runick Flashing Fire`'s second
  bullet names that zone explicitly, and a monster sitting in it has to be a monster the player
  controls for every rules question that follows.
* **`EffectPrimitives.extra_deck_monsters()` / `special_summon_from_extra_deck()`** and
  **`skip_your_next_battle_phase()`**.
* Test-side: `TestFixtures.trap_monster()`, fully parameterised so the gate can prove the runtime
  type line is really carried rather than hard-coded.

#### Defects found by the final two units

**No pre-existing engine defect.** Every defect found was in test code, and all three are of the
two false-positive shapes `PROJECT_STATE.md §12` warns about — which is why the path assertions
that caught them were written in the first place.

1. **A vacuous negation test, caught by its own path assertion.** `TrapMonsterTests`'s
   summon-negation test used `TestFixtures.effect_negator()`, which deliberately answers only the
   narrower "a Spell/Trap **CARD** was activated below me" question and so could never fire on a
   Graveyard **Ignition Effect** — and it drove the Chain through
   `TestFixtures.activate_effect()`, which finishes with `pass_until_open()` and therefore
   auto-passes the opponent's response window. The test would have passed against a broken
   implementation. It failed on the `EFFECT_NEGATED` assertion instead of on its conclusions,
   which is exactly what that assertion is for. Rewritten to build the Chain link by link with
   `any_effect_negator()`.
2. **A script error that aborted a test after its passing assertions.** A shape assertion in
   `ThePhantomKnightsOfShadowVeilTests` read `EffectDef.optional`, which does not exist — the
   field is `optionality`. The suite reported 123/124 with a `SCRIPT ERROR` line rather than
   failing cleanly. Same class as the batch-8 `JunkBladerTests` `copies_total` access, and the
   reason the run is checked for `SCRIPT ERROR` lines and not for `RESULT: PASS` alone.
3. **A Damage Step test observing the wrong moment.** The response window straight after an
   attack declaration is the **Battle Step**, not the Damage Step, and a Spell Speed 2 Trap is
   perfectly legal there — so "is it offered?" taken at that instant tested nothing. Rewritten to
   ask `ActivationRules.damage_step_ok()` at the sub-step, the way `JunkBladerTests` does.

A fourth finding was a wrong expectation of the author's rather than a defect: a test asserted the
opponent's Deck grew by one when their monster was bounced, and a bounce goes to the **hand**.
Corrected to the right expectation rather than the assertion being removed.

#### Generic mechanics added earlier in batch 8

* **Paying LP as an activation cost.** `EffectPrimitives.LP_COST_KEY` / `LP_COST_REASON`,
  `can_pay_life_points_cost()`, `pay_life_points_cost()`, `life_points_paid_in()`,
  `activation_paid_life_points()`, `cost_event_paid_life_points()`. **No engine change was
  needed to carry the provenance**: `_perform_activation()` already copied `ctx.cost_payload`
  into both the `COST_PAID` event and the `ChainLink`, so the payment rides the cost channel
  batch 4 built. New spec section `RULES_SPEC.md §10.4`; new ruling **R31**.
* **A CONTINUOUS clause that reacts to a discrete event.** `EffectDef.respond_to_event` +
  `ContinuousEffects.respond_to()`, dispatched from a non-reentrant queue in `DuelEngine` so
  application order equals emission order and replays reproduce it. `CardRegistry` rejects such
  a clause that is not continuous or that names no event. New spec section `RULES_SPEC.md §5.7`.
* **Archetype membership by quoted name.** `name_matches_archetype()`, `archetype_monster()`,
  `controls_archetype_monster()` (with the `exclude_id` that "another" needs).
* **`chain_link_below()`** — the negation question that does not care what kind of card the link
  below is. `spell_trap_activation_below()` deliberately answers only the narrower Spell/Trap
  question and could not reach a monster's Ignition Effect at all.
* Test-side: `TestFixtures.lp_cost_activation()`, `lp_cost_ignition()`,
  `non_lp_cost_activation()`, `lp_changer()`, `lp_cost_watcher()`, `any_effect_negator()`.

#### Defects found earlier in batch 8

**No pre-existing engine defect, and no engine defect at all.** That is a result rather than an
omission: the LP-cost gate was written and green before `Judge of the Ice Barrier` existed, so
the card landed on an API that had already been exercised. Everything found was test-side.

1. **Three tests observed the Chain after it had already resolved.** The engine does not pause
   when neither player holds a legal response — it auto-passes and resolves the whole Chain
   inside one `submit_action()` — so `state.chain` was correctly empty when read. Fixed by
   giving the responding side a spare Set card, which keeps the window genuinely open. Not an
   engine defect: the reminder in `PROJECT_STATE.md §8` describes exactly this behaviour.
2. **A fixture gap, not a card bug.** `TestFixtures.effect_negator()` cannot negate a monster's
   Ignition Effect, because `spell_trap_activation_below()` deliberately returns null for a
   monster source. Judge's clauses 2 and 3 are the pool's first clauses that need it. Closed
   with the generic `chain_link_below()` and `any_effect_negator()`, leaving the narrower
   primitive and its existing consumers untouched.
3. **A `JunkBladerTests` assertion read `copies_total` off `CardDef`, which does not carry it**
   — the copy count is a property of the DECKS. The bad access aborted the test **after** its
   passing assertions rather than failing it, so the suite reported a clean 70/70 while
   silently dropping its final claim. This is the same class of false positive as the batch-8
   `Interdimensional Matter Transporter` fallback-path pass, and it is why the run is now also
   checked for `SCRIPT ERROR` lines rather than for `RESULT: PASS` alone. Rewritten to read the
   verified card database directly; the suite is now 73/73 with no script errors.

#### Not yet covered — additions from this session

* **R31 part B (paying LP down to exactly 0) rests on weak evidence** and is a TCG/OCG split.
  It is isolated in `can_pay_life_points_cost()` and is unreachable in the V1 pool.
* **`ContinuousEffects.respond_to()` is exercised by two clause shapes only** — the synthetic
  watcher and Judge's LP tax, both keyed on `COST_PAID`. No card in the pool responds to any
  other event this way, so the dispatcher's behaviour for other event kinds is proven only by
  its own structure, not by a printed card.
* **The ObjectDB figure rose faster than assertions did this session** — see the harness note.

### Batch 7 — kept for the record

Batch 7 units C and D added **794** assertions and changed **no existing test expectation at
all**. **All 3324 assertions from the units-A+B checkpoint pass unchanged** — none was weakened,
retargeted or deleted. Every pre-existing suite reports exactly its previous count; the single
suite whose number moved is `MovementTests`, which **grew** from 194 to 210 because two generic
tests were added to it, not because anything in it was rewritten.

* New per-card suites: `PhoenixWingWindBlastTests` **162**, `SpiritualWindArtMiyabiTests` **150**,
  `ChainDetonationTests` **168**, `ChainHealingTests` **147**, `CrystalSeerTests` **151**.
* `MovementTests` 194 → **210**: two new generic tests for the resolution-time target re-checks
  units C and D needed (`surviving_field_target()` / `surviving_opponent_field_target()`), written
  against synthetic cards so they prove the ENGINE is right rather than that one printed card is.
  See `CARD_RULINGS.md` **R29**.

The units-A+B summary below is kept for the record.

> Batch 7 units A and B added **462** assertions and changed **nothing** that already existed.
> **All 2862 assertions from the batch-6 checkpoint passed unchanged.**
>
> * New: `MovementTests` **194** (the movement / excavation gate — written and passing before
>   any batch-7 card existed, the way `EquipTests` and `ControlTests` were),
>   `CompulsoryEvacuationDeviceTests` **88**, `KaiserGliderTests` **93**,
>   `AWingbeatOfGiantDragonTests` **87**.

The batch-6 summary below is kept for the record.

> Batch 6 added **465** and changed **two** existing suites, both deliberately and both because
> the behaviour they described was corrected:
>
> * `SummonTests` 45 → **85**. Four new tests for the Flip Summon declaration architecture. The
>   original `Flip Summon legality and position` test is unchanged and still passes.
> * `ChampionsVigilanceTests` 114 → **128**. Its `KNOWN GAP` test — which asserted that a Flip
>   Summon could NOT be negated — was **replaced** by `it negates a Flip Summon`, plus a positive
>   control that an unanswered Flip Summon still succeeds. This is the one test expectation
>   changed in that batch, and it was changed because the old expectation described an engine
>   limitation that has been fixed, not because the new code failed it.
> * New: `ControlTests` **93** (the control gate), `AussaTheEarthCharmerTests` **107**,
>   `EriaTheWaterCharmerTests` **36**, `WynnTheWindCharmerTests` **48**,
>   `EnemyControllerTests` **127**.

Per-test assertion counts in this file are **measured**, not counted by hand from source:
`TestCase` records them per test and `Scripts/tests/DumpAssertionCounts.gd` prints them.
A suite that loops over nine cards runs many more assertions than it has `t.` call sites,
and the earlier hand-written `ShiningAngelTests` breakdown was wrong for exactly that
reason — it has been corrected against the measurement.

Card library: **44 / 77 implemented, 44 / 77 tested, 33 remaining** — computed by
`Tools/build_matrix.py`
from `Scripts/cards/registry/*.gd`, the card database's `is_normal` flag and
`Tests/cards/*.gd`, never by hand.

`RESULT: PASS`, exit code 0.

Separately, `Scripts/tests/SmokeCheck.gd` passes (data load + RNG determinism); it is a
load check, not part of the rules suite count above.

**No suite reports success with zero executed assertions.** `RunTests.gd` treats a
zero-assertion suite as an explicit failure; that guard is load-bearing and must not be
removed.

---

## Suites

| Suite | Assertions | Rules |
|---|---:|---|
| `ChainTests` | 27 | `RULES_SPEC.md §4` |
| `TimingTests` | 37 | `RULES_SPEC.md §3`, `§4.4` |
| `TurnFlowTests` | 40 | `RULES_SPEC.md §1, §2, §13` |
| `SummonTests` | 88 | `RULES_SPEC.md §5`, `§5.4`, `§5.9` |
| `SpellTrapTests` | 49 | `RULES_SPEC.md §4.2` |
| `BattleTests` | 72 | `RULES_SPEC.md §6` |
| `DamageStepTests` | 98 | `RULES_SPEC.md §7`, R42 |
| `ContinuousTests` | 52 | `RULES_SPEC.md §4.2/§8` |
| `CounterTests` | 44 | `RULES_SPEC.md §14` |
| `HiddenInfoTests` | 156 | `RULES_SPEC.md §9, §12, §12.2, §12.3`, R15, R42 |
| `SpecialSummonTests` | 54 | `RULES_SPEC.md §5.5` |
| `RulesQuestionTests` | 37 | `RULES_SPEC.md §8.1, §12.1, §6/§7, §2.3` |
| `ReplayTests` | 33 | master prompt §8 / §70 |
| `EquipTests` | 83 | `RULES_SPEC.md §16, §17` |
| `ControlTests` | 93 | `RULES_SPEC.md §5.6` |
| `MovementTests` | 210 | `RULES_SPEC.md §8, §8.2, §9, §10, §12.1` |
| `BanishTests` | 158 | `RULES_SPEC.md §8, §8.3, §12, §15`, R30 |
| `LifePointCostTests` | 109 | `RULES_SPEC.md §10, §10.4, §4.3, §5.7`, R31 |
| `TrapMonsterTests` | 192 | `RULES_SPEC.md §5.8, §15, §17` |
| `BattlePhaseRestrictionTests` | 53 | `RULES_SPEC.md §2.4, §6`, R32 |
| `AttackRestrictionTests` | 272 | `RULES_SPEC.md §6.1, §6.3, §6.4, §6.5, §4.4, §11`, R41 |
| `ChoiceConstraintTests` | 137 | `RULES_SPEC.md §5.9`, R39 |
| `DeckAccessTests` | 139 | `RULES_SPEC.md §8.4`, R40 |
| `CostLegalityTests` | 56 | `RULES_SPEC.md §10.5`, R42 Part D |
| `ShiningAngelTests` | 43 | per-card |
| `NormalMonsterTests` | 76 | per-card |
| `MonsterRebornTests` | 48 | per-card |
| `SilversCryTests` | 47 | per-card |
| `KaibamanTests` | 47 | per-card |
| `DragonicTacticsTests` | 39 | per-card |
| `OneForOneTests` | 70 | per-card |
| `BirthrightTests` | 59 | per-card |
| `CallOfTheHauntedTests` | 48 | per-card |
| `HieraticDragonOfTefnuitTests` | 67 | per-card |
| `InariFireTests` | 65 | per-card |
| `RanryuTests` | 49 | per-card |
| `NefariousArchfiendTests` | 44 | per-card |
| `GagagashieldTests` | 63 | per-card |
| `RiderOfTheStormWindsTests` | 66 | per-card |
| `CastleOfDragonSoulsTests` | 109 | per-card |
| `FiendishChainTests` | 74 | per-card |
| `FiveBrothersExplosionTests` | 67 | per-card |
| `SealingCeremonyOfSuitonTests` | 73 | per-card |
| `WonderBalloonsTests` | 85 | per-card |
| `ApprenticeMagicianTests` | 92 | per-card |
| `KunaiWithChainTests` | 117 | per-card |
| `FairyTailRellaTests` | 106 | per-card |
| `ChampionsVigilanceTests` | 128 | per-card |
| `AussaTheEarthCharmerTests` | 107 | per-card |
| `EriaTheWaterCharmerTests` | 36 | per-card |
| `WynnTheWindCharmerTests` | 48 | per-card |
| `EnemyControllerTests` | 127 | per-card |
| `CompulsoryEvacuationDeviceTests` | 88 | per-card |
| `KaiserGliderTests` | 93 | per-card |
| `AWingbeatOfGiantDragonTests` | 87 | per-card |
| `PhoenixWingWindBlastTests` | 162 | per-card |
| `SpiritualWindArtMiyabiTests` | 150 | per-card |
| `ChainDetonationTests` | 168 | per-card |
| `ChainHealingTests` | 147 | per-card |
| `CrystalSeerTests` | 151 | per-card |
| `InterdimensionalMatterTransporterTests` | 175 | per-card |
| `JudgeOfTheIceBarrierTests` | 154 | per-card |
| `JunkBladerTests` | 73 | per-card |
| `ThePhantomKnightsOfShadowVeilTests` | 125 | per-card |
| `RunickFlashingFireTests` | 123 | per-card |
| `MirageDragonTests` | 121 | per-card |
| `SwordsOfRevealingLightTests` | 122 | per-card |
| `MaidenWithEyesOfBlueTests` | 139 | per-card |
| `KaiserSeaHorseTests` | 57 | per-card |
| `SoulExchangeTests` | 174 | per-card |
| `SpecialSummonInteractionTests` | 46 | interaction |
| `DragonShrineTests` | 78 | per-card |
| `TheWhiteStoneOfLegendTests` | 78 | per-card |
| `HeraldOfCreationTests` | 73 | per-card |
| `DivineDragonApocralyphTests` | 65 | per-card |
| `TradeInTests` | 70 | per-card |
| `CardsOfConsonanceTests` | 63 | per-card |
| `WhiteElephantsGiftTests` | 64 | per-card |
| `StampingDestructionTests` | 134 | per-card |
| `StraightFlushTests` | 143 | per-card |
| `BurstStreamOfDestructionTests` | 132 | per-card |
| `ChironTheMageTests` | 113 | per-card |
| `BackUpRiderTests` | 115 | per-card |
| `VampiricKoalaTests` | 131 | per-card |
| `SpiritualFireArtKurenaiTests` | 160 | per-card |
| `SpiritualWaterArtAoiTests` | 179 | per-card |
| `DamageCondenserTests` | 156 | per-card |
| `HonestTests` | 125 | per-card |
| `WitchcrafterGolemAruruTests` | 312 | per-card |
| `AHeroEmergesTests` | 197 | per-card |
| **TOTAL** | **9032** | 90 suites |

<!-- summary: core 24 suites / 2289 ; per-card 65 / 6697 ; interaction 1 / 46 ; total 90 / 9032 -->
### BanishTests — 158/158

`Tests/rules/BanishTests.gd`. Rules: `RULES_SPEC.md §8, §8.3, §12, §15` [S1 p.52–53],
`CARD_RULINGS.md R30`. **The banish gate** — written and passing before any batch-8 card
existed, from synthetic cards, so what it proves is that the ENGINE is right.

| Test | Asserts | Rule verified |
|---|---:|---|
| banishing is not destruction and not a send to GY | 7 | `CARD_BANISHED` only; a banished card later moved to the GY is still not "sent" [S1 p.53] |
| cost and effect are two different moments | 8 | `pay_banish_cost()` vs `banish_target()`; only the effect re-checks |
| a cost is all-or-nothing and is not refunded by negation | 5 | an unpayable cost pays nothing; a paid cost stays paid |
| banishing from every source zone | 13 | field / GY / hand / Deck, each recording the zone it came FROM |
| banishing the top N of a Deck | 11 | exact N, from the top, fixed order, rest of the Deck untouched, owner correct |
| top-of-Deck banish with a short Deck | 5 | fewer than N banishes what is there; an empty Deck is not a loss [S1 p.35] |
| top-of-Deck banish is not an excavate, a draw or a mill | 7 | none of those events is emitted; the holding area stays empty |
| a banished card goes to its OWNER's banished zone | 7 | ownership never mutated; the control lease ends |
| face-up and face-down banishment are different | 5 | the two states are kept apart; the pool's default is face-up |
| banishing from the field cleans up every relationship | 14 | Equip Cards destroyed by rule, leases dropped, counters/modifiers/flags cleared, `card_memory` survives |
| a temporary banish registers a lease, a permanent one does not | 12 | the lease records source, duration, destination, position, controller |
| the return happens when the End Phase is entered | 11 | not at a mid-turn timing point; `RETURNED_FROM_BANISHMENT` |
| the return is not a Summon | 10 | no Normal/Special/Flip Summon, no declaration, no flip-face-up, nothing pending to negate |
| the return position is the one it left in | 12 | asserted separately for all three battle positions |
| the card returns under its OWNER's control | 9 | R30(c) — a borrowed monster goes home, ownership untouched |
| nothing comes back when the Monster Zone is full | 7 | stays banished; failure recorded as an event; not retried forever |
| a card moved out of banishment never returns | 6 | the lease is dropped at the moment it leaves the Banished zone |
| a return never happens twice | 7 | a discharged lease cannot fire again however often expiry runs |
| a temporary banish comes back stateless | 8 | fresh instance: equips dead, counters/modifiers/attack record gone |
| the whole cycle is replay deterministic | 4 | two identically seeded runs give the identical event sequence, in a fixed order |

### ChainTests — 27/27
`Tests/rules/ChainTests.gd`. Rules: `RULES_SPEC.md §4` (Rulebook v10 pp.44–47, 51).

| Test | Asserts | Rule verified |
|---|---:|---|
| spell speed response legality | 8 | SS1 may be Chain Link 1; SS1 cannot respond; SS2/SS3 may [S1 p.44] |
| chain link numbering | 4 | activations become Chain Link 1, 2, 3 in order |
| reverse chain resolution | 3 | resolves highest link first; chain cleared [S1 p.46-47] |
| negate activation vs negate effect | 8 | the two negation kinds are distinct (master prompt §18) |
| counter trap response restriction | 3 | only SS3 may respond to SS3 [S1 p.45] |
| chain link number readable at resolution | 1 | needed by Chain Detonation / Chain Healing (R4) |
| unimplemented effect fails loudly | 1 | a missing `resolve()` errors instead of being skipped (§67) |

### TimingTests — 37/37
`Tests/rules/TimingTests.gd`. Rules: `RULES_SPEC.md §3` (official Fast Effect Timing
chart, S2) and `§4.4` [S1 p.51].

| Test | Asserts | Rule verified |
|---|---:|---|
| summon opens a response window | 6 | a Summon does not return to an open game state while a legal response exists (master prompt §23) |
| optional trigger requires consent | 6 | an optional Trigger Effect is offered, and answering "no" does not activate it (§24) |
| mandatory trigger is not asked | 2 | a mandatory trigger fires and is never presented as a choice |
| simultaneous trigger group order | 1 | Chain built TP-mandatory → opp-mandatory → TP-optional → opp-optional [S1 p.51] |
| within-group order is asked | 2 | the owning player chooses the order inside their own group |
| Spell Speed 1 never offered as a response | 2 | a Normal Spell is not a fast effect [S1 p.44] |
| Quick Effect offered in a response window | 4 | a monster Quick Effect is Spell Speed 2 and usable in a window |
| two consecutive passes close the chain | 7 | one pass does not close it; responses alternate [S2 box D] |
| triggers during resolution wait | 2 | a trigger raised mid-resolution becomes a Chain Link only after `CHAIN_RESOLVED` (master prompt §45) |
| summon negation | 6 | a negated Summon never occupies a Monster Zone; the allowance is still spent |

### TurnFlowTests — 40/40
`Tests/rules/TurnFlowTests.gd`. Rules: `RULES_SPEC.md §1, §2, §13`.

Covers 8000 starting LP, the 5-card opening hand, the first player's skipped turn-1 draw,
the turn-1 Battle Phase prohibition, Draw→Standby→Main 1→End ordering, Battle Phase→Main
Phase 2, the Normal Summon allowance resetting each turn, the 6-card hand-size discard at
the end of the End Phase, and losing by deck-out.

### SummonTests — 88/88
`Tests/rules/SummonTests.gd`. Rules: `RULES_SPEC.md §5`.

Covers one Normal Summon **or** Set per turn, Normal Summon in face-up Attack vs Set in
face-down Defense, a Normal Set not being a Summon, Tribute counts by Level (0/1/2), a
Tribute not being a destruction but still being "sent to the GY", a card that counts as
two Tributes for a LIGHT Summon (the `Kaiser Sea Horse` mechanic), a full Monster Zone
blocking a 0-Tribute Summon while still allowing a Tribute Summon, Flip Summon being
illegal the turn a monster was Set and legal later, and the three manual
position-change restrictions.

### SpellTrapTests — 49/49
`Tests/rules/SpellTrapTests.gd`. Rules: `RULES_SPEC.md §4.2` and [S1 p.28–31].

Covers the Trap Set-turn restriction, a Set Normal Spell being activatable the same turn,
the Quick-Play exception to that, which cards a player may activate on the opponent's turn
(Set Quick-Play yes, Set Normal Spell no), a Normal Spell going to the GY after resolving,
a Continuous Spell staying on the field, and a new Field Spell replacing the old one.

### BattleTests — 72/72
`Tests/rules/BattleTests.gd`. Rules: `RULES_SPEC.md §6` [S1 p.37–39, 52].

| Test | Asserts | Rule verified |
|---|---:|---|
| Start Step is a real response window | 8 | the phase does not change until box E closes; the Battle Phase then opens in its Start Step, which is itself a window [S1 p.37; S2 box E] |
| no attacks outside the Battle Step | 4 | attacks are offered in the Battle Step only, not Main 1 or Main 2 |
| which monsters may attack | 7 | face-up Attack Position, turn player's own, on the field; not Defense, not face-down, not the opponent's [S1 p.38] |
| one attack per monster per turn | 5 | the used attacker is withdrawn, others remain, and the allowance returns next turn [S1 p.38] |
| `cannot_attack` restriction honoured | 3 | a continuous restriction removes the attack, and lifts with its source |
| direct attack legality | 6 | rejected while the opponent controls a monster; legal and full-ATK once the field is empty [S1 p.38, p.43] |
| attack target validation | 5 | targets are exactly the opponent's monsters (face-down included); a monster you control is rejected |
| declaration opens a window | 7 | ATTACK_DECLARED / ATTACK_TARGET_SELECTED emitted, opponent gets the window, no Damage Step sub-step entered until it closes |
| attacker leaving cancels the attack | 7 | no damage calculation, no Damage Step, target untouched, nobody "battled" [S1 p.52] |
| **removing the target causes a Replay** | 8 | a removed target is a Replay, not a cancelled attack; the attack is not spent and may be re-declared [S1 p.39] |
| replay with a different monster | 6 | the original monster is still treated as having declared an attack and cannot attack again [S1 p.39] |
| Battle Phase ends into Main Phase 2 | 6 | passes through the End Step, reaches Main Phase 2, leaves no battle state behind [S1 p.37, p.40] |

### DamageStepTests — 98/98
`Tests/rules/DamageStepTests.gd`. Rules: `RULES_SPEC.md §7` [S1 p.41–43, 51–52; S3].

| Test | Asserts | Rule verified |
|---|---:|---|
| sub-steps run in order | 4 | all five sub-steps in the [S3] order; Battle Step handed over and back; no sub-step left set |
| Attack vs Attack Position calculation | 11 | all three rows of §7.4, damage direction and amount, DEF not involved [S1 p.42] |
| Attack vs Defense Position calculation | 11 | all three rows: destroyed with no damage, neither destroyed, attacker's controller takes DEF−ATK [S1 p.42] |
| 0 ATK destroys nothing | 5 | two 0-ATK monsters destroy neither; a real attacker still destroys a 0-ATK monster [S1 p.51] |
| destruction determined before the GY | 6 | destruction decided during damage calculation, card sent only in sub-step 5 — asserted from event order [S3] |
| battle destruction is semantically distinct | 7 | `DESTROYED_BY_BATTLE` reason, `CARD_DESTROYED` **and** `CARD_SENT_TO_GY`, never a Tribute, into the **owner's** GY [S1 p.52–53] |
| face-down target flip timing | 8 | flipped in sub-step 2, Flip effect becomes a Chain Link only in sub-step 4 [S1 p.41] |
| activation restriction (rule) | 7 | `NONE` illegal in all five sub-steps; `UNTIL_DAMAGE_CALC` legal in 1–2 and illegal from 3 on; `MANDATORY_TRIGGER` is about timing, not optionality [S1 p.41] |
| activation restriction (live Damage Step) | 6 | both traps offered before the Damage Step; inside it the `NONE` trap is never offered and the permitted one only up to damage calculation |
| optional battle-destruction trigger declined | 5 | the `Shining Angel` shape is **optional**: its controller is asked exactly once, and "no" activates nothing |
| optional battle-destruction trigger accepted | 8 | becomes a Chain Link in sub-step 5 after the card reached the GY, over candidates filtered by the card's own restriction |
| no trigger without battle destruction | 6 | a real activation sends the same card to the GY by effect; the destroyed-by-battle trigger does not fire and its controller is never asked |
| battle damage to 0 LP ends the Duel | 6 | LP floored at 0, result, end reason, timing machine, no further legal action [S1 p.33] |

### EquipTests — 83/83
`Tests/rules/EquipTests.gd`. Rules: `RULES_SPEC.md §16, §17` [S1 p.29, p.53, p.55].

This suite is the **Equip gate**: before it existed, equip mechanics had **zero** assertions
while `GameState._unequip_all()` quietly ran on every field departure. It is a RULES suite
built from synthetic cards, so what it proves is that the ENGINE is right rather than that one
printed card happens to work. `Gagagashield` and `Rider of the Storm Winds` were only written
once it passed.

| Test | Asserts | Rule verified |
|---|---:|---|
| equipping attaches to one face-up monster | 10 | both sides of the relationship, a real Spell & Trap Zone slot, one `CARD_EQUIPPED` event [S1 p.29] |
| only a legal host can be equipped | 8 | face-down / off-field / itself all rejected; an equipped card "cannot be moved to a different target" [S1 p.53] |
| the granted effect follows the host | 7 | the modifier applies to the host, the printed and **original** ATK are untouched, five recomputes equal one [S1 p.55] |
| **the host leaving the field destroys the Equip Card** | 8 | destroyed with `MoveReason.DESTROYED_BY_RULE`, **not** `DESTROYED_BY_EFFECT`, plus a `CARD_UNEQUIPPED` event [S1 p.29] |
| **the host flipped face-down destroys it** | 5 | the monster never moves, so `move_card()` never sees this — it is handled in `set_battle_position()` [S1 p.29, p.55] |
| the Equip Card leaving takes its effect with it | 6 | the monster survives, with no stale modifier and no stale relationship |
| **battle is recalculated from the equipped ATK** | 7 | a 1000 ATK attacker that would lose beats a 1500 ATK defender once equipped, for 200 damage [S1 p.42] |
| an Equip Spell that resolves without equipping | 8 | no host, so it does not stay on the field, and no `CARD_EQUIPPED` was ever emitted [S1 p.29] |
| a target that became illegal | 8 | still on the field but no longer face-up so it is not equipped to |
| **a counted destruction prevention** | 9 | exactly N destructions per turn are stopped, the N+1th lands, uncovered cards were never protected, and the count returns next turn |
| **a destruction replacement** | 7 | the substitute is destroyed instead — a replacement is not a prevention — and with the substitute gone the next destruction lands |

### ContinuousTests — 52/52
`Tests/rules/ContinuousTests.gd`. Rules: `RULES_SPEC.md §4.2/§8`, master prompt §25.

| Test | Asserts | Rule verified |
|---|---:|---|
| ATK/DEF modifiers apply | 5 | continuous modifiers apply; the printed values and "original ATK" are untouched |
| recompute rebuilds, never accumulates | 4 | five recomputes equal one; exactly one modifier entry; playing on does not inflate it |
| source leaving the field | 4 | the modifier disappears with its source, leaving no stale entry |
| source flipped face-down | 3 | a face-down source applies nothing, and applies again when flipped back up |
| negated source | 3 | a negated source applies nothing, and resumes when the negation ends |
| restriction flags owned by the system | 4 | an unsourced restriction flag does not survive a recompute; unrelated flags are untouched; an unknown flag is rejected loudly |
| multiple simultaneous modifiers | 5 | two sources apply together as separate entries and leave independently |
| counter-scaled modifier | 6 | the `Wonder Balloons` shape follows counters up and down exactly, and ATK floors at 0 |
| `cannot_be_destroyed_by_battle` | 4 | survives damage calculation while battle damage is still inflicted; removing the source restores normal destruction |
| never starts a Chain | 6 | `starts_chain` false, no `resolve()`, never offered as an action, no Chain Link or activation event |
| applies once its source is on the field | 4 | nothing while in the hand; applying after the activation resolved |
| player-level restrictions | 5 | namespaced under `continuous:`, per player, cleared on recompute, unrelated restrictions untouched |

### CounterTests — 44/44
`Tests/rules/CounterTests.gd`. Rules: `RULES_SPEC.md §14`, `Research/CARD_RULINGS.md`.

Generic counter primitives for the two V1 cards that need them (`Apprentice Magician` —
Spell Counter, `Wonder Balloons` — Balloon Counter). Covers placing and reading, counters
tracked per kind and per instance, all-or-nothing removal (removal is used as a **cost**,
so a partial payment must be impossible), counts never going negative, counters only being
placeable on a face-up card on the field, `COUNTER_PLACED` / `COUNTER_REMOVED` carrying
kind/amount/total, a rejected removal emitting nothing, counters cleared when the card
leaves the field and not restored when it returns, and counters on a face-up card being
public to both players.

### HiddenInfoTests — 116/116
`Tests/rules/HiddenInfoTests.gd`. Rules: `RULES_SPEC.md §9, §12` [S1 p.50, p.52].

Every leak test runs from **both** sides. Covers: hand contents private to their owner
while the card's presence is public; face-down field cards hidden by identity but public
by position, with no ATK/Level leak, and public once flipped; Deck contents and order
exposed to nobody (asserted by walking every string in the whole view against the
opponent's Deck); face-up field, both Graveyards, face-up banished cards and LP public to
both; hand/Deck/GY/banished counts and the Normal Summon allowance public; a card legally
revealed to one player visible to that player only, per card; private draw events filtered
out of the public log while a player's own draws stay in their own log; Chain contents
public to both while a Chain is open; and owner reported separately from controller, with
a card whose control changed still going to its **owner's** Graveyard.

---

### SpecialSummonTests — 54/54
`Tests/rules/SpecialSummonTests.gd`. Rules: `RULES_SPEC.md §5.5` [S1 p.24].

This was the last UNVERIFIED path in the rules engine: `SummonRules.begin_special_summon()`
compiled but nothing reached it. 22 of the 77 V1 cards Special Summon something.

| Test | Asserts | Rule verified |
|---|---:|---|
| procedure Summon declares then succeeds | 9 | DECLARED precedes SUCCEEDED; `summoned_by = SPECIAL`; properly Special Summoned; not a Normal Summon |
| declaration window opens first | 6 | the monster waits in `IN_TRANSIT`, controls no zone, and no success event fires until the window closes |
| a negated Special Summon | 5 | `SUMMON_NEGATED` emitted, **no** `SPECIAL_SUMMON_SUCCEEDED`, the card returns to the hand rather than being destroyed |
| the Normal Summon allowance | 5 | a Special Summon does not spend it; a Normal Summon is still legal in the same turn [S1 p.24] |
| a full Monster Zone | 5 | the procedure is not offered, the engine hook returns false, the card does not move, nothing is announced |
| Special Summon from the Deck mid-resolution | 7 | the `Shining Angel` shape: summoned during resolution, left the Deck, in the effect's position |
| Special Summon from the GY mid-resolution | 5 | returns from the GY in the chosen position under its controller |
| position is the player's choice | 6 | both face-up positions offered; a face-down choice the card did not grant is rejected and changes nothing |

### RulesQuestionTests — 37/37
`Tests/rules/RulesQuestionTests.gd`. The four questions Phase 4b recorded rather than
guessed, each now decided against an official source and pinned down.

| Test | Asserts | Rule verified |
|---|---:|---|
| a Continuous Trap waits for its own activation | 8 | the continuous clause does **not** apply while its activation is an unresolved Chain Link, and applies the moment it resolves — `RULES_SPEC.md §8.1` [S1 p.17, p.18 with p.44–47] |
| and keeps applying while face-up | 4 | recomputes do not stack it; it ends with its source |
| shuffled into the Deck | 4 | `revealed_to` is cleared by a shuffle, and by `shuffle_deck()` for every card — `RULES_SPEC.md §12.1` [S1 p.5, p.28] |
| placed on the Deck without a shuffle | 3 | `revealed_to` survives: the position is still known, so the rule is keyed on the shuffle |
| continuous player restriction | 6 | `TurnFlow.can_enter_battle_phase()` now consumes `continuous:cannot_conduct_battle_phase`, the action disappears, and it lifts with its source |
| turn-scoped restriction | 6 | `skip_battle_phase_this_turn` survives a recompute, blocks the Battle Phase, and expires at end of turn — the two restrictions stay independent |
| piercing battle damage | 5 | ATK − DEF is inflicted when a Defense Position monster is destroyed [S1 p.42] |
| no piercing without the flag | 3 | the defender still dies but no damage is inflicted — piercing is never the default |

### ReplayTests — 33/33
`Tests/rules/ReplayTests.gd`. Master prompt §8 / §70.

| Test | Asserts | Property verified |
|---|---:|---|
| the payload records the inputs | 8 | seed, first player, every submitted action with its turn/phase, strictly increasing and collision-free sequence numbers shared with the decision stream |
| the payload carries the Deck contents | 6 | `deck_lists` holds both 40-card Decks in **pre-shuffle** order |
| every decision is recorded | 5 | the log holds exactly as many decisions as the players were asked, including optional-trigger consent |
| **replay reproduces the duel** | 11 | rebuilt from the payload alone, the replayed duel produces an **identical event stream**, LP, hand, board, turn number and Deck order |
| a replayed action is re-validated | 5 | `DuelAction.from_dict()` round-trips, a forged action is rejected, and a rejected action is never logged |

---

## Defects found and fixed by these tests

### This milestone (Phase 5 batch 8, PARTIAL — the banish gate and the first card)

Three defects, in three different categories. **None was a pre-existing engine defect** — the
banish subsystem is new in this batch, so the two engine-side findings are defects in code written
this batch and caught before any card depended on it, which is precisely what the gate is for.

1. **`GameState.banish_temporarily()` dropped its `face_up` argument on the PERMANENT path.**
   Found by `BanishTests :: face-up and face-down banishment are different` on the gate's first
   run, before `Interdimensional Matter Transporter` existed. A caller asking for a **face-down**
   permanent banishment silently got a face-up one — that is, the card would have become public
   information when the rules say it is hidden [S1 p.53, RULES_SPEC.md §12]. The permanent branch
   short-circuits to a plain `move_card()` and simply forgot to pass the position through. Fixed
   by passing it; `face_up` is a statement about the banishment itself and has nothing to do with
   how long it lasts. Nothing in the V1 pool banishes face-down, so this would not have shown up
   in any card suite — it was found only because the gate asserts the distinction generically.

2. **The lease recorded a `return_index` that nothing read.** Found by re-reading the committed
   unit-A code, **not** by a test — recorded honestly as such. This is the same failure shape as
   batch 5's `cannot_be_targeted` and batch 6's `CONTROL_CHANGED`: declared state with zero
   consumers, which later reads as a promise the engine does not keep. It was **removed rather
   than consumed**, and that direction is the load-bearing part: nothing in the rules reserves the
   Monster Zone slot a banished monster left, and another monster may legally be sitting in it by
   the time the card returns, so consuming the index would have encoded a rule that does not
   exist. The card returns to the first free zone, which is deterministic and always available.

3. **A test-harness defect that produced a convincing false pass.**
   `InterdimensionalMatterTransporterTests :: it rescues a monster from a destruction effect` put
   the interfering destruction card on the **non-turn player**, and
   `DuelEngine.get_legal_actions(pid)` returns nothing unless the engine is open *and* `pid` is
   the turn player. The lookup therefore returned `null` every time and the test took a fallback
   branch that asserted a plain banish-and-return — passing, while never building the two-link
   Chain it claimed to test and never proving that Chain Link 2 resolves first. Rewritten with
   player 1 as the turn player so the Chain is real. No engine behaviour and no rules expectation
   was involved. This is the same class of harness trap batch 7 recorded, and the reminder in
   `PROJECT_STATE.md §8` is what identified it.

### Previous milestone (Phase 5 batch 7 units C+D — Deck placement, Chain state, excavation)

**No engine defect was found by units C or D, and none was fixed.** That is a real result rather
than an absence of looking: the movement/excavation gate (unit A) had already been written and had
already flushed out the two live movement defects recorded under units A+B below, so the five
cards written here landed on an API that was correct before they arrived. It is what a gate is
for, and it is the second batch in a row where the gate did its job.

Three things did have to be **added** generically rather than open-coded per card, and each is
recorded as an addition, not a fix:

1. **The movement gate re-checked a target's ZONE but had no way to re-check the FIELD.**
   `EffectPrimitives.surviving_target()` takes ONE zone, which is exactly right for
   `Compulsory Evacuation Device`'s "1 monster on the field". Units C's two Deck-placement cards
   target "1 **card** your opponent controls", which reaches a monster, a Set or face-up
   Spell/Trap and a Field Spell alike — asking the single-zone check with `MONSTER_ZONE` would
   have silently dropped every Spell/Trap target the cards legally chose. Added
   `surviving_field_target()`, and asserted the difference directly in the gate:
   `MovementTests :: a surviving field target spans every field zone` shows the single-zone check
   returning null for the very target the new one accepts.
2. **"Your opponent controls" was not re-checked at all.** Added
   `surviving_opponent_field_target()`, plus generic coverage in both directions including the
   ownership mirror. This is a **ruling**, not a mechanical gap — see `CARD_RULINGS.md` **R29**,
   recorded at MEDIUM confidence with the reasoning and the sources stated honestly.
3. **The Chain Link position had no card-facing reader.** `ChainLink.link_number` already existed
   and was already 1-based authoritative state (it was written for exactly this, R4), but nothing
   read it. Added `EffectPrimitives.activated_chain_link_number()` and
   `return_self_by_chain_link()`, so `Chain Detonation` and `Chain Healing` share the sentence
   pair they print identically instead of duplicating ad-hoc Chain-number bookkeeping.

One **test-harness** defect was found and fixed, and it is worth recording because it produced a
convincing wrong answer rather than an error:

* **`TestFixtures.card_activation()` allows `FIELD_FACE_UP`**, which a real Normal Trap does not.
  A synthetic spacer Trap used to build a deep Chain was therefore offered *again* from its own
  face-up position after it had been activated, so the engine never auto-passed that side, and
  `build_chain_to_depth()` stalled one link short — but only at the depths where the last spacer
  belonged to the same player as the card under test. The result was that Chain Link 2, 3 and 5
  tests passed while Chain Link 4 failed, which looks like a card bug and is not one.
  `TestFixtures.build_chain_to_depth()` now restricts its spacers to `FIELD_FACE_DOWN`.
  No engine behaviour was involved and no rules expectation was changed.

Two test-side additions were made for coverage that could not be written before:
`TestFixtures.effect_negator()` (negating an EFFECT, as distinct from the existing
`activation_negator()`'s negating an ACTIVATION — a card whose cost is paid at activation must
survive both with the cost still spent) and `TestFixtures.build_chain_to_depth()`.

### Previous milestone (Phase 5 batch 7 units A+B — the movement gate and the return-to-hand group)

Three defects. The first two are **pre-existing engine defects** that had been live since the
movement API was written and that nothing before now needed; the third is a defect in a card
written this batch, caught by its own suite on the first run.

1. **`RETURNED_TO_DECK_BOTTOM` did not place the card on the bottom of the Deck.**
   `GameState.move_card()` took the end of the Deck from a `deck_position` option in `opts`,
   defaulting to `"top"`, entirely independently of the `MoveReason`. **No caller anywhere in
   the repository passed that option**, so every "place it on the bottom of the Deck" in the
   engine would silently have placed the card on TOP — an exactly-wrong result that the
   MoveReason claimed not to be. Two of batch 7's remaining cards
   (`Spiritual Wind Art - Miyabi`, `Crystal Seer`) depend on it entirely.
   Fixed by deriving the end from the reason itself (`Enums.deck_position_for()`), so the two
   can never disagree. The option survives only for a `RULE` move that names no end.
   *Guard:* `MovementTests :: top and bottom are exact positions`, which deliberately passes
   **no** `deck_position` and asserts the placement, the untouched order of the rest of the
   Deck, and that the next draw is the card placed on top.
2. **`SHUFFLED_INTO_DECK` never shuffled the Deck.** The reason cleared `revealed_to` — so the
   hidden-information half of the rule was right — but the card was inserted with the default
   `push_front` and the Deck was left in its old order. A card "shuffled into the Deck" sat
   deterministically on top of it, so the very next draw returned it. `RulesQuestionTests`
   did not catch this because it only ever asserted the `revealed_to` half.
   Fixed by performing the shuffle inside `move_card()` for that reason, so a card cannot be
   shuffled in without the shuffle happening.
   *Guard:* `MovementTests :: a shuffle actually shuffles and is deterministic`, which asserts
   the card is not on top, that the rest of the Deck was reordered, and that the same seed
   reproduces the same order — the last of which is what replay depends on.
3. **`Compulsory Evacuation Device` was written at Spell Speed 1.** `EffectDef.of_type()`
   derives Spell Speed from the EFFECT category, which is Spell Speed 1 for everything except a
   Quick Effect, so a Trap's CARD-level Spell Speed [S1 p.44–45] has to be stated explicitly —
   every other Trap in the registry does. Without it the card would never have been offered in
   a response window: a Normal Trap unusable on the opponent's turn.
   *Guard:* `CompulsoryEvacuationDeviceTests :: the clause shape`, which asserts the Spell
   Speed directly rather than inferring it from behaviour.

Generic mechanics completed and tested in unit A — none is left UNVERIFIED:

* **The five movement destinations are five different rules**, not one with a destination
  argument: return to hand · add to hand · top of Deck · bottom of Deck · shuffle into Deck.
  `MovementTests` asserts each one's reason, event and resulting zone, and asserts in both
  directions that none of them is a destruction or a send to the Graveyard.
* **`Enums.MoveReason.ADDED_TO_HAND` + `GameEvent.Kind.CARD_ADDED_TO_HAND`.** "Add to your
  hand" is not "return to the hand": a bounce trigger must not see a search, and vice versa.
* **`GameState.reveal()`** — showing a hidden card without moving it, private to one player
  when only one saw it and public when both did.
* **Excavation** — `Enums.Zone.EXCAVATED`, `GameState.excavate()` / `excavated_cards()`,
  `PlayerState.excavated`. Kept distinct from draw, search, reveal and mill, and asserted so:
  it emits no `CARD_DRAWN`, puts nothing in the hand, and an empty Deck does **not** lose the
  Duel. `Zone.EXCAVATED` is deliberately separate from `Zone.IN_TRANSIT` so that a
  Summon-negation cannot destroy a card sitting in somebody's excavation.
* **The `revealed_to` / shuffle rule now has a real consumer path.** It had been proved
  generically by `RulesQuestionTests` and exercised by no card; `MovementTests` proves it
  through the movement primitives and through a whole-Deck shuffle by a bystander card, and
  batch 7 unit D (`Crystal Seer`) will exercise the "keeps it" branch with a printed card.
* **Card-facing primitives**: `cards_on_field()`, `opponent_field_cards()`, `return_to_hand()`,
  `return_target_to_hand()`, `place_on_deck()`, `place_target_on_deck()`, `shuffle_into_deck()`,
  `add_to_hand()`, `excavate()`, `return_excavated()`, plus `battle_opponent_of()` and
  `destroyed_and_sent_to_gy_condition()` for unit B.

### Previous milestone (Phase 5 batch 6 — Flip Summon negation, and the control-change group)

Cards: `Aussa the Earth Charmer` (107), `Eria the Water Charmer` (36), `Wynn the Wind Charmer`
(48), `Enemy Controller` (127). All four are complete: every official clause implemented, every
clause tested positively and negatively. **Nothing in this batch is partial or unverified.**

The batch was done in three units, each tested and committed before the next began.

**Unit A — the Flip Summon negation gap, closed generically.** This was the KNOWN GAP batch 5
recorded, and it was an ENGINE defect rather than a card one:

1. **A Flip Summon did not declare.** `SummonRules.flip_summon()` applied the flip immediately
   and emitted `FLIP_SUMMON_SUCCEEDED`, so no response window opened and no negation card was
   ever offered one. A Flip Summon **is** a Summon [S1 p.24]. Replaced by
   `begin_flip_summon()` / `_complete_flip_summon()`, the same declaration → response →
   completion shape the other two routes use — but deliberately **not** the same mechanism. The
   monster does not move: it waits face-down in the Monster Zone it already occupies, because
   entering `Zone.IN_TRANSIT` would be a departure from the field, destroying its Equip Cards
   and clearing its per-instance state. Covered by four new `SummonTests` cases and by
   `ChampionsVigilanceTests :: it negates a Flip Summon`.
2. **A consequence that had to be fixed with it:** `EffectPrimitives.summon_is_pending()`
   answered "is a Summon pending?" by scanning `PlayerState.in_transit`, which covers only the
   Normal and Special routes. A Flip Summon that had genuinely been declared read as "no Summon
   is pending". Moved to `GameState.pending_summon_card_id`, written by every `begin_*_summon()`
   and cleared by `complete_summon()` / `abort_summon()`, so all three routes answer uniformly.

**Unit B — the control subsystem, and one more declared-but-unconsumed piece of vocabulary.**

3. **`GameEvent.Kind.CONTROL_CHANGED` had ZERO emitters.** It had been in the event vocabulary
   since the engine was written and nothing ever raised it, so no card could have keyed on a
   change of control and no test could have observed one. This is the same failure shape as
   batch 5's `cannot_be_targeted` — declared, round-tripping, and doing nothing — and it is the
   reason a repository-wide search for readers *and writers* is now part of adding any
   vocabulary. It has real emitters now.

`ControlTests` (93) is the **control gate**, written and passing before any Charmer was
implemented, exactly as `EquipTests` came before `Gagagashield`. What it proves about the engine
rather than about one card:

* a control change is **not** a `move_card()`. The sharpest probe is an Equip Card on the stolen
  monster: an Equip Card dies when its host leaves the field [S1 p.29], so if control change were
  a move it would die. It does not, `on_leave_field()` does not run, and `last_move_*` is not
  rewritten to describe a move that did not happen.
* **owner is never controller.** A borrowed monster destroyed or Tributed under temporary control
  still reaches its OWNER's Graveyard [S1 p.52].
* leases **stack per card** and unwind newest-first. Ending a lease that is not the newest hands
  its `from_controller` down to the next one instead of moving the card, so control still returns
  all the way to where it started rather than stopping at an intermediate controller.
* control cannot be taken with **no free Monster Zone** — a monster is only ever controlled from
  one — and the failed attempt announces nothing and records no lease.

**Unit C — `Enemy Controller`,** whose two bullets are two EffectDefs with different costs,
different effects and different durations, and are never collapsed into one generic control Spell.
Its "until the End Phase" duration is expired by `TurnFlow.enter_phase()` and asserted against
event **sequence numbers**, not merely against the final state, because this engine's End Phase is
two steps and "which step" is the whole question (R25).

**Three test-authoring mistakes worth recording, because each cost a cycle and each will recur.**

* **A bare `count_events()` counts events other cards raised.** Activating a Set Spell/Trap flips
  that card face-up, which is itself a `CARD_FLIPPED_FACE_UP` **and** a
  `BATTLE_POSITION_CHANGED`. Three assertions in this batch were wrong for that reason alone.
  `TestFixtures.count_events_for(engine, kind, card_id)` was added and is the right tool whenever
  the question is about one specific card.
* **The Battle Phase is prohibited on turn 1** [S1 p.35], so `advance_to_phase(BATTLE)` returns
  **false** rather than advancing, and a following `advance_to_phase(MAIN_2)` then walks straight
  into the End Phase — which silently expired an "until the End Phase" lease three phases early
  and made two `EnemyControllerTests` cases fail for a reason that had nothing to do with the
  card. Any test that cares *when* in a turn something happens must build a turn-2 duel, and must
  assert the return value of `advance_to_phase()`.
* **A synthetic FLIP effect must key on ITS OWN flip.** The first draft of
  `TestFixtures.flip_effect_monster()` fired on any `CARD_FLIPPED_FACE_UP` event, which would
  have made every later Flip test quietly wrong. `DamageStepTests._flip_effect_monster()` already
  had the correct shape — check the event's `card_id` against `ctx.source.id` — and the fixture
  now matches it.

**One diagnostic defect fixed.** `CardRegistry._load_one()` reported a registry script that failed
to **compile** as `"declares no CARD_NAME"`, because `get_script_constant_map()` returns an empty
dictionary for a broken script. That sends the reader hunting for a missing constant in a file
whose real problem is a type error elsewhere; it cost a cycle here. The two cases are now
distinguished by a `can_instantiate()` check.

**Generic mechanics added this batch** — each is generic, each has its own tests:

* **The Flip Summon declaration architecture** — `SummonRules.begin_flip_summon()` /
  `_complete_flip_summon()`, `GameEvent.Kind.FLIP_SUMMON_DECLARED`, and
  `GameState.pending_summon_card_id` as the single authoritative answer to "what would be
  Summoned?" across all three routes.
* **Change of control** — `GameState.change_control()` / `can_change_control()` /
  `end_control_lease()` / `drop_control_leases_for()` / `expire_control_leases()`, the
  `control_leases` register, and `Enums.ControlDuration`
  (`WHILE_SOURCE_FACE_UP` / `UNTIL_END_PHASE` / `PERMANENT`). Expiry runs at exactly two named
  points: `DuelEngine._advance()` (the same cadence as the continuous recompute, but a state
  mutation rather than a derived flag, which is why it is not inside `recompute()`), and
  `TurnFlow.enter_phase()` on entering the End Phase.
* **Card-facing control primitives** — `EffectPrimitives.opponent_monsters()`,
  `take_control_of_target()` (which re-checks the target at resolution), and
  `charmer_take_control()` for the three word-identical Charmer clauses.
* **`SummonRules.opposite_face_up_position_of()`** — the battle-position toggle as a static, for
  a card effect that changes a position rather than a player doing it manually.
* **Test-side:** `TestFixtures.flip_effect_monster()`, `summon_negator()`, `count_events_for()`.

### Previous milestone (Phase 5 batch 5 — the counter monster, the second Equip group, negation)

Cards: `Apprentice Magician` (92), `Kunai with Chain` (117), `Fairy Tail - Rella` (106),
`Champion's Vigilance` (114). All four are complete: every official clause implemented, every
clause tested positively and negatively. **Nothing in this batch is partial or unverified.**

**One pre-existing engine defect, and it is a real one.**

1. **A "cannot be targeted" restriction was declared but consumed by NOTHING.**
   `ContinuousEffects.RESTRICTION_FLAGS` has listed `"cannot_be_targeted"` since the continuous
   system was written, and `_clear()` dutifully wiped and rebuilt it on every recompute — but a
   repository-wide search found **zero readers**. Any card that had set it would have been
   silently ignored, and the failure mode is the worst kind: the flag round-trips, the recompute
   tests pass, and the restriction simply does not exist. `Fairy Tail - Rella` is the pool's only
   source of one, so nothing had noticed. Fixed by reading it once in
   `ActivationRules.legal_targets()` — the single funnel that both
   `DuelEngine._activation_actions()` (which publishes candidates) and
   `DuelEngine._choices_valid()` (which re-validates a submitted selection) already pass through,
   so one read covers both the offering and the validation path. Covered by
   `FairyTailRellaTests :: 'NEITHER player' …`, which asserts against a real targeting card
   (`Fiendish Chain`) that the protected monsters vanish from the candidate list and that a
   hand-built activation naming one is rejected.

**Three test-authoring mistakes worth recording, because each cost a cycle and each will recur.**

* **`pass_until_open()` passes for EVERYBODY**, including the opponent you wanted to respond. A
  test that needs a Chain Link 2 in a window the engine opens *itself* (after a Summon completes
  and a trigger becomes Chain Link 1, rather than after a submitted activation) has to loop:
  pass while nobody may act, and submit the response the moment `get_legal_responses()` offers
  it. `ApprenticeMagicianTests` and `ChampionsVigilanceTests` both needed this.
* **Asserting a monster's `position` after a battle reads the Graveyard.** The engine resolves
  the attack declaration window, the Damage Step and the destruction inside one
  `submit_action()`, and `move_card()` turns a card in the Graveyard FACE_UP. An intermediate
  battle position only survives in the EVENT LOG —
  `KunaiWithChainTests._position_changes_to()` exists for exactly that.
* **A negative control against a CONJUNCTION can pass for the wrong reason.**
  `Champion's Vigilance`'s condition is "you control a Level 7+ Normal Monster **AND** a Summon
  is pending". Four negatives calling `condition` directly on a board with no Summon declared all
  returned false — correctly, but for the wrong half — and the positive control then failed and
  exposed the whole group as vacuous. Rewritten to declare a real Summon and ask whether the
  Counter Trap is actually offered, with the underlying card data (Level, Normal-vs-Effect)
  asserted separately so a wrong negative cannot hide.

**Generic mechanics added this batch** — each is generic, each has its own tests:

* **Counter CAPACITY as a rules query** — `GameState.COUNTER_CAPACITY_EFFECT_ID`,
  `can_place_counter()`, `cards_that_can_receive_counter()`, registered in
  `CardRegistry.RULES_QUERY_EFFECT_IDS`. Deliberately not enforced by `place_counters()`; see
  `CARD_RULINGS.md` R21.
* **`cannot_be_targeted` is now consumed** in `ActivationRules.legal_targets()`, plus
  `CardInstance.cannot_be_targeted()` as the single read point.
* **`EffectDef.targets_valid`** — an optional per-clause validation of the SET of chosen targets,
  checked by `DuelEngine._choices_valid()` via `ActivationRules.target_selection_ok()`. Needed
  because `Kunai with Chain` in "both" mode has HETEROGENEOUS targets, where membership in the
  candidate list plus the count is not enough to make a selection legal.
* **`EffectPrimitives.pay_discard_cost()`** — "discard", distinct from `pay_send_to_gy_cost()`'s
  "send from your hand to the GY" [S1 p.52-53].
* **`GameState.destroy()` now accepts a card in `Zone.IN_TRANSIT`**, so "negate the Summon, and
  if you do, destroy that card" goes through the ONE destruction entry point rather than a
  card-specific move. Design decision 19 is preserved, not worked around.
* **Negation primitives** — `summon_is_pending()`, `negate_summon_and_destroy()`,
  `spell_trap_activation_below()`, `negate_activation_and_destroy()`, keeping the Summon path and
  the Chain-Link path separate.
* **Equipping in the other direction** — `equip_card_to_source()`, plus the
  `EQUIPPED_BY_EFFECT_KEY` / `EQUIPPED_BY_EFFECT_TURN_KEY` memory so a delayed "return it during
  the End Phase" clause knows WHICH card and WHICH turn.
* **Test-side:** `TestFixtures.counter_holder()`, `equip_spell()`, `activation_negator()`.

**Two pool facts discovered and reported rather than papered over.** Both are asserted directly
against the real 77-card library so they cannot rot:

* **No card in the V1 pool can have a Spell Counter placed on it**, so `Apprentice Magician`'s
  first clause has no legal target in a real duel between these two Decks. Implemented in full,
  tested against a synthetic card that declares the capacity. R21.
* **The V1 pool contains no Equip Spells at all**, so `Fairy Tail - Rella`'s second clause is
  never live in a real duel. Implemented in full, tested against synthetic Equip Spells. R23.

**One planning error corrected against the official text.** The previous checkpoint's batch plan
said `Fairy Tail - Rella` needs "targeting protection / **redirect**". The verified official text
has no redirect. None was invented. R23.

**One KNOWN GAP, honestly recorded and pinned by a test.** A **Flip Summon is a Summon**
[S1 p.24], but `SummonRules.flip_summon()` applies the flip immediately instead of splitting into
begin/complete like the Normal and Special Summon routes, so no declaration window opens and
`Champion's Vigilance` cannot negate one. This is an ENGINE limitation, not a card one, and it is
the one part of `Champion's Vigilance`'s printed text that is not reachable.
`ChampionsVigilanceTests :: KNOWN GAP` asserts the current behaviour so it cannot be forgotten.
Both Summon routes that DO open a declaration window are negated correctly and tested.

### Previous milestone (Phase 5 batch 4 — the remaining Continuous Traps and the Continuous Spell)

**Three engine defects, all of them pre-existing gaps rather than mistakes made this batch.**
Each was found because a card in this batch is the first card in the pool that needs the
behaviour, and each is now covered by assertions.

1. **A resolving effect could not see what its own cost had paid.** `ChainManager._resolve_link()`
   built the resolution `EffectContext` with the targets and the decider but **never copied
   `ChainLink.cost_payload`**, so `ctx.cost_payload` was always empty at resolution. Every card
   implemented before this batch happened to have a cost whose size was fixed by the card, so
   nothing had noticed. `Wonder Balloons` is the first card whose EFFECT is measured by its own
   COST — "place 1 Balloon Counter on this card **for each card sent to the GY**" — and
   recounting from the Graveyard is not an option, because the sent cards are indistinguishable
   from everything else already there. Fixed by carrying the payload forward in `_resolve_link()`.
   Covered by `WonderBalloonsTests :: "any number" is the player's choice`, which sends three of
   four cards and asserts exactly three counters.

2. **"You can only control 1" was never checked on any route a SPELL/TRAP takes onto the field.**
   `SummonRules.control_limit_satisfied()` existed and was consumed by `can_normal_summon_or_set`,
   `begin_special_summon` and `can_use_summon_procedure` — all three of them **monster** routes.
   `Castle of Dragon Souls` is the pool's only Spell/Trap carrying the restriction, so its limit
   was silently unenforced: a second copy could be activated freely. Fixed in
   `ActivationRules.can_activate()`, which now asks the same question for a non-monster card
   activation. Setting a second copy stays legal and the limit is re-tested when it is activated
   — see `Research/CARD_RULINGS.md` R19 for why that is the right reading and not a shortcut.
   Covered by `CastleOfDragonSoulsTests :: the control limit on a TRAP`.

3. **A continuously-applied negation had no system-owned channel, and applying one would have
   depended on board iteration order.** `CardInstance.effects_negated` is a plain flag cleared
   only when a card leaves the field or is flipped face-down; `ContinuousEffects` neither wrote
   nor cleared it. Had `Fiendish Chain` set it directly, the negation would have outlived its
   own source — the exact bug the continuous system exists to make impossible. Worse, because
   `_continuous_sources()` skips negated cards, a single-pass recompute would have given a
   *different answer depending on which card was walked first*: a monster processed before
   Fiendish Chain would apply its own continuous effect for that recompute, and one processed
   after it would not. Fixed with three pieces that belong together:
   `ContinuousEffects.NEGATION_FLAG` (listed in `RESTRICTION_FLAGS`, so it is wiped and rebuilt
   like everything else the system owns) written only via `negate_effects()`;
   `CardInstance.effects_are_negated()` as the single read point, which every rules-layer caller
   now uses; and a **two-pass** `recompute()` driven by the declarative `EffectDef.negates_effects`
   marker, so negating clauses run before anything asks whether a source is negated. Covered by
   `FiendishChainTests :: it negates a CONTINUOUS effect`, which uses a monster whose only effect
   is continuous and additionally asserts that five recomputes equal one.

No pre-existing **rules** defect was found beyond these three, and that is reported as-is. All
1560 assertions from the previous milestone still pass unchanged; none was weakened, retargeted
or deleted.

Two test-authoring mistakes cost a cycle and are worth recording:

* `GameState.destroy()` correctly refuses a card that is **not on the field**, so
  `TestFixtures.interferer(..., "destroy")` cannot move a card out of the HAND. A clause keyed on
  "this face-up card **on the field** is sent to the GY" needs a card reaching the Graveyard from
  somewhere else to be tested negatively; a `"send_to_gy"` mode was added for exactly that.
* Continuous effects are recomputed by the engine at every timing point, so a board arranged
  **directly** through `TestFixtures.give_*` has not had one yet. A baseline assertion about a
  continuous effect taken before any engine action reads the un-recomputed value and fails
  confusingly.

### Previous milestone (Phase 5 batch 3 — Continuous-Trap revival, summoning procedures, Equip)

Three defects, two of them in engine code written during this batch and caught before the
cards that depend on it were written, one a genuine gap in the pre-existing engine.

1. **`GameState.move_card()` captured "was this card face-up?" AFTER the move had already
   rewritten the position.** The new `last_move_was_face_up` record (RULES_SPEC.md §15.1) was
   read after `_attach()` and the position-handling block, and those overwrite
   `card.position`: a card sent to the Graveyard is turned FACE_UP by the move itself, and one
   returned to the hand is turned FACE_DOWN. So the flag answered a question about the
   DESTINATION rather than about where the card came from — it would have read `true` for every
   card sent to the GY, including one destroyed while face-down, and `false` for a face-up card
   bounced to the hand. `Inari Fire`'s "after this **face-up card on the field** was destroyed
   by card effect" depends entirely on it. Fixed by capturing `was_face_up` at the top of
   `move_card()` alongside `was_on_field`, before `_detach()`. Covered by
   `InariFireTests :: the Standby revival`.
2. **`CARD_DESTROYED` was not emitted for a rules destruction.** `Enums.MoveReason` gained
   `DESTROYED_BY_RULE` this batch (an Equip Card losing its host is destroyed by the game rules,
   not by a card effect [S1 p.29, p.55]), and `Enums.is_destruction()` was updated — but the
   `match reason:` block in `move_card()` that emits the semantic event was not, so an Equip
   Card was silently sent to the Graveyard with no `CARD_DESTROYED` event at all. Any future
   "when a card is destroyed" trigger would have missed it. Caught by
   `EquipTests :: the host leaving the field destroys the Equip Card` on its first run.
3. **`DuelEngine._cleanup_resolved_spell_traps()` decided what stays on the field from the card
   KIND alone.** That is wrong in both directions once Equip Cards exist: a NORMAL Trap that
   equipped (`Gagagashield`) must stay, and an Equip Spell that resolved without equipping must
   not. The equip relationship now takes precedence over `Enums.stays_on_field()`. Covered by
   `GagagashieldTests :: a Normal Trap that stays on the field` and
   `EquipTests :: an Equip Spell that resolves without equipping`.

**No pre-existing rules defect was found by the 544 new assertions beyond item 3**, and that is
reported as-is. All 1016 assertions from the previous milestone still pass unchanged; none was
weakened, retargeted or deleted.

Two test-authoring mistakes are worth recording because they cost a cycle and will recur:

* A test that mutates the board by calling `GameState.move_card()` / `destroy()` directly does
  **not** reach a trigger check — those events never enter `_pending_events`. A trigger effect
  can only be observed if the change travels through the timing machine, i.e. through a real
  card effect resolving. `TestFixtures.interferer()` exists for exactly this.
* The engine resolves a whole Chain inside one `submit_action()` when nobody holds a legal
  response, so a test that needs to change the board BETWEEN an activation and its resolution
  must give the opponent a real Spell Speed 2 effect. Two `EquipTests` cases were written
  without one and silently tested nothing until they failed.

### Previous milestone (Phase 5 batch 1+2)

**No rules-engine defect was found by this batch, and that is reported as-is rather than
dressed up.** Every one of the 343 new assertions passed against the engine as Gate B
left it, which is the outcome Gate B was supposed to produce. Three real problems were
found and fixed, none of them in the rules:

1. **`Tools/build_matrix.py` could never report a vanilla Normal Monster as implemented.**
   It derived implementation status purely from the presence of a registry file, but a
   card with no effect text correctly has no registry file — `CardDef.is_vanilla()` and
   `CardRegistry.unimplemented()` already treated an empty effect list as the complete
   implementation, so the matrix and the engine disagreed. The matrix now counts a card
   as implemented when it has a registry file **or** when the card database marks it
   `is_normal`, and `NormalMonsterTests` asserts the shortcut cannot be abused: no Effect
   Monster satisfies `is_vanilla()`, and every non-vanilla card without effects is still
   on the honest unimplemented list.
2. **A suite could not report covering more than one card.** `tested_cards()` read only
   the singular `CARD_UNDER_TEST`, so a mechanic-group suite could not mark its cards
   TESTED without nine near-identical files. It now also reads a `CARDS_UNDER_TEST`
   array. An interaction suite declares neither marker, so a card is still only ever
   counted as TESTED because it has its own suite.
3. **The per-test assertion counts in this file were estimates, and at least one was
   wrong.** The published `ShiningAngelTests` breakdown summed to 45 against a suite that
   runs 43. `TestCase` now records assertions per test and
   `Scripts/tests/DumpAssertionCounts.gd` prints them, so every per-test number in this
   file is measured. The `ShiningAngelTests` table has been corrected.

One test was also strengthened after measurement showed it was thin:
`DragonicTacticsTests :: a Level 7 Wyrm does not qualify` ran a single assertion, so a
positive control was added — adding a Level 8 Dragon to the same Deck makes the card
activatable — which turns the negative from "something blocked it" into "the filter
blocked it".

### Earlier milestone (Phase 4c — the generic-engine gate)

1. **`SummonRules.begin_special_summon()` was unreachable from the engine.** It existed and
   compiled, but no engine path called it, so "Special Summon" was not a capability the
   engine actually had. Two paths were added and tested: `DuelEngine.special_summon()` for
   the resolution-time case (the `Shining Angel` family) and the
   `SPECIAL_SUMMON_PROCEDURE` action for the open-game-state case (`Hieratic Dragon of
   Tefnuit`, `Inari Fire`, `Ranryu`, `Nefarious Archfiend`), the latter opening a real
   declaration window so a Summon negation can answer it.
2. **The replay payload could not reproduce a duel.** It carried the Deck *names* but not
   the Deck *contents*, and the seed only determines how a **known** Deck is shuffled.
   `deck_lists` (pre-shuffle order) was added.
3. **Most player decisions were never recorded.** Only `DuelEngine`'s target selection went
   into the log; optional-trigger consent, trigger ordering, the End Phase hand-size
   discard and every mid-resolution `EffectContext.ask()` were lost, so any duel
   containing one of them was unreplayable. `TriggerCollector`, `TurnFlow` and
   `EffectContext` now record through the same log.
4. **A Continuous Spell/Trap applied its continuous effect one step too early.** It applied
   as soon as the card was face-up, i.e. from activation, which would let it affect the
   resolution of Chain Links above it. It now waits for its own activation to resolve.
5. **Player-level continuous restrictions were consumed by nothing.** `restrict_player()`
   round-tripped but `TurnFlow.can_enter_battle_phase()` only read the separate
   un-namespaced key. It now honours both, and the two are documented as having
   deliberately different lifetimes.
6. **Piercing was wrongly believed to be unexercised by the V1 pool.** `Rider of the Storm
   Winds` grants it ("If a monster equipped with this card attacks a Defense Position
   monster, inflict piercing battle damage"), so the branch is required and is now tested
   in both directions.

No test expectation was weakened to make the implementation pass, and none of the 506
earlier assertions was retargeted or deleted.

### Earlier milestone (Phase 4b-3)

1. **Removing the attack TARGET cancelled the attack instead of causing a Replay.**
   `DuelEngine._advance_battle()` called `BattleRules.attack_still_valid()` — which
   checked the attacker *and* the target — before `replay_required()`, so a destroyed
   target silently swallowed the Replay. `RULES_SPEC.md §6.2` [S1 p.39] is explicit that a
   removed target **is** a Replay. Fixed by splitting the check into
   `attacker_still_valid()` / `target_still_valid()` and running the Replay check first.
   Caught by `BattleTests :: removing the attack target causes a Replay`.
2. **`get_visible_state()` ignored `revealed_to` for cards in the opponent's hand.**
   `CardInstance.revealed_to` is documented as the record of who has legally seen a hidden
   card, and `_visible_card()` honours it — but the opponent's hand was mapped straight to
   `_hidden_card_stub()`, bypassing it. A card revealed to a player stayed invisible to
   them. Fixed by routing the opponent's hand through `_visible_card()`, which still
   returns a stub in every other case. Caught by
   `HiddenInfoTests :: a card revealed to a player stays visible to that player only`.
3. **Two test-harness gaps that would have silently weakened later tests.**
   `TestFixtures.end_turn()` and `advance_to_phase()` both looked for `END_PHASE`, which
   the Battle Phase does not offer (it offers `END_BATTLE_PHASE`), so any duel that
   reached the Battle Phase could not be advanced and the helper returned `false`
   unnoticed. Both now fall back correctly.

No test expectation was weakened to make the implementation pass.

### Earlier milestones

1. **`RunTests.gd` reported PASS for a suite that ran zero assertions.** When `TimingTests`
   failed to compile, the runner printed `TimingTests: 0/0 passed` and still exited 0.
   Fixed: a suite with zero assertions is now an explicit failure. This remains the most
   important guard in the harness — without it a green run proves nothing.
2. **Repeated `:=` type-inference compile failures.** GDScript cannot infer through a
   `Variant` (an untyped `Array` element, or a function declared `-> Variant`). This bit
   again this milestone in `BattleTests`, `DamageStepTests` and `HiddenInfoTests`.
   Annotate explicitly.
3. **`project.godot` pointed `run/main_scene` at `res://Scenes/ui/Boot.tscn`, which does
   not exist yet**, so every headless run logged a resource load error. Unset until the
   Phase 7 UI exists.

## Known issues in the harness (not rules defects)

* **The ObjectDB figure is CHARACTERISED as of batch 15 (2026-09-09), and the "per assertion"
  ratio every entry below quotes is now known to have been measuring the wrong quantity.** A
  direct probe measured **188 leaked objects per duel CONSTRUCTED** (exactly linear over 0 / 50 /
  100 / 200 duels, intercept 17), **~6 more per turn played**, and **zero** for any number of
  `CardRegistry.load_library()` calls. The count tracks how many duels a run builds — roughly one
  duel's entire object graph, retained by a reference cycle at the `DuelEngine` / `GameState`
  root — and has no relationship to assertion counts, which is why eight checkpoints produced
  four falls and four rises with no trend. The full table and reasoning are in the batch-15
  ObjectDB note above. **The entries below are kept verbatim for the record; their
  per-assertion arithmetic is correct but meaningless, and their repeated "no explanation has
  been measured" is now superseded.** What remains is a FIX — break the cycle — and it is still
  required before Phase 7.

* **Superseded by the characterisation above: `154223 ObjectDB instances were leaked at exit`** (2026-08-14, at
  **5280** assertions across 62 suites), up from 135266. That is **18957 more for 493 more
  assertions, ~38.5 per assertion**, against the previous checkpoint's ~36.2. This is the
  **fourth consecutive rising checkpoint** and again the highest per-assertion figure recorded.
  Reported as measured; **no explanation is offered, because none has been measured.** The
  plausible reading is still that the four new suites build many small duels — `TrapMonsterTests`
  and `RunickFlashingFireTests` each construct a fresh duel per test, and two of them loop over
  four to six departure routes building one duel apiece — rather than that the new
  `monster_identity` dictionary or `battle_phase_skips` array retains anything; both are plain
  data cleared on the paths that own them. **That remains inference, not measurement**, and
  confirming it belongs to the characterisation task below, which is now **more** warranted than
  it was. It causes no test failure, hang, memory pressure or unreliability, so per the batch
  rules it was correctly not allowed to derail the card work. **It must be characterised or fixed
  before Phase 7.**

* **Superseded, kept for the trend: `135266 ObjectDB instances were leaked at exit`** (2026-08-14, at
  4787 assertions across 58 suites), up from 123104. That is **12162 more for 336 more
  assertions, ~36.2 per assertion** — a further rise, and at the time **the highest per-assertion
  figure recorded so far**. Reported as measured rather than explained away. The plausible
  reading is unchanged and unchanged in status: the three new suites build many small duels
  (`LifePointCostTests` alone constructs a fresh duel per test and runs one scenario twice for
  determinism, and `JudgeOfTheIceBarrierTests` builds one per clause case), rather than the new
  cost payload or the event-response queue retaining anything — the queue is drained
  synchronously and is empty at the end of every dispatch. **That remains inference, not
  measurement.** No test fails, hangs, or becomes unreliable, so per the batch rules it was
  correctly not allowed to derail the card work — but the trend is now three checkpoints of
  rising per-assertion cost, and the characterisation task below is **more** warranted than it
  was, not less. It must be done before Phase 7.

* **Superseded, kept for the trend: `123104 ObjectDB instances were leaked at exit`** (2026-08-13, at
  4451 assertions across 55 suites), up from 113897 at the batch-7 checkpoint. That is **9207
  more for 333 more assertions, ~27.6 per assertion**, against batch 7's ~20.6, units A+B's ~25.7
  and batch 6's ~25.0. It is the **highest per-assertion figure recorded so far**, modestly above
  the previous high, so it is reported as such rather than as "in band". The most likely reading
  is that `BanishTests` and the `Interdimensional Matter Transporter` suite build comparatively
  many small duels — several of their tests loop over positions or run a scenario twice for
  determinism — rather than that the `banish_leases` register retains anything: the register holds
  plain Dictionaries keyed by card id, is emptied when a lease discharges, and holds nothing at all
  at the end of any test that runs to an End Phase. **That reading is inference, not measurement**,
  and the characterisation task below is what would confirm it. No test fails, hangs, or becomes
  unreliable, no rules outcome changes, and there is no memory pressure, so it was correctly not
  allowed to derail batch 8. It **remains scheduled before Phase 7**, and the next session should
  treat "confirm the banish register is not a new retention class" as part of that task. The
  batch-7 note below is kept for the trend.
* The run reported **`113897 ObjectDB instances were leaked at exit`** at batch 7, up from 97559 at the
  units-A+B checkpoint, 85668 at batch 6, 74049 at batch 5 and 61457 at batch 4 — purely because
  the suite now builds more duels (794 more assertions across five new suites). The growth stays
  proportional to the number of duels built, not to anything units C or D introduced: **~16.3k
  more for 794 more assertions is ~20.6 per assertion, against units A+B's ~25.7 and batch 6's
  ~25.0** — the ratio did not worsen, it improved slightly, which is consistent with these suites
  building somewhat larger duels rather than more of them. No test fails, hangs, or becomes
  unreliable because of it, no rules outcome changes, and there is no memory pressure, so it was
  correctly not allowed to derail batch 7 — but it **must be characterised or fixed before Phase
  7**, when the UI keeps a single duel alive for a long session. Measured again this milestone so
  the trend stays visible. These are RefCounted
  reference cycles between `GameState`, `DuelLog` (connected signal) and the closures the
  tests capture. The count grows with the number of duels the suite builds. It does not
  affect any rules outcome and does not fail the suite, but it must be cleaned up before
  the UI keeps a duel alive for a long session.
* The run prints two `SCRIPT ERROR` lines from `push_error`. Both are **intentional** and
  are what the corresponding assertions require:
  `ChainTests` proves a missing `resolve()` fails loudly, and `ContinuousTests` proves an
  unknown restriction flag is rejected rather than silently written.
* A GDScript single-line lambda ends at the newline. A wrapped lambda body inside a call
  needs an explicit `\` continuation or it is a parse error with no line number.

---

## Not yet covered (required by master prompt §64 — tracked, not claimed)

**A. Core rules** — still missing: **simultaneous-LP-zero draws**. Batch 8 did not make it
reachable either: nothing in the banish group changes Life Points at all, so no card added this
batch can take two players to 0 at once. The gap is preserved unchanged.

**A2. New this batch, and deliberately left open — a card banished by an effect activated DURING
the End Phase does not return until the NEXT turn's End Phase.** Expiry runs as the phase is
entered, so an activation later in the same phase has already missed it.
`Interdimensional Matter Transporter` is a Normal Trap and *can* be activated in the End Phase,
so this is reachable, and the real-world answer is probably that it should return during that
same End Phase. It is left as it is on purpose and is **not** an oversight: `Enemy Controller`'s
"until the End Phase" control lease has exactly the same behaviour for exactly the same reason,
R25 fixed that moment deliberately, and making banishment differ from control would break the one
invariant the whole lease design rests on. **Changing it must change both together and must
revisit R25** — it is not a banish-only fix. Recorded as `CARD_RULINGS.md` **R30(e)**. No test
asserts the current behaviour, because pinning behaviour that is probably wrong would make the
correction harder rather than easier.

**A3. Batch 8 was PARTIAL when this paragraph was written; it is now COMPLETE.** All four of the
cards it named — `Judge of the Ice Barrier`, `Junk Blader`, `The Phantom Knights of Shadow Veil`
and `Runick Flashing Fire` — are implemented and tested, and the matrix counts them. The
paragraph is corrected rather than deleted so the record of what was open when still reads
straight.

**A4. Batch 9 adds nothing to the uncovered list, and the simultaneous-LP-zero gap survives it
too.** Neither `Soul Exchange` nor the material-choice constraint touches Life Points at all, so
no card in this batch can take two players to 0 at once. Two things about the constraint are
deliberately scoped rather than missing: it covers the Tribute Summon/Set and Tribute-**cost**
routes because those are the only Tribute channels the implemented pool has — an effect that
Tributes during resolution would need the same call and does not exist yet; and no **immunity**
subsystem was invented for it, because no card in the pool has immunity (recorded in **R39**).

Units C and D did not make the simultaneous-LP-zero case reachable: `Chain Detonation` damages only the
opponent and `Chain Healing` only gains LP, so neither can take two players to 0 at once. Both are
asserted from that side rather than assumed — `ChainDetonationTests :: it can end the duel` proves
the burn ends the Duel with a single winner and not a draw, and
`ChainHealingTests :: it cannot end the duel` runs with both players on 100 LP and proves nothing
ends. The gap is therefore preserved as a known future item, deliberately and with evidence.

Card movement, Deck placement (top / bottom / shuffle), revealing and excavation were on this list
and are now covered end to end by `MovementTests` (210 assertions) **and, since units C and D, by
printed cards**: `Phoenix Wing Wind Blast` (top), `Spiritual Wind Art - Miyabi` (bottom),
`Chain Detonation` / `Chain Healing` (the only two cards in the pool that shuffle into the Deck,
and therefore the printed-card exercise of the `revealed_to`-cleared branch) and `Crystal Seer`
(excavate, and the printed-card exercise of the `revealed_to`-KEPT branch). Effect damage (as
opposed to battle damage), banishing as a COST, continuous negation of another card's effects,
and a turn-scoped ATK modifier that outlives its source were on this list and are now covered by
batch 4. Equip mechanics were on this list
and are now covered end to end by `EquipTests` (83 assertions), together with
destruction prevention and destruction replacement. GY-activated effects were on it too and
are now exercised by `Inari Fire`, `Ranryu` and `Nefarious Archfiend Eater of
Nefariousness`. Special Summon execution, piercing battle damage and the duel log / replay
payload were covered in the previous milestone.

**B. Per-card** — **44 of 77** cards implemented and tested; **33 remain**, honestly reported as
`NOT_IMPLEMENTED` / `NOT_TESTED` in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`. Batch 7 added
`Compulsory Evacuation Device`, `Kaiser Glider`, `A Wingbeat of Giant Dragon` (unit B),
`Phoenix Wing Wind Blast`, `Spiritual Wind Art - Miyabi`, `Chain Detonation`, `Chain Healing`
(unit C) and `Crystal Seer` (unit D), which completes the pool's **movement group** — every card
in the V1 pool that returns a card to the hand, places one on the Deck, shuffles one in, or
excavates is now implemented and tested.

The paragraph below describes the state at the end of batch 6 and is kept for the record.

**B (batch 6 snapshot)** — **36 of 77** cards implemented and tested; **41 remained**. Batch 6
added `Aussa the Earth Charmer`, `Eria the Water Charmer`, `Wynn the Wind Charmer` and
`Enemy Controller`, which completes the pool's **control-change group**.

The paragraph below describes the state at the end of batch 5 and is kept for the record.

**B (batch 5 snapshot)** — **32 of 77** cards implemented and tested; **45 remained**. Batch 5
added `Apprentice Magician`, `Kunai with Chain`, `Fairy Tail - Rella` and `Champion's Vigilance`,
which completes the pool's **Equip group** (all four equippers) and its **only Counter Trap**.

The paragraph below describes the state at the end of batch 4 and is kept for the record.

**B (batch 4 snapshot)** — **28 of 77** cards implemented and tested: the 9 vanilla Normal
Monsters, `Shining Angel`, the first Special Summon batch (`Monster Reborn`, `Silver's Cry`,
`Kaibaman`, `Dragonic Tactics`, `One for One`), batch 3 (`Birthright`, `Call of the Haunted`,
`Hieratic Dragon of Tefnuit`, `Inari Fire`, `Ranryu`, `Nefarious Archfiend Eater of
Nefariousness`, `Gagagashield`, `Rider of the Storm Winds`) and batch 4 (`Castle of Dragon
Souls`, `Fiendish Chain`, `Five Brothers Explosion`, `Sealing Ceremony of Suiton`,
`Wonder Balloons`). The other **49** are honestly reported as `NOT_IMPLEMENTED` /
`NOT_TESTED` in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`.

With batch 4 the pool's **Continuous Spell/Trap group is complete**: all 6 Continuous Traps and
the single Continuous Spell are implemented and tested.

### ShiningAngelTests — 43/43
`Tests/cards/ShiningAngelTests.gd`. The first per-card suite, and the shape every later
one follows: the clause is exercised **positively and negatively**, and the negatives are
where the value is.

| Test | Asserts | What it proves |
|---|---:|---|
| the registry loads cleanly | 5 | all 77 definitions load, the registry reports no errors, one `EffectDef` per official clause, and the card name is stamped onto the effect |
| the clause shape | 9 | optional Trigger Effect, Spell Speed 1, Damage Step window as a *timing* permission, activates from the GY, and **does not target** — the official text has no "target", so the monster is chosen at resolution |
| destroyed by battle | 11 | a LIGHT monster with ≤1500 ATK arrives from the Deck in Attack Position by Special Summon; the controller is asked exactly once; **every candidate offered passes the clause's own filter** while the too-strong LIGHT copies in the same Deck are excluded |
| declining | 5 | asked, said no, nothing Summoned, Deck untouched |
| destroyed by a card effect | 3 | not destroyed *by battle*, so nobody is asked [S1 p.52–53] |
| Tributed | 3 | a Tribute **is** "sent to the GY" and the trigger event does fire, but the clause still does not — destruction by battle is what it requires |
| no legal monster in the Deck | 3 | the controller is not asked a question with no possible answer |
| a full Monster Zone | 4 | the zone the Angel itself vacated is available, so the recruit legitimately fills it |

### NormalMonsterTests — 76/76
`Tests/cards/NormalMonsterTests.gd`. Covers all nine vanilla Normal Monsters at once via
`CARDS_UNDER_TEST`, because their implementation is shared: an EMPTY effect list is the
correct and complete implementation of a card with no effect text.

| Test | Asserts | What it proves |
|---|---:|---|
| all nine are vanilla | 38 | exactly nine cards in the pool satisfy `is_vanilla()`, and each is a Normal Monster with zero `EffectDef`s |
| Tribute requirement follows Level | 9 | 0 / 1 / 2 Tributes by printed Level, on the real cards [S1 p.24-25] |
| Normal Summon a real vanilla | 9 | Sabersaurus reaches a Monster Zone face-up in Attack Position with its printed 1900/500, spending the turn's one Normal Summon |
| Tribute Summon a real vanilla | 8 | Blue-Eyes White Dragon needs two Tributes, both reach the Graveyard, and only the Summoned monster remains |
| a vanilla battles on printed stats | 4 | Alexandrite Dragon 2000 beats Sabersaurus 1900; 100 battle damage [S1 p.42] |
| offers no effect to activate | 4 | no `ACTIVATE_EFFECT` / `ACTIVATE_CARD` / summon procedure is offered, and a hand-built activation is rejected |
| **no Effect Monster is treated as vanilla** | 4 | `is_vanilla()` is false for every Effect Monster; every non-vanilla card with no effects is still on `CardRegistry.unimplemented()`; the two categories never overlap, and that list is genuinely non-empty |

The last test is the load-bearing one: it is what stops "vanilla counts as implemented"
from becoming a way to over-report an unimplemented Effect Monster.

### MonsterRebornTests — 48/48
`Tests/cards/MonsterRebornTests.gd`. "Target 1 monster in either GY; Special Summon it."

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 9 | Spell Speed 1 card activation, targets exactly 1, activatable from hand or a Set copy, no invented once-per-turn |
| revives from your own GY | 8 | the target leaves the GY, is properly Special Summoned, the Spell goes to the GY, and the Normal Summon is untouched |
| the player chooses the position | 4 | face-up Defense is honoured; face-down is never offered (RULES_SPEC.md 5.5) |
| revives from the OPPONENT's GY | 9 | you control it, the OWNER is unchanged, and it returns to the **owner's** Graveyard when it later leaves the field [S1 p.52] |
| a Trap in the GY is not a target | 5 | only monsters are candidates; a hand-built activation targeting a Trap is rejected |
| empty Graveyard | 4 | an effect that targets with no legal target cannot be activated (master prompt 17) |
| a full Monster Zone | 2 | not offered — unlike Kaibaman, nothing here frees a zone |
| **a target that left the GY** | 7 | a Chain Link 2 that banishes the target resolves first, and Monster Reborn then Summons nothing while still resolving to the GY (master prompt 44) |

### SilversCryTests — 47/47
`Tests/cards/SilversCryTests.gd`. Quick-Play, targeting, hard once-per-turn.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | Spell Speed 2, a real fast effect, targets 1, hard OPT on the NAME rather than the copy |
| revives a Dragon Normal Monster | 6 | the target arrives at full printed ATK; the Quick-Play does not stay on the field [S1 p.29] |
| the target filter | 7 | "Dragon Normal Monster" is both halves: a Dragon **Effect** Monster, a Normal **Wyrm** and a Normal Dinosaur are all rejected, on the real cards |
| only your own Graveyard | 4 | a legal-looking Dragon in the opponent's GY does not enable it |
| hard once-per-turn | 7 | a SECOND COPY is blocked in the same turn, the restriction is recorded against the card name, and it expires by that player's next turn |
| cannot be activated the turn it was Set | 5 | the Quick-Play exception to the "Spells may be activated the turn they are Set" rule [S1 p.31] |
| a Set copy on the opponent's turn | 7 | offered in a response window during the opponent's turn and resolves there |

### KaibamanTests — 47/47
`Tests/cards/KaibamanTests.gd`. The cost/effect split lives or dies here.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | a non-targeting Ignition Effect, Spell Speed 1, never a fast effect, field face-up only, Main Phases only, with a real `pay_cost` |
| Tributes itself and Summons | 10 | `CARD_TRIBUTED` and no `CARD_DESTROYED` — a Tribute is not a destruction [S1 p.53]; Blue-Eyes fills the zone Kaibaman vacated |
| **the cost survives negation** | 10 | the Tribute is already paid before any response window opens, and stays paid when Chain Link 2 negates the effect — the single most important cost assertion in the library |
| no Blue-Eyes in hand | 4 | not offered, a hand-built activation is rejected and pays nothing, and a copy in the GY does not count |
| only Blue-Eyes qualifies | 5 | other Level 8 LIGHT Dragons in hand do not satisfy a clause that names one card |
| from the hand or face-down | 3 | usable only from a face-up field position, and turning the same copy face-up enables it |
| outside the Main Phases | 4 | absent in the Battle Phase, present again in Main Phase 2 [S1 p.10] |

### DragonicTacticsTests — 39/39
`Tests/cards/DragonicTacticsTests.gd`. The first two-card cost and the first Deck Summon.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 8 | non-targeting Normal Spell activation with both a cost check and a cost payment |
| two Dragons for a Level 8 Dragon | 11 | both Tributes happen at activation, the Deck loses exactly one card, two `CARD_TRIBUTED` and zero `CARD_DESTROYED` |
| the Tribute candidates | 10 | the three Dragons you control are offered; the Dinosaur, the **Wyrm** and the opponent's Dragon are not |
| only one Dragon | 4 | an unpayable cost blocks the activation, a hand-built one is rejected, nothing is Tributed, and a second Dragon fixes it |
| no Level 8 Dragon in the Deck | 2 | one in the HAND does not count; putting one in the Deck enables it |
| a Level 7 Wyrm does not qualify | 4 | "Level 8 Dragon monster" is an exact Level **and** the race, with a positive control so the negative is not vacuous |

### OneForOneTests — 40/40
`Tests/cards/OneForOneTests.gd`.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 8 | non-targeting Normal Spell activation with a send-from-hand cost |
| sends and Summons from the Deck | 7 | the cost is paid before any response window; the Level 1 monster arrives and the Deck shrinks by one |
| **a send is not a discard** | 5 | the move reason is `SENT_AS_COST`, explicitly not `DISCARDED`, while still counting as "sent to the GY" and not as a destruction [S1 p.52-53] |
| "hand or Deck" is both zones | 6 | both candidates are offered and the hand copy can be the one Summoned |
| no monster in hand | 3 | a Spell in hand is not "a monster"; adding one makes the cost payable |
| no Level 1 monster anywhere | 2 | one in the GY, or one the opponent holds, does not count |
| a full Monster Zone | 2 | unlike Kaibaman, nothing here frees a zone |
| **paying away the last Level 1 monster** | 7 | the activation is legal because the candidate check precedes the cost; the card then legitimately resolves for nothing |

---

## Phase 5 batch 3 — per-card suites

### BirthrightTests — 59/59
`Tests/cards/BirthrightTests.gd`. The first Continuous Trap in the library.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 14 | three EffectDefs, Spell Speed 2, targets 1, Set-card activation, two MANDATORY triggers, the third keyed on `CARD_MOVED` |
| revives in Attack Position | 9 | the position is FIXED by the card, so **nobody is asked** — unlike `Monster Reborn`; the Trap stays on the field and remembers what it Summoned |
| the target filter | 6 | "1 **Normal** Monster" excludes an Effect Monster and a Spell; a hand-built activation on the Effect Monster is rejected |
| only your own Graveyard | 2 | with a positive control, so the negative is not vacuous |
| not the turn it was Set | 2 | [S1 p.30] |
| a full Monster Zone | 2 | nothing here frees a zone |
| **this card leaving destroys the monster** | 6 | mandatory, by card effect, and the link is cleared so nothing fires twice |
| **the monster LEAVING THE FIELD destroys this card** | 5 | **banished counts** — the clause says "leaves the field", and this is where `Call of the Haunted` disagrees |
| destruction also triggers it | 4 | destruction is one way of leaving the field; exactly one Special Summon in the whole duel, so nothing looped |
| a failed revival links nothing | 9 | a Chain Link 2 removes the target; the Trap resolves, stays on the field, and is linked to nothing |

### CallOfTheHauntedTests — 48/48
`Tests/cards/CallOfTheHauntedTests.gd`.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 12 | three EffectDefs; the third listens for `CARD_DESTROYED`, and the suite asserts directly that the two cards' third clauses listen to **different events** |
| revives in Attack Position | 5 | fixed position, Continuous Trap stays, link recorded |
| an Effect Monster is a legal target | 7 | and the same board offers `Birthright` only **one** of the two monsters — the two filters are genuinely different |
| only your own Graveyard | 2 | with a positive control |
| this card leaving destroys the monster | 4 | the clause shared verbatim with `Birthright` |
| **the monster being DESTROYED destroys this card** | 3 | |
| **the monster being BANISHED does NOT** | 8 | the single most important difference from `Birthright`; the link survives and the banished monster is not dragged back |
| destruction by battle | 7 | fires inside the Damage Step, and battle damage is inflicted normally [S1 p.41-42] |

### HieraticDragonOfTefnuitTests — 67/67
`Tests/cards/HieraticDragonOfTefnuitTests.gd`. The first card to use a summoning PROCEDURE.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | `SUMMON_PROCEDURE` + `CONTINUOUS` + `TRIGGER`; the procedure starts no Chain |
| the procedure Summons from the hand | 8 | properly Special Summoned, `summoned_by_procedure_id` recorded, Normal Summon untouched |
| **the procedure is not an activation** | 6 | never offered as `ACTIVATE_CARD` / `ACTIVATE_EFFECT` / a response; **no Chain Link created**, but the Summon IS declared so a negation can still answer it |
| "only your opponent controls a monster" | 6 | both halves; a face-down monster still counts as one they control; a forged action naming a non-existent effect is rejected |
| **cannot attack the turn Summoned this way** | 8 | the restriction applies, another monster attacks freely as a positive control, a hand-built attack is refused, and it lifts next turn |
| **a copy Summoned another way may attack** | 7 | revived by `Monster Reborn` it has no `summoned_by_procedure_id`, so "this way" does not apply — CARD_RULINGS.md §2.1 |
| the Tribute trigger | 9 | a Tribute is not a destruction; the Dragon arrives with ATK/DEF 0 while the **printed** and **original** ATK stay 3000 [S1 p.55] |
| the Tribute trigger filter | 7 | hand + Deck + GY all reachable; a Dragon Effect Monster, a Normal **Wyrm** and a card the opponent holds are all excluded |
| destroyed rather than Tributed | 5 | no `CARD_TRIBUTED`, no Special Summon [S1 p.53] |

### InariFireTests — 65/65
`Tests/cards/InariFireTests.gd`. Research/CARD_RULINGS.md R18.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 14 | a control-limit rules query, a procedure, and a once-per-turn mandatory Standby trigger traced to R18 |
| the procedure needs a face-up Spellcaster | 8 | the opponent's Spellcaster, another race, and a **face-down** Spellcaster all fail; flipping the same monster face-up enables it |
| you can only control 1 | 7 | a second copy's procedure is refused and a hand-built one rejected; a copy the OPPONENT controls does not restrict you |
| **the limit applies to every route** | 6 | Normal Summon and Normal Set are both refused, and `Monster Reborn` activates but Special Summons nothing |
| **the Standby revival** | 12 | the `last_move_*` record survives `on_leave_field()`; the **opponent's** Standby Phase does not count; your own does |
| destroyed by battle does not revive | 6 | "destroyed by **card effect**" is narrower [S1 p.52-53] |
| Tributed does not revive | 6 | |
| **only the NEXT Standby Phase** | 6 | blocked once by a full field, the window is gone — a later Standby Phase does not resurrect it |

### RanryuTests — 49/49
`Tests/cards/RanryuTests.gd`.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 12 | optional, targets, activates from the GY, Damage Step timing permitted, and **no invented once-per-turn** |
| the procedure and the control limit | 8 | a face-up Spellcaster is required; a second copy is refused by both the procedure and a Normal Summon |
| destroyed by battle | 8 | the controller is asked exactly once, and the 1500/200 monster arrives |
| destroyed by card effect | 4 | both branches of "by battle or card effect" are live |
| declining | 4 | asked, said no, nothing Summoned |
| **the target filter** | 8 | exact printed 1500/200; a 1900/500 monster excluded; **another copy of `Ranryu` excluded BY NAME**; the opponent's GY out of reach |
| Tributed does not fire | 5 | and the controller is never asked a question with no basis |

### NefariousArchfiendTests — 44/44
`Tests/cards/NefariousArchfiendTests.gd`. Research/CARD_RULINGS.md R17.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 11 | optional, once per turn, End Phase only, targets, activates from the GY |
| the procedure and the control limit | 5 | |
| **the opponent's End Phase revival** | 8 | its controller acts on a turn that is **not theirs**: it destroys its own face-up monster and Special Summons itself |
| not during your own End Phase | 5 | the controller is never asked |
| declining | 4 | your own monster is NOT destroyed |
| no face-up monster to target | 5 | a face-down monster of yours and a face-up one of theirs are both illegal targets |
| **"and if you do"** | 6 | with the target protected from destruction, the effect activates, destroys nothing, and Summons nothing — the two halves are not independent |

### GagagashieldTests — 63/63
`Tests/cards/GagagashieldTests.gd`. Research/CARD_RULINGS.md R10.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 12 | a **NORMAL Trap**, Spell Speed 2, targets 1; the protection declares `uses_per_turn = 2` |
| a Normal Trap that stays on the field | 6 | its card KIND alone would have sent it to the GY — the equip is what keeps it [S1 p.30, p.53] |
| the target filter | 7 | Spellcaster, yours, face-up; the opponent's is rejected even hand-built |
| **twice per turn vs card effects** | 7 | two prevented, the third lands, and the shield follows its host to the GY |
| the count resets next turn | 7 | |
| **battle destruction is prevented too** | 7 | the monster survives while battle damage is still inflicted, and one use is still left that turn |
| the equipped monster leaving | 4 | `DESTROYED_BY_RULE` [S1 p.29, p.55] |
| the shield leaving | 5 | the card is not protected by its own clause; the monster is then destroyed normally |
| resolving without equipping | 8 | the target is banished by Chain Link 2; nothing equips and the Normal Trap goes to the GY |

### RiderOfTheStormWindsTests — 66/66
`Tests/cards/RiderOfTheStormWindsTests.gd`. Research/CARD_RULINGS.md R9. The pool's only
monster that equips **itself**.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 13 | an Ignition effect (Spell Speed 1, never a fast effect, Main Phases only) from **hand or field**, plus a continuous grant and a destruction replacement |
| equips itself from the hand | 8 | it lands in a **Spell & Trap Zone**, occupies no Monster Zone, was never Summoned, and cannot be re-equipped [S1 p.53] |
| equips itself from the field | 7 | it vacates its Monster Zone and nothing is destroyed on the way |
| the target filter | 8 | "Dragon **Normal** Monster you control": a Dragon Effect Monster, a non-Dragon vanilla, a face-down one and the opponent's are all excluded |
| no free Spell & Trap Zone | 5 | not offered, hand-built rejected, and it never leaves the hand [S1 p.29] |
| **it grants piercing** | 6 | the flag is on the EQUIPPED monster, not on the Equip Card; 1900 − 1000 pierces through [S1 p.42] |
| **destruction replacement by card effect** | 9 | exactly one card is destroyed and it is Rider, carrying the ORIGINAL reason; the piercing goes with it; the next destruction then lands |
| **destruction replacement in battle** | 6 | the equipped monster survives a losing battle and the battle damage is still inflicted |
| the host leaving the field | 4 | banished host ⇒ Rider destroyed by `DESTROYED_BY_RULE`, not by the replacement clause |

---

## Phase 5 batch 4 — the remaining Continuous Traps and the Continuous Spell

All per-test counts below are **measured** by `Scripts/tests/DumpAssertionCounts.gd`.

### CastleOfDragonSoulsTests — 109/109
`Tests/cards/CastleOfDragonSoulsTests.gd`. Research/CARD_RULINGS.md R19. The card was
mis-grouped as an Equip card in an earlier plan; it is a **Continuous Trap** and equips nothing.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 24 | four EffectDefs for three printed clauses — the fourth is the Trap's own activation, which has no printed effect; an Ignition Effect at Spell Speed 1, never a fast effect, Main Phases only; the control limit is found by effect id |
| **the banish is a COST** | 10 | `CARD_BANISHED` and not `CARD_SENT_TO_GY` [S1 p.53]; the target gains 700 while its printed and **original** ATK are untouched |
| **the cost survives negation** | 8 | already paid before any response window opened, and not refunded when Chain Link 2 removes the target |
| the cost filter | 5 | a **Wyrm** named "... Dragon" does not qualify, nor does a Dragon in the opponent's GY, with a positive control |
| **the boost survives its own source leaving the field** | 7 | the parenthesis "(even if this card leaves the field)" — exactly one modifier, carried by the `end_of_turn` duration rather than the continuous one, where a continuous modifier would have vanished |
| the boost expires at the end of the turn | 6 | back to printed ATK with no stale modifier |
| once per turn | 7 | a second use is refused even with a Dragon left to pay with; the use returns |
| the target filter | 6 | "1 monster you control" reaches a **face-down** one and not the opponent's; a forged activation is rejected |
| **sent to the GY recovers a banished Dragon** | 9 | including the very Dragon this card banished as its own cost; properly Special Summoned, and the position is the player's choice |
| banished rather than sent to the GY | 5 | a banished Castle never reaches the Graveyard, so nothing fires and nobody is asked [S1 p.53] |
| **never face-up on the field** | 7 | a copy sent from the HAND does not fire the clause, with a positive control on the same board showing a field copy does |
| declining | 5 | asked, said no, the Dragon stays banished |
| **the control limit on a TRAP** | 10 | two Set copies are both activatable; once one is face-up the other is refused, hand-built included; the opponent is unaffected; destroying the first lifts it |

### FiendishChainTests — 74/74
`Tests/cards/FiendishChainTests.gd`. The pool's first CONTINUOUS NEGATION.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 15 | three EffectDefs; the continuous clause declares `negates_effects`, which is what orders the recompute |
| the target filter | 7 | a Normal Monster and a **face-down** monster are both illegal targets — whether a face-down monster is an Effect Monster is not something either player may act on; both players' face-up Effect Monsters are legal |
| it negates an activated effect | 8 | `Kaibaman`'s Ignition Effect stops being offered, a hand-built activation is rejected, and nothing was Tributed; negation goes through the continuous channel rather than overwriting the one-shot flag |
| **it negates a CONTINUOUS effect** | 7 | the two-pass recompute: a monster whose own effect is continuous loses it, and five recomputes equal one |
| the attack lock | 6 | the flag is on the monster, the attack disappears, another monster attacks freely, a hand-built attack is refused |
| the negation ends with this card | 7 | destroy Fiendish Chain and both halves lift together — they are one clause |
| flipped face-down | 6 | "that FACE-UP monster" stops applying, and Fiendish Chain is **not** destroyed: being flipped face-down is not being destroyed |
| **the monster being destroyed destroys this card** | 5 | and the link is cleared so nothing fires twice |
| **the monster being banished does NOT** | 6 | "is destroyed" is narrower than "leaves the field" [S1 p.52-53]; the Trap stays face-up with nothing to negate |
| a target that left before resolution | 7 | Chain Link 2 removes it; the Trap resolves, stays on the field, and holds no stale reference |

### FiveBrothersExplosionTests — 67/67
`Tests/cards/FiveBrothersExplosionTests.gd`. Research/CARD_RULINGS.md R16.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 13 | two printed clauses, two EffectDefs — this card's activation genuinely has a printed effect; the second clause is MANDATORY |
| **it counts itself** | 5 | activation places it face-up on the field, so it is one of the cards it counts [S1 p.28-30] |
| it counts every Continuous card you control | 6 | a Continuous Spell and a Continuous Trap both count; a Normal Trap and the opponent's do not |
| **a SET Continuous Trap is not counted** | 7 | with the same card, once face-up, as the positive control (R16) |
| **the opponent's effect burns** | 9 | 500 damage per Continuous Spell/Trap in your Graveyard; your own LP untouched |
| your own effect does not | 5 | "by your OPPONENT'S card effect" — the agent is read from the movement's source |
| banished does not | 7 | "sent to your GRAVEYARD" — a banish inflicts nothing [S1 p.53] |
| the Graveyard count | 6 | a Normal Trap, a monster and the opponent's Continuous Trap are all excluded; exactly 3 counted |
| **effect damage can end the Duel** | 9 | LP floored at 0, the result and end reason recorded [S1 p.33] |

### SealingCeremonyOfSuitonTests — 73/73
`Tests/cards/SealingCeremonyOfSuitonTests.gd`. The mirror image of `Castle of Dragon Souls`:
here the banish is the EFFECT and the send is the cost.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 15 | two EffectDefs; an Ignition Effect at Spell Speed 1 with a real cost checked before the activation is offered |
| sends and banishes | 8 | the WATER monster reaches the **owner's** Graveyard, the target is banished and still owned by the opponent |
| **a send is not a discard** | 6 | `SENT_AS_COST`, explicitly not `DISCARDED`, still "sent to the GY" and not a destruction; exactly one card was sent — the banished one was not |
| "1 CARD" in their GY | 7 | a Spell and a Trap are legal targets too |
| only the opponent's Graveyard | 6 | with a positive control; a hand-built activation on your own card is rejected |
| the cost filter | 5 | an EARTH monster in hand and a WATER monster in your **Graveyard** both fail; a WATER monster in hand succeeds |
| **the cost survives negation** | 7 | paid before the opponent could respond, not refunded when Chain Link 2 removes the target |
| a target that left the Graveyard | 6 | returned to the hand by Chain Link 2 and **not** chased there |
| once per turn is per COPY | 9 | a second copy has its own use; the first copy's use returns next turn |
| outside the Main Phases | 4 | absent in the Battle Phase, present again in Main Phase 2 [S1 p.10] |

### WonderBalloonsTests — 85/85
`Tests/cards/WonderBalloonsTests.gd`. The V1 pool's only **Continuous Spell**, and the first
card to actually drive the counter engine that `CounterTests` built.

| Test | Asserts | What it proves |
|---|---:|---|
| the clause shape | 17 | three EffectDefs; Continuous Spell at Spell Speed 1, activatable from hand or a Set copy |
| one card in hand | 6 | with a single candidate and a minimum of one there is nothing to ask; `SENT_AS_COST`, one counter |
| **"any number" is the player's choice** | 8 | three of four cards sent, three counters placed, the fourth kept — a count `choose_n` cannot express |
| any **card**, not just monsters | 6 | a Spell and a Trap in hand are legal to send |
| counters accumulate | 7 | a second turn's use adds to the first rather than replacing it |
| **the drain scales with the counters** | 11 | -300 per counter; five recomputes equal one; exactly one modifier entry; 3 counters give -900 |
| only the opponent | 5 | your own monsters untouched; **every** monster they control, face-down included |
| **ATK floors at 0** | 5 | 300 - 900 is 0, not -600, and the ORIGINAL ATK is untouched |
| the drain ends with the card | 7 | destroyed gives no modifier, and its counters were cleared when it left the field |
| an empty hand cannot pay | 5 | "any number" still has a minimum of one; hand-built rejected; one card is enough |
| once per turn | 8 | refused even with cards left to send; the use returns |

**C. Interaction** — `SpecialSummonInteractionTests` (46). Everything else, not yet.

### SpecialSummonInteractionTests — 46/46
`Tests/cards/SpecialSummonInteractionTests.gd`. Declares no card-under-test marker on
purpose: a card is only counted as TESTED because it has its own suite.

| Test | Asserts | What it proves |
|---|---:|---|
| Kaibaman then Silver's Cry | 10 | the deck's real line: Kaibaman fetches Blue-Eyes, Silver's Cry has no target while it lives, and recovers the very same copy once it is in the GY |
| two revivals in one Chain | 10 | Silver's Cry (SS2) legally chains to Monster Reborn (SS1); both resolve, and the `SPECIAL_SUMMON_SUCCEEDED` order proves reverse resolution [S1 p.46-47] |
| the last zone goes to Chain Link 2 | 9 | with one free zone both activations are legal, Chain Link 2 takes it, and Chain Link 1 re-checks the board at RESOLUTION and Summons nothing |
| revived monsters can be Tributed | 8 | a monster Special Summoned this turn is an ordinary monster and may pay Dragonic Tactics' cost |
| none spend the Normal Summon | 9 | two Special Summons later the Normal Summon is still available, and only a real Normal Summon spends it [S1 p.24] |

**D. Scripted full duels** — none yet.

---

## Phase 5 batch 7 units C and D — per-card suites

Deck placement (top / bottom / shuffle), Chain-Link-position-aware effects, and excavation.
Every card below is IMPLEMENTED and TESTED in full; none is partial, approximated or stubbed.

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Phoenix Wing Wind Blast` | 1 | `PhoenixWingWindBlastTests` | 162/162 |
| `Spiritual Wind Art - Miyabi` | 1 | `SpiritualWindArtMiyabiTests` | 150/150 |
| `Chain Detonation` | 1 | `ChainDetonationTests` | 168/168 |
| `Chain Healing` | 1 | `ChainHealingTests` | 147/147 |
| `Crystal Seer` | 1 | `CrystalSeerTests` | 151/151 |

What each suite pins down that the generic gate cannot:

* **`Phoenix Wing Wind Blast`** — that it is a Normal **Trap** at Spell Speed 2 (§2.4: it is
  commonly misremembered as a Quick-Play Spell); that the discard is a **COST**, observable in the
  Graveyard *before* any resolution and not refunded by either kind of negation; that "1 card"
  reaches a Set Trap and a face-down monster and never the controller's own side; that the target
  lands on the **TOP** of its **OWNER's** Deck with the rest of the Deck in unchanged order and
  `revealed_to` **kept**; and both resolution-time drops — target left the field, and target
  changed control (**R29**).
* **`Spiritual Wind Art - Miyabi`** — the same shape with the two deliberate differences asserted
  hardest: a **WIND Tribute** cost (a non-WIND monster does not pay it; a face-down WIND monster
  you control does; the cost is *not* paid when the card cannot legally activate), and the
  **BOTTOM** of the Deck rather than the top. Its clause text is checked to carry the current
  official "that opponent's card" wording rather than the older "that card".
* **`Chain Detonation`** — all three Chain Link branches driven at real Chain depths built by
  `TestFixtures.build_chain_to_depth()`: CL1 (damage only, Trap to the Graveyard), CL2 and CL3
  (shuffled into the Deck, `revealed_to` cleared for the whole Deck), CL4 and CL5 (returned to the
  hand). Plus: the damage always hits the opponent, asserted from both seats; the branch comes
  from the position **recorded on the Chain Link**, proved on a three-link Chain where a count
  taken at resolution would differ; a higher link destroying the card first leaves the damage done
  and the self-return impossible; and the card that moved itself off the field is **not** also
  swept to the Graveyard by `_cleanup_resolved_spell_traps()`.
* **`Chain Healing`** — the same three branches on this card rather than inherited from the shared
  primitive, plus the half it does not share: the LP go to the **activating player**, asserted
  from both seats, and the card cannot end a Duel even with both players on 100 LP. One test
  asserts the relationship itself — separate registry files, separate effect ids, and the shared
  two sentences printed verbatim on both — so "same shape, not one implementation" cannot rot.
* **`Crystal Seer`** — that it is a **FLIP** effect, fired by all three routes (Flip Summon, a card
  effect, an attacker) and never while face-down; that an excavate is **not a draw** (no
  `CARD_DRAWN`) and **not a search** (nothing shuffled, so the leftover card **keeps**
  `revealed_to` — the printed-card exercise of design decision 11's other branch); that the player
  really chooses which card goes to hand and the choice is logged for replay; that 1 card left
  excavates 1 and 0 left does nothing **without decking the player out**; that nothing is left in
  the `EXCAVATED` zone; and that a negated effect and a negated Flip Summon each leave the Deck
  byte-for-byte untouched.

---

## Phase 5 batch 8 (PARTIAL) — per-card suites

The banish group and temporary removal. **One of five cards is done.**

| Card | EffectDefs | Suite | Result |
|---|---:|---|---|
| `Interdimensional Matter Transporter` | 1 | `InterdimensionalMatterTransporterTests` | 175/175 |
| `Judge of the Ice Barrier` | — | — | **NOT STARTED** |
| `Junk Blader` | — | — | **NOT STARTED** |
| `The Phantom Knights of Shadow Veil` | — | — | **NOT STARTED** |
| `Runick Flashing Fire` | — | — | **NOT STARTED** |

What the one finished suite pins down that the generic gate cannot:

* **`Interdimensional Matter Transporter`** — that it is a Normal **Trap** at Spell Speed 2, so it
  can be activated in a response window on the opponent's turn (asserted by actually building a
  Chain Link 2 from the non-turn player's seat) and returns the monster in **that** turn's End
  Phase; that all three restricting words of "1 **face-up** **monster** **you control**" bind the
  candidate set — the opponent's monsters, a face-down monster of your own, and your own
  Spell/Traps are each excluded, and submitting an excluded card as the target is **rejected by
  the engine** rather than merely not offered; that with no face-up monster the activation is not
  offered at all, with a face-up monster it is (so the two negatives are about the candidate set
  and not about a broken board); and all three resolution-time re-checks — target left the field,
  target's control taken by the opponent (**R29**), target flipped face-down — each with a
  positive control proving the negative was caused by the change and not by a broken context.
  Then the round trip on the printed card: banished face-up into its **owner's** Banished zone
  with no destruction and no send-to-GY event, a lease naming this card as its source that
  **outlives the Trap** going to the Graveyard, the return at the End Phase under the owner's
  control in the position it left in (both positions asserted), the monster coming back as a
  **fresh instance** with its Equip Card dead in the Graveyard and its counters and modifiers
  gone, and — the card's whole reason to exist — a real two-link Chain in which Chain Link 2
  banishes the monster before the opponent's Chain Link 1 destruction resolves, so
  `CARD_DESTROYED` never fires for it and it comes back at the End Phase. Both negations are
  asserted to banish nothing and schedule nothing, and the round trip is replay-deterministic.

### Open rules questions — all four now RESOLVED (Phase 4c)

* **When a Continuous Spell/Trap's continuous effect begins applying.** DECIDED: only once
  its own activation resolves. `RULES_SPEC.md §8.1` [S1 p.17, p.18 with p.44–47]. The
  section records honestly that no single official sentence states the start point
  verbatim and that the decision rests on the rulebook's activation-vs-resolution
  separation.
* **Whether `revealed_to` survives a shuffle into the Deck.** DECIDED: no — but it *does*
  survive a placement on top/bottom without a shuffle, because the position is still
  known. `RULES_SPEC.md §12.1` [S1 p.5, p.28].
* **Player-level continuous restrictions.** RESOLVED: `TurnFlow.can_enter_battle_phase()`
  now consumes `continuous:cannot_conduct_battle_phase` as well as the turn-scoped
  `skip_battle_phase_this_turn`. Both are kept because their lifetimes differ — one is
  rebuilt on every recompute, the other must survive one.
* **Piercing battle damage.** The earlier note that no V1 card requires it was WRONG:
  `Rider of the Storm Winds` grants piercing. Both branches are now tested.

Coverage is reported honestly here and in `Reports/CARD_IMPLEMENTATION_MATRIX.csv`
(**54 / 77 implemented, 54 / 77 tested, 23 remaining**, computed by
`python Tools/build_matrix.py`). No test result in this file is estimated or projected.

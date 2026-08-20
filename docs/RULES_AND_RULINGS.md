# Rules and rulings — an index

Where the rules in this engine come from, how sources are ranked, and how uncertainty is
recorded rather than hidden.

**This is an index, not a copy.** The authoritative documents live in
[`../Research/`](../Research/) and run to thousands of lines; duplicating them here would just
create two versions to disagree with each other. Read this to know *which* document answers
your question, then go and read that document.

---

## The three documents

| Document | What it is | Read it when |
|---|---|---|
| [`../Research/RULES_SOURCES.md`](../Research/RULES_SOURCES.md) | **The source register.** For each source S1–S4: title, publisher, canonical URL, byte size, SHA-256, date accessed, and the exact list of rules it establishes, with page numbers. | You need to know *where a rule came from*, or you are adding a new source. |
| [`../Research/RULES_SPEC.md`](../Research/RULES_SPEC.md) | **The implementable rules contract**, §1–§17. The rules as the engine implements them, each section citing the source it came from. | You are implementing or changing anything rules-bearing. This is the document engine code cites in comments. |
| [`../Research/CARD_RULINGS.md`](../Research/CARD_RULINGS.md) | **Per-card ruling decisions R1–R34**, plus data discrepancies resolved against the official source, each with an explicit confidence level. | A specific card's official text is ambiguous, or you want to know why a card behaves the way it does. |

The chain runs one way and is meant to be followed backwards:

```
engine code comment  ->  RULES_SPEC.md §n  ->  RULES_SOURCES.md S1-S4  ->  the official document
card behaviour       ->  CARD_RULINGS.md Rn ->  its stated confidence and reasoning
```

**Nothing in this engine is implemented from memory.** If you cannot trace a rule back along
that chain, it does not belong in the engine yet.

---

## The source hierarchy

### 1. Primary — official Konami sources

These are the only sources that establish a rule on their own.

| | Source | Establishes |
|---|---|---|
| **S1** | Official Rulebook Version 10 (PDF) | Deck construction, zones, effect categories, summoning, Spell/Trap types and restrictions, turn structure, the Battle Phase and its steps, Damage Step restrictions, damage calculation, Chains and Spell Speed, priority, simultaneous-activation ordering, "leaves the field", the glossary definition of *destroy* |
| **S2** | Official Fast Effect Timing chart | The complete turn-flow state machine, boxes A–E — when each player may act, when a trigger check occurs, when a Chain is built, and how play returns to an open game state. Transcribed in full in `RULES_SPEC.md §3` |
| **S3** | Official Damage Step Rules (web) | The five Damage Step sub-steps and what may be activated in each |
| **S4** | Official Yu-Gi-Oh! Card Database (Neuron) | Current official English card text, type, Attribute, Level, ATK/DEF and errata status for all 77 cards |

S2 **supersedes** the older "Ignition Effect priority" model, which is deliberately not
implemented.

Two audit notes recorded in `RULES_SOURCES.md` rather than smoothed over: the
`/en/gameplay/damage_step/` URL printed in Rulebook v10 p.41 now returns HTTP 404, so S3 is the
equivalent live official document on Konami's EU portal — still a Konami-operated official TCG
site, and the discrepancy is written down. And the local `official_card_data.json` used for
passcode lookup is an **input, not an authority**: where it disagrees with S4, S4 wins and the
disagreement is recorded.

### 2. Secondary — permitted, but always labelled

A community source may be used **only** where no official source covers the detail, and must be
marked `[SECONDARY]` at the point of use.

**Never present a community source as official.** That is the single most damaging thing that
can be done to this project's rules trail: every downstream reader would then have a false
belief about how well-founded a behaviour is, and no way to detect it.

### 3. Never a rules authority

Explicitly excluded, and listed as excluded in `RULES_SOURCES.md`:

* **Yu-Gi-Oh! Master Duel** — aesthetic and presentation inspiration only, for a future phase.
  It never settles a rules question, and this project claims no affiliation with it.
* Reddit, forums, deck profiles and fan videos.
* AI-generated rules summaries.
* Wikis — permitted only as clearly-labelled SECONDARY fallback, as above.

---

## How confidence is handled

Some questions the official text simply does not settle. The project's answer is to **decide,
record the decision, and be explicit about how well-founded it is** — never to guess silently
and never to present a reasoned inference as a quoted rule.

Every non-obvious decision gets:

1. an entry in `CARD_RULINGS.md` with an `R` number, stating the question, the decision, the
   reasoning, and an explicit **confidence level**;
2. a `ruling_ref` on the affected `EffectDef`, so the code points back at the reasoning;
3. **isolation behind a single predicate** wherever possible, so a later correction is a
   one-place change;
4. **an assertion that pins it**, so that if the decision turns out to be wrong the suite fails
   loudly instead of the behaviour drifting.

### Confidence levels in use

| Level | Meaning |
|---|---|
| HIGH | Directly supported by a quoted official sentence. |
| MEDIUM-HIGH | Strongly implied by official text or Problem-Solving Card Text conventions, but not stated outright. |
| MEDIUM | A reasoned decision resting on a general rule or a community-transcribed ruling rather than a quoted official sentence for *this* card. |
| LOW | Recorded, implemented, and explicitly flagged as needing research. |

Real examples currently on the record — this is what honest bookkeeping looks like in practice:

* **R34 part D** — that "cannot activate Trap Cards" locks activating a Trap *card* but not
  activating an *effect* of an already-face-up Trap. **MEDIUM-HIGH**, reasoned from
  Problem-Solving Card Text rather than from a quoted ruling. It is explicitly flagged as the
  most worthwhile piece of research for the next session, and is isolated behind one predicate
  (`ActivationRules.card_class_activation_ok()`).
* **R29** — "1 card your opponent controls" is re-checked for *control* at resolution.
  **MEDIUM overall**, and the entry says why it splits: HIGH for `Spiritual Wind Art - Miyabi`,
  whose own official resolution clause says "that **opponent's** card", and MEDIUM for
  `Phoenix Wing Wind Blast`, which says only "that target" and therefore rests on the general
  targeting rule. Ownership is deliberately not part of it.
* **R27 / R28** — both rest on community-transcribed rulings rather than an S1–S4 source, and
  both say so. R28 (a card destroying "all Spell and Trap Cards on the field" does not destroy
  itself) is reasoned from the `Heavy Storm` precedent.
* **R25** — when "until the End Phase" ends. No single official sentence names the instant, so
  the entry states what *is* certain (control lasts through Main Phase 2 and is gone before the
  next turn) and records the chosen instant as a reasoned decision.

### Open rulings

**R3, R6, R7 and R8 are still OPEN.** They concern `Maiden with Eyes of Blue`,
`Swords of Revealing Light`, `Soul Exchange` and `Kaiser Sea Horse` — four of the 28 cards not
yet implemented. The generic *mechanisms* those cards will use have been settled by batch 9
unit A; the per-card questions have not. Do not treat them as closed.

`CARD_RULINGS.md` §4 lists all 21 ruling-flagged cards; §4A holds the decided rulings R4–R34,
each marked CLOSED or OPEN.

---

## Adding a rule or a ruling

1. **Find it in a primary source first.** If S1–S4 answer the question, cite the source and the
   page.
2. **Add or extend the `RULES_SPEC.md` section**, with the citation inline (`[S1 p.44]`).
3. **Register a new source** in `RULES_SOURCES.md` if you used one — title, publisher, canonical
   URL, size, SHA-256, date accessed, and the specific rules it establishes.
4. **If the answer is not in a primary source**, write the `CARD_RULINGS.md` entry with a
   confidence level and the reasoning, set `ruling_ref`, isolate the decision, and assert it.
5. **Cite the spec section in the code comment**, so the next reader can follow the chain
   backwards.

Adding a MEDIUM-confidence ruling honestly is a contribution. Adding one as though it were
certain is a defect.

---

## Getting the primary documents

The official Konami documents are **not vendored in this repository** — they are Konami
publications and this project holds no redistribution rights, and they are free downloads from
Konami's own site.

[`../Research/sources/README.md`](../Research/sources/README.md) has the fetch commands for
each, plus the expected SHA-256 and byte size so you can confirm you are reading the same
revision the citations were taken from.

**A hash mismatch is not automatically a problem** — it means Konami revised the document. It
*is* a signal that any citation you are about to add or re-check must be re-read against the
new revision, and that `RULES_SOURCES.md` needs a new dated entry rather than an edit in place.
Never silently update a page number.

You do not need any of these files to build, run or test the project.

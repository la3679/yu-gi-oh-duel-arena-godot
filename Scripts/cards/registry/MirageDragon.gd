extends RefCounted

## Mirage Dragon — LIGHT / Dragon / Level 4 Effect Monster, 1600 / 600. Two copies, deck 1.
##
## Official text (verified against the Konami card database, `Data/cards/cards.json`,
## cid 6196):
##
##   "Your opponent cannot activate Trap Cards during the Battle Phase."
##
## **One clause, and it is CONTINUOUS.** It is the first printed card in the pool to consume
## the card-class activation lock that Phase 5 batch 9 unit A built and tested
## (`AttackRestrictionTests`, `RULES_SPEC.md 4.4`, `CARD_RULINGS.md` R34 part D). Everything
## it needs already exists, so this file is deliberately tiny — the interesting work was
## done in the gate, before this card was written.
##
## Five things this card is careful about, each of which has a test:
##
##   1. **It locks activating a Trap CARD, not activating an EFFECT of a Trap.** A Continuous
##      Trap that is already face-up was activated on an earlier turn; using one of its
##      Ignition-like or Trigger-like abilities now is not a second activation of the Trap
##      Card [S1 p.30: "Continuous Trap Cards remain on the field once they are activated …
##      Some Continuous Trap Cards have abilities similar to the Ignition Effects or Trigger
##      Effects"; S1 p.53: "The effect of a card is the special ability written on it"].
##      `ActivationRules.card_class_activation_ok()` already draws exactly this line and no
##      card name reaches it. R34 part D records the confidence honestly.
##   2. **A Counter Trap is a Trap Card.** The rulebook lists Normal, Continuous and Counter
##      as the three kinds of Trap Card [S1 p.30], so the lock covers activating one. Nothing
##      in the engine special-cases Counter Traps here and nothing should — but it is
##      asserted rather than left implied.
##   3. **It names the OPPONENT.** `ctx.opponent_id()` rather than a hard-coded player, so
##      the restriction turns around by itself if control of this card changes.
##   4. **It names the BATTLE PHASE.** The lock key carries the phase, so the same Set Trap
##      is activatable again in Main Phase 2.
##   5. **There is no `resolve`.** A continuous clause never resolves and starts no Chain;
##      `of_type(CONTINUOUS)` already clears `starts_chain`. It is written through
##      `ctx.continuous`, so it is rebuilt on every recompute and switches itself off the
##      moment this card stops being a face-up, un-negated monster on the field.
##
## There is deliberately **no card-specific state and no `Mirage Dragon` anywhere in
## `ActivationRules`**. The generic channel is the whole point of unit A.

const CARD_NAME := "Mirage Dragon"

const CLAUSE_TRAP_LOCK := "Your opponent cannot activate Trap Cards during the Battle Phase."

## The effect id the test suite asserts against, so a rename is a failing test rather than a
## silent divergence between the card and its documentation.
const EFFECT_ID := "opponent_cannot_activate_traps_in_battle_phase"


func effects() -> Array:
	return [_trap_lock()]


func _trap_lock() -> EffectDef:
	var e := EffectDef.new(EFFECT_ID, CLAUSE_TRAP_LOCK)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.ruling("R34")

	e.apply_continuous = func(ctx: EffectContext) -> void:
		EffectPrimitives.forbid_card_activation(ctx, ctx.opponent_id(),
			Enums.Category.TRAP, Enums.Phase.BATTLE)

	return e

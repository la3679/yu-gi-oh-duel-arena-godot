extends RefCounted

## Junk Blader — EARTH / Warrior / Level 4 / 1800 ATK / 1000 DEF.
##
## Official text (verified against the Konami card database, cid 8735):
##
##   "You can banish 1 "Junk" monster from your Graveyard; this card gains 400 ATK until the
##    end of this turn."
##
## ONE effect clause. An IGNITION effect activated from the field face-up.
##
## Details this implementation accounts for:
##
##   1. **The banish is a COST.** It sits before the semicolon, which is PSCT for a cost
##      [RULES_SPEC.md 10]: `pay_banish_cost()` in `pay_cost`, never in `resolve`, and never
##      refunded when the effect is later negated. This reuses the batch-4 cost primitive
##      unchanged — banish-as-a-cost and banish-as-an-effect stay two primitives.
##   2. **No once-per-turn is printed, so none is added.** The clause may be used as many
##      times in a turn as there are "Junk" monsters to banish, and each use stacks another
##      400 ATK. That is asserted rather than assumed, because adding a restriction the card
##      does not print would be as wrong as dropping one it does.
##   3. **"until the end of THIS turn"** is `gain_atk_until_end_of_turn()` (batch 4), which
##      already expires in `TurnFlow._end_of_turn_cleanup()`. DEF is untouched: the text says
##      ATK only.
##   4. **The cost is never live in the V1 pool.** `Junk Blader` is the only "Junk" card in
##      either deck and there is exactly one copy, so the only card that could pay the cost
##      is this card itself — which cannot be in the Graveyard while it is face-up on the
##      field activating the effect. Implemented in full anyway and tested against a
##      SYNTHETIC second "Junk" monster, with a real-pool assertion, the same treatment R21
##      (`Apprentice Magician`) and R23 (`Fairy Tail - Rella`) established.

const CARD_NAME := "Junk Blader"

const ARCHETYPE := "Junk"
const ATK_GAIN := 400

const CLAUSE_GAIN := "You can banish 1 \"Junk\" monster from your Graveyard; this card " \
	+ "gains 400 ATK until the end of this turn."


func effects() -> Array:
	return [_gain_atk()]


func _gain_atk() -> EffectDef:
	var e := EffectDef.new("banish_junk_gain_atk", CLAUSE_GAIN)
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not _junk_in_graveyard(ctx).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_banish_cost(ctx, _junk_in_graveyard(ctx), 1,
			"Banish 1 \"Junk\" monster from your Graveyard")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# "THIS card gains 400 ATK" — the source itself, and only while it is still on the
		# field to gain anything. The cost has already been paid either way.
		if not ctx.source.is_on_field():
			ctx.log_note("Junk Blader is no longer on the field")
			return
		EffectPrimitives.gain_atk_until_end_of_turn(ctx, ctx.source, ATK_GAIN)
		ctx.log_note("gained %d ATK until the end of this turn" % ATK_GAIN)

	return e


## "1 'Junk' monster in your Graveyard" — the controller's Graveyard only.
static func _junk_in_graveyard(ctx: EffectContext) -> Array:
	return EffectPrimitives.cards_in(ctx, ctx.controller_id, Enums.Zone.GRAVEYARD,
		EffectPrimitives.archetype_monster(ARCHETYPE))

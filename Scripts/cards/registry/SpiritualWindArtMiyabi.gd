extends RefCounted

## Spiritual Wind Art - Miyabi — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6442; see
## Data/generated/konami_cards.json):
##
##   "Tribute 1 WIND monster, then target 1 card your opponent controls; place that
##    opponent's card on the bottom of the Deck."
##
## The saved text said "that card"; the official current text says "that **opponent's**
## card". Research/CARD_RULINGS.md §2.1 records the discrepancy and resolves it in favour of
## the official source — and the errata matters, because the resolution clause itself now
## names the target as the opponent's. See detail 6.
##
## One printed clause, one EffectDef. It is the mirror of `Phoenix Wing Wind Blast` with two
## deliberate differences — a different COST, and the OTHER end of the Deck:
##
##   1. **The Tribute is a COST.** It sits before the comma and before "then target", which
##      is where PSCT puts costs [S1 p.52]. Paid at ACTIVATION through
##      `EffectPrimitives.pay_tribute_cost()`, and **not refunded** if the activation or the
##      effect is later negated.
##   2. **"Tribute 1 WIND monster" is a monster YOU control.** A Tribute is always your own
##      [S1 p.23]. A face-down WIND monster you control is a legal Tribute: you know what
##      your own Set monster is, and the cost does not require anyone else to read it.
##      Without a WIND monster the cost cannot be paid and the card cannot be activated.
##   3. **A Tribute is not a destruction** and it IS a send to the Graveyard [S1 p.53] —
##      `MoveReason.TRIBUTED`, which is exactly what `pay_tribute_cost()` encodes.
##   4. **"1 card your opponent controls" is any card** — monster, Spell/Trap, face-down.
##      The same candidate set `Phoenix Wing Wind Blast` publishes.
##   5. **It places the target on the BOTTOM of the Deck.** `place_on_deck(…, true)`.
##      Nothing is shuffled — the text says "place", so `revealed_to` is KEPT and the card's
##      whereabouts stay known. RULES_SPEC.md §12.1, design decision 11. The bottom end is
##      derived from the MoveReason by `Enums.deck_position_for()`, so the reason and the end
##      can never disagree — the batch-7 unit A fix.
##   6. **"that opponent's card" is re-checked at resolution.** Unlike `Phoenix Wing Wind
##      Blast`, whose resolution clause says only "that target", this card's own resolution
##      text names the card as the opponent's, so the re-check is not merely the general
##      targeting rule here. Research/CARD_RULINGS.md R29.
##   7. **The Deck is the target's OWNER's Deck** [S1 p.52], never the current controller's.

const CARD_NAME := "Spiritual Wind Art - Miyabi"

const CLAUSE := "Tribute 1 WIND monster, then target 1 card your opponent controls; " \
	+ "place that opponent's card on the bottom of the Deck."

const WIND := "WIND"


func effects() -> Array:
	var e := EffectDef.new("tribute_wind_then_place_target_on_bottom_of_deck", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it. See
	# `PhoenixWingWindBlast.gd`.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R29")
	e.targeting(1)

	# Attribute only: no ATK, Level or Race condition, and deliberately no face-up filter.
	var wind_monster := EffectPrimitives.monster_filter(WIND)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.exclude_required_tributes(ctx, EffectPrimitives.opponent_field_cards(ctx))

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_pay_tribute_cost(ctx, EffectPrimitives.tribute_cost_candidates(ctx, wind_monster, true), 1)

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.tribute_cost_candidates(ctx, wind_monster, true)
		var paid := EffectPrimitives.pay_tribute_cost(ctx, candidates, 1,
			"Tribute 1 WIND monster (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_opponent_field_target(ctx)
		if target == null:
			ctx.log_note("the target is no longer a card the opponent controls on the field")
			return
		# BOTTOM of the Deck, and no shuffle: `to_bottom` is true.
		if EffectPrimitives.place_on_deck(ctx, target, true):
			ctx.log_note("placed %s on the bottom of its owner's Deck" % target.card_name())

	return [e]

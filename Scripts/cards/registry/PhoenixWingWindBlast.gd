extends RefCounted

## Phoenix Wing Wind Blast — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6279; see
## Data/generated/konami_cards.json):
##
##   "Discard 1 card, then target 1 card your opponent controls; place that target on the
##    top of the Deck."
##
## **It is a Normal TRAP**, not the Quick-Play Spell it is commonly remembered as. The
## official database records it as a Normal Trap and both independent local sources agree;
## Research/CARD_RULINGS.md §2.4 records the confirmation.
##
## One printed clause, one EffectDef, and six details that are easy to get wrong:
##
##   1. **The discard is a COST.** It sits before the comma and before "then target", which
##      is where PSCT puts costs [S1 p.52]. It is paid at ACTIVATION through
##      `EffectPrimitives.pay_discard_cost()` in `pay_cost`, and it is **not refunded** if
##      the activation or the effect is later negated. Contrast `A Wingbeat of Giant
##      Dragon`, whose return is part of the effect (R27).
##   2. **"Discard 1 card" is any card**, not just a monster — every card in the hand is a
##      legal payment. With an empty hand the cost cannot be paid and the card cannot be
##      activated at all.
##   3. **"1 card your opponent controls" is any card** — a monster, a Set or face-up
##      Spell/Trap, a Field Spell. A face-down card is legal: the text names no property a
##      face-down card lacks. The controller's OWN cards are never legal targets.
##   4. **It places the target on the TOP of the Deck.** This is not a generic "return to
##      Deck": nothing is shuffled, so the card's whereabouts stay known and `revealed_to`
##      is KEPT. RULES_SPEC.md §12.1, design decision 11. `place_on_deck(…, false)`.
##   5. **The Deck is the target's OWNER's Deck**, even for a card the opponent had taken
##      control of and even though the text says "the Deck" rather than "its owner's Deck"
##      [S1 p.52]. `GameState.move_card()` forces this; this card must not pass a
##      `to_player`.
##   6. **"your opponent controls" is re-checked at resolution**, not only at activation.
##      A target this card's controller has since taken control of is no longer a card the
##      opponent controls and the effect does not apply to it. Research/CARD_RULINGS.md R29
##      records that decision and its confidence.

const CARD_NAME := "Phoenix Wing Wind Blast"

const CLAUSE := "Discard 1 card, then target 1 card your opponent controls; place that " \
	+ "target on the top of the Deck."


func effects() -> Array:
	var e := EffectDef.new("discard_then_place_target_on_top_of_deck", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]. `of_type()` derives Spell Speed from the
	# EFFECT category, which is Spell Speed 1 for everything but a Quick Effect, so the
	# CARD's Spell Speed has to be stated or the card would never be offered in a response
	# window.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R29")
	e.targeting(1)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.opponent_field_cards(ctx)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		# "Discard 1 card" — every card in the hand qualifies. This card itself is Set on the
		# field, never in the hand, so it can never be its own payment.
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			func(_card: CardInstance) -> bool: return true).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			func(_card: CardInstance) -> bool: return true)
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1,
			"Discard 1 card (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_opponent_field_target(ctx)
		if target == null:
			ctx.log_note("the target is no longer a card the opponent controls on the field")
			return
		# TOP of the Deck, and no shuffle: `to_bottom` is false.
		if EffectPrimitives.place_on_deck(ctx, target, false):
			ctx.log_note("placed %s on top of its owner's Deck" % target.card_name())

	return [e]

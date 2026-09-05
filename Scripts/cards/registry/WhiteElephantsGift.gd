extends RefCounted

## White Elephant's Gift — Normal Spell.
##
## Official text (verified against the Konami card database, cid 9138; see
## Data/generated/konami_cards.json):
##
##   "Send 1 face-up non-Effect Monster you control to the GY; draw 2 cards."
##
## The third of the batch-10 draw cards, and the one that differs from the other two in
## every part of its cost: it SENDS rather than discards, it takes the card from the FIELD
## rather than the hand, and its qualification is a negative property.
##
## Details this implementation accounts for:
##
##   1. **It is a SEND, not a DISCARD**, and the card is on the FIELD. PSCT keeps "discard"
##      (hand to GY) and "send to the GY" apart [S1 p.52-53], so this is
##      `pay_send_to_gy_cost()` with `MoveReason.SENT_AS_COST`, and a clause worded for a
##      discard must never see it. The suite asserts the distinction directly against the
##      other two cards.
##   2. **It is still a COST** — the official supplement (cid 9138, 2021-04-01) says so, and
##      it precedes the semicolon. Paid at activation, not refunded on negation
##      [S1 p.53, "Pay a Cost"].
##   3. **"non-Effect Monster" is officially WIDER than "Normal Monster"** (same
##      supplement): it also covers effectless Ritual, Fusion, Synchro, Xyz and Link
##      monsters. So the predicate is "is a monster AND is not an Effect Monster", not
##      `is_normal_monster`. Both Extra Decks are empty in V1, so in THIS pool the two sets
##      coincide — the suite asserts that coincidence against the real pool, the R21 / R23
##      never-live treatment, so the fact cannot rot silently.
##   4. **"face-up"** is printed, so a face-down Set monster cannot pay. `face_up_only` on
##      `qualified_own_field_monsters()` is the default and is asserted.
##   5. **"you control"** — the opponent's monsters are never candidates, and CONTROL is the
##      question, not ownership: a monster you have taken control of can pay.
##   6. The supplement also excludes monsters that cannot be sent to the GY (Tokens,
##      Pendulums). The V1 pool has neither, so there is nothing to implement; the
##      never-live fact is asserted rather than coded around.
##   7. **The Deck requirement.** The other two draw cards carry an explicit official
##      statement that they cannot be activated on a Deck of fewer than 2. This card's own
##      supplement is SILENT on the point. Applying the same gate here is an **inference by
##      analogy**, recorded as such in R40 part D at MEDIUM-HIGH confidence and NOT presented
##      as an official ruling for this card. It is applied because the alternative — letting
##      this one card deck its controller out where two identically-worded cards may not —
##      is equally unsourced and inconsistent.
##   8. In deck 2 the live payments are `Metaphys Armed Dragon` (x2), `Sabersaurus`,
##      `Gladiator Beast Andal` and `Zure, Knight of Dark World`.
##   9. **No once-per-turn is printed and none was added.**

const CARD_NAME := "White Elephant's Gift"

const CLAUSE := "Send 1 face-up non-Effect Monster you control to the GY; draw 2 cards."

const DRAW_COUNT := 2


func effects() -> Array:
	var e := EffectDef.new("send_non_effect_monster_draw_2", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var payable := EffectPrimitives.non_effect_monster()

	# R40 part D, applied here by analogy rather than by a card-specific official statement.
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_draw(ctx, ctx.controller_id, DRAW_COUNT)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.qualified_own_field_monsters(ctx, payable).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.qualified_own_field_monsters(ctx, payable)
		var paid := EffectPrimitives.pay_send_to_gy_cost(ctx, candidates, 1,
			"Send 1 face-up non-Effect Monster you control to the GY")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "sent", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var drawn := EffectPrimitives.draw_cards(ctx, ctx.controller_id, DRAW_COUNT)
		ctx.log_note("drew %d card(s)" % drawn.size())

	return [e]

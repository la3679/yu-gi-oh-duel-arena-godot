extends RefCounted

## Trade-In — Normal Spell.
##
## Official text (verified against the Konami card database, cid 7248; see
## Data/generated/konami_cards.json):
##
##   "Discard 1 Level 8 monster; draw 2 cards."
##
## The generic behaviour is the batch-10 DECK-ACCESS unit (RULES_SPEC.md 8.4), built and
## green in `DeckAccessTests` before this card existed. This file is the card, not the
## mechanic.
##
## Details this implementation accounts for:
##
##   1. **The discard is a COST**, not part of the effect: it stands before the semicolon,
##      and the official supplement (cid 7248, 2021-02-06) says so outright. It is paid at
##      activation and, per [S1 p.53] "Pay a Cost", is NOT refunded if the activation is
##      negated. `pay_cost`, never `resolve`. RULES_SPEC.md 10.
##   2. **It is a DISCARD, not a "send".** PSCT keeps the two apart [S1 p.52-53], so the
##      move reason is `DISCARDED` and a future "if this card was sent from the field"
##      clause must not see it. `pay_discard_cost()`, not `pay_send_to_gy_cost()`.
##   3. **The cost is QUALIFIED: a Level 8 monster.** The qualification lives in the
##      candidate list, so the engine can answer "may I activate this at all?" before
##      anything is paid. `Trade-In` itself is a Spell and has already left the hand for a
##      Spell & Trap Zone by the time the cost is paid, so it can never pay for itself.
##   4. **It cannot be activated unless the Deck holds 2 cards** — R40 part D, from the same
##      official supplement ("can be activated in a situation where your Deck has 2 or more
##      cards"). This does NOT follow from the general rules: without it the engine would
##      let a player activate on a one-card Deck, draw 1 and lose the Duel by deck-out.
##      `EffectPrimitives.can_draw()` is the generic form of that rule.
##   5. **It does not target.** Nothing is chosen at activation except the cost.
##   6. **Level is read from the card as it is**, via `monster_of_level`, which asks
##      `current_level()`. Nothing in the V1 pool changes a Level in the hand, but the
##      official Q&A for this card (fid 7036) is precisely about a hand monster whose Level
##      was CHANGED to 8, so the correct question is the current Level, not the printed one.
##   7. **No once-per-turn is printed and none was added.**
##   8. In deck 1 the live payments are `Blue-Eyes White Dragon` and `Rabidragon`, the
##      pool's only Level 8 monsters. `The White Stone of Legend` is Level 1 and therefore
##      CANNOT be discarded by this card — `Cards of Consonance` is the card that does that.

const CARD_NAME := "Trade-In"

const CLAUSE := "Discard 1 Level 8 monster; draw 2 cards."

const DRAW_COUNT := 2
const REQUIRED_LEVEL := 8


func effects() -> Array:
	var e := EffectDef.new("discard_level_8_draw_2", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var level_8 := EffectPrimitives.monster_of_level(REQUIRED_LEVEL)

	# R40 part D. The Deck requirement is an ACTIVATION condition, so a short Deck makes the
	# card un-activatable rather than making it a deck-out.
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_draw(ctx, ctx.controller_id, DRAW_COUNT)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.qualified_hand_cards(ctx, level_8).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.qualified_hand_cards(ctx, level_8)
		var paid := EffectPrimitives.pay_discard_cost(ctx, candidates, 1,
			"Discard 1 Level 8 monster")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "discarded", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var drawn := EffectPrimitives.draw_cards(ctx, ctx.controller_id, DRAW_COUNT)
		ctx.log_note("drew %d card(s)" % drawn.size())

	return [e]

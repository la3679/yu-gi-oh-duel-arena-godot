extends RefCounted

## One for One — Normal Spell.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Send 1 monster from your hand to the GY; Special Summon 1 Level 1 monster from
##    your hand or Deck."
##
## Details this implementation accounts for:
##
##   1. The semicolon splits COST from EFFECT: "Send 1 monster from your hand to the GY"
##      is a **cost**, paid at activation. RULES_SPEC.md 10, master prompt 16.
##   2. "Send ... to the GY" is NOT "discard". PSCT treats the two as different, so the
##      move reason is `SENT_AS_COST` and a card that triggers on a discard must not see
##      it. [S1 p.52-53]
##   3. The cost is a **monster** from the hand — One for One itself is a Spell, and by
##      the time the cost is paid it has already left the hand for a Spell & Trap Zone
##      anyway (`DuelEngine._reveal_for_activation` runs first).
##   4. The Summon does **not** target, so the monster is chosen at RESOLUTION —
##      necessarily, since half the candidates are in the hidden Deck. RULES_SPEC.md 10.
##   5. "from your hand or Deck" is one pool of candidates spanning two zones.
##   6. Unlike Kaibaman and Dragonic Tactics, nothing here frees a Monster Zone, so a
##      free zone genuinely is an activation requirement.
##   7. The cost is paid BEFORE the effect resolves, so a player who sends their only
##      Level 1 monster as the cost, holding none in the Deck, legitimately resolves the
##      card for nothing. The activation was still legal — the candidate check happens
##      before the cost. That branch is covered by the test suite rather than papered
##      over.
##   8. Looking through the Deck requires shuffling it afterwards. [S1 p.5]

const CARD_NAME := "One for One"

const CLAUSE := "Send 1 monster from your hand to the GY; Special Summon 1 Level 1 " \
	+ "monster from your hand or Deck."


func effects() -> Array:
	var one := EffectDef.new("send_monster_summon_level_1", CLAUSE)
	one.of_type(Enums.EffectType.CARD_ACTIVATION)
	one.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var any_monster := EffectPrimitives.monster_filter()
	var level_1 := EffectPrimitives.monster_of_level(1)

	one.condition = func(ctx: EffectContext) -> bool:
		if not ctx.me().has_free_monster_zone():
			return false
		if not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, level_1).is_empty():
			return true
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, level_1).is_empty()

	one.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			any_monster).is_empty()

	one.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, any_monster)
		var paid := EffectPrimitives.pay_send_to_gy_cost(ctx, candidates, 1,
			"Send 1 monster from your hand to the GY")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "sent", paid)
		return true

	one.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, level_1)
		candidates.append_array(
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, level_1))
		var summoned := EffectPrimitives.special_summon_one_any_position(ctx, candidates,
			"Special Summon 1 Level 1 monster from your hand or Deck")
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())
		# "If a card effect requires you to reveal cards from your Deck, or look through
		# it, shuffle it and put it back." [S1 p.5]
		ctx.state.shuffle_deck(ctx.controller_id)

	return [one]

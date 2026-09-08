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
##   7. **A monster that is the ONLY way to carry out the effect may not be used as the
##      cost.** Official Konami supplemental information, cid 8197 (2020-03-20,
##      `request_locale=ja`):
##
##        ■処理を行えるようにコストのモンスターを墓地へ送る必要があります。レベル１の
##        モンスターが自分のデッキに存在せず、自分の手札に１体のみ存在する状況では、
##        そのモンスターをコストにできません。
##
##      *You must send the cost monster to the Graveyard in such a way that the effect can
##      be carried out. Where no Level 1 monster is in your Deck and only one is in your
##      hand, that monster cannot be used as the cost.*
##
##      This CORRECTS what this file used to say and what `OneForOneTests` used to assert
##      — that sending your last Level 1 monster was legal and "legitimately resolved for
##      nothing". It is not legal. CARD_RULINGS.md **R42 Part D**, RULES_SPEC.md **10.5**.
##
##      The restriction is on the COST CANDIDATE LIST, not on the activation: with a Level
##      1 monster in hand or Deck the activation stays legal, and only the set of monsters
##      that may be spent shrinks. When that shrinks to nothing — the last Level 1 monster
##      is also the only monster in hand — there is no payable cost and the card is not
##      offered at all.
##
##      Expressed through the general primitive
##      `EffectPrimitives.cost_candidates_keeping_effect_performable()` rather than inline,
##      and fed the SAME `has_summonable_level_1` predicate the activation condition uses,
##      so the two can never drift apart.
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

	# Detail 4/5/7: the ONE question "can this card still Summon something?", asked with a
	# set of cards treated as already spent. `spent` empty is the activation condition;
	# `spent` holding a proposed cost is the detail-7 legality check. One predicate, so the
	# condition and the cost filter cannot disagree.
	var has_summonable_level_1 := func(ctx: EffectContext, spent: Array) -> bool:
		for entry in EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, level_1):
			if not spent.has(entry):
				return true
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, level_1).is_empty()

	# Detail 7: the monsters in hand that may legally be SPENT — every monster, less any
	# whose loss would leave nothing to Summon. Deliberately not a second copy of the rule.
	var payable_candidates := func(ctx: EffectContext) -> Array:
		return EffectPrimitives.cost_candidates_keeping_effect_performable(ctx,
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, any_monster), 1,
			has_summonable_level_1)

	one.condition = func(ctx: EffectContext) -> bool:
		if not ctx.me().has_free_monster_zone():
			return false
		return bool(has_summonable_level_1.call(ctx, []))

	one.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not (payable_candidates.call(ctx) as Array).is_empty()

	one.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates: Array = payable_candidates.call(ctx)
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

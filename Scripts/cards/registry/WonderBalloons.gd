extends RefCounted

## Wonder Balloons — the V1 pool's only CONTINUOUS SPELL.
##
## Official text (verified against the Konami card database, cid 11387):
##
##   "Once per turn: You can send any number of cards from your hand to the GY; place 1
##    Balloon Counter on this card for each card sent to the GY. All monsters your opponent
##    controls lose 300 ATK for each Balloon Counter on this card."
##
## THREE EffectDefs for two printed sentences. The extra one is the activation of the
## Continuous Spell itself, which has no printed effect; the two printed sentences are a
## once-per-turn effect and a continuous effect, and this engine models those as separate
## clauses because one starts a Chain and the other never does (RULES_SPEC.md 8).
##
## Details this implementation accounts for:
##
##   1. The send is a **COST** (before the semicolon), so it is paid at ACTIVATION and is
##      not refunded if the effect is negated — but the counters are the EFFECT, so a
##      negated activation sends the cards and places no counters. Both halves are tested.
##   2. "**Any number** of cards" is the player's choice, not the card's, so it cannot use
##      `choose_n`. The minimum is ONE: "any number" still has to send something, and this
##      card measures its own effect by how many were sent, so a payment of nothing would
##      be a cost that pays for nothing. `EffectPrimitives.pay_send_any_number_to_gy_cost`.
##   3. "**For each card sent to the GY**" is read from what the cost actually consumed,
##      carried on the Chain Link — not recounted from the Graveyard, where the cards are
##      indistinguishable from everything else already there. Making that payload reach
##      resolution was an engine fix; see PROJECT_STATE.md §4.
##   4. "Any number of **cards**", not "monsters" — a Spell or Trap in your hand is a legal
##      thing to send, and the tests assert that.
##   5. The continuous clause hits "**all** monsters your opponent controls", face-down
##      ones included: the text has no face-up qualifier, and a monster that is later
##      flipped face-up must already be at the reduced ATK.
##   6. It scales with the counters currently on this card, so it follows them up and down
##      on every recompute and disappears entirely with the card — counters are cleared when
##      a card leaves the field (`CardInstance.on_leave_field()`).
##   7. ATK never goes below 0 (`CardInstance.current_atk()` floors it), which matters here
##      more than anywhere else in the pool.

const CARD_NAME := "Wonder Balloons"

const CLAUSE_ACTIVATION := "Activate this Continuous Spell Card. (It has no effect on " \
	+ "activation; it remains on the field.)"
const CLAUSE_PLACE := "Once per turn: You can send any number of cards from your hand to " \
	+ "the GY; place 1 Balloon Counter on this card for each card sent to the GY."
const CLAUSE_DRAIN := "All monsters your opponent controls lose 300 ATK for each Balloon " \
	+ "Counter on this card."

const BALLOON_COUNTER := "Balloon Counter"
const ATK_LOSS_PER_COUNTER := 300


func effects() -> Array:
	return [_activation(), _place_counters(), _drain_opponent_monsters()]


func _activation() -> EffectDef:
	var e := EffectDef.new("activate_wonder_balloons", CLAUSE_ACTIVATION)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS1)
	# A Continuous Spell is activated from the hand, or from a copy Set earlier. A Spell
	# that is not a Quick-Play may be activated the same turn it was Set [S1 p.31], which
	# `ActivationRules.set_turn_ok()` already encodes.
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	e.resolve = func(ctx: EffectContext) -> void:
		# No printed activation effect. A Continuous Spell stays face-up on the field
		# afterwards [S1 p.29], which is what makes the other two clauses reachable.
		ctx.log_note("remains face-up on the field")

	return e


func _place_counters() -> EffectDef:
	var e := EffectDef.new("send_hand_place_balloon_counters", CLAUSE_PLACE)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# No "(Quick Effect)": Spell Speed 1, its controller's own Main Phase [S1 p.10, p.44].
	e.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	e.opt_instance()

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		# "any number" with a minimum of one, so one card in hand is enough.
		return not ctx.me().hand.is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			func(_card: CardInstance) -> bool: return true)
		var paid := EffectPrimitives.pay_send_any_number_to_gy_cost(ctx, candidates,
			"Send any number of cards from your hand to the Graveyard (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var sent := EffectPrimitives.cost_card_count(ctx)
		if sent <= 0:
			ctx.log_note("no cards were sent, so no counters are placed")
			return
		# `place_counters()` refuses a card that is not face-up on the field, so a copy
		# removed between activation and resolution correctly places nothing.
		if not ctx.state.place_counters(ctx.source, BALLOON_COUNTER, sent, ctx.source.id):
			ctx.log_note("this card is no longer face-up on the field")
			return
		ctx.log_note("placed %d Balloon Counter(s)" % sent)

	return e


func _drain_opponent_monsters() -> EffectDef:
	var e := EffectDef.new("opponent_monsters_lose_atk", CLAUSE_DRAIN)
	e.of_type(Enums.EffectType.CONTINUOUS)

	e.apply_continuous = func(ctx: EffectContext) -> void:
		var counters := ctx.state.total_counters(ctx.source, BALLOON_COUNTER)
		if counters <= 0:
			return
		var loss := ATK_LOSS_PER_COUNTER * counters
		# "ALL monsters your opponent controls" — face-down ones too. The text carries no
		# face-up qualifier, and a monster flipped face-up later must already be reduced.
		for entry in ctx.state.player(ctx.opponent_id()).monsters():
			var monster: CardInstance = entry
			ContinuousEffects.add_atk(ctx.source, monster, -loss)

	return e

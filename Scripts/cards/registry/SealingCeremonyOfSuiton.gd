extends RefCounted

## Sealing Ceremony of Suiton — Continuous Trap.
##
## Official text (verified against the Konami card database, cid 9798):
##
##   "Once per turn: You can send 1 WATER monster from your hand to the GY, then target 1
##    card in your opponent's GY; banish that target."
##
## TWO EffectDefs for one printed clause. The extra one is the activation of the Trap
## itself: a Continuous Trap has to be activated to reach the field, and this card's
## activation has no printed effect. The printed clause is a once-per-turn effect of the
## card while it sits face-up, not the activation.
##
## Details this implementation accounts for:
##
##   1. The send is a **COST** — it sits before the semicolon and before "then target",
##      which is where PSCT puts costs. It is paid at ACTIVATION and stays paid if the
##      effect is later negated.
##   2. "**Send** 1 WATER monster from your hand to the GY" is not a discard.
##      `MoveReason.SENT_AS_COST` is what distinguishes them [S1 p.52-53], and
##      `EffectPrimitives.pay_send_to_gy_cost` already encodes exactly that — its semantics
##      match this clause, so it is reused rather than re-implemented.
##   3. "1 **card** in your opponent's GY" is any card, not just a monster: a Spell or Trap
##      in their Graveyard is a legal target and the tests assert it.
##   4. "in your **opponent's** GY" — your own Graveyard is out of reach.
##   5. "Banish that target" is an EFFECT, not a cost, and is re-checked at resolution: a
##      target that already left the Graveyard is not chased into its new zone.
##      Master prompt 44.
##   6. Banishing is not sending to the Graveyard [S1 p.53]: the card leaves for the
##      banished zone and emits `CARD_BANISHED`, never `CARD_SENT_TO_GY`.
##   7. "Once per turn" with no "You can only use this effect of …" wording is a soft
##      once-per-turn on this COPY, so a second copy on the field has its own use.

const CARD_NAME := "Sealing Ceremony of Suiton"

const CLAUSE_ACTIVATION := "Activate this Continuous Trap Card. (It has no effect on " \
	+ "activation; it remains on the field.)"
const CLAUSE_BANISH := "Once per turn: You can send 1 WATER monster from your hand to " \
	+ "the GY, then target 1 card in your opponent's GY; banish that target."

const WATER := "WATER"


func effects() -> Array:
	return [_activation(), _banish_from_opponent_graveyard()]


func _activation() -> EffectDef:
	var e := EffectDef.new("activate_sealing_ceremony_of_suiton", CLAUSE_ACTIVATION)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]

	e.resolve = func(ctx: EffectContext) -> void:
		# No printed activation effect. A Continuous Trap stays face-up on the field
		# afterwards [S1 p.29-30], which is the whole point of activating it.
		ctx.log_note("remains face-up on the field")

	return e


func _banish_from_opponent_graveyard() -> EffectDef:
	var e := EffectDef.new("send_water_banish_from_opponent_gy", CLAUSE_BANISH)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# No "(Quick Effect)" and no "During either player's turn": Spell Speed 1, its
	# controller's own Main Phase [S1 p.10, p.44].
	e.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	e.opt_instance()
	e.targeting(1)

	var water_monster := EffectPrimitives.monster_filter(WATER)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		# "1 card" — every card in their Graveyard, monsters and Spell/Traps alike.
		return EffectPrimitives.cards_in(ctx, ctx.opponent_id(), Enums.Zone.GRAVEYARD,
			func(_card: CardInstance) -> bool: return true)

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND,
			water_monster).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, water_monster)
		var paid := EffectPrimitives.pay_send_to_gy_cost(ctx, candidates, 1,
			"Send 1 WATER monster from your hand to the Graveyard (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var banished := EffectPrimitives.banish_target(ctx, Enums.Zone.GRAVEYARD)
		if banished != null:
			ctx.log_note("banished %s" % banished.card_name())

	return e

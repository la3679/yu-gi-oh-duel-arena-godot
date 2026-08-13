extends RefCounted

## Castle of Dragon Souls — CONTINUOUS TRAP. It is **not** an Equip Card and it equips
## nothing; an earlier plan mis-grouped it with the Equip batch and that grouping was
## corrected (PROJECT_STATE.md §7).
##
## Official text (verified against the Konami card database, cid 10592, see
## Data/generated/konami_cards.json):
##
##   "Once per turn: You can banish 1 Dragon monster from your GY, then target 1 monster
##    you control; it gains 700 ATK until the end of this turn (even if this card leaves
##    the field). When this face-up card on the field is sent to the GY: You can target 1
##    of your banished Dragon monsters; Special Summon that target. You can only control 1
##    'Castle of Dragon Souls'."
##
## Research/CARD_RULINGS.md R19.
##
## FOUR EffectDefs for three printed clauses. The extra one is the activation of the Trap
## itself: a Continuous Trap has to be activated to reach the field, and this card's
## activation has no printed effect of its own. Writing it as a real clause with an honest
## empty resolution is the alternative to pretending the first printed clause is the
## activation — which it is not, because it is once per turn and usable long afterwards.
##
## Details this implementation accounts for:
##
##   1. The banish is a **COST**, not an effect. PSCT puts the cost before the semicolon
##      and before "then target"; `Research/CARD_RULINGS.md §3` lists this card under
##      "Banish as cost". It is therefore paid at ACTIVATION and is never refunded — it
##      stays paid when the effect is negated.
##   2. Banishing is not sending to the Graveyard [S1 p.53], so the cost uses
##      `pay_banish_cost` rather than the send-to-GY cost, and the banished Dragon becomes
##      a legal target for this card's own second clause.
##   3. "It gains 700 ATK **until the end of this turn (even if this card leaves the
##      field)**" — a turn-scoped modifier, NOT a continuous one. A continuous modifier is
##      state-derived and would vanish the instant the Trap left the field, which is exactly
##      what the parenthesis forbids.
##   4. The second clause is keyed on being sent to the GY **for any reason** and requires
##      the card to have been **face-up on the field** at the time. A copy discarded from
##      the hand, or one that was banished rather than sent to the GY, does not qualify.
##   5. "Special Summon that target" names no position, so the summoning player chooses one
##      of the two face-up positions. RULES_SPEC.md 5.5.
##   6. "You can only control 1" is a rules-layer QUESTION answered by effect id
##      (`SummonRules.CONTROL_LIMIT_EFFECT_ID`), not by reading text. This is the pool's
##      only Spell/Trap that carries one, and enforcing it required
##      `ActivationRules.can_activate()` to start asking — see PROJECT_STATE.md §4.

const CARD_NAME := "Castle of Dragon Souls"

const CLAUSE_ACTIVATION := "Activate this Continuous Trap Card. (It has no effect on " \
	+ "activation; it remains on the field.)"
const CLAUSE_BOOST := "Once per turn: You can banish 1 Dragon monster from your GY, then " \
	+ "target 1 monster you control; it gains 700 ATK until the end of this turn (even if " \
	+ "this card leaves the field)."
const CLAUSE_RECOVER := "When this face-up card on the field is sent to the GY: You can " \
	+ "target 1 of your banished Dragon monsters; Special Summon that target."
const CLAUSE_CONTROL_LIMIT := "You can only control 1 \"Castle of Dragon Souls\"."

const ATK_GAIN := 700
const DRAGON := "Dragon"


func effects() -> Array:
	return [_activation(), _atk_boost(), _recover_banished_dragon(), _control_limit()]


func _activation() -> EffectDef:
	var e := EffectDef.new("activate_castle_of_dragon_souls", CLAUSE_ACTIVATION)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	# The "cannot be activated the turn it was Set" rule is enforced once, in
	# ActivationRules.set_turn_ok() [S1 p.30].

	e.resolve = func(ctx: EffectContext) -> void:
		# Nothing to do. The card has no printed activation effect; the whole point of the
		# activation is that a Continuous Trap stays face-up on the field afterwards
		# [S1 p.29-30], which `Enums.stays_on_field()` handles. This is a real, complete
		# resolution rather than a placeholder.
		ctx.log_note("remains face-up on the field")

	return e


func _atk_boost() -> EffectDef:
	var e := EffectDef.new("banish_dragon_for_700_atk", CLAUSE_BOOST)
	e.of_type(Enums.EffectType.IGNITION)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# An Ignition Effect: the printed text carries no "(Quick Effect)" and no "During
	# either player's turn", so it is Spell Speed 1 and belongs to its controller's own
	# Main Phase [S1 p.10, p.44]. `card_activation_timing_ok` does not gate a non-activation
	# effect, so the phase restriction is declared here.
	e.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	e.opt_instance()
	e.targeting(1)
	e.ruling("R19")

	var dragon_monster := EffectPrimitives.monster_filter("", -1, -1, DRAGON)

	# "1 monster you control" — no face-up requirement, so a Set monster qualifies too.
	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.MONSTER_ZONE,
			func(card: CardInstance) -> bool: return card.is_monster())

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD,
			dragon_monster).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD,
			dragon_monster)
		var paid := EffectPrimitives.pay_banish_cost(ctx, candidates, 1,
			"Banish 1 Dragon monster from your Graveyard (cost)")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		# Activation legality is not carried forward: a target that left the Monster Zone
		# is no longer something this clause can give ATK to. Master prompt 44.
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
		if target == null:
			ctx.log_note("the target is no longer a monster on the field")
			return
		EffectPrimitives.gain_atk_until_end_of_turn(ctx, target, ATK_GAIN)
		ctx.log_note("%s gains %d ATK until the end of this turn"
			% [target.card_name(), ATK_GAIN])

	return e


func _recover_banished_dragon() -> EffectDef:
	var e := EffectDef.new("special_summon_banished_dragon", CLAUSE_RECOVER)
	e.of_type(Enums.EffectType.TRIGGER)
	# Optional: "You can target". The controller is asked, and "no" activates nothing.
	e.on_events([GameEvent.Kind.CARD_SENT_TO_GY])
	# By the time this can be activated the card is already in the Graveyard.
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	# This card can be destroyed during the Damage Step, and the rules require the trigger
	# to happen there. The permission is about TIMING, not optionality — RULES_SPEC.md 7.2
	# and PROJECT_STATE.md design decision 5.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)
	e.targeting(1)
	e.ruling("R19")

	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.event_is_sent_to_gy_from_face_up_field(
			ctx.trigger_event, ctx.source)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.BANISHED,
			EffectPrimitives.monster_filter("", -1, -1, DRAGON))

	e.resolve = func(ctx: EffectContext) -> void:
		var summoned := EffectPrimitives.special_summon_target(ctx, Enums.Zone.BANISHED)
		if summoned != null:
			ctx.log_note("Special Summoned %s from banishment" % summoned.card_name())

	return e


func _control_limit() -> EffectDef:
	var e := EffectDef.new(SummonRules.CONTROL_LIMIT_EFFECT_ID, CLAUSE_CONTROL_LIMIT)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP,
		Enums.ActivationLocation.FIELD_FACE_DOWN, Enums.ActivationLocation.HAND]

	# A rules-layer query: it applies nothing to the board and is PURE, so it never spends
	# a use or writes state. PROJECT_STATE.md design decision 20.
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.controls_no_other_copy(ctx)

	return e

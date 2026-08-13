extends RefCounted

## Nefarious Archfiend Eater of Nefariousness — Level 4 EARTH Beast Effect Monster,
## 1500 / 200.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "You can only control 1 'Nefarious Archfiend Eater of Nefariousness'. If you control
##    a Spellcaster monster, you can Special Summon this card (from your hand). Once per
##    turn, during your opponent's End Phase, if this card is in your GY: You can target
##    1 face-up monster you control; destroy it, and if you do, Special Summon this card."
##
## Three official clauses, so three EffectDefs. Research/CARD_RULINGS.md R17.
##
##   1. "You can only control 1" — see `InariFire` for how the limit is enforced.
##   2. The summoning PROCEDURE is worded identically to `Inari Fire`'s and `Ranryu`'s.
##   3. The third clause is a Graveyard-activated Trigger Effect with an unusual timing —
##      it activates during the OPPONENT's End Phase, i.e. this card's controller acts on
##      a turn that is not theirs. It is optional, once per turn, and it TARGETS.
##   4. "destroy it, AND IF YOU DO, Special Summon this card" is conditional on the
##      destruction actually happening. A target that is gone by resolution, or that
##      cannot be destroyed, means no Special Summon — the two halves are not
##      independent. That is also why the free Monster Zone is checked AFTER the
##      destruction: destroying your own monster is what makes room for this one.

const CARD_NAME := "Nefarious Archfiend Eater of Nefariousness"

const PROCEDURE_ID := "ss_if_you_control_a_spellcaster"

const CLAUSE_CONTROL_LIMIT := "You can only control 1 \"Nefarious Archfiend Eater of " \
	+ "Nefariousness\"."
const CLAUSE_PROCEDURE := "If you control a Spellcaster monster, you can Special Summon " \
	+ "this card (from your hand)."
const CLAUSE_GY_EFFECT := "Once per turn, during your opponent's End Phase, if this " \
	+ "card is in your GY: You can target 1 face-up monster you control; destroy it, " \
	+ "and if you do, Special Summon this card."


func effects() -> Array:
	return [_control_limit(), _procedure(), _end_phase_revival()]


func _control_limit() -> EffectDef:
	var e := EffectDef.new(SummonRules.CONTROL_LIMIT_EFFECT_ID, CLAUSE_CONTROL_LIMIT)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.controls_no_other_copy(ctx)
	return e


func _procedure() -> EffectDef:
	var e := EffectDef.new(PROCEDURE_ID, CLAUSE_PROCEDURE)
	e.of_type(Enums.EffectType.SUMMON_PROCEDURE)
	e.from_locations([Enums.ActivationLocation.HAND])
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.controls_face_up_monster_of_race(ctx, "Spellcaster")
	return e


func _end_phase_revival() -> EffectDef:
	var e := EffectDef.new("opponent_end_phase_self_revival", CLAUSE_GY_EFFECT)
	e.of_type(Enums.EffectType.TRIGGER)
	# "You can" — optional, so its controller is asked. Master prompt 24.
	e.on_events([GameEvent.Kind.PHASE_CHANGED])
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	e.in_phases([Enums.Phase.END])
	e.opt_instance()
	e.targeting(1)
	e.ruling("R17")

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return ctx.me().face_up_monsters()

	e.condition = func(ctx: EffectContext) -> bool:
		# "during your OPPONENT's End Phase" — the turn player is not this card's owner.
		return EffectPrimitives.event_is_phase_change_to(ctx.trigger_event,
			Enums.Phase.END, ctx.opponent_id())

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
		if target == null or not target.is_face_up() \
				or target.controller_id != ctx.controller_id:
			ctx.log_note("the target is no longer a face-up monster you control")
			return
		if not ctx.state.destroy(target, Enums.MoveReason.DESTROYED_BY_EFFECT,
				ctx.source.id):
			# "AND IF YOU DO" — no destruction, no Special Summon.
			ctx.log_note("the target was not destroyed, so nothing is Special Summoned")
			return
		if EffectPrimitives.special_summon_self(ctx, Enums.Zone.GRAVEYARD):
			ctx.log_note("destroyed %s and Special Summoned itself" % target.card_name())

	return e

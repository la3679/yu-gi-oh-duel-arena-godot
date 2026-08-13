extends RefCounted

## Inari Fire — Level 4 FIRE Pyro Effect Monster, 1500 / 200.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "You can only control 1 'Inari Fire'. If you control a Spellcaster monster, you can
##    Special Summon this card (from your hand). Once per turn, during your next Standby
##    Phase after this face-up card on the field was destroyed by card effect and sent to
##    the GY: Special Summon it from your GY."
##
## Three official clauses, so three EffectDefs. Research/CARD_RULINGS.md R18.
##
##   1. "You can only control 1" is a real restriction, not flavour: it is enforced on
##      EVERY route onto the field (Normal Summon, Set, this card's own procedure, and a
##      Special Summon by another card such as `Monster Reborn`), because the limit is on
##      what you CONTROL [S1 p.53]. `SummonRules.CONTROL_LIMIT_EFFECT_ID` is the
##      convention that hooks it into the rules layer.
##   2. The second clause is a summoning PROCEDURE — see the notes on
##      `HieraticDragonOfTefnuit` and PROJECT_STATE.md design decision 9.
##   3. The third clause is a DELAYED trigger with four independent requirements, and
##      each one is a way for it not to fire:
##        * the card was FACE-UP ON THE FIELD when it left, so a copy destroyed in the
##          hand or flipped face-down first does not qualify;
##        * it was DESTROYED BY CARD EFFECT — not by battle, not Tributed, not sent to
##          the GY by an effect that does not destroy, and not the rules destruction that
##          kills an Equip Card [S1 p.52-53];
##        * it reached the GY, and is still there when the trigger would activate;
##        * the timing is YOUR NEXT Standby Phase — the first Standby Phase of your own
##          next turn, not merely some later one.
##      Those facts are read from `CardInstance.last_move_*`, which `GameState.move_card()`
##      records AFTER `on_leave_field()` precisely so they survive the move that makes
##      them relevant. RULES_SPEC.md 15.

const CARD_NAME := "Inari Fire"

const PROCEDURE_ID := "ss_if_you_control_a_spellcaster"

const CLAUSE_CONTROL_LIMIT := "You can only control 1 \"Inari Fire\"."
const CLAUSE_PROCEDURE := "If you control a Spellcaster monster, you can Special Summon " \
	+ "this card (from your hand)."
const CLAUSE_STANDBY_REVIVAL := "Once per turn, during your next Standby Phase after " \
	+ "this face-up card on the field was destroyed by card effect and sent to the GY: " \
	+ "Special Summon it from your GY."


func effects() -> Array:
	return [_control_limit(), _procedure(), _standby_revival()]


func _control_limit() -> EffectDef:
	var e := EffectDef.new(SummonRules.CONTROL_LIMIT_EFFECT_ID, CLAUSE_CONTROL_LIMIT)
	e.of_type(Enums.EffectType.CONTINUOUS)
	# A rules QUERY, not a modifier: it answers "may this copy reach your field?" and
	# applies nothing to the board, which is why it has no apply_continuous().
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


func _standby_revival() -> EffectDef:
	var e := EffectDef.new("standby_phase_self_revival", CLAUSE_STANDBY_REVIVAL)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.PHASE_CHANGED])
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	e.in_phases([Enums.Phase.STANDBY])
	e.opt_instance()
	e.ruling("R18")

	e.condition = func(ctx: EffectContext) -> bool:
		var card := ctx.source
		if not EffectPrimitives.event_is_phase_change_to(ctx.trigger_event,
				Enums.Phase.STANDBY, ctx.controller_id):
			return false
		if not ctx.me().has_free_monster_zone():
			return false
		# "this FACE-UP card ON THE FIELD was DESTROYED BY CARD EFFECT and sent to the GY"
		if not card.last_move_was_face_up:
			return false
		if not Enums.is_on_field_zone(card.last_move_from_zone):
			return false
		if card.last_move_reason != Enums.MoveReason.DESTROYED_BY_EFFECT:
			return false
		# "your NEXT Standby Phase" — the first Standby Phase of your own next turn. Turns
		# strictly alternate between two players, so the turn number that qualifies is
		# fully determined by whose turn the destruction happened on.
		var gap := 2 if card.last_move_turn_player_id == ctx.controller_id else 1
		return ctx.state.turn_number == card.last_move_turn + gap

	e.resolve = func(ctx: EffectContext) -> void:
		if EffectPrimitives.special_summon_self(ctx, Enums.Zone.GRAVEYARD):
			ctx.log_note("Special Summoned itself from the Graveyard")

	return e

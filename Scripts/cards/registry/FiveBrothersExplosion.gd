extends RefCounted

## Five Brothers Explosion — Continuous Trap.
##
## Official text (verified against the Konami card database, cid 10603):
##
##   "When this card is activated: Gain 500 LP for each Continuous Spell/Trap Card you
##    control. If this face-up card you control is sent to your Graveyard by your
##    opponent's card effect: Inflict 500 damage to your opponent for each Continuous
##    Spell/Trap Card in your Graveyard."
##
## Research/CARD_RULINGS.md R16.
##
## Two printed clauses, two EffectDefs. Unlike the pool's other Continuous Traps this card's
## activation DOES have a printed effect, so no extra activation clause is needed.
##
## Details this implementation accounts for:
##
##   1. "When this card is activated: Gain 500 LP …" is the resolution of the card's OWN
##      activation, so by then the card is already face-up on the field [S1 p.28-30] and
##      **counts itself**. The tests assert this directly rather than leaving it implied.
##   2. "each Continuous Spell/Trap Card **you control**" counts FACE-UP cards only. A Set
##      Spell/Trap is face-down and its specific subtype is not a property either player may
##      act on. See `EffectPrimitives.continuous_spell_traps_controlled()` for the reasoning
##      and Research/CARD_RULINGS.md R16 for the recorded decision.
##   3. The second clause is THREE separate requirements and each one is tested negatively:
##        * this **face-up** card **you control** — a face-down copy, or one that was never
##          on the field, does not qualify;
##        * **sent to your Graveyard** — banished or bounced does not count [S1 p.53];
##        * **by your opponent's card effect** — destruction by BATTLE does not count, a
##          rules destruction does not count, and neither does your OWN card effect.
##      The agent is read from the movement's `source_id`, which is why
##      `EffectPrimitives.event_caused_by_effect_of()` asks who controls that card rather
##      than guessing from the move reason alone.
##   4. The second clause has no "You can", so it is MANDATORY.
##   5. "each Continuous Spell/Trap Card **in your Graveyard**" — every card in a Graveyard
##      is public, so there is no face-up filter there; and this card has just arrived, so
##      it counts itself again. Both are asserted.

const CARD_NAME := "Five Brothers Explosion"

const CLAUSE_GAIN_LP := "When this card is activated: Gain 500 LP for each Continuous " \
	+ "Spell/Trap Card you control."
const CLAUSE_BURN := "If this face-up card you control is sent to your Graveyard by your " \
	+ "opponent's card effect: Inflict 500 damage to your opponent for each Continuous " \
	+ "Spell/Trap Card in your Graveyard."

const LP_PER_CARD := 500
const DAMAGE_PER_CARD := 500


func effects() -> Array:
	return [_gain_life_points(), _burn_from_graveyard()]


func _gain_life_points() -> EffectDef:
	var e := EffectDef.new("gain_lp_per_continuous", CLAUSE_GAIN_LP)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R16")

	e.resolve = func(ctx: EffectContext) -> void:
		var counted := EffectPrimitives.continuous_spell_traps_controlled(
			ctx.state, ctx.controller_id)
		var gain := LP_PER_CARD * counted.size()
		if gain <= 0:
			# Only reachable if this card somehow left the field before its own activation
			# resolved. It is a legitimate resolution of nothing, not an error.
			ctx.log_note("no Continuous Spell/Trap Cards to count")
			return
		ctx.state.change_life_points(ctx.controller_id, gain,
			"Five Brothers Explosion", ctx.source.id)
		ctx.log_note("gained %d LP for %d Continuous Spell/Trap Card(s)"
			% [gain, counted.size()])

	return e


func _burn_from_graveyard() -> EffectDef:
	var e := EffectDef.new("burn_per_continuous_in_gy", CLAUSE_BURN)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.CARD_SENT_TO_GY])
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	# An opponent's effect can send this card to the Graveyard during the Damage Step, and
	# the rules require the trigger to happen there. RULES_SPEC.md 7.2 — the permission is
	# about TIMING, not optionality.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)
	e.ruling("R16")

	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if not EffectPrimitives.event_is_sent_to_gy_from_face_up_field(ev, ctx.source):
			return false
		# "this face-up card YOU CONTROL … sent to YOUR Graveyard".
		if int(ev.data.get("from_player", -1)) != ctx.controller_id:
			return false
		if int(ev.data.get("to_player", -1)) != ctx.controller_id:
			return false
		# "by your OPPONENT'S CARD EFFECT".
		return EffectPrimitives.event_caused_by_effect_of(ctx.state, ev, ctx.opponent_id())

	e.resolve = func(ctx: EffectContext) -> void:
		var counted := EffectPrimitives.continuous_spell_traps_in_graveyard(
			ctx.state, ctx.controller_id)
		var damage := DAMAGE_PER_CARD * counted.size()
		if damage <= 0:
			ctx.log_note("no Continuous Spell/Trap Cards in the Graveyard to count")
			return
		ctx.state.change_life_points(ctx.opponent_id(), -damage,
			"Five Brothers Explosion", ctx.source.id)
		# Effect damage can end the Duel, and `change_life_points()` deliberately does not
		# decide that for itself — the caller does, exactly as the battle path does.
		ctx.state.check_life_point_loss()
		ctx.log_note("inflicted %d damage for %d Continuous Spell/Trap Card(s)"
			% [damage, counted.size()])

	return e

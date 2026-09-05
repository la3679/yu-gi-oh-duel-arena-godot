extends RefCounted

## Current official cid 5099 text; R7 decided in CARD_RULINGS.md R39.
## RULES_SPEC.md 5.9. This is material permission, NEVER a control change.
const CARD_NAME := "Soul Exchange"

func effects() -> Array:
	var exchange := EffectDef.new("require_opponent_tribute", "Target 1 monster your opponent controls; this turn, if you Tribute a monster, you must Tribute that target, as if you controlled it.")
	exchange.of_type(Enums.EffectType.CARD_ACTIVATION).targeting(1).ruling("R39")
	exchange.activation_locations = [Enums.ActivationLocation.HAND, Enums.ActivationLocation.FIELD_FACE_DOWN]
	exchange.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.opponent_monsters(ctx)
	exchange.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_opponent_field_target(ctx)
		if target != null and target.is_monster() and EffectPrimitives.target_kept_field_identity(ctx, target):
			ctx.state.require_choice_this_turn(ctx.controller_id, SummonRules.TRIBUTE_CHOICE_SCOPE, target, ctx.source.id)

	var battle := EffectDef.new(ActivationRules.ACTIVATION_CONDITION_EFFECT_ID, "You cannot conduct your Battle Phase the turn you activate this card.")
	battle.of_type(Enums.EffectType.CONTINUOUS).ruling("R39")
	battle.condition = func(ctx: EffectContext) -> bool:
		return not ctx.state.battle_phase_conducted_this_turn
	battle.activation_confirmed = func(ctx: EffectContext) -> void:
		ctx.me().set_restriction("skip_battle_phase_this_turn", true)
	return [exchange, battle]

extends RefCounted

## Ranryu — Level 4 WIND Dragon Effect Monster, 1500 / 200.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "You can only control 1 'Ranryu'. If you control a Spellcaster monster, you can
##    Special Summon this card (from your hand). If this card is destroyed by battle or
##    card effect and sent to the GY: You can target 1 monster with 1500 ATK/200 DEF in
##    your GY, except 'Ranryu'; Special Summon it."
##
## Three official clauses, so three EffectDefs.
##
##   1. "You can only control 1" — see `InariFire` for how the limit is enforced.
##   2. The summoning PROCEDURE is identical in wording to `Inari Fire`'s and
##      `Nefarious Archfiend Eater of Nefariousness`'s, so all three share
##      `EffectPrimitives.controls_face_up_monster_of_race`.
##   3. The third clause differs from `Inari Fire`'s in every dimension that matters:
##        * it is OPTIONAL ("You can"), so its controller is asked and may decline;
##        * it TARGETS, so the monster is fixed when the trigger activates, not at
##          resolution — RULES_SPEC.md 10;
##        * it fires on destruction BY BATTLE OR BY CARD EFFECT, which is why its window
##          has to be legal inside the Damage Step (the `Shining Angel` shape);
##        * it revives a DIFFERENT monster, not itself.
##   4. "1 monster with 1500 ATK/200 DEF" reads the PRINTED values: a monster in the
##      Graveyard carries no modifiers [S1 p.55]. "except 'Ranryu'" excludes by NAME, so a
##      second copy of Ranryu would be excluded too, not merely this instance.

const CARD_NAME := "Ranryu"

const PROCEDURE_ID := "ss_if_you_control_a_spellcaster"

const CLAUSE_CONTROL_LIMIT := "You can only control 1 \"Ranryu\"."
const CLAUSE_PROCEDURE := "If you control a Spellcaster monster, you can Special Summon " \
	+ "this card (from your hand)."
const CLAUSE_ON_DESTROYED := "If this card is destroyed by battle or card effect and " \
	+ "sent to the GY: You can target 1 monster with 1500 ATK/200 DEF in your GY, " \
	+ "except \"Ranryu\"; Special Summon it."


func effects() -> Array:
	return [_control_limit(), _procedure(), _on_destroyed()]


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


func _on_destroyed() -> EffectDef:
	var e := EffectDef.new("on_destroyed_revive_a_1500_200_monster", CLAUSE_ON_DESTROYED)
	e.of_type(Enums.EffectType.TRIGGER)
	# "You can" — optional, so TriggerCollector asks its controller and never fires it
	# silently. Master prompt 24.
	e.on_events([GameEvent.Kind.CARD_SENT_TO_GY])
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	e.targeting(1)
	# Destruction by battle happens inside the Damage Step, so this window must exist
	# there. The permission is about TIMING, not optionality — PROJECT_STATE.md decision 5.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	var twin := EffectPrimitives.monster_with_stats(1500, 200, CARD_NAME)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, twin)

	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null or int(ev.data.get("card_id", -1)) != ctx.source.id:
			return false
		var reason = ev.data.get("reason", null)
		# "destroyed by battle OR CARD EFFECT" — and nothing else. A Tribute, a cost, a
		# discard and the rules destruction of an Equip Card are all excluded.
		if reason != Enums.MoveReason.DESTROYED_BY_BATTLE \
				and reason != Enums.MoveReason.DESTROYED_BY_EFFECT:
			return false
		return ctx.me().has_free_monster_zone()

	e.resolve = func(ctx: EffectContext) -> void:
		var summoned := EffectPrimitives.special_summon_target(ctx, Enums.Zone.GRAVEYARD)
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())

	return e

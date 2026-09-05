extends RefCounted

## Kaibaman — LIGHT / Warrior / Level 3 / 200 ATK / 700 DEF.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "You can Tribute this card; Special Summon 1 'Blue-Eyes White Dragon' from your
##    hand."
##
## Details this implementation accounts for:
##
##   1. The semicolon splits COST from EFFECT. "Tribute this card" is a **cost**, so it
##      is paid the moment the effect is activated, before the Chain Link resolves and
##      whether or not the effect is later negated. RULES_SPEC.md 10, master prompt 16.
##   2. It is an **Ignition Effect**: Spell Speed 1, activated by its controller in an
##      open game state during their own Main Phase. `DuelEngine.get_legal_actions()`
##      already restricts open actions to the turn player, so only the phase is declared
##      here. [S1 p.10]
##   3. It does **not** target — there is no "target" in the text — so which copy of
##      "Blue-Eyes White Dragon" is Summoned is chosen at RESOLUTION. RULES_SPEC.md 10.
##   4. No position is named, so the summoning player chooses. RULES_SPEC.md 5.5.
##   5. A free Monster Zone is not a separate activation requirement here: the cost
##      Tributes Kaibaman itself, which always vacates the zone it occupied. The zone is
##      still re-checked at resolution, because a Chain Link resolving above this one can
##      fill it in the meantime.

const CARD_NAME := "Kaibaman"

const CLAUSE := "You can Tribute this card; Special Summon 1 \"Blue-Eyes White " \
	+ "Dragon\" from your hand."

const SUMMONS := "Blue-Eyes White Dragon"


func effects() -> Array:
	var fetch := EffectDef.new("tribute_self_summon_blue_eyes", CLAUSE)
	fetch.of_type(Enums.EffectType.IGNITION)
	fetch.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	fetch.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])

	var blue_eyes := EffectPrimitives.monster_named(SUMMONS)

	# "Special Summon 1 'Blue-Eyes White Dragon' from your hand" is the whole effect, so
	# with no copy in hand there is nothing the activation could do.
	fetch.condition = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, blue_eyes).is_empty()

	fetch.can_pay_cost = func(ctx: EffectContext) -> bool:
		return ctx.source.is_on_field() and ctx.source.is_face_up() and EffectPrimitives.can_pay_tribute_cost(ctx, [ctx.source], 1)

	fetch.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_tribute_cost(ctx, [ctx.source], 1,
			"Tribute Kaibaman")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "tributed", paid)
		return true

	fetch.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, blue_eyes)
		var summoned := EffectPrimitives.special_summon_one_any_position(ctx, candidates,
			"Special Summon 1 \"%s\" from your hand" % SUMMONS)
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())

	return [fetch]

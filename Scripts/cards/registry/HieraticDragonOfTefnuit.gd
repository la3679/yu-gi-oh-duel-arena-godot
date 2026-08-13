extends RefCounted

## Hieratic Dragon of Tefnuit — Level 6 LIGHT Dragon Effect Monster, 2100 / 1400.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "If only your opponent controls a monster, you can Special Summon this card (from
##    your hand). Cannot attack during the turn it is Special Summoned this way. When
##    this card is Tributed: Special Summon 1 Dragon Normal Monster from your hand, Deck,
##    or GY, and make its ATK/DEF 0."
##
## Three official clauses, so three EffectDefs.
##
##   1. The first is a summoning PROCEDURE, not an activated effect: "The conditions that
##      describe how to play a 'Special Summon Monster' are also not an effect" [S1 p.53].
##      It starts no Chain, cannot be responded to as an activation, and is offered as
##      `Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE` in an open game state — which DOES
##      open a Summon declaration window, so `Champion's Vigilance` can still negate the
##      Summon. PROJECT_STATE.md design decision 9, RULES_SPEC.md 5.5.
##   2. "If ONLY your opponent controls a monster" is both halves: they control at least
##      one AND you control none. Face-down monsters count — they are still monsters
##      their controller controls [S1 p.53].
##   3. "Cannot attack during the turn it is Special Summoned THIS WAY" is narrower than
##      "the turn it is Special Summoned": a copy revived by `Monster Reborn` or
##      `Call of the Haunted` may attack normally. CARD_RULINGS.md §2.1 records this as a
##      substantive erratum against the older wording, so it is implemented against
##      `CardInstance.summoned_by_procedure_id` rather than against `turn_summoned`.
##   4. "When this card is TRIBUTED" — a Tribute, specifically. A copy destroyed by
##      battle or sent to the GY by an effect does not fire it [S1 p.53].
##   5. The Tribute clause does NOT say "target", so the Dragon Normal Monster is chosen
##      at RESOLUTION, out of three zones at once. RULES_SPEC.md 10.
##   6. "make its ATK/DEF 0" overwrites the values rather than adding a modifier, so the
##      monster's ORIGINAL ATK is untouched [S1 p.55].

const CARD_NAME := "Hieratic Dragon of Tefnuit"

const PROCEDURE_ID := "ss_if_only_opponent_controls_a_monster"

const CLAUSE_PROCEDURE := "If only your opponent controls a monster, you can Special " \
	+ "Summon this card (from your hand)."
const CLAUSE_CANNOT_ATTACK := "Cannot attack during the turn it is Special Summoned " \
	+ "this way."
const CLAUSE_ON_TRIBUTE := "When this card is Tributed: Special Summon 1 Dragon Normal " \
	+ "Monster from your hand, Deck, or GY, and make its ATK/DEF 0."


func effects() -> Array:
	return [_procedure(), _cannot_attack(), _on_tributed()]


func _procedure() -> EffectDef:
	var e := EffectDef.new(PROCEDURE_ID, CLAUSE_PROCEDURE)
	e.of_type(Enums.EffectType.SUMMON_PROCEDURE)
	e.from_locations([Enums.ActivationLocation.HAND])

	e.condition = func(ctx: EffectContext) -> bool:
		# "ONLY your opponent controls a monster": they have one, and you have none.
		return ctx.opponent().monster_count() > 0 and ctx.me().monster_count() == 0

	return e


func _cannot_attack() -> EffectDef:
	var e := EffectDef.new("cannot_attack_the_turn_summoned_this_way", CLAUSE_CANNOT_ATTACK)
	e.of_type(Enums.EffectType.CONTINUOUS)

	e.apply_continuous = func(ctx: EffectContext) -> void:
		if EffectPrimitives.summoned_this_way_this_turn(ctx, PROCEDURE_ID):
			ContinuousEffects.restrict(ctx.source, "cannot_attack")

	return e


func _on_tributed() -> EffectDef:
	var e := EffectDef.new("on_tributed_summon_dragon_normal_monster", CLAUSE_ON_TRIBUTE)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.CARD_TRIBUTED])
	# Being Tributed puts this card in the Graveyard, which is where the trigger activates
	# from. A Tribute is "sent to the Graveyard" but is NOT a destruction [S1 p.53].
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])
	# A Tribute can be paid inside the Damage Step (`Enemy Controller`), and this trigger
	# is mandatory, so the rules require its timing to be available there.
	# RULES_SPEC.md 7.2, PROJECT_STATE.md design decision 5.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	var dragon_normal := EffectPrimitives.monster_filter("", -1, -1, "Dragon", true)

	var candidates := func(ctx: EffectContext) -> Array:
		var out := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, dragon_normal)
		out.append_array(EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, dragon_normal))
		out.append_array(
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, dragon_normal))
		return out

	e.condition = func(ctx: EffectContext) -> bool:
		if ctx.trigger_event == null:
			return false
		if int(ctx.trigger_event.data.get("card_id", -1)) != ctx.source.id:
			return false
		if not ctx.me().has_free_monster_zone():
			return false
		# A mandatory effect with nothing it could possibly do is not activated at all,
		# rather than activated and resolved into silence.
		return not (candidates.call(ctx) as Array).is_empty()

	e.resolve = func(ctx: EffectContext) -> void:
		var summoned := EffectPrimitives.special_summon_one_any_position(ctx,
			candidates.call(ctx),
			"Special Summon which Dragon Normal Monster from your hand, Deck or GY?")
		if summoned == null:
			return
		EffectPrimitives.set_atk_and_def(summoned, 0)
		ctx.log_note("Special Summoned %s with its ATK/DEF made 0" % summoned.card_name())

	return e

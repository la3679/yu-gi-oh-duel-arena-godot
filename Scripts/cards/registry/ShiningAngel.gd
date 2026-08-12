extends RefCounted

## Shining Angel — LIGHT / Fairy / Level 4 / 1400 ATK / 800 DEF.
## The one card that appears in BOTH V1 decks.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "When this card is destroyed by battle and sent to the GY: You can Special Summon
##    1 LIGHT monster with 1500 or less ATK from your Deck in Attack Position."
##
## One clause, and three details that are easy to get wrong:
##
##   1. It is a **Trigger Effect whose window is inside the Damage Step**. That is a
##      timing permission, not a statement that the effect is mandatory —
##      `DamageStepPermission.MANDATORY_TRIGGER` with `Optionality.OPTIONAL`.
##      RULES_SPEC.md 7.2 clarification.
##   2. "You can" makes it **optional**: the controller is asked, and silence is never
##      taken as yes.
##   3. It does **not** target — the text has no "target". The monster is therefore
##      chosen at RESOLUTION, not at activation. RULES_SPEC.md 10.

const CARD_NAME := "Shining Angel"

const CLAUSE := "When this card is destroyed by battle and sent to the GY: You can " \
	+ "Special Summon 1 LIGHT monster with 1500 or less ATK from your Deck in " \
	+ "Attack Position."


func effects() -> Array:
	var recruit := EffectDef.new("recruit_light_on_battle_destruction", CLAUSE)
	recruit.of_type(Enums.EffectType.TRIGGER)
	# It activates from the Graveyard: by the time the trigger is collected the card has
	# already been sent there in sub-step 5. [S1 p.41]
	recruit.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	recruit.trigger_events = [GameEvent.Kind.CARD_SENT_TO_GY]
	recruit.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER

	var search := EffectPrimitives.monster_filter("LIGHT", 1500)

	recruit.condition = func(ctx: EffectContext) -> bool:
		if not bool(EffectPrimitives.destroyed_by_battle_condition().call(ctx)):
			return false
		# Nothing to Summon and nowhere to put it means there is no effect to activate.
		if not ctx.me().has_free_monster_zone():
			return false
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, search).is_empty()

	recruit.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, search)
		var summoned := EffectPrimitives.special_summon_one(ctx, candidates,
			Enums.Position.FACE_UP_ATTACK,
			"Special Summon 1 LIGHT monster with 1500 or less ATK from your Deck")
		if summoned != null:
			ctx.log_note("Special Summoned %s" % summoned.card_name())
		# "If a card effect requires you to reveal cards from your Deck, or look through
		# it, shuffle it and put it back." [S1 p.5]
		ctx.state.shuffle_deck(ctx.controller_id)

	return [recruit]

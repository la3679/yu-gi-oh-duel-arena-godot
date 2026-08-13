extends RefCounted

## Apprentice Magician — DARK / Spellcaster / Level 2 / 400 ATK / 800 DEF.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "If this card is Summoned: Target 1 face-up card on the field that you can place a
##    Spell Counter on; place 1 Spell Counter on that target. When this card is destroyed
##    by battle: You can Special Summon 1 Level 2 or lower Spellcaster monster from your
##    Deck in face-down Defense Position."
##
## Two official clauses, so two EffectDefs, and they differ in almost every respect.
##
## Clause 1 — "If this card is Summoned"
##   * "If", not "When": it cannot miss the timing. The engine collects triggers from the
##     event batch at the next timing point, which already gives it that behaviour.
##   * "Summoned" with no qualifier covers a Normal Summon, a Flip Summon and a Special
##     Summon [S1 p.24]. A Normal SET is not a Summon and is deliberately absent.
##   * It is MANDATORY. There is no "You can", so the controller is never asked.
##   * It TARGETS, so the recipient is fixed at activation and re-checked at resolution.
##   * "that you can place a Spell Counter on" is a property of the TARGET, not of this
##     card. A card can hold Spell Counters only because some card text says it can, which
##     is what `GameState.COUNTER_CAPACITY_EFFECT_ID` declares and
##     `GameState.can_place_counter()` answers. **No card in the V1 pool declares Spell
##     Counter capacity**, so in a real duel between these two Decks this clause has no
##     legal target and is never activated. That is reported honestly rather than papered
##     over by widening the filter to "any face-up card": the wide reading would let the
##     card place a Spell Counter on a Blue-Eyes White Dragon, which is not the rule.
##     Research/CARD_RULINGS.md R21.
##   * "1 face-up CARD on the field" — either player's, and not restricted to monsters.
##
## Clause 2 — "When this card is destroyed by battle"
##   * OPTIONAL ("You can"), and its window is inside the Damage Step, which is a TIMING
##     permission rather than a statement about optionality — the same shape as
##     `Shining Angel`. RULES_SPEC.md 7.2 clarification.
##   * It activates from the GRAVEYARD: the card has already been sent there in sub-step 5
##     by the time the trigger is collected [S1 p.41].
##   * **Face-down Defense Position.** This is the one Special Summon in the pool that names
##     a face-down position, which is exactly why
##     `EffectPrimitives.choose_face_up_position()` must not be used here and must not be
##     widened to offer face-down: a Special Summon is face-up unless the card says
##     otherwise. The position is passed explicitly to
##     `EffectPrimitives.special_summon_one()`. PROJECT_STATE.md design decision 15.

const CARD_NAME := "Apprentice Magician"

## The counter kind, named once. RULES_SPEC.md 14.
const SPELL_COUNTER := "Spell Counter"

const CLAUSE_COUNTER := "If this card is Summoned: Target 1 face-up card on the field " \
	+ "that you can place a Spell Counter on; place 1 Spell Counter on that target."
const CLAUSE_RECRUIT := "When this card is destroyed by battle: You can Special Summon " \
	+ "1 Level 2 or lower Spellcaster monster from your Deck in face-down Defense Position."


func effects() -> Array:
	return [_spell_counter(), _recruit()]


func _spell_counter() -> EffectDef:
	var e := EffectDef.new("place_spell_counter_on_summon", CLAUSE_COUNTER)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	# A monster's Trigger Effect is activated from the field, face-up — which is where a
	# freshly Summoned monster is, in every one of the three Summon kinds below.
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.trigger_events = [
		GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		GameEvent.Kind.FLIP_SUMMON_SUCCEEDED,
	]
	e.targeting(1)
	e.ruling("R21")

	# The event has to be about THIS copy. Without the identity check a second
	# `Apprentice Magician` reaching the field would fire this copy's clause too.
	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null:
			return false
		return int(ev.data.get("card_id", -1)) == ctx.source.id

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.counter_recipients(ctx, SPELL_COUNTER)

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.place_counter_on_target(ctx, SPELL_COUNTER, 1)
		if target != null:
			ctx.log_note("placed 1 Spell Counter on %s" % target.card_name())

	return e


func _recruit() -> EffectDef:
	var e := EffectDef.new("recruit_spellcaster_face_down", CLAUSE_RECRUIT)
	e.of_type(Enums.EffectType.TRIGGER)
	e.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	e.trigger_events = [GameEvent.Kind.CARD_DESTROYED]
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER

	var search := EffectPrimitives.monster_filter("", -1, 2, "Spellcaster")

	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null or not EffectPrimitives.event_is_destruction_of(ev, ctx.source.id):
			return false
		# "destroyed BY BATTLE" — a copy destroyed by a card effect must not fire it
		# [S1 p.52-53].
		if ev.data.get("reason") != Enums.MoveReason.DESTROYED_BY_BATTLE:
			return false
		if not ctx.me().has_free_monster_zone():
			return false
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, search).is_empty()

	e.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, search)
		var summoned := EffectPrimitives.special_summon_one(ctx, candidates,
			Enums.Position.FACE_DOWN_DEFENSE,
			"Special Summon 1 Level 2 or lower Spellcaster monster from your Deck "
			+ "in face-down Defense Position")
		if summoned != null:
			ctx.log_note("Special Summoned %s face-down" % summoned.card_name())
		# "If a card effect requires you to reveal cards from your Deck, or look through
		# it, shuffle it and put it back." [S1 p.5]
		ctx.state.shuffle_deck(ctx.controller_id)

	return e

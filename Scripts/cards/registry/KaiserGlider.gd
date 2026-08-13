extends RefCounted

## Kaiser Glider — LIGHT / Dragon / Level 6 / 2400 ATK / 2200 DEF.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Cannot be destroyed by battle with a monster that has the same ATK. If this card is
##    destroyed and sent to the GY: Target 1 monster on the field; return that target to
##    the hand."
##
## Two clauses, and they are answerable at two completely different moments.
##
## **Clause 1** is a destruction PREVENTION, so it goes through the rules-query convention
## rather than being asked for by the battle code: a CONTINUOUS `EffectDef` whose id is
## `GameState.DESTRUCTION_PREVENTION_EFFECT_ID` and whose `condition` is a PURE query.
## Design decision 20. Three things about it are easy to get wrong:
##
##   * It is **conditional on the other monster**, not on this one, so the query has to
##     find out what this card is battling. `EffectPrimitives.battle_opponent_of()` reads
##     `GameState.current_attacker` / `current_attack_target`, which are both live at
##     damage calculation, where prevention is asked. RULES_SPEC.md 17.
##   * "the same ATK" is **current** ATK on both sides at that instant, not printed ATK.
##     A monster pumped to 2400 is stopped; the printed 2400 that was pumped to 2500 is not.
##   * It is uncounted and it prevents battle destruction only. It does nothing whatever
##     about a destruction by a card effect, and it does not stop battle DAMAGE.
##
## **Clause 2** is a Trigger Effect activated from the Graveyard, and it is the pool's
## sharpest test of "destroyed **and sent to the GY**":
##
##   * both destruction routes qualify — by battle and by card effect. Contrast
##     `Shining Angel`, whose clause names battle alone.
##   * a Tribute, a discard, a banish and a bounce do **not** qualify [S1 p.52-53], and
##     neither does a rules destruction.
##   * it has no "You can", so it is **MANDATORY**. With no monster on the field it simply
##     has no legal target and cannot activate, which is not the same as being optional.
##   * destroyed by battle, its window is inside the Damage Step, so it needs
##     `DamageStepPermission.MANDATORY_TRIGGER` — the timing permission, not a statement
##     about optionality. RULES_SPEC.md 7.2.
##   * it **targets**, so the monster is locked in at activation. Its own destroyer is a
##     perfectly legal target, and so is one of its controller's own monsters.

const CARD_NAME := "Kaiser Glider"

const CLAUSE_PROTECT := "Cannot be destroyed by battle with a monster that has the same ATK."

const CLAUSE_BOUNCE := "If this card is destroyed and sent to the GY: Target 1 monster " \
	+ "on the field; return that target to the hand."


func effects() -> Array:
	# --- Clause 1 --------------------------------------------------------------
	var protect := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID, CLAUSE_PROTECT)
	protect.of_type(Enums.EffectType.CONTINUOUS)

	protect.condition = func(ctx: EffectContext) -> bool:
		# The rules layer asks this about EVERY card it is about to destroy, so the first
		# question is always "is this about me?".
		var subject = ctx.params.get("card", null)
		if subject != ctx.source:
			return false
		if ctx.params.get("reason", null) != Enums.MoveReason.DESTROYED_BY_BATTLE:
			return false
		var other := EffectPrimitives.battle_opponent_of(ctx.state, ctx.source)
		if other == null:
			return false
		return other.current_atk() == ctx.source.current_atk()

	# --- Clause 2 --------------------------------------------------------------
	var bounce := EffectDef.new("bounce_on_destruction", CLAUSE_BOUNCE)
	bounce.of_type(Enums.EffectType.TRIGGER)
	# By the time the trigger is collected the card is already in the Graveyard — being
	# sent there is the very event that makes the clause live.
	bounce.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	bounce.trigger_events = [GameEvent.Kind.CARD_SENT_TO_GY]
	bounce.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER
	bounce.mandatory()
	bounce.targeting(1)

	var destroyed_and_sent := EffectPrimitives.destroyed_and_sent_to_gy_condition()

	bounce.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.cards_on_field(ctx, true)

	bounce.condition = func(ctx: EffectContext) -> bool:
		if not bool(destroyed_and_sent.call(ctx)):
			return false
		# A mandatory trigger with no legal target does not activate at all.
		return not EffectPrimitives.cards_on_field(ctx, true).is_empty()

	bounce.resolve = func(ctx: EffectContext) -> void:
		var returned := EffectPrimitives.return_target_to_hand(ctx, Enums.Zone.MONSTER_ZONE)
		if returned != null:
			ctx.log_note("returned %s to its owner's hand" % returned.card_name())

	return [protect, bounce]

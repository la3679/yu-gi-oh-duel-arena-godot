extends RefCounted

## Birthright — Continuous Trap.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Activate this card by targeting 1 Normal Monster in your GY; Special Summon that
##    target in Attack Position. When this card leaves the field, destroy that monster.
##    When that monster leaves the field, destroy this card."
##
## Three official clauses, so three EffectDefs. Details this implementation accounts for:
##
##   1. "Activate this card BY targeting" — the target is chosen at ACTIVATION, and the
##      Special Summon is the resolution of the card's own activation. RULES_SPEC.md 10.
##   2. "1 NORMAL Monster in YOUR GY" — both halves. A Normal Monster in the opponent's
##      Graveyard is not a legal target, and neither is an Effect Monster in your own.
##      This is the only difference in the targeting between this card and
##      `Call of the Haunted`.
##   3. "in Attack Position" — the position is FIXED by the card, so unlike
##      `Monster Reborn` the summoning player is never asked. RULES_SPEC.md 5.5.
##   4. It is a Continuous Trap, so it STAYS on the field after resolving [S1 p.29-30],
##      which is what makes the following two clauses reachable at all.
##   5. "When this card leaves the field, destroy that monster" — mandatory, and keyed on
##      LEAVING THE FIELD rather than on being destroyed: banished, Tributed and returned
##      to the hand all leave the field [S1 p.52-53].
##   6. "When that monster LEAVES THE FIELD, destroy this card" — and this is where the
##      card differs from `Call of the Haunted`, which says "is DESTROYED" instead. If
##      the revived monster is banished or bounced, Birthright destroys itself and
##      `Call of the Haunted` does not. The two are NOT interchangeable, so the two
##      conditions are written separately rather than shared.
##
## The link between this card and the monster it Summoned lives in `GameState.card_memory`
## (RULES_SPEC.md 15). It cannot live in `CardInstance.flags`: clause 5 fires exactly
## BECAUSE this card left the field, and leaving the field clears `flags`.

const CARD_NAME := "Birthright"

const CLAUSE_REVIVE := "Activate this card by targeting 1 Normal Monster in your GY; " \
	+ "Special Summon that target in Attack Position."
const CLAUSE_DESTROY_MONSTER := "When this card leaves the field, destroy that monster."
const CLAUSE_DESTROY_SELF := "When that monster leaves the field, destroy this card."

## Zones this card can be in once it has left the field, and therefore the locations its
## "when this card leaves the field" trigger has to be activatable from.
const OFF_FIELD_LOCATIONS := [
	Enums.ActivationLocation.GRAVEYARD,
	Enums.ActivationLocation.BANISHED,
	Enums.ActivationLocation.HAND,
	Enums.ActivationLocation.DECK,
]


func effects() -> Array:
	return [_revive(), _destroy_that_monster(), _destroy_this_card()]


func _revive() -> EffectDef:
	var e := EffectDef.new("revive_normal_monster_target", CLAUSE_REVIVE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	# A Trap is activated from a Set card on the field. The "cannot be activated the turn
	# it was Set" rule is enforced once, in ActivationRules.set_turn_ok() [S1 p.30].
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)

	var normal_monster := EffectPrimitives.monster_filter("", -1, -1, "", true)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, normal_monster)

	e.condition = func(ctx: EffectContext) -> bool:
		return ctx.me().has_free_monster_zone()

	e.resolve = func(ctx: EffectContext) -> void:
		var summoned := EffectPrimitives.revive_target_in_attack_position(ctx)
		if summoned != null:
			ctx.log_note("Special Summoned %s in Attack Position" % summoned.card_name())

	return e


func _destroy_that_monster() -> EffectDef:
	var e := EffectDef.new("destroy_that_monster_when_this_leaves", CLAUSE_DESTROY_MONSTER)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.CARD_MOVED])
	e.from_locations(OFF_FIELD_LOCATIONS)
	# This card can leave the field during the Damage Step, and the rules require the
	# trigger to happen there. The permission is about TIMING, not optionality — see
	# RULES_SPEC.md 7.2 and PROJECT_STATE.md design decision 5.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	e.condition = func(ctx: EffectContext) -> bool:
		if not EffectPrimitives.event_is_leaving_the_field(ctx.trigger_event, ctx.source.id):
			return false
		# Nothing to destroy means nothing to activate: this card is only linked to a
		# monster when its own activation actually Summoned one.
		return EffectPrimitives.revived_monster(ctx) != null

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.destroy_linked_monster(ctx)

	return e


func _destroy_this_card() -> EffectDef:
	var e := EffectDef.new("destroy_this_when_that_monster_leaves", CLAUSE_DESTROY_SELF)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.CARD_MOVED])
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	e.condition = func(ctx: EffectContext) -> bool:
		var monster := EffectPrimitives.revived_monster(ctx)
		if monster == null:
			return false
		# "LEAVES THE FIELD" — the whole point of the difference from Call of the Haunted.
		return EffectPrimitives.event_is_leaving_the_field(ctx.trigger_event, monster.id)

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.destroy_self(ctx)

	return e

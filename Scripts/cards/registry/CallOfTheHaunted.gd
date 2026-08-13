extends RefCounted

## Call of the Haunted — Continuous Trap.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Activate this card by targeting 1 monster in your GY; Special Summon that target in
##    Attack Position. When this card leaves the field, destroy that monster. When that
##    monster is destroyed, destroy this card."
##
## Three official clauses, so three EffectDefs.
##
## This card and `Birthright` are the same SHAPE and are deliberately NOT the same
## implementation. They agree on clauses 1 and 2 and disagree on clause 3:
##
##   | clause | Birthright | Call of the Haunted |
##   |---|---|---|
##   | what may be revived | 1 **Normal Monster** in your GY | **1 monster** in your GY |
##   | this card leaves the field | destroy that monster | destroy that monster |
##   | the monster goes away | when it **leaves the field** | when it **is destroyed** |
##
## The third row is the one that changes real outcomes: banish or bounce the revived
## monster and `Birthright` destroys itself while this card stays face-up on the field.
## Collapsing the two into one "approximately revival" implementation would silently
## erase that, so only what is genuinely shared is shared
## (`EffectPrimitives.revive_target_in_attack_position` / `destroy_linked_monster`), and
## each card writes its own trigger condition.
##
## Everything else — targeting at activation, the FIXED Attack Position, the Continuous
## Trap staying on the field, and the link surviving in `GameState.card_memory` rather
## than in `CardInstance.flags` — is documented on `Birthright`.

const CARD_NAME := "Call of the Haunted"

const CLAUSE_REVIVE := "Activate this card by targeting 1 monster in your GY; " \
	+ "Special Summon that target in Attack Position."
const CLAUSE_DESTROY_MONSTER := "When this card leaves the field, destroy that monster."
const CLAUSE_DESTROY_SELF := "When that monster is destroyed, destroy this card."

const OFF_FIELD_LOCATIONS := [
	Enums.ActivationLocation.GRAVEYARD,
	Enums.ActivationLocation.BANISHED,
	Enums.ActivationLocation.HAND,
	Enums.ActivationLocation.DECK,
]


func effects() -> Array:
	return [_revive(), _destroy_that_monster(), _destroy_this_card()]


func _revive() -> EffectDef:
	var e := EffectDef.new("revive_monster_target", CLAUSE_REVIVE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)

	# "1 monster", with no further qualification — the whole of your own Graveyard.
	var any_monster := EffectPrimitives.revivable_monster()

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.own_cards_in(ctx, Enums.Zone.GRAVEYARD, any_monster)

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
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	e.condition = func(ctx: EffectContext) -> bool:
		if not EffectPrimitives.event_is_leaving_the_field(ctx.trigger_event, ctx.source.id):
			return false
		return EffectPrimitives.revived_monster(ctx) != null

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.destroy_linked_monster(ctx)

	return e


func _destroy_this_card() -> EffectDef:
	var e := EffectDef.new("destroy_this_when_that_monster_is_destroyed", CLAUSE_DESTROY_SELF)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	# Keyed on CARD_DESTROYED rather than CARD_MOVED: "is destroyed" is strictly narrower
	# than "leaves the field" [S1 p.52-53]. This is the clause that differs from
	# `Birthright` and the reason the two cards are not one implementation.
	e.on_events([GameEvent.Kind.CARD_DESTROYED])
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	# The revived monster is most often destroyed BY BATTLE, which happens inside the
	# Damage Step, so this trigger has to be legal there. RULES_SPEC.md 7.2.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	e.condition = func(ctx: EffectContext) -> bool:
		var monster := EffectPrimitives.revived_monster(ctx)
		if monster == null:
			return false
		return EffectPrimitives.event_is_destruction_of(ctx.trigger_event, monster.id)

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.destroy_self(ctx)

	return e

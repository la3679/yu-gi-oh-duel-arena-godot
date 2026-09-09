extends RefCounted

## Fiendish Chain — Continuous Trap.
##
## Official text (verified against the Konami card database, cid 8675):
##
##   "Activate this card by targeting 1 Effect Monster on the field; negate the effects of
##    that face-up monster while it is on the field, also that face-up monster cannot
##    attack. When it is destroyed, destroy this card."
##
## Three EffectDefs. The first printed clause is genuinely two mechanisms — an ACTIVATION
## that fixes the target, and a CONTINUOUS application that lasts while both cards remain —
## and this engine models a continuous effect as a clause that starts no Chain and is
## recomputed from the board (RULES_SPEC.md 8, master prompt 25). They cannot be one
## EffectDef, so they are two, and the split is documented rather than silent.
##
## Details this implementation accounts for:
##
##   1. "Activate this card BY targeting" — the monster is fixed at ACTIVATION.
##      RULES_SPEC.md 10.
##   2. "1 Effect Monster **on the field**" reaches BOTH players' monsters; this card is
##      normally used on the opponent's. But it must be FACE-UP: whether a face-down
##      monster is an Effect Monster is not a property either player may act on, and the
##      clause immediately goes on to say "that FACE-UP monster" twice.
##   3. A Normal Monster is not a legal target, even face-up.
##   4. The negation and the attack lock are ONE continuous clause, so they switch on and
##      off together — "while it is on the field". Flip the monster face-down, banish it or
##      bounce it and both stop; nothing has to be undone by a cleanup step.
##   5. The negation is applied through `ContinuousEffects.negate_effects()`, the only
##      channel that owns a continuously-applied negation. It required a two-pass recompute:
##      see PROJECT_STATE.md §4 and `ContinuousEffects.recompute()`.
##   6. "When **it** is destroyed, destroy this card" — "it" is the targeted monster, and
##      the clause is keyed on DESTRUCTION, not on leaving the field. A targeted monster
##      that is banished or returned to the hand leaves this card sitting face-up on the
##      field with nothing to negate, which is correct. This is the same distinction
##      `Call of the Haunted` draws against `Birthright`.
##
## The link to the targeted monster lives in `GameState.card_memory`
## (`EffectPrimitives.AFFLICTED_MONSTER_KEY`), because the Chain Link that carried the
## target is gone by the time the continuous clause runs, and because clause 6 has to be
## answerable at a moment when `CardInstance.flags` has already been cleared.
## RULES_SPEC.md 15, PROJECT_STATE.md design decision 18.

const CARD_NAME := "Fiendish Chain"

const CLAUSE_ACTIVATE := "Activate this card by targeting 1 Effect Monster on the field."
const CLAUSE_NEGATE := "Negate the effects of that face-up monster while it is on the " \
	+ "field, also that face-up monster cannot attack."
const CLAUSE_DESTROY_SELF := "When it is destroyed, destroy this card."


func effects() -> Array:
	return [_activation(), _negate_and_lock(), _destroy_self()]


func _activation() -> EffectDef:
	var e := EffectDef.new("chain_target_effect_monster", CLAUSE_ACTIVATE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)

	# "1 Effect Monster on the field" — an Effect Monster, in a Monster Zone, FACE-UP.
	var targetable := func(card: CardInstance) -> bool:
		if not card.is_monster() or not card.is_face_up():
			return false
		if card.zone != Enums.Zone.MONSTER_ZONE:
			return false
		return card.definition != null and card.definition.is_effect_monster

	e.legal_targets = func(ctx: EffectContext) -> Array:
		# "on the field" is both sides of the table.
		var out := EffectPrimitives.cards_in(ctx, ctx.controller_id,
			Enums.Zone.MONSTER_ZONE, targetable)
		out.append_array(EffectPrimitives.cards_in(ctx, ctx.opponent_id(),
			Enums.Zone.MONSTER_ZONE, targetable))
		return out

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
		if target == null or not target.is_face_up():
			# The target left the field, or was flipped face-down, between activation and
			# resolution. Nothing is attached, so the continuous clause finds nothing and
			# the Trap sits face-up doing nothing — it is not destroyed by this.
			# Master prompt 44.
			ctx.log_note("the target is no longer a face-up monster on the field")
			return
		EffectPrimitives.link_afflicted_monster(ctx, target)
		ctx.log_note("negating %s" % target.card_name())

	return e


func _negate_and_lock() -> EffectDef:
	var e := EffectDef.new("negate_and_lock_target", CLAUSE_NEGATE)
	e.of_type(Enums.EffectType.CONTINUOUS)
	# Declares that this clause negates, so `ContinuousEffects.recompute()` runs it before
	# any clause that asks "is this source negated?". Without the declaration the answer
	# would depend on board iteration order. See EffectDef.negates_effects.
	e.negating()

	e.apply_continuous = func(ctx: EffectContext) -> void:
		var monster := EffectPrimitives.afflicted_monster(ctx)
		if monster == null:
			return
		# "while it is ON THE FIELD" and "that FACE-UP monster" — both halves.
		if monster.zone != Enums.Zone.MONSTER_ZONE or not monster.is_face_up():
			return
		ContinuousEffects.negate_effects(monster, ctx.source)
		ContinuousEffects.restrict(monster, "cannot_attack", ctx.source)

	return e


func _destroy_self() -> EffectDef:
	var e := EffectDef.new("destroy_this_when_target_destroyed", CLAUSE_DESTROY_SELF)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.on_events([GameEvent.Kind.CARD_DESTROYED])
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	# The targeted monster is most often destroyed by battle, so the timing has to be legal
	# inside the Damage Step [S1 p.41]. RULES_SPEC.md 7.2.
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)

	e.condition = func(ctx: EffectContext) -> bool:
		var monster := EffectPrimitives.afflicted_monster(ctx)
		if monster == null:
			return false
		# "IS DESTROYED" — strictly narrower than leaving the field. A banished or bounced
		# monster does not fire this [S1 p.52-53].
		return EffectPrimitives.event_is_destruction_of(ctx.trigger_event, monster.id)

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.clear_afflicted_link(ctx)
		if not ctx.source.is_on_field():
			return
		ctx.state.destroy(ctx.source, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)

	return e

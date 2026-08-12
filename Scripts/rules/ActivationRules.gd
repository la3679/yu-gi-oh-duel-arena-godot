class_name ActivationRules
extends RefCounted

## Shared activation legality. RULES_SPEC.md 3, 4, 7.2, 11.
##
## Both the trigger system and the player-facing legal-action API funnel through
## can_activate(), so a Trigger Effect and a hand-activated Spell are judged by exactly
## the same rules. There is deliberately no second, looser path.
##
## Sources: Official Rulebook v10 (S1) and the official Fast Effect Timing chart (S2).
## Rulebook citations use printed page numbers.


# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------

## Is the card in a zone/face state this effect may be activated from?
static func location_ok(card: CardInstance, effect: EffectDef) -> bool:
	for loc in effect.activation_locations:
		match loc:
			Enums.ActivationLocation.HAND:
				if card.zone == Enums.Zone.HAND:
					return true
			Enums.ActivationLocation.FIELD_FACE_UP:
				if card.is_on_field() and card.is_face_up():
					return true
			Enums.ActivationLocation.FIELD_FACE_DOWN:
				if card.is_on_field() and card.is_face_down():
					return true
			Enums.ActivationLocation.GRAVEYARD:
				if card.zone == Enums.Zone.GRAVEYARD:
					return true
			Enums.ActivationLocation.BANISHED:
				if card.zone == Enums.Zone.BANISHED:
					return true
			Enums.ActivationLocation.DECK:
				if card.zone == Enums.Zone.DECK:
					return true
	return false


# ---------------------------------------------------------------------------
# Set-turn restrictions. [S1 p.30-31]
# ---------------------------------------------------------------------------

## "You cannot activate a Trap in the same turn that you Set it, but you can activate it
## at any time after that." [S1 p.30]
##
## Spells differ: "Spell Cards can be activated during the Main Phases even in the same
## turn that you Set them (except for Quick-Play Spell Cards)." [S1 p.31]
static func set_turn_ok(state: GameState, card: CardInstance) -> bool:
	if not card.is_on_field() or card.turn_set != state.turn_number:
		return true
	if card.definition == null:
		return true
	var kind: Enums.STKind = card.definition.st_kind
	if Enums.is_trap(kind):
		return false
	if kind == Enums.STKind.QUICK_PLAY_SPELL:
		return false
	return true


## Who may activate this card right now, given where it is. [S1 p.28, p.30-31]
##
##  * A Spell activated from the HAND is a turn-player, Main-Phase action, except a
##    Quick-Play Spell, which its controller may activate during their own turn at any
##    fast-effect timing.
##  * A Set Spell that is not a Quick-Play Spell "still can only be activated during your
##    Main Phase" [S1 p.31].
##  * A Set Quick-Play Spell or any Trap may be activated during either player's turn.
static func card_activation_timing_ok(state: GameState, card: CardInstance,
		controller_id: int) -> bool:
	if card.definition == null:
		return true
	var kind: Enums.STKind = card.definition.st_kind
	if Enums.is_trap(kind):
		return true

	var is_turn_player := state.turn_player_id == controller_id
	var in_main_phase := state.phase == Enums.Phase.MAIN_1 or state.phase == Enums.Phase.MAIN_2

	if kind == Enums.STKind.QUICK_PLAY_SPELL:
		# From the hand: your turn only. Once Set on the field: either player's turn.
		if card.zone == Enums.Zone.HAND:
			return is_turn_player
		return true

	# Every other Spell: your own Main Phase, from hand or from a Set card.
	return is_turn_player and in_main_phase


# ---------------------------------------------------------------------------
# Phase / Damage Step. RULES_SPEC.md 7.2 [S1 p.41]
# ---------------------------------------------------------------------------

static func phase_ok(state: GameState, effect: EffectDef) -> bool:
	if effect.legal_phases.is_empty():
		return true
	return effect.legal_phases.has(state.phase)


## "During the Damage Step, you can only activate Counter Trap Cards, or cards with
## effects that directly change a monster's ATK or DEF. Also, these cards can only be
## activated up until the start of damage calculation." [S1 p.41]
##
## There is no generic allow-everything path: an effect with permission NONE is never
## surfaced inside the Damage Step.
static func damage_step_ok(state: GameState, effect: EffectDef) -> bool:
	if state.battle_step != Enums.BattleStep.DAMAGE:
		return true
	match effect.damage_step_permission:
		Enums.DamageStepPermission.UNTIL_DAMAGE_CALC:
			return state.damage_substep == Enums.DamageSubStep.START_OF_DAMAGE_STEP \
				or state.damage_substep == Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
		Enums.DamageStepPermission.MANDATORY_TRIGGER:
			# Collected by the trigger system at its own sub-step; never offered as a
			# free-choice fast effect.
			return effect.optionality == Enums.Optionality.MANDATORY
		_:
			return false


# ---------------------------------------------------------------------------
# Once per turn. RULES_SPEC.md 11, master prompt 47.
# ---------------------------------------------------------------------------

static func once_per_turn_ok(state: GameState, card: CardInstance, effect: EffectDef,
		controller_id: int) -> bool:
	var key := effect.named_key()
	if effect.once_per_turn_instance:
		if card.was_effect_used_this_turn(key, state.turn_number):
			return false
	var p := state.player(controller_id)
	if effect.once_per_turn_named_effect:
		if p.was_named_effect_used(card.card_name(), key, state.turn_number):
			return false
	if effect.once_per_turn_named_activation:
		if p.was_named_activation_used(card.card_name(), state.turn_number):
			return false
	return true


## Record that this effect was used. Called immediately after the activation is
## committed, so a second copy in the same Chain cannot slip through.
static func mark_used(state: GameState, card: CardInstance, effect: EffectDef,
		controller_id: int) -> void:
	var key := effect.named_key()
	var p := state.player(controller_id)
	if effect.once_per_turn_instance:
		card.mark_effect_used(key, state.turn_number)
	if effect.once_per_turn_named_effect:
		p.mark_named_effect_used(card.card_name(), key, state.turn_number)
	if effect.once_per_turn_named_activation:
		p.mark_named_activation_used(card.card_name(), state.turn_number)


# ---------------------------------------------------------------------------
# Cost and targets. RULES_SPEC.md 10, master prompt 16/17.
# ---------------------------------------------------------------------------

static func make_context(state: GameState, card: CardInstance, effect: EffectDef,
		controller_id: int, trigger_event: GameEvent = null) -> EffectContext:
	var ctx := EffectContext.new(state, card, effect)
	ctx.controller_id = controller_id
	ctx.trigger_event = trigger_event
	return ctx


static func cost_ok(ctx: EffectContext) -> bool:
	if not ctx.effect.can_pay_cost.is_valid():
		return true
	return bool(ctx.effect.can_pay_cost.call(ctx))


## Legal targets evaluated at activation. An effect that targets and has fewer legal
## targets than it requires cannot be activated at all (master prompt 17).
static func legal_targets(ctx: EffectContext) -> Array:
	if not ctx.effect.legal_targets.is_valid():
		return []
	var out = ctx.effect.legal_targets.call(ctx)
	return out if out is Array else []


static func targets_ok(ctx: EffectContext) -> bool:
	if not ctx.effect.targets:
		return true
	return legal_targets(ctx).size() >= ctx.effect.target_count_min


static func condition_ok(ctx: EffectContext) -> bool:
	if not ctx.effect.condition.is_valid():
		return true
	return bool(ctx.effect.condition.call(ctx))


# ---------------------------------------------------------------------------
# The single legality gate.
# ---------------------------------------------------------------------------

## Everything except Chain-response Spell Speed, which depends on the current Chain and
## is checked by ChainManager.can_respond_with_spell_speed().
static func can_activate(state: GameState, card: CardInstance, effect: EffectDef,
		controller_id: int, trigger_event: GameEvent = null) -> bool:
	if state.is_duel_over():
		return false
	if card == null or effect == null:
		return false
	if not effect.starts_chain:
		return false
	if card.effects_negated:
		return false
	if not location_ok(card, effect):
		return false
	if not set_turn_ok(state, card):
		return false
	if effect.effect_type == Enums.EffectType.CARD_ACTIVATION \
			and not card_activation_timing_ok(state, card, controller_id):
		return false
	if not phase_ok(state, effect):
		return false
	if not damage_step_ok(state, effect):
		return false
	if not once_per_turn_ok(state, card, effect, controller_id):
		return false

	# Activating a Spell/Trap from the hand needs a free zone to place it in [S1 p.28].
	if effect.effect_type == Enums.EffectType.CARD_ACTIVATION \
			and card.zone == Enums.Zone.HAND \
			and not _has_room_to_activate(state, card, controller_id):
		return false

	var ctx := make_context(state, card, effect, controller_id, trigger_event)
	if not condition_ok(ctx):
		return false
	if not cost_ok(ctx):
		return false
	if not targets_ok(ctx):
		return false
	return true


static func _has_room_to_activate(state: GameState, card: CardInstance,
		controller_id: int) -> bool:
	if card.definition == null:
		return true
	var p := state.player(controller_id)
	if card.definition.st_kind == Enums.STKind.FIELD_SPELL:
		# A new Field Spell replaces the old one, so the zone being occupied is fine.
		return true
	return p.has_free_spell_trap_zone()


## Is this effect a fast effect, i.e. usable in a response window? [S1 p.44-45]
## Ignition / Trigger / Flip monster effects and Spell Speed 1 Spells are not.
static func is_fast_effect(effect: EffectDef) -> bool:
	return effect.starts_chain and effect.spell_speed >= Enums.SpellSpeed.SS2

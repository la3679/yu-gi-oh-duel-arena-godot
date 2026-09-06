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
		Enums.DamageStepPermission.AFTER_DAMAGE_CALC:
			# Sub-step 4 ONLY. Not sub-steps 1-2, where UNTIL_DAMAGE_CALC lives and where
			# this card's window has not opened yet; and not sub-step 5, by which time
			# battle destruction is being carried out and the window has closed.
			# RULES_SPEC.md 7.1.
			return state.damage_substep == Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION
		Enums.DamageStepPermission.MANDATORY_TRIGGER:
			# "Mandatory" here means the TIMING is rules-mandated, not that the effect
			# itself is compulsory: `Shining Angel`'s "when this card is destroyed by
			# battle" effect is optional but its window is inside the Damage Step.
			# Such effects are collected by the trigger system at their own sub-step and
			# are never offered as a free-choice fast effect.
			return TriggerCollector._is_collectable(effect)
		_:
			return false


# ---------------------------------------------------------------------------
# Card-class activation locks. RULES_SPEC.md 4.4, CARD_RULINGS.md R6.
# ---------------------------------------------------------------------------

## "Your opponent cannot activate Trap Cards during the Battle Phase." (`Mirage Dragon`)
##
## Asked generically, from the category of the card being activated and the current phase, so
## no card name reaches this gate. The restriction itself is written by whatever continuous
## clause imposes it, through `ContinuousEffects.restrict_card_activation()`.
##
## **It locks activating a CARD, not activating an EFFECT of a card.** The distinction is
## real and the engine already carries it structurally: `EffectType.CARD_ACTIVATION` is the
## activation of the Spell/Trap card itself, while an `IGNITION` / `QUICK` / `TRIGGER` clause
## of a card that is ALREADY face-up on the field is the activation of an effect. A
## Continuous Trap sitting face-up was activated on an earlier turn; using one of its effects
## is not "activating a Trap Card". CARD_RULINGS.md R6 records this with its confidence.
##
## The PRINTED category is what counts (`original_card_category()`), so a Trap that is
## currently a Trap Monster is still a Trap for the purpose of activating it as a card, and a
## runtime monster identity cannot be used to slip a card activation past the lock.
static func card_class_activation_ok(state: GameState, card: CardInstance,
		effect: EffectDef, controller_id: int) -> bool:
	if effect.effect_type != Enums.EffectType.CARD_ACTIVATION:
		return true
	if card.definition == null:
		return true
	return not ContinuousEffects.card_activation_locked(
		state, controller_id, card.original_card_category())


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
##
## This is the SINGLE funnel for target candidates — `DuelEngine._activation_actions()`
## publishes what it returns and `DuelEngine._choices_valid()` re-validates against the same
## list — so a card that "cannot be targeted" is filtered out here, once, rather than in each
## of the eighteen `legal_targets` callables. `Fairy Tail - Rella` is the pool's only source.
static func legal_targets(ctx: EffectContext) -> Array:
	if not ctx.effect.legal_targets.is_valid():
		return []
	var out = ctx.effect.legal_targets.call(ctx)
	if not (out is Array):
		return []
	var kept: Array = []
	for entry in (out as Array):
		var card: CardInstance = entry
		if card != null and card.cannot_be_targeted():
			continue
		kept.append(card)
	return kept


static func targets_ok(ctx: EffectContext) -> bool:
	if not ctx.effect.targets:
		return true
	return legal_targets(ctx).size() >= ctx.effect.target_count_min


## Is this specific SET of chosen targets legal for this effect?
##
## Membership in `legal_targets()` and the count are checked by the engine already. This is
## the extra question a clause with HETEROGENEOUS targets has to answer: `Kunai with Chain`
## activated in both modes targets the attacking monster AND a face-up monster you control,
## and picking two of your own monsters satisfies both the candidate list and the count while
## being an illegal selection. A clause that does not declare `targets_valid` is unrestricted
## beyond the generic checks, which is the correct default for every other card in the pool.
static func target_selection_ok(ctx: EffectContext, chosen: Array) -> bool:
	if not ctx.effect.targets_valid.is_valid():
		return true
	return bool(ctx.effect.targets_valid.call(ctx, chosen))


static func condition_ok(ctx: EffectContext) -> bool:
	if not ctx.effect.condition.is_valid():
		return true
	return bool(ctx.effect.condition.call(ctx))


# ---------------------------------------------------------------------------
# The single legality gate.
# ---------------------------------------------------------------------------

## Everything except Chain-response Spell Speed, which depends on the current Chain and
## is checked by ChainManager.can_respond_with_spell_speed().
const ACTIVATION_CONDITION_EFFECT_ID := "card_activation_condition"

static func can_activate(state: GameState, card: CardInstance, effect: EffectDef,
		controller_id: int, trigger_event: GameEvent = null) -> bool:
	if state.is_duel_over():
		return false
	if card == null or effect == null:
		return false
	if not effect.starts_chain:
		return false
	if card.effects_are_negated():
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
	if not card_class_activation_ok(state, card, effect, controller_id):
		return false
	if not once_per_turn_ok(state, card, effect, controller_id):
		return false

	# Activating a Spell/Trap from the hand needs a free zone to place it in [S1 p.28].
	if effect.effect_type == Enums.EffectType.CARD_ACTIVATION \
			and card.zone == Enums.Zone.HAND \
			and not _has_room_to_activate(state, card, controller_id):
		return false

	# "You can only control 1 '<name>'." — until now this was only asked on the routes a
	# MONSTER takes onto the field, so a Spell/Trap carrying the same restriction
	# (`Castle of Dragon Souls`) was unrestricted. Activating a Spell/Trap is what puts it
	# face-up on the field, so that is where the limit has to be enforced for one.
	# Setting a second copy stays legal: a Set card has not been activated, and the limit is
	# re-tested if and when it is. [S1 p.53 "Control"]
	if effect.effect_type == Enums.EffectType.CARD_ACTIVATION \
			and not card.is_monster() \
			and not SummonRules.control_limit_satisfied(state, card, controller_id):
		return false

	if effect.effect_type == Enums.EffectType.CARD_ACTIVATION:
		for clause in card.definition.effects:
			if clause.effect_id == ACTIVATION_CONDITION_EFFECT_ID and clause.condition.is_valid():
				if not bool(clause.condition.call(make_context(state, card, clause, controller_id, trigger_event))):
					return false
	var ctx := make_context(state, card, effect, controller_id, trigger_event)
	if not condition_ok(ctx):
		return false
	if not cost_ok(ctx):
		return false
	if not targets_ok(ctx):
		return false
	return true


## A summoning PROCEDURE — "If only your opponent controls a monster, you can Special
## Summon this card (from your hand)" — is not an activation and starts no Chain, so
## can_activate() rejects it on the `starts_chain` guard by design. It is still gated:
## location, phase, once-per-turn, a free Monster Zone, its condition and its cost all
## have to hold. RULES_SPEC.md 5.5 [S1 p.24].
static func can_use_summon_procedure(state: GameState, card: CardInstance,
		effect: EffectDef, controller_id: int) -> bool:
	if state.is_duel_over():
		return false
	if card == null or effect == null:
		return false
	if effect.effect_type != Enums.EffectType.SUMMON_PROCEDURE:
		return false
	if card.effects_are_negated():
		return false
	if not card.is_monster():
		return false
	if not location_ok(card, effect):
		return false
	if not phase_ok(state, effect):
		return false
	if not once_per_turn_ok(state, card, effect, controller_id):
		return false
	if not state.player(controller_id).has_free_monster_zone():
		return false
	# "You can only control 1 …" is checked here as well as in SummonRules, so the action
	# is never even OFFERED when the limit already forbids it.
	if not SummonRules.control_limit_satisfied(state, card, controller_id):
		return false
	var ctx := make_context(state, card, effect, controller_id, null)
	if not condition_ok(ctx):
		return false
	if not cost_ok(ctx):
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

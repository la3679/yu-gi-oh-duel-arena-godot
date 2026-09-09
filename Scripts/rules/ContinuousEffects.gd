class_name ContinuousEffects
extends RefCounted

## State-derived continuous effects. RULES_SPEC.md, master prompt 25.
##
## A Continuous Effect is NOT an activation and does not start a Chain. It is recomputed
## from the current board every time the state could have changed, so it switches off by
## itself the moment its source leaves the field, is flipped face-down or is negated —
## rather than being "undone" by some later cleanup step.
##
## Everything this system writes is tagged so it can be wiped and rebuilt from scratch:
##   * stat modifiers use duration `CONTINUOUS_DURATION`
##   * per-card restriction flags are listed in `RESTRICTION_FLAGS`
##   * per-player restrictions live in PlayerState.restrictions under a "continuous:" key
##
## A card's continuous effect is declared as an EffectDef with
## `effect_type = Enums.EffectType.CONTINUOUS` and an `apply_continuous` callable; it
## never has `resolve`, because it never resolves.

const CONTINUOUS_DURATION := "continuous"
const PLAYER_KEY_PREFIX := "continuous:"

## Set on a card whose effects are negated by a CONTINUOUS clause of another card
## (`Fiendish Chain`). Read through `CardInstance.effects_are_negated()`, never directly,
## and written only by `negate_effects()` below. It is listed in RESTRICTION_FLAGS so it is
## wiped and rebuilt like every other state-derived flag.
const NEGATION_FLAG := "effects_negated_by_continuous"

## Per-card restriction flags this system owns. Cleared and rebuilt on every recompute,
## so a card must never write these from anywhere else.
const RESTRICTION_FLAGS := [
	"cannot_attack",
	"cannot_be_destroyed_by_battle",
	"cannot_be_destroyed_by_effect",
	"cannot_be_targeted",
	"cannot_be_tributed",
	"cannot_change_position",
	"piercing",
	NEGATION_FLAG,
]

var state: GameState = null


func _init(p_state: GameState) -> void:
	state = p_state


# ---------------------------------------------------------------------------
# Recompute
# ---------------------------------------------------------------------------

## Wipe every continuous-sourced modifier and restriction, then reapply from the current
## board. Cheap for the V1 pool: at most a handful of face-up cards per side.
## Two passes, and the split is load-bearing rather than cosmetic.
##
## `_clear()` erases the negation flag along with everything else, so during a recompute
## "is this source negated?" is only answerable once the negating clauses have run again.
## With a single pass the answer would depend on the order the sources happen to be
## iterated in: a monster processed before `Fiendish Chain` would apply its own continuous
## effect for one recompute despite being negated, and a monster processed after it would
## not. Pass 1 applies only the clauses that negate; pass 2 applies everything else and can
## then trust `effects_are_negated()`.
func recompute() -> void:
	_clear()
	_apply_pass(true)
	_apply_pass(false)


func _apply_pass(negation_only: bool) -> void:
	for card in _continuous_sources(negation_only):
		for effect in card.definition.effects:
			if effect.effect_type != Enums.EffectType.CONTINUOUS:
				continue
			if effect.negates_effects != negation_only:
				continue
			if not effect.apply_continuous.is_valid():
				continue
			var ctx := EffectContext.new(state, card, effect)
			ctx.controller_id = card.controller_id
			ctx.continuous = self
			effect.apply_continuous.call(ctx)


# ---------------------------------------------------------------------------
# Continuous clauses that react to a discrete EVENT. RULES_SPEC.md 5.7.
# ---------------------------------------------------------------------------

## Apply every CONTINUOUS clause that responds to `event`, immediately and exactly once.
##
## This is not the trigger system and it must never become it. A Trigger Effect is
## activated, goes on the Chain, and can be responded to and negated. A continuous clause
## like `Judge of the Ice Barrier`'s "each time your opponent activates a card or effect by
## paying LP, they lose 500 LP" does none of that: it applies at the moment the event
## happens, puts no link on the Chain, and is never offered as a choice. RULES_SPEC.md 4.3
## already records that paying a cost is not an activation and cannot be chained to, which
## is exactly why this cannot be modelled as a Trigger Effect.
##
## Sources are the same set `recompute()` uses — face-up, on the field, not negated, own
## activation resolved — so a clause switches off by itself under precisely the conditions
## its continuous stat modifiers would. Order is board order, which is deterministic, so a
## replay reproduces the same LP changes in the same sequence.
func respond_to(event: GameEvent) -> void:
	if event == null or state.is_duel_over():
		return
	for card in _continuous_sources():
		for effect in card.definition.effects:
			if effect.effect_type != Enums.EffectType.CONTINUOUS:
				continue
			if not effect.respond_to_event.is_valid():
				continue
			if not effect.trigger_events.has(event.kind):
				continue
			var ctx := EffectContext.new(state, card, effect)
			ctx.controller_id = card.controller_id
			ctx.continuous = self
			ctx.trigger_event = event
			if effect.condition.is_valid() and not bool(effect.condition.call(ctx)):
				continue
			effect.respond_to_event.call(ctx)


func _clear() -> void:
	for card in state.all_instances():
		card.remove_modifiers_with_duration(CONTINUOUS_DURATION)
		for flag in RESTRICTION_FLAGS:
			card.flags.erase(flag)
	for p in state.players:
		for key in p.restrictions.keys():
			if str(key).begins_with(PLAYER_KEY_PREFIX):
				p.restrictions.erase(key)


## Face-up cards on the field whose effects are not negated. A face-down card and a
## negated card apply nothing.
##
## A Continuous Spell/Trap whose own activation is still an unresolved Chain Link is also
## excluded: its continuous effect only begins applying once that activation RESOLVES.
## RULES_SPEC.md 8.1 [S1 p.17, p.18 with p.46-47] — activating a card places it face-up on
## the field, but an activation has no effect until its Chain Link resolves, and a
## Continuous Spell/Trap removed before resolution resolves without effect.
## `negation_pass` is true while pass 1 runs. In that pass the continuously-applied
## negation flag has just been cleared and has not been rebuilt yet, so asking about it
## would be meaningless; only a negation written from OUTSIDE this system is honoured then.
## Pass 2 uses the full answer. Nothing in the V1 pool can negate a negator — `Fiendish
## Chain` targets Effect Monsters only — so pass 1 has no ordering dependency of its own.
func _continuous_sources(negation_pass: bool = false) -> Array:
	var out: Array = []
	for p in state.players:
		for card in p.controlled_cards():
			if card == null or card.definition == null:
				continue
			if not card.is_face_up():
				continue
			if card.effects_negated:
				continue
			if not negation_pass and card.effects_are_negated():
				continue
			if activation_unresolved(card):
				continue
			out.append(card)
	return out


## Is this card's own card activation still on the Chain, unresolved?
func activation_unresolved(card: CardInstance) -> bool:
	for entry in state.chain:
		var link: ChainLink = entry
		if link.source_card != card:
			continue
		if link.effect == null \
				or link.effect.effect_type != Enums.EffectType.CARD_ACTIVATION:
			continue
		if not link.resolved:
			return true
	return false


# ---------------------------------------------------------------------------
# The API a card's apply_continuous() uses. Master prompt 25.
# ---------------------------------------------------------------------------

## Add a continuous ATK change to `card`. Removed automatically on the next recompute.
static func add_atk(source: CardInstance, card: CardInstance, amount: int) -> void:
	if card == null or amount == 0:
		return
	card.add_atk_modifier(source.id, amount, CONTINUOUS_DURATION,
		"%d:atk" % source.id)


static func add_def(source: CardInstance, card: CardInstance, amount: int) -> void:
	if card == null or amount == 0:
		return
	card.add_def_modifier(source.id, amount, CONTINUOUS_DURATION,
		"%d:def" % source.id)


## Set one of RESTRICTION_FLAGS on a card for as long as the source applies.
##
## `source` is optional only so that a synthetic test clause can restrict a card without
## inventing one. A real card must always pass `ctx.source`: a monster that is unaffected by
## the effects of other cards does not receive a flag from them either, whether the flag
## helps it (`cannot_be_destroyed_by_battle`, `piercing`) or hurts it (`cannot_attack`).
## RULES_SPEC.md 18, CARD_RULINGS.md R12 Part B — official Q&A fid 18199 is exactly this
## case, and the flag it refuses is a protection.
static func restrict(card: CardInstance, flag: String,
		source: CardInstance = null) -> bool:
	if card == null:
		return false
	if not RESTRICTION_FLAGS.has(flag):
		push_error("ContinuousEffects: unknown restriction flag '%s'" % flag)
		return false
	if source != null and EffectImmunity.blocks(card, source.id):
		return false
	card.flags[flag] = true
	return true


## "Negate the effects of that face-up monster while it is on the field." [Fiendish Chain]
##
## This is the ONLY way to write a continuously-applied negation. It goes through
## `restrict()` so the flag is validated against RESTRICTION_FLAGS and is wiped by the next
## recompute like everything else this system owns.
static func negate_effects(card: CardInstance, source: CardInstance = null) -> bool:
	return restrict(card, NEGATION_FLAG, source)


## Set a player-level continuous restriction, e.g. "cannot_conduct_battle_phase".
func restrict_player(pid: int, key: String) -> void:
	state.player(pid).set_restriction(PLAYER_KEY_PREFIX + key, true)


func player_restricted(pid: int, key: String) -> bool:
	return bool(state.player(pid).get_restriction(PLAYER_KEY_PREFIX + key, false))


# ---------------------------------------------------------------------------
# Player-level ATTACK restriction. RULES_SPEC.md 6.1.
# ---------------------------------------------------------------------------

## "While this card is face-up on the field, your opponent's monsters cannot declare an
## attack." (`Swords of Revealing Light`)
##
## Deliberately a PLAYER-level restriction rather than the per-card `cannot_attack` flag
## applied to each monster in turn, and the two must stay separate channels:
##
##   * `cannot_attack` names one monster. `Fiendish Chain` locks the monster it targeted and
##     nothing else, so the restriction has to travel with that card — a monster that changes
##     control keeps it, and a different monster arriving is unaffected.
##   * this key names a PLAYER. "Your opponent's monsters cannot declare an attack" covers
##     monsters that were not on the field when the source resolved and monsters whose
##     control changed into that player's hands afterwards. Expressing it by flagging the
##     monsters present at recompute time would answer the same for the board as it stands
##     and the wrong thing for a monster that arrives between two recomputes.
##
## `BattleRules.can_declare_attack()` asks both, so neither is expressed in terms of the
## other and neither can be quietly dropped.
const ATTACK_LOCK_KEY := "cannot_declare_attacks"


func restrict_attacks(pid: int) -> void:
	restrict_player(pid, ATTACK_LOCK_KEY)


## Static so `BattleRules` can ask without holding a `ContinuousEffects` instance. There is
## deliberately one implementation of the question.
static func attacks_restricted(p_state: GameState, pid: int) -> bool:
	return bool(p_state.player(pid).get_restriction(
		PLAYER_KEY_PREFIX + ATTACK_LOCK_KEY, false))


# ---------------------------------------------------------------------------
# Player-level CARD-CLASS activation lock. RULES_SPEC.md 4.4.
# ---------------------------------------------------------------------------

## "Your opponent cannot activate Trap Cards during the Battle Phase." (`Mirage Dragon`)
##
## A generic channel keyed by CARD CATEGORY and PHASE, not by card name. `ActivationRules`
## asks it once, for every card activation, so no card ever appears by name in the legality
## gate — the same reason `CONTROL_LIMIT_EFFECT_ID` and `TRIBUTE_VALUE_EFFECT_ID` are
## declarative markers rather than a list of the three cards that use them.
##
## Two things this key is careful about:
##
##   * it locks the activation of a CARD of that category, not the activation of an EFFECT of
##     a card of that category. See `ActivationRules.card_class_activation_ok()` and
##     CARD_RULINGS.md R6.
##   * `phase` may be null, meaning "in every phase". Nothing in the V1 pool needs that, but
##     the key shape has to be able to say it or the next card that does would arrive as a
##     second, differently-shaped mechanism.
const ACTIVATION_LOCK_PREFIX := "cannot_activate_category:"


static func activation_lock_key(category: Enums.Category, phase) -> String:
	return "%s%d:%s" % [ACTIVATION_LOCK_PREFIX, int(category),
		"any" if phase == null else str(int(phase))]


func restrict_card_activation(pid: int, category: Enums.Category, phase = null) -> void:
	restrict_player(pid, activation_lock_key(category, phase))


## Is `pid` currently forbidden from activating a card of `category`, given `p_state.phase`?
## True when either an every-phase lock or a lock naming the current phase applies.
static func card_activation_locked(p_state: GameState, pid: int,
		category: Enums.Category) -> bool:
	var p := p_state.player(pid)
	if bool(p.get_restriction(
			PLAYER_KEY_PREFIX + activation_lock_key(category, null), false)):
		return true
	return bool(p.get_restriction(
		PLAYER_KEY_PREFIX + activation_lock_key(category, p_state.phase), false))

class_name ChainManager
extends RefCounted

## Chain construction and resolution. RULES_SPEC.md 4, master prompt 12.
##
## Rules implemented here, all from RULES_SOURCES.md S1/S2:
##   * Chain Link 1 is the first activation; each later activation is the next link.
##   * To respond, an effect must be Spell Speed >= 2 AND >= the previous link's
##     Spell Speed [S1 p.44].
##   * Spell Speed 1 can only be Chain Link 2+ when multiple Spell Speed 1 effects are
##     activated simultaneously [S1 p.44] — handled by build_simultaneous_chain().
##   * The Chain closes after two consecutive passes [S2 box D].
##   * Resolution is strictly reverse order [S1 p.46-47].
##   * No new Chain starts mid-resolution; events raised during resolution are deferred
##     and processed after the Chain fully resolves (master prompt 45).

var state: GameState = null
## The DuelEngine, passed through to each EffectContext so effects can reach the timing
## machine. Null in the pure-chain unit tests, which do not need it.
var engine = null
## The links of the most recently resolved Chain, kept after state.chain is cleared so
## the caller can apply post-resolution rules (a Normal Spell/Trap going to the GY).
var last_resolved_links: Array = []


func _init(p_state: GameState, p_engine = null) -> void:
	state = p_state
	engine = p_engine


# ---------------------------------------------------------------------------
# Response legality. RULES_SPEC.md 4.1/4.2.
# ---------------------------------------------------------------------------

## Spell Speed of the current top link, or 0 when the Chain is empty.
func current_top_spell_speed() -> int:
	if state.chain.is_empty():
		return 0
	return state.chain.back().spell_speed()


## May an effect with this Spell Speed be added as the next Chain Link?
##
## Empty chain: any Spell Speed may start it (an Ignition Effect or Normal Spell is
## Spell Speed 1 and legally becomes Chain Link 1).
## Non-empty chain: must be Spell Speed >= 2 and >= the top link's Spell Speed.
func can_respond_with_spell_speed(spell_speed: int) -> bool:
	if state.chain.is_empty():
		return true
	if spell_speed < Enums.SpellSpeed.SS2:
		return false
	return spell_speed >= current_top_spell_speed()


func chain_size() -> int:
	return state.chain.size()


func is_chain_active() -> bool:
	return not state.chain.is_empty()


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

## Append an activation as the next Chain Link. Costs must already be paid and
## targets already chosen by the caller (RULES_SPEC.md 10 — both happen at activation).
func add_link(source: CardInstance, effect: EffectDef, controller_id: int,
		target_ids: Array = [], cost_payload: Dictionary = {},
		params: Dictionary = {}) -> ChainLink:
	var link := ChainLink.new(source, effect, controller_id)
	link.link_number = state.chain.size() + 1
	link.target_ids = target_ids.duplicate()
	link.cost_payload = cost_payload.duplicate()
	link.params = params.duplicate()
	state.chain.append(link)

	state.emit(GameEvent.Kind.EFFECT_ACTIVATED, {
		"card_id": source.id if source != null else -1,
		"card_name": link.card_name(),
		"effect_id": effect.effect_id if effect != null else "",
		"clause_text": effect.clause_text if effect != null else "",
		"controller": controller_id,
		"spell_speed": link.spell_speed(),
		"link_number": link.link_number,
	})
	state.emit(GameEvent.Kind.CHAIN_LINK_ADDED, {
		"link_number": link.link_number,
		"card_id": source.id if source != null else -1,
		"card_name": link.card_name(),
		"controller": controller_id,
		"target_ids": link.target_ids.duplicate(),
	})
	if not link.target_ids.is_empty():
		state.emit(GameEvent.Kind.TARGET_SELECTED, {
			"link_number": link.link_number,
			"target_ids": link.target_ids.duplicate(),
			"by": controller_id,
		})
	return link


## Build the opening links of a Chain from effects that triggered off the same event.
##
## Order is fixed by [S1 p.51]:
##   1. turn player's mandatory  2. opponent's mandatory
##   3. turn player's optional   4. opponent's optional
## with the player choosing the internal order within each group.
##
## `groups` is the pre-ordered array of {source, effect, controller, targets, cost, params}
## dictionaries produced by TriggerCollector, which is responsible for asking each player
## to order their own group and for asking whether to use optional effects.
func build_simultaneous_chain(ordered_activations: Array) -> void:
	for a in ordered_activations:
		add_link(a["source"], a["effect"], int(a["controller"]),
			a.get("targets", []), a.get("cost", {}), a.get("params", {}))


# ---------------------------------------------------------------------------
# Negation. Master prompt 18 — these are genuinely different.
# ---------------------------------------------------------------------------

## Negate the ACTIVATION of a link: it never resolves and, for Spell/Trap cards, is
## treated as not having been successfully activated.
func negate_activation(link_number: int, by_source: CardInstance) -> bool:
	var link := link_at(link_number)
	if link == null or link.resolved:
		return false
	link.activation_negated = true
	state.emit(GameEvent.Kind.ACTIVATION_NEGATED, {
		"link_number": link_number,
		"card_id": link.source_card.id if link.source_card != null else -1,
		"card_name": link.card_name(),
		"by_card_id": by_source.id if by_source != null else -1,
	})
	return true


## Negate the EFFECT of a link: the activation still happened (so costs stay paid and
## "when you activate" triggers still saw it), but the effect does not apply.
func negate_effect(link_number: int, by_source: CardInstance) -> bool:
	var link := link_at(link_number)
	if link == null or link.resolved:
		return false
	link.effect_negated = true
	state.emit(GameEvent.Kind.EFFECT_NEGATED, {
		"link_number": link_number,
		"card_id": link.source_card.id if link.source_card != null else -1,
		"card_name": link.card_name(),
		"by_card_id": by_source.id if by_source != null else -1,
	})
	return true


func link_at(link_number: int) -> ChainLink:
	for l in state.chain:
		if l.link_number == link_number:
			return l
	return null


func top_link() -> ChainLink:
	return state.chain.back() if not state.chain.is_empty() else null


# ---------------------------------------------------------------------------
# Resolution. [S1 p.46-47]
# ---------------------------------------------------------------------------

## Resolve the whole Chain, highest link first. Returns the events that were deferred
## during resolution for the caller to process afterwards (master prompt 45).
##
## `controllers` is the per-player-id array of PlayerControllers; each link is resolved
## with its OWN controller attached, so a mid-resolution choice is always put to the
## player who activated that link.
func resolve_chain(controllers = null) -> Array:
	if state.chain.is_empty():
		return []

	state.emit(GameEvent.Kind.CHAIN_CLOSED, {"links": state.chain.size()})

	state.chain_is_resolving = true
	state.deferred_trigger_events.clear()
	last_resolved_links = state.chain.duplicate()

	# Strictly reverse order.
	for i in range(state.chain.size() - 1, -1, -1):
		if state.is_duel_over():
			break
		var link: ChainLink = state.chain[i]
		_resolve_link(link, _controller_for(controllers, link.controller_id))

	state.chain_is_resolving = false

	var links_resolved := state.chain.size()
	state.chain.clear()
	state.emit(GameEvent.Kind.CHAIN_RESOLVED, {"links": links_resolved})

	var deferred := state.deferred_trigger_events.duplicate()
	state.deferred_trigger_events.clear()
	return deferred


static func _controller_for(controllers, pid: int):
	if controllers is Array and pid >= 0 and pid < controllers.size():
		return controllers[pid]
	return null


func _resolve_link(link: ChainLink, decider) -> void:
	state.emit(GameEvent.Kind.CHAIN_LINK_RESOLVING, {
		"link_number": link.link_number,
		"card_id": link.source_card.id if link.source_card != null else -1,
		"card_name": link.card_name(),
		"negated": link.is_negated(),
	})

	if not link.should_resolve():
		link.resolved = true
		if link.resolution_note == "":
			link.resolution_note = "negated"
		state.emit(GameEvent.Kind.CHAIN_LINK_RESOLVED, {
			"link_number": link.link_number,
			"resolved": false,
			"note": link.resolution_note,
		})
		return

	var effect := link.effect
	if effect == null or not effect.resolve.is_valid():
		# Master prompt 67: fail loudly rather than silently skipping an effect.
		push_error("ChainManager: no resolve() for %s link %d — effect '%s'" % [
			link.card_name(), link.link_number,
			effect.effect_id if effect != null else "<null>"])
		link.resolved = true
		link.resolution_note = "UNIMPLEMENTED EFFECT"
		state.emit(GameEvent.Kind.CHAIN_LINK_RESOLVED, {
			"link_number": link.link_number,
			"resolved": false,
			"note": link.resolution_note,
			"error": true,
		})
		return

	var ctx := EffectContext.new(state, link.source_card, effect)
	ctx.controller_id = link.controller_id
	ctx.link = link
	ctx.decider = decider
	ctx.engine = engine
	ctx.chosen_target_ids = link.target_ids.duplicate()
	# What the COST actually consumed, carried forward from activation. A clause whose
	# effect is measured by its own cost — `Wonder Balloons`' "place 1 Balloon Counter on
	# this card FOR EACH card sent to the GY" — cannot be resolved without it, and a cost is
	# never re-inspected or recomputed at resolution. RULES_SPEC.md 10.
	ctx.cost_payload = link.cost_payload.duplicate()

	effect.resolve.call(ctx)

	link.resolved = true
	state.emit(GameEvent.Kind.CHAIN_LINK_RESOLVED, {
		"link_number": link.link_number,
		"resolved": true,
		"note": link.resolution_note,
	})


## Called by GameState consumers while a Chain resolves: record the event instead of
## letting it start a new Chain immediately. Master prompt 45.
func defer_trigger_event(ev: GameEvent) -> void:
	state.deferred_trigger_events.append(ev)

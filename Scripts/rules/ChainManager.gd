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
	for id in target_ids:
		var target: CardInstance = state.instance(id)
		if target != null:
			link.target_field_revisions[id] = target.field_revision
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


# ---------------------------------------------------------------------------
# Effect SUBSTITUTION. RULES_SPEC.md 10.11, CARD_RULINGS.md R5.
# ---------------------------------------------------------------------------

## "The activated effect BECOMES '…'" — replace what a link already on the Chain will
## resolve, without negating anything.
##
## This is a THIRD operation beside the two negations above, and collapsing it into either
## of them gets the official rulings wrong in opposite directions:
##
##   * it is NOT `negate_activation()`. The card was activated and stays activated. A
##     "when this card is activated" trigger already fired and keeps its result, the card
##     still counts as having resolved, and a Normal Spell/Trap still reaches the Graveyard
##     as a resolved card rather than as a negated one;
##   * it is NOT `negate_effect()` plus a new link. The substituted text resolves as THIS
##     link, in THIS link's position, under THIS link's controller — which matters, because
##     the replacement's own "your opponent" is read from the perspective of the player who
##     controls the card being substituted, not the one doing the substituting (R5 Part B).
##
## What survives, and what does not, is the whole of R5 Part D and is decided ENTIRELY by
## which field this writes:
##
##   * a restriction that lives inside the replaced effect's own `resolve` is replaced away
##     with it — official Q&A fid 8714;
##   * a restriction that is an `ACTIVATION_CONDITION_EFFECT_ID` clause with an
##     `activation_confirmed` callable is NOT touched, because `_resolve_link()` runs those
##     off `link.source_card.definition.effects` and gates them on `link.effect`, both of
##     which this leaves alone — official Q&A fid 19695.
##
## Refuses loudly rather than silently for every impossible case: no such link, a link that
## has already resolved, a link already carrying a substitution, and a null replacement.
## A link whose ACTIVATION was negated is deliberately still substitutable — the
## substitution is simply never reached, which is the correct outcome and is asserted.
func substitute_link_effect(link_number: int, replacement: EffectDef,
		by_source: CardInstance) -> bool:
	var link := link_at(link_number)
	if link == null:
		push_error("ChainManager.substitute_link_effect: no link %d on the Chain"
			% link_number)
		return false
	if link.resolved:
		push_error("ChainManager.substitute_link_effect: link %d (%s) has already resolved"
			% [link_number, link.card_name()])
		return false
	if replacement == null:
		push_error("ChainManager.substitute_link_effect: null replacement for link %d (%s)"
			% [link_number, link.card_name()])
		return false
	if link.is_substituted():
		# Two substitutions of one link is not a case any official text produces, and
		# silently letting the second win would hide whichever card lost.
		push_error("ChainManager.substitute_link_effect: link %d (%s) is already "
			% [link_number, link.card_name()]
			+ "substituted with '%s'" % link.substituted_effect.effect_id)
		return false

	link.substituted_effect = replacement
	link.substituted_by_card_id = by_source.id if by_source != null else -1
	state.emit(GameEvent.Kind.CHAIN_LINK_EFFECT_SUBSTITUTED, {
		"link_number": link_number,
		"card_id": link.source_card.id if link.source_card != null else -1,
		"card_name": link.card_name(),
		"from_effect_id": link.effect.effect_id if link.effect != null else "",
		"to_effect_id": replacement.effect_id,
		"to_clause_text": replacement.clause_text,
		"by_card_id": link.substituted_by_card_id,
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
		_resolve_link(link, _controller_for(controllers, link.controller_id), controllers)

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


func _resolve_link(link: ChainLink, decider, controllers = null) -> void:
	state.emit(GameEvent.Kind.CHAIN_LINK_RESOLVING, {
		"link_number": link.link_number,
		"card_id": link.source_card.id if link.source_card != null else -1,
		"card_name": link.card_name(),
		"negated": link.is_negated(),
		"substituted": link.is_substituted(),
	})

	# Activation conditions survive EFFECT negation and source departure. R39 / spec 5.9.
	# They ALSO survive effect SUBSTITUTION, and that is not an accident of this code: it
	# is official Q&A fid 19695, and it works because this block reads the card's own
	# `definition.effects` and gates on `link.effect` — the ORIGINAL — rather than on what
	# the link now resolves. Do not "tidy" either read into `resolving_effect()`.
	# RULES_SPEC.md 10.11, CARD_RULINGS.md R5 Part D.
	# No phase can be conducted while this Chain is unresolved.
	if not link.activation_negated and link.effect != null and link.source_card != null and link.effect.effect_type == Enums.EffectType.CARD_ACTIVATION:
		for clause in link.source_card.definition.effects:
			if clause.effect_id == ActivationRules.ACTIVATION_CONDITION_EFFECT_ID and clause.activation_confirmed.is_valid():
				var activation_ctx := EffectContext.new(state, link.source_card, clause)
				activation_ctx.controller_id = link.controller_id
				clause.activation_confirmed.call(activation_ctx)

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

	# What RESOLVES, which is not always what was activated. RULES_SPEC.md 10.11.
	var effect := link.resolving_effect()
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
	# The whole controller table, not just this link's own controller: a clause whose text
	# puts a decision to the OTHER player resolves through `ctx.ask_player()`, and that
	# needs somebody to ask. CARD_RULINGS.md R11.
	if controllers is Array:
		ctx.deciders = controllers
	ctx.engine = engine
	# Targets belong to the effect that DECLARED them. A substituted link resolves a
	# different effect, which declared none of its own — R5 Part C: the replacement
	# 「…１体を選んで…」 chooses at resolution and targets nothing. Handing it the original
	# card's targets would let `ctx.first_target()` silently return a card the resolving
	# text never named. `link.target_ids` is left intact as the activation record.
	ctx.chosen_target_ids = [] if link.is_substituted() else link.target_ids.duplicate()
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
		# The card resolved; it resolved something else. Both halves matter to a replay,
		# and "resolved: true" alone would lose the second one.
		"substituted": link.is_substituted(),
		"resolved_effect_id": effect.effect_id,
	})


## Called by GameState consumers while a Chain resolves: record the event instead of
## letting it start a new Chain immediately. Master prompt 45.
func defer_trigger_event(ev: GameEvent) -> void:
	state.deferred_trigger_events.append(ev)

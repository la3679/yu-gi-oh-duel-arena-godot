class_name TriggerCollector
extends RefCounted

## Collects Trigger / Flip Effects that became eligible from a batch of events, and puts
## them in the order the Chain must be built in. RULES_SPEC.md 4.4, master prompt 14/24.
##
## Ordering is fixed by [S1 p.51] and is NOT invented here:
##   1. turn player's mandatory effects   (turn player chooses the order within the group)
##   2. opponent's mandatory effects      (opponent chooses)
##   3. turn player's optional effects    (turn player chooses)
##   4. opponent's optional effects       (opponent chooses)
##
## An optional effect is never auto-activated: its controller is asked (master prompt 24).
## A mandatory effect is never asked about — it must happen.
##
## Quick Effects are NOT collected here. They are fast effects offered in response
## windows by DuelEngine, because the player chooses when to use them.

var state: GameState = null
## PlayerController per player id, used to ask ordering / optional questions.
var controllers: Array = []
## Replay log, assigned by DuelEngine. Every question put to a player is a duel INPUT, so
## it has to be recorded or the replay payload cannot reproduce the duel. Master prompt 70.
var log: DuelLog = null


func _record(request: DecisionRequest, answer) -> void:
	if log != null:
		log.record_decision(state, request, answer)


func _init(p_state: GameState, p_controllers: Array = []) -> void:
	state = p_state
	controllers = p_controllers


func _controller(pid: int):
	if pid >= 0 and pid < controllers.size():
		return controllers[pid]
	return null


# ---------------------------------------------------------------------------
# Collection
# ---------------------------------------------------------------------------

## Every Trigger/Flip Effect made eligible by `events`.
##
## Returns an Array of {source, effect, controller, event}. An effect appears at most
## once per batch even if several events in the batch would have triggered it: one
## activation condition being met several times still activates the effect once.
func collect(events: Array) -> Array:
	var found := []
	var seen := {}
	for ev in events:
		for card in state.all_instances():
			if card.definition == null:
				continue
			for effect in card.definition.effects:
				if not _is_collectable(effect):
					continue
				if not effect.trigger_events.has(ev.kind):
					continue
				var key := "%d::%s" % [card.id, effect.effect_id]
				if seen.has(key):
					continue
				var controller_id: int = card.controller_id
				if not ActivationRules.can_activate(state, card, effect, controller_id, ev):
					continue
				seen[key] = true
				found.append({
					"source": card,
					"effect": effect,
					"controller": controller_id,
					"event": ev,
				})
	return found


static func _is_collectable(effect: EffectDef) -> bool:
	return effect.effect_type == Enums.EffectType.TRIGGER \
		or effect.effect_type == Enums.EffectType.FLIP


# ---------------------------------------------------------------------------
# Ordering. RULES_SPEC.md 4.4 [S1 p.51]
# ---------------------------------------------------------------------------

## Turns raw eligible triggers into the exact order the Chain Links must be created in,
## after asking each player about their own optional effects and their own group order.
func order_activations(eligible: Array) -> Array:
	if eligible.is_empty():
		return []

	var tp := state.turn_player_id
	var opp := state.opponent_id(tp)

	var groups := [
		_filter(eligible, tp, Enums.Optionality.MANDATORY),
		_filter(eligible, opp, Enums.Optionality.MANDATORY),
		_ask_optional(_filter(eligible, tp, Enums.Optionality.OPTIONAL)),
		_ask_optional(_filter(eligible, opp, Enums.Optionality.OPTIONAL)),
	]
	var group_owner := [tp, opp, tp, opp]

	var ordered := []
	for i in range(groups.size()):
		ordered.append_array(_order_within_group(groups[i], group_owner[i], i))
	return ordered


static func _filter(eligible: Array, pid: int, opt: Enums.Optionality) -> Array:
	return eligible.filter(func(e):
		return int(e["controller"]) == pid and e["effect"].optionality == opt)


## Master prompt 24: an optional Trigger Effect must be offered as an explicit choice,
## never fired silently.
func _ask_optional(group: Array) -> Array:
	var kept := []
	for entry in group:
		var pid: int = int(entry["controller"])
		var ctrl = _controller(pid)
		if ctrl == null:
			# No controller attached (pure-rules evaluation): do not fire optional
			# effects. Silence must never become "yes".
			continue
		var effect: EffectDef = entry["effect"]
		var source: CardInstance = entry["source"]
		var req := DecisionRequest.yes_no(pid,
			"Activate the effect of %s?" % source.card_name(), source, effect)
		var answer = ctrl.decide(req)
		_record(req, answer)
		if typeof(answer) == TYPE_BOOL and answer:
			kept.append(entry)
	return kept


## Within one group the owning player chooses the order. Asked only when it matters.
func _order_within_group(group: Array, pid: int, group_index: int) -> Array:
	if group.size() <= 1:
		return group
	var ctrl = _controller(pid)
	if ctrl == null:
		return group
	var options := []
	for entry in group:
		options.append({
			"card_id": entry["source"].id,
			"card_name": entry["source"].card_name(),
			"effect_id": entry["effect"].effect_id,
			"clause_text": entry["effect"].clause_text,
		})
	var req := DecisionRequest.order(pid,
		"Choose the order these effects are put onto the Chain",
		options, {"group_index": group_index})
	var answer = ctrl.decide(req)
	_record(req, answer)
	if not req.validate(answer):
		push_error("TriggerCollector: invalid trigger ordering from player %d" % pid)
		return group
	var out := []
	for idx in answer:
		out.append(group[int(idx)])
	return out


## Convenience: collect and order in one call.
func collect_ordered(events: Array) -> Array:
	return order_activations(collect(events))

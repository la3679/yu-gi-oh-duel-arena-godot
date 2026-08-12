class_name EffectContext
extends RefCounted

## Everything an effect callable needs. Passed to condition / cost / target / resolve.
##
## Effects never reach for globals: all state access goes through this object, which
## keeps card behaviour testable in isolation and keeps the engine the single authority.

var state: GameState = null
var source: CardInstance = null
var effect: EffectDef = null
var controller_id: int = 0

## The chain link this activation created. Null while merely testing legality
## (condition / can_pay_cost are evaluated before a link exists).
var link: ChainLink = null

## The event that made a TRIGGER/FLIP/QUICK effect eligible, if any.
var trigger_event: GameEvent = null

## Interface used to ask a player something mid-resolution. Master prompt 42.
## Assigned by DuelEngine; null in pure-legality checks.
var decider = null


func _init(p_state: GameState = null, p_source: CardInstance = null,
		p_effect: EffectDef = null) -> void:
	state = p_state
	source = p_source
	effect = p_effect
	if p_source != null:
		controller_id = p_source.controller_id


func me() -> PlayerState:
	return state.player(controller_id)


func opponent() -> PlayerState:
	return state.opponent_of(controller_id)


func opponent_id() -> int:
	return state.opponent_id(controller_id)


func targets() -> Array:
	return link.targets(state) if link != null else []


func first_target():
	var t := targets()
	return t[0] if not t.is_empty() else null


## Convenience: is this effect's source still where it needs to be to resolve?
func source_still_valid(required_zone: Enums.Zone) -> bool:
	return source != null and source.zone == required_zone


func log_note(text: String) -> void:
	if link != null:
		link.resolution_note = text

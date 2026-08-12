class_name PlayerController
extends RefCounted

## The abstraction every player sits behind. Master prompt 69.
##
## Local human, future CPU and future network players all implement this same
## interface, and all of them go through DuelEngine's legality checks — a controller
## can only ever pick from actions the engine already declared legal.
##
## A controller is given only what its player may legally see
## (GameState.get_visible_state(player_id)); it never reads hidden state.
##
## The interface is deliberately synchronous. DuelEngine calls decide() at a decision
## point and the answer comes straight back, which is what makes the whole engine
## deterministic and headless-testable. The Phase 7 UI supplies a controller that
## bridges this to on-screen prompts.

var player_id: int = 0
var display_name: String = "Player"
## Set to true only by a debug controller. Master prompt 71/90 — a normal controller
## must never be allowed to read the opponent's hidden information.
var is_debug: bool = false


func _init(p_player_id: int = 0, p_name: String = "Player") -> void:
	player_id = p_player_id
	display_name = p_name


## Answer a structured question. Return type depends on request.kind:
##   YES_NO          -> bool
##   ORDER_TRIGGERS  -> Array[int], a permutation of option indices
##   every other kind-> Array of chosen option values (usually CardInstance ids)
func decide(_request: DecisionRequest):
	push_error("PlayerController.decide() not implemented for '%s'" % display_name)
	return null


## Pick one of the actions the engine has already declared legal, or null to take no
## action where that is itself legal. Used by scripted/CPU drivers; the interactive UI
## instead submits actions to DuelEngine as the human clicks.
func choose_action(_legal_actions: Array):
	return null


func _to_string() -> String:
	return "PlayerController(p%d '%s')" % [player_id, display_name]

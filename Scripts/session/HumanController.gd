class_name HumanController
extends PlayerController

## A player answered by a person through an `EngineSession`. Phase 7 unit A (ADR-0001).
##
## `decide()` runs on the session's WORKER thread, inside the engine's own call stack. It hands
## the request to the session core — which publishes it on this player's channel only — and
## blocks until the owner thread answers that prompt or the session is stopped. Nothing here
## touches the scene tree, and nothing here judges an answer: the engine's own
## `DecisionRequest.validate()` does, and the engine records every answer in `DuelLog`, so
## replay and determinism are exactly what they are for any other controller.

## The session core that carries requests to the UI. Cleared when the session shuts down, which
## also breaks the only reference cycle (core -> engine -> controllers -> core).
var bridge = null


func _init(p_player_id: int = 0, p_name: String = "Player", p_bridge = null) -> void:
	super(p_player_id, p_name)
	bridge = p_bridge


func decide(request: DecisionRequest):
	var b = bridge
	if b == null:
		# The session is gone. Answer so the engine can unwind — never null, which the engine
		# treats as a hard error.
		return EngineSession.default_answer(request)
	return b.ask(player_id, request)

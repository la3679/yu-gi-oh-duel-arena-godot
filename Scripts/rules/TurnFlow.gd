class_name TurnFlow
extends RefCounted

## Turn and phase progression. RULES_SPEC.md 2, master prompt 10.
##
##   Draw Phase -> Standby Phase -> Main Phase 1 -> [Battle Phase] -> [Main Phase 2]
##                                                                 -> End Phase
##
## Main Phase 2 exists only after a Battle Phase was conducted [S1 p.34, p.40].
##
## This class performs phase entry/exit; it does NOT decide when to advance. The turn
## player declares an intent, the opponent gets their Fast Effect Timing window
## (RULES_SPEC.md 3 box E), and only then does DuelEngine call in here. That ordering is
## what stops a phase change from skipping a legal response window.

var state: GameState = null
## PlayerController per player id, needed for the End Phase hand-size discard.
var controllers: Array = []

## True once the End Phase hand-size check has been carried out for this turn, so the
## discard happens at the END of the End Phase and any effects it triggers still resolve
## during that End Phase rather than on the next player's turn. [S1 p.40]
var end_phase_cleanup_done: bool = false

## Replay log, assigned by DuelEngine. The hand-size discard is a player CHOICE, so it is
## a duel input and has to be recorded for the replay payload. Master prompt 70.
var log: DuelLog = null


func _init(p_state: GameState, p_controllers: Array = []) -> void:
	state = p_state
	controllers = p_controllers


func _controller(pid: int):
	if pid >= 0 and pid < controllers.size():
		return controllers[pid]
	return null


# ---------------------------------------------------------------------------
# Phase order
# ---------------------------------------------------------------------------

## The phase reached by simply finishing the current one, given whether a Battle Phase
## has been conducted this turn.
func next_phase_after(phase: Enums.Phase) -> Enums.Phase:
	match phase:
		Enums.Phase.DRAW:
			return Enums.Phase.STANDBY
		Enums.Phase.STANDBY:
			return Enums.Phase.MAIN_1
		Enums.Phase.MAIN_1:
			return Enums.Phase.END
		Enums.Phase.BATTLE:
			return Enums.Phase.MAIN_2
		Enums.Phase.MAIN_2:
			return Enums.Phase.END
		_:
			return Enums.Phase.END


## "The player who goes first cannot conduct a Battle Phase on their first turn."
## [S1 p.37]
func can_enter_battle_phase(pid: int) -> bool:
	if state.turn_player_id != pid:
		return false
	if state.phase != Enums.Phase.MAIN_1:
		return false
	if state.turn_number == 1 and state.first_player_id == pid:
		return false
	# Two deliberately separate restrictions, because they have different lifetimes:
	#
	#   `skip_battle_phase_this_turn`  — one-shot and turn-scoped, written by a resolving
	#      effect (`Runick Flashing Fire`: "skip your next Battle Phase after activation")
	#      and cleared by _end_of_turn_cleanup(). It is NOT namespaced, so a continuous
	#      recompute must not wipe it.
	#   `continuous:cannot_conduct_battle_phase` — state-derived, rebuilt from its face-up
	#      source on every ContinuousEffects.recompute(), and gone the moment that source
	#      stops applying.
	#
	# Both must block the Battle Phase; neither may be expressed in terms of the other.
	if bool(state.player(pid).get_restriction("skip_battle_phase_this_turn", false)):
		return false
	if bool(state.player(pid).get_restriction(
			ContinuousEffects.PLAYER_KEY_PREFIX + "cannot_conduct_battle_phase", false)):
		return false
	return true


# ---------------------------------------------------------------------------
# Phase entry
# ---------------------------------------------------------------------------

func enter_phase(new_phase: Enums.Phase) -> void:
	var old := state.phase
	state.phase = new_phase
	state.battle_step = Enums.BattleStep.NONE
	state.damage_substep = Enums.DamageSubStep.NONE
	state.emit(GameEvent.Kind.PHASE_CHANGED, {
		"from": old, "to": new_phase, "turn_player": state.turn_player_id,
		"turn": state.turn_number,
	})
	if new_phase == Enums.Phase.BATTLE:
		state.battle_phase_conducted_this_turn = true
	if new_phase == Enums.Phase.DRAW:
		_do_draw_phase_draw()
	if new_phase == Enums.Phase.END:
		# "…take control of that target UNTIL THE END PHASE" (`Enemy Controller`): the lease
		# runs up TO the End Phase, so it ends as the End Phase is entered — before the
		# hand-size discard, which is the *end* of the End Phase [S1 p.40], and therefore
		# before anything either player does during it. This engine's End Phase is two
		# steps, so the moment has to be named explicitly rather than left to "some point in
		# the End Phase". RULES_SPEC.md 5.6, CARD_RULINGS.md R25.
		state.expire_control_leases(true)
		# "…banish that target UNTIL THE END PHASE" (`Interdimensional Matter Transporter`)
		# names the same moment as the control lease above and must not come to mean a
		# different one, so the two expire side by side, here, at the ENTRY to the End Phase.
		# RULES_SPEC.md 8.3, CARD_RULINGS.md R25/R30.
		state.expire_banish_leases(true)


## "The player who goes first does not draw during the Draw Phase of their first turn."
## A player who must draw and cannot loses the Duel. [S1 p.33, p.35]
func _do_draw_phase_draw() -> void:
	if state.turn_number == 1 and state.turn_player_id == state.first_player_id:
		return
	state.draw(state.turn_player_id, 1)


# ---------------------------------------------------------------------------
# End Phase cleanup. [S1 p.40]
# ---------------------------------------------------------------------------

func needs_end_phase_cleanup() -> bool:
	return state.phase == Enums.Phase.END and not end_phase_cleanup_done


## Hand size limit 6, discarded at the end of the End Phase. Emits real DISCARD moves so
## GY triggers see them; DuelEngine runs a trigger check afterwards, still in this phase.
func perform_end_phase_cleanup() -> void:
	end_phase_cleanup_done = true
	var pid := state.turn_player_id
	var p := state.player(pid)
	var excess := p.hand.size() - PlayerState.HAND_SIZE_LIMIT
	if excess <= 0:
		return

	var ctrl = _controller(pid)
	var chosen: Array = []
	if ctrl != null:
		var options := p.hand.map(func(c): return c.id)
		var req := DecisionRequest.select(Enums.DecisionKind.CHOOSE_DISCARD, pid,
			"Discard down to %d cards" % PlayerState.HAND_SIZE_LIMIT,
			options, excess, excess)
		var answer = ctrl.decide(req)
		if log != null:
			log.record_decision(state, req, answer)
		if req.validate(answer):
			chosen = answer
		else:
			push_error("TurnFlow: invalid hand-size discard from player %d" % pid)
	if chosen.size() != excess:
		# Never leave the hand illegal: fall back to the oldest cards, and say so.
		chosen = []
		for i in range(excess):
			chosen.append(p.hand[i].id)

	for cid in chosen:
		var card = state.instance(cid)
		if card != null:
			state.move_card(card, Enums.Zone.GRAVEYARD, Enums.MoveReason.HAND_SIZE_DISCARD)


# ---------------------------------------------------------------------------
# Turn transition
# ---------------------------------------------------------------------------

## Starts the very first turn of the Duel. `first` also becomes the turn player.
func begin_first_turn(first: int) -> void:
	state.first_player_id = first
	state.turn_player_id = first
	state.turn_number = 1
	_begin_turn_common()


## Ends the current turn and starts the opponent's.
func begin_next_turn() -> void:
	_end_of_turn_cleanup()
	state.turn_player_id = state.opponent_id(state.turn_player_id)
	state.turn_number += 1
	_begin_turn_common()


func _begin_turn_common() -> void:
	end_phase_cleanup_done = false
	state.battle_phase_conducted_this_turn = false
	state.player(state.turn_player_id).begin_turn()
	state.emit(GameEvent.Kind.TURN_STARTED, {
		"turn": state.turn_number, "player": state.turn_player_id,
	})
	enter_phase(Enums.Phase.DRAW)


## Per-turn state that expires when the turn ends. RULES_SPEC.md 11.
func _end_of_turn_cleanup() -> void:
	for card in state.all_instances():
		card.remove_modifiers_with_duration("end_of_turn")
	for p in state.players:
		p.end_turn(state.turn_number)
		p.clear_restriction("skip_battle_phase_this_turn")

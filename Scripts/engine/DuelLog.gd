class_name DuelLog
extends RefCounted

## Action / replay log. Master prompt 8 and 70.
##
## The duel is deterministic given (decks, RNG seed, player decisions), so recording the
## seed plus the ordered list of submitted actions and decision answers is enough to
## reproduce any duel exactly. That is what makes a reported bug reproducible instead of
## anecdotal.
##
## This records INPUTS (actions, decisions) and the engine's own semantic events. It is
## never consulted to decide legality.

var seed_value: int = 0
var deck_names: Array = ["", ""]
## Each player's Deck as an ordered list of card names, captured BEFORE the opening
## shuffle. Without it the payload cannot reproduce a duel: the seed only determines how a
## known Deck is shuffled, so the Deck contents and their pre-shuffle order are as much an
## input as the seed is. Master prompt 70.
var deck_lists: Array = [[], []]
var first_player_id: int = 0

## Ordered submitted actions: {seq, turn, phase, action: <DuelAction.to_dict()>}
var actions: Array = []
## Ordered decision answers: {seq, turn, phase, request: {...}, answer: <value>}
var decisions: Array = []
## Ordered engine events, as dictionaries. Mirrors GameState.events.
var entries: Array = []

var _seq: int = 0


## Called by DuelEngine.setup_duel() after the Decks are built and BEFORE they are
## shuffled, so `deck_lists` is the pre-shuffle order the seed is then applied to.
func begin(state: GameState) -> void:
	seed_value = state.rng.get_seed()
	first_player_id = state.first_player_id
	deck_names = [state.player(0).deck_name, state.player(1).deck_name]
	deck_lists = []
	for pid in range(GameState.PLAYER_COUNT):
		var names: Array = []
		for card in state.player(pid).deck:
			names.append(card.card_name())
		deck_lists.append(names)


func record_action(state: GameState, action: DuelAction) -> void:
	actions.append({
		"seq": _next(),
		"turn": state.turn_number,
		"phase": state.phase,
		"action": action.to_dict(),
	})


func record_decision(state: GameState, request: DecisionRequest, answer) -> void:
	decisions.append({
		"seq": _next(),
		"turn": state.turn_number,
		"phase": state.phase,
		"request": request.to_dict(),
		"answer": answer,
	})


func record_event(ev: GameEvent) -> void:
	entries.append({
		"seq": _next(),
		"event_seq": ev.sequence,
		"turn": ev.turn,
		"phase": ev.phase,
		"kind": GameEvent.kind_name(ev.kind),
		"data": ev.data.duplicate(),
	})


func _next() -> int:
	var n := _seq
	_seq += 1
	return n


## Everything needed to replay this duel: the seed, the decks and the ordered inputs.
func to_replay() -> Dictionary:
	return {
		"seed": seed_value,
		"deck_names": deck_names.duplicate(),
		"deck_lists": deck_lists.duplicate(true),
		"first_player": first_player_id,
		"actions": actions.duplicate(true),
		"decisions": decisions.duplicate(true),
	}


func to_json() -> String:
	return JSON.stringify(to_replay(), "  ")


## Read back a payload stored with `to_json()`, ready to replay.
##
## JSON has one number type, so every id, index and enum value comes back as a FLOAT, and the
## engine compares decision answers against the offered options by value AND type — a
## recorded answer `[12]` read back as `[12.0]` is not one of the options `[12]`. A whole-number
## float is therefore restored to an int, recursively. The payload never records a genuinely
## fractional number, so nothing is lost. Returns {} when the text is not a payload.
static func payload_from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return _restore_ints(parsed)


static func _restore_ints(value):
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			return int(f) if f == floorf(f) else f
		TYPE_ARRAY:
			var out: Array = []
			for v in value:
				out.append(_restore_ints(v))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k in value.keys():
				out[k] = _restore_ints(value[k])
			return out
		_:
			return value


## Human-readable trace for debugging a failing test.
func format_trace() -> String:
	var lines := ["DuelLog seed=%d first_player=%d" % [seed_value, first_player_id]]
	for e in entries:
		lines.append("  [T%d %s] %s %s" % [
			e["turn"], Enums.phase_name(e["phase"]), e["kind"], str(e["data"])])
	return "\n".join(lines)


func event_count(kind: GameEvent.Kind) -> int:
	var name := GameEvent.kind_name(kind)
	var n := 0
	for e in entries:
		if e["kind"] == name:
			n += 1
	return n

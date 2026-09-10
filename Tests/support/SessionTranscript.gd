class_name SessionTranscript
extends RefCounted

## Phase 7 unit B — one scripted real-deck duel played through `EngineSession` with `DuelDriver`'s
## own policies, RECORDED at every message that carries a view (every prompt and the final "over"),
## on both channels, together with the TRUTH behind every card that message shows as hidden.
##
## The truth is read with `debug_engine()` while the worker is parked (tests only), and it is paired
## with the message WITHOUT going through the session's projection: a hidden stub is matched to the
## engine card at the same POSITION (hand order, zone index), and a log entry to the raw engine event
## it came from by re-applying the projection's documented filter to `state.events` in order. So a
## wrong alias table can never make its own truth agree with it.
##
## What it measures is the unit-A finding 3 attack (PROJECT_STATE.md §8, B0): take an identifier the
## viewer was shown for a card hidden from them, subtract the owner's registration base, and read
## that slot of the owner's PUBLIC pre-shuffle Deck list. The blind baseline for the same identifier
## is the best guess that uses no identifier at all: the most common name among the cards of that
## owner the viewer cannot see at that moment.

const STUB := "hand stub"
const FACE_DOWN := "face-down card"
const EVENT := "event naming a hidden card"

## Event-data keys whose values are card instance ids (ints or arrays of ints), at any depth.
## Kept independently of the session's own list on purpose.
const CARD_KEYS := ["card_id", "attacker_id", "defender_id", "target_id", "target_ids",
	"source_id", "by_card_id", "for_card_id", "equipped_to_id", "negated_by", "destroyed",
	"tribute_ids", "card_ids", "cost_cards", "discarded", "sent", "tributed",
	"honest_boosted_monster"]

var label := ""
var outcome := ""
var problems: Array = []
var engine: DuelEngine = null
var stats: Dictionary = {}
var deck_lists: Array = [[], []]
var id_base: Array = [-1, -1]
## Per category: {"observations", "hits", "baseline"}.
var tally: Dictionary = {}
## The same attack on the ENGINE's own view at the same moments — the control that proves the
## attack is real: {"observations", "hits"}.
var raw_tally := {"observations": 0, "hits": 0}
## Messages recorded, per channel.
var recorded: Array = [0, 0]
var overs: Array = [false, false]
## Called as on_message.call(viewer, message, engine) at every recorded message, worker parked.
var on_message: Callable = Callable()

var _cursor: Array = [0, 0]


## The owner side of the session with a hook: every prompt / over is recorded as it is drained.
class RecordingHarness extends EngineSessionTests.Harness:
	var transcript: SessionTranscript = null

	func _init(s: EngineSession, t: SessionTranscript) -> void:
		super(s, false)
		transcript = t

	func _check(pid: int, m: Dictionary) -> void:
		super(pid, m)
		var type := str(m.get("type", ""))
		if type == "prompt" or type == "over":
			transcript.record(session, pid, m)


static func play(cfg: Dictionary, on_message: Callable = Callable()) -> SessionTranscript:
	var tr := SessionTranscript.new()
	tr.label = str(cfg["label"])
	tr.on_message = on_message
	tr.deck_lists = [ScriptedDuelTests._expected_list(0), ScriptedDuelTests._expected_list(1)]
	var d0 := TestFixtures.real_deck(0)
	var d1 := TestFixtures.real_deck(1)
	var session := EngineSession.new()
	if not session.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]],
			int(cfg["seed"]), int(cfg["first"]), ["Player 1", "Player 2"]):
		tr.outcome = "not started"
		return tr
	var policy := DuelDriver.new()
	policy.seed_value = int(cfg["seed"])
	policy.first_player = int(cfg["first"])
	policy.styles = (cfg["styles"] as Array).duplicate()
	policy.surrender_on_turn = int(cfg.get("surrender_on_turn", -1))
	var answerer := DuelDriver.PolicyController.new(0, "policy")
	var h := RecordingHarness.new(session, tr)
	var out := {"outcome": "", "problems": [], "decisions": {}, "prompts": [0, 0], "refused": 0}
	while true:
		var m := h.next()
		if m.is_empty():
			tr.outcome = "timeout"
			break
		var type := str(m["type"])
		if type == "over":
			tr.outcome = "ended"
			break
		if type != "prompt":
			tr.problems.append("unexpected message %s" % str(m).left(200))
			tr.outcome = "unexpected"
			break
		if not EngineSessionTests._answer_like_the_driver(h, policy, answerer, m, out):
			tr.outcome = str(out["outcome"]) if str(out["outcome"]) != "" else "rejected"
			break
	# The second channel's "over" can still be on its way.
	var deadline := Time.get_ticks_msec() + EngineSessionTests.TIMEOUT_MS
	while tr.outcome == "ended" and not (tr.overs[0] and tr.overs[1]) \
			and Time.get_ticks_msec() < deadline:
		if session.wait_for_message(200):
			h._drain()
	tr.problems.append_array(out["problems"])
	tr.problems.append_array(h.violations)
	policy.engine = null
	session.stop()
	tr.engine = session.debug_engine()
	tr.stats = session.stats()
	return tr


## The engine, waiting for the worker to park if the message was not the parking one (the first of
## the two "over" messages is enqueued just before the worker parks on the second).
static func parked_engine(session: EngineSession) -> DuelEngine:
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		var e := session.debug_engine()
		if e != null:
			return e
		OS.delay_usec(100)
	return null


func record(session: EngineSession, v: int, m: Dictionary) -> void:
	var eng := parked_engine(session)
	if eng == null:
		problems.append("%s: the engine was not readable at a %s on channel %d"
			% [label, str(m.get("type")), v])
		return
	recorded[v] = int(recorded[v]) + 1
	if str(m.get("type", "")) == "over":
		overs[v] = true
	var s := eng.state
	if int(id_base[0]) == -1:
		# `setup_duel()` registers each Deck in its pre-shuffle list order, player 0 first, so an
		# owner's lowest id is slot 0 of that owner's list.
		for o in [0, 1]:
			var lo := 1 << 30
			for c in s.all_instances():
				if (c as CardInstance).owner_id == o:
					lo = mini(lo, (c as CardInstance).id)
			id_base[o] = lo
	var modes := _modes(s, v)
	var opp := 1 - v
	var view: Dictionary = m.get("view", {})
	var pv: Dictionary = (view.get("players", [{}, {}]) as Array)[opp]
	var real_p := s.player(opp)

	# 1. The opponent's hand, paired by position.
	var shown_hand: Array = pv.get("hand", [])
	if shown_hand.size() != real_p.hand.size():
		problems.append("%s: channel %d shows %d hand cards for player %d, who holds %d"
			% [label, v, shown_hand.size(), opp, real_p.hand.size()])
	else:
		for i in range(shown_hand.size()):
			var e: Dictionary = shown_hand[i]
			if bool(e.get("hidden", false)):
				_observe(STUB, e.get("id"), real_p.hand[i], modes)

	# 2. Face-down cards, paired by zone and index.
	for key in ["monster_zones", "spell_trap_zones"]:
		var shown: Array = pv.get(key, [])
		var real: Array = real_p.monster_zones if key == "monster_zones" else real_p.spell_trap_zones
		for i in range(mini(shown.size(), real.size())):
			if shown[i] != null and bool((shown[i] as Dictionary).get("hidden", false)) \
					and real[i] != null:
				_observe(FACE_DOWN, (shown[i] as Dictionary).get("id"), real[i], modes)
	var fz = pv.get("field_zone")
	if fz != null and bool((fz as Dictionary).get("hidden", false)) and real_p.field_zone != null:
		_observe(FACE_DOWN, (fz as Dictionary).get("id"), real_p.field_zone, modes)

	# 3. The log, paired entry by entry with the raw events it was projected from.
	var evs: Array = s.events
	var raw: Array = []
	for i in range(int(_cursor[v]), evs.size()):
		var ev: GameEvent = evs[i]
		if not (ev.is_public() or v in ev.private_to()):
			continue
		if ev.kind == GameEvent.Kind.RESPONSE_PASSED and int(ev.data.get("player", -1)) != v:
			continue
		raw.append(ev)
	_cursor[v] = evs.size()
	var log: Array = m.get("log", [])
	if raw.size() != log.size():
		problems.append("%s: channel %d's log delta has %d entries; the raw events it came from %d"
			% [label, v, log.size(), raw.size()])
	else:
		for j in range(raw.size()):
			_observe_event(s, v, raw[j], (log[j] as Dictionary).get("data", {}), modes)

	# Control: the same attack on the engine's OWN view of the same moment.
	var raw_hand: Array = eng.get_visible_state(v)["players"][opp]["hand"]
	for i in range(mini(raw_hand.size(), real_p.hand.size())):
		if bool((raw_hand[i] as Dictionary).get("hidden", false)):
			raw_tally["observations"] = int(raw_tally["observations"]) + 1
			if attack((raw_hand[i] as Dictionary).get("id"), real_p.hand[i]) \
					== (real_p.hand[i] as CardInstance).card_name():
				raw_tally["hits"] = int(raw_tally["hits"]) + 1

	if on_message.is_valid():
		on_message.call(v, m, eng)


## Every card an event names that is hidden from `v`: the moved card of a move event when it was
## hidden at BOTH ends; any other card-id field whose card is hidden from `v` now and whose name the
## event does not carry.
func _observe_event(s: GameState, v: int, ev: GameEvent, shown: Dictionary,
		modes: Dictionary) -> void:
	var is_move := ev.data.has("card_id") and ev.data.has("from_zone") and ev.data.has("to_zone")
	for pair in _card_fields(ev.data, []):
		var path: Array = pair[0]
		var real_id := int(pair[1])
		var card = s.instance(real_id)
		if card == null or v in (card as CardInstance).revealed_to:
			continue
		var hidden := false
		if is_move and path == ["card_id"]:
			hidden = DuelDriver._end_hidden(v, int(ev.data["from_zone"]),
				int(ev.data.get("from_player", -1)), false, ev, card) \
				and DuelDriver._end_hidden(v, int(ev.data["to_zone"]),
				int(ev.data.get("to_player", -1)), true, ev, card)
		elif not (path == ["card_id"] and ev.data.has("card_name")):
			hidden = DuelDriver._hidden_from(card, v)
		if hidden:
			_observe(EVENT, _at(shown, path), card, modes)


## [[path, id], ...] for every card-id value in `v`.
static func _card_fields(v, path: Array) -> Array:
	var out: Array = []
	if v is Dictionary:
		for k in v.keys():
			var p := path.duplicate()
			p.append(k)
			var x = v[k]
			if str(k) in CARD_KEYS:
				if typeof(x) == TYPE_INT and int(x) > 0:
					out.append([p, x])
				elif x is Array:
					for i in range((x as Array).size()):
						if typeof(x[i]) == TYPE_INT and int(x[i]) > 0:
							var q := p.duplicate()
							q.append(i)
							out.append([q, x[i]])
			elif x is Dictionary:
				out.append_array(_card_fields(x, p))
	return out


static func _at(v, path: Array):
	var cur = v
	for k in path:
		if cur is Dictionary and (cur as Dictionary).has(k):
			cur = cur[k]
		elif cur is Array and typeof(k) == TYPE_INT and int(k) < (cur as Array).size():
			cur = cur[k]
		else:
			return null
	return cur


## The Deck-list-order attack: the name at slot (identifier − owner's base) of the public list.
func attack(identifier, card: CardInstance) -> String:
	if typeof(identifier) != TYPE_INT:
		return ""
	var lst: Array = deck_lists[card.owner_id]
	var slot := int(identifier) - int(id_base[card.owner_id])
	if slot < 0 or slot >= lst.size():
		return ""
	return str(lst[slot])


func _observe(category: String, identifier, card: CardInstance, modes: Dictionary) -> void:
	var t: Dictionary = tally.get(category, {"observations": 0, "hits": 0, "baseline": 0})
	t["observations"] = int(t["observations"]) + 1
	if attack(identifier, card) == card.card_name():
		t["hits"] = int(t["hits"]) + 1
	if str(modes.get(card.owner_id, "")) == card.card_name():
		t["baseline"] = int(t["baseline"]) + 1
	tally[category] = t


## Per owner: the most common name among that owner's cards `v` cannot see (ties: the first name
## alphabetically) — the best guess that uses no identifier.
static func _modes(s: GameState, v: int) -> Dictionary:
	var counts := [{}, {}]
	for c in s.all_instances():
		var card: CardInstance = c
		if card.zone == Enums.Zone.DECK or DuelDriver._hidden_from(card, v):
			var d: Dictionary = counts[card.owner_id]
			d[card.card_name()] = int(d.get(card.card_name(), 0)) + 1
	var out := {}
	for o in [0, 1]:
		var best := ""
		var best_n := -1
		var names: Array = (counts[o] as Dictionary).keys()
		names.sort()
		for n in names:
			if int(counts[o][n]) > best_n:
				best = n
				best_n = int(counts[o][n])
		out[o] = best
	return out

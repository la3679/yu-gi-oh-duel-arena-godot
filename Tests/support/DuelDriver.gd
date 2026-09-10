class_name DuelDriver
extends RefCounted

## Plays a WHOLE duel, start to finish, through the public `DuelEngine` API only.
## The post-card phase, unit 2 (PROJECT_STATE.md §8, "scripted duels").
##
## Every suite before this one built a board, exercised a mechanism and stopped. This drives
## a real duel between the two REAL 40-card decks from the opening shuffle to a legitimate
## game over, and checks the whole game as it goes:
##
##   * every action comes from `get_legal_actions()` / `get_legal_responses()` and goes back
##     through `submit_action()`. Nothing arranges the board and nothing mutates state;
##   * every question the engine asks is answered by a deterministic `PolicyController`, so the
##     same seed, first player and styles always play the same duel;
##   * after every step: every card is in exactly one zone, the one it believes it is in; LP
##     moved only through `LP_CHANGED`; no hidden card leaks through either player's
##     viewer-filtered state; no event either player may read names a card that was hidden
##     from them at BOTH ends of its move; no once-per-turn allowance was exceeded;
##   * every engine `push_error` and every `SCRIPT ERROR` raised during the duel is captured
##     IN-PROCESS through a `Logger`, so "0 SCRIPT ERROR" is an assertion about this duel
##     rather than a grep over a whole run.
##
## The driver never decides legality. A policy only ORDERS what the engine offered and picks
## parameters out of the candidate lists the engine attached to each offer. An offer the
## engine then refuses is recorded as a defect (`rejected`), never retried into a pass.
##
## Hidden information is hidden from the POLICY too: anything the opponent controls is read
## from `get_visible_state()`, never from the engine's own state.

## Summons, activates, sets Traps, attacks whenever the visible board says it wins the
## battle, and never responds in an opponent's window.
const STYLE_BEATDOWN := "beatdown"
## Everything beatdown does, but Sets a monster it cannot win with, Sets Quick-Play Spells
## too, and RESPONDS in every window with every legal activation — the Chain-maker.
const STYLE_CONTROL := "control"
## Never summons, Sets or activates: ends every phase. Still answers every question the
## engine puts to it (the hand-size discard, optional triggers).
const STYLE_PASSIVE := "passive"

## Activations of one (card, effect) the policy will attempt per turn. A bound on the
## POLICY, not a rule: it stops a policy re-activating an unlimited effect forever. The
## engine's own once-per-turn rules are checked separately and independently.
const MAX_TRIES_PER_TURN := 2
## Alternative target selections tried before the policy gives up on an offered activation.
const MAX_CHOICE_ATTEMPTS := 6
## Stand-in for a stat the policy cannot see (a face-down monster).
const UNKNOWN_STAT := 1500
## Steps allowed inside ONE turn before the driver declares the turn stuck.
const MAX_STEPS_PER_TURN := 600
## Each failure list keeps at most this many messages; the rest are only counted.
const MAX_MESSAGES := 25
## [S1 p.32]
const STARTING_LP := 8000

const FIELD_ZONES := [Enums.Zone.MONSTER_ZONE, Enums.Zone.SPELL_TRAP_ZONE,
	Enums.Zone.FIELD_ZONE, Enums.Zone.EXTRA_MONSTER_ZONE]


## Captures every error Godot reports while a duel is being played.
class ErrorCapture extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append({"type": error_type, "code": code, "rationale": rationale,
			"where": "%s:%d %s()" % [file, line, function]})

	func _log_message(_message: String, _error: bool) -> void:
		pass


## A `ScriptedController` whose default answers make optional effects DO something:
## "yes" to an optional trigger, and one pick rather than none for an "up to N" choice.
## Always the first offered options, so the answer is a pure function of the request.
class PolicyController extends ScriptedController:
	var take_optional: bool = true

	func _init(p_player_id: int = 0, p_name: String = "Policy") -> void:
		super(p_player_id, p_name)
		default_yes = true

	func _default_answer(request: DecisionRequest):
		if request.kind == Enums.DecisionKind.YES_NO:
			return default_yes
		if request.kind == Enums.DecisionKind.ORDER_TRIGGERS:
			return range(request.options.size())
		var n := request.min_count
		if take_optional and n == 0 and request.max_count > 0:
			n = 1
		n = mini(n, request.options.size())
		return request.options.slice(0, n)


## Answers a replayed duel from the decisions its payload recorded, in order, per player.
## A missing or mismatched answer is an error, never a silent default: a replay that quietly
## diverged would prove nothing.
class ReplayController extends PlayerController:
	var queue: Array = []
	var errors: Array = []

	func _init(p_player_id: int, p_name: String, decisions: Array) -> void:
		super(p_player_id, p_name)
		for d in decisions:
			if int(d["request"].get("player", -1)) == p_player_id:
				queue.append(d)

	func decide(request: DecisionRequest):
		if queue.is_empty():
			errors.append("player %d: the payload ran out of decisions at '%s'"
				% [player_id, request.prompt])
			return null
		var head: Dictionary = queue.pop_front()
		var recorded := str(head["request"].get("kind", ""))
		if recorded != DecisionRequest.kind_name(request.kind):
			errors.append("player %d: recorded a %s answer, the replay asked %s '%s'"
				% [player_id, recorded, DecisionRequest.kind_name(request.kind), request.prompt])
		return head["answer"]


# --- Configuration ---
var seed_value: int = 0
var first_player: int = 0
var styles: Array = [STYLE_BEATDOWN, STYLE_BEATDOWN]
var max_turns: int = 120
var max_steps: int = 40000
## The turn player surrenders at Main Phase 1 of this turn (-1 = never).
var surrender_on_turn: int = -1

# --- The duel ---
var engine: DuelEngine = null
var controllers: Array = []
var deck_names: Array = ["", ""]
var deck_errors: Array = []

# --- Results ---
## "ended" | "turn_cap" | "step_cap" | "turn_stuck" | "stalled" | "rejected"
var outcome: String = ""
var steps: int = 0
var errors: Array = []
var rejected: Array = []
var choice_rejections: int = 0
var invariant_failures: Array = []
var hidden_failures: Array = []
var log_leaks: Array = []
var opt_violations: Array = []
var suppressed: int = 0
## Hidden cards whose view entry was actually inspected — the non-vacuity count.
var hidden_checks: int = 0
## Events of a move family whose privacy was actually evaluated.
var move_checks: int = 0

## ActionKind name -> successful submissions.
var submitted: Dictionary = {}
## GameEvent kind name -> count.
var event_counts: Dictionary = {}
## Enums.Phase -> times entered.
var phases_entered: Dictionary = {}
## "FROM>TO" zone names -> count, and MoveReason name -> count, over every move event.
var moves: Dictionary = {}
var move_reasons: Dictionary = {}
## "card name::effect id" -> activations.
var activated_effects: Dictionary = {}
## once-per-turn key (without the turn) -> {turn: true}. Two turns = the allowance reset.
var opt_turns: Dictionary = {}
var max_chain: int = 0
## Response windows a player was really offered and declined (not the engine's auto-pass).
var manual_passes: int = 0
## Activations submitted IN a response window (through `get_legal_responses()`).
var response_activations: int = 0
## Chain Links added by the player who did NOT start that Chain — a real answer to the opponent.
var cross_responses: int = 0
var _chain_starter: int = -1

var _tries: Dictionary = {}
var _opt_counts: Dictionary = {}
## card id -> how many times it has changed zone or been flipped face-down.
var _stay: Dictionary = {}
var _lp: Array = [STARTING_LP, STARTING_LP]
var _event_cursor: int = 0
var _turn_steps: int = 0
var _last_turn: int = 0


## Build the duel: both REAL decks, deterministic policy controllers, the given seed.
func setup() -> bool:
	var d0 := TestFixtures.real_deck(0)
	var d1 := TestFixtures.real_deck(1)
	deck_errors = []
	deck_errors.append_array(d0["errors"])
	deck_errors.append_array(d1["errors"])
	deck_names = [d0["name"], d1["name"]]
	controllers = [PolicyController.new(0, "Player 1"), PolicyController.new(1, "Player 2")]
	engine = DuelEngine.new(seed_value)
	engine.setup_duel([d0["cards"], d1["cards"]], controllers, first_player, deck_names)
	return deck_errors.is_empty()


## Play the duel to its end (or to a cap, which is a failure). Returns `outcome`.
func play() -> String:
	var cap := ErrorCapture.new()
	OS.add_logger(cap)
	if engine == null:
		setup()
	_scan_new_events()
	_check_all()
	outcome = _loop()
	_scan_new_events()
	_check_all()
	OS.remove_logger(cap)
	errors.append_array(cap.errors)
	return outcome


func summary() -> String:
	if engine == null:
		return "no duel"
	var s := engine.state
	return "outcome=%s turn=%d steps=%d LP=%d/%d result=%s reason=%s submitted=%s" % [
		outcome, s.turn_number, steps, s.player(0).life_points, s.player(1).life_points,
		Enums.DuelResult.keys()[s.result], Enums.EndReason.keys()[s.end_reason],
		str(submitted)]


# ---------------------------------------------------------------------------
# The loop
# ---------------------------------------------------------------------------

func _loop() -> String:
	while not engine.is_duel_over():
		if steps >= max_steps:
			return "step_cap"
		if engine.state.turn_number > max_turns:
			return "turn_cap"
		if engine.state.turn_number != _last_turn:
			_last_turn = engine.state.turn_number
			_turn_steps = 0
		_turn_steps += 1
		if _turn_steps > MAX_STEPS_PER_TURN:
			return "turn_stuck"
		var pid := engine.waiting_player()
		if pid == -1:
			return "stalled"
		var is_response := engine.timing != DuelEngine.Timing.OPEN
		var offered: Array = engine.get_legal_responses(pid) if is_response \
			else engine.get_legal_actions(pid)
		if offered.is_empty():
			return "stalled"
		if not _take_step(pid, offered, is_response):
			return "rejected"
		steps += 1
		_scan_new_events()
		_check_all()
	return "ended"


func _take_step(pid: int, offered: Array, is_response: bool) -> bool:
	for a in _candidates(pid, offered, is_response):
		if a == null:
			continue
		var action: DuelAction = a
		_note_try(action)
		if engine.submit_action(action):
			var k := DuelAction.kind_name(action.kind)
			submitted[k] = int(submitted.get(k, 0)) + 1
			if is_response and action.is_activation():
				response_activations += 1
			return true
		if _has_parameters(action):
			# The policy's guess at a parameter was wrong; the OFFER itself was fine.
			choice_rejections += 1
		else:
			_fail(rejected, "T%d %s: the engine offered %s to player %d and then refused it"
				% [engine.state.turn_number, Enums.phase_name(engine.state.phase),
				str(action), pid])
	return false


static func _has_parameters(action: DuelAction) -> bool:
	return not action.target_ids.is_empty() or not action.tribute_ids.is_empty() \
		or action.kind == Enums.ActionKind.DECLARE_ATTACK


# ---------------------------------------------------------------------------
# Policy — orders the engine's offers; never invents one.
# ---------------------------------------------------------------------------

func _candidates(pid: int, offered: Array, is_response: bool) -> Array:
	var style: String = styles[pid]
	var out: Array = []
	if is_response:
		if style == STYLE_CONTROL:
			out.append_array(_activations(offered))
		out.append(_first(offered, Enums.ActionKind.PASS))
		return out

	var phase := engine.state.phase
	if surrender_on_turn == engine.state.turn_number and phase == Enums.Phase.MAIN_1:
		out.append(_first(offered, Enums.ActionKind.SURRENDER))
		return out

	if style != STYLE_PASSIVE:
		match phase:
			Enums.Phase.MAIN_1, Enums.Phase.MAIN_2:
				for a in _sorted(offered):
					if a.kind == Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE and _may_try(a):
						out.append(a)
				out.append_array(_activations(offered))
				out.append_array(_summons(pid, offered, style))
				for a in _sorted(offered):
					if a.kind == Enums.ActionKind.FLIP_SUMMON:
						out.append(a)
				if style == STYLE_BEATDOWN:
					out.append_array(_position_changes(pid, offered))
				out.append_array(_sets(offered, style))
			Enums.Phase.BATTLE:
				out.append_array(_attacks(pid, offered))
			_:
				if style == STYLE_CONTROL:
					out.append_array(_activations(offered))

	# Moving on is always LAST: the policy only advances once it wants nothing else here.
	if style != STYLE_PASSIVE and phase == Enums.Phase.MAIN_1 and _wants_battle(pid):
		out.append(_first(offered, Enums.ActionKind.ENTER_BATTLE_PHASE))
	out.append(_first(offered, Enums.ActionKind.END_BATTLE_PHASE))
	out.append(_first(offered, Enums.ActionKind.END_PHASE))
	return out


func _activations(offered: Array) -> Array:
	var out: Array = []
	for a in _sorted(offered):
		if a.is_activation() and _may_try(a):
			out.append_array(_parameterize(a))
	return out


func _summons(pid: int, offered: Array, style: String) -> Array:
	var scored: Array = []
	var opp_best := _opponent_best_visible_atk(pid)
	for a in offered:
		if not (a.kind in [Enums.ActionKind.NORMAL_SUMMON, Enums.ActionKind.TRIBUTE_SUMMON,
				Enums.ActionKind.NORMAL_SET, Enums.ActionKind.TRIBUTE_SET]):
			continue
		var card: CardInstance = engine.state.instance(a.card_id)
		var atk := card.original_atk()
		var is_set: bool = a.kind in [Enums.ActionKind.NORMAL_SET, Enums.ActionKind.TRIBUTE_SET]
		var wants_set := style == STYLE_CONTROL and atk <= opp_best
		if is_set != wants_set:
			continue
		var score := card.original_def() if is_set else atk
		if a.tributes_required > 0:
			var combo := _cheapest_tributes(a)
			if combo.is_empty() or _max_atk(combo) >= atk:
				continue
			scored.append([score, a.with_choices({"tribute_ids": combo})])
		else:
			scored.append([score, a])
	scored.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1].card_id < y[1].card_id))
	return scored.map(func(x): return x[1])


func _sets(offered: Array, style: String) -> Array:
	var out: Array = []
	for a in _sorted(offered):
		if a.kind != Enums.ActionKind.SET_SPELL_TRAP:
			continue
		var card: CardInstance = engine.state.instance(a.card_id)
		if card.is_trap() or (style == STYLE_CONTROL and card.definition != null \
				and card.definition.st_kind == Enums.STKind.QUICK_PLAY_SPELL):
			out.append(a)
	return out


func _position_changes(pid: int, offered: Array) -> Array:
	var out: Array = []
	var opp_best := _opponent_best_visible_atk(pid)
	for a in _sorted(offered):
		if a.kind != Enums.ActionKind.CHANGE_POSITION \
				or a.position != Enums.Position.FACE_UP_ATTACK:
			continue
		var card: CardInstance = engine.state.instance(a.card_id)
		if card.current_atk() > opp_best:
			out.append(a)
	return out


func _attacks(pid: int, offered: Array) -> Array:
	var by_id := _opponent_view_monsters(pid)
	var scored: Array = []
	for a in offered:
		if a.kind != Enums.ActionKind.DECLARE_ATTACK:
			continue
		var attacker: CardInstance = engine.state.instance(a.card_id)
		var atk := attacker.current_atk()
		if a.allows_direct_attack:
			scored.append([atk, a.with_choices({"attack_target_id": -1})])
			continue
		var best_tid := -1
		var best_v := -1
		for tid in a.attack_target_candidates:
			var v := _defending_value(by_id.get(int(tid), {}))
			if atk > v and v > best_v:
				best_v = v
				best_tid = int(tid)
		if best_tid != -1:
			scored.append([atk, a.with_choices({"attack_target_id": best_tid})])
	scored.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1].card_id < y[1].card_id))
	return scored.map(func(x): return x[1])


func _wants_battle(pid: int) -> bool:
	for c in engine.state.player(pid).monsters():
		if c.position == Enums.Position.FACE_UP_ATTACK:
			return true
	return false


## Every target selection worth trying for an offered activation, opponent's cards first.
func _parameterize(a: DuelAction) -> Array:
	if a.target_min <= 0 and a.target_max <= 0:
		return [a]
	var n := maxi(a.target_min, 1)
	var cands := _opponent_first(a.player_id, a.target_candidates)
	if cands.size() < n:
		return []
	var out: Array = []
	for start in range(mini(cands.size(), MAX_CHOICE_ATTEMPTS)):
		var sel: Array = []
		for i in range(n):
			sel.append(cands[(start + i) % cands.size()])
		out.append(a.with_choices({"target_ids": sel}))
	return out


func _opponent_first(pid: int, ids: Array) -> Array:
	var theirs: Array = []
	var mine: Array = []
	for id in ids:
		var c: CardInstance = engine.state.instance(int(id))
		if c != null and c.controller_id != pid:
			theirs.append(id)
		else:
			mine.append(id)
	return theirs + mine


func _cheapest_tributes(a: DuelAction) -> Array:
	var best: Array = []
	var best_cost := -1
	for combo in a.tribute_combinations:
		var cost := 0
		for id in combo:
			cost += (engine.state.instance(int(id)) as CardInstance).current_atk()
		if best_cost == -1 or cost < best_cost:
			best_cost = cost
			best = (combo as Array).duplicate()
	return best


func _max_atk(ids: Array) -> int:
	var m := 0
	for id in ids:
		m = maxi(m, (engine.state.instance(int(id)) as CardInstance).current_atk())
	return m


## The opponent's monsters as `pid` may see them, by id.
func _opponent_view_monsters(pid: int) -> Dictionary:
	var vis := engine.get_visible_state(pid)
	var out := {}
	for e in vis["players"][1 - pid]["monster_zones"]:
		if e != null:
			out[int(e["id"])] = e
	return out


func _opponent_best_visible_atk(pid: int) -> int:
	var best := 0
	for e in _opponent_view_monsters(pid).values():
		best = maxi(best, _defending_value(e, true))
	return best


static func _defending_value(e: Dictionary, as_attacker: bool = false) -> int:
	if e.is_empty() or bool(e.get("hidden", true)):
		return UNKNOWN_STAT
	if as_attacker or int(e.get("position", -1)) == Enums.Position.FACE_UP_ATTACK:
		return int(e.get("atk", 0))
	return int(e.get("def", 0))


static func _sorted(actions: Array) -> Array:
	var out := actions.duplicate()
	out.sort_custom(func(x, y): return x.card_id < y.card_id or (x.card_id == y.card_id and x.effect_id < y.effect_id))
	return out


static func _first(actions: Array, kind: Enums.ActionKind):
	for a in actions:
		if a.kind == kind:
			return a
	return null


func _try_key(a: DuelAction) -> String:
	return "%d|%d|%s" % [engine.state.turn_number, a.card_id, a.effect_id]


func _may_try(a: DuelAction) -> bool:
	return int(_tries.get(_try_key(a), 0)) < MAX_TRIES_PER_TURN


func _note_try(a: DuelAction) -> void:
	if a.is_activation() or a.kind == Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE:
		var k := _try_key(a)
		_tries[k] = int(_tries.get(k, 0)) + 1


# ---------------------------------------------------------------------------
# Event scan — what happened, and was it allowed to be seen?
# ---------------------------------------------------------------------------

func _scan_new_events() -> void:
	var evs: Array = engine.state.events
	for i in range(_event_cursor, evs.size()):
		var ev: GameEvent = evs[i]
		var kname := GameEvent.kind_name(ev.kind)
		event_counts[kname] = int(event_counts.get(kname, 0)) + 1
		# A card that changes zone or is flipped face-down is a NEW card for per-instance
		# usage (RULES_SPEC.md 11). Counted in event order, so a use after the move reads the
		# new stay. The first battery caught the driver without this: `Fairy Tail - Luna`
		# bounced HERSELF, was Normal Summoned again and legally bounced again that turn.
		if ev.data.has("card_id") and (ev.kind == GameEvent.Kind.CARD_MOVED \
				or (ev.kind == GameEvent.Kind.BATTLE_POSITION_CHANGED and int(ev.data.get(
				"to", -1)) in [Enums.Position.FACE_DOWN_DEFENSE, Enums.Position.FACE_DOWN])):
			var cid := int(ev.data["card_id"])
			_stay[cid] = int(_stay.get(cid, 0)) + 1
		match ev.kind:
			GameEvent.Kind.LP_CHANGED:
				var who := int(ev.data.get("player", -1))
				_lp[who] = int(_lp[who]) + int(ev.data.get("delta", 0))
				if int(_lp[who]) != int(ev.data.get("life_points", -1)):
					_fail(invariant_failures, "T%d: LP_CHANGED for player %d reports %d LP but "
						% [ev.turn, who, int(ev.data.get("life_points", -1))]
						+ "the deltas since the start add up to %d" % int(_lp[who]))
					_lp[who] = int(ev.data.get("life_points", -1))
			GameEvent.Kind.CHAIN_LINK_ADDED:
				var link := int(ev.data.get("link_number", 0))
				var by := int(ev.data.get("controller", -1))
				max_chain = maxi(max_chain, link)
				if link == 1:
					_chain_starter = by
				elif by != _chain_starter:
					cross_responses += 1
			GameEvent.Kind.EFFECT_ACTIVATED:
				_note_activation(ev)
			GameEvent.Kind.PHASE_CHANGED:
				var to := int(ev.data.get("to", -1))
				phases_entered[to] = int(phases_entered.get(to, 0)) + 1
			GameEvent.Kind.RESPONSE_PASSED:
				if not bool(ev.data.get("automatic", false)):
					manual_passes += 1
		if ev.data.has("from_zone") and ev.data.has("to_zone") and ev.data.has("card_id"):
			if ev.kind == GameEvent.Kind.CARD_MOVED:
				var mk := "%s>%s" % [Enums.Zone.keys()[int(ev.data["from_zone"])],
					Enums.Zone.keys()[int(ev.data["to_zone"])]]
				moves[mk] = int(moves.get(mk, 0)) + 1
				var rk: String = Enums.MoveReason.keys()[int(ev.data.get("reason", 0))]
				move_reasons[rk] = int(move_reasons.get(rk, 0)) + 1
			_check_move_privacy(ev)
	_event_cursor = evs.size()


## A move event names its card. If a player may read the event but could see the card at
## NEITHER end of the move, the event has told them something the rules keep from them.
func _check_move_privacy(ev: GameEvent) -> void:
	var card: CardInstance = engine.state.instance(int(ev.data["card_id"]))
	if card == null or not ev.data.has("card_name"):
		return
	move_checks += 1
	for x in [0, 1]:
		if not (ev.is_public() or x in ev.private_to()):
			continue
		if x in card.revealed_to:
			continue
		var from_hidden := _end_hidden(x, int(ev.data["from_zone"]),
			int(ev.data.get("from_player", -1)), false, ev, card)
		var to_hidden := _end_hidden(x, int(ev.data["to_zone"]),
			int(ev.data.get("to_player", -1)), true, ev, card)
		if from_hidden and to_hidden:
			_fail(log_leaks, "T%d %s: %s %s>%s (reason %s) names '%s' to player %d, who could "
				% [ev.turn, Enums.phase_name(ev.phase), GameEvent.kind_name(ev.kind),
				Enums.Zone.keys()[int(ev.data["from_zone"])],
				Enums.Zone.keys()[int(ev.data["to_zone"])],
				Enums.MoveReason.keys()[int(ev.data.get("reason", 0))],
				str(ev.data["card_name"]), x]
				+ "see it at neither end of the move")


static func _end_hidden(x: int, zone: int, zone_player: int, is_destination: bool,
		ev: GameEvent, card: CardInstance) -> bool:
	match zone:
		Enums.Zone.DECK, Enums.Zone.EXTRA_DECK:
			return true
		Enums.Zone.HAND:
			return zone_player != x
		Enums.Zone.MONSTER_ZONE, Enums.Zone.SPELL_TRAP_ZONE, Enums.Zone.FIELD_ZONE, \
		Enums.Zone.EXTRA_MONSTER_ZONE:
			if zone_player == x or not is_destination:
				# Where a card left the field from, the payload does not say whether it was
				# face-down; the check stays conservative and never flags an origin it cannot
				# prove was hidden.
				return false
			return int(ev.data.get("reason", -1)) == Enums.MoveReason.SET \
				or (card.zone == zone and not card.is_face_up())
		_:
			return false


func _note_activation(ev: GameEvent) -> void:
	var card: CardInstance = engine.state.instance(int(ev.data.get("card_id", -1)))
	if card == null or card.definition == null:
		return
	var eid := str(ev.data.get("effect_id", ""))
	var nm := card.card_name()
	var ak := "%s::%s" % [nm, eid]
	activated_effects[ak] = int(activated_effects.get(ak, 0)) + 1
	var effect: EffectDef = null
	for e in card.definition.effects:
		if e.effect_id == eid:
			effect = e
	if effect == null:
		return
	var who := int(ev.data.get("controller", card.controller_id))
	var limit := effect.uses_per_turn if effect.uses_per_turn > 0 else 1
	var keys: Array = []
	var stay := int(_stay.get(card.id, 0))
	if effect.once_per_turn_instance:
		keys.append("instance|%d#%d|%s" % [card.id, stay, eid])
	if effect.once_per_turn_named_effect:
		keys.append("named_effect|%d|%s|%s" % [who, nm, eid])
	if effect.once_per_turn_named_activation:
		keys.append("named_activation|%d|%s" % [who, nm])
	if effect.uses_per_turn > 0 and keys.is_empty():
		keys.append("uses|%d#%d|%s" % [card.id, stay, eid])
	for k in keys:
		var tk := "%d|%s" % [ev.turn, k]
		_opt_counts[tk] = int(_opt_counts.get(tk, 0)) + 1
		var cap := 1 if str(k).begins_with("named_activation") else limit
		if int(_opt_counts[tk]) > cap:
			_fail(opt_violations, "T%d: %s activated %d times against a limit of %d (%s)"
				% [ev.turn, ak, int(_opt_counts[tk]), cap, k])
		var turns: Dictionary = opt_turns.get(k, {})
		turns[ev.turn] = true
		opt_turns[k] = turns


# ---------------------------------------------------------------------------
# Invariants and the viewer-filtered state
# ---------------------------------------------------------------------------

func _check_all() -> void:
	_check_conservation()
	for viewer in [0, 1]:
		_check_visible_state(viewer)
	for pid in [0, 1]:
		var actual := engine.state.player(pid).life_points
		if int(_lp[pid]) != actual:
			_fail(invariant_failures, "T%d: player %d has %d LP but LP_CHANGED accounts for %d"
				% [engine.state.turn_number, pid, actual, int(_lp[pid])])
			_lp[pid] = actual


func _check_conservation() -> void:
	var s := engine.state
	var seen := {}
	for pid in [0, 1]:
		var p := s.player(pid)
		_expect(seen, p.deck, Enums.Zone.DECK, pid, true)
		_expect(seen, p.hand, Enums.Zone.HAND, pid, true)
		_expect(seen, p.graveyard, Enums.Zone.GRAVEYARD, pid, true)
		_expect(seen, p.banished, Enums.Zone.BANISHED, pid, true)
		_expect(seen, p.extra_deck, Enums.Zone.EXTRA_DECK, pid, true)
		_expect(seen, p.in_transit, Enums.Zone.IN_TRANSIT, -1, false)
		_expect(seen, p.excavated, Enums.Zone.EXCAVATED, pid, true)
		_expect(seen, p.monster_zones.filter(func(c): return c != null),
			Enums.Zone.MONSTER_ZONE, pid, false)
		_expect(seen, p.spell_trap_zones.filter(func(c): return c != null),
			Enums.Zone.SPELL_TRAP_ZONE, pid, false)
		if p.field_zone != null:
			_expect(seen, [p.field_zone], Enums.Zone.FIELD_ZONE, pid, false)
		if p.extra_monster_zone != null:
			_expect(seen, [p.extra_monster_zone], Enums.Zone.EXTRA_MONSTER_ZONE, pid, false)
		if p.monster_zones.size() != PlayerState.MONSTER_ZONE_COUNT \
				or p.spell_trap_zones.size() != PlayerState.SPELL_TRAP_ZONE_COUNT:
			_fail(invariant_failures, "player %d's zone arrays changed size" % pid)
	var total := s.all_instances().size()
	if seen.size() != total:
		_fail(invariant_failures, "T%d: %d of %d cards are in a zone container"
			% [s.turn_number, seen.size(), total])


func _expect(seen: Dictionary, cards: Array, zone: Enums.Zone, pid: int,
		owner_bound: bool) -> void:
	for c in cards:
		var card: CardInstance = c
		if seen.has(card.id):
			_fail(invariant_failures, "T%d: card %d (%s) is in two zones at once"
				% [engine.state.turn_number, card.id, card.card_name()])
		seen[card.id] = true
		if card.zone != zone:
			_fail(invariant_failures, "T%d: card %d (%s) sits in %s but believes it is in %s"
				% [engine.state.turn_number, card.id, card.card_name(),
				Enums.Zone.keys()[zone], Enums.Zone.keys()[card.zone]])
		if pid == -1:
			continue
		if owner_bound and card.owner_id != pid:
			_fail(invariant_failures, "T%d: card %d (%s) is in player %d's %s but player %d owns it"
				% [engine.state.turn_number, card.id, card.card_name(), pid,
				Enums.Zone.keys()[zone], card.owner_id])
		if not owner_bound and card.controller_id != pid:
			_fail(invariant_failures, "T%d: card %d (%s) is in player %d's %s but player %d "
				% [engine.state.turn_number, card.id, card.card_name(), pid,
				Enums.Zone.keys()[zone], card.controller_id] + "controls it")


## The engine's view for `viewer`, checked against the TRUTH computed independently here:
## a card hidden from the viewer must be a nameless stub, and a card the viewer may see must
## not be one.
func _check_visible_state(viewer: int) -> void:
	var vis := engine.get_visible_state(viewer)
	var entries := {}
	for pd in vis["players"]:
		var pdict: Dictionary = pd
		if pdict.has("deck"):
			_fail(hidden_failures, "a Deck's contents are in player %d's view" % viewer)
		for key in ["hand", "monster_zones", "spell_trap_zones"]:
			for e in pdict[key]:
				if e != null:
					entries[int(e["id"])] = e
		if pdict["field_zone"] != null:
			entries[int(pdict["field_zone"]["id"])] = pdict["field_zone"]
	for c in engine.state.all_instances():
		var card: CardInstance = c
		if not (card.zone == Enums.Zone.HAND or card.zone in [Enums.Zone.MONSTER_ZONE,
				Enums.Zone.SPELL_TRAP_ZONE, Enums.Zone.FIELD_ZONE]):
			continue
		var e: Dictionary = entries.get(card.id, {})
		if e.is_empty():
			_fail(hidden_failures, "T%d: card %d in %s is missing from player %d's view"
				% [engine.state.turn_number, card.id, Enums.Zone.keys()[card.zone], viewer])
			continue
		if _hidden_from(card, viewer):
			hidden_checks += 1
			if not bool(e.get("hidden", false)) or e.get("name") != null or e.has("atk") \
					or e.has("level"):
				_fail(hidden_failures, "T%d: player %d's view identifies hidden card %d (%s) in %s"
					% [engine.state.turn_number, viewer, card.id, card.card_name(),
					Enums.Zone.keys()[card.zone]])
		elif bool(e.get("hidden", false)):
			_fail(hidden_failures, "T%d: player %d may see card %d (%s) but is shown a stub"
				% [engine.state.turn_number, viewer, card.id, card.card_name()])


static func _hidden_from(card: CardInstance, viewer: int) -> bool:
	if viewer in card.revealed_to:
		return false
	if card.zone == Enums.Zone.HAND:
		return card.controller_id != viewer
	if card.zone in FIELD_ZONES:
		return not card.is_face_up() and card.controller_id != viewer
	return false


func _fail(list: Array, msg: String) -> void:
	if list.size() < MAX_MESSAGES:
		list.append(msg)
	else:
		suppressed += 1


# ---------------------------------------------------------------------------
# Replay and comparison
# ---------------------------------------------------------------------------

## Rebuild a duel from its replay payload ALONE — seed, first player, Deck lists by name and
## the ordered inputs — and play the recorded inputs back into it. Returns
## {"engine", "applied", "errors"}.
static func replay(payload: Dictionary) -> Dictionary:
	var defs: Dictionary = TestFixtures.real_library()["cards"]
	var errs: Array = []
	var decks: Array = []
	for list in payload["deck_lists"]:
		var cards: Array = []
		for n in list:
			if defs.has(str(n)):
				cards.append(defs[str(n)])
			else:
				errs.append("the payload names unknown card '%s'" % str(n))
		decks.append(cards)
	var r0 := ReplayController.new(0, "Player 1", payload["decisions"])
	var r1 := ReplayController.new(1, "Player 2", payload["decisions"])
	var engine := DuelEngine.new(int(payload["seed"]))
	engine.setup_duel(decks, [r0, r1], int(payload["first_player"]), payload["deck_names"])
	var applied := 0
	for entry in payload["actions"]:
		if engine.submit_action(DuelAction.from_dict(entry["action"])):
			applied += 1
	errs.append_array(r0.errors)
	errs.append_array(r1.errors)
	for r in [r0, r1]:
		if not r.queue.is_empty():
			errs.append("player %d left %d recorded decision(s) unasked"
				% [r.player_id, r.queue.size()])
	return {"engine": engine, "applied": applied, "errors": errs}


## Every engine event of a duel, one JSON line each — the thing a replay must reproduce.
static func event_lines(engine: DuelEngine) -> Array:
	var out: Array = []
	for e in engine.log.entries:
		out.append(JSON.stringify(e))
	return out


## The final board: every card's zone, slot, controller and position, both LPs, the result.
static func final_board(engine: DuelEngine) -> String:
	var s := engine.state
	var cards := s.all_instances()
	cards.sort_custom(func(a, b): return a.id < b.id)
	var rows: Array = []
	for c in cards:
		rows.append("%d:%s:%d:%d:%d:%d" % [c.id, c.card_name(), c.zone, c.zone_index,
			c.controller_id, c.position])
	return "LP=%d/%d result=%d reason=%d turn=%d | %s" % [s.player(0).life_points,
		s.player(1).life_points, s.result, s.end_reason, s.turn_number, " ".join(rows)]


## Index of the first line where two event streams differ, or -1 when they are identical.
static func first_difference(a: Array, b: Array) -> int:
	for i in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())

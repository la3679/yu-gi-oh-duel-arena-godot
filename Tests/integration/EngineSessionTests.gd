class_name EngineSessionTests
extends RefCounted

## Phase 7 unit A — the engine session adapter (ADR-0001, docs/ARCHITECTURE.md).
##
## Proves, deterministically and headless, that the engine can run on its own worker thread while
## the owner thread (a UI's main thread; here, the test) starts a duel, receives plain-data views
## and events, receives every question — timing-window prompts AND mid-resolution decisions —
## on the right player's channel, answers them, and stops the duel cleanly:
##
##   * a synthetic Chain with a response from each player, then five mid-resolution decisions
##     across both players — sequential and nested — answered from the owner thread, and the
##     duel it produces is IDENTICAL to the same inputs played single-threaded;
##   * forged, stale, foreign and malformed answers are rejected, change nothing, and re-prompt;
##   * every engine event is emitted on the worker; every call from another thread is refused;
##   * PRIVACY: a player's channel is identical whether the opponent was asked something
##     mid-resolution (`Fairy Tail - Luna`) or had a response window at all — and the RAW engine
##     log is shown to differ in the second case, so the projection is load-bearing;
##   * the six scripted real-deck duels, played through the session with `DuelDriver`'s own
##     policies, reproduce the `DuelDriver` run event for event, board for board, payload for
##     payload;
##   * stop while blocked mid-resolution, while idle, before start and twice; dropping a running
##     session joins its thread; repeated sessions leave ObjectDB growth at 0;
##   * scans: the UI talks to the session only, and the session never touches the scene tree.
##
## Determinism does not depend on timing: the protocol is strictly question / answer, the worker
## produces messages only in reply to a submission, and every wait has a timeout that FAILS.

const TIMEOUT_MS := 20000

const UI_DIR := "res://Scripts/ui"
const SESSION_DIR := "res://Scripts/session"
## The UI may not name the rules layer, the engine, its state or its types, the card library, the
## test harness, or any of the session's test-only `debug_` accessors (unit B made this stricter).
const UI_FORBIDDEN := "\\b(GameState|PlayerState|CardInstance|CardDef|CardRegistry|EffectDef|DuelAction|DecisionRequest|GameEvent|ActivationRules|SummonRules|BattleRules|ChainManager|DuelEngine|TestFixtures|DuelDriver|debug_\\w+)\\b"
## The session may not reach into the scene tree, signal into it, or defer calls onto it.
const SESSION_FORBIDDEN := "\\bNode\\b|get_tree\\(|call_deferred|call_thread_safe|^signal\\b|\\.emit\\(|emit_signal|Engine\\.get_main_loop|SceneTree"


static func run() -> TestCase:
	var t := TestCase.new("EngineSessionTests")
	_test_the_pure_helpers(t)
	_test_a_chain_with_responses_and_nested_decisions(t)
	_test_engine_work_happens_only_on_the_worker(t)
	_test_the_owner_api_refuses_every_other_thread(t)
	_test_an_opponent_decision_mid_resolution_is_invisible_to_the_other_channel(t)
	_test_an_opponent_response_window_is_invisible_to_the_other_channel(t)
	_test_whole_real_duels_equal_the_duel_driver(t)
	_test_stop_while_blocked_mid_resolution(t)
	_test_stop_idle_before_start_and_twice(t)
	_test_dropping_a_running_session_joins_its_thread(t)
	_test_repeated_sessions_leak_nothing(t)
	_test_the_ui_talks_to_the_session_only(t)
	_test_the_session_never_touches_the_scene_tree(t)
	_test_the_production_deck_loader(t)
	return t


# ---------------------------------------------------------------------------
# The harness: the owner side of one session, with a per-message privacy check
# ---------------------------------------------------------------------------

class Harness extends RefCounted:
	var session: EngineSession = null
	## Every message received, per channel — only when `keep` (a whole duel would be large).
	var channels: Array = [[], []]
	var keep: bool = true
	## Received and not yet consumed by the test, in drain order.
	var pending: Array = []
	## Per-message checks: the right channel, the right requesting player, plain data.
	var violations: Array = []
	var checked: int = 0

	func _init(s: EngineSession, p_keep: bool = true) -> void:
		session = s
		keep = p_keep

	## The next message on either channel, or {} on timeout.
	func next() -> Dictionary:
		while pending.is_empty():
			if not session.wait_for_message(EngineSessionTests.TIMEOUT_MS):
				return {}
			_drain()
		return pending.pop_front()

	## The next message of `type` for `player`; everything else stays pending. {} on timeout.
	func next_for(player: int, type: String) -> Dictionary:
		while true:
			for i in range(pending.size()):
				var m: Dictionary = pending[i]
				if int(m.get("player", -2)) == player and str(m.get("type", "")) == type:
					pending.remove_at(i)
					return m
			if not session.wait_for_message(EngineSessionTests.TIMEOUT_MS):
				return {}
			_drain()
		return {}

	func _drain() -> void:
		for pid in [0, 1]:
			for m in session.poll(pid):
				_check(pid, m)
				if keep:
					(channels[pid] as Array).append(m)
				pending.append(m)

	func _check(pid: int, m: Dictionary) -> void:
		checked += 1
		var type := str(m.get("type", ""))
		if EngineSession.contains_object(m):
			violations.append("channel %d received an Object in a %s message" % [pid, type])
		if type in ["prompt", "rejected", "over"] and int(m.get("player", -1)) != pid:
			violations.append("channel %d received a %s addressed to player %s"
				% [pid, type, str(m.get("player"))])
		if type == "prompt" and str(m.get("mode", "")) == EngineSession.MODE_DECISION \
				and int((m["request"] as Dictionary).get("player", -1)) != pid:
			violations.append("channel %d was asked a question addressed to player %s"
				% [pid, str((m["request"] as Dictionary).get("player"))])
		if type in ["prompt", "over"] and int((m["view"] as Dictionary).get("viewer", -1)) != pid:
			violations.append("channel %d received player %s's view"
				% [pid, str((m["view"] as Dictionary).get("viewer"))])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _offer_index(offers: Array, kind: String, card_id: int = -1,
		effect_id: String = "") -> int:
	for o in offers:
		if str(o["kind"]) != kind:
			continue
		if card_id != -1 and int(o["card_id"]) != card_id:
			continue
		if effect_id != "" and str(o["effect_id"]) != effect_id:
			continue
		return int(o["index"])
	return -1


## Rebuild an offered action from its message, so `DuelDriver`'s policy can rank it.
static func _action_from_offer(o: Dictionary) -> DuelAction:
	var a := DuelAction.make(DuelAction.kind_from_name(str(o["kind"])), int(o["player"]),
		int(o["card_id"]), str(o["effect_id"]))
	a.label = str(o["label"])
	a.clause_text = str(o["clause_text"])
	a.target_ids = (o["target_ids"] as Array).duplicate()
	a.tribute_ids = (o["tribute_ids"] as Array).duplicate()
	a.attack_target_id = int(o["attack_target_id"])
	a.position = int(o["position"])
	a.zone_index = int(o["zone_index"])
	a.target_candidates = (o["target_candidates"] as Array).duplicate()
	a.target_min = int(o["target_min"])
	a.target_max = int(o["target_max"])
	a.tribute_candidates = (o["tribute_candidates"] as Array).duplicate()
	a.tribute_combinations = (o["tribute_combinations"] as Array).duplicate(true)
	a.tributes_required = int(o["tributes_required"])
	a.attack_target_candidates = (o["attack_target_candidates"] as Array).duplicate()
	a.allows_direct_attack = bool(o["allows_direct_attack"])
	a.legal_positions = (o["legal_positions"] as Array).duplicate()
	return a


## Unit B (ADR-0002): the session names every card by a per-viewer alias. `DuelDriver`'s policy
## ranks actions against the engine's own state, so the harness translates an offer back to
## instance ids to rank it, and the pick back to aliases to submit it — through the session's
## test-only accessors, which the UI scan forbids under Scripts/ui/.
static func _to_real(session: EngineSession, viewer: int, v):
	if v is Array:
		return (v as Array).map(func(x): return _to_real(session, viewer, x))
	if typeof(v) == TYPE_INT and int(v) > 0:
		return session.debug_real_id(viewer, int(v))
	return v


static func _to_alias(session: EngineSession, viewer: int, v):
	if v is Array:
		return (v as Array).map(func(x): return _to_alias(session, viewer, x))
	if typeof(v) == TYPE_INT and int(v) > 0:
		return session.debug_alias(viewer, int(v))
	return v


static func _real_offer(session: EngineSession, viewer: int, o: Dictionary) -> Dictionary:
	var r := o.duplicate(true)
	for k in ["card_id", "target_ids", "tribute_ids", "attack_target_id", "target_candidates",
			"tribute_candidates", "tribute_combinations", "attack_target_candidates"]:
		r[k] = _to_real(session, viewer, o[k])
	return r


static func _alias_choices(session: EngineSession, viewer: int, choices: Dictionary) -> Dictionary:
	var c := choices.duplicate(true)
	for k in ["target_ids", "tribute_ids", "attack_target_id"]:
		if c.has(k):
			c[k] = _to_alias(session, viewer, c[k])
	return c


static func _index_of(recon: Array, a: DuelAction) -> int:
	var i := recon.find(a)
	if i != -1:
		return i
	for j in range(recon.size()):
		var r: DuelAction = recon[j]
		if r.kind == a.kind and r.card_id == a.card_id and r.effect_id == a.effect_id \
				and r.player_id == a.player_id:
			return j
	return -1


static func _choices_of(a: DuelAction) -> Dictionary:
	return {"target_ids": a.target_ids.duplicate(), "tribute_ids": a.tribute_ids.duplicate(),
		"attack_target_id": a.attack_target_id, "position": int(a.position),
		"zone_index": a.zone_index}


static func _request_from(rd: Dictionary) -> DecisionRequest:
	var r := DecisionRequest.new(Enums.DecisionKind.keys().find(str(rd["kind"])),
		int(rd["player"]), str(rd["prompt"]))
	r.options = (rd["options"] as Array).duplicate(true)
	r.min_count = int(rd["min_count"])
	r.max_count = int(rd["max_count"])
	return r


## An engine-format answer, as the session's index-based submission.
static func _as_submission(req: DecisionRequest, answer):
	if req.kind == Enums.DecisionKind.YES_NO or req.kind == Enums.DecisionKind.ORDER_TRIGGERS:
		return answer
	return (answer as Array).map(func(v): return req.options.find(v))


## Decline, pass, or move on — whatever commits to nothing. For boards where the answer does
## not matter, and for the leak tests' repeated sessions.
static func _neutral(m: Dictionary):
	if str(m["mode"]) == EngineSession.MODE_DECISION:
		var req := _request_from(m["request"])
		if req.kind == Enums.DecisionKind.YES_NO:
			return false
		if req.kind == Enums.DecisionKind.ORDER_TRIGGERS:
			return range(req.options.size())
		return range(req.min_count)
	for kind in ["PASS", "END_PHASE", "END_BATTLE_PHASE"]:
		var i := _offer_index(m["offers"], kind)
		if i != -1:
			return {"offer": i, "choices": {}}
	return {"offer": 0, "choices": {}}


## A Chain board: player 0, Main Phase 1, with two Set no-op-activation Traps of their own (A and
## C) and one of the opponent's (B). A's and B's resolutions ask five questions between them.
## `seen` receives what each resolution was actually told.
static func _chain_board(seed_value: int, seen: Array) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var a := TestFixtures.card_activation("session_a", Enums.SpellSpeed.SS2, [])
	a.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	a.resolve = func(ctx: EffectContext) -> void:
		var pick = ctx.ask(DecisionRequest.select(Enums.DecisionKind.SELECT_EXACTLY, 0,
			"A: pick one", [11, 22, 33], 1, 1, ctx.source, ctx.effect))
		seen.append(["A pick", pick])
		# Nested: this question exists only because of the previous answer.
		if pick == [22]:
			var again = ctx.ask(DecisionRequest.yes_no(0, "A: and the follow-up?", ctx.source,
				ctx.effect))
			seen.append(["A nested", again])
		var theirs = ctx.ask_player(1, DecisionRequest.select(Enums.DecisionKind.SELECT_UP_TO,
			1, "A asks the opponent", [7, 8], 0, 1, ctx.source, ctx.effect))
		seen.append(["A opponent", theirs])
	var b := TestFixtures.card_activation("session_b", Enums.SpellSpeed.SS2, [])
	b.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	b.resolve = func(ctx: EffectContext) -> void:
		var order = ctx.ask(DecisionRequest.order(1, "B: order these",
			[{"label": "first"}, {"label": "second"}, {"label": "third"}]))
		seen.append(["B order", order])
		var yes = ctx.ask(DecisionRequest.yes_no(1, "B: go on?", ctx.source, ctx.effect))
		seen.append(["B yes", yes])
	# C only exists so player 0 gets a REAL response window (a manual pass) inside the Chain.
	var c := TestFixtures.card_activation("session_c", Enums.SpellSpeed.SS2, [])
	c.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	return {"engine": engine, "p0": d["p0"], "p1": d["p1"],
		"a": TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.with_effect(TestFixtures.trap("Session Trap A"), a)),
		"b": TestFixtures.give_set_spell_trap(engine, 1,
			TestFixtures.with_effect(TestFixtures.trap("Session Trap B"), b)),
		"c": TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.with_effect(TestFixtures.trap("Session Trap C"), c))}


const CHAIN_EXPECTED := [["B order", [2, 0, 1]], ["B yes", true], ["A pick", [22]],
	["A nested", false], ["A opponent", [8]]]


## The same Chain, played single-threaded through ScriptedControllers — the reference.
static func _chain_reference(seed_value: int) -> DuelEngine:
	var seen: Array = []
	var board := _chain_board(seed_value, seen)
	var engine: DuelEngine = board["engine"]
	(board["p0"] as ScriptedController).queue([22]).queue(false)
	(board["p1"] as ScriptedController).queue([2, 0, 1]).queue(true).queue([8])
	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, (board["a"] as CardInstance).id))
	engine.submit_action(TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, (board["b"] as CardInstance).id))
	engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0))
	return engine


static func _gd_files(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, f])
	for sub in dir.get_directories():
		out.append_array(_gd_files("%s/%s" % [dir_path, sub]))
	return out


static func _object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _test_the_pure_helpers(t: TestCase) -> void:
	t.start("the pure helpers: the per-viewer event projection, plain-data copies, and the "
		+ "index-based answer formats")
	var own := GameEvent.new(GameEvent.Kind.RESPONSE_PASSED, {"player": 0, "automatic": true})
	var theirs_auto := GameEvent.new(GameEvent.Kind.RESPONSE_PASSED,
		{"player": 1, "automatic": true})
	var theirs_manual := GameEvent.new(GameEvent.Kind.RESPONSE_PASSED, {"player": 1, "timing": 4})
	var secret := GameEvent.new(GameEvent.Kind.CARD_DRAWN, {"card_name": "X", "private_to": [1]})
	var mine := GameEvent.new(GameEvent.Kind.CARD_DRAWN, {"card_name": "Y", "private_to": [0]})
	secret.sequence = 7
	mine.sequence = 8
	t.not_null(EngineSession.project_event(own, 0), "a viewer's own pass is kept")
	t.is_null(EngineSession.project_event(theirs_auto, 0), "the opponent's automatic pass is dropped")
	t.is_null(EngineSession.project_event(theirs_manual, 0), "and so is their manual pass")
	t.is_null(EngineSession.project_event(secret, 0), "an event private to the other player is dropped")
	var p = EngineSession.project_event(mine, 0)
	t.eq(p, {"kind": "CARD_DRAWN", "turn": 0, "phase": Enums.Phase.DRAW,
		"data": {"card_name": "Y"}},
		"a readable event keeps kind, turn, phase and data — no sequence, no private_to")

	var probe := DuelAction.new()
	var raw := {"a": [1, {"b": probe}], "c": "x"}
	t.is_true(EngineSession.contains_object(raw), "control: the raw value holds an Object")
	var copy = EngineSession.plain(raw)
	t.is_false(EngineSession.contains_object(copy), "plain() leaves no Object")
	t.eq(copy, {"a": [1, {"b": null}], "c": "x"}, "and replaces it with null, nothing else")
	(copy["a"] as Array).append(2)
	t.eq((raw["a"] as Array).size(), 2, "and it is a deep copy")

	var offer := DuelAction.make(Enums.ActionKind.ACTIVATE_CARD, 0, 5, "e")
	offer.label = "Activate"
	var offers := [offer]
	for bad in [null, 3, {}, {"offer": 1}, {"offer": -1}, {"offer": "0"}, {"offer": 0, "x": 1},
			{"offer": 0, "choices": {"params": {}}}, {"offer": 0, "choices": {"card_id": 99}},
			{"offer": 0, "choices": {"target_ids": 4}},
			{"offer": 0, "choices": {"target_ids": ["4"]}},
			{"offer": 0, "choices": {"attack_target_id": 1.5}}]:
		t.is_null(EngineSession.action_from(bad, offers), "malformed submission %s is refused"
			% str(bad))
	var chosen = EngineSession.action_from({"offer": 0, "choices": {"target_ids": [9]}}, offers)
	t.is_true(chosen is DuelAction and chosen != offer and chosen.card_id == 5
		and chosen.target_ids == [9] and offer.target_ids.is_empty(),
		"a valid one is a COPY of the offer with the choice applied; the offer is untouched")

	var yn := DecisionRequest.yes_no(0, "q")
	var sel := DecisionRequest.select(Enums.DecisionKind.SELECT_UP_TO, 0, "q", [10, 20, 30], 0, 2)
	var ord := DecisionRequest.order(0, "q", [{"k": 1}, {"k": 2}])
	t.eq(EngineSession.decision_from(true, yn), true, "YES_NO takes a bool")
	t.is_null(EngineSession.decision_from(1, yn), "and nothing else")
	t.eq(EngineSession.decision_from([2, 0], sel), [30, 10], "selections are option INDICES")
	for bad in [[3], [-1], [0, 0], ["0"], 0]:
		t.is_null(EngineSession.decision_from(bad, sel), "malformed selection %s is refused" % str(bad))
	t.eq(EngineSession.decision_from([1, 0], ord), [1, 0], "ORDER_TRIGGERS takes a permutation")
	t.eq(EngineSession.default_answer(yn), false, "the stop default declines a yes/no")
	t.eq(EngineSession.default_answer(sel), [], "commits to nothing optional")
	t.eq(EngineSession.default_answer(ord), [0, 1], "and keeps the offered order")


static func _test_a_chain_with_responses_and_nested_decisions(t: TestCase) -> void:
	t.start("a Chain built by both players through RESPONSE prompts, then five mid-resolution "
		+ "decisions — sequential, nested, and asked of the opponent — all answered from the "
		+ "owner thread; the duel is identical to the same inputs played single-threaded")
	var seen: Array = []
	var board := _chain_board(8821, seen)
	var engine: DuelEngine = board["engine"]
	var ta: int = (board["a"] as CardInstance).id
	var tb: int = (board["b"] as CardInstance).id
	var session := EngineSession.new()
	t.is_true(session.start_attached(engine), "the session takes over the arranged duel")
	var h := Harness.new(session)
	var modes: Array = []

	var p := h.next()
	t.is_true(int(p.get("player", -1)) == 0 and str(p.get("mode", "")) == "ACTION",
		"the first prompt is player 0's open game state")
	if p.is_empty():
		session.stop()
		return
	modes.append("0:ACTION")
	var ia := _offer_index(p["offers"], "ACTIVATE_CARD", session.debug_alias(0, ta))
	t.ne(ia, -1, "Trap A is offered")

	# Forged and malformed submissions: each is refused and the prompt is issued again.
	var id0 := int(p["prompt_id"])
	session.submit(0, id0, {"offer": 999})
	var r := h.next_for(0, "rejected")
	p = h.next_for(0, "prompt")
	t.is_true(not r.is_empty() and int(p.get("prompt_id", -1)) > id0,
		"an out-of-range offer index is rejected and re-prompted under a new id")
	session.submit(0, int(p["prompt_id"]), {"offer": ia, "choices": {"params": {"x": 1}}})
	r = h.next_for(0, "rejected")
	p = h.next_for(0, "prompt")
	t.is_false(r.is_empty(), "a choice field the UI may not set is rejected")
	# An int-valued field `with_choices()` does not read would otherwise be IGNORED, and the offer
	# carried out as if it had never been sent — a UI trying to redirect an action must hear no.
	session.submit(0, int(p["prompt_id"]), {"offer": ia, "choices": {"card_id": 99}})
	r = h.next_for(0, "rejected")
	if r.is_empty():
		t.check(false, "an unknown choice field was ACCEPTED instead of rejected")
		session.stop()
		return
	p = h.next_for(0, "prompt")
	t.eq(str(r.get("reason", "")), "malformed: name one offer by index, with only choice fields",
		"an unknown choice field is rejected, not silently ignored")
	var events_before := session.debug_engine().state.events.size()
	session.submit(0, int(p["prompt_id"]), {"offer": ia, "choices": {"target_ids": [4242]}})
	r = h.next_for(0, "rejected")
	p = h.next_for(0, "prompt")
	t.eq(str(r.get("reason", "")), "the engine refused that action",
		"a forged target on a non-targeting card is refused BY THE ENGINE")
	t.eq(session.debug_engine().state.events.size(), events_before,
		"and the refusal changed nothing — not one event")
	t.eq(_offer_index(p["offers"], "ACTIVATE_CARD", session.debug_alias(0, ta)), ia,
		"the same offers come back")

	session.submit(0, int(p["prompt_id"]), {"offer": ia, "choices": {}})
	p = h.next_for(1, "prompt")
	modes.append("1:%s" % str(p.get("mode", "")))
	var ib := _offer_index(p.get("offers", []), "ACTIVATE_CARD", session.debug_alias(1, tb))
	t.ne(ib, -1, "player 1 is offered Trap B as a response to Chain Link 1")
	session.submit(1, int(p["prompt_id"]), {"offer": ib, "choices": {}})
	p = h.next_for(0, "prompt")
	modes.append("0:%s" % str(p.get("mode", "")))
	var ipass := _offer_index(p.get("offers", []), "PASS")
	t.ne(ipass, -1, "player 0 has a real response window on Chain Link 2, with Pass")
	session.submit(0, int(p["prompt_id"]), {"offer": ipass, "choices": {}})

	# The Chain resolves: B (link 2) asks player 1 twice, then A (link 1) asks player 0 twice
	# — the second only because of the first answer — and then asks player 1.
	p = h.next_for(1, "prompt")
	modes.append("1:%s:%s" % [str(p.get("mode", "")), str(p.get("request", {}).get("kind", ""))])
	session.submit(1, int(p["prompt_id"]), [2, 0, 1])
	p = h.next_for(1, "prompt")
	modes.append("1:%s:%s" % [str(p.get("mode", "")), str(p.get("request", {}).get("kind", ""))])
	session.submit(1, int(p["prompt_id"]), true)
	p = h.next_for(0, "prompt")
	modes.append("0:%s:%s" % [str(p.get("mode", "")), str(p.get("request", {}).get("kind", ""))])
	# Unit B: selection options are instance ids, so they arrive as player 0's aliases of those ids
	# (ADR-0002); read back through the test-only accessor, they are still exactly the three.
	t.eq(_to_real(session, 0, p.get("request", {}).get("options", [])), [11, 22, 33],
		"A's question carries its options")
	# Well-formed index lists with the wrong COUNT: only the engine's own validate() refuses them.
	for wrong in [[], [0, 1]]:
		session.submit(0, int(p["prompt_id"]), wrong)
		r = h.next_for(0, "rejected")
		if r.is_empty():
			t.check(false, "the wrong-count answer %s was ACCEPTED" % str(wrong))
			session.stop()
			return
		p = h.next_for(0, "prompt")
		t.eq(str(r.get("reason", "")), "not a valid answer to that question",
			"%s for an exactly-1 choice is refused by the engine's validate() and asked again"
			% str(wrong))
	var stale := int(p["prompt_id"])
	session.submit(0, stale, [5])
	r = h.next_for(0, "rejected")
	p = h.next_for(0, "prompt")
	t.eq(str(r.get("reason", "")), "not a valid answer to that question",
		"an out-of-range answer mid-resolution is rejected and the question asked again")
	session.submit(0, stale, [1])
	r = h.next_for(0, "rejected")
	t.eq(str(r.get("reason", "")), EngineSession.NOT_YOUR_PROMPT,
		"an answer to the superseded prompt id is rejected")
	session.submit(1, int(p["prompt_id"]), [1])
	r = h.next_for(1, "rejected")
	t.eq(str(r.get("reason", "")), EngineSession.NOT_YOUR_PROMPT,
		"the OTHER player answering player 0's question is rejected, with the same reason")
	session.submit(0, int(p["prompt_id"]), [1])
	p = h.next_for(0, "prompt")
	modes.append("0:%s:%s" % [str(p.get("mode", "")), str(p.get("request", {}).get("kind", ""))])
	session.submit(0, int(p["prompt_id"]), false)
	p = h.next_for(1, "prompt")
	modes.append("1:%s:%s" % [str(p.get("mode", "")), str(p.get("request", {}).get("kind", ""))])
	session.submit(1, int(p["prompt_id"]), [1])
	p = h.next_for(0, "prompt")
	modes.append("0:%s" % str(p.get("mode", "")))

	# The last prompt is a RESPONSE, not an open game state: after a Chain resolves the turn
	# player gets a fast-effect window (RULES_SPEC.md 3 box B), and Trap C is still live.
	t.eq(modes, ["0:ACTION", "1:RESPONSE", "0:RESPONSE", "1:DECISION:ORDER_TRIGGERS",
		"1:DECISION:YES_NO", "0:DECISION:SELECT_EXACTLY", "0:DECISION:YES_NO",
		"1:DECISION:SELECT_UP_TO", "0:RESPONSE"],
		"every question reached the player it was addressed to, in the engine's order")
	t.eq(seen, CHAIN_EXPECTED, "every resolution received exactly the answer given for it")
	t.eq(h.violations, [], "every message was plain data on the right channel (%d checked)"
		% h.checked)
	var stats := session.stats()
	t.eq(int(stats["decisions_answered"]), 5, "five mid-resolution decisions were answered")
	t.eq(int(stats["request_player_mismatch"]), 0, "each was asked of the controller it names")
	t.eq((stats["decide_threads"] as Dictionary).keys(), [session.worker_thread_id()],
		"decide() ran on the worker thread only")
	t.ne(session.worker_thread_id(), session.owner_thread_id(),
		"and the worker is not the owner thread")

	var reference := _chain_reference(8821)
	var mine := session.debug_engine()
	t.eq(DuelDriver.first_difference(DuelDriver.event_lines(mine),
		DuelDriver.event_lines(reference)), -1,
		"the session's duel and the single-threaded reference emit identical events")
	t.eq(JSON.stringify(mine.log.to_replay()), JSON.stringify(reference.log.to_replay()),
		"and identical replay payloads — every action and every decision")
	t.eq(DuelDriver.final_board(mine), DuelDriver.final_board(reference), "and the same board")
	session.stop()
	t.is_false(session.is_running(), "stopped")


static func _test_engine_work_happens_only_on_the_worker(t: TestCase) -> void:
	t.start("every engine event is emitted on the worker thread; the owner thread never runs "
		+ "engine code once the session has started")
	var d := TestFixtures.new_duel(8841, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var threads: Array = []
	engine.state.event_emitted.connect(func(_e): threads.append(OS.get_thread_caller_id()))
	var session := EngineSession.new()
	session.start_attached(engine)
	var h := Harness.new(session)
	var steps := 0
	while steps < 12:
		var m := h.next()
		if m.is_empty() or str(m["type"]) != "prompt":
			break
		session.submit(int(m["player"]), int(m["prompt_id"]), _neutral(m))
		steps += 1
	var worker := session.worker_thread_id()
	session.stop()
	var distinct := {}
	for id in threads:
		distinct[id] = true
	t.eq(steps, 12, "non-vacuity: twelve prompts were answered")
	t.is_true(threads.size() > 0, "non-vacuity: %d events were emitted" % threads.size())
	t.eq(distinct.keys(), [worker], "every one of them on the worker thread")
	t.ne(worker, OS.get_main_thread_id(), "which is not the main thread")
	t.eq(h.violations, [], "every message was plain data on the right channel")


static func _test_the_owner_api_refuses_every_other_thread(t: TestCase) -> void:
	t.start("poll / submit / wait / debug_engine / stop from any thread but the owner are "
		+ "refused and counted; the session is untouched by them")
	var decks := [TestFixtures.real_deck(0), TestFixtures.real_deck(1)]
	var session := EngineSession.new()
	session.start_duel([decks[0]["cards"], decks[1]["cards"]],
		[decks[0]["name"], decks[1]["name"]], 8851, 0)
	t.is_true(session.wait_for_message(TIMEOUT_MS), "the first prompt was published")
	var results := {}
	var intruder := Thread.new()
	intruder.start(func() -> void:
		results["poll"] = session.poll(0) + session.poll(1)
		results["submit"] = session.submit(0, 1, {"offer": 0})
		results["wait"] = session.wait_for_message(1)
		results["engine"] = session.debug_engine()
		session.stop())
	intruder.wait_to_finish()
	intruder = null
	t.eq(results.get("poll"), [], "another thread's poll() gets nothing")
	t.eq(results.get("submit"), false, "its submit() is not queued")
	t.eq(results.get("wait"), false, "its wait_for_message() is refused")
	t.is_null(results.get("engine"), "its debug_engine() gets nothing")
	t.is_true(session.is_running(), "its stop() did not stop the session")
	t.eq((session.stats()["violations"] as Array).size(), 6,
		"all six calls were recorded as violations")
	var delivered := session.poll(0) + session.poll(1)
	t.eq(delivered.size(), 1, "the owner still receives the first prompt, which nobody stole")
	session.stop()
	t.is_false(session.is_running(), "the owner's stop() works")


## Luna's bounce against a Mirage Dragon with the opponent's Deck holding a copy they decline to
## send, or holding none — the batch-17 case, now through the session.
static func _luna_channels(opponent_holds_copy: bool) -> Dictionary:
	var target_def := FairyTailLunaTests._card(FairyTailLunaTests.DUPLICATE)
	var d := FairyTailLunaTests._bounce_board(8801, target_def)
	var engine: DuelEngine = d["engine"]
	TestFixtures.clear_deck(engine, 1)
	TestFixtures.give_to_deck(engine, 1, target_def if opponent_holds_copy \
		else TestFixtures.monster("Unrelated Card", 4, 1000, 1000))
	TestFixtures.give_to_deck(engine, 1, TestFixtures.monster("Deck Filler", 4, 1000, 1000))
	var luna_id: int = (d["luna"] as CardInstance).id
	var target_id: int = (d["target"] as CardInstance).id
	var session := EngineSession.new()
	session.start_attached(engine)
	var h := Harness.new(session)
	var out := {"ok": false, "ch0": "", "asked": 0, "kinds": [], "returned": false,
		"violations": []}
	var first := h.next()
	if first.is_empty() or int(first["player"]) != 0:
		session.stop()
		return out
	var i := _offer_index(first["offers"], "ACTIVATE_EFFECT", session.debug_alias(0, luna_id),
		FairyTailLunaTests.EFFECT_BOUNCE)
	var mark := (h.channels[0] as Array).size()
	session.submit(0, int(first["prompt_id"]), {"offer": i,
		"choices": {"target_ids": [session.debug_alias(0, target_id)]}})
	for guard in range(20):
		var m := h.next()
		if m.is_empty():
			break
		if str(m["type"]) != "prompt":
			continue
		if int(m["player"]) == 0:
			out["ok"] = i != -1
			break
		out["asked"] = int(out["asked"]) + 1
		(out["kinds"] as Array).append("%s:%s" % [str(m["mode"]),
			str(m.get("request", {}).get("kind", ""))])
		session.submit(1, int(m["prompt_id"]), _neutral(m))
	out["ch0"] = JSON.stringify((h.channels[0] as Array).slice(mark))
	out["returned"] = session.debug_engine().state.instance(luna_id).zone == Enums.Zone.HAND
	out["violations"] = h.violations
	session.stop()
	return out


static func _test_an_opponent_decision_mid_resolution_is_invisible_to_the_other_channel(
		t: TestCase) -> void:
	t.start("privacy: an opponent-side decision DURING resolution (Fairy Tail - Luna) reaches "
		+ "only the opponent's channel; player 0's channel is identical whether they were asked "
		+ "and declined or had nothing to be asked about")
	var declined := _luna_channels(true)
	var nothing := _luna_channels(false)
	t.is_true(bool(declined["ok"]) and bool(nothing["ok"]),
		"in both duels the effect resolved and player 0 was prompted again")
	t.is_true(int(declined["asked"]) > 0,
		"non-vacuity: with a copy in their Deck the opponent WAS asked, on their channel %s"
		% str(declined["kinds"]))
	t.eq(int(nothing["asked"]), 0, "non-vacuity: without one they were asked nothing")
	t.is_true(bool(declined["returned"]) and bool(nothing["returned"]),
		"and in both Luna returned to the hand")
	t.eq(declined["ch0"], nothing["ch0"],
		"player 0's channel — every message, view and log entry — is byte-identical")
	t.eq(declined["violations"] + nothing["violations"], [],
		"every message was plain data on the right channel")


## Player 1 holds a Set card that either CAN be activated in player 0's windows (a Spell Speed 2
## Trap) or cannot (a Normal Spell). Both are the same face-down stub to player 0. Player 0 ends
## their turn; player 1 passes whatever they are asked. Stops at player 1's first open state.
##
## `extra` (unit B, ADR-0002): "before" / "after" also gives player 1 a hand card, registered before
## or after the Set card, so the two hidden cards swap instance ids; "" (the unit-A boards) gives none.
static func _window_channels(opponent_can_respond: bool, extra: String = "") -> Dictionary:
	var d := TestFixtures.new_duel(8811, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var def: CardDef
	if opponent_can_respond:
		var e := TestFixtures.card_activation("session_probe", Enums.SpellSpeed.SS2, [])
		e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
		def = TestFixtures.with_effect(TestFixtures.trap("Session Probe"), e)
	else:
		def = TestFixtures.spell("Session Probe")
	if extra == "before":
		TestFixtures.give_to_hand(engine, 1, TestFixtures.monster("Session Extra", 4, 1000, 1000))
	TestFixtures.give_set_spell_trap(engine, 1, def)
	if extra == "after":
		TestFixtures.give_to_hand(engine, 1, TestFixtures.monster("Session Extra", 4, 1000, 1000))
	var session := EngineSession.new()
	session.start_attached(engine)
	var h := Harness.new(session)
	var out := {"reached": false, "ch0": "", "ch1_prompts": 0, "raw_passes": 0,
		"projected_passes": 0, "violations": []}
	var mark := -1
	for guard in range(60):
		var m := h.next()
		if m.is_empty():
			break
		if str(m["type"]) != "prompt":
			continue
		if mark == -1:
			mark = (h.channels[0] as Array).size()
		var pid := int(m["player"])
		if pid == 1:
			if str(m["mode"]) == "ACTION":
				out["reached"] = true
				break
			out["ch1_prompts"] = int(out["ch1_prompts"]) + 1
		session.submit(pid, int(m["prompt_id"]), _neutral(m))
	var ch0: Array = (h.channels[0] as Array).slice(maxi(mark, 0))
	out["ch0"] = JSON.stringify(ch0)
	for m in h.channels[0]:
		for e in (m as Dictionary).get("log", []):
			if str(e["kind"]) == "RESPONSE_PASSED" and int(e["data"].get("player", -1)) == 1:
				out["projected_passes"] = int(out["projected_passes"]) + 1
	for e in session.debug_engine().state.get_log_for(0):
		var ev: GameEvent = e
		if ev.kind == GameEvent.Kind.RESPONSE_PASSED and int(ev.data.get("player", -1)) == 1:
			out["raw_passes"] = int(out["raw_passes"]) + 1
	out["violations"] = h.violations
	session.stop()
	return out


static func _test_an_opponent_response_window_is_invisible_to_the_other_channel(
		t: TestCase) -> void:
	t.start("privacy: whether the opponent HAD a response window is invisible on the other "
		+ "channel — though the raw engine log reveals it, which is what the projection closes")
	var can := _window_channels(true)
	var cannot := _window_channels(false)
	t.is_true(bool(can["reached"]) and bool(cannot["reached"]),
		"both duels reached player 1's own open game state")
	t.is_true(int(can["ch1_prompts"]) > 0,
		"non-vacuity: holding a live Trap, player 1 was given %d response window(s)"
		% int(can["ch1_prompts"]))
	t.eq(int(cannot["ch1_prompts"]), 0, "non-vacuity: holding a dead card, none")
	t.is_true(int(can["raw_passes"]) > 0 and int(cannot["raw_passes"]) == 0,
		"the FINDING, measured: the raw log player 0 may read shows player 1's passes in one "
		+ "duel (%d) and none in the other" % int(can["raw_passes"]))
	t.eq(can["projected_passes"], 0, "the session's projection shows player 0 none of them")
	t.eq(can["ch0"], cannot["ch0"],
		"so player 0's channel — every message, view and log entry — is byte-identical")
	t.eq(can["violations"] + cannot["violations"], [],
		"every message was plain data on the right channel")
	# Unit B (ADR-0002): the same channel, with player 1's two hidden cards registered in the
	# opposite order — every identifier player 0 is shown for them comes from the alias book.
	var before := _window_channels(true, "before")
	var after := _window_channels(true, "after")
	t.is_true(bool(before["reached"]) and bool(after["reached"]),
		"unit B: both permuted duels reached player 1's own open game state")
	t.eq(before["ch0"], after["ch0"], "unit B: player 0's channel is byte-identical whatever order "
		+ "player 1's hidden cards were registered in")


## One scripted duel through the session, answered with `DuelDriver`'s own policy objects.
static func _play_session_duel(cfg: Dictionary) -> Dictionary:
	var d0 := TestFixtures.real_deck(0)
	var d1 := TestFixtures.real_deck(1)
	var session := EngineSession.new()
	var out := {"outcome": "", "problems": [], "decisions": {}, "prompts": [0, 0],
		"refused": 0, "engine": null, "violations": [], "checked": 0}
	if not session.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]],
			int(cfg["seed"]), int(cfg["first"]), ["Player 1", "Player 2"]):
		out["outcome"] = "not started"
		return out
	var policy := DuelDriver.new()
	policy.seed_value = int(cfg["seed"])
	policy.first_player = int(cfg["first"])
	policy.styles = (cfg["styles"] as Array).duplicate()
	policy.surrender_on_turn = int(cfg.get("surrender_on_turn", -1))
	var answerer := DuelDriver.PolicyController.new(0, "policy")
	var h := Harness.new(session, false)
	while true:
		var m := h.next()
		if m.is_empty():
			out["outcome"] = "timeout"
			break
		var type := str(m["type"])
		if type == "over":
			out["outcome"] = "ended"
			break
		if type != "prompt":
			(out["problems"] as Array).append("unexpected message %s" % str(m).left(200))
			out["outcome"] = "unexpected"
			break
		var prompts: Array = out["prompts"]
		prompts[int(m["player"])] = int(prompts[int(m["player"])]) + 1
		if not _answer_like_the_driver(h, policy, answerer, m, out):
			if str(out["outcome"]) == "":
				out["outcome"] = "rejected"
			break
	policy.engine = null
	session.stop()
	out["engine"] = session.debug_engine()
	out["violations"] = h.violations
	out["checked"] = h.checked
	return out


static func _answer_like_the_driver(h: Harness, policy: DuelDriver,
		answerer: ScriptedController, prompt: Dictionary, out: Dictionary) -> bool:
	var pid := int(prompt["player"])
	if str(prompt["mode"]) == EngineSession.MODE_DECISION:
		var rd: Dictionary = prompt["request"]
		var decisions: Dictionary = out["decisions"]
		decisions[str(rd["kind"])] = int(decisions.get(str(rd["kind"]), 0)) + 1
		var req := _request_from(rd)
		h.session.submit(pid, int(prompt["prompt_id"]),
			_as_submission(req, answerer._default_answer(req)))
		return true
	policy.engine = h.session.debug_engine()
	var recon: Array = (prompt["offers"] as Array).map(
		func(o): return _action_from_offer(_real_offer(h.session, pid, o)))
	var current := prompt
	for c in policy._candidates(pid, recon, str(prompt["mode"]) == EngineSession.MODE_RESPONSE):
		if c == null:
			continue
		var a: DuelAction = c
		policy._note_try(a)
		h.session.submit(pid, int(current["prompt_id"]),
			{"offer": _index_of(recon, a), "choices": _alias_choices(h.session, pid, _choices_of(a))})
		var reply := h.next()
		if reply.is_empty():
			out["outcome"] = "timeout"
			return false
		if str(reply["type"]) != "rejected":
			h.pending.push_front(reply)
			return true
		out["refused"] = int(out["refused"]) + 1
		current = h.next()
		if current.is_empty() or str(current["type"]) != "prompt" or int(current["player"]) != pid:
			(out["problems"] as Array).append("no re-issued prompt after a refusal")
			return false
	(out["problems"] as Array).append("every candidate the policy ranked was refused")
	return false


static func _test_whole_real_duels_equal_the_duel_driver(t: TestCase) -> void:
	t.start("the six scripted duels between the two REAL decks, played through the session "
		+ "with DuelDriver's own policies, reproduce DuelDriver's run exactly")
	var cap := DuelDriver.ErrorCapture.new()
	OS.add_logger(cap)
	var decision_kinds := {}
	var total_prompts := [0, 0]
	for cfg in ScriptedDuelTests.DUELS:
		var label := str(cfg["label"])
		var reference := ScriptedDuelTests.play(cfg)
		var started := Time.get_ticks_msec()
		var mine := _play_session_duel(cfg)
		var ms := Time.get_ticks_msec() - started
		t.eq(str(mine["outcome"]), "ended", "%s: ended through the session — problems %s"
			% [label, str(mine["problems"])])
		t.eq(reference.outcome, "ended", "%s: the reference run ended too" % label)
		var engine: DuelEngine = mine["engine"]
		if engine == null:
			continue
		t.eq(DuelDriver.first_difference(DuelDriver.event_lines(engine),
			DuelDriver.event_lines(reference.engine)), -1,
			"%s: every event is identical (%d events)" % [label, engine.log.entries.size()])
		t.eq(DuelDriver.final_board(engine), DuelDriver.final_board(reference.engine),
			"%s: the final board is identical" % label)
		t.eq(JSON.stringify(engine.log.to_replay()), JSON.stringify(reference.engine.log.to_replay()),
			"%s: the replay payload — every action and decision — is identical" % label)
		t.eq(int(mine["refused"]), reference.choice_rejections,
			"%s: the policy's refused guesses match the reference's (%d)"
			% [label, reference.choice_rejections])
		t.eq(mine["violations"], [], "%s: all %d messages were plain data on the right channel"
			% [label, int(mine["checked"])])
		for k in (mine["decisions"] as Dictionary).keys():
			decision_kinds[k] = int(decision_kinds.get(k, 0)) + int(mine["decisions"][k])
		for pid in [0, 1]:
			total_prompts[pid] += int(mine["prompts"][pid])
		print("  [session] %s: %d + %d prompts, %d decisions, %d ms" % [label,
			int(mine["prompts"][0]), int(mine["prompts"][1]),
			(mine["decisions"] as Dictionary).values().reduce(func(a, b): return a + b, 0), ms])
	OS.remove_logger(cap)
	t.eq(cap.errors, [], "no engine error and no SCRIPT ERROR was raised on either thread")
	print("  [session] mid-resolution decisions by kind: %s" % str(decision_kinds))
	t.is_true(total_prompts[0] > 0 and total_prompts[1] > 0,
		"non-vacuity: both channels were prompted (%s)" % str(total_prompts))
	t.is_true(decision_kinds.size() >= 2,
		"non-vacuity: real cards asked mid-resolution questions of %d kinds" % decision_kinds.size())


static func _test_stop_while_blocked_mid_resolution(t: TestCase) -> void:
	t.start("stop() while the worker is blocked INSIDE a Chain's resolution returns promptly, "
		+ "unwinds the engine with default answers and joins the thread")
	var seen: Array = []
	var board := _chain_board(8831, seen)
	var session := EngineSession.new()
	session.start_attached(board["engine"])
	var h := Harness.new(session)
	var p := h.next_for(0, "prompt")
	session.submit(0, int(p["prompt_id"]), {"offer": _offer_index(p["offers"], "ACTIVATE_CARD",
		session.debug_alias(0, (board["a"] as CardInstance).id)), "choices": {}})
	p = h.next_for(1, "prompt")
	session.submit(1, int(p["prompt_id"]), {"offer": _offer_index(p["offers"], "ACTIVATE_CARD",
		session.debug_alias(1, (board["b"] as CardInstance).id)), "choices": {}})
	p = h.next_for(0, "prompt")
	session.submit(0, int(p["prompt_id"]), {"offer": _offer_index(p["offers"], "PASS"),
		"choices": {}})
	p = h.next_for(1, "prompt")
	t.eq(str(p.get("mode", "")), "DECISION", "the worker is parked inside B's resolution")
	var started := Time.get_ticks_msec()
	session.stop()
	var ms := Time.get_ticks_msec() - started
	t.is_false(session.is_running(), "the session stopped")
	t.is_true(ms < 2000, "promptly (%d ms)" % ms)
	t.eq(seen, [["B order", [0, 1, 2]], ["B yes", false], ["A pick", [11]], ["A opponent", []]],
		"every pending question got the neutral default, so the whole Chain unwound")
	t.is_true(int(session.stats()["stop_defaults"]) >= 4, "four defaults were handed out")
	var engine := session.debug_engine()
	t.eq(engine.chain.chain_size(), 0, "the whole Chain resolved")
	t.eq(engine.waiting_player(), 0,
		"and the engine came back to rest waiting on a player (the turn player's window)")
	var left := session.poll(0) + session.poll(1)
	var types: Array = left.map(func(m): return str(m["type"]))
	t.eq(types, ["stopped", "stopped"], "nothing was published after the stop but 'stopped', "
		+ "once per channel")
	t.is_false(session.submit(0, 1, true), "a submit after the stop is not queued")


static func _test_stop_idle_before_start_and_twice(t: TestCase) -> void:
	t.start("stop() at an idle prompt, before start, and twice: each is clean and idempotent")
	var d0 := TestFixtures.real_deck(0)
	var d1 := TestFixtures.real_deck(1)
	var session := EngineSession.new()
	session.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]], 8861, 1)
	var h := Harness.new(session)
	var p := h.next()
	t.eq(str(p.get("type", "")), "prompt", "the duel opened with a prompt")
	session.stop()
	t.is_false(session.is_running(), "stopped at an idle prompt")
	session.stop()
	t.is_false(session.is_running(), "a second stop() is a no-op")
	t.not_null(session.debug_engine(), "the finished engine stays readable after the stop")
	var never := EngineSession.new()
	never.stop()
	t.is_false(never.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]], 1, 0),
		"a session stopped before it started cannot be started")
	t.is_false(never.is_running(), "and never ran")
	var twice := EngineSession.new()
	twice.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]], 8862, 0)
	t.is_false(twice.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]], 8863, 0),
		"a session runs one duel; a second start is refused")
	twice.stop()


## Build a session, start a real duel, wait for its first prompt, and DROP it without stop().
static func _dropped_session_refs() -> Dictionary:
	var d0 := TestFixtures.real_deck(0)
	var d1 := TestFixtures.real_deck(1)
	var session := EngineSession.new()
	session.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]], 8871, 0)
	var waited := session.wait_for_message(TIMEOUT_MS)
	return {"waited": waited, "session": weakref(session), "core": weakref(session._core),
		"thread": weakref(session._thread), "engine": weakref(session._core.engine),
		"controller": weakref(session._core.controllers[1])}


static func _test_dropping_a_running_session_joins_its_thread(t: TestCase) -> void:
	t.start("dropping the last reference to a RUNNING session stops and joins its worker and "
		+ "frees the session, its core, thread, engine and controllers")
	var cap := DuelDriver.ErrorCapture.new()
	OS.add_logger(cap)
	var refs := _dropped_session_refs()
	OS.remove_logger(cap)
	t.is_true(bool(refs["waited"]), "non-vacuity: the worker had published its first prompt")
	for k in ["session", "core", "thread", "engine", "controller"]:
		t.is_null((refs[k] as WeakRef).get_ref(), "the %s was freed" % k)
	t.eq(cap.errors, [], "and Godot reported nothing — no un-joined thread")


static func _session_cycle(kind: String) -> void:
	match kind:
		"chain_stop":
			var seen: Array = []
			var board := _chain_board(8881, seen)
			var session := EngineSession.new()
			session.start_attached(board["engine"])
			var h := Harness.new(session, false)
			var p := h.next_for(0, "prompt")
			session.submit(0, int(p["prompt_id"]), {"offer": _offer_index(p["offers"],
				"ACTIVATE_CARD", session.debug_alias(0, (board["a"] as CardInstance).id)),
				"choices": {}})
			p = h.next_for(1, "prompt")
			session.submit(1, int(p["prompt_id"]), {"offer": _offer_index(p["offers"],
				"ACTIVATE_CARD", session.debug_alias(1, (board["b"] as CardInstance).id)),
				"choices": {}})
			p = h.next_for(0, "prompt")
			session.submit(0, int(p["prompt_id"]), _neutral(p))
			h.next_for(1, "prompt")
			session.stop()
		"real_stop":
			var d0 := TestFixtures.real_deck(0)
			var d1 := TestFixtures.real_deck(1)
			var session := EngineSession.new()
			session.start_duel([d0["cards"], d1["cards"]], [d0["name"], d1["name"]], 8891, 0)
			var h := Harness.new(session, false)
			for i in range(40):
				var m := h.next()
				if m.is_empty() or str(m["type"]) != "prompt":
					break
				session.submit(int(m["player"]), int(m["prompt_id"]), _neutral(m))
			session.stop()
		"drop":
			_dropped_session_refs()


static func _test_repeated_sessions_leak_nothing(t: TestCase) -> void:
	t.start("sessions created, played and stopped back to back — mid-resolution, idle, or "
		+ "simply dropped — leave the ObjectDB count where it started")
	for kind in ["chain_stop", "real_stop", "drop"]:
		# Warm-up: the first use of a script can create per-PROCESS objects (static caches).
		_session_cycle(kind)
		_session_cycle(kind)
		var before := _object_count()
		var n := 8
		for i in range(n):
			_session_cycle(kind)
		t.eq(_object_count() - before, 0, "%d '%s' sessions: ObjectDB growth is 0" % [n, kind])


static func _test_the_ui_talks_to_the_session_only(t: TestCase) -> void:
	t.start("nothing under Scripts/ui/ names the engine, its state, the rules layer or the test "
		+ "harness — the UI talks to EngineSession only")
	var re := RegEx.create_from_string(UI_FORBIDDEN)
	var files := _gd_files(UI_DIR)
	var hits: Array = []
	for path in files:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if re.search(line) != null:
				hits.append("%s:%d %s" % [path, n, line.strip_edges()])
	t.is_true(files.size() >= 1, "non-vacuity: %d UI script(s) scanned" % files.size())
	t.eq(hits, [], "no forbidden reference")
	t.not_null(re.search("var s: GameState = null"), "control: the pattern matches GameState")
	t.not_null(re.search("session.debug_engine()"), "control: and the test-only accessor")
	t.is_null(re.search("var s: EngineSession = null"), "control: and not the session itself")


static func _test_the_session_never_touches_the_scene_tree(t: TestCase) -> void:
	t.start("nothing under Scripts/session/ reaches the scene tree, emits a signal or defers a "
		+ "call — the worker cannot do UI work, because the code it runs has no way to")
	var re := RegEx.create_from_string(SESSION_FORBIDDEN)
	var files := _gd_files(SESSION_DIR)
	var hits: Array = []
	for path in files:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			if re.search(code) != null:
				hits.append("%s:%d %s" % [path, n, code])
	# Unit B added Scripts/session/CardAliases.gd (ADR-0002), so the scan now covers four scripts.
	t.eq(files.size(), 4, "non-vacuity: the four session scripts were scanned")
	t.eq(hits, [], "no scene-tree, signal or deferred-call reference")
	t.not_null(re.search("node.call_deferred(\"x\")"), "control: the pattern matches call_deferred")
	t.not_null(re.search("changed.emit()"), "control: and a signal emission")


static func _test_the_production_deck_loader(t: TestCase) -> void:
	t.start("DeckLists (what the screen uses) loads exactly the Deck lists the test fixtures do")
	var lists := DeckLists.load_two_real_decks()
	t.eq(lists["errors"], [], "no load error")
	for i in [0, 1]:
		var fixture := TestFixtures.real_deck(i)
		t.eq(lists["names"][i], fixture["name"], "deck %d has the same name" % (i + 1))
		t.eq((lists["decks"][i] as Array).map(func(c): return (c as CardDef).name),
			(fixture["cards"] as Array).map(func(c): return (c as CardDef).name),
			"deck %d has the same 40 cards in the same order" % (i + 1))

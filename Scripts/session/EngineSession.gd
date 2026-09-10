class_name EngineSession
extends RefCounted

## The UI's ONLY door into a duel. Phase 7 unit A; the decision record is ADR-0001 in
## docs/ARCHITECTURE.md ("The UI execution boundary").
##
## The engine is synchronous. `submit_action()` runs until the duel next waits for a player, and
## every choice a card makes WHILE it resolves is pushed through `PlayerController.decide()` from
## deep inside the engine's own call stack. A Godot UI cannot answer from inside that call on its
## main thread. So one `EngineSession` owns one `DuelEngine` and runs it on ONE dedicated worker
## thread, and the thread that created the session (the "owner" — the UI's main thread) only ever:
##
##   * `poll(viewer)`   drains the messages addressed to that player — plain data, deep copies;
##   * `submit(player, prompt_id, value)`   answers the ONE prompt that is open;
##   * `stop()`   cancels the duel and joins the worker.
##
## Every engine call — `setup_duel()`, every `submit_action()`, every `decide()` — runs on the
## worker. The owner never touches an engine object, and the worker never touches the scene
## tree: nothing in this directory emits a signal or defers a call. The UI pulls.
##
## Exactly one question is open at a time, because the engine is single-threaded: either a
## timing-window prompt (ACTION in an open game state, RESPONSE in a response window — the
## engine's own pull API) or a mid-resolution DECISION (a `DecisionRequest` pushed through a
## `HumanController`). The worker publishes the prompt and parks until it is answered.
##
## PRIVACY — by construction, not by convention. A player's channel advances ONLY at that
## player's own prompts and at the end of the duel. Whether, when or how often the OTHER player
## was asked anything therefore cannot change what arrives on this channel: not the number of
## messages, not the prompt ids (numbered per player), not the view (taken at this player's own
## prompt), and not the log (projected per viewer, with the other player's RESPONSE_PASSED
## removed — see `project_event()` for why the raw log would leak).
##
## Messages (every one a Dictionary with "type"):
##   prompt    {player, prompt_id, mode: ACTION|RESPONSE|DECISION, prompt, view, log,
##              offers (ACTION/RESPONSE) | request (DECISION)}
##   rejected  {player, prompt_id, reason}   — a re-issued prompt follows when one is still open
##   over      {player, result, end_reason, view, log}   — to both players
##   stopped   {player: -1}   — to both players, once the worker has exited
##   error     {player: -1, reason}   — the engine waited on nobody while the duel was not over
##
## Answers (`submit`'s `value`):
##   ACTION / RESPONSE   {"offer": <index into offers>, "choices": {<CHOICE_FIELDS>}}
##   DECISION            YES_NO: bool;  ORDER_TRIGGERS: a permutation of option indices;
##                       every other kind: an Array of option INDICES
## The UI never builds an action or echoes an engine value back. The engine re-validates every
## action, and every answer goes through the engine's own `DecisionRequest.validate()`.
##
## CARD IDENTIFIERS (unit B, ADR-0002). Every card id in a message — views, log entries, offers,
## requests — is the RECEIVING player's alias for that card (`CardAliases`), never the engine's
## instance id: instance ids follow the public Deck lists and would name hidden cards. Choice
## fields in a submission name cards by the submitting player's aliases; the session translates
## them back, and an alias it cannot honour becomes 0, which the engine refuses.

const MODE_ACTION := "ACTION"
const MODE_RESPONSE := "RESPONSE"
const MODE_DECISION := "DECISION"

## The fields a submission may choose on an offered action. Everything else about the action is
## the engine's own offer.
const CHOICE_FIELDS := ["target_ids", "tribute_ids", "attack_target_id", "position", "zone_index"]

## One reason for every submission that does not answer the prompt open for its sender. It is
## the same whatever the engine is actually waiting on, so a stray submission learns nothing.
const NOT_YOUR_PROMPT := "that is not the prompt open for you"

var _core: Core = null
var _thread: Thread = null
var _owner_thread_id: int = -1
var _started: bool = false
var _shut_down: bool = false
var _last_error: String = ""


func _init() -> void:
	_owner_thread_id = OS.get_thread_caller_id()
	_core = Core.new()


## Dropping the last reference to a running session stops and joins its worker, so a session can
## never outlive its owner as a detached thread.
##
## Inlined rather than calling `_shutdown()`: during PREDELETE a script method called on the
## object itself fails with "base 'null instance'" (measured — every dropped session leaked its
## thread and core). Member fields and calls on OTHER objects still work.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _shut_down:
		return
	_shut_down = true
	if _thread != null:
		_core.request_stop()
		_thread.wait_to_finish()
		_thread = null
	if _core != null:
		_core.dispose()


# ---------------------------------------------------------------------------
# The owner-thread API
# ---------------------------------------------------------------------------

## Start a new duel between `decks` ([Array[CardDef], Array[CardDef]]) on the worker thread.
func start_duel(decks: Array, deck_names: Array, seed_value: int, first_player: int,
		player_names: Array = ["Player 1", "Player 2"]) -> bool:
	if not _owner_call("start_duel") or _started or _shut_down:
		return false
	var controllers: Array = []
	for pid in [0, 1]:
		controllers.append(HumanController.new(pid, str(player_names[pid]), _core))
	_core.engine = DuelEngine.new(seed_value)
	_core.aliases.attach(_core.engine.state)
	_core.controllers = controllers
	_core.setup = {"decks": decks, "controllers": controllers, "first": first_player,
		"names": deck_names}
	return _launch()


## Take over a duel that is already set up — for headless tests that arrange a board before the
## worker starts. Its controllers are replaced IN PLACE with `HumanController`s: the engine,
## `TriggerCollector`, `TurnFlow` and `ChainManager` all read that one Array. After this call the
## caller must not touch the engine again.
func start_attached(engine: DuelEngine) -> bool:
	if not _owner_call("start_attached") or _started or _shut_down or engine == null \
			or engine.controllers.size() != 2:
		return false
	var controllers: Array = []
	for pid in [0, 1]:
		var old = engine.controllers[pid]
		var shown: String = old.display_name if old != null else "Player %d" % (pid + 1)
		var h := HumanController.new(pid, shown, _core)
		engine.controllers[pid] = h
		controllers.append(h)
	_core.engine = engine
	_core.aliases.attach(engine.state)
	_core.controllers = controllers
	return _launch()


## Start a duel between the two REAL decks (`DeckLists`), so a UI never holds a `CardDef`. False
## when the decks do not load (`last_error()` says why) or the session cannot start.
func start_real_duel(seed_value: int, first_player: int,
		player_names: Array = ["Player 1", "Player 2"]) -> bool:
	if not _owner_call("start_real_duel"):
		return false
	var lists := DeckLists.load_two_real_decks()
	if not (lists["errors"] as Array).is_empty():
		_last_error = "the decks did not load: %s" % str(lists["errors"])
		return false
	if not start_duel(lists["decks"], lists["names"], seed_value, first_player, player_names):
		_last_error = "the session could not start"
		return false
	_last_error = ""
	return true


func last_error() -> String:
	return _last_error


## Drain every message addressed to `viewer`. Never blocks.
func poll(viewer: int) -> Array:
	if not _owner_call("poll") or viewer < 0 or viewer > 1:
		return []
	return _core.drain(viewer)


## Block the OWNER thread until a message is waiting for either player, or `timeout_ms` passes.
## For headless tests and tools; a frame-driven UI calls `poll()` from `_process()` instead.
func wait_for_message(timeout_ms: int = 5000) -> bool:
	if not _owner_call("wait_for_message"):
		return false
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not _core.has_messages():
		if Time.get_ticks_msec() >= deadline:
			return false
		if not _core.outbox_sem.try_wait():
			OS.delay_usec(50)
	return true


## Answer prompt `prompt_id` as `player`. Returns false only when nothing was queued (wrong
## thread, session not running); whether the answer is ACCEPTED arrives as a message.
func submit(player: int, prompt_id: int, value) -> bool:
	if not _owner_call("submit") or not is_running():
		return false
	var copy = value.duplicate(true) if (value is Array or value is Dictionary) else value
	_core.post({"player": player, "prompt_id": prompt_id, "value": copy})
	return true


## Cancel the duel and join the worker. Idempotent. A worker blocked inside a mid-resolution
## decision is released with a structurally valid default answer so the engine's stack unwinds;
## the abandoned duel is not a result and nothing more is published but "stopped".
func stop() -> void:
	if not _owner_call("stop"):
		return
	_shutdown()


func is_running() -> bool:
	return _thread != null and not _shut_down


func owner_thread_id() -> int:
	return _owner_thread_id


func worker_thread_id() -> int:
	return _core.get_worker_thread_id()


## Counters the tests assert on: prompts per player, answered decisions, rejections, engine
## refusals, defaults handed out while stopping, the threads `decide()` ran on, and every call
## made from a thread other than the owner.
func stats() -> Dictionary:
	return _core.snapshot_stats()


## The engine — for HEADLESS TESTS that compare a session's duel with a reference run. Valid only
## while the worker is parked (a prompt is open or the duel is over) or after `stop()`; null
## otherwise. The UI never calls this: `EngineSessionTests` fails if the name appears under
## Scripts/ui/.
func debug_engine() -> DuelEngine:
	if not _owner_call("debug_engine"):
		return null
	if is_running() and not _core.is_parked():
		return null
	return _core.engine


## The latest alias `viewer` was shown for instance `real_id` in its current stay — for HEADLESS
## TESTS that name a card they arranged. -1 when there is none or the worker is not parked. The UI
## never calls this (scanned).
func debug_alias(viewer: int, real_id: int) -> int:
	if not _owner_call("debug_alias") or (is_running() and not _core.is_parked()):
		return -1
	return _core.aliases.latest_alias(viewer, real_id)


## The instance id `alias` names for `viewer` now — for HEADLESS TESTS. -1 when it names none.
func debug_real_id(viewer: int, alias: int) -> int:
	if not _owner_call("debug_real_id") or (is_running() and not _core.is_parked()):
		return -1
	var id := _core.aliases.real_id(viewer, alias)
	return id if id > 0 else -1


func _launch() -> bool:
	_started = true
	_thread = Thread.new()
	if _thread.start(_core.run) != OK:
		_thread = null
		_core.dispose()
		return false
	return true


func _shutdown() -> void:
	if _shut_down:
		return
	_shut_down = true
	if _thread != null:
		_core.request_stop()
		_thread.wait_to_finish()
		_thread = null
	if _core != null:
		_core.dispose()


func _owner_call(api: String) -> bool:
	if OS.get_thread_caller_id() == _owner_thread_id:
		return true
	_core.note_violation(api)
	push_error("EngineSession.%s() was called from thread %d; only its owner thread %d may call it"
		% [api, OS.get_thread_caller_id(), _owner_thread_id])
	return false


# ---------------------------------------------------------------------------
# Pure helpers — static, so the tests exercise them without a thread
# ---------------------------------------------------------------------------

## What `viewer` may read of `ev`, as plain data — or null when they may not read it at all.
##
## Beyond the engine's own `private_to` filter, the OTHER player's RESPONSE_PASSED is dropped.
## The engine only stops in a response window for a player who has a legal response; otherwise
## it passes for them. A manual pass emits `{"player", "timing"}`, an automatic one
## `{"player", "automatic": true}`, and in the FAST / TP windows an automatic skip emits nothing
## at all. So the raw log tells the opponent whether this player COULD have responded, which the
## rules keep hidden. The viewer's own passes stay: they reveal nothing they do not know.
## `sequence` is dropped too: its gaps would count events the viewer may not read.
static func project_event(ev: GameEvent, viewer: int):
	if ev == null or not (ev.is_public() or viewer in ev.private_to()):
		return null
	if ev.kind == GameEvent.Kind.RESPONSE_PASSED and int(ev.data.get("player", -1)) != viewer:
		return null
	var data := {}
	for k in ev.data.keys():
		if k != "private_to":
			data[k] = ev.data[k]
	return {"kind": GameEvent.kind_name(ev.kind), "turn": ev.turn, "phase": ev.phase,
		"data": plain(data)}


## A deep copy holding only plain data: every Object is replaced by null, so nothing the UI
## receives can reach back into the engine or be shared with the worker.
static func plain(v):
	return _plain(v, [0])


static func _plain(v, sanitized: Array):
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[_plain(k, sanitized)] = _plain(v[k], sanitized)
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_plain(x, sanitized))
		return a
	if v is Object:
		sanitized[0] += 1
		return null
	return v


## True when `v` holds an Object anywhere — the tests' check that messages are plain data.
static func contains_object(v) -> bool:
	if v is Object:
		return true
	if v is Dictionary:
		for k in v.keys():
			if contains_object(k) or contains_object(v[k]):
				return true
	elif v is Array:
		for x in v:
			if contains_object(x):
				return true
	return false


## An offered action as the UI sees it: the engine's own enumeration, index-addressed.
static func offer_view(a: DuelAction, index: int) -> Dictionary:
	return plain({
		"index": index,
		"kind": DuelAction.kind_name(a.kind),
		"player": a.player_id,
		"card_id": a.card_id,
		"effect_id": a.effect_id,
		"label": a.label,
		"clause_text": a.clause_text,
		"target_ids": a.target_ids,
		"tribute_ids": a.tribute_ids,
		"attack_target_id": a.attack_target_id,
		"position": a.position,
		"zone_index": a.zone_index,
		"target_candidates": a.target_candidates,
		"target_min": a.target_min,
		"target_max": a.target_max,
		"tribute_candidates": a.tribute_candidates,
		"tribute_combinations": a.tribute_combinations,
		"tributes_required": a.tributes_required,
		"attack_target_candidates": a.attack_target_candidates,
		"allows_direct_attack": a.allows_direct_attack,
		"legal_positions": a.legal_positions,
	})


## The action a submission names: one of `offers` by index, with only CHOICE_FIELDS set. Null
## when the submission is malformed. Whether the choices are LEGAL is the engine's call.
static func action_from(value, offers: Array):
	if not (value is Dictionary):
		return null
	for k in value.keys():
		if not (k in ["offer", "choices"]):
			return null
	var idx = value.get("offer", null)
	if typeof(idx) != TYPE_INT or idx < 0 or idx >= offers.size():
		return null
	var choices = value.get("choices", {})
	if not (choices is Dictionary):
		return null
	var opts := {}
	for k in choices.keys():
		if not (k in CHOICE_FIELDS):
			return null
		var v = choices[k]
		if k == "target_ids" or k == "tribute_ids":
			if not (v is Array):
				return null
			for x in v:
				if typeof(x) != TYPE_INT:
					return null
			opts[k] = (v as Array).duplicate()
		else:
			if typeof(v) != TYPE_INT:
				return null
			opts[k] = v
	return (offers[idx] as DuelAction).with_choices(opts)


## The engine-format answer a submission names, or null when it is malformed. Selection kinds
## are answered by option INDEX, so the UI never has to echo an engine value back.
static func decision_from(value, req: DecisionRequest):
	match req.kind:
		Enums.DecisionKind.YES_NO:
			return value if typeof(value) == TYPE_BOOL else null
		Enums.DecisionKind.ORDER_TRIGGERS:
			if not (value is Array):
				return null
			for x in value:
				if typeof(x) != TYPE_INT:
					return null
			return (value as Array).duplicate()
		_:
			if not (value is Array):
				return null
			var out: Array = []
			var seen := {}
			for x in value:
				if typeof(x) != TYPE_INT or x < 0 or x >= req.options.size() or seen.has(x):
					return null
				seen[x] = true
				out.append(req.options[x])
			return out


## A structurally valid answer that commits to nothing optional — used only to let the engine's
## stack unwind when the session is stopped mid-resolution.
static func default_answer(req: DecisionRequest):
	match req.kind:
		Enums.DecisionKind.YES_NO:
			return false
		Enums.DecisionKind.ORDER_TRIGGERS:
			return range(req.options.size())
		_:
			return req.options.slice(0, mini(req.min_count, req.options.size()))


# ---------------------------------------------------------------------------
# The core: the only state the two threads share. Everything under `mutex` is shared; the rest
# is touched by the worker alone (or by the owner before the worker starts / after it is joined).
# It holds no reference to the EngineSession, so dropping the session can always join it.
# ---------------------------------------------------------------------------

class Core extends RefCounted:
	var mutex := Mutex.new()
	var inbox_sem := Semaphore.new()
	var outbox_sem := Semaphore.new()

	var engine: DuelEngine = null
	var controllers: Array = []
	var setup: Dictionary = {}
	## Worker-owned: every card id that leaves the session goes through it (ADR-0002).
	var aliases := CardAliases.new()

	# --- shared, guarded by `mutex` ---
	var _inbox: Array = []
	var _outbox: Array = [[], []]
	var _stop: bool = false
	var _parked: bool = false
	var _worker_thread_id: int = -1
	var _stats: Dictionary = {
		"prompts": [0, 0], "decisions_answered": 0, "rejected": 0, "refused_by_engine": 0,
		"accepted": 0, "stop_defaults": 0, "decide_threads": {}, "sanitized_objects": 0,
		"violations": [], "request_player_mismatch": 0, "unclassified_keys": {},
	}

	# --- worker only ---
	var _open: Dictionary = {}
	var _prompt_seq: Array = [0, 0]
	var _log_cursor: Array = [0, 0]
	var _over: bool = false

	# --- owner side ---

	func post(msg: Dictionary) -> void:
		mutex.lock()
		_inbox.append(msg)
		mutex.unlock()
		inbox_sem.post()

	func request_stop() -> void:
		mutex.lock()
		_stop = true
		mutex.unlock()
		inbox_sem.post()

	func drain(viewer: int) -> Array:
		mutex.lock()
		var out: Array = _outbox[viewer]
		_outbox[viewer] = []
		mutex.unlock()
		return out

	func has_messages() -> bool:
		mutex.lock()
		var any: bool = not (_outbox[0] as Array).is_empty() or not (_outbox[1] as Array).is_empty()
		mutex.unlock()
		return any

	func is_parked() -> bool:
		mutex.lock()
		var p := _parked
		mutex.unlock()
		return p

	func get_worker_thread_id() -> int:
		mutex.lock()
		var id := _worker_thread_id
		mutex.unlock()
		return id

	func note_violation(api: String) -> void:
		mutex.lock()
		(_stats["violations"] as Array).append("%s from thread %d" % [api,
			OS.get_thread_caller_id()])
		mutex.unlock()

	func snapshot_stats() -> Dictionary:
		mutex.lock()
		var s: Dictionary = _stats.duplicate(true)
		mutex.unlock()
		return s

	## Break the only reference cycle (core -> engine -> controllers -> core). The engine is kept
	## so a test can still read a finished duel.
	func dispose() -> void:
		aliases.detach()
		for c in controllers:
			c.bridge = null
		controllers = []
		setup = {}

	# --- worker side ---

	func run() -> void:
		mutex.lock()
		_worker_thread_id = OS.get_thread_caller_id()
		mutex.unlock()
		if not setup.is_empty():
			engine.setup_duel(setup["decks"], setup["controllers"], int(setup["first"]),
				setup["names"])
			setup = {}
		_park()
		while true:
			var msg := _take()
			if msg.is_empty():
				break
			_handle(msg)
		_open = {}
		_publish_both({"type": "stopped", "player": -1})

	func stopping() -> bool:
		mutex.lock()
		var s := _stop
		mutex.unlock()
		return s

	## Block until a submission arrives. {} means "stop": checked BEFORE waiting, because a stop
	## that was already consumed by a decision's wait must still end the main loop.
	func _take() -> Dictionary:
		while true:
			mutex.lock()
			if _stop:
				mutex.unlock()
				return {}
			_parked = true
			mutex.unlock()
			inbox_sem.wait()
			mutex.lock()
			var stop := _stop
			var msg: Dictionary = {} if _inbox.is_empty() else _inbox.pop_front()
			if not stop and not msg.is_empty():
				_parked = false
			mutex.unlock()
			if stop:
				return {}
			if not msg.is_empty():
				return msg
		return {}

	## A timing-window submission (ACTION / RESPONSE) arrived at the main loop.
	func _handle(msg: Dictionary) -> void:
		var from := int(msg.get("player", -1))
		var id := int(msg.get("prompt_id", -1))
		if _open.is_empty() or _open["mode"] == EngineSession.MODE_DECISION \
				or not _addresses_open(msg):
			_reject(from, id, EngineSession.NOT_YOUR_PROMPT)
			return
		var action = EngineSession.action_from(aliases.choices_to_real(from, msg.get("value")),
			_open["offers"])
		if action == null:
			_reject(from, id, "malformed: name one offer by index, with only choice fields")
			_reopen()
			return
		_open = {}
		if not engine.submit_action(action):
			_bump("refused_by_engine")
			if stopping():
				return
			_reject(from, id, "the engine refused that action")
			# The engine changes nothing when it refuses, so this re-offers the same choices.
			_park()
			return
		_bump("accepted")
		if stopping():
			return
		_park()

	## Called by a HumanController, on this thread, from inside the engine's call stack.
	func ask(pid: int, request: DecisionRequest):
		mutex.lock()
		var threads: Dictionary = _stats["decide_threads"]
		threads[OS.get_thread_caller_id()] = true
		if request.player_id != pid:
			_stats["request_player_mismatch"] = int(_stats["request_player_mismatch"]) + 1
		mutex.unlock()
		if stopping():
			_bump("stop_defaults")
			return EngineSession.default_answer(request)
		_open_prompt(pid, EngineSession.MODE_DECISION, request.prompt, [], request)
		while true:
			var msg := _take()
			if msg.is_empty():
				_open = {}
				_bump("stop_defaults")
				return EngineSession.default_answer(request)
			var from := int(msg.get("player", -1))
			var id := int(msg.get("prompt_id", -1))
			if not _addresses_open(msg):
				_reject(from, id, EngineSession.NOT_YOUR_PROMPT)
				continue
			var answer = EngineSession.decision_from(msg.get("value"), request)
			if answer == null or not request.validate(answer):
				_reject(from, id, "not a valid answer to that question")
				_reopen()
				continue
			_open = {}
			_bump("decisions_answered")
			return answer
		return EngineSession.default_answer(request)

	func _addresses_open(msg: Dictionary) -> bool:
		return not _open.is_empty() and int(msg.get("player", -1)) == int(_open["player"]) \
			and int(msg.get("prompt_id", -1)) == int(_open["id"])

	## The engine returned from setup or a submit: publish what it now waits for.
	func _park() -> void:
		if stopping():
			return
		if engine.is_duel_over():
			_finish()
			return
		var pid := engine.waiting_player()
		if pid == -1:
			_open = {}
			_publish_both({"type": "error", "player": -1,
				"reason": "the engine is waiting on nobody while the duel is not over"})
			return
		var pending := engine.get_pending_decision()
		var mode: String = EngineSession.MODE_RESPONSE if str(pending["kind"]) == "RESPONSE" \
			else EngineSession.MODE_ACTION
		_open_prompt(pid, mode, str(pending["prompt"]), pending["actions"], null)

	func _finish() -> void:
		_open = {}
		if _over:
			return
		_over = true
		var s := engine.state
		for pid in [0, 1]:
			var log := _log_delta(pid)
			var view: Dictionary = aliases.view(pid, _plain_counted(engine.get_visible_state(pid)))
			_sync_unclassified()
			_enqueue(pid, {"type": "over", "player": pid,
				"result": Enums.DuelResult.keys()[s.result],
				"end_reason": Enums.EndReason.keys()[s.end_reason],
				"view": view, "log": log}, pid == 1)

	## Publish a prompt to `pid`'s channel ONLY. The view and the log are taken now, at this
	## player's own prompt, which is what keeps the other channel independent of it.
	func _open_prompt(pid: int, mode: String, text: String, offers: Array,
			request: DecisionRequest) -> void:
		_prompt_seq[pid] = int(_prompt_seq[pid]) + 1
		var id: int = _prompt_seq[pid]
		_open = {"player": pid, "id": id, "mode": mode, "text": text, "offers": offers,
			"request": request}
		# Log first, then view, then offers: the order a viewer is shown cards in fixes their
		# aliases, so it is the same at every prompt.
		var log := _log_delta(pid)
		var view: Dictionary = aliases.view(pid, _plain_counted(engine.get_visible_state(pid)))
		var msg := {"type": "prompt", "player": pid, "prompt_id": id, "mode": mode,
			"prompt": text, "view": view, "log": log}
		if request != null:
			msg["request"] = aliases.request(pid, _plain_counted(request.to_dict()))
		else:
			var views: Array = []
			for i in range(offers.size()):
				views.append(aliases.offer(pid, EngineSession.offer_view(offers[i], i)))
			msg["offers"] = views
		_sync_unclassified()
		mutex.lock()
		var prompts: Array = _stats["prompts"]
		prompts[pid] = int(prompts[pid]) + 1
		mutex.unlock()
		_enqueue(pid, msg, true)

	## The prompt still open, issued again under a new id after a rejected answer.
	func _reopen() -> void:
		if _open.is_empty():
			return
		_open_prompt(int(_open["player"]), str(_open["mode"]), str(_open["text"]),
			_open["offers"], _open["request"])

	func _reject(pid: int, id: int, reason: String) -> void:
		_bump("rejected")
		if pid != 0 and pid != 1:
			return
		_enqueue(pid, {"type": "rejected", "player": pid, "prompt_id": id, "reason": reason})

	## Everything `pid` may read that happened since their last message.
	func _log_delta(pid: int) -> Array:
		var evs: Array = engine.state.events
		var out: Array = []
		for i in range(int(_log_cursor[pid]), evs.size()):
			var p = EngineSession.project_event(evs[i], pid)
			if p != null:
				p["data"] = aliases.event_data(pid, i, p["data"])
				out.append(p)
		_log_cursor[pid] = evs.size()
		return out

	## Publish the keys the alias book dropped as unclassified, for the tests that require none.
	func _sync_unclassified() -> void:
		mutex.lock()
		_stats["unclassified_keys"] = aliases.unclassified.duplicate()
		mutex.unlock()

	func _plain_counted(v):
		var n := [0]
		var out = EngineSession._plain(v, n)
		if int(n[0]) > 0:
			mutex.lock()
			_stats["sanitized_objects"] = int(_stats["sanitized_objects"]) + int(n[0])
			mutex.unlock()
		return out

	## Hand a finished message to the owner; the worker never touches it again. `parks` marks
	## the LAST message of a stretch of engine work (a prompt, the final "over", "stopped"): from
	## then until it takes the next submission the worker reads nothing, which is the only time
	## `debug_engine()` is valid. A "rejected" never parks — a re-issued prompt follows it.
	func _enqueue(pid: int, msg: Dictionary, parks: bool = false) -> void:
		mutex.lock()
		(_outbox[pid] as Array).append(msg)
		if parks:
			_parked = true
		mutex.unlock()
		outbox_sem.post()

	func _publish_both(msg: Dictionary) -> void:
		_enqueue(0, msg.duplicate(true))
		_enqueue(1, msg.duplicate(true), true)

	func _bump(key: String) -> void:
		mutex.lock()
		_stats[key] = int(_stats[key]) + 1
		mutex.unlock()

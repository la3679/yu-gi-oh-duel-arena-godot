extends Control

## Phase 7 unit A — the thinnest possible duel screen. It exists to prove the session boundary
## and nothing more: the open prompt as text, the offered actions / answers as buttons, a short
## log. The unit B board replaces all of it.
##
## It talks to `EngineSession` and to nothing else; `EngineSessionTests` scans this directory and
## fails on any reference to the rules layer's own types. Everything shown comes from a message
## the session delivered, and every button carries an offer index or option index the session
## sent — nothing here decides what is legal.
##
## NOT hidden-information safe on a shared screen yet. It shows whichever player's prompt is
## open, and on one monitor that alone shows the other player was asked something. The session's
## per-player channels do not leak; the pass-and-play HANDOFF policy that makes a shared screen
## safe is unit E.

@export var seed_value: int = 1001
@export var first_player: int = 0

const LOG_LINES := 16
## Buttons generated for one multi-choice offer, at most; the unit C prompts replace this.
const MAX_COMBOS := 12

var session: EngineSession = null
## The prompt message now open, or {} while the engine works.
var current: Dictionary = {}
var status_line: String = ""
## Per player: every log line their channel delivered.
var logs: Array = [[], []]
## False if a message handler ever ran off the main thread — `SceneSpikeCheck` asserts it.
var main_thread_only: bool = true

var _header: Label
var _prompt: Label
var _status: Label
var _choices: VBoxContainer
var _log: Label


func _ready() -> void:
	_build_layout()
	start_new_duel()


func _exit_tree() -> void:
	if session != null:
		session.stop()
		session = null


func start_new_duel() -> void:
	if session != null:
		session.stop()
	current = {}
	logs = [[], []]
	var lists := DeckLists.load_two_real_decks()
	if not (lists["errors"] as Array).is_empty():
		status_line = "The decks did not load: %s" % str(lists["errors"])
		_render()
		return
	session = EngineSession.new()
	if session.start_duel(lists["decks"], lists["names"], seed_value, first_player):
		status_line = "Duel started — seed %d" % seed_value
	else:
		status_line = "The duel could not be started"
	_render()


func _process(_delta: float) -> void:
	if session == null:
		return
	var changed := false
	for viewer in [0, 1]:
		for msg in session.poll(viewer):
			_on_message(msg)
			changed = true
	if changed:
		_render()


func _on_message(msg: Dictionary) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		main_thread_only = false
	match str(msg.get("type", "")):
		"prompt":
			current = msg
			_append_log(int(msg["player"]), msg.get("log", []))
		"rejected":
			status_line = "Not accepted: %s" % str(msg.get("reason", ""))
		"over":
			current = {}
			_append_log(int(msg["player"]), msg.get("log", []))
			status_line = "Duel over — %s (%s)" % [str(msg.get("result", "")),
				str(msg.get("end_reason", ""))]
		"stopped":
			current = {}
			status_line = "Session stopped"
		"error":
			current = {}
			status_line = "Engine error: %s" % str(msg.get("reason", ""))


func _append_log(player: int, entries: Array) -> void:
	for e in entries:
		var d: Dictionary = e.get("data", {})
		var who := ""
		if d.has("card_name") and d["card_name"] != null:
			who = " %s" % str(d["card_name"])
		(logs[player] as Array).append("T%d %s%s" % [int(e.get("turn", 0)), str(e.get("kind", "")),
			who])


# ---------------------------------------------------------------------------
# Rendering — from the open prompt message only
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 26)
	column.add_child(_header)
	_prompt = Label.new()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_prompt)
	_status = Label.new()
	column.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	column.add_child(scroll)
	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_choices)
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_log)


func _render() -> void:
	for child in _choices.get_children():
		child.queue_free()
	_status.text = status_line
	if current.is_empty():
		_header.text = "Duel Arena — waiting for the engine"
		_prompt.text = ""
		_log.text = ""
		return
	var player := int(current["player"])
	var view: Dictionary = current.get("view", {})
	var lp := []
	for p in view.get("players", []):
		lp.append("%s %d LP" % [str(p.get("name", "")), int(p.get("life_points", 0))])
	_header.text = "%s to act — %s" % [_player_name(view, player), str(current["mode"])]
	_prompt.text = "%s\nTurn %d · %s · %s" % [str(current.get("prompt", "")),
		int(view.get("turn", 0)), Enums.phase_name(int(view.get("phase", 0))), " / ".join(lp)]
	var entries: Array = logs[player]
	_log.text = "\n".join(entries.slice(maxi(0, entries.size() - LOG_LINES)))
	for choice in _choices_for(current):
		var b := Button.new()
		b.text = str(choice[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_submit.bind(choice[1]))
		_choices.add_child(b)


## [[button text, the value to submit], ...] for the open prompt.
func _choices_for(prompt: Dictionary) -> Array:
	var view: Dictionary = prompt.get("view", {})
	var out: Array = []
	if str(prompt["mode"]) == EngineSession.MODE_DECISION:
		var req: Dictionary = prompt["request"]
		var options: Array = req.get("options", [])
		match str(req.get("kind", "")):
			"YES_NO":
				out.append(["Yes", true])
				out.append(["No", false])
			"ORDER_TRIGGERS":
				out.append(["Resolve in the offered order", range(options.size())])
			_:
				var n := maxi(1, int(req.get("min_count", 1)))
				if int(req.get("min_count", 1)) == 0:
					out.append(["None", []])
				for combo in _combinations(range(options.size()), n):
					var names: Array = combo.map(func(i): return _option_name(view, options[i]))
					out.append([", ".join(names), combo])
		return out
	for offer in prompt.get("offers", []):
		var o: Dictionary = offer
		var i := int(o["index"])
		var label := str(o.get("label", o.get("kind", "")))
		if int(o.get("tributes_required", 0)) > 0:
			for combo in (o.get("tribute_combinations", []) as Array).slice(0, MAX_COMBOS):
				out.append(["%s — Tribute %s" % [label, _names(view, combo)],
					{"offer": i, "choices": {"tribute_ids": combo}}])
		elif str(o["kind"]) == "DECLARE_ATTACK":
			for tid in o.get("attack_target_candidates", []):
				out.append(["%s → %s" % [label, _card_name(view, int(tid))],
					{"offer": i, "choices": {"attack_target_id": int(tid)}}])
			if bool(o.get("allows_direct_attack", false)):
				out.append(["%s directly" % label, {"offer": i, "choices": {"attack_target_id": -1}}])
		elif int(o.get("target_max", 0)) > 0:
			if int(o.get("target_min", 0)) == 0:
				out.append([label, {"offer": i, "choices": {}}])
			for combo in _combinations(o.get("target_candidates", []),
					maxi(1, int(o.get("target_min", 0)))):
				out.append(["%s → %s" % [label, _names(view, combo)],
					{"offer": i, "choices": {"target_ids": combo}}])
		elif (o.get("legal_positions", []) as Array).size() > 1:
			for pos in o["legal_positions"]:
				out.append(["%s (%s)" % [label, Enums.Position.keys()[int(pos)]],
					{"offer": i, "choices": {"position": int(pos)}}])
		else:
			out.append([label, {"offer": i, "choices": {}}])
	return out


func _submit(value) -> void:
	if session == null or current.is_empty():
		return
	session.submit(int(current["player"]), int(current["prompt_id"]), value)
	current = {}
	_render()


# ---------------------------------------------------------------------------
# Small helpers over the delivered view
# ---------------------------------------------------------------------------

static func _player_name(view: Dictionary, pid: int) -> String:
	for p in view.get("players", []):
		if int(p.get("id", -1)) == pid:
			return str(p.get("name", "Player %d" % (pid + 1)))
	return "Player %d" % (pid + 1)


static func _option_name(view: Dictionary, option) -> String:
	if typeof(option) == TYPE_INT:
		return _card_name(view, option)
	if option is Dictionary:
		return str(option.get("label", option.get("effect_id", str(option))))
	return str(option)


static func _names(view: Dictionary, ids: Array) -> String:
	return " + ".join(ids.map(func(id): return _card_name(view, int(id))))


## The name the view gives card `id`, or "#id" when the viewer is not shown one.
static func _card_name(view, id: int) -> String:
	var found = _find_card(view, id)
	if found is Dictionary and found.get("name") != null:
		return str(found["name"])
	return "#%d" % id


static func _find_card(v, id: int):
	if v is Dictionary:
		if v.has("id") and v.has("hidden") and int(v["id"]) == id:
			return v
		for k in v.keys():
			var hit = _find_card(v[k], id)
			if hit != null:
				return hit
	elif v is Array:
		for x in v:
			var hit = _find_card(x, id)
			if hit != null:
				return hit
	return null


## Every `k`-element combination of `items`, in order, at most MAX_COMBOS of them.
static func _combinations(items: Array, k: int) -> Array:
	var out: Array = []
	if k <= 0 or k > items.size():
		return out
	var idx: Array = range(k)
	while out.size() < MAX_COMBOS:
		out.append(idx.map(func(i): return items[i]))
		var j := k - 1
		while j >= 0 and int(idx[j]) == items.size() - k + j:
			j -= 1
		if j < 0:
			break
		idx[j] = int(idx[j]) + 1
		for m in range(j + 1, k):
			idx[m] = int(idx[m - 1]) + 1
	return out

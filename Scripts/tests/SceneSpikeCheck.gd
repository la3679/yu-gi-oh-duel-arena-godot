extends SceneTree

## Phase 7 unit A — the playable spike, driven through a REAL main loop.
##
##   ./Tools/run_tests.sh SceneSpikeCheck
##
## Loads the project's `run/main_scene` exactly as F5 would, lets the screen poll its session
## from `_process()` frame by frame, and presses the screen's own buttons: it moves the duel on
## until the turn player is offered a Normal Summon, clicks it, and passes when the log the
## screen received shows NORMAL_SUMMON_SUCCEEDED. `EngineSessionTests` proves the session in
## depth; this proves the scene is wired to it and that nothing blocks the main thread.
##
## Prints "RESULT: PASS" / "RESULT: FAIL", which `Tools/run_tests.*` reads.

const MAX_FRAMES := 20000
## Buttons that move a duel on without committing to anything, in preference order.
const MOVERS := ["Pass", "Proceed", "Finish the End Phase", "End your turn", "End the Battle Phase",
	"No", "Resolve in the offered order"]

## Untyped on purpose: the checks read the screen script's own members.
var screen = null
var frames := 0
var clicked := false
var clicked_label := ""
var done := false


func _initialize() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var packed = load(path) if path != "" else null
	if not (packed is PackedScene):
		_finish("run/main_scene '%s' is not a loadable scene" % path)
		return
	screen = (packed as PackedScene).instantiate()
	root.add_child(screen)


func _process(_delta: float) -> bool:
	if done:
		return false
	frames += 1
	if frames == 1:
		# A `--script` run must not ALSO load run/main_scene on its own: every headless suite
		# would then start a duel and a worker thread nobody asked for.
		var screens := root.get_children().filter(
			func(n): return n.scene_file_path == screen.scene_file_path)
		if screens.size() != 1:
			_finish("%d copies of the main scene are in the tree; a --script run loaded it "
				% screens.size() + "by itself")
			return false
	if frames > MAX_FRAMES:
		_finish("no Normal Summon succeeded within %d frames (clicked: %s)" % [MAX_FRAMES,
			str(clicked)])
		return false
	if clicked and _summon_succeeded():
		_finish("")
		return false
	var prompt: Dictionary = screen.current
	if prompt.is_empty():
		return false
	if not clicked and str(prompt.get("mode", "")) == "ACTION":
		var summon := _button_starting_with("Normal Summon")
		if summon != null:
			clicked = true
			clicked_label = summon.text
			summon.pressed.emit()
			return false
	for m in MOVERS:
		var b := _button_starting_with(m)
		if b != null:
			b.pressed.emit()
			return false
	var any := _live_buttons()
	if not any.is_empty():
		(any[0] as Button).pressed.emit()
	return false


func _summon_succeeded() -> bool:
	for lines in screen.logs:
		for line in lines:
			if str(line).find("NORMAL_SUMMON_SUCCEEDED") != -1:
				return true
	return false


func _live_buttons() -> Array:
	var out: Array = []
	for c in screen._choices.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _button_starting_with(prefix: String) -> Button:
	for b in _live_buttons():
		if (b as Button).text.begins_with(prefix):
			return b
	return null


func _finish(error: String) -> void:
	done = true
	var failures: Array = []
	if error != "":
		failures.append(error)
	if screen != null:
		if not screen.main_thread_only:
			failures.append("a session message was handled off the main thread")
		print("  [spike] %d frames; clicked '%s'; status '%s'" % [frames, clicked_label,
			str(screen.status_line)])
		root.remove_child(screen)
		screen.free()
		screen = null
	if failures.is_empty():
		print("RESULT: PASS")
	else:
		for f in failures:
			print("  FAIL " + f)
		print("RESULT: FAIL")
	quit()

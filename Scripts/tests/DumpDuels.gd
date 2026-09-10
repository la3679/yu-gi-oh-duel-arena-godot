extends SceneTree

## Cross-process determinism probe — part of the backend acceptance gate
## (PROJECT_STATE.md §8, unit 3). Not a suite: it asserts nothing on its own.
##
##   ./Tools/check_determinism.sh        (or Tools\check_determinism.ps1)
##
## Plays every scripted duel of `ScriptedDuelTests.DUELS` and prints one line per duel: its
## outcome, its event count and a SHA-256 over its whole event stream, its final board and its
## replay payload. The check scripts run this in two SEPARATE Godot processes and require the
## two outputs to be identical. Same-process determinism is asserted inside the suite; this
## proves a duel depends on nothing that differs between processes — object ids, hash seeds,
## allocation order or the clock.

func _initialize() -> void:
	var ok := true
	for cfg in ScriptedDuelTests.DUELS:
		var drv := ScriptedDuelTests.play(cfg)
		var lines := DuelDriver.event_lines(drv.engine)
		var blob := "\n".join(PackedStringArray(lines)) + "\n" \
			+ DuelDriver.final_board(drv.engine) + "\n" + drv.engine.log.to_json()
		var digest := blob.sha256_text()
		print("DUEL %s | outcome=%s turn=%d events=%d sha256=%s" % [cfg["label"], drv.outcome,
			drv.engine.state.turn_number, lines.size(), digest])
		if drv.outcome != "ended" or not drv.errors.is_empty():
			ok = false
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()

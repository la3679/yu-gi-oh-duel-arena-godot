extends SceneTree

## Headless test entry point. Master prompt 64.
##
##   godot --headless --path <project> --script res://Scripts/tests/RunTests.gd
##
## Exits 0 only when every suite passes. Suites are registered explicitly so a suite
## that fails to load is a hard error rather than a silently skipped test.

func _initialize() -> void:
	var suites: Array[TestCase] = []

	suites.append(ChainTests.run())

	var total_passed := 0
	var total_failed := 0
	print("")
	for s in suites:
		print(s.report())
		total_passed += s.passed
		total_failed += s.failed

	print("")
	print("=======================================")
	print("TOTAL: %d passed, %d failed (%d assertions across %d suite(s))"
		% [total_passed, total_failed, total_passed + total_failed, suites.size()])
	print("=======================================")

	if total_failed > 0:
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)

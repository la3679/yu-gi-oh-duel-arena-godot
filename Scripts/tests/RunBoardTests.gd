extends SceneTree

## Targeted runner for Phase 7 unit B: the hidden-identity gate, the board view model and the
## board scene, with the unit-A session suite they build on.
##
##   ./Tools/run_tests.sh RunBoardTests
##
## The FULL run (`RunTests`) stays the authority for every number.

func _initialize() -> void:
	var suites: Array[TestCase] = []
	suites.append(EngineSessionTests.run())
	suites.append(HiddenIdentityTests.run())

	var total_passed := 0
	var total_failed := 0
	var empty_suites: Array[String] = []
	print("")
	for s in suites:
		print(s.report())
		total_passed += s.passed
		total_failed += s.failed
		if s.total() == 0:
			empty_suites.append(s.suite_name)
	print("")
	print("TOTAL: %d passed, %d failed (%d assertions across %d suite(s))" % [
		total_passed, total_failed, total_passed + total_failed, suites.size()])
	if not empty_suites.is_empty():
		print("EMPTY SUITES (a suite that asserts nothing is a failure): %s"
			% ", ".join(empty_suites))
	print("RESULT: %s" % ("PASS" if total_failed == 0 and empty_suites.is_empty()
		else "FAIL"))
	quit()

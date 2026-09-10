extends SceneTree

## Targeted runner for the post-card phase: object lifetime, scripted full duels and the
## backend acceptance gate.
##
##   ./Tools/run_tests.sh RunIntegrationTests
##
## `ReplayTests` and `HiddenInfoTests` ride along because the scripted duels extend exactly
## what those two prove per fragment — the replay payload and hidden-information filtering —
## to a whole game. The FULL run stays the authority for every number.

func _initialize() -> void:
	var suites: Array[TestCase] = []
	suites.append(ReplayTests.run())
	suites.append(HiddenInfoTests.run())
	suites.append(LifetimeTests.run())
	suites.append(ScriptedDuelTests.run())
	suites.append(BackendAcceptanceTests.run())

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

extends SceneTree

## Targeted runner for Phase 5 batch 16 — the twin of `RunBatch15Tests.gd`.
##
##   ./Tools/run_tests.sh RunBatch16Tests
##
## Runs the new gate and the new card next to the suites they are most likely to disturb:
## the continuous layer whose `restrict()` and `negate_effects()` now take a source, the
## control and banish subsystems whose entry points are now gated, the summon layer that
## records the corrected "Tribute Summoned" property, the replay claim, and the three
## neighbouring cards that write through the gated primitives (`Fiendish Chain` negates,
## `Fairy Tail - Rella` restricts, `Compulsory Evacuation Device` moves). The FULL run
## stays the authority for every number.

func _initialize() -> void:
	var suites: Array[TestCase] = []
	suites.append(ImmunityTests.run())
	suites.append(ContinuousTests.run())
	suites.append(ControlTests.run())
	suites.append(BanishTests.run())
	suites.append(SummonTests.run())
	suites.append(ReplayTests.run())
	suites.append(FiendishChainTests.run())
	suites.append(FairyTailRellaTests.run())
	suites.append(CompulsoryEvacuationDeviceTests.run())
	suites.append(InterdimensionalMatterTransporterTests.run())
	suites.append(MonarchsAwakenTests.run())

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
	print("TOTAL: %d passed, %d failed (%d assertions across %d suite(s))"
		% [total_passed, total_failed, total_passed + total_failed, suites.size()])
	for name in empty_suites:
		print("EMPTY SUITE: %s ran no assertions — treated as a failure" % name)
	if total_failed > 0 or not empty_suites.is_empty():
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)

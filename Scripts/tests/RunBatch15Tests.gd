extends SceneTree

## Targeted runner for Phase 5 batch 15 — the twin of `RunBatch14Tests.gd`.
##
##   ./Tools/run_tests.sh RunBatch15Tests
##
## Runs the new card suite next to the suites it is most likely to disturb: the
## hidden-information gate it extends, the replay claim its randomness rides on, the
## Special Summon layer it consumes, and the two neighbouring cards that answer an attack
## declaration in the same window. The FULL run stays the authority for every number.

func _initialize() -> void:
	var suites: Array[TestCase] = []
	suites.append(HiddenInfoTests.run())
	suites.append(ReplayTests.run())
	suites.append(SpecialSummonTests.run())
	suites.append(KunaiWithChainTests.run())
	suites.append(MaidenWithEyesOfBlueTests.run())
	suites.append(DamageCondenserTests.run())
	suites.append(AHeroEmergesTests.run())

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

extends SceneTree

## Prints the measured per-test assertion count for each Phase 5 per-card / interaction
## suite. `Reports/TEST_RESULTS.md` quotes those numbers, and they must be measured, not
## counted by hand from the source: a suite that loops over nine cards runs many more
## assertions than it has `t.` call sites.
##
##   godot --headless --path <project> --script res://Scripts/tests/DumpAssertionCounts.gd
##
## This is a reporting tool, not a test. `RunTests.gd` remains the pass/fail authority.

func _initialize() -> void:
	var suites: Array[TestCase] = [
		ShiningAngelTests.run(),
		NormalMonsterTests.run(),
		MonsterRebornTests.run(),
		SilversCryTests.run(),
		KaibamanTests.run(),
		DragonicTacticsTests.run(),
		OneForOneTests.run(),
		SpecialSummonInteractionTests.run(),
		BirthrightTests.run(),
		CallOfTheHauntedTests.run(),
		HieraticDragonOfTefnuitTests.run(),
		InariFireTests.run(),
		RanryuTests.run(),
		NefariousArchfiendTests.run(),
		GagagashieldTests.run(),
		RiderOfTheStormWindsTests.run(),
		# A rules suite, but Reports/TEST_RESULTS.md quotes its per-test counts too, and
		# they have to be measured for the same reason.
		EquipTests.run(),
	]
	print("")
	for suite in suites:
		print("%s — %d/%d" % [suite.suite_name, suite.passed, suite.total()])
		for test_name in suite.test_order:
			print("    %4d  %s" % [int(suite.test_counts[test_name]), test_name])
	quit(0)

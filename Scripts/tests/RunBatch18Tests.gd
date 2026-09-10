extends SceneTree

## Targeted runner for Phase 5 batch 18 — the twin of `RunBatch17Tests.gd`.
##
##   ./Tools/run_tests.sh RunBatch18Tests
##
## Batch 18 is the FINAL card batch and is done in two units, so this runner grows with
## it. Unit A (`Fairy Tail - Sleeper`, R5) reached into the one function every resolving
## effect passes through, so the neighbours are chosen by what it touched:
##
##   * `ChainTests` — the substitution gate itself, next to the two negations it must not
##     be confused with;
##   * `TimingTests` and `ReplayTests` — `_resolve_link()` now chooses between two effects
##     and reports which one it ran, which is what a replay records;
##   * `DamageStepTests` and `SummonTests` — clause 1 is a FLIP effect that Special Summons, and
##     it carries a Damage Step PERMISSION rather than the usual refusal;
##   * `ImmunityTests` — the replacement writes through `set_battle_position()`, which is
##     one of batch 16's gated mutation entry points;
##   * `ChampionsVigilanceTests` — the pool's other card that answers a Spell/Trap
##     activation, and the one most likely to be disturbed by a change to
##     `spell_trap_activation_below()`;
##   * `EnemyControllerTests` — the pool's other Tribute-cost card, and a battle-position
##     changer;
##   * `CrystalSeerTests` — the pool's other FLIP monster, and the MANDATORY contrast to
##     clause 1's optional one;
##   * `FairyTailLunaTests` and `FairyTailRellaTests` — the same archetype, and Luna's
##     search reads the 1850 ATK Spellcaster list that Sleeper is a member of.
##
## The FULL run stays the authority for every number.

func _initialize() -> void:
	var suites: Array[TestCase] = []
	suites.append(ChainTests.run())
	suites.append(TimingTests.run())
	suites.append(ReplayTests.run())
	suites.append(DamageStepTests.run())
	suites.append(SummonTests.run())
	suites.append(ImmunityTests.run())
	suites.append(ChampionsVigilanceTests.run())
	suites.append(EnemyControllerTests.run())
	suites.append(CrystalSeerTests.run())
	suites.append(FairyTailRellaTests.run())
	suites.append(FairyTailLunaTests.run())
	suites.append(FairyTailSleeperTests.run())

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

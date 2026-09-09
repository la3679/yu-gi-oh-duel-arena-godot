extends SceneTree

## Targeted runner for batch 14, so a card unit can be driven without the full 88-suite run.
## `Tools/run_tests.sh RunBatch14Tests`. The full suite is still the authority.
func _initialize() -> void:
	var suites := [WitchcrafterGolemAruruTests.run(), MaidenWithEyesOfBlueTests.run(),
		HonestTests.run(), MovementTests.run()]
	var failed := 0
	var total := 0
	for s in suites:
		print(s.report())
		failed += s.failed
		total += s.total()
	print("RESULT: PASS" if failed == 0 and total > 0 else "RESULT: FAIL")
	quit(0 if failed == 0 else 1)

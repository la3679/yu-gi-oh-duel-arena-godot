extends SceneTree
func _initialize() -> void:
	var suites := [SpiritualFireArtKurenaiTests.run(), HiddenInfoTests.run(), SpiritualWaterArtAoiTests.run(), DamageStepTests.run(), DamageCondenserTests.run()]
	var failed := 0
	var total := 0
	for s in suites:
		print(s.report())
		failed += s.failed
		total += s.total()
	print("RESULT: PASS" if failed == 0 and total > 0 else "RESULT: FAIL")
	quit(0 if failed == 0 else 1)

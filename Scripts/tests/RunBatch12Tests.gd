extends SceneTree
func _initialize() -> void:
	var result := SpiritualFireArtKurenaiTests.run()
	print(result.report())
	print("RESULT: PASS" if result.failed == 0 and result.total() > 0 else "RESULT: FAIL")
	quit(0 if result.failed == 0 else 1)

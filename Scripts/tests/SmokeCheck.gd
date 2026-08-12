extends SceneTree

## Minimal load/parse check. Run with:
##   godot --headless --path <project> --script res://Scripts/tests/SmokeCheck.gd
##
## Verifies that the engine classes parse, that the generated card data loads, and
## that the deterministic RNG is actually deterministic.

func _initialize() -> void:
	var failures: Array[String] = []

	# --- RNG determinism ---
	var a := Rng.new(12345)
	var b := Rng.new(12345)
	var xs := []
	var ys := []
	for i in range(20):
		xs.append(a.next_int(100))
		ys.append(b.next_int(100))
	if xs != ys:
		failures.append("Rng not deterministic for identical seeds")

	var c := Rng.new(999)
	var zs := []
	for i in range(20):
		zs.append(c.next_int(100))
	if xs == zs:
		failures.append("Rng produced identical output for different seeds")

	var deck := range(40).map(func(i): return i)
	var s1 := Rng.new(7).shuffled(deck)
	var s2 := Rng.new(7).shuffled(deck)
	if s1 != s2:
		failures.append("Rng.shuffle not deterministic")
	if s1 == deck:
		failures.append("Rng.shuffle did not reorder a 40-card deck")
	if s1.size() != 40:
		failures.append("Rng.shuffle changed array size")

	# --- Card data loads ---
	var cards = _load_json("res://Data/cards/cards.json")
	if cards == null:
		failures.append("could not load Data/cards/cards.json")
	else:
		var list: Array = cards.get("cards", [])
		if list.size() != 77:
			failures.append("expected 77 card definitions, got %d" % list.size())
		var monsters := 0
		var spells := 0
		var traps := 0
		for d in list:
			var def := CardDef.from_dict(d)
			if def.name == "":
				failures.append("card definition with empty name")
			if def.text == "":
				failures.append("card '%s' has empty official text" % def.name)
			if def.is_monster():
				monsters += 1
				if def.race == "" or def.attribute == "":
					failures.append("monster '%s' missing race/attribute" % def.name)
			elif def.is_spell():
				spells += 1
				if def.st_kind == Enums.STKind.NONE:
					failures.append("spell '%s' has unknown subtype" % def.name)
			elif def.is_trap():
				traps += 1
				if def.st_kind == Enums.STKind.NONE:
					failures.append("trap '%s' has unknown subtype" % def.name)
		print("  card definitions: %d monsters / %d spells / %d traps" % [monsters, spells, traps])

	# --- Deck lists load and are exactly 40 ---
	for path in ["res://Data/decks/deck1.json", "res://Data/decks/deck2.json"]:
		var d = _load_json(path)
		if d == null:
			failures.append("could not load %s" % path)
			continue
		var total := 0
		for e in d.get("main_deck", []):
			total += int(e.get("quantity", 0))
		if total != 40:
			failures.append("%s has %d Main Deck cards, expected 40" % [path, total])
		print("  %s -> '%s' %d cards" % [path.get_file(), d.get("deck_name", "?"), total])

	# --- Enum classification sanity (RULES_SPEC.md 4.2 / 8) ---
	if Enums.spell_speed_for_st(Enums.STKind.COUNTER_TRAP) != 3:
		failures.append("Counter Trap must be Spell Speed 3")
	if Enums.spell_speed_for_st(Enums.STKind.QUICK_PLAY_SPELL) != 2:
		failures.append("Quick-Play Spell must be Spell Speed 2")
	if Enums.spell_speed_for_st(Enums.STKind.NORMAL_SPELL) != 1:
		failures.append("Normal Spell must be Spell Speed 1")
	if Enums.spell_speed_for_effect(Enums.EffectType.QUICK) != 2:
		failures.append("Quick Effect must be Spell Speed 2")
	if Enums.spell_speed_for_effect(Enums.EffectType.IGNITION) != 1:
		failures.append("Ignition Effect must be Spell Speed 1")
	if Enums.is_destruction(Enums.MoveReason.TRIBUTED):
		failures.append("Tribute must not count as destruction [S1 p.53]")
	if Enums.is_destruction(Enums.MoveReason.RETURNED_TO_HAND):
		failures.append("Return to hand must not count as destruction [S1 p.52]")
	if not Enums.is_sent_to_gy(Enums.MoveReason.DISCARDED):
		failures.append("Discard must count as sent to the GY [S1 p.53]")
	if not Enums.is_sent_to_gy(Enums.MoveReason.TRIBUTED):
		failures.append("Tribute must count as sent to the GY [S1 p.53]")
	if Enums.is_sent_to_gy(Enums.MoveReason.BANISHED):
		failures.append("Banish must not count as sent to the GY [S1 p.53]")

	# --- CardInstance stat handling ---
	var def2 := CardDef.new()
	def2.name = "Test Dragon"
	def2.base_atk = 1800
	def2.base_def = 1000
	def2.category = Enums.Category.MONSTER
	var inst := CardInstance.new(def2, 0)
	inst.add_atk_modifier(99, 700, "end_of_turn")
	if inst.current_atk() != 2500:
		failures.append("ATK modifier not applied (got %d)" % inst.current_atk())
	if inst.original_atk() != 1800:
		failures.append("original ATK must stay printed value")
	if def2.base_atk != 1800:
		failures.append("modifier leaked into CardDef")
	inst.reset_turn_state()
	if inst.current_atk() != 1800:
		failures.append("end_of_turn modifier not cleared")

	if failures.is_empty():
		print("\nSMOKE CHECK: PASS")
		quit(0)
	else:
		print("\nSMOKE CHECK: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - " + f)
		quit(1)


func _load_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	return parsed

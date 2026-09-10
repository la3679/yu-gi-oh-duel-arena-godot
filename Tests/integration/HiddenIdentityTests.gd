class_name HiddenIdentityTests
extends RefCounted

## Phase 7 unit B, step B0 — the hidden-card identity gate (unit A finding 3; ADR-0002 in
## docs/ARCHITECTURE.md).
##
## The finding: `get_visible_state()` stubs carried the card's instance `id`, ids are assigned in
## pre-shuffle Deck-list order, and the Deck lists are public — so the id of a face-down card or of
## a card in the opponent's hand named it. These tests were written to FAIL against that, before
## the fix:
##
##   * the Deck-list-order attack, run at every message of the six scripted real-deck duels on both
##     channels, identifies no more hidden cards than the best blind guess — while the same attack
##     on the ENGINE's own view still identifies nearly all of them (the control: the attack is
##     real, and the session's projection is what closes it);
##   * what a channel shows does not depend on the order hidden cards were registered in.

const PERMUTE_SEED := 8901


static func run() -> TestCase:
	var t := TestCase.new("HiddenIdentityTests")
	_test_the_deck_list_attack_does_no_better_than_a_blind_guess(t)
	_test_identifiers_do_not_depend_on_registration_order(t)
	return t


static func _test_the_deck_list_attack_does_no_better_than_a_blind_guess(t: TestCase) -> void:
	t.start("the Deck-list-order attack, at every message of the six scripted duels on both "
		+ "channels, identifies no more hidden cards than the best blind guess")
	var totals := {}
	var raw := {"observations": 0, "hits": 0}
	for cfg in ScriptedDuelTests.DUELS:
		var tr := SessionTranscript.play(cfg)
		var label := str(cfg["label"])
		t.eq(tr.outcome, "ended", "%s: the duel ended through the session" % label)
		t.eq(tr.problems, [], "%s: every message was paired with its truth" % label)
		t.is_true(int(tr.recorded[0]) > 0 and int(tr.recorded[1]) > 0,
			"%s: non-vacuity: both channels were recorded (%s)" % [label, str(tr.recorded)])
		for cat in tr.tally.keys():
			var into: Dictionary = totals.get(cat, {"observations": 0, "hits": 0, "baseline": 0})
			for k in ["observations", "hits", "baseline"]:
				into[k] = int(into[k]) + int(tr.tally[cat][k])
			totals[cat] = into
		raw["observations"] = int(raw["observations"]) + int(tr.raw_tally["observations"])
		raw["hits"] = int(raw["hits"]) + int(tr.raw_tally["hits"])
	var obs := 0
	var hits := 0
	var base := 0
	for cat in totals.keys():
		var c: Dictionary = totals[cat]
		print("  [hidden] %s: %d identifiers, attack %d, blind guess %d" % [cat,
			int(c["observations"]), int(c["hits"]), int(c["baseline"])])
		obs += int(c["observations"])
		hits += int(c["hits"])
		base += int(c["baseline"])
	print("  [hidden] control on the engine's raw view: %d of %d hidden hand cards identified"
		% [int(raw["hits"]), int(raw["observations"])])
	t.is_true(int(totals.get(SessionTranscript.STUB, {}).get("observations", 0)) > 0,
		"non-vacuity: hidden hand cards were shown")
	t.is_true(int(totals.get(SessionTranscript.FACE_DOWN, {}).get("observations", 0)) > 0,
		"non-vacuity: face-down cards were shown")
	t.is_true(int(raw["observations"]) > 0 and int(raw["hits"]) * 10 >= int(raw["observations"]) * 9,
		"control: the same attack on the engine's own view identifies %d of %d hidden hand cards"
		% [int(raw["hits"]), int(raw["observations"])])
	t.is_true(hits <= base,
		"the attack identifies %d of %d hidden-card identifiers; the blind guess %d" % [hits, obs,
		base])


## Player 1 holds two hidden hand cards, a Set Trap and a face-down monster. The two boards differ
## ONLY in the order those four cards were registered, so every hidden card has a different
## instance id. Returns player 0's first prompt, as JSON, and what it shows.
static func _registration_board(permuted: bool) -> Dictionary:
	var d := TestFixtures.new_duel(PERMUTE_SEED, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var x := TestFixtures.monster("Hidden Probe X", 4, 1800, 1000)
	var y := TestFixtures.monster("Hidden Probe Y", 3, 1200, 900)
	var z := TestFixtures.trap("Hidden Probe Z")
	var w := TestFixtures.monster("Hidden Probe W", 4, 1000, 1000)
	var ids := {}
	var order := ["w", "z", "y", "x"] if permuted else ["x", "y", "z", "w"]
	for k in order:
		match k:
			"x":
				ids["x"] = TestFixtures.give_to_hand(engine, 1, x).id
			"y":
				ids["y"] = TestFixtures.give_to_hand(engine, 1, y).id
			"z":
				ids["z"] = TestFixtures.give_set_spell_trap(engine, 1, z).id
			"w":
				ids["w"] = TestFixtures.give_monster_on_field(engine, 1, w,
					Enums.Position.FACE_DOWN_DEFENSE).id
	var session := EngineSession.new()
	session.start_attached(engine)
	var h := EngineSessionTests.Harness.new(session)
	var m := h.next_for(0, "prompt")
	var out := {"json": JSON.stringify(m), "ids": ids, "hidden": 0}
	if not m.is_empty():
		var p1: Dictionary = (m["view"]["players"] as Array)[1]
		for key in ["hand", "monster_zones", "spell_trap_zones"]:
			for e in p1[key]:
				if e != null and bool((e as Dictionary).get("hidden", false)):
					out["hidden"] = int(out["hidden"]) + 1
	session.stop()
	return out


static func _test_identifiers_do_not_depend_on_registration_order(t: TestCase) -> void:
	t.start("player 0's channel is byte-identical whatever order the opponent's hidden cards were "
		+ "registered in — an identifier shown for a hidden card is not derived from it")
	var a := _registration_board(false)
	var b := _registration_board(true)
	t.eq(int(a["hidden"]), 9, "non-vacuity: player 1's five drawn cards, the two probe hand "
		+ "cards, the Set Trap and the face-down monster are shown to player 0 as hidden")
	var differ := 0
	for k in ["x", "y", "z", "w"]:
		if int(a["ids"][k]) != int(b["ids"][k]):
			differ += 1
	t.eq(differ, 4, "control: every one of the four hidden cards has a different instance id in "
		+ "the two boards")
	t.eq(a["json"], b["json"], "player 0's first prompt — view, log and offers — is identical")

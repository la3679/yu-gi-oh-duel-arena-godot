class_name BackendAcceptanceTests
extends RefCounted

## The backend acceptance gate. The post-card phase, unit 3 (PROJECT_STATE.md §8).
##
## What this suite proves in-process; the rest of the gate (full regression, SmokeCheck, the
## SCRIPT ERROR scan, the ObjectDB exit count and CROSS-PROCESS determinism) is proved by the
## runners and recorded in `Reports/TEST_RESULTS.md`:
##
##   * all 77 unique cards resolve through IMPLEMENTED paths — the registry validates, and no
##     clause that starts a Chain lacks a `resolve`, no continuous clause answers nothing;
##   * no TODO / FIXME / NotImplemented marker in the engine, rules or card code, and none of
##     the things that would stop a backend running it headless and deterministically: the
##     scene tree, `await`, the clock, unseeded randomness;
##   * a WIDER battery of unarranged real-deck duels than `ScriptedDuelTests`, each of which
##     must end legitimately, raise no error, never have an offered action refused, keep every
##     invariant, leak nothing hidden, and replay exactly;
##   * the replay payload survives a JSON round trip, which is how a backend stores it;
##   * hidden information at the API boundary in the one case §8 names: a player must not be
##     able to tell "my opponent was asked and declined" from "my opponent had nothing to be
##     asked about".

const BATTERY_SIZE := 18
const BATTERY_STYLES := [
	[DuelDriver.STYLE_BEATDOWN, DuelDriver.STYLE_BEATDOWN],
	[DuelDriver.STYLE_CONTROL, DuelDriver.STYLE_BEATDOWN],
	[DuelDriver.STYLE_BEATDOWN, DuelDriver.STYLE_CONTROL],
	[DuelDriver.STYLE_CONTROL, DuelDriver.STYLE_CONTROL],
	[DuelDriver.STYLE_BEATDOWN, DuelDriver.STYLE_PASSIVE],
	[DuelDriver.STYLE_PASSIVE, DuelDriver.STYLE_CONTROL],
]

## Directories whose code the playable pool runs through.
const CODE_DIRS := ["res://Scripts/engine", "res://Scripts/rules", "res://Scripts/cards",
	"res://Scripts/cards/registry"]

## A stub marker anywhere, comment or code.
const STUB_PATTERN := "\\b(TODO|FIXME)\\b|NotImplemented|NOT_IMPLEMENTED"
## Things a headless, deterministic backend cannot have in the rules. `Rng` wraps a SEEDED
## RandomNumberGenerator; the global unseeded helpers are what this forbids.
const HAZARD_PATTERN := "get_tree\\(|^extends Node|\\bawait\\b|\\bTime\\.|OS\\.get_ticks|OS\\.get_unix_time|(^|[^\\w.])(randi|randf|randi_range|randf_range|randomize)\\("


static func run() -> TestCase:
	var t := TestCase.new("BackendAcceptanceTests")
	_test_every_card_resolves_through_an_implemented_path(t)
	_test_no_stub_marker_and_no_headless_hazard_in_the_code(t)
	_test_a_wider_battery_of_unarranged_real_duels(t)
	_test_the_replay_payload_survives_a_json_round_trip(t)
	_test_being_asked_nothing_is_indistinguishable_at_the_api_boundary(t)
	return t


# ---------------------------------------------------------------------------
# The card library
# ---------------------------------------------------------------------------

static func _test_every_card_resolves_through_an_implemented_path(t: TestCase) -> void:
	t.start("all 77 unique cards resolve through implemented paths: the registry validates, "
		+ "and every clause has the callable its kind needs")
	var lib := TestFixtures.real_library()
	var defs: Dictionary = lib["cards"]
	t.eq(lib["errors"], [], "the card registry loads with no validation error")
	t.eq(defs.size(), 77, "the library is the 77-card V1 pool")
	t.eq(CardRegistry.unimplemented(defs), [], "no card that needs effects lacks them")
	var clauses := 0
	var effect_cards := 0
	var bad: Array = []
	for card_name in defs.keys():
		var def: CardDef = defs[card_name]
		if def.is_vanilla():
			if not def.effects.is_empty():
				bad.append("%s is vanilla but registers effects" % card_name)
			continue
		effect_cards += 1
		for entry in def.effects:
			var e: EffectDef = entry
			clauses += 1
			if e.starts_chain and not e.resolve.is_valid():
				bad.append("%s '%s' starts a Chain with no resolve()" % [card_name, e.effect_id])
			if e.is_continuous() and not (e.apply_continuous.is_valid() \
					or e.respond_to_event.is_valid() or e.condition.is_valid() \
					or e.destruction_substitute.is_valid()):
				bad.append("%s '%s' is continuous and answers nothing" % [card_name, e.effect_id])
	t.eq(bad, [], "every clause is implemented for what it is")
	t.is_true(effect_cards > 0 and clauses >= effect_cards,
		"non-vacuity: %d effect cards, %d clauses inspected" % [effect_cards, clauses])
	var slots := 0
	for index in [0, 1]:
		var deck := TestFixtures.real_deck(index)
		t.eq(deck["errors"], [], "deck %d names only cards the library knows" % (index + 1))
		slots += (deck["cards"] as Array).size()
	t.eq(slots, 80, "and the two decks fill all 80 slots from it")


static func _code_files() -> Array:
	var out: Array = []
	for dir_path in CODE_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".gd"):
				out.append("%s/%s" % [dir_path, f])
	return out


static func _test_no_stub_marker_and_no_headless_hazard_in_the_code(t: TestCase) -> void:
	t.start("no TODO / FIXME / NotImplemented marker in the engine, rules or card code, and "
		+ "nothing a headless deterministic backend cannot run: scene tree, await, clock, "
		+ "unseeded randomness")
	var stub := RegEx.create_from_string(STUB_PATTERN)
	var hazard := RegEx.create_from_string(HAZARD_PATTERN)
	var files := _code_files()
	var stubs: Array = []
	var hazards: Array = []
	var lines_read := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		var n := 0
		for line in text.split("\n"):
			n += 1
			lines_read += 1
			if stub.search(line) != null:
				stubs.append("%s:%d %s" % [path, n, line.strip_edges()])
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			if hazard.search(code) != null:
				hazards.append("%s:%d %s" % [path, n, code])
	t.is_true(files.size() >= 80, "non-vacuity: %d code files scanned (%d lines)"
		% [files.size(), lines_read])
	t.eq(stubs, [], "no stub marker anywhere in the code the playable pool runs through")
	t.eq(hazards, [], "no scene-tree, await, clock or unseeded-randomness dependency")
	# The two patterns really do match what they claim to, so a clean scan is not a broken regex.
	t.not_null(stub.search("# TODO: later"), "control: the stub pattern matches a TODO")
	t.not_null(hazard.search("var x := randi() % 6"), "control: the hazard pattern matches randi()")
	t.is_null(hazard.search("var x := _rng.randi_range(0, 5)"),
		"control: and not the SEEDED generator's method")


# ---------------------------------------------------------------------------
# The battery
# ---------------------------------------------------------------------------

static func _test_a_wider_battery_of_unarranged_real_duels(t: TestCase) -> void:
	t.start("a battery of %d unarranged duels between the two real decks: every one ends "
		% BATTERY_SIZE + "legitimately, cleanly, and replays exactly")
	var problems: Array = []
	var activated := {}
	var played := {}
	var ends := {}
	var hidden_checks := 0
	var total_turns := 0
	var total_steps := 0
	for i in range(BATTERY_SIZE):
		var drv := DuelDriver.new()
		drv.seed_value = 9000 + i * 37
		drv.first_player = i % 2
		drv.styles = (BATTERY_STYLES[i % BATTERY_STYLES.size()] as Array).duplicate()
		drv.play()
		var label := "seed %d %s" % [drv.seed_value, "/".join(PackedStringArray(drv.styles))]
		t.eq(drv.outcome, "ended", "%s ended — %s" % [label, drv.summary()])
		for pair in [["errors", drv.errors], ["rejected", drv.rejected],
				["invariants", drv.invariant_failures], ["hidden", drv.hidden_failures],
				["log leaks", drv.log_leaks], ["once-per-turn", drv.opt_violations]]:
			if not (pair[1] as Array).is_empty():
				problems.append("%s %s: %s" % [label, pair[0], str(pair[1])])
		for c in drv.controllers:
			if not (c as ScriptedController).errors.is_empty():
				problems.append("%s controller %d: %s" % [label,
					(c as ScriptedController).player_id, str((c as ScriptedController).errors)])
		var r := DuelDriver.replay(drv.engine.log.to_replay())
		var diff := DuelDriver.first_difference(DuelDriver.event_lines(drv.engine),
			DuelDriver.event_lines(r["engine"]))
		t.is_true(diff == -1 and (r["errors"] as Array).is_empty()
			and DuelDriver.final_board(r["engine"]) == DuelDriver.final_board(drv.engine),
			"%s replays exactly (first difference %d, errors %s)" % [label, diff, str(r["errors"])])
		ends[Enums.EndReason.keys()[drv.engine.state.end_reason]] = \
			int(ends.get(Enums.EndReason.keys()[drv.engine.state.end_reason], 0)) + 1
		hidden_checks += drv.hidden_checks
		total_turns += drv.engine.state.turn_number
		total_steps += drv.steps
		for k in drv.activated_effects.keys():
			activated[str(k).split("::")[0]] = true
		for e in drv.engine.state.events:
			var ge: GameEvent = e
			if ge.kind in [GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED,
					GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, GameEvent.Kind.CARD_SET,
					GameEvent.Kind.EFFECT_ACTIVATED, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED]:
				played[str(ge.data.get("card_name", ""))] = true
	t.eq(problems, [], "no duel in the battery raised an error, had an offer refused, broke an "
		+ "invariant, leaked hidden information or exceeded a once-per-turn allowance")
	t.is_true(hidden_checks > 0, "non-vacuity: %d hidden view entries inspected" % hidden_checks)
	played.erase("")
	print("  [acceptance] %d duels, %d turns, %d actions; end reasons %s" % [BATTERY_SIZE,
		total_turns, total_steps, str(ends)])
	print("  [acceptance] %d distinct cards summoned, Set or activated; %d distinct cards "
		% [played.size(), activated.size()] + "activated an effect")
	t.is_true(played.size() > 0 and activated.size() > 0,
		"non-vacuity: %d cards were played and %d activated an effect"
		% [played.size(), activated.size()])


# ---------------------------------------------------------------------------
# The replay payload as a backend stores it
# ---------------------------------------------------------------------------

static func _test_the_replay_payload_survives_a_json_round_trip(t: TestCase) -> void:
	t.start("the replay payload survives being stored as JSON and read back: the duel it "
		+ "rebuilds is the same duel, event for event")
	var drv := ScriptedDuelTests.play(ScriptedDuelTests.DUELS[1])
	var text := drv.engine.log.to_json()
	var parsed = JSON.parse_string(text)
	t.check(parsed is Dictionary, "the stored payload parses")
	if not (parsed is Dictionary):
		return
	var r := DuelDriver.replay(DuelLog.payload_from_json(text))
	var a := DuelDriver.event_lines(drv.engine)
	var diff := DuelDriver.first_difference(a, DuelDriver.event_lines(r["engine"]))
	t.eq(r["errors"], [], "every recorded answer was accepted after the round trip")
	t.eq(int(r["applied"]), (parsed["actions"] as Array).size(),
		"every recorded action was accepted after the round trip")
	t.eq(diff, -1, "the rebuilt duel reproduces all %d events" % a.size())
	t.eq(DuelDriver.final_board(r["engine"]), DuelDriver.final_board(drv.engine),
		"and the same final board")
	# The control that makes `payload_from_json()` load-bearing rather than decorative: the
	# RAW parse, with every number a float, does not reproduce the duel.
	var raw := DuelDriver.replay(parsed)
	var raw_diff := DuelDriver.first_difference(a, DuelDriver.event_lines(raw["engine"]))
	t.is_true(raw_diff != -1 or not (raw["errors"] as Array).is_empty(),
		"control: replaying the RAW JSON parse diverges (first difference %d, %d error(s)) — "
		% [raw_diff, (raw["errors"] as Array).size()] + "the int restoration is needed")


# ---------------------------------------------------------------------------
# Hidden information at the API boundary — the batch-17 case
# ---------------------------------------------------------------------------

## Luna's bounce against a Mirage Dragon, with the opponent's 2-card Deck either holding a
## copy they decline to send, or holding none. Returns what PLAYER 0 can observe.
static func _luna_observation(opponent_holds_copy: bool) -> Dictionary:
	var target_def := FairyTailLunaTests._card(FairyTailLunaTests.DUPLICATE)
	var d := FairyTailLunaTests._bounce_board(8801, target_def)
	var engine: DuelEngine = d["engine"]
	TestFixtures.clear_deck(engine, 1)
	TestFixtures.give_to_deck(engine, 1, target_def if opponent_holds_copy \
		else TestFixtures.monster("Unrelated Card", 4, 1000, 1000))
	TestFixtures.give_to_deck(engine, 1, TestFixtures.monster("Deck Filler", 4, 1000, 1000))
	var p1: ScriptedController = d["p1"]
	p1.reset()
	var mark := engine.state.events.size()
	var activated := FairyTailLunaTests._activate_bounce(engine, d["luna"], d["target"])
	var seen: Array = []
	for e in engine.state.get_log_for(0):
		var ev: GameEvent = e
		if ev.sequence >= mark:
			seen.append("%s %s" % [GameEvent.kind_name(ev.kind), JSON.stringify(ev.data)])
	return {"activated": activated, "asked": p1.seen_requests.size(), "log": seen,
		"view": JSON.stringify(engine.get_visible_state(0)),
		"returned": (d["luna"] as CardInstance).zone == Enums.Zone.HAND}


static func _test_being_asked_nothing_is_indistinguishable_at_the_api_boundary(
		t: TestCase) -> void:
	t.start("hidden information at the API boundary: 'my opponent was asked and declined' "
		+ "looks exactly like 'my opponent had nothing to be asked about'")
	var declined := _luna_observation(true)
	var nothing := _luna_observation(false)
	t.is_true(bool(declined["activated"]) and bool(nothing["activated"]),
		"the effect was activated in both duels")
	t.is_true(int(declined["asked"]) > 0,
		"non-vacuity: with a copy in their Deck the opponent WAS asked (%d)" % int(declined["asked"]))
	t.eq(int(nothing["asked"]), 0, "non-vacuity: without one they were asked nothing")
	t.is_true(bool(declined["returned"]) and bool(nothing["returned"]),
		"and in both the return happened")
	t.eq(declined["log"], nothing["log"],
		"yet every event player 0 may read is identical, payload and all")
	t.eq(declined["view"], nothing["view"], "and so is player 0's whole view of the board")

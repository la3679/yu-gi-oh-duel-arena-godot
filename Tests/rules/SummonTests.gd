class_name SummonTests
extends RefCounted

## Normal Summon / Set / Tribute Summon / Flip Summon and manual position changes.
## Rules under test: RULES_SPEC.md 5 (Official Rulebook v10 p.24-25, p.28, p.36, S1).


static func run() -> TestCase:
	var t := TestCase.new("SummonTests")
	_test_one_normal_summon_or_set_per_turn(t)
	_test_summon_and_set_positions(t)
	_test_tribute_requirements_by_level(t)
	_test_tribute_is_not_destruction(t)
	_test_card_worth_two_tributes(t)
	_test_full_field_blocks_a_zero_tribute_summon(t)
	_test_flip_summon_rules(t)
	_test_manual_position_change_rules(t)
	return t


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


# --- RULES_SPEC.md 5.1 [S1 p.24] ---
static func _test_one_normal_summon_or_set_per_turn(t: TestCase) -> void:
	t.start("one Normal Summon OR Set per turn")
	var d := _main_phase_duel(201)
	var engine: DuelEngine = d["engine"]

	var a := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("First"))
	var b := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Second"))

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, b.id), "both monsters are summonable at first")

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, a.id))
	TestFixtures.pass_until_open(engine)

	var actions := engine.get_legal_actions(0)
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.NORMAL_SUMMON, b.id),
		"a second Normal Summon is not offered")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.NORMAL_SET, b.id),
		"a Set is not offered either — they share one allowance [S1 p.24]")


# --- RULES_SPEC.md 5.1 ---
static func _test_summon_and_set_positions(t: TestCase) -> void:
	t.start("Normal Summon is face-up Attack; Set is face-down Defense")
	var d := _main_phase_duel(202)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Upright"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))
	TestFixtures.pass_until_open(engine)
	t.eq(mon.position, Enums.Position.FACE_UP_ATTACK,
		"a Normal Summoned monster is in face-up Attack Position [S1 p.24]")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "and occupies a Monster Zone")
	t.eq(mon.turn_summoned, engine.state.turn_number, "the summon turn is recorded")

	var d2 := _main_phase_duel(203)
	var engine2: DuelEngine = d2["engine"]
	var mon2 := TestFixtures.give_to_hand(engine2, 0, TestFixtures.monster("Hidden"))
	engine2.submit_action(TestFixtures.find_action(
		engine2.get_legal_actions(0), Enums.ActionKind.NORMAL_SET, mon2.id))
	TestFixtures.pass_until_open(engine2)
	t.eq(mon2.position, Enums.Position.FACE_DOWN_DEFENSE,
		"a Set monster is in face-down Defense Position [S1 p.24]")
	t.eq(mon2.turn_set, engine2.state.turn_number, "the set turn is recorded")
	t.eq(TestFixtures.count_events(engine2, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED), 0,
		"a Normal Set is NOT a Summon [S1 p.24]")


# --- RULES_SPEC.md 5.2 [S1 p.24-25] ---
static func _test_tribute_requirements_by_level(t: TestCase) -> void:
	t.start("Tribute requirements by Level")
	var d := _main_phase_duel(204)
	var engine: DuelEngine = d["engine"]

	var lvl4 := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Four", 4))
	var lvl6 := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Six", 6))
	var lvl8 := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Eight", 8))

	t.eq(engine.summons.tributes_required(lvl4), 0, "Level 4 needs no Tribute")
	t.eq(engine.summons.tributes_required(lvl6), 1, "Level 5-6 needs 1 Tribute")
	t.eq(engine.summons.tributes_required(lvl8), 2, "Level 7+ needs 2 Tributes")

	var actions := engine.get_legal_actions(0)
	t.is_true(TestFixtures.has_action(actions, Enums.ActionKind.NORMAL_SUMMON, lvl4.id),
		"the Level 4 monster can be Normal Summoned with an empty field")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.TRIBUTE_SUMMON, lvl6.id),
		"the Level 6 monster cannot be summoned with no Tribute material")

	# One monster on the field is enough for the Level 6, not for the Level 8.
	TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Fodder"))
	actions = engine.get_legal_actions(0)
	var six = TestFixtures.find_action(actions, Enums.ActionKind.TRIBUTE_SUMMON, lvl6.id)
	t.not_null(six, "one Tribute available makes the Level 6 summonable")
	t.eq(six.tributes_required, 1, "the offered action states 1 Tribute is required")
	t.eq(six.tribute_candidates.size(), 1, "and names the one legal Tribute")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.TRIBUTE_SUMMON, lvl8.id),
		"the Level 8 monster still needs a second Tribute")


static func _test_tribute_is_not_destruction(t: TestCase) -> void:
	t.start("Tributing is not destruction")
	var d := _main_phase_duel(205)
	var engine: DuelEngine = d["engine"]
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder"))
	var big := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Big", 6, 2400))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, big.id)
	t.not_null(action, "the Tribute Summon is offered")
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [fodder.id]})),
		"the Tribute Summon is accepted with a legal Tribute")
	TestFixtures.pass_until_open(engine)

	t.eq(big.zone, Enums.Zone.MONSTER_ZONE, "the Level 6 monster was summoned")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the Tribute went to the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_TRIBUTED), 1,
		"a Tribute event was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), 0,
		"Tributing is NOT destruction [S1 p.52-53]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY), 1,
		"but a Tributed card IS 'sent to the Graveyard' [S1 p.53]")

	# An illegal Tribute selection must be refused outright.
	t.is_false(engine.submit_action(action.with_choices({"tribute_ids": []})),
		"a Tribute Summon with no Tributes is rejected")


# --- CARD_RULINGS.md: Kaiser Sea Horse counts as 2 Tributes for a LIGHT monster ---
static func _test_card_worth_two_tributes(t: TestCase) -> void:
	t.start("a card that counts as two Tributes")
	var d := _main_phase_duel(206)
	var engine: DuelEngine = d["engine"]

	var seahorse_def := TestFixtures.monster("Sea Horse-like", 4, 1700, 1650, "LIGHT")
	var worth_two := EffectDef.new(SummonRules.TRIBUTE_VALUE_EFFECT_ID,
		"This card can be treated as 2 Tributes for the Tribute Summon of a LIGHT monster.")
	worth_two.of_type(Enums.EffectType.CONTINUOUS)
	worth_two.condition = func(ctx: EffectContext) -> bool:
		var target = ctx.params.get("summoning_card", null)
		return target != null and target.definition != null \
			and target.definition.attribute == "LIGHT"
	TestFixtures.with_effect(seahorse_def, worth_two)
	var seahorse := TestFixtures.give_monster_on_field(engine, 0, seahorse_def)

	var light8 := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Big LIGHT", 8, 3000, 2500, "LIGHT"))
	var dark8 := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Big DARK", 8, 3000, 2500, "DARK"))

	t.eq(engine.summons.tribute_value(seahorse, light8), 2,
		"counts as 2 Tributes for a LIGHT Summon")
	t.eq(engine.summons.tribute_value(seahorse, dark8), 1,
		"counts as only 1 Tribute for a non-LIGHT Summon")

	var actions := engine.get_legal_actions(0)
	var light_action = TestFixtures.find_action(actions,
		Enums.ActionKind.TRIBUTE_SUMMON, light8.id)
	t.not_null(light_action, "the LIGHT Level 8 monster is summonable off one Tribute")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.TRIBUTE_SUMMON,
		dark8.id), "the DARK Level 8 monster is not")

	t.is_true(engine.submit_action(
		light_action.with_choices({"tribute_ids": [seahorse.id]})),
		"one Tribute satisfies a two-Tribute Summon of a LIGHT monster")
	TestFixtures.pass_until_open(engine)
	t.eq(light8.zone, Enums.Zone.MONSTER_ZONE, "the LIGHT monster reached the field")


static func _test_full_field_blocks_a_zero_tribute_summon(t: TestCase) -> void:
	t.start("a full Monster Zone blocks a Summon that Tributes nothing")
	var d := _main_phase_duel(207)
	var engine: DuelEngine = d["engine"]
	for i in range(PlayerState.MONSTER_ZONE_COUNT):
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Wall %d" % i))
	t.eq(engine.state.player(0).monster_count(), 5, "the field is full")

	var lvl4 := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Late", 4))
	var lvl6 := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Boss", 6))
	var actions := engine.get_legal_actions(0)
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.NORMAL_SUMMON, lvl4.id),
		"no free Monster Zone means no Normal Summon")
	t.is_true(TestFixtures.has_action(actions, Enums.ActionKind.TRIBUTE_SUMMON, lvl6.id),
		"a Tribute Summon is still legal because Tributing frees a zone")


# --- RULES_SPEC.md 5.4 [S1 p.24, p.28] ---
static func _test_flip_summon_rules(t: TestCase) -> void:
	t.start("Flip Summon legality and position")
	var d := _main_phase_duel(208)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Sleeper"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SET, mon.id))
	TestFixtures.pass_until_open(engine)

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, mon.id),
		"a monster cannot be Flip Summoned the turn it was Set [S1 p.28]")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "back on the owner's turn")

	var flip = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, mon.id)
	t.not_null(flip, "the Flip Summon is offered on a later turn")
	engine.submit_action(flip)
	TestFixtures.pass_until_open(engine)
	t.eq(mon.position, Enums.Position.FACE_UP_ATTACK,
		"a Flip Summon puts the monster in face-up Attack Position only [S1 p.24]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 1,
		"a Flip Summon event was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP), 1,
		"and the card was flipped face-up, which is what Flip effects watch for")


# --- RULES_SPEC.md 5.3 [S1 p.36] ---
static func _test_manual_position_change_rules(t: TestCase) -> void:
	t.start("manual battle position change restrictions")
	var d := _main_phase_duel(209)
	var engine: DuelEngine = d["engine"]

	var fresh := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Fresh"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, fresh.id))
	TestFixtures.pass_until_open(engine)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.CHANGE_POSITION, fresh.id),
		"a monster played onto the field this turn cannot change position [S1 p.36]")

	var veteran := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Veteran"))
	var change = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.CHANGE_POSITION, veteran.id)
	t.not_null(change, "a monster already on the field may change position")
	engine.submit_action(change)
	TestFixtures.pass_until_open(engine)
	t.eq(veteran.position, Enums.Position.FACE_UP_DEFENSE,
		"Attack Position flipped to Defense Position")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.CHANGE_POSITION, veteran.id),
		"battle position may only be changed once per turn [S1 p.36]")

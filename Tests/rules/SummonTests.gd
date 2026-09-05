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
	_test_flip_summon_is_a_declaration(t)
	_test_a_negated_flip_summon(t)
	_test_a_flip_summon_whose_monster_leaves_the_window(t)
	_test_flip_summon_accounting(t)
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

	# A face-down monster is a legal Tribute [S1 p.53] but applies no effects, so it is
	# worth 1. Found by KaiserSeaHorseTests; the rule belongs to this gate, so it is
	# asserted here too. The card is turned back face-up before the Summon below.
	engine.state.set_battle_position(seahorse, Enums.Position.FACE_DOWN_DEFENSE, true)
	engine.continuous.recompute()
	t.is_true(engine.summons.tribute_candidates(0).has(seahorse),
		"a face-down monster is still a legal Tribute")
	t.eq(engine.summons.tribute_value(seahorse, light8), 1,
		"but it applies no effects while face-down, so it is worth only 1 Tribute")
	engine.state.set_battle_position(seahorse, Enums.Position.FACE_UP_ATTACK, true)
	engine.continuous.recompute()
	t.eq(engine.summons.tribute_value(seahorse, light8), 2,
		"and it is worth 2 again once it is face-up")

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


# ---------------------------------------------------------------------------
# A Flip Summon is a SUMMON — declaration, window, completion or negation.
# RULES_SPEC.md 5.4 [S1 p.24]. Added in batch 6; before it, `flip_summon()` applied the
# flip immediately and no negation card could answer one.
# ---------------------------------------------------------------------------

## Set a monster on turn 1 and hand the turn back and forth so it is legally Flip
## Summonable. Returns {"engine", "p0", "p1", "monster"}.
static func _flip_ready_duel(seed_value: int, def: CardDef) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_to_hand(engine, 0, def)
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SET, mon.id))
	TestFixtures.pass_until_open(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["monster"] = mon
	return d


static func _test_flip_summon_is_a_declaration(t: TestCase) -> void:
	t.start("a Flip Summon DECLARES and waits for a response window, like the other two "
		+ "Summon routes [S1 p.24]")
	var d := _flip_ready_duel(210, TestFixtures.flip_effect_monster("Watcher"))
	var engine: DuelEngine = d["engine"]
	var mon: CardInstance = d["monster"]
	# Player 1 holds a real Spell Speed 3 response, so the window genuinely stays open
	# instead of the engine auto-passing and resolving everything in one submit_action().
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.summon_negator("Deny"), 0)
	var hand_before := engine.state.player(0).hand.size()

	var flip = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, mon.id)
	t.not_null(flip, "the Flip Summon is offered")
	t.is_true(engine.submit_action(flip), "and declared")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_DECLARED), 1,
		"a FLIP_SUMMON_DECLARED event was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 0,
		"and no success event yet — the Summon has not happened")
	t.eq(engine.state.pending_summon_card_id, mon.id,
		"the authoritative state records which monster \"would be Summoned\"")
	t.ne(engine.timing, DuelEngine.Timing.OPEN,
		"the game state is not open while the declaration window is up")

	# The transitional state is NOT `Zone.IN_TRANSIT`: a Flip Summon does not move the card.
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster stays in its Monster Zone")
	t.ne(mon.zone, Enums.Zone.IN_TRANSIT,
		"it does not leave the field — that would destroy its Equip Cards and clear its "
		+ "per-instance state, none of which a Flip Summon does")
	t.eq(mon.position, Enums.Position.FACE_DOWN_DEFENSE,
		"and is still FACE-DOWN: the flip IS the Summon, so it has not happened yet")
	t.eq(engine.state.player(0).hand.size(), hand_before,
		"so its FLIP effect has not triggered either")
	t.not_null(TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id),
		"and a Summon negation IS offered against it — the point of the whole split")

	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 1,
		"unanswered, it completes when the window closes")
	t.eq(mon.position, Enums.Position.FACE_UP_ATTACK, "face-up Attack Position [S1 p.24]")
	t.eq(engine.state.pending_summon_card_id, -1, "and the pending record is cleared")
	t.eq(engine.state.player(0).hand.size(), hand_before + 1,
		"the FLIP effect fired exactly once, on the successful flip")


static func _test_a_negated_flip_summon(t: TestCase) -> void:
	t.start("a negated Flip Summon: the monster stays face-down, no success event, no Flip "
		+ "effect, and the manual position change is still available")
	var d := _flip_ready_duel(211, TestFixtures.flip_effect_monster("Watcher"))
	var engine: DuelEngine = d["engine"]
	var mon: CardInstance = d["monster"]
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.summon_negator("Deny"), 0)
	var hand_before := engine.state.player(0).hand.size()

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, mon.id))
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(response, "the opponent may answer the declaration")
	t.is_true(engine.submit_action(response), "and negates the Summon")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 1,
		"SUMMON_NEGATED was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 0,
		"no successful-summon event, so no successful-summon trigger can be collected")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP, mon.id), 0,
		"the monster was never flipped face-up")
	t.eq(mon.position, Enums.Position.FACE_DOWN_DEFENSE,
		"it is still face-down: the position change WAS the Summon [S1 p.24]")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE,
		"and still on the field — a negated Summon does not by itself destroy the monster")
	t.eq(engine.state.player(0).hand.size(), hand_before,
		"its FLIP effect never triggered, because it was never flipped")
	t.ne(mon.summoned_by, Enums.SummonKind.FLIP, "it was not recorded as Flip Summoned")
	t.eq(engine.state.pending_summon_card_id, -1, "the pending record is cleared")
	t.is_false(mon.position_changed_this_turn,
		"and no position change was spent on the attempt")


static func _test_a_flip_summon_whose_monster_leaves_the_window(t: TestCase) -> void:
	t.start("if the monster leaves the field while the Flip Summon is pending, the Summon "
		+ "simply does not happen")
	var d := _flip_ready_duel(212, TestFixtures.flip_effect_monster("Watcher"))
	var engine: DuelEngine = d["engine"]
	var mon: CardInstance = d["monster"]
	# A Spell Speed 2 Trap that destroys the pending monster during the window.
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Snipe", mon, "destroy"), 0)
	var hand_before := engine.state.player(0).hand.size()

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, mon.id))
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(response, "the opponent may respond to the declaration")
	t.is_true(engine.submit_action(response), "and destroys the face-down monster")
	TestFixtures.pass_until_open(engine)

	t.eq(mon.zone, Enums.Zone.GRAVEYARD, "the monster is in the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 0,
		"the Flip Summon did not succeed — completion re-checks the monster")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 0,
		"and it was not NEGATED either: nobody negated anything")
	t.eq(engine.state.player(0).hand.size(), hand_before,
		"no FLIP effect, because the monster was never flipped face-up")
	t.eq(engine.state.pending_summon_card_id, -1, "the pending record is cleared either way")


static func _test_flip_summon_accounting(t: TestCase) -> void:
	t.start("a Flip Summon spends no Normal Summon and no manual position change, and a "
		+ "monster Flip Summoned this turn cannot then change position [S1 p.24, p.36]")
	var d := _flip_ready_duel(213, TestFixtures.monster("Sleeper"))
	var engine: DuelEngine = d["engine"]
	var mon: CardInstance = d["monster"]

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, mon.id))
	TestFixtures.pass_until_open(engine)
	t.eq(mon.position, Enums.Position.FACE_UP_ATTACK, "the Flip Summon succeeded")
	t.eq(mon.summoned_by, Enums.SummonKind.FLIP, "recorded as a Flip Summon")
	t.eq(mon.summoned_by_procedure_id, "",
		"a Flip Summon uses no summoning procedure, so \"Summoned this way\" is empty")
	t.is_false(mon.position_changed_this_turn,
		"a Flip Summon is not a manual position change, so that allowance is untouched")
	t.eq(mon.turn_summoned, engine.state.turn_number,
		"but the monster WAS played into its current position this turn")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.CHANGE_POSITION, mon.id),
		"so it may not also change position this turn [S1 p.36]")

	# The Normal Summon allowance is a separate resource and a Flip Summon does not touch it.
	var other := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Fresh"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, other.id),
		"a Normal Summon is still available: a Flip Summon is not one [S1 p.24]")


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

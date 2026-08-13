class_name SpecialSummonInteractionTests
extends RefCounted

## Cross-card interaction tests for the Phase 5 revival/Special Summon batch.
##
## This file deliberately declares no card-under-test marker. `Tools/build_matrix.py`
## must not count a card as tested because it appeared in an interaction, only because it
## has its own suite. These tests are about what happens when the cards meet each other.

static func run() -> TestCase:
	var t := TestCase.new("SpecialSummonInteractionTests")
	_test_kaibaman_then_silvers_cry_recovers_the_same_dragon(t)
	_test_two_revivals_in_one_chain_resolve_in_reverse(t)
	_test_the_last_zone_is_taken_by_the_link_that_resolves_first(t)
	_test_dragonic_tactics_can_tribute_revived_monsters(t)
	_test_none_of_these_spend_the_normal_summon(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _activate_card(engine: DuelEngine, pid: int, card: CardInstance,
		target_ids: Array = []) -> bool:
	var action = TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	if action == null:
		return false
	if target_ids.is_empty():
		return engine.submit_action(action)
	return engine.submit_action(action.with_choices({"target_ids": target_ids}))


# ---------------------------------------------------------------------------
# The deck's actual line
# ---------------------------------------------------------------------------

static func _test_kaibaman_then_silvers_cry_recovers_the_same_dragon(t: TestCase) -> void:
	t.start("Kaibaman fetches Blue-Eyes; once it dies, Silver's Cry brings it back")
	var d := _main_phase_duel(9701)
	var engine: DuelEngine = d["engine"]

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	var blue_eyes := TestFixtures.give_to_hand(engine, 0,
		_card("Blue-Eyes White Dragon"))
	var cry := TestFixtures.give_to_hand(engine, 0, _card("Silver's Cry"))

	var fetch = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, "tribute_self_summon_blue_eyes")
	t.not_null(fetch, "Kaibaman's effect is available")
	t.is_true(engine.submit_action(fetch), "and is activated")
	TestFixtures.pass_until_open(engine)
	t.eq(blue_eyes.zone, Enums.Zone.MONSTER_ZONE, "Blue-Eyes is on the field")

	# Silver's Cry needs it in the Graveyard, and Blue-Eyes is a Dragon Normal Monster.
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id),
		"Silver's Cry has no target while the Dragon is still on the field")

	engine.state.move_card(blue_eyes, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	TestFixtures.pass_until_open(engine)
	t.eq(blue_eyes.zone, Enums.Zone.GRAVEYARD, "the Dragon has been destroyed")

	t.is_true(_activate_card(engine, 0, cry, [blue_eyes.id]),
		"Silver's Cry can now target it")
	TestFixtures.pass_until_open(engine)

	t.eq(blue_eyes.zone, Enums.Zone.MONSTER_ZONE, "the very same copy is back")
	t.eq(blue_eyes.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.eq(blue_eyes.current_atk(), 3000, "at full printed ATK")
	t.is_true(engine.state.player(0).graveyard.has(kaibaman),
		"and Kaibaman, the Tributed cost, is still in the Graveyard")


# ---------------------------------------------------------------------------
# Two of them on one Chain
# ---------------------------------------------------------------------------

static func _test_two_revivals_in_one_chain_resolve_in_reverse(t: TestCase) -> void:
	t.start("Silver's Cry chained to Monster Reborn: Chain Link 2 resolves first, and "
		+ "both monsters arrive")
	var d := _main_phase_duel(9702)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var cry := TestFixtures.give_to_hand(engine, 0, _card("Silver's Cry"))
	var dinosaur := TestFixtures.give(engine, 0, _card("Sabersaurus"),
		Enums.Zone.GRAVEYARD)
	var dragon := TestFixtures.give(engine, 0, _card("Luster Dragon"),
		Enums.Zone.GRAVEYARD)

	t.is_true(_activate_card(engine, 0, reborn, [dinosaur.id]),
		"Monster Reborn is Chain Link 1, targeting the Dinosaur")
	t.eq(engine.waiting_player(), 0,
		"the opponent has no response, so the window comes back to the activating player")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id)
	t.not_null(response,
		"Silver's Cry is Spell Speed 2, so it may be chained to a Spell Speed 1 link")
	t.is_true(engine.submit_action(
		response.with_choices({"target_ids": [dragon.id]})),
		"it becomes Chain Link 2, targeting the Dragon")
	TestFixtures.pass_until_open(engine)

	t.eq(dragon.zone, Enums.Zone.MONSTER_ZONE, "the Dragon was Special Summoned")
	t.eq(dinosaur.zone, Enums.Zone.MONSTER_ZONE, "and so was the Dinosaur")
	t.eq(engine.state.player(0).monster_count(), 2, "both are on the field")

	var summons := TestFixtures.events_of(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED)
	t.eq(summons.size(), 2, "exactly two Special Summons succeeded")
	t.eq(int(summons[0].data.get("card_id", -1)), dragon.id,
		"Chain Link 2 resolved FIRST, so the Dragon arrived first [S1 p.46-47]")
	t.eq(int(summons[1].data.get("card_id", -1)), dinosaur.id,
		"and Chain Link 1 resolved second")


static func _test_the_last_zone_is_taken_by_the_link_that_resolves_first(t: TestCase) -> void:
	t.start("with one Monster Zone left, Chain Link 2 takes it and Chain Link 1 "
		+ "Summons nothing")
	var d := _main_phase_duel(9703)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var cry := TestFixtures.give_to_hand(engine, 0, _card("Silver's Cry"))
	var dinosaur := TestFixtures.give(engine, 0, _card("Sabersaurus"),
		Enums.Zone.GRAVEYARD)
	var dragon := TestFixtures.give(engine, 0, _card("Luster Dragon"),
		Enums.Zone.GRAVEYARD)
	while engine.state.player(0).monster_count() < 4:
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Bystander %d" % engine.state.player(0).monster_count(),
				4, 800, 800))
	t.eq(engine.state.player(0).monster_count(), 4, "exactly one Monster Zone is free")

	t.is_true(_activate_card(engine, 0, reborn, [dinosaur.id]),
		"Monster Reborn is legally activated as Chain Link 1 — a zone is free right now")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id)
	t.not_null(response, "and Silver's Cry may be chained to it")
	t.is_true(engine.submit_action(
		response.with_choices({"target_ids": [dragon.id]})), "as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(dragon.zone, Enums.Zone.MONSTER_ZONE,
		"Chain Link 2 resolved first and took the last zone")
	t.eq(dinosaur.zone, Enums.Zone.GRAVEYARD,
		"Chain Link 1 re-checked the board at RESOLUTION and Summoned nothing")
	t.eq(engine.state.player(0).monster_count(), 5, "the field is now full")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon succeeded")
	t.eq(reborn.zone, Enums.Zone.GRAVEYARD,
		"Monster Reborn still resolved and still went to the Graveyard")


# ---------------------------------------------------------------------------
# Feeding one card's output into another's cost
# ---------------------------------------------------------------------------

static func _test_dragonic_tactics_can_tribute_revived_monsters(t: TestCase) -> void:
	t.start("a monster revived this turn is an ordinary monster and may be Tributed "
		+ "as a cost")
	var d := _main_phase_duel(9704)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var tactics := TestFixtures.give_to_hand(engine, 0, _card("Dragonic Tactics"))
	var revived := TestFixtures.give(engine, 0, _card("Luster Dragon"),
		Enums.Zone.GRAVEYARD)
	var partner := TestFixtures.give_monster_on_field(engine, 0,
		_card("Alexandrite Dragon"))
	var prize := TestFixtures.give(engine, 0, _card("Blue-Eyes White Dragon"),
		Enums.Zone.DECK)

	t.is_true(_activate_card(engine, 0, reborn, [revived.id]), "Monster Reborn revives")
	TestFixtures.pass_until_open(engine)
	t.eq(revived.zone, Enums.Zone.MONSTER_ZONE, "the Dragon is on the field")
	t.eq(revived.turn_summoned, engine.state.turn_number, "Summoned this very turn")

	t.is_true(_activate_card(engine, 0, tactics),
		"Dragonic Tactics can pay its cost with the two Dragons now on the field")
	t.eq(revived.zone, Enums.Zone.GRAVEYARD,
		"the revived Dragon was Tributed — nothing about being Special Summoned this "
		+ "turn prevents it")
	t.eq(partner.zone, Enums.Zone.GRAVEYARD, "and so was the other Dragon")
	TestFixtures.pass_until_open(engine)

	t.eq(prize.zone, Enums.Zone.MONSTER_ZONE, "Blue-Eyes came out of the Deck")
	t.eq(engine.state.player(0).monster_count(), 1, "and is the only monster left")


static func _test_none_of_these_spend_the_normal_summon(t: TestCase) -> void:
	t.start("no Special Summon in this batch spends the one Normal Summon per turn "
		+ "[S1 p.24]")
	var d := _main_phase_duel(9705)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var one := TestFixtures.give_to_hand(engine, 0, _card("One for One"))
	var sleeper := TestFixtures.give(engine, 0, _card("Sabersaurus"),
		Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine, 0, _card("Flamvell Guard"), Enums.Zone.DECK)
	var summonable := TestFixtures.give_to_hand(engine, 0, _card("Zure, Knight of Dark World"))

	t.is_true(_activate_card(engine, 0, reborn, [sleeper.id]), "Monster Reborn resolves")
	TestFixtures.pass_until_open(engine)
	t.is_true(engine.state.player(0).can_normal_summon(),
		"the Normal Summon is still available after a revival")

	t.is_true(_activate_card(engine, 0, one), "One for One resolves")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(0).monster_count(), 2, "two monsters were Special Summoned")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"and the Normal Summon is STILL available")

	var summon = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, summonable.id)
	t.not_null(summon, "so a Normal Summon is still offered")
	t.is_true(engine.submit_action(summon), "and succeeds")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(0).monster_count(), 3, "three monsters are now on the field")
	t.is_false(engine.state.player(0).can_normal_summon(),
		"and only now is the Normal Summon spent")

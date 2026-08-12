class_name TurnFlowTests
extends RefCounted

## Duel setup, turn structure and phase progression.
## Rules under test: RULES_SPEC.md 1, 2 and 13 (Official Rulebook v10 p.32-40, S1).


static func run() -> TestCase:
	var t := TestCase.new("TurnFlowTests")
	_test_duel_setup(t)
	_test_first_player_does_not_draw_on_turn_one(t)
	_test_first_turn_battle_phase_is_forbidden(t)
	_test_phase_order_without_battle_phase(t)
	_test_phase_order_with_battle_phase(t)
	_test_turn_transition_resets_the_summon_allowance(t)
	_test_hand_size_limit(t)
	_test_deck_out_loses_the_duel(t)
	return t


# --- RULES_SPEC.md 1 [S1 p.32-33] ---
static func _test_duel_setup(t: TestCase) -> void:
	t.start("duel setup")
	var d := TestFixtures.new_duel(101, 0)
	var engine: DuelEngine = d["engine"]
	var s := engine.state

	t.eq(s.player(0).life_points, 8000, "starting LP is 8000 [S1 p.32]")
	t.eq(s.player(1).life_points, 8000, "both players start at 8000")
	t.eq(s.player(0).hand.size(), 5, "opening hand is 5 cards [S1 p.33]")
	t.eq(s.player(1).hand.size(), 5, "both players draw 5")
	t.eq(s.player(0).deck.size(), TestFixtures.DECK_SIZE - 5,
		"the opening hand came out of the Deck")
	t.eq(s.turn_number, 1, "the Duel begins on turn 1")
	t.eq(s.turn_player_id, 0, "the designated first player takes the first turn")
	t.eq(engine.timing, DuelEngine.Timing.OPEN,
		"the engine settles into an open game state")
	t.eq(s.phase, Enums.Phase.DRAW, "the turn begins in the Draw Phase [S1 p.34]")


# --- RULES_SPEC.md 2.1 [S1 p.35] ---
static func _test_first_player_does_not_draw_on_turn_one(t: TestCase) -> void:
	t.start("first player does not draw on their first turn")
	var d := TestFixtures.new_duel(102, 0)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.player(0).hand.size(), 5,
		"the first player still holds exactly the opening 5 [S1 p.35]")

	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_number, 2, "the turn passed")
	t.eq(engine.state.turn_player_id, 1, "to the second player")
	t.eq(engine.state.player(1).hand.size(), 6,
		"the second player DOES draw on their first turn")

	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 0, "back to the first player")
	t.eq(engine.state.player(0).hand.size(), 6,
		"the first player draws normally from their second turn onward")


# --- RULES_SPEC.md 2.4 [S1 p.37] ---
static func _test_first_turn_battle_phase_is_forbidden(t: TestCase) -> void:
	t.start("the player going first cannot conduct a Battle Phase on turn 1")
	var d := TestFixtures.new_duel(103, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ENTER_BATTLE_PHASE),
		"no Battle Phase is offered on the first player's first turn [S1 p.37]")
	t.is_false(engine.flow.can_enter_battle_phase(0),
		"the rule holds when asked directly")

	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.ENTER_BATTLE_PHASE),
		"the second player may conduct a Battle Phase on their first turn")


# --- RULES_SPEC.md 2 [S1 p.34, p.40] ---
static func _test_phase_order_without_battle_phase(t: TestCase) -> void:
	t.start("phase order when no Battle Phase is conducted")
	var d := TestFixtures.new_duel(104, 0)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	var expected := [Enums.Phase.STANDBY, Enums.Phase.MAIN_1, Enums.Phase.END]
	for i in range(3):
		var a = TestFixtures.find_action(
			engine.get_legal_actions(engine.state.turn_player_id),
			Enums.ActionKind.END_PHASE)
		engine.submit_action(a)
		TestFixtures.pass_until_open(engine)
		seen.append(engine.state.phase)
	t.eq(seen, expected,
		"Draw -> Standby -> Main 1 -> End when the Battle Phase is skipped [S1 p.34]")
	t.is_false(engine.state.battle_phase_conducted_this_turn,
		"Main Phase 2 only exists after a Battle Phase [S1 p.40]")


static func _test_phase_order_with_battle_phase(t: TestCase) -> void:
	t.start("phase order through the Battle Phase")
	var d := TestFixtures.new_duel(105, 0)
	var engine: DuelEngine = d["engine"]
	# Turn 1 belongs to the first player, who may not battle; use turn 2.
	TestFixtures.end_turn(engine)
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase can be entered from Main Phase 1")
	t.eq(engine.state.phase, Enums.Phase.BATTLE, "phase is the Battle Phase")
	t.is_true(engine.state.battle_phase_conducted_this_turn,
		"the turn is recorded as having conducted a Battle Phase")

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.END_BATTLE_PHASE)
	t.not_null(a, "the Battle Phase can be ended")
	engine.submit_action(a)
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.phase, Enums.Phase.MAIN_2,
		"ending the Battle Phase moves to Main Phase 2 [S1 p.40]")


static func _test_turn_transition_resets_the_summon_allowance(t: TestCase) -> void:
	t.start("the Normal Summon allowance resets each turn")
	var d := TestFixtures.new_duel(106, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Body"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))
	TestFixtures.pass_until_open(engine)
	t.is_false(engine.state.player(0).can_normal_summon(),
		"the allowance is spent after a Normal Summon")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 0, "back on player 0's turn")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"the allowance is restored at the start of the turn [S1 p.24]")


# --- RULES_SPEC.md 2.5 [S1 p.40] ---
static func _test_hand_size_limit(t: TestCase) -> void:
	t.start("hand size limit of 6 at the end of the End Phase")
	var d := TestFixtures.new_duel(107, 0)
	var engine: DuelEngine = d["engine"]
	var c0: ScriptedController = d["p0"]

	# Nine cards in hand: three must go.
	for i in range(4):
		TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Spare %d" % i))
	t.eq(engine.state.player(0).hand.size(), 9, "hand is over the limit")

	var doomed: Array = [
		engine.state.player(0).hand[0].id,
		engine.state.player(0).hand[1].id,
		engine.state.player(0).hand[2].id,
	]
	c0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, doomed)

	TestFixtures.end_turn(engine)
	t.eq(engine.state.player(0).hand.size(), 6,
		"discarded down to exactly 6 [S1 p.40]")
	t.eq(c0.request_count(Enums.DecisionKind.CHOOSE_DISCARD), 1,
		"the player chose which cards to discard")
	for cid in doomed:
		var card = engine.state.instance(cid)
		t.eq(card.zone, Enums.Zone.GRAVEYARD, "the chosen card went to the Graveyard")
	t.eq(c0.errors.size(), 0, "the scripted answers were all valid")


# --- RULES_SPEC.md 13 [S1 p.33] ---
static func _test_deck_out_loses_the_duel(t: TestCase) -> void:
	t.start("a player who must draw and cannot loses")
	var d := TestFixtures.new_duel(108, 0)
	var engine: DuelEngine = d["engine"]
	engine.state.player(1).deck.clear()

	TestFixtures.end_turn(engine)

	t.is_true(engine.is_duel_over(), "the Duel ended")
	t.eq(engine.state.result, Enums.DuelResult.PLAYER_0_WINS,
		"the player who could not draw lost [S1 p.33]")
	t.eq(engine.state.end_reason, Enums.EndReason.DECK_OUT, "recorded as a deck-out")
	t.eq(engine.timing, DuelEngine.Timing.DUEL_OVER,
		"the timing machine stops once the Duel is over")
	t.eq(engine.get_legal_actions(0).size(), 0, "no actions are legal after the Duel")

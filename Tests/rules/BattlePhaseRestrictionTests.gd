class_name BattlePhaseRestrictionTests
extends RefCounted

## "SKIP YOUR NEXT BATTLE PHASE" — a restriction that is acquired at one moment, owed against
## a specific FUTURE turn, and consumed by the Battle Phase it costs. Rules under test:
## `RULES_SPEC.md §2.4`, `§2`, `§6` [S1 p.37]; `CARD_RULINGS.md` **R1** and **R32**.
##
## This is the **Battle-Phase-restriction gate**, written the way `EquipTests`,
## `ControlTests`, `MovementTests`, `BanishTests`, `LifePointCostTests` and
## `TrapMonsterTests` were: a RULES suite built from synthetic drivers, so what it proves is
## that the ENGINE is right rather than that one printed card happens to work.
## `Runick Flashing Fire` is only implemented once it passes.
##
## **The load-bearing claim is that this is a THIRD lifetime**, and that collapsing it into
## either of the two the engine already has would be wrong:
##
##   * `skip_battle_phase_this_turn` is turn-scoped and wiped by `_end_of_turn_cleanup()`, so
##     it would evaporate before the turn it is supposed to apply to;
##   * `continuous:cannot_conduct_battle_phase` is rebuilt from a face-up source on every
##     recompute, so it would lift the moment that source left the field — and the source
##     here is a Quick-Play Spell that is in the Graveyard immediately.
##
## So it is authoritative state on `PlayerState`, asked by `TurnFlow.can_enter_battle_phase()`
## and spent by `TurnFlow._end_of_turn_cleanup()`. **No card polls it and no UI owns it**;
## that is asserted by driving every test below through the engine's own phase machinery.


static func run() -> TestCase:
	var t := TestCase.new("BattlePhaseRestrictionTests")
	# Acquisition
	_test_acquiring_it_records_which_battle_phase_it_owes(t)
	_test_acquired_before_your_battle_phase_it_costs_THIS_turn(t)
	_test_acquired_after_your_battle_phase_it_costs_a_LATER_turn(t)
	_test_acquired_on_the_opponents_turn_it_costs_your_next_turn(t)
	# Who it affects
	_test_it_affects_only_the_player_who_took_it_on(t)
	# Consumption
	_test_the_battle_phase_it_costs_is_actually_unenterable(t)
	_test_it_is_consumed_by_that_turn_and_the_next_one_is_free(t)
	_test_it_is_not_consumed_by_the_opponents_turn(t)
	_test_a_turn_with_no_battle_phase_available_does_not_spend_it(t)
	# Repetition
	_test_two_obligations_cost_two_battle_phases(t)
	# Independence from the other two restrictions
	_test_it_is_a_third_mechanism_and_not_either_of_the_existing_two(t)
	_test_a_continuous_recompute_does_not_clear_it(t)
	# Determinism
	_test_it_is_replay_deterministic(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A duel in player `first`'s Main Phase 1 on turn 1.
static func _duel(seed_value: int, first: int = 0) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, first)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Advance to the turn player's Main Phase 1 on the following turn.
static func _next_turn(engine: DuelEngine) -> void:
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)


## Can `pid` enter the Battle Phase right now, asked of the rules layer?
static func _can_battle(engine: DuelEngine, pid: int) -> bool:
	return engine.flow.can_enter_battle_phase(pid)


static func _pending(engine: DuelEngine, pid: int) -> int:
	return engine.state.player(pid).battle_phase_skips.size()


# ---------------------------------------------------------------------------
# Acquisition
# ---------------------------------------------------------------------------

static func _test_acquiring_it_records_which_battle_phase_it_owes(t: TestCase) -> void:
	t.start("taking the obligation on records the turn it is owed against, and announces it")
	var d := _duel(9701, 0)
	var engine: DuelEngine = d["engine"]
	t.eq(_pending(engine, 0), 0, "nothing is owed to begin with")
	var before := TestFixtures.count_events(engine,
		GameEvent.Kind.BATTLE_PHASE_SKIP_IMPOSED)

	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	t.eq(_pending(engine, 0), 1, "one obligation is outstanding")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_PHASE_SKIP_IMPOSED),
		before + 1, "and it was announced exactly once")
	var lease: Dictionary = engine.state.player(0).battle_phase_skips[0]
	t.eq(int(lease.get("applies_from_turn", -1)), engine.state.turn_number,
		"owed against THIS turn — the acquirer is the turn player and has not battled yet")
	t.eq(str(lease.get("source_name", "")), "Test Source",
		"and it remembers what imposed it")


static func _test_acquired_before_your_battle_phase_it_costs_THIS_turn(
		t: TestCase) -> void:
	t.start("acquired in your Main Phase 1, it costs the Battle Phase of the very turn it "
		+ "was acquired on")
	# Player 1 goes first, so player 0 may conduct a Battle Phase from turn 2.
	var d := _duel(9702, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn")
	t.check(_can_battle(engine, 0), "and they could battle before taking the obligation on")

	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	t.check(not _can_battle(engine, 0), "now they cannot enter the Battle Phase")
	t.check(engine.state.has_pending_battle_phase_skip(0),
		"because an obligation applies to this very turn")


static func _test_acquired_after_your_battle_phase_it_costs_a_LATER_turn(
		t: TestCase) -> void:
	t.start("acquired once your Battle Phase has already been conducted, it is owed against "
		+ "a later turn — you do not 'skip' one you have already had")
	var d := _duel(9703, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.check(engine.state.battle_phase_conducted_this_turn,
		"the Battle Phase really was conducted this turn")

	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	var lease: Dictionary = engine.state.player(0).battle_phase_skips[0]
	t.eq(int(lease.get("applies_from_turn", -1)), engine.state.turn_number + 1,
		"owed against a later turn, not this one")
	t.check(not engine.state.has_pending_battle_phase_skip(0),
		"so nothing bars the rest of THIS turn")


static func _test_acquired_on_the_opponents_turn_it_costs_your_next_turn(
		t: TestCase) -> void:
	t.start("acquired during the opponent's turn, it is owed against your own next turn")
	var d := _duel(9704, 0)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	t.eq(engine.state.turn_player_id, 1, "it is the opponent's turn")

	# Player 0 takes the obligation on during a turn that is not theirs.
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")
	t.check(not engine.state.has_pending_battle_phase_skip(0),
		"it does not apply to the opponent's turn")

	_next_turn(engine)
	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn again")
	t.check(engine.state.has_pending_battle_phase_skip(0), "now it applies")
	t.check(not _can_battle(engine, 0), "and bars the Battle Phase")


# ---------------------------------------------------------------------------
# Who it affects
# ---------------------------------------------------------------------------

static func _test_it_affects_only_the_player_who_took_it_on(t: TestCase) -> void:
	t.start("'skip YOUR next Battle Phase' — the opponent's Battle Phase is untouched")
	var d := _duel(9705, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	t.check(not _can_battle(engine, 0), "player 0 is barred")
	t.eq(_pending(engine, 1), 0, "player 1 owes nothing")

	_next_turn(engine)
	t.eq(engine.state.turn_player_id, 1, "it is player 1's turn")
	t.check(_can_battle(engine, 1), "and player 1 may battle perfectly normally")


# ---------------------------------------------------------------------------
# Consumption
# ---------------------------------------------------------------------------

static func _test_the_battle_phase_it_costs_is_actually_unenterable(t: TestCase) -> void:
	t.start("the engine does not merely answer 'no' — it does not OFFER the Battle Phase, "
		+ "and the turn goes Main 1 -> End")
	var d := _duel(9706, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ENTER_BATTLE_PHASE),
		"entering the Battle Phase is not among the legal actions")
	t.eq(engine.flow.next_phase_after(Enums.Phase.MAIN_1), Enums.Phase.END,
		"and simply finishing Main Phase 1 leads to the End Phase")


static func _test_it_is_consumed_by_that_turn_and_the_next_one_is_free(
		t: TestCase) -> void:
	t.start("the turn that paid the obligation spends it, and the player's following turn "
		+ "has its Battle Phase back")
	var d := _duel(9707, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")
	t.check(not _can_battle(engine, 0), "this turn is barred")
	var before := TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_PHASE_SKIPPED)

	_next_turn(engine)   # -> opponent's turn; player 0's turn just ended and paid.

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_PHASE_SKIPPED),
		before + 1, "exactly one Battle Phase was announced as skipped")
	t.eq(_pending(engine, 0), 0, "the obligation is spent")

	_next_turn(engine)   # -> player 0's turn again.
	t.eq(engine.state.turn_player_id, 0, "player 0's turn")
	t.check(_can_battle(engine, 0), "and their Battle Phase is available again")


static func _test_it_is_not_consumed_by_the_opponents_turn(t: TestCase) -> void:
	t.start("the opponent's turn does not spend YOUR obligation — a Battle Phase you never "
		+ "had was not skipped")
	var d := _duel(9708, 0)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)                                  # turn 2, player 1's turn
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")
	t.eq(_pending(engine, 0), 1, "player 0 owes one")

	_next_turn(engine)                                  # turn 3, player 0's turn
	t.eq(_pending(engine, 0), 1,
		"the opponent's turn ending did not spend it")
	t.check(not _can_battle(engine, 0), "and it is barring player 0's turn now")


static func _test_a_turn_with_no_battle_phase_available_does_not_spend_it(
		t: TestCase) -> void:
	t.start("turn 1 of the player who went first has no Battle Phase to skip [S1 p.37], so "
		+ "the obligation survives to the next turn that really offers one — R32")
	var d := _duel(9709, 0)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.turn_number, 1, "turn 1")
	t.eq(engine.state.turn_player_id, 0, "and player 0 went first")
	t.check(not _can_battle(engine, 0),
		"they cannot conduct a Battle Phase on it regardless")

	engine.state.impose_battle_phase_skip(0, -1, "Test Source")
	var skipped_before := TestFixtures.count_events(engine,
		GameEvent.Kind.BATTLE_PHASE_SKIPPED)

	_next_turn(engine)   # turn 1 ends
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_PHASE_SKIPPED),
		skipped_before, "nothing was skipped, so nothing was announced")
	t.eq(_pending(engine, 0), 1, "and the obligation is still owed")

	_next_turn(engine)   # turn 3, player 0's turn — the first that offers a Battle Phase
	t.eq(engine.state.turn_player_id, 0, "player 0's next turn")
	t.check(not _can_battle(engine, 0), "this is the Battle Phase it takes")

	_next_turn(engine)
	t.eq(_pending(engine, 0), 0, "and now it is spent")


# ---------------------------------------------------------------------------
# Repetition
# ---------------------------------------------------------------------------

static func _test_two_obligations_cost_two_battle_phases(t: TestCase) -> void:
	t.start("two obligations are two Battle Phases, not one — they are counted, not a flag")
	var d := _duel(9710, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)                                  # turn 2, player 0
	engine.state.impose_battle_phase_skip(0, -1, "First")
	engine.state.impose_battle_phase_skip(0, -1, "Second")
	t.eq(_pending(engine, 0), 2, "two are outstanding")
	t.check(not _can_battle(engine, 0), "turn 2 is barred")

	_next_turn(engine)                                  # turn 3, player 1
	t.eq(_pending(engine, 0), 1, "turn 2 spent exactly one")
	_next_turn(engine)                                  # turn 4, player 0
	t.check(not _can_battle(engine, 0), "turn 4 is barred by the second one")
	_next_turn(engine)                                  # turn 5, player 1
	t.eq(_pending(engine, 0), 0, "which is now spent too")
	_next_turn(engine)                                  # turn 6, player 0
	t.check(_can_battle(engine, 0), "and turn 6 is finally free")


# ---------------------------------------------------------------------------
# Independence from the two restrictions that already existed
# ---------------------------------------------------------------------------

static func _test_it_is_a_third_mechanism_and_not_either_of_the_existing_two(
		t: TestCase) -> void:
	t.start("it is not expressed as the turn-scoped restriction, which the end of the turn "
		+ "would wipe before it ever applied")
	var d := _duel(9711, 0)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)                                  # turn 2, player 1's turn
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	t.check(not bool(engine.state.player(0).get_restriction(
		"skip_battle_phase_this_turn", false)),
		"it did not write the turn-scoped restriction")
	t.check(not bool(engine.state.player(0).get_restriction(
		ContinuousEffects.PLAYER_KEY_PREFIX + "cannot_conduct_battle_phase", false)),
		"nor the continuous one")

	# The turn ends — which is exactly what would have destroyed a turn-scoped flag.
	_next_turn(engine)
	t.eq(_pending(engine, 0), 1, "and it survived the turn boundary intact")
	t.check(not _can_battle(engine, 0), "still barring player 0's Battle Phase")


static func _test_a_continuous_recompute_does_not_clear_it(t: TestCase) -> void:
	t.start("a continuous recompute rebuilds player restrictions from the board and must "
		+ "leave this obligation alone — it has no face-up source to be rebuilt from")
	var d := _duel(9712, 1)
	var engine: DuelEngine = d["engine"]
	_next_turn(engine)
	engine.state.impose_battle_phase_skip(0, -1, "Test Source")

	ContinuousEffects.new(engine.state).recompute()
	ContinuousEffects.new(engine.state).recompute()

	t.eq(_pending(engine, 0), 1, "still owed after two recomputes")
	t.check(not _can_battle(engine, 0), "and still barring the Battle Phase")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

static func _test_it_is_replay_deterministic(t: TestCase) -> void:
	t.start("acquiring and spending the obligation produces an identical event stream from "
		+ "the same seed")
	var signatures: Array = []
	for run_index in range(2):
		var d := _duel(9713, 1)
		var engine: DuelEngine = d["engine"]
		_next_turn(engine)
		engine.state.impose_battle_phase_skip(0, -1, "Test Source")
		_next_turn(engine)
		_next_turn(engine)
		var parts: Array = []
		for e in engine.state.events:
			parts.append("%d:%s" % [e.kind, str(e.data.get("player", -1))])
		signatures.append("|".join(parts))

	t.eq(signatures[0], signatures[1], "two runs produced the same event stream")
	t.check(signatures[0].contains("%d:" % GameEvent.Kind.BATTLE_PHASE_SKIPPED),
		"and the stream really does contain the skip — this is not two empty logs")

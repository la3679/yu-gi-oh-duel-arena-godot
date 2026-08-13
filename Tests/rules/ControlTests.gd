class_name ControlTests
extends RefCounted

## Change of CONTROL. Rules under test: `RULES_SPEC.md §5.6` [S1 p.52].
##
## This is the **control gate**, written the same way `EquipTests` was: it is a RULES suite
## built from synthetic cards, so what it proves is that the ENGINE is right rather than that
## one printed card happens to work. The three Charmers and `Enemy Controller` are only
## implemented once it passes.
##
## The single load-bearing distinction is OWNER vs CONTROLLER. Taking control must move a
## monster between the two players' Monster Zone arrays and rewrite `controller_id`, and must
## never touch `owner_id` — the owner is what sends the card to the right Graveyard, hand or
## Deck when it later leaves the field.


static func run() -> TestCase:
	var t := TestCase.new("ControlTests")
	_test_owner_is_not_controller(t)
	_test_it_is_not_a_move(t)
	_test_no_free_zone(t)
	_test_a_lease_ends_with_its_source(t)
	_test_the_end_phase_lease(t)
	_test_the_controlled_monster_leaves_the_field(t)
	_test_the_controlled_monster_is_flipped_face_down(t)
	_test_destroyed_and_tributed_under_temporary_control(t)
	_test_two_control_effects_on_one_monster(t)
	_test_control_changes_hands_and_comes_all_the_way_back(t)
	_test_a_permanent_lease_does_not_expire(t)
	_test_controller_facing_queries(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A face-up monster on player 1's field plus a face-up "source" card on player 0's, which is
## what a `WHILE_SOURCE_FACE_UP` lease hangs off.
static func _board(seed_value: int) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["source"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source", 3, 500, 1500))
	d["victim"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Victim", 4, 1200, 800))
	return d


static func _zone_of(state: GameState, pid: int, card: CardInstance) -> int:
	var n := 0
	for entry in state.player(pid).monster_zones:
		if entry == card:
			n += 1
	return n


# ---------------------------------------------------------------------------
# The distinction the whole subsystem exists for
# ---------------------------------------------------------------------------

static func _test_owner_is_not_controller(t: TestCase) -> void:
	t.start("taking control changes the CONTROLLER and never the OWNER [S1 p.52]")
	var d := _board(301)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]

	t.eq(victim.owner_id, 1, "the monster is owned by player 1")
	t.eq(victim.controller_id, 1, "and controlled by player 1 to begin with")

	t.is_true(engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP), "player 0 takes control")

	t.eq(victim.controller_id, 0, "the CONTROLLER is now player 0")
	t.eq(victim.owner_id, 1, "the OWNER is unchanged — this is the whole point")
	t.eq(_zone_of(engine.state, 0, victim), 1,
		"it occupies one of player 0's Monster Zones")
	t.eq(_zone_of(engine.state, 1, victim), 0, "and none of player 1's")
	t.eq(engine.state.player(0).monsters().size(), 2,
		"player 0 now controls two monsters")
	t.eq(engine.state.player(1).monsters().size(), 0, "and player 1 none")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"exactly one CONTROL_CHANGED event")
	t.eq(engine.state.control_leases_for(victim.id).size(), 1,
		"and one control lease is in force")


static func _test_it_is_not_a_move(t: TestCase) -> void:
	t.start("a control change is not a MOVE: the monster does not leave the field, so "
		+ "nothing that keys on leaving the field may fire")
	var d := _board(302)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	# An Equip Card on the monster is the sharpest probe available: an Equip Card is
	# destroyed when its host leaves the field [S1 p.29], so if a control change were
	# implemented as a move_card() this would die.
	var equip := TestFixtures.give(engine, 1,
		TestFixtures.equip_spell("Clinger", 400), Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	t.is_true(engine.state.equip_to(equip, victim), "the monster is equipped")
	var moves_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_MOVED)
	var last_reason_before := victim.last_move_reason

	t.is_true(engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP), "player 0 takes control")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_MOVED), moves_before,
		"no CARD_MOVED event was emitted")
	t.eq(victim.last_move_reason, last_reason_before,
		"and `last_move_*` was not rewritten to describe a move that did not happen")
	t.eq(equip.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Equip Card was not destroyed: its host never left the field")
	t.eq(equip.equipped_to_id, victim.id, "and is still equipped to it")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_UNEQUIPPED), 0,
		"nothing was unequipped")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "the monster is still in a Monster Zone")


static func _test_no_free_zone(t: TestCase) -> void:
	t.start("control cannot be taken when the taker has no free Monster Zone — a monster is "
		+ "only ever controlled FROM a Monster Zone")
	var d := _duel(303)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source", 3, 500, 1500))
	for i in range(PlayerState.MONSTER_ZONE_COUNT - 1):
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Filler %d" % i, 4, 100, 100))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Victim", 4, 1200, 800))
	t.is_false(engine.state.player(0).has_free_monster_zone(), "player 0's field is full")

	t.is_false(engine.state.can_change_control(victim, 0), "so the change is not legal")
	t.is_false(engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP), "and it does not happen")
	t.eq(victim.controller_id, 1, "the monster stays with its controller")
	t.eq(_zone_of(engine.state, 1, victim), 1, "in its original Monster Zone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 0,
		"and nothing was announced")
	t.eq(engine.state.control_leases.size(), 0, "no lease was recorded")


# ---------------------------------------------------------------------------
# Durations
# ---------------------------------------------------------------------------

static func _test_a_lease_ends_with_its_source(t: TestCase) -> void:
	t.start("\"while this card is face-up on the field\": control reverts the moment the "
		+ "SOURCE stops being face-up on the field")
	var d := _board(304)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	t.eq(victim.controller_id, 0, "player 0 has taken control")

	# Flipping the source face-down is the first of the two ways it stops applying.
	engine.state.set_battle_position(source, Enums.Position.FACE_DOWN_DEFENSE, true)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 1, "a face-down source ends the lease")
	t.eq(_zone_of(engine.state, 1, victim), 1, "and the monster is back in its own zone")
	t.eq(victim.owner_id, 1, "the owner never changed throughout")
	t.eq(engine.state.control_leases.size(), 0, "the lease is gone")
	var reverts := TestFixtures.events_of(engine, GameEvent.Kind.CONTROL_CHANGED).filter(
		func(e): return bool(e.data.get("reverted", false)))
	t.eq(reverts.size(), 1, "exactly one reverting CONTROL_CHANGED event")

	# Second way: the source leaves the field entirely.
	engine.state.set_battle_position(source, Enums.Position.FACE_UP_ATTACK, true)
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	t.eq(victim.controller_id, 0, "taken again")
	engine.state.destroy(source, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 1, "the source leaving the field ends it too")
	t.eq(engine.state.control_leases.size(), 0, "and leaves no lease behind")


static func _test_the_end_phase_lease(t: TestCase) -> void:
	t.start("\"until the End Phase\": control lasts through the turn and reverts as the End "
		+ "Phase is ENTERED, before the two-step End Phase does anything")
	var d := _board(305)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.UNTIL_END_PHASE)
	t.eq(victim.controller_id, 0, "player 0 has taken control")

	# A timing-point expiry must NOT end this one: its condition is the End Phase, not the
	# state of its source. Destroying the source proves the two durations are independent.
	engine.state.destroy(source, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 0,
		"losing the source does NOT end an \"until the End Phase\" lease")

	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.eq(victim.controller_id, 0, "still controlled during the Battle Phase")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(engine.state.phase, Enums.Phase.END, "the End Phase has been entered")
	t.eq(victim.controller_id, 1, "and control has already reverted")
	t.eq(_zone_of(engine.state, 1, victim), 1, "into its own Monster Zone")
	t.eq(engine.state.control_leases.size(), 0, "with no lease left")
	# The discard step is the END of the End Phase [S1 p.40], so the revert must be earlier.
	var revert_seq := -1
	for e in engine.state.events:
		if e.kind == GameEvent.Kind.CONTROL_CHANGED and bool(e.data.get("reverted", false)):
			revert_seq = e.sequence
	var end_phase_seq := -1
	for e in engine.state.events:
		if e.kind == GameEvent.Kind.PHASE_CHANGED and e.data.get("to") == Enums.Phase.END:
			end_phase_seq = e.sequence
	t.is_true(revert_seq > end_phase_seq,
		"the revert happens after the End Phase is announced")
	TestFixtures.end_turn(engine)
	t.eq(victim.controller_id, 1, "and it stays reverted into the next turn")


static func _test_a_permanent_lease_does_not_expire(t: TestCase) -> void:
	t.start("a lease with no stated end condition is never expired by either mechanism")
	var d := _board(306)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id, Enums.ControlDuration.PERMANENT)
	engine.state.destroy(source, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 0, "losing the source does not end it")
	engine.state.expire_control_leases(true)
	t.eq(victim.controller_id, 0, "and neither does the End Phase")
	t.eq(engine.state.control_leases.size(), 1, "the lease is still in force")


# ---------------------------------------------------------------------------
# What happens to a monster under someone else's control
# ---------------------------------------------------------------------------

static func _test_the_controlled_monster_leaves_the_field(t: TestCase) -> void:
	t.start("a controlled monster that leaves the field goes to its OWNER's zones, and its "
		+ "lease simply ends [S1 p.52]")
	var d := _board(307)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)

	t.is_true(engine.state.move_card(victim, Enums.Zone.HAND,
		Enums.MoveReason.RETURNED_TO_HAND), "it is returned to the hand")
	t.is_true(engine.state.player(1).hand.has(victim),
		"into the OWNER's hand, not the controller's")
	t.is_false(engine.state.player(0).hand.has(victim), "player 0 does not get it")
	t.eq(victim.controller_id, 1, "and it is its owner's card again")
	t.eq(engine.state.control_leases.size(), 0, "the lease ended with the departure")

	# The lease must be genuinely gone, not merely dormant: if it survived, the source
	# leaving later would try to "revert" a card that is no longer anybody's to revert.
	engine.state.destroy(source, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.zone, Enums.Zone.HAND, "the returned card is untouched by the expiry")
	t.eq(victim.controller_id, 1, "and still its owner's")


static func _test_the_controlled_monster_is_flipped_face_down(t: TestCase) -> void:
	t.start("turning a controlled monster face-down does NOT return it: the lease is on the "
		+ "SOURCE being face-up, not on the target")
	var d := _board(308)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)

	engine.state.set_battle_position(victim, Enums.Position.FACE_DOWN_DEFENSE, true)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 0, "player 0 still controls it face-down")
	t.eq(_zone_of(engine.state, 0, victim), 1, "in player 0's Monster Zone")
	t.eq(victim.owner_id, 1, "still owned by player 1")
	t.eq(engine.state.control_leases.size(), 1, "and the lease is still in force")

	engine.state.set_battle_position(source, Enums.Position.FACE_DOWN_DEFENSE, true)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 1,
		"while the SOURCE going face-down does return it, even face-down")
	t.eq(victim.position, Enums.Position.FACE_DOWN_DEFENSE,
		"and it goes back in the position it was in — reverting is not a flip")


static func _test_destroyed_and_tributed_under_temporary_control(t: TestCase) -> void:
	t.start("a monster destroyed or Tributed under temporary control still goes to its "
		+ "OWNER's Graveyard [S1 p.52-53]")
	var d := _board(309)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	t.is_true(engine.state.destroy(victim, Enums.MoveReason.DESTROYED_BY_EFFECT, -1),
		"the borrowed monster is destroyed")
	t.is_true(engine.state.player(1).graveyard.has(victim),
		"it goes to player 1's Graveyard — the OWNER's")
	t.is_false(engine.state.player(0).graveyard.has(victim),
		"and not to the controller's")
	t.eq(engine.state.control_leases.size(), 0, "the lease ended")

	# The same for a Tribute, which is the other way a borrowed monster is spent.
	var d2 := _board(310)
	var engine2: DuelEngine = d2["engine"]
	var source2: CardInstance = d2["source"]
	var victim2: CardInstance = d2["victim"]
	engine2.state.change_control(victim2, 0, source2.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	var tribute_fodder := TestFixtures.give_to_hand(engine2, 0,
		TestFixtures.monster("Big One", 5, 2000, 1000))
	var summon = TestFixtures.find_action(engine2.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, tribute_fodder.id)
	t.not_null(summon, "a Tribute Summon is offered")
	t.is_true(summon.tribute_candidates.has(victim2.id),
		"and the borrowed monster is a legal Tribute — Tributes are about CONTROL")
	t.is_true(engine2.submit_action(summon.with_choices({"tribute_ids": [victim2.id]})),
		"it is Tributed for the Summon")
	TestFixtures.pass_until_open(engine2)
	t.is_true(engine2.state.player(1).graveyard.has(victim2),
		"and still reaches its OWNER's Graveyard")
	t.eq(engine2.state.control_leases.size(), 0, "with no lease left over")


# ---------------------------------------------------------------------------
# More than one control effect
# ---------------------------------------------------------------------------

static func _test_two_control_effects_on_one_monster(t: TestCase) -> void:
	t.start("two control effects on one monster unwind in the right order — ending the "
		+ "older one does not move a monster the newer one governs")
	var d := _duel(311)
	var engine: DuelEngine = d["engine"]
	var a := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source A", 3, 500, 1500))
	var b := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source B", 3, 500, 1500))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Victim", 4, 1200, 800))

	engine.state.change_control(victim, 0, a.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	t.eq(victim.controller_id, 0, "effect A takes it")
	# Effect B hands it back to player 1 while A's lease is still in force.
	engine.state.change_control(victim, 1, b.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	t.eq(victim.controller_id, 1, "effect B moves it again")
	t.eq(engine.state.control_leases_for(victim.id).size(), 2, "two leases stack")

	# Ending the OLDER lease must not move the card: B is what governs where it sits now.
	engine.state.destroy(a, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 1, "losing A's source does not move it")
	t.eq(engine.state.control_leases_for(victim.id).size(), 1, "but A's lease is gone")

	# ...and when B ends, the card must go all the way back to where it started, not to
	# the intermediate controller A had put it under.
	engine.state.destroy(b, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 1, "and it ends up back with its original controller")
	t.eq(victim.owner_id, 1, "which is also its owner here")
	t.eq(engine.state.control_leases.size(), 0, "no lease survives")


static func _test_control_changes_hands_and_comes_all_the_way_back(t: TestCase) -> void:
	t.start("the same, with the intermediate controller genuinely different: control comes "
		+ "all the way back rather than stopping halfway")
	var d := _duel(312)
	var engine: DuelEngine = d["engine"]
	var a := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source A", 3, 500, 1500))
	var b := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Source B", 3, 500, 1500))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Victim", 4, 1200, 800))

	# 1 -> 0 by A, then 0 -> 1 by B, then A ends (no move), then B ends.
	engine.state.change_control(victim, 0, a.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
	engine.state.change_control(victim, 1, b.id, Enums.ControlDuration.UNTIL_END_PHASE)
	t.eq(victim.controller_id, 1, "player 1 has it back under B")

	engine.state.destroy(a, Enums.MoveReason.DESTROYED_BY_EFFECT, -1)
	engine.state.expire_control_leases()
	t.eq(victim.controller_id, 1, "A ending changes nothing visible")
	var remaining := engine.state.control_leases_for(victim.id)
	t.eq(remaining.size(), 1, "one lease left")
	t.eq(int((remaining[0] as Dictionary)["from_controller"]), 1,
		"and it now points all the way back to the original controller, not to the "
		+ "intermediate one A had created")

	engine.state.expire_control_leases(true)
	t.eq(victim.controller_id, 1, "so the End Phase leaves it with its original controller")
	t.eq(engine.state.control_leases.size(), 0, "and every lease is done")


# ---------------------------------------------------------------------------
# Controller-facing queries
# ---------------------------------------------------------------------------

static func _test_controller_facing_queries(t: TestCase) -> void:
	t.start("every controller-facing query follows the CONTROLLER, while the visible state "
		+ "reports owner and controller separately")
	var d := _board(313)
	var engine: DuelEngine = d["engine"]
	var source: CardInstance = d["source"]
	var victim: CardInstance = d["victim"]
	engine.state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP)

	t.is_true(engine.state.player(0).monsters().has(victim),
		"it is among the monsters player 0 controls")
	t.is_false(engine.state.player(1).monsters().has(victim),
		"and not among player 1's")
	t.is_true(engine.state.player(0).face_up_monsters().has(victim),
		"including the face-up query the card conditions use")

	var view := engine.state.get_visible_state(1)
	var found := {}
	for side in view["players"]:
		for c in (side as Dictionary)["monster_zones"]:
			if c != null and int((c as Dictionary).get("id", -1)) == victim.id:
				found = c
	t.is_false(found.is_empty(), "the monster appears in the visible state")
	t.eq(int(found["controller"]), 0, "reported as controlled by player 0")
	t.eq(int(found["owner"]), 1, "and owned by player 1 — the two are separate fields")

	# Attacking is a controller question: the borrowed monster attacks for its CONTROLLER.
	# A separate duel, because the Battle Phase is prohibited on turn 1 [S1 p.35].
	var bd := TestFixtures.battle_duel(314)
	var engine2: DuelEngine = bd["engine"]
	t.eq(engine2.state.turn_player_id, 0, "player 0 is the turn player in the Battle Phase")
	var holder := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.monster("Source", 3, 500, 1500))
	var borrowed := TestFixtures.give_monster_on_field(engine2, 1,
		TestFixtures.monster("Borrowed", 4, 1200, 800))
	var before: Array = []
	for a in engine2.get_legal_actions(0):
		if a.kind == Enums.ActionKind.DECLARE_ATTACK:
			before.append(a.card_id)
	t.is_false(before.has(borrowed.id),
		"the opponent's monster is not one player 0 may attack WITH")

	t.is_true(engine2.state.change_control(borrowed, 0, holder.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP), "player 0 takes control of it")
	var after: Array = []
	for a in engine2.get_legal_actions(0):
		if a.kind == Enums.ActionKind.DECLARE_ATTACK:
			after.append(a.card_id)
	t.is_true(after.has(borrowed.id),
		"and may now attack with it — attacking follows the CONTROLLER")

class_name CompulsoryEvacuationDeviceTests
extends RefCounted

## `Compulsory Evacuation Device` — "Target 1 monster on the field; return that target to
## the hand."
##
## The generic behaviour is proved by `MovementTests`; this suite proves that THIS card
## reaches it correctly — its activation legality, its candidate set, and the negatives.

const CARD_UNDER_TEST := "Compulsory Evacuation Device"


static func run() -> TestCase:
	var t := TestCase.new("CompulsoryEvacuationDeviceTests")
	_test_the_clause_shape(t)
	_test_it_returns_an_opponents_monster(t)
	_test_it_returns_your_own_monster(t)
	_test_a_face_down_monster_is_a_legal_target(t)
	_test_spell_traps_are_not_legal_targets(t)
	_test_it_cannot_be_activated_with_an_empty_field(t)
	_test_a_target_that_left_the_field(t)
	_test_a_monster_under_borrowed_control_goes_to_its_owner(t)
	_test_it_is_not_a_destruction(t)
	_test_it_cleans_up_equips_and_the_set_turn_rule(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.new().load_library()


static func _card_def(t: TestCase) -> CardDef:
	var lib := _library()
	t.eq(lib["errors"], [], "the card library loads with no errors")
	var cards: Dictionary = lib["cards"]
	t.is_true(cards.has(CARD_UNDER_TEST), "the registry knows the card")
	return cards[CARD_UNDER_TEST]


## A duel in Main Phase 1 with the card Set on player 0's field on an earlier turn.
static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["ced"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	return d


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal Trap card activation that targets exactly 1 monster")
	var def := _card_def(t)
	t.eq(def.effects.size(), 1, "exactly one EffectDef, for the card's one clause")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2")
	t.is_true(clause.targets, "it TARGETS, the word appears in the official text")
	t.eq(clause.target_count_min, 1, "exactly one target")
	t.eq(clause.target_count_max, 1, "and no more")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Trap is activated from a Set position, never from the hand")
	t.eq(clause.damage_step_permission, Enums.DamageStepPermission.NONE,
		"it is not one of the effects the Damage Step allows [S1 p.41]")
	t.is_true(clause.clause_text.contains("return that target to the hand"),
		"the clause quotes the official text")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_it_returns_an_opponents_monster(t: TestCase) -> void:
	t.start("it returns the opponent's monster to the opponent's hand")
	var d := _board(t, 7301)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	var hand_before: int = engine.state.player(1).hand.size()

	t.is_true(TestFixtures.activate_card(engine, 0, ced, [victim.id]),
		"the Trap is activated targeting the opponent's monster")
	t.eq(victim.zone, Enums.Zone.HAND, "the monster is in a hand")
	t.eq(engine.state.player(1).hand.size(), hand_before + 1, "the OPPONENT's hand grew")
	t.is_true(engine.state.player(1).hand.has(victim), "and holds that very card")
	t.eq(engine.state.player(1).monsters().size(), 0, "their field is empty")
	t.eq(victim.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"recorded as a return to the hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		victim.id), 1, "exactly one bounce event")
	t.eq(ced.zone, Enums.Zone.GRAVEYARD, "the Normal Trap goes to the Graveyard after")


static func _test_it_returns_your_own_monster(t: TestCase) -> void:
	t.start("'1 monster ON THE FIELD' includes your own, and that is a legal play")
	var d := _board(t, 7302)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Monster", 4, 1600, 1200))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ced.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(mine.id),
		"the player's own monster is in the published candidate set")

	t.is_true(TestFixtures.activate_card(engine, 0, ced, [mine.id]),
		"it is activated on the player's own monster")
	t.eq(mine.zone, Enums.Zone.HAND, "the monster is back in a hand")
	t.is_true(engine.state.player(0).hand.has(mine), "its owner's, the same player's")


static func _test_a_face_down_monster_is_a_legal_target(t: TestCase) -> void:
	t.start("a face-down monster is a legal target: the text names no property a "
		+ "face-down monster lacks")
	var d := _board(t, 7303)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Set Monster", 4, 1000, 1800),
		Enums.Position.FACE_DOWN_DEFENSE)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ced.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(hidden.id), "the face-down monster is a candidate")

	t.is_true(TestFixtures.activate_card(engine, 0, ced, [hidden.id]),
		"it is activated on the face-down monster")
	t.eq(hidden.zone, Enums.Zone.HAND, "it is returned to the hand")
	t.eq(hidden.position, Enums.Position.FACE_DOWN, "and is face-down there")
	t.is_false(hidden.last_move_was_face_up,
		"the move records that it came from a face-DOWN position")


# ---------------------------------------------------------------------------
# Negatives, where the value is
# ---------------------------------------------------------------------------

static func _test_spell_traps_are_not_legal_targets(t: TestCase) -> void:
	t.start("'1 MONSTER on the field' excludes Spell and Trap Cards, including the card's "
		+ "own controller's and its own self")
	var d := _board(t, 7304)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	var monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("A Monster", 4, 1000, 1000))
	var other_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ced.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(monster.id), "the monster is a candidate")
	t.is_false(candidates.has(other_trap.id), "the opponent's Set Trap is not")
	t.is_false(candidates.has(ced.id), "and neither is this card itself")
	t.eq(candidates.size(), 1, "exactly one legal target exists")


static func _test_it_cannot_be_activated_with_an_empty_field(t: TestCase) -> void:
	t.start("with no monster anywhere on the field there is no legal target, so the card "
		+ "cannot be activated at all")
	var d := _board(t, 7305)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	t.eq(engine.state.all_field_monsters().size(), 0, "no monster is on the field")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ced.id),
		"the activation is not offered")
	t.is_false(TestFixtures.activate_card(engine, 0, ced),
		"and cannot be forced through the public API")
	t.eq(ced.zone, Enums.Zone.SPELL_TRAP_ZONE, "the card is still Set on the field")

	# One monster appears and the activation becomes available: the positive control that
	# proves the block above was about the target and not about something else.
	var monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Arrival", 4, 1000, 1000))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ced.id),
		"one monster on the field is enough to make it activatable")
	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "and that monster is on the field")


static func _test_a_target_that_left_the_field(t: TestCase) -> void:
	t.start("a target that left the field before resolution is dropped, never chased into "
		+ "its new zone (master prompt 44)")
	var d := _board(t, 7306)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Doomed", 4, 1000, 1000))
	# A Spell Speed 2 response that removes the target between activation and resolution.
	# It belongs to the TURN PLAYER because that is who chains to their own activation.
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Remover", victim, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ced.id)
	t.not_null(offered, "the bounce is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"the bounce is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the response window is open for Chain Link 2")
	t.is_true(engine.submit_action(response), "the remover is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(victim.zone, Enums.Zone.GRAVEYARD,
		"Chain Link 2 sent the target to the Graveyard first")
	t.is_false(engine.state.player(1).hand.has(victim),
		"so the bounce did nothing, the card is NOT in the hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		victim.id), 0, "and no bounce event was ever emitted")
	t.eq(ced.zone, Enums.Zone.GRAVEYARD, "the Trap still resolved and left the field")


static func _test_a_monster_under_borrowed_control_goes_to_its_owner(t: TestCase) -> void:
	t.start("a monster the opponent has taken control of returns to its OWNER's hand, and "
		+ "the control lease goes with it [S1 p.52]")
	var d := _board(t, 7307)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Lender", 3, 500, 500))
	var borrowed := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Borrowed", 4, 1500, 1000))
	t.is_true(engine.state.change_control(borrowed, 0, source.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "player 0 takes control of it")
	t.eq(borrowed.controller_id, 0, "player 0 controls it")
	t.eq(borrowed.owner_id, 1, "player 1 still owns it")

	t.is_true(TestFixtures.activate_card(engine, 0, ced, [borrowed.id]),
		"the Trap is activated on the borrowed monster")
	t.eq(borrowed.zone, Enums.Zone.HAND, "it is in a hand")
	t.is_true(engine.state.player(1).hand.has(borrowed), "its OWNER's hand [S1 p.52]")
	t.is_false(engine.state.player(0).hand.has(borrowed), "not the controller's")
	t.eq(borrowed.controller_id, 1, "and the controller is now its owner again")
	t.eq(engine.state.control_leases_for(borrowed.id).size(), 0,
		"the control lease left with the card")


static func _test_it_is_not_a_destruction(t: TestCase) -> void:
	t.start("returning to the hand is NOT a destruction and NOT a send to the Graveyard, "
		+ "so a 'when this card is destroyed' trigger does not fire [S1 p.52]")
	var d := _board(t, 7308)
	var engine: DuelEngine = d["engine"]
	var ced: CardInstance = d["ced"]
	# A monster whose trigger would be loud if a bounce were mistaken for a destruction.
	var watcher_def := TestFixtures.monster("Watcher", 4, 1000, 1000)
	var watched := EffectDef.new("watch_destruction", "Test: draw when destroyed.")
	watched.of_type(Enums.EffectType.TRIGGER)
	watched.mandatory()
	watched.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	watched.trigger_events = [GameEvent.Kind.CARD_DESTROYED]
	watched.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.event_is_destruction_of(ctx.trigger_event, ctx.source.id)
	watched.resolve = func(ctx: EffectContext) -> void:
		ctx.state.draw(ctx.source.controller_id, 1)
	TestFixtures.with_effect(watcher_def, watched)
	var watcher := TestFixtures.give_monster_on_field(engine, 1, watcher_def)

	var gy_before: int = engine.state.player(1).graveyard.size()
	var destroyed_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED)
	var hand_before: int = engine.state.player(1).hand.size()

	t.is_true(TestFixtures.activate_card(engine, 0, ced, [watcher.id]),
		"the Trap bounces the watcher")
	t.eq(watcher.zone, Enums.Zone.HAND, "the watcher is in the hand")
	t.eq(engine.state.player(1).graveyard.size(), gy_before,
		"nothing of the opponent's reached the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), destroyed_before,
		"no CARD_DESTROYED event was emitted")
	t.eq(engine.state.player(1).hand.size(), hand_before + 1,
		"the hand grew by exactly the bounced card, so the trigger did NOT draw")


static func _test_it_cleans_up_equips_and_the_set_turn_rule(t: TestCase) -> void:
	t.start("bouncing an equipped monster destroys its Equip Cards, and the Trap itself "
		+ "obeys the Set-turn restriction")
	var d := TestFixtures.new_duel(7309, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	# Set THIS turn: a Trap cannot be activated on the turn it was Set. [S1 p.30]
	var fresh := TestFixtures.give(engine, 0, _card_def(t), Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_DOWN)
	fresh.turn_set = engine.state.turn_number
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Equipped", 4, 1200, 1000))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, fresh.id),
		"a Trap Set this turn cannot be activated")

	# Backdate it and try again: the positive control for the block above.
	fresh.turn_set = engine.state.turn_number - 1
	var equip := TestFixtures.give(engine, 1, TestFixtures.equip_spell("Clinger", 500),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.is_true(engine.state.equip_to(equip, victim), "the monster is equipped")

	t.is_true(TestFixtures.activate_card(engine, 0, fresh, [victim.id]),
		"a Trap Set on an earlier turn can be activated")
	t.eq(victim.zone, Enums.Zone.HAND, "the equipped monster is returned to the hand")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "its Equip Card is destroyed by the rules")
	t.eq(equip.last_move_reason, Enums.MoveReason.DESTROYED_BY_RULE,
		"with the rules-destruction reason [S1 p.29, p.55]")
	t.eq(victim.equipped_card_ids.size(), 0, "and the equip relationship is gone")

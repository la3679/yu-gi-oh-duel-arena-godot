class_name InterdimensionalMatterTransporterTests
extends RefCounted

## `Interdimensional Matter Transporter` — "Target 1 face-up monster you control; banish that
## target until the End Phase."
##
## The generic temporary-removal behaviour is proved by `BanishTests`; this suite proves that
## THIS card reaches it correctly — its activation legality, its candidate set, its three
## resolution-time re-checks, the End Phase return on a printed card, and the negatives.
##
## It is also the pool's only real-card exercise of `GameState.banish_leases`, so the
## consequences CARD_RULINGS.md R30 reasons about are asserted here on the printed card as
## well as generically: the return is not a Summon, the position is preserved, and the
## monster comes back with its Equip Cards and modifiers gone.

const CARD_UNDER_TEST := "Interdimensional Matter Transporter"


static func run() -> TestCase:
	var t := TestCase.new("InterdimensionalMatterTransporterTests")
	# Clause enumeration
	_test_the_clause_shape(t)
	# Candidate set — what the text does and does not allow
	_test_it_targets_your_own_face_up_monsters(t)
	_test_an_opponents_monster_is_not_a_legal_target(t)
	_test_a_face_down_monster_is_not_a_legal_target(t)
	_test_spell_traps_are_not_legal_targets(t)
	_test_it_cannot_be_activated_with_no_face_up_monster(t)
	# The main line
	_test_it_banishes_the_target_and_schedules_the_return(t)
	_test_it_is_not_a_destruction_and_not_a_send_to_gy(t)
	_test_the_monster_comes_back_in_the_end_phase(t)
	_test_the_return_is_not_a_summon(t)
	_test_the_position_is_preserved_across_the_round_trip(t)
	_test_it_rescues_a_monster_from_a_destruction_effect(t)
	_test_the_monster_comes_back_without_its_equips_or_modifiers(t)
	# Resolution-time re-checks
	_test_a_target_that_left_the_field_before_resolution(t)
	_test_a_target_the_opponent_took_control_of_before_resolution(t)
	_test_a_target_flipped_face_down_before_resolution(t)
	# Negation and chain
	_test_a_negated_activation_banishes_nothing(t)
	_test_a_negated_effect_banishes_nothing(t)
	_test_it_can_be_activated_in_a_response_window(t)
	# Determinism
	_test_the_round_trip_is_replay_deterministic(t)
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
	d["imt"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	return d


## A context carrying `target`, for driving the card's own `resolve` callable directly. This
## is how the resolution-time re-checks are exercised for board changes the test suite cannot
## easily stage inside a live Chain (a control change or a flip in response).
static func _ctx(t: TestCase, engine: DuelEngine, source: CardInstance,
		target: CardInstance) -> EffectContext:
	var def := _card_def(t)
	var effect: EffectDef = def.effects[0]
	var ctx := EffectContext.new(engine.state, source, effect)
	ctx.controller_id = 0
	ctx.chosen_target_ids.append(target.id)
	return ctx


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
	t.is_true(clause.clause_text.contains("banish that target until the End Phase"),
		"the clause quotes the official text")
	t.is_true(clause.clause_text.contains("face-up monster you control"),
		"including the two words that restrict the candidate set")


# ---------------------------------------------------------------------------
# The candidate set
# ---------------------------------------------------------------------------

static func _test_it_targets_your_own_face_up_monsters(t: TestCase) -> void:
	t.start("'1 face-up monster YOU control' publishes the activator's own face-up monsters")
	var d := _board(t, 7501)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine_a := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine A", 4, 1800, 1000))
	var mine_b := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine B", 4, 1200, 1000), Enums.Position.FACE_UP_DEFENSE)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(mine_a.id), "the face-up Attack Position monster is a candidate")
	t.is_true(candidates.has(mine_b.id),
		"and so is the face-up Defense Position one — 'face-up' is not 'Attack Position'")
	t.eq(candidates.size(), 2, "and nothing else is")


static func _test_an_opponents_monster_is_not_a_legal_target(t: TestCase) -> void:
	t.start("'you control' excludes the opponent's monsters — this card is protection, "
		+ "not removal")
	var d := _board(t, 7502)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(mine.id), "the activator's own monster is a candidate")
	t.is_true(not candidates.has(theirs.id), "the opponent's monster is NOT")
	t.eq(candidates.size(), 1, "exactly one candidate")

	# And the engine refuses the illegal selection rather than merely not offering it.
	t.is_true(not engine.submit_action(offered.with_choices({"target_ids": [theirs.id]})),
		"submitting the opponent's monster as the target is rejected")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "and it is still on their field")


static func _test_a_face_down_monster_is_not_a_legal_target(t: TestCase) -> void:
	t.start("'face-up' excludes a face-down Defense Position monster you control")
	var d := _board(t, 7503)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var up := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Face Up"))
	var down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face Down"), Enums.Position.FACE_DOWN_DEFENSE)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(up.id), "the face-up monster is a candidate")
	t.is_true(not candidates.has(down.id), "the face-down one is not")
	t.is_true(not engine.submit_action(offered.with_choices({"target_ids": [down.id]})),
		"and selecting it is rejected")


static func _test_spell_traps_are_not_legal_targets(t: TestCase) -> void:
	t.start("'1 face-up MONSTER' does not reach a Spell/Trap the activator controls")
	var d := _board(t, 7504)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))
	var backrow := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("My Other Trap"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(mine.id), "the monster is a candidate")
	t.is_true(not candidates.has(backrow.id), "the Spell/Trap is not")
	t.is_true(not candidates.has(imt.id), "and neither is the card itself")


static func _test_it_cannot_be_activated_with_no_face_up_monster(t: TestCase) -> void:
	t.start("with no face-up monster you control there is no legal target, so the "
		+ "activation is not offered at all (RULES_SPEC.md 10)")
	var d := _board(t, 7505)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	# The opponent has a monster; the activator does not.
	TestFixtures.give_monster_on_field(engine, 1, TestFixtures.monster("Theirs"))
	t.is_true(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id) == null,
		"not offered when the activator controls no monster")

	# A face-down monster is still not a face-up one.
	TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine Face Down"),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_true(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id) == null,
		"and not offered when the only monster you control is face-down")

	# One face-up monster makes it legal, which proves the two negatives above were about
	# the candidate set and not about something else being wrong with the board.
	TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine Face Up"))
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id),
		"one face-up monster is enough to make it activatable")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_it_banishes_the_target_and_schedules_the_return(t: TestCase) -> void:
	t.start("it banishes the target and registers a temporary-banish lease describing the "
		+ "return")
	var d := _board(t, 7506)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1800, 1000))

	t.is_true(TestFixtures.activate_card(engine, 0, imt, [mine.id]),
		"the Trap is activated targeting the player's own monster")

	t.eq(mine.zone, Enums.Zone.BANISHED, "the monster is banished")
	t.is_true(state.player(0).banished.has(mine), "in its owner's Banished zone")
	t.is_true(mine.is_face_up(), "face-up, so it is public information [S1 p.53]")
	t.eq(state.player(0).monsters().size(), 0, "and off the field")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_BANISHED, mine.id), 1,
		"exactly one banish event")
	t.is_true(state.is_temporarily_banished(mine.id), "a return is scheduled")
	var lease: Dictionary = state.banish_leases_for(mine.id)[0]
	t.eq(int(lease["source_id"]), imt.id, "the lease names this card as its source")
	t.eq(lease["duration"], Enums.BanishDuration.UNTIL_END_PHASE,
		"with the duration the text states")
	t.eq(imt.zone, Enums.Zone.GRAVEYARD, "the Normal Trap goes to the Graveyard after")
	# The lease outlives the card that created it — the state owns the return, not the card.
	t.is_true(state.is_temporarily_banished(mine.id),
		"and the schedule survives the Trap leaving the field")


static func _test_it_is_not_a_destruction_and_not_a_send_to_gy(t: TestCase) -> void:
	t.start("the banish is neither a destruction nor a send to the Graveyard, which is the "
		+ "whole reason the card protects a monster [S1 p.53]")
	var d := _board(t, 7507)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))

	TestFixtures.activate_card(engine, 0, imt, [mine.id])

	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, mine.id), 0,
		"no destruction event for the banished monster")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, mine.id), 0,
		"and no send-to-GY event")
	t.eq(mine.last_move_reason, Enums.MoveReason.BANISHED,
		"the recorded reason is BANISHED and nothing else")
	t.is_true(not engine.state.player(0).graveyard.has(mine),
		"the monster is not in the Graveyard")


static func _test_the_monster_comes_back_in_the_end_phase(t: TestCase) -> void:
	t.start("the monster returns to the field when the End Phase is entered, under its "
		+ "owner's control, and the lease is discharged")
	var d := _board(t, 7508)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1800, 1000))

	TestFixtures.activate_card(engine, 0, imt, [mine.id])
	t.eq(mine.zone, Enums.Zone.BANISHED, "away for now")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)

	t.eq(state.phase, Enums.Phase.END, "the End Phase has been entered")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster is back on the field")
	t.eq(mine.controller_id, 0, "under its owner's control")
	t.is_true(state.player(0).monsters().has(mine), "in that player's Monster Zone")
	t.eq(mine.last_move_reason, Enums.MoveReason.RETURNED_FROM_BANISHMENT,
		"recorded with the return's own move reason")
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT, mine.id), 1,
		"exactly one return event")
	t.is_true(not state.is_temporarily_banished(mine.id), "the lease is discharged")
	t.eq(state.banish_leases.size(), 0, "and nothing is left scheduled")


static func _test_the_return_is_not_a_summon(t: TestCase) -> void:
	t.start("the monster is NOT Summoned on the way back, so no successful-Summon trigger "
		+ "sees it and a Summon-negating card has nothing to answer (CARD_RULINGS.md R30)")
	var d := _board(t, 7509)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))
	# A real summon-negating card sitting ready on the opponent's field.
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.summon_negator("Vigilance"))

	TestFixtures.activate_card(engine, 0, imt, [mine.id])
	var normal_before := TestFixtures.count_events(engine,
		GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED)
	var special_before := TestFixtures.count_events(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED)
	var declared_before := TestFixtures.count_events(engine,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED)
	var flip_before := TestFixtures.count_events(engine,
		GameEvent.Kind.CARD_FLIPPED_FACE_UP)

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)

	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster is back")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED),
		normal_before, "no Normal Summon happened")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED),
		special_before, "no Special Summon happened")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED),
		declared_before, "not even a Special Summon declaration")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP),
		flip_before, "and no flip-face-up, so no FLIP effect may fire")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 0,
		"the waiting summon negator was never given anything to negate")
	t.is_true(not mine.properly_special_summoned,
		"and the monster is not marked as properly Special Summoned")


static func _test_the_position_is_preserved_across_the_round_trip(t: TestCase) -> void:
	t.start("the monster comes back in the battle position it was banished in, for each of "
		+ "the two positions the card can target (CARD_RULINGS.md R30)")
	var seed_value := 7510
	for entry in [Enums.Position.FACE_UP_ATTACK, Enums.Position.FACE_UP_DEFENSE]:
		var position: Enums.Position = entry
		seed_value += 1
		var d := _board(t, seed_value)
		var engine: DuelEngine = d["engine"]
		var imt: CardInstance = d["imt"]
		var mine := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Mine"), position)

		TestFixtures.activate_card(engine, 0, imt, [mine.id])
		TestFixtures.advance_to_phase(engine, Enums.Phase.END)

		t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster came back")
		t.eq(mine.position, position, "in the position it left in, not a default one")


static func _test_it_rescues_a_monster_from_a_destruction_effect(t: TestCase) -> void:
	t.start("the card does the job it exists for: a monster banished in response to a "
		+ "destruction effect is not on the field when that effect resolves, and comes back")
	# Player 1 is the TURN PLAYER here, deliberately: `get_legal_actions(pid)` returns nothing
	# unless the engine is open AND `pid` is the turn player, so an interferer meant to fire
	# in an open game state has to belong to them. Player 0 then answers through a response
	# window, which is the real shape of this play.
	var d := TestFixtures.new_duel(7520, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var imt := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Rescued", 4, 1900, 1000))
	var killer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Executioner", mine, "destroy"))

	var kill = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, killer.id)
	t.not_null(kill, "the opponent's destruction effect is offered in the open game state")
	t.is_true(engine.submit_action(kill), "the destruction effect is Chain Link 1")
	var save = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(save, "the Trap may be activated in response")
	t.is_true(engine.submit_action(save.with_choices({"target_ids": [mine.id]})),
		"it is Chain Link 2, targeting the threatened monster")
	TestFixtures.pass_until_open(engine)

	# Chain Link 2 resolves first: the monster is banished before the destruction resolves.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, mine.id), 0,
		"the monster was never destroyed — it was not on the field to be destroyed")
	t.eq(mine.zone, Enums.Zone.BANISHED, "it is banished")
	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "and it comes back at the End Phase, rescued")


static func _test_the_monster_comes_back_without_its_equips_or_modifiers(
		t: TestCase) -> void:
	t.start("the monster genuinely left the field, so it comes back as a fresh instance: "
		+ "its Equip Cards died and its counters and modifiers are gone")
	var d := _board(t, 7530)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1000, 1000))
	var equip := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.equip_spell("An Equip", 500))
	t.is_true(state.equip_to(equip, mine, equip.id), "the equip is attached")
	state.place_counters(mine, "Spell Counter", 2, imt.id)

	TestFixtures.activate_card(engine, 0, imt, [mine.id])
	t.eq(equip.zone, Enums.Zone.GRAVEYARD,
		"the Equip Card was destroyed the moment its host was banished [S1 p.29, p.55]")
	t.eq(equip.last_move_reason, Enums.MoveReason.DESTROYED_BY_RULE,
		"as a RULES destruction")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)

	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster is back")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "its Equip Card does NOT come back with it")
	t.eq(mine.equipped_card_ids.size(), 0, "nothing is equipped to it")
	t.eq(mine.counters.size(), 0, "its counters are gone")
	t.eq(mine.current_atk(), 1000, "and its ATK is the printed value")


# ---------------------------------------------------------------------------
# Resolution-time re-checks. RULES_SPEC.md 10, CARD_RULINGS.md R29.
# ---------------------------------------------------------------------------

static func _test_a_target_that_left_the_field_before_resolution(t: TestCase) -> void:
	t.start("a target that left the field before resolution is dropped, never chased, and "
		+ "nothing is banished")
	var d := _board(t, 7540)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))

	var ctx := _ctx(t, engine, imt, mine)
	engine.state.move_card(mine, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	var def := _card_def(t)
	var clause: EffectDef = def.effects[0]
	clause.resolve.call(ctx)

	t.eq(mine.zone, Enums.Zone.GRAVEYARD, "the target is left exactly where it went")
	t.eq(engine.state.banish_leases.size(), 0, "nothing was scheduled to return")
	t.eq(engine.state.player(0).banished.size(), 0, "and nothing was banished")


static func _test_a_target_the_opponent_took_control_of_before_resolution(
		t: TestCase) -> void:
	t.start("'you control' is re-checked at resolution: a target the opponent has taken "
		+ "control of is no longer a monster YOU control (CARD_RULINGS.md R29)")
	var d := _board(t, 7541)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))

	var ctx := _ctx(t, engine, imt, mine)
	t.is_true(state.change_control(mine, 1, imt.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "the opponent takes control in response")
	t.eq(mine.controller_id, 1, "they control it")
	t.eq(mine.owner_id, 0, "though player 0 still owns it")

	var def := _card_def(t)
	var clause: EffectDef = def.effects[0]
	clause.resolve.call(ctx)

	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster is not banished")
	t.eq(mine.controller_id, 1, "and is still under the opponent's control")
	t.eq(state.banish_leases.size(), 0, "nothing was scheduled")
	# Ownership is never what the clause asks about — the mirror of R29.
	t.eq(mine.owner_id, 0,
		"ownership was never consulted: the activator owns it and still cannot use it")


static func _test_a_target_flipped_face_down_before_resolution(t: TestCase) -> void:
	t.start("'face-up' is re-checked at resolution: a target flipped face-down in response "
		+ "is no longer what was targeted")
	var d := _board(t, 7542)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))

	var ctx := _ctx(t, engine, imt, mine)
	mine.position = Enums.Position.FACE_DOWN_DEFENSE
	mine.on_flipped_face_down()

	var def := _card_def(t)
	var clause: EffectDef = def.effects[0]
	clause.resolve.call(ctx)

	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster is not banished")
	t.eq(engine.state.banish_leases.size(), 0, "and nothing was scheduled")

	# The positive control: the same context on a face-up monster DOES banish it, which
	# proves the negative above was caused by the flip and not by a broken context.
	mine.position = Enums.Position.FACE_UP_ATTACK
	clause.resolve.call(_ctx(t, engine, imt, mine))
	t.eq(mine.zone, Enums.Zone.BANISHED, "face-up again, it is banished")


# ---------------------------------------------------------------------------
# Negation and chain behaviour
# ---------------------------------------------------------------------------

static func _test_a_negated_activation_banishes_nothing(t: TestCase) -> void:
	t.start("a negated ACTIVATION banishes nothing and schedules no return")
	var d := _board(t, 7550)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"it is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the Counter Trap is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"the activation was negated")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster stayed on the field")
	t.eq(engine.state.banish_leases.size(), 0, "and no return was scheduled")
	t.eq(imt.zone, Enums.Zone.GRAVEYARD, "the negated Trap is destroyed and in the GY")


static func _test_a_negated_effect_banishes_nothing(t: TestCase) -> void:
	t.start("a negated EFFECT banishes nothing either — the activation happened, only the "
		+ "effect did not apply")
	var d := _board(t, 7551)
	var engine: DuelEngine = d["engine"]
	var imt: CardInstance = d["imt"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silencer"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"it is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the effect negator is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the effect was negated")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the monster stayed on the field")
	t.eq(engine.state.banish_leases.size(), 0, "and no return was scheduled")


static func _test_it_can_be_activated_in_a_response_window(t: TestCase) -> void:
	t.start("being Spell Speed 2, it can be activated in a response window on the "
		+ "opponent's turn, as Chain Link 2")
	var d := TestFixtures.new_duel(7560, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	# Player 0 is NOT the turn player here.
	var imt := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var mine := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Mine"))
	# A plain `trap()` CardDef carries no effect and so is not activatable at all; the Chain
	# has to be opened by something the engine will actually offer.
	var log: Array = []
	var opener := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(TestFixtures.trap("Their Opener"),
			TestFixtures.card_activation("their_opener", Enums.SpellSpeed.SS2, log)))

	var start = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, opener.id)
	t.not_null(start, "the turn player opens a Chain")
	t.is_true(engine.submit_action(start), "Chain Link 1 is theirs")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, imt.id)
	t.not_null(response, "the Trap is offered in the response window")
	t.is_true(engine.submit_action(response.with_choices({"target_ids": [mine.id]})),
		"and is activated as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(mine.zone, Enums.Zone.BANISHED, "the monster is banished on the opponent's turn")
	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE,
		"and returns in THIS turn's End Phase — the opponent's — not the activator's")


# ---------------------------------------------------------------------------
# Determinism. RULES_SPEC.md 13.
# ---------------------------------------------------------------------------

static func _test_the_round_trip_is_replay_deterministic(t: TestCase) -> void:
	t.start("the same seed and the same actions produce the same banish/return event "
		+ "sequence, twice")
	var runs: Array = []
	for run in range(2):
		var d := _board(t, 7570)
		var engine: DuelEngine = d["engine"]
		var imt: CardInstance = d["imt"]
		var mine := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Mine"), Enums.Position.FACE_UP_DEFENSE)
		TestFixtures.activate_card(engine, 0, imt, [mine.id])
		TestFixtures.advance_to_phase(engine, Enums.Phase.END)

		var trace: Array = []
		for entry in engine.state.events:
			var ev: GameEvent = entry
			if ev.kind == GameEvent.Kind.CARD_BANISHED \
					or ev.kind == GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT:
				trace.append("%d:%s" % [ev.kind, str(ev.data.get("card_name", ""))])
		runs.append(trace)

	t.eq(runs[0].size(), 2, "one banish and one return")
	t.eq(runs[0], runs[1], "and two identically seeded runs are identical")

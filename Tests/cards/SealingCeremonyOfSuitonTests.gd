class_name SealingCeremonyOfSuitonTests
extends RefCounted

## Per-card suite for `Sealing Ceremony of Suiton` — Continuous Trap.
##
##   "Once per turn: You can send 1 WATER monster from your hand to the GY, then target 1
##    card in your opponent's GY; banish that target."
##
## The card exercises the same cost/effect split as `Kaibaman` and `One for One`, but with
## a banish as the EFFECT rather than as the cost — which is the mirror image of
## `Castle of Dragon Souls`, where the banish is the cost. Keeping the two apart is the
## point of having `pay_banish_cost` and `banish_target` as separate primitives.

const CARD_UNDER_TEST := "Sealing Ceremony of Suiton"

const BANISH_ID := "send_water_banish_from_opponent_gy"


static func run() -> TestCase:
	var t := TestCase.new("SealingCeremonyOfSuitonTests")
	_test_clause_shape(t)
	_test_sends_and_banishes(t)
	_test_a_send_is_not_a_discard(t)
	_test_any_card_in_their_graveyard(t)
	_test_only_the_opponents_graveyard(t)
	_test_the_cost_filter(t)
	_test_the_cost_survives_negation(t)
	_test_a_target_that_left_the_graveyard(t)
	_test_once_per_turn(t)
	_test_outside_the_main_phases(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Face-up Suiton on the field, one WATER monster in hand to pay with, and one card in the
## opponent's Graveyard to banish.
static func _armed_board(seed_value: int) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, trap)
	d["trap"] = trap
	d["water"] = TestFixtures.give_to_hand(engine, 0, _card("Judge of the Ice Barrier"))
	d["victim"] = TestFixtures.give(engine, 1, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("two EffectDefs: the Trap's own activation, which has no printed effect, and "
		+ "the once-per-turn clause")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.CONTINUOUS_TRAP, "a Continuous Trap")
	t.eq(def.effects.size(), 2, "activation + the printed clause")

	var activation: EffectDef = def.effects[0]
	t.eq(activation.effect_type, Enums.EffectType.CARD_ACTIVATION, "the card's activation")
	t.is_false(activation.targets,
		"the ACTIVATION does not target — the printed clause does, later")
	t.is_false(activation.pay_cost.is_valid(), "and it costs nothing to activate")

	var banish: EffectDef = def.effects[1]
	t.eq(banish.effect_type, Enums.EffectType.IGNITION,
		"no '(Quick Effect)': an Ignition Effect, Spell Speed 1")
	t.eq(banish.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.is_false(ActivationRules.is_fast_effect(banish),
		"so it is never offered in a response window [S1 p.44]")
	t.eq(banish.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"its controller's own Main Phases")
	t.is_true(banish.once_per_turn_instance, "'Once per turn' on this copy")
	t.is_true(banish.targets, "'then TARGET 1 card'")
	t.eq(banish.target_count_min, 1, "exactly one")
	t.is_true(banish.pay_cost.is_valid(), "the send is a real COST")
	t.is_true(banish.can_pay_cost.is_valid(),
		"and it is checked BEFORE the activation is offered")


# ---------------------------------------------------------------------------
# The effect
# ---------------------------------------------------------------------------

static func _test_sends_and_banishes(t: TestCase) -> void:
	t.start("the WATER monster goes to your Graveyard and the target leaves theirs for "
		+ "banishment")
	var d := _armed_board(9401)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var water: CardInstance = d["water"]
	var victim: CardInstance = d["victim"]

	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Continuous Trap stays face-up on the field [S1 p.29-30]")
	t.is_true(TestFixtures.activate_effect(engine, 0, trap, BANISH_ID, [victim.id]),
		"the effect is activated, targeting the card in their Graveyard")

	t.eq(water.zone, Enums.Zone.GRAVEYARD, "the WATER monster left your hand")
	t.eq(water.owner_id, 0, "into YOUR Graveyard — the Graveyard is owner-bound [S1 p.52]")
	t.eq(victim.zone, Enums.Zone.BANISHED, "and the target is banished")
	t.eq(victim.owner_id, 1, "still owned by the opponent")
	t.eq(victim.last_move_reason, Enums.MoveReason.BANISHED, "with the BANISHED reason")
	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE, "the Trap is still on the field afterwards")


static func _test_a_send_is_not_a_discard(t: TestCase) -> void:
	t.start("'SEND … from your hand to the GY' is not a discard, and banishing is not "
		+ "sending to the GY [S1 p.52-53]")
	var d := _armed_board(9402)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var water: CardInstance = d["water"]
	var victim: CardInstance = d["victim"]

	var sent_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)
	t.is_true(TestFixtures.activate_effect(engine, 0, trap, BANISH_ID, [victim.id]), "ok")

	t.eq(water.last_move_reason, Enums.MoveReason.SENT_AS_COST,
		"the cost payment is SENT_AS_COST, explicitly not DISCARDED")
	t.ne(water.last_move_reason, Enums.MoveReason.DISCARDED, "definitely not a discard")
	t.is_true(Enums.is_sent_to_gy(Enums.MoveReason.SENT_AS_COST),
		"it still counts as 'sent to the Graveyard'")
	t.is_false(Enums.is_destruction(Enums.MoveReason.SENT_AS_COST),
		"and it is not a destruction")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY), sent_before + 1,
		"exactly one card was sent to a Graveyard — the banished one was not")


static func _test_any_card_in_their_graveyard(t: TestCase) -> void:
	t.start("'1 CARD in your opponent's GY' — a Spell and a Trap are legal targets too, "
		+ "not just monsters")
	var d := _armed_board(9403)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var victim: CardInstance = d["victim"]

	var their_spell := TestFixtures.give(engine, 1, _card("Monster Reborn"),
		Enums.Zone.GRAVEYARD)
	var their_trap := TestFixtures.give(engine, 1, _card("Birthright"), Enums.Zone.GRAVEYARD)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID)
	t.not_null(action, "the effect is offered")
	t.is_true(action.target_candidates.has(victim.id), "their monster is a target")
	t.is_true(action.target_candidates.has(their_spell.id), "so is their Spell")
	t.is_true(action.target_candidates.has(their_trap.id), "and their Trap")
	t.eq(action.target_candidates.size(), 3, "every card in their Graveyard, and only those")

	t.is_true(TestFixtures.activate_effect(engine, 0, trap, BANISH_ID, [their_spell.id]),
		"the Spell is banished")
	t.eq(their_spell.zone, Enums.Zone.BANISHED, "it left their Graveyard")


static func _test_only_the_opponents_graveyard(t: TestCase) -> void:
	t.start("'in your OPPONENT'S GY' — your own Graveyard is out of reach, with a positive "
		+ "control so the negative is not vacuous")
	var d := _main_phase_duel(9404)
	var engine: DuelEngine = d["engine"]
	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, trap)
	TestFixtures.give_to_hand(engine, 0, _card("Judge of the Ice Barrier"))

	var mine := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"a card in YOUR Graveyard is not a legal target, so there is nothing to activate on")

	var theirs := TestFixtures.give(engine, 1, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID)
	t.not_null(action, "a card in THEIR Graveyard enables it")
	t.is_true(action.target_candidates.has(theirs.id), "and theirs is the candidate")
	t.is_false(action.target_candidates.has(mine.id), "yours still is not")
	t.is_false(engine.submit_action(action.with_choices({"target_ids": [mine.id]})),
		"a hand-built activation on your own card is rejected")
	t.eq(mine.zone, Enums.Zone.GRAVEYARD, "and it stays where it was")


static func _test_the_cost_filter(t: TestCase) -> void:
	t.start("'1 WATER monster from your HAND' — the Attribute, the card type and the zone")
	var d := _main_phase_duel(9405)
	var engine: DuelEngine = d["engine"]
	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, trap)
	TestFixtures.give(engine, 1, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"with nothing to send, the cost is unpayable and the effect is not offered")

	TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"an EARTH monster in hand does not qualify")

	TestFixtures.give(engine, 0, _card("Crystal Seer"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"and a WATER monster in your GRAVEYARD is not 'from your hand'")

	var water := TestFixtures.give_to_hand(engine, 0, _card("Eria the Water Charmer"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"a WATER monster in hand enables it — the positive control")
	t.eq(water.zone, Enums.Zone.HAND, "and it has only been counted, not paid")


static func _test_the_cost_survives_negation(t: TestCase) -> void:
	t.start("the send happens at ACTIVATION, before any response window, and is not "
		+ "refunded when the target is removed")
	var d := _armed_board(9406)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var water: CardInstance = d["water"]
	var victim: CardInstance = d["victim"]

	# A Spell Speed 2 answer that moves the target out of the Graveyard.
	var thief_def := TestFixtures.trap("Test Thief")
	var thief_effect := EffectDef.new("interfere",
		"Test: banish one specific card from a Graveyard.")
	thief_effect.of_type(Enums.EffectType.CARD_ACTIVATION)
	thief_effect.spell_speed = Enums.SpellSpeed.SS2
	thief_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	thief_effect.resolve = func(ctx: EffectContext) -> void:
		ctx.state.move_card(victim, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED,
			{"source_id": ctx.source.id})
	var thief := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(thief_def, thief_effect), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"and activated as Chain Link 1")
	t.eq(water.zone, Enums.Zone.GRAVEYARD,
		"the cost is ALREADY paid, before the opponent could respond")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and removes the target as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(water.zone, Enums.Zone.GRAVEYARD, "the cost stays paid — a cost is never refunded")
	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"and the Continuous Trap is still on the field")


static func _test_a_target_that_left_the_graveyard(t: TestCase) -> void:
	t.start("a target that is no longer in the Graveyard at RESOLUTION is not chased into "
		+ "its new zone (master prompt 44)")
	var d := _armed_board(9407)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var victim: CardInstance = d["victim"]

	# Chain Link 2 returns the target to its owner's hand instead.
	var thief_def := TestFixtures.trap("Test Recovery")
	var thief_effect := EffectDef.new("interfere", "Test: return one card to the hand.")
	thief_effect.of_type(Enums.EffectType.CARD_ACTIVATION)
	thief_effect.spell_speed = Enums.SpellSpeed.SS2
	thief_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	thief_effect.resolve = func(ctx: EffectContext) -> void:
		ctx.state.move_card(victim, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND,
			{"source_id": ctx.source.id})
	var thief := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(thief_def, thief_effect), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})), "ok")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent responds")
	t.is_true(engine.submit_action(response), "returning the target to their hand")
	TestFixtures.pass_until_open(engine)

	t.eq(victim.zone, Enums.Zone.HAND,
		"Chain Link 2 resolved first and moved the target [S1 p.46-47]")
	t.ne(victim.zone, Enums.Zone.BANISHED,
		"and Suiton did NOT reach into the hand to banish it")


static func _test_once_per_turn(t: TestCase) -> void:
	t.start("'Once per turn' is per COPY: a second copy has its own use, and the use "
		+ "returns next turn")
	var d := _armed_board(9408)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var victim: CardInstance = d["victim"]

	# Enough material for a second use, so only the restriction can block it.
	TestFixtures.give_to_hand(engine, 0, _card("Crystal Seer"))
	var second_victim := TestFixtures.give(engine, 1, _card("Luster Dragon"),
		Enums.Zone.GRAVEYARD)

	t.is_true(TestFixtures.activate_effect(engine, 0, trap, BANISH_ID, [victim.id]),
		"the first use resolves")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"the same copy cannot be used again this turn")

	var second := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, second), "a SECOND copy is activated")
	t.is_true(TestFixtures.activate_effect(engine, 0, second, BANISH_ID,
		[second_victim.id]),
		"and it has its own use — the restriction is on the copy, not on the name")
	t.eq(second_victim.zone, Enums.Zone.BANISHED, "which banishes a second card")

	t.is_true(TestFixtures.end_turn(engine), "the opponent takes a turn")
	t.is_true(TestFixtures.end_turn(engine), "and play returns")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1), "to Main Phase 1")
	TestFixtures.give_to_hand(engine, 0, _card("Eria the Water Charmer"))
	TestFixtures.give(engine, 1, _card("Alexandrite Dragon"), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"the first copy's use has returned")


static func _test_outside_the_main_phases(t: TestCase) -> void:
	t.start("an Ignition Effect belongs to the Main Phases [S1 p.10]")
	var d := TestFixtures.battle_duel(9409)
	var engine: DuelEngine = d["engine"]
	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, trap)
	TestFixtures.give_to_hand(engine, 0, _card("Judge of the Ice Barrier"))
	TestFixtures.give(engine, 1, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)

	t.eq(engine.state.phase, Enums.Phase.BATTLE, "the duel is in the Battle Phase")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"the effect is not offered there")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"the turn player moves to Main Phase 2")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, trap.id, BANISH_ID),
		"and it is available again")

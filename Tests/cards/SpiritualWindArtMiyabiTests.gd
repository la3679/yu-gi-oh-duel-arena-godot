class_name SpiritualWindArtMiyabiTests
extends RefCounted

## `Spiritual Wind Art - Miyabi` — "Tribute 1 WIND monster, then target 1 card your opponent
## controls; place that opponent's card on the bottom of the Deck."
##
## The mirror of `Phoenix Wing Wind Blast`, and this suite deliberately asserts the two
## differences hardest: a TRIBUTE cost rather than a discard, and the BOTTOM of the Deck
## rather than the top.

const CARD_UNDER_TEST := "Spiritual Wind Art - Miyabi"


static func run() -> TestCase:
	var t := TestCase.new("SpiritualWindArtMiyabiTests")
	_test_the_clause_shape(t)
	_test_it_places_the_target_on_the_bottom_of_the_deck(t)
	_test_the_tribute_is_a_cost_paid_at_activation(t)
	_test_the_player_chooses_which_wind_monster(t)
	_test_a_face_down_wind_monster_is_a_legal_tribute(t)
	_test_a_wind_trap_monster_is_a_legal_tribute(t)
	_test_it_cannot_be_activated_without_a_wind_monster(t)
	_test_it_cannot_be_activated_with_an_empty_opponent_field(t)
	_test_only_the_opponents_cards_are_legal_targets(t)
	_test_a_set_spell_trap_is_a_legal_target(t)
	_test_nothing_is_shuffled_and_revealed_to_is_kept(t)
	_test_it_goes_to_the_owners_deck(t)
	_test_a_target_that_left_the_field(t)
	_test_a_target_that_changed_control(t)
	_test_the_cost_is_not_refunded_when_the_activation_is_negated(t)
	_test_the_cost_is_not_refunded_when_the_effect_is_negated(t)
	_test_the_tribute_is_not_a_destruction(t)
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


static func _wind(name: String) -> CardDef:
	return TestFixtures.monster(name, 4, 1000, 1000, "WIND")


## A duel in Main Phase 1 with the Trap Set on player 0's field and one WIND monster on
## player 0's field to pay the Tribute with.
static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["miyabi"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	d["wind"] = TestFixtures.give_monster_on_field(engine, 0, _wind("My Wind Monster"))
	return d


static func _bottom_of(engine: DuelEngine, pid: int) -> CardInstance:
	var deck: Array = engine.state.player(pid).deck
	return deck[deck.size() - 1] if not deck.is_empty() else null


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal Trap card activation, Spell Speed 2, targeting exactly 1 "
		+ "card, with a Tribute COST")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.TRAP, "it is a Trap")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP, "and specifically a NORMAL Trap")
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
	t.is_true(clause.can_pay_cost.is_valid(), "it declares a cost check")
	t.is_true(clause.pay_cost.is_valid(), "and a cost payment, so the Tribute is a COST")
	t.is_true(clause.clause_text.contains("Tribute 1 WIND monster"),
		"the clause quotes the official cost")
	t.is_true(clause.clause_text.contains("on the bottom of the Deck"),
		"and quotes the BOTTOM of the Deck specifically")
	t.is_true(clause.clause_text.contains("that opponent's card"),
		"with the current official wording, not the older 'that card' (CARD_RULINGS §2.1)")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_it_places_the_target_on_the_bottom_of_the_deck(t: TestCase) -> void:
	t.start("it places the opponent's monster on the BOTTOM of the opponent's Deck — the "
		+ "opposite end from Phoenix Wing Wind Blast")
	var d := _board(t, 7501)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	var deck_before: int = engine.state.player(1).deck.size()
	var old_top: CardInstance = engine.state.player(1).deck[0]
	var old_bottom := _bottom_of(engine, 1)

	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"the Trap is activated targeting the opponent's monster")
	t.eq(victim.zone, Enums.Zone.DECK, "the monster is in a Deck")
	t.eq(engine.state.player(1).deck.size(), deck_before + 1, "the OPPONENT's Deck grew by 1")
	t.eq(_bottom_of(engine, 1), victim, "and the card is the BOTTOM card of that Deck")
	t.ne(engine.state.player(1).deck[0], victim, "it is emphatically NOT on top")
	t.eq(engine.state.player(1).deck[0], old_top, "the top card is unchanged")
	t.ne(_bottom_of(engine, 1), old_bottom, "and it displaced the previous bottom card")
	t.eq(victim.last_move_reason, Enums.MoveReason.RETURNED_TO_DECK_BOTTOM,
		"recorded as a placement on the BOTTOM of the Deck")
	t.eq(engine.state.player(1).monsters().size(), 0, "their field is empty")
	t.eq(miyabi.zone, Enums.Zone.GRAVEYARD, "the Normal Trap goes to the Graveyard after")


static func _test_the_tribute_is_a_cost_paid_at_activation(t: TestCase) -> void:
	t.start("the Tribute is a COST: it is paid at ACTIVATION, before the Chain Link "
		+ "resolves, and the Tributed monster reaches the Graveyard as a TRIBUTE")
	var d := _board(t, 7502)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	var order_log: Array = []
	var spacer := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.with_effect(
		TestFixtures.trap("Spacer"),
		TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")

	t.eq(wind.zone, Enums.Zone.GRAVEYARD,
		"the Tributed monster is ALREADY in the Graveyard, before any resolution")
	t.eq(wind.last_move_reason, Enums.MoveReason.TRIBUTED,
		"with the TRIBUTED reason — a Tribute is a send to the GY, not a destruction "
		+ "[S1 p.53]")
	t.eq(engine.state.player(0).monsters().size(), 0, "the player's own field is now empty")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "while the target has NOT moved yet")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, spacer.id)
	t.not_null(response, "a response window is genuinely open")
	t.is_true(engine.submit_action(response), "the spacer is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(victim.zone, Enums.Zone.DECK, "and only then does the target reach the Deck")


static func _test_the_player_chooses_which_wind_monster(t: TestCase) -> void:
	t.start("with more than one WIND monster the player chooses which to Tribute, and the "
		+ "choice is a logged duel input")
	var d := _board(t, 7503)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var first: CardInstance = d["wind"]
	var second := TestFixtures.give_monster_on_field(engine, 0, _wind("Second Wind"))
	var p0: ScriptedController = d["p0"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	# Two candidates, so a real question is asked — `choose_n` asks nothing when the number
	# of candidates equals the number required.
	p0.queue_for(Enums.DecisionKind.CHOOSE_TRIBUTES, [second.id])

	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"the Trap is activated")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(second.zone, Enums.Zone.GRAVEYARD, "the CHOSEN monster was Tributed")
	t.eq(first.zone, Enums.Zone.MONSTER_ZONE, "the other one is untouched on the field")
	t.eq(victim.zone, Enums.Zone.DECK, "and the effect still resolved")


static func _test_a_face_down_wind_monster_is_a_legal_tribute(t: TestCase) -> void:
	t.start("a face-DOWN WIND monster you control is a legal Tribute: you know what your "
		+ "own Set monster is")
	var d := TestFixtures.new_duel(7504, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var miyabi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var hidden := TestFixtures.give_monster_on_field(engine, 0, _wind("Set Wind"),
		Enums.Position.FACE_DOWN_DEFENSE)
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	t.is_false(hidden.is_face_up(), "the only WIND monster is face-down")

	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"the Trap is still activatable and is activated")
	t.eq(hidden.zone, Enums.Zone.GRAVEYARD, "the face-down monster paid the Tribute")
	t.eq(hidden.last_move_reason, Enums.MoveReason.TRIBUTED, "as a Tribute")
	t.eq(victim.zone, Enums.Zone.DECK, "and the effect resolved")


## Phase 6 unit 4. On the FIELD the Attribute is read with `current_attribute()` — a Trap
## Monster carries it in its runtime identity and its printed `CardDef` carries none — exactly
## as `Kurenai` and `Aoi` read it (R33, `EffectPrimitives.field_monster_of_attribute()`).
## Never live in the V1 pool; written, and seen to FAIL, before the one-line fix.
static func _test_a_wind_trap_monster_is_a_legal_tribute(t: TestCase) -> void:
	t.start("a WIND Trap Monster is a legal Tribute: its Attribute lives in its RUNTIME "
		+ "identity, which is the reader the field needs")
	var d := TestFixtures.new_duel(7519, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var miyabi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var veil := TestFixtures.give(engine, 0, TestFixtures.trap_monster("Wind Veil",
		"Winged Beast", "WIND"), Enums.Zone.GRAVEYARD)
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id),
		"control: with the WIND Trap still in the Graveyard there is nothing to Tribute")
	t.is_true(TestFixtures.activate_effect(engine, 0, veil, "summon_self_as_trap_monster"),
		"the Trap Monster Summons itself out of the Graveyard")
	t.is_true(veil.is_monster(), "it is now a monster")
	t.eq(veil.current_attribute(), "WIND", "whose runtime Attribute is WIND")
	t.eq(veil.definition.attribute, "",
		"while the printed CardDef is blank — which is what makes this test bite")

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id),
		"so it IS a legal Tribute for the WIND cost, and the Trap is offered")
	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"and the Trap is activated targeting the opponent's monster")
	t.eq(veil.zone, Enums.Zone.GRAVEYARD, "the Trap Monster was Tributed")
	t.eq(_bottom_of(engine, 1), victim, "and the target is on the bottom of its owner's Deck")


static func _test_it_goes_to_the_owners_deck(t: TestCase) -> void:
	t.start("the card goes to its OWNER's Deck even when the opponent had taken control of "
		+ "it, and no stale control state is left [S1 p.52]")
	var d := _board(t, 7505)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var lender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Lender", 3, 500, 500))
	var borrowed := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Borrowed", 4, 1500, 1000))
	t.is_true(engine.state.change_control(borrowed, 1, lender.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "player 1 takes control of it")
	t.eq(borrowed.owner_id, 0, "player 0 still OWNS it")

	var p0_deck_before: int = engine.state.player(0).deck.size()
	var p1_deck_before: int = engine.state.player(1).deck.size()
	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [borrowed.id]),
		"the Trap is activated on the borrowed monster")
	t.eq(engine.state.player(0).deck.size(), p0_deck_before + 1,
		"its OWNER's Deck grew [S1 p.52]")
	t.eq(engine.state.player(1).deck.size(), p1_deck_before,
		"the controller's Deck did not")
	t.eq(_bottom_of(engine, 0), borrowed, "it is on the BOTTOM of its owner's Deck")
	t.eq(borrowed.controller_id, 0, "and the controller is its owner again")
	t.eq(engine.state.control_leases_for(borrowed.id).size(), 0,
		"no stale control lease is left behind")


static func _test_nothing_is_shuffled_and_revealed_to_is_kept(t: TestCase) -> void:
	t.start("the text says 'place', not 'shuffle', so revealed_to survives and the rest of "
		+ "the Deck keeps its order (design decision 11)")
	var d := _board(t, 7506)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Known Card", 4, 1600, 1200))
	engine.state.reveal(victim, [0, 1])
	var order_before: Array = []
	for entry in engine.state.player(1).deck:
		order_before.append((entry as CardInstance).id)

	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"the Trap is activated")
	t.is_true(victim.revealed_to.has(0), "the card's identity is still known to player 0")
	t.is_true(victim.revealed_to.has(1), "and to player 1 — no shuffle cleared it")
	var order_after: Array = []
	for entry in engine.state.player(1).deck:
		order_after.append((entry as CardInstance).id)
	t.eq(order_after.slice(0, order_after.size() - 1), order_before,
		"the rest of the Deck is untouched and in its original order")


# ---------------------------------------------------------------------------
# Negatives, where the value is
# ---------------------------------------------------------------------------

static func _test_it_cannot_be_activated_without_a_wind_monster(t: TestCase) -> void:
	t.start("without a WIND monster to Tribute the COST cannot be paid, so the card cannot "
		+ "be activated at all — a non-WIND monster does not qualify")
	var d := TestFixtures.new_duel(7507, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var miyabi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id),
		"with no monster at all the activation is not offered")

	# A non-WIND monster is not a legal Tribute for this cost.
	var earth := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Earth Monster", 4, 1000, 1000, "EARTH"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id),
		"an EARTH monster does not pay a WIND Tribute")
	t.is_false(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"and it cannot be forced through the public API")
	t.eq(earth.zone, Enums.Zone.MONSTER_ZONE, "the EARTH monster was not Tributed")
	t.eq(miyabi.zone, Enums.Zone.SPELL_TRAP_ZONE, "the Trap is still Set")

	# A WIND monster appears: the positive control that proves the block was about WIND.
	var wind := TestFixtures.give_monster_on_field(engine, 0, _wind("Late Wind"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id),
		"one WIND monster is enough to make it activatable")
	t.eq(wind.definition.attribute, "WIND", "and that monster really is WIND")


static func _test_it_cannot_be_activated_with_an_empty_opponent_field(t: TestCase) -> void:
	t.start("a payable cost is not enough: with nothing on the opponent's field there is no "
		+ "legal target, and the Tribute is never paid")
	var d := _board(t, 7508)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	t.eq(engine.state.player(1).controlled_cards().size(), 0,
		"the opponent controls nothing")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id), "the activation is not offered")
	t.eq(wind.zone, Enums.Zone.MONSTER_ZONE,
		"and crucially the WIND monster was NOT Tributed for a card that never activated")

	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Arrival", 4, 1000, 1000))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id),
		"one card on the opponent's field is enough")


static func _test_only_the_opponents_cards_are_legal_targets(t: TestCase) -> void:
	t.start("'1 card YOUR OPPONENT controls' excludes the activating player's own cards, "
		+ "including the WIND monster it is about to Tribute")
	var d := _board(t, 7509)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(theirs.id), "the opponent's monster is a candidate")
	t.is_false(candidates.has(wind.id), "the player's own WIND monster is NOT")
	t.is_false(candidates.has(miyabi.id), "and neither is this card itself")
	t.eq(candidates.size(), 1, "exactly one legal target exists")


static func _test_a_set_spell_trap_is_a_legal_target(t: TestCase) -> void:
	t.start("'1 CARD' reaches a Set Spell/Trap and a face-down monster, not just a face-up "
		+ "monster")
	var d := _board(t, 7510)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Set Monster", 4, 1000, 1800),
		Enums.Position.FACE_DOWN_DEFENSE)
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(hidden.id), "the face-down monster is a candidate")
	t.is_true(candidates.has(their_trap.id), "so is the Set Trap")
	t.eq(candidates.size(), 2, "and those are the only two")

	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [their_trap.id]),
		"it is activated on the Set Trap")
	t.eq(_bottom_of(engine, 1), their_trap, "the Set Trap is on the bottom of the Deck")
	t.eq(engine.state.player(1).spell_traps().size(), 0,
		"and its Spell & Trap Zone is free again")


static func _test_a_target_that_left_the_field(t: TestCase) -> void:
	t.start("a target that left the field before resolution is dropped — and the Tribute "
		+ "stays paid (master prompt 44, RULES_SPEC.md 10)")
	var d := _board(t, 7511)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Doomed", 4, 1000, 1000))
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Remover", victim, "send_to_gy"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the response window is open for Chain Link 2")
	t.is_true(engine.submit_action(response), "the remover is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "Chain Link 2 removed the target first")
	t.eq(engine.state.player(1).deck.size(), deck_before, "nothing was placed on the Deck")
	t.eq(wind.zone, Enums.Zone.GRAVEYARD, "but the Tributed monster is still Tributed")
	t.eq(wind.last_move_reason, Enums.MoveReason.TRIBUTED, "with the cost's own reason")


static func _test_a_target_that_changed_control(t: TestCase) -> void:
	t.start("a target the activating player has since taken control of is no longer 'that "
		+ "OPPONENT'S card', so the effect does not apply to it (R29)")
	var d := _board(t, 7512)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Defector", 4, 1000, 1000))
	var thief_def := TestFixtures.trap("Thief")
	var steal := EffectDef.new("steal", "Test: take control of one named card.")
	steal.of_type(Enums.EffectType.CARD_ACTIVATION)
	steal.with_spell_speed(Enums.SpellSpeed.SS2)
	steal.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	steal.resolve = func(ctx: EffectContext) -> void:
		ctx.state.change_control(victim, ctx.controller_id, ctx.source.id,
			Enums.ControlDuration.UNTIL_END_PHASE)
	TestFixtures.with_effect(thief_def, steal)
	var thief := TestFixtures.give_set_spell_trap(engine, 0, thief_def)
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered while the opponent still controls it")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the response window is open")
	t.is_true(engine.submit_action(response), "the control theft is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(victim.controller_id, 0, "the activating player now controls the target")
	t.eq(victim.owner_id, 1, "ownership never moved")
	t.eq(engine.state.player(1).deck.size(), deck_before,
		"and nothing was placed on the Deck")
	t.eq(wind.zone, Enums.Zone.GRAVEYARD, "the Tribute cost stays paid regardless")


static func _test_the_cost_is_not_refunded_when_the_activation_is_negated(t: TestCase) -> void:
	t.start("a negated ACTIVATION does not give the Tributed monster back")
	var d := _board(t, 7513)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")
	t.eq(wind.zone, Enums.Zone.GRAVEYARD, "the cost is already paid")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the Counter Trap is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(wind.zone, Enums.Zone.GRAVEYARD, "the Tributed monster is NOT returned")
	t.eq(engine.state.player(0).monsters().size(), 0, "it is not back on the field")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "the target never moved")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and the Deck did not grow")


static func _test_the_cost_is_not_refunded_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("a negated EFFECT does not give the Tributed monster back either")
	var d := _board(t, 7514)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silencer"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, miyabi.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the effect negator is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the EFFECT was negated, not the activation")
	t.eq(wind.zone, Enums.Zone.GRAVEYARD, "the Tribute stays paid")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "the target never moved")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and the Deck did not grow")


static func _test_the_tribute_is_not_a_destruction(t: TestCase) -> void:
	t.start("a Tribute is not a destruction, and placing a card on the Deck is neither a "
		+ "destruction nor a send to the Graveyard [S1 p.52-53]")
	var d := _board(t, 7515)
	var engine: DuelEngine = d["engine"]
	var miyabi: CardInstance = d["miyabi"]
	var wind: CardInstance = d["wind"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Quiet", 4, 1000, 1000))
	var gy_before: int = engine.state.player(1).graveyard.size()

	t.is_true(TestFixtures.activate_card(engine, 0, miyabi, [victim.id]),
		"the Trap is activated")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, wind.id), 0,
		"the Tributed monster was not DESTROYED")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, wind.id), 1,
		"it WAS sent to the Graveyard, which is what a Tribute is [S1 p.53]")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"and the target was not destroyed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, victim.id), 0,
		"nor sent to the Graveyard")
	t.eq(engine.state.player(1).graveyard.size(), gy_before,
		"the opponent's Graveyard is untouched")

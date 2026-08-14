class_name PhoenixWingWindBlastTests
extends RefCounted

## `Phoenix Wing Wind Blast` — "Discard 1 card, then target 1 card your opponent controls;
## place that target on the top of the Deck."
##
## The generic movement behaviour is proved by `MovementTests`; this suite proves that THIS
## card reaches it correctly — its card type, its COST, its candidate set, the TOP end of
## the Deck specifically, and the negatives.

const CARD_UNDER_TEST := "Phoenix Wing Wind Blast"


static func run() -> TestCase:
	var t := TestCase.new("PhoenixWingWindBlastTests")
	_test_the_clause_shape(t)
	_test_it_places_the_target_on_top_of_the_deck(t)
	_test_the_discard_is_a_cost_paid_at_activation(t)
	_test_any_card_in_the_hand_pays_the_cost(t)
	_test_it_cannot_be_activated_with_an_empty_hand(t)
	_test_it_cannot_be_activated_with_an_empty_opponent_field(t)
	_test_only_the_opponents_cards_are_legal_targets(t)
	_test_a_face_down_card_and_a_set_trap_are_legal_targets(t)
	_test_nothing_is_shuffled_and_revealed_to_is_kept(t)
	_test_it_goes_to_the_owners_deck(t)
	_test_a_target_that_left_the_field(t)
	_test_a_target_that_changed_control(t)
	_test_the_cost_is_not_refunded_when_the_activation_is_negated(t)
	_test_the_cost_is_not_refunded_when_the_effect_is_negated(t)
	_test_it_cleans_up_equips_and_control_leases(t)
	_test_it_is_not_a_destruction(t)
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


## A duel in Main Phase 1 with the Trap Set on player 0's field on an earlier turn, and
## EXACTLY one card in player 0's hand to pay the discard with.
##
## The opening hand is cleared on purpose. With five unknown cards in hand the discard cost
## asks `choose_n`, whose default scripted answer is "the first option" — so the test could
## not say which card paid, and every assertion about the payment would be about whichever
## card the shuffle happened to deal first. One card means the cost is unambiguous and no
## question is asked at all.
static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	_empty_hand(engine, 0)
	d["pwwb"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	d["fodder"] = TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Fodder", 4, 900, 900))
	return d


static func _empty_hand(engine: DuelEngine, pid: int) -> void:
	for entry in engine.state.player(pid).hand.duplicate():
		engine.state.move_card(entry, Enums.Zone.GRAVEYARD,
			Enums.MoveReason.SENT_TO_GY_BY_EFFECT)


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal TRAP card activation, Spell Speed 2, targeting exactly 1 "
		+ "card, with a discard COST")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.TRAP,
		"it is a TRAP, not the Quick-Play Spell it is commonly remembered as (§2.4)")
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
	t.is_true(clause.pay_cost.is_valid(), "and a cost payment, so the discard is a COST")
	t.is_true(clause.clause_text.contains("Discard 1 card"),
		"the clause quotes the official cost")
	t.is_true(clause.clause_text.contains("on the top of the Deck"),
		"and quotes the TOP of the Deck specifically")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_it_places_the_target_on_top_of_the_deck(t: TestCase) -> void:
	t.start("it places the opponent's monster on the TOP of the opponent's Deck")
	var d := _board(t, 7401)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	var deck_before: int = engine.state.player(1).deck.size()
	var old_top: CardInstance = engine.state.player(1).deck[0]

	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [victim.id]),
		"the Trap is activated targeting the opponent's monster")
	t.eq(victim.zone, Enums.Zone.DECK, "the monster is in a Deck")
	t.eq(engine.state.player(1).deck.size(), deck_before + 1, "the OPPONENT's Deck grew by 1")
	t.eq(engine.state.player(1).deck[0], victim, "and the card is the TOP card of that Deck")
	t.ne(engine.state.player(1).deck[0], old_top, "displacing what used to be on top")
	t.eq(engine.state.player(1).deck[1], old_top, "which is now the second card down")
	t.eq(victim.last_move_reason, Enums.MoveReason.RETURNED_TO_DECK_TOP,
		"recorded as a placement on the TOP of the Deck, not the bottom")
	t.eq(engine.state.player(1).monsters().size(), 0, "their field is empty")
	t.eq(pwwb.zone, Enums.Zone.GRAVEYARD, "the Normal Trap goes to the Graveyard after")


static func _test_the_discard_is_a_cost_paid_at_activation(t: TestCase) -> void:
	t.start("the discard is a COST: it is paid at ACTIVATION, before the Chain Link "
		+ "resolves, and the discarded card is DISCARDED rather than sent as a cost")
	var d := _board(t, 7402)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var fodder: CardInstance = d["fodder"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	# A responder so the window genuinely opens and the board can be inspected BETWEEN the
	# activation and the resolution.
	var order_log: Array = []
	var filler := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.with_effect(
		TestFixtures.trap("Spacer"),
		TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")

	# The Chain is still building: nothing has resolved.
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the discarded card is ALREADY in the Graveyard, before any resolution")
	t.eq(fodder.last_move_reason, Enums.MoveReason.DISCARDED,
		"with the DISCARD reason, not SENT_AS_COST — PSCT keeps them apart [S1 p.52-53]")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "while the target has NOT moved yet")
	t.is_false(engine.state.player(0).hand.has(fodder), "and the hand no longer holds it")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, filler.id)
	t.not_null(response, "a response window is genuinely open")
	t.is_true(engine.submit_action(response), "the spacer is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(victim.zone, Enums.Zone.DECK, "and only then does the target reach the Deck")


static func _test_any_card_in_the_hand_pays_the_cost(t: TestCase) -> void:
	t.start("'Discard 1 CARD' is any card — a Spell in the hand pays it just as a monster "
		+ "does, and the player chooses which")
	var d := _board(t, 7403)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var p0: ScriptedController = d["p0"]
	var spell_in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.spell("A Spell In Hand"))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	# Two candidates, so a real question is asked; `choose_n` asks nothing when the number
	# of candidates equals the number required.
	var fodder: CardInstance = d["fodder"]
	t.eq(engine.state.player(0).hand.size(), 2, "there are two cards to choose between")
	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [spell_in_hand.id])

	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [victim.id]),
		"the Trap is activated")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(spell_in_hand.zone, Enums.Zone.GRAVEYARD, "the chosen Spell was discarded")
	t.eq(fodder.zone, Enums.Zone.HAND, "and the monster the player kept is still in hand")
	t.eq(engine.state.player(0).hand.size(), 1, "exactly one card left the hand")
	t.eq(victim.zone, Enums.Zone.DECK, "and the effect still resolved")


static func _test_it_goes_to_the_owners_deck(t: TestCase) -> void:
	t.start("the card goes to its OWNER's Deck even when the opponent had taken control of "
		+ "it, and the control lease leaves with it [S1 p.52]")
	var d := _board(t, 7404)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	# Player 0 OWNS the monster; player 1 has taken control of it, so it is now "a card your
	# opponent controls" from player 0's seat.
	var lender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Lender", 3, 500, 500))
	var borrowed := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Borrowed", 4, 1500, 1000))
	t.is_true(engine.state.change_control(borrowed, 1, lender.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "player 1 takes control of it")
	t.eq(borrowed.controller_id, 1, "player 1 controls it")
	t.eq(borrowed.owner_id, 0, "player 0 still OWNS it")

	var p0_deck_before: int = engine.state.player(0).deck.size()
	var p1_deck_before: int = engine.state.player(1).deck.size()
	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [borrowed.id]),
		"the Trap is activated on the borrowed monster")
	t.eq(borrowed.zone, Enums.Zone.DECK, "it is in a Deck")
	t.eq(engine.state.player(0).deck.size(), p0_deck_before + 1,
		"its OWNER's Deck grew [S1 p.52]")
	t.eq(engine.state.player(1).deck.size(), p1_deck_before,
		"the controller's Deck did not")
	t.eq(engine.state.player(0).deck[0], borrowed, "it is on TOP of its owner's Deck")
	t.eq(borrowed.controller_id, 0, "and the controller is its owner again")
	t.eq(engine.state.control_leases_for(borrowed.id).size(), 0,
		"no stale control lease is left behind")


static func _test_nothing_is_shuffled_and_revealed_to_is_kept(t: TestCase) -> void:
	t.start("a known top placement without a shuffle KEEPS revealed_to, and leaves the rest "
		+ "of the Deck in its original order (design decision 11)")
	var d := _board(t, 7405)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Known Card", 4, 1600, 1200))
	# A face-up monster on the field is public; make the knowledge explicit so the assertion
	# is about the Deck placement rather than about what reveal() did.
	engine.state.reveal(victim, [0, 1])
	t.is_true(victim.revealed_to.has(0), "player 0 knows the card")
	var order_before: Array = []
	for entry in engine.state.player(1).deck:
		order_before.append((entry as CardInstance).id)

	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [victim.id]),
		"the Trap is activated")
	t.is_true(victim.revealed_to.has(0),
		"the target's identity is still known: 'place on top' does not shuffle")
	t.is_true(victim.revealed_to.has(1), "to both players")
	var order_after: Array = []
	for entry in engine.state.player(1).deck:
		order_after.append((entry as CardInstance).id)
	t.eq(order_after.slice(1), order_before,
		"the rest of the Deck is untouched and in its original order — no shuffle happened")
	# A shuffle clears revealed_to for EVERY card in the Deck, so a Deck that still holds a
	# known card anywhere proves no shuffle ran, independently of the order check above.
	t.eq(victim.revealed_to.size(), 2,
		"and the placed card is still known to both players, which a shuffle would have "
		+ "cleared (GameState.shuffle_deck)")


# ---------------------------------------------------------------------------
# Negatives, where the value is
# ---------------------------------------------------------------------------

static func _test_it_cannot_be_activated_with_an_empty_hand(t: TestCase) -> void:
	t.start("with an empty hand the discard COST cannot be paid, so the card cannot be "
		+ "activated at all")
	var d := TestFixtures.new_duel(7406, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var pwwb := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1200))
	# Empty player 0's hand: a legal target exists, so only the cost can be the blocker.
	for entry in engine.state.player(0).hand.duplicate():
		engine.state.move_card(entry, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(engine.state.player(0).hand.size(), 0, "the hand is empty")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id), "the activation is not offered")
	t.is_false(TestFixtures.activate_card(engine, 0, pwwb, [victim.id]),
		"and cannot be forced through the public API")
	t.eq(pwwb.zone, Enums.Zone.SPELL_TRAP_ZONE, "the card is still Set on the field")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "and the target was not touched")

	# One card in hand and it becomes available: the positive control.
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Late Arrival", 4, 900, 900))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id),
		"one card in the hand is enough to make it activatable")


static func _test_it_cannot_be_activated_with_an_empty_opponent_field(t: TestCase) -> void:
	t.start("with nothing on the OPPONENT's field there is no legal target, however full "
		+ "the activating player's own field is")
	var d := _board(t, 7407)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Monster", 4, 1600, 1200))
	t.eq(engine.state.player(1).controlled_cards().size(), 0,
		"the opponent controls nothing")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id),
		"the activation is not offered even though the player's own field is not empty")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the player's own monster is untouched")

	var arrival := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Arrival", 4, 1000, 1000))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id),
		"one card on the opponent's field is enough")
	t.eq(arrival.controller_id, 1, "and it is the opponent who controls it")


static func _test_only_the_opponents_cards_are_legal_targets(t: TestCase) -> void:
	t.start("'1 card YOUR OPPONENT controls' excludes every card on the activating player's "
		+ "own side, including this card itself")
	var d := _board(t, 7408)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000))
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1000, 1000))
	var my_trap := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("My Other Trap"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(theirs.id), "the opponent's monster is a candidate")
	t.is_false(candidates.has(mine.id), "the player's own monster is NOT")
	t.is_false(candidates.has(my_trap.id), "nor their own Set Trap")
	t.is_false(candidates.has(pwwb.id), "and neither is this card itself")
	t.eq(candidates.size(), 1, "exactly one legal target exists")


static func _test_a_face_down_card_and_a_set_trap_are_legal_targets(t: TestCase) -> void:
	t.start("'1 CARD' is any card the opponent controls — a face-down monster and a Set "
		+ "Spell/Trap are both legal, and a Set Trap really does end up on the Deck")
	var d := _board(t, 7409)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Set Monster", 4, 1000, 1800),
		Enums.Position.FACE_DOWN_DEFENSE)
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(hidden.id), "the face-down monster is a candidate")
	t.is_true(candidates.has(their_trap.id), "so is the Set Trap — the text says 'card'")
	t.eq(candidates.size(), 2, "and those are the only two")

	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [their_trap.id]),
		"it is activated on the Set Trap")
	t.eq(their_trap.zone, Enums.Zone.DECK, "the Set Trap is placed on the Deck")
	t.eq(engine.state.player(1).deck[0], their_trap, "on TOP of it")
	t.eq(engine.state.player(1).spell_traps().size(), 0,
		"and its Spell & Trap Zone is free again")


static func _test_a_target_that_left_the_field(t: TestCase) -> void:
	t.start("a target that left the field before resolution is dropped, never chased — and "
		+ "the discard COST stays paid (master prompt 44, RULES_SPEC.md 10)")
	var d := _board(t, 7410)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var fodder: CardInstance = d["fodder"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Doomed", 4, 1000, 1000))
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Remover", victim, "send_to_gy"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the response window is open for Chain Link 2")
	t.is_true(engine.submit_action(response), "the remover is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(victim.zone, Enums.Zone.GRAVEYARD,
		"Chain Link 2 sent the target to the Graveyard first")
	t.eq(engine.state.player(1).deck.size(), deck_before,
		"so nothing was placed on the Deck")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "but the discarded card is still discarded")
	t.eq(pwwb.zone, Enums.Zone.GRAVEYARD, "and the Trap still resolved and left the field")


static func _test_a_target_that_changed_control(t: TestCase) -> void:
	t.start("a target the activating player has since taken control of is no longer 'a card "
		+ "YOUR OPPONENT controls', so the effect does not apply to it (R29)")
	var d := _board(t, 7411)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Defector", 4, 1000, 1000))
	# A Spell Speed 2 response that hands the target to the activating player mid-Chain.
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
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
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
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "the target is still on the field")
	t.eq(engine.state.player(1).deck.size(), deck_before,
		"and nothing was placed on the Deck: the target is no longer the opponent's")
	t.eq(pwwb.zone, Enums.Zone.GRAVEYARD, "the Trap still resolved and left the field")


static func _test_the_cost_is_not_refunded_when_the_activation_is_negated(t: TestCase) -> void:
	t.start("a negated ACTIVATION does not refund the discard, and the target stays put "
		+ "(RULES_SPEC.md 10)")
	var d := _board(t, 7412)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var fodder: CardInstance = d["fodder"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the cost is already paid")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the Counter Trap is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the discarded card is NOT returned to the hand")
	t.is_false(engine.state.player(0).hand.has(fodder), "the hand did not get it back")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "the target never moved")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and the Deck did not grow")
	t.eq(pwwb.zone, Enums.Zone.GRAVEYARD, "the negated Trap is destroyed and in the GY")


static func _test_the_cost_is_not_refunded_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("a negated EFFECT does not refund the discard either — the activation happened, "
		+ "only the effect did not apply (master prompt 18)")
	var d := _board(t, 7413)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var fodder: CardInstance = d["fodder"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silencer"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, pwwb.id)
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
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 0,
		"and the activation was not")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the discarded card stays discarded")
	t.eq(victim.zone, Enums.Zone.MONSTER_ZONE, "the target never moved")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and the Deck did not grow")


static func _test_it_cleans_up_equips_and_control_leases(t: TestCase) -> void:
	t.start("placing an equipped monster on the Deck destroys its Equip Cards and leaves no "
		+ "stale controller state behind")
	var d := _board(t, 7414)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Equipped", 4, 1200, 1000))
	var equip := TestFixtures.give(engine, 1, TestFixtures.equip_spell("Clinger", 500),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.is_true(engine.state.equip_to(equip, victim), "the monster is equipped")

	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [victim.id]),
		"the Trap is activated on the equipped monster")
	t.eq(victim.zone, Enums.Zone.DECK, "the monster is placed on the Deck")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "its Equip Card is destroyed by the rules")
	t.eq(equip.last_move_reason, Enums.MoveReason.DESTROYED_BY_RULE,
		"with the rules-destruction reason [S1 p.29, p.55]")
	t.eq(victim.equipped_card_ids.size(), 0, "and the equip relationship is gone")
	t.eq(engine.state.control_leases_for(victim.id).size(), 0, "no control lease survives")


static func _test_it_is_not_a_destruction(t: TestCase) -> void:
	t.start("placing a card on the Deck is NOT a destruction and NOT a send to the "
		+ "Graveyard, so neither trigger fires [S1 p.52]")
	var d := _board(t, 7415)
	var engine: DuelEngine = d["engine"]
	var pwwb: CardInstance = d["pwwb"]
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Quiet", 4, 1000, 1000))
	var gy_before: int = engine.state.player(1).graveyard.size()
	var destroyed_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED)
	var to_gy_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)

	t.is_true(TestFixtures.activate_card(engine, 0, pwwb, [victim.id]),
		"the Trap is activated")
	t.eq(victim.zone, Enums.Zone.DECK, "the card is on the Deck")
	t.eq(engine.state.player(1).graveyard.size(), gy_before,
		"nothing of the opponent's reached the Graveyard")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"no destruction event for the target")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, victim.id), 0,
		"and no send-to-Graveyard event for it either")
	t.is_true(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED)
		== destroyed_before,
		"no destruction happened at all")
	t.is_true(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)
		> to_gy_before,
		"the discarded cost and the spent Trap DID reach the Graveyard, as they should")

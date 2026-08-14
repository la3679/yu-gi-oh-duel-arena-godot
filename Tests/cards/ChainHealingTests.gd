class_name ChainHealingTests
extends RefCounted

## `Chain Healing` — "Gain 500 Life Points. If this card was activated as Chain Link 2 or 3,
## add this card to the Deck and shuffle it. If this card was activated as Chain Link 4 or
## higher, return this card to the hand."
##
## Research/CARD_RULINGS.md **R4**. The self-return half is shared with `Chain Detonation`
## through `EffectPrimitives.return_self_by_chain_link()`; this suite still drives all three
## branches on THIS card, because sharing an implementation is not evidence that this card
## reaches it. The first half is the card's own and is asserted from both seats.

const CARD_UNDER_TEST := "Chain Healing"

const LIFE_POINTS := 500


static func run() -> TestCase:
	var t := TestCase.new("ChainHealingTests")
	_test_the_clause_shape(t)
	_test_chain_link_1_gains_lp_and_goes_to_the_graveyard(t)
	_test_chain_link_2_shuffles_itself_into_the_deck(t)
	_test_chain_link_3_shuffles_itself_into_the_deck(t)
	_test_chain_link_4_returns_itself_to_the_hand(t)
	_test_chain_link_5_also_returns_itself_to_the_hand(t)
	_test_the_lp_go_to_the_activating_player(t)
	_test_it_cannot_end_the_duel(t)
	_test_the_shuffle_clears_revealed_to(t)
	_test_it_does_not_also_reach_the_graveyard(t)
	_test_a_negated_effect_gains_nothing(t)
	_test_a_negated_activation_gains_nothing(t)
	_test_it_shares_the_self_return_with_chain_detonation_but_not_the_first_half(t)
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


static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["card"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	return d


static func _activate_at_link(t: TestCase, engine: DuelEngine, card: CardInstance,
		depth: int) -> int:
	if depth > 1:
		var spacers := TestFixtures.build_chain_to_depth(engine, depth - 1)
		t.eq(spacers.size(), depth - 1,
			"the Chain was built %d link(s) deep before the card" % (depth - 1))
	var actions: Array = engine.get_legal_actions(0) if depth == 1 \
		else engine.get_legal_responses(0)
	var offered = TestFixtures.find_action(actions, Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(offered, "the activation is offered at Chain Link %d" % depth)
	if offered == null:
		return -1
	var observed := engine.state.chain.size() + 1
	t.is_true(engine.submit_action(offered), "it is activated")
	t.eq(observed, depth, "and it really is Chain Link %d" % depth)
	TestFixtures.pass_until_open(engine)
	return observed


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("three printed sentences but ONE EffectDef: a Normal Trap activation whose "
		+ "second and third sentences are branches of the same resolution")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.TRAP, "it is a Trap")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP, "and specifically a NORMAL Trap")
	t.eq(def.effects.size(), 1, "one EffectDef")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2")
	t.is_false(clause.targets, "it does not target")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Trap is activated from a Set position")
	t.is_false(clause.can_pay_cost.is_valid(), "it has no cost")
	t.is_true(clause.clause_text.contains("Gain 500 Life Points"),
		"the clause quotes the LP gain")
	t.is_true(clause.clause_text.contains("Chain Link 2 or 3"),
		"and the Chain Link 2-or-3 branch")
	t.is_true(clause.clause_text.contains("Chain Link 4 or higher"),
		"and the Chain Link 4-or-higher branch")
	t.eq(clause.ruling_ref, "R4", "it declares the R4 ruling it rests on")


# ---------------------------------------------------------------------------
# The three Chain Link branches
# ---------------------------------------------------------------------------

static func _test_chain_link_1_gains_lp_and_goes_to_the_graveyard(t: TestCase) -> void:
	t.start("Chain Link 1: the LP gain happens and NEITHER conditional half does")
	var d := _board(t, 7701)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(0).life_points
	var deck_before: int = engine.state.player(0).deck.size()
	var hand_before: int = engine.state.player(0).hand.size()

	t.eq(_activate_at_link(t, engine, card, 1), 1, "activated as Chain Link 1")
	t.eq(engine.state.player(0).life_points, lp_before + LIFE_POINTS,
		"the activating player gained exactly 500 LP")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "and the card is in the Graveyard")
	t.eq(engine.state.player(0).deck.size(), deck_before, "it did NOT go to the Deck")
	t.eq(engine.state.player(0).hand.size(), hand_before, "and it did NOT go to the hand")
	t.eq(card.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"it left as a resolved Spell/Trap")


static func _test_chain_link_2_shuffles_itself_into_the_deck(t: TestCase) -> void:
	t.start("Chain Link 2: the LP gain happens AND the card is added to the Deck and "
		+ "shuffled")
	var d := _board(t, 7702)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(0).life_points
	var deck_before: int = engine.state.player(0).deck.size()

	t.eq(_activate_at_link(t, engine, card, 2), 2, "activated as Chain Link 2")
	t.eq(engine.state.player(0).life_points, lp_before + LIFE_POINTS,
		"the player still gained exactly 500 LP")
	t.eq(card.zone, Enums.Zone.DECK, "the card is in a Deck")
	t.is_true(engine.state.player(0).deck.has(card), "its OWNER's Deck")
	t.eq(engine.state.player(0).deck.size(), deck_before + 1, "which grew by exactly 1")
	t.is_false(engine.state.player(0).graveyard.has(card),
		"and it is NOT in the Graveyard as well")
	t.eq(card.last_move_reason, Enums.MoveReason.SHUFFLED_INTO_DECK, "with a shuffle")


static func _test_chain_link_3_shuffles_itself_into_the_deck(t: TestCase) -> void:
	t.start("Chain Link 3 takes the same branch as Chain Link 2")
	var d := _board(t, 7703)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(0).life_points
	var deck_before: int = engine.state.player(0).deck.size()

	t.eq(_activate_at_link(t, engine, card, 3), 3, "activated as Chain Link 3")
	t.eq(engine.state.player(0).life_points, lp_before + LIFE_POINTS, "500 LP as always")
	t.eq(card.zone, Enums.Zone.DECK, "the card is in a Deck")
	t.eq(engine.state.player(0).deck.size(), deck_before + 1, "its owner's, which grew by 1")
	t.is_false(engine.state.player(0).hand.has(card),
		"and not the hand — that is the Chain Link 4 branch")


static func _test_chain_link_4_returns_itself_to_the_hand(t: TestCase) -> void:
	t.start("Chain Link 4: the card is returned to the HAND")
	var d := _board(t, 7704)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(0).life_points
	var deck_before: int = engine.state.player(0).deck.size()
	var hand_before: int = engine.state.player(0).hand.size()

	t.eq(_activate_at_link(t, engine, card, 4), 4, "activated as Chain Link 4")
	t.eq(engine.state.player(0).life_points, lp_before + LIFE_POINTS, "500 LP as always")
	t.eq(card.zone, Enums.Zone.HAND, "the card is in a hand")
	t.is_true(engine.state.player(0).hand.has(card), "its OWNER's hand")
	t.eq(engine.state.player(0).hand.size(), hand_before + 1, "which grew by exactly 1")
	t.eq(engine.state.player(0).deck.size(), deck_before, "the Deck did NOT grow")
	t.eq(card.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"recorded as a return to the hand")


static func _test_chain_link_5_also_returns_itself_to_the_hand(t: TestCase) -> void:
	t.start("'Chain Link 4 or HIGHER' is open-ended: Chain Link 5 behaves like Chain Link 4")
	var d := _board(t, 7705)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(0).life_points

	t.eq(_activate_at_link(t, engine, card, 5), 5, "activated as Chain Link 5")
	t.eq(engine.state.player(0).life_points, lp_before + LIFE_POINTS, "500 LP as always")
	t.eq(card.zone, Enums.Zone.HAND, "the card is in a hand")
	t.is_true(engine.state.player(0).hand.has(card), "its owner's hand")


# ---------------------------------------------------------------------------
# The LP half — the one thing this card does NOT share with Chain Detonation
# ---------------------------------------------------------------------------

static func _test_the_lp_go_to_the_activating_player(t: TestCase) -> void:
	t.start("'GAIN 500 Life Points' means YOU gain them: the opponent's LP never move, "
		+ "from either seat")
	var d := _board(t, 7706)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var own_before: int = engine.state.player(0).life_points
	var their_before: int = engine.state.player(1).life_points

	t.eq(_activate_at_link(t, engine, card, 1), 1, "player 0 activates it")
	t.eq(engine.state.player(0).life_points, own_before + LIFE_POINTS,
		"the activating player GAINED 500")
	t.eq(engine.state.player(1).life_points, their_before,
		"and the opponent's LP are completely unchanged")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.LP_CHANGED), 1,
		"exactly one LP change was emitted, so the gain was applied once")

	# The other seat.
	var d2 := TestFixtures.new_duel(7707, 1)
	var engine2: DuelEngine = d2["engine"]
	TestFixtures.advance_to_phase(engine2, Enums.Phase.MAIN_1)
	var theirs := TestFixtures.give_set_spell_trap(engine2, 1, _card_def(t))
	var p0_before: int = engine2.state.player(0).life_points
	var p1_before: int = engine2.state.player(1).life_points
	var offered = TestFixtures.find_action(engine2.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, theirs.id)
	t.not_null(offered, "player 1 may activate their copy")
	t.is_true(engine2.submit_action(offered), "they do")
	TestFixtures.pass_until_open(engine2)
	t.eq(engine2.state.player(1).life_points, p1_before + LIFE_POINTS,
		"player 1 gained the 500")
	t.eq(engine2.state.player(0).life_points, p0_before, "and player 0's LP did not move")


static func _test_it_cannot_end_the_duel(t: TestCase) -> void:
	t.start("gaining LP can never take a player to 0, so unlike Chain Detonation this card "
		+ "cannot end the Duel and does not need to ask check_life_point_loss()")
	var d := _board(t, 7708)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	# Both players on the brink: if this card ended Duels, this is where it would.
	engine.state.player(0).life_points = 100
	engine.state.player(1).life_points = 100

	t.eq(_activate_at_link(t, engine, card, 1), 1, "it is activated")
	t.eq(engine.state.player(0).life_points, 100 + LIFE_POINTS, "the player gained 500")
	t.eq(engine.state.player(1).life_points, 100, "the opponent is untouched at 100")
	t.is_false(engine.is_duel_over(), "and the Duel is still going")
	t.eq(engine.state.result, Enums.DuelResult.ONGOING, "with no result recorded")


# ---------------------------------------------------------------------------
# The self-return half, in detail
# ---------------------------------------------------------------------------

static func _test_the_shuffle_clears_revealed_to(t: TestCase) -> void:
	t.start("'add this card to the Deck and SHUFFLE it' really shuffles, so the card stops "
		+ "being identifiable (design decision 11)")
	var d := _board(t, 7709)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	engine.state.reveal(card, [0, 1])
	t.eq(card.revealed_to.size(), 2, "both players know the card before it moves")

	t.eq(_activate_at_link(t, engine, card, 2), 2, "activated as Chain Link 2")
	t.eq(card.zone, Enums.Zone.DECK, "it is in the Deck")
	t.eq(card.revealed_to.size(), 0, "and nobody knows where it is any more")
	var still_known := 0
	for entry in engine.state.player(0).deck:
		if not (entry as CardInstance).revealed_to.is_empty():
			still_known += 1
	t.eq(still_known, 0, "no card anywhere in that Deck is still identifiable")


static func _test_it_does_not_also_reach_the_graveyard(t: TestCase) -> void:
	t.start("a card that moved ITSELF off the field during its own resolution is not then "
		+ "swept to the Graveyard by the resolved-Spell/Trap cleanup")
	var d := _board(t, 7710)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]

	t.eq(_activate_at_link(t, engine, card, 4), 4, "activated as Chain Link 4")
	t.eq(card.zone, Enums.Zone.HAND, "it ended in the hand")
	t.is_false(engine.state.player(0).graveyard.has(card), "and never reached the Graveyard")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, card.id), 0,
		"no send-to-Graveyard event was emitted for it")
	t.eq(card.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"its last move is the return, not a RESOLVED_TO_GY that overwrote it")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

static func _test_a_negated_effect_gains_nothing(t: TestCase) -> void:
	t.start("a negated EFFECT gains no LP and performs no self-return, but the card was "
		+ "still activated and still leaves the field")
	var d := _board(t, 7711)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silencer"))
	var lp_before: int = engine.state.player(0).life_points
	var deck_before: int = engine.state.player(0).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the effect negator is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the effect was negated")
	t.eq(engine.state.player(0).life_points, lp_before, "no LP were gained")
	t.eq(engine.state.player(0).deck.size(), deck_before, "and nothing was added to the Deck")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "the spent Trap still leaves the field")


static func _test_a_negated_activation_gains_nothing(t: TestCase) -> void:
	t.start("a negated ACTIVATION gains no LP either, and the card is destroyed rather than "
		+ "returning itself anywhere")
	var d := _board(t, 7712)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))
	var lp_before: int = engine.state.player(0).life_points
	var hand_before: int = engine.state.player(0).hand.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "the Counter Trap is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"the activation was negated")
	t.eq(engine.state.player(0).life_points, lp_before, "no LP were gained")
	t.eq(engine.state.player(0).hand.size(), hand_before, "nothing returned to the hand")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "the card was destroyed")


# ---------------------------------------------------------------------------
# The relationship with Chain Detonation, asserted rather than assumed
# ---------------------------------------------------------------------------

static func _test_it_shares_the_self_return_with_chain_detonation_but_not_the_first_half(
		t: TestCase) -> void:
	t.start("the two cards are the same shape but NOT one implementation: separate registry "
		+ "files, separate effect ids, identical Chain Link sentences (design decision 22)")
	var lib := _library()
	var cards: Dictionary = lib["cards"]
	t.is_true(cards.has(CARD_UNDER_TEST), "Chain Healing is in the registry")
	t.is_true(cards.has("Chain Detonation"), "so is Chain Detonation")
	var healing: CardDef = cards[CARD_UNDER_TEST]
	var detonation: CardDef = cards["Chain Detonation"]
	var h: EffectDef = healing.effects[0]
	var det: EffectDef = detonation.effects[0]
	t.ne(h.effect_id, det.effect_id, "the two effect ids are different")
	t.ne(h.clause_text, det.clause_text, "and so is the printed text")
	t.is_true(h.clause_text.contains("Gain 500 Life Points"), "this one gains LP")
	t.is_true(det.clause_text.contains("Inflict 500 damage"), "the other one burns")
	# The shared sentences really are identical, which is what justifies one primitive.
	var shared := "If this card was activated as Chain Link 2 or 3, add this card to the " \
		+ "Deck and shuffle it. If this card was activated as Chain Link 4 or higher, " \
		+ "return this card to the hand."
	t.is_true(h.clause_text.contains(shared),
		"Chain Healing prints the shared sentences verbatim")
	t.is_true(det.clause_text.contains(shared),
		"and Chain Detonation prints exactly the same two sentences")

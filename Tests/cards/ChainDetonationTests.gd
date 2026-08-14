class_name ChainDetonationTests
extends RefCounted

## `Chain Detonation` — "Inflict 500 damage to your opponent. If this card was activated as
## Chain Link 2 or 3, add this card to the Deck and shuffle it. If this card was activated
## as Chain Link 4 or higher, return this card to the hand."
##
## Research/CARD_RULINGS.md **R4**. The whole point of this suite is the Chain Link position:
## every one of the three branches is driven at a real Chain depth built by
## `TestFixtures.build_chain_to_depth()`, never by writing `link_number` by hand.

const CARD_UNDER_TEST := "Chain Detonation"

const DAMAGE := 500


static func run() -> TestCase:
	var t := TestCase.new("ChainDetonationTests")
	_test_the_clause_shape(t)
	_test_chain_link_1_damages_and_goes_to_the_graveyard(t)
	_test_chain_link_2_shuffles_itself_into_the_deck(t)
	_test_chain_link_3_shuffles_itself_into_the_deck(t)
	_test_chain_link_4_returns_itself_to_the_hand(t)
	_test_chain_link_5_also_returns_itself_to_the_hand(t)
	_test_the_damage_always_hits_the_opponent(t)
	_test_the_shuffle_clears_revealed_to(t)
	_test_it_does_not_also_reach_the_graveyard(t)
	_test_it_can_end_the_duel(t)
	_test_a_negated_effect_does_nothing_at_all(t)
	_test_a_negated_activation_does_nothing_at_all(t)
	_test_it_cannot_move_itself_once_it_has_left_the_field(t)
	_test_the_link_number_is_read_from_the_chain_link(t)
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


## A duel in Main Phase 1 with the card Set on player 0's field, player 0 the turn player.
static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["card"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	return d


## Build a Chain `depth - 1` links deep, then activate the card as Chain Link `depth` and
## let the whole Chain resolve. Returns the link number the card was actually activated at.
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
	t.eq(def.effects.size(), 1,
		"one EffectDef: the conditional halves are not separately activatable effects")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2")
	t.is_false(clause.targets, "it does not target — the word does not appear")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Trap is activated from a Set position")
	t.is_false(clause.can_pay_cost.is_valid(), "it has no cost")
	t.is_true(clause.clause_text.contains("Inflict 500 damage to your opponent"),
		"the clause quotes the damage")
	t.is_true(clause.clause_text.contains("Chain Link 2 or 3"),
		"and the Chain Link 2-or-3 branch")
	t.is_true(clause.clause_text.contains("Chain Link 4 or higher"),
		"and the Chain Link 4-or-higher branch")
	t.eq(clause.ruling_ref, "R4", "it declares the R4 ruling it rests on")


# ---------------------------------------------------------------------------
# The three Chain Link branches
# ---------------------------------------------------------------------------

static func _test_chain_link_1_damages_and_goes_to_the_graveyard(t: TestCase) -> void:
	t.start("Chain Link 1: the damage happens and NEITHER conditional half does — the Trap "
		+ "goes to the Graveyard the ordinary way")
	var d := _board(t, 7601)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(1).life_points
	var deck_before: int = engine.state.player(0).deck.size()
	var hand_before: int = engine.state.player(0).hand.size()

	t.eq(_activate_at_link(t, engine, card, 1), 1, "activated as Chain Link 1")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE,
		"the opponent took exactly 500 damage")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "and the card is in the Graveyard")
	t.eq(engine.state.player(0).deck.size(), deck_before, "it did NOT go to the Deck")
	t.eq(engine.state.player(0).hand.size(), hand_before, "and it did NOT go to the hand")
	t.eq(card.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"it left as a resolved Spell/Trap")


static func _test_chain_link_2_shuffles_itself_into_the_deck(t: TestCase) -> void:
	t.start("Chain Link 2: the damage happens AND the card is added to the Deck and shuffled")
	var d := _board(t, 7602)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(1).life_points
	var deck_before: int = engine.state.player(0).deck.size()
	var gy_before: int = engine.state.player(0).graveyard.size()

	t.eq(_activate_at_link(t, engine, card, 2), 2, "activated as Chain Link 2")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE,
		"the opponent still took exactly 500 damage")
	t.eq(card.zone, Enums.Zone.DECK, "the card is in a Deck")
	t.is_true(engine.state.player(0).deck.has(card), "its OWNER's Deck")
	t.eq(engine.state.player(0).deck.size(), deck_before + 1, "which grew by exactly 1")
	t.is_false(engine.state.player(0).graveyard.has(card),
		"and it is NOT in the Graveyard as well")
	t.eq(card.last_move_reason, Enums.MoveReason.SHUFFLED_INTO_DECK,
		"recorded as a shuffle into the Deck, not a top or bottom placement")
	# The spacer at Chain Link 1 is a Normal Trap and still resolves normally.
	t.eq(engine.state.player(0).graveyard.size(), gy_before + 1,
		"only the Chain Link 1 spacer reached the Graveyard")


static func _test_chain_link_3_shuffles_itself_into_the_deck(t: TestCase) -> void:
	t.start("Chain Link 3 takes the same branch as Chain Link 2 — '2 or 3' is inclusive at "
		+ "both ends")
	var d := _board(t, 7603)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(1).life_points
	var deck_before: int = engine.state.player(0).deck.size()

	t.eq(_activate_at_link(t, engine, card, 3), 3, "activated as Chain Link 3")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE, "500 damage as always")
	t.eq(card.zone, Enums.Zone.DECK, "the card is in a Deck")
	t.eq(engine.state.player(0).deck.size(), deck_before + 1, "its owner's, which grew by 1")
	t.eq(card.last_move_reason, Enums.MoveReason.SHUFFLED_INTO_DECK, "with a shuffle")
	t.is_false(engine.state.player(0).hand.has(card),
		"and emphatically not the hand — that is the Chain Link 4 branch")


static func _test_chain_link_4_returns_itself_to_the_hand(t: TestCase) -> void:
	t.start("Chain Link 4: the card is returned to the HAND, not shuffled into the Deck")
	var d := _board(t, 7604)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(1).life_points
	var deck_before: int = engine.state.player(0).deck.size()
	var hand_before: int = engine.state.player(0).hand.size()

	t.eq(_activate_at_link(t, engine, card, 4), 4, "activated as Chain Link 4")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE, "500 damage as always")
	t.eq(card.zone, Enums.Zone.HAND, "the card is in a hand")
	t.is_true(engine.state.player(0).hand.has(card), "its OWNER's hand")
	t.eq(engine.state.player(0).hand.size(), hand_before + 1, "which grew by exactly 1")
	t.eq(engine.state.player(0).deck.size(), deck_before, "the Deck did NOT grow")
	t.eq(card.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"recorded as a return to the hand")


static func _test_chain_link_5_also_returns_itself_to_the_hand(t: TestCase) -> void:
	t.start("'Chain Link 4 or HIGHER' is open-ended: Chain Link 5 behaves like Chain Link 4")
	var d := _board(t, 7605)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(1).life_points

	t.eq(_activate_at_link(t, engine, card, 5), 5, "activated as Chain Link 5")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE, "500 damage as always")
	t.eq(card.zone, Enums.Zone.HAND, "the card is in a hand")
	t.is_true(engine.state.player(0).hand.has(card), "its owner's hand")


# ---------------------------------------------------------------------------
# The damage half
# ---------------------------------------------------------------------------

static func _test_the_damage_always_hits_the_opponent(t: TestCase) -> void:
	t.start("'Inflict 500 damage to YOUR OPPONENT' — the activating player's own LP are "
		+ "never touched, from either seat")
	var d := _board(t, 7606)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var own_before: int = engine.state.player(0).life_points
	var their_before: int = engine.state.player(1).life_points

	t.eq(_activate_at_link(t, engine, card, 1), 1, "player 0 activates it")
	t.eq(engine.state.player(0).life_points, own_before,
		"the activating player's own LP are unchanged")
	t.eq(engine.state.player(1).life_points, their_before - DAMAGE,
		"and the opponent lost 500")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.LP_CHANGED), 1,
		"exactly one LP change was emitted, so the damage was applied once")

	# The other seat: player 1 owns and activates a second copy on their own turn.
	var d2 := TestFixtures.new_duel(7607, 1)
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
	t.eq(engine2.state.player(1).life_points, p1_before,
		"the activating player (player 1) took no damage")
	t.eq(engine2.state.player(0).life_points, p0_before - DAMAGE,
		"and THEIR opponent (player 0) took the 500")


static func _test_it_can_end_the_duel(t: TestCase) -> void:
	t.start("the damage is effect damage that can reduce a player to 0 LP and end the Duel, "
		+ "so the resolution must ask check_life_point_loss() itself")
	var d := _board(t, 7608)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	engine.state.player(1).life_points = DAMAGE
	t.eq(engine.state.player(1).life_points, DAMAGE, "the opponent is on exactly 500 LP")

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).life_points, 0, "the opponent is on 0 LP")
	t.is_true(engine.is_duel_over(), "and the Duel is over")
	t.eq(engine.state.result, Enums.DuelResult.PLAYER_0_WINS,
		"the activating player wins — this is not a simultaneous zero")


# ---------------------------------------------------------------------------
# The self-return half, in detail
# ---------------------------------------------------------------------------

static func _test_the_shuffle_clears_revealed_to(t: TestCase) -> void:
	t.start("'add this card to the Deck and SHUFFLE it' really shuffles: an activated card "
		+ "is public, and afterwards nobody may know where it is (design decision 11)")
	var d := _board(t, 7609)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	# Activating a Set card reveals it; make the knowledge explicit either way.
	engine.state.reveal(card, [0, 1])
	t.eq(card.revealed_to.size(), 2, "both players know the card before it moves")

	t.eq(_activate_at_link(t, engine, card, 2), 2, "activated as Chain Link 2")
	t.eq(card.zone, Enums.Zone.DECK, "it is in the Deck")
	t.eq(card.revealed_to.size(), 0,
		"and nobody knows where it is any more — the shuffle cleared revealed_to")
	# The shuffle clears revealed_to for EVERY card in that Deck, which is what separates it
	# from the unshuffled top/bottom placements Phoenix Wing Wind Blast and Miyabi perform.
	var still_known := 0
	for entry in engine.state.player(0).deck:
		if not (entry as CardInstance).revealed_to.is_empty():
			still_known += 1
	t.eq(still_known, 0, "no card anywhere in that Deck is still identifiable")


static func _test_it_does_not_also_reach_the_graveyard(t: TestCase) -> void:
	t.start("a card that moved ITSELF off the field during its own resolution must not then "
		+ "be swept to the Graveyard by the resolved-Spell/Trap cleanup")
	var d := _board(t, 7610)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var gy_ids_before: Array = []
	for entry in engine.state.player(0).graveyard:
		gy_ids_before.append((entry as CardInstance).id)

	t.eq(_activate_at_link(t, engine, card, 4), 4, "activated as Chain Link 4")
	t.eq(card.zone, Enums.Zone.HAND, "it ended in the hand")
	t.is_false(engine.state.player(0).graveyard.has(card),
		"and never reached the Graveyard")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, card.id), 0,
		"no send-to-Graveyard event was emitted for it at all")
	t.eq(engine.state.player(0).spell_traps().size(), 0,
		"its Spell & Trap Zone is free again")
	t.eq(card.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"and its last move is the return, not a RESOLVED_TO_GY that overwrote it")


static func _test_it_cannot_move_itself_once_it_has_left_the_field(t: TestCase) -> void:
	t.start("a higher Chain Link resolves FIRST and can destroy this card: the damage still "
		+ "happens, but a card already in the Graveyard cannot add itself to the Deck")
	var d := _board(t, 7611)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var lp_before: int = engine.state.player(1).life_points
	var deck_before: int = engine.state.player(0).deck.size()

	# Chain Link 1 spacer, this card at Chain Link 2 (its shuffle branch), then a Chain Link
	# 3 that destroys it — and Chain Link 3 resolves before Chain Link 2.
	#
	# The destroyer is Set BEFORE the Chain starts: the engine does not pause when nobody
	# holds a legal response, so a card produced after Chain Link 2 was submitted would
	# arrive to find the whole Chain already resolved.
	var killer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Killer", card, "destroy"))
	var spacers := TestFixtures.build_chain_to_depth(engine, 1)
	t.eq(spacers.size(), 1, "Chain Link 1 is on the Chain")
	# The opponent now holds a response, so the window really is theirs first.
	t.eq(engine.waiting_player(), 1, "the opponent is asked first, and declines for now")
	t.is_true(engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)),
		"they pass")
	var offered = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(offered, "the card may be activated as Chain Link 2")
	t.is_true(engine.submit_action(offered), "it is Chain Link 2")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, killer.id)
	t.not_null(response, "the opponent may add Chain Link 3")
	t.is_true(engine.submit_action(response), "the destroyer is Chain Link 3")
	TestFixtures.pass_until_open(engine)

	t.eq(card.zone, Enums.Zone.GRAVEYARD,
		"Chain Link 3 destroyed it before its own link resolved")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE,
		"the damage half still happened — the activation was never negated")
	t.eq(engine.state.player(0).deck.size(), deck_before,
		"but it could not add itself to the Deck from the Graveyard")
	t.is_false(engine.state.player(0).deck.has(card), "it is not in the Deck")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

static func _test_a_negated_effect_does_nothing_at_all(t: TestCase) -> void:
	t.start("a negated EFFECT inflicts no damage and performs no self-return, but the card "
		+ "was still activated and still leaves the field")
	var d := _board(t, 7612)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silencer"))
	var lp_before: int = engine.state.player(1).life_points
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
	t.eq(engine.state.player(1).life_points, lp_before, "no damage was inflicted")
	t.eq(engine.state.player(0).deck.size(), deck_before, "and nothing was added to the Deck")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "the spent Trap still leaves the field")


static func _test_a_negated_activation_does_nothing_at_all(t: TestCase) -> void:
	t.start("a negated ACTIVATION inflicts no damage either, and the card is destroyed "
		+ "rather than returning itself anywhere")
	var d := _board(t, 7613)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))
	var lp_before: int = engine.state.player(1).life_points
	var deck_before: int = engine.state.player(0).deck.size()
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
	t.eq(engine.state.player(1).life_points, lp_before, "no damage was inflicted")
	t.eq(engine.state.player(0).deck.size(), deck_before, "nothing was added to the Deck")
	t.eq(engine.state.player(0).hand.size(), hand_before, "and nothing returned to the hand")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "the card was destroyed")


# ---------------------------------------------------------------------------
# The Chain-state read itself
# ---------------------------------------------------------------------------

static func _test_the_link_number_is_read_from_the_chain_link(t: TestCase) -> void:
	t.start("the branch is chosen from the ACTIVATION position recorded on the Chain Link, "
		+ "not from the size of the chain array at resolution time")
	var d := _board(t, 7614)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = d["card"]

	# Activated at Chain Link 2 of a THREE-link Chain. By the time this link resolves,
	# Chain Link 3 above it has already resolved and been marked resolved — so the branch
	# must come from the position RECORDED at activation, which this test reads off the
	# ChainLink directly, and not from any count taken at resolution time.
	var order_log: Array = []
	var top_effect := TestFixtures.card_activation("topper", Enums.SpellSpeed.SS2,
		order_log, "top")
	top_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	var top := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.with_effect(
		TestFixtures.trap("Topper"), top_effect))

	var spacers := TestFixtures.build_chain_to_depth(engine, 1)
	t.eq(spacers.size(), 1, "Chain Link 1 is on the Chain")
	t.eq(engine.waiting_player(), 1, "the opponent is asked first, and declines for now")
	t.is_true(engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)), "they pass")
	var offered = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(offered, "the card may be activated as Chain Link 2")
	t.is_true(engine.submit_action(offered), "it is Chain Link 2")

	var recorded := -1
	for entry in engine.state.chain:
		var link: ChainLink = entry
		if link.source_card == card:
			recorded = link.link_number
	t.eq(recorded, 2, "the Chain Link records position 2, 1-based")

	t.eq(engine.state.chain.size(), 2, "the Chain is two links deep so far")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, top.id)
	t.not_null(response, "a third link can still be added above it")
	# Nobody holds a further response, so submitting this resolves the whole Chain inside
	# one `submit_action()` — `state.chain` is empty again by the time it returns, and the
	# depth has to be read off the links that resolved.
	t.is_true(engine.submit_action(response), "the topper is Chain Link 3")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.chain.last_resolved_links.size(), 3,
		"three links resolved, so the Chain really was three deep")

	t.eq(card.zone, Enums.Zone.DECK,
		"the card took the Chain-Link-2 branch, from its recorded activation position")
	t.eq(card.last_move_reason, Enums.MoveReason.SHUFFLED_INTO_DECK,
		"and shuffled itself in, not returned to the hand")

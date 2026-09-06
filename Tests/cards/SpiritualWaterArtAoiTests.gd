class_name SpiritualWaterArtAoiTests
extends RefCounted

## `Spiritual Water Art - Aoi` — "Tribute 1 WATER monster; look at your opponent's hand,
## then send 1 card from their hand to the GY."
##
## The closest sibling of `Spiritual Fire Art - Kurenai`: the same Tribute COST with a
## different Attribute, and a completely different second half. What this suite asserts
## that no other suite in the pool can is the **hidden-information** half —
##
##   * looking reveals the hand to the LOOKER and to nobody else;
##   * looking moves nothing, and the knowledge survives the effect (RULES_SPEC §12.1);
##   * the send is a SEND, never a discard [S1 p.52-53];
##   * an **empty** opponent hand still resolves — the vacuous path is asserted in both
##     directions rather than guarded away.
##
## The generic operation itself has its own gate in `HiddenInfoTests`, written and passing
## before this card existed.

const CARD_UNDER_TEST := "Spiritual Water Art - Aoi"

## The two WATER monsters in this card's own deck.
const CRYSTAL_SEER := "Crystal Seer"
const ERIA := "Eria the Water Charmer"


static func run() -> TestCase:
	var t := TestCase.new("SpiritualWaterArtAoiTests")
	_test_the_clause_shape(t)
	_test_it_looks_at_the_hand_and_sends_one_card(t)
	_test_the_look_is_private_to_the_looking_player(t)
	_test_the_knowledge_survives_the_resolution(t)
	_test_the_looking_player_chooses_which_card_is_sent(t)
	_test_the_send_is_not_a_discard(t)
	_test_it_sends_from_the_opponents_hand_never_its_own(t)
	_test_the_card_reaches_its_owners_graveyard(t)
	_test_an_empty_opponent_hand_still_resolves(t)
	_test_a_hand_emptied_between_activation_and_resolution(t)
	_test_the_tribute_is_a_cost_paid_at_activation(t)
	_test_a_face_down_water_monster_is_a_legal_tribute(t)
	_test_it_cannot_be_activated_without_a_water_monster(t)
	_test_a_non_water_monster_is_not_a_legal_tribute(t)
	_test_an_opponents_water_monster_is_not_a_legal_tribute(t)
	_test_the_cost_is_not_refunded_when_the_activation_is_negated(t)
	_test_the_cost_is_not_refunded_when_the_effect_is_negated(t)
	_test_the_tribute_is_not_a_destruction(t)
	_test_it_is_illegal_in_the_damage_step(t)
	_test_the_trap_leaves_as_a_resolved_normal_trap(t)
	_test_it_is_live_against_the_real_printed_pool(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.new().load_library()


static func _card_def(t: TestCase, card_name: String = CARD_UNDER_TEST) -> CardDef:
	var lib := _library()
	t.eq(lib["errors"], [], "the card library loads with no errors")
	var cards: Dictionary = lib["cards"]
	t.is_true(cards.has(card_name), "the registry knows %s" % card_name)
	return cards[card_name]


static func _effect(t: TestCase) -> EffectDef:
	var def := _card_def(t)
	return def.effects[0] if not def.effects.is_empty() else null


static func _water(name: String, atk: int = 1200) -> CardDef:
	return TestFixtures.monster(name, 4, atk, 1000, "WATER")


## A duel in Main Phase 1 with the Trap Set on player 0, one WATER monster to Tribute, and
## an opponent hand of EXACTLY `hand_size` known cards — the opening hand is cleared first,
## so a test can name every card the look is supposed to find.
static func _board(t: TestCase, seed_value: int, hand_size: int = 3) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["aoi"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	d["water"] = TestFixtures.give_monster_on_field(engine, 0, _water("My Water Monster"))
	engine.state.player(1).hand.clear()
	var theirs: Array = []
	for i in range(hand_size):
		theirs.append(TestFixtures.give_to_hand(engine, 1,
			TestFixtures.monster("Their Card %d" % (i + 1), 4, 1000 + i, 1000)))
	d["theirs"] = theirs
	return d


static func _named_in_view(engine: DuelEngine, viewer: int, owner: int) -> int:
	var view := engine.get_visible_state(viewer)
	var named := 0
	for entry in view["players"][owner]["hand"]:
		if entry != null and entry.get("name") != null:
			named += 1
	return named


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal Trap card activation, Spell Speed 2, a Tribute COST, and "
		+ "NO targeting — the candidates are in a hidden zone")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.TRAP, "it is a Trap")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP, "and specifically a NORMAL Trap")
	t.eq(def.effects.size(), 1, "exactly one EffectDef, for the card's one clause")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2")
	t.is_false(clause.targets,
		"it does NOT target — the choice is made at resolution, from a hidden zone")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Trap is activated from a Set position, never from the hand")
	t.eq(clause.damage_step_permission, Enums.DamageStepPermission.NONE,
		"cid 6440: it cannot be activated in the Damage Step")
	t.is_true(clause.can_pay_cost.is_valid(), "it declares a cost check")
	t.is_true(clause.pay_cost.is_valid(), "and a cost payment, so the Tribute is a COST")
	t.is_true(clause.clause_text.contains("Tribute 1 WATER monster"),
		"the clause quotes the official cost")
	t.is_true(clause.clause_text.contains("look at your opponent's hand"),
		"and quotes the LOOK, which is the half nothing else in the pool does")


# ---------------------------------------------------------------------------
# The hidden-information half
# ---------------------------------------------------------------------------

static func _test_it_looks_at_the_hand_and_sends_one_card(t: TestCase) -> void:
	t.start("it looks at the whole opponent hand and sends exactly ONE card from it")
	var d := _board(t, 8201, 3)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	var gy_before: int = engine.state.player(1).graveyard.size()

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]),
		"the Trap is activated with no target")
	t.eq(engine.state.player(1).hand.size(), 2, "their hand went from 3 cards to 2")
	t.eq(engine.state.player(1).graveyard.size(), gy_before + 1,
		"and exactly one card reached the Graveyard")

	var sent := 0
	for entry in theirs:
		var card: CardInstance = entry
		# Every card was LOOKED at, whether or not it was the one sent.
		t.is_true(card.revealed_to.has(0), "%s was looked at" % card.card_name())
		if card.zone == Enums.Zone.GRAVEYARD:
			sent += 1
	t.eq(sent, 1, "exactly one of the three was sent, not all of them")


static func _test_the_look_is_private_to_the_looking_player(t: TestCase) -> void:
	t.start("the look reveals the hand to the LOOKER only: the opponent learns nothing, "
		+ "and nothing about it reaches the public log")
	var d := _board(t, 8202, 3)
	var engine: DuelEngine = d["engine"]
	t.eq(_named_in_view(engine, 0, 1), 0,
		"before the look, the looker sees none of the opponent's hand")
	var mark: int = engine.state.events.size()

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")

	# Two cards are left in the hand; both are now named in the looker's view.
	t.eq(engine.state.player(1).hand.size(), 2, "two cards remain in the hand")
	t.eq(_named_in_view(engine, 0, 1), 2,
		"and the looker can name both of them")
	t.eq(_named_in_view(engine, 1, 0), 0,
		"while the opponent still sees nothing of the LOOKER's hand")

	var reveals := TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED, mark)
	t.eq(reveals.size(), 3, "one reveal per card in the hand that was looked at")
	t.eq(reveals.filter(func(e): return e.is_public()).size(), 0,
		"not one of them is public — a look is not a reveal to the table")


static func _test_the_knowledge_survives_the_resolution(t: TestCase) -> void:
	t.start("RULES_SPEC §12.1: what was seen stays seen. A card looked at and NOT sent is "
		+ "still known turns later — there is no `forget`, deliberately")
	var d := _board(t, 8203, 3)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var theirs: Array = d["theirs"]
	var doomed: CardInstance = theirs[0]
	var survivor: CardInstance = theirs[1]
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [doomed.id])

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(doomed.zone, Enums.Zone.GRAVEYARD, "the chosen card was sent")
	t.eq(survivor.zone, Enums.Zone.HAND, "the other one stayed in the hand")
	t.is_true(survivor.revealed_to.has(0), "and it is known to the looker")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.eq(survivor.zone, Enums.Zone.HAND, "it is still in the hand two turns later")
	t.is_true(survivor.revealed_to.has(0), "and it is still known")


static func _test_the_looking_player_chooses_which_card_is_sent(t: TestCase) -> void:
	t.start("R42 Part B: the ACTIVATING player chooses which card is sent, and the choice "
		+ "is a logged duel input rather than a silent pick")
	var d := _board(t, 8204, 3)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var theirs: Array = d["theirs"]
	var wanted: CardInstance = theirs[2]
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [wanted.id])

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(wanted.zone, Enums.Zone.GRAVEYARD, "the CHOSEN card was the one sent")
	t.eq((theirs[0] as CardInstance).zone, Enums.Zone.HAND, "the first is untouched")
	t.eq((theirs[1] as CardInstance).zone, Enums.Zone.HAND, "and so is the second")


static func _test_the_send_is_not_a_discard(t: TestCase) -> void:
	t.start("[S1 p.52-53]: the card reaches the Graveyard as a SEND BY EFFECT. A discard is "
		+ "a player's own hand, and this is not one")
	var d := _board(t, 8205, 1)
	var engine: DuelEngine = d["engine"]
	var only: CardInstance = (d["theirs"] as Array)[0]

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")
	t.eq(only.zone, Enums.Zone.GRAVEYARD, "the one card was sent")
	t.eq(only.last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"with the SEND-BY-EFFECT reason")
	t.ne(only.last_move_reason, Enums.MoveReason.DISCARDED,
		"and emphatically NOT the DISCARD reason")
	t.ne(only.last_move_reason, Enums.MoveReason.SENT_AS_COST,
		"nor the cost reason — the send is the effect, not the payment")


static func _test_it_sends_from_the_opponents_hand_never_its_own(t: TestCase) -> void:
	t.start("it sends from THEIR hand: the controller's own hand is untouched, however "
		+ "many cards are in it")
	var d := _board(t, 8206, 2)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("My Own Card", 4, 1000, 1000))
	var own_before: int = engine.state.player(0).hand.size()

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")
	t.eq(engine.state.player(0).hand.size(), own_before,
		"the controller's own hand is exactly the same size")
	t.eq(mine.zone, Enums.Zone.HAND, "and their own card is still in it")
	t.eq(engine.state.player(1).hand.size(), 1, "while the opponent lost one")


static func _test_the_card_reaches_its_owners_graveyard(t: TestCase) -> void:
	t.start("[S1 p.52]: the card goes to its OWNER's Graveyard, not the activating "
		+ "player's")
	var d := _board(t, 8207, 1)
	var engine: DuelEngine = d["engine"]
	var only: CardInstance = (d["theirs"] as Array)[0]
	var own_gy: int = engine.state.player(0).graveyard.size()

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")
	t.is_true(engine.state.player(1).graveyard.has(only),
		"the card is in the OPPONENT's Graveyard")
	t.is_false(engine.state.player(0).graveyard.has(only),
		"and not in the activating player's")
	# The controller's own Graveyard grows by exactly TWO, and neither is the sent card:
	# the Tributed WATER monster (the cost) and the resolved Trap itself.
	t.eq(engine.state.player(0).graveyard.size(), own_gy + 2,
		"the controller's Graveyard gains exactly its own two cards")
	t.is_true(engine.state.player(0).graveyard.has(d["water"]),
		"the Tributed monster, which is the cost")
	t.is_true(engine.state.player(0).graveyard.has(d["aoi"]),
		"and the resolved Trap — but never the opponent's sent card")


# ---------------------------------------------------------------------------
# The vacuous paths, asserted rather than guarded away
# ---------------------------------------------------------------------------

static func _test_an_empty_opponent_hand_still_resolves(t: TestCase) -> void:
	t.start("R42 Part B: an EMPTY opponent hand does not stop the activation. The card is "
		+ "activated, the cost IS paid, and it resolves having sent nothing — which must "
		+ "be distinguishable from the card never resolving at all")
	var d := _board(t, 8208, 0)
	var engine: DuelEngine = d["engine"]
	var water: CardInstance = d["water"]
	var aoi: CardInstance = d["aoi"]
	t.eq(engine.state.player(1).hand.size(), 0, "the opponent's hand really is empty")
	var their_gy: int = engine.state.player(1).graveyard.size()

	t.is_true(TestFixtures.activate_card(engine, 0, aoi),
		"the activation is legal against an empty hand")
	# The four things that separate "resolved for nothing" from "did not happen".
	t.eq(water.zone, Enums.Zone.GRAVEYARD, "the cost was really paid")
	t.eq(water.last_move_reason, Enums.MoveReason.TRIBUTED, "as a Tribute")
	t.eq(aoi.zone, Enums.Zone.GRAVEYARD, "the Trap really resolved and left")
	t.eq(aoi.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY, "as a RESOLVED Trap")
	t.eq(engine.state.player(1).graveyard.size(), their_gy,
		"while nothing at all was sent from the empty hand")

	# The duel log must say WHICH vacuous outcome this was. "Looked at an empty hand" and
	# "could not choose a card" are different facts about the same board, and only the
	# first one is true here — a replay that cannot tell them apart is a worse record.
	var resolutions := TestFixtures.events_of(engine,
		GameEvent.Kind.CHAIN_LINK_RESOLVED)
	t.is_true(resolutions.size() >= 1, "the link really did resolve")
	var note := str((resolutions[resolutions.size() - 1] as GameEvent).data.get("note", ""))
	t.is_true(note.contains("empty"),
		"and the resolution note records that the hand was empty: %s" % note)
	t.is_false(note.contains("no card could be chosen"),
		"not the different, wrong reason that a card was unpickable")


static func _test_a_hand_emptied_between_activation_and_resolution(t: TestCase) -> void:
	t.start("the hand is read at RESOLUTION: a hand emptied after the activation sends "
		+ "nothing, and the card still resolves")
	var d := _board(t, 8209, 2)
	var engine: DuelEngine = d["engine"]
	var order_log: Array = []
	var spacer := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.with_effect(
		TestFixtures.trap("Spacer"),
		TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["aoi"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "and made as Chain Link 1")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, spacer.id)
	t.not_null(response, "a response window is open")
	t.is_true(engine.submit_action(response), "the spacer is Chain Link 2")
	# Emptied while the Chain is built, before Aoi's link resolves.
	engine.state.player(1).hand.clear()
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).hand.size(), 0, "the hand is empty at resolution")
	t.eq(d["aoi"].zone, Enums.Zone.GRAVEYARD, "and the Trap resolved anyway")
	t.eq((d["water"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"with the cost still spent")


# ---------------------------------------------------------------------------
# The cost half — shared shape with Kurenai and Miyabi
# ---------------------------------------------------------------------------

static func _test_the_tribute_is_a_cost_paid_at_activation(t: TestCase) -> void:
	t.start("the Tribute is a COST: it is paid at ACTIVATION, and nothing leaves the "
		+ "opponent's hand until the link resolves")
	var d := _board(t, 8210, 2)
	var engine: DuelEngine = d["engine"]
	var water: CardInstance = d["water"]
	var order_log: Array = []
	var spacer := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.with_effect(
		TestFixtures.trap("Spacer"),
		TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["aoi"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is activated as Chain Link 1")

	t.eq(water.zone, Enums.Zone.GRAVEYARD,
		"the Tributed monster is ALREADY in the Graveyard, before any resolution")
	t.eq(water.last_move_reason, Enums.MoveReason.TRIBUTED, "with the TRIBUTED reason")
	t.eq(engine.state.player(1).hand.size(), 2,
		"while the opponent's hand is untouched — the look is the effect, not the cost")
	for entry in d["theirs"]:
		t.is_false((entry as CardInstance).revealed_to.has(0),
			"and nothing has been looked at yet either")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, spacer.id)
	t.not_null(response, "a response window is genuinely open")
	t.is_true(engine.submit_action(response), "the spacer is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(1).hand.size(), 1, "and only then is a card sent")


static func _test_a_face_down_water_monster_is_a_legal_tribute(t: TestCase) -> void:
	t.start("cid 6440 (表示形式を問わず): a face-DOWN WATER monster is a legal Tribute")
	var d := TestFixtures.new_duel(8211, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var aoi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var hidden := TestFixtures.give_monster_on_field(engine, 0, _water("Set Water"),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_true(hidden.is_face_down(), "the monster really is face-down")

	t.is_true(TestFixtures.activate_card(engine, 0, aoi),
		"the Trap is activated with only a face-down WATER monster to pay with")
	t.eq(hidden.zone, Enums.Zone.GRAVEYARD, "the face-down monster was Tributed")


static func _test_it_cannot_be_activated_without_a_water_monster(t: TestCase) -> void:
	t.start("with no WATER monster on your field the cost cannot be paid, so the card is "
		+ "not offered at all — even with a full opponent hand to look at")
	var d := TestFixtures.new_duel(8212, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var aoi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))

	t.is_true(engine.state.player(1).hand.size() > 0,
		"the opponent does have a hand, so it is the COST that is missing")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, aoi.id),
		"an empty field offers no activation")
	t.eq(aoi.zone, Enums.Zone.SPELL_TRAP_ZONE, "and the Trap is still Set")


static func _test_a_non_water_monster_is_not_a_legal_tribute(t: TestCase) -> void:
	t.start("a FIRE monster is not a legal Tribute for the WATER cost — and the same board "
		+ "becomes legal the moment a WATER monster joins it")
	var d := TestFixtures.new_duel(8213, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var aoi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var fire := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Fire Monster", 4, 1900, 1000, "FIRE"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, aoi.id),
		"a FIRE monster does not enable the WATER cost")
	t.eq(fire.zone, Enums.Zone.MONSTER_ZONE, "and it is untouched")

	TestFixtures.give_monster_on_field(engine, 0, _water("Now A Water Monster"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, aoi.id),
		"one WATER monster later, the same Trap IS offered")


static func _test_an_opponents_water_monster_is_not_a_legal_tribute(t: TestCase) -> void:
	t.start("a Tribute is always your OWN monster [S1 p.23]: an opponent's WATER monster "
		+ "does not enable the cost")
	var d := TestFixtures.new_duel(8214, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var aoi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _water("Their Water"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, aoi.id),
		"the opponent's WATER monster is not yours to Tribute")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "and it stays on their field")


# ---------------------------------------------------------------------------
# Negation — the cost stays paid, and nothing is looked at
# ---------------------------------------------------------------------------

static func _test_the_cost_is_not_refunded_when_the_activation_is_negated(
		t: TestCase) -> void:
	t.start("the ACTIVATION negated: the Tribute is NOT refunded, no card is sent, and the "
		+ "hand is never looked at")
	var d := _board(t, 8215, 3)
	var engine: DuelEngine = d["engine"]
	var water: CardInstance = d["water"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Test Counter"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["aoi"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "and made")
	t.eq(water.zone, Enums.Zone.GRAVEYARD, "the cost is paid at once")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and negates the activation")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).hand.size(), 3, "no card was sent")
	for entry in d["theirs"]:
		t.is_false((entry as CardInstance).revealed_to.has(0),
			"and the hand was never looked at — a negated effect reveals nothing")
	t.eq(water.zone, Enums.Zone.GRAVEYARD,
		"while the Tributed monster stays in the Graveyard — a cost is never refunded")


static func _test_the_cost_is_not_refunded_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("the EFFECT negated: the activation happened, the Tribute stays spent, and "
		+ "again nothing is looked at or sent")
	var d := _board(t, 8216, 3)
	var engine: DuelEngine = d["engine"]
	var water: CardInstance = d["water"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Test Effect Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["aoi"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "and made")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and negates the EFFECT")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).hand.size(), 3, "no card was sent")
	for entry in d["theirs"]:
		t.is_false((entry as CardInstance).revealed_to.has(0),
			"and nothing was looked at")
	t.eq(water.zone, Enums.Zone.GRAVEYARD, "the Tributed monster is still in the Graveyard")


static func _test_the_tribute_is_not_a_destruction(t: TestCase) -> void:
	t.start("a Tribute is not a destruction: no CARD_DESTROYED event names the Tributed "
		+ "monster")
	var d := _board(t, 8217, 2)
	var engine: DuelEngine = d["engine"]
	var water: CardInstance = d["water"]

	t.is_true(TestFixtures.activate_card(engine, 0, d["aoi"]), "activated")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, water.id), 0,
		"the Tributed monster was never destroyed")
	t.eq(water.last_move_reason, Enums.MoveReason.TRIBUTED,
		"it reached the Graveyard as a Tribute")


static func _test_it_is_illegal_in_the_damage_step(t: TestCase) -> void:
	t.start("cid 6440 (ダメージステップ中には発動できません): the rules layer refuses it "
		+ "inside the Damage Step, and allows it outside")
	var d := _board(t, 8218, 2)
	var engine: DuelEngine = d["engine"]
	var e := _effect(t)
	t.not_null(e, "the clause is reachable")
	if e == null:
		return
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"no Damage Step permission is declared")
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_false(ActivationRules.damage_step_ok(engine.state, e),
		"the rules layer refuses it inside the Damage Step")
	engine.state.battle_step = Enums.BattleStep.NONE
	engine.state.damage_substep = Enums.DamageSubStep.NONE
	t.is_true(ActivationRules.damage_step_ok(engine.state, e),
		"while outside it the same question says yes")


static func _test_the_trap_leaves_as_a_resolved_normal_trap(t: TestCase) -> void:
	t.start("the Normal Trap goes to the Graveyard after resolving, as a resolution rather "
		+ "than as a destruction")
	var d := _board(t, 8219, 2)
	var engine: DuelEngine = d["engine"]
	var aoi: CardInstance = d["aoi"]

	t.is_true(TestFixtures.activate_card(engine, 0, aoi), "activated")
	t.eq(aoi.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(aoi.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"it left as a RESOLVED Normal Trap, not as a destroyed one")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, aoi.id), 0,
		"and nothing destroyed it")


# ---------------------------------------------------------------------------
# The real printed pool
# ---------------------------------------------------------------------------

static func _test_it_is_live_against_the_real_printed_pool(t: TestCase) -> void:
	t.start("live on real cards: `Crystal Seer` and `Eria the Water Charmer` are the WATER "
		+ "monsters in this card's own deck, and either one pays the cost")
	for water_name in [CRYSTAL_SEER, ERIA]:
		var d := TestFixtures.new_duel(8220, 0)
		var engine: DuelEngine = d["engine"]
		TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
		var aoi := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
		var water_def := _card_def(t, water_name)
		t.eq(water_def.attribute, "WATER", "%s really is WATER" % water_name)
		var water := TestFixtures.give_monster_on_field(engine, 0, water_def)
		engine.state.player(1).hand.clear()
		var victim := TestFixtures.give_to_hand(engine, 1,
			TestFixtures.monster("Their Only Card", 4, 1000, 1000))

		t.is_true(TestFixtures.activate_card(engine, 0, aoi),
			"the Trap is activated with %s to pay with" % water_name)
		t.eq(water.zone, Enums.Zone.GRAVEYARD, "%s was Tributed" % water_name)
		t.eq(victim.zone, Enums.Zone.GRAVEYARD, "and their card was sent")

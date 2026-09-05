class_name DragonShrineTests
extends RefCounted

## Per-card suite for `Dragon Shrine` — "Send 1 Dragon monster from your Deck to the GY,
## then, if that monster in your GY is a Dragon Normal Monster, you can send 1 more Dragon
## monster from your Deck to the GY. You can only activate 1 'Dragon Shrine' per turn."
##
## The pool's only MILL. Everything asserted here is fixed by the official supplement
## (cid 10590, 2024-03-23) and its two Q&As: the two sends are sequential and not
## simultaneous, the second is optional, the Normal-Monster test reads the GY rather than
## the print, and the cap is two.

const CARD_UNDER_TEST := "Dragon Shrine"
const EFFECT_ID := "send_dragon_then_maybe_one_more"


static func run() -> TestCase:
	var t := TestCase.new("DragonShrineTests")
	_test_clause_shape(t)
	_test_normal_dragon_unlocks_the_second_send(t)
	_test_effect_dragon_does_not_unlock_it(t)
	_test_the_second_send_is_optional(t)
	_test_the_cap_is_two(t)
	_test_only_dragons_are_candidates(t)
	_test_not_offered_without_a_dragon_in_the_deck(t)
	_test_once_per_turn_activation(t)
	_test_negation_sends_nothing(t)
	_test_the_mill_feeds_the_graveyard_cards(t)
	_test_real_pool(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _dragon(name: String, normal: bool = true) -> CardDef:
	var d := TestFixtures.monster(name)
	d.race = "Dragon"
	d.is_normal_monster = normal
	d.is_effect_monster = not normal
	return d


static func _not_a_dragon(name: String) -> CardDef:
	var d := TestFixtures.monster(name)
	d.race = "Warrior"
	return d


## A duel whose Deck for player 0 is exactly `deck_defs`, with Dragon Shrine in hand.
static func _board(seed_value: int, deck_defs: Array) -> Dictionary:
	var d := _duel(seed_value)
	var e: DuelEngine = d["engine"]
	TestFixtures.clear_deck(e, 0)
	var made: Array = []
	for entry in deck_defs:
		made.append(TestFixtures.give_to_deck(e, 0, entry))
	d["deck"] = made
	d["shrine"] = TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	return d


static func _queue_send(d: Dictionary, card: CardInstance) -> void:
	(d["p0"] as ScriptedController).queue_for(Enums.DecisionKind.SELECT_EXACTLY, [card.id])


static func _queue_yes(d: Dictionary, answer: bool) -> void:
	(d["p0"] as ScriptedController).queue_for(Enums.DecisionKind.YES_NO, answer)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Dragon Shrine: one clause, a Normal Spell, no cost, no target, 1 per turn")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.SPELL, "it is a Spell")
	t.eq(d.st_kind, Enums.STKind.NORMAL_SPELL, "a NORMAL Spell")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION, "a CARD_ACTIVATION")
	t.is_false(e.targets, "it does not target - both sends happen at resolution")
	t.is_false(e.pay_cost.is_valid(),
		"and it has NO cost: nothing precedes a semicolon, so both sends are the EFFECT")
	t.is_true(e.once_per_turn_named_activation,
		"'You can only ACTIVATE 1 per turn' is a named ACTIVATION limit")
	t.is_false(e.once_per_turn_named_effect,
		"and NOT a named EFFECT limit - the two are different restrictions")
	t.is_false(e.once_per_turn_instance, "nor an instance limit")
	t.is_true(e.condition.is_valid(), "it declares an activation condition")


# ---------------------------------------------------------------------------
# The two sends
# ---------------------------------------------------------------------------

static func _test_normal_dragon_unlocks_the_second_send(t: TestCase) -> void:
	t.start("Dragon Shrine: a Dragon NORMAL Monster unlocks the optional second send")
	var d := _board(57001, [_dragon("Normal dragon"), _dragon("Second dragon"),
		_not_a_dragon("Not a dragon")])
	var e: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	_queue_send(d, deck[0])
	_queue_yes(d, true)
	_queue_send(d, deck[1])
	var gy_before := e.state.player(0).graveyard.size()

	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "activated and resolved")
	t.eq((d["p0"] as ScriptedController).errors, [],
		"every queued answer went to the prompt this test meant")
	t.eq(deck[0].zone, Enums.Zone.GRAVEYARD, "the first Dragon was milled")
	t.eq(deck[0].last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"sent by an effect, not destroyed and not discarded")
	t.eq(deck[1].zone, Enums.Zone.GRAVEYARD, "and so was the second")
	t.eq(deck[2].zone, Enums.Zone.DECK, "the non-Dragon stayed in the Deck")
	# GY: +2 milled, +1 the spent Normal Spell.
	t.eq(e.state.player(0).graveyard.size(), gy_before + 3,
		"two mills plus the spent Spell reached the GY")
	t.eq(e.state.player(0).deck_count(), 1, "exactly two cards left the Deck")
	t.is_false(e.state.is_duel_over(), "a mill is never a deck-out")


static func _test_effect_dragon_does_not_unlock_it(t: TestCase) -> void:
	t.start("Dragon Shrine: a Dragon EFFECT Monster gives no second send, and asks nothing")
	var d := _board(57002, [_dragon("Effect dragon", false), _dragon("Normal dragon")])
	var e: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	var ctrl: ScriptedController = d["p0"]
	_queue_send(d, deck[0])
	# A YES and a second send are queued that a CORRECT build must never consume: the gate
	# is the condition, so the optional step is never even offered. Asserting the queue is
	# still full afterwards is what makes this test catch a build that drops the gate — the
	# controller's default answer to a "you can" is "no", so a bare board assertion would
	# not notice.
	_queue_yes(d, true)
	_queue_send(d, deck[1])
	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "activated and resolved")
	t.eq(ctrl.answers.size(), 2,
		"neither queued answer was consumed - the second send was never reached")
	t.eq(ctrl.errors, [], "the queued send answer went to the prompt this test meant")
	t.eq(deck[0].zone, Enums.Zone.GRAVEYARD, "the Effect Dragon was milled")
	t.eq(deck[1].zone, Enums.Zone.DECK,
		"but the second send did NOT happen - the first was not a Normal Monster")
	t.eq(e.state.player(0).deck_count(), 1, "exactly one card left the Deck")
	var asked_yes_no := 0
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.YES_NO:
			asked_yes_no += 1
	t.eq(asked_yes_no, 0,
		"and the optional second send was never even OFFERED - the gate is the condition")


static func _test_the_second_send_is_optional(t: TestCase) -> void:
	t.start("Dragon Shrine: the second send is a real 'you can', and declining is legal")
	var d := _board(57003, [_dragon("Normal dragon"), _dragon("Second dragon")])
	var e: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	var ctrl: ScriptedController = d["p0"]
	_queue_send(d, deck[0])
	_queue_yes(d, false)
	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "activated and resolved")
	t.eq(ctrl.errors, [], "the queued answers went to the prompts this test meant")
	t.eq(deck[0].zone, Enums.Zone.GRAVEYARD, "the first Dragon was milled")
	t.eq(deck[1].zone, Enums.Zone.DECK, "the declined second send did not happen")
	var asked_yes_no := 0
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.YES_NO:
			asked_yes_no += 1
	t.eq(asked_yes_no, 1, "but it WAS offered - exactly one yes/no question was asked")
	t.eq(e.state.player(0).deck_count(), 1, "only one card left the Deck")


static func _test_the_cap_is_two(t: TestCase) -> void:
	t.start("Dragon Shrine: at most TWO - a Normal Dragon sent SECOND starts no third send")
	var d := _board(57004, [_dragon("Normal A"), _dragon("Normal B"), _dragon("Normal C"),
		_dragon("Normal D")])
	var e: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	var ctrl: ScriptedController = d["p0"]
	_queue_send(d, deck[0])
	_queue_yes(d, true)
	_queue_send(d, deck[1])
	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "activated and resolved")
	t.eq(ctrl.errors, [], "every queued answer landed where the test meant")
	t.eq(deck[0].zone, Enums.Zone.GRAVEYARD, "the first was milled")
	t.eq(deck[1].zone, Enums.Zone.GRAVEYARD,
		"the second was milled, and it too is a Dragon Normal Monster")
	t.eq(deck[2].zone, Enums.Zone.DECK, "but no THIRD send happened")
	t.eq(deck[3].zone, Enums.Zone.DECK, "and certainly no fourth")
	t.eq(e.state.player(0).deck_count(), 2, "exactly two cards left the Deck")
	var asked_yes_no := 0
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.YES_NO:
			asked_yes_no += 1
	t.eq(asked_yes_no, 1, "and only ONE optional-send question was ever asked")


static func _test_only_dragons_are_candidates(t: TestCase) -> void:
	t.start("Dragon Shrine: only Dragon MONSTERS are ever offered, by RACE not by name")
	var d := _board(57005, [
		_dragon("An actual dragon"),
		_not_a_dragon("Dragon Knight of Warriors"),
		TestFixtures.spell("A spell"),
	])
	var e: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	var ctrl: ScriptedController = d["p0"]
	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "activated and resolved")
	t.eq(deck[0].zone, Enums.Zone.GRAVEYARD, "the one real Dragon was milled")
	t.eq(deck[1].zone, Enums.Zone.DECK,
		"a Warrior named 'Dragon Knight...' was never a candidate")
	t.eq(deck[2].zone, Enums.Zone.DECK, "and neither was a Spell")
	# With exactly one candidate nothing is asked, which is itself the assertion.
	var asked_select := 0
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.SELECT_EXACTLY:
			asked_select += 1
	t.eq(asked_select, 0, "with one candidate there was nothing to decide, so nothing asked")


static func _test_not_offered_without_a_dragon_in_the_deck(t: TestCase) -> void:
	t.start("Dragon Shrine: no Dragon in the Deck means the activation is not offered")
	var d := _board(57006, [_not_a_dragon("Warrior"), TestFixtures.spell("A spell")])
	var e: DuelEngine = d["engine"]
	# Dragons ANYWHERE ELSE must not help.
	TestFixtures.give_monster_on_field(e, 0, _dragon("On the field"))
	TestFixtures.give(e, 0, _dragon("In the GY"), Enums.Zone.GRAVEYARD)
	TestFixtures.give_to_hand(e, 0, _dragon("In the hand"))
	TestFixtures.give_to_deck(e, 1, _dragon("In THEIR deck"))
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, (d["shrine"] as CardInstance).id),
		"not offered: the Dragon must be in the controller's own DECK")
	var joined := TestFixtures.give_to_deck(e, 0, _dragon("Now in the deck"))
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, (d["shrine"] as CardInstance).id),
		"offered the moment one is in the Deck")
	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "and it resolves")
	t.eq(joined.zone, Enums.Zone.GRAVEYARD, "milling that one")


static func _test_once_per_turn_activation(t: TestCase) -> void:
	t.start("Dragon Shrine: only 1 per turn, by NAME, and it resets next turn")
	var d := _board(57007, [_dragon("A"), _dragon("B"), _dragon("C"), _dragon("D")])
	var e: DuelEngine = d["engine"]
	var second_copy := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var ctrl: ScriptedController = d["p0"]
	var deck: Array = d["deck"]
	_queue_send(d, deck[0])
	_queue_yes(d, false)
	t.is_true(TestFixtures.activate_card(e, 0, d["shrine"]), "the first copy activated")
	t.eq(ctrl.errors, [], "queued answers landed correctly")
	t.eq(deck[0].zone, Enums.Zone.GRAVEYARD, "and milled one")
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second_copy.id),
		"a DIFFERENT copy cannot be activated in the same turn - the limit is on the NAME")
	TestFixtures.end_turn(e)
	TestFixtures.end_turn(e)
	t.eq(e.state.turn_player_id, 0, "it is player 0's turn again")
	# A new turn begins in the DRAW phase, and a Normal Spell needs a Main Phase.
	TestFixtures.advance_to_phase(e, Enums.Phase.MAIN_1)
	t.eq(e.state.phase, Enums.Phase.MAIN_1, "and we are back in Main Phase 1")
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second_copy.id),
		"and the allowance reset")


static func _test_negation_sends_nothing(t: TestCase) -> void:
	t.start("Dragon Shrine: a negated activation mills nothing - both sends are the EFFECT")
	var d := _board(57008, [_dragon("A"), _dragon("B")])
	var e: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	var negator := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.activation_negator("Negate it"))
	var deck_before := e.state.player(0).deck_count()
	var offered = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, (d["shrine"] as CardInstance).id)
	t.not_null(offered, "activation offered")
	if offered == null:
		return
	t.is_true(e.submit_action(offered), "activation submitted")
	t.eq(e.state.player(0).deck_count(), deck_before,
		"nothing was milled at activation - there is no cost here")
	var response = TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "a real negator response was offered")
	if response == null:
		return
	t.is_true(e.submit_action(response), "the negator activated")
	TestFixtures.pass_until_open(e)
	t.check(TestFixtures.count_events(e, GameEvent.Kind.ACTIVATION_NEGATED) >= 1,
		"the activation really was negated")
	t.eq(deck[0].zone, Enums.Zone.DECK, "the first Dragon stayed in the Deck")
	t.eq(deck[1].zone, Enums.Zone.DECK, "and so did the second")
	t.eq(e.state.player(0).deck_count(), deck_before, "nothing was milled at all")


static func _test_the_mill_feeds_the_graveyard_cards(t: TestCase) -> void:
	t.start("Dragon Shrine: milling The White Stone of Legend fires its GY trigger")
	var d := _duel(57009)
	var e: DuelEngine = d["engine"]
	TestFixtures.clear_deck(e, 0)
	var stone := TestFixtures.give_to_deck(e, 0, _card("The White Stone of Legend"))
	var bewd := TestFixtures.give_to_deck(e, 0, _card("Blue-Eyes White Dragon"))
	TestFixtures.give_to_deck(e, 0, TestFixtures.monster("Padding"))
	var shrine := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var ctrl: ScriptedController = d["p0"]
	# Both are Dragons, so both are candidates; mill the stone deliberately.
	ctrl.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [stone.id])
	var links_before := TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
	t.is_true(TestFixtures.activate_card(e, 0, shrine), "Dragon Shrine activated")
	t.eq(ctrl.errors, [], "the stone really was the card milled")
	t.eq(stone.zone, Enums.Zone.GRAVEYARD, "the stone reached the Graveyard")
	t.check(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before >= 2,
		"the stone's own GY trigger REALLY activated off the mill")
	t.eq(bewd.zone, Enums.Zone.HAND,
		"and it searched Blue-Eyes White Dragon out of the Deck")
	# The stone is an EFFECT monster, so it never unlocks the second send.
	t.is_false((_card("The White Stone of Legend") as CardDef).is_normal_monster,
		"the stone is not a Normal Monster, so there was no second send to offer")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Dragon Shrine: deck 1's Dragons, and which of them unlock the second send")
	var cards: Dictionary = CardRegistry.load_library()["cards"]
	const DECK1 := "Blue-Eyes Dragon Guard"
	t.is_true(TradeInTests.deck_names(CARD_UNDER_TEST).has(DECK1), "Dragon Shrine is in deck 1")
	var normals: Array = []
	var effects: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if not (def.is_monster() and def.race == "Dragon"):
			continue
		if not TradeInTests.deck_names(def.name).has(DECK1):
			continue
		if def.is_normal_monster:
			normals.append(def.name)
		else:
			effects.append(def.name)
	normals.sort()
	effects.sort()
	t.eq(normals, ["Alexandrite Dragon", "Blue-Eyes White Dragon", "Flamvell Guard",
		"Luster Dragon", "Rabidragon"],
		"deck 1's Dragon NORMAL Monsters - the ones that unlock the second send")
	t.eq(effects, ["Divine Dragon Apocralyph", "Hieratic Dragon of Tefnuit", "Kaiser Glider",
		"Mirage Dragon", "Rider of the Storm Winds", "The White Stone of Legend"],
		"and deck 1's Dragon EFFECT Monsters, which do not")
	t.check(normals.size() >= 2,
		"at least two Normal Dragons, so the two-send line is genuinely reachable")
	# Nothing in the pool is 'treated as a Normal Monster in the GY', so the fid 12831
	# distinction never bites here - but the implementation still reads the GY, not the print.
	var gemini: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.monster_subtypes.has("Gemini"):
			gemini.append(def.name)
	t.eq(gemini, [],
		"the pool has no Gemini monsters, so print and GY identity always agree here")

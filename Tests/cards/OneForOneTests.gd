class_name OneForOneTests
extends RefCounted

## Per-card suite for `One for One` — "Send 1 monster from your hand to the GY;
## Special Summon 1 Level 1 monster from your hand or Deck."
##
## Two things make this card worth its own suite. Its cost is a SEND, not a discard, and
## PSCT treats those as different words. And it is the first card whose cost can destroy
## its own effect: send your last Level 1 monster and the resolution finds nothing. That
## branch is asserted rather than avoided.

const CARD_UNDER_TEST := "One for One"

const EFFECT_ID := "send_monster_summon_level_1"


static func run() -> TestCase:
	var t := TestCase.new("OneForOneTests")
	_test_clause_shape(t)
	_test_sends_a_monster_and_summons_from_the_deck(t)
	_test_the_cost_is_a_send_not_a_discard(t)
	_test_a_level_1_monster_in_hand_is_also_a_candidate(t)
	_test_not_offered_without_a_monster_in_hand(t)
	_test_not_offered_without_a_level_1_monster_anywhere(t)
	_test_not_offered_with_a_full_monster_zone(t)
	_test_paying_away_the_last_level_1_monster(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _one_def() -> CardDef:
	return _card(CARD_UNDER_TEST)


## A duel whose Decks hold no monsters at all, so every Level 1 candidate in a test is
## one the test put there. `filler_deck` is 40 Level 4 vanillas, which is already free of
## Level 1 monsters, but saying so here is what makes the negatives meaningful.
static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _into_deck(engine: DuelEngine, pid: int, def: CardDef) -> CardInstance:
	return TestFixtures.give(engine, pid, def, Enums.Zone.DECK)


static func _count_monsters_in(cards: Array) -> int:
	var n := 0
	for entry in cards:
		var card: CardInstance = entry
		if card.is_monster():
			n += 1
	return n


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("the clause is a non-targeting Normal Spell activation with a send-from-hand "
		+ "cost")
	var def := _one_def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.NORMAL_SPELL, "the card database says Normal Spell")
	t.eq(def.effects.size(), 1, "one EffectDef per official clause, and this card has one")
	var effect: EffectDef = def.effects[0]

	t.eq(effect.effect_type, Enums.EffectType.CARD_ACTIVATION, "activating the card is it")
	t.eq(effect.spell_speed, Enums.SpellSpeed.SS1, "a Normal Spell is Spell Speed 1")
	t.is_false(effect.targets, "the text has no 'target'")
	t.is_true(effect.can_pay_cost.is_valid(), "the cost is checked before it is offered")
	t.is_true(effect.pay_cost.is_valid(), "and paid at activation")


# ---------------------------------------------------------------------------
# Positively
# ---------------------------------------------------------------------------

static func _test_sends_a_monster_and_summons_from_the_deck(t: TestCase) -> void:
	t.start("a monster is sent from the hand and a Level 1 monster arrives from the Deck")
	var d := _main_phase_duel(9601)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	var prize := _into_deck(engine, 0, _card("Flamvell Guard"))
	var deck_before := engine.state.player(0).deck.size()
	# The opening hand is five monsters too, so which one pays the cost is a real choice.
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [fodder.id])

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.not_null(action, "One for One is offered")
	t.is_true(engine.submit_action(action), "and is activated")

	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the cost was paid at activation, before any response window")
	TestFixtures.pass_until_open(engine)

	t.eq(prize.zone, Enums.Zone.MONSTER_ZONE, "the Level 1 monster arrived from the Deck")
	t.eq(prize.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.eq(engine.state.player(0).deck.size(), deck_before - 1, "the Deck lost one card")
	t.eq(one.zone, Enums.Zone.GRAVEYARD,
		"and the Normal Spell went to the Graveyard after resolving")


static func _test_the_cost_is_a_send_not_a_discard(t: TestCase) -> void:
	t.start("'Send 1 monster from your hand to the GY' is a SEND, not a discard "
		+ "[S1 p.52-53]")
	var d := _main_phase_duel(9602)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	_into_deck(engine, 0, _card("Flamvell Guard"))
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [fodder.id])
	var mark := engine.state.events.size()

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.is_true(engine.submit_action(action), "One for One is activated")
	TestFixtures.pass_until_open(engine)

	var reason_seen := -1
	for event in TestFixtures.events_of(engine, GameEvent.Kind.CARD_MOVED, mark):
		if int(event.data.get("card_id", -1)) == fodder.id \
				and event.data.get("to_zone") == Enums.Zone.GRAVEYARD:
			reason_seen = event.data.get("reason")
	t.eq(reason_seen, Enums.MoveReason.SENT_AS_COST,
		"the move reason is SENT_AS_COST, so a card that triggers on a DISCARD will "
		+ "not see it")
	t.ne(reason_seen, Enums.MoveReason.DISCARDED, "and it is explicitly not a discard")
	t.is_true(Enums.is_sent_to_gy(Enums.MoveReason.SENT_AS_COST),
		"it is still 'sent to the Graveyard', which is a different question [S1 p.53]")
	t.is_false(Enums.is_destruction(Enums.MoveReason.SENT_AS_COST),
		"and it is not a destruction")


static func _test_a_level_1_monster_in_hand_is_also_a_candidate(t: TestCase) -> void:
	t.start("'from your hand or Deck' really is both zones")
	var d := _main_phase_duel(9603)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	var in_hand := TestFixtures.give_to_hand(engine, 0, _card("The White Stone of Legend"))
	var in_deck := _into_deck(engine, 0, _card("Flamvell Guard"))
	# The cost must not eat the hand candidate, so the choice is scripted explicitly.
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [fodder.id])
	controller.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [in_hand.id])

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.is_true(engine.submit_action(action), "One for One is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(controller.errors, [], "every scripted answer matched the prompt it was given to")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the chosen cost was sent")
	t.eq(in_hand.zone, Enums.Zone.MONSTER_ZONE,
		"and the Level 1 monster chosen from the HAND was Special Summoned")
	t.eq(in_deck.zone, Enums.Zone.DECK, "the Deck candidate stayed where it was")

	var offered_both := false
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind != Enums.DecisionKind.SELECT_EXACTLY:
			continue
		if request.options.has(in_hand.id) and request.options.has(in_deck.id):
			offered_both = true
	t.is_true(offered_both,
		"both the hand copy and the Deck copy were offered as candidates")


# ---------------------------------------------------------------------------
# Negatively
# ---------------------------------------------------------------------------

static func _test_not_offered_without_a_monster_in_hand(t: TestCase) -> void:
	t.start("with no monster in hand the cost cannot be paid")
	var d := _main_phase_duel(9604)
	var engine: DuelEngine = d["engine"]

	# Clear the opening hand so the only cards in it are the ones this test puts there.
	var opening := engine.state.player(0).hand.duplicate()
	for entry in opening:
		engine.state.move_card(entry, Enums.Zone.DECK, Enums.MoveReason.RULE)

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	_into_deck(engine, 0, _card("Flamvell Guard"))
	t.eq(_count_monsters_in(engine.state.player(0).hand), 0,
		"the hand holds only Spell cards")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"One for One is not offered — a Spell in hand is not 'a monster'")

	TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"adding a monster to the hand makes the cost payable")


static func _test_not_offered_without_a_level_1_monster_anywhere(t: TestCase) -> void:
	t.start("with no Level 1 monster in hand or Deck the effect can do nothing")
	var d := _main_phase_duel(9605)
	var engine: DuelEngine = d["engine"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	# A Level 1 monster in the GRAVEYARD is neither the hand nor the Deck.
	TestFixtures.give(engine, 0, _card("Flamvell Guard"), Enums.Zone.GRAVEYARD)
	# Nor is one the OPPONENT holds.
	TestFixtures.give_to_hand(engine, 1, _card("Flamvell Guard"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"One for One is not offered")

	_into_deck(engine, 0, _card("Flamvell Guard"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"one in your own Deck makes it activatable")


static func _test_not_offered_with_a_full_monster_zone(t: TestCase) -> void:
	t.start("unlike Kaibaman, nothing here frees a zone, so a full field blocks it")
	var d := _main_phase_duel(9606)
	var engine: DuelEngine = d["engine"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	_into_deck(engine, 0, _card("Flamvell Guard"))
	while engine.state.player(0).has_free_monster_zone():
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Bystander %d" % engine.state.player(0).monster_count(),
				4, 800, 800))
	t.eq(engine.state.player(0).monster_count(), 5, "all five Monster Zones are occupied")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"One for One is not offered with nowhere to Summon")


static func _test_paying_away_the_last_level_1_monster(t: TestCase) -> void:
	t.start("sending your only Level 1 monster as the cost legitimately resolves for "
		+ "nothing")
	var d := _main_phase_duel(9607)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var only_level_1 := TestFixtures.give_to_hand(engine, 0,
		_card("The White Stone of Legend"))
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [only_level_1.id])

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.not_null(action,
		"the activation is legal: the candidate check happens BEFORE the cost is paid")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(controller.errors, [], "the scripted cost choice matched the prompt")
	t.eq(only_level_1.zone, Enums.Zone.GRAVEYARD, "the cost was paid with it")
	t.eq(engine.state.player(0).monster_count(), 0,
		"and the effect then found no Level 1 monster to Summon")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no Special Summon occurred")
	t.eq(one.zone, Enums.Zone.GRAVEYARD,
		"the Spell still resolved and still went to the Graveyard")

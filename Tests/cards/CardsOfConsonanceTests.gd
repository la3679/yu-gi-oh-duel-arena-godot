class_name CardsOfConsonanceTests
extends RefCounted

## Per-card suite for `Cards of Consonance` — "Discard 1 Dragon Tuner with 1000 or less ATK;
## draw 2 cards."
##
## The same shape as `Trade-In` with a THREE-part qualification, so most of what is tested
## here is that all three parts are really enforced and that failing any one of them is a
## refusal rather than a silent pass. It is also the card that discards
## `The White Stone of Legend`, which is the pool's only cost-fires-a-trigger interaction
## and the reason the engine's `_cost_events` carry exists at all.

const CARD_UNDER_TEST := "Cards of Consonance"
const EFFECT_ID := "discard_dragon_tuner_draw_2"


static func run() -> TestCase:
	var t := TestCase.new("CardsOfConsonanceTests")
	_test_clause_shape(t)
	_test_discards_and_draws_two(t)
	_test_all_three_qualifications_are_enforced(t)
	_test_not_offered_without_a_qualifying_tuner(t)
	_test_not_offered_on_a_short_deck(t)
	_test_cost_kept_when_negated(t)
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


## A synthetic monster with independently controllable race / tuner / ATK, so each of the
## three qualifications can be failed one at a time.
static func _mon(name: String, race: String, tuner: bool, atk: int) -> CardDef:
	var d := TestFixtures.monster(name, 1, atk, 100)
	d.race = race
	d.is_tuner = tuner
	return d


static func _good(name: String = "Dragon tuner") -> CardDef:
	return _mon(name, "Dragon", true, 300)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Cards of Consonance: one clause, a Normal Spell, a cost and NO target")
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
	# cid 8656 states outright that it is not an effect that targets.
	t.is_false(e.targets, "officially it does NOT target")
	t.is_false(e.legal_targets.is_valid(),
		"so the qualification lives in the COST, not in a target list")
	t.is_true(e.pay_cost.is_valid(), "it really declares a COST")
	t.is_true(e.can_pay_cost.is_valid(), "and a cost check")
	t.is_true(e.condition.is_valid(), "and the Deck-size activation condition")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_discards_and_draws_two(t: TestCase) -> void:
	t.start("Cards of Consonance: discards the Dragon Tuner and draws exactly 2")
	var d := _duel(52001)
	var e: DuelEngine = d["engine"]
	var tuner := TestFixtures.give_to_hand(e, 0, _good())
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var deck_before := e.state.player(0).deck_count()
	var hand_before := e.state.player(0).hand.size()
	var draws_before := TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN)

	t.is_true(TestFixtures.activate_card(e, 0, spell), "activated and resolved")
	t.eq(tuner.zone, Enums.Zone.GRAVEYARD, "the Dragon Tuner really went to the GY")
	t.eq(tuner.last_move_reason, Enums.MoveReason.DISCARDED,
		"DISCARDED, not SENT_AS_COST")
	t.eq(e.state.player(0).deck_count(), deck_before - 2, "exactly two cards left the Deck")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN) - draws_before, 2,
		"two real CARD_DRAWN events")
	t.eq(e.state.player(0).hand.size(), hand_before, "net hand size unchanged")
	t.is_false(e.state.is_duel_over(), "not a deck-out")


static func _test_all_three_qualifications_are_enforced(t: TestCase) -> void:
	t.start("Cards of Consonance: Dragon AND Tuner AND 1000-or-less ATK, each enforced")
	var d := _duel(52002)
	var e: DuelEngine = d["engine"]
	var ctrl: ScriptedController = d["p0"]
	var good := TestFixtures.give_to_hand(e, 0, _good())
	var good2 := TestFixtures.give_to_hand(e, 0, _good("Second dragon tuner"))
	var exactly_1000 := TestFixtures.give_to_hand(e, 0,
		_mon("Exactly 1000", "Dragon", true, 1000))
	var too_big := TestFixtures.give_to_hand(e, 0, _mon("Too big", "Dragon", true, 1001))
	var not_tuner := TestFixtures.give_to_hand(e, 0, _mon("Not a Tuner", "Dragon", false, 300))
	var wrong_race := TestFixtures.give_to_hand(e, 0,
		_mon("Spellcaster tuner", "Spellcaster", true, 0))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	ctrl.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [good2.id])
	t.is_true(TestFixtures.activate_card(e, 0, spell), "activated")
	t.eq(ctrl.errors, [], "the queued answer went to the prompt this test meant")
	var asked: DecisionRequest = null
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.CHOOSE_DISCARD:
			asked = req
	t.not_null(asked, "a discard prompt really happened")
	if asked != null:
		t.eq(asked.options.size(), 3, "exactly the three qualifying monsters were offered")
		t.is_true(asked.options.has(good.id), "a 300 ATK Dragon Tuner qualifies")
		t.is_true(asked.options.has(good2.id), "and the second one")
		t.is_true(asked.options.has(exactly_1000.id),
			"'1000 or less' is INCLUSIVE - exactly 1000 qualifies")
		t.is_false(asked.options.has(too_big.id), "1001 ATK does not")
		t.is_false(asked.options.has(not_tuner.id), "a Dragon that is not a Tuner does not")
		t.is_false(asked.options.has(wrong_race.id),
			"a Tuner that is not a Dragon does not - the race is really checked")
	t.eq(good2.zone, Enums.Zone.GRAVEYARD, "the CHOSEN monster was discarded")
	t.eq(good.zone, Enums.Zone.HAND, "and the others stayed in the hand")
	t.eq(wrong_race.zone, Enums.Zone.HAND, "including the Spellcaster Tuner")


static func _test_not_offered_without_a_qualifying_tuner(t: TestCase) -> void:
	t.start("Cards of Consonance: nothing qualifying in hand means it is not offered")
	var d := _duel(52003)
	var e: DuelEngine = d["engine"]
	TestFixtures.give_to_hand(e, 0, _mon("Too big", "Dragon", true, 1800))
	TestFixtures.give_to_hand(e, 0, _mon("Spellcaster tuner", "Spellcaster", true, 0))
	# A qualifying monster somewhere OTHER than the hand must not help.
	TestFixtures.give_monster_on_field(e, 0, _good("On the field"))
	TestFixtures.give(e, 0, _good("In the GY"), Enums.Zone.GRAVEYARD)
	TestFixtures.give(e, 0, _good("In the Deck"), Enums.Zone.DECK)
	TestFixtures.give_to_hand(e, 1, _good("Theirs"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"not offered: the cost is a qualifying Tuner IN THE HAND")
	var joined := TestFixtures.give_to_hand(e, 0, _good("Now in hand"))
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id), "offered once one is in the hand")
	t.is_true(TestFixtures.activate_card(e, 0, spell), "and it resolves")
	t.eq(joined.zone, Enums.Zone.GRAVEYARD, "paying with the hand copy")


static func _test_not_offered_on_a_short_deck(t: TestCase) -> void:
	t.start("Cards of Consonance: R40 part D - not activatable unless the Deck holds 2")
	for n in [0, 1, 2]:
		var d := _duel(52010 + n)
		var e: DuelEngine = d["engine"]
		TestFixtures.clear_deck(e, 0)
		for i in range(n):
			TestFixtures.give_to_deck(e, 0, TestFixtures.monster("Deck card %d" % i))
		var tuner := TestFixtures.give_to_hand(e, 0, _good())
		var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
		var offered := TestFixtures.has_action(e.get_legal_actions(0),
			Enums.ActionKind.ACTIVATE_CARD, spell.id)
		t.eq(offered, n >= 2, "Deck of %d: offered == %s" % [n, str(n >= 2)])
		t.eq(tuner.zone, Enums.Zone.HAND, "Deck of %d: nothing was paid either way" % n)
		t.is_false(e.state.is_duel_over(), "Deck of %d: and no deck-out happened" % n)


static func _test_cost_kept_when_negated(t: TestCase) -> void:
	t.start("Cards of Consonance: a negated activation keeps the cost and draws nothing")
	var d := _duel(52004)
	var e: DuelEngine = d["engine"]
	var tuner := TestFixtures.give_to_hand(e, 0, _good())
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var negator := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.activation_negator("Negate it"))
	var draws_before := TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN)
	var deck_before := e.state.player(0).deck_count()
	var offered = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "activation offered")
	if offered == null:
		return
	t.is_true(e.submit_action(offered), "activation submitted")
	t.eq(tuner.zone, Enums.Zone.GRAVEYARD, "the cost was paid at ACTIVATION")
	var response = TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "a real negator response was offered")
	if response == null:
		return
	t.is_true(e.submit_action(response), "the negator activated")
	TestFixtures.pass_until_open(e)
	t.check(TestFixtures.count_events(e, GameEvent.Kind.ACTIVATION_NEGATED) >= 1,
		"the activation really was negated")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN) - draws_before, 0,
		"nothing was drawn")
	t.eq(e.state.player(0).deck_count(), deck_before, "the Deck is untouched")
	t.eq(tuner.zone, Enums.Zone.GRAVEYARD, "the cost is KEPT [S1 p.53]")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Cards of Consonance: the real pool's qualifying discards, and the negative case")
	var cards: Dictionary = CardRegistry.load_library()["cards"]
	var qualifying: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.is_monster() and def.is_tuner and def.race == "Dragon" and def.base_atk <= 1000:
			qualifying.append(def.name)
	qualifying.sort()
	t.eq(qualifying, ["Flamvell Guard", "Rider of the Storm Winds",
		"The White Stone of Legend"], "the pool's only Dragon Tuners with 1000 or less ATK")
	const DECK1 := "Blue-Eyes Dragon Guard"
	t.is_true(TradeInTests.deck_names(CARD_UNDER_TEST).has(DECK1),
		"Cards of Consonance is in deck 1")
	for name in qualifying:
		t.is_true(TradeInTests.deck_names(name).has(DECK1),
			"%s is in deck 1 too, so the cost is genuinely live" % name)
	# The negative case that a race-blind filter would silently pass.
	var maiden: CardDef = cards["Maiden with Eyes of Blue"]
	t.is_true(maiden.is_tuner, "Maiden with Eyes of Blue IS a Tuner")
	t.check(maiden.base_atk <= 1000, "and its ATK is within the cap")
	t.ne(maiden.race, "Dragon", "but it is a Spellcaster, so it can NEVER pay this cost")
	t.is_false(EffectPrimitives.tuner_monster("Dragon", 1000).call(
		CardInstance.new(maiden, 0)), "and the predicate really refuses it")

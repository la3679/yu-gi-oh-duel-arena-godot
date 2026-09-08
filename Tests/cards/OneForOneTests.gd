class_name OneForOneTests
extends RefCounted

## Per-card suite for `One for One` — "Send 1 monster from your hand to the GY;
## Special Summon 1 Level 1 monster from your hand or Deck."
##
## Two things make this card worth its own suite. Its cost is a SEND, not a discard, and
## PSCT treats those as different words. And its cost pool OVERLAPS its own effect's
## candidate pool — the pool's only card of that shape — which is what makes detail 7 of
## `Scripts/cards/registry/OneForOne.gd` load-bearing.
##
## **AUTHORITATIVE CORRECTION, Phase 5 batch 13 unit A.** This suite used to assert the
## OPPOSITE of what it asserts now, and the change is deliberate. Official Konami
## supplemental information (cid 8197, 2020-03-20, `request_locale=ja`;
## `CARD_RULINGS.md` **R42 Part D**, `RULES_SPEC.md` **10.5**) states:
##
##   *You must send the cost monster to the Graveyard in such a way that the effect can be
##   carried out. Where no Level 1 monster is in your Deck and only one is in your hand,
##   that monster cannot be used as the cost.*
##
## The retired test was `_test_paying_away_the_last_level_1_monster`, which asserted that
## sending your only Level 1 monster "legitimately resolves for nothing". Four of its
## assertions were WRONG and are inverted here:
##
##   1. `only_level_1.zone == GRAVEYARD`     -> it is NOT a legal cost and is not spent;
##   2. `monster_count() == 0`               -> a monster IS Summoned;
##   3. `SPECIAL_SUMMON_SUCCEEDED == 0`      -> exactly one Special Summon happens;
##   4. the scripted cost choice was valid   -> that choice is now rejected by the engine.
##
## Everything else the retired test asserted was RIGHT and is kept: the activation is still
## legal, and the Spell still resolves and still reaches the Graveyard. The restriction is
## on the COST CANDIDATE LIST, never on the activation.
##
## The general rule lives in `EffectPrimitives.cost_candidates_keeping_effect_performable()`
## and has its own engine-level gate in `Tests/rules/CostLegalityTests.gd`, built from
## synthetic cards. What THIS suite proves is that the printed card consumes it correctly.

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
	_test_the_last_level_1_monster_is_not_a_legal_cost(t)
	_test_no_legal_cost_when_the_last_enabler_is_the_only_monster(t)
	_test_a_deck_copy_makes_the_hand_copy_spendable(t)
	_test_two_level_1_monsters_are_each_spendable(t)
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


## The card's single EffectDef, for the tests that ask `ActivationRules` directly instead
## of going through `get_legal_actions()`. Reading it off the definition rather than
## rebuilding it is what keeps those tests honest about the shipped card.
static func _one_effect() -> EffectDef:
	return _one_def().effects[0]


## Empty a player's hand, for a test that needs an EXACT hand. The opening hand is five
## Level 4 vanillas, and "the only monster in hand" is a precondition several of the
## cost-legality tests turn on, so it cannot be left to the deal.
static func _empty_hand(engine: DuelEngine, pid: int) -> void:
	for entry in engine.state.player(pid).hand.duplicate():
		engine.state.move_card(entry, Enums.Zone.DECK, Enums.MoveReason.RULE)


## The option list of the FIRST cost decision the controller was asked, or [] if it was
## never asked. Reading the REQUEST rather than the outcome is what makes a test about the
## candidate list rather than about which card happened to be picked.
static func _first_cost_options(controller: ScriptedController) -> Array:
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind == Enums.DecisionKind.CHOOSE_COST:
			return request.options
	return []


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


static func _test_the_last_level_1_monster_is_not_a_legal_cost(t: TestCase) -> void:
	t.start("your only Level 1 monster may NOT be sent as the cost (R42 Part D)")
	var d := _main_phase_duel(9607)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var only_level_1 := TestFixtures.give_to_hand(engine, 0,
		_card("The White Stone of Legend"))
	# The opening hand is Level 4 vanillas, so there is plenty that CAN be spent. Both
	# facts are asserted rather than assumed, because the whole test turns on them.
	var spendable := engine.state.player(0).hand.filter(
		func(c): return c.is_monster() and c.id != only_level_1.id)
	t.is_true(spendable.size() >= 2,
		"precondition: at least two other monsters in hand, so the cost is a real choice")
	t.eq(EffectPrimitives.own_cards_in(
		ActivationRules.make_context(engine.state, one, _one_effect(), 0),
		Enums.Zone.DECK, EffectPrimitives.monster_of_level(1)).size(), 0,
		"precondition: no Level 1 monster in the Deck")
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST,
		[(spendable[0] as CardInstance).id])

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.not_null(action,
		"UNCHANGED from before the correction: the activation is still legal")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	var cost_options := _first_cost_options(controller)
	t.ne(cost_options, [], "a cost choice really was offered (the branch is not vacuous)")
	# INVERTED by the correction. This used to be spendable and is not.
	t.is_false(cost_options.has(only_level_1.id),
		"the last Level 1 monster was NOT among the cost candidates")
	for entry in spendable:
		t.is_true(cost_options.has((entry as CardInstance).id),
			"every OTHER monster in hand still was")

	t.eq(controller.errors, [], "the scripted cost choice matched the prompt")
	t.eq((spendable[0] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"a spendable monster paid the cost")
	# INVERTED: it used to be sent to the Graveyard and the card resolved for nothing.
	t.eq(only_level_1.zone, Enums.Zone.MONSTER_ZONE,
		"and the Level 1 monster was Special Summoned instead of being spent")
	t.eq(engine.state.player(0).monster_count(), 1, "one monster is on the field")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon occurred")
	# UNCHANGED from before the correction, and still true.
	t.eq(one.zone, Enums.Zone.GRAVEYARD,
		"the Spell resolved and went to the Graveyard")


static func _test_no_legal_cost_when_the_last_enabler_is_the_only_monster(
		t: TestCase) -> void:
	t.start("when the last Level 1 monster is the ONLY monster in hand, nothing is payable")
	var d := _main_phase_duel(9608)
	var engine: DuelEngine = d["engine"]
	_empty_hand(engine, 0)

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var only_level_1 := TestFixtures.give_to_hand(engine, 0,
		_card("The White Stone of Legend"))
	t.eq(_count_monsters_in(engine.state.player(0).hand), 1,
		"the hand holds exactly one monster and it is the Level 1")

	# The CONDITION is satisfied — there IS a Level 1 monster to Summon — and the card is
	# still not offered, because no cost can be paid. Asserted at both levels so a future
	# change that folds the rule into the condition fails here.
	var ctx := ActivationRules.make_context(engine.state, one, _one_effect(), 0)
	t.is_true(ActivationRules.condition_ok(ctx),
		"the activation condition is satisfied")
	t.is_false(ActivationRules.cost_ok(ctx), "but no cost is payable")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"so One for One is not offered at all")

	# Mutation guard: one spendable monster is the whole difference.
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"adding a NON-Level-1 monster makes it activatable")
	t.eq(only_level_1.zone, Enums.Zone.HAND, "and nothing moved to make that true")

	# Taking it away again restores the refusal, so the assertion above cannot have
	# passed for an unrelated reason.
	engine.state.move_card(fodder, Enums.Zone.DECK, Enums.MoveReason.RULE)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id),
		"removing it blocks the activation again")


static func _test_a_deck_copy_makes_the_hand_copy_spendable(t: TestCase) -> void:
	t.start("a Level 1 monster in the DECK makes the hand copy a legal cost again")
	var d := _main_phase_duel(9609)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	_empty_hand(engine, 0)

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var in_hand := TestFixtures.give_to_hand(engine, 0, _card("The White Stone of Legend"))
	var in_deck := _into_deck(engine, 0, _card("Flamvell Guard"))
	t.eq(_count_monsters_in(engine.state.player(0).hand), 1,
		"the hand's only monster is the Level 1 one")

	# One candidate and a payment of one, so `choose_n` asks nothing — the evidence has to
	# be that the payment HAPPENED with that card, not an option list.
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.not_null(action, "One for One is offered")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(controller.errors, [], "no scripted answer mismatched its prompt")
	t.eq(in_hand.zone, Enums.Zone.GRAVEYARD,
		"the hand copy WAS spendable: the Deck copy can still carry out the effect")
	t.eq(in_deck.zone, Enums.Zone.MONSTER_ZONE, "and the Deck copy was Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon occurred")


static func _test_two_level_1_monsters_are_each_spendable(t: TestCase) -> void:
	t.start("with two Level 1 monsters in hand, either one may be sent as the cost")
	var d := _main_phase_duel(9610)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	_empty_hand(engine, 0)

	var one := TestFixtures.give_to_hand(engine, 0, _one_def())
	var first := TestFixtures.give_to_hand(engine, 0, _card("The White Stone of Legend"))
	var second := TestFixtures.give_to_hand(engine, 0, _card("Flamvell Guard"))
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [first.id])

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one.id)
	t.not_null(action, "One for One is offered")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	var cost_options := _first_cost_options(controller)
	t.is_true(cost_options.has(first.id) and cost_options.has(second.id),
		"BOTH were offered — spending one leaves the other to be Summoned")
	t.eq(controller.errors, [], "the scripted cost choice matched the prompt")
	t.eq(first.zone, Enums.Zone.GRAVEYARD, "the chosen one was sent")
	t.eq(second.zone, Enums.Zone.MONSTER_ZONE, "and the other was Special Summoned")

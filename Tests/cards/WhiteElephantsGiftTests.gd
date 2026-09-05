class_name WhiteElephantsGiftTests
extends RefCounted

## Per-card suite for `White Elephant's Gift` — "Send 1 face-up non-Effect Monster you
## control to the GY; draw 2 cards."
##
## The third batch-10 draw card and the one that differs from the other two in every part of
## its cost: it SENDS rather than discards, from the FIELD rather than the hand, and its
## qualification is a negative property that is officially WIDER than "Normal Monster".

const CARD_UNDER_TEST := "White Elephant's Gift"
const EFFECT_ID := "send_non_effect_monster_draw_2"


static func run() -> TestCase:
	var t := TestCase.new("WhiteElephantsGiftTests")
	_test_clause_shape(t)
	_test_sends_and_draws_two(t)
	_test_the_cost_is_a_send_not_a_discard(t)
	_test_only_face_up_own_non_effect_monsters_may_pay(t)
	_test_not_offered_without_a_payable_monster(t)
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


## A monster that really is an Effect Monster, so the negative case is a real one.
static func _with_effect(name: String) -> CardDef:
	var e := EffectDef.new("inert", "Does nothing.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(_ctx: EffectContext) -> void:
		pass
	var d := TestFixtures.with_effect(TestFixtures.monster(name), e)
	d.is_effect_monster = true
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("White Elephant's Gift: one clause, a Normal Spell, a cost and no target")
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
	t.is_false(e.targets, "it does not target")
	t.is_true(e.pay_cost.is_valid(), "it really declares a COST")
	t.is_true(e.can_pay_cost.is_valid(), "and a cost check")
	t.is_true(e.condition.is_valid(), "and the Deck-size activation condition")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_sends_and_draws_two(t: TestCase) -> void:
	t.start("White Elephant's Gift: sends the monster from the FIELD and draws exactly 2")
	var d := _duel(53001)
	var e: DuelEngine = d["engine"]
	var vanilla := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Vanilla"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var deck_before := e.state.player(0).deck_count()
	var draws_before := TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN)
	var monsters_before := e.state.player(0).monster_count()

	t.is_true(TestFixtures.activate_card(e, 0, spell), "activated and resolved")
	t.eq(vanilla.zone, Enums.Zone.GRAVEYARD, "the monster really left the field for the GY")
	t.eq(e.state.player(0).monster_count(), monsters_before - 1, "a Monster Zone was freed")
	t.eq(e.state.player(0).deck_count(), deck_before - 2, "exactly two cards left the Deck")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN) - draws_before, 2,
		"two real CARD_DRAWN events")
	t.eq(TestFixtures.count_events_for(e, GameEvent.Kind.CARD_SENT_TO_GY, vanilla.id), 1,
		"a real send to the GY, which a 'sent to the GY' trigger could see")
	t.eq(TestFixtures.count_events_for(e, GameEvent.Kind.CARD_DESTROYED, vanilla.id), 0,
		"and it was NOT destroyed [S1 p.53]")
	t.is_false(e.state.is_duel_over(), "not a deck-out")


static func _test_the_cost_is_a_send_not_a_discard(t: TestCase) -> void:
	t.start("White Elephant's Gift: SENT_AS_COST, not DISCARDED, and paid at activation")
	var d := _duel(53002)
	var e: DuelEngine = d["engine"]
	var vanilla := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Vanilla"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var holder := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.activation_negator("Hold window"))
	var offered = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "activation offered")
	if offered == null:
		return
	t.is_true(e.submit_action(offered), "activation submitted")
	t.eq(vanilla.zone, Enums.Zone.GRAVEYARD, "the cost was ALREADY paid at activation")
	t.eq(vanilla.last_move_reason, Enums.MoveReason.SENT_AS_COST,
		"SENT_AS_COST - this card SENDS, it does not discard")
	t.ne(vanilla.last_move_reason, Enums.MoveReason.DISCARDED,
		"a 'discarded' clause must never see this payment")
	t.not_null(TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, holder.id),
		"a real response window was open, so the read above was mid-Chain")
	TestFixtures.pass_until_open(e)


static func _test_only_face_up_own_non_effect_monsters_may_pay(t: TestCase) -> void:
	t.start("White Elephant's Gift: face-up, yours, and NOT an Effect Monster - all three")
	var d := _duel(53003)
	var e: DuelEngine = d["engine"]
	var ctrl: ScriptedController = d["p0"]
	var vanilla := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Vanilla A"))
	var vanilla2 := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Vanilla B"))
	var has_effect := TestFixtures.give_monster_on_field(e, 0, _with_effect("Has an effect"))
	var facedown := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Set one"),
		Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(e, 1, TestFixtures.monster("Theirs"))
	var in_hand := TestFixtures.give_to_hand(e, 0, TestFixtures.monster("In hand"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	ctrl.queue_for(Enums.DecisionKind.CHOOSE_COST, [vanilla2.id])
	t.is_true(TestFixtures.activate_card(e, 0, spell), "activated")
	t.eq(ctrl.errors, [], "the queued answer went to the prompt this test meant")
	var asked: DecisionRequest = null
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.CHOOSE_COST:
			asked = req
	t.not_null(asked, "a cost prompt really happened")
	if asked != null:
		t.eq(asked.options.size(), 2, "exactly the two face-up own vanillas were offered")
		t.is_true(asked.options.has(vanilla.id), "the first vanilla qualifies")
		t.is_true(asked.options.has(vanilla2.id), "and the second")
		t.is_false(asked.options.has(has_effect.id), "an Effect Monster does NOT qualify")
		t.is_false(asked.options.has(facedown.id), "a face-down monster does NOT qualify")
		t.is_false(asked.options.has(theirs.id),
			"the opponent's monster does NOT qualify - 'you control'")
		t.is_false(asked.options.has(in_hand.id),
			"a monster in the HAND does not qualify - this card sends from the field")
	t.eq(vanilla2.zone, Enums.Zone.GRAVEYARD, "the CHOSEN monster was sent")
	t.eq(vanilla.zone, Enums.Zone.MONSTER_ZONE, "and the other stayed on the field")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "as did the opponent's")


static func _test_not_offered_without_a_payable_monster(t: TestCase) -> void:
	t.start("White Elephant's Gift: nothing payable on the field means it is not offered")
	var d := _duel(53004)
	var e: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(e, 0, _with_effect("Has an effect"))
	TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Set one"),
		Enums.Position.FACE_DOWN_DEFENSE)
	TestFixtures.give_monster_on_field(e, 1, TestFixtures.monster("Theirs"))
	TestFixtures.give_to_hand(e, 0, TestFixtures.monster("In hand"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id), "not offered")
	var joined := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Vanilla"))
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"offered the moment a face-up own non-Effect Monster exists")
	t.is_true(TestFixtures.activate_card(e, 0, spell), "and it resolves")
	t.eq(joined.zone, Enums.Zone.GRAVEYARD, "paying with it")


static func _test_not_offered_on_a_short_deck(t: TestCase) -> void:
	t.start("White Elephant's Gift: the Deck-of-2 gate, applied by analogy (R40 part D)")
	for n in [0, 1, 2]:
		var d := _duel(53010 + n)
		var e: DuelEngine = d["engine"]
		TestFixtures.clear_deck(e, 0)
		for i in range(n):
			TestFixtures.give_to_deck(e, 0, TestFixtures.monster("Deck card %d" % i))
		var vanilla := TestFixtures.give_monster_on_field(e, 0,
			TestFixtures.monster("Vanilla"))
		var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
		var offered := TestFixtures.has_action(e.get_legal_actions(0),
			Enums.ActionKind.ACTIVATE_CARD, spell.id)
		t.eq(offered, n >= 2, "Deck of %d: offered == %s" % [n, str(n >= 2)])
		t.eq(vanilla.zone, Enums.Zone.MONSTER_ZONE,
			"Deck of %d: nothing was paid either way" % n)
		t.is_false(e.state.is_duel_over(), "Deck of %d: and no deck-out happened" % n)


static func _test_cost_kept_when_negated(t: TestCase) -> void:
	t.start("White Elephant's Gift: a negated activation keeps the cost and draws nothing")
	var d := _duel(53005)
	var e: DuelEngine = d["engine"]
	var vanilla := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Vanilla"))
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
	t.eq(vanilla.zone, Enums.Zone.GRAVEYARD, "but the cost is KEPT [S1 p.53]")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("White Elephant's Gift: non-Effect Monster is WIDER than Normal Monster, but "
		+ "the two coincide in this pool")
	var cards: Dictionary = CardRegistry.load_library()["cards"]
	var non_effect: Array = []
	var normal: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if not def.is_monster():
			continue
		if not def.is_effect_monster:
			non_effect.append(def.name)
		if def.is_normal_monster:
			normal.append(def.name)
	non_effect.sort()
	normal.sort()
	# The implementation asks the WIDER question, because that is what the card says
	# (cid 9138). The two answers coincide here only because both Extra Decks are empty.
	t.eq(non_effect, normal,
		"in the V1 pool every non-Effect Monster is a Normal Monster and vice versa")
	t.check(non_effect.size() > 0, "and the pool really does have some")
	const DECK2 := "Fairy-Tail Tribute Guard"
	t.is_true(TradeInTests.deck_names(CARD_UNDER_TEST).has(DECK2),
		"White Elephant's Gift is in deck 2")
	var live: Array = []
	for name in non_effect:
		if TradeInTests.deck_names(name).has(DECK2):
			live.append(name)
	live.sort()
	t.eq(live, ["Gladiator Beast Andal", "Metaphys Armed Dragon", "Sabersaurus",
		"Zure, Knight of Dark World"],
		"the payments genuinely available in its own deck")
	# The branch that can never run: an effectless Extra Deck monster.
	var extra: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.monster_subtypes.has("Fusion") or def.monster_subtypes.has("Synchro") \
				or def.monster_subtypes.has("Xyz") or def.monster_subtypes.has("Link"):
			extra.append(def.name)
	t.eq(extra, [],
		"the pool has no Extra Deck monsters, so the wider half of the rule is never live")

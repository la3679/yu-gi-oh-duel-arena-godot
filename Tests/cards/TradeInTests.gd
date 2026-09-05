class_name TradeInTests
extends RefCounted

## Per-card suite for `Trade-In` — "Discard 1 Level 8 monster; draw 2 cards."
##
## The pool's first card that DRAWS. The generic behaviour is `DeckAccessTests`; what is
## tested here is the card: that the discard is a qualified COST rather than an effect, that
## the Level 8 requirement is real in both directions, and that the R40 part D activation
## gate (the Deck must hold 2) is honoured rather than becoming a deck-out.

const CARD_UNDER_TEST := "Trade-In"
const EFFECT_ID := "discard_level_8_draw_2"


static func run() -> TestCase:
	var t := TestCase.new("TradeInTests")
	_test_clause_shape(t)
	_test_discards_and_draws_two(t)
	_test_the_cost_is_a_discard_not_a_send(t)
	_test_only_a_level_8_monster_may_pay(t)
	_test_not_offered_without_a_level_8_monster(t)
	_test_not_offered_on_a_short_deck(t)
	_test_the_cost_is_kept_when_the_activation_is_negated(t)
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


static func _lv8(name: String = "Level eight") -> CardDef:
	return TestFixtures.monster(name, 8, 3000, 2500)


## Which decks a real pool card belongs to. `CardDef` deliberately does not carry deck
## membership — it is a property of the DECK LIST, not of the card — so a real-pool
## assertion reads the card database directly.
static func deck_names(card_name: String) -> Array:
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("cards"):
		return []
	for entry in parsed["cards"]:
		if str(entry.get("name", "")) == card_name:
			return entry.get("decks", [])
	return []


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Trade-In: one clause, a Normal Spell, a cost and no target")
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
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.is_false(e.targets, "it does not target")
	t.is_true(e.pay_cost.is_valid(), "it really declares a COST")
	t.is_true(e.can_pay_cost.is_valid(), "and a cost check, so it is never offered unpayably")
	t.is_true(e.condition.is_valid(), "and an activation condition (the Deck requirement)")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed, so none was added")
	t.is_false(e.once_per_turn_named_activation, "and not a named one either")
	t.check(e.activation_locations.has(Enums.ActivationLocation.HAND),
		"activatable from the hand")
	t.check(e.activation_locations.has(Enums.ActivationLocation.FIELD_FACE_DOWN),
		"and as a Set card")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_discards_and_draws_two(t: TestCase) -> void:
	t.start("Trade-In: discards the Level 8 monster and draws exactly 2")
	var d := _duel(51001)
	var e: DuelEngine = d["engine"]
	var big := TestFixtures.give_to_hand(e, 0, _lv8())
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	var deck_before := e.state.player(0).deck_count()
	var hand_before := e.state.player(0).hand.size()
	var draws_before := TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN)
	var gy_before := e.state.player(0).graveyard.size()

	t.is_true(TestFixtures.activate_card(e, 0, spell), "activated and resolved")
	t.eq(big.zone, Enums.Zone.GRAVEYARD, "the Level 8 monster really went to the GY")
	t.eq(e.state.player(0).deck_count(), deck_before - 2, "exactly two cards left the Deck")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN) - draws_before, 2,
		"two real CARD_DRAWN events - the draw path actually happened")
	# hand: -1 spell, -1 discard, +2 drawn.
	t.eq(e.state.player(0).hand.size(), hand_before, "net hand size is unchanged")
	# GY: +1 the discard, +1 the spent Normal Spell.
	t.eq(e.state.player(0).graveyard.size(), gy_before + 2,
		"the discard and the spent Spell both reached the GY")
	t.eq(spell.zone, Enums.Zone.GRAVEYARD, "a Normal Spell goes to the GY after resolving")
	t.is_false(e.state.is_duel_over(), "drawing 2 from a full Deck is not a loss")


static func _test_the_cost_is_a_discard_not_a_send(t: TestCase) -> void:
	t.start("Trade-In: the payment is a DISCARD, and it is paid at ACTIVATION")
	var d := _duel(51002)
	var e: DuelEngine = d["engine"]
	var big := TestFixtures.give_to_hand(e, 0, _lv8())
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	# A responder holds the Chain open, so the board can be read BETWEEN activation and
	# resolution - which is the only way to prove the cost was paid at activation.
	var holder := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.activation_negator("Hold window"))
	var offered = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "activation offered")
	if offered == null:
		return
	t.is_true(e.submit_action(offered), "activation submitted")
	t.eq(big.zone, Enums.Zone.GRAVEYARD, "the cost was ALREADY paid at activation")
	t.eq(big.last_move_reason, Enums.MoveReason.DISCARDED,
		"DISCARDED, not SENT_AS_COST - PSCT keeps the two apart")
	t.not_null(TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, holder.id),
		"a real response window really was open, so the read above was mid-Chain")
	TestFixtures.pass_until_open(e)
	t.eq(TestFixtures.count_events_for(e, GameEvent.Kind.CARD_SENT_TO_GY, big.id), 1,
		"a discard IS a send to the GY, so 'if this card is sent to the GY' can still see it")


static func _test_only_a_level_8_monster_may_pay(t: TestCase) -> void:
	t.start("Trade-In: only the Level 8 monster is offered as the cost")
	var d := _duel(51003)
	var e: DuelEngine = d["engine"]
	var ctrl: ScriptedController = d["p0"]
	var big := TestFixtures.give_to_hand(e, 0, _lv8())
	var big2 := TestFixtures.give_to_hand(e, 0, _lv8("Other level eight"))
	var lv7 := TestFixtures.give_to_hand(e, 0, TestFixtures.monster("Level seven", 7))
	var lv4 := TestFixtures.give_to_hand(e, 0, TestFixtures.monster("Level four", 4))
	var a_spell := TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Inert spell"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	# Two candidates, so a prompt really happens; queue the SECOND one, so a default
	# "first option" answer would be visibly wrong.
	ctrl.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [big2.id])
	t.is_true(TestFixtures.activate_card(e, 0, spell), "activated")
	t.eq(ctrl.errors, [], "the queued answer went to the prompt this test meant")
	var asked: DecisionRequest = null
	for entry in ctrl.seen_requests:
		var req: DecisionRequest = entry
		if req.kind == Enums.DecisionKind.CHOOSE_DISCARD:
			asked = req
	t.not_null(asked, "a discard prompt really happened")
	if asked != null:
		t.eq(asked.options.size(), 2, "exactly the two Level 8 monsters were offered")
		t.is_true(asked.options.has(big.id), "the first Level 8 monster was an option")
		t.is_true(asked.options.has(big2.id), "and the second")
		t.is_false(asked.options.has(lv7.id), "a Level 7 monster was NOT an option")
		t.is_false(asked.options.has(lv4.id), "nor a Level 4 monster")
		t.is_false(asked.options.has(a_spell.id), "nor a Spell")
		t.is_false(asked.options.has(spell.id), "and Trade-In can never pay for itself")
	t.eq(big2.zone, Enums.Zone.GRAVEYARD, "the CHOSEN monster was the one discarded")
	t.eq(big.zone, Enums.Zone.HAND, "and the other Level 8 monster stayed in the hand")


static func _test_not_offered_without_a_level_8_monster(t: TestCase) -> void:
	t.start("Trade-In: no Level 8 monster in hand means the activation is not offered")
	var d := _duel(51004)
	var e: DuelEngine = d["engine"]
	TestFixtures.give_to_hand(e, 0, TestFixtures.monster("Level seven", 7))
	TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Inert spell"))
	# A Level 8 monster the player does NOT hold in the hand must not help.
	TestFixtures.give_monster_on_field(e, 0, _lv8("On the field"))
	TestFixtures.give(e, 0, _lv8("In the GY"), Enums.Zone.GRAVEYARD)
	TestFixtures.give_to_hand(e, 1, _lv8("Theirs"))
	var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"not offered: the cost is a Level 8 monster IN THE HAND")
	var joined := TestFixtures.give_to_hand(e, 0, _lv8("Now in hand"))
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"and offered the moment one is in the hand")
	t.is_true(TestFixtures.activate_card(e, 0, spell), "and it resolves")
	t.eq(joined.zone, Enums.Zone.GRAVEYARD, "paying with the hand copy")


static func _test_not_offered_on_a_short_deck(t: TestCase) -> void:
	t.start("Trade-In: R40 part D - not activatable unless the Deck holds 2")
	for n in [0, 1, 2]:
		var d := _duel(51010 + n)
		var e: DuelEngine = d["engine"]
		TestFixtures.clear_deck(e, 0)
		for i in range(n):
			TestFixtures.give_to_deck(e, 0, TestFixtures.monster("Deck card %d" % i))
		var big := TestFixtures.give_to_hand(e, 0, _lv8())
		var spell := TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
		var offered := TestFixtures.has_action(e.get_legal_actions(0),
			Enums.ActionKind.ACTIVATE_CARD, spell.id)
		t.eq(offered, n >= 2, "Deck of %d: offered == %s" % [n, str(n >= 2)])
		t.eq(big.zone, Enums.Zone.HAND, "Deck of %d: nothing was paid either way" % n)
		if not offered:
			t.is_false(e.state.is_duel_over(),
				"Deck of %d: refusing to activate is not a deck-out" % n)
		else:
			t.is_true(TestFixtures.activate_card(e, 0, spell), "Deck of 2: it resolves")
			t.eq(e.state.player(0).deck_count(), 0, "and empties the Deck")
			t.is_false(e.state.is_duel_over(),
				"an empty Deck is not a loss until a draw is REQUIRED [S1 p.35]")


static func _test_the_cost_is_kept_when_the_activation_is_negated(t: TestCase) -> void:
	t.start("Trade-In: a negated activation keeps the cost and draws nothing")
	var d := _duel(51005)
	var e: DuelEngine = d["engine"]
	var big := TestFixtures.give_to_hand(e, 0, _lv8())
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
		"the activation really was negated - the negation path happened")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN) - draws_before, 0,
		"nothing was drawn")
	t.eq(e.state.player(0).deck_count(), deck_before, "the Deck is untouched")
	t.eq(big.zone, Enums.Zone.GRAVEYARD,
		"but the cost is KEPT - a paid cost is never refunded [S1 p.53]")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Trade-In: the real pool's Level 8 monsters are exactly two, and it is in deck 1")
	var lib := CardRegistry.load_library()
	var cards: Dictionary = lib["cards"]
	var level_8: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.is_monster() and def.level == 8:
			level_8.append(def.name)
	level_8.sort()
	t.eq(level_8, ["Blue-Eyes White Dragon", "Rabidragon", "Witchcrafter Golem Aruru"],
		"the pool's only Level 8 monsters")
	# Deck 1 is Trade-In's deck; Witchcrafter Golem Aruru is in deck 2, so it can never pay.
	const DECK1 := "Blue-Eyes Dragon Guard"
	t.is_true(deck_names(CARD_UNDER_TEST).has(DECK1), "Trade-In is in deck 1")
	t.is_true(deck_names("Blue-Eyes White Dragon").has(DECK1),
		"Blue-Eyes White Dragon is too, so it can really pay")
	t.is_true(deck_names("Rabidragon").has(DECK1), "and so can Rabidragon")
	t.is_false(deck_names("Witchcrafter Golem Aruru").has(DECK1),
		"Witchcrafter Golem Aruru is NOT in deck 1, so it can never pay for this card")
	var stone: CardDef = cards["The White Stone of Legend"]
	t.eq(stone.level, 1,
		"The White Stone of Legend is Level 1: Trade-In can NEVER discard it")

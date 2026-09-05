class_name HeraldOfCreationTests
extends RefCounted

## Per-card suite for `Herald of Creation` — "Once per turn: You can discard 1 card, then
## target 1 Level 7 or higher monster in your Graveyard; add that target to your hand."
##
## The pool's first GY-to-hand retrieval with a LEVEL FLOOR. Most of what is tested here is
## that the floor is a floor in both directions, that the discard is a cost paid at
## activation, that the once-per-turn is on this COPY rather than on the name, and that a
## target which leaves the Graveyard mid-Chain is dropped rather than chased — with the cost
## still spent.

const CARD_UNDER_TEST := "Herald of Creation"
const EFFECT_ID := "discard_to_retrieve_level_7"


static func run() -> TestCase:
	var t := TestCase.new("HeraldOfCreationTests")
	_test_clause_shape(t)
	_test_retrieves_a_level_7_or_higher_monster(t)
	_test_the_level_floor_is_a_floor(t)
	_test_only_your_own_graveyard(t)
	_test_not_offered_without_a_target_or_a_hand(t)
	_test_once_per_turn_is_on_this_copy(t)
	_test_target_that_leaves_the_graveyard(t)
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


## Queue the fodder as the discard. "Discard 1 card" is unqualified, so the whole hand —
## including the five opening-hand cards — is a candidate and the controller's default
## answer ("the first option") is not the card a test means. Asserting `controller.errors`
## afterwards is what proves the queued answer reached the prompt this test intended.
static func _queue_discard(d: Dictionary, card: CardInstance) -> void:
	(d["p0"] as ScriptedController).queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [card.id])


## Herald on the field, one card in hand to discard, and the given monsters in the GY.
static func _board(seed_value: int, gy_levels: Array) -> Dictionary:
	var d := _duel(seed_value)
	var e: DuelEngine = d["engine"]
	d["herald"] = TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	d["fodder"] = TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Discard fodder"))
	var gy: Array = []
	for lv in gy_levels:
		gy.append(TestFixtures.give(e, 0,
			TestFixtures.monster("GY level %d" % int(lv), int(lv)), Enums.Zone.GRAVEYARD))
	d["gy"] = gy
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Herald of Creation: one IGNITION clause, targeting, with a cost")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.MONSTER, "it is a monster")
	t.eq(d.level, 4, "Level 4")
	t.eq(d.race, "Spellcaster", "a Spellcaster")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.IGNITION,
		"an IGNITION effect, per the official supplement - not a Trigger")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1, so it is not a Quick Effect")
	t.is_true(e.targets, "it targets")
	t.eq(e.target_count_min, 1, "exactly one target")
	t.eq(e.target_count_max, 1, "no more than one")
	t.is_true(e.pay_cost.is_valid(), "it really declares a COST")
	t.is_true(e.once_per_turn_instance,
		"'Once per turn' with no name printed is a limit on this COPY")
	t.is_false(e.once_per_turn_named_effect, "and NOT a named once-per-turn")
	t.is_false(e.once_per_turn_named_activation, "nor a named activation limit")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"activated from the Monster Zone, face-up")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_retrieves_a_level_7_or_higher_monster(t: TestCase) -> void:
	t.start("Herald of Creation: discards 1, adds the targeted Level 8 monster to the hand")
	var d := _board(54001, [8])
	var e: DuelEngine = d["engine"]
	var herald: CardInstance = d["herald"]
	var fodder: CardInstance = d["fodder"]
	var target: CardInstance = (d["gy"] as Array)[0]
	var hand_before := e.state.player(0).hand.size()
	_queue_discard(d, fodder)

	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID)
	t.not_null(a, "the ignition effect is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [target.id]})),
		"activated with the GY monster as the target")
	TestFixtures.pass_until_open(e)
	t.eq((d["p0"] as ScriptedController).errors, [],
		"the queued discard answer went to the prompt this test meant")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the discard cost was paid")
	t.eq(fodder.last_move_reason, Enums.MoveReason.DISCARDED, "and it was a DISCARD")
	t.eq(target.zone, Enums.Zone.HAND, "the target really reached the hand")
	t.eq(target.last_move_reason, Enums.MoveReason.ADDED_TO_HAND,
		"ADDED_TO_HAND, never RETURNED_TO_HAND - it was never on the field")
	t.is_true(e.state.player(0).hand.has(target), "and it is in the controller's hand")
	# hand: -1 discard, +1 retrieved.
	t.eq(e.state.player(0).hand.size(), hand_before, "net hand size unchanged")
	t.eq(herald.zone, Enums.Zone.MONSTER_ZONE, "Herald itself stays on the field")


static func _test_the_level_floor_is_a_floor(t: TestCase) -> void:
	t.start("Herald of Creation: 'Level 7 or higher' is a FLOOR, inclusive at 7")
	var d := _board(54002, [4, 6, 7, 8, 12])
	var e: DuelEngine = d["engine"]
	var herald: CardInstance = d["herald"]
	var gy: Array = d["gy"]
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID)
	t.not_null(a, "the effect is offered")
	if a == null:
		return
	var options: Array = a.target_candidates
	t.eq(options.size(), 3, "exactly the three Level 7-or-higher monsters are targetable")
	t.is_false(options.has(gy[0].id), "Level 4 is NOT a legal target")
	t.is_false(options.has(gy[1].id), "Level 6 is NOT a legal target")
	t.is_true(options.has(gy[2].id), "Level 7 IS - the floor is inclusive")
	t.is_true(options.has(gy[3].id), "Level 8 is")
	t.is_true(options.has(gy[4].id), "and Level 12 is")
	# A forged action naming an illegal target must be refused outright.
	t.is_false(e.submit_action(a.with_choices({"target_ids": [gy[1].id]})),
		"a forged Level 6 target is rejected")
	t.eq((d["fodder"] as CardInstance).zone, Enums.Zone.HAND,
		"and the rejection paid no cost")


static func _test_only_your_own_graveyard(t: TestCase) -> void:
	t.start("Herald of Creation: 'your Graveyard' never reaches the opponent's")
	var d := _duel(54003)
	var e: DuelEngine = d["engine"]
	var herald := TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Discard fodder"))
	var theirs := TestFixtures.give(e, 1, TestFixtures.monster("Theirs level 8", 8),
		Enums.Zone.GRAVEYARD)
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD, "the opponent really has a Level 8 in the GY")
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID),
		"not offered: the opponent's Graveyard is not 'your Graveyard'")
	var mine := TestFixtures.give(e, 0, TestFixtures.monster("Mine level 8", 8),
		Enums.Zone.GRAVEYARD)
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID)
	t.not_null(a, "offered once the controller's own GY holds one")
	if a == null:
		return
	t.eq(a.target_candidates, [mine.id], "and only their OWN monster is targetable")


static func _test_not_offered_without_a_target_or_a_hand(t: TestCase) -> void:
	t.start("Herald of Creation: needs BOTH a legal target and a card to discard")
	# No target in the GY.
	var d1 := _board(54004, [4])
	var e1: DuelEngine = d1["engine"]
	t.is_false(TestFixtures.has_action(e1.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, (d1["herald"] as CardInstance).id, EFFECT_ID),
		"not offered with nothing Level 7 or higher in the GY")
	t.eq((d1["fodder"] as CardInstance).zone, Enums.Zone.HAND, "and nothing was paid")

	# A target, but an empty hand.
	var d2 := _duel(54005)
	var e2: DuelEngine = d2["engine"]
	var herald2 := TestFixtures.give_monster_on_field(e2, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give(e2, 0, TestFixtures.monster("GY level 8", 8), Enums.Zone.GRAVEYARD)
	for entry in e2.state.player(0).hand.duplicate():
		e2.state.move_card(entry, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.eq(e2.state.player(0).hand.size(), 0, "the hand really is empty")
	t.is_false(TestFixtures.has_action(e2.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald2.id, EFFECT_ID),
		"not offered with an empty hand - the cost could not be paid")
	TestFixtures.give_to_hand(e2, 0, TestFixtures.spell("Now something to discard"))
	t.is_true(TestFixtures.has_action(e2.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald2.id, EFFECT_ID),
		"offered once a card is in hand")

	# A face-down Herald cannot use an effect that activates from FIELD_FACE_UP.
	var d3 := _board(54006, [8])
	var e3: DuelEngine = d3["engine"]
	var herald3: CardInstance = d3["herald"]
	e3.state.set_battle_position(herald3, Enums.Position.FACE_DOWN_DEFENSE, true)
	t.is_false(TestFixtures.has_action(e3.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald3.id, EFFECT_ID),
		"a face-down Herald cannot activate it")


static func _test_once_per_turn_is_on_this_copy(t: TestCase) -> void:
	t.start("Herald of Creation: once per turn, per COPY, and it resets next turn")
	var d := _board(54007, [8, 8])
	var e: DuelEngine = d["engine"]
	var herald: CardInstance = d["herald"]
	var second := TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	var more := TestFixtures.give_to_hand(e, 0, TestFixtures.spell("More fodder"))
	var yet_more := TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Yet more fodder"))
	var gy: Array = d["gy"]
	_queue_discard(d, more)
	_queue_discard(d, yet_more)

	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID)
	t.not_null(a, "the first copy is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [gy[0].id]})), "and used")
	TestFixtures.pass_until_open(e)
	t.eq(gy[0].zone, Enums.Zone.HAND, "the first retrieval happened")
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID),
		"the SAME copy cannot use it twice in a turn")
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, second.id, EFFECT_ID),
		"but a DIFFERENT copy still can - the limit is on the instance, not the name")
	var b = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, second.id, EFFECT_ID)
	t.is_true(e.submit_action(b.with_choices({"target_ids": [gy[1].id]})),
		"the second copy really used it in the same turn")
	TestFixtures.pass_until_open(e)
	t.eq(gy[1].zone, Enums.Zone.HAND, "and its retrieval happened too")

	# Round the turn back to player 0 and the allowance is back.
	TestFixtures.give(e, 0, TestFixtures.monster("Fresh level 8", 8), Enums.Zone.GRAVEYARD)
	TestFixtures.end_turn(e)
	TestFixtures.end_turn(e)
	t.eq(e.state.turn_player_id, 0, "it is player 0's turn again")
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID),
		"the once-per-turn allowance reset")


static func _test_target_that_leaves_the_graveyard(t: TestCase) -> void:
	t.start("Herald of Creation: a target that leaves the GY is DROPPED, cost still spent")
	var d := _board(54008, [8])
	var e: DuelEngine = d["engine"]
	var herald: CardInstance = d["herald"]
	var fodder: CardInstance = d["fodder"]
	var target: CardInstance = (d["gy"] as Array)[0]
	# A real Spell Speed 2 response, so the removal travels through the timing machine
	# rather than being written onto the board behind the engine's back.
	var thief := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.interferer("Banish the target", target, "banish"))
	_queue_discard(d, fodder)
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID)
	t.not_null(a, "the effect is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [target.id]})), "activated")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the cost was paid at ACTIVATION")
	var response = TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "a real response window is open, so this is genuinely mid-Chain")
	if response == null:
		return
	t.is_true(e.submit_action(response), "the opponent chained a real removal")
	TestFixtures.pass_until_open(e)
	t.eq(target.zone, Enums.Zone.BANISHED,
		"the target stayed where it went - it was NOT chased into the hand")
	t.is_false(e.state.player(0).hand.has(target), "and it never reached the hand")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "but the cost is still spent")
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID),
		"and the once-per-turn use is still spent too")


static func _test_cost_kept_when_negated(t: TestCase) -> void:
	t.start("Herald of Creation: a negated activation keeps the cost and retrieves nothing")
	var d := _board(54009, [8])
	var e: DuelEngine = d["engine"]
	var herald: CardInstance = d["herald"]
	var fodder: CardInstance = d["fodder"]
	var target: CardInstance = (d["gy"] as Array)[0]
	var negator := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.any_effect_negator("Negate it"))
	_queue_discard(d, fodder)
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, herald.id, EFFECT_ID)
	t.not_null(a, "the effect is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [target.id]})), "activated")
	var response = TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "a real negator response was offered")
	if response == null:
		return
	t.is_true(e.submit_action(response), "the negator activated")
	TestFixtures.pass_until_open(e)
	t.check(TestFixtures.count_events(e, GameEvent.Kind.EFFECT_NEGATED)
		+ TestFixtures.count_events(e, GameEvent.Kind.ACTIVATION_NEGATED) >= 1,
		"a negation really happened - the negation path was taken")
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the target stayed in the Graveyard")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "but the cost is KEPT [S1 p.53]")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Herald of Creation: the real pool's Level 7+ targets, and the never-live branch")
	var cards: Dictionary = CardRegistry.load_library()["cards"]
	const DECK1 := "Blue-Eyes Dragon Guard"
	t.is_true(TradeInTests.deck_names(CARD_UNDER_TEST).has(DECK1), "Herald is in deck 1")
	var live: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.is_monster() and def.level >= 7 \
				and TradeInTests.deck_names(def.name).has(DECK1):
			live.append(def.name)
	live.sort()
	t.eq(live, ["Blue-Eyes White Dragon", "Rabidragon"],
		"deck 1's only Level 7-or-higher monsters, so the clause is genuinely live")
	# The branch that can never run: an Extra Deck target, which would go to the Extra Deck.
	var extra: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.monster_subtypes.has("Fusion") or def.monster_subtypes.has("Synchro") \
				or def.monster_subtypes.has("Xyz") or def.monster_subtypes.has("Link"):
			extra.append(def.name)
	t.eq(extra, [],
		"the pool has no Extra Deck monsters, so the Extra-Deck branch is never live")

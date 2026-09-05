class_name DivineDragonApocralyphTests
extends RefCounted

## Per-card suite for `Divine Dragon Apocralyph` — "Once per turn: You can discard 1 card,
## then target 1 Dragon-Type monster in your Graveyard; add that target to your hand."
##
## The same SHAPE as `Herald of Creation` and deliberately not the same code. What this suite
## tests that Herald's does not is that "Dragon-Type" is matched on the RACE and never on the
## name — deck 1 holds four Dragons whose names contain no "Dragon" at all, so a name test
## would silently work on the obvious cards and fail on the real ones.

const CARD_UNDER_TEST := "Divine Dragon Apocralyph"
const EFFECT_ID := "discard_to_retrieve_dragon"


static func run() -> TestCase:
	var t := TestCase.new("DivineDragonApocralyphTests")
	_test_clause_shape(t)
	_test_retrieves_a_dragon(t)
	_test_race_is_matched_not_the_name(t)
	_test_only_your_own_graveyard(t)
	_test_not_offered_without_a_target_or_a_hand(t)
	_test_once_per_turn_is_on_this_copy(t)
	_test_cannot_target_itself_from_the_field(t)
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


static func _mon(name: String, race: String) -> CardDef:
	var d := TestFixtures.monster(name)
	d.race = race
	return d


## Queue the fodder as the discard. "Discard 1 card" is unqualified, so the whole hand is a
## candidate and the controller's default answer is not the card a test means.
static func _queue_discard(d: Dictionary, card: CardInstance) -> void:
	(d["p0"] as ScriptedController).queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [card.id])


## Apocralyph on the field, a card in hand to discard, and the given monsters in the GY.
static func _board(seed_value: int, gy: Array) -> Dictionary:
	var d := _duel(seed_value)
	var e: DuelEngine = d["engine"]
	d["apoc"] = TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	d["fodder"] = TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Discard fodder"))
	var made: Array = []
	for entry in gy:
		made.append(TestFixtures.give(e, 0, entry, Enums.Zone.GRAVEYARD))
	d["gy"] = made
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: one IGNITION clause, targeting, with a cost")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.MONSTER, "it is a monster")
	t.eq(d.race, "Dragon", "and is itself a Dragon")
	t.eq(d.attribute, "DARK", "DARK")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.IGNITION, "an IGNITION effect")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.is_true(e.targets, "it targets")
	t.eq(e.target_count_min, 1, "exactly one target")
	t.is_true(e.pay_cost.is_valid(), "it really declares a COST")
	t.is_true(e.once_per_turn_instance, "once per turn, on this COPY")
	t.is_false(e.once_per_turn_named_effect, "not a named once-per-turn")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"activated from the Monster Zone, face-up")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_retrieves_a_dragon(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: discards 1, adds the targeted Dragon to the hand")
	var d := _board(55001, [_mon("A dragon", "Dragon")])
	var e: DuelEngine = d["engine"]
	var apoc: CardInstance = d["apoc"]
	var fodder: CardInstance = d["fodder"]
	var target: CardInstance = (d["gy"] as Array)[0]
	var hand_before := e.state.player(0).hand.size()
	_queue_discard(d, fodder)

	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID)
	t.not_null(a, "the ignition effect is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [target.id]})), "activated")
	TestFixtures.pass_until_open(e)
	t.eq((d["p0"] as ScriptedController).errors, [],
		"the queued discard answer went to the prompt this test meant")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the discard cost was paid")
	t.eq(fodder.last_move_reason, Enums.MoveReason.DISCARDED, "and it was a DISCARD")
	t.eq(target.zone, Enums.Zone.HAND, "the Dragon really reached the hand")
	t.eq(target.last_move_reason, Enums.MoveReason.ADDED_TO_HAND, "ADDED_TO_HAND")
	t.eq(e.state.player(0).hand.size(), hand_before, "net hand size unchanged")
	t.eq(apoc.zone, Enums.Zone.MONSTER_ZONE, "Apocralyph itself stays on the field")


static func _test_race_is_matched_not_the_name(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: 'Dragon-Type' is the RACE, never the card NAME")
	var d := _board(55002, [
		_mon("Flamvell Guard lookalike", "Dragon"),   # a Dragon with no 'Dragon' in the name
		_mon("Dragon Knight of Warriors", "Warrior"),  # 'Dragon' in the NAME but a Warrior
		_mon("Ordinary spellcaster", "Spellcaster"),
	])
	var e: DuelEngine = d["engine"]
	var apoc: CardInstance = d["apoc"]
	var gy: Array = d["gy"]
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID)
	t.not_null(a, "the effect is offered")
	if a == null:
		return
	t.eq(a.target_candidates, [gy[0].id],
		"only the actual Dragon is targetable, name notwithstanding")
	t.is_false(a.target_candidates.has(gy[1].id),
		"a Warrior named 'Dragon Knight...' is NOT a legal target")
	t.is_false(a.target_candidates.has(gy[2].id), "and neither is a Spellcaster")
	t.is_false(e.submit_action(a.with_choices({"target_ids": [gy[1].id]})),
		"a forged non-Dragon target is rejected")
	t.eq((d["fodder"] as CardInstance).zone, Enums.Zone.HAND, "and paid no cost")


static func _test_only_your_own_graveyard(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: 'your Graveyard' never reaches the opponent's")
	var d := _duel(55003)
	var e: DuelEngine = d["engine"]
	var apoc := TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Discard fodder"))
	var theirs := TestFixtures.give(e, 1, _mon("Their dragon", "Dragon"),
		Enums.Zone.GRAVEYARD)
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD, "the opponent really has a Dragon in the GY")
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID),
		"not offered: the opponent's Graveyard is not 'your Graveyard'")
	var mine := TestFixtures.give(e, 0, _mon("My dragon", "Dragon"), Enums.Zone.GRAVEYARD)
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID)
	t.not_null(a, "offered once the controller's own GY holds one")
	if a == null:
		return
	t.eq(a.target_candidates, [mine.id], "and only their OWN Dragon is targetable")


static func _test_not_offered_without_a_target_or_a_hand(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: needs BOTH a legal target and a card to discard")
	var d1 := _board(55004, [_mon("Not a dragon", "Warrior")])
	var e1: DuelEngine = d1["engine"]
	t.is_false(TestFixtures.has_action(e1.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, (d1["apoc"] as CardInstance).id, EFFECT_ID),
		"not offered with no Dragon in the GY")
	t.eq((d1["fodder"] as CardInstance).zone, Enums.Zone.HAND, "and nothing was paid")

	var d2 := _duel(55005)
	var e2: DuelEngine = d2["engine"]
	var apoc2 := TestFixtures.give_monster_on_field(e2, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give(e2, 0, _mon("A dragon", "Dragon"), Enums.Zone.GRAVEYARD)
	for entry in e2.state.player(0).hand.duplicate():
		e2.state.move_card(entry, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.eq(e2.state.player(0).hand.size(), 0, "the hand really is empty")
	t.is_false(TestFixtures.has_action(e2.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc2.id, EFFECT_ID),
		"not offered with an empty hand - the cost could not be paid")
	TestFixtures.give_to_hand(e2, 0, TestFixtures.spell("Now something to discard"))
	t.is_true(TestFixtures.has_action(e2.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc2.id, EFFECT_ID),
		"offered once a card is in hand")


static func _test_once_per_turn_is_on_this_copy(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: once per turn, per COPY, resetting next turn")
	var d := _board(55006, [_mon("Dragon A", "Dragon"), _mon("Dragon B", "Dragon")])
	var e: DuelEngine = d["engine"]
	var apoc: CardInstance = d["apoc"]
	var second := TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	var more := TestFixtures.give_to_hand(e, 0, TestFixtures.spell("More fodder"))
	var yet_more := TestFixtures.give_to_hand(e, 0, TestFixtures.spell("Yet more fodder"))
	var gy: Array = d["gy"]
	_queue_discard(d, more)
	_queue_discard(d, yet_more)

	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID)
	t.not_null(a, "the first copy is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [gy[0].id]})), "and used")
	TestFixtures.pass_until_open(e)
	t.eq(gy[0].zone, Enums.Zone.HAND, "the first retrieval happened")
	t.is_false(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID),
		"the SAME copy cannot use it twice in a turn")
	var b = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, second.id, EFFECT_ID)
	t.not_null(b, "a DIFFERENT copy still can - the limit is on the instance")
	if b == null:
		return
	t.is_true(e.submit_action(b.with_choices({"target_ids": [gy[1].id]})),
		"and it really used it in the same turn")
	TestFixtures.pass_until_open(e)
	t.eq(gy[1].zone, Enums.Zone.HAND, "its retrieval happened too")

	TestFixtures.give(e, 0, _mon("Fresh dragon", "Dragon"), Enums.Zone.GRAVEYARD)
	TestFixtures.end_turn(e)
	TestFixtures.end_turn(e)
	t.eq(e.state.turn_player_id, 0, "it is player 0's turn again")
	t.is_true(TestFixtures.has_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID),
		"the once-per-turn allowance reset")


static func _test_cannot_target_itself_from_the_field(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: it is a Dragon, but it cannot target ITSELF")
	var d := _board(55007, [_mon("A dragon", "Dragon")])
	var e: DuelEngine = d["engine"]
	var apoc: CardInstance = d["apoc"]
	t.eq(apoc.definition.race, "Dragon", "Apocralyph really is a Dragon")
	t.eq(apoc.zone, Enums.Zone.MONSTER_ZONE, "but it is on the FIELD, not in the GY")
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID)
	t.not_null(a, "the effect is offered")
	if a == null:
		return
	t.is_false(a.target_candidates.has(apoc.id),
		"the source is never among its own targets - the target must be in the GY")
	t.is_false(e.submit_action(a.with_choices({"target_ids": [apoc.id]})),
		"and a forged self-target is rejected")


static func _test_cost_kept_when_negated(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: a negated activation keeps the cost, retrieves nothing")
	var d := _board(55008, [_mon("A dragon", "Dragon")])
	var e: DuelEngine = d["engine"]
	var apoc: CardInstance = d["apoc"]
	var fodder: CardInstance = d["fodder"]
	var target: CardInstance = (d["gy"] as Array)[0]
	var negator := TestFixtures.give_set_spell_trap(e, 1,
		TestFixtures.any_effect_negator("Negate it"))
	_queue_discard(d, fodder)
	var a = TestFixtures.find_action(e.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, apoc.id, EFFECT_ID)
	t.not_null(a, "the effect is offered")
	if a == null:
		return
	t.is_true(e.submit_action(a.with_choices({"target_ids": [target.id]})), "activated")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the cost was paid at ACTIVATION")
	var response = TestFixtures.find_action(e.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "a real negator response was offered")
	if response == null:
		return
	t.is_true(e.submit_action(response), "the negator activated")
	TestFixtures.pass_until_open(e)
	t.check(TestFixtures.count_events(e, GameEvent.Kind.EFFECT_NEGATED)
		+ TestFixtures.count_events(e, GameEvent.Kind.ACTIVATION_NEGATED) >= 1,
		"a negation really happened")
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the target stayed in the Graveyard")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "but the cost is KEPT [S1 p.53]")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Divine Dragon Apocralyph: deck 1's Dragons, including the ones a NAME test misses")
	var cards: Dictionary = CardRegistry.load_library()["cards"]
	const DECK1 := "Blue-Eyes Dragon Guard"
	t.is_true(TradeInTests.deck_names(CARD_UNDER_TEST).has(DECK1),
		"Divine Dragon Apocralyph is in deck 1")
	var dragons: Array = []
	for key in cards:
		var def: CardDef = cards[key]
		if def.is_monster() and def.race == "Dragon" \
				and TradeInTests.deck_names(def.name).has(DECK1):
			dragons.append(def.name)
	dragons.sort()
	t.eq(dragons, ["Alexandrite Dragon", "Blue-Eyes White Dragon",
		"Divine Dragon Apocralyph", "Flamvell Guard", "Hieratic Dragon of Tefnuit",
		"Kaiser Glider", "Luster Dragon", "Mirage Dragon", "Rabidragon",
		"Rider of the Storm Winds", "The White Stone of Legend"],
		"every Dragon in deck 1")
	# The point of matching on race: four of these have no 'Dragon' in their name at all.
	var no_dragon_in_name: Array = []
	for name in dragons:
		if not str(name).to_lower().contains("dragon"):
			no_dragon_in_name.append(name)
	no_dragon_in_name.sort()
	t.eq(no_dragon_in_name, ["Flamvell Guard", "Kaiser Glider",
		"Rider of the Storm Winds", "The White Stone of Legend"],
		"four Dragons a NAME test would silently have missed")
	# And one card whose name contains 'Dragon' but which is not in deck 1 at all.
	t.is_false(TradeInTests.deck_names("Metaphys Armed Dragon").has(DECK1),
		"Metaphys Armed Dragon is in deck 2")
	var metaphys: CardDef = cards["Metaphys Armed Dragon"]
	t.eq(metaphys.race, "Wyrm",
		"and it is a WYRM, not a Dragon - a name test would have been wrong twice over")

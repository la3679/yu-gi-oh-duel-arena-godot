class_name WonderBalloonsTests
extends RefCounted

## Per-card suite for `Wonder Balloons` — the pool's only CONTINUOUS SPELL, and the first
## card to actually drive the counter engine.
##
##   "Once per turn: You can send any number of cards from your hand to the GY; place 1
##    Balloon Counter on this card for each card sent to the GY. All monsters your opponent
##    controls lose 300 ATK for each Balloon Counter on this card."
##
## Two things here are new to the library:
##   * a cost whose SIZE is the player's choice, not the card's ("any number"), which
##     `choose_n` cannot express;
##   * an effect measured by what its own cost consumed, which required the Chain Link's
##     cost payload to reach resolution at all (PROJECT_STATE.md §4).

const CARD_UNDER_TEST := "Wonder Balloons"

const PLACE_ID := "send_hand_place_balloon_counters"
const BALLOON := "Balloon Counter"


static func run() -> TestCase:
	var t := TestCase.new("WonderBalloonsTests")
	_test_clause_shape(t)
	_test_sending_one_card(t)
	_test_sending_several_cards(t)
	_test_any_card_not_just_monsters(t)
	_test_counters_accumulate_across_turns(t)
	_test_the_drain_scales_with_the_counters(t)
	_test_it_drains_only_the_opponent(t)
	_test_atk_floors_at_zero(t)
	_test_the_drain_ends_with_the_card(t)
	_test_an_empty_hand_cannot_pay(t)
	_test_once_per_turn(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A face-up Wonder Balloons on the field, with the player's opening hand cleared out so a
## test controls exactly what is available to send.
static func _armed_board(seed_value: int) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var balloons := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.activate_card(engine, 0, balloons)
	_empty_hand(engine, 0, balloons)
	d["balloons"] = balloons
	return d


## Move every remaining card out of a player's hand, so the only candidates for the cost
## are the ones a test puts there. The opening hand is dealt from a shuffled Deck, so
## leaving it in place would make the offered option list depend on the seed.
static func _empty_hand(engine: DuelEngine, pid: int, keep: CardInstance) -> void:
	for entry in engine.state.player(pid).hand.duplicate():
		var card: CardInstance = entry
		if card != keep:
			engine.state.move_card(card, Enums.Zone.DECK, Enums.MoveReason.RULE)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three EffectDefs: the Continuous Spell's activation, the once-per-turn "
		+ "counter placement, and the continuous drain")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.CONTINUOUS_SPELL,
		"the V1 pool's only Continuous Spell")
	t.eq(def.spell_speed, Enums.SpellSpeed.SS1, "a Continuous Spell is Spell Speed 1")
	t.eq(def.effects.size(), 3, "activation + placement + drain")

	var activation: EffectDef = def.effects[0]
	t.eq(activation.effect_type, Enums.EffectType.CARD_ACTIVATION, "the card's activation")
	t.is_true(activation.activation_locations.has(Enums.ActivationLocation.HAND),
		"activatable from the hand")
	t.is_true(activation.activation_locations.has(Enums.ActivationLocation.FIELD_FACE_DOWN),
		"and from a Set copy")

	var place: EffectDef = def.effects[1]
	t.eq(place.effect_type, Enums.EffectType.IGNITION, "an Ignition Effect")
	t.eq(place.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.is_true(place.once_per_turn_instance, "'Once per turn' on this copy")
	t.is_false(place.targets, "it targets nothing")
	t.is_true(place.pay_cost.is_valid(), "the send is a real COST")
	t.eq(place.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"and belongs to its controller's Main Phases")

	var drain: EffectDef = def.effects[2]
	t.eq(drain.effect_type, Enums.EffectType.CONTINUOUS, "the drain is continuous")
	t.is_false(drain.starts_chain, "so it never starts a Chain")
	t.is_false(drain.negates_effects, "and it negates nothing")
	t.is_true(drain.apply_continuous.is_valid(), "with a real apply_continuous()")


# ---------------------------------------------------------------------------
# "send any number of cards from your hand"
# ---------------------------------------------------------------------------

static func _test_sending_one_card(t: TestCase) -> void:
	t.start("one card in hand: nothing to decide, one card sent, one counter placed")
	var d := _armed_board(9501)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var balloons: CardInstance = d["balloons"]

	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	t.eq(engine.state.player(0).hand.size(), 1, "exactly one card in hand")

	var asked_before := controller.request_count(Enums.DecisionKind.CHOOSE_COST)
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID),
		"the effect is activated")

	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_COST), asked_before,
		"with a single candidate and a minimum of one there is nothing to ask")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the card was sent to the Graveyard")
	t.eq(fodder.last_move_reason, Enums.MoveReason.SENT_AS_COST,
		"as a COST, not as a discard [S1 p.52-53]")
	t.eq(engine.state.total_counters(balloons, BALLOON), 1, "one Balloon Counter")


static func _test_sending_several_cards(t: TestCase) -> void:
	t.start("'ANY NUMBER' is the player's choice — three of four cards sent, three "
		+ "counters placed, one card kept")
	var d := _armed_board(9502)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var balloons: CardInstance = d["balloons"]

	var a := TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	var b := TestFixtures.give_to_hand(engine, 0, _card("Luster Dragon"))
	var c := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var kept := TestFixtures.give_to_hand(engine, 0, _card("Alexandrite Dragon"))
	t.eq(engine.state.player(0).hand.size(), 4, "four cards in hand")

	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [a.id, b.id, c.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID),
		"the effect is activated, sending three of them")
	t.eq(controller.errors, [], "the queued answer went to the prompt the test meant")

	t.eq(a.zone, Enums.Zone.GRAVEYARD, "the first chosen card was sent")
	t.eq(b.zone, Enums.Zone.GRAVEYARD, "the second too")
	t.eq(c.zone, Enums.Zone.GRAVEYARD, "and the third")
	t.eq(kept.zone, Enums.Zone.HAND, "the one not chosen stayed in hand")
	t.eq(engine.state.total_counters(balloons, BALLOON), 3,
		"3 Balloon Counters — one FOR EACH card sent, read from what the cost consumed")


static func _test_any_card_not_just_monsters(t: TestCase) -> void:
	t.start("'any number of CARDS' — a Spell and a Trap in hand are legal to send")
	var d := _armed_board(9503)
	var engine: DuelEngine = d["engine"]
	var balloons: CardInstance = d["balloons"]

	var spell := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var trap := TestFixtures.give_to_hand(engine, 0, _card("Birthright"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, balloons.id, PLACE_ID)
	t.not_null(action, "the effect is offered with only non-monsters in hand")

	var controller: ScriptedController = d["p0"]
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [spell.id, trap.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "both are sent")
	t.eq(controller.errors, [], "the queued answer matched the prompt")
	t.eq(spell.zone, Enums.Zone.GRAVEYARD, "the Spell went to the Graveyard")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "and so did the Trap")
	t.eq(engine.state.total_counters(balloons, BALLOON), 2, "two counters")


static func _test_counters_accumulate_across_turns(t: TestCase) -> void:
	t.start("counters accumulate on the card rather than being replaced")
	var d := _armed_board(9504)
	var engine: DuelEngine = d["engine"]
	var balloons: CardInstance = d["balloons"]

	TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "one this turn")
	t.eq(engine.state.total_counters(balloons, BALLOON), 1, "one counter")

	t.is_true(TestFixtures.end_turn(engine), "the opponent takes a turn")
	t.is_true(TestFixtures.end_turn(engine), "and play returns")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1), "to Main Phase 1")
	_empty_hand(engine, 0, balloons)

	TestFixtures.give_to_hand(engine, 0, _card("Luster Dragon"))
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "one more")
	t.eq(engine.state.total_counters(balloons, BALLOON), 2,
		"two counters in total — the second use added to the first")


# ---------------------------------------------------------------------------
# The continuous drain
# ---------------------------------------------------------------------------

static func _test_the_drain_scales_with_the_counters(t: TestCase) -> void:
	t.start("'lose 300 ATK for each Balloon Counter' — the drain follows the counters exactly")
	var d := _armed_board(9505)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var balloons: CardInstance = d["balloons"]

	var victim := TestFixtures.give_monster_on_field(engine, 1, _card("Sabersaurus"))
	t.eq(victim.current_atk(), 1900, "no counters yet, so no drain")

	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "one counter")
	t.eq(victim.current_atk(), 1600, "1900 - 300")

	# Five recomputes must equal one: a continuous effect is rebuilt, never accumulated.
	var continuous := ContinuousEffects.new(engine.state)
	for i in range(5):
		continuous.recompute()
	t.eq(victim.current_atk(), 1600, "still 1600 after five recomputes")
	t.eq(victim.atk_modifiers.size(), 1, "exactly one modifier entry")

	t.is_true(TestFixtures.end_turn(engine), "the opponent takes a turn")
	t.is_true(TestFixtures.end_turn(engine), "and play returns")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1), "to Main Phase 1")
	_empty_hand(engine, 0, balloons)

	var x := TestFixtures.give_to_hand(engine, 0, _card("Luster Dragon"))
	var y := TestFixtures.give_to_hand(engine, 0, _card("Alexandrite Dragon"))
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [x.id, y.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "two more")
	t.eq(engine.state.total_counters(balloons, BALLOON), 3, "three counters now")
	t.eq(victim.current_atk(), 1000, "1900 - 900")


static func _test_it_drains_only_the_opponent(t: TestCase) -> void:
	t.start("'all monsters YOUR OPPONENT controls' — yours are untouched, theirs are all "
		+ "affected including face-down ones")
	var d := _armed_board(9506)
	var engine: DuelEngine = d["engine"]
	var balloons: CardInstance = d["balloons"]

	var mine := TestFixtures.give_monster_on_field(engine, 0, _card("Sabersaurus"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _card("Sabersaurus"))
	var their_second := TestFixtures.give_monster_on_field(engine, 1,
		_card("Alexandrite Dragon"))
	var their_face_down := TestFixtures.give_monster_on_field(engine, 1,
		_card("Luster Dragon"), Enums.Position.FACE_DOWN_DEFENSE)

	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "one counter")

	t.eq(mine.current_atk(), 1900, "your own monster is untouched")
	t.eq(theirs.current_atk(), 1600, "theirs loses 300")
	t.eq(their_second.current_atk(), 1700, "and so does every other one they control")
	t.eq(their_face_down.current_atk(), 1600,
		"including a FACE-DOWN one — the text has no face-up qualifier")


static func _test_atk_floors_at_zero(t: TestCase) -> void:
	t.start("ATK never goes negative, however many counters are on the card")
	var d := _armed_board(9507)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var balloons: CardInstance = d["balloons"]

	var weak := TestFixtures.give_monster_on_field(engine, 1,
		_card("The White Stone of Legend"))
	t.eq(weak.current_atk(), 300, "it starts at its printed 300 ATK")

	var a := TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	var b := TestFixtures.give_to_hand(engine, 0, _card("Luster Dragon"))
	var c := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	controller.queue_for(Enums.DecisionKind.CHOOSE_COST, [a.id, b.id, c.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID),
		"three cards are sent")

	t.eq(engine.state.total_counters(balloons, BALLOON), 3, "three counters")
	t.eq(weak.current_atk(), 0, "300 - 900 floors at 0, not -600")
	t.eq(weak.original_atk(), 300,
		"while the ORIGINAL ATK is untouched — it is a modifier [S1 p.55]")


static func _test_the_drain_ends_with_the_card(t: TestCase) -> void:
	t.start("the drain is state-derived: destroy Wonder Balloons and it is gone, counters "
		+ "and all")
	var d := _armed_board(9508)
	var engine: DuelEngine = d["engine"]
	var balloons: CardInstance = d["balloons"]

	var victim := TestFixtures.give_monster_on_field(engine, 1, _card("Sabersaurus"))
	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "one counter")
	t.eq(victim.current_atk(), 1600, "drained")

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", balloons, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Wonder Balloons")

	t.eq(balloons.zone, Enums.Zone.GRAVEYARD, "it left the field")
	t.eq(victim.current_atk(), 1900, "the drain lifted with its source")
	t.eq(victim.atk_modifiers.size(), 0, "with no stale modifier left behind")
	t.eq(engine.state.total_counters(balloons, BALLOON), 0,
		"and its counters were cleared when it left the field")


# ---------------------------------------------------------------------------
# Negatives
# ---------------------------------------------------------------------------

static func _test_an_empty_hand_cannot_pay(t: TestCase) -> void:
	t.start("'any number' still has a minimum of one, so an empty hand cannot pay the cost")
	var d := _armed_board(9509)
	var engine: DuelEngine = d["engine"]
	var balloons: CardInstance = d["balloons"]

	t.eq(engine.state.player(0).hand.size(), 0, "the hand is empty")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, balloons.id, PLACE_ID),
		"the effect is not offered")

	var forged := DuelAction.make(Enums.ActionKind.ACTIVATE_EFFECT, 0, balloons.id, PLACE_ID)
	t.is_false(engine.submit_action(forged), "a hand-built activation is rejected")
	t.eq(engine.state.total_counters(balloons, BALLOON), 0, "and no counter was placed")

	TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, balloons.id, PLACE_ID),
		"one card in hand is enough — the positive control")


static func _test_once_per_turn(t: TestCase) -> void:
	t.start("'Once per turn' is per COPY, and it blocks a second use even with cards left "
		+ "to send")
	var d := _armed_board(9510)
	var engine: DuelEngine = d["engine"]
	var balloons: CardInstance = d["balloons"]

	TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	t.is_true(TestFixtures.activate_effect(engine, 0, balloons, PLACE_ID), "the first use")
	t.eq(engine.state.total_counters(balloons, BALLOON), 1, "one counter")

	TestFixtures.give_to_hand(engine, 0, _card("Luster Dragon"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, balloons.id, PLACE_ID),
		"a second use is refused this turn even though the cost is payable")
	t.eq(engine.state.total_counters(balloons, BALLOON), 1, "still one counter")

	t.is_true(TestFixtures.end_turn(engine), "the opponent takes a turn")
	t.is_true(TestFixtures.end_turn(engine), "and play returns")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1), "to Main Phase 1")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, balloons.id, PLACE_ID),
		"the use has returned")

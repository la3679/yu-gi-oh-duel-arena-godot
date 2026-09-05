class_name TheWhiteStoneOfLegendTests
extends RefCounted

## Per-card suite for `The White Stone of Legend` — "If this card is sent to the GY: Add 1
## 'Blue-Eyes White Dragon' from your Deck to your hand."
##
## The card R40 exists for. Two things it must get right and that the general rules alone
## would have got wrong:
##
##   * it activates **even with no Blue-Eyes White Dragon in the Deck** (cid 7850), where
##     [S1 p.53]'s general search-activation restriction would have suppressed it;
##   * it fires off a **discard paid as a COST**, which no card in the pool had ever done
##     and which the engine silently dropped until unit A fixed it.
##
## Both are asserted directly, so neither can be "tidied away" by a later change.

const CARD_UNDER_TEST := "The White Stone of Legend"
const EFFECT_ID := "gy_search_blue_eyes"
const BLUE_EYES := "Blue-Eyes White Dragon"


static func run() -> TestCase:
	var t := TestCase.new("TheWhiteStoneOfLegendTests")
	_test_clause_shape(t)
	_test_fires_when_sent_to_the_gy(t)
	_test_it_activates_with_an_empty_search(t)
	_test_every_route_to_the_gy_fires_it(t)
	_test_a_banished_card_later_moved_to_the_gy_does_not_fire_it(t)
	_test_only_its_own_send_fires_it(t)
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


## Every interferer in this suite belongs to PLAYER 0, the turn player. `get_legal_actions()`
## returns nothing for a player who is not the turn player, so a Set Trap on the opponent's
## side is simply never offered in an open game state — and the failure is silent, because
## the helper just returns false. Who owns the card that sends the stone to the Graveyard is
## irrelevant to this card's rule, so the turn player owns it.
##
## How many Chain Links `card` itself put on the Chain. `CHAIN_LINK_ADDED` carries the source
## card's id, so "did THIS card's effect activate" is answerable directly rather than by
## counting links and hoping.
static func _links_made_by(engine: DuelEngine, card: CardInstance) -> int:
	return TestFixtures.count_events_for(engine, GameEvent.Kind.CHAIN_LINK_ADDED, card.id)


## A duel with the stone in `zone` and, optionally, a real Blue-Eyes White Dragon in the Deck.
static func _board(seed_value: int, zone: Enums.Zone, blue_eyes_in_deck: bool) -> Dictionary:
	var d := _duel(seed_value)
	var e: DuelEngine = d["engine"]
	TestFixtures.clear_deck(e, 0)
	if blue_eyes_in_deck:
		d["bewd"] = TestFixtures.give_to_deck(e, 0, _card(BLUE_EYES))
	# Padding, so the Deck is never empty for reasons unrelated to the search.
	for i in range(3):
		TestFixtures.give_to_deck(e, 0, TestFixtures.monster("Padding %d" % i))
	if zone == Enums.Zone.MONSTER_ZONE:
		d["stone"] = TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
	else:
		d["stone"] = TestFixtures.give(e, 0, _card(CARD_UNDER_TEST), zone)
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("The White Stone of Legend: one MANDATORY Graveyard trigger")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.MONSTER, "it is a monster")
	t.eq(d.level, 1, "Level 1")
	t.eq(d.race, "Dragon", "a Dragon")
	t.eq(d.attribute, "LIGHT", "LIGHT")
	t.is_true(d.is_tuner, "and a Tuner - which is what lets Cards of Consonance discard it")
	t.check(d.base_atk <= 1000, "with 1000 or less ATK, the other half of that requirement")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.TRIGGER, "a TRIGGER effect")
	t.eq(e.optionality, Enums.Optionality.MANDATORY,
		"MANDATORY - no 'You can' is printed and cid 7850 says it must activate")
	t.eq(e.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"activated from the GRAVEYARD - it is already there when it activates")
	t.eq(e.trigger_events, [GameEvent.Kind.CARD_SENT_TO_GY],
		"keyed on being SENT to the GY, not on being destroyed")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"cid 7850: it activates even during the Damage Step")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")
	t.is_false(e.targets, "it does not target")
	t.is_false(e.pay_cost.is_valid(), "and it has no cost of its own")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_fires_when_sent_to_the_gy(t: TestCase) -> void:
	t.start("The White Stone of Legend: sent from the field, it searches out Blue-Eyes")
	var d := _board(56001, Enums.Zone.MONSTER_ZONE, true)
	var e: DuelEngine = d["engine"]
	var stone: CardInstance = d["stone"]
	var bewd: CardInstance = d["bewd"]
	var killer := TestFixtures.give_set_spell_trap(e, 0,
		TestFixtures.interferer("Send it away", stone, "destroy"))
	var hand_before := e.state.player(0).hand.size()
	var links_before := TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)

	t.is_true(TestFixtures.activate_card(e, 0, killer), "a real effect destroyed the stone")
	t.eq(stone.zone, Enums.Zone.GRAVEYARD, "the stone really reached the Graveyard")
	t.check(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before >= 2,
		"the trigger REALLY activated - a Chain Link beyond the interferer's was made")
	t.eq(_links_made_by(e, stone), 1, "and that link was THE STONE'S OWN")
	t.eq(bewd.zone, Enums.Zone.HAND, "Blue-Eyes White Dragon was added to the hand")
	t.eq(bewd.last_move_reason, Enums.MoveReason.ADDED_TO_HAND, "ADDED_TO_HAND")
	t.eq(bewd.revealed_to, [0, 1], "and it was revealed to both players on the way")
	t.eq(e.state.player(0).hand.size(), hand_before + 1, "the hand grew by exactly one")
	t.eq(e.state.player(0).deck_count(), 3, "and the Deck lost exactly one card")


static func _test_it_activates_with_an_empty_search(t: TestCase) -> void:
	t.start("The White Stone of Legend: it ACTIVATES with no Blue-Eyes in the Deck (cid 7850)")
	var d := _board(56002, Enums.Zone.MONSTER_ZONE, false)
	var e: DuelEngine = d["engine"]
	var stone: CardInstance = d["stone"]
	var killer := TestFixtures.give_set_spell_trap(e, 0,
		TestFixtures.interferer("Send it away", stone, "destroy"))
	var hand_before := e.state.player(0).hand.size()
	var deck_before := e.state.player(0).deck_count()
	var links_before := TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)

	t.is_true(TestFixtures.activate_card(e, 0, killer), "a real effect destroyed the stone")
	t.eq(stone.zone, Enums.Zone.GRAVEYARD, "the stone reached the Graveyard")
	# This is the whole point, and the most load-bearing assertion in batch 10: the general
	# [S1 p.53] restriction would have suppressed this activation, and cid 7850 says it
	# happens anyway. Asserted three ways so it cannot be quietly "fixed" back.
	t.check(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before >= 2,
		"the trigger STILL activated with nothing to find - card-specific ruling wins")
	t.eq(_links_made_by(e, stone), 1,
		"and the extra link was THE STONE'S OWN, not somebody else's")
	t.check(TestFixtures.count_events_for(e, GameEvent.Kind.EFFECT_ACTIVATED, stone.id) >= 1,
		"the engine recorded the stone's effect as ACTIVATED")
	t.eq(e.state.player(0).hand.size(), hand_before, "but nothing was added to the hand")
	t.eq(e.state.player(0).deck_count(), deck_before, "and nothing left the Deck")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_REVEALED), 0, "nothing was revealed")
	t.is_false(e.state.is_duel_over(), "and an empty search is never a loss")


static func _test_every_route_to_the_gy_fires_it(t: TestCase) -> void:
	# "sent to the GY" names no cause, so every route must fire it - including the one the
	# engine used to drop, a discard paid as a COST.
	var routes := [
		["discarded as a COST by another card", "cost"],
		["sent to the GY from the hand", "discard"],
		["Tributed for a Summon", "tribute"],
		["sent to the GY from the field by an effect", "send"],
		["destroyed by an effect", "destroy"],
	]
	for entry in routes:
		var label: String = entry[0]
		var mode: String = entry[1]
		t.start("The White Stone of Legend: it fires when %s" % label)
		var d := _duel(56100 + routes.find(entry))
		var e: DuelEngine = d["engine"]
		TestFixtures.clear_deck(e, 0)
		var bewd := TestFixtures.give_to_deck(e, 0, _card(BLUE_EYES))
		for i in range(3):
			TestFixtures.give_to_deck(e, 0, TestFixtures.monster("Padding %d" % i))
		var stone: CardInstance = null
		var links_before := 0
		match mode:
			"cost":
				# The real deck line: Cards of Consonance discards it as a cost.
				stone = TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
				var consonance := TestFixtures.give_to_hand(e, 0,
					_card("Cards of Consonance"))
				(d["p0"] as ScriptedController).queue_for(
					Enums.DecisionKind.CHOOSE_DISCARD, [stone.id])
				links_before = TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
				t.is_true(TestFixtures.activate_card(e, 0, consonance),
					"Cards of Consonance activated")
				t.eq((d["p0"] as ScriptedController).errors, [],
					"the stone really was the card discarded")
			"discard":
				stone = TestFixtures.give_to_hand(e, 0, _card(CARD_UNDER_TEST))
				var sender := TestFixtures.give_set_spell_trap(e, 0,
					TestFixtures.interferer("Send it", stone, "send_to_gy"))
				links_before = TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
				t.is_true(TestFixtures.activate_card(e, 0, sender), "sent from the hand")
			"tribute":
				stone = TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
				var boss := TestFixtures.give_to_hand(e, 0,
					TestFixtures.monster("Tribute target", 6, 2400))
				links_before = TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
				var a = TestFixtures.find_action(e.get_legal_actions(0),
					Enums.ActionKind.TRIBUTE_SUMMON, boss.id)
				t.not_null(a, "a Tribute Summon using the stone is offered")
				if a == null:
					continue
				t.is_true(e.submit_action(a.with_choices({"tribute_ids": [stone.id]})),
					"Tribute Summon declared")
				TestFixtures.pass_until_open(e)
			"send":
				stone = TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
				var sender2 := TestFixtures.give_set_spell_trap(e, 0,
					TestFixtures.interferer("Send it", stone, "send_to_gy"))
				links_before = TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
				t.is_true(TestFixtures.activate_card(e, 0, sender2), "sent from the field")
			"destroy":
				stone = TestFixtures.give_monster_on_field(e, 0, _card(CARD_UNDER_TEST))
				var killer := TestFixtures.give_set_spell_trap(e, 0,
					TestFixtures.interferer("Destroy it", stone, "destroy"))
				links_before = TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
				t.is_true(TestFixtures.activate_card(e, 0, killer), "destroyed")
		TestFixtures.pass_until_open(e)
		t.eq(stone.zone, Enums.Zone.GRAVEYARD, "the stone reached the Graveyard")
		t.eq(TestFixtures.count_events_for(e, GameEvent.Kind.CARD_SENT_TO_GY, stone.id), 1,
			"and the engine really recorded it as SENT TO THE GY")
		# One link on the Tribute route (a Tribute Summon is not itself a Chain Link),
		# two on the routes that go through an activation of their own.
		t.check(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before >= 1,
			"the trigger REALLY activated on this route - a Chain Link was made")
		t.eq(bewd.zone, Enums.Zone.HAND, "Blue-Eyes White Dragon was searched out")


static func _test_a_banished_card_later_moved_to_the_gy_does_not_fire_it(t: TestCase) -> void:
	t.start("The White Stone of Legend: banished, then moved to the GY, is NOT 'sent' [S1 p.53]")
	var d := _board(56003, Enums.Zone.BANISHED, true)
	var e: DuelEngine = d["engine"]
	var stone: CardInstance = d["stone"]
	var bewd: CardInstance = d["bewd"]
	t.eq(stone.zone, Enums.Zone.BANISHED, "the stone starts banished")
	var links_before := TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
	e.state.move_card(stone, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	TestFixtures.pass_until_open(e)
	t.eq(stone.zone, Enums.Zone.GRAVEYARD, "it is now in the Graveyard")
	t.eq(TestFixtures.count_events_for(e, GameEvent.Kind.CARD_SENT_TO_GY, stone.id), 0,
		"but no CARD_SENT_TO_GY was emitted - a banished card is not 'sent to the GY'")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED), links_before,
		"so the trigger did NOT activate")
	t.eq(bewd.zone, Enums.Zone.DECK, "and Blue-Eyes stayed in the Deck")


static func _test_only_its_own_send_fires_it(t: TestCase) -> void:
	t.start("The White Stone of Legend: another card reaching the GY does not fire it")
	var d := _board(56004, Enums.Zone.GRAVEYARD, true)
	var e: DuelEngine = d["engine"]
	var bewd: CardInstance = d["bewd"]
	var other := TestFixtures.give_monster_on_field(e, 0, TestFixtures.monster("Someone else"))
	var killer := TestFixtures.give_set_spell_trap(e, 0,
		TestFixtures.interferer("Destroy the other one", other, "destroy"))
	var links_before := TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED)
	t.is_true(TestFixtures.activate_card(e, 0, killer), "a real effect destroyed the OTHER monster")
	t.eq(other.zone, Enums.Zone.GRAVEYARD, "and it reached the Graveyard")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before, 1,
		"only the interferer's own link - the stone's trigger did NOT activate")
	t.eq(bewd.zone, Enums.Zone.DECK, "Blue-Eyes stayed in the Deck")


# ---------------------------------------------------------------------------
# The real pool
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("The White Stone of Legend: the real pool makes the search and the cost line live")
	var cards: Dictionary = CardRegistry.load_library()["cards"]
	const DECK1 := "Blue-Eyes Dragon Guard"
	t.is_true(TradeInTests.deck_names(CARD_UNDER_TEST).has(DECK1), "the stone is in deck 1")
	t.is_true(TradeInTests.deck_names(BLUE_EYES).has(DECK1),
		"and so is Blue-Eyes White Dragon, so the search is genuinely live")
	t.is_true(TradeInTests.deck_names("Cards of Consonance").has(DECK1),
		"Cards of Consonance is too, so the discard-as-a-cost line is genuinely live")
	# It qualifies for that cost, and NOT for Trade-In's.
	var stone: CardDef = cards[CARD_UNDER_TEST]
	t.is_true(EffectPrimitives.tuner_monster("Dragon", 1000).call(
		CardInstance.new(stone, 0)),
		"the stone really qualifies as a Dragon Tuner with 1000 or less ATK")
	t.is_false(EffectPrimitives.monster_of_level(8).call(CardInstance.new(stone, 0)),
		"and it is Level 1, so Trade-In can never discard it")
	# It is also a legal Dragon Shrine mill and a legal Apocralyph target.
	t.eq(stone.race, "Dragon", "it is a Dragon, so Dragon Shrine can mill it")
	t.is_false(stone.is_normal_monster,
		"but NOT a Normal Monster, so milling it does not unlock Dragon Shrine's second send")

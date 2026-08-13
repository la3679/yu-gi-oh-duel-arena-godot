class_name DragonicTacticsTests
extends RefCounted

## Per-card suite for `Dragonic Tactics` — "Tribute 2 Dragon monsters; Special Summon 1
## Level 8 Dragon monster from your Deck."
##
## This is the first card in the library whose cost consumes TWO cards, and the first
## whose Summon comes out of the hidden Deck. The negatives worth having are therefore
## about the two filters: which monsters may be Tributed, and which may be Summoned.

const CARD_UNDER_TEST := "Dragonic Tactics"

const EFFECT_ID := "tribute_two_dragons_summon_level_8"


static func run() -> TestCase:
	var t := TestCase.new("DragonicTacticsTests")
	_test_clause_shape(t)
	_test_tributes_two_dragons_and_summons_from_the_deck(t)
	_test_only_dragons_you_control_are_offered_as_tributes(t)
	_test_not_offered_with_only_one_dragon(t)
	_test_not_offered_without_a_level_8_dragon_in_the_deck(t)
	_test_a_level_7_wyrm_does_not_qualify(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _tactics_def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _into_deck(engine: DuelEngine, pid: int, def: CardDef) -> CardInstance:
	return TestFixtures.give(engine, pid, def, Enums.Zone.DECK)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("the clause is a non-targeting Normal Spell activation with a two-card cost")
	var def := _tactics_def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.NORMAL_SPELL, "the card database says Normal Spell")
	t.eq(def.effects.size(), 1, "one EffectDef per official clause, and this card has one")
	var effect: EffectDef = def.effects[0]

	t.eq(effect.effect_type, Enums.EffectType.CARD_ACTIVATION, "activating the card is it")
	t.eq(effect.spell_speed, Enums.SpellSpeed.SS1, "a Normal Spell is Spell Speed 1")
	t.is_false(effect.targets,
		"the text has no 'target', and the Deck is hidden, so the monster is chosen "
		+ "at resolution (RULES_SPEC.md 10)")
	t.is_true(effect.can_pay_cost.is_valid(), "the cost is checked before it is offered")
	t.is_true(effect.pay_cost.is_valid(), "and paid at activation")


# ---------------------------------------------------------------------------
# Positively
# ---------------------------------------------------------------------------

static func _test_tributes_two_dragons_and_summons_from_the_deck(t: TestCase) -> void:
	t.start("two Dragons are Tributed at activation and a Level 8 Dragon comes out "
		+ "of the Deck")
	var d := _main_phase_duel(9501)
	var engine: DuelEngine = d["engine"]

	var tactics := TestFixtures.give_to_hand(engine, 0, _tactics_def())
	var first := TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	var second := TestFixtures.give_monster_on_field(engine, 0,
		_card("Alexandrite Dragon"))
	var prize := _into_deck(engine, 0, _card("Blue-Eyes White Dragon"))
	var deck_before := engine.state.player(0).deck.size()

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id)
	t.not_null(action, "Dragonic Tactics is offered")
	t.is_true(engine.submit_action(action), "and is activated")

	t.eq(first.zone, Enums.Zone.GRAVEYARD, "the first Dragon was Tributed at activation")
	t.eq(second.zone, Enums.Zone.GRAVEYARD, "and so was the second")
	TestFixtures.pass_until_open(engine)

	t.eq(prize.zone, Enums.Zone.MONSTER_ZONE, "the Level 8 Dragon arrived from the Deck")
	t.eq(prize.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.eq(engine.state.player(0).deck.size(), deck_before - 1, "the Deck lost one card")
	t.eq(engine.state.player(0).monster_count(), 1,
		"and it is the only monster on the field")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_TRIBUTED), 2,
		"exactly two Tributes happened")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), 0,
		"a Tribute is not a destruction [S1 p.53]")
	t.eq(tactics.zone, Enums.Zone.GRAVEYARD,
		"and the Normal Spell went to the Graveyard after resolving")


# ---------------------------------------------------------------------------
# Negatively — the two filters
# ---------------------------------------------------------------------------

static func _test_only_dragons_you_control_are_offered_as_tributes(t: TestCase) -> void:
	t.start("the Tribute candidates are Dragon monsters YOU control, and nothing else")
	var d := _main_phase_duel(9502)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	# Three Dragons, so the choice is genuinely put to the player: with exactly two
	# candidates there would be nothing to decide and no question would be asked.
	var tactics := TestFixtures.give_to_hand(engine, 0, _tactics_def())
	var dragon_a := TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	var dragon_b := TestFixtures.give_monster_on_field(engine, 0,
		_card("Alexandrite Dragon"))
	var dragon_c := TestFixtures.give_monster_on_field(engine, 0, _card("Flamvell Guard"))
	var not_a_dragon := TestFixtures.give_monster_on_field(engine, 0,
		_card("Sabersaurus"))
	var wyrm := TestFixtures.give_monster_on_field(engine, 0,
		_card("Metaphys Armed Dragon"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _card("Rabidragon"))
	_into_deck(engine, 0, _card("Blue-Eyes White Dragon"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id)
	t.not_null(action, "Dragonic Tactics is offered")
	t.is_true(engine.submit_action(action), "and is activated")
	TestFixtures.pass_until_open(engine)

	var offered: Array = []
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind == Enums.DecisionKind.CHOOSE_TRIBUTES:
			offered = request.options
	t.eq(offered.size(), 3,
		"the controller was asked to pick 2 Tributes from the three Dragons they control")
	t.is_true(offered.has(dragon_a.id), "Luster Dragon is a candidate")
	t.is_true(offered.has(dragon_b.id), "so is Alexandrite Dragon")
	t.is_true(offered.has(dragon_c.id), "so is the Level 1 Flamvell Guard — no Level "
		+ "restriction applies to the Tributes")
	t.is_false(offered.has(not_a_dragon.id), "the Dinosaur is not")
	t.is_false(offered.has(wyrm.id), "the Wyrm is not — 'Dragon' is the race, not the name")
	t.is_false(offered.has(theirs.id),
		"and the opponent's Dragon is not: you only ever Tribute your own monsters")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "the opponent's Dragon was untouched")


static func _test_not_offered_with_only_one_dragon(t: TestCase) -> void:
	t.start("with only one Dragon on the field the cost cannot be paid")
	var d := _main_phase_duel(9503)
	var engine: DuelEngine = d["engine"]

	var tactics := TestFixtures.give_to_hand(engine, 0, _tactics_def())
	var lone := TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	TestFixtures.give_monster_on_field(engine, 0, _card("Sabersaurus"))
	_into_deck(engine, 0, _card("Blue-Eyes White Dragon"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id),
		"a cost that cannot be paid means the card cannot be activated (master prompt 16)")
	t.is_false(engine.submit_action(
		DuelAction.make(Enums.ActionKind.ACTIVATE_CARD, 0, tactics.id, EFFECT_ID)),
		"and a hand-built activation is rejected")
	t.eq(lone.zone, Enums.Zone.MONSTER_ZONE, "so nothing was Tributed")

	TestFixtures.give_monster_on_field(engine, 0, _card("Alexandrite Dragon"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id),
		"a second Dragon makes the cost payable and the card activatable")


static func _test_not_offered_without_a_level_8_dragon_in_the_deck(t: TestCase) -> void:
	t.start("with no Level 8 Dragon in the Deck the effect can do nothing")
	var d := _main_phase_duel(9504)
	var engine: DuelEngine = d["engine"]

	var tactics := TestFixtures.give_to_hand(engine, 0, _tactics_def())
	TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	TestFixtures.give_monster_on_field(engine, 0, _card("Alexandrite Dragon"))
	# A Level 8 Dragon in the HAND is not "from your Deck".
	TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id),
		"the card is not offered even though the cost is payable")

	_into_deck(engine, 0, _card("Rabidragon"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id),
		"putting one in the Deck makes it activatable")


static func _test_a_level_7_wyrm_does_not_qualify(t: TestCase) -> void:
	t.start("'Level 8 Dragon monster' is an exact Level and the Dragon race")
	var d := _main_phase_duel(9505)
	var engine: DuelEngine = d["engine"]

	var tactics := TestFixtures.give_to_hand(engine, 0, _tactics_def())
	TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	TestFixtures.give_monster_on_field(engine, 0, _card("Alexandrite Dragon"))
	# Level 7, and a Wyrm rather than a Dragon: it fails both halves of the filter.
	_into_deck(engine, 0, _card("Metaphys Armed Dragon"))
	# A Level 1 Dragon fails the Level half on its own.
	_into_deck(engine, 0, _card("Flamvell Guard"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id),
		"neither a Level 7 Wyrm nor a Level 1 Dragon satisfies 'Level 8 Dragon monster'")

	# Positive control: the card really is one Deck card away from being activatable, so
	# the negative above is a filter result and not some unrelated blocker.
	var qualifier := _into_deck(engine, 0, _card("Rabidragon"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, tactics.id),
		"adding a Level 8 Dragon to the same Deck makes it activatable")
	t.eq(qualifier.definition.level, 8, "and that card is the Level 8 Dragon")
	t.eq(qualifier.definition.race, "Dragon", "of the Dragon race")

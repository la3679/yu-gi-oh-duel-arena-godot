class_name NormalMonsterTests
extends RefCounted

## The nine vanilla Normal Monsters of the V1 pool.
##
## A Normal Monster has no effect clauses, so "implemented" means something different for
## it than for the other 68 cards: an EMPTY effect list is the complete and correct
## implementation, which is what `CardDef.is_vanilla()` and `CardRegistry.unimplemented()`
## already encode. `Tools/build_matrix.py` reads CARDS_UNDER_TEST below and reports these
## nine as IMPLEMENTED / TESTED only because this suite exists and passes.
##
## The load-bearing test in this file is the LAST one. It proves the shortcut cannot be
## abused: every Effect Monster in the pool that has no registry file is still reported as
## unimplemented, so an unimplemented Effect Monster can never be quietly demoted to a
## vanilla body. Master prompt 67 — no silent fallbacks.

const CARDS_UNDER_TEST := [
	"Alexandrite Dragon",
	"Blue-Eyes White Dragon",
	"Flamvell Guard",
	"Gladiator Beast Andal",
	"Luster Dragon",
	"Metaphys Armed Dragon",
	"Rabidragon",
	"Sabersaurus",
	"Zure, Knight of Dark World",
]


static func run() -> TestCase:
	var t := TestCase.new("NormalMonsterTests")
	_test_all_nine_are_vanilla(t)
	_test_tribute_requirement_follows_level(t)
	_test_normal_summon_a_real_vanilla(t)
	_test_tribute_summon_a_real_vanilla(t)
	_test_a_vanilla_battles_on_its_printed_stats(t)
	_test_a_vanilla_offers_no_effect_to_activate(t)
	_test_no_effect_monster_is_treated_as_vanilla(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def(cards: Dictionary, card_name: String) -> CardDef:
	return cards.get(card_name, null)


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

static func _test_all_nine_are_vanilla(t: TestCase) -> void:
	t.start("all nine Normal Monsters load as vanilla bodies with no effect clauses")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var cards: Dictionary = lib["cards"]

	var vanilla_names: Array = []
	for card_name in cards.keys():
		var def: CardDef = cards[card_name]
		if def.is_vanilla():
			vanilla_names.append(card_name)
	vanilla_names.sort()

	var expected := CARDS_UNDER_TEST.duplicate()
	expected.sort()
	t.eq(vanilla_names, expected,
		"exactly these nine cards are vanilla — the pool composition recorded in "
		+ "PROJECT_STATE.md 1 says 9 Normal Monsters")

	for card_name in CARDS_UNDER_TEST:
		var def := _def(cards, card_name)
		t.not_null(def, "%s is in the card database" % card_name)
		t.is_true(def.is_normal_monster, "%s is a Normal Monster" % card_name)
		t.is_false(def.is_effect_monster, "%s is not an Effect Monster" % card_name)
		t.eq(def.effects.size(), 0,
			"%s has no effect clauses — an empty list IS its implementation" % card_name)


static func _test_tribute_requirement_follows_level(t: TestCase) -> void:
	t.start("each vanilla's Tribute requirement follows its printed Level [S1 p.24-25]")
	var cards: Dictionary = _library()["cards"]
	for card_name in CARDS_UNDER_TEST:
		var def := _def(cards, card_name)
		var expected := 0
		if def.level >= 7:
			expected = 2
		elif def.level >= 5:
			expected = 1
		t.eq(def.base_tributes_required(), expected,
			"%s is Level %d, so it needs %d Tribute(s)" % [card_name, def.level, expected])


# ---------------------------------------------------------------------------
# They are real, playable cards
# ---------------------------------------------------------------------------

static func _test_normal_summon_a_real_vanilla(t: TestCase) -> void:
	t.start("a Level 4 vanilla can actually be Normal Summoned from the hand")
	var cards: Dictionary = _library()["cards"]
	var d := TestFixtures.new_duel(9101, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var sabersaurus := TestFixtures.give_to_hand(engine, 0, _def(cards, "Sabersaurus"))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, sabersaurus.id)
	t.not_null(action, "Sabersaurus is offered as a Normal Summon")
	t.eq(action.tributes_required, 0, "a Level 4 monster needs no Tribute")

	t.is_true(engine.submit_action(action), "the Summon is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(sabersaurus.zone, Enums.Zone.MONSTER_ZONE, "it reached a Monster Zone")
	t.eq(sabersaurus.position, Enums.Position.FACE_UP_ATTACK, "face-up in Attack Position")
	t.eq(sabersaurus.summoned_by, Enums.SummonKind.NORMAL, "by Normal Summon")
	t.eq(sabersaurus.current_atk(), 1900, "with its printed ATK")
	t.eq(sabersaurus.current_def(), 500, "and its printed DEF")
	t.is_false(engine.state.player(0).can_normal_summon(),
		"and the one Normal Summon per turn is spent [S1 p.24]")


static func _test_tribute_summon_a_real_vanilla(t: TestCase) -> void:
	t.start("a Level 8 vanilla needs two Tributes and can be Tribute Summoned")
	var cards: Dictionary = _library()["cards"]
	var d := TestFixtures.new_duel(9102, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var blue_eyes := TestFixtures.give_to_hand(engine, 0,
		_def(cards, "Blue-Eyes White Dragon"))
	var fodder_a := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder A", 4, 1000, 1000))
	var fodder_b := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder B", 4, 1000, 1000))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, blue_eyes.id)
	t.not_null(action, "Blue-Eyes White Dragon is offered as a Tribute Summon")
	t.eq(action.tributes_required, 2, "Level 8 requires two Tributes [S1 p.25]")

	# `action` comes back from find_action() as a Variant, so := cannot infer through it.
	var chosen = action.with_choices({"tribute_ids": [fodder_a.id, fodder_b.id]})
	t.is_true(engine.submit_action(chosen), "the Tribute Summon is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(blue_eyes.zone, Enums.Zone.MONSTER_ZONE, "Blue-Eyes reached the field")
	t.eq(blue_eyes.current_atk(), 3000, "with its printed 3000 ATK")
	t.eq(fodder_a.zone, Enums.Zone.GRAVEYARD, "the first Tribute is in the Graveyard")
	t.eq(fodder_b.zone, Enums.Zone.GRAVEYARD, "so is the second")
	t.eq(engine.state.player(0).monster_count(), 1,
		"and only the Summoned monster remains on the field")


static func _test_a_vanilla_battles_on_its_printed_stats(t: TestCase) -> void:
	t.start("two real vanillas resolve a battle on their printed ATK [S1 p.42]")
	var cards: Dictionary = _library()["cards"]
	var d := TestFixtures.battle_duel(9103)
	var engine: DuelEngine = d["engine"]

	var alexandrite := TestFixtures.give_monster_on_field(engine, 0,
		_def(cards, "Alexandrite Dragon"))
	var sabersaurus := TestFixtures.give_monster_on_field(engine, 1,
		_def(cards, "Sabersaurus"))
	var lp_before := engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, alexandrite, sabersaurus),
		"Alexandrite Dragon attacks Sabersaurus")
	TestFixtures.pass_until_open(engine)

	t.eq(sabersaurus.zone, Enums.Zone.GRAVEYARD,
		"2000 ATK beats 1900 ATK, so the defender is destroyed")
	t.eq(alexandrite.zone, Enums.Zone.MONSTER_ZONE, "the attacker survives")
	t.eq(engine.state.player(1).life_points, lp_before - 100,
		"and the difference, 100, is inflicted as battle damage")


# ---------------------------------------------------------------------------
# Negatively — the part that matters
# ---------------------------------------------------------------------------

static func _test_a_vanilla_offers_no_effect_to_activate(t: TestCase) -> void:
	t.start("a vanilla on the field never offers an effect to activate")
	var cards: Dictionary = _library()["cards"]
	var d := TestFixtures.new_duel(9104, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var luster := TestFixtures.give_monster_on_field(engine, 0,
		_def(cards, "Luster Dragon"))
	var actions := engine.get_legal_actions(0)
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.ACTIVATE_EFFECT, luster.id),
		"no effect activation is offered for Luster Dragon")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.ACTIVATE_CARD, luster.id),
		"and no card activation either")
	t.is_false(TestFixtures.has_action(actions,
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, luster.id),
		"and it carries no summoning procedure")
	# A hand-built activation must be rejected too: absence from the offered list is not
	# by itself proof that the engine would refuse it.
	var forged := DuelAction.make(Enums.ActionKind.ACTIVATE_EFFECT, 0, luster.id, "anything")
	t.is_false(engine.submit_action(forged),
		"and a hand-built activation for it is rejected")


static func _test_no_effect_monster_is_treated_as_vanilla(t: TestCase) -> void:
	t.start("no Effect Monster is silently treated as a vanilla card")
	var lib := _library()
	var cards: Dictionary = lib["cards"]

	var effect_monsters_marked_vanilla: Array = []
	for card_name in cards.keys():
		var def: CardDef = cards[card_name]
		if def.is_effect_monster and def.is_vanilla():
			effect_monsters_marked_vanilla.append(card_name)
	t.eq(effect_monsters_marked_vanilla, [],
		"is_vanilla() is false for every Effect Monster, implemented or not")

	# The honest "not implemented" list must still contain every non-vanilla card that has
	# no effects. If this ever silently shrinks, the matrix is over-reporting.
	var unimplemented := CardRegistry.unimplemented(cards)
	var missing_from_list: Array = []
	for card_name in cards.keys():
		var def: CardDef = cards[card_name]
		if def.is_vanilla():
			continue
		if def.effects.is_empty() and not unimplemented.has(card_name):
			missing_from_list.append(card_name)
	t.eq(missing_from_list, [],
		"every card that needs effects and has none is reported as unimplemented")

	var vanilla_on_the_unimplemented_list: Array = []
	for card_name in unimplemented:
		var def: CardDef = cards[card_name]
		if def.is_vanilla():
			vanilla_on_the_unimplemented_list.append(card_name)
	t.eq(vanilla_on_the_unimplemented_list, [],
		"and nothing on that list is a vanilla body — the two categories never overlap")
	t.is_true(unimplemented.size() > 0,
		"the list is genuinely non-empty at this point in Phase 5, so the checks above "
		+ "are not passing vacuously")

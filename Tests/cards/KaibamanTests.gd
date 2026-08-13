class_name KaibamanTests
extends RefCounted

## Per-card suite for `Kaibaman` — "You can Tribute this card; Special Summon 1
## 'Blue-Eyes White Dragon' from your hand."
##
## The whole point of this card in the test suite is the SEMICOLON: everything before it
## is a cost, paid at activation. The test that matters most is
## `_test_the_cost_is_paid_even_when_the_effect_is_negated` — if the Tribute were folded
## into resolution, that test would fail and the engine would be wrong about every other
## cost too. RULES_SPEC.md 10, master prompt 16.

const CARD_UNDER_TEST := "Kaibaman"

const EFFECT_ID := "tribute_self_summon_blue_eyes"
const BLUE_EYES := "Blue-Eyes White Dragon"


static func run() -> TestCase:
	var t := TestCase.new("KaibamanTests")
	_test_clause_shape(t)
	_test_tributes_itself_and_summons_blue_eyes(t)
	_test_the_cost_is_paid_even_when_the_effect_is_negated(t)
	_test_not_offered_without_blue_eyes_in_hand(t)
	_test_only_blue_eyes_qualifies(t)
	_test_not_offered_from_the_hand_or_face_down(t)
	_test_not_offered_outside_the_main_phases(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _kaibaman_def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("the clause is a non-targeting Ignition Effect usable only in a Main Phase")
	var def := _kaibaman_def()
	t.not_null(def, "the definition exists")
	t.is_true(def.is_effect_monster, "Kaibaman is an Effect Monster, not a vanilla body")
	t.is_false(def.is_vanilla(), "so it is never treated as vanilla")
	t.eq(def.effects.size(), 1, "one EffectDef per official clause, and this card has one")
	var effect: EffectDef = def.effects[0]

	t.eq(effect.effect_type, Enums.EffectType.IGNITION, "it is an Ignition Effect")
	t.eq(effect.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1 [S1 p.10]")
	t.is_false(ActivationRules.is_fast_effect(effect),
		"so it is never offered in a Fast Effect response window")
	t.is_false(effect.targets,
		"the official text has no 'target', so the copy is chosen at resolution")
	t.eq(effect.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"it is activated from the field, face-up")
	t.eq(effect.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"an Ignition Effect is a Main Phase action")
	t.is_true(effect.pay_cost.is_valid(),
		"the text before the semicolon is modelled as a real cost")


# ---------------------------------------------------------------------------
# Positively
# ---------------------------------------------------------------------------

static func _test_tributes_itself_and_summons_blue_eyes(t: TestCase) -> void:
	t.start("Kaibaman Tributes itself as a cost and Special Summons Blue-Eyes")
	var d := _main_phase_duel(9401)
	var engine: DuelEngine = d["engine"]

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _kaibaman_def())
	var blue_eyes := TestFixtures.give_to_hand(engine, 0, _card(BLUE_EYES))
	var tributes_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_TRIBUTED)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID)
	t.not_null(action, "the effect is offered")
	t.is_true(engine.submit_action(action), "and is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(kaibaman.zone, Enums.Zone.GRAVEYARD, "Kaibaman paid the cost and is in the GY")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_TRIBUTED),
		tributes_before + 1, "it was TRIBUTED, which is not a destruction [S1 p.53]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), 0,
		"and nothing was destroyed")

	t.eq(blue_eyes.zone, Enums.Zone.MONSTER_ZONE, "Blue-Eyes left the hand for the field")
	t.eq(blue_eyes.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.eq(blue_eyes.current_atk(), 3000, "with its printed ATK")
	t.eq(engine.state.player(0).monster_count(), 1,
		"the zone Kaibaman vacated is the one Blue-Eyes fills")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"and the Normal Summon for the turn is still available [S1 p.24]")


static func _test_the_cost_is_paid_even_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("the Tribute is a COST: it stays paid when the effect is negated")
	var d := _main_phase_duel(9402)
	var engine: DuelEngine = d["engine"]

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _kaibaman_def())
	var blue_eyes := TestFixtures.give_to_hand(engine, 0, _card(BLUE_EYES))
	var negator := TestFixtures.give_set_spell_trap(engine, 1, _negator_def(), 0)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID)
	t.not_null(action, "the effect is offered")
	t.is_true(engine.submit_action(action), "and is activated as Chain Link 1")
	t.eq(kaibaman.zone, Enums.Zone.GRAVEYARD,
		"the cost was already paid the moment it was activated, before any response")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and negates the effect as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(blue_eyes.zone, Enums.Zone.HAND, "Blue-Eyes was not Summoned")
	t.eq(engine.state.player(0).monster_count(), 0, "the field is empty")
	t.eq(kaibaman.zone, Enums.Zone.GRAVEYARD,
		"but Kaibaman is still gone — a paid cost is never refunded")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"exactly one effect negation happened")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"and no Special Summon occurred")


# ---------------------------------------------------------------------------
# Negatively
# ---------------------------------------------------------------------------

static func _test_not_offered_without_blue_eyes_in_hand(t: TestCase) -> void:
	t.start("with no Blue-Eyes in hand there is nothing the effect could do")
	var d := _main_phase_duel(9403)
	var engine: DuelEngine = d["engine"]

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _kaibaman_def())
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID),
		"the effect is not offered")
	t.is_false(engine.submit_action(
		DuelAction.make(Enums.ActionKind.ACTIVATE_EFFECT, 0, kaibaman.id, EFFECT_ID)),
		"and a hand-built activation is rejected")
	t.eq(kaibaman.zone, Enums.Zone.MONSTER_ZONE,
		"so no cost was paid — a rejected action changes nothing")

	# A copy in the GRAVEYARD is not "in your hand".
	TestFixtures.give(engine, 0, _card(BLUE_EYES), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID),
		"a Blue-Eyes in the Graveyard does not enable it either")


static func _test_only_blue_eyes_qualifies(t: TestCase) -> void:
	t.start("the clause names one specific card, so no other Dragon will do")
	var d := _main_phase_duel(9404)
	var engine: DuelEngine = d["engine"]

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _kaibaman_def())
	TestFixtures.give_to_hand(engine, 0, _card("Rabidragon"))
	TestFixtures.give_to_hand(engine, 0, _card("Alexandrite Dragon"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID),
		"other Level 8 LIGHT Dragons in hand do not satisfy '1 \"Blue-Eyes White Dragon\"'")

	var blue_eyes := TestFixtures.give_to_hand(engine, 0, _card(BLUE_EYES))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID)
	t.not_null(action, "adding the named card makes it activatable")
	t.is_true(engine.submit_action(action), "it is activated")
	TestFixtures.pass_until_open(engine)
	t.eq(blue_eyes.zone, Enums.Zone.MONSTER_ZONE,
		"and it is the named card that was Summoned")
	t.eq(engine.state.player(0).monster_count(), 1, "exactly one monster arrived")


static func _test_not_offered_from_the_hand_or_face_down(t: TestCase) -> void:
	t.start("the effect is activated from the field face-up, nowhere else")
	var d := _main_phase_duel(9405)
	var engine: DuelEngine = d["engine"]

	TestFixtures.give_to_hand(engine, 0, _card(BLUE_EYES))
	var in_hand := TestFixtures.give_to_hand(engine, 0, _kaibaman_def())
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, in_hand.id, EFFECT_ID),
		"a copy in the hand cannot use it")

	var face_down := TestFixtures.give_monster_on_field(engine, 0, _kaibaman_def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, face_down.id, EFFECT_ID),
		"a face-down copy on the field cannot use it either")

	engine.state.set_battle_position(face_down, Enums.Position.FACE_UP_ATTACK, true)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, face_down.id, EFFECT_ID),
		"turning that same copy face-up makes it usable")


static func _test_not_offered_outside_the_main_phases(t: TestCase) -> void:
	t.start("an Ignition Effect is not available in the Battle Phase [S1 p.10]")
	var d := TestFixtures.battle_duel(9406)
	var engine: DuelEngine = d["engine"]

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _kaibaman_def())
	TestFixtures.give_to_hand(engine, 0, _card(BLUE_EYES))
	t.eq(engine.state.phase, Enums.Phase.BATTLE, "the duel is in the Battle Phase")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID),
		"the effect is not offered there")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"the turn player moves on to Main Phase 2")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, EFFECT_ID),
		"where it is offered again — Main Phase 2 counts")


# ---------------------------------------------------------------------------
# A synthetic negation card, so this suite stays about Kaibaman
# ---------------------------------------------------------------------------

static func _negator_def() -> CardDef:
	var def := TestFixtures.trap("Test Effect Negator")
	var effect := EffectDef.new("negate_chain_link_1",
		"Test card: negate the effect of Chain Link 1.")
	effect.of_type(Enums.EffectType.CARD_ACTIVATION)
	effect.spell_speed = Enums.SpellSpeed.SS2
	effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	effect.resolve = func(ctx: EffectContext) -> void:
		ctx.engine.chain.negate_effect(1, ctx.source)
	return TestFixtures.with_effect(def, effect)

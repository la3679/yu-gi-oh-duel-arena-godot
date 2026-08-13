class_name WynnTheWindCharmerTests
extends RefCounted

## Per-card suite for `Wynn the Wind Charmer`. Research/CARD_RULINGS.md §2.1.
##
##   "FLIP: Target 1 WIND monster your opponent controls; take control of that monster
##    while this card is face-up on the field."
##
## Word for word `Aussa the Earth Charmer` with WIND in place of EARTH, so the mechanics are
## shared through `EffectPrimitives.charmer_take_control()` and the full clause enumeration
## lives in `AussaTheEarthCharmerTests`. This suite proves the behaviour end to end on ITS OWN
## card — that the shared primitive is genuinely wired up with the right Attribute, and that
## the duration works — plus the one assertion the group as a whole needs: that the three
## Charmers really are three separate cards with three different Attribute filters, so a
## shared implementation cannot quietly collapse them into one.


const CARD_UNDER_TEST := "Wynn the Wind Charmer"

const EFFECT_ID := "charmer_take_control"

const CHARMERS := {
	"Aussa the Earth Charmer": "EARTH",
	"Eria the Water Charmer": "WATER",
	"Wynn the Wind Charmer": "WIND",
}


static func run() -> TestCase:
	var t := TestCase.new("WynnTheWindCharmerTests")
	_test_clause_shape(t)
	_test_the_wind_requirement(t)
	_test_it_takes_control(t)
	_test_control_ends_when_wynn_is_flipped_face_down(t)
	_test_the_three_charmers_are_three_cards(t)
	return t


static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _effect_of(def: CardDef) -> EffectDef:
	for entry in def.effects:
		var e: EffectDef = entry
		if e.effect_id == EFFECT_ID:
			return e
	return null


static func _effect() -> EffectDef:
	return _effect_of(_def())


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _board(seed_value: int) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["wynn"] = TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	d["prey"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1200, 800, "WIND"))
	return d


static func _flip_summon(engine: DuelEngine, wynn: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, wynn.id)
	if a == null:
		return false
	var ok := engine.submit_action(a)
	TestFixtures.pass_until_open(engine)
	return ok


static func _test_clause_shape(t: TestCase) -> void:
	t.start("one printed clause, one EffectDef: a MANDATORY, TARGETING Flip Effect")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.attribute, "WIND", "Wynn is a WIND monster herself")
	t.eq(def.level, 3, "Level 3")
	t.eq(def.effects.size(), 1, "one printed clause, one EffectDef")

	var e := _effect()
	t.not_null(e, "the clause is present")
	t.eq(e.effect_type, Enums.EffectType.FLIP, "a FLIP effect")
	t.eq(e.optionality, Enums.Optionality.MANDATORY, "MANDATORY — no \"you can\"")
	t.is_true(e.targets, "it TARGETS — the current official wording, not the old one")
	t.is_true(e.trigger_events.has(GameEvent.Kind.CARD_FLIPPED_FACE_UP),
		"it triggers on being flipped face-up")
	t.is_true(e.clause_text.contains("Target 1 WIND monster your opponent controls"),
		"and the quoted text is Wynn's own")


static func _test_the_wind_requirement(t: TestCase) -> void:
	t.start("only WIND monsters your opponent controls are legal targets")
	var d := _duel(451)
	var engine: DuelEngine = d["engine"]
	var wynn := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var wind := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Windy", 4, 1200, 800, "WIND"))
	var earth := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Earthy", 4, 1200, 800, "EARTH"))
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden Wind", 4, 1200, 800, "WIND"),
		Enums.Position.FACE_DOWN_DEFENSE)

	var ctx := ActivationRules.make_context(engine.state, wynn, _effect(), 0, null)
	var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)
	t.is_true(legal.has(wind.id), "the face-up WIND monster is a candidate")
	t.is_false(legal.has(earth.id), "the EARTH monster is not")
	t.is_false(legal.has(hidden.id), "and neither is the face-down WIND monster")
	t.eq(legal.size(), 1, "exactly one candidate")


static func _test_it_takes_control(t: TestCase) -> void:
	t.start("Flip Summoned, Wynn takes control of the WIND monster")
	var d := _board(452)
	var engine: DuelEngine = d["engine"]
	var wynn: CardInstance = d["wynn"]
	var prey: CardInstance = d["prey"]

	t.is_true(_flip_summon(engine, wynn), "Wynn is Flip Summoned")
	t.eq(prey.controller_id, 0, "player 0 controls the WIND monster")
	t.eq(prey.owner_id, 1, "player 1 still owns it")
	t.is_true(engine.state.player(0).monsters().has(prey), "it sits in player 0's zones")
	t.is_false(engine.state.player(1).monsters().has(prey), "and not in player 1's")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"one control change was announced")
	var lease: Dictionary = engine.state.control_leases_for(prey.id)[0]
	t.eq(int(lease["source_id"]), wynn.id, "the lease hangs off Wynn")


static func _test_control_ends_when_wynn_is_flipped_face_down(t: TestCase) -> void:
	t.start("control returns the moment Wynn is flipped face-down — she does not have to "
		+ "leave the field for the duration to end")
	var d := _board(453)
	var engine: DuelEngine = d["engine"]
	var wynn: CardInstance = d["wynn"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Veil", wynn, "flip_face_down"), 0)

	t.is_true(_flip_summon(engine, wynn), "Wynn is Flip Summoned")
	t.eq(prey.controller_id, 0, "control was taken")

	var trap = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	if trap == null:
		TestFixtures.end_turn(engine)
		trap = TestFixtures.find_action(engine.get_legal_actions(1),
			Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(trap, "the opponent can act")
	t.is_true(engine.submit_action(trap), "and flips Wynn face-down")
	TestFixtures.pass_until_open(engine)

	t.is_false(wynn.is_face_up(), "Wynn is face-down")
	t.eq(wynn.zone, Enums.Zone.MONSTER_ZONE, "but still on the field")
	t.eq(prey.controller_id, 1, "and control has returned anyway")
	t.eq(engine.state.control_leases.size(), 0, "the lease is over")


static func _test_the_three_charmers_are_three_cards(t: TestCase) -> void:
	t.start("the shared implementation is three cards, not one: each has its own name, "
		+ "Attribute, quoted text and Attribute FILTER")
	var d := _duel(454)
	var engine: DuelEngine = d["engine"]
	var earth := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Earthy", 4, 1200, 800, "EARTH"))
	var water := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Watery", 4, 1200, 800, "WATER"))
	var wind := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Windy", 4, 1200, 800, "WIND"))
	var by_attribute := {"EARTH": earth.id, "WATER": water.id, "WIND": wind.id}

	for card_name in CHARMERS:
		var attribute: String = CHARMERS[card_name]
		var def := _card(card_name)
		t.not_null(def, "%s is in the library" % card_name)
		t.eq(def.attribute, attribute, "%s is a %s monster" % [card_name, attribute])
		var e := _effect_of(def)
		t.not_null(e, "%s has the clause" % card_name)
		t.is_true(e.clause_text.contains("Target 1 %s monster" % attribute),
			"%s quotes its own Attribute" % card_name)

		# The filter, on a real board holding one monster of each Attribute.
		var charmer := TestFixtures.give_monster_on_field(engine, 0, def,
			Enums.Position.FACE_DOWN_DEFENSE)
		var ctx := ActivationRules.make_context(engine.state, charmer, e, 0, null)
		var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)
		t.eq(legal.size(), 1, "%s sees exactly one candidate" % card_name)
		t.eq(int(legal[0]), int(by_attribute[attribute]),
			"and it is the %s monster" % attribute)
		engine.state.move_card(charmer, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)

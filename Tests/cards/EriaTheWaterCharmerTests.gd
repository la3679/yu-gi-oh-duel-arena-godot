class_name EriaTheWaterCharmerTests
extends RefCounted

## Per-card suite for `Eria the Water Charmer`. Research/CARD_RULINGS.md §2.1.
##
##   "FLIP: Target 1 WATER monster your opponent controls; take control of that monster
##    while this card is face-up on the field."
##
## Eria is the one Charmer whose CURRENT official text differs from the older printing in
## more than the Attribute: the old wording said "1 **face-up** WATER monster" and the
## current one does not, while gaining "Target". This suite therefore does two things the
## other two do not:
##
##   * it asserts the implemented clause text against the current official wording, including
##     that "face-up" is absent;
##   * it proves that dropping the word changed nothing about what can actually be taken — a
##     face-down monster is still not a legal target, because its Attribute is not a property
##     either player may act on.
##
## The mechanics are shared with `Aussa the Earth Charmer` and `Wynn the Wind Charmer`
## through `EffectPrimitives.charmer_take_control()`, and `AussaTheEarthCharmerTests` carries
## the full clause enumeration. This suite still proves the behaviour end to end on ITS OWN
## card rather than assuming the shared primitive is wired up correctly.


const CARD_UNDER_TEST := "Eria the Water Charmer"

const EFFECT_ID := "charmer_take_control"


static func run() -> TestCase:
	var t := TestCase.new("EriaTheWaterCharmerTests")
	_test_clause_shape_and_the_corrected_text(t)
	_test_the_water_requirement(t)
	_test_face_down_is_still_not_a_target(t)
	_test_it_takes_control(t)
	_test_control_ends_with_eria(t)
	return t


static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


static func _effect() -> EffectDef:
	for entry in _def().effects:
		var e: EffectDef = entry
		if e.effect_id == EFFECT_ID:
			return e
	return null


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _board(seed_value: int) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["eria"] = TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	d["prey"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1200, 800, "WATER"))
	return d


static func _flip_summon(engine: DuelEngine, eria: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, eria.id)
	if a == null:
		return false
	var ok := engine.submit_action(a)
	TestFixtures.pass_until_open(engine)
	return ok


static func _test_clause_shape_and_the_corrected_text(t: TestCase) -> void:
	t.start("the CURRENT official text is implemented: it targets, and \"face-up\" is gone")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.attribute, "WATER", "Eria is a WATER monster herself")
	t.eq(def.level, 3, "Level 3")
	t.eq(def.effects.size(), 1, "one printed clause, one EffectDef")

	var e := _effect()
	t.not_null(e, "the clause is present")
	t.eq(e.effect_type, Enums.EffectType.FLIP, "a FLIP effect")
	t.eq(e.optionality, Enums.Optionality.MANDATORY, "MANDATORY — no \"you can\"")
	t.is_true(e.targets, "it TARGETS, which the older printing did not")
	t.eq(e.target_count_min, 1, "exactly 1 target")
	t.is_true(e.clause_text.contains("Target 1 WATER monster your opponent controls"),
		"the quoted text is the current official wording")
	t.is_false(e.clause_text.contains("face-up WATER"),
		"and does NOT carry the old \"face-up WATER monster\" wording")
	t.is_true(e.clause_text.contains("while this card is face-up on the field"),
		"the one \"face-up\" that IS in the current text is the DURATION, about Eria "
		+ "herself rather than about the target")


static func _test_the_water_requirement(t: TestCase) -> void:
	t.start("only WATER monsters your opponent controls are legal targets")
	var d := _duel(431)
	var engine: DuelEngine = d["engine"]
	var eria := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var water := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Watery", 4, 1200, 800, "WATER"))
	var earth := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Earthy", 4, 1200, 800, "EARTH"))
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Water", 4, 1200, 800, "WATER"))

	var ctx := ActivationRules.make_context(engine.state, eria, _effect(), 0, null)
	var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)
	t.is_true(legal.has(water.id), "the opponent's WATER monster is a candidate")
	t.is_false(legal.has(earth.id), "an EARTH monster is not — the Attribute is the filter")
	t.is_false(legal.has(mine.id), "and neither is your own WATER monster")
	t.eq(legal.size(), 1, "exactly one candidate")


static func _test_face_down_is_still_not_a_target(t: TestCase) -> void:
	t.start("dropping the printed word \"face-up\" did NOT make face-down monsters "
		+ "targetable: an unknown Attribute cannot satisfy \"1 WATER monster\"")
	var d := _duel(432)
	var engine: DuelEngine = d["engine"]
	var eria := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden", 4, 1200, 800, "WATER"),
		Enums.Position.FACE_DOWN_DEFENSE)

	var ctx := ActivationRules.make_context(engine.state, eria, _effect(), 0, null)
	t.eq(ActivationRules.legal_targets(ctx).size(), 0,
		"the face-down WATER monster is not a candidate")

	# Positive control, so the negative cannot pass for the wrong reason.
	engine.state.set_battle_position(hidden, Enums.Position.FACE_UP_ATTACK, true)
	var ctx2 := ActivationRules.make_context(engine.state, eria, _effect(), 0, null)
	var legal := ActivationRules.legal_targets(ctx2).map(func(c): return c.id)
	t.eq(legal.size(), 1, "face-up, the very same monster IS a candidate")
	t.is_true(legal.has(hidden.id), "and it is that monster")


static func _test_it_takes_control(t: TestCase) -> void:
	t.start("Flip Summoned, Eria takes control of the WATER monster — controller changes, "
		+ "owner does not")
	var d := _board(433)
	var engine: DuelEngine = d["engine"]
	var eria: CardInstance = d["eria"]
	var prey: CardInstance = d["prey"]

	t.is_true(_flip_summon(engine, eria), "Eria is Flip Summoned")
	t.is_true(eria.is_face_up(), "and is face-up")
	t.eq(prey.controller_id, 0, "player 0 controls the WATER monster")
	t.eq(prey.owner_id, 1, "player 1 still owns it")
	t.is_true(engine.state.player(0).monsters().has(prey), "it sits in player 0's zones")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"one control change was announced")
	var lease: Dictionary = engine.state.control_leases_for(prey.id)[0]
	t.eq(int(lease["source_id"]), eria.id, "the lease hangs off Eria")
	t.eq(lease["duration"], Enums.ControlDuration.WHILE_SOURCE_FACE_UP,
		"for as long as she is face-up on the field")


static func _test_control_ends_with_eria(t: TestCase) -> void:
	t.start("control returns the moment Eria leaves the field")
	var d := _board(434)
	var engine: DuelEngine = d["engine"]
	var eria: CardInstance = d["eria"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Snipe", eria, "destroy"), 0)

	t.is_true(_flip_summon(engine, eria), "Eria is Flip Summoned")
	t.eq(prey.controller_id, 0, "control was taken")

	var trap = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	if trap == null:
		TestFixtures.end_turn(engine)
		trap = TestFixtures.find_action(engine.get_legal_actions(1),
			Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(trap, "the opponent can act")
	t.is_true(engine.submit_action(trap), "and destroys Eria")
	TestFixtures.pass_until_open(engine)

	t.eq(eria.zone, Enums.Zone.GRAVEYARD, "Eria is in the Graveyard")
	t.eq(prey.controller_id, 1, "control has returned")
	t.eq(prey.owner_id, 1, "and the owner never changed")
	t.eq(engine.state.control_leases.size(), 0, "the lease is over")

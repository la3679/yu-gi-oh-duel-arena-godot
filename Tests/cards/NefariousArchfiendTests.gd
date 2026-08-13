class_name NefariousArchfiendTests
extends RefCounted

## Per-card suite for `Nefarious Archfiend Eater of Nefariousness`.
## Research/CARD_RULINGS.md R17.
##
##   "You can only control 1 'Nefarious Archfiend Eater of Nefariousness'. If you control
##    a Spellcaster monster, you can Special Summon this card (from your hand). Once per
##    turn, during your opponent's End Phase, if this card is in your GY: You can target
##    1 face-up monster you control; destroy it, and if you do, Special Summon this card."
##
## Two things here exist nowhere else in the library so far: an effect activated on a turn
## that is not its controller's, and a "destroy it, AND IF YOU DO" clause whose second
## half is conditional on the first actually happening.

const CARD_UNDER_TEST := "Nefarious Archfiend Eater of Nefariousness"

const PROCEDURE_ID := "ss_if_you_control_a_spellcaster"


static func run() -> TestCase:
	var t := TestCase.new("NefariousArchfiendTests")
	_test_clause_shape(t)
	_test_the_procedure_and_the_control_limit(t)
	_test_the_opponents_end_phase_revival(t)
	_test_not_during_your_own_end_phase(t)
	_test_declining(t)
	_test_no_face_up_monster_to_target(t)
	_test_and_if_you_do(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


## A Continuous Spell that makes its controller's monsters immune to effect destruction.
## Used to prove the "and if you do" half really is conditional.
static func _ward_def() -> CardDef:
	var d := TestFixtures.spell("Test Ward", Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new("ward",
		"Test: monsters you control cannot be destroyed by card effects.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		for entry in ctx.me().monsters():
			var card: CardInstance = entry
			ContinuousEffects.restrict(card, "cannot_be_destroyed_by_effect")
	return TestFixtures.with_effect(d, e)


## A duel where player 0 has this card in the Graveyard and a face-up monster on the
## field, sitting on player 1's turn so player 1's End Phase is reachable.
static func _armed_board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var controller: ScriptedController = d["p0"]
	controller.default_yes = true
	d["archfiend"] = TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	d["fodder"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses, and the third activates in the OPPONENT's End Phase")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var limit: EffectDef = def.effects[0]
	t.eq(limit.effect_id, SummonRules.CONTROL_LIMIT_EFFECT_ID, "the control limit is real")

	var procedure: EffectDef = def.effects[1]
	t.eq(procedure.effect_type, Enums.EffectType.SUMMON_PROCEDURE, "a summoning procedure")

	var trigger: EffectDef = def.effects[2]
	t.eq(trigger.effect_type, Enums.EffectType.TRIGGER, "and a Trigger Effect")
	t.eq(trigger.optionality, Enums.Optionality.OPTIONAL, "'You can' — optional")
	t.is_true(trigger.once_per_turn_instance, "'Once per turn'")
	t.eq(trigger.legal_phases, [Enums.Phase.END], "'during your opponent's End Phase'")
	t.is_true(trigger.targets, "'You can TARGET 1 face-up monster you control'")
	t.eq(trigger.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"'if this card is in your GY'")
	t.eq(trigger.ruling_ref, "R17", "traced to the recorded ruling")


static func _test_the_procedure_and_the_control_limit(t: TestCase) -> void:
	t.start("the procedure needs a face-up Spellcaster, and only one copy may be controlled")
	var d := TestFixtures.new_duel(7701, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var archfiend := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, archfiend.id, PROCEDURE_ID),
		"not offered with no Spellcaster on your side")

	TestFixtures.give_monster_on_field(engine, 0, _card("Apprentice Magician"))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, archfiend.id, PROCEDURE_ID)
	t.not_null(action, "offered once you control a face-up Spellcaster")
	t.is_true(engine.submit_action(action), "and performed")
	TestFixtures.pass_until_open(engine)
	t.eq(archfiend.zone, Enums.Zone.MONSTER_ZONE, "it reaches the field")

	var second := TestFixtures.give_to_hand(engine, 0, _def())
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, second.id, PROCEDURE_ID),
		"a second copy is refused by the control limit")


# ---------------------------------------------------------------------------
# The Graveyard effect
# ---------------------------------------------------------------------------

static func _test_the_opponents_end_phase_revival(t: TestCase) -> void:
	t.start("during the OPPONENT's End Phase it destroys one of your own face-up monsters "
		+ "and Special Summons itself in its place")
	var d := _armed_board(7702)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var archfiend: CardInstance = d["archfiend"]
	var fodder: CardInstance = d["fodder"]

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"the opponent's End Phase is reached")

	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 1,
		"its controller was asked exactly once — the effect is optional and once per turn")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the targeted monster was destroyed")
	t.eq(fodder.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT, "by a card effect")
	t.eq(archfiend.zone, Enums.Zone.MONSTER_ZONE,
		"and the Archfiend Special Summoned itself out of the Graveyard")
	t.eq(archfiend.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.eq(archfiend.controller_id, 0, "under its owner's control")
	t.eq(engine.state.turn_player_id, 1,
		"all of this happened on the OPPONENT's turn")


static func _test_not_during_your_own_end_phase(t: TestCase) -> void:
	t.start("'your OPPONENT's End Phase' — your own End Phase is not the timing")
	var d := TestFixtures.new_duel(7703, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var controller: ScriptedController = d["p0"]
	controller.default_yes = true
	var archfiend := TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"your OWN End Phase is reached")
	t.eq(engine.state.turn_player_id, 0, "and it really is your turn")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 0,
		"the controller is never asked")
	t.eq(fodder.zone, Enums.Zone.MONSTER_ZONE, "nothing was destroyed")
	t.eq(archfiend.zone, Enums.Zone.GRAVEYARD, "and nothing was Special Summoned")


static func _test_declining(t: TestCase) -> void:
	t.start("declining the optional trigger destroys nothing (master prompt 24)")
	var d := _armed_board(7704)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	controller.default_yes = false
	var archfiend: CardInstance = d["archfiend"]
	var fodder: CardInstance = d["fodder"]

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"the opponent's End Phase is reached")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 1, "the controller was asked")
	t.eq(fodder.zone, Enums.Zone.MONSTER_ZONE,
		"said no, so your own monster was NOT destroyed")
	t.eq(archfiend.zone, Enums.Zone.GRAVEYARD, "and it stayed in the Graveyard")


static func _test_no_face_up_monster_to_target(t: TestCase) -> void:
	t.start("an effect that targets with no legal target is not activated at all "
		+ "(master prompt 17)")
	var d := TestFixtures.new_duel(7705, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var controller: ScriptedController = d["p0"]
	controller.default_yes = true
	var archfiend := TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	# A FACE-DOWN monster of yours, and a face-up monster of THEIRS: neither qualifies.
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face Down", 4, 1000, 1000),
		Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"the opponent's End Phase is reached")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 0,
		"the controller is not asked a question with no possible answer")
	t.eq(face_down.zone, Enums.Zone.MONSTER_ZONE, "your face-down monster is untouched")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "and so is theirs")
	t.eq(archfiend.zone, Enums.Zone.GRAVEYARD, "nothing was Special Summoned")


static func _test_and_if_you_do(t: TestCase) -> void:
	t.start("'destroy it, AND IF YOU DO, Special Summon this card' — no destruction, no "
		+ "Special Summon")
	var d := _armed_board(7706)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var archfiend: CardInstance = d["archfiend"]
	var fodder: CardInstance = d["fodder"]

	TestFixtures.give(engine, 0, _ward_def(), Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.is_true(bool(fodder.flags.get("cannot_be_destroyed_by_effect", false)),
		"the target cannot be destroyed by card effects")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"the opponent's End Phase is reached")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 1,
		"the effect was still activated — the protection is discovered at resolution")
	t.eq(fodder.zone, Enums.Zone.MONSTER_ZONE, "the target was not destroyed")
	t.eq(archfiend.zone, Enums.Zone.GRAVEYARD,
		"so the second half did not happen either — the two are not independent")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no Special Summon occurred at all")

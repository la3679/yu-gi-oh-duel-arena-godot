class_name RanryuTests
extends RefCounted

## Per-card suite for `Ranryu`.
##
##   "You can only control 1 'Ranryu'. If you control a Spellcaster monster, you can
##    Special Summon this card (from your hand). If this card is destroyed by battle or
##    card effect and sent to the GY: You can target 1 monster with 1500 ATK/200 DEF in
##    your GY, except 'Ranryu'; Special Summon it."
##
## The third clause is where this card differs from `Inari Fire`, whose wording it
## superficially resembles: it is OPTIONAL, it TARGETS, it accepts BOTH destruction
## reasons, and it revives a different monster rather than itself.

const CARD_UNDER_TEST := "Ranryu"

const PROCEDURE_ID := "ss_if_you_control_a_spellcaster"
const TRIGGER_ID := "on_destroyed_revive_a_1500_200_monster"


static func run() -> TestCase:
	var t := TestCase.new("RanryuTests")
	_test_clause_shape(t)
	_test_the_procedure_and_the_control_limit(t)
	_test_destroyed_by_battle_revives_a_twin(t)
	_test_destroyed_by_card_effect_also_works(t)
	_test_declining(t)
	_test_the_target_filter(t)
	_test_tributed_does_not_fire(t)
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


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses, and the third is optional and targets")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var limit: EffectDef = def.effects[0]
	t.eq(limit.effect_id, SummonRules.CONTROL_LIMIT_EFFECT_ID, "the control limit is real")

	var procedure: EffectDef = def.effects[1]
	t.eq(procedure.effect_type, Enums.EffectType.SUMMON_PROCEDURE, "a summoning procedure")
	t.is_false(procedure.starts_chain, "which starts no Chain")

	var trigger: EffectDef = def.effects[2]
	t.eq(trigger.effect_type, Enums.EffectType.TRIGGER, "and a Trigger Effect")
	t.eq(trigger.optionality, Enums.Optionality.OPTIONAL,
		"'You can' — its controller is asked and may decline")
	t.is_true(trigger.targets, "'You can TARGET' fixes the monster at activation")
	t.eq(trigger.target_count_min, 1, "exactly one target")
	t.eq(trigger.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"it activates from the Graveyard, where the destruction put it")
	t.eq(trigger.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"destruction by battle happens inside the Damage Step, so the timing must be "
		+ "legal there [S1 p.41]")
	t.is_false(trigger.once_per_turn_instance,
		"the official text carries no once-per-turn clause, so none is invented")


# ---------------------------------------------------------------------------
# The procedure and the control limit
# ---------------------------------------------------------------------------

static func _test_the_procedure_and_the_control_limit(t: TestCase) -> void:
	t.start("the procedure needs a face-up Spellcaster, and a second copy may not be "
		+ "Summoned at all")
	var d := _main_phase_duel(7601)
	var engine: DuelEngine = d["engine"]
	var ranryu := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, ranryu.id, PROCEDURE_ID),
		"not offered with no Spellcaster on your side")

	TestFixtures.give_monster_on_field(engine, 0, _card("Fairy Tail - Luna"))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, ranryu.id, PROCEDURE_ID)
	t.not_null(action, "offered once you control a face-up Spellcaster")
	t.is_true(engine.submit_action(action), "and performed")
	TestFixtures.pass_until_open(engine)
	t.eq(ranryu.zone, Enums.Zone.MONSTER_ZONE, "Ranryu is on the field")
	t.eq(ranryu.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"and the Normal Summon is untouched [S1 p.24]")

	var second := TestFixtures.give_to_hand(engine, 0, _def())
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, second.id, PROCEDURE_ID),
		"a second copy's procedure is refused — 'You can only control 1'")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, second.id),
		"and so is a Normal Summon of it")


# ---------------------------------------------------------------------------
# The trigger
# ---------------------------------------------------------------------------

## A board where player 0's Ranryu is on the field with a legal revival target in the GY.
static func _armed_board(seed_value: int, first_player: int = 0) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, first_player)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var controller: ScriptedController = d["p0"]
	controller.default_yes = true
	d["ranryu"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	d["twin"] = TestFixtures.give(engine, 0, _card("Inari Fire"), Enums.Zone.GRAVEYARD)
	return d


static func _test_destroyed_by_battle_revives_a_twin(t: TestCase) -> void:
	t.start("destroyed BY BATTLE, it Special Summons a 1500/200 monster from your GY")
	var d := _armed_board(7602)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var ranryu: CardInstance = d["ranryu"]
	var twin: CardInstance = d["twin"]

	TestFixtures.end_turn(engine)
	var attacker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Big Attacker", 4, 2500, 1000))
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the opponent reaches their Battle Phase")
	t.is_true(TestFixtures.attack(engine, attacker, ranryu), "and runs Ranryu over")
	TestFixtures.pass_until_open(engine)

	t.eq(ranryu.zone, Enums.Zone.GRAVEYARD, "Ranryu was destroyed by battle")
	t.eq(ranryu.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE, "by battle")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 1,
		"its controller was asked exactly once — the effect is optional")
	t.eq(twin.zone, Enums.Zone.MONSTER_ZONE, "and the 1500/200 monster was Summoned")
	t.eq(twin.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.eq(twin.controller_id, 0, "under Ranryu's controller")


static func _test_destroyed_by_card_effect_also_works(t: TestCase) -> void:
	t.start("'destroyed by battle OR CARD EFFECT' — both branches are live")
	var d := _armed_board(7603)
	var engine: DuelEngine = d["engine"]
	var ranryu: CardInstance = d["ranryu"]
	var twin: CardInstance = d["twin"]

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", ranryu, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Ranryu")

	t.eq(ranryu.zone, Enums.Zone.GRAVEYARD, "Ranryu is in the Graveyard")
	t.eq(ranryu.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT, "by a card effect")
	t.eq(twin.zone, Enums.Zone.MONSTER_ZONE, "and the twin was Special Summoned")


static func _test_declining(t: TestCase) -> void:
	t.start("an optional trigger that is declined does nothing at all (master prompt 24)")
	var d := _armed_board(7604)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	controller.default_yes = false
	var ranryu: CardInstance = d["ranryu"]
	var twin: CardInstance = d["twin"]

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", ranryu, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover), "Ranryu is destroyed")

	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 1,
		"the controller was asked")
	t.eq(twin.zone, Enums.Zone.GRAVEYARD, "said no, so nothing was Summoned")
	t.eq(engine.state.player(0).monster_count(), 0, "and your field is empty")


static func _test_the_target_filter(t: TestCase) -> void:
	t.start("'1 monster with 1500 ATK/200 DEF in YOUR GY, EXCEPT \"Ranryu\"' — exact "
		+ "printed stats, own Graveyard, and the name excluded")
	var d := _armed_board(7605)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var ranryu: CardInstance = d["ranryu"]
	var twin: CardInstance = d["twin"]

	var other_twin := TestFixtures.give(engine, 0,
		_card("Nefarious Archfiend Eater of Nefariousness"), Enums.Zone.GRAVEYARD)
	var wrong_stats := TestFixtures.give(engine, 0, _card("Sabersaurus"),
		Enums.Zone.GRAVEYARD)
	var another_ranryu := TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	var theirs := TestFixtures.give(engine, 1, _card("Inari Fire"), Enums.Zone.GRAVEYARD)

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", ranryu, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover), "Ranryu is destroyed")

	var offered: Array = []
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind == Enums.DecisionKind.CHOOSE_TARGETS:
			offered = request.options
	t.eq(offered.size(), 2, "exactly two legal targets")
	t.is_true(offered.has(twin.id), "Inari Fire is 1500/200")
	t.is_true(offered.has(other_twin.id), "so is Nefarious Archfiend")
	t.is_false(offered.has(wrong_stats.id), "a 1900/500 monster is not")
	t.is_false(offered.has(another_ranryu.id),
		"and another copy of Ranryu is excluded BY NAME, not merely this instance")
	t.is_false(offered.has(theirs.id), "'in YOUR GY' — theirs is out of reach")
	t.is_false(offered.has(ranryu.id), "and it does not target itself")


static func _test_tributed_does_not_fire(t: TestCase) -> void:
	t.start("Tributed is neither 'destroyed by battle' nor 'by card effect' [S1 p.53]")
	var d := _armed_board(7606)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var ranryu: CardInstance = d["ranryu"]
	var twin: CardInstance = d["twin"]

	var eater := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Tribute Eater", 6, 2000, 2000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, eater.id)
	t.not_null(action, "a Level 6 monster may be Tribute Summoned over Ranryu")
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [ranryu.id]})),
		"Ranryu is Tributed")
	TestFixtures.pass_until_open(engine)

	t.eq(ranryu.zone, Enums.Zone.GRAVEYARD, "it reached the Graveyard")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO), 0,
		"but its controller was never asked a question with no basis")
	t.eq(twin.zone, Enums.Zone.GRAVEYARD, "and nothing was Special Summoned")

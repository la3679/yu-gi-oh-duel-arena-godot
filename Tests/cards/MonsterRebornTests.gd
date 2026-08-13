class_name MonsterRebornTests
extends RefCounted

## Per-card suite for `Monster Reborn` — "Target 1 monster in either GY;
## Special Summon it."
##
## The clause is one sentence and four separate rules, so each is exercised positively
## and negatively: it TARGETS (fixed at activation), it reaches EITHER Graveyard, it
## Special Summons to YOUR side while the OWNER is unchanged, and it names no position
## so the summoning player chooses.

const CARD_UNDER_TEST := "Monster Reborn"


static func run() -> TestCase:
	var t := TestCase.new("MonsterRebornTests")
	_test_clause_shape(t)
	_test_revives_from_your_own_graveyard(t)
	_test_the_player_chooses_the_position(t)
	_test_revives_from_the_opponents_graveyard(t)
	_test_a_trap_in_the_graveyard_is_not_a_target(t)
	_test_not_offered_with_an_empty_graveyard(t)
	_test_not_offered_with_a_full_monster_zone(t)
	_test_a_target_that_left_the_graveyard(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _reborn_def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


## A duel sitting in Main Phase 1 of player 0's turn.
static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Put `def` straight into `pid`'s Graveyard so it is a legal revival target.
static func _into_graveyard(engine: DuelEngine, pid: int, def: CardDef) -> CardInstance:
	return TestFixtures.give(engine, pid, def, Enums.Zone.GRAVEYARD)


## Activate Monster Reborn from `pid`'s hand at `target`. Returns whether it was accepted.
static func _activate(engine: DuelEngine, pid: int, reborn: CardInstance,
		target: CardInstance) -> bool:
	var action = TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id)
	if action == null:
		return false
	return engine.submit_action(action.with_choices({"target_ids": [target.id]}))


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("the clause is a Spell Speed 1 card activation that targets exactly 1 monster")
	var def := _reborn_def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 1, "one EffectDef per official clause, and this card has one")
	var effect: EffectDef = def.effects[0]

	t.eq(effect.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"activating the Spell card itself is the effect")
	t.eq(effect.spell_speed, Enums.SpellSpeed.SS1, "a Normal Spell is Spell Speed 1")
	t.is_true(effect.targets,
		"the official text says 'Target', so the monster is fixed at activation "
		+ "(RULES_SPEC.md 10)")
	t.eq(effect.target_count_min, 1, "exactly one target minimum")
	t.eq(effect.target_count_max, 1, "and exactly one maximum")
	t.eq(effect.activation_locations,
		[Enums.ActivationLocation.HAND, Enums.ActivationLocation.FIELD_FACE_DOWN],
		"from the hand or from a Set copy — never from a face-up field position")
	t.is_false(effect.once_per_turn_named_activation,
		"the official text carries no once-per-turn clause, so none is invented")


# ---------------------------------------------------------------------------
# Positively
# ---------------------------------------------------------------------------

static func _test_revives_from_your_own_graveyard(t: TestCase) -> void:
	t.start("a monster in your own Graveyard is Special Summoned to your field")
	var d := _main_phase_duel(9201)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	var sleeper := _into_graveyard(engine, 0, _card("Luster Dragon"))

	t.is_true(_activate(engine, 0, reborn, sleeper), "Monster Reborn is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(sleeper.zone, Enums.Zone.MONSTER_ZONE, "the target left the Graveyard")
	t.eq(sleeper.controller_id, 0, "and is controlled by the activating player")
	t.eq(sleeper.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.is_true(sleeper.properly_special_summoned, "and it was properly Special Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon succeeded")
	t.eq(reborn.zone, Enums.Zone.GRAVEYARD,
		"and the Normal Spell itself is in the Graveyard after resolving [S1 p.28]")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"a Special Summon does not spend the Normal Summon [S1 p.24]")


static func _test_the_player_chooses_the_position(t: TestCase) -> void:
	t.start("no position is named, so the summoning player picks face-up Defense if "
		+ "they want it")
	var d := _main_phase_duel(9202)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	controller.queue_for(Enums.DecisionKind.CHOOSE_POSITION,
		[Enums.Position.FACE_UP_DEFENSE])

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	var sleeper := _into_graveyard(engine, 0, _card("Rabidragon"))

	t.is_true(_activate(engine, 0, reborn, sleeper), "Monster Reborn is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(sleeper.position, Enums.Position.FACE_UP_DEFENSE,
		"it arrived in the position its controller chose")
	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_POSITION), 1,
		"and the choice was put to them exactly once")

	var offered_face_down := false
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind != Enums.DecisionKind.CHOOSE_POSITION:
			continue
		if request.options.has(Enums.Position.FACE_DOWN_DEFENSE):
			offered_face_down = true
	t.is_false(offered_face_down,
		"face-down was never offered: a Special Summon is face-up unless the card says "
		+ "otherwise (RULES_SPEC.md 5.5)")


static func _test_revives_from_the_opponents_graveyard(t: TestCase) -> void:
	t.start("'either GY' includes the opponent's, and the OWNER is unchanged [S1 p.52]")
	var d := _main_phase_duel(9203)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	var stolen := _into_graveyard(engine, 1, _card("Sabersaurus"))
	t.eq(stolen.owner_id, 1, "the target starts out owned by the opponent")

	t.is_true(_activate(engine, 0, reborn, stolen),
		"a monster in the opponent's Graveyard is a legal target")
	TestFixtures.pass_until_open(engine)

	t.eq(stolen.zone, Enums.Zone.MONSTER_ZONE, "it is on the field")
	t.eq(stolen.controller_id, 0, "controlled by the activating player")
	t.eq(stolen.owner_id, 1, "but still OWNED by the opponent")
	t.eq(engine.state.player(0).monster_count(), 1, "it occupies one of your zones")
	t.eq(engine.state.player(1).monster_count(), 0, "and none of theirs")

	# A card returns to its OWNER's Graveyard, not its controller's. [S1 p.52]
	engine.state.move_card(stolen, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	TestFixtures.pass_until_open(engine)
	t.is_true(engine.state.player(1).graveyard.has(stolen),
		"when it later leaves the field it goes to its OWNER's Graveyard")
	t.is_false(engine.state.player(0).graveyard.has(stolen),
		"and not to the Graveyard of the player who controlled it")


# ---------------------------------------------------------------------------
# Negatively
# ---------------------------------------------------------------------------

static func _test_a_trap_in_the_graveyard_is_not_a_target(t: TestCase) -> void:
	t.start("only a MONSTER in the Graveyard is a legal target")
	var d := _main_phase_duel(9204)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	var trap := _into_graveyard(engine, 0, _card("Call of the Haunted"))
	var monster := _into_graveyard(engine, 0, _card("Luster Dragon"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id)
	t.not_null(action, "Monster Reborn is offered")
	t.is_true(action.target_candidates.has(monster.id),
		"the monster in the Graveyard is offered as a target")
	t.is_false(action.target_candidates.has(trap.id),
		"the Trap Card in the same Graveyard is not")
	t.eq(action.target_candidates.size(), 1, "and it is the only candidate")

	var forged = action.with_choices({"target_ids": [trap.id]})
	t.is_false(engine.submit_action(forged),
		"a hand-built activation targeting the Trap is rejected by the engine")


static func _test_not_offered_with_an_empty_graveyard(t: TestCase) -> void:
	t.start("with no monster in either Graveyard the card cannot be activated at all")
	var d := _main_phase_duel(9205)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	t.eq(engine.state.player(0).graveyard.size(), 0, "your Graveyard is empty")
	t.eq(engine.state.player(1).graveyard.size(), 0, "so is the opponent's")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id),
		"an effect that targets and has no legal target cannot be activated "
		+ "(master prompt 17)")
	t.is_false(engine.submit_action(
		DuelAction.make(Enums.ActionKind.ACTIVATE_CARD, 0, reborn.id,
			"revive_target_in_either_gy")),
		"and a hand-built activation with no target is rejected")


static func _test_not_offered_with_a_full_monster_zone(t: TestCase) -> void:
	t.start("with no free Monster Zone there is nowhere to Summon, so it is not offered")
	var d := _main_phase_duel(9206)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	_into_graveyard(engine, 0, _card("Luster Dragon"))
	while engine.state.player(0).has_free_monster_zone():
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Bystander %d" % engine.state.player(0).monster_count(),
				4, 800, 800))
	t.eq(engine.state.player(0).monster_count(), 5, "all five Monster Zones are occupied")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id),
		"Monster Reborn is not offered — nothing here frees a zone, unlike Kaibaman")


static func _test_a_target_that_left_the_graveyard(t: TestCase) -> void:
	t.start("a target that left the Graveyard before resolution is no longer summoned")
	var d := _main_phase_duel(9207)
	var engine: DuelEngine = d["engine"]

	var reborn := TestFixtures.give_to_hand(engine, 0, _reborn_def())
	var sleeper := _into_graveyard(engine, 0, _card("Luster Dragon"))

	# A synthetic Spell Speed 2 Trap for the opponent that banishes the target. Building
	# the interference from a test card rather than a real one keeps this suite about
	# Monster Reborn: what is being proved is that a resolving effect re-checks its own
	# target, not what any other card does.
	var thief_def := _banisher_def(sleeper)
	var thief := TestFixtures.give_set_spell_trap(engine, 1, thief_def, 0)

	t.is_true(_activate(engine, 0, reborn, sleeper),
		"Monster Reborn is activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent may respond with a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response), "and does so as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(sleeper.zone, Enums.Zone.BANISHED,
		"Chain Link 2 resolved first and removed the target [S1 p.46-47]")
	t.eq(engine.state.player(0).monster_count(), 0,
		"so Monster Reborn Special Summoned nothing")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no Special Summon occurred at all")
	t.eq(reborn.zone, Enums.Zone.GRAVEYARD,
		"the Spell still resolved and still went to the Graveyard")


static func _banisher_def(victim: CardInstance) -> CardDef:
	var def := TestFixtures.trap("Test Banisher")
	var effect := EffectDef.new("banish_the_victim",
		"Test card: banish one specific card.")
	effect.of_type(Enums.EffectType.CARD_ACTIVATION)
	effect.spell_speed = Enums.SpellSpeed.SS2
	effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	effect.resolve = func(ctx: EffectContext) -> void:
		ctx.state.move_card(victim, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED,
			{"source_id": ctx.source.id})
	return TestFixtures.with_effect(def, effect)

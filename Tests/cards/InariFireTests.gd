class_name InariFireTests
extends RefCounted

## Per-card suite for `Inari Fire`. Research/CARD_RULINGS.md R18.
##
##   "You can only control 1 'Inari Fire'. If you control a Spellcaster monster, you can
##    Special Summon this card (from your hand). Once per turn, during your next Standby
##    Phase after this face-up card on the field was destroyed by card effect and sent to
##    the GY: Special Summon it from your GY."
##
## The third clause has four independent requirements and each one is tested as a way for
## the effect NOT to happen — a delayed trigger that fires when it should not is worse
## than one that never fires, because it is invisible in a passing positive test.

const CARD_UNDER_TEST := "Inari Fire"

const PROCEDURE_ID := "ss_if_you_control_a_spellcaster"
const REVIVAL_ID := "standby_phase_self_revival"


static func run() -> TestCase:
	var t := TestCase.new("InariFireTests")
	_test_clause_shape(t)
	_test_the_procedure_needs_a_face_up_spellcaster(t)
	_test_you_can_only_control_one(t)
	_test_the_control_limit_applies_to_every_route(t)
	_test_the_standby_revival(t)
	_test_destroyed_by_battle_does_not_revive(t)
	_test_tributed_does_not_revive(t)
	_test_only_the_next_standby_phase(t)
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


static func _procedure_action(engine: DuelEngine, pid: int, card: CardInstance):
	return TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, card.id, PROCEDURE_ID)


## Advance to the Standby Phase of the turn after next, i.e. this player's next turn.
static func _to_own_next_standby(engine: DuelEngine) -> bool:
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	return TestFixtures.advance_to_phase(engine, Enums.Phase.STANDBY)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses: a control limit, a summoning procedure and a delayed "
		+ "Trigger Effect")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var limit: EffectDef = def.effects[0]
	t.eq(limit.effect_id, SummonRules.CONTROL_LIMIT_EFFECT_ID,
		"the control limit uses the id the rules layer looks for")
	t.eq(limit.effect_type, Enums.EffectType.CONTINUOUS,
		"it is continuous — it is never activated")
	t.is_false(limit.starts_chain, "and starts no Chain")
	t.is_true(limit.condition.is_valid(),
		"a rules query has to actually answer something")

	var procedure: EffectDef = def.effects[1]
	t.eq(procedure.effect_type, Enums.EffectType.SUMMON_PROCEDURE,
		"'you can Special Summon this card' is a procedure [S1 p.53]")
	t.eq(procedure.activation_locations, [Enums.ActivationLocation.HAND],
		"'(from your hand)'")

	var revival: EffectDef = def.effects[2]
	t.eq(revival.effect_type, Enums.EffectType.TRIGGER, "the revival is a Trigger Effect")
	t.eq(revival.optionality, Enums.Optionality.MANDATORY,
		"there is no 'You can', so it is mandatory")
	t.is_true(revival.once_per_turn_instance, "'Once per turn'")
	t.eq(revival.legal_phases, [Enums.Phase.STANDBY], "'during your … Standby Phase'")
	t.eq(revival.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"'from your GY' — it activates while it is in the Graveyard")
	t.eq(revival.ruling_ref, "R18", "and it is traced to the recorded ruling")


# ---------------------------------------------------------------------------
# The procedure and the control limit
# ---------------------------------------------------------------------------

static func _test_the_procedure_needs_a_face_up_spellcaster(t: TestCase) -> void:
	t.start("'If you control a Spellcaster monster' — face-up, yours, and a Spellcaster")
	var d := _main_phase_duel(7501)
	var engine: DuelEngine = d["engine"]
	var inari := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_null(_procedure_action(engine, 0, inari),
		"with an empty board it is not offered")

	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		_card("Aussa the Earth Charmer"))
	t.is_null(_procedure_action(engine, 0, inari),
		"a Spellcaster the OPPONENT controls does not count")
	engine.state.move_card(theirs, Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE)

	var not_a_caster := TestFixtures.give_monster_on_field(engine, 0,
		_card("Sabersaurus"))
	t.is_null(_procedure_action(engine, 0, inari),
		"and neither does a monster of another race")
	engine.state.move_card(not_a_caster, Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE)

	var caster := TestFixtures.give_monster_on_field(engine, 0,
		_card("Aussa the Earth Charmer"), Enums.Position.FACE_DOWN_DEFENSE)
	t.is_null(_procedure_action(engine, 0, inari),
		"a FACE-DOWN Spellcaster is not something either player may act on")

	engine.state.set_battle_position(caster, Enums.Position.FACE_UP_ATTACK, true)
	t.not_null(_procedure_action(engine, 0, inari),
		"turning the very same monster face-up enables it")

	t.is_true(engine.submit_action(_procedure_action(engine, 0, inari)),
		"the procedure is performed")
	TestFixtures.pass_until_open(engine)
	t.eq(inari.zone, Enums.Zone.MONSTER_ZONE, "and Inari Fire reaches the field")
	t.eq(inari.summoned_by_procedure_id, PROCEDURE_ID, "by its own procedure")


static func _test_you_can_only_control_one(t: TestCase) -> void:
	t.start("'You can only control 1 \"Inari Fire\"' blocks a second copy's procedure")
	var d := _main_phase_duel(7502)
	var engine: DuelEngine = d["engine"]

	TestFixtures.give_monster_on_field(engine, 0, _card("Aussa the Earth Charmer"))
	var first := TestFixtures.give_monster_on_field(engine, 0, _def())
	var second := TestFixtures.give_to_hand(engine, 0, _def())
	t.ne(first.id, second.id, "these are two distinct copies of the same card")

	t.is_null(_procedure_action(engine, 0, second),
		"the second copy's procedure is not offered while you control the first")
	t.is_false(engine.submit_action(DuelAction.make(
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, 0, second.id, PROCEDURE_ID)),
		"and a hand-built one is rejected")
	t.eq(second.zone, Enums.Zone.HAND, "so it never left the hand")

	engine.state.move_card(first, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.not_null(_procedure_action(engine, 0, second),
		"once you no longer control a copy, the second one may be Summoned")

	# And a copy the OPPONENT controls is not one you control [S1 p.53].
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _def())
	t.eq(theirs.controller_id, 1, "the opponent controls a copy")
	t.not_null(_procedure_action(engine, 0, second),
		"which does not restrict you at all")


static func _test_the_control_limit_applies_to_every_route(t: TestCase) -> void:
	t.start("the limit is on what you CONTROL, so it blocks a Normal Summon and a "
		+ "revival too — not only this card's own procedure")
	var d := _main_phase_duel(7503)
	var engine: DuelEngine = d["engine"]

	TestFixtures.give_monster_on_field(engine, 0, _def())
	var in_hand := TestFixtures.give_to_hand(engine, 0, _def())
	var in_gy := TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, in_hand.id),
		"a second copy cannot be Normal Summoned")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SET, in_hand.id),
		"and cannot be Set either — a Set card is still a card you control")

	# Monster Reborn can still be ACTIVATED (it targets any monster in either GY), but the
	# Special Summon itself is what the limit refuses.
	t.is_true(TestFixtures.activate_card(engine, 0, reborn, [in_gy.id]),
		"Monster Reborn is activated targeting the copy in the Graveyard")
	t.eq(in_gy.zone, Enums.Zone.GRAVEYARD,
		"but the Special Summon does not happen, so the copy stays in the Graveyard")
	t.eq(engine.state.player(0).monster_count(), 1, "you still control exactly one copy")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"and no Special Summon succeeded")


# ---------------------------------------------------------------------------
# The delayed revival
# ---------------------------------------------------------------------------

static func _test_the_standby_revival(t: TestCase) -> void:
	t.start("destroyed by a card effect while face-up on the field, it Special Summons "
		+ "itself during your NEXT Standby Phase")
	var d := _main_phase_duel(7504)
	var engine: DuelEngine = d["engine"]

	var inari := TestFixtures.give_monster_on_field(engine, 0, _def())
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", inari, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys it")

	t.eq(inari.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(inari.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"the move was recorded as a card-effect destruction")
	t.is_true(inari.last_move_was_face_up,
		"and as having happened to a FACE-UP card — recorded after on_leave_field(), "
		+ "which is the only reason it survived the move at all")
	t.eq(inari.last_move_from_zone, Enums.Zone.MONSTER_ZONE, "from the field")

	TestFixtures.end_turn(engine)
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.STANDBY),
		"the OPPONENT's Standby Phase is reached first")
	t.eq(inari.zone, Enums.Zone.GRAVEYARD,
		"'YOUR next Standby Phase' — the opponent's does not count")

	TestFixtures.end_turn(engine)
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.STANDBY),
		"then your own Standby Phase")
	t.eq(inari.zone, Enums.Zone.MONSTER_ZONE, "and it Special Summons itself")
	t.eq(inari.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.eq(inari.controller_id, 0, "under its owner's control")
	t.eq(inari.summoned_by_procedure_id, "",
		"this is the Trigger Effect, not the summoning procedure")


static func _test_destroyed_by_battle_does_not_revive(t: TestCase) -> void:
	t.start("'destroyed by CARD EFFECT' — destruction by BATTLE is a different thing "
		+ "[S1 p.52-53]")
	# Player 1 goes first so player 0 can attack on turn 2.
	var d := TestFixtures.new_duel(7505, 1)
	var engine: DuelEngine = d["engine"]
	var inari := TestFixtures.give_monster_on_field(engine, 1, _def())
	TestFixtures.end_turn(engine)
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2500, 1000))

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, attacker, inari), "and Inari Fire is attacked")
	TestFixtures.pass_until_open(engine)
	t.eq(inari.zone, Enums.Zone.GRAVEYARD, "it was destroyed by battle")
	t.eq(inari.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE,
		"recorded with the battle reason")

	TestFixtures.end_turn(engine)
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.STANDBY),
		"its controller's next Standby Phase arrives")
	t.eq(inari.zone, Enums.Zone.GRAVEYARD, "and it is not Special Summoned")


static func _test_tributed_does_not_revive(t: TestCase) -> void:
	t.start("a Tribute is not a destruction, so the clause does not apply [S1 p.53]")
	var d := _main_phase_duel(7506)
	var engine: DuelEngine = d["engine"]

	var inari := TestFixtures.give_monster_on_field(engine, 0, _def())
	var eater := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Tribute Eater", 6, 2000, 2000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, eater.id)
	t.not_null(action, "a Level 6 monster may be Tribute Summoned over it")
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [inari.id]})),
		"Tributing Inari Fire")
	TestFixtures.pass_until_open(engine)

	t.eq(inari.zone, Enums.Zone.GRAVEYARD, "it reached the Graveyard")
	t.eq(inari.last_move_reason, Enums.MoveReason.TRIBUTED, "as a Tribute")

	t.is_true(_to_own_next_standby(engine), "your next Standby Phase arrives")
	t.eq(inari.zone, Enums.Zone.GRAVEYARD, "and nothing was Special Summoned")


static func _test_only_the_next_standby_phase(t: TestCase) -> void:
	t.start("'your NEXT Standby Phase' is one specific Standby Phase — a later one is "
		+ "too late")
	var d := _main_phase_duel(7507)
	var engine: DuelEngine = d["engine"]

	var inari := TestFixtures.give_monster_on_field(engine, 0, _def())
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", inari, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover), "a card effect destroys it")

	# Fill every Monster Zone so the revival cannot happen on the turn it should.
	while engine.state.player(0).has_free_monster_zone():
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Blocker %d" % engine.state.player(0).monster_count(),
				4, 800, 800))
	t.is_true(_to_own_next_standby(engine), "your next Standby Phase arrives")
	t.eq(inari.zone, Enums.Zone.GRAVEYARD,
		"with no free Monster Zone there is nowhere to Summon it")

	# Free the board again. The window has passed, so it must not fire later.
	for entry in engine.state.player(0).monsters():
		var blocker: CardInstance = entry
		engine.state.move_card(blocker, Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE)
	t.is_true(engine.state.player(0).has_free_monster_zone(), "the board is clear again")
	t.is_true(_to_own_next_standby(engine), "and a LATER Standby Phase of yours arrives")
	t.eq(inari.zone, Enums.Zone.GRAVEYARD,
		"it still does not revive — the clause names one Standby Phase, not any of them")

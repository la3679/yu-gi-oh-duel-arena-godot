class_name BirthrightTests
extends RefCounted

## Per-card suite for `Birthright` — the first Continuous Trap in the library.
##
##   "Activate this card by targeting 1 Normal Monster in your GY; Special Summon that
##    target in Attack Position. When this card leaves the field, destroy that monster.
##    When that monster leaves the field, destroy this card."
##
## Three clauses, and the third is the one that separates this card from
## `Call of the Haunted`. Both directions of the mutual link are exercised here, and the
## negative that matters most is the one `CallOfTheHauntedTests` gets the opposite answer
## for: a revived monster that is BANISHED rather than destroyed still destroys this card.

const CARD_UNDER_TEST := "Birthright"


static func run() -> TestCase:
	var t := TestCase.new("BirthrightTests")
	_test_clause_shape(t)
	_test_revives_a_normal_monster_in_attack_position(t)
	_test_the_target_filter(t)
	_test_only_your_own_graveyard(t)
	_test_cannot_be_activated_the_turn_it_was_set(t)
	_test_not_offered_with_a_full_monster_zone(t)
	_test_this_card_leaving_destroys_the_monster(t)
	_test_the_monster_leaving_the_field_destroys_this_card(t)
	_test_the_monster_being_destroyed_destroys_this_card(t)
	_test_a_failed_revival_links_nothing(t)
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


## A board where Birthright has already revived `Sabersaurus` for player 0.
## Returns the duel plus "trap" and "monster".
static func _revived_board(seed_value: int) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	TestFixtures.activate_card(engine, 0, trap, [monster.id])
	d["trap"] = trap
	d["monster"] = monster
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses, three EffectDefs, with the right kinds")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var activation: EffectDef = def.effects[0]
	t.eq(activation.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"the first clause is the activation of the Trap itself")
	t.eq(activation.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2 [S1 p.44]")
	t.is_true(activation.targets, "'by TARGETING' fixes the monster at activation")
	t.eq(activation.target_count_min, 1, "exactly one target")
	t.eq(activation.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Trap is activated from a Set card on the field, never from the hand")

	var destroy_monster: EffectDef = def.effects[1]
	t.eq(destroy_monster.effect_type, Enums.EffectType.TRIGGER,
		"'When this card leaves the field' is a Trigger Effect")
	t.eq(destroy_monster.optionality, Enums.Optionality.MANDATORY,
		"the text says 'destroy', not 'you can destroy'")
	t.is_true(destroy_monster.activation_locations.has(Enums.ActivationLocation.GRAVEYARD),
		"it activates from wherever the card went, most often the Graveyard")

	var destroy_self: EffectDef = def.effects[2]
	t.eq(destroy_self.effect_type, Enums.EffectType.TRIGGER,
		"and so is 'When that monster leaves the field'")
	t.eq(destroy_self.optionality, Enums.Optionality.MANDATORY, "also mandatory")
	t.eq(destroy_self.trigger_events, [GameEvent.Kind.CARD_MOVED],
		"keyed on MOVEMENT — 'leaves the field' — not on destruction, which is what "
		+ "separates this card from Call of the Haunted")
	t.eq(destroy_self.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"and it can only fire while this card is still face-up on the field")


# ---------------------------------------------------------------------------
# The revival
# ---------------------------------------------------------------------------

static func _test_revives_a_normal_monster_in_attack_position(t: TestCase) -> void:
	t.start("the target is Special Summoned in Attack Position, and nobody is asked which "
		+ "position — the card names it")
	var d := _revived_board(7201)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "the target left the Graveyard")
	t.eq(monster.position, Enums.Position.FACE_UP_ATTACK, "in face-up Attack Position")
	t.eq(monster.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.is_true(monster.properly_special_summoned, "and properly so")
	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_POSITION), 0,
		"the position is FIXED by the card text, so no choice is offered "
		+ "(unlike Monster Reborn)")
	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"a Continuous Trap stays on the field after resolving [S1 p.29-30]")
	t.is_true(trap.is_face_up(), "face-up")
	t.eq(engine.state.recall(trap, EffectPrimitives.REVIVED_MONSTER_KEY, -1), monster.id,
		"and it remembers which monster it Summoned")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"a Special Summon does not spend the Normal Summon [S1 p.24]")


static func _test_the_target_filter(t: TestCase) -> void:
	t.start("'1 NORMAL Monster' excludes Effect Monsters — this is the targeting "
		+ "difference from Call of the Haunted")
	var d := _main_phase_duel(7202)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var vanilla := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var effect_monster := TestFixtures.give(engine, 0, _card("Mirage Dragon"),
		Enums.Zone.GRAVEYARD)
	var spell := TestFixtures.give(engine, 0, _card("Monster Reborn"), Enums.Zone.GRAVEYARD)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id)
	t.not_null(action, "Birthright is offered")
	t.is_true(action.target_candidates.has(vanilla.id),
		"the Normal Monster in your Graveyard is a candidate")
	t.is_false(action.target_candidates.has(effect_monster.id),
		"a Dragon EFFECT Monster in the same Graveyard is not")
	t.is_false(action.target_candidates.has(spell.id), "and neither is a Spell Card")
	t.eq(action.target_candidates.size(), 1, "so there is exactly one candidate")

	t.is_false(engine.submit_action(
		action.with_choices({"target_ids": [effect_monster.id]})),
		"a hand-built activation targeting the Effect Monster is rejected")


static func _test_only_your_own_graveyard(t: TestCase) -> void:
	t.start("'in YOUR GY' — a Normal Monster in the opponent's Graveyard does not enable it")
	var d := _main_phase_duel(7203)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.give(engine, 1, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"an effect that targets with no legal target cannot be activated "
		+ "(master prompt 17)")

	# The positive control: the same card in YOUR Graveyard does enable it.
	TestFixtures.give(engine, 0, _card("Zure, Knight of Dark World"),
		Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"and one in your own Graveyard does — so it was the ownership that blocked it")


static func _test_cannot_be_activated_the_turn_it_was_set(t: TestCase) -> void:
	t.start("'You cannot activate a Trap in the same turn that you Set it' [S1 p.30]")
	var d := _main_phase_duel(7204)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(),
		engine.state.turn_number)
	TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"not offered on the turn it was Set")
	trap.turn_set = engine.state.turn_number - 1
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"and offered once that turn has passed")


static func _test_not_offered_with_a_full_monster_zone(t: TestCase) -> void:
	t.start("with no free Monster Zone there is nowhere to Summon, so it is not offered")
	var d := _main_phase_duel(7205)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	while engine.state.player(0).has_free_monster_zone():
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Bystander %d" % engine.state.player(0).monster_count(),
				4, 800, 800))
	t.eq(engine.state.player(0).monster_count(), 5, "all five Monster Zones are occupied")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"Birthright is not offered — nothing here frees a zone")


# ---------------------------------------------------------------------------
# The mutual link
# ---------------------------------------------------------------------------

static func _test_this_card_leaving_destroys_the_monster(t: TestCase) -> void:
	t.start("'When this card leaves the field, destroy that monster' — and the monster's "
		+ "destruction does not then bounce back at an already-departed Trap")
	var d := _revived_board(7206)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", trap, "destroy"), 0)
	var mark := engine.state.events.size()
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Birthright")

	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "Birthright left the field")
	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "and the monster it Summoned was destroyed")
	var destroyed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark)
	var monster_destroyed := false
	for entry in destroyed:
		var ev: GameEvent = entry
		if int(ev.data.get("card_id", -1)) == monster.id:
			monster_destroyed = true
			t.eq(ev.data.get("reason", null), Enums.MoveReason.DESTROYED_BY_EFFECT,
				"by a card effect — Birthright's own")
	t.is_true(monster_destroyed, "a CARD_DESTROYED event names the revived monster")
	t.eq(engine.state.recall(trap, EffectPrimitives.REVIVED_MONSTER_KEY, -1), -1,
		"and the link has been cleared, so nothing can fire off it twice")


static func _test_the_monster_leaving_the_field_destroys_this_card(t: TestCase) -> void:
	t.start("'When that monster LEAVES THE FIELD, destroy this card' — being BANISHED "
		+ "counts, which is exactly where Call of the Haunted disagrees")
	var d := _revived_board(7207)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	var banisher := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Banisher", monster, "banish"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, banisher),
		"a card effect banishes the revived monster")

	t.eq(monster.zone, Enums.Zone.BANISHED, "the monster is banished")
	t.is_false(Enums.is_destruction(Enums.MoveReason.BANISHED),
		"and being banished is NOT a destruction [S1 p.52-53]")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD,
		"Birthright still destroys itself, because its clause says 'leaves the field'")
	t.eq(engine.state.recall(trap, EffectPrimitives.REVIVED_MONSTER_KEY, -1), -1,
		"the link is cleared")


static func _test_the_monster_being_destroyed_destroys_this_card(t: TestCase) -> void:
	t.start("destruction is one way of leaving the field, so it triggers the same clause")
	var d := _revived_board(7208)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", monster, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys the revived monster")

	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "the monster is in the Graveyard")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "and Birthright destroyed itself")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon happened in the whole duel — nothing looped")


static func _test_a_failed_revival_links_nothing(t: TestCase) -> void:
	t.start("if the target is gone by resolution nothing is Summoned, nothing is linked, "
		+ "and the Continuous Trap simply sits there")
	var d := _main_phase_duel(7209)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var thief := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Banisher", monster, "banish"), 0)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id)
	t.not_null(action, "Birthright is offered")
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [monster.id]})),
		"and activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent chains a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response), "as Chain Link 2, which resolves first")
	TestFixtures.pass_until_open(engine)

	t.eq(monster.zone, Enums.Zone.BANISHED, "the target was removed before resolution")
	t.eq(engine.state.player(0).monster_count(), 0, "so nothing was Special Summoned")
	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Continuous Trap still resolved and stays on the field")
	t.eq(engine.state.recall(trap, EffectPrimitives.REVIVED_MONSTER_KEY, -1), -1,
		"but it is linked to nothing")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"and no Special Summon ever occurred")

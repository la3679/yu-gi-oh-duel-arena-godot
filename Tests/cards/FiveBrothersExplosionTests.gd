class_name FiveBrothersExplosionTests
extends RefCounted

## Per-card suite for `Five Brothers Explosion` — Continuous Trap.
##
##   "When this card is activated: Gain 500 LP for each Continuous Spell/Trap Card you
##    control. If this face-up card you control is sent to your Graveyard by your
##    opponent's card effect: Inflict 500 damage to your opponent for each Continuous
##    Spell/Trap Card in your Graveyard."
##
## Research/CARD_RULINGS.md R16. The second clause is three independent requirements and
## each is tested against the outcome of failing exactly one of them:
##   * it must have been FACE-UP ON THE FIELD;
##   * it must have been SENT TO THE GRAVEYARD (not banished);
##   * it must have been BY THE OPPONENT'S CARD EFFECT (not battle, not your own effect).

const CARD_UNDER_TEST := "Five Brothers Explosion"


static func run() -> TestCase:
	var t := TestCase.new("FiveBrothersExplosionTests")
	_test_clause_shape(t)
	_test_it_counts_itself(t)
	_test_it_counts_every_continuous_card_you_control(t)
	_test_a_face_down_set_card_is_not_counted(t)
	_test_the_opponents_effect_burns(t)
	_test_your_own_effect_does_not(t)
	_test_banished_does_not(t)
	_test_the_graveyard_count(t)
	_test_effect_damage_can_end_the_duel(t)
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
	t.start("two printed clauses, two EffectDefs — this card's activation DOES have a "
		+ "printed effect, unlike the pool's other Continuous Traps")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.CONTINUOUS_TRAP, "a Continuous Trap")
	t.eq(def.effects.size(), 2, "the LP gain and the burn")

	var gain: EffectDef = def.effects[0]
	t.eq(gain.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"'When this card is activated' IS the card's activation")
	t.eq(gain.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2")
	t.is_false(gain.targets, "it targets nothing")
	t.eq(gain.ruling_ref, "R16", "traced to the recorded ruling")

	var burn: EffectDef = def.effects[1]
	t.eq(burn.effect_type, Enums.EffectType.TRIGGER, "the second clause triggers")
	t.eq(burn.optionality, Enums.Optionality.MANDATORY,
		"no 'You can', so it is MANDATORY and its controller is never asked")
	t.eq(burn.trigger_events, [GameEvent.Kind.CARD_SENT_TO_GY],
		"keyed on being SENT TO THE GRAVEYARD")
	t.eq(burn.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"activated from the Graveyard it has just reached")
	t.eq(burn.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"an opponent's effect can send it there during the Damage Step [S1 p.41]")
	t.is_false(burn.targets, "and it targets nothing")


# ---------------------------------------------------------------------------
# "for each Continuous Spell/Trap Card you control"
# ---------------------------------------------------------------------------

static func _test_it_counts_itself(t: TestCase) -> void:
	t.start("activating it places it face-up on the field, so it counts ITSELF: 500 LP "
		+ "even with nothing else out")
	var d := _main_phase_duel(9301)
	var engine: DuelEngine = d["engine"]
	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	t.eq(engine.state.player(0).life_points, 8000, "starting LP")
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "it is activated")

	t.eq(engine.state.player(0).life_points, 8500,
		"500 LP for the one Continuous Trap you control — itself [S1 p.28-30]")
	t.eq(explosion.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"and it stays face-up on the field")
	t.eq(engine.state.player(1).life_points, 8000, "the opponent's LP is untouched")


static func _test_it_counts_every_continuous_card_you_control(t: TestCase) -> void:
	t.start("a Continuous Spell and a Continuous Trap both count; a Normal Trap and the "
		+ "opponent's Continuous Trap do not")
	var d := _main_phase_duel(9302)
	var engine: DuelEngine = d["engine"]

	# Two other face-up Continuous cards of your own.
	var castle := TestFixtures.give_set_spell_trap(engine, 0,
		_card("Castle of Dragon Souls"), 0)
	TestFixtures.activate_card(engine, 0, castle)
	var balloons := TestFixtures.give_to_hand(engine, 0, _card("Wonder Balloons"))
	TestFixtures.activate_card(engine, 0, balloons)
	t.is_true(castle.is_face_up(), "the Continuous Trap is face-up")
	t.is_true(balloons.is_face_up(), "and so is the Continuous Spell")

	# Cards that must NOT count.
	var normal_trap := TestFixtures.give_set_spell_trap(engine, 0,
		_card("Gagagashield"), 0)
	var theirs := TestFixtures.give_set_spell_trap(engine, 1, _card("Birthright"), 0)
	t.is_true(normal_trap.is_face_down(), "the Normal Trap is Set")
	t.is_true(theirs.is_face_down(), "and so is the opponent's Continuous Trap")

	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "Five Brothers is activated")

	t.eq(engine.state.player(0).life_points, 8000 + 1500,
		"3 x 500: Castle, Wonder Balloons and Five Brothers itself")


static func _test_a_face_down_set_card_is_not_counted(t: TestCase) -> void:
	t.start("a SET Continuous Trap is not counted — a face-down card's specific subtype is "
		+ "not a property either player may act on (CARD_RULINGS.md R16)")
	var d := _main_phase_duel(9303)
	var engine: DuelEngine = d["engine"]

	var hidden := TestFixtures.give_set_spell_trap(engine, 0, _card("Birthright"), 0)
	t.is_true(hidden.is_face_down(), "your other Continuous Trap is face-down")
	t.eq(hidden.definition.st_kind, Enums.STKind.CONTINUOUS_TRAP,
		"and it genuinely is a Continuous Trap by printed type")

	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "Five Brothers is activated")
	t.eq(engine.state.player(0).life_points, 8500,
		"only 500: itself, and not the Set card next to it")

	# The positive control: the very same card, once it is face-up, does count.
	var second := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, hidden, [
		TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD).id]),
		"the Set Continuous Trap is activated, turning it face-up")
	t.is_true(TestFixtures.activate_card(engine, 0, second),
		"a second Five Brothers Explosion is activated")
	t.eq(engine.state.player(0).life_points, 8500 + 1500,
		"now 3 x 500: the first copy, the now face-up Birthright, and this copy")


# ---------------------------------------------------------------------------
# "sent to your Graveyard by your opponent's card effect"
# ---------------------------------------------------------------------------

static func _test_the_opponents_effect_burns(t: TestCase) -> void:
	t.start("destroyed by the OPPONENT's card effect: 500 damage for each Continuous "
		+ "Spell/Trap Card in your Graveyard")
	var d := _main_phase_duel(9304)
	var engine: DuelEngine = d["engine"]
	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "it is activated (+500 LP)")
	t.eq(engine.state.player(0).life_points, 8500, "you are at 8500")

	# The opponent answers with a Spell Speed 2 Trap of their own that destroys it.
	var remover := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Remover", explosion, "destroy"), 0)
	var bait := TestFixtures.give_set_spell_trap(engine, 0, _card("Fiendish Chain"), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, bait.id)
	t.not_null(offered, "player 0 activates something to open a response window")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [monster.id]})),
		"as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response),
		"and destroys Five Brothers Explosion with their own card effect")
	TestFixtures.pass_until_open(engine)

	t.eq(explosion.zone, Enums.Zone.GRAVEYARD, "it was sent to your Graveyard")
	t.eq(engine.state.player(1).life_points, 8000 - 500,
		"500 damage for the one Continuous Spell/Trap in your Graveyard — itself")
	t.eq(engine.state.player(0).life_points, 8500,
		"and your own LP is not touched by the burn")


static func _test_your_own_effect_does_not(t: TestCase) -> void:
	t.start("'by your OPPONENT'S card effect' — your own effect sending it there inflicts "
		+ "nothing")
	var d := _main_phase_duel(9305)
	var engine: DuelEngine = d["engine"]
	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "it is activated")

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", explosion, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"YOUR OWN card effect destroys it")

	t.eq(explosion.zone, Enums.Zone.GRAVEYARD, "it is in your Graveyard")
	t.eq(engine.state.player(1).life_points, 8000,
		"and the opponent takes no damage at all")
	t.eq(engine.state.player(0).life_points, 8500, "nor do you")


static func _test_banished_does_not(t: TestCase) -> void:
	t.start("'sent to your GRAVEYARD' — the opponent banishing it inflicts nothing "
		+ "[S1 p.53]")
	var d := _main_phase_duel(9306)
	var engine: DuelEngine = d["engine"]
	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "it is activated")

	var banisher := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Banisher", explosion, "banish"), 0)
	var bait := TestFixtures.give_set_spell_trap(engine, 0, _card("Fiendish Chain"), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, bait.id)
	t.not_null(offered, "a Chain Link 1 opens a response window")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [monster.id]})), "ok")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, banisher.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and banishes Five Brothers Explosion")
	TestFixtures.pass_until_open(engine)

	t.eq(explosion.zone, Enums.Zone.BANISHED, "it is banished, not in the Graveyard")
	t.eq(engine.state.player(1).life_points, 8000, "so no damage was inflicted")


static func _test_the_graveyard_count(t: TestCase) -> void:
	t.start("'for each Continuous Spell/Trap Card IN YOUR GRAVEYARD' — every card in a "
		+ "Graveyard is public, so nothing is filtered on visibility there")
	var d := _main_phase_duel(9307)
	var engine: DuelEngine = d["engine"]

	# Three Continuous cards already in your Graveyard, plus decoys that must not count.
	TestFixtures.give(engine, 0, _card("Birthright"), Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine, 0, _card("Wonder Balloons"), Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine, 0, _card("Gagagashield"), Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine, 1, _card("Call of the Haunted"), Enums.Zone.GRAVEYARD)

	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "it is activated")

	var remover := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Remover", explosion, "destroy"), 0)
	var bait := TestFixtures.give_set_spell_trap(engine, 0, _card("Fiendish Chain"), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, bait.id)
	t.not_null(offered, "a Chain Link 1 opens a response window")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [monster.id]})), "ok")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the opponent responds")
	t.is_true(engine.submit_action(response), "destroying Five Brothers Explosion")
	TestFixtures.pass_until_open(engine)

	# Birthright + Wonder Balloons + Five Brothers itself = 3. Gagagashield is a NORMAL
	# Trap, Sabersaurus is a monster, and Call of the Haunted is in the OPPONENT's Graveyard.
	t.eq(engine.state.player(1).life_points, 8000 - 1500,
		"1500 damage: exactly 3 Continuous Spell/Trap Cards in YOUR Graveyard")


static func _test_effect_damage_can_end_the_duel(t: TestCase) -> void:
	t.start("effect damage is real damage: it can take a player to 0 LP and end the Duel")
	var d := _main_phase_duel(9308)
	var engine: DuelEngine = d["engine"]
	engine.state.player(1).life_points = 400

	var explosion := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, explosion), "it is activated")

	var remover := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Remover", explosion, "destroy"), 0)
	var bait := TestFixtures.give_set_spell_trap(engine, 0, _card("Fiendish Chain"), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, bait.id)
	t.not_null(offered, "a Chain Link 1 opens a response window")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [monster.id]})), "ok")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the opponent responds")
	t.is_true(engine.submit_action(response), "destroying it with their own effect")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).life_points, 0, "LP is floored at 0, never negative")
	t.is_true(engine.state.is_duel_over(), "and the Duel is over")
	t.eq(engine.state.result, Enums.DuelResult.PLAYER_0_WINS, "player 0 wins")
	t.eq(engine.state.end_reason, Enums.EndReason.LP_ZERO, "by LP reaching zero [S1 p.33]")

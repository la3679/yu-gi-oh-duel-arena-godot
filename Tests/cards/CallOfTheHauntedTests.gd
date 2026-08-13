class_name CallOfTheHauntedTests
extends RefCounted

## Per-card suite for `Call of the Haunted`.
##
##   "Activate this card by targeting 1 monster in your GY; Special Summon that target in
##    Attack Position. When this card leaves the field, destroy that monster. When that
##    monster is destroyed, destroy this card."
##
## The two differences from `Birthright` each get their own test, and both are asserted
## against the OPPOSITE outcome that `BirthrightTests` records:
##
##   * an EFFECT Monster in your Graveyard is a legal target here and is not there;
##   * a revived monster that is BANISHED leaves this card alone, while `Birthright`
##     destroys itself.
##
## Everything the two cards genuinely share is shared in `EffectPrimitives`; nothing about
## the difference is.

const CARD_UNDER_TEST := "Call of the Haunted"


static func run() -> TestCase:
	var t := TestCase.new("CallOfTheHauntedTests")
	_test_clause_shape(t)
	_test_revives_any_monster_in_attack_position(t)
	_test_an_effect_monster_is_a_legal_target(t)
	_test_only_your_own_graveyard(t)
	_test_this_card_leaving_destroys_the_monster(t)
	_test_the_monster_being_destroyed_destroys_this_card(t)
	_test_the_monster_being_banished_does_not(t)
	_test_destruction_by_battle_destroys_this_card(t)
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


static func _revived_board(seed_value: int, revived: String = "Sabersaurus") -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give(engine, 0, _card(revived), Enums.Zone.GRAVEYARD)
	TestFixtures.activate_card(engine, 0, trap, [monster.id])
	d["trap"] = trap
	d["monster"] = monster
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses, and the third is keyed on DESTRUCTION rather than on "
		+ "leaving the field")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var activation: EffectDef = def.effects[0]
	t.eq(activation.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"the first clause is the activation of the Trap itself")
	t.eq(activation.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2")
	t.is_true(activation.targets, "'by TARGETING' fixes the monster at activation")

	var destroy_monster: EffectDef = def.effects[1]
	t.eq(destroy_monster.trigger_events, [GameEvent.Kind.CARD_MOVED],
		"'when this card LEAVES THE FIELD' is keyed on movement — identical to Birthright")
	t.eq(destroy_monster.optionality, Enums.Optionality.MANDATORY, "and is mandatory")

	var destroy_self: EffectDef = def.effects[2]
	t.eq(destroy_self.trigger_events, [GameEvent.Kind.CARD_DESTROYED],
		"but 'when that monster IS DESTROYED' is keyed on DESTRUCTION — the one clause "
		+ "where this card and Birthright differ")
	t.eq(destroy_self.optionality, Enums.Optionality.MANDATORY, "also mandatory")
	t.eq(destroy_self.damage_step_permission,
		Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"the revived monster is most often destroyed by battle, so the timing has to be "
		+ "legal inside the Damage Step [S1 p.41]")

	# The two cards are not one implementation, and this is the assertion that says so.
	var birthright := _card("Birthright")
	t.not_null(birthright, "Birthright exists too")
	var birthright_self: EffectDef = birthright.effects[2]
	t.ne(destroy_self.trigger_events, birthright_self.trigger_events,
		"the two cards' third clauses genuinely listen to different events")


# ---------------------------------------------------------------------------
# The revival
# ---------------------------------------------------------------------------

static func _test_revives_any_monster_in_attack_position(t: TestCase) -> void:
	t.start("the target is Special Summoned in the Attack Position the card names")
	var d := _revived_board(7301)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "the target left the Graveyard")
	t.eq(monster.position, Enums.Position.FACE_UP_ATTACK, "in face-up Attack Position")
	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_POSITION), 0,
		"the position is fixed by the card, so no choice is offered")
	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"a Continuous Trap stays on the field after resolving [S1 p.29-30]")
	t.eq(engine.state.recall(trap, EffectPrimitives.REVIVED_MONSTER_KEY, -1), monster.id,
		"and it remembers which monster it Summoned")


static func _test_an_effect_monster_is_a_legal_target(t: TestCase) -> void:
	t.start("'1 monster' with no qualification — an EFFECT Monster qualifies here and "
		+ "does not for Birthright")
	var d := _main_phase_duel(7302)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var effect_monster := TestFixtures.give(engine, 0, _card("Mirage Dragon"),
		Enums.Zone.GRAVEYARD)
	var vanilla := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var spell := TestFixtures.give(engine, 0, _card("Monster Reborn"), Enums.Zone.GRAVEYARD)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id)
	t.not_null(action, "Call of the Haunted is offered")
	t.is_true(action.target_candidates.has(effect_monster.id),
		"the Effect Monster is a legal target")
	t.is_true(action.target_candidates.has(vanilla.id), "so is the Normal Monster")
	t.is_false(action.target_candidates.has(spell.id), "but a Spell Card is not a monster")
	t.eq(action.target_candidates.size(), 2, "exactly the two monsters")

	# The contrast: Birthright, in the same Graveyard, sees only one of them.
	var birthright := TestFixtures.give_set_spell_trap(engine, 0, _card("Birthright"), 0)
	var other = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, birthright.id)
	t.not_null(other, "Birthright is offered from the same board")
	t.eq(other.target_candidates.size(), 1,
		"but reaches only the Normal Monster — the two filters are genuinely different")


static func _test_only_your_own_graveyard(t: TestCase) -> void:
	t.start("'in YOUR GY' — the opponent's Graveyard is out of reach, unlike Monster Reborn")
	var d := _main_phase_duel(7303)
	var engine: DuelEngine = d["engine"]

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.give(engine, 1, _card("Blue-Eyes White Dragon"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"a monster in the opponent's Graveyard is not a legal target")

	TestFixtures.give(engine, 0, _card("Luster Dragon"), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id),
		"and one in your own Graveyard does enable it")


# ---------------------------------------------------------------------------
# The mutual link
# ---------------------------------------------------------------------------

static func _test_this_card_leaving_destroys_the_monster(t: TestCase) -> void:
	t.start("'When this card leaves the field, destroy that monster' — the clause this "
		+ "card shares verbatim with Birthright")
	var d := _revived_board(7304)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", trap, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Call of the Haunted")

	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "the Trap left the field")
	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "and took the monster with it")
	t.eq(engine.state.recall(trap, EffectPrimitives.REVIVED_MONSTER_KEY, -1), -1,
		"the link is cleared, so the monster's own destruction cannot fire back at it")


static func _test_the_monster_being_destroyed_destroys_this_card(t: TestCase) -> void:
	t.start("'When that monster IS DESTROYED, destroy this card'")
	var d := _revived_board(7305)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", monster, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys the revived monster")

	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "the monster is in the Graveyard")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "and Call of the Haunted destroyed itself")


static func _test_the_monster_being_banished_does_not(t: TestCase) -> void:
	t.start("a revived monster that is BANISHED leaves this card on the field — the "
		+ "single most important difference from Birthright")
	var d := _revived_board(7306)
	var engine: DuelEngine = d["engine"]
	var trap: CardInstance = d["trap"]
	var monster: CardInstance = d["monster"]

	var banisher := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Banisher", monster, "banish"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, banisher),
		"a card effect banishes the revived monster")

	t.eq(monster.zone, Enums.Zone.BANISHED, "the monster left the field")
	t.is_false(Enums.is_destruction(Enums.MoveReason.BANISHED),
		"but it was not DESTROYED [S1 p.52-53]")
	t.eq(trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"so this card stays face-up on the field — where Birthright would destroy itself")
	t.is_true(trap.is_face_up(), "still face-up")

	# And the link survives, so the "when this card leaves the field" clause has nothing
	# left to destroy rather than being armed with a stale reference.
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", trap, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover), "the Trap is then destroyed")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "it went to the Graveyard")
	t.eq(monster.zone, Enums.Zone.BANISHED,
		"and the banished monster was not dragged back out to be destroyed")


static func _test_destruction_by_battle_destroys_this_card(t: TestCase) -> void:
	t.start("destruction BY BATTLE happens inside the Damage Step, and the clause fires "
		+ "there [S1 p.41]")
	# Player 1 goes first so player 0 may attack on turn 2; here player 1 is the one who
	# revived a monster and player 0 runs it over.
	var d := TestFixtures.new_duel(7307, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var trap := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	var monster := TestFixtures.give(engine, 1, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.activate_card(engine, 1, trap, [monster.id]),
		"player 1 revives Sabersaurus (1900 ATK) on their own turn")
	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "it is on the field")

	TestFixtures.end_turn(engine)
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2500, 1000))
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"player 0 reaches the Battle Phase")
	t.is_true(TestFixtures.attack(engine, attacker, monster), "and attacks the revived monster")
	TestFixtures.pass_until_open(engine)

	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "the revived monster was destroyed by battle")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD,
		"and Call of the Haunted destroyed itself as a result")
	t.eq(engine.state.player(1).life_points, 8000 - 600,
		"battle damage was still inflicted normally: 2500 - 1900")

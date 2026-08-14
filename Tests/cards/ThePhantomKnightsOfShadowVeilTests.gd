class_name ThePhantomKnightsOfShadowVeilTests
extends RefCounted

## `The Phantom Knights of Shadow Veil` — Normal Trap, Spell Speed 2.
##
## Official text (verified, `Data/cards/cards.json`, cid 11404):
##
##   "Target 1 face-up monster you control; it gains 300 ATK/DEF. When an opponent's monster
##    declares a direct attack while this card is in your GY: Special Summon this card in
##    Defense Position as a Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300). (This card
##    is NOT treated as a Trap.) If Summoned this way, banish this card when it leaves the
##    field."
##
## **THREE clauses, all covered here.** The third is not a separate `EffectDef` because it is
## not separately activatable: "If Summoned **this way**" is a rider on the second, and it is
## asserted as its own behaviour below rather than assumed from the second passing.
##
## The generic Trap-Monster machinery this card sits on is proved separately by
## `TrapMonsterTests`, which was written and passing before this file existed. What is tested
## here is that THIS CARD's printed text is what drives it: the exact type line, the exact
## trigger condition, and the exact ATK/DEF amount.
##
## The boundary that gets the most attention is clause 1's **absent duration**. "It gains 300
## ATK/DEF" prints no duration at all, so the gain must survive the end of the turn — the
## commonest way to get this card wrong is to reach for the end-of-turn primitive that four
## other cards in this pool legitimately use.


const CARD_UNDER_TEST := "The Phantom Knights of Shadow Veil"

const BOOST_EFFECT_ID := "boost_own_monster"
const SUMMON_EFFECT_ID := "gy_summon_self_as_trap_monster"
const GAIN := 300


static func run() -> TestCase:
	var t := TestCase.new("ThePhantomKnightsOfShadowVeilTests")
	# Shape
	_test_the_card_declares_its_official_clauses(t)
	# Clause 1 — the Trap activation
	_test_it_is_not_offered_without_a_face_up_monster_you_control(t)
	_test_it_targets_only_your_own_face_up_monsters(t)
	_test_it_grants_300_atk_AND_300_def(t)
	_test_the_gain_has_no_duration_and_survives_the_end_of_the_turn(t)
	_test_the_gain_dies_with_the_monster_not_with_the_trap(t)
	_test_a_target_that_stops_qualifying_gains_nothing(t)
	_test_activation_negation_grants_nothing(t)
	_test_effect_negation_grants_nothing(t)
	_test_the_gain_is_used_in_damage_calculation(t)
	_test_clause_1_is_not_legal_in_the_damage_step(t)
	_test_the_trap_reaches_the_graveyard_after_resolving(t)
	# Clause 2 — the Graveyard trigger
	_test_a_direct_attack_by_the_opponent_summons_it_from_the_graveyard(t)
	_test_the_summoned_card_has_exactly_the_printed_type_line(t)
	_test_it_is_a_real_special_summon_from_the_graveyard(t)
	_test_an_attack_on_a_monster_does_not_trigger_it(t)
	_test_your_own_direct_attack_does_not_trigger_it(t)
	_test_it_does_not_trigger_from_anywhere_but_the_graveyard(t)
	_test_the_monster_zone_is_always_free_when_this_clause_triggers(t)
	# Clause 3 — "if Summoned this way, banish this card when it leaves the field"
	_test_the_obligation_is_taken_only_by_that_summon(t)
	_test_every_departure_after_that_summon_banishes_it(t)
	_test_it_leaves_no_stale_monster_state_behind(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## Player 0's turn, the Trap Set on their side and ready to activate.
static func _boost_board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["veil"] = TestFixtures.give_set_spell_trap(engine, 0, _def())
	d["mine"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Monster", 4, 1000, 1000))
	return d


## Turn 2, player 1 is the turn player with a monster, player 0 has an EMPTY field and the
## Trap in their Graveyard — so the opponent's next attack is a direct one.
##
## Player 0 goes first so that player 1, attacking on turn 2, is not caught by "the player who
## goes first cannot conduct a Battle Phase on their first turn" [S1 p.37].
static func _direct_attack_board(seed_value: int,
		attacker_atk: int = 1500) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["veil"] = TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Beater", 4, attacker_atk, 1000))
	return d


static func _atk_of(engine: DuelEngine, card: CardInstance) -> int:
	ContinuousEffects.new(engine.state).recompute()
	return card.current_atk()


static func _def_of(engine: DuelEngine, card: CardInstance) -> int:
	ContinuousEffects.new(engine.state).recompute()
	return card.current_def()


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_its_official_clauses(t: TestCase) -> void:
	t.start("a Normal Trap at Spell Speed 2 with the two activatable clauses its text prints")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	if card_def == null:
		return
	t.eq(card_def.category, Enums.Category.TRAP, "it is a Trap Card")
	t.eq(card_def.st_kind, Enums.STKind.NORMAL_TRAP, "a NORMAL Trap")
	t.eq(card_def.effects.size(), 2, "two activatable clauses")

	var boost: EffectDef = card_def.effects[0]
	var summon: EffectDef = card_def.effects[1]
	t.eq(boost.effect_id, BOOST_EFFECT_ID, "clause 1 is the ATK/DEF boost")
	t.eq(boost.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"clause 1 is the card's own activation")
	t.eq(boost.spell_speed, Enums.SpellSpeed.SS2,
		"at Spell Speed 2, so it can be used in a response window [S1 p.44-45]")
	t.eq(boost.damage_step_permission, Enums.DamageStepPermission.NONE,
		"and it is not legal in the Damage Step — nothing in its text makes it so")

	t.eq(summon.effect_id, SUMMON_EFFECT_ID, "clause 2 is the Graveyard summon")
	t.eq(summon.effect_type, Enums.EffectType.TRIGGER, "clause 2 is a Trigger Effect")
	t.check(summon.trigger_events.has(GameEvent.Kind.ATTACK_DECLARED),
		"keyed on an attack declaration")
	t.check(summon.activation_locations.has(Enums.ActivationLocation.GRAVEYARD),
		"activated from the GRAVEYARD")
	t.eq(summon.optionality, Enums.Optionality.MANDATORY,
		"MANDATORY — the sentence contains no 'You can'")


# ---------------------------------------------------------------------------
# Clause 1 — "Target 1 face-up monster you control; it gains 300 ATK/DEF."
# ---------------------------------------------------------------------------

static func _test_it_is_not_offered_without_a_face_up_monster_you_control(
		t: TestCase) -> void:
	t.start("with no face-up monster of your own the Trap has no legal target and is not "
		+ "offered")
	var d := TestFixtures.new_duel(9901, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var veil := TestFixtures.give_set_spell_trap(engine, 0, _def())
	# The opponent's monster is not "a monster you control".
	TestFixtures.give_monster_on_field(engine, 1, TestFixtures.monster("Theirs"))

	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, veil.id),
		"the activation is not offered")


static func _test_it_targets_only_your_own_face_up_monsters(t: TestCase) -> void:
	t.start("the candidate set is exactly your FACE-UP monsters — not the opponent's, and "
		+ "not your own face-down ones")
	var d := _boost_board(9902)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Set Monster"), Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, veil.id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	var candidates: Array = offered.target_candidates
	t.check(candidates.has(mine.id), "your face-up monster is a candidate")
	t.check(not candidates.has(face_down.id),
		"your FACE-DOWN monster is not — the text says face-up")
	t.check(not candidates.has(theirs.id),
		"and the opponent's monster is not — the text says you control it")
	t.eq(candidates.size(), 1, "exactly one legal target")


static func _test_it_grants_300_atk_AND_300_def(t: TestCase) -> void:
	t.start("it gains 300 ATK and 300 DEF — both, not ATK alone")
	var d := _boost_board(9903)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	var atk_before := _atk_of(engine, mine)
	var def_before := _def_of(engine, mine)

	t.check(TestFixtures.activate_card(engine, 0, veil, [mine.id]),
		"the Trap was activated on your own face-up monster")

	t.eq(_atk_of(engine, mine), atk_before + GAIN, "+300 ATK")
	t.eq(_def_of(engine, mine), def_before + GAIN, "+300 DEF")


static func _test_the_gain_has_no_duration_and_survives_the_end_of_the_turn(
		t: TestCase) -> void:
	t.start("no duration is printed, so the gain is NOT an end-of-turn modifier and is still "
		+ "there on the following turn")
	var d := _boost_board(9904)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	t.check(TestFixtures.activate_card(engine, 0, veil, [mine.id]), "activated")
	t.eq(_atk_of(engine, mine), 1000 + GAIN, "the gain applied")
	# The distinction this test exists for: the modifier must not carry the turn-scoped
	# duration that TurnFlow._end_of_turn_cleanup() strips.
	for m in mine.atk_modifiers:
		t.check(str((m as Dictionary).get("until", "")) != "end_of_turn",
			"no ATK modifier is turn-scoped")
	for m in mine.def_modifiers:
		t.check(str((m as Dictionary).get("until", "")) != "end_of_turn",
			"no DEF modifier is turn-scoped")

	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_number, 2, "the turn really did change")
	t.eq(_atk_of(engine, mine), 1000 + GAIN, "the ATK gain survived the turn boundary")
	t.eq(_def_of(engine, mine), 1000 + GAIN, "and so did the DEF gain")


static func _test_the_gain_dies_with_the_monster_not_with_the_trap(t: TestCase) -> void:
	t.start("the modifier lives on the TARGET: the Trap reaching the Graveyard does not "
		+ "remove it, but the monster leaving the field does")
	var d := _boost_board(9905)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	t.check(TestFixtures.activate_card(engine, 0, veil, [mine.id]), "activated")

	t.eq(veil.zone, Enums.Zone.GRAVEYARD,
		"the Normal Trap is already in the Graveyard — its source is gone")
	t.eq(_atk_of(engine, mine), 1000 + GAIN,
		"and the gain is still there, so it is not tied to the source")

	engine.state.destroy(mine, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.eq(mine.atk_modifiers.size(), 0, "the monster leaving the field cleared the modifier")
	t.eq(mine.def_modifiers.size(), 0, "both of them")


static func _test_a_target_that_stops_qualifying_gains_nothing(t: TestCase) -> void:
	t.start("a target flipped face-down in response is no longer 'a face-up monster you "
		+ "control' and gains nothing")
	var d := _boost_board(9906)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	var flipper := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Flip It Down", mine, "flip_face_down"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, veil.id)
	t.not_null(offered, "the Trap is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, flipper.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.check(engine.submit_action(response), "the flipper becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# Prove the Chain really reached the interferer rather than resolving unopposed.
	t.check(mine.is_face_down(), "the target really was flipped face-down")
	t.eq(mine.atk_modifiers.size(), 0, "so it gained no ATK")
	t.eq(mine.def_modifiers.size(), 0, "and no DEF")


static func _test_activation_negation_grants_nothing(t: TestCase) -> void:
	t.start("a negated ACTIVATION grants nothing")
	var d := _boost_board(9907)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Stop That"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, veil.id)
	t.not_null(offered, "the Trap is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.check(engine.submit_action(response), "the negator becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.check(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED) >= 1,
		"the activation really was negated — this is not a fallback path")
	t.eq(_atk_of(engine, mine), 1000, "no ATK was gained")
	t.eq(_def_of(engine, mine), 1000, "and no DEF")


static func _test_effect_negation_grants_nothing(t: TestCase) -> void:
	t.start("a negated EFFECT grants nothing either")
	var d := _boost_board(9908)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silence That"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, veil.id)
	t.not_null(offered, "the Trap is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.check(engine.submit_action(response), "the negator becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.check(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED) >= 1,
		"the effect really was negated")
	t.eq(_atk_of(engine, mine), 1000, "no ATK was gained")


static func _test_the_gain_is_used_in_damage_calculation(t: TestCase) -> void:
	t.start("the boosted ATK is the ATK that fights: 1000 + 300 beats a 1200 defender")
	var d := TestFixtures.new_duel(9909, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var veil := TestFixtures.give_set_spell_trap(engine, 0, _def())
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, 1000, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Wall", 4, 1200, 1000))
	t.check(TestFixtures.activate_card(engine, 0, veil, [mine.id]), "the Trap resolved")
	t.eq(_atk_of(engine, mine), 1300, "the attacker is at 1300")

	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.check(TestFixtures.attack(engine, mine, theirs), "the attack was declared")
	TestFixtures.pass_until_open(engine)

	t.eq(theirs.zone, Enums.Zone.GRAVEYARD,
		"1300 beat 1200 — without the gain this battle would have been lost")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "and the attacker survived")


static func _test_clause_1_is_not_legal_in_the_damage_step(t: TestCase) -> void:
	t.start("nothing in clause 1's text makes it Damage Step legal, so it is not offered "
		+ "there [S1 p.41], RULES_SPEC.md 7.2")
	var d := _boost_board(9910)
	var engine: DuelEngine = d["engine"]
	var effect: EffectDef = _def().effects[0]
	t.eq(effect.damage_step_permission, Enums.DamageStepPermission.NONE,
		"no Damage Step permission is declared")

	# Asked of the rules layer directly, at the sub-step, rather than by looking at what is
	# offered mid-attack: the response window straight after an attack declaration is the
	# BATTLE step, not the Damage Step, and a Spell Speed 2 Trap is perfectly legal there —
	# so an "is it offered?" check taken at that moment would be testing the wrong moment.
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_false(ActivationRules.damage_step_ok(engine.state, effect),
		"the rules layer refuses it inside the Damage Step")
	engine.state.battle_step = Enums.BattleStep.NONE
	engine.state.damage_substep = Enums.DamageSubStep.NONE
	t.is_true(ActivationRules.damage_step_ok(engine.state, effect),
		"while outside it the same question says yes")


static func _test_the_trap_reaches_the_graveyard_after_resolving(t: TestCase) -> void:
	t.start("a Normal Trap goes to the Graveyard once it has resolved, which is what puts "
		+ "clause 2 in reach")
	var d := _boost_board(9911)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var mine: CardInstance = d["mine"]
	t.check(TestFixtures.activate_card(engine, 0, veil, [mine.id]), "activated")

	t.eq(veil.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.check(veil.is_trap(), "and it is a Trap there — not a monster")
	t.check(not veil.is_monster(), "definitely not a monster")


# ---------------------------------------------------------------------------
# Clause 2 — the Graveyard trigger.
# ---------------------------------------------------------------------------

static func _test_a_direct_attack_by_the_opponent_summons_it_from_the_graveyard(
		t: TestCase) -> void:
	t.start("when an opponent's monster declares a DIRECT attack while this card is in your "
		+ "GY, it Special Summons itself")
	var d := _direct_attack_board(9920)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.eq(veil.zone, Enums.Zone.GRAVEYARD, "it starts in the Graveyard")
	t.check(engine.state.player(0).monsters().is_empty(),
		"and player 0 has an empty field, so the attack really is direct")

	t.check(TestFixtures.attack(engine, attacker, null), "the direct attack was declared")
	TestFixtures.pass_until_open(engine)

	t.eq(veil.zone, Enums.Zone.MONSTER_ZONE, "it is now in a Monster Zone")
	t.check(veil.is_monster(), "and it is a monster")
	t.eq(veil.controller_id, 0, "under its own controller")


static func _test_the_summoned_card_has_exactly_the_printed_type_line(t: TestCase) -> void:
	t.start("Warrior / DARK / Level 4 / ATK 0 / DEF 300, in Defense Position, as a NORMAL "
		+ "Monster, and NOT treated as a Trap — every value the card prints")
	var d := _direct_attack_board(9921)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.check(TestFixtures.attack(engine, attacker, null), "the direct attack was declared")
	TestFixtures.pass_until_open(engine)
	if veil.zone != Enums.Zone.MONSTER_ZONE:
		t.check(false, "it did not reach the Monster Zone, so the type line cannot be read")
		return

	t.eq(veil.current_race(), "Warrior", "Warrior")
	t.eq(veil.current_attribute(), "DARK", "DARK")
	t.eq(veil.current_level(), 4, "Level 4")
	t.eq(veil.base_atk(), 0, "ATK 0")
	t.eq(veil.base_def(), 300, "DEF 300")
	t.eq(veil.position, Enums.Position.FACE_UP_DEFENSE, "in Defense Position")
	t.check(veil.is_normal_monster(), "as a Normal Monster")
	t.check(not veil.is_trap(), "(This card is NOT treated as a Trap.)")
	t.check(veil.is_monster(), "but it IS a monster")
	# And the shared printed definition is untouched by any of it.
	t.eq(veil.definition.category, Enums.Category.TRAP,
		"the printed CardDef is still a Trap Card")
	t.eq(veil.definition.level, 0, "and carries no Level of its own")


static func _test_it_is_a_real_special_summon_from_the_graveyard(t: TestCase) -> void:
	t.start("it goes through the ordinary Special Summon route, with the real events")
	var d := _direct_attack_board(9922)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.check(TestFixtures.attack(engine, attacker, null), "the direct attack was declared")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, veil.id), 1,
		"exactly one successful Special Summon of this card")
	t.eq(veil.summoned_by, Enums.SummonKind.SPECIAL, "recorded as a Special Summon")
	t.check(veil.properly_special_summoned, "and as properly Special Summoned")
	t.eq(veil.last_move_from_zone, Enums.Zone.IN_TRANSIT,
		"it arrived through the declaration holding area, not by a direct placement")


static func _test_an_attack_on_a_monster_does_not_trigger_it(t: TestCase) -> void:
	t.start("'declares a DIRECT attack' — an attack on a monster does not trigger it")
	var d := _direct_attack_board(9923)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	# Give player 0 a monster, so the attack has a target and is not direct.
	var wall := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Wall", 4, 100, 2000), Enums.Position.FACE_UP_DEFENSE)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)

	t.check(TestFixtures.attack(engine, attacker, wall),
		"the attack was declared against the monster")
	TestFixtures.pass_until_open(engine)

	t.eq(veil.zone, Enums.Zone.GRAVEYARD, "the Trap stayed in the Graveyard")
	t.check(not veil.is_monster(), "and is not a monster")


static func _test_your_own_direct_attack_does_not_trigger_it(t: TestCase) -> void:
	t.start("'an OPPONENT'S monster' — your own direct attack does not trigger it")
	var d := TestFixtures.new_duel(9924, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	# The Trap is in PLAYER 0's Graveyard and player 0 is the one attacking directly.
	var veil := TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Beater", 4, 1500, 1000))
	t.check(engine.state.player(1).monsters().is_empty(),
		"the opponent's field is empty, so this attack is direct")
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)

	t.check(TestFixtures.attack(engine, mine, null), "player 0 attacks directly")
	TestFixtures.pass_until_open(engine)

	t.eq(veil.zone, Enums.Zone.GRAVEYARD,
		"the Trap stayed in the Graveyard — the attacker was not an opponent's monster")


static func _test_it_does_not_trigger_from_anywhere_but_the_graveyard(t: TestCase) -> void:
	t.start("'while this card is in your GY' — a Set copy in the Spell & Trap Zone does not "
		+ "Special Summon itself off a direct attack")
	var d := TestFixtures.new_duel(9925, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var veil := TestFixtures.give_set_spell_trap(engine, 0, _def())
	var attacker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Beater", 4, 1500, 1000))
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)

	t.check(TestFixtures.attack(engine, attacker, null), "the direct attack was declared")
	TestFixtures.pass_until_open(engine)

	t.eq(veil.zone, Enums.Zone.SPELL_TRAP_ZONE, "it is still Set in the Spell & Trap Zone")
	t.check(not veil.is_monster(), "and never became a monster")


static func _test_the_monster_zone_is_always_free_when_this_clause_triggers(t: TestCase) -> void:
	t.start("the 'no free Monster Zone' branch is UNREACHABLE for this clause, and the reason "
		+ "is asserted rather than assumed")
	var d := _direct_attack_board(9926)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	# The generic "no free Monster Zone" behaviour is covered by `TrapMonsterTests`. For THIS
	# card the branch cannot be reached at all, and that is a fact about the card rather than
	# a gap in the tests: the trigger requires a DIRECT attack, a direct attack requires the
	# defending player to control no monsters, and a player controlling no monsters has five
	# free Monster Zones. The two halves of that reasoning are asserted below so the claim
	# cannot rot if either rule ever changes.
	t.check(engine.state.player(0).monsters().is_empty(),
		"a DIRECT attack requires the defender to control no monsters [S1 p.38]")
	t.check(engine.state.player(0).has_free_monster_zone(),
		"so the defender always has a free Monster Zone when this clause triggers")
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.check(TestFixtures.attack(engine, attacker, null), "the direct attack was declared")
	TestFixtures.pass_until_open(engine)
	t.eq(veil.zone, Enums.Zone.MONSTER_ZONE,
		"and the Summon therefore always has somewhere to go")


# ---------------------------------------------------------------------------
# Clause 3 — "If Summoned this way, banish this card when it leaves the field."
# ---------------------------------------------------------------------------

static func _test_the_obligation_is_taken_only_by_that_summon(t: TestCase) -> void:
	t.start("the banish obligation is taken on by the Graveyard Summon and by nothing else")
	var d := _direct_attack_board(9930)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	t.check(not bool(engine.state.recall(veil,
		GameState.BANISH_WHEN_LEAVING_FIELD_KEY, false)),
		"sitting in the Graveyard it carries no obligation")

	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.check(TestFixtures.attack(engine, attacker, null), "the direct attack was declared")
	TestFixtures.pass_until_open(engine)

	t.check(bool(engine.state.recall(veil,
		GameState.BANISH_WHEN_LEAVING_FIELD_KEY, false)),
		"after being Summoned this way it does")


static func _test_every_departure_after_that_summon_banishes_it(t: TestCase) -> void:
	t.start("destroyed, returned to the hand, returned to the Deck or tributed — after that "
		+ "Summon it is banished instead, and the departure it replaced still happened")
	var routes := [
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT, "destroyed"],
		[Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND, "returned to the hand"],
		[Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_TOP, "returned to the Deck"],
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.TRIBUTED, "tributed"],
	]
	var seed_value := 9940
	for entry in routes:
		var route: Array = entry
		var to_zone: Enums.Zone = route[0]
		var reason: Enums.MoveReason = route[1]
		var label: String = route[2]
		seed_value += 1
		var d := _direct_attack_board(seed_value)
		var engine: DuelEngine = d["engine"]
		var veil: CardInstance = d["veil"]
		var attacker: CardInstance = d["attacker"]
		TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
		TestFixtures.attack(engine, attacker, null)
		TestFixtures.pass_until_open(engine)
		if veil.zone != Enums.Zone.MONSTER_ZONE:
			t.check(false, "%s: it was not Summoned, so nothing can be tested" % label)
			continue

		engine.state.move_card(veil, to_zone, reason)

		t.eq(veil.zone, Enums.Zone.BANISHED, "%s: it was banished instead" % label)
		t.check(engine.state.player(0).banished.has(veil),
			"%s: into its owner's banished zone" % label)
		t.eq(veil.last_move_reason, reason,
			"%s: and the departure it replaced is still the recorded reason" % label)


static func _test_it_leaves_no_stale_monster_state_behind(t: TestCase) -> void:
	t.start("once banished it is a Trap again with no monster state left on it")
	var d := _direct_attack_board(9950)
	var engine: DuelEngine = d["engine"]
	var veil: CardInstance = d["veil"]
	var attacker: CardInstance = d["attacker"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	TestFixtures.attack(engine, attacker, null)
	TestFixtures.pass_until_open(engine)
	if veil.zone != Enums.Zone.MONSTER_ZONE:
		t.check(false, "it was not Summoned, so nothing can be tested")
		return

	engine.state.destroy(veil, Enums.MoveReason.DESTROYED_BY_EFFECT)

	t.eq(veil.zone, Enums.Zone.BANISHED, "it is banished")
	t.check(not veil.is_monster(), "not a monster")
	t.check(veil.is_trap(), "a Trap again")
	t.check(not veil.has_monster_identity(), "no runtime monster identity")
	t.eq(veil.current_level(), 0, "no Level")
	t.eq(veil.base_def(), 0, "no DEF")
	t.eq(veil.summoned_by_procedure_id, "", "no summoning-procedure record")
	t.eq(engine.state.player(0).monster_count(), 0, "and it holds no Monster Zone")

class_name MonarchsAwakenTests
extends RefCounted

## Per-card suite for `The Monarchs Awaken`. Research/CARD_RULINGS.md **R12**.
##
##   "If you have no cards in your Extra Deck: Target 1 face-up Tribute Summoned monster you
##    control; its effects are negated, also it is unaffected by the effects of cards other
##    than this card."
##
## The generic half — what "unaffected by the effects of cards other than this card"
## actually blocks, and what it pointedly does not — is proved by the gate in
## `ImmunityTests`, which was written and green before this card existed. What is specific
## to this card, and what this suite is about, is:
##
##   * the fact the printed English text does not carry (R12 Part A): it **cannot be
##     activated during the Damage Step**. Asserted directly against the permission gate,
##     because for this card the restriction is the engine's DEFAULT — a default that
##     happens to be right is indistinguishable from one nobody checked;
##   * **which monsters are legal targets**, which is not `summoned_by == TRIBUTE` and is
##     the place the engine's own answer was wrong (R12 Part F). A Tribute Set monster
##     counts, a Flip Summon does not erase the property, a temporary banishment does not
##     erase it, and leaving the field permanently does;
##   * the **resolution-time face-up gate**: if the target is face-down when the Trap
##     resolves, **neither** clause applies and the card is spent for nothing (R12 Part E);
##   * that a **Normal Monster** is a legal target even though the negation then has nothing
##     to negate (R12 Part G);
##   * that the negation and the immunity **coexist**, and that both **outlive the Trap**,
##     which is in the Graveyard the moment it resolves (R12 Part D).
##
## Real pool cards are used wherever the pool has one. The Extra Deck condition is the only
## thing tested synthetically, because both V1 decks have empty Extra Decks and it is
## therefore never false in the pool — the never-false shape R1 records for
## `Runick Flashing Fire`.

const CARD_UNDER_TEST := "The Monarchs Awaken"
const EFFECT_ID := "monarchs_awaken_negate_and_ward"


static func run() -> TestCase:
	var t := TestCase.new("MonarchsAwakenTests")
	# Shape and declarations
	_test_clause_shape(t)
	_test_it_targets(t)
	_test_the_damage_step_is_closed(t)
	_test_not_the_turn_it_was_set(t)
	# Activation legality — the target set
	_test_a_tribute_summoned_monster_is_a_legal_target(t)
	_test_a_normal_summoned_monster_is_not(t)
	_test_the_opponents_tribute_summoned_monster_is_not(t)
	_test_a_face_down_monster_is_not(t)
	_test_a_tribute_set_monster_becomes_legal_when_flipped(t)
	_test_a_normal_monster_is_a_legal_target(t)
	_test_a_returned_monster_is_still_a_legal_target(t)
	_test_a_monster_that_left_the_field_is_not(t)
	_test_no_legal_target_means_no_activation(t)
	# The Extra Deck condition — R12 Part G
	_test_a_non_empty_extra_deck_forbids_the_activation(t)
	_test_an_empty_extra_deck_allows_it(t)
	# Resolution
	_test_it_negates_and_wards_the_target(t)
	_test_the_immunity_exempts_this_card(t)
	_test_both_states_outlive_the_trap(t)
	_test_a_face_down_target_at_resolution_applies_neither_clause(t)
	_test_a_normal_monster_target_is_still_warded(t)
	# Interaction
	_test_the_warded_monster_resists_a_real_pool_card(t)
	_test_the_warded_monster_is_still_destroyed_by_battle(t)
	_test_the_states_end_when_the_monster_leaves_the_field(t)
	_test_activation_negated(t)
	# Replay
	_test_the_same_seed_replays_identically(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _effect() -> EffectDef:
	var d := _def()
	if d == null:
		return null
	for entry in d.effects:
		var e: EffectDef = entry
		if e.effect_id == EFFECT_ID:
			return e
	return null


## Player 0, in Main Phase 1 of their own turn, with the Trap Set and ready.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["trap"] = TestFixtures.give_set_spell_trap(engine, 0, _def())
	return d


## Tribute Summon `big` over `fodder` for player 0 and return whether it happened.
static func _tribute_summon(t: TestCase, engine: DuelEngine, big: CardInstance,
		fodder) -> bool:
	var ids: Array = []
	if fodder is Array:
		for f in fodder:
			ids.append((f as CardInstance).id)
	else:
		ids.append((fodder as CardInstance).id)
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, big.id)
	t.not_null(action, "the Tribute Summon is offered")
	if action == null:
		return false
	var ok: bool = engine.submit_action(action.with_choices({"tribute_ids": ids}))
	TestFixtures.pass_until_open(engine)
	return ok


## A board with one Tribute Summoned monster player 0 controls, and the Trap Set.
## Returns {"engine", "trap", "monarch"}.
static func _board_with_tribute_summon(t: TestCase, seed_value: int,
		monarch_def: CardDef = null, tributes: int = 1) -> Dictionary:
	var d := _board(seed_value)
	var engine: DuelEngine = d["engine"]
	var fodder: Array = []
	for i in range(tributes):
		fodder.append(TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Fodder %d" % i, 4, 1000, 1000)))
	var def := monarch_def if monarch_def != null \
		else TestFixtures.monster("Monarch", 6, 2400, 1000)
	var monarch := TestFixtures.give_to_hand(engine, 0, def)
	t.is_true(_tribute_summon(t, engine, monarch, fodder), "and is accepted")
	t.is_true(monarch.was_tribute_summoned(), "the monster counts as Tribute Summoned")
	d["monarch"] = monarch
	return d


static func _activate(engine: DuelEngine, trap: CardInstance,
		target: CardInstance) -> bool:
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id, EFFECT_ID)
	if action == null:
		return false
	if not engine.submit_action(action.with_choices({"target_ids": [target.id]})):
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _offered(engine: DuelEngine, trap: CardInstance):
	return TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, trap.id, EFFECT_ID)


static func _targets(engine: DuelEngine, trap: CardInstance) -> Array:
	var a = _offered(engine, trap)
	return [] if a == null else a.target_candidates


# ---------------------------------------------------------------------------
# Shape and declarations
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("one EffectDef, a Spell Speed 2 CARD_ACTIVATION from a Set position")
	var d := _def()
	t.not_null(d, "the card is registered")
	if d == null:
		return
	t.eq(d.effects.size(), 1, "the official text is one clause, so there is one EffectDef")
	var e := _effect()
	t.not_null(e, "and it carries the expected effect id")
	if e == null:
		return
	t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION, "it is a card activation")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2 [S1 p.44-45]")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"activated from a Set position on the field, never from the hand")
	t.eq(e.ruling_ref, "R12", "and it carries its ruling reference")


static func _test_it_targets(t: TestCase) -> void:
	t.start("it TARGETS exactly 1 monster — 「対象として発動できる」")
	var e := _effect()
	if e == null:
		return
	t.is_true(e.targets, "the clause is declared as targeting")
	t.eq(e.target_count_min, 1, "exactly one target, minimum")
	t.eq(e.target_count_max, 1, "and maximum")


static func _test_the_damage_step_is_closed(t: TestCase) -> void:
	t.start("R12 Part A: 「ダメージステップには発動できません」 — the activation "
		+ "restriction the printed English text does not carry")
	var e := _effect()
	if e == null:
		return
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"the permission is NONE")

	var d := _board(1601)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	t.is_true(ActivationRules.damage_step_ok(state, e),
		"outside the Damage Step the permission gate allows it")

	state.battle_step = Enums.BattleStep.DAMAGE
	for substep in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		state.damage_substep = substep
		t.is_false(ActivationRules.damage_step_ok(state, e),
			"refused in Damage Step sub-step %d" % int(substep))

	# The control: a clause that DOES carry a permission is allowed in its own sub-step, so
	# the assertions above are not passing because the gate refuses everything. This is the
	# whole reason the test exists — for this card the restriction is the engine's default,
	# and a default nobody checked looks exactly like a default that is right.
	var permitted := EffectDef.new("permitted", "Test")
	permitted.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_true(ActivationRules.damage_step_ok(state, permitted),
		"a clause that carries UNTIL_DAMAGE_CALC is allowed in the same sub-step")


static func _test_not_the_turn_it_was_set(t: TestCase) -> void:
	t.start("a Trap cannot be activated the turn it was Set [S1 p.45]")
	var d := TestFixtures.new_duel(1602, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var monarch := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	t.is_true(_tribute_summon(t, engine, monarch, fodder), "the Tribute Summon happens")

	var trap := TestFixtures.give_set_spell_trap(engine, 0, _def(),
		engine.state.turn_number)
	t.is_null(_offered(engine, trap), "Set this turn, it is not offered")

	trap.turn_set = engine.state.turn_number - 1
	t.not_null(_offered(engine, trap),
		"and the same card Set on an earlier turn is — so the refusal above was the "
		+ "Set-turn rule and not a missing target")


# ---------------------------------------------------------------------------
# The target set — R12 Part F
# ---------------------------------------------------------------------------

static func _test_a_tribute_summoned_monster_is_a_legal_target(t: TestCase) -> void:
	t.start("a face-up Tribute Summoned monster you control is a legal target")
	var d := _board_with_tribute_summon(t, 1610)
	var engine: DuelEngine = d["engine"]
	var targets := _targets(engine, d["trap"])
	t.eq(targets.size(), 1, "exactly one legal target")
	t.is_true(targets.has((d["monarch"] as CardInstance).id), "and it is the Monarch")


static func _test_a_normal_summoned_monster_is_not(t: TestCase) -> void:
	t.start("a monster Normal Summoned WITHOUT Tributes is not 'Tribute Summoned'")
	var d := _board(1611)
	var engine: DuelEngine = d["engine"]
	var small := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 1000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, small.id)
	t.not_null(action, "it is Normal Summoned")
	if action == null:
		return
	t.is_true(engine.submit_action(action), "successfully")
	TestFixtures.pass_until_open(engine)

	t.is_true(small.is_face_up(), "it is face-up on the field")
	t.is_false(small.was_tribute_summoned(), "but it was not Tribute Summoned")
	t.eq(_targets(engine, d["trap"]).size(), 0, "so there is no legal target")
	t.is_null(_offered(engine, d["trap"]), "and the card is not offered at all")


static func _test_the_opponents_tribute_summoned_monster_is_not(t: TestCase) -> void:
	t.start("'you control' — the opponent's Tribute Summoned monster is not a target")
	var d := _board_with_tribute_summon(t, 1612)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]

	# Give the opponent a Tribute Summoned monster of their own, by construction.
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monarch", 6, 2400, 1000))
	theirs.tribute_summoned = true

	var targets := _targets(engine, d["trap"])
	t.eq(targets.size(), 1, "still exactly one legal target")
	t.is_true(targets.has(monarch.id), "your own")
	t.is_false(targets.has(theirs.id), "and not the opponent's")


static func _test_a_face_down_monster_is_not(t: TestCase) -> void:
	t.start("'face-up' — a face-down Tribute Set monster is not a legal target, even "
		+ "though it already counts as Tribute Summoned")
	var d := _board(1613)
	var engine: DuelEngine = d["engine"]
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var monarch := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SET, monarch.id)
	t.not_null(action, "a Tribute Set is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [fodder.id]})),
		"and accepted")
	TestFixtures.pass_until_open(engine)

	t.is_true(monarch.is_face_down(), "the monster is face-down")
	t.is_true(monarch.was_tribute_summoned(),
		"it already counts as Tribute Summoned (Q&A fid 20533)")
	t.eq(_targets(engine, d["trap"]).size(), 0,
		"but 'face-up' excludes it — the two requirements are independent")


static func _test_a_tribute_set_monster_becomes_legal_when_flipped(t: TestCase) -> void:
	t.start("R12 Part F: a Tribute SET monster flipped face-up IS a legal target — the "
		+ "engine's previous answer was wrong (Q&A fid 20548)")
	var d := _board(1614)
	var engine: DuelEngine = d["engine"]
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var monarch := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SET, monarch.id)
	t.not_null(action, "a Tribute Set is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [fodder.id]})),
		"and accepted")
	TestFixtures.pass_until_open(engine)

	t.is_true(TestFixtures.end_turn(engine), "the turn passes")
	t.is_true(TestFixtures.end_turn(engine), "and comes back")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"reaching Main Phase 1")
	var flip = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, monarch.id)
	t.not_null(flip, "it can be Flip Summoned")
	if flip == null:
		return
	t.is_true(engine.submit_action(flip), "and is")
	TestFixtures.pass_until_open(engine)

	t.eq(monarch.summoned_by, Enums.SummonKind.FLIP,
		"`summoned_by` now reads FLIP, which is why it cannot answer this question")
	t.is_true(_targets(engine, d["trap"]).has(monarch.id),
		"and the monster is a legal target all the same")


static func _test_a_normal_monster_is_a_legal_target(t: TestCase) -> void:
	t.start("R12 Part G: a Tribute Summoned NORMAL Monster is a legal target, though the "
		+ "negation will have nothing to negate — 「通常モンスターを対象に発動することも"
		+ "できます」")
	var d := _board(1615)
	var engine: DuelEngine = d["engine"]
	var vanilla := _card("Metaphys Armed Dragon")
	t.not_null(vanilla, "the pool's Level 7 vanilla is available")
	if vanilla == null:
		return
	t.is_true(vanilla.is_normal_monster, "and it really is a Normal Monster")
	t.eq(vanilla.effects.size(), 0, "with no effects at all")

	var fodder: Array = []
	for i in range(2):
		fodder.append(TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Fodder %d" % i, 4, 1000, 1000)))
	var mon := TestFixtures.give_to_hand(engine, 0, vanilla)
	t.is_true(_tribute_summon(t, engine, mon, fodder), "it is Tribute Summoned")
	t.is_true(_targets(engine, d["trap"]).has(mon.id), "and it is a legal target")


static func _test_a_returned_monster_is_still_a_legal_target(t: TestCase) -> void:
	t.start("R12 Part F case 4: a Tribute Summoned monster temporarily banished by a REAL "
		+ "pool card and returned is still a legal target (Q&A fid 11352)")
	var d := _board_with_tribute_summon(t, 1616)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	var transporter_def := _card("Interdimensional Matter Transporter")
	t.not_null(transporter_def, "the pool's temporary-banish Trap is available")
	if transporter_def == null:
		return
	var transporter := TestFixtures.give_set_spell_trap(engine, 0, transporter_def)

	t.is_true(TestFixtures.activate_card(engine, 0, transporter, [monarch.id]),
		"it banishes the Monarch until the End Phase")
	t.eq(monarch.zone, Enums.Zone.BANISHED, "which really happened")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"the End Phase arrives")
	t.eq(monarch.zone, Enums.Zone.MONSTER_ZONE, "and the Monarch comes back")
	t.is_true(monarch.was_tribute_summoned(), "still treated as Tribute Summoned")
	t.is_true(_targets(engine, d["trap"]).has(monarch.id),
		"so the Trap can still target it")


static func _test_a_monster_that_left_the_field_is_not(t: TestCase) -> void:
	t.start("a monster that left the field PERMANENTLY and came back was not Tribute "
		+ "Summoned — R12 Part F case 5")
	var d := _board_with_tribute_summon(t, 1617)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]

	var bouncer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Bouncer", monarch, "bounce"))
	t.is_true(TestFixtures.activate_card(engine, 0, bouncer),
		"it is returned to the hand")
	t.eq(monarch.zone, Enums.Zone.HAND, "which really happened")
	t.is_false(monarch.was_tribute_summoned(), "and the property is gone")
	t.eq(_targets(engine, d["trap"]).size(), 0, "so there is no legal target")


static func _test_no_legal_target_means_no_activation(t: TestCase) -> void:
	t.start("with no legal target the card cannot be activated at all")
	var d := _board(1618)
	var engine: DuelEngine = d["engine"]
	t.is_null(_offered(engine, d["trap"]),
		"an empty board offers nothing, though the Extra Deck condition is satisfied")
	t.is_true(engine.state.player(0).extra_deck.is_empty(),
		"and the Extra Deck really is empty, so it was the target that was missing")


# ---------------------------------------------------------------------------
# The Extra Deck condition — R12 Part G
# ---------------------------------------------------------------------------

static func _test_a_non_empty_extra_deck_forbids_the_activation(t: TestCase) -> void:
	t.start("R12 Part G: 'If you have no cards in your Extra Deck' really gates the "
		+ "activation — tested SYNTHETICALLY, because both V1 decks have empty Extra "
		+ "Decks and it is never false in the pool (the R1 shape)")
	var d := _board_with_tribute_summon(t, 1620)
	var engine: DuelEngine = d["engine"]
	t.not_null(_offered(engine, d["trap"]), "with an empty Extra Deck it is offered")

	var intruder := CardInstance.new(TestFixtures.monster("Extra", 4, 1000, 1000), 0)
	engine.state.register_instance(intruder)
	intruder.zone = Enums.Zone.EXTRA_DECK
	engine.state.player(0).extra_deck.append(intruder)
	t.is_null(_offered(engine, d["trap"]),
		"one card in your Extra Deck forbids the activation")

	engine.state.player(0).extra_deck.clear()
	t.not_null(_offered(engine, d["trap"]),
		"and emptying it again restores the activation — so it was the Extra Deck")


static func _test_an_empty_extra_deck_allows_it(t: TestCase) -> void:
	t.start("the OPPONENT's Extra Deck is not asked about — 'YOUR Extra Deck'")
	var d := _board_with_tribute_summon(t, 1621)
	var engine: DuelEngine = d["engine"]
	var intruder := CardInstance.new(TestFixtures.monster("Extra", 4, 1000, 1000), 1)
	engine.state.register_instance(intruder)
	intruder.zone = Enums.Zone.EXTRA_DECK
	engine.state.player(1).extra_deck.append(intruder)
	t.not_null(_offered(engine, d["trap"]),
		"a card in the OPPONENT's Extra Deck does not forbid it")


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

static func _test_it_negates_and_wards_the_target(t: TestCase) -> void:
	t.start("both clauses apply: the effects are negated AND the monster is warded")
	var d := _board_with_tribute_summon(t, 1630)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	t.is_false(monarch.effects_are_negated(), "not negated before")
	t.is_false(monarch.unaffected_by_effects, "and not warded before")

	t.is_true(_activate(engine, d["trap"], monarch), "the Trap resolves")
	t.is_true(monarch.effects_are_negated(), "its effects are negated")
	t.is_true(monarch.unaffected_by_effects, "and it is unaffected by other cards")


static func _test_the_immunity_exempts_this_card(t: TestCase) -> void:
	t.start("R12 Part D: the exemption names THIS Trap, which is what lets the negation "
		+ "it applied survive the immunity it applied")
	var d := _board_with_tribute_summon(t, 1631)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	var trap: CardInstance = d["trap"]
	t.is_true(_activate(engine, trap, monarch), "the Trap resolves")

	t.eq(monarch.unaffected_exempt_source_ids, [trap.id],
		"the exempt source is this Trap instance and nothing else")
	t.is_false(monarch.is_unaffected_by_effect_of(trap.id), "which is therefore exempt")
	var stranger := TestFixtures.give(engine, 1, TestFixtures.trap("Stranger"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.is_true(monarch.is_unaffected_by_effect_of(stranger.id),
		"while every other card is refused")


static func _test_both_states_outlive_the_trap(t: TestCase) -> void:
	t.start("R12 Part D: the Trap is in the Graveyard the moment it resolves, and both "
		+ "states carry on regardless — 「モンスターゾーンに表側表示で存在する限り」")
	var d := _board_with_tribute_summon(t, 1632)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	var trap: CardInstance = d["trap"]
	t.is_true(_activate(engine, trap, monarch), "the Trap resolves")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD, "and is already in the Graveyard")

	engine.continuous.recompute()
	t.is_true(monarch.effects_are_negated(),
		"a continuous recompute does not wipe the negation — it is not a continuous flag")
	t.is_true(monarch.unaffected_by_effects, "nor the immunity")

	t.is_true(TestFixtures.end_turn(engine), "the turn passes")
	t.is_true(TestFixtures.end_turn(engine), "and comes back")
	t.is_true(monarch.effects_are_negated(), "still negated two turns later")
	t.is_true(monarch.unaffected_by_effects, "and still warded")


static func _test_a_face_down_target_at_resolution_applies_neither_clause(
		t: TestCase) -> void:
	t.start("R12 Part E: 「処理時に、対象のモンスターが裏側守備表示の場合」 — the target "
		+ "flipped face-down before resolution gets NEITHER clause, and the Trap is spent")
	var d := _board_with_tribute_summon(t, 1633)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	var trap: CardInstance = d["trap"]
	# The flip must land on a real Chain Link ABOVE this card, not by poking the board after
	# `submit_action()` has already resolved it — that version of this test passed whatever
	# the card did, because `on_flipped_face_down()` would have wiped the states afterwards
	# regardless. Chain Link 2 resolves first, so Chain Link 1 genuinely finds a face-down
	# target.
	var veil := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Veil", monarch, "flip_face_down"))

	var action = _offered(engine, trap)
	t.not_null(action, "the Trap is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [monarch.id]})),
		"and activated as Chain Link 1, targeting the face-up Monarch")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, veil.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response),
		"and flips the target face-down as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.is_true(monarch.is_face_down(), "the target is face-down when Chain Link 1 resolves")
	t.is_false(monarch.effects_are_negated(), "its effects are NOT negated")
	t.is_false(monarch.unaffected_by_effects, "and it is NOT warded")
	t.eq(trap.zone, Enums.Zone.GRAVEYARD,
		"but the Trap was spent all the same — it resolved and did nothing")


static func _test_a_normal_monster_target_is_still_warded(t: TestCase) -> void:
	t.start("R12 Part G: targeting a Normal Monster still wards it, though the negation "
		+ "has nothing to negate — 「その場合でも、…効果を受けなくなります」")
	var vanilla := _card("Metaphys Armed Dragon")
	t.not_null(vanilla, "the pool's Level 7 vanilla is available")
	if vanilla == null:
		return
	var d := _board_with_tribute_summon(t, 1634, vanilla, 2)
	var engine: DuelEngine = d["engine"]
	var mon: CardInstance = d["monarch"]
	t.is_true(_activate(engine, d["trap"], mon), "the Trap resolves on the vanilla")
	t.is_true(mon.unaffected_by_effects, "it is unaffected by other cards")
	t.is_true(mon.effects_are_negated(),
		"and the negation is still recorded, vacuous though it is on a vanilla")


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

static func _test_the_warded_monster_resists_a_real_pool_card(t: TestCase) -> void:
	t.start("a warded monster is untouched by a REAL pool removal card, and the same "
		+ "card removes an unwarded monster in the same duel")
	var d := _board_with_tribute_summon(t, 1640)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1200, 1200))
	t.is_true(_activate(engine, d["trap"], monarch), "the Monarch is warded")

	var ced_def := _card("Compulsory Evacuation Device")
	t.not_null(ced_def, "the pool's bounce Trap is available")
	if ced_def == null:
		return
	var ced := TestFixtures.give_set_spell_trap(engine, 0, ced_def)
	t.is_true(TestFixtures.activate_card(engine, 0, ced, [monarch.id]),
		"it is activated on the warded Monarch and resolves")
	t.eq(monarch.zone, Enums.Zone.MONSTER_ZONE, "which does nothing")

	var ced2 := TestFixtures.give_set_spell_trap(engine, 0, ced_def)
	t.is_true(TestFixtures.activate_card(engine, 0, ced2, [bystander.id]),
		"the same card is activated on the unwarded bystander")
	t.eq(bystander.zone, Enums.Zone.HAND,
		"and bounces it — so the first refusal was the ward, not a broken arrangement")


static func _test_the_warded_monster_is_still_destroyed_by_battle(t: TestCase) -> void:
	t.start("battle is not a card effect, so the ward does not stop it (Q&A fid 18199)")
	var d := _board_with_tribute_summon(t, 1641)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	t.is_true(_activate(engine, d["trap"], monarch), "the Monarch is warded")

	var attacker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Bigger", 8, 3000, 2500))
	t.is_true(TestFixtures.end_turn(engine), "the turn passes to the opponent")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"who reaches their Battle Phase")
	t.is_true(TestFixtures.attack(engine, attacker, monarch), "and attacks the Monarch")
	TestFixtures.pass_until_open(engine)

	t.eq(monarch.zone, Enums.Zone.GRAVEYARD, "the Monarch is destroyed by battle")
	t.eq(monarch.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE,
		"with the battle reason")


static func _test_the_states_end_when_the_monster_leaves_the_field(t: TestCase) -> void:
	t.start("R12 Part E: both states end when the monster leaves the Monster Zone")
	var d := _board_with_tribute_summon(t, 1642)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	t.is_true(_activate(engine, d["trap"], monarch), "the Monarch is warded")

	# Tributed — a cost, which the ward does not block.
	var bigger := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Bigger Monarch", 6, 2500, 1000))
	t.is_true(TestFixtures.end_turn(engine), "the turn passes")
	t.is_true(TestFixtures.end_turn(engine), "and comes back")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"reaching Main Phase 1")
	t.is_true(_tribute_summon(t, engine, bigger, monarch),
		"the warded Monarch is Tributed — a cost, not an effect")
	t.eq(monarch.zone, Enums.Zone.GRAVEYARD, "it left the field")
	t.is_false(monarch.unaffected_by_effects, "the ward is gone")
	t.is_false(monarch.effects_negated, "and so is the negation")


static func _test_activation_negated(t: TestCase) -> void:
	t.start("if the activation is negated, neither clause applies")
	var d := _board_with_tribute_summon(t, 1643)
	var engine: DuelEngine = d["engine"]
	var monarch: CardInstance = d["monarch"]
	var trap: CardInstance = d["trap"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))

	var action = _offered(engine, trap)
	t.not_null(action, "the Trap is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [monarch.id]})),
		"and activated")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can negate the activation")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "and does")
	TestFixtures.pass_until_open(engine)

	t.is_false(monarch.effects_are_negated(), "the Monarch's effects are not negated")
	t.is_false(monarch.unaffected_by_effects, "and it is not warded")


# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

static func _test_the_same_seed_replays_identically(t: TestCase) -> void:
	t.start("the same seed and the same actions reach the same state, event for event")
	var results: Array = []
	for run in range(2):
		var d := TestFixtures.new_duel(1650, 0)
		var engine: DuelEngine = d["engine"]
		TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
		var trap := TestFixtures.give_set_spell_trap(engine, 0, _def())
		var fodder := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Fodder", 4, 1000, 1000))
		var monarch := TestFixtures.give_to_hand(engine, 0,
			TestFixtures.monster("Monarch", 6, 2400, 1000))
		var summon = TestFixtures.find_action(engine.get_legal_actions(0),
			Enums.ActionKind.TRIBUTE_SUMMON, monarch.id)
		if summon != null:
			engine.submit_action(summon.with_choices({"tribute_ids": [fodder.id]}))
			TestFixtures.pass_until_open(engine)
		_activate(engine, trap, monarch)
		results.append({
			"negated": monarch.effects_are_negated(),
			"warded": monarch.unaffected_by_effects,
			"exempt": monarch.unaffected_exempt_source_ids.size(),
			"trap_zone": trap.zone,
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["negated"], results[1]["negated"], "the negation matches")
	t.eq(results[0]["warded"], results[1]["warded"], "the ward matches")
	t.eq(results[0]["exempt"], results[1]["exempt"], "the exemption record matches")
	t.eq(results[0]["trap_zone"], results[1]["trap_zone"], "the Trap's zone matches")
	t.eq(results[0]["events"], results[1]["events"], "and the event count matches")
	t.is_true(bool(results[0]["warded"]),
		"and the run was not vacuous — the card really did resolve")

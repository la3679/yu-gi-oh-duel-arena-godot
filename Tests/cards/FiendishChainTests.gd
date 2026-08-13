class_name FiendishChainTests
extends RefCounted

## Per-card suite for `Fiendish Chain` — Continuous Trap.
##
##   "Activate this card by targeting 1 Effect Monster on the field; negate the effects of
##    that face-up monster while it is on the field, also that face-up monster cannot
##    attack. When it is destroyed, destroy this card."
##
## This is the pool's first CONTINUOUS NEGATION, and it is the reason
## `ContinuousEffects.recompute()` now runs in two passes: a negation has to be applied
## before anything asks "is this source negated?", or the answer depends on the order the
## board happens to be iterated in. `_test_a_negated_continuous_effect` is the assertion
## that pins that down, and it uses a monster whose own effect is CONTINUOUS on purpose.

const CARD_UNDER_TEST := "Fiendish Chain"

const KAIBAMAN_EFFECT := "tribute_self_summon_blue_eyes"


static func run() -> TestCase:
	var t := TestCase.new("FiendishChainTests")
	_test_clause_shape(t)
	_test_the_target_filter(t)
	_test_it_negates_an_activated_effect(t)
	_test_a_negated_continuous_effect(t)
	_test_the_negated_monster_cannot_attack(t)
	_test_the_negation_ends_when_this_card_leaves(t)
	_test_the_negation_ends_when_the_monster_is_flipped_face_down(t)
	_test_the_monster_being_destroyed_destroys_this_card(t)
	_test_the_monster_being_banished_does_not(t)
	_test_a_target_that_left_before_resolution(t)
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


## A synthetic Effect Monster whose ONLY effect is continuous: it gives itself +1000 ATK.
## Used to prove the negation reaches continuous effects and not just activated ones.
static func _self_buffing_monster(card_name: String) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, 1000, 1000)
	var e := EffectDef.new("self_buff", "This card gains 1000 ATK.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		ContinuousEffects.add_atk(ctx.source, ctx.source, 1000)
	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three EffectDefs: the targeting activation, the continuous application, and "
		+ "the self-destruction")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.CONTINUOUS_TRAP, "a Continuous Trap")
	t.eq(def.effects.size(), 3, "activation + continuous + trigger")

	var activation: EffectDef = def.effects[0]
	t.eq(activation.effect_type, Enums.EffectType.CARD_ACTIVATION, "the card's activation")
	t.eq(activation.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2")
	t.is_true(activation.targets, "'Activate this card BY TARGETING' fixes it at activation")
	t.eq(activation.target_count_min, 1, "exactly one monster")

	var continuous: EffectDef = def.effects[1]
	t.eq(continuous.effect_type, Enums.EffectType.CONTINUOUS,
		"the negation and the attack lock are a continuous effect")
	t.is_false(continuous.starts_chain, "so it never starts a Chain")
	t.is_true(continuous.negates_effects,
		"and it declares that it negates, so the recompute applies it first")
	t.is_true(continuous.apply_continuous.is_valid(), "with a real apply_continuous()")

	var destroy_self: EffectDef = def.effects[2]
	t.eq(destroy_self.effect_type, Enums.EffectType.TRIGGER, "the third clause triggers")
	t.eq(destroy_self.optionality, Enums.Optionality.MANDATORY,
		"'destroy this card' with no 'You can' is mandatory")
	t.eq(destroy_self.trigger_events, [GameEvent.Kind.CARD_DESTROYED],
		"'When it IS DESTROYED' — destruction, not leaving the field")
	t.eq(destroy_self.damage_step_permission,
		Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"the negated monster is most often destroyed by battle [S1 p.41]")


# ---------------------------------------------------------------------------
# Targeting
# ---------------------------------------------------------------------------

static func _test_the_target_filter(t: TestCase) -> void:
	t.start("'1 EFFECT Monster on the field' — face-up, an Effect Monster, either player's")
	var d := _main_phase_duel(9201)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	var mine := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _card("Shining Angel"))
	var vanilla := TestFixtures.give_monster_on_field(engine, 0, _card("Sabersaurus"))
	var face_down := TestFixtures.give_monster_on_field(engine, 1,
		_card("Mirage Dragon"), Enums.Position.FACE_DOWN_DEFENSE)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, chain.id)
	t.not_null(action, "Fiendish Chain is offered")
	t.is_true(action.target_candidates.has(mine.id),
		"your own Effect Monster is a legal target — 'on the field' is both sides")
	t.is_true(action.target_candidates.has(theirs.id),
		"and so is the opponent's")
	t.is_false(action.target_candidates.has(vanilla.id),
		"a NORMAL Monster is not an Effect Monster")
	t.is_false(action.target_candidates.has(face_down.id),
		"and a FACE-DOWN monster is not a legal target: whether it is an Effect Monster is "
		+ "not something either player may act on")
	t.eq(action.target_candidates.size(), 2, "exactly the two face-up Effect Monsters")

	t.is_false(engine.submit_action(action.with_choices({"target_ids": [vanilla.id]})),
		"a hand-built activation on the Normal Monster is rejected")


# ---------------------------------------------------------------------------
# The negation
# ---------------------------------------------------------------------------

static func _test_it_negates_an_activated_effect(t: TestCase) -> void:
	t.start("'negate the effects of that face-up monster' — its Ignition Effect stops "
		+ "being offered at all")
	var d := _main_phase_duel(9202)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	TestFixtures.give_to_hand(engine, 0, _card("Blue-Eyes White Dragon"))

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, KAIBAMAN_EFFECT),
		"Kaibaman's effect is available before the negation — the positive control")

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [kaibaman.id]),
		"Fiendish Chain is activated targeting Kaibaman")
	t.eq(chain.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Continuous Trap stays face-up on the field [S1 p.29-30]")
	t.is_true(kaibaman.effects_are_negated(), "the monster's effects are negated")
	t.is_false(kaibaman.effects_negated,
		"through the continuous channel, not by overwriting the one-shot flag")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id, KAIBAMAN_EFFECT),
		"and its effect is no longer offered")

	var forged := DuelAction.make(Enums.ActionKind.ACTIVATE_EFFECT, 0, kaibaman.id,
		KAIBAMAN_EFFECT)
	t.is_false(engine.submit_action(forged), "a hand-built activation is rejected too")
	t.eq(kaibaman.zone, Enums.Zone.MONSTER_ZONE,
		"and nothing was Tributed — the cost was never reached")


static func _test_a_negated_continuous_effect(t: TestCase) -> void:
	t.start("the negation reaches CONTINUOUS effects, whichever order the board is walked "
		+ "in — the two-pass recompute")
	var d := _main_phase_duel(9203)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var buffed := TestFixtures.give_monster_on_field(engine, 1,
		_self_buffing_monster("Test Self Buffer"))

	# Continuous effects are recomputed by the engine at every timing point; this board was
	# arranged directly, so the baseline needs one explicit recompute to be meaningful.
	var baseline := ContinuousEffects.new(engine.state)
	baseline.recompute()
	t.eq(buffed.current_atk(), 2000, "1000 printed + its own continuous 1000")

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [buffed.id]),
		"Fiendish Chain is activated targeting it")
	t.is_true(buffed.effects_are_negated(), "its effects are negated")
	t.eq(buffed.current_atk(), 1000,
		"so its own continuous effect no longer applies and it is back to printed ATK")
	t.eq(buffed.atk_modifiers.size(), 0, "with no stale modifier left behind")

	# Five recomputes must give the same answer as one — the negation is state-derived and
	# must not accumulate or oscillate.
	var continuous := ContinuousEffects.new(engine.state)
	for i in range(5):
		continuous.recompute()
	t.is_true(buffed.effects_are_negated(), "still negated after five recomputes")
	t.eq(buffed.current_atk(), 1000, "and still at printed ATK")


static func _test_the_negated_monster_cannot_attack(t: TestCase) -> void:
	t.start("'also that face-up monster cannot attack'")
	# Player 1 goes first so player 0 may conduct a Battle Phase from turn 2 [S1 p.37].
	var d := TestFixtures.battle_duel(9204)
	var engine: DuelEngine = d["engine"]

	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var locked := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	var free := TestFixtures.give_monster_on_field(engine, 0, _card("Sabersaurus"))

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, locked.id),
		"before the lock, the Effect Monster may attack")

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [locked.id]),
		"Fiendish Chain is activated on it in the Battle Step")

	t.is_true(bool(locked.flags.get("cannot_attack", false)),
		"the restriction flag is on the monster")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, locked.id),
		"and the attack is no longer offered")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, free.id),
		"while the other monster attacks freely — a positive control")
	t.is_false(TestFixtures.attack(engine, locked, null),
		"a hand-built attack declaration is refused")


static func _test_the_negation_ends_when_this_card_leaves(t: TestCase) -> void:
	t.start("'while it is on the field' cuts both ways — destroy Fiendish Chain and the "
		+ "monster is itself again")
	var d := _main_phase_duel(9205)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var buffed := TestFixtures.give_monster_on_field(engine, 1,
		_self_buffing_monster("Test Self Buffer"))

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [buffed.id]), "it is negated")
	t.eq(buffed.current_atk(), 1000, "and drained")

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", chain, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Fiendish Chain")

	t.eq(chain.zone, Enums.Zone.GRAVEYARD, "the Trap left the field")
	t.is_false(buffed.effects_are_negated(), "the negation lifted with its source")
	t.eq(buffed.current_atk(), 2000, "and the monster's own effect applies again")
	t.is_false(bool(buffed.flags.get("cannot_attack", false)),
		"the attack lock lifted too — the two are one clause")


static func _test_the_negation_ends_when_the_monster_is_flipped_face_down(t: TestCase) -> void:
	t.start("'that FACE-UP monster' — flipping it face-down stops the clause applying, "
		+ "without destroying anything")
	var d := _main_phase_duel(9206)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 1,
		_self_buffing_monster("Test Self Buffer"))

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [monster.id]), "it is negated")
	t.is_true(monster.effects_are_negated(), "negated while face-up")

	var flipper := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Flipper", monster, "flip_face_down"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, flipper),
		"a card effect turns the monster face-down")

	t.is_true(monster.is_face_down(), "the monster is face-down")
	t.is_false(monster.effects_are_negated(),
		"the clause no longer applies to it — it is not a 'face-up monster'")
	t.eq(chain.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"and Fiendish Chain is NOT destroyed: being flipped face-down is not being "
		+ "destroyed [S1 p.52-53]")


# ---------------------------------------------------------------------------
# "When it is destroyed, destroy this card"
# ---------------------------------------------------------------------------

static func _test_the_monster_being_destroyed_destroys_this_card(t: TestCase) -> void:
	t.start("'When it IS DESTROYED, destroy this card'")
	var d := _main_phase_duel(9207)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 1, _card("Kaibaman"))

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [monster.id]), "it is negated")

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", monster, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys the negated monster")

	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "the monster is in the Graveyard")
	t.eq(chain.zone, Enums.Zone.GRAVEYARD, "and Fiendish Chain destroyed itself")
	t.eq(engine.state.recall(chain, EffectPrimitives.AFFLICTED_MONSTER_KEY, -1), -1,
		"the link is cleared, so nothing can fire twice")


static func _test_the_monster_being_banished_does_not(t: TestCase) -> void:
	t.start("a negated monster that is BANISHED leaves Fiendish Chain on the field — "
		+ "'is destroyed' is narrower than 'leaves the field' [S1 p.52-53]")
	var d := _main_phase_duel(9208)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 1,
		_self_buffing_monster("Test Self Buffer"))

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [monster.id]), "it is negated")

	var banisher := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Banisher", monster, "banish"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, banisher),
		"a card effect banishes the negated monster")

	t.eq(monster.zone, Enums.Zone.BANISHED, "the monster left the field")
	t.is_false(Enums.is_destruction(Enums.MoveReason.BANISHED), "but was not destroyed")
	t.eq(chain.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"so Fiendish Chain stays face-up on the field with nothing to negate")
	t.is_false(monster.effects_are_negated(),
		"and the negation does not follow it off the field")


static func _test_a_target_that_left_before_resolution(t: TestCase) -> void:
	t.start("a target removed between activation and resolution attaches nothing, and the "
		+ "Trap stays on the field doing nothing")
	var d := _main_phase_duel(9209)
	var engine: DuelEngine = d["engine"]
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var monster := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	var banisher := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Banisher", monster, "banish"), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, chain.id)
	t.not_null(offered, "Fiendish Chain is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [monster.id]})),
		"and activated as Chain Link 1")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, banisher.id)
	t.not_null(response, "the opponent may respond with a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response), "banishing the target as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(monster.zone, Enums.Zone.BANISHED,
		"Chain Link 2 resolved first and removed the target [S1 p.46-47]")
	t.eq(chain.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"a Continuous Trap still stays on the field after resolving to nothing")
	t.eq(engine.state.recall(chain, EffectPrimitives.AFFLICTED_MONSTER_KEY, -1), -1,
		"and it is attached to nothing, rather than holding a stale reference")

class_name HieraticDragonOfTefnuitTests
extends RefCounted

## Per-card suite for `Hieratic Dragon of Tefnuit` — the first card in the library that
## uses a summoning PROCEDURE.
##
##   "If only your opponent controls a monster, you can Special Summon this card (from
##    your hand). Cannot attack during the turn it is Special Summoned this way. When
##    this card is Tributed: Special Summon 1 Dragon Normal Monster from your hand, Deck,
##    or GY, and make its ATK/DEF 0."
##
## The load-bearing assertions are that the first clause is NOT an activated effect — it
## starts no Chain and is offered as `SPECIAL_SUMMON_PROCEDURE` (PROJECT_STATE.md design
## decision 9) — and that "this way" really is narrower than "Special Summoned"
## (CARD_RULINGS.md §2.1).

const CARD_UNDER_TEST := "Hieratic Dragon of Tefnuit"

const PROCEDURE_ID := "ss_if_only_opponent_controls_a_monster"


static func run() -> TestCase:
	var t := TestCase.new("HieraticDragonOfTefnuitTests")
	_test_clause_shape(t)
	_test_the_procedure_summons_from_the_hand(t)
	_test_the_procedure_is_not_an_activation(t)
	_test_only_your_opponent_controls_a_monster(t)
	_test_cannot_attack_the_turn_summoned_this_way(t)
	_test_a_copy_summoned_another_way_may_attack(t)
	_test_the_tribute_trigger(t)
	_test_the_tribute_trigger_filter(t)
	_test_destroyed_rather_than_tributed(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


## A duel in Main Phase 1 of player 0's SECOND turn, so player 0 may also attack.
static func _second_turn_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	TestFixtures.end_turn(d["engine"])
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _procedure_action(engine: DuelEngine, pid: int, card: CardInstance):
	return TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, card.id, PROCEDURE_ID)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses: a summoning procedure, a continuous restriction and "
		+ "a Trigger Effect")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var procedure: EffectDef = def.effects[0]
	t.eq(procedure.effect_type, Enums.EffectType.SUMMON_PROCEDURE,
		"'you can Special Summon this card' is a PROCEDURE, not an activated effect "
		+ "[S1 p.53]")
	t.is_false(procedure.starts_chain,
		"so it starts no Chain and cannot be responded to as an activation")
	t.eq(procedure.activation_locations, [Enums.ActivationLocation.HAND],
		"'(from your hand)' — from nowhere else")

	var restriction: EffectDef = def.effects[1]
	t.eq(restriction.effect_type, Enums.EffectType.CONTINUOUS,
		"'Cannot attack …' is a continuous restriction")
	t.is_false(restriction.starts_chain, "which never starts a Chain either")

	var trigger: EffectDef = def.effects[2]
	t.eq(trigger.effect_type, Enums.EffectType.TRIGGER, "'When this card is Tributed:'")
	t.eq(trigger.optionality, Enums.Optionality.MANDATORY,
		"no 'You can', so it is mandatory")
	t.is_false(trigger.targets,
		"the text has no 'target', so the monster is chosen at RESOLUTION "
		+ "(RULES_SPEC.md 10)")
	t.eq(trigger.trigger_events, [GameEvent.Kind.CARD_TRIBUTED],
		"and it listens for a Tribute specifically")


# ---------------------------------------------------------------------------
# The procedure
# ---------------------------------------------------------------------------

static func _test_the_procedure_summons_from_the_hand(t: TestCase) -> void:
	t.start("with only the opponent controlling a monster it Special Summons itself from "
		+ "the hand")
	var d := _second_turn_duel(7401)
	var engine: DuelEngine = d["engine"]

	var tefnuit := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))

	var action = _procedure_action(engine, 0, tefnuit)
	t.not_null(action, "the summoning procedure is offered")
	t.is_true(engine.submit_action(action), "and performed")
	TestFixtures.pass_until_open(engine)

	t.eq(tefnuit.zone, Enums.Zone.MONSTER_ZONE, "it reached a Monster Zone")
	t.eq(tefnuit.summoned_by, Enums.SummonKind.SPECIAL, "as a Special Summon")
	t.is_true(tefnuit.properly_special_summoned, "properly Special Summoned")
	t.eq(tefnuit.summoned_by_procedure_id, PROCEDURE_ID,
		"and it recorded WHICH procedure did it, so 'this way' is answerable")
	t.eq(tefnuit.current_atk(), 2100, "at its printed 2100 ATK")
	t.is_true(engine.state.player(0).can_normal_summon(),
		"and the Normal Summon is untouched [S1 p.24]")


static func _test_the_procedure_is_not_an_activation(t: TestCase) -> void:
	t.start("the procedure is never offered as an activation and never becomes a Chain Link")
	var d := _second_turn_duel(7402)
	var engine: DuelEngine = d["engine"]

	var tefnuit := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))

	var actions := engine.get_legal_actions(0)
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.ACTIVATE_EFFECT,
		tefnuit.id), "it is not an ACTIVATE_EFFECT")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.ACTIVATE_CARD,
		tefnuit.id), "and not an ACTIVATE_CARD")
	t.is_false(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, tefnuit.id),
		"nor is it a fast effect that could be used in a response window")

	var before := TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED)
	t.is_true(engine.submit_action(_procedure_action(engine, 0, tefnuit)),
		"the procedure is performed")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED), before,
		"no Chain Link was created by it")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED), 1,
		"but the Summon WAS declared — the declaration window still opens, so a Summon "
		+ "negation can answer it")


static func _test_only_your_opponent_controls_a_monster(t: TestCase) -> void:
	t.start("'if ONLY your opponent controls a monster' is both halves of a condition")
	var d := _second_turn_duel(7403)
	var engine: DuelEngine = d["engine"]
	var tefnuit := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_null(_procedure_action(engine, 0, tefnuit),
		"with an empty board the opponent controls no monster, so it is not offered")

	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))
	t.not_null(_procedure_action(engine, 0, tefnuit),
		"once they control one, it is offered")

	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Monster", 4, 1000, 1000))
	t.is_null(_procedure_action(engine, 0, tefnuit),
		"but not while YOU also control one — 'only' means only")

	engine.state.move_card(mine, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.not_null(_procedure_action(engine, 0, tefnuit),
		"and it comes back once your side is empty again")

	engine.state.set_battle_position(theirs, Enums.Position.FACE_DOWN_DEFENSE, true)
	t.not_null(_procedure_action(engine, 0, tefnuit),
		"a FACE-DOWN monster is still a monster they control [S1 p.53]")

	t.is_false(engine.submit_action(DuelAction.make(
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, 0, tefnuit.id, "not_a_real_procedure")),
		"and a hand-built action naming an effect this card does not have is rejected")


# ---------------------------------------------------------------------------
# "…this way"
# ---------------------------------------------------------------------------

static func _test_cannot_attack_the_turn_summoned_this_way(t: TestCase) -> void:
	t.start("'Cannot attack during the turn it is Special Summoned this way'")
	var d := _second_turn_duel(7404)
	var engine: DuelEngine = d["engine"]

	var tefnuit := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))
	t.is_true(engine.submit_action(_procedure_action(engine, 0, tefnuit)),
		"Tefnuit Special Summons itself")
	TestFixtures.pass_until_open(engine)

	# A second attacker that was already on the field is the positive control: it proves
	# the Battle Phase itself is fine and only Tefnuit is restricted.
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Free Attacker", 4, 1000, 1000))

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	engine.continuous.recompute()
	t.is_true(bool(tefnuit.flags.get("cannot_attack", false)),
		"the continuous restriction is applied to it")
	var actions := engine.get_legal_actions(0)
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.DECLARE_ATTACK, tefnuit.id),
		"so no attack is offered for Tefnuit")
	t.is_true(TestFixtures.has_action(actions, Enums.ActionKind.DECLARE_ATTACK, other.id),
		"while the other monster attacks perfectly normally")
	t.is_false(TestFixtures.attack(engine, tefnuit, null),
		"and a hand-built attack declaration for it is refused")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	engine.continuous.recompute()
	t.is_false(bool(tefnuit.flags.get("cannot_attack", false)),
		"the restriction is only for THAT turn")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, tefnuit.id),
		"so on a later turn it may attack")


static func _test_a_copy_summoned_another_way_may_attack(t: TestCase) -> void:
	t.start("'this way' is narrower than 'Special Summoned': a copy revived by Monster "
		+ "Reborn attacks on the same turn (CARD_RULINGS.md §2.1)")
	var d := _second_turn_duel(7405)
	var engine: DuelEngine = d["engine"]

	var tefnuit := TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	t.is_true(TestFixtures.activate_card(engine, 0, reborn, [tefnuit.id]),
		"Monster Reborn revives Tefnuit")
	t.eq(tefnuit.zone, Enums.Zone.MONSTER_ZONE, "it is on the field")
	t.eq(tefnuit.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.eq(tefnuit.summoned_by_procedure_id, "",
		"but NOT by its own procedure, which is what 'this way' asks about")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	engine.continuous.recompute()
	t.is_false(bool(tefnuit.flags.get("cannot_attack", false)),
		"so no attack restriction applies")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, tefnuit.id), "and it may attack")


# ---------------------------------------------------------------------------
# The Tribute trigger
# ---------------------------------------------------------------------------

## Normal Summon a Level 6 synthetic monster by Tributing `victim`.
static func _tribute_summon_over(engine: DuelEngine, pid: int,
		victim: CardInstance) -> bool:
	var eater := TestFixtures.give_to_hand(engine, pid,
		TestFixtures.monster("Tribute Eater", 6, 2000, 2000))
	var action = TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.TRIBUTE_SUMMON, eater.id)
	if action == null:
		return false
	if not engine.submit_action(action.with_choices({"tribute_ids": [victim.id]})):
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _test_the_tribute_trigger(t: TestCase) -> void:
	t.start("'When this card is Tributed: Special Summon 1 Dragon Normal Monster … and "
		+ "make its ATK/DEF 0'")
	var d := _second_turn_duel(7406)
	var engine: DuelEngine = d["engine"]

	var tefnuit := TestFixtures.give_monster_on_field(engine, 0, _def())
	var dragon := TestFixtures.give_to_hand(engine, 0, _card("Blue-Eyes White Dragon"))

	t.is_true(_tribute_summon_over(engine, 0, tefnuit),
		"Tefnuit is Tributed for a Tribute Summon")
	t.eq(tefnuit.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), 0,
		"a Tribute is NOT a destruction [S1 p.53]")

	t.eq(dragon.zone, Enums.Zone.MONSTER_ZONE, "the Dragon Normal Monster was Summoned")
	t.eq(dragon.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.eq(dragon.current_atk(), 0, "with its ATK made 0")
	t.eq(dragon.current_def(), 0, "and its DEF made 0")
	t.eq(dragon.base_atk(), 3000, "while the PRINTED ATK is untouched")
	t.eq(dragon.original_atk(), 3000,
		"so 'original ATK' still reads 3000 [S1 p.55]")


static func _test_the_tribute_trigger_filter(t: TestCase) -> void:
	t.start("'1 DRAGON NORMAL Monster from your hand, Deck, or GY' — all three zones, "
		+ "both halves of the filter, your side only")
	var d := _second_turn_duel(7407)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var tefnuit := TestFixtures.give_monster_on_field(engine, 0, _def())
	var in_hand := TestFixtures.give_to_hand(engine, 0, _card("Luster Dragon"))
	var in_gy := TestFixtures.give(engine, 0, _card("Alexandrite Dragon"),
		Enums.Zone.GRAVEYARD)
	# Neither of these qualifies: a Dragon EFFECT Monster and a Level 7 Normal WYRM.
	TestFixtures.give_to_hand(engine, 0, _card("Mirage Dragon"))
	TestFixtures.give_to_hand(engine, 0, _card("Metaphys Armed Dragon"))
	# Nor does one the OPPONENT holds.
	TestFixtures.give_to_hand(engine, 1, _card("Rabidragon"))

	controller.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [in_gy.id])
	t.is_true(_tribute_summon_over(engine, 0, tefnuit), "Tefnuit is Tributed")
	t.eq(controller.errors, [],
		"the queued answer went to the prompt this test meant it for")

	var offered: Array = []
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind == Enums.DecisionKind.SELECT_EXACTLY:
			offered = request.options
	t.eq(offered.size(), 2, "exactly two candidates were offered")
	t.is_true(offered.has(in_hand.id), "the Dragon Normal Monster in your hand")
	t.is_true(offered.has(in_gy.id), "and the one in your Graveyard")
	t.eq(in_gy.zone, Enums.Zone.MONSTER_ZONE, "the chosen one was Summoned")
	t.eq(in_hand.zone, Enums.Zone.HAND, "and the other stayed put")


static func _test_destroyed_rather_than_tributed(t: TestCase) -> void:
	t.start("a copy destroyed by a card effect was not TRIBUTED, so the clause does "
		+ "nothing [S1 p.53]")
	var d := _second_turn_duel(7408)
	var engine: DuelEngine = d["engine"]

	var tefnuit := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_to_hand(engine, 0, _card("Blue-Eyes White Dragon"))
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", tefnuit, "destroy"), 0)

	t.is_true(TestFixtures.activate_card(engine, 0, remover), "a card effect destroys it")
	t.eq(tefnuit.zone, Enums.Zone.GRAVEYARD, "it reached the Graveyard all the same")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_TRIBUTED), 0,
		"but nothing was Tributed")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"so no Dragon Normal Monster was Special Summoned")
	t.eq(engine.state.player(0).monster_count(), 0, "and your field is empty")

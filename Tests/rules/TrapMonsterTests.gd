class_name TrapMonsterTests
extends RefCounted

## TRAP MONSTERS — a card whose printed identity is a Trap and whose runtime identity, while
## it occupies a Monster Zone, is a monster. Rules under test: `RULES_SPEC.md §5.8`, `§5.5`,
## `§8`, `§15` [S1 p.53].
##
## This is the **Trap-Monster gate**, written the way `EquipTests`, `ControlTests`,
## `MovementTests`, `BanishTests` and `LifePointCostTests` were: a RULES suite built from
## SYNTHETIC cards, so what it proves is that the ENGINE is right rather than that one printed
## card happens to work. `The Phantom Knights of Shadow Veil` is only implemented once it
## passes.
##
## Three load-bearing claims.
##
## **First: the printed `CardDef` is never touched.** A `CardDef` is the immutable canonical
## definition and is SHARED by every copy of that card, so writing a temporary type line into
## it would rewrite the card for the whole duel and for every other copy. The runtime identity
## lives on the `CardInstance`, and the suite proves it by keeping a second copy of the very
## same `CardDef` in the Graveyard and asserting it never becomes a monster.
##
## **Second: "is it a monster?" and "is it a Trap?" are two questions with two answers, and
## the card's own text decides both.** Phantom Knights prints "(This card is NOT treated as a
## Trap.)", but most printed Trap Monsters stay Traps, so `treated_as_original_type` is
## exercised in both directions rather than assumed.
##
## **Third: the identity is revoked by leaving the Monster Zone, on every route out.**
## Destroyed, banished, returned to the hand, returned to the Deck, sent to the Graveyard,
## tributed, or put back because the Summon was negated — each is asserted separately, because
## a single shared teardown that happened to be wired to only one of them would pass a test
## that checked only that one.
##
## The Summon itself goes through `SummonRules.begin_special_summon()` /
## `complete_summon()` — the ordinary Special Summon route — rather than around it, so it is a
## real Special Summon with real events. That is asserted directly rather than inferred from
## the card having arrived.


static func run() -> TestCase:
	var t := TestCase.new("TrapMonsterTests")
	# What a Trap Monster IS
	_test_a_trap_in_the_graveyard_is_not_a_monster(t)
	_test_the_summon_grants_a_runtime_monster_identity(t)
	_test_the_shared_printed_carddef_is_never_mutated(t)
	_test_the_type_line_really_comes_from_the_effect(t)
	_test_whether_it_is_still_a_trap_is_what_the_text_says(t)
	# Where it lives
	_test_it_occupies_a_monster_zone_and_no_spell_trap_zone(t)
	_test_owner_and_controller(t)
	# The Summon
	_test_it_is_a_real_special_summon_with_real_events(t)
	_test_no_summon_and_no_identity_when_the_monster_zones_are_full(t)
	_test_a_negated_effect_leaves_no_stale_monster_identity(t)
	_test_the_trap_is_not_swept_away_after_summoning_itself(t)
	# Being a monster
	_test_it_is_found_by_a_clause_that_looks_for_monsters(t)
	_test_it_battles_with_its_granted_stats(t)
	_test_continuous_effects_apply_to_it_as_to_any_monster(t)
	_test_control_can_change_and_it_goes_home_to_its_owner(t)
	# Leaving
	_test_every_route_out_of_the_monster_zone_restores_the_trap(t)
	_test_no_stale_runtime_state_survives_the_departure(t)
	# The departure replacement
	_test_banish_when_it_leaves_the_field_redirects_the_destination(t)
	_test_the_redirect_keeps_the_departure_it_replaced(t)
	_test_the_redirect_is_consumed_and_does_not_apply_to_an_unmarked_card(t)
	# Determinism
	_test_the_whole_cycle_is_replay_deterministic(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const EFFECT_ID := "summon_self_as_trap_monster"


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Put a synthetic Trap Monster in player `pid`'s Graveyard and return it.
static func _trap_in_gy(engine: DuelEngine, pid: int, def: CardDef) -> CardInstance:
	return TestFixtures.give(engine, pid, def, Enums.Zone.GRAVEYARD)


## Activate the fixture's Graveyard Ignition and assert the Summon actually happened.
##
## The assertion is the point: every test below that goes on to inspect a Trap Monster would
## otherwise pass vacuously if the activation were never offered, which is exactly the
## false-positive shape batch 8 has now hit twice.
static func _summon(t: TestCase, engine: DuelEngine, pid: int,
		card: CardInstance) -> bool:
	var ok := TestFixtures.activate_effect(engine, pid, card, EFFECT_ID)
	t.check(ok, "the Graveyard Ignition was actually offered and accepted")
	return ok


# ---------------------------------------------------------------------------
# What a Trap Monster IS. RULES_SPEC.md 5.8.
# ---------------------------------------------------------------------------

static func _test_a_trap_in_the_graveyard_is_not_a_monster(t: TestCase) -> void:
	t.start("before it is Summoned, the card is an ordinary Trap: not a monster, no Level, "
		+ "no Attribute, no Type, and no ATK/DEF")
	var d := _duel(9801)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))

	t.check(card.is_trap(), "it is a Trap")
	t.check(not card.is_monster(), "it is not a monster")
	t.check(not card.has_monster_identity(), "it holds no runtime monster identity")
	t.eq(card.current_level(), 0, "no Level")
	t.eq(card.current_attribute(), "", "no Attribute")
	t.eq(card.current_race(), "", "no Type")
	t.eq(card.base_atk(), 0, "no printed ATK")
	t.eq(card.base_def(), 0, "no printed DEF")
	t.eq(card.original_card_category(), Enums.Category.TRAP,
		"and the printed category is TRAP")


static func _test_the_summon_grants_a_runtime_monster_identity(t: TestCase) -> void:
	t.start("Special Summoning it as a monster makes every runtime identity question answer "
		+ "from the granting effect, not from the printed Trap")
	var d := _duel(9802)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return

	t.eq(card.zone, Enums.Zone.MONSTER_ZONE, "it is in a Monster Zone")
	t.check(card.is_monster(), "it is now a monster")
	t.check(card.has_monster_identity(), "it holds a runtime monster identity")
	t.eq(card.current_race(), "Warrior", "Type comes from the effect")
	t.eq(card.current_attribute(), "DARK", "Attribute comes from the effect")
	t.eq(card.current_level(), 4, "Level comes from the effect")
	t.eq(card.base_atk(), 0, "ATK comes from the effect")
	t.eq(card.base_def(), 300, "DEF comes from the effect")
	t.eq(card.current_atk(), 0, "and the current ATK is computed from it")
	t.eq(card.current_def(), 300, "and the current DEF is computed from it")
	t.check(card.is_normal_monster(),
		"summoned 'as a Normal Monster', so it answers as one")
	t.eq(card.position, Enums.Position.FACE_UP_DEFENSE,
		"in the position the clause named")
	# The printed identity is unchanged underneath, which is what makes the card go back to
	# being a Trap when it leaves.
	t.eq(card.original_card_category(), Enums.Category.TRAP,
		"the PRINTED category is still TRAP while it sits there as a monster")


static func _test_the_shared_printed_carddef_is_never_mutated(t: TestCase) -> void:
	t.start("the immutable CardDef is untouched, and a SECOND copy sharing it does not "
		+ "become a monster too")
	var d := _duel(9803)
	var engine: DuelEngine = d["engine"]
	var def := TestFixtures.trap_monster("Veiled Trap")
	var first := _trap_in_gy(engine, 0, def)
	var second := _trap_in_gy(engine, 0, def)
	if not _summon(t, engine, 0, first):
		return

	t.check(first.definition == second.definition,
		"both copies really do share one CardDef — otherwise this test proves nothing")
	t.eq(def.category, Enums.Category.TRAP, "the CardDef is still a Trap")
	t.eq(def.level, 0, "the CardDef's Level was not written")
	t.eq(def.base_atk, 0, "the CardDef's ATK was not written")
	t.eq(def.base_def, 0, "the CardDef's DEF was not written")
	t.eq(def.race, "", "the CardDef's Type was not written")
	t.eq(def.attribute, "", "the CardDef's Attribute was not written")
	t.check(not second.is_monster(),
		"the other copy is still a Trap — the identity is per-instance, not per-definition")
	t.check(not second.has_monster_identity(), "and holds no identity of its own")


static func _test_the_type_line_really_comes_from_the_effect(t: TestCase) -> void:
	t.start("a differently-worded clause grants a different type line — the values are "
		+ "carried, not hard-coded")
	var d := _duel(9804)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Other Veil",
		"Dragon", "WATER", 7, 2400, 1000, false))
	if not _summon(t, engine, 0, card):
		return

	t.eq(card.current_race(), "Dragon", "Type is the one this clause named")
	t.eq(card.current_attribute(), "WATER", "Attribute is the one this clause named")
	t.eq(card.current_level(), 7, "Level is the one this clause named")
	t.eq(card.base_atk(), 2400, "ATK is the one this clause named")
	t.eq(card.base_def(), 1000, "DEF is the one this clause named")
	t.check(not card.is_normal_monster(),
		"and it is not a Normal Monster, because this clause did not say so")


static func _test_whether_it_is_still_a_trap_is_what_the_text_says(t: TestCase) -> void:
	t.start("'(This card is NOT treated as a Trap.)' is a real distinction: a Trap Monster "
		+ "whose text omits it stays a Trap AND is a monster at the same time")
	var d := _duel(9805)
	var engine: DuelEngine = d["engine"]
	# Phantom Knights' shape: not treated as a Trap.
	var not_a_trap := _trap_in_gy(engine, 0,
		TestFixtures.trap_monster("Not A Trap Any More"))
	# The commoner printed shape: still a Trap.
	var still_a_trap := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Still A Trap",
		"Warrior", "DARK", 4, 0, 300, true, true))
	if not _summon(t, engine, 0, not_a_trap):
		return
	if not _summon(t, engine, 0, still_a_trap):
		return

	t.check(not_a_trap.is_monster(), "the first is a monster")
	t.check(not not_a_trap.is_trap(), "and is NOT treated as a Trap, as its text says")
	t.check(still_a_trap.is_monster(), "the second is a monster")
	t.check(still_a_trap.is_trap(),
		"and IS still a Trap, because its text does not say otherwise")
	t.check(not not_a_trap.is_spell() and not still_a_trap.is_spell(),
		"neither is a Spell either way")


# ---------------------------------------------------------------------------
# Where it lives
# ---------------------------------------------------------------------------

static func _test_it_occupies_a_monster_zone_and_no_spell_trap_zone(t: TestCase) -> void:
	t.start("it occupies a MONSTER Zone and no Spell & Trap Zone — the two are not both "
		+ "held, and the Spell & Trap Zone it never used is not consumed")
	var d := _duel(9806)
	var engine: DuelEngine = d["engine"]
	var p := engine.state.player(0)
	var st_free_before := p.free_spell_trap_zone_index()
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return

	t.check(card.zone_index >= 0, "it has a real Monster Zone index")
	t.check(p.monster_zones.has(card), "it is in the Monster Zone array")
	t.check(not p.spell_trap_zones.has(card), "it is in NO Spell & Trap Zone")
	t.eq(p.monster_count(), 1, "it is counted as a monster this player controls")
	t.eq(p.free_spell_trap_zone_index(), st_free_before,
		"and no Spell & Trap Zone was consumed by it")
	t.check(p.monsters().has(card), "PlayerState.monsters() includes it")
	t.check(p.face_up_monsters().has(card), "and so does face_up_monsters()")
	t.check(not p.spell_traps().has(card), "while spell_traps() does not")


static func _test_owner_and_controller(t: TestCase) -> void:
	t.start("owner and controller are the summoning player, and the owner is what decides "
		+ "where it goes when it leaves [S1 p.52]")
	var d := _duel(9807)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return

	t.eq(card.owner_id, 0, "owner is player 0")
	t.eq(card.controller_id, 0, "controller is player 0")
	engine.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.check(engine.state.player(0).graveyard.has(card),
		"and it goes to its OWNER's Graveyard")


# ---------------------------------------------------------------------------
# The Summon. RULES_SPEC.md 5.5.
# ---------------------------------------------------------------------------

static func _test_it_is_a_real_special_summon_with_real_events(t: TestCase) -> void:
	t.start("it goes through the ordinary Special Summon route: both summon events fire for "
		+ "this card, and the per-instance summon record is written")
	var d := _duel(9808)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))

	var declared_before := TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED, card.id)
	var ok_before := TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, card.id)
	if not _summon(t, engine, 0, card):
		return

	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED, card.id), declared_before + 1,
		"exactly one SPECIAL_SUMMON_DECLARED for this card")
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, card.id), ok_before + 1,
		"exactly one SPECIAL_SUMMON_SUCCEEDED for this card")
	t.eq(card.summoned_by, Enums.SummonKind.SPECIAL, "recorded as a Special Summon")
	t.check(card.properly_special_summoned, "and as properly Special Summoned")
	t.eq(card.turn_summoned, engine.state.turn_number, "on this turn")
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED, card.id), 0,
		"and it is not a Normal Summon")


static func _test_no_summon_and_no_identity_when_the_monster_zones_are_full(
		t: TestCase) -> void:
	t.start("with no free Monster Zone the Summon does not happen — and the card is not left "
		+ "sitting in the Graveyard still claiming to be a monster")
	var d := _duel(9809)
	var engine: DuelEngine = d["engine"]
	for i in range(5):
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Blocker %d" % i))
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	t.check(not engine.state.player(0).has_free_monster_zone(),
		"the board really is full — otherwise this test proves nothing")

	TestFixtures.activate_effect(engine, 0, card, EFFECT_ID)

	t.eq(card.zone, Enums.Zone.GRAVEYARD, "it is still in the Graveyard")
	t.check(not card.is_monster(), "it is not a monster")
	t.check(not card.has_monster_identity(), "and holds no stale runtime identity")
	t.check(card.is_trap(), "it is a Trap again, exactly as it was")


static func _test_a_negated_effect_leaves_no_stale_monster_identity(t: TestCase) -> void:
	t.start("when the effect is negated the Summon never happens, and no monster identity "
		+ "is left behind")
	var d := _duel(9810)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	# The negator belongs to the OPPONENT, who answers through get_legal_responses().
	#
	# `any_effect_negator`, not `effect_negator`: the Summon is an IGNITION EFFECT activated
	# from the Graveyard, and `effect_negator` deliberately answers only the narrower
	# "a Spell/Trap CARD was activated below me" question, so it would never fire here. The
	# first version of this test used it, the path assertion below caught the miss, and the
	# test would otherwise have passed for the wrong reason on a working negation.
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Negate That"))

	# The Chain is built link by link on purpose. `TestFixtures.activate_effect()` finishes
	# with `pass_until_open()`, which auto-passes the opponent's response window — so driving
	# this through the helper would resolve the Summon unopposed and quietly test nothing.
	var before := engine.state.events.size()
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, card.id, EFFECT_ID)
	t.check(offered != null, "the Graveyard Ignition is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered), "it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.check(response != null, "the opponent can respond to it")
	if response == null:
		return
	t.check(engine.submit_action(response), "the negator becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# Prove the Chain the test claims to have built really was built: a negation that never
	# happened would leave the card summoned and this test passing for the wrong reason.
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.EFFECT_NEGATED, before).size(), 1,
		"the opponent's negation actually resolved")
	t.eq(card.zone, Enums.Zone.GRAVEYARD, "the card never left the Graveyard")
	t.check(not card.is_monster(), "it is not a monster")
	t.check(not card.has_monster_identity(), "and holds no stale runtime identity")


static func _test_the_trap_is_not_swept_away_after_summoning_itself(t: TestCase) -> void:
	t.start("the resolved-Spell/Trap cleanup does not send the Trap Monster to the Graveyard "
		+ "the moment it arrives — it was not a card activation")
	var d := _duel(9811)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return

	TestFixtures.pass_until_open(engine)
	t.eq(card.zone, Enums.Zone.MONSTER_ZONE,
		"it is still in the Monster Zone after the Chain finished")
	t.check(card.is_monster(), "and still a monster")
	t.eq(card.last_move_reason, Enums.MoveReason.SUMMONED,
		"its last movement was the Summon, not a cleanup to the Graveyard")


# ---------------------------------------------------------------------------
# Being a monster
# ---------------------------------------------------------------------------

static func _test_it_is_found_by_a_clause_that_looks_for_monsters(t: TestCase) -> void:
	t.start("a clause that collects 'monsters you control' finds it, and one that collects "
		+ "Spell/Trap cards does not")
	var d := _duel(9812)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return

	var ctx := EffectContext.new(engine.state, card,
		EffectDef.new("probe", "Test: look at the board."))
	ctx.controller_id = 0
	var mine := EffectPrimitives.own_monsters(ctx)
	t.check(mine.has(card), "own_monsters() includes it")
	t.eq(mine.size(), 1, "and finds exactly the one monster on the board")
	t.check(EffectPrimitives.cards_on_field(ctx, true).has(card),
		"it is a face-up card on the field")
	# Level / Type filters must read the granted line, not the printed blank.
	t.check(EffectPrimitives.monster_of_level(4, "Warrior").call(card),
		"a 'Level 4 Warrior monster' filter matches its granted type line")
	t.check(not EffectPrimitives.monster_of_level(1).call(card),
		"and a Level 1 filter does not — the Level really is read, not defaulted to 0")


static func _test_it_battles_with_its_granted_stats(t: TestCase) -> void:
	t.start("it can be attacked and destroyed by battle using its GRANTED DEF, and goes back "
		+ "to being a Trap in the Graveyard")
	# Player 1 goes first, so player 0 may conduct a Battle Phase from turn 2.
	var d := TestFixtures.new_duel(9813, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	# The Trap Monster belongs to player 1; player 0 will attack it next.
	var card := _trap_in_gy(engine, 1, TestFixtures.trap_monster("Veiled Trap"))
	# Summon it on ITS controller's turn, then hand the turn to player 0.
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	if not _summon(t, engine, 1, card):
		return
	t.eq(card.current_def(), 300, "it sits there with the DEF its clause granted")

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	var lp_before := engine.state.player(1).life_points

	t.check(TestFixtures.attack(engine, attacker, card),
		"the attack on the Trap Monster was accepted — it is a legal attack target")
	TestFixtures.pass_until_open(engine)

	t.eq(card.zone, Enums.Zone.GRAVEYARD, "1800 beats 300, so it was destroyed by battle")
	t.eq(card.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE,
		"and destroyed by BATTLE specifically")
	t.check(not card.is_monster(), "back in the Graveyard it is not a monster")
	t.check(card.is_trap(), "it is a Trap again")
	t.eq(engine.state.player(1).life_points, lp_before,
		"no battle damage: it was in Defense Position [S1 p.38]")


static func _test_continuous_effects_apply_to_it_as_to_any_monster(t: TestCase) -> void:
	t.start("an ATK modifier applies to it and is computed from its granted base ATK")
	var d := _duel(9814)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap",
		"Warrior", "DARK", 4, 500, 300))
	if not _summon(t, engine, 0, card):
		return

	t.eq(card.current_atk(), 500, "its base ATK is the granted one")
	card.add_atk_modifier(-1, 300, "end_of_turn")
	t.eq(card.current_atk(), 800, "a +300 modifier stacks on the GRANTED base, not on 0")
	t.eq(card.original_atk(), 500,
		"and 'original ATK' is the granted printed value, since a Trap has none of its own")


static func _test_control_can_change_and_it_goes_home_to_its_owner(t: TestCase) -> void:
	t.start("control of a Trap Monster can change, it stays a monster under the new "
		+ "controller, and it still goes to its OWNER's Graveyard when it leaves")
	var d := _duel(9815)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return

	t.check(engine.state.change_control(card, 1, Enums.ControlDuration.UNTIL_END_PHASE,
		card.id), "control changed to player 1")
	t.eq(card.controller_id, 1, "player 1 controls it")
	t.eq(card.owner_id, 0, "player 0 still owns it")
	t.check(card.is_monster(), "it is still a monster under the new controller")
	t.check(engine.state.player(1).monster_zones.has(card),
		"and it occupies a Monster Zone on their side")

	engine.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.check(engine.state.player(0).graveyard.has(card),
		"it goes to its OWNER's Graveyard, not the controller's [S1 p.52]")
	t.check(not card.is_monster(), "and is a Trap again")


# ---------------------------------------------------------------------------
# Leaving the Monster Zone
# ---------------------------------------------------------------------------

static func _test_every_route_out_of_the_monster_zone_restores_the_trap(
		t: TestCase) -> void:
	t.start("destroyed, banished, returned to the hand, returned to the Deck, sent to the "
		+ "Graveyard and tributed each revoke the monster identity — asserted one by one")
	var routes := [
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT, "destroyed"],
		[Enums.Zone.BANISHED, Enums.MoveReason.BANISHED, "banished"],
		[Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND, "returned to the hand"],
		[Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_TOP, "returned to the Deck"],
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT, "sent to the GY"],
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.TRIBUTED, "tributed"],
	]
	var seed_value := 9816
	for entry in routes:
		var route: Array = entry
		var to_zone: Enums.Zone = route[0]
		var reason: Enums.MoveReason = route[1]
		var label: String = route[2]
		seed_value += 1
		var d := _duel(seed_value)
		var engine: DuelEngine = d["engine"]
		var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
		if not _summon(t, engine, 0, card):
			continue
		t.check(card.is_monster(), "%s: it is a monster first" % label)

		engine.state.move_card(card, to_zone, reason)

		t.eq(card.zone, to_zone, "%s: it arrived where it was sent" % label)
		t.check(not card.is_monster(), "%s: it is no longer a monster" % label)
		t.check(not card.has_monster_identity(),
			"%s: the runtime identity is gone" % label)
		t.check(card.is_trap(), "%s: it is an ordinary Trap again" % label)
		t.eq(card.current_level(), 0, "%s: and has no Level again" % label)


static func _test_no_stale_runtime_state_survives_the_departure(t: TestCase) -> void:
	t.start("after it leaves, nothing of the monster remains: no identity, no stats, no "
		+ "summon record, and it is not counted as a monster anywhere")
	var d := _duel(9823)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap"))
	if not _summon(t, engine, 0, card):
		return
	card.add_atk_modifier(-1, 700, "end_of_turn")
	t.eq(card.current_atk(), 700, "it has a modifier while it is a monster")

	engine.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT)

	t.check(card.monster_identity.is_empty(), "the identity dictionary is empty")
	t.eq(card.base_atk(), 0, "base ATK is back to the printed Trap's nothing")
	t.eq(card.current_atk(), 0, "and so is current ATK — the modifier went with the field")
	t.eq(card.atk_modifiers.size(), 0, "no modifier survived")
	t.eq(card.summoned_by_procedure_id, "", "no summoning-procedure record survived")
	t.eq(engine.state.player(0).monster_count(), 0,
		"the player controls no monsters")
	t.check(not engine.state.player(0).monster_zones.has(card),
		"and it is in no Monster Zone")


# ---------------------------------------------------------------------------
# "Banish this card when it leaves the field" — a DESTINATION replacement.
# ---------------------------------------------------------------------------

static func _test_banish_when_it_leaves_the_field_redirects_the_destination(
		t: TestCase) -> void:
	t.start("a card marked 'banish this card when it leaves the field' is banished instead "
		+ "of arriving where the movement was headed — on every route out")
	var routes := [
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT, "destroyed"],
		[Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND, "returned to the hand"],
		[Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_TOP, "returned to the Deck"],
		[Enums.Zone.GRAVEYARD, Enums.MoveReason.TRIBUTED, "tributed"],
	]
	var seed_value := 9830
	for entry in routes:
		var route: Array = entry
		var to_zone: Enums.Zone = route[0]
		var reason: Enums.MoveReason = route[1]
		var label: String = route[2]
		seed_value += 1
		var d := _duel(seed_value)
		var engine: DuelEngine = d["engine"]
		var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap",
			"Warrior", "DARK", 4, 0, 300, true, false,
			Enums.Position.FACE_UP_DEFENSE, true))
		if not _summon(t, engine, 0, card):
			continue

		engine.state.move_card(card, to_zone, reason)

		t.eq(card.zone, Enums.Zone.BANISHED,
			"%s: it was banished instead" % label)
		t.check(engine.state.player(0).banished.has(card),
			"%s: and it is in its owner's banished zone" % label)
		t.check(not card.is_monster(), "%s: and is no longer a monster" % label)


static func _test_the_redirect_keeps_the_departure_it_replaced(t: TestCase) -> void:
	t.start("the redirect changes only WHERE the card goes: a destruction is still a "
		+ "destruction, so a clause keyed on 'is destroyed' still sees it")
	var d := _duel(9840)
	var engine: DuelEngine = d["engine"]
	var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap",
		"Warrior", "DARK", 4, 0, 300, true, false,
		Enums.Position.FACE_UP_DEFENSE, true))
	if not _summon(t, engine, 0, card):
		return

	var destroyed_before := TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_DESTROYED, card.id)
	var banished_before := TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_BANISHED, card.id)
	var gy_before := TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_SENT_TO_GY, card.id)

	engine.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT)

	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id),
		destroyed_before + 1, "the destruction still happened and still fired its event")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_BANISHED, card.id),
		banished_before + 1, "and the banishment fired its own event too")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, card.id),
		gy_before, "but it was never 'sent to the Graveyard' — it did not go there")
	t.eq(card.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"the recorded reason is the destruction, not the redirect")


static func _test_the_redirect_is_consumed_and_does_not_apply_to_an_unmarked_card(
		t: TestCase) -> void:
	t.start("the obligation is consumed when it fires, and an unmarked Trap Monster is not "
		+ "banished — the redirect is opt-in, not a property of being a Trap Monster")
	var d := _duel(9841)
	var engine: DuelEngine = d["engine"]
	var marked := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Marked",
		"Warrior", "DARK", 4, 0, 300, true, false,
		Enums.Position.FACE_UP_DEFENSE, true))
	var plain := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Unmarked"))
	if not _summon(t, engine, 0, marked):
		return
	if not _summon(t, engine, 0, plain):
		return

	t.check(bool(engine.state.recall(marked,
		GameState.BANISH_WHEN_LEAVING_FIELD_KEY, false)),
		"the marked card really carries the obligation")
	t.check(not bool(engine.state.recall(plain,
		GameState.BANISH_WHEN_LEAVING_FIELD_KEY, false)),
		"and the unmarked one does not")

	engine.state.destroy(plain, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.eq(plain.zone, Enums.Zone.GRAVEYARD,
		"the unmarked Trap Monster goes to the Graveyard as normal")

	engine.state.destroy(marked, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.eq(marked.zone, Enums.Zone.BANISHED, "the marked one is banished")
	t.check(not bool(engine.state.recall(marked,
		GameState.BANISH_WHEN_LEAVING_FIELD_KEY, false)),
		"and the obligation was consumed rather than left to fire again")

	# It fired once; moving the card again must not redirect anything a second time.
	engine.state.move_card(marked, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(marked.zone, Enums.Zone.GRAVEYARD,
		"a later movement is unaffected by the spent obligation")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

static func _test_the_whole_cycle_is_replay_deterministic(t: TestCase) -> void:
	t.start("summoning a Trap Monster and losing it again produces an identical event "
		+ "stream from the same seed")
	var signatures: Array = []
	for run_index in range(2):
		var d := _duel(9850)
		var engine: DuelEngine = d["engine"]
		var card := _trap_in_gy(engine, 0, TestFixtures.trap_monster("Veiled Trap",
			"Warrior", "DARK", 4, 0, 300, true, false,
			Enums.Position.FACE_UP_DEFENSE, true))
		TestFixtures.activate_effect(engine, 0, card, EFFECT_ID)
		engine.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT)
		var parts: Array = []
		for e in engine.state.events:
			parts.append("%d:%s" % [e.kind, str(e.data.get("card_id", -1))])
		signatures.append("|".join(parts))

	t.eq(signatures[0], signatures[1],
		"two runs from the same seed produced the same event stream")
	t.check(signatures[0].length() > 0, "and the stream is not empty")

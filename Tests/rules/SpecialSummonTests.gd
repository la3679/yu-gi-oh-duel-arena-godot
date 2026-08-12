class_name SpecialSummonTests
extends RefCounted

## Special Summon execution. RULES_SPEC.md 5.5 [S1 p.24].
##
## This was the last UNVERIFIED path in the rules engine: `SummonRules.begin_special_summon()`
## compiled but nothing called it. 22 of the 77 V1 cards Special Summon something, so the
## card library cannot start until this is proven.
##
## Two distinct paths are covered, because the rules treat them differently:
##
##   * a summoning PROCEDURE ("you can Special Summon this card (from your hand)") is a box
##     A1 action in an open game state. There is no activation to respond to, so the Summon
##     itself opens a declaration window and can be negated.
##   * a Special Summon performed while an effect RESOLVES (the `Shining Angel` family).
##     No new Chain starts mid-resolution (master prompt 45), so it completes immediately;
##     negating it is done by responding to the activation that Summons.


static func run() -> TestCase:
	var t := TestCase.new("SpecialSummonTests")
	_test_procedure_summon_declares_then_succeeds(t)
	_test_declaration_window_opens_before_it_succeeds(t)
	_test_negated_special_summon_never_reaches_the_field(t)
	_test_normal_summon_allowance_is_not_consumed(t)
	_test_full_monster_zone_blocks_a_special_summon(t)
	_test_summon_from_deck_during_resolution(t)
	_test_summon_from_graveyard_during_resolution(t)
	_test_position_is_the_summoning_players_choice(t)
	return t


# ---------------------------------------------------------------------------
# Synthetic cards
# ---------------------------------------------------------------------------

## The `Hieratic Dragon of Tefnuit` / `Inari Fire` shape: a monster that Special Summons
## ITSELF from the hand by a rule, not by activating an effect.
static func _self_summoner(name: String, atk: int = 1800) -> CardDef:
	var d := TestFixtures.monster(name, 6, atk, 1000)
	var e := EffectDef.new("summon_self",
		"You can Special Summon this card (from your hand).")
	e.of_type(Enums.EffectType.SUMMON_PROCEDURE)
	e.activation_locations = [Enums.ActivationLocation.HAND]
	e.legal_phases = [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2]
	TestFixtures.with_effect(d, e)
	return d


## A Normal Spell that Special Summons the first monster it finds in `zone` for its
## controller, through the engine hook an effect is supposed to use.
static func _summoner_spell(name: String, zone: Enums.Zone,
		position: Enums.Position = Enums.Position.FACE_UP_ATTACK) -> CardDef:
	var d := TestFixtures.spell(name)
	var e := EffectDef.new("special_summon",
		"Special Summon 1 monster from your %s." % Enums.Zone.keys()[zone])
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN, Enums.ActivationLocation.FIELD_FACE_UP]
	e.resolve = func(ctx: EffectContext) -> void:
		var pool: Array = ctx.me().deck if zone == Enums.Zone.DECK else ctx.me().graveyard
		for candidate in pool:
			var card: CardInstance = candidate
			if not card.is_monster():
				continue
			ctx.engine.special_summon(card, ctx.controller_id, position, ctx.source.id)
			return
	TestFixtures.with_effect(d, e)
	return d


## The `Champion's Vigilance` shape, aimed at a declared SPECIAL Summon.
static func _summon_negator(name: String) -> CardDef:
	var d := TestFixtures.trap(name, Enums.STKind.COUNTER_TRAP)
	var e := EffectDef.new("negate_summon",
		"When a monster(s) would be Summoned: Negate the Summon.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS3
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	e.trigger_events = [GameEvent.Kind.SPECIAL_SUMMON_DECLARED]
	e.resolve = func(ctx: EffectContext) -> void:
		ctx.engine.negate_pending_summon(ctx.source.id)
	TestFixtures.with_effect(d, e)
	return d


## Fill every Monster Zone this player has.
static func _fill_monster_zones(engine: DuelEngine, pid: int) -> int:
	var n := 0
	while engine.state.player(pid).has_free_monster_zone() and n < 10:
		TestFixtures.give_monster_on_field(engine, pid,
			TestFixtures.monster("Wall %d" % n, 4, 1000, 1000))
		n += 1
	return n


static func _duel_in_main_1(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


# ---------------------------------------------------------------------------
# The summoning-procedure path
# ---------------------------------------------------------------------------

static func _test_procedure_summon_declares_then_succeeds(t: TestCase) -> void:
	t.start("a summoning-procedure Special Summon declares, then succeeds")
	var d := _duel_in_main_1(9001)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_to_hand(engine, 0, _self_summoner("Self Summoner"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, mon.id)
	t.not_null(action, "the summoning procedure is offered as a box A1 action")
	t.is_true(engine.submit_action(action), "the engine accepts it")
	TestFixtures.pass_until_open(engine)

	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster reached a Monster Zone")
	t.eq(mon.controller_id, 0, "its controller is the summoning player")
	t.eq(mon.summoned_by, Enums.SummonKind.SPECIAL, "it was Special Summoned")
	t.is_true(mon.properly_special_summoned,
		"it is recorded as properly Special Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED), 1,
		"exactly one declaration was announced")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"and exactly one success")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED), 0,
		"a Special Summon is not a Normal Summon")
	var declared := TestFixtures.first_event_index(engine,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED)
	var succeeded := TestFixtures.first_event_index(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED)
	t.is_true(declared < succeeded,
		"the declaration is announced before the Summon succeeds")


static func _test_declaration_window_opens_before_it_succeeds(t: TestCase) -> void:
	t.start("the monster waits in transit while the declaration window is open")
	var d := _duel_in_main_1(9002)
	var engine: DuelEngine = d["engine"]
	# The opponent holds a fast effect, so the window genuinely opens instead of the
	# engine auto-passing through it.
	TestFixtures.give_set_spell_trap(engine, 1, _summon_negator("Vigilance-like"), 0)
	var mon := TestFixtures.give_to_hand(engine, 0, _self_summoner("Self Summoner"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, mon.id)
	t.is_true(engine.submit_action(action), "the Summon is declared")

	t.eq(engine.waiting_player(), 1, "the opponent may respond to the declaration")
	t.eq(mon.zone, Enums.Zone.IN_TRANSIT,
		"the monster is in transit, not in a Monster Zone, while the window is open")
	t.eq(engine.state.player(0).monster_count(), 0,
		"the summoning player controls no monster yet")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"SPECIAL_SUMMON_SUCCEEDED is not emitted until the window closes")

	TestFixtures.pass_until_open(engine)
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE,
		"declining the response completes the Summon")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"and only then is the success announced")


static func _test_negated_special_summon_never_reaches_the_field(t: TestCase) -> void:
	t.start("a negated Special Summon emits no success and returns the card")
	var d := _duel_in_main_1(9003)
	var engine: DuelEngine = d["engine"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		_summon_negator("Vigilance-like"), 0)
	var mon := TestFixtures.give_to_hand(engine, 0, _self_summoner("Self Summoner"))

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, mon.id))
	var resp = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(resp, "the Counter Trap is offered against the declared Special Summon")
	engine.submit_action(resp)
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 1,
		"the negation is a semantic event")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no success trigger is emitted for a negated Special Summon")
	t.eq(engine.state.player(0).monster_count(), 0,
		"the monster never occupied a Monster Zone")
	t.eq(mon.zone, Enums.Zone.HAND,
		"a negated Summon is not by itself a destruction: the card goes back to the hand")
	t.is_false(mon.properly_special_summoned,
		"and it was never properly Special Summoned")


static func _test_normal_summon_allowance_is_not_consumed(t: TestCase) -> void:
	t.start("a Special Summon does not consume the Normal Summon allowance")
	var d := _duel_in_main_1(9004)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_to_hand(engine, 0, _self_summoner("Self Summoner"))
	var vanilla := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Ordinary", 4, 1400, 1200))

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, mon.id))
	TestFixtures.pass_until_open(engine)

	t.is_true(engine.state.player(0).can_normal_summon(),
		"the once-per-turn Normal Summon is still available [S1 p.24]")
	var normal = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, vanilla.id)
	t.not_null(normal, "so a Normal Summon is still offered in the same turn")
	t.is_true(engine.submit_action(normal), "and it is accepted")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(0).monster_count(), 2,
		"both the Special Summoned and the Normal Summoned monster are on the field")
	t.is_false(engine.state.player(0).can_normal_summon(),
		"only the Normal Summon spent the allowance")


static func _test_full_monster_zone_blocks_a_special_summon(t: TestCase) -> void:
	t.start("a Special Summon into a full Monster Zone is illegal")
	var d := _duel_in_main_1(9005)
	var engine: DuelEngine = d["engine"]
	var filled := _fill_monster_zones(engine, 0)
	t.is_true(filled > 0, "the test filled the Monster Zones")
	t.is_false(engine.state.player(0).has_free_monster_zone(),
		"there is no free Monster Zone")

	var mon := TestFixtures.give_to_hand(engine, 0, _self_summoner("Self Summoner"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, mon.id),
		"the summoning procedure is not offered with no room to place the monster")

	# The resolution-time hook must refuse it too, not half-summon into transit.
	t.is_false(engine.special_summon(mon, 0, Enums.Position.FACE_UP_ATTACK),
		"the engine hook reports failure instead of Summoning")
	t.eq(mon.zone, Enums.Zone.HAND, "and the card did not move")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED), 0,
		"a refused Special Summon announces nothing")


# ---------------------------------------------------------------------------
# The resolution-time path — the shape the V1 pool actually uses
# ---------------------------------------------------------------------------

static func _test_summon_from_deck_during_resolution(t: TestCase) -> void:
	t.start("an effect Special Summons from the Deck while it resolves")
	var d := _duel_in_main_1(9006)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0,
		_summoner_spell("Deck Recruiter", Enums.Zone.DECK))
	var deck_before := engine.state.player(0).deck.size()

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(action, "the Spell can be activated")
	engine.submit_action(action)
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(0).monster_count(), 1,
		"a monster was Special Summoned from the Deck")
	t.eq(engine.state.player(0).deck.size(), deck_before - 1,
		"and it left the Deck")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"the Summon succeeded")
	var summoned: CardInstance = engine.state.player(0).monsters()[0]
	t.eq(summoned.summoned_by, Enums.SummonKind.SPECIAL, "as a Special Summon")
	t.eq(summoned.position, Enums.Position.FACE_UP_ATTACK,
		"in the position the summoning effect specified")
	# No new Chain starts mid-resolution, so declaration and success are not separated
	# by a response window here.
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED), 1,
		"the declaration is still announced for presentation and triggers")
	t.eq(spell.zone, Enums.Zone.GRAVEYARD,
		"the Normal Spell went to the GY after resolving")


static func _test_summon_from_graveyard_during_resolution(t: TestCase) -> void:
	t.start("an effect Special Summons from the Graveyard while it resolves")
	var d := _duel_in_main_1(9007)
	var engine: DuelEngine = d["engine"]
	var buried := TestFixtures.give(engine, 0,
		TestFixtures.monster("Fallen", 4, 1500, 1200), Enums.Zone.GRAVEYARD)
	var spell := TestFixtures.give_to_hand(engine, 0,
		_summoner_spell("Reborn-like", Enums.Zone.GRAVEYARD,
			Enums.Position.FACE_UP_DEFENSE))

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id))
	TestFixtures.pass_until_open(engine)

	t.eq(buried.zone, Enums.Zone.MONSTER_ZONE,
		"the monster came back from the Graveyard")
	t.eq(buried.position, Enums.Position.FACE_UP_DEFENSE,
		"in the position the effect chose")
	t.eq(buried.controller_id, 0, "under its controller")
	t.is_true(buried.properly_special_summoned,
		"and it is properly Special Summoned")
	t.eq(engine.state.player(0).graveyard.size(), 1,
		"only the resolved Spell is left in the Graveyard")


static func _test_position_is_the_summoning_players_choice(t: TestCase) -> void:
	t.start("a summoning procedure offers both face-up positions and validates the choice")
	var d := _duel_in_main_1(9008)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_to_hand(engine, 0, _self_summoner("Self Summoner"))

	var template = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, mon.id)
	t.not_null(template, "the procedure is offered")
	t.is_true(template.legal_positions.has(Enums.Position.FACE_UP_ATTACK),
		"face-up Attack Position is offered [S1 p.24]")
	t.is_true(template.legal_positions.has(Enums.Position.FACE_UP_DEFENSE),
		"face-up Defense Position is offered too")

	var illegal: DuelAction = template.with_choices(
		{"position": Enums.Position.FACE_DOWN_DEFENSE})
	t.is_false(engine.submit_action(illegal),
		"a face-down position the card did not grant is rejected")
	t.eq(mon.zone, Enums.Zone.HAND, "and the rejected action changed nothing")

	var chosen: DuelAction = template.with_choices(
		{"position": Enums.Position.FACE_UP_DEFENSE})
	t.is_true(engine.submit_action(chosen), "the offered Defense Position is accepted")
	TestFixtures.pass_until_open(engine)
	t.eq(mon.position, Enums.Position.FACE_UP_DEFENSE,
		"and the monster arrives in the position the player chose")

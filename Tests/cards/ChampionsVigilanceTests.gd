class_name ChampionsVigilanceTests
extends RefCounted

## Per-card suite for `Champion's Vigilance`. Research/CARD_RULINGS.md R24.
##
##   "If you control a Level 7 or higher Normal Monster, when a monster(s) would be
##    Summoned OR a Spell/Trap Card is activated: Negate the Summon or activation, and if
##    you do, destroy that card."
##
## The generic summon-negation architecture already existed (`Zone.IN_TRANSIT`,
## `DuelEngine.negate_pending_summon()`, `SummonRules.abort_summon()`) and is preserved
## rather than replaced — this card is its first real consumer. What this suite proves is
## that the two response categories stay on SEPARATE timing paths: a declared Summon is not
## a Chain Link and an activated Spell/Trap is, and an activated effect that WOULD Special
## Summon is the second case rather than the first.

const CARD_UNDER_TEST := "Champion's Vigilance"

const NEGATE_SUMMON := "negate_summon"
const NEGATE_ACTIVATION := "negate_spell_trap_activation"


static func run() -> TestCase:
	var t := TestCase.new("ChampionsVigilanceTests")
	_test_clause_shape(t)
	_test_the_field_condition(t)
	_test_negates_a_normal_summon(t)
	_test_negates_a_special_summon_procedure(t)
	_test_no_successful_summon_trigger_is_collected(t)
	_test_negates_a_spell_activation(t)
	_test_negates_a_trap_activation_and_the_cost_stays_paid(t)
	_test_a_monster_effect_is_not_a_spell_trap_activation(t)
	_test_an_effect_that_would_special_summon_is_the_other_path(t)
	_test_spell_speed_three(t)
	_test_flip_summon_is_a_known_gap(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _effect(effect_id: String) -> EffectDef:
	for entry in _def().effects:
		var e: EffectDef = entry
		if e.effect_id == effect_id:
			return e
	return null


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Player 1 holds a Set Champion's Vigilance and controls the Level 8 Normal Monster the
## activation condition needs. Returns {"engine", "p0", "p1", "vigilance", "anchor"}.
static func _armed_duel(seed_value: int) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["anchor"] = TestFixtures.give_monster_on_field(engine, 1,
		_card("Blue-Eyes White Dragon"))
	d["vigilance"] = TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	return d


static func _response(engine: DuelEngine, pid: int, card: CardInstance, effect_id: String):
	return TestFixtures.find_action(engine.get_legal_responses(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id, effect_id)


## Pass on behalf of whoever holds the window until `pid` may activate `effect_id`, or the
## engine goes back to an open game state.
static func _wait_for_response(engine: DuelEngine, pid: int, card: CardInstance,
		effect_id: String):
	var guard := 0
	while guard < 8 and engine.timing != DuelEngine.Timing.OPEN:
		guard += 1
		var found = _response(engine, pid, card, effect_id)
		if found != null:
			return found
		var waiting := engine.waiting_player()
		if waiting == -1:
			return null
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting))
	return null


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("one printed clause, two disjoint timings — so two EffectDefs on two separate "
		+ "negation paths")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.COUNTER_TRAP, "it is a Counter Trap")
	t.eq(def.effects.size(), 2, "the Summon response and the Spell/Trap response")

	for entry in def.effects:
		var e: EffectDef = entry
		t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION,
			"%s: activating the Trap itself is the effect" % e.effect_id)
		t.eq(e.spell_speed, Enums.SpellSpeed.SS3,
			"%s: a Counter Trap is Spell Speed 3 [S1 p.44]" % e.effect_id)
		t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
			"%s: activated from a Set card" % e.effect_id)
		t.eq(e.damage_step_permission, Enums.DamageStepPermission.UNTIL_DAMAGE_CALC,
			"%s: a Counter Trap is legal in the Damage Step up to damage calculation "
			% e.effect_id + "[S1 p.41]")
		t.is_false(e.targets, "%s: a Counter Trap that negates does not target" % e.effect_id)

	var summon := _effect(NEGATE_SUMMON)
	t.not_null(summon, "the Summon response exists")
	t.is_true(summon.trigger_events.has(GameEvent.Kind.NORMAL_SUMMON_DECLARED),
		"it answers a declared Normal Summon")
	t.is_true(summon.trigger_events.has(GameEvent.Kind.SPECIAL_SUMMON_DECLARED),
		"and a declared Special Summon")
	t.is_false(summon.trigger_events.has(GameEvent.Kind.EFFECT_ACTIVATED),
		"and nothing else — the two paths do not overlap")

	var activation := _effect(NEGATE_ACTIVATION)
	t.not_null(activation, "the Spell/Trap response exists")
	t.eq(activation.trigger_events, [GameEvent.Kind.EFFECT_ACTIVATED],
		"it answers an activation, which IS a Chain Link")


# ---------------------------------------------------------------------------
# The field condition
# ---------------------------------------------------------------------------

## Set up a fresh duel where player 1 holds a Set Champion's Vigilance, optionally give
## player 1 or player 0 an anchor monster, declare a Normal Summon by player 0, and report
## whether the Counter Trap was offered in the declaration window.
##
## Asked LIVE rather than by calling `condition` directly, because the condition is a
## conjunction — the field requirement AND a pending Summon — and calling it on a board with
## no Summon declared would answer false for the wrong reason, making every negative vacuous.
static func _offered_with_anchor(seed_value: int, anchor_name: String, anchor_owner: int,
		position: Enums.Position = Enums.Position.FACE_UP_ATTACK) -> bool:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var vigilance := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	if anchor_name != "":
		TestFixtures.give_monster_on_field(engine, anchor_owner, _card(anchor_name), position)
	var summoner := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Something", 4, 1000, 1000))
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, summoner.id)
	if a == null or not engine.submit_action(a):
		return false
	return _response(engine, 1, vigilance, NEGATE_SUMMON) != null


static func _test_the_field_condition(t: TestCase) -> void:
	t.start("'If you control a Level 7 or higher Normal Monster': the Level, the Normal "
		+ "Monster requirement, the controller and face-up — all four, against a real "
		+ "pending Summon so no negative is vacuous")

	t.is_true(_offered_with_anchor(7702, "Blue-Eyes White Dragon", 1),
		"a face-up Level 8 Normal Monster you control satisfies it — the positive control")
	t.is_true(_offered_with_anchor(7703, "Metaphys Armed Dragon", 1),
		"and so does a Level 7 one: the bound is 'or higher', inclusive at 7")

	t.is_false(_offered_with_anchor(7704, "", 1),
		"with no monster at all the Counter Trap cannot be activated")
	t.is_false(_offered_with_anchor(7705, "Sabersaurus", 1),
		"a Level 4 Normal Monster is not enough")
	t.is_false(_offered_with_anchor(7706, "Witchcrafter Golem Aruru", 1),
		"a Level 8 EFFECT Monster does not satisfy 'Normal Monster'")
	t.is_false(_offered_with_anchor(7707, "Blue-Eyes White Dragon", 0),
		"'YOU control' — the opponent's Level 8 Normal Monster does not count")
	t.is_false(_offered_with_anchor(7708, "Blue-Eyes White Dragon", 1,
		Enums.Position.FACE_DOWN_DEFENSE),
		"a face-down monster's Level is not a property either player may act on")

	# The card data the four negatives rest on, asserted so a wrong negative cannot pass
	# for a wrong reason.
	t.eq(_card("Sabersaurus").level, 4, "Sabersaurus really is Level 4")
	t.is_true(_card("Sabersaurus").is_normal_monster, "and really is a Normal Monster")
	t.eq(_card("Witchcrafter Golem Aruru").level, 8, "Aruru really is Level 8")
	t.is_false(_card("Witchcrafter Golem Aruru").is_normal_monster,
		"and really is an Effect Monster")
	t.eq(_card("Metaphys Armed Dragon").level, 7, "Metaphys Armed Dragon really is Level 7")
	t.is_true(_card("Metaphys Armed Dragon").is_normal_monster,
		"and really is a Normal Monster")


# ---------------------------------------------------------------------------
# Negating a Summon
# ---------------------------------------------------------------------------

static func _test_negates_a_normal_summon(t: TestCase) -> void:
	t.start("a declared Normal Summon is negated, the monster never reaches a Monster Zone, "
		+ "and 'if you do, destroy that card' sends it to the Graveyard")
	var d := _armed_duel(7703)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	var victim := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Doomed Summon", 4, 1900, 1000))

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, victim.id)
	t.not_null(a, "the Normal Summon is offered")
	t.is_true(engine.submit_action(a), "and declared")
	t.eq(victim.zone, Enums.Zone.IN_TRANSIT,
		"the monster waits in IN_TRANSIT while the declaration window is open")

	var counter = _response(engine, 1, vigilance, NEGATE_SUMMON)
	t.not_null(counter, "the Counter Trap may answer the declaration")
	t.is_true(engine.submit_action(counter), "and is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "the monster was destroyed")
	t.eq(victim.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"by a card effect")
	t.eq(engine.state.player(0).monsters().size(), 0,
		"it never occupied a Monster Zone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 1,
		"exactly one SUMMON_NEGATED event")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED), 0,
		"and NO successful-summon event was ever emitted")
	t.eq(vigilance.zone, Enums.Zone.GRAVEYARD,
		"the Counter Trap resolved and went to the Graveyard [S1 p.30]")
	t.eq(engine.state.player(0).normal_summons_used, 1,
		"the Normal Summon allowance is still spent — a negated Summon is a used Summon")


static func _test_negates_a_special_summon_procedure(t: TestCase) -> void:
	t.start("the OTHER Summon route: a summoning procedure also opens a real declaration "
		+ "window, and it is negated the same way")
	var d := _armed_duel(7704)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	# "If only your opponent controls a monster, you can Special Summon this card (from your
	# hand)." Player 1 controls the Blue-Eyes and player 0 controls nothing.
	var tefnuit := TestFixtures.give_to_hand(engine, 0,
		_card("Hieratic Dragon of Tefnuit"))

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SPECIAL_SUMMON_PROCEDURE, tefnuit.id)
	t.not_null(a, "the summoning procedure is offered")
	t.is_true(engine.submit_action(a), "and declared")
	t.eq(tefnuit.zone, Enums.Zone.IN_TRANSIT, "the monster waits in IN_TRANSIT")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED), 0,
		"a summoning procedure creates no Chain Link — there is nothing on the Chain to "
		+ "respond to, which is exactly why the declaration window exists")

	var counter = _response(engine, 1, vigilance, NEGATE_SUMMON)
	t.not_null(counter, "the Counter Trap may still answer it")
	t.is_true(engine.submit_action(counter), "and is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(tefnuit.zone, Enums.Zone.GRAVEYARD, "the monster was destroyed")
	t.eq(engine.state.player(0).monsters().size(), 0, "and reached no Monster Zone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no successful Special Summon event")
	t.is_false(tefnuit.properly_special_summoned,
		"and it was never properly Special Summoned")


static func _test_no_successful_summon_trigger_is_collected(t: TestCase) -> void:
	t.start("a negated Summon collects no 'if this card is Summoned' Trigger Effect, and "
		+ "the field is left internally consistent")
	var d := _armed_duel(7705)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	# Apprentice Magician's first clause is a MANDATORY "If this card is Summoned" trigger.
	var mage := TestFixtures.give_to_hand(engine, 0, _card("Apprentice Magician"))
	var holder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.counter_holder("Spell Counter Tower", "Spell Counter"))

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, mage.id)
	t.not_null(a, "the Normal Summon is offered")
	t.is_true(engine.submit_action(a), "and declared")
	var counter = _response(engine, 1, vigilance, NEGATE_SUMMON)
	t.not_null(counter, "the Counter Trap answers the declaration")
	t.is_true(engine.submit_action(counter), "and is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(mage.zone, Enums.Zone.GRAVEYARD, "the Magician was destroyed")
	t.eq(engine.state.total_counters(holder, "Spell Counter"), 0,
		"its Summon trigger placed no Spell Counter — the Summon did not happen")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COUNTER_PLACED), 0,
		"no COUNTER_PLACED event at all")

	# Internal consistency of the board after a negation.
	t.eq(engine.state.player(0).in_transit.size(), 0, "nothing is left in transit")
	t.eq(engine.state.chain.size(), 0, "the Chain is empty")
	t.eq(engine.timing, DuelEngine.Timing.OPEN, "and the game state is open again")
	t.is_true(engine.get_legal_actions(0).size() > 0, "with legal actions available")


# ---------------------------------------------------------------------------
# Negating an activation
# ---------------------------------------------------------------------------

static func _test_negates_a_spell_activation(t: TestCase) -> void:
	t.start("a Spell Card activation is negated and the card is destroyed; the effect never "
		+ "resolves")
	var d := _armed_duel(7706)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	var buried := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id)
	t.not_null(offered, "Monster Reborn is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [buried.id]})),
		"and activated as Chain Link 1")

	var counter = _response(engine, 1, vigilance, NEGATE_ACTIVATION)
	t.not_null(counter, "the Counter Trap may answer a Spell activation")
	t.is_true(engine.submit_action(counter), "and is activated as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"the ACTIVATION was negated — not merely the effect [master prompt 18]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 0,
		"and the two are kept distinct")
	t.eq(buried.zone, Enums.Zone.GRAVEYARD, "the target was not revived")
	t.eq(engine.state.player(0).monsters().size(), 0, "nothing reached the field")
	t.eq(reborn.zone, Enums.Zone.GRAVEYARD, "the negated Spell was destroyed")
	t.eq(reborn.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"'and if you do, destroy that card' — destroyed, not merely sent [S1 p.52-53]")
	t.eq(vigilance.zone, Enums.Zone.GRAVEYARD, "and the Counter Trap resolved to the GY")


static func _test_negates_a_trap_activation_and_the_cost_stays_paid(t: TestCase) -> void:
	t.start("a Trap activation is negated too, and a cost already paid by the negated card "
		+ "stays paid (RULES_SPEC.md 10)")
	var d := _armed_duel(7707)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	# `One for One`: "Send 1 monster from your hand to the GY" is a COST paid at ACTIVATION,
	# on the card activation itself — which is what this card can answer.
	var p0: ScriptedController = d["p0"]
	var one_for_one := TestFixtures.give_to_hand(engine, 0, _card("One for One"))
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Sabersaurus"))
	TestFixtures.give(engine, 0, _card("Crystal Seer"), Enums.Zone.DECK)
	var deck_before := engine.state.player(0).deck.size()

	# The opening hand already holds monsters, so which one pays the cost has to be stated
	# explicitly or the default policy picks the first option instead.
	p0.queue_for(Enums.DecisionKind.CHOOSE_COST, [fodder.id])
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, one_for_one.id)
	t.not_null(offered, "One for One is offered")
	t.is_true(engine.submit_action(offered), "and activated as Chain Link 1")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the cost is ALREADY paid, before any response window opened")

	var counter = _wait_for_response(engine, 1, vigilance, NEGATE_ACTIVATION)
	t.not_null(counter, "the Counter Trap may answer a Spell Card activation")
	t.is_true(engine.submit_action(counter), "and is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"the activation was negated")
	t.eq(one_for_one.zone, Enums.Zone.GRAVEYARD, "the negated Spell was destroyed")
	t.eq(engine.state.player(0).deck.size(), deck_before,
		"and its effect did not apply — nothing left the Deck")
	t.eq(engine.state.player(0).monsters().size(), 0, "nothing was Special Summoned")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"but the COST stays paid — a cost is never refunded by a negation")
	t.eq(fodder.last_move_reason, Enums.MoveReason.SENT_AS_COST,
		"and it is still recorded as having been sent to pay a cost")
	t.eq(p0.errors, [], "the queued answer went to the cost prompt")


static func _test_a_monster_effect_is_not_a_spell_trap_activation(t: TestCase) -> void:
	t.start("'a SPELL/TRAP CARD is activated' does not cover a monster's activated effect")
	var d := _armed_duel(7708)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	# Kaibaman's Ignition Effect: "Tribute this card; Special Summon 1 Blue-Eyes White
	# Dragon from your hand." It is a monster's effect, so this card cannot answer it.
	var kaibaman := TestFixtures.give_monster_on_field(engine, 0, _card("Kaibaman"))
	TestFixtures.give_to_hand(engine, 0, _card("Blue-Eyes White Dragon"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, kaibaman.id)
	t.not_null(offered, "Kaibaman's effect is offered")
	t.is_true(engine.submit_action(offered), "and activated as Chain Link 1")
	t.is_null(_response(engine, 1, vigilance, NEGATE_ACTIVATION),
		"the Counter Trap is NOT offered against a monster's effect")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 0,
		"nothing was negated")
	t.eq(engine.state.player(0).monsters().size(), 1,
		"and the Blue-Eyes arrived normally")


static func _test_an_effect_that_would_special_summon_is_the_other_path(t: TestCase) -> void:
	t.start("negating a Summon and negating an activation that WOULD Summon are different "
		+ "timings and must not collapse into one")
	var d := _armed_duel(7709)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	var buried := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id)
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [buried.id]})),
		"Monster Reborn is activated")

	# At THIS moment nothing has been Summoned yet, so the Summon branch has nothing to do.
	t.is_null(_response(engine, 1, vigilance, NEGATE_SUMMON),
		"the Summon branch is not offered: no Summon has been declared")
	t.not_null(_response(engine, 1, vigilance, NEGATE_ACTIVATION),
		"the ACTIVATION branch is, because a Spell Card was activated")
	var summon_effect := _effect(NEGATE_SUMMON)
	var ctx := ActivationRules.make_context(engine.state, vigilance, summon_effect, 1, null)
	t.is_null(EffectPrimitives.summon_is_pending(ctx),
		"and there is genuinely no pending Summon record to negate")

	TestFixtures.pass_until_open(engine)
	t.eq(buried.zone, Enums.Zone.MONSTER_ZONE,
		"left alone, the effect resolves and Special Summons normally")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"one successful Special Summon — declared and completed inside the resolution")


static func _test_spell_speed_three(t: TestCase) -> void:
	t.start("only Spell Speed 3 may respond to a Counter Trap [S1 p.45]")
	var d := _armed_duel(7710)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	var buried := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	# Player 0 holds BOTH a Spell Speed 2 Trap and a Spell Speed 3 Counter Trap. The Spell
	# Speed 3 one is what keeps the window genuinely open — without a legal response the
	# engine auto-passes and resolves the whole Chain inside one `submit_action()`, and
	# there would be no mid-chain state left to assert on.
	var quick := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Too Slow", buried, "banish"), 0)
	var fast_enough := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.activation_negator("Fast Enough"), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id)
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [buried.id]})),
		"Monster Reborn is Chain Link 1")
	var counter = _response(engine, 1, vigilance, NEGATE_ACTIVATION)
	t.not_null(counter, "the Counter Trap is Chain Link 2")
	t.is_true(engine.submit_action(counter), "and is activated")

	t.eq(engine.state.chain.size(), 2, "the Chain is two links and still open")
	t.is_null(TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, quick.id),
		"a Spell Speed 2 Trap cannot respond to a Spell Speed 3 Chain Link")
	t.not_null(TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, fast_enough.id),
		"a Spell Speed 3 one can — the exclusion is about Spell Speed, nothing else")

	TestFixtures.pass_until_open(engine)
	t.eq(reborn.zone, Enums.Zone.GRAVEYARD, "and the negation went through")


# ---------------------------------------------------------------------------
# Known gap, pinned down rather than forgotten
# ---------------------------------------------------------------------------

static func _test_flip_summon_is_a_known_gap(t: TestCase) -> void:
	t.start("KNOWN GAP: the engine applies a Flip Summon immediately instead of declaring "
		+ "it, so this card cannot currently answer one (PROJECT_STATE.md §7, R24)")
	var d := _armed_duel(7711)
	var engine: DuelEngine = d["engine"]
	var vigilance: CardInstance = d["vigilance"]
	var hidden := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face Down", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, hidden.id)
	t.not_null(a, "a Flip Summon is offered")
	t.is_true(engine.submit_action(a), "and performed")

	# This is the DOCUMENTED CURRENT BEHAVIOUR, not the rules-correct one. A Flip Summon is
	# a Summon [S1 p.24] and Champion's Vigilance should be able to negate it. Making that
	# possible is an engine change — `SummonRules.flip_summon()` needs a begin/complete
	# split like the other two routes — and is deliberately out of scope for this batch.
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 1,
		"the Flip Summon succeeds immediately")
	t.eq(hidden.zone, Enums.Zone.MONSTER_ZONE, "the monster never left its Monster Zone")
	t.ne(hidden.zone, Enums.Zone.IN_TRANSIT,
		"so it never entered the IN_TRANSIT declaration pipeline")
	t.is_null(_response(engine, 1, vigilance, NEGATE_SUMMON),
		"and the Counter Trap is therefore not offered — the gap, asserted so it cannot be "
		+ "silently forgotten")
	TestFixtures.pass_until_open(engine)
	t.is_true(hidden.is_face_up(), "the monster is face-up in Attack Position")

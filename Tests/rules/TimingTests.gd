class_name TimingTests
extends RefCounted

## Fast Effect Timing, trigger collection and Chain closure.
## Rules under test: RULES_SPEC.md 3 and 4.4, from the official Fast Effect Timing
## chart (S2) and Official Rulebook v10 p.44-51 (S1).


static func run() -> TestCase:
	var t := TestCase.new("TimingTests")
	_test_summon_opens_response_window(t)
	_test_optional_trigger_requires_consent(t)
	_test_mandatory_trigger_is_not_asked(t)
	_test_simultaneous_trigger_group_order(t)
	_test_within_group_order_is_asked(t)
	_test_spell_speed_1_never_offered_as_response(t)
	_test_quick_effect_offered_in_response_window(t)
	_test_two_consecutive_passes_close_the_chain(t)
	_test_triggers_during_resolution_wait_for_the_chain_to_finish(t)
	_test_summon_negation(t)
	return t


# ---------------------------------------------------------------------------
# Box A1 -> trigger check: a Summon must not fall straight back to an open state
# while a legal response exists. RULES_SPEC.md 3, master prompt 23.
# ---------------------------------------------------------------------------

static func _test_summon_opens_response_window(t: TestCase) -> void:
	t.start("summon opens a response window before the open game state returns")
	var d := TestFixtures.new_duel(11, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	# Opponent holds a Set Trap that can respond to a successful Normal Summon.
	var order: Array = []
	var trap_def := TestFixtures.trap("Response Trap")
	var trap_effect := TestFixtures.card_activation("activate", Enums.SpellSpeed.SS2,
		order, "trap")
	trap_effect.trigger_events = [GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED]
	TestFixtures.with_effect(trap_def, trap_effect)
	TestFixtures.give_set_spell_trap(engine, 1, trap_def, 0)

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Beater"))
	var summon = TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id)
	t.not_null(summon, "Normal Summon is offered for a Level 4 monster in hand")
	engine.submit_action(summon)

	t.ne(engine.timing, DuelEngine.Timing.OPEN,
		"engine must not return to an open game state while a response is legal")
	t.eq(engine.waiting_player(), 1, "the opponent is the one being asked")
	var responses := engine.get_legal_responses(1)
	t.is_true(TestFixtures.has_action(responses, Enums.ActionKind.ACTIVATE_CARD),
		"the Trap that responds to the Summon is offered")

	TestFixtures.pass_until_open(engine)
	t.eq(engine.timing, DuelEngine.Timing.OPEN,
		"passing every window returns to the open game state")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the Summon completed")


# ---------------------------------------------------------------------------
# Master prompt 24 / RULES_SPEC.md 4.4: an optional Trigger Effect is offered, never
# fired silently.
# ---------------------------------------------------------------------------

static func _test_optional_trigger_requires_consent(t: TestCase) -> void:
	t.start("optional trigger effect is asked about, not auto-fired")

	for say_yes in [false, true]:
		var d := TestFixtures.new_duel(12, 0)
		var engine: DuelEngine = d["engine"]
		var c0: ScriptedController = d["p0"]
		TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

		var order: Array = []
		var def := TestFixtures.monster("Optional Trigger Guy")
		TestFixtures.with_effect(def, TestFixtures.trigger_effect("on_summon",
			[GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED], order, "fired"))
		var mon := TestFixtures.give_to_hand(engine, 0, def)

		c0.answers.clear()
		c0.queue_for(Enums.DecisionKind.YES_NO, say_yes)

		var summon = TestFixtures.find_action(
			engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id)
		engine.submit_action(summon)
		TestFixtures.pass_until_open(engine)

		t.eq(c0.request_count(Enums.DecisionKind.YES_NO), 1,
			"the controller is asked exactly once whether to use the optional effect")
		if say_yes:
			t.eq(order, ["fired"], "answering yes puts the effect on the Chain")
		else:
			t.eq(order, [], "answering no must not activate the effect")


static func _test_mandatory_trigger_is_not_asked(t: TestCase) -> void:
	t.start("mandatory trigger effect fires without being asked")
	var d := TestFixtures.new_duel(13, 0)
	var engine: DuelEngine = d["engine"]
	var c0: ScriptedController = d["p0"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	var def := TestFixtures.monster("Mandatory Trigger Guy")
	TestFixtures.with_effect(def, TestFixtures.trigger_effect("on_summon",
		[GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED], order, "fired", true))
	var mon := TestFixtures.give_to_hand(engine, 0, def)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))
	TestFixtures.pass_until_open(engine)

	t.eq(order, ["fired"], "a mandatory trigger resolves")
	t.eq(c0.request_count(Enums.DecisionKind.YES_NO), 0,
		"a mandatory effect must never be offered as a choice")


# ---------------------------------------------------------------------------
# RULES_SPEC.md 4.4 [S1 p.51]: turn player mandatory, opponent mandatory,
# turn player optional, opponent optional.
# ---------------------------------------------------------------------------

static func _test_simultaneous_trigger_group_order(t: TestCase) -> void:
	t.start("simultaneous triggers are chained in the official group order")
	var d := TestFixtures.new_duel(14, 0)
	var engine: DuelEngine = d["engine"]
	var c0: ScriptedController = d["p0"]
	var c1: ScriptedController = d["p1"]
	c0.default_yes = true
	c1.default_yes = true
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	var ev := [GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED]

	# One of each group, all watching the same event.
	var tp_mand := TestFixtures.monster("TP Mandatory")
	TestFixtures.with_effect(tp_mand,
		TestFixtures.trigger_effect("e", ev, order, "tp_mandatory", true))
	var opp_mand := TestFixtures.monster("Opp Mandatory")
	TestFixtures.with_effect(opp_mand,
		TestFixtures.trigger_effect("e", ev, order, "opp_mandatory", true))
	var tp_opt := TestFixtures.monster("TP Optional")
	TestFixtures.with_effect(tp_opt,
		TestFixtures.trigger_effect("e", ev, order, "tp_optional"))
	var opp_opt := TestFixtures.monster("Opp Optional")
	TestFixtures.with_effect(opp_opt,
		TestFixtures.trigger_effect("e", ev, order, "opp_optional"))

	TestFixtures.give_monster_on_field(engine, 0, tp_mand)
	TestFixtures.give_monster_on_field(engine, 1, opp_mand)
	TestFixtures.give_monster_on_field(engine, 0, tp_opt)
	TestFixtures.give_monster_on_field(engine, 1, opp_opt)

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Trigger Source"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))
	TestFixtures.pass_until_open(engine)

	# Built bottom-up in that order, so it RESOLVES in exactly the reverse.
	t.eq(order, ["opp_optional", "tp_optional", "opp_mandatory", "tp_mandatory"],
		"Chain built TP-mandatory, opp-mandatory, TP-optional, opp-optional [S1 p.51], "
		+ "and therefore resolves in reverse")


static func _test_within_group_order_is_asked(t: TestCase) -> void:
	t.start("player chooses the order within their own trigger group")
	var d := TestFixtures.new_duel(15, 0)
	var engine: DuelEngine = d["engine"]
	var c0: ScriptedController = d["p0"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	var ev := [GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED]
	var a := TestFixtures.monster("Mand A")
	TestFixtures.with_effect(a, TestFixtures.trigger_effect("e", ev, order, "A", true))
	var b := TestFixtures.monster("Mand B")
	TestFixtures.with_effect(b, TestFixtures.trigger_effect("e", ev, order, "B", true))
	TestFixtures.give_monster_on_field(engine, 0, a)
	TestFixtures.give_monster_on_field(engine, 0, b)

	# Reverse the offered order: B is placed on the Chain first, so A resolves first.
	c0.queue_for(Enums.DecisionKind.ORDER_TRIGGERS, [1, 0])

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Src"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))
	TestFixtures.pass_until_open(engine)

	t.eq(c0.request_count(Enums.DecisionKind.ORDER_TRIGGERS), 1,
		"a group of two effects prompts once for the order")
	t.eq(order, ["A", "B"],
		"chosen build order B,A resolves A,B — reverse order [S1 p.46-47]")


# ---------------------------------------------------------------------------
# RULES_SPEC.md 4.2 [S1 p.44]: Spell Speed 1 can never be a response.
# ---------------------------------------------------------------------------

static func _test_spell_speed_1_never_offered_as_response(t: TestCase) -> void:
	t.start("Spell Speed 1 is never offered in a response window")
	var d := TestFixtures.new_duel(16, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	# A Normal Spell (Spell Speed 1) in the opponent's hand.
	var spell_def := TestFixtures.spell("Slow Spell")
	TestFixtures.with_effect(spell_def, TestFixtures.card_activation("activate",
		Enums.SpellSpeed.SS1, order, "slow"))
	TestFixtures.give_to_hand(engine, 1, spell_def)

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Beater"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))

	# The engine auto-passed straight through both fast-effect boxes: the only card
	# either player holds is Spell Speed 1, which is not a fast effect.
	t.eq(engine.timing, DuelEngine.Timing.OPEN,
		"no response window opens when nobody holds a fast effect")
	t.eq(engine.get_legal_responses(1).size(), 0,
		"a Spell Speed 1 Spell is not a legal response [S1 p.44]")


static func _test_quick_effect_offered_in_response_window(t: TestCase) -> void:
	t.start("Quick Effect is offered and resolves in a response window")
	var d := TestFixtures.new_duel(17, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	var quick_def := TestFixtures.monster("Quick Guy")
	var quick := TestFixtures.logging_effect("quick", "quick_fired", order)
	quick.of_type(Enums.EffectType.QUICK)
	TestFixtures.with_effect(quick_def, quick)
	TestFixtures.give_monster_on_field(engine, 1, quick_def)

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Beater"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))

	t.eq(engine.waiting_player(), 1, "the opponent holding a Quick Effect is asked")
	var responses := engine.get_legal_responses(1)
	var use = TestFixtures.find_action(responses, Enums.ActionKind.ACTIVATE_EFFECT,
		-1, "quick")
	t.not_null(use, "the Quick Effect is offered as a response")
	t.eq(quick.spell_speed, Enums.SpellSpeed.SS2,
		"a Quick Effect is Spell Speed 2 [S1 p.45]")
	engine.submit_action(use)
	TestFixtures.pass_until_open(engine)
	t.eq(order, ["quick_fired"], "the Quick Effect resolved")


# ---------------------------------------------------------------------------
# RULES_SPEC.md 3 box D: the Chain closes only after two consecutive passes.
# ---------------------------------------------------------------------------

static func _test_two_consecutive_passes_close_the_chain(t: TestCase) -> void:
	t.start("chain closes after two consecutive passes, not one")
	var d := TestFixtures.new_duel(18, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	# Both players hold a Set Trap, so both have a real choice at every step.
	var t0 := TestFixtures.trap("Trap Zero")
	TestFixtures.with_effect(t0, TestFixtures.card_activation("activate",
		Enums.SpellSpeed.SS2, order, "t0"))
	var t1 := TestFixtures.trap("Trap One")
	TestFixtures.with_effect(t1, TestFixtures.card_activation("activate",
		Enums.SpellSpeed.SS2, order, "t1"))
	var c_p0 := TestFixtures.give_set_spell_trap(engine, 0, t0, 0)
	TestFixtures.give_set_spell_trap(engine, 1, t1, 0)

	# Player 0 opens the Chain in their own Main Phase (box A2, any Spell Speed).
	var open_trap = TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, c_p0.id)
	t.not_null(open_trap, "a Trap Set on an earlier turn can be activated")
	engine.submit_action(open_trap)

	t.eq(engine.timing, DuelEngine.Timing.CHAIN_BUILD, "a Chain is being built")
	t.eq(engine.waiting_player(), 1,
		"the player who did NOT activate the last link responds first [S2 box D]")

	engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1))
	t.eq(engine.timing, DuelEngine.Timing.CHAIN_BUILD,
		"one pass does not close the Chain")
	t.eq(engine.waiting_player(), 0, "the response opportunity alternates")

	engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0))
	t.eq(order, ["t0"], "two consecutive passes closed and resolved the Chain")
	t.eq(engine.state.chain.size(), 0, "the Chain is empty afterwards")


# ---------------------------------------------------------------------------
# Master prompt 45 / RULES_SPEC.md 3: events raised during resolution are handled only
# after the whole Chain has resolved.
# ---------------------------------------------------------------------------

static func _test_triggers_during_resolution_wait_for_the_chain_to_finish(
		t: TestCase) -> void:
	t.start("a trigger raised during resolution waits for the Chain to finish")
	var d := TestFixtures.new_duel(19, 0)
	var engine: DuelEngine = d["engine"]
	var c0: ScriptedController = d["p0"]
	c0.default_yes = true
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []

	# A monster that reacts to being destroyed, from the Graveyard.
	var victim_def := TestFixtures.monster("Doomed")
	var on_destroyed := TestFixtures.trigger_effect("on_destroyed",
		[GameEvent.Kind.CARD_DESTROYED], order, "trigger_fired", true)
	on_destroyed.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	TestFixtures.with_effect(victim_def, on_destroyed)
	var victim := TestFixtures.give_monster_on_field(engine, 0, victim_def)

	# A Spell whose resolution destroys it.
	var boom_def := TestFixtures.spell("Destroyer")
	var boom := TestFixtures.card_activation("activate", Enums.SpellSpeed.SS1,
		order, "spell_resolved")
	boom.resolve = func(ctx: EffectContext) -> void:
		order.append("spell_resolved")
		ctx.state.move_card(victim, Enums.Zone.GRAVEYARD,
			Enums.MoveReason.DESTROYED_BY_EFFECT, {"source_id": ctx.source.id})
	TestFixtures.with_effect(boom_def, boom)
	var boom_card := TestFixtures.give_to_hand(engine, 0, boom_def)

	var act = TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, boom_card.id)
	engine.submit_action(act)
	TestFixtures.pass_until_open(engine)

	t.eq(order, ["spell_resolved", "trigger_fired"],
		"the destruction trigger resolved after the Spell, on a later Chain")

	var chain_resolved := TestFixtures.first_event_index(
		engine, GameEvent.Kind.CHAIN_RESOLVED)
	var trigger_link := -1
	for i in range(engine.state.events.size()):
		var e: GameEvent = engine.state.events[i]
		if e.kind == GameEvent.Kind.CHAIN_LINK_ADDED \
				and str(e.data.get("card_name", "")) == "Doomed":
			trigger_link = i
			break
	t.is_true(chain_resolved != -1 and trigger_link > chain_resolved,
		"the trigger became a Chain Link only after CHAIN_RESOLVED — no new Chain was "
		+ "started mid-resolution (master prompt 45)")


# ---------------------------------------------------------------------------
# The V1 pool contains Champion's Vigilance: "when a monster(s) would be Summoned:
# Negate the Summon". The monster must never reach the field.
# ---------------------------------------------------------------------------

static func _test_summon_negation(t: TestCase) -> void:
	t.start("a negated Summon never places the monster on the field")
	var d := TestFixtures.new_duel(20, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var negator_def := TestFixtures.trap("Vigilance-like", Enums.STKind.COUNTER_TRAP)
	var negate := EffectDef.new("negate_summon",
		"when a monster(s) would be Summoned: Negate the Summon")
	negate.of_type(Enums.EffectType.CARD_ACTIVATION)
	negate.spell_speed = Enums.SpellSpeed.SS3
	negate.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	negate.trigger_events = [GameEvent.Kind.NORMAL_SUMMON_DECLARED]
	negate.resolve = func(ctx: EffectContext) -> void:
		var negated = ctx.engine.negate_pending_summon(ctx.source.id)
		if negated != null:
			ctx.state.move_card(negated, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.DESTROYED_BY_EFFECT, {"source_id": ctx.source.id})
	TestFixtures.with_effect(negator_def, negate)
	var negator := TestFixtures.give_set_spell_trap(engine, 1, negator_def, 0)

	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Blocked"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))

	t.eq(engine.waiting_player(), 1, "the opponent may respond to the declaration")
	var resp = TestFixtures.find_action(
		engine.get_legal_responses(1), Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(resp, "the Counter Trap is offered against the declared Summon")
	engine.submit_action(resp)
	TestFixtures.pass_until_open(engine)

	t.eq(mon.zone, Enums.Zone.GRAVEYARD,
		"the negated monster was destroyed and never occupied a Monster Zone")
	t.eq(engine.state.player(0).monster_count(), 0, "player 0 controls no monsters")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED), 0,
		"no Summon ever succeeded")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 1,
		"the negation was recorded as a semantic event")
	t.is_false(engine.state.player(0).can_normal_summon(),
		"the Normal Summon allowance was still consumed by the attempt")

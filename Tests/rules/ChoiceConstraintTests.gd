class_name ChoiceConstraintTests
extends RefCounted

## Generic gate, written before Soul Exchange. RULES_SPEC.md 5.9 / R39.
static func grant_spell() -> CardDef:
	var effect := EffectDef.new("require_material", "Require a selected opposing material this turn")
	effect.of_type(Enums.EffectType.CARD_ACTIVATION).targeting(1)
	effect.activation_locations = [Enums.ActivationLocation.HAND, Enums.ActivationLocation.FIELD_FACE_DOWN]
	effect.legal_targets = func(ctx: EffectContext) -> Array: return EffectPrimitives.opponent_monsters(ctx)
	effect.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_opponent_field_target(ctx)
		if target != null and target.is_monster():
			ctx.state.require_choice_this_turn(ctx.controller_id, SummonRules.TRIBUTE_CHOICE_SCOPE, target, ctx.source.id)
	return TestFixtures.with_effect(TestFixtures.spell("Choice grant"), effect)

static func board(pid: int = 0, definition: CardDef = null) -> Dictionary:
	var d := TestFixtures.new_duel(39001, pid)
	var e: DuelEngine = d.engine
	TestFixtures.advance_to_phase(e, Enums.Phase.MAIN_1)
	d.pid = pid
	d.target = TestFixtures.give_monster_on_field(e, 1 - pid, TestFixtures.monster("Required opponent"))
	d.own = TestFixtures.give_monster_on_field(e, pid, TestFixtures.monster("Own A"))
	d.other = TestFixtures.give_monster_on_field(e, pid, TestFixtures.monster("Own B"))
	d.boss = TestFixtures.give_to_hand(e, pid, TestFixtures.monster("Level eight", 8))
	d.small = TestFixtures.give_to_hand(e, pid, TestFixtures.monster("Level four"))
	d.spell = TestFixtures.give_to_hand(e, pid, definition if definition != null else grant_spell())
	return d

static func grant(t: TestCase, d: Dictionary) -> void:
	t.is_true(TestFixtures.activate_card(d.engine, d.pid, d.spell, [d.target.id]), "grant actually activated and resolved")
	t.eq(d.engine.state.required_choice_ids(d.pid, SummonRules.TRIBUTE_CHOICE_SCOPE), [d.target.id], "exact required material registered")

static func summon(t: TestCase, d: Dictionary, materials: Array, negate: bool = false) -> void:
	var e: DuelEngine = d.engine
	var n: CardInstance = null
	if negate:
		n = TestFixtures.give_set_spell_trap(e, 1 - d.pid, TestFixtures.summon_negator("Negator"))
	var a = TestFixtures.find_action(e.get_legal_actions(d.pid), Enums.ActionKind.TRIBUTE_SUMMON, d.boss.id)
	t.not_null(a, "Tribute Summon offered")
	if a == null: return
	t.is_true(e.submit_action(a.with_choices({"tribute_ids": materials.map(func(c): return c.id)})), "declared through engine")
	if negate:
		var r = TestFixtures.find_action(e.get_legal_responses(1 - d.pid), Enums.ActionKind.ACTIVATE_CARD, n.id)
		t.not_null(r, "real summon negator response offered")
		if r != null: t.is_true(e.submit_action(r), "negator activated")
	TestFixtures.pass_until_open(e)
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.NORMAL_SUMMON_DECLARED), 1, "declaration path happened")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.SUMMON_NEGATED), 1 if negate else 0, "negation path observed")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED), 0 if negate else 1, "success matches path")
	for material in materials:
		t.eq(material.zone, Enums.Zone.GRAVEYARD, "paid material stays in GY even after negation")
		t.is_true(e.state.player(material.owner_id).graveyard.has(material), "owner receives material")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.CONTROL_CHANGED), 0, "permission never changed control")

static func run() -> TestCase:
	var t := TestCase.new("ChoiceConstraintTests")
	for pid in [0, 1]:
		t.start("resolution, player ownership, independent scope and legal combinations seat %d" % pid)
		var d := board(pid)
		var e: DuelEngine = d.engine
		var hold := TestFixtures.give_set_spell_trap(e, 1 - pid, TestFixtures.activation_negator("Hold window"))
		var a = TestFixtures.find_action(e.get_legal_actions(pid), Enums.ActionKind.ACTIVATE_CARD, d.spell.id)
		t.not_null(a, "activation offered")
		if a == null: continue
		t.is_true(e.submit_action(a.with_choices({"target_ids": [d.target.id]})), "activation submitted")
		t.eq(e.state.choice_constraints.size(), 0, "not created at activation")
		t.not_null(TestFixtures.find_action(e.get_legal_responses(1-pid), Enums.ActionKind.ACTIVATE_CARD, hold.id), "real response window holds resolution")
		TestFixtures.pass_until_open(e)
		t.eq(e.state.choice_constraints.size(), 1, "created at resolution")
		t.eq(e.state.required_choice_ids(pid, "tribute"), [d.target.id], "belongs to activating seat")
		t.eq(e.state.required_choice_ids(1-pid, "tribute"), [], "opponent not constrained")
		t.eq(e.state.required_choice_ids(pid, "unrelated"), [], "scope is respected")
		t.eq(d.target.owner_id, 1-pid, "owner unchanged")
		t.eq(d.target.controller_id, 1-pid, "controller unchanged")
		t.not_null(TestFixtures.find_action(e.get_legal_actions(pid), Enums.ActionKind.NORMAL_SUMMON, d.small.id), "non-Tribute action legal")
		t.is_false(e.summons.tributes_satisfy(d.boss, [d.own, d.other]), "own-only combination refused")
		t.is_false(e.summons.tributes_satisfy(d.boss, [d.target]), "insufficient value refused")
		t.is_false(e.summons.tributes_satisfy(d.boss, [d.target, d.target]), "duplicate refused")
		t.is_true(e.summons.tributes_satisfy(d.boss, [d.target, d.own]), "first legal combination")
		t.is_true(e.summons.tributes_satisfy(d.boss, [d.other, d.target]), "second legal combination")
		var offer = TestFixtures.find_action(e.get_legal_actions(pid), Enums.ActionKind.TRIBUTE_SUMMON, d.boss.id)
		t.eq(offer.tribute_combinations.size(), 2, "complete legal combinations published")
		t.is_false(e.submit_action(offer.with_choices({"tribute_ids": [d.own.id, d.other.id]})), "forged own-only action rejected")
		t.eq(d.own.zone, Enums.Zone.MONSTER_ZONE, "rejection pays nothing")
		summon(t, d, [d.target, d.other])
	for mode in ["leave", "banish_return", "control", "face_down"]:
		t.start("constraint invalidation: " + mode)
		var d := board()
		var e: DuelEngine = d.engine
		grant(t, d)
		match mode:
			"leave": e.state.move_card(d.target, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
			"banish_return":
				e.state.move_card(d.target, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
				e.state.move_card(d.target, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.RULE, {"to_player": 1})
			"control": t.is_true(e.state.change_control(d.target, 0, d.spell.id, Enums.ControlDuration.PERMANENT), "real control change")
			"face_down":
				e.state.set_battle_position(d.target, Enums.Position.FACE_DOWN_DEFENSE, true)
				e.state.set_battle_position(d.target, Enums.Position.FACE_UP_ATTACK, true)
		t.eq(e.state.choice_constraints, [], "constraint permanently cleared")
		t.is_true(e.summons.tributes_satisfy(d.boss, [d.own, d.other]), "own choice restored")
	t.start("unsuitable target blocks tribute without lifting constraint")
	var d := board()
	grant(t, d)
	d.target.flags["cannot_be_tributed"] = true
	t.eq(d.engine.state.required_choice_ids(0, "tribute"), [d.target.id], "obligation still present")
	t.is_false(d.engine.summons.can_normal_summon_or_set(d.boss, 0), "no legal combination")
	t.not_null(TestFixtures.find_action(d.engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, d.small.id), "unrelated action still legal")
	d.target.flags.erase("cannot_be_tributed")
	t.is_true(d.engine.summons.can_normal_summon_or_set(d.boss, 0), "eligibility restored")
	t.start("double value optional and cannot free an opponent's zone for you")
	d = board()
	var double := EffectDef.new(SummonRules.TRIBUTE_VALUE_EFFECT_ID, "Can count as two for LIGHT")
	double.of_type(Enums.EffectType.CONTINUOUS)
	double.condition = func(ctx: EffectContext) -> bool: return ctx.params.summoning_card.current_attribute() == "LIGHT"
	d.own.definition = TestFixtures.with_effect(TestFixtures.monster("Generic double", 4), double)
	grant(t, d)
	t.is_true(d.engine.summons.tributes_satisfy(d.boss, [d.target, d.own]), "own double may count as one with required material")
	d.target.definition = d.own.definition
	t.is_true(d.engine.summons.tributes_satisfy(d.boss, [d.target]), "opponent double supplies both")
	for i in range(3): TestFixtures.give_monster_on_field(d.engine, 0, TestFixtures.monster("Fill %d" % i))
	t.is_false(d.engine.summons.tributes_satisfy(d.boss, [d.target]), "full own field: opposing tribute frees no own slot")
	t.is_true(d.engine.summons.tributes_satisfy(d.boss, [d.target, d.own]), "own material frees needed slot")
	d.engine.state.set_battle_position(d.target, Enums.Position.FACE_DOWN_DEFENSE, true)
	t.eq(d.engine.summons.tribute_value(d.target, d.boss), 1, "face-down double remains one")
	t.start("summon negation never refunds already-paid Tributes")
	d = board()
	grant(t, d)
	summon(t, d, [d.target, d.own], true)
	t.start("exact turn boundary, not End Phase entry")
	d = board()
	grant(t, d)
	t.is_true(TestFixtures.advance_to_phase(d.engine, Enums.Phase.END), "reached End Phase")
	t.eq(d.engine.state.required_choice_ids(0, "tribute"), [d.target.id], "still applies in End Phase")
	t.is_true(TestFixtures.end_turn(d.engine), "turn actually ended")
	t.eq(d.engine.state.choice_constraints, [], "cleared at turn boundary")
	t.start("two simultaneous constraints must both be included")
	d = board()
	grant(t, d)
	var second := TestFixtures.give_monster_on_field(d.engine, 1, TestFixtures.monster("Second opposing"))
	d.engine.state.require_choice_this_turn(0, "tribute", second, d.spell.id)
	t.is_false(d.engine.summons.tributes_satisfy(d.boss, [d.target, d.own]), "one required target insufficient")
	t.is_true(d.engine.summons.tributes_satisfy(d.boss, [d.target, second]), "both required targets legal")
	t.start("cost gate enforces qualifications and pays whole selection")
	d = board()
	grant(t, d)
	var ctx := EffectContext.new(d.engine.state, d.spell, d.spell.definition.effects[0])
	ctx.controller_id = 0
	t.is_false(EffectPrimitives.can_pay_tribute_cost(ctx, [d.own], 1), "self-only cost cannot substitute other card")
	t.eq(EffectPrimitives.pay_tribute_cost(ctx, [d.own], 1, "self cost"), [], "invalid payment does nothing")
	t.eq(d.own.zone, Enums.Zone.MONSTER_ZONE, "no partial payment")
	t.is_true(EffectPrimitives.can_pay_tribute_cost(ctx, [d.own, d.target], 2), "legal pair")
	t.eq(EffectPrimitives.pay_tribute_cost(ctx, [d.own, d.target], 2, "pair"), [d.target, d.own], "forced material included")
	t.eq(d.target.zone, Enums.Zone.GRAVEYARD, "cost paid")
	t.eq(d.target.controller_id, 1, "owner's GY with no control change")
	t.start("deterministic replay of recorded action payloads from identical fixture")
	var original := board()
	grant(t, original)
	summon(t, original, [original.target, original.own])
	var replay := board()
	var initial: int = replay.engine.log.actions.size()
	for record in original.engine.log.actions.slice(initial):
		t.is_true(replay.engine.submit_action(DuelAction.from_dict(record.action)), "recorded action revalidated")
	t.eq(replay.engine.log.entries, original.engine.log.entries, "identical event stream")
	t.eq(replay.engine.state.choice_constraints, original.engine.state.choice_constraints, "identical constraint state")
	return t

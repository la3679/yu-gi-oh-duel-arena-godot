class_name SoulExchangeTests
extends RefCounted
const CARD_UNDER_TEST := "Soul Exchange"

static func run() -> TestCase:
	var t := TestCase.new("SoulExchangeTests")
	var lib := CardRegistry.load_library()
	var defs: Dictionary = lib.cards
	var definition: CardDef = defs[CARD_UNDER_TEST]
	t.start("official clause shape")
	t.eq(lib.errors, [], "registry clean")
	t.eq(definition.effects.size(), 2, "both clauses")
	t.eq(definition.st_kind, Enums.STKind.NORMAL_SPELL, "Normal Spell")
	var clause: EffectDef = definition.effects[0]
	t.eq(clause.spell_speed, 1, "Spell Speed one")
	t.is_true(clause.targets, "targets")
	t.eq(clause.target_count_min, 1, "one target")
	t.eq(clause.target_count_max, 1, "only one target")
	t.is_false(clause.pay_cost.is_valid(), "permission not a cost")
	t.is_false(definition.effects[1].starts_chain, "condition is not another activation")
	for pid in [0, 1]:
		t.start("real pool summon and correct player duration seat %d" % pid)
		var d := ChoiceConstraintTests.board(pid, definition)
		var e: DuelEngine = d.engine
		d.target.definition = defs["Alexandrite Dragon"]
		d.boss.definition = defs["Metaphys Armed Dragon"]
		ChoiceConstraintTests.grant(t, d)
		t.eq(d.target.owner_id, 1-pid, "ownership unchanged")
		t.eq(d.target.controller_id, 1-pid, "control unchanged")
		t.is_true(e.state.player(pid).get_restriction("skip_battle_phase_this_turn", false), "activating player's turn locked")
		t.is_false(e.state.player(1-pid).get_restriction("skip_battle_phase_this_turn", false), "opponent not locked")
		t.is_false(e.summons.tributes_satisfy(d.boss, [d.own, d.other]), "own-only Tribute Summon refused while this card's permission stands")
		t.is_true(e.summons.tributes_satisfy(d.boss, [d.target, d.own]), "the granted opposing material completes the Summon")
		ChoiceConstraintTests.summon(t, d, [d.target, d.own])
		t.eq(d.spell.zone, Enums.Zone.GRAVEYARD, "Normal Spell cleaned up")
		t.is_true(TestFixtures.end_turn(e), "turn ended")
		t.is_false(e.state.player(pid).get_restriction("skip_battle_phase_this_turn", false), "exact reset")
	t.start("target legality and timing")
	var d := ChoiceConstraintTests.board(0, definition)
	var e: DuelEngine = d.engine
	var a = TestFixtures.find_action(e.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, d.spell.id)
	t.not_null(a, "own Main Phase activation offered")
	if a != null:
		t.eq(a.target_candidates, [d.target.id], "only opposing monster")
		t.is_false(e.submit_action(a.with_choices({"target_ids": [d.own.id]})), "own monster rejected")
		t.is_false(e.submit_action(a.with_choices({"target_ids": [d.spell.id]})), "Spell rejected")
		t.is_false(e.submit_action(a.with_choices({"target_ids": []})), "missing target rejected")
	t.is_false(ActivationRules.can_activate(e.state, d.spell, clause, 1), "opponent turn timing refused")
	e.state.battle_phase_conducted_this_turn = true
	t.is_false(ActivationRules.can_activate(e.state, d.spell, clause, 0), "after Battle Phase refused")
	e.state.battle_phase_conducted_this_turn = false
	e.state.phase = Enums.Phase.BATTLE
	t.is_false(ActivationRules.can_activate(e.state, d.spell, clause, 0), "Battle Phase refused")
	e.state.phase = Enums.Phase.MAIN_1
	e.state.move_card(d.target, Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE)
	t.is_false(ActivationRules.can_activate(e.state, d.spell, clause, 0), "no opposing monster refused")
	for mode in ["activation", "effect", "leave", "return", "control", "down", "source"]:
		t.start("real two-link Chain: " + mode)
		d = ChoiceConstraintTests.board(0, definition)
		e = d.engine
		var response: CardDef
		if mode == "activation": response = TestFixtures.activation_negator("Negate activation")
		elif mode == "effect": response = TestFixtures.effect_negator("Negate effect")
		else:
			var effect := TestFixtures.card_activation("interfere", 2, [])
			effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
			var victim: CardInstance = d.target
			var source: CardInstance = d.spell
			effect.resolve = func(ctx: EffectContext) -> void:
				match mode:
					"leave": ctx.state.move_card(victim, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
					"return":
						ctx.state.move_card(victim, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
						ctx.state.move_card(victim, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.RULE, {"to_player": 1})
					"control": ctx.state.change_control(victim, 0, ctx.source.id, Enums.ControlDuration.PERMANENT)
					"down": ctx.state.set_battle_position(victim, Enums.Position.FACE_DOWN_DEFENSE, true)
					"source": ctx.state.destroy(source, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)
			response = TestFixtures.with_effect(TestFixtures.trap("Interference"), effect)
		var rcard := TestFixtures.give_set_spell_trap(e, 1, response)
		a = TestFixtures.find_action(e.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, d.spell.id)
		t.not_null(a, "first link offered")
		if a == null: continue
		t.is_true(e.submit_action(a.with_choices({"target_ids": [d.target.id]})), "first link activated")
		t.eq(e.state.choice_constraints, [], "no constraint before resolution")
		var r = TestFixtures.find_action(e.get_legal_responses(1), Enums.ActionKind.ACTIVATE_CARD, rcard.id)
		t.not_null(r, "second link offered")
		if r == null: continue
		t.is_true(e.submit_action(r), "second link activated")
		TestFixtures.pass_until_open(e)
		t.eq(TestFixtures.count_events(e, GameEvent.Kind.CHAIN_LINK_ADDED), 2, "two actual links")
		t.eq(e.state.required_choice_ids(0, "tribute"), [d.target.id] if mode in ["down", "source"] else [], "revalidation result")
		t.eq(e.state.player(0).get_restriction("skip_battle_phase_this_turn", false), mode != "activation", "activation negation alone lifts Battle condition")
		if mode in ["activation", "effect"]:
			t.eq(TestFixtures.count_events(e, GameEvent.Kind.ACTIVATION_NEGATED if mode == "activation" else GameEvent.Kind.EFFECT_NEGATED), 1, "negation really occurred")
		if mode == "down": ChoiceConstraintTests.summon(t, d, [d.target, d.own])
	t.start("Kaiser interactions: both placements, LIGHT and non-LIGHT")
	for opposing in [true, false]:
		d = ChoiceConstraintTests.board(0, definition)
		e = d.engine
		d.boss.definition = defs["Witchcrafter Golem Aruru"]
		if opposing: d.target.definition = defs["Kaiser Sea Horse"]
		else: d.own.definition = defs["Kaiser Sea Horse"]
		ChoiceConstraintTests.grant(t, d)
		ChoiceConstraintTests.summon(t, d, [d.target] if opposing else [d.target, d.own])
	t.start("post-resolution reset, typed Tribute costs and self cost")
	d = ChoiceConstraintTests.board(0, definition)
	e = d.engine
	d.target.definition = defs["Alexandrite Dragon"]
	ChoiceConstraintTests.grant(t, d)
	var kaiba := TestFixtures.give_monster_on_field(e, 0, defs["Kaibaman"])
	TestFixtures.give_to_hand(e, 0, defs["Blue-Eyes White Dragon"])
	t.is_false(TestFixtures.activate_effect(e, 0, kaiba, "tribute_self_summon_blue_eyes"), "self-Tribute cannot omit required opponent")
	var tactics := TestFixtures.give_to_hand(e, 0, defs["Dragonic Tactics"])
	d.own.definition = defs["Rabidragon"]
	TestFixtures.give(e, 0, defs["Blue-Eyes White Dragon"], Enums.Zone.DECK)
	t.is_true(TestFixtures.activate_card(e, 0, tactics), "typed cost uses opposing Dragon plus own Dragon")
	t.eq(d.target.zone, Enums.Zone.GRAVEYARD, "target paid as cost")
	t.eq(d.own.zone, Enums.Zone.GRAVEYARD, "second cost paid")
	t.eq(TestFixtures.count_events(e, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1, "Tactics actually summoned")
	t.eq(d.p0.errors, [], "no scripted fallback")
	t.start("Soul Exchange action replay determinism")
	var original := ChoiceConstraintTests.board(0, definition)
	ChoiceConstraintTests.grant(t, original)
	ChoiceConstraintTests.summon(t, original, [original.target, original.own])
	var replay := ChoiceConstraintTests.board(0, definition)
	var initial: int = replay.engine.log.actions.size()
	for record in original.engine.log.actions.slice(initial):
		t.is_true(replay.engine.submit_action(DuelAction.from_dict(record.action)), "recorded action replayed")
	t.eq(replay.engine.log.entries, original.engine.log.entries, "identical events")
	t.eq(replay.engine.state.choice_constraints, original.engine.state.choice_constraints, "identical constraints")
	return t

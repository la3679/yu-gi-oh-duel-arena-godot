class_name AHeroEmergesTests
extends RefCounted

## Per-card suite for `A Hero Emerges`. Research/CARD_RULINGS.md **R15**.
##
##   "When an opponent's monster declares an attack: Your opponent chooses 1 random card
##    from your hand, then if it is a monster that can be Special Summoned, Special Summon
##    it. Otherwise, send it to the GY."
##
## The generic half — a random pick out of a hidden hand, and "can this be Special Summoned
## right now?" — is proved by the gate in `HiddenInfoTests` (batch 15 unit A), which was
## written and green before this card existed. What is specific to this card, and what this
## suite is about, is:
##
##   * the three facts the printed English text does not carry (R15 Parts A, B and C) —
##     an empty or monsterless hand forbids the ACTIVATION; the requirement is really "a
##     monster this effect could Special Summon RIGHT NOW"; and if that stops being true by
##     resolution the effect does nothing at all, **not even the random choice**;
##   * that the two halves of "Otherwise" are one decision, so a monster that cannot be
##     Special Summoned goes to the Graveyard exactly as a Spell does;
##   * that the whole thing stays replayable and stays private.
##
## Seeds are chosen so each branch is driven deterministically, and the branch-sweep tests
## run a fixed list of seeds so that "both branches happen" is itself asserted rather than
## assumed. A test that only ever saw one branch would be vacuous, which is the failure
## mode a random effect invites.

const CARD_UNDER_TEST := "A Hero Emerges"
const EFFECT_ID := "random_hand_card_summoned_or_sent"


static func run() -> TestCase:
	var t := TestCase.new("AHeroEmergesTests")
	# Shape and declarations
	_test_clause_shape(t)
	_test_it_does_not_target(t)
	_test_the_damage_step_is_closed(t)
	# Activation timing
	_test_offered_only_in_the_attack_declaration_window(t)
	_test_not_offered_when_you_are_the_attacker(t)
	_test_a_direct_attack_opens_it_too(t)
	_test_not_the_turn_it_was_set(t)
	# Activation legality — R15 Parts A and B
	_test_an_empty_hand_forbids_the_activation(t)
	_test_a_hand_with_no_monster_forbids_the_activation(t)
	_test_a_full_monster_zone_forbids_the_activation(t)
	_test_only_an_unsummonable_monster_forbids_the_activation(t)
	_test_one_summonable_monster_is_enough(t)
	# Resolution — the two branches
	_test_a_chosen_monster_is_special_summoned(t)
	_test_a_chosen_spell_or_trap_is_sent_to_the_graveyard(t)
	_test_both_branches_are_reached_across_seeds(t)
	_test_a_chosen_monster_that_cannot_be_summoned_is_sent_to_the_graveyard(t)
	_test_the_send_is_not_a_discard(t)
	_test_the_position_is_the_summoning_player_s_choice(t)
	_test_ownership_and_control_stay_with_the_trap_s_controller(t)
	# R15 Part C — the resolution-time gate
	_test_losing_the_last_summonable_monster_suppresses_everything(t)
	_test_filling_the_monster_zone_suppresses_everything(t)
	# Hidden information — R15 Part H
	_test_only_the_chosen_card_becomes_public(t)
	_test_the_chooser_is_asked_nothing(t)
	# Interaction
	_test_the_special_summon_is_announced_and_can_be_responded_to(t)
	_test_activation_negated(t)
	_test_effect_negated(t)
	_test_an_attack_negated_above_it_does_not_undo_it(t)
	# Replay
	_test_the_same_seed_replays_to_the_same_card(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


static func _effect() -> EffectDef:
	for entry in _def().effects:
		var e: EffectDef = entry
		if e.effect_id == EFFECT_ID:
			return e
	return null


## Player 1 holds the Trap; player 0 is the turn player and attacks.
## Returns {"engine", "p0", "p1", "ahe", "attacker", "blocker"}.
static func _board(seed_value: int, with_blocker: bool = true) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Opposing Attacker", 4, 1800, 1000))
	d["blocker"] = null
	if with_blocker:
		d["blocker"] = TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Wall", 4, 100, 2500), Enums.Position.FACE_UP_DEFENSE)
	d["ahe"] = TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	return d


## Replace player 1's hand with exactly these definitions, in order.
static func _stack_hand(engine: DuelEngine, defs: Array) -> Array:
	engine.state.player(1).hand.clear()
	var out: Array = []
	for def in defs:
		out.append(TestFixtures.give_to_hand(engine, 1, def))
	return out


static func _monster(name: String) -> CardDef:
	return TestFixtures.monster(name, 4, 1000, 1000)


## "You can only control 1 <name>" as the rules layer really asks it — a CONTINUOUS clause
## registered under `SummonRules.CONTROL_LIMIT_EFFECT_ID`, the shape `Inari Fire` prints.
## Synthetic because the V1 pool holds exactly one copy of each card that carries the
## limit, so a hand copy alongside a field copy cannot arise from the printed decks
## (R15 Part I).
static func _control_limited(name: String) -> CardDef:
	var clause := EffectDef.new(SummonRules.CONTROL_LIMIT_EFFECT_ID,
		"Test: You can only control 1 \"%s\"." % name)
	clause.of_type(Enums.EffectType.CONTINUOUS)
	clause.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.controls_no_other_copy(ctx)
	return TestFixtures.with_effect(_monster(name), clause)


static func _response(engine: DuelEngine, pid: int, card: CardInstance):
	return TestFixtures.find_action(engine.get_legal_responses(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id, EFFECT_ID)


## Activate the Trap in the window that is currently open and let the Chain finish.
static func _activate(engine: DuelEngine, ahe: CardInstance) -> bool:
	var offered = _response(engine, 1, ahe)
	if offered == null:
		return false
	if not engine.submit_action(offered):
		return false
	TestFixtures.pass_until_open(engine)
	return true


## Activate the Trap and let player 0 answer with `responder`, then settle.
## Mirrors the loop `DamageCondenserTests` uses for the same purpose.
static func _activate_with_response(engine: DuelEngine, ahe: CardInstance,
		responder: CardInstance) -> bool:
	var activated := false
	var answered := false
	for i in range(24):
		if not activated:
			var offered = _response(engine, 1, ahe)
			if offered != null and engine.submit_action(offered):
				activated = true
				continue
		if activated and not answered:
			var response = TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, responder.id)
			if response != null and engine.submit_action(response):
				answered = true
				continue
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)
	return activated and answered


## The card the random pick chose, read from the public reveal the primitive raises.
## Null when no choice was made at all — which is itself an assertable outcome.
static func _chosen(engine: DuelEngine, mark: int, ahe: CardInstance):
	for ev in TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED, mark):
		if int(ev.data.get("source_id", -1)) != ahe.id:
			continue
		return engine.state.instance(int(ev.data.get("card_id", -1)))
	return null


# ---------------------------------------------------------------------------
# Shape and declarations
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("one printed clause, one EffectDef: a Normal Trap that answers an attack "
		+ "declaration")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP, "it is a Normal Trap")
	t.eq(def.effects.size(), 1, "one clause, one EffectDef")

	var e := _effect()
	t.not_null(e, "the clause is registered under its effect id")
	t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"activating the Trap card itself, not an effect of a face-up card")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2 [S1 p.44-45]")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"activated from the Spell & Trap Zone, face-down")
	t.eq(e.trigger_events, [GameEvent.Kind.ATTACK_DECLARED],
		"'When an opponent's monster declares an attack' is a real timing requirement")
	t.eq(e.optionality, Enums.Optionality.OPTIONAL, "a Trap you choose to activate")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")
	t.is_false(e.once_per_turn_named_effect, "and none is implied")
	t.eq(e.ruling_ref, "R15", "the clause carries its ruling reference")
	t.eq(e.clause_text,
		"When an opponent's monster declares an attack: Your opponent chooses 1 random "
		+ "card from your hand, then if it is a monster that can be Special Summoned, "
		+ "Special Summon it. Otherwise, send it to the GY.",
		"the clause text is the official English text, verbatim")


static func _test_it_does_not_target(t: TestCase) -> void:
	t.start("R15 Part D: 対象を取る効果ではありません — it does not target, and could not: "
		+ "the candidates are in a hidden hand and the choice is made at resolution")
	var e := _effect()
	t.is_false(e.targets, "no targeting")
	t.eq(e.target_count_min, 0, "no minimum target count")
	t.eq(e.target_count_max, 0, "and no maximum")
	t.is_false(e.legal_targets.is_valid(), "no legal_targets callable")
	t.is_false(e.targets_valid.is_valid(), "and no target validator")

	# And the offered action really carries no candidates, which is what a UI would show.
	var d := _board(1501)
	var engine: DuelEngine = d["engine"]
	_stack_hand(engine, [_monster("Hand Monster")])
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var offered = _response(engine, 1, d["ahe"])
	t.not_null(offered, "the Trap is offered")
	t.eq(offered.target_candidates, [], "with no target candidates at all")


static func _test_the_damage_step_is_closed(t: TestCase) -> void:
	t.start("R15 Part G: the window is the attack declaration, so the Damage Step is "
		+ "closed — asserted DIRECTLY, because RULES_SPEC 10.7 says 'never offered there' "
		+ "would prove nothing for a clause whose trigger cannot occur there")
	var e := _effect()
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"the permission is NONE, stated rather than left to the default")

	var d := _board(1502)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	t.is_true(ActivationRules.damage_step_ok(state, e),
		"outside the Damage Step the permission gate allows it")

	# Force the Damage Step and ask the rule itself, sub-step by sub-step. This is the
	# assertion that actually proves the permission, and R15 Part G records why it looks
	# redundant next to the window test and is not.
	state.battle_step = Enums.BattleStep.DAMAGE
	for substep in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		state.damage_substep = substep
		t.is_false(ActivationRules.damage_step_ok(state, e),
			"refused in Damage Step sub-step %d" % int(substep))

	# The control: a clause that DOES carry a permission is allowed in its own sub-step,
	# so the assertions above are not passing because the gate refuses everything.
	var permitted := EffectDef.new("permitted", "Test")
	permitted.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_true(ActivationRules.damage_step_ok(state, permitted),
		"a clause that carries UNTIL_DAMAGE_CALC is allowed in the same sub-step")


# ---------------------------------------------------------------------------
# Activation timing
# ---------------------------------------------------------------------------

static func _test_offered_only_in_the_attack_declaration_window(t: TestCase) -> void:
	t.start("offered in the window an attack declaration opens, and in no other window")
	var d := _board(1503)
	var engine: DuelEngine = d["engine"]
	var ahe: CardInstance = d["ahe"]
	_stack_hand(engine, [_monster("Hand Monster"), TestFixtures.spell("Hand Spell")])

	# Before any attack, in the opponent's Battle Phase, there is no declaration to answer.
	t.is_false(TestFixtures.has_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, ahe.id, EFFECT_ID),
		"not offered before an attack is declared")

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.not_null(_response(engine, 1, ahe), "now it is offered")

	# And it is gone again once the Battle Phase is over and an open game state returns.
	TestFixtures.pass_until_open(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 1, "it is now the Trap controller's own turn")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, ahe.id, EFFECT_ID),
		"and it is not offered in an open game state — no monster is declaring an attack")


static func _test_not_offered_when_you_are_the_attacker(t: TestCase) -> void:
	t.start("'when an OPPONENT'S monster declares an attack' — your own attack does not "
		+ "open this window")
	var d := TestFixtures.new_duel(1504, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.eq(engine.state.turn_player_id, 1, "it is the Trap controller's own Battle Phase")

	var mine := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("My Attacker", 4, 1800, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Their Wall", 4, 100, 100))
	var ahe := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	_stack_hand(engine, [_monster("Hand Monster")])
	# The control is set up BEFORE the declaration, in the same window: the OPPONENT holds
	# an identical copy and an identical hand, so the only difference between the two
	# answers is whose monster is attacking. (A window with no legal response for either
	# side is auto-passed and closed, so a control added afterwards would test nothing.)
	var theirs_ahe := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	engine.state.player(0).hand.clear()
	TestFixtures.give_to_hand(engine, 0, _monster("Their Hand Monster"))

	t.is_true(TestFixtures.attack(engine, mine, theirs), "player 1 declares the attack")
	t.is_null(_response(engine, 1, ahe),
		"the Trap's own controller attacking does not make it activatable")
	t.not_null(TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, theirs_ahe.id, EFFECT_ID),
		"the player being attacked IS offered it, with the same attack")


static func _test_a_direct_attack_opens_it_too(t: TestCase) -> void:
	t.start("nothing in the clause narrows the attack — a DIRECT attack declaration opens "
		+ "the window exactly as an attack on a monster does")
	var d := _board(1505, false)
	var engine: DuelEngine = d["engine"]
	_stack_hand(engine, [_monster("Hand Monster")])
	t.eq(engine.state.player(1).monsters().size(), 0,
		"the Trap's controller has no monsters, so the attack is direct")

	t.is_true(TestFixtures.attack(engine, d["attacker"], null),
		"a direct attack is declared")
	var declared := TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_DECLARED)
	t.eq(declared.size(), 1, "one attack declaration")
	t.is_true(bool(declared[0].data.get("direct", false)), "and it really was direct")
	t.not_null(_response(engine, 1, d["ahe"]), "the Trap is offered")


static func _test_not_the_turn_it_was_set(t: TestCase) -> void:
	t.start("a Trap Set this turn cannot be activated this turn [S1 p.31], and this card "
		+ "adds nothing that changes that")
	var d := _board(1506)
	var engine: DuelEngine = d["engine"]
	var fresh := TestFixtures.give_set_spell_trap(engine, 1, _def(),
		engine.state.turn_number)
	_stack_hand(engine, [_monster("Hand Monster")])

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.is_null(_response(engine, 1, fresh), "the freshly Set copy is not offered")
	t.not_null(_response(engine, 1, d["ahe"]),
		"while the copy Set on an earlier turn is — so the refusal is about the Set turn")


# ---------------------------------------------------------------------------
# Activation legality — R15 Parts A and B, the facts the English text does not carry
# ---------------------------------------------------------------------------

static func _test_an_empty_hand_forbids_the_activation(t: TestCase) -> void:
	t.start("R15 Part A: 自分の手札が0枚の場合…発動する事自体ができません — an EMPTY hand "
		+ "forbids the activation outright, which the printed English text does not say")
	var d := _board(1507)
	var engine: DuelEngine = d["engine"]
	engine.state.player(1).hand.clear()
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.is_null(_response(engine, 1, d["ahe"]), "the Trap is not offered at all")
	t.is_true(engine.state.instance(d["ahe"].id).is_face_down(), "and it is still Set")

	# The control, on an identical board built from the same seed with ONE monster in the
	# hand. It has to be a separate board: a response window nobody can answer is
	# auto-passed and closed, so adding a card to this one would prove nothing.
	var d2 := _board(1507)
	var engine2: DuelEngine = d2["engine"]
	_stack_hand(engine2, [_monster("Late Arrival")])
	t.is_true(TestFixtures.attack(engine2, d2["attacker"], d2["blocker"]),
		"the same attack is declared on the control board")
	t.not_null(_response(engine2, 1, d2["ahe"]),
		"one monster in the hand is the whole difference")


static func _test_a_hand_with_no_monster_forbids_the_activation(t: TestCase) -> void:
	t.start("R15 Part A: 自分の手札にモンスターカードがない場合 — a hand of Spells and Traps "
		+ "forbids the activation too")
	var d := _board(1508)
	var engine: DuelEngine = d["engine"]
	_stack_hand(engine, [TestFixtures.spell("Hand Spell A"),
		TestFixtures.spell("Hand Spell B"), TestFixtures.trap("Hand Trap")])
	t.eq(engine.state.player(1).hand.size(), 3, "three cards, none of them a monster")

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.is_null(_response(engine, 1, d["ahe"]), "the Trap is not offered")

	var d2 := _board(1508)
	var engine2: DuelEngine = d2["engine"]
	_stack_hand(engine2, [TestFixtures.spell("Hand Spell A"),
		TestFixtures.spell("Hand Spell B"), TestFixtures.trap("Hand Trap"),
		_monster("The One Monster")])
	t.is_true(TestFixtures.attack(engine2, d2["attacker"], d2["blocker"]),
		"the same attack is declared on the control board")
	t.not_null(_response(engine2, 1, d2["ahe"]),
		"the same three cards plus one monster IS enough")


static func _test_a_full_monster_zone_forbids_the_activation(t: TestCase) -> void:
	t.start("R15 Part B: the requirement is a monster this effect could Special Summon "
		+ "RIGHT NOW, so a full Monster Zone forbids the activation even with a hand full "
		+ "of monsters")
	var d := _board(1509)
	var engine: DuelEngine = d["engine"]
	_stack_hand(engine, [_monster("Hand Monster A"), _monster("Hand Monster B")])
	# The board already holds the blocker; fill the rest.
	for i in range(PlayerState.MONSTER_ZONE_COUNT):
		if engine.state.player(1).has_free_monster_zone():
			TestFixtures.give_monster_on_field(engine, 1,
				TestFixtures.monster("Filler %d" % i, 4, 100, 100))
	t.is_false(engine.state.player(1).has_free_monster_zone(),
		"every Monster Zone is occupied")

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.is_null(_response(engine, 1, d["ahe"]),
		"the Trap is not offered — two monsters in hand and nowhere to put either")

	# The control: the identical board with ONE zone left free.
	var d2 := _board(1509)
	var engine2: DuelEngine = d2["engine"]
	_stack_hand(engine2, [_monster("Hand Monster A"), _monster("Hand Monster B")])
	for i in range(PlayerState.MONSTER_ZONE_COUNT - 2):
		TestFixtures.give_monster_on_field(engine2, 1,
			TestFixtures.monster("Filler %d" % i, 4, 100, 100))
	t.is_true(engine2.state.player(1).has_free_monster_zone(),
		"one Monster Zone is free on the control board")
	t.is_true(TestFixtures.attack(engine2, d2["attacker"], d2["blocker"]),
		"the same attack is declared")
	t.not_null(_response(engine2, 1, d2["ahe"]),
		"and there the same hand IS enough — the refusal was about the room")


static func _test_only_an_unsummonable_monster_forbids_the_activation(t: TestCase) -> void:
	t.start("R15 Part B, the Gozen Match shape: a hand whose ONLY monster could not be "
		+ "placed does not satisfy the requirement — here because 'You can only control 1' "
		+ "already has a copy on the field")
	var d := _board(1510)
	var engine: DuelEngine = d["engine"]
	var limited := _control_limited("Only One Of These")
	_stack_hand(engine, [limited, TestFixtures.spell("Hand Spell")])
	var on_field := TestFixtures.give_monster_on_field(engine, 1, limited)

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.is_null(_response(engine, 1, d["ahe"]),
		"a monster in hand that cannot legally be Special Summoned is not a candidate")
	t.eq(on_field.zone, Enums.Zone.MONSTER_ZONE, "the blocking copy is on the field")

	# The control: the identical hand with NO copy on the field is legal, so the refusal
	# is about the restriction and not about the card being unusual.
	var d2 := _board(1510)
	var engine2: DuelEngine = d2["engine"]
	_stack_hand(engine2, [_control_limited("Only One Of These"),
		TestFixtures.spell("Hand Spell")])
	t.is_true(TestFixtures.attack(engine2, d2["attacker"], d2["blocker"]),
		"the same attack is declared")
	t.not_null(_response(engine2, 1, d2["ahe"]),
		"with no copy on the field the same hand is enough")


static func _test_one_summonable_monster_is_enough(t: TestCase) -> void:
	t.start("the requirement is one candidate, not a whole hand of them: a single "
		+ "summonable monster beside any number of unusable cards is enough")
	var d := _board(1511)
	var engine: DuelEngine = d["engine"]
	var limited := _control_limited("Only One Of These")
	TestFixtures.give_monster_on_field(engine, 1, limited)
	_stack_hand(engine, [TestFixtures.spell("Hand Spell"), limited,
		TestFixtures.trap("Hand Trap"), _monster("The One Candidate")])

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	t.not_null(_response(engine, 1, d["ahe"]), "the Trap is offered")

	# And the candidate list really is one card, which is what the requirement counted.
	var ctx := EffectContext.new(engine.state, d["ahe"], _effect())
	ctx.controller_id = 1
	var candidates := EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx, 1)
	t.eq(candidates.size(), 1, "exactly one card in that hand qualifies")
	t.eq(candidates[0].card_name(), "The One Candidate", "and it is the ordinary monster")


# ---------------------------------------------------------------------------
# Resolution — the two branches
# ---------------------------------------------------------------------------

## Drive one full activation with a stacked hand, and report what happened.
static func _run_once(seed_value: int, hand: Array) -> Dictionary:
	var d := _board(seed_value)
	var engine: DuelEngine = d["engine"]
	var cards := _stack_hand(engine, hand)
	if not TestFixtures.attack(engine, d["attacker"], d["blocker"]):
		return {"ok": false}
	var mark: int = engine.state.events.size()
	var activated := _activate(engine, d["ahe"])
	return {
		"ok": activated, "engine": engine, "ahe": d["ahe"], "cards": cards,
		"mark": mark, "chosen": _chosen(engine, mark, d["ahe"]),
		"p0": d["p0"], "p1": d["p1"],
	}


static func _test_a_chosen_monster_is_special_summoned(t: TestCase) -> void:
	t.start("the chosen card is a monster that can be Special Summoned: it is Special "
		+ "Summoned, to the Trap controller's own field")
	var r := _run_once(1512, [_monster("Only Monster")])
	t.is_true(r["ok"], "the Trap was activated and resolved")
	var engine: DuelEngine = r["engine"]
	var chosen: CardInstance = r["chosen"]
	t.not_null(chosen, "a card was chosen")
	t.eq(chosen.card_name(), "Only Monster", "the only card in the hand")
	t.eq(chosen.zone, Enums.Zone.MONSTER_ZONE, "it is on the field")
	t.eq(chosen.controller_id, 1, "controlled by the Trap's controller")
	t.is_true(chosen.is_face_up(), "face-up, as a Special Summon is [S1 p.24]")
	t.eq(engine.state.player(1).hand.size(), 0, "and it left the hand")
	# The only card in that Graveyard is the resolved Normal Trap itself, which is ordinary
	# cleanup and not the effect: "Otherwise" was never reached.
	t.eq(engine.state.player(1).graveyard.size(), 1, "one card is in the Graveyard")
	t.eq((engine.state.player(1).graveyard[0] as CardInstance).card_name(),
		CARD_UNDER_TEST, "and it is the spent Trap, not anything out of the hand")

	var summons := TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, chosen.id)
	t.eq(summons, 1, "exactly one Special Summon happened")
	t.is_true(chosen.properly_special_summoned,
		"and it counts as properly Special Summoned")


static func _test_a_chosen_spell_or_trap_is_sent_to_the_graveyard(t: TestCase) -> void:
	t.start("R15 Part E: the chosen card is not a monster, so it is SENT to the Graveyard "
		+ "— and the monster that made the activation legal stays in the hand")
	# Two cards, one of them a monster so the activation is legal at all. Sweep seeds
	# until the pick lands on the Spell, then assert that run.
	var found := false
	for seed_value in range(1600, 1700):
		var r := _run_once(seed_value, [_monster("Hand Monster"),
			TestFixtures.spell("Hand Spell")])
		if not r["ok"]:
			continue
		var chosen: CardInstance = r["chosen"]
		if chosen == null or chosen.card_name() != "Hand Spell":
			continue
		found = true
		var engine: DuelEngine = r["engine"]
		t.eq(chosen.zone, Enums.Zone.GRAVEYARD, "the Spell is in the Graveyard")
		t.eq(chosen.owner_id, 1, "in its OWNER's Graveyard")
		# Two cards in that Graveyard: the Spell the effect sent, and the spent Trap.
		t.eq(engine.state.player(1).graveyard.size(), 2, "the Spell and the spent Trap")
		t.is_true(engine.state.player(1).graveyard.has(chosen),
			"and the Spell is one of them")
		t.eq(engine.state.player(1).hand.size(), 1, "the other card is still in the hand")
		t.eq((engine.state.player(1).hand[0] as CardInstance).card_name(), "Hand Monster",
			"and it is the monster — nothing was Special Summoned")
		t.eq(engine.state.player(1).monsters().size(), 1,
			"the field still holds only the blocker")
		break
	t.is_true(found, "a seed in the swept range chose the Spell — the branch is reachable")


static func _test_both_branches_are_reached_across_seeds(t: TestCase) -> void:
	t.start("across a fixed sweep of seeds the same board reaches BOTH branches, so "
		+ "neither branch's test is passing because the pick never varies")
	var summoned := 0
	var sent := 0
	for seed_value in range(1700, 1760):
		var r := _run_once(seed_value, [_monster("Hand Monster"),
			TestFixtures.spell("Hand Spell")])
		if not r["ok"]:
			continue
		var chosen: CardInstance = r["chosen"]
		if chosen == null:
			continue
		if chosen.zone == Enums.Zone.MONSTER_ZONE:
			summoned += 1
		elif chosen.zone == Enums.Zone.GRAVEYARD:
			sent += 1
	t.is_true(summoned > 0, "some seeds Special Summoned the monster (%d)" % summoned)
	t.is_true(sent > 0, "some seeds sent the Spell to the Graveyard (%d)" % sent)
	t.eq(summoned + sent, 60, "and every run took exactly one of the two branches")


static func _test_a_chosen_monster_that_cannot_be_summoned_is_sent_to_the_graveyard(
		t: TestCase) -> void:
	t.start("R15 Part E, the half the English text hides: the chosen card IS a monster but "
		+ "this effect cannot Special Summon it, so it goes to the Graveyard exactly as a "
		+ "Spell would")
	var limited_found := false
	var ordinary_found := false
	for seed_value in range(1800, 1900):
		var d := _board(seed_value)
		var engine: DuelEngine = d["engine"]
		var limited := _control_limited("Only One Of These")
		TestFixtures.give_monster_on_field(engine, 1, limited)
		_stack_hand(engine, [limited, _monster("Ordinary Monster")])
		if not TestFixtures.attack(engine, d["attacker"], d["blocker"]):
			continue
		var mark: int = engine.state.events.size()
		if not _activate(engine, d["ahe"]):
			continue
		var chosen = _chosen(engine, mark, d["ahe"])
		if chosen == null:
			continue
		var card: CardInstance = chosen
		if card.card_name() == "Only One Of These" and not limited_found:
			limited_found = true
			t.eq(card.zone, Enums.Zone.GRAVEYARD,
				"the control-limited monster was SENT to the Graveyard, not Summoned")
			t.eq(card.last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
				"as a send by effect")
			t.eq(TestFixtures.count_events_for(engine,
				GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, card.id), 0,
				"and no Special Summon of it was even attempted successfully")
		elif card.card_name() == "Ordinary Monster" and not ordinary_found:
			ordinary_found = true
			t.eq(card.zone, Enums.Zone.MONSTER_ZONE,
				"while the ordinary monster in the same hand IS Special Summoned")
		if limited_found and ordinary_found:
			break
	t.is_true(limited_found, "the unsummonable-monster branch was reached")
	t.is_true(ordinary_found, "and so was its control, on the same board")


static func _test_the_send_is_not_a_discard(t: TestCase) -> void:
	t.start("R15 Part E: 墓地へ送る is a SEND, never a discard [S1 p.52-53] — a future card "
		+ "that watches for a discard must not see this")
	var found := false
	for seed_value in range(1900, 2000):
		var r := _run_once(seed_value, [_monster("Hand Monster"),
			TestFixtures.trap("Hand Trap")])
		if not r["ok"]:
			continue
		var chosen: CardInstance = r["chosen"]
		if chosen == null or chosen.card_name() != "Hand Trap":
			continue
		found = true
		t.eq(chosen.last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
			"the move reason is SENT_TO_GY_BY_EFFECT")
		t.ne(chosen.last_move_reason, Enums.MoveReason.DISCARDED,
			"and emphatically not DISCARDED — the two are different things")
		break
	t.is_true(found, "a seed in the swept range chose the Trap")


static func _test_the_position_is_the_summoning_player_s_choice(t: TestCase) -> void:
	t.start("R15 Part F: neither text names a position, so the SUMMONING player chooses "
		+ "face-up Attack or face-up Defense [S1 p.24] — the deliberate opposite of "
		+ "`Damage Condenser`, whose text does name one")
	var d := _board(1513)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p1"]
	controller.queue_for(Enums.DecisionKind.CHOOSE_POSITION,
		[Enums.Position.FACE_UP_DEFENSE])
	_stack_hand(engine, [_monster("Only Monster")])
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate(engine, d["ahe"]), "the Trap resolves")

	var chosen = _chosen(engine, mark, d["ahe"])
	t.not_null(chosen, "a card was chosen")
	var card: CardInstance = chosen
	t.eq(card.position, Enums.Position.FACE_UP_DEFENSE,
		"it was Summoned in the position its CONTROLLER asked for")
	t.eq(controller.errors, [], "the scripted answer matched the prompt the engine raised")

	var position_prompts := 0
	for request in controller.seen_requests:
		if request.kind == Enums.DecisionKind.CHOOSE_POSITION:
			position_prompts += 1
	t.eq(position_prompts, 1, "the position was asked exactly once")

	# The control: the default policy answers Attack Position, so the assertion above is
	# about the answer given and not about a hard-coded position.
	var d2 := _board(1514)
	var engine2: DuelEngine = d2["engine"]
	_stack_hand(engine2, [_monster("Only Monster")])
	t.is_true(TestFixtures.attack(engine2, d2["attacker"], d2["blocker"]),
		"a second attack is declared")
	var mark2: int = engine2.state.events.size()
	t.is_true(_activate(engine2, d2["ahe"]), "and the Trap resolves")
	var chosen2 = _chosen(engine2, mark2, d2["ahe"])
	t.not_null(chosen2, "a card was chosen")
	t.eq((chosen2 as CardInstance).position, Enums.Position.FACE_UP_ATTACK,
		"with no scripted answer it lands in Attack Position")


static func _test_ownership_and_control_stay_with_the_trap_s_controller(
		t: TestCase) -> void:
	t.start("R15 Part F: 自分フィールドに特殊召喚 — the OPPONENT chooses which card, but the "
		+ "Summon is yours, to your field, and ownership never moves")
	var r := _run_once(1515, [_monster("Only Monster")])
	t.is_true(r["ok"], "the Trap resolved")
	var engine: DuelEngine = r["engine"]
	var chosen: CardInstance = r["chosen"]
	t.not_null(chosen, "a card was chosen")
	t.eq(chosen.owner_id, 1, "the card is still owned by the Trap's controller")
	t.eq(chosen.controller_id, 1, "and controlled by them")
	t.is_true(engine.state.player(1).monsters().has(chosen),
		"it occupies one of THEIR Monster Zones")
	t.is_false(engine.state.player(0).monsters().has(chosen),
		"and none of the opponent's")

	var summon_events := TestFixtures.events_of(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, r["mark"])
	t.eq(summon_events.size(), 1, "one Special Summon was announced")
	t.eq(int(summon_events[0].data.get("player", -1)), 1,
		"announced as the Trap controller's Summon")
	t.eq(int(summon_events[0].data.get("source_id", -1)), (r["ahe"] as CardInstance).id,
		"and attributed to the Trap")


# ---------------------------------------------------------------------------
# R15 Part C — the resolution-time gate that suppresses the random choice
# ---------------------------------------------------------------------------

static func _test_losing_the_last_summonable_monster_suppresses_everything(
		t: TestCase) -> void:
	t.start("R15 Part C (fid 8193): the activation was legal, but by resolution nothing in "
		+ "the hand could be Special Summoned — so the effect does NOTHING, the random "
		+ "choice is not made, and the Spell still in the hand is NOT sent")
	var d := _board(1516)
	var engine: DuelEngine = d["engine"]
	var cards := _stack_hand(engine, [_monster("Hand Monster"),
		TestFixtures.spell("Hand Spell")])
	var victim: CardInstance = cards[0]
	# A real Spell Speed 2 response that removes the hand's only monster while the Chain
	# is still building — the live analogue of `Vanity's Emptiness`, which is not in this
	# pool. The interference goes through the timing machine, not around it.
	var interferer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Hand Stripper", victim, "send_to_gy"), 0)

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate_with_response(engine, d["ahe"], interferer),
		"the Trap was activated and the opponent chained the interference above it")

	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "the monster left the hand first")
	t.is_null(_chosen(engine, mark, d["ahe"]),
		"NO card was chosen — the pick is not even performed")
	t.eq(engine.state.player(1).hand.size(), 1, "the Spell is still in the hand")
	t.eq((engine.state.player(1).hand[0] as CardInstance).card_name(), "Hand Spell",
		"and it is the Spell")
	# Two cards: the interference's own victim, and the spent Trap. Nothing the effect did.
	t.eq(engine.state.player(1).graveyard.size(), 2,
		"only the interference's victim and the spent Trap reached the Graveyard")
	t.is_true(engine.state.player(1).graveyard.has(victim),
		"the victim is one of them")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		mark).size(), 0, "and nothing was Special Summoned")

	# The control: the identical board WITHOUT the interference resolves normally and
	# reaches one of the two branches, so the assertions above are about the gate.
	var r := _run_once(1516, [_monster("Hand Monster"), TestFixtures.spell("Hand Spell")])
	t.is_true(r["ok"], "the same seed and hand, uninterfered with, resolves")
	t.not_null(r["chosen"], "and a card IS chosen there")


static func _test_filling_the_monster_zone_suppresses_everything(t: TestCase) -> void:
	t.start("R15 Part C again, by the other live route: the Monster Zone fills up between "
		+ "activation and resolution, so the effect does nothing at all")
	var d := _board(1517)
	var engine: DuelEngine = d["engine"]
	_stack_hand(engine, [_monster("Hand Monster"), TestFixtures.spell("Hand Spell")])
	# Four occupied zones (the blocker plus three), one free at activation time.
	for i in range(3):
		TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Filler %d" % i, 4, 100, 100))
	t.eq(engine.state.player(1).monsters().size(), 4, "four Monster Zones are occupied")

	# A Spell Speed 2 response that fills the last zone with a monster from the GY.
	var occupier := TestFixtures.give(engine, 1, TestFixtures.monster("Late Filler", 4,
		100, 100), Enums.Zone.GRAVEYARD)
	var filler_def := TestFixtures.trap("Test Zone Filler")
	var filler_effect := EffectDef.new("fill_the_zone", "Test: fill the last Monster Zone.")
	filler_effect.of_type(Enums.EffectType.CARD_ACTIVATION)
	filler_effect.with_spell_speed(Enums.SpellSpeed.SS2)
	filler_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	filler_effect.resolve = func(ctx: EffectContext) -> void:
		ctx.engine.special_summon(occupier, 1, Enums.Position.FACE_UP_ATTACK, ctx.source.id)
	var filler := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.with_effect(filler_def, filler_effect), 0)

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate_with_response(engine, d["ahe"], filler),
		"the Trap was activated and the zone was filled above it on the Chain")

	t.is_false(engine.state.player(1).has_free_monster_zone(),
		"the Monster Zone is full by the time the Trap resolves")
	t.is_null(_chosen(engine, mark, d["ahe"]), "so no card was chosen")
	t.eq(engine.state.player(1).hand.size(), 2, "the whole hand is untouched")
	t.eq(engine.state.player(1).graveyard.size(), 1,
		"and the only card in the Graveyard is the spent Trap itself")
	t.eq((engine.state.player(1).graveyard[0] as CardInstance).card_name(),
		CARD_UNDER_TEST, "nothing out of the hand was sent")


# ---------------------------------------------------------------------------
# Hidden information — R15 Part H
# ---------------------------------------------------------------------------

static func _test_only_the_chosen_card_becomes_public(t: TestCase) -> void:
	t.start("R15 Part H: the chosen card is revealed to BOTH players and the rest of the "
		+ "hand stays hidden — after the resolution as well as during it")
	var d := _board(1518)
	var engine: DuelEngine = d["engine"]
	var cards := _stack_hand(engine, [_monster("Secret Monster A"),
		_monster("Secret Monster B"), TestFixtures.spell("Secret Spell"),
		TestFixtures.trap("Secret Trap")])
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate(engine, d["ahe"]), "the Trap resolves")

	var chosen = _chosen(engine, mark, d["ahe"])
	t.not_null(chosen, "one card was chosen")
	var picked: CardInstance = chosen
	t.is_true(picked.revealed_to.has(0) and picked.revealed_to.has(1),
		"and it is known to both players")

	var still_hidden := 0
	for entry in cards:
		var card: CardInstance = entry
		if card == picked:
			continue
		t.is_false(card.revealed_to.has(0),
			"%s was never shown to the opponent" % card.card_name())
		still_hidden += 1
	t.eq(still_hidden, 3, "three of the four cards stayed hidden")

	# Exactly one reveal came from this card, and it is public.
	var reveals: Array = []
	for ev in TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED, mark):
		if int(ev.data.get("source_id", -1)) == (d["ahe"] as CardInstance).id:
			reveals.append(ev)
	t.eq(reveals.size(), 1, "one reveal, raised by this card")
	t.is_true((reveals[0] as GameEvent).is_public(),
		"and it is public, unlike the private reveal a LOOK raises")

	# The filtered view is the real leak test: the opponent may name the chosen card and
	# no other card of that hand.
	var view0 := engine.get_visible_state(0)
	var named: Array = []
	for entry in view0["players"][1]["hand"]:
		if entry != null and entry.get("name") != null:
			named.append(str(entry["name"]))
	var expected: Array = [] if picked.zone != Enums.Zone.HAND else [picked.card_name()]
	t.eq(named, expected,
		"the opponent's view of the remaining hand names nothing they were not shown")
	t.eq(engine.state.player(1).hand.size(), cards.size() - 1,
		"the chosen card left the hand either way")


static func _test_the_chooser_is_asked_nothing(t: TestCase) -> void:
	t.start("R15 Part D: 'your opponent chooses' is agency WITHOUT information — the "
		+ "opponent's controller is asked nothing, and only the Trap's controller is "
		+ "asked anything at all")
	var d := _board(1519)
	var engine: DuelEngine = d["engine"]
	var chooser: ScriptedController = d["p0"]
	var controller: ScriptedController = d["p1"]
	_stack_hand(engine, [_monster("Hand Monster A"), _monster("Hand Monster B"),
		_monster("Hand Monster C")])
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var before_chooser: int = chooser.seen_requests.size()
	t.is_true(_activate(engine, d["ahe"]), "the Trap resolves")

	var asked_of_chooser: Array = []
	for i in range(before_chooser, chooser.seen_requests.size()):
		asked_of_chooser.append(chooser.seen_requests[i])
	var selections := 0
	for request in asked_of_chooser:
		if request.kind == Enums.DecisionKind.SELECT_EXACTLY \
				or request.kind == Enums.DecisionKind.SELECT_UP_TO:
			selections += 1
	t.eq(selections, 0,
		"the chooser was handed no selection — one would have listed a hidden hand")
	t.eq(chooser.errors, [], "and nothing it was asked was answered wrongly")

	# The controller IS asked — the position — which proves the run really reached the
	# Summon and that "nobody was asked anything" is not why the test passes.
	var controller_positions := 0
	for request in controller.seen_requests:
		if request.kind == Enums.DecisionKind.CHOOSE_POSITION:
			controller_positions += 1
	t.eq(controller_positions, 1, "the Trap's controller was asked for a position, once")

	# And no decision recorded in the replay payload belongs to the chooser for this card.
	var decisions: Array = engine.log.decisions
	var chooser_decisions := 0
	for entry in decisions:
		var record: Dictionary = entry
		if int((record["request"] as Dictionary).get("player", -1)) == 0:
			chooser_decisions += 1
	t.eq(chooser_decisions, 0, "the replay payload records no decision for the chooser")


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

static func _test_the_special_summon_is_announced_and_can_be_responded_to(
		t: TestCase) -> void:
	t.start("the Special Summon is a real Summon: it raises SPECIAL_SUMMON_SUCCEEDED, and "
		+ "a Trigger Effect keyed on that is collected afterwards — a Summon performed "
		+ "inside a resolution opens no declaration window (design decision 9) but is "
		+ "still announced")
	var d := _board(1520)
	var engine: DuelEngine = d["engine"]
	var order_log: Array = []
	var watcher_def := TestFixtures.with_effect(
		TestFixtures.monster("Summon Watcher", 4, 800, 800),
		TestFixtures.trigger_effect("saw_a_special_summon",
			[GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED], order_log, "watched", true))
	TestFixtures.give_monster_on_field(engine, 1, watcher_def)
	_stack_hand(engine, [_monster("Only Monster")])

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate(engine, d["ahe"]), "the Trap resolves")

	var chosen = _chosen(engine, mark, d["ahe"])
	t.not_null(chosen, "a card was chosen")
	t.eq((chosen as CardInstance).zone, Enums.Zone.MONSTER_ZONE, "and Special Summoned")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		mark).size(), 1, "the Summon was announced exactly once")
	t.is_true(order_log.has("watched"),
		"and a mandatory Trigger Effect watching for it really fired")

	# No SPECIAL_SUMMON_DECLARED window was opened for a responder to answer: the
	# declaration and completion happen in one step inside a resolution.
	var declared := TestFixtures.events_of(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED,
		mark)
	t.eq(declared.size(), 1, "the declaration event exists")
	t.eq(int(declared[0].data.get("player", -1)), 1, "for the Trap's controller")


static func _test_activation_negated(t: TestCase) -> void:
	t.start("the ACTIVATION is negated: the Trap was not successfully activated, nothing "
		+ "is chosen, nothing moves, and the Trap itself is destroyed")
	var d := _board(1521)
	var engine: DuelEngine = d["engine"]
	var cards := _stack_hand(engine, [_monster("Hand Monster"),
		TestFixtures.spell("Hand Spell")])
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.activation_negator("Test Counter"), 0)

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate_with_response(engine, d["ahe"], negator),
		"the Trap was activated and the opponent negated the activation")

	t.is_null(_chosen(engine, mark, d["ahe"]), "no card was chosen")
	t.eq(engine.state.player(1).hand.size(), 2, "the hand is untouched")
	for entry in cards:
		t.is_false((entry as CardInstance).revealed_to.has(0),
			"and nothing in it was revealed to the opponent")
	t.eq(engine.state.player(1).graveyard.size(), 1,
		"the Graveyard holds only the negated Trap itself")
	t.eq((d["ahe"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"the Trap was destroyed by the Counter Trap")


static func _test_effect_negated(t: TestCase) -> void:
	t.start("the EFFECT is negated: the activation happened — the Trap is face-up and is "
		+ "cleaned up as a resolved Normal Trap — but nothing it would do happens")
	var d := _board(1522)
	var engine: DuelEngine = d["engine"]
	var cards := _stack_hand(engine, [_monster("Hand Monster"),
		TestFixtures.spell("Hand Spell")])
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.effect_negator("Test Effect Negator"), 0)

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate_with_response(engine, d["ahe"], negator),
		"the Trap was activated and its effect was negated")

	t.is_null(_chosen(engine, mark, d["ahe"]), "no card was chosen")
	t.eq(engine.state.player(1).hand.size(), 2, "the hand is untouched")
	for entry in cards:
		t.is_false((entry as CardInstance).revealed_to.has(0),
			"and nothing in it was revealed to the opponent")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		mark).size(), 0, "nothing was Special Summoned")
	# The activation itself DID happen, which is the whole difference from the previous
	# test: a Normal Trap that resolved goes to the Graveyard as an ordinary cleanup.
	t.eq((d["ahe"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"the Trap reached the Graveyard as a resolved Normal Trap")
	var activations := TestFixtures.count_events_for(engine,
		GameEvent.Kind.EFFECT_ACTIVATED, (d["ahe"] as CardInstance).id)
	t.eq(activations, 1, "and the activation was announced")


static func _test_an_attack_negated_above_it_does_not_undo_it(t: TestCase) -> void:
	t.start("R15 Part G: an attack negation chained ABOVE this card resolves first, and "
		+ "this card still resolves — nothing in its resolution reads the attack")
	var d := _board(1523)
	var engine: DuelEngine = d["engine"]
	_stack_hand(engine, [_monster("Only Monster")])
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.attack_negator("Test Attack Negator"), 0)

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var mark: int = engine.state.events.size()
	t.is_true(_activate_with_response(engine, d["ahe"], negator),
		"the Trap was activated and the attack was negated above it")

	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_NEGATED, mark).size(), 1,
		"the attack really was negated")
	var chosen = _chosen(engine, mark, d["ahe"])
	t.not_null(chosen, "and a card was still chosen")
	t.eq((chosen as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"and Special Summoned — the effect does not depend on the attack surviving")


# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

static func _test_the_same_seed_replays_to_the_same_card(t: TestCase) -> void:
	t.start("the pick goes through the duel's seeded Rng, so the same seed and the same "
		+ "inputs choose the same card every time — and different seeds do not")
	var hand := [_monster("Hand Monster"), TestFixtures.spell("Hand Spell"),
		TestFixtures.trap("Hand Trap"), _monster("Second Monster")]
	var first := _run_once(1524, hand)
	t.is_true(first["ok"], "the first run resolved")
	var second := _run_once(1524, hand)
	t.is_true(second["ok"], "the second run resolved")
	t.not_null(first["chosen"], "a card was chosen")
	t.eq((second["chosen"] as CardInstance).card_name(),
		(first["chosen"] as CardInstance).card_name(),
		"the same seed chose the same card")
	t.eq((second["chosen"] as CardInstance).zone, (first["chosen"] as CardInstance).zone,
		"and it ended up in the same zone")
	t.eq((second["engine"] as DuelEngine).state.rng.get_call_count(),
		(first["engine"] as DuelEngine).state.rng.get_call_count(),
		"having consumed the same number of random values")

	# The full event stream is identical, which is the claim `ReplayTests` makes for the
	# duel as a whole and which a card taking randomness from anywhere else would break.
	var sig_a: Array = []
	for ev in (first["engine"] as DuelEngine).state.events:
		sig_a.append(GameEvent.kind_name(ev.kind))
	var sig_b: Array = []
	for ev in (second["engine"] as DuelEngine).state.events:
		sig_b.append(GameEvent.kind_name(ev.kind))
	t.eq(sig_b, sig_a, "and the two runs produced identical event streams")

	# Different seeds reach different cards, so "deterministic" is not "always the first".
	var names := {}
	for seed_value in range(2100, 2140):
		var r := _run_once(seed_value, hand)
		if r["ok"] and r["chosen"] != null:
			names[(r["chosen"] as CardInstance).card_name()] = true
	t.eq(names.size(), 4, "all four hand cards are reachable across seeds")

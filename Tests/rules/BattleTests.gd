class_name BattleTests
extends RefCounted

## Battle Phase: entering it, its steps, who may attack, what may be attacked, the
## response window an attack declaration opens, and attack replay.
##
## Rules under test: RULES_SPEC.md 6 (Official Rulebook v10 p.37-39, 52 = S1).
## The Damage Step itself is covered by DamageStepTests.
##
## The engine does not stop when nobody holds a legal response: it auto-passes and runs
## the whole attack inside a single submit_action(). Assertions about intermediate states
## therefore read the event log, or arrange for the opponent to hold a fast effect so the
## window really opens.


static func run() -> TestCase:
	var t := TestCase.new("BattleTests")
	_test_start_step_is_a_real_window(t)
	_test_no_attacks_outside_the_battle_step(t)
	_test_which_monsters_may_attack(t)
	_test_a_monster_attacks_once_per_turn(t)
	_test_cannot_attack_restriction_is_honoured(t)
	_test_direct_attack_only_with_an_empty_opposing_field(t)
	_test_attack_target_must_come_from_the_offered_set(t)
	_test_declaration_opens_a_window_before_the_damage_step(t)
	_test_attacker_leaving_the_field_cancels_the_attack(t)
	_test_removing_the_target_causes_a_replay(t)
	_test_replay_with_a_different_monster_spends_the_original_attack(t)
	_test_battle_phase_ends_into_main_phase_2(t)
	return t


# ---------------------------------------------------------------------------
# Synthetic cards
# ---------------------------------------------------------------------------

## A Set Normal Trap (Spell Speed 2) that destroys whatever card is in `victim_holder[0]`.
## Used to change the board while an attack declaration window is open.
static func _destroy_trap(name: String, victim_holder: Array) -> CardDef:
	var def := TestFixtures.trap(name, Enums.STKind.NORMAL_TRAP)
	var e := EffectDef.new("destroy", "Destroy 1 monster on the field.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	e.resolve = func(ctx: EffectContext) -> void:
		var victim = victim_holder[0]
		if victim != null and victim.is_on_field():
			ctx.state.move_card(victim, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.DESTROYED_BY_EFFECT, {"source_id": ctx.source.id})
	TestFixtures.with_effect(def, e)
	return def


## A face-up Continuous Spell whose continuous effect stops `victim_holder[0]` attacking.
static func _cannot_attack_lock(name: String, victim_holder: Array) -> CardDef:
	var def := TestFixtures.spell(name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new("lock", "The chosen monster cannot attack.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(_ctx: EffectContext) -> void:
		var victim = victim_holder[0]
		if victim != null and victim.is_on_field():
			ContinuousEffects.restrict(victim, "cannot_attack")
	TestFixtures.with_effect(def, e)
	return def


# ---------------------------------------------------------------------------
# Battle Phase structure. RULES_SPEC.md 6.1 [S1 p.37]
# ---------------------------------------------------------------------------

static func _test_start_step_is_a_real_window(t: TestCase) -> void:
	t.start("the Battle Phase opens with a Start Step that is a real response window")
	# Player 1 goes first, so player 0 may conduct a Battle Phase on turn 2.
	var d := TestFixtures.new_duel(601, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	# The opponent holds a fast effect, so the engine must stop and offer the window.
	var holder: Array = [null]
	TestFixtures.give_set_spell_trap(engine, 1, _destroy_trap("Opposing Trap", holder), 0)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ENTER_BATTLE_PHASE))
	# Box E: the turn player declared the phase change, and the opponent responds BEFORE
	# it happens [S2 box E]. The phase must not have moved yet.
	t.eq(engine.state.phase, Enums.Phase.MAIN_1,
		"the phase does not change until the opponent's window closes [S2 box E]")
	t.eq(engine.waiting_player(), 1, "the opponent holds that window")
	t.eq(engine.get_legal_actions(0).size(), 0,
		"no open-game-state action is available while a response window is open")

	engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1))
	t.eq(engine.state.phase, Enums.Phase.BATTLE, "the Battle Phase was then entered")
	t.eq(engine.state.battle_step, Enums.BattleStep.START,
		"it opens in the Start Step [S1 p.37]")
	t.eq(engine.waiting_player(), 1,
		"the Start Step is itself a real response window, not a formality")

	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE,
		"passing the Start Step reaches the Battle Step [S1 p.37]")
	t.eq(engine.state.battle_phase_conducted_this_turn, true,
		"the turn is recorded as having conducted a Battle Phase [S1 p.40]")


static func _test_no_attacks_outside_the_battle_step(t: TestCase) -> void:
	t.start("attacks are offered only during the Battle Step")
	var d := TestFixtures.new_duel(602, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, mon.id),
		"no attack in Main Phase 1")

	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, mon.id),
		"the attack is offered in the Battle Step")

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.END_BATTLE_PHASE))
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.phase, Enums.Phase.MAIN_2, "the Battle Phase ended into Main Phase 2")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, mon.id),
		"no attack in Main Phase 2")


# ---------------------------------------------------------------------------
# Who may attack. RULES_SPEC.md 6.1 [S1 p.38]
# ---------------------------------------------------------------------------

static func _test_which_monsters_may_attack(t: TestCase) -> void:
	t.start("only a face-up Attack Position monster the turn player controls may attack")
	var d := TestFixtures.battle_duel(603)
	var engine: DuelEngine = d["engine"]

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Ready", 4, 1800, 1000), Enums.Position.FACE_UP_ATTACK)
	var defending_pos := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Guarding", 4, 1000, 2000), Enums.Position.FACE_UP_DEFENSE)
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Hidden", 4, 1200, 1200), Enums.Position.FACE_DOWN_DEFENSE)
	var opposing := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000), Enums.Position.FACE_UP_ATTACK)

	var actions := engine.get_legal_actions(0)
	t.is_true(TestFixtures.has_action(actions, Enums.ActionKind.DECLARE_ATTACK,
		attacker.id), "a face-up Attack Position monster may attack")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.DECLARE_ATTACK,
		defending_pos.id), "a Defense Position monster may not attack [S1 p.38]")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.DECLARE_ATTACK,
		face_down.id), "a face-down monster may not attack")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.DECLARE_ATTACK,
		opposing.id), "the opponent's monster is not an attacker for the turn player")
	t.eq(engine.get_legal_actions(1).size(), 0,
		"the non-turn player has no actions at all in an open game state")

	var offered: DuelAction = TestFixtures.find_action(actions,
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	t.eq(offered.attack_target_candidates, [opposing.id],
		"the offered targets are exactly the opponent's monsters")
	t.is_false(offered.allows_direct_attack,
		"a direct attack is not offered while the opponent controls a monster [S1 p.38]")


static func _test_a_monster_attacks_once_per_turn(t: TestCase) -> void:
	t.start("each monster gets one attack per turn")
	var d := TestFixtures.battle_duel(604)
	var engine: DuelEngine = d["engine"]
	var first := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("First", 4, 1800, 1000))
	var second := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Second", 4, 1600, 1000))

	t.is_true(TestFixtures.attack(engine, first, null), "the first attack was accepted")
	t.eq(first.has_attacked_this_turn, true, "the attacker is marked as having attacked")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, first.id),
		"it is not offered a second attack this turn [S1 p.38]")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, second.id),
		"a different monster may still attack")

	# The allowance comes back on that player's next turn.
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.eq(first.has_attacked_this_turn, false,
		"the attack allowance is restored at the start of the controller's next turn")


static func _test_cannot_attack_restriction_is_honoured(t: TestCase) -> void:
	t.start("a continuous 'cannot attack' restriction removes the attack from the "
		+ "legal actions")
	var d := TestFixtures.battle_duel(605)
	var engine: DuelEngine = d["engine"]
	var locked := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Chained", 4, 1800, 1000))
	var free := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Loose", 4, 1500, 1000))
	var holder: Array = [locked]
	var lock := TestFixtures.give(engine, 1, _cannot_attack_lock("Shackles", holder),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	engine.continuous.recompute()
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, locked.id),
		"the restricted monster cannot declare an attack")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, free.id),
		"an unrestricted monster still can")

	# Removing the source lifts the restriction on the next recompute.
	engine.state.move_card(lock, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, locked.id),
		"the restriction disappears with its source")


# ---------------------------------------------------------------------------
# Targets. RULES_SPEC.md 6.1 [S1 p.38, p.43]
# ---------------------------------------------------------------------------

static func _test_direct_attack_only_with_an_empty_opposing_field(t: TestCase) -> void:
	t.start("a direct attack is legal only when the opponent controls no monsters")
	var d := TestFixtures.battle_duel(606)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Runner", 4, 1700, 1000))
	var blocker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Blocker", 4, 1000, 1000))

	var blocked: DuelAction = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	blocked.attack_target_id = -1
	t.is_false(engine.submit_action(blocked),
		"a direct attack is rejected while the opponent controls a monster [S1 p.38]")
	t.eq(engine.state.player(1).life_points, 8000, "no life points were lost")

	engine.state.move_card(blocker, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	var direct: DuelAction = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	t.is_true(direct.allows_direct_attack,
		"with the field empty a direct attack is offered")
	t.eq(direct.attack_target_candidates, [], "and there are no monster targets")
	direct.attack_target_id = -1
	t.is_true(engine.submit_action(direct), "the direct attack is accepted")
	t.eq(engine.state.player(1).life_points, 8000 - 1700,
		"a direct attack inflicts the attacker's full ATK [S1 p.43]")


static func _test_attack_target_must_come_from_the_offered_set(t: TestCase) -> void:
	t.start("an attack target outside the offered set is rejected")
	var d := TestFixtures.battle_duel(607)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Striker", 4, 1800, 1000))
	var ally := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Ally", 4, 1000, 1000))
	var enemy_up := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Enemy Up", 4, 1000, 1000), Enums.Position.FACE_UP_ATTACK)
	var enemy_down := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Enemy Down", 4, 1000, 1000),
		Enums.Position.FACE_DOWN_DEFENSE)

	var offered: DuelAction = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	t.eq(offered.attack_target_candidates.size(), 2,
		"both of the opponent's monsters are legal targets")
	t.is_true(offered.attack_target_candidates.has(enemy_down.id),
		"a face-down monster may be attacked")

	var bad: DuelAction = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	bad.attack_target_id = ally.id
	t.is_false(engine.submit_action(bad),
		"a monster you control is not a legal attack target")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 0,
		"the illegal declaration produced no attack event")

	t.is_true(TestFixtures.attack(engine, attacker, enemy_up),
		"attacking a legal target is accepted")


# ---------------------------------------------------------------------------
# The declaration window. RULES_SPEC.md 6.1, 3 [S2]
# ---------------------------------------------------------------------------

static func _test_declaration_opens_a_window_before_the_damage_step(t: TestCase) -> void:
	t.start("an attack declaration opens a response window before the Damage Step")
	var d := TestFixtures.battle_duel(608)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Declarer", 4, 1800, 1000))
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Target", 4, 1000, 1000))
	var holder: Array = [null]
	TestFixtures.give_set_spell_trap(engine, 1, _destroy_trap("Reaction", holder), 0)

	var mark := engine.state.events.size()
	t.is_true(TestFixtures.attack(engine, attacker, target), "the attack was declared")

	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_DECLARED, mark).size(), 1,
		"ATTACK_DECLARED was emitted")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_TARGET_SELECTED, mark).size(),
		1, "ATTACK_TARGET_SELECTED was emitted")
	t.eq(engine.waiting_player(), 1,
		"the opponent may respond to the declaration [S2 box C]")
	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE,
		"the Damage Step has not begun while the window is open")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED), 0,
		"no Damage Step sub-step has been entered yet")

	var responses := engine.get_legal_responses(1)
	t.is_true(responses.size() >= 2,
		"the opponent is offered their fast effect and a pass")

	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 1,
		"once the window closes the Damage Step runs")


static func _test_attacker_leaving_the_field_cancels_the_attack(t: TestCase) -> void:
	t.start("an attack whose attacker left the field before damage calculation "
		+ "does not happen")
	var d := TestFixtures.battle_duel(609)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Doomed", 4, 1800, 1000))
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))
	var holder: Array = [attacker]
	var trap := TestFixtures.give_set_spell_trap(engine, 1,
		_destroy_trap("Remove Attacker", holder), 0)

	TestFixtures.attack(engine, attacker, target)
	engine.submit_action(TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, trap.id))
	TestFixtures.pass_until_open(engine)

	t.eq(attacker.zone, Enums.Zone.GRAVEYARD, "the attacker was destroyed")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 0,
		"damage calculation never happened")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED), 0,
		"the Damage Step was never entered")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "the target survived untouched")
	t.eq(engine.state.player(1).life_points, 8000, "no battle damage was inflicted")
	t.eq(target.battled_this_turn, false,
		"a monster only battled if damage calculation was reached [S1 p.52]")
	t.eq(engine.state.current_attacker, null, "the battle state was cleared")


# ---------------------------------------------------------------------------
# Attack replay. RULES_SPEC.md 6.2 [S1 p.39]
# ---------------------------------------------------------------------------

static func _test_removing_the_target_causes_a_replay(t: TestCase) -> void:
	t.start("removing the attack target causes a Replay, not a cancelled attack")
	var d := TestFixtures.battle_duel(610)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Charger", 4, 1800, 1000))
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Vanisher", 4, 1000, 1000))
	var holder: Array = [target]
	var trap := TestFixtures.give_set_spell_trap(engine, 1,
		_destroy_trap("Self Removal", holder), 0)

	TestFixtures.attack(engine, attacker, target)
	engine.submit_action(TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, trap.id))
	TestFixtures.pass_until_open(engine)

	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the attack target left the field")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_REPLAY), 1,
		"a Replay occurred [S1 p.39]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 0,
		"no damage calculation happened as part of the interrupted attack")
	t.eq(attacker.has_attacked_this_turn, false,
		"the attacker's attack was not spent by the Replay [S1 p.39]")
	t.eq(engine.timing, DuelEngine.Timing.OPEN,
		"the choice is handed back to the attacking player")

	var again: DuelAction = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	t.not_null(again, "the same monster may attack again after a Replay")
	t.is_true(again != null and again.allows_direct_attack,
		"and may now attack directly, since the opponent controls no monsters")

	if again != null:
		again.attack_target_id = -1
		engine.submit_action(again)
		TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(1).life_points, 8000 - 1800,
		"the re-declared attack resolved normally")


static func _test_replay_with_a_different_monster_spends_the_original_attack(
		t: TestCase) -> void:
	t.start("after a Replay, attacking with a different monster spends the original "
		+ "monster's attack")
	var d := TestFixtures.battle_duel(611)
	var engine: DuelEngine = d["engine"]
	var first := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Original", 4, 1800, 1000))
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Substitute", 4, 1600, 1000))
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Kept", 4, 1000, 1000))
	var spare := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Spare", 4, 800, 800))
	var holder: Array = [spare]
	var trap := TestFixtures.give_set_spell_trap(engine, 1,
		_destroy_trap("Board Change", holder), 0)

	TestFixtures.attack(engine, first, target)
	engine.submit_action(TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, trap.id))
	TestFixtures.pass_until_open(engine)

	t.eq(spare.zone, Enums.Zone.GRAVEYARD, "a non-targeted monster left the field")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "the original target is still there")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_REPLAY), 1,
		"the change in the opponent's monsters caused a Replay [S1 p.39]")

	t.is_true(TestFixtures.attack(engine, other, target),
		"the attacking player may attack with a different monster instead")
	t.eq(first.has_attacked_this_turn, true,
		"the original monster is still treated as having declared an attack [S1 p.39]")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, first.id),
		"so it cannot attack again this turn [S1 p.39]")


static func _test_battle_phase_ends_into_main_phase_2(t: TestCase) -> void:
	t.start("the Battle Phase ends through its End Step into Main Phase 2")
	var d := TestFixtures.battle_duel(612)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Finisher", 4, 1200, 1000))

	TestFixtures.attack(engine, attacker, null)
	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE,
		"after the Damage Step play returns to the Battle Step [S1 p.37]")

	var mark := engine.state.events.size()
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.END_BATTLE_PHASE))
	TestFixtures.pass_until_open(engine)

	var steps := TestFixtures.events_of(engine, GameEvent.Kind.BATTLE_STEP_CHANGED, mark)
	t.is_true(steps.size() >= 1 and steps[0].data.get("step") == Enums.BattleStep.END,
		"the Battle Phase passes through its End Step [S1 p.37]")
	t.eq(engine.state.phase, Enums.Phase.MAIN_2, "and reaches Main Phase 2 [S1 p.40]")
	t.eq(engine.state.current_attacker, null, "no battle state leaks out of the phase")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.END_PHASE), "the turn can then proceed to the End Phase")

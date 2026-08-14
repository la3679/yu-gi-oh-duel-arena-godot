class_name AttackRestrictionTests
extends RefCounted

## ATTACK PREVENTION, ATTACK NEGATION and the BATTLE-PHASE CARD-CLASS LOCK — the three things
## the batch-9 cards need and the three things that must never become one flag. Rules under
## test: `RULES_SPEC.md §6.1`, `§6.3`, `§4.4`, `§11`; `CARD_RULINGS.md` **R6**.
##
## This is the **attack-restriction gate**, written the way `EquipTests`, `ControlTests`,
## `MovementTests`, `BanishTests`, `LifePointCostTests`, `TrapMonsterTests` and
## `BattlePhaseRestrictionTests` were: a RULES suite built from synthetic drivers, so what it
## proves is that the ENGINE is right rather than that one printed card happens to work. No
## batch-9 card is implemented until it passes.
##
## **The load-bearing claim is that these are three separate concepts.** Collapsing any pair
## of them into a single `attack_blocked` boolean would be wrong in an observable way, and
## each of the three sections below asserts the difference rather than assuming it:
##
##   PREVENTION  the attack is never DECLARED. `can_declare_attack()` refuses, the action is
##               never offered, **no `ATTACK_DECLARED` event exists**, and the monster still
##               has its attack for the turn. Two channels — per-CARD (`cannot_attack`,
##               `Fiendish Chain`) and per-PLAYER (`Swords of Revealing Light`) — because one
##               travels with a monster and the other covers monsters that arrive later.
##   NEGATION    the attack **was** declared. `ATTACK_DECLARED` really happened, the response
##               window really opened, the monster really has attacked this turn, and a
##               resolving effect stops the rest of the battle before damage calculation.
##               It is **not** a Replay: a Replay gives the choice back, a negation spends it.
##   CARD-CLASS LOCK
##               an authoritative restriction on ACTIVATING a class of card for the duration
##               of a phase (`Mirage Dragon`). It locks activating a Trap CARD, not activating
##               an EFFECT of a Trap already face-up on the field.
##
## Every test that claims to exercise a route asserts **that the route happened** — the exact
## `ATTACK_DECLARED` count, the real Chain Link, the real responder — because a suite that
## only checks conclusions passes just as happily when the mechanism never ran. That is the
## failure mode `PROJECT_STATE.md §0` records twice from batch 8.


static func run() -> TestCase:
	var t := TestCase.new("AttackRestrictionTests")

	# --- Baseline: the positive control every negative below is measured against ---
	_test_an_unrestricted_monster_can_declare_an_attack(t)

	# --- PREVENTION: per-card ---
	_test_a_per_card_lock_prevents_declaration(t)
	_test_a_per_card_lock_leaves_other_monsters_alone(t)

	# --- PREVENTION: per-player ---
	_test_a_player_lock_prevents_every_monster_that_player_controls(t)
	_test_a_player_lock_is_aimed_and_does_not_hit_its_own_controller(t)
	_test_a_player_lock_covers_a_monster_that_arrives_afterwards(t)
	_test_a_prevented_attack_emits_no_attack_declared_event(t)
	_test_a_prevented_monster_keeps_its_attack_for_the_turn(t)

	# --- PREVENTION: the source's own lifetime ---
	_test_the_lock_lifts_when_its_source_leaves_the_field(t)
	_test_the_lock_lifts_when_its_source_is_flipped_face_down(t)
	_test_the_lock_lifts_when_its_source_effects_are_negated(t)
	_test_the_lock_follows_control_of_its_source(t)
	_test_two_sources_both_apply_and_one_leaving_does_not_lift_the_other(t)
	_test_the_two_prevention_channels_are_independent(t)

	# --- PREVENTION vs attack TARGET legality ---
	_test_attacker_legality_and_target_legality_are_separate_questions(t)

	# --- NEGATION ---
	_test_a_negated_attack_was_really_declared_first(t)
	_test_a_negated_attack_does_not_reach_damage_calculation(t)
	_test_a_negated_attack_is_not_a_replay(t)
	_test_the_battle_phase_continues_after_a_negated_attack(t)
	_test_the_target_survives_a_negated_attack(t)
	_test_negation_beats_the_replay_a_summon_would_otherwise_cause(t)
	_test_a_second_negation_of_the_same_attack_is_refused(t)
	_test_negation_is_refused_once_the_damage_step_has_begun(t)
	_test_negation_is_refused_when_no_attack_is_live(t)
	_test_negating_the_negator_lets_the_attack_through(t)
	_test_a_direct_attack_can_be_negated(t)
	_test_the_event_order_is_declared_then_negated(t)

	# --- CARD-CLASS ACTIVATION LOCK ---
	_test_the_class_lock_blocks_activating_that_class_in_that_phase(t)
	_test_the_class_lock_does_not_apply_outside_its_phase(t)
	_test_the_class_lock_does_not_touch_other_categories(t)
	_test_the_class_lock_is_aimed_at_one_player(t)
	_test_the_class_lock_does_not_stop_an_effect_of_a_face_up_card(t)
	_test_the_class_lock_lifts_with_its_source(t)
	_test_a_chain_already_underway_is_unaffected_by_the_class_lock(t)

	# --- PER-CARD TURN COUNTER ---
	_test_a_turn_counter_counts_only_the_named_players_turns(t)
	_test_a_turn_counter_does_not_double_count_within_one_turn(t)
	_test_a_turn_counter_is_per_instance(t)
	_test_a_turn_counter_is_cleared_when_the_card_leaves_the_field(t)
	_test_a_turn_counter_reaching_its_limit_acts_once(t)

	# --- SHARED once-per-turn (restriction_group) ---
	_test_two_clauses_in_one_group_share_a_single_use(t)
	_test_clauses_outside_the_group_keep_their_own_use(t)
	_test_a_shared_group_resets_next_turn(t)
	_test_a_shared_group_is_per_player_and_per_name(t)

	# --- Determinism ---
	_test_prevention_and_negation_are_replay_deterministic(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A duel sitting in the Battle Step of turn 2 with player 0 as the turn player, plus a plain
## attacker for player 0 and a plain defender for player 1.
##
## `battle_duel()` gives player 1 the first turn precisely so player 0 may attack from turn 2
## [S1 p.37]; building the board before advancing would put the monsters on the field during
## turn 1, so they are placed after it and back-dated by `give_monster_on_field()`.
static func _battlefield(seed_value: int, attacker_atk: int = 1800,
		defender_atk: int = 1000) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Gate Attacker", 4, attacker_atk, 1000))
	d["defender"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Gate Defender", 4, defender_atk, 1000))
	engine.continuous.recompute()
	return d


## Is the DECLARE_ATTACK action actually offered for this monster? This is the honest
## prevention question: prevention means the engine never offers the declaration, so asking
## `can_declare_attack()` alone would not prove the action list agrees with it.
static func _attack_offered(engine: DuelEngine, attacker: CardInstance) -> bool:
	return TestFixtures.has_action(
		engine.get_legal_actions(attacker.controller_id),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)


static func _can_attack(engine: DuelEngine, attacker: CardInstance) -> bool:
	return engine.battle.can_declare_attack(attacker, attacker.controller_id)


static func _declared(engine: DuelEngine) -> int:
	return TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED)


static func _negated(engine: DuelEngine) -> int:
	return TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED)


# ---------------------------------------------------------------------------
# Baseline
# ---------------------------------------------------------------------------

static func _test_an_unrestricted_monster_can_declare_an_attack(t: TestCase) -> void:
	t.start("BASELINE: with no restriction the attack is offered, declared and calculated")
	var d := _battlefield(9101)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]
	var defender: CardInstance = d["defender"]

	t.is_true(_can_attack(engine, attacker), "the rules layer allows the declaration")
	t.is_true(_attack_offered(engine, attacker), "and the action is actually offered")

	t.is_true(TestFixtures.attack(engine, attacker, defender), "the attack is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(_declared(engine), 1, "exactly one ATTACK_DECLARED")
	t.eq(_negated(engine), 0, "and nothing negated it")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 1,
		"damage really was calculated — this is the control every negative below is read "
		+ "against")
	t.eq(defender.zone, Enums.Zone.GRAVEYARD, "1800 beats 1000, so the defender is gone")
	t.is_true(attacker.has_attacked_this_turn, "and the attacker has used its attack")


# ---------------------------------------------------------------------------
# Prevention — per card
# ---------------------------------------------------------------------------

static func _test_a_per_card_lock_prevents_declaration(t: TestCase) -> void:
	t.start("PREVENTION (per card): a monster flagged `cannot_attack` is never offered the "
		+ "declaration")
	var d := _battlefield(9102)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]

	t.is_true(_attack_offered(engine, attacker), "it could attack a moment ago")
	attacker.flags["cannot_attack"] = true

	t.is_false(_can_attack(engine, attacker), "the rules layer now refuses")
	t.is_false(_attack_offered(engine, attacker), "and the action is withdrawn")
	t.is_false(TestFixtures.attack(engine, attacker, d["defender"]),
		"driving the attack through the public API fails")
	t.eq(_declared(engine), 0, "NO ATTACK_DECLARED event was emitted — prevention happens "
		+ "before declaration, it is not a declaration that is cancelled")


static func _test_a_per_card_lock_leaves_other_monsters_alone(t: TestCase) -> void:
	t.start("PREVENTION (per card): the lock names ONE monster")
	var d := _battlefield(9103)
	var engine: DuelEngine = d["engine"]
	var locked: CardInstance = d["attacker"]
	var free := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Free Attacker", 4, 1900, 1000))
	engine.continuous.recompute()

	locked.flags["cannot_attack"] = true

	t.is_false(_attack_offered(engine, locked), "the flagged monster cannot attack")
	t.is_true(_attack_offered(engine, free), "the other one still can")
	t.is_true(TestFixtures.attack(engine, free, d["defender"]), "and really does")
	TestFixtures.pass_until_open(engine)
	t.eq(_declared(engine), 1, "exactly one declaration, from the unlocked monster")


# ---------------------------------------------------------------------------
# Prevention — per player
# ---------------------------------------------------------------------------

static func _test_a_player_lock_prevents_every_monster_that_player_controls(
		t: TestCase) -> void:
	t.start("PREVENTION (per player): 'your opponent's monsters cannot declare an attack' "
		+ "covers all of them at once")
	var d := _battlefield(9104)
	var engine: DuelEngine = d["engine"]
	var first: CardInstance = d["attacker"]
	var second := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Second Attacker", 4, 1900, 1000))
	# Player 1 holds the lock, so it is PLAYER 0 — its opponent — who is restricted.
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Gate Swords", "opponent"))
	engine.continuous.recompute()

	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0),
		"the restriction is recorded against player 0")
	t.is_false(_attack_offered(engine, first), "the first monster cannot declare")
	t.is_false(_attack_offered(engine, second), "nor the second")
	t.eq(_declared(engine), 0, "and no declaration event was emitted for either")


static func _test_a_player_lock_is_aimed_and_does_not_hit_its_own_controller(
		t: TestCase) -> void:
	t.start("PREVENTION (per player): the restriction is AIMED — a lock on the opponent "
		+ "leaves its own controller free")
	var d := _battlefield(9105)
	var engine: DuelEngine = d["engine"]
	# Player 0 — the turn player and attacker — holds a lock aimed at its OPPONENT.
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.attack_lock_monster("Own Swords", "opponent"))
	engine.continuous.recompute()

	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 1),
		"player 1 is the one restricted")
	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0),
		"player 0 is not")
	t.is_true(_attack_offered(engine, d["attacker"]),
		"so player 0's own monster may still attack")
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]), "and does")
	TestFixtures.pass_until_open(engine)
	t.eq(_declared(engine), 1, "one real declaration happened")


static func _test_a_player_lock_covers_a_monster_that_arrives_afterwards(
		t: TestCase) -> void:
	t.start("PREVENTION (per player): a monster that reaches the field AFTER the lock is "
		+ "restricted too — this is why it is not a per-card flag")
	var d := _battlefield(9106)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Late Swords", "opponent"))
	engine.continuous.recompute()
	t.is_false(_attack_offered(engine, d["attacker"]), "the monster present is restricted")

	var latecomer := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Latecomer", 4, 2000, 1000))
	engine.continuous.recompute()

	t.is_false(_attack_offered(engine, latecomer),
		"and so is the monster that arrived after the lock was already in force")
	t.is_false(bool(latecomer.flags.get("cannot_attack", false)),
		"without any per-card flag having been written on it")


static func _test_a_prevented_attack_emits_no_attack_declared_event(t: TestCase) -> void:
	t.start("PREVENTION: the whole Battle Phase passes with ZERO attack events")
	var d := _battlefield(9107)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Silent Swords", "opponent"))
	engine.continuous.recompute()

	t.is_false(TestFixtures.attack(engine, d["attacker"], d["defender"]),
		"the declaration is refused")
	t.eq(_declared(engine), 0, "no ATTACK_DECLARED")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_TARGET_SELECTED), 0,
		"no ATTACK_TARGET_SELECTED")
	t.eq(_negated(engine), 0, "and no ATTACK_NEGATED — nothing was declared to negate")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_REPLAY), 0,
		"and no Replay — a prevented attack is not a cancelled one")


static func _test_a_prevented_monster_keeps_its_attack_for_the_turn(t: TestCase) -> void:
	t.start("PREVENTION: a monster that was prevented still has its attack, and uses it "
		+ "once the lock lifts")
	var d := _battlefield(9108)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]
	var lock := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Liftable Swords", "opponent"))
	engine.continuous.recompute()

	t.is_false(TestFixtures.attack(engine, attacker, d["defender"]), "prevented")
	t.is_false(attacker.has_attacked_this_turn,
		"and crucially it has NOT spent its attack — nothing was declared")

	engine.state.move_card(lock, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()

	t.is_true(_attack_offered(engine, attacker), "with the lock gone it may attack")
	t.is_true(TestFixtures.attack(engine, attacker, d["defender"]), "and it does")
	TestFixtures.pass_until_open(engine)
	t.eq(_declared(engine), 1, "exactly one declaration, the one that was allowed")


# ---------------------------------------------------------------------------
# Prevention — the source's own lifetime
# ---------------------------------------------------------------------------

static func _test_the_lock_lifts_when_its_source_leaves_the_field(t: TestCase) -> void:
	t.start("PREVENTION: the lock is state-derived — it is gone the moment its source is")
	var d := _battlefield(9109)
	var engine: DuelEngine = d["engine"]
	var lock := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Departing Swords", "opponent"))
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0), "in force")

	engine.state.move_card(lock, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()

	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0), "and gone")
	t.is_true(_attack_offered(engine, d["attacker"]), "the attack is offered again")


static func _test_the_lock_lifts_when_its_source_is_flipped_face_down(t: TestCase) -> void:
	t.start("PREVENTION: a face-DOWN source applies nothing")
	var d := _battlefield(9110)
	var engine: DuelEngine = d["engine"]
	var lock := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Hidden Swords", "opponent"))
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0), "in force face-up")

	engine.state.set_battle_position(lock, Enums.Position.FACE_DOWN, false)
	engine.continuous.recompute()

	t.is_true(lock.is_face_down(), "the source really is face-down")
	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0), "so it applies nothing")
	t.is_true(_attack_offered(engine, d["attacker"]), "the attack is offered again")


static func _test_the_lock_lifts_when_its_source_effects_are_negated(t: TestCase) -> void:
	t.start("PREVENTION: a source whose effects are negated applies nothing")
	var d := _battlefield(9111)
	var engine: DuelEngine = d["engine"]
	var lock := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Negated Swords", "opponent"))
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0), "in force")

	# `effects_negated` is the OUTSIDE-the-system negation channel, so it survives the
	# recompute that wipes the continuously-applied one.
	lock.effects_negated = true
	engine.continuous.recompute()

	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0),
		"a negated source restricts nobody")
	t.is_true(_attack_offered(engine, d["attacker"]), "the attack is offered again")


static func _test_the_lock_follows_control_of_its_source(t: TestCase) -> void:
	t.start("PREVENTION: 'your opponent' is read from the CURRENT controller, so taking the "
		+ "source turns the lock around")
	var d := _battlefield(9112)
	var engine: DuelEngine = d["engine"]
	var lock := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Turncoat Swords", "opponent"))
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0),
		"player 1 controls it, so player 0 is locked")

	engine.state.change_control(lock, 0, Enums.ControlDuration.PERMANENT, -1)
	engine.continuous.recompute()

	t.eq(lock.controller_id, 0, "player 0 now controls the source")
	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0),
		"so player 0 is no longer the 'opponent' the clause names")
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 1),
		"player 1 is")
	t.is_true(_attack_offered(engine, d["attacker"]), "and player 0 may attack")


static func _test_two_sources_both_apply_and_one_leaving_does_not_lift_the_other(
		t: TestCase) -> void:
	t.start("PREVENTION: two simultaneous sources — removing one leaves the other in force")
	var d := _battlefield(9113)
	var engine: DuelEngine = d["engine"]
	var first := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Swords A", "opponent"))
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Swords B", "opponent"))
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0), "both apply")

	engine.state.move_card(first, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()

	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 0),
		"the surviving source still restricts — the flag is rebuilt from the board, not "
		+ "reference-counted down to zero by the departure")
	t.is_false(_attack_offered(engine, d["attacker"]), "so the attack stays prevented")


static func _test_the_two_prevention_channels_are_independent(t: TestCase) -> void:
	t.start("PREVENTION: the per-CARD and per-PLAYER channels are separate — neither is "
		+ "expressed in terms of the other")
	var d := _battlefield(9114)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]
	var lock := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.attack_lock_monster("Both Swords", "opponent"))
	engine.continuous.recompute()

	t.is_false(bool(attacker.flags.get("cannot_attack", false)),
		"the player lock writes NO per-card flag")
	t.is_false(_attack_offered(engine, attacker), "yet the attack is prevented")

	# Now add the per-card flag as well and remove the player lock: the card flag alone must
	# still prevent, which proves the player lock is not the only consumer.
	attacker.flags["cannot_attack"] = true
	engine.state.move_card(lock, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()
	attacker.flags["cannot_attack"] = true

	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0),
		"the player-level restriction is gone")
	t.is_false(_attack_offered(engine, attacker),
		"but the per-card flag alone still prevents the declaration")
	t.eq(_declared(engine), 0, "and nothing was ever declared")


# ---------------------------------------------------------------------------
# Attacker legality vs target legality
# ---------------------------------------------------------------------------

static func _test_attacker_legality_and_target_legality_are_separate_questions(
		t: TestCase) -> void:
	t.start("attacker legality and TARGET legality are different questions and stay so")
	var d := _battlefield(9115)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]
	var defender: CardInstance = d["defender"]

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	t.not_null(action, "the declaration is offered")
	t.is_true(action.attack_target_candidates.has(defender.id),
		"and it publishes the opponent's monster as a candidate")
	t.is_false(action.allows_direct_attack,
		"a direct attack is not allowed while they control a monster [S1 p.38]")

	# Prevention removes the ATTACKER, not the target set: the defender remains a perfectly
	# legal target for anything else that could attack.
	attacker.flags["cannot_attack"] = true
	t.is_false(_attack_offered(engine, attacker), "the attacker is now illegal")
	t.is_true(engine.battle.attack_targets(0).has(defender),
		"but the target set is untouched — prevention does not shrink the target list")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

## Arrange the standard negation board: player 0 attacks, player 1 holds a Set Trap that
## negates the declared attack. Returns the battlefield dictionary plus `"negator"`.
static func _negation_board(seed_value: int, only_target: Array = []) -> Dictionary:
	var d := _battlefield(seed_value)
	var engine: DuelEngine = d["engine"]
	d["negator"] = TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.attack_negator("Gate Negator", only_target))
	engine.continuous.recompute()
	return d


## Declare the attack, then activate the negator from the response window it opens.
## Returns whether the negator's activation was actually submitted.
static func _declare_then_negate(engine: DuelEngine, attacker: CardInstance, target,
		negator: CardInstance) -> bool:
	if not TestFixtures.attack(engine, attacker, target):
		return false
	var responses := engine.get_legal_responses(1)
	var a = TestFixtures.find_action(responses, Enums.ActionKind.ACTIVATE_CARD, negator.id)
	if a == null:
		return false
	if not engine.submit_action(a):
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _test_a_negated_attack_was_really_declared_first(t: TestCase) -> void:
	t.start("NEGATION: the attack is legally DECLARED, the window opens, and a real Chain "
		+ "Link negates it")
	var d := _negation_board(9120)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]
	var negator: CardInstance = d["negator"]

	t.is_true(TestFixtures.attack(engine, attacker, d["defender"]),
		"the declaration is accepted — nothing prevented it")
	t.eq(_declared(engine), 1,
		"ATTACK_DECLARED really happened; this is what makes it negation and not prevention")

	var responses := engine.get_legal_responses(1)
	var a = TestFixtures.find_action(responses, Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(a, "the response window genuinely offered the negator")
	t.is_true(engine.submit_action(a), "and it was activated")
	TestFixtures.pass_until_open(engine)

	t.eq(_negated(engine), 1, "exactly one ATTACK_NEGATED")
	var ev: Array = TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_NEGATED)
	t.eq(int(ev[0].data.get("negated_by", -1)), negator.id,
		"and it names the card that actually negated it")
	t.eq(int(ev[0].data.get("attacker_id", -1)), attacker.id,
		"and the attacker it stopped")
	t.eq(negator.zone, Enums.Zone.GRAVEYARD,
		"the Trap resolved and went to the Graveyard, so the Chain Link really resolved")


static func _test_a_negated_attack_does_not_reach_damage_calculation(t: TestCase) -> void:
	t.start("NEGATION: the battle stops before damage calculation")
	var d := _negation_board(9121)
	var engine: DuelEngine = d["engine"]
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(_declare_then_negate(engine, d["attacker"], d["defender"], d["negator"]),
		"the attack was declared and then negated")

	t.eq(_declared(engine), 1, "one declaration")
	t.eq(_negated(engine), 1, "one negation")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 0,
		"and NO damage calculation — the baseline test proves one would otherwise happen")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_DAMAGE_INFLICTED), 0,
		"no battle damage")
	t.eq(engine.state.player(1).life_points, lp_before, "so no LP changed hands")
	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE,
		"the Damage Step was never entered")


static func _test_a_negated_attack_is_not_a_replay(t: TestCase) -> void:
	t.start("NEGATION is not a REPLAY: the attacker has spent its attack and cannot "
		+ "re-declare")
	var d := _negation_board(9122)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]

	t.is_true(_declare_then_negate(engine, attacker, d["defender"], d["negator"]),
		"declared and negated")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_REPLAY), 0,
		"no ATTACK_REPLAY event — this is the distinction that must not blur")
	t.is_true(attacker.has_attacked_this_turn,
		"the attacker HAS attacked this turn; a Replay would have cleared this")
	t.eq(engine.battle.replay_attacker_id, -1,
		"and no replay allowance was granted")
	t.is_false(_attack_offered(engine, attacker),
		"so the same monster is not offered a second declaration")


static func _test_the_battle_phase_continues_after_a_negated_attack(t: TestCase) -> void:
	t.start("NEGATION stops the ATTACK, not the Battle Phase: another monster may still "
		+ "attack")
	var d := _negation_board(9123)
	var engine: DuelEngine = d["engine"]
	var second := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Follow Up", 4, 1900, 1000))
	engine.continuous.recompute()

	t.is_true(_declare_then_negate(engine, d["attacker"], d["defender"], d["negator"]),
		"the first attack was negated")

	t.eq(engine.state.phase, Enums.Phase.BATTLE, "still in the Battle Phase")
	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE, "and back in the Battle Step")
	t.is_true(_attack_offered(engine, second), "the second monster is offered its attack")
	t.is_true(TestFixtures.attack(engine, second, d["defender"]), "and takes it")
	TestFixtures.pass_until_open(engine)
	t.eq(_declared(engine), 2, "two declarations in total")
	t.eq(_negated(engine), 1, "only the first was negated")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 1,
		"and the second one really did calculate damage")


static func _test_the_target_survives_a_negated_attack(t: TestCase) -> void:
	t.start("NEGATION: the target is left coherent — on the field, same position, unharmed")
	var d := _negation_board(9124)
	var engine: DuelEngine = d["engine"]
	var defender: CardInstance = d["defender"]
	var position_before := defender.position

	t.is_true(_declare_then_negate(engine, d["attacker"], defender, d["negator"]),
		"declared and negated")

	t.eq(defender.zone, Enums.Zone.MONSTER_ZONE, "the target is still on the field")
	t.eq(defender.position, position_before, "in the position it was in")
	t.is_false(defender.battled_this_turn, "and it never battled")
	t.is_null(engine.state.current_attack_target, "the battle state is cleared")
	t.is_null(engine.state.current_attacker, "on both sides")
	t.is_false(engine.battle.attack_is_negated(),
		"and the negation flag itself was reset, so it cannot leak into the next attack")


static func _test_negation_beats_the_replay_a_summon_would_otherwise_cause(
		t: TestCase) -> void:
	t.start("NEGATION is checked BEFORE the Replay: a monster arriving on the defending "
		+ "side during the negation does not hand the attack back")
	# This is the `Maiden with Eyes of Blue` shape exactly: negate the attack, then Special
	# Summon to the defending field. The summon changes the set of monsters the attacker
	# faces, which is the textbook Replay condition [S1 p.39] — and must not apply here,
	# because there is no longer an attack to replay.
	var d := _battlefield(9125)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]

	var summon_def := TestFixtures.monster("Summoned By Negation", 4, 1000, 1000)
	var negate_and_summon := TestFixtures.trap("Negate And Summon")
	var e := EffectDef.new("negate_then_summon",
		"Test: negate the attack, then Special Summon a monster.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.trigger_events = [GameEvent.Kind.ATTACK_DECLARED]
	e.condition = func(ctx: EffectContext) -> bool:
		return ctx.state.current_attacker != null
	e.resolve = func(ctx: EffectContext) -> void:
		if not EffectPrimitives.negate_declared_attack(ctx):
			return
		var extra := CardInstance.new(summon_def, ctx.controller_id)
		ctx.state.register_instance(extra)
		extra.zone = Enums.Zone.DECK
		ctx.state.player(ctx.controller_id).deck.append(extra)
		ctx.engine.special_summon(extra, ctx.controller_id,
			Enums.Position.FACE_UP_ATTACK, ctx.source.id)
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(negate_and_summon, e))
	engine.continuous.recompute()

	t.is_true(_declare_then_negate(engine, attacker, d["defender"], negator),
		"declared, then negated, and a monster was Special Summoned in the same resolution")

	t.eq(_negated(engine), 1, "the attack was negated")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"and the summon that would otherwise force a Replay really did happen")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_REPLAY), 0,
		"yet there is NO Replay — the negation was checked first")
	t.is_true(attacker.has_attacked_this_turn, "the attack stays spent")
	t.is_false(_attack_offered(engine, attacker), "and is not handed back")


static func _test_a_second_negation_of_the_same_attack_is_refused(t: TestCase) -> void:
	t.start("NEGATION: an attack can only be negated once")
	# `_negation_board` is used rather than a bare battlefield because the engine does not
	# pause when nobody holds a legal response — it auto-passes and resolves the whole attack
	# inside one `submit_action()`. Player 1's Set negator keeps the post-declaration window
	# genuinely open, which is the only way to observe the battle mid-flight.
	var d := _negation_board(9126)
	var engine: DuelEngine = d["engine"]

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]), "declared")
	t.eq(engine.battle.stage, BattleRules.Stage.AFTER_DECLARATION,
		"and the battle really is paused in its post-declaration window")
	t.is_true(engine.battle.negate_attack(-1), "the first negation applies")
	t.is_false(engine.battle.negate_attack(-1),
		"the second is refused rather than emitting a second event")
	t.eq(_negated(engine), 1, "exactly one ATTACK_NEGATED event")


static func _test_negation_is_refused_once_the_damage_step_has_begun(t: TestCase) -> void:
	t.start("NEGATION: the Damage Step boundary — there is no attack left to negate once "
		+ "damage calculation has started")
	var d := _negation_board(9127)
	var engine: DuelEngine = d["engine"]

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]), "declared")
	t.eq(engine.battle.stage, BattleRules.Stage.AFTER_DECLARATION,
		"the battle is in its post-declaration window")
	# Driven straight against `BattleRules`, because the guard under test is its own: the
	# question is whether the boundary is enforced at the one place that owns the battle,
	# not whether the engine happens to route around it.
	engine.battle.begin_damage_step()
	t.eq(engine.battle.stage, BattleRules.Stage.DS_START, "now inside the Damage Step")

	t.is_false(engine.battle.negate_attack(-1),
		"negation is refused rather than silently doing nothing")
	t.eq(_negated(engine), 0, "and no event was emitted")


static func _test_negation_is_refused_when_no_attack_is_live(t: TestCase) -> void:
	t.start("NEGATION: refused outright when no attack has been declared")
	var d := _battlefield(9128)
	var engine: DuelEngine = d["engine"]

	t.is_null(engine.state.current_attacker, "no attack is live")
	t.is_false(engine.battle.negate_attack(-1), "so negation is refused")
	t.eq(_negated(engine), 0, "and nothing was announced")


static func _test_negating_the_negator_lets_the_attack_through(t: TestCase) -> void:
	t.start("NEGATION: negating the attack-negating EFFECT lets the attack proceed to "
		+ "damage calculation")
	var d := _negation_board(9129)
	var engine: DuelEngine = d["engine"]
	var negator: CardInstance = d["negator"]
	# The turn player answers the negator with an effect-negation of its own, so the Chain is
	# two links deep and the upper one stops the lower.
	var counter := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.effect_negator("Gate Counter"))
	engine.continuous.recompute()

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]), "declared")
	var a = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(a, "the negator is offered")
	t.is_true(engine.submit_action(a), "and becomes Chain Link 1")
	var b = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, counter.id)
	t.not_null(b, "the counter is offered in response")
	t.is_true(engine.submit_action(b), "and becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the negator's EFFECT was negated — the route really was a two-link Chain")
	t.eq(_declared(engine), 1, "the attack was declared")
	t.eq(_negated(engine), 0, "and never negated")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 1,
		"so damage calculation happened after all")
	t.eq(d["defender"].zone, Enums.Zone.GRAVEYARD, "and the defender was destroyed")


static func _test_a_direct_attack_can_be_negated(t: TestCase) -> void:
	t.start("NEGATION: a DIRECT attack is negated the same way and inflicts no damage")
	var d := TestFixtures.battle_duel(9130)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Direct Attacker", 4, 1800, 1000))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.attack_negator("Direct Negator"))
	engine.continuous.recompute()
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(engine.battle.can_attack_directly(0), "player 1 controls no monsters")
	t.is_true(_declare_then_negate(engine, attacker, null, negator), "declared and negated")

	t.eq(_declared(engine), 1, "one declaration")
	var ev: Array = TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_DECLARED)
	t.is_true(bool(ev[0].data.get("direct", false)), "and it really was a direct attack")
	t.eq(_negated(engine), 1, "negated once")
	t.eq(engine.state.player(1).life_points, lp_before, "so no direct damage was dealt")


static func _test_the_event_order_is_declared_then_negated(t: TestCase) -> void:
	t.start("NEGATION: the event order is DECLARED before NEGATED, deterministically")
	var d := _negation_board(9131)
	var engine: DuelEngine = d["engine"]

	t.is_true(_declare_then_negate(engine, d["attacker"], d["defender"], d["negator"]),
		"declared and negated")

	var declared_at := TestFixtures.first_event_index(engine, GameEvent.Kind.ATTACK_DECLARED)
	var negated_at := TestFixtures.first_event_index(engine, GameEvent.Kind.ATTACK_NEGATED)
	t.ne(declared_at, -1, "the declaration is in the log")
	t.ne(negated_at, -1, "so is the negation")
	t.is_true(declared_at < negated_at,
		"and the declaration comes first — the attack existed before it was negated")


# ---------------------------------------------------------------------------
# Card-class activation lock
# ---------------------------------------------------------------------------

## A board in the Battle Step with player 1 holding a Set Trap and player 0 optionally
## holding the class lock. Returns the battlefield plus `"trap"`.
static func _class_lock_board(seed_value: int, with_lock: bool = true,
		category: Enums.Category = Enums.Category.TRAP,
		phase = Enums.Phase.BATTLE) -> Dictionary:
	var d := _battlefield(seed_value)
	var engine: DuelEngine = d["engine"]
	# A plain Set Trap for player 1 whose activation the lock is supposed to stop.
	var order_log: Array = []
	var e := TestFixtures.card_activation("locked_trap", Enums.SpellSpeed.SS2, order_log,
		"trap")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	d["trap"] = TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(TestFixtures.trap("Locked Trap"), e))
	if with_lock:
		d["lock"] = TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.activation_lock_monster("Gate Mirage", category, phase, "opponent"))
	engine.continuous.recompute()
	return d


## Can player 1 activate their Set Trap right now, in a response window?
static func _trap_offered(engine: DuelEngine, trap_card: CardInstance) -> bool:
	return TestFixtures.has_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, trap_card.id)


static func _test_the_class_lock_blocks_activating_that_class_in_that_phase(
		t: TestCase) -> void:
	t.start("CLASS LOCK: with the lock in force the opponent cannot activate a Trap Card "
		+ "during the Battle Phase")
	var control := _class_lock_board(9140, false)
	var control_engine: DuelEngine = control["engine"]
	t.is_true(TestFixtures.attack(control_engine, control["attacker"], control["defender"]),
		"CONTROL: the attack is declared")
	t.is_true(_trap_offered(control_engine, control["trap"]),
		"CONTROL: and without a lock the Trap IS offered — so the negative below is real")
	TestFixtures.pass_until_open(control_engine)

	var d := _class_lock_board(9141, true)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.phase, Enums.Phase.BATTLE, "we are in the Battle Phase")
	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "the lock is recorded against player 1's Traps")
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]), "the attack is declared")
	t.is_false(_trap_offered(engine, d["trap"]),
		"and the Trap is NOT offered in the window the declaration opened")
	t.is_false(ActivationRules.can_activate(engine.state, d["trap"],
		d["trap"].definition.effects[0], 1),
		"the legality gate itself refuses it")
	TestFixtures.pass_until_open(engine)


static func _test_the_class_lock_does_not_apply_outside_its_phase(t: TestCase) -> void:
	t.start("CLASS LOCK: it names a PHASE — outside it the same Trap is activatable")
	var d := _class_lock_board(9142, true)
	var engine: DuelEngine = d["engine"]
	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "locked during the Battle Phase")

	# Leave the Battle Phase; the very same lock must stop applying.
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)
	engine.continuous.recompute()

	t.eq(engine.state.phase, Enums.Phase.MAIN_2, "now in Main Phase 2")
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "and the lock does not apply here")
	t.is_true(ActivationRules.can_activate(engine.state, d["trap"],
		d["trap"].definition.effects[0], 1),
		"so the Trap may be activated again")


static func _test_the_class_lock_does_not_touch_other_categories(t: TestCase) -> void:
	t.start("CLASS LOCK: a Trap lock leaves SPELLS alone")
	var d := _class_lock_board(9143, true)
	var engine: DuelEngine = d["engine"]
	# A Set Quick-Play Spell for player 1 — activatable in either player's turn once Set.
	var order_log: Array = []
	var e := TestFixtures.card_activation("quick_spell", Enums.SpellSpeed.SS2, order_log,
		"spell")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	var quick := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.with_effect(
		TestFixtures.spell("Locked Spell", Enums.STKind.QUICK_PLAY_SPELL), e))
	engine.continuous.recompute()

	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "Traps are locked")
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.SPELL), "Spells are not")
	t.is_false(ActivationRules.can_activate(engine.state, d["trap"],
		d["trap"].definition.effects[0], 1), "the Trap is refused")
	t.is_true(ActivationRules.can_activate(engine.state, quick,
		quick.definition.effects[0], 1), "the Quick-Play Spell is allowed")


static func _test_the_class_lock_is_aimed_at_one_player(t: TestCase) -> void:
	t.start("CLASS LOCK: it names a PLAYER — the controller's own Traps are unaffected")
	var d := _class_lock_board(9144, true)
	var engine: DuelEngine = d["engine"]
	var order_log: Array = []
	var e := TestFixtures.card_activation("own_trap", Enums.SpellSpeed.SS2, order_log, "own")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	var own := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.with_effect(TestFixtures.trap("Own Trap"), e))
	engine.continuous.recompute()

	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "player 1's Traps are locked")
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 0,
		Enums.Category.TRAP), "player 0's are not")
	t.is_true(ActivationRules.can_activate(engine.state, own,
		own.definition.effects[0], 0),
		"so the lock's own controller may still activate a Trap")


static func _test_the_class_lock_does_not_stop_an_effect_of_a_face_up_card(
		t: TestCase) -> void:
	t.start("CLASS LOCK: it stops activating a Trap CARD, not activating an EFFECT of a "
		+ "Trap already face-up on the field — CARD_RULINGS.md R6")
	var d := _class_lock_board(9145, true)
	var engine: DuelEngine = d["engine"]
	# A Continuous Trap already face-up on the field, with an IGNITION effect. Activating
	# that effect is not "activating a Trap Card": the card was activated on an earlier turn.
	var continuous_trap := TestFixtures.trap("Face-Up Trap", Enums.STKind.CONTINUOUS_TRAP)
	var ignition := EffectDef.new("field_effect", "Test: an effect of a face-up Trap.")
	ignition.of_type(Enums.EffectType.QUICK)
	ignition.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	ignition.resolve = func(_ctx: EffectContext) -> void:
		pass
	var face_up := TestFixtures.give(engine, 1,
		TestFixtures.with_effect(continuous_trap, ignition),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	face_up.turn_set = -1
	engine.continuous.recompute()

	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "the Trap-card lock is in force")
	t.is_false(ActivationRules.can_activate(engine.state, d["trap"],
		d["trap"].definition.effects[0], 1),
		"so a Set Trap CARD may not be activated")
	t.eq(face_up.definition.effects[0].effect_type, Enums.EffectType.QUICK,
		"the face-up card's clause is an EFFECT activation, not a CARD activation")
	t.is_true(ActivationRules.can_activate(engine.state, face_up,
		face_up.definition.effects[0], 1),
		"and it IS allowed — the lock does not reach it")


static func _test_the_class_lock_lifts_with_its_source(t: TestCase) -> void:
	t.start("CLASS LOCK: state-derived — it lifts when its source leaves, is flipped down "
		+ "or is negated")
	var d := _class_lock_board(9146, true)
	var engine: DuelEngine = d["engine"]
	var lock: CardInstance = d["lock"]

	engine.state.set_battle_position(lock, Enums.Position.FACE_DOWN, false)
	engine.continuous.recompute()
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "face-down: the lock is gone")

	engine.state.set_battle_position(lock, Enums.Position.FACE_UP_ATTACK, false)
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "face-up again: the lock is back")

	lock.effects_negated = true
	engine.continuous.recompute()
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "negated: the lock is gone")

	lock.effects_negated = false
	engine.state.move_card(lock, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "off the field: the lock is gone for good")
	t.is_true(ActivationRules.can_activate(engine.state, d["trap"],
		d["trap"].definition.effects[0], 1), "and the Trap is activatable again")


static func _test_a_chain_already_underway_is_unaffected_by_the_class_lock(
		t: TestCase) -> void:
	t.start("CLASS LOCK: a Trap activated BEFORE the lock existed still resolves — the lock "
		+ "gates activation, not resolution")
	var d := _class_lock_board(9147, false)
	var engine: DuelEngine = d["engine"]
	var trap_card: CardInstance = d["trap"]
	# Player 1 gets a SECOND Set Trap it could respond with, so the engine PAUSES in
	# CHAIN_BUILD after the first one becomes Chain Link 1 instead of auto-passing both sides
	# and resolving the whole Chain inside one `submit_action()`. It is never activated.
	#
	# It belongs to player 1 rather than player 0 deliberately: the timing machine offers the
	# TURN PLAYER first, so a responder held by player 0 would make the engine stop before
	# player 1 was ever asked, and `get_legal_responses(1)` would correctly return nothing.
	var order_log: Array = []
	var spacer_effect := TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2,
		order_log, "spacer")
	spacer_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(TestFixtures.trap("Chain Holder"), spacer_effect))
	# The lock is placed FACE-DOWN, so it applies nothing yet and can be switched on mid-Chain
	# without putting a new card onto the field while a window is open.
	var lock := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.activation_lock_monster("Late Mirage", Enums.Category.TRAP,
			Enums.Phase.BATTLE, "opponent"), Enums.Position.FACE_DOWN)
	engine.continuous.recompute()
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "face-down, so no lock is in force yet")

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]), "the attack is declared")
	var a = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, trap_card.id)
	t.not_null(a, "the Trap is offered — no lock exists yet")
	t.is_true(engine.submit_action(a), "and is activated, becoming a real Chain Link")
	t.eq(engine.chain.chain_size(), 1, "the Chain is one link deep and still unresolved")

	# The lock switches on while that link is on the Chain, unresolved.
	engine.state.set_battle_position(lock, Enums.Position.FACE_UP_ATTACK, true)
	engine.continuous.recompute()
	t.is_true(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.TRAP), "the lock is now in force")

	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_RESOLVED), 1,
		"the already-activated link resolved anyway")
	t.eq(trap_card.zone, Enums.Zone.GRAVEYARD,
		"and the Trap reached the Graveyard, so it really resolved")


# ---------------------------------------------------------------------------
# Per-card turn counters
# ---------------------------------------------------------------------------

## Put a face-up turn-counting card into player `pid`'s Spell & Trap Zone and return it.
static func _counting_card(engine: DuelEngine, pid: int, limit: int,
		counted: String = "opponent") -> CardInstance:
	var c := TestFixtures.give(engine, pid,
		TestFixtures.turn_counting_card("Gate Countdown", limit, counted),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	c.turn_set = -1
	engine.continuous.recompute()
	return c


static func _test_a_turn_counter_counts_only_the_named_players_turns(t: TestCase) -> void:
	t.start("TURN COUNTER: only the named player's turns are counted")
	var d := TestFixtures.new_duel(9150, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	# Player 0 controls it and counts player 1's turns.
	var card := _counting_card(engine, 0, 99, "opponent")
	t.eq(card.turn_counter_value("turn_countdown"), 0, "nothing counted yet")

	TestFixtures.end_turn(engine)          # finishes player 0's turn 1
	t.eq(card.turn_counter_value("turn_countdown"), 0,
		"the CONTROLLER's own End Phase does not count")
	TestFixtures.end_turn(engine)          # finishes player 1's turn 2
	t.eq(card.turn_counter_value("turn_countdown"), 1, "the opponent's first turn counts")
	TestFixtures.end_turn(engine)          # player 0's turn 3
	t.eq(card.turn_counter_value("turn_countdown"), 1, "still one")
	TestFixtures.end_turn(engine)          # player 1's turn 4
	t.eq(card.turn_counter_value("turn_countdown"), 2, "the opponent's second turn counts")


static func _test_a_turn_counter_does_not_double_count_within_one_turn(
		t: TestCase) -> void:
	t.start("TURN COUNTER: advancing twice in the same turn counts once")
	var d := TestFixtures.new_duel(9151, 0)
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Counter Holder", 4, 1000, 1000))

	t.eq(card.advance_turn_counter("k", 5), 1, "first advance on turn 5")
	t.eq(card.advance_turn_counter("k", 5), 1, "second advance on turn 5 changes nothing")
	t.is_true(card.turn_counter_advanced_on("k", 5), "and it knows it counted turn 5")
	t.eq(card.advance_turn_counter("k", 6), 2, "turn 6 advances it")
	t.is_false(card.turn_counter_advanced_on("k", 5),
		"the record now names turn 6, not turn 5")
	t.eq(card.turn_counter_value("k"), 2, "the running total is 2")


static func _test_a_turn_counter_is_per_instance(t: TestCase) -> void:
	t.start("TURN COUNTER: two copies count separately")
	var d := TestFixtures.new_duel(9152, 0)
	var engine: DuelEngine = d["engine"]
	var def := TestFixtures.monster("Twin Counter", 4, 1000, 1000)
	var first := TestFixtures.give_monster_on_field(engine, 0, def)
	var second := TestFixtures.give_monster_on_field(engine, 0, def)

	first.advance_turn_counter("k", 3)
	first.advance_turn_counter("k", 4)

	t.eq(first.turn_counter_value("k"), 2, "the first copy has counted twice")
	t.eq(second.turn_counter_value("k"), 0,
		"the second copy is untouched — the counter is per INSTANCE, not per name")


static func _test_a_turn_counter_is_cleared_when_the_card_leaves_the_field(
		t: TestCase) -> void:
	t.start("TURN COUNTER: per-instance state, so leaving the field clears it")
	var d := TestFixtures.new_duel(9153, 0)
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Departing Counter", 4, 1000, 1000))
	card.advance_turn_counter("k", 2)
	card.advance_turn_counter("k", 3)
	t.eq(card.turn_counter_value("k"), 2, "two counted")

	engine.state.move_card(card, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(card.turn_counter_value("k"), 0, "and the tally is gone with the rest of the "
		+ "per-instance state — a card that left and came back starts over")

	var flipped := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Flipped Counter", 4, 1000, 1000))
	flipped.advance_turn_counter("k", 2)
	t.eq(flipped.turn_counter_value("k"), 1, "one counted")
	flipped.on_flipped_face_down()
	t.eq(flipped.turn_counter_value("k"), 0, "flipping face-down clears it too")


static func _test_a_turn_counter_reaching_its_limit_acts_once(t: TestCase) -> void:
	t.start("TURN COUNTER: the card acts in the End Phase of the counted player's Nth turn "
		+ "— and the two turns before it pass untouched")
	var d := TestFixtures.new_duel(9154, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var card := _counting_card(engine, 0, 3, "opponent")

	TestFixtures.end_turn(engine)   # p0 turn 1 — not counted
	TestFixtures.end_turn(engine)   # p1 turn 2 — count 1
	t.eq(card.turn_counter_value("turn_countdown"), 1, "one of the opponent's turns counted")
	t.eq(card.zone, Enums.Zone.SPELL_TRAP_ZONE, "and the card is still on the field")
	TestFixtures.end_turn(engine)   # p0 turn 3
	TestFixtures.end_turn(engine)   # p1 turn 4 — count 2
	t.eq(card.turn_counter_value("turn_countdown"), 2, "two counted")
	t.eq(card.zone, Enums.Zone.SPELL_TRAP_ZONE, "still on the field")
	TestFixtures.end_turn(engine)   # p0 turn 5
	TestFixtures.end_turn(engine)   # p1 turn 6 — count 3, the limit
	t.eq(card.zone, Enums.Zone.GRAVEYARD,
		"on the THIRD counted turn it acted and destroyed itself")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 1,
		"exactly once — the counter did not fire again on the way out")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED), 0,
		"and it put NO link on the Chain: this is a continuous clause responding to an "
		+ "event, not a Trigger Effect")


# ---------------------------------------------------------------------------
# Shared once-per-turn — EffectDef.restriction_group
# ---------------------------------------------------------------------------

## A monster with two independent IGNITION clauses. When `group` is non-empty both clauses
## are put in that shared restriction group, so they share ONE once-per-turn use; otherwise
## each carries its own named-effect limit.
##
## `Maiden with Eyes of Blue`'s "You can only use 1 'Maiden with Eyes of Blue' effect per
## turn, and only once that turn" is exactly the first shape, and it is neither
## `opt_named_effect()` on each clause nor `opt_instance()`. CARD_RULINGS.md R3.
static func _two_clause_monster(card_name: String, group: String) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, 1000, 1000)
	for suffix in ["a", "b"]:
		var e := EffectDef.new("clause_%s" % suffix, "Test: clause %s." % suffix)
		e.of_type(Enums.EffectType.IGNITION)
		e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
		e.opt_named_effect()
		if group != "":
			e.in_group(group)
		e.resolve = func(_ctx: EffectContext) -> void:
			pass
		d = TestFixtures.with_effect(d, e)
	return d


static func _clause_usable(engine: DuelEngine, card: CardInstance, index: int) -> bool:
	return ActivationRules.can_activate(engine.state, card,
		card.definition.effects[index], card.controller_id)


static func _test_two_clauses_in_one_group_share_a_single_use(t: TestCase) -> void:
	t.start("SHARED OPT: two clauses in one restriction group share ONE use per turn, in "
		+ "BOTH orders")
	# Order 1: clause A first, then clause B must be locked out.
	var d := TestFixtures.new_duel(9160, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var card := TestFixtures.give_monster_on_field(engine, 0,
		_two_clause_monster("Shared A First", "shared_use"))
	engine.continuous.recompute()

	t.is_true(_clause_usable(engine, card, 0), "clause A is available")
	t.is_true(_clause_usable(engine, card, 1), "so is clause B")
	t.is_true(TestFixtures.activate_effect(engine, 0, card, "clause_a"),
		"clause A is activated")
	t.is_false(_clause_usable(engine, card, 0), "clause A is now spent")
	t.is_false(_clause_usable(engine, card, 1),
		"and so is clause B — they share ONE use")

	# Order 2: clause B first, then clause A must be locked out. Both directions are tested
	# because a shared key implemented as "mark A, check A" would pass only one of them.
	var d2 := TestFixtures.new_duel(9161, 0)
	var engine2: DuelEngine = d2["engine"]
	TestFixtures.advance_to_phase(engine2, Enums.Phase.MAIN_1)
	var card2 := TestFixtures.give_monster_on_field(engine2, 0,
		_two_clause_monster("Shared B First", "shared_use"))
	engine2.continuous.recompute()

	t.is_true(TestFixtures.activate_effect(engine2, 0, card2, "clause_b"),
		"clause B is activated first this time")
	t.is_false(_clause_usable(engine2, card2, 1), "clause B is spent")
	t.is_false(_clause_usable(engine2, card2, 0),
		"and clause A is locked out by the same shared use")


static func _test_clauses_outside_the_group_keep_their_own_use(t: TestCase) -> void:
	t.start("SHARED OPT: without a group the two clauses are INDEPENDENT — this is the "
		+ "control that proves the shared key is doing the work")
	var d := TestFixtures.new_duel(9162, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var card := TestFixtures.give_monster_on_field(engine, 0,
		_two_clause_monster("Independent", ""))
	engine.continuous.recompute()

	t.eq(card.definition.effects[0].named_key(), "clause_a",
		"with no group the key is the clause's own id")
	t.is_true(TestFixtures.activate_effect(engine, 0, card, "clause_a"),
		"clause A is activated")
	t.is_false(_clause_usable(engine, card, 0), "clause A is spent")
	t.is_true(_clause_usable(engine, card, 1),
		"but clause B is untouched — separate keys, separate uses")


static func _test_a_shared_group_resets_next_turn(t: TestCase) -> void:
	t.start("SHARED OPT: the shared use comes back next turn")
	var d := TestFixtures.new_duel(9163, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var card := TestFixtures.give_monster_on_field(engine, 0,
		_two_clause_monster("Resetting", "shared_use"))
	engine.continuous.recompute()

	t.is_true(TestFixtures.activate_effect(engine, 0, card, "clause_a"), "clause A used")
	t.is_false(_clause_usable(engine, card, 1), "clause B locked out this turn")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn again")
	t.is_true(_clause_usable(engine, card, 0), "clause A is available again")
	t.is_true(_clause_usable(engine, card, 1), "and so is clause B")


static func _test_a_shared_group_is_per_player_and_per_name(t: TestCase) -> void:
	t.start("SHARED OPT: the key is per PLAYER and per NAME — another copy is locked out "
		+ "too, and the opponent's copy is not")
	var d := TestFixtures.new_duel(9164, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var def := _two_clause_monster("Named Share", "shared_use")
	var first := TestFixtures.give_monster_on_field(engine, 0, def)
	var second := TestFixtures.give_monster_on_field(engine, 0, def)
	var theirs := TestFixtures.give_monster_on_field(engine, 1, def)
	engine.continuous.recompute()

	t.is_true(TestFixtures.activate_effect(engine, 0, first, "clause_a"),
		"the first copy uses clause A")
	t.is_false(_clause_usable(engine, first, 1), "its own clause B is locked")
	t.is_false(_clause_usable(engine, second, 0),
		"and so is ANOTHER COPY's clause A — the restriction is on the name, not the copy")
	t.is_false(_clause_usable(engine, second, 1), "and that copy's clause B")
	t.is_false(engine.state.player(1).was_named_effect_used(
		theirs.card_name(), "shared_use", engine.state.turn_number),
		"the OPPONENT's record is untouched — the restriction is per player")
	t.is_true(engine.state.player(0).was_named_effect_used(
		first.card_name(), "shared_use", engine.state.turn_number),
		"while player 0's record really does hold the shared key — proving the assertion "
		+ "above is a genuine difference and not an empty ledger on both sides")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

static func _test_prevention_and_negation_are_replay_deterministic(t: TestCase) -> void:
	t.start("DETERMINISM: the same seed and the same inputs produce the same attack events "
		+ "in the same order")
	var runs: Array = []
	for i in range(2):
		var d := _negation_board(9170)
		var engine: DuelEngine = d["engine"]
		# One prevented monster and one attack that is declared and then negated.
		var blocked := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Blocked", 4, 1500, 1000))
		blocked.flags["cannot_attack"] = true
		var prevented := TestFixtures.attack(engine, blocked, d["defender"])
		var negated := _declare_then_negate(engine, d["attacker"], d["defender"],
			d["negator"])
		var trace: Array = []
		for e in engine.state.events:
			match e.kind:
				GameEvent.Kind.ATTACK_DECLARED, GameEvent.Kind.ATTACK_NEGATED, \
				GameEvent.Kind.ATTACK_REPLAY, GameEvent.Kind.DAMAGE_CALCULATED:
					trace.append("%d:%d" % [int(e.kind), int(e.data.get("attacker_id", -1))])
		runs.append({"prevented": prevented, "negated": negated, "trace": trace})

	t.is_false(bool(runs[0]["prevented"]), "the prevented attack really was refused")
	t.is_true(bool(runs[0]["negated"]), "and the other really was declared and negated")
	t.eq((runs[0]["trace"] as Array).size(), 2,
		"exactly two attack events: one declaration and one negation")
	t.eq(runs[1]["prevented"], runs[0]["prevented"], "the refusal reproduces")
	t.eq(runs[1]["negated"], runs[0]["negated"], "the negation reproduces")
	t.eq(str(runs[1]["trace"]), str(runs[0]["trace"]),
		"and the event trace is identical between the two runs")

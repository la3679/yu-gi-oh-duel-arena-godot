class_name MirageDragonTests
extends RefCounted

## `Mirage Dragon` — LIGHT / Dragon / Level 4 / 1600 ATK / 600 DEF, **2 copies**, deck 1.
##
## Official text (verified, `Data/cards/cards.json`, cid 6196):
##
##   "Your opponent cannot activate Trap Cards during the Battle Phase."
##
## One CONTINUOUS clause, and the first printed card in the pool to consume the card-class
## activation lock built by Phase 5 batch 9 unit A. `AttackRestrictionTests` (229) already
## proves the GENERIC channel; this suite proves that **this printed card** is wired to it —
## the right player, the right category, the right phase, the right lifetime — and that
## nothing card-specific was smuggled into the rules layer to make it work.
##
## Every positive claim is read against a CONTROL board without the Dragon, because a suite
## that only asserts "the Trap is not offered" passes just as happily when the Trap was never
## offered in the first place. That is the failure mode `PROJECT_STATE.md 0` records from
## batch 8, and it is why `_control_and_locked()` exists.
##
## Two facts about the pool make specific tests non-optional:
##
##   * **there are two copies**, so removing one must not lift the lock. `Mirage Dragon` is
##     one of only two quantity-2 cards in the pool, so this is a real board state rather
##     than a hypothetical one.
##   * a **Counter Trap** is a Trap Card [S1 p.30 lists Normal, Continuous and Counter as the
##     three kinds], so the lock covers activating one. Nothing in the engine special-cases
##     it; the test says so out loud rather than leaving it implied.
##
## `CARD_RULINGS.md` **R34 part D** is the ruling that carries this card, and its confidence is
## **HIGH**: cid 6196's official supplement (補足情報, 2015-03-21, fetched with
## `request_locale=ja` in Phase 6 unit 4) states the card/effect distinction outright, and each
## of its four bullets maps onto a test below — the table is in **R35 Part C**. (Batch 9 wrote
## "no Q&A entry for cid 6196" here; that came from the `en` locale and was wrong.) Both
## directions are asserted, so a later correction fails loudly in one place.

const CARD_UNDER_TEST := "Mirage Dragon"

const EFFECT_ID := "opponent_cannot_activate_traps_in_battle_phase"
const BASE_ATK := 1600
const BASE_DEF := 600
const COPIES := 2


static func run() -> TestCase:
	var t := TestCase.new("MirageDragonTests")

	# --- Shape: what the card declares before anything is driven through it ---
	_test_the_card_declares_one_continuous_clause(t)
	_test_the_clause_has_no_resolve_and_starts_no_chain(t)
	_test_the_clause_prints_no_once_per_turn_and_no_target(t)

	# --- The lock itself, against a control board ---
	_test_the_opponent_cannot_activate_a_set_trap_in_the_battle_phase(t)
	_test_the_lock_is_visible_to_the_generic_predicate(t)
	_test_the_action_is_withdrawn_from_the_real_response_list(t)

	# --- Which PLAYER ---
	_test_its_own_controller_may_still_activate_traps(t)
	_test_it_locks_the_turn_player_when_the_defender_controls_it(t)

	# --- Which PHASE ---
	_test_the_same_trap_is_activatable_in_main_phase_2(t)
	_test_the_lock_is_absent_in_main_phase_1(t)
	_test_the_lock_covers_the_whole_battle_phase_not_only_the_battle_step(t)

	# --- Which CATEGORY ---
	_test_spells_are_untouched(t)
	_test_a_counter_trap_is_a_trap_card_and_is_locked(t)
	_test_a_monster_effect_is_untouched(t)

	# --- CARD activation versus EFFECT activation — R34 part D ---
	_test_an_effect_of_an_already_face_up_trap_is_still_legal(t)

	# --- The source's own lifetime ---
	_test_the_lock_needs_the_source_face_up(t)
	_test_the_lock_lifts_when_the_source_is_negated(t)
	_test_the_lock_lifts_when_the_source_leaves_the_field(t)
	_test_the_lock_turns_around_when_control_of_the_source_changes(t)

	# --- Two copies ---
	_test_two_copies_both_apply_and_removing_one_does_not_lift_the_lock(t)

	# --- Timing boundary ---
	_test_a_chain_already_underway_still_resolves(t)

	# --- The pool ---
	_test_the_real_pool_carries_two_copies_and_the_printed_stat_line(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## A plain Set Trap whose CARD activation the lock is meant to stop. Set on turn 0 so it is
## legal to activate — a Trap may not be activated the turn it was Set [S1 p.30].
static func _set_trap(engine: DuelEngine, pid: int, card_name: String = "Board Trap",
		kind: Enums.STKind = Enums.STKind.NORMAL_TRAP) -> CardInstance:
	var order_log: Array = []
	var e := TestFixtures.card_activation("board_trap", Enums.SpellSpeed.SS2, order_log,
		"trap")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	if kind == Enums.STKind.COUNTER_TRAP:
		e.with_spell_speed(Enums.SpellSpeed.SS3)
	return TestFixtures.give_set_spell_trap(engine, pid,
		TestFixtures.with_effect(TestFixtures.trap(card_name, kind), e))


## The Battle Step of turn 2 with player 0 as the turn player, an attacker and a defender,
## a Set Trap for player 1, and — when `with_dragon` — a real `Mirage Dragon` face-up for
## player 0. `dragon_owner` lets the same board be built with the Dragon on the other side.
static func _board(seed_value: int, with_dragon: bool = true,
		dragon_owner: int = 0) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Field Attacker", 4, 1800, 1000))
	d["defender"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Field Defender", 4, 1000, 1000))
	d["trap"] = _set_trap(engine, 1)
	if with_dragon:
		d["dragon"] = TestFixtures.give_monster_on_field(engine, dragon_owner, _def())
	engine.continuous.recompute()
	return d


## Build the same board twice — once WITHOUT the Dragon and once with it — so every negative
## below is read against a positive that proves the route exists.
static func _control_and_locked(seed_value: int) -> Array:
	return [_board(seed_value, false), _board(seed_value + 1, true)]


static func _traps_locked(engine: DuelEngine, pid: int) -> bool:
	return ContinuousEffects.card_activation_locked(engine.state, pid, Enums.Category.TRAP)


## Does the legality gate itself allow player `pid` to activate `card` as a CARD?
static func _can_activate(engine: DuelEngine, card: CardInstance, pid: int) -> bool:
	return ActivationRules.can_activate(engine.state, card,
		card.definition.effects[0], pid)


## Is the activation actually OFFERED to player `pid` in the current response window?
static func _offered_as_response(engine: DuelEngine, card: CardInstance, pid: int) -> bool:
	return TestFixtures.has_action(engine.get_legal_responses(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_one_continuous_clause(t: TestCase) -> void:
	t.start("one EffectDef, CONTINUOUS, on the printed 1600 / 600 Level 4 LIGHT Dragon")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	t.eq(card_def.effects.size(), 1, "exactly one official clause")
	t.eq(card_def.base_atk, BASE_ATK, "1600 ATK")
	t.eq(card_def.base_def, BASE_DEF, "600 DEF")
	t.eq(card_def.level, 4, "Level 4")
	t.eq(card_def.attribute, "LIGHT", "LIGHT")
	t.eq(card_def.race, "Dragon", "Dragon")
	t.eq(card_def.category, Enums.Category.MONSTER, "and it is a Monster Card")

	var effect: EffectDef = card_def.effects[0]
	t.eq(effect.effect_id, EFFECT_ID, "the clause is the Trap lock")
	t.eq(effect.effect_type, Enums.EffectType.CONTINUOUS, "a Continuous Effect")
	t.eq(effect.ruling_ref, "R34", "and it cites the ruling that carries it")
	t.is_true(effect.apply_continuous.is_valid(),
		"it applies itself through apply_continuous")


static func _test_the_clause_has_no_resolve_and_starts_no_chain(t: TestCase) -> void:
	t.start("a continuous clause never resolves and puts no link on the Chain — there is no "
		+ "resolve() and starts_chain is false")
	var effect: EffectDef = _def().effects[0]
	t.is_false(effect.resolve.is_valid(), "no resolve() — nothing to resolve")
	t.is_false(effect.starts_chain, "and it starts no Chain")
	t.is_false(effect.pay_cost.is_valid(), "no cost — nothing is printed")
	t.is_false(effect.condition.is_valid(),
		"and no activation condition: it applies whenever the card is face-up on the field")
	t.is_true(effect.trigger_events.is_empty(),
		"it keys on no event — it is not a Trigger Effect in disguise")


static func _test_the_clause_prints_no_once_per_turn_and_no_target(t: TestCase) -> void:
	t.start("nothing that is not printed was added: no once-per-turn, no targeting, no "
		+ "bounded uses, no restriction group")
	var effect: EffectDef = _def().effects[0]
	t.is_false(effect.targets, "it does not target")
	t.is_false(effect.once_per_turn_instance, "no once-per-turn on the instance")
	t.is_false(effect.once_per_turn_named_effect, "none on the name")
	t.is_false(effect.once_per_turn_named_activation, "and none on the activation")
	t.eq(effect.uses_per_turn, 0, "no bounded number of uses")
	t.eq(effect.restriction_group, "", "and no shared restriction group")
	t.is_false(effect.negates_effects,
		"it does not negate effects — it forbids an activation, which is a different thing")


# ---------------------------------------------------------------------------
# The lock
# ---------------------------------------------------------------------------

static func _test_the_opponent_cannot_activate_a_set_trap_in_the_battle_phase(
		t: TestCase) -> void:
	t.start("CONTROL vs LOCKED: with Mirage Dragon face-up the opponent's Set Trap is "
		+ "refused during the Battle Phase, and without it the very same Trap is allowed")
	var pair := _control_and_locked(9201)
	var control: Dictionary = pair[0]
	var locked: Dictionary = pair[1]
	var control_engine: DuelEngine = control["engine"]
	var engine: DuelEngine = locked["engine"]

	t.eq(control_engine.state.phase, Enums.Phase.BATTLE, "the control board is in the Battle Phase")
	t.is_false(_traps_locked(control_engine, 1), "CONTROL: no lock exists")
	t.is_true(_can_activate(control_engine, control["trap"], 1),
		"CONTROL: so the Trap IS activatable — the negative below is real")

	t.eq(engine.state.phase, Enums.Phase.BATTLE, "the locked board is in the Battle Phase")
	t.is_true(_traps_locked(engine, 1), "LOCKED: the lock is recorded against player 1")
	t.is_false(_can_activate(engine, locked["trap"], 1),
		"LOCKED: and the same Trap is refused")


static func _test_the_lock_is_visible_to_the_generic_predicate(t: TestCase) -> void:
	t.start("the card writes the GENERIC key — the same one AttackRestrictionTests proved — "
		+ "rather than any Mirage-Dragon-specific state")
	var d := _board(9203)
	var engine: DuelEngine = d["engine"]
	var expected := ContinuousEffects.activation_lock_key(Enums.Category.TRAP,
		Enums.Phase.BATTLE)
	t.is_true(bool(engine.state.player(1).get_restriction(
		ContinuousEffects.PLAYER_KEY_PREFIX + expected, false)),
		"the Battle-Phase Trap key is set on player 1")
	t.is_false(bool(engine.state.player(1).get_restriction(
		ContinuousEffects.PLAYER_KEY_PREFIX
			+ ContinuousEffects.activation_lock_key(Enums.Category.TRAP, null), false)),
		"and the every-phase key is NOT — the card names one phase and only that phase")


static func _test_the_action_is_withdrawn_from_the_real_response_list(t: TestCase) -> void:
	t.start("the lock reaches the ACTION LIST, not only the legality predicate: after an "
		+ "attack is declared the Trap is offered without the Dragon and withdrawn with it")
	var pair := _control_and_locked(9205)
	var control: Dictionary = pair[0]
	var locked: Dictionary = pair[1]
	var control_engine: DuelEngine = control["engine"]
	var engine: DuelEngine = locked["engine"]

	t.is_true(TestFixtures.attack(control_engine, control["attacker"], control["defender"]),
		"CONTROL: the attack is declared")
	t.is_true(_offered_as_response(control_engine, control["trap"], 1),
		"CONTROL: and the Trap is offered in the window it opened")
	TestFixtures.pass_until_open(control_engine)

	t.is_true(TestFixtures.attack(engine, locked["attacker"], locked["defender"]),
		"LOCKED: the attack is declared too — the Dragon restricts activation, not attacking")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 1,
		"exactly one real declaration happened")
	t.is_false(_offered_as_response(engine, locked["trap"], 1),
		"LOCKED: but the Trap is not offered")
	TestFixtures.pass_until_open(engine)


# ---------------------------------------------------------------------------
# Which player
# ---------------------------------------------------------------------------

static func _test_its_own_controller_may_still_activate_traps(t: TestCase) -> void:
	t.start("'YOUR OPPONENT cannot' — the Dragon's own controller is unaffected")
	var d := _board(9207)
	var engine: DuelEngine = d["engine"]
	var own_trap := _set_trap(engine, 0, "Own Trap")
	engine.continuous.recompute()

	t.is_true(_traps_locked(engine, 1), "player 1 — the opponent — is locked")
	t.is_false(_traps_locked(engine, 0), "player 0 — the controller — is not")
	t.is_true(_can_activate(engine, own_trap, 0),
		"so the controller may still activate a Trap Card in the Battle Phase")
	t.is_false(_can_activate(engine, d["trap"], 1), "while the opponent may not")


static func _test_it_locks_the_turn_player_when_the_defender_controls_it(
		t: TestCase) -> void:
	t.start("the clause names the OPPONENT, not the turn player: a Dragon on the defending "
		+ "side locks the attacking player's own Traps")
	var d := _board(9209, true, 1)
	var engine: DuelEngine = d["engine"]
	var turn_player_trap := _set_trap(engine, 0, "Turn Player Trap")
	engine.continuous.recompute()

	t.eq(engine.state.turn_player_id, 0, "player 0 is the turn player")
	t.eq((d["dragon"] as CardInstance).controller_id, 1, "and player 1 controls the Dragon")
	t.is_true(_traps_locked(engine, 0), "so it is player 0 who is locked")
	t.is_false(_traps_locked(engine, 1), "and player 1 is free")
	t.is_false(_can_activate(engine, turn_player_trap, 0),
		"the turn player may not activate their own Trap during their Battle Phase")
	t.is_true(_can_activate(engine, d["trap"], 1),
		"while the Dragon's controller still may")


# ---------------------------------------------------------------------------
# Which phase
# ---------------------------------------------------------------------------

static func _test_the_same_trap_is_activatable_in_main_phase_2(t: TestCase) -> void:
	t.start("'during the BATTLE PHASE' — the same Trap, the same Dragon, Main Phase 2: "
		+ "activatable again")
	var d := _board(9211)
	var engine: DuelEngine = d["engine"]
	t.is_false(_can_activate(engine, d["trap"], 1), "refused in the Battle Phase")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"the Battle Phase ends")
	engine.continuous.recompute()

	t.eq(engine.state.phase, Enums.Phase.MAIN_2, "we are in Main Phase 2")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"the Dragon is still face-up on the field")
	t.is_true((d["dragon"] as CardInstance).is_face_up(), "and still face-up")
	t.is_false(_traps_locked(engine, 1), "but the lock does not apply here")
	t.is_true(_can_activate(engine, d["trap"], 1), "so the Trap may be activated")


static func _test_the_lock_is_absent_in_main_phase_1(t: TestCase) -> void:
	t.start("nor does it reach Main Phase 1 — the phase is part of the key, not decoration")
	var d := TestFixtures.new_duel(9213, 0)
	var engine: DuelEngine = d["engine"]
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"a duel sitting in Main Phase 1")
	var trap := _set_trap(engine, 1)
	TestFixtures.give_monster_on_field(engine, 0, _def())
	engine.continuous.recompute()

	t.eq(engine.state.phase, Enums.Phase.MAIN_1, "Main Phase 1")
	t.is_false(_traps_locked(engine, 1), "no lock applies")
	t.is_true(_can_activate(engine, trap, 1), "and the Trap is activatable")


static func _test_the_lock_covers_the_whole_battle_phase_not_only_the_battle_step(
		t: TestCase) -> void:
	t.start("it is keyed on the PHASE, so it is already in force at the Start Step — before "
		+ "any attack has been declared")
	var d := _board(9215)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.phase, Enums.Phase.BATTLE, "the Battle Phase")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 0,
		"and nothing has attacked yet")
	t.is_true(_traps_locked(engine, 1),
		"the lock is already in force — it does not wait for a declaration")
	t.is_false(_can_activate(engine, d["trap"], 1), "so the Trap is already refused")


# ---------------------------------------------------------------------------
# Which category
# ---------------------------------------------------------------------------

static func _test_spells_are_untouched(t: TestCase) -> void:
	t.start("'TRAP CARDS' — a Set Quick-Play Spell is still activatable in the same window")
	var d := _board(9217)
	var engine: DuelEngine = d["engine"]
	var order_log: Array = []
	var e := TestFixtures.card_activation("board_spell", Enums.SpellSpeed.SS2, order_log,
		"spell")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	var quick := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.with_effect(
		TestFixtures.spell("Board Spell", Enums.STKind.QUICK_PLAY_SPELL), e))
	engine.continuous.recompute()

	t.is_true(_traps_locked(engine, 1), "Traps are locked")
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.SPELL), "Spells are not")
	t.is_false(_can_activate(engine, d["trap"], 1), "the Trap is refused")
	t.is_true(_can_activate(engine, quick, 1), "the Quick-Play Spell is allowed")


static func _test_a_counter_trap_is_a_trap_card_and_is_locked(t: TestCase) -> void:
	t.start("a COUNTER TRAP is one of the three kinds of Trap Card [S1 p.30], so the lock "
		+ "covers it — asserted rather than left implied")
	var d := _board(9219)
	var engine: DuelEngine = d["engine"]
	var counter := _set_trap(engine, 1, "Board Counter", Enums.STKind.COUNTER_TRAP)
	var continuous_set := _set_trap(engine, 1, "Board Continuous",
		Enums.STKind.CONTINUOUS_TRAP)
	engine.continuous.recompute()

	t.eq(counter.definition.st_kind, Enums.STKind.COUNTER_TRAP, "it really is a Counter Trap")
	t.eq(counter.definition.category, Enums.Category.TRAP, "whose category is TRAP")
	t.eq(counter.definition.effects[0].spell_speed, Enums.SpellSpeed.SS3,
		"and whose activation is Spell Speed 3 — the lock is not a Spell Speed question")
	t.is_false(_can_activate(engine, counter, 1),
		"activating the Counter Trap as a CARD is refused")
	t.is_false(_can_activate(engine, continuous_set, 1),
		"and so is activating a Set Continuous Trap — all three kinds are Trap Cards")


static func _test_a_monster_effect_is_untouched(t: TestCase) -> void:
	t.start("'TRAP Cards' — a monster's own effect is a different category and is untouched")
	var d := _board(9221)
	var engine: DuelEngine = d["engine"]
	t.is_true(_traps_locked(engine, 1), "Traps are locked")
	t.is_false(ContinuousEffects.card_activation_locked(engine.state, 1,
		Enums.Category.MONSTER), "monsters are not")
	t.is_false(_traps_locked(engine, 0),
		"and the lock is aimed at one player, so the controller's Traps are free too")


# ---------------------------------------------------------------------------
# CARD activation versus EFFECT activation — R34 part D
# ---------------------------------------------------------------------------

static func _test_an_effect_of_an_already_face_up_trap_is_still_legal(t: TestCase) -> void:
	t.start("R34 part D: it locks activating a Trap CARD, not activating an EFFECT of a "
		+ "Continuous Trap already face-up on the field")
	var d := _board(9223)
	var engine: DuelEngine = d["engine"]
	# A Continuous Trap that was activated on an earlier turn and is sitting face-up, with an
	# Ignition-like ability of the kind [S1 p.30] describes. Using it is not a second
	# activation of the Trap Card.
	var ignition := EffectDef.new("face_up_ability",
		"Test: an ability of a Continuous Trap already face-up on the field.")
	ignition.of_type(Enums.EffectType.QUICK)
	ignition.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	ignition.resolve = func(_ctx: EffectContext) -> void:
		pass
	var face_up := TestFixtures.give(engine, 1, TestFixtures.with_effect(
		TestFixtures.trap("Face-Up Continuous Trap", Enums.STKind.CONTINUOUS_TRAP), ignition),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	face_up.turn_set = -1
	engine.continuous.recompute()

	t.is_true(_traps_locked(engine, 1), "the Trap-card lock is in force")
	t.eq(face_up.original_card_category(), Enums.Category.TRAP,
		"the face-up card is a Trap Card by category")
	t.eq(face_up.definition.effects[0].effect_type, Enums.EffectType.QUICK,
		"but its clause is an EFFECT activation, not a CARD activation")
	t.is_false(_can_activate(engine, d["trap"], 1),
		"so a Set Trap CARD may not be activated")
	t.is_true(_can_activate(engine, face_up, 1),
		"while the ability of the face-up Trap may be — the lock does not reach it")


# ---------------------------------------------------------------------------
# The source's own lifetime
# ---------------------------------------------------------------------------

static func _test_the_lock_needs_the_source_face_up(t: TestCase) -> void:
	t.start("'while face-up on the field' is what a continuous clause means: face-down, the "
		+ "lock is gone; face-up again, it returns")
	var d := _board(9225)
	var engine: DuelEngine = d["engine"]
	var dragon: CardInstance = d["dragon"]
	t.is_true(_traps_locked(engine, 1), "face-up: locked")

	engine.state.set_battle_position(dragon, Enums.Position.FACE_DOWN, false)
	engine.continuous.recompute()
	t.is_false(_traps_locked(engine, 1), "face-down: the lock is gone")
	t.is_true(_can_activate(engine, d["trap"], 1), "and the Trap is activatable")

	engine.state.set_battle_position(dragon, Enums.Position.FACE_UP_ATTACK, false)
	engine.continuous.recompute()
	t.is_true(_traps_locked(engine, 1), "face-up again: the lock is back")
	t.is_false(_can_activate(engine, d["trap"], 1), "and the Trap is refused again")


static func _test_the_lock_lifts_when_the_source_is_negated(t: TestCase) -> void:
	t.start("negating the Dragon's effects lifts the lock — the clause is an effect like "
		+ "any other")
	var d := _board(9227)
	var engine: DuelEngine = d["engine"]
	var dragon: CardInstance = d["dragon"]
	t.is_true(_traps_locked(engine, 1), "locked to begin with")

	dragon.effects_negated = true
	engine.continuous.recompute()
	t.is_false(_traps_locked(engine, 1), "negated: the lock is gone")
	t.is_true(_can_activate(engine, d["trap"], 1), "and the Trap is activatable")

	dragon.effects_negated = false
	engine.continuous.recompute()
	t.is_true(_traps_locked(engine, 1), "un-negated: the lock is back")


static func _test_the_lock_lifts_when_the_source_leaves_the_field(t: TestCase) -> void:
	t.start("the lock is state-derived — it is gone the moment the Dragon is")
	var d := _board(9229)
	var engine: DuelEngine = d["engine"]
	var dragon: CardInstance = d["dragon"]
	t.is_true(_traps_locked(engine, 1), "locked while it is on the field")

	engine.state.move_card(dragon, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()

	t.eq(dragon.zone, Enums.Zone.GRAVEYARD, "the Dragon is in the Graveyard")
	t.is_false(_traps_locked(engine, 1), "the lock is gone")
	t.is_true(_can_activate(engine, d["trap"], 1), "and the Trap is activatable again")


static func _test_the_lock_turns_around_when_control_of_the_source_changes(
		t: TestCase) -> void:
	t.start("'your opponent' is read from the CONTROLLER: take the Dragon and the lock "
		+ "turns around")
	var d := _board(9231)
	var engine: DuelEngine = d["engine"]
	var dragon: CardInstance = d["dragon"]
	var own_trap := _set_trap(engine, 0, "Own Trap")
	engine.continuous.recompute()
	t.is_true(_traps_locked(engine, 1), "player 1 is locked")
	t.is_false(_traps_locked(engine, 0), "player 0 is not")

	t.is_true(engine.state.change_control(dragon, 1, dragon.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "player 1 takes control of the Dragon")
	engine.continuous.recompute()

	t.eq(dragon.controller_id, 1, "player 1 now controls it")
	t.is_true(_traps_locked(engine, 0), "so it is now player 0 who is locked")
	t.is_false(_traps_locked(engine, 1), "and player 1 who is free")
	t.is_false(_can_activate(engine, own_trap, 0), "player 0's own Trap is now refused")
	t.is_true(_can_activate(engine, d["trap"], 1), "and player 1's is allowed")


# ---------------------------------------------------------------------------
# Two copies
# ---------------------------------------------------------------------------

static func _test_two_copies_both_apply_and_removing_one_does_not_lift_the_lock(
		t: TestCase) -> void:
	t.start("there are TWO copies in deck 1 — with both face-up, removing one must not lift "
		+ "the lock, because the other still says it")
	var d := _board(9233)
	var engine: DuelEngine = d["engine"]
	var first: CardInstance = d["dragon"]
	var second := TestFixtures.give_monster_on_field(engine, 0, _def())
	engine.continuous.recompute()

	t.ne(first.id, second.id, "two distinct instances of the same card")
	t.is_true(_traps_locked(engine, 1), "the lock is in force")

	engine.state.move_card(first, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()
	t.is_true(_traps_locked(engine, 1),
		"one copy left the field and the lock STILL stands — it is recomputed from the "
		+ "board, not reference-counted or toggled off by a departure")
	t.is_false(_can_activate(engine, d["trap"], 1), "so the Trap is still refused")

	engine.state.move_card(second, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	engine.continuous.recompute()
	t.is_false(_traps_locked(engine, 1), "with both gone the lock lifts")
	t.is_true(_can_activate(engine, d["trap"], 1), "and the Trap is activatable")


# ---------------------------------------------------------------------------
# Timing boundary
# ---------------------------------------------------------------------------

static func _test_a_chain_already_underway_still_resolves(t: TestCase) -> void:
	t.start("the lock gates ACTIVATION, not resolution: a Trap activated before the Dragon "
		+ "was face-up still resolves")
	var d := _board(9235, false)
	var engine: DuelEngine = d["engine"]
	var trap_card: CardInstance = d["trap"]
	# A second Set Trap for player 1 so the engine PAUSES in CHAIN_BUILD after the first
	# becomes Chain Link 1 rather than resolving the whole Chain inside one submit_action().
	# It belongs to player 1 because the timing machine offers the turn player first.
	_set_trap(engine, 1, "Chain Holder")
	# The Dragon starts FACE-DOWN so it applies nothing yet and can be switched on mid-Chain
	# without a new card arriving on the field while a window is open.
	var dragon := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN)
	engine.continuous.recompute()
	t.is_false(_traps_locked(engine, 1), "face-down, so no lock is in force yet")

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["defender"]),
		"the attack is declared")
	var a = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, trap_card.id)
	t.not_null(a, "the Trap is offered — no lock exists yet")
	t.is_true(engine.submit_action(a), "and is activated, becoming a real Chain Link")
	t.eq(engine.chain.chain_size(), 1, "the Chain is one link deep and still unresolved")

	engine.state.set_battle_position(dragon, Enums.Position.FACE_UP_ATTACK, true)
	engine.continuous.recompute()
	t.is_true(_traps_locked(engine, 1), "the lock is now in force, mid-Chain")

	TestFixtures.pass_until_open(engine)
	t.eq(trap_card.zone, Enums.Zone.GRAVEYARD,
		"the Trap resolved and went to the Graveyard — a lock acquired after activation "
		+ "does not reach back and undo it")
	t.eq(engine.chain.chain_size(), 0, "and the Chain is empty again")


# ---------------------------------------------------------------------------
# The pool
# ---------------------------------------------------------------------------

static func _test_the_real_pool_carries_two_copies_and_the_printed_stat_line(
		t: TestCase) -> void:
	t.start("the real pool: two copies in deck 1, so the two-copy test above is a board "
		+ "state that can actually happen")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")
	t.is_true(cards.has(CARD_UNDER_TEST), "and it contains Mirage Dragon")

	# `CardDef` deliberately does not carry the copy count — that is a property of the DECKS,
	# not of the card — so this reads the verified card database directly.
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the verified card database is readable")
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	t.check(parsed is Dictionary, "and parses")

	var copies := -1
	var cid := ""
	var text := ""
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if str(row.get("name", "")) == CARD_UNDER_TEST:
				copies = int(row.get("copies_total", -1))
				cid = str(row.get("konami_cid", ""))
				text = str(row.get("text", ""))
	t.eq(copies, COPIES, "two copies are printed in the pool")
	t.eq(cid, "6196", "the verified Konami card id")
	t.eq(text, "Your opponent cannot activate Trap Cards during the Battle Phase.",
		"and the implemented clause is the verified official text, verbatim")

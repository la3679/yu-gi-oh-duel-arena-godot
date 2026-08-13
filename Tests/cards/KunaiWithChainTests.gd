class_name KunaiWithChainTests
extends RefCounted

## Per-card suite for `Kunai with Chain`. Research/CARD_RULINGS.md R22.
##
##   "Activate 1 or both of these effects (simultaneously);
##    ●When an opponent's monster declares an attack: Target the attacking monster;
##      change that target to Defense Position.
##    ●Target 1 face-up monster you control; equip this card to that target.
##      It gains 500 ATK."
##
## The generic Equip subsystem is proved by `EquipTests` (83). What is specific to this card
## — and what this suite is about — is that the player has a real CHOICE of which effects to
## activate, that the two bullets have different timings, and that choosing both is one
## activation rather than two.

const CARD_UNDER_TEST := "Kunai with Chain"

const DEFENSE_ONLY := "change_attacker_to_defense"
const EQUIP_ONLY := "equip_to_your_monster"
const BOTH := "both_effects"
const ATK_BONUS := "equipped_monster_gains_500_atk"


static func run() -> TestCase:
	var t := TestCase.new("KunaiWithChainTests")
	_test_clause_shape(t)
	_test_equip_alone(t)
	_test_the_equip_target_filter(t)
	_test_which_activations_are_offered_when(t)
	_test_change_the_attacker_to_defense(t)
	_test_not_offered_when_you_are_the_attacker(t)
	_test_both_effects_are_one_activation(t)
	_test_an_illegal_two_target_selection_is_rejected(t)
	_test_battle_is_recalculated_from_the_equipped_atk(t)
	_test_the_host_leaving_destroys_it(t)
	_test_the_target_became_illegal_before_resolution(t)
	_test_activation_negated(t)
	_test_not_the_turn_it_was_set(t)
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


## A duel in the Battle Step of turn 2 with player 0 attacking. Player 1 holds the Kunai,
## because the first bullet answers "an OPPONENT's monster declares an attack".
static func _battle_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	TestFixtures.end_turn(d["engine"])
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.BATTLE)
	return d


static func _response(engine: DuelEngine, pid: int, card: CardInstance, effect_id: String):
	return TestFixtures.find_action(engine.get_legal_responses(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id, effect_id)


## How many times `card` was moved into `position` by a battle-position change.
##
## Read from the event log rather than from the board, because the engine resolves the
## attack declaration window, the Damage Step and the destruction inside one
## `submit_action()`: by the time control returns, a monster destroyed in that battle is in
## the Graveyard and its `position` says FACE_UP. The log is where the intermediate state
## survives.
static func _position_changes_to(engine: DuelEngine, card: CardInstance,
		position: Enums.Position) -> int:
	var n := 0
	for ev in TestFixtures.events_of(engine, GameEvent.Kind.BATTLE_POSITION_CHANGED):
		if int(ev.data.get("card_id", -1)) == card.id and ev.data.get("to") == position:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("'Activate 1 or both' is three legal activations, plus the continuous ATK gain "
		+ "the Equip Card grants")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP,
		"it is a NORMAL Trap — 'Equipped Traps remain Trap Cards' [S1 p.53]")
	t.eq(def.effects.size(), 4,
		"three activations (bullet 1, bullet 2, both) plus the granted continuous effect")

	var one := _effect(DEFENSE_ONLY)
	t.not_null(one, "bullet 1 alone is an activation in its own right")
	t.eq(one.effect_type, Enums.EffectType.CARD_ACTIVATION, "activating the Trap itself")
	t.eq(one.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2")
	t.eq(one.trigger_events, [GameEvent.Kind.ATTACK_DECLARED],
		"'When an opponent's monster declares an attack' is a real timing requirement")
	t.eq(one.target_count_min, 1, "'Target the attacking monster' — exactly one")
	t.eq(one.damage_step_permission, Enums.DamageStepPermission.NONE,
		"an attack declaration is in the Battle Step, not the Damage Step [S1 p.41]")

	var two := _effect(EQUIP_ONLY)
	t.not_null(two, "bullet 2 alone is an activation in its own right")
	t.eq(two.trigger_events, [],
		"bullet 2 carries NO timing requirement — it is not tied to an attack")
	t.eq(two.target_count_min, 1, "'Target 1 face-up monster you control'")
	t.eq(two.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"activated from a Set card on the field")

	var both := _effect(BOTH)
	t.not_null(both, "and 'both, simultaneously' is a third")
	t.eq(both.trigger_events, [GameEvent.Kind.ATTACK_DECLARED],
		"choosing both means meeting bullet 1's timing")
	t.eq(both.target_count_min, 2, "two targets, one for each bullet")
	t.eq(both.target_count_max, 2, "and no more")
	t.is_true(both.targets_valid.is_valid(),
		"a heterogeneous selection needs the clause's own validation, not just a count")

	var bonus := _effect(ATK_BONUS)
	t.not_null(bonus, "the ATK gain is its own clause")
	t.eq(bonus.effect_type, Enums.EffectType.CONTINUOUS,
		"'It gains 500 ATK' applies while equipped and is never activated [S1 p.55]")
	t.is_false(bonus.starts_chain, "so it starts no Chain")


# ---------------------------------------------------------------------------
# Bullet 2 alone
# ---------------------------------------------------------------------------

static func _test_equip_alone(t: TestCase) -> void:
	t.start("bullet 2 alone: equips to your own face-up monster, which gains 500 ATK, and "
		+ "the Normal Trap stays on the field because it equipped")
	var d := _main_phase_duel(5501)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY)
	t.not_null(offered, "bullet 2 is offered in an open game state with no attack anywhere")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [host.id]})),
		"and is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(kunai.equipped_to_id, host.id, "the Trap is equipped to the monster")
	t.eq(host.equipped_card_ids, [kunai.id], "and the monster knows about it")
	t.eq(kunai.zone, Enums.Zone.SPELL_TRAP_ZONE, "it stays in a Spell & Trap Zone")
	t.is_true(kunai.is_face_up(), "face-up")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 1,
		"exactly one CARD_EQUIPPED event")
	t.eq(host.current_atk(), 1500, "the host gained exactly 500 ATK")
	t.eq(host.definition.base_atk, 1000,
		"the PRINTED ATK is untouched — a modifier is not a rewrite [S1 p.55]")


static func _test_the_equip_target_filter(t: TestCase) -> void:
	t.start("'1 face-up monster YOU CONTROL': not the opponent's, and not a face-down one")
	var d := _main_phase_duel(5502)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1000, 1000))
	var hidden := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Hidden", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY)
	t.not_null(offered, "bullet 2 is offered")
	t.eq(offered.target_candidates, [mine.id],
		"exactly one candidate: the face-up monster its controller owns")
	t.is_false(offered.target_candidates.has(theirs.id), "not the opponent's monster")
	t.is_false(offered.target_candidates.has(hidden.id), "not a face-down monster")

	# A hand-built activation naming an illegal target is rejected outright.
	t.is_false(engine.submit_action(offered.with_choices({"target_ids": [theirs.id]})),
		"a hand-built activation targeting the opponent's monster is rejected")
	t.eq(kunai.zone, Enums.Zone.SPELL_TRAP_ZONE, "and the Trap is not even flipped")
	t.is_true(kunai.is_face_down(), "it is still Set")


# ---------------------------------------------------------------------------
# Timing — which activations exist when
# ---------------------------------------------------------------------------

static func _test_which_activations_are_offered_when(t: TestCase) -> void:
	t.start("bullet 1 and 'both' need an attack declaration; bullet 2 never does")
	var d := _battle_duel(5503)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Defender", 4, 1000, 1000))
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)

	# Before any attack: player 1 may still respond in the Battle Step's windows, but only
	# with bullet 2.
	t.is_true(TestFixtures.attack(engine, attacker, host), "player 0 declares an attack")
	t.not_null(_response(engine, 1, kunai, DEFENSE_ONLY),
		"bullet 1 is offered in the attack-declaration window")
	t.not_null(_response(engine, 1, kunai, EQUIP_ONLY),
		"so is bullet 2 — it has no timing requirement of its own")
	t.not_null(_response(engine, 1, kunai, BOTH),
		"and so is 'both', because bullet 1's timing is met")

	var one = _response(engine, 1, kunai, DEFENSE_ONLY)
	t.eq(one.target_candidates, [attacker.id],
		"bullet 1's only candidate is the attacking monster — there is nothing to choose")

	var both = _response(engine, 1, kunai, BOTH)
	t.eq(both.target_candidates.size(), 2,
		"'both' offers the attacking monster and the one face-up monster its user controls")
	t.is_true(both.target_candidates.has(attacker.id) and both.target_candidates.has(host.id),
		"one candidate from each bullet")

	# Now finish the battle and check an open game state on the Kunai controller's own turn.
	# The defender dies in that battle, so player 1 needs another face-up monster for
	# bullet 2 to have a legal target at all — otherwise this would test the wrong thing.
	TestFixtures.pass_until_open(engine)
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 1, "it is now the Kunai controller's own turn")
	var open_actions := engine.get_legal_actions(1)
	t.is_true(TestFixtures.has_action(open_actions, Enums.ActionKind.ACTIVATE_CARD,
		kunai.id, EQUIP_ONLY), "bullet 2 is available in an open game state")
	t.is_false(TestFixtures.has_action(open_actions, Enums.ActionKind.ACTIVATE_CARD,
		kunai.id, DEFENSE_ONLY), "bullet 1 is not — no monster is declaring an attack")
	t.is_false(TestFixtures.has_action(open_actions, Enums.ActionKind.ACTIVATE_CARD,
		kunai.id, BOTH), "and neither is 'both'")


static func _test_not_offered_when_you_are_the_attacker(t: TestCase) -> void:
	t.start("'when an OPPONENT'S monster declares an attack' — your own attacker does not "
		+ "enable bullet 1")
	var d := _battle_duel(5504)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, 1800, 1000))
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Wall", 4, 1000, 1000))
	# The attacking player holds the Kunai this time.
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	t.is_true(TestFixtures.attack(engine, attacker,
		engine.state.player(1).monsters()[0]), "player 0 declares an attack")
	# Player 1 responds first, then player 0 gets the window.
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_ACTIVATED), 0,
		"nothing was activated")

	var ctx := ActivationRules.make_context(engine.state, kunai,
		_effect(DEFENSE_ONLY), 0, null)
	t.is_false(bool(_effect(DEFENSE_ONLY).condition.call(ctx)),
		"the condition rejects an attack declared by a monster its own controller owns")

	# Positive control: the same clause accepts the opponent's attacker.
	var d2 := _battle_duel(5505)
	var engine2: DuelEngine = d2["engine"]
	var theirs := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.monster("Their Attacker", 4, 1800, 1000))
	var wall := TestFixtures.give_monster_on_field(engine2, 1,
		TestFixtures.monster("My Wall", 4, 1000, 1000))
	var kunai2 := TestFixtures.give_set_spell_trap(engine2, 1, _def(), 0)
	t.is_true(TestFixtures.attack(engine2, theirs, wall), "the opponent attacks")
	var ctx2 := ActivationRules.make_context(engine2.state, kunai2,
		_effect(DEFENSE_ONLY), 1, null)
	t.is_true(bool(_effect(DEFENSE_ONLY).condition.call(ctx2)),
		"and then the condition is satisfied — the negative was not vacuous")


# ---------------------------------------------------------------------------
# Bullet 1 — the position change
# ---------------------------------------------------------------------------

static func _test_change_the_attacker_to_defense(t: TestCase) -> void:
	t.start("the attacking monster is changed to Defense Position and the attack CONTINUES, "
		+ "with damage calculated from the attacker's ATK (R22)")
	var d := _battle_duel(5506)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	var wall := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wall", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	var lp_before := engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, attacker, wall), "the attack is declared")
	var one = _response(engine, 1, kunai, DEFENSE_ONLY)
	t.not_null(one, "bullet 1 is offered")
	t.is_true(engine.submit_action(one.with_choices({"target_ids": [attacker.id]})),
		"and activated targeting the attacking monster")
	TestFixtures.pass_until_open(engine)

	t.eq(attacker.position, Enums.Position.FACE_UP_DEFENSE,
		"the attacking monster is now in face-up Defense Position")
	t.is_true(attacker.is_face_up(), "face-up — it was not flipped down")
	t.eq(_position_changes_to(engine, attacker, Enums.Position.FACE_UP_DEFENSE), 1,
		"exactly one battle-position change, and it was on the attacking monster")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 0,
		"the attack was NOT negated")
	t.is_true(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED) > 0,
		"damage calculation still happened — the attack continued (R22)")
	t.eq(wall.zone, Enums.Zone.GRAVEYARD,
		"1800 ATK still beat the 1000 ATK defender, so the attacker's ATK was used")
	t.eq(engine.state.player(1).life_points, lp_before - 800,
		"and the defending player took the full 800 battle damage [S1 p.42]")
	t.eq(kunai.zone, Enums.Zone.GRAVEYARD,
		"the Trap did not equip in this mode, so it resolved to the Graveyard [S1 p.30]")
	t.eq(kunai.equipped_to_id, -1, "and is equipped to nothing")


# ---------------------------------------------------------------------------
# Both at once
# ---------------------------------------------------------------------------

static func _test_both_effects_are_one_activation(t: TestCase) -> void:
	t.start("'(simultaneously)' is ONE Chain Link that does both things")
	var d := _battle_duel(5507)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	var host := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Host", 4, 1400, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)

	t.is_true(TestFixtures.attack(engine, attacker, host), "the attack is declared")
	var both = _response(engine, 1, kunai, BOTH)
	t.not_null(both, "'both' is offered")
	var links_before := TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED)
	t.is_true(engine.submit_action(both.with_choices(
		{"target_ids": [attacker.id, host.id]})), "and activated with both targets")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before, 1,
		"one activation, one Chain Link — not two")
	TestFixtures.pass_until_open(engine)

	t.eq(_position_changes_to(engine, attacker, Enums.Position.FACE_UP_DEFENSE), 1,
		"bullet 1 applied: the attacker was changed to Defense Position")
	t.eq(kunai.equipped_to_id, host.id, "bullet 2 applied: the Trap equipped to the host")
	t.eq(kunai.zone, Enums.Zone.SPELL_TRAP_ZONE, "so it stays on the field")
	t.eq(host.current_atk(), 1900, "and the host gained 500 ATK, from 1400")
	t.eq(attacker.zone, Enums.Zone.GRAVEYARD,
		"the 1900 ATK host destroyed the 1800 ATK attacker in Defense Position")
	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "and survived")


static func _test_an_illegal_two_target_selection_is_rejected(t: TestCase) -> void:
	t.start("two of your OWN monsters satisfy the candidate list and the count, and are "
		+ "still an illegal selection for 'both'")
	var d := _battle_duel(5508)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	var a := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Mine A", 4, 1000, 1000))
	var b := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Mine B", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)

	t.is_true(TestFixtures.attack(engine, attacker, a), "the attack is declared")
	var both = _response(engine, 1, kunai, BOTH)
	t.not_null(both, "'both' is offered")
	t.eq(both.target_candidates.size(), 3, "three candidates across the two bullets")

	t.is_false(engine.submit_action(both.with_choices({"target_ids": [a.id, b.id]})),
		"picking two of your own monsters is rejected")
	t.is_true(kunai.is_face_down(), "the Trap was not even flipped face-up")
	t.eq(kunai.equipped_to_id, -1, "and nothing was equipped")

	# The legal selection on the same board is accepted, so the rejection is specific.
	var legal = _response(engine, 1, kunai, BOTH)
	t.not_null(legal, "'both' is still offered")
	t.is_true(engine.submit_action(legal.with_choices({"target_ids": [attacker.id, b.id]})),
		"one from each bullet is accepted")
	TestFixtures.pass_until_open(engine)
	t.eq(kunai.equipped_to_id, b.id, "and it equipped to the chosen monster")


# ---------------------------------------------------------------------------
# The equipped ATK
# ---------------------------------------------------------------------------

static func _test_battle_is_recalculated_from_the_equipped_atk(t: TestCase) -> void:
	t.start("a battle that would have been lost is won once the 500 ATK applies [S1 p.42]")
	var d := _battle_duel(5509)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1200, 1000))
	var host := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	var attacker_lp_before := engine.state.player(0).life_points

	t.is_true(TestFixtures.attack(engine, attacker, host), "the attack is declared")
	var equip = _response(engine, 1, kunai, EQUIP_ONLY)
	t.not_null(equip, "bullet 2 may be activated in the attack window too")
	t.is_true(engine.submit_action(equip.with_choices({"target_ids": [host.id]})),
		"equipping the defender")
	TestFixtures.pass_until_open(engine)

	t.eq(host.current_atk(), 1500, "the defender is now 1500 ATK")
	t.eq(attacker.zone, Enums.Zone.GRAVEYARD, "so the 1200 ATK attacker is destroyed")
	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "and the defender survives")
	t.eq(engine.state.player(0).life_points, attacker_lp_before - 300,
		"the attacking player takes 1500 - 1200 = 300 battle damage")


static func _test_the_host_leaving_destroys_it(t: TestCase) -> void:
	t.start("the host leaving takes the Equip Card with it, and the ATK gain with that")
	var d := _main_phase_duel(5510)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var bomb := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Blow It Up", host, "destroy"), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY)
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [host.id]})),
		"the Kunai equips")
	TestFixtures.pass_until_open(engine)
	t.eq(host.current_atk(), 1500, "the host is at 1500 ATK")

	t.is_true(TestFixtures.activate_card(engine, 0, bomb), "the host is then destroyed")
	t.eq(host.zone, Enums.Zone.GRAVEYARD, "the host left the field")
	t.eq(kunai.zone, Enums.Zone.GRAVEYARD,
		"and the Equip Card was destroyed with it [S1 p.29, p.55]")
	t.eq(kunai.equipped_to_id, -1, "the relationship is gone")
	t.eq(host.current_atk(), 1000,
		"and so is the modifier — the host is back to its printed ATK")
	t.is_true(TestFixtures.count_events(engine, GameEvent.Kind.CARD_UNEQUIPPED) > 0,
		"a CARD_UNEQUIPPED event was emitted")


static func _test_the_target_became_illegal_before_resolution(t: TestCase) -> void:
	t.start("a target removed between activation and resolution is not equipped to, and a "
		+ "Normal Trap that equipped nothing goes to the Graveyard")
	var d := _main_phase_duel(5511)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Doomed Host", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var remover := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Banish It", host, "banish"), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY)
	t.not_null(offered, "the Kunai is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [host.id]})),
		"and activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the opponent chains a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response), "which resolves first and banishes the target")
	TestFixtures.pass_until_open(engine)

	t.eq(host.zone, Enums.Zone.BANISHED, "the target left the field")
	t.eq(kunai.equipped_to_id, -1, "the Kunai equipped nothing")
	t.eq(kunai.zone, Enums.Zone.GRAVEYARD,
		"so it does not stay on the field despite being an Equip-capable Trap")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 0,
		"and no CARD_EQUIPPED event was ever emitted")


static func _test_activation_negated(t: TestCase) -> void:
	t.start("an activation negated by a Counter Trap equips nothing")
	var d := _main_phase_duel(5512)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	# A synthetic Counter Trap, so this suite tests its own card rather than another one.
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Test Counter"), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY)
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [host.id]})),
		"the Kunai is activated as Chain Link 1")
	var counter = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(counter, "the Counter Trap may answer a Trap activation")
	t.is_true(engine.submit_action(counter), "and is activated as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(kunai.equipped_to_id, -1, "nothing was equipped")
	t.eq(host.current_atk(), 1000, "the host gained no ATK")
	t.eq(kunai.zone, Enums.Zone.GRAVEYARD, "the negated card was destroyed")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 0,
		"no CARD_EQUIPPED event")


static func _test_not_the_turn_it_was_set(t: TestCase) -> void:
	t.start("a Trap cannot be activated the turn it was Set [S1 p.30]")
	var d := _main_phase_duel(5513)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var kunai := TestFixtures.give_set_spell_trap(engine, 0, _def(),
		engine.state.turn_number)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY),
		"Set this turn: not offered")

	kunai.turn_set = engine.state.turn_number - 1
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kunai.id, EQUIP_ONLY),
		"Set earlier: offered — the restriction is about the Set turn, nothing else")

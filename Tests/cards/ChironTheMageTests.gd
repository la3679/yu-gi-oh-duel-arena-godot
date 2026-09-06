class_name ChironTheMageTests
extends RefCounted

## Per-card suite for `Chiron the Mage` — "Once per turn: You can discard 1 Spell, then
## target 1 Spell/Trap your opponent controls; destroy that target."
##
## Four things have to hold at once, and each is failed on its own here rather than only
## together: the QUALIFIED cost (a Spell, not any card), the target scope (the opponent's
## Spell & Trap Zones and Field Zone, not their monsters and not your own cards), the
## once-per-turn allowance, and the fact that a cost stays paid when the card is stopped.
##
## `CARD_RULINGS.md` R41 Part D is why the shape is asserted at all: the OCG print says
## "select", the current TCG print says "target", and cid 5810 confirms the TCG reading —
## an Ignition effect on the field that really targets, with the discard as a real cost.

const CARD_UNDER_TEST := "Chiron the Mage"
const EFFECT_ID := "discard_spell_to_destroy_spell_trap"


static func run() -> TestCase:
	var t := TestCase.new("ChironTheMageTests")
	_test_clause_shape(t)
	_test_discards_a_spell_and_destroys_the_target(t)
	_test_the_cost_must_be_a_SPELL(t)
	_test_the_cost_is_paid_at_activation_and_never_refunded(t)
	_test_only_the_opponents_spell_traps_are_candidates(t)
	_test_a_field_spell_they_control_is_a_candidate(t)
	_test_a_face_down_set_card_is_a_candidate(t)
	_test_no_opponent_spell_trap_means_no_activation(t)
	_test_it_is_once_per_turn_per_instance(t)
	_test_a_target_that_left_the_field_is_dropped(t)
	_test_a_target_that_stopped_being_a_spell_trap_is_dropped(t)
	_test_a_prevented_destruction_destroys_nothing(t)
	_test_effect_negation_destroys_nothing_but_keeps_the_cost(t)
	_test_it_cannot_be_used_while_face_down_or_negated(t)
	_test_real_pool(t)
	_test_deterministic_replay(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _effect() -> EffectDef:
	var d := _card(CARD_UNDER_TEST)
	if d == null:
		return null
	for e in d.effects:
		if e.effect_id == EFFECT_ID:
			return e
	return null


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Chiron face-up on player 0's field, a Spell in their hand, one Set Trap for the opponent.
static func _board(seed_value: int) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["chiron"] = TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	d["fuel"] = TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Fuel Spell"))
	d["victim"] = TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Set Trap"))
	engine.continuous.recompute()
	return d


static func _activate_at(engine: DuelEngine, chiron: CardInstance,
		target: CardInstance) -> bool:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, chiron.id, EFFECT_ID)
	if offered == null:
		return false
	if not offered.target_candidates.has(target.id):
		return false
	if not engine.submit_action(offered.with_choices({"target_ids": [target.id]})):
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _candidates(engine: DuelEngine, chiron: CardInstance) -> Array:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, chiron.id, EFFECT_ID)
	return [] if offered == null else offered.target_candidates


static func _offered(engine: DuelEngine, chiron: CardInstance) -> bool:
	return TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, chiron.id, EFFECT_ID)


static func _indestructible_guard(card_name: String, ward: CardInstance) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, 1000, 1000)
	var e := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"Test: that card cannot be destroyed.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.condition = func(ctx: EffectContext) -> bool:
		var subject = ctx.params.get("card", null)
		return subject != null and (subject as CardInstance).id == ward.id
	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Chiron the Mage: one clause — an IGNITION effect on the field, with a real cost "
		+ "and a real target, once per turn on this copy")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.MONSTER, "it is a Monster")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	# cid 5810: an Ignition effect activated on the field.
	t.eq(e.effect_type, Enums.EffectType.IGNITION, "an IGNITION effect")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"activated only from a face-up Monster Zone")
	# cid 5810: it DOES target, despite the OCG "select" wording.
	t.is_true(e.targets, "it TARGETS")
	t.eq(e.target_count_min, 1, "exactly one target")
	t.eq(e.target_count_max, 1, "and no more than one")
	# cid 5810: the discard is a cost.
	t.is_true(e.pay_cost.is_valid(), "the discard is a COST")
	t.is_true(e.can_pay_cost.is_valid(), "with an affordability check")
	t.is_true(e.once_per_turn_instance, "once per turn on this copy")
	t.is_false(e.once_per_turn_named_effect, "not the per-name form")
	t.is_false(e.once_per_turn_named_activation, "and not the per-name activation form")
	t.eq(e.ruling_ref, "R41", "it cites the ruling that settled it")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_discards_a_spell_and_destroys_the_target(t: TestCase) -> void:
	t.start("Chiron the Mage: discards the Spell and destroys the targeted Spell/Trap")
	var d := _board(4401)
	var engine: DuelEngine = d["engine"]
	var fuel: CardInstance = d["fuel"]
	var victim: CardInstance = d["victim"]

	t.is_true(_activate_at(engine, d["chiron"], victim), "activated and resolved")
	t.eq(fuel.zone, Enums.Zone.GRAVEYARD, "the Spell really left the hand")
	t.eq(fuel.last_move_reason, Enums.MoveReason.DISCARDED,
		"DISCARDED, not sent by an effect")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 1,
		"exactly one CARD_DESTROYED event for the target")
	t.eq(victim.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"DESTROYED_BY_EFFECT")
	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "and it is in the Graveyard")
	t.eq((d["chiron"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"Chiron itself stays on the field")


static func _test_the_cost_must_be_a_SPELL(t: TestCase) -> void:
	t.start("Chiron the Mage: the discard is QUALIFIED — a hand of monsters and Traps cannot "
		+ "pay it, and only a Spell turns the effect on")
	var d := _duel(4402)
	var engine: DuelEngine = d["engine"]
	var chiron := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Their Set Trap"))
	engine.continuous.recompute()

	t.is_false(_offered(engine, chiron), "an empty hand cannot pay the cost")

	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("A Monster", 4, 1000, 1000))
	t.is_false(_offered(engine, chiron), "a monster in the hand is not a Spell")

	TestFixtures.give_to_hand(engine, 0, TestFixtures.trap("A Trap"))
	t.is_false(_offered(engine, chiron), "nor is a Trap")

	# Every Spell subtype qualifies — "1 Spell", not "1 Normal Spell".
	var continuous := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.spell("A Continuous Spell", Enums.STKind.CONTINUOUS_SPELL))
	t.is_true(_offered(engine, chiron),
		"a Continuous Spell qualifies — the clause says '1 Spell', not one subtype")

	# And the Spell that was really discarded is the one that was in the hand.
	var victim: CardInstance = engine.state.player(1).spell_traps()[0]
	t.is_true(_activate_at(engine, chiron, victim), "activated")
	t.eq(continuous.zone, Enums.Zone.GRAVEYARD, "the Continuous Spell was the one discarded")
	t.eq(continuous.last_move_reason, Enums.MoveReason.DISCARDED, "as a DISCARD")


static func _test_the_cost_is_paid_at_activation_and_never_refunded(t: TestCase) -> void:
	t.start("Chiron the Mage: the cost is paid at ACTIVATION — the Spell is already in the "
		+ "Graveyard while the Chain is still being built")
	var d := _board(4403)
	var engine: DuelEngine = d["engine"]
	var fuel: CardInstance = d["fuel"]
	var victim: CardInstance = d["victim"]
	# The engine does not pause when nobody holds a legal response — it auto-passes and
	# resolves the whole Chain inside one `submit_action()`. A Spell Speed 2 card the
	# opponent could respond with is what keeps the Chain open long enough to look at.
	var order: Array = []
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.with_effect(
		TestFixtures.trap("Their Bait"),
		TestFixtures.card_activation("bait", Enums.SpellSpeed.SS2, order)))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, d["chiron"].id, EFFECT_ID)
	t.not_null(offered, "the effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"activated as Chain Link 1")
	t.eq(engine.state.chain.size(), 1, "the Chain is still being built")
	t.eq(victim.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"and nothing has resolved yet — the target is untouched")
	t.eq(fuel.zone, Enums.Zone.GRAVEYARD,
		"but the cost is ALREADY paid: it is paid at activation, not at resolution")
	t.eq(fuel.last_move_reason, Enums.MoveReason.DISCARDED, "as a DISCARD")
	TestFixtures.pass_until_open(engine)
	t.eq(fuel.zone, Enums.Zone.GRAVEYARD, "and it stays paid")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 1,
		"the effect then resolved and destroyed the target")


# ---------------------------------------------------------------------------
# The candidate list
# ---------------------------------------------------------------------------

static func _test_only_the_opponents_spell_traps_are_candidates(t: TestCase) -> void:
	t.start("Chiron the Mage: only the OPPONENT's Spell/Traps are candidates — not their "
		+ "monsters, not their hand, and not your own cards")
	var d := _board(4404)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("My Set Trap"))
	var their_monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))
	var their_hand := TestFixtures.give_to_hand(engine, 1, TestFixtures.trap("Held Trap"))
	var their_gy := TestFixtures.give(engine, 1, TestFixtures.trap("Dead Trap"),
		Enums.Zone.GRAVEYARD)
	engine.continuous.recompute()

	var candidates := _candidates(engine, d["chiron"])
	t.is_true(candidates.has(d["victim"].id), "their Set Trap is a candidate")
	t.is_false(candidates.has(mine.id), "your own Set Trap is not")
	t.is_false(candidates.has(their_monster.id), "their monster is not")
	t.is_false(candidates.has(their_hand.id), "a Trap in their hand is not")
	t.is_false(candidates.has(their_gy.id), "a Trap in their Graveyard is not")
	t.is_false(candidates.has(d["chiron"].id), "and Chiron itself is not")
	t.eq(candidates.size(), 1, "exactly one candidate on this board")


static func _test_a_field_spell_they_control_is_a_candidate(t: TestCase) -> void:
	t.start("Chiron the Mage: a Field Spell the opponent controls is a Spell they control")
	var d := _board(4405)
	var engine: DuelEngine = d["engine"]
	var field_spell := TestFixtures.give(engine, 1,
		TestFixtures.spell("Their Field Spell", Enums.STKind.FIELD_SPELL),
		Enums.Zone.FIELD_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()

	t.eq(field_spell.zone, Enums.Zone.FIELD_ZONE, "it sits in their Field Zone")
	t.is_true(_candidates(engine, d["chiron"]).has(field_spell.id), "and is a candidate")
	t.is_true(_activate_at(engine, d["chiron"], field_spell), "it can be targeted")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		field_spell.id), 1, "and it was destroyed")


static func _test_a_face_down_set_card_is_a_candidate(t: TestCase) -> void:
	t.start("Chiron the Mage: a face-down Set card is a candidate — the clause names no "
		+ "property a face-down card lacks")
	var d := _board(4406)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	t.is_true(victim.is_face_down(), "the target really is face-down")
	t.is_true(_activate_at(engine, d["chiron"], victim), "it can be targeted and destroyed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 1,
		"the face-down card was destroyed")


static func _test_no_opponent_spell_trap_means_no_activation(t: TestCase) -> void:
	t.start("Chiron the Mage: with a payable cost but no legal target it is not offered")
	var d := _duel(4407)
	var engine: DuelEngine = d["engine"]
	var chiron := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Fuel Spell"))
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))
	engine.continuous.recompute()

	t.is_false(_offered(engine, chiron), "no Spell/Trap on their side means no activation")
	var appeared := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Now One"))
	t.is_true(_candidates(engine, chiron).has(appeared.id),
		"one Set card is enough to make it activatable")


# ---------------------------------------------------------------------------
# Once per turn
# ---------------------------------------------------------------------------

static func _test_it_is_once_per_turn_per_instance(t: TestCase) -> void:
	t.start("Chiron the Mage: once per turn on THIS copy — a second copy keeps its own use, "
		+ "and the allowance comes back next turn")
	var d := _board(4408)
	var engine: DuelEngine = d["engine"]
	var chiron: CardInstance = d["chiron"]
	var second := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Second Fuel"))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Third Fuel"))
	var second_victim := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Second Set Trap"))
	var third_victim := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Third Set Trap"))
	engine.continuous.recompute()

	t.is_true(_activate_at(engine, chiron, d["victim"]), "the first copy uses its effect")
	t.is_false(_offered(engine, chiron), "and may not use it again this turn")
	t.is_true(_offered(engine, second), "but the OTHER copy still may")
	t.is_true(_activate_at(engine, second, second_victim), "and does")
	t.is_false(_offered(engine, second), "which spends its own use")

	t.is_true(TestFixtures.end_turn(engine), "player 1 takes a turn")
	t.is_true(TestFixtures.end_turn(engine), "and it comes back to player 0")
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.is_true(_offered(engine, chiron), "the allowance is back next turn")
	t.is_true(_activate_at(engine, chiron, third_victim), "and can be spent again")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		third_victim.id), 1, "destroying the third target")


# ---------------------------------------------------------------------------
# Resolution, and every route by which it can fail
# ---------------------------------------------------------------------------

static func _test_a_target_that_left_the_field_is_dropped(t: TestCase) -> void:
	t.start("Chiron the Mage: a target removed in response is dropped, and the cost is "
		+ "still spent")
	var d := _board(4409)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	var fuel: CardInstance = d["fuel"]
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", victim, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, d["chiron"].id, EFFECT_ID)
	t.not_null(offered, "the effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.not_null(response, "a response window is open")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "Chain Link 2 removes the target")
	TestFixtures.pass_until_open(engine)

	# The prerequisite failed…
	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "the target left the field first")
	t.eq(victim.last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"it was SENT, not destroyed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"so no CARD_DESTROYED event exists")
	# …and the cost stayed paid.
	t.eq(fuel.zone, Enums.Zone.GRAVEYARD, "and the discard is not refunded")


static func _test_a_target_that_stopped_being_a_spell_trap_is_dropped(t: TestCase) -> void:
	t.start("Chiron the Mage: a Trap Monster that Summons itself in response is still on "
		+ "the field and still theirs, but is no longer a Spell/Trap — it is dropped")
	var d := _duel(4410)
	var engine: DuelEngine = d["engine"]
	var chiron := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var fuel := TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Fuel Spell"))
	# A face-up Continuous Trap in their Spell & Trap Zone with a Quick Effect that turns it
	# into a monster. RULES_SPEC.md 5.8.
	var shifter := TestFixtures.give(engine, 1,
		TestFixtures.trap_monster("Apophis Stand-In", "Reptile", "EARTH", 4, 1600, 1800,
			true, false, Enums.Position.FACE_UP_ATTACK, false, Enums.Zone.SPELL_TRAP_ZONE),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, chiron.id, EFFECT_ID)
	t.not_null(offered, "the effect is offered")
	if offered == null:
		return
	t.is_true(offered.target_candidates.has(shifter.id),
		"a face-up Spell/Trap in their Spell & Trap Zone is a legal target")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [shifter.id]})),
		"activated as Chain Link 1")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_EFFECT, shifter.id, "summon_self_as_trap_monster")
	t.not_null(response, "the Trap Monster's Quick Effect can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# The prerequisite for the claim.
	t.eq(shifter.zone, Enums.Zone.MONSTER_ZONE, "it moved into a Monster Zone")
	t.is_true(shifter.is_on_field(), "so it is STILL on the field")
	t.eq(shifter.controller_id, 1, "and STILL controlled by the opponent")
	t.is_true(shifter.is_monster(), "but it is a monster now")
	# …and it was dropped anyway, because neither "on the field" nor "theirs" is the test.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, shifter.id), 0,
		"it was NOT destroyed: it is no longer a Spell/Trap they control")
	t.eq(fuel.zone, Enums.Zone.GRAVEYARD, "and the cost is still spent")


static func _test_a_prevented_destruction_destroys_nothing(t: TestCase) -> void:
	t.start("Chiron the Mage: a target that cannot be destroyed survives, and the cost is "
		+ "still spent")
	var d := _board(4411)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	TestFixtures.give_monster_on_field(engine, 1,
		_indestructible_guard("Warding Guard", victim))
	engine.continuous.recompute()

	t.is_true(_activate_at(engine, d["chiron"], victim),
		"it is still a legal target — protection is not a targeting restriction")
	t.eq(victim.zone, Enums.Zone.SPELL_TRAP_ZONE, "the target survived")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"no CARD_DESTROYED event was raised")
	t.eq((d["fuel"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"and the discard is still spent")


static func _test_effect_negation_destroys_nothing_but_keeps_the_cost(t: TestCase) -> void:
	t.start("Chiron the Mage: a negated EFFECT destroys nothing, the cost stays paid, and "
		+ "the once-per-turn use stays spent")
	var d := _board(4412)
	var engine: DuelEngine = d["engine"]
	var chiron: CardInstance = d["chiron"]
	var victim: CardInstance = d["victim"]
	var fuel: CardInstance = d["fuel"]
	TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Spare Fuel"))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Effect Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, chiron.id, EFFECT_ID)
	t.not_null(offered, "the effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the negator can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(negator.zone, Enums.Zone.GRAVEYARD, "the negator resolved")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"nothing was destroyed")
	t.eq(victim.zone, Enums.Zone.SPELL_TRAP_ZONE, "the target is untouched")
	t.eq(fuel.zone, Enums.Zone.GRAVEYARD, "the cost stays paid [S1 p.53]")
	t.is_false(_offered(engine, chiron),
		"and the once-per-turn use stays spent, even with a spare Spell in hand")


static func _test_it_cannot_be_used_while_face_down_or_negated(t: TestCase) -> void:
	t.start("Chiron the Mage: the effect is activated from a FACE-UP Monster Zone, and a "
		+ "negated Chiron cannot use it")
	var d := _board(4413)
	var engine: DuelEngine = d["engine"]
	var chiron: CardInstance = d["chiron"]
	t.is_true(_offered(engine, chiron), "face-up and unnegated, it is offered")

	engine.state.set_battle_position(chiron, Enums.Position.FACE_DOWN_DEFENSE, true)
	t.is_true(chiron.is_face_down(), "now it is face-down")
	t.is_false(_offered(engine, chiron), "and the effect is not offered")

	engine.state.set_battle_position(chiron, Enums.Position.FACE_UP_ATTACK, true)
	t.is_true(_offered(engine, chiron), "face-up again, it is offered again")

	chiron.flags[ContinuousEffects.NEGATION_FLAG] = true
	t.is_true(chiron.effects_are_negated(), "its effects are negated")
	t.is_false(_offered(engine, chiron), "so the effect is not offered")


# ---------------------------------------------------------------------------
# The real pool, and determinism
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Chiron the Mage: it is in deck 1, and deck 1 really holds Spells to pay the "
		+ "cost with")
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the card database is readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary and parsed.has("cards")):
		t.check(false, "the card database parses")
		return
	var decks: Array = []
	var spells_in_deck_1 := 0
	for entry in parsed["cards"]:
		var name := str(entry.get("name", ""))
		if name == CARD_UNDER_TEST:
			decks = entry.get("decks", [])
		if (entry.get("decks", []) as Array).has("Blue-Eyes Dragon Guard") \
				and str(entry.get("category", "")) == "Spell":
			spells_in_deck_1 += 1
	t.is_true(decks.has("Blue-Eyes Dragon Guard"), "it is in deck 1")
	t.is_true(spells_in_deck_1 >= 5,
		"deck 1 really holds Spells to discard as the cost (%d)" % spells_in_deck_1)
	# Chiron is a Beast-Warrior, so it is not itself a Dragon and cannot be confused with the
	# deck's Dragon cards by any clause that reads Type.
	var lib: Dictionary = CardRegistry.load_library()["cards"]
	var def: CardDef = lib.get(CARD_UNDER_TEST, null)
	t.not_null(def, "it is implemented")
	if def != null:
		t.eq(def.race, "Beast-Warrior", "and it is a Beast-Warrior, not a Dragon")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("Chiron the Mage: the same seed and the same actions produce the same result")
	var results: Array = []
	for _i in range(2):
		var d := _board(4414)
		var engine: DuelEngine = d["engine"]
		var victim: CardInstance = d["victim"]
		_activate_at(engine, d["chiron"], victim)
		results.append({
			"victim_zone": victim.zone,
			"victim_reason": victim.last_move_reason,
			"fuel_zone": (d["fuel"] as CardInstance).zone,
			"destroyed": TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["victim_zone"], Enums.Zone.GRAVEYARD, "the target really was destroyed")
	t.eq(results[1]["victim_zone"], results[0]["victim_zone"], "the target's zone matches")
	t.eq(results[1]["victim_reason"], results[0]["victim_reason"], "and its move reason")
	t.eq(results[1]["fuel_zone"], results[0]["fuel_zone"], "the cost matches")
	t.eq(results[1]["destroyed"], results[0]["destroyed"], "the destruction counts match")
	t.eq(results[1]["events"], results[0]["events"], "and the whole event stream matches")

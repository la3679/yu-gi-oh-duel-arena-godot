class_name StampingDestructionTests
extends RefCounted

## Per-card suite for `Stamping Destruction` — "If you control a Dragon monster: Target 1
## Spell/Trap on the field; destroy that target, and if you do, inflict 500 damage to its
## controller."
##
## The card's whole difficulty is that its three clauses have three DIFFERENT lifetimes, and
## `CARD_RULINGS.md` R41 Part A settles each from the official supplement (cid 5345):
##
##   * the Dragon is an **activation condition** and is explicitly **not** re-checked at
##     resolution — the one place where this engine's usual "re-check everything" habit is
##     wrong, so it is the test this suite cares about most;
##   * the target **is** re-checked, like every targeting clause;
##   * the damage is **strictly conditional on the destruction succeeding**, so every route by
##     which the destruction can fail has to produce no damage at all.
##
## Every assertion that claims a destruction happened asserts the `CARD_DESTROYED` event and
## the move reason, not merely that the card is in a Graveyard — a card can reach a Graveyard
## without being destroyed [S1 p.52], and this card's damage depends on the difference.

const CARD_UNDER_TEST := "Stamping Destruction"
const EFFECT_ID := "destroy_spell_trap_and_burn"
const DAMAGE := 500


static func run() -> TestCase:
	var t := TestCase.new("StampingDestructionTests")
	_test_clause_shape(t)
	_test_destroys_the_target_and_burns_its_controller(t)
	_test_your_own_spell_trap_burns_YOU(t)
	_test_a_face_down_set_card_is_a_legal_target(t)
	_test_a_field_spell_is_a_legal_target(t)
	_test_no_dragon_means_no_activation(t)
	_test_a_face_down_dragon_does_not_count(t)
	_test_the_dragon_is_NOT_rechecked_at_resolution(t)
	_test_a_target_that_left_the_field_destroys_nothing_and_burns_nobody(t)
	_test_a_target_that_stopped_being_a_spell_trap_is_dropped(t)
	_test_a_prevented_destruction_inflicts_no_damage(t)
	_test_effect_negation_destroys_nothing_and_burns_nobody(t)
	_test_activation_negation_destroys_nothing_and_burns_nobody(t)
	_test_it_is_not_among_its_own_legal_targets(t)
	_test_monsters_are_never_targets(t)
	_test_no_spell_trap_on_the_field_means_no_activation(t)
	_test_the_damage_can_end_the_duel(t)
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


static func _dragon(name: String = "A Dragon") -> CardDef:
	var d := TestFixtures.monster(name, 4, 1600, 1200)
	d.race = "Dragon"
	return d


static func _not_a_dragon(name: String = "Not a Dragon") -> CardDef:
	var d := TestFixtures.monster(name, 4, 1600, 1200)
	d.race = "Beast-Warrior"
	return d


## A board where player 0 holds the Spell, controls a Dragon, and player 1 has one Set Trap.
static func _board(seed_value: int) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["dragon"] = TestFixtures.give_monster_on_field(engine, 0, _dragon())
	d["spell"] = TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	d["victim"] = TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Set Trap"))
	return d


## Activate the Spell against `target` and let the Chain finish. Returns false when the
## activation was never offered or the target was not among the published candidates.
static func _activate_at(engine: DuelEngine, spell: CardInstance,
		target: CardInstance) -> bool:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	if offered == null:
		return false
	if not offered.target_candidates.has(target.id):
		return false
	if not engine.submit_action(offered.with_choices({"target_ids": [target.id]})):
		return false
	TestFixtures.pass_until_open(engine)
	return true


## The published candidate list for an offered activation, or an empty array when the
## activation is not offered at all.
static func _candidates(engine: DuelEngine, spell: CardInstance) -> Array:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	return [] if offered == null else offered.target_candidates


## A continuous clause on a monster that prevents the destruction of one specific card.
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
	t.start("Stamping Destruction: one clause, a Normal Spell, a condition, a target, no cost")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.SPELL, "it is a Spell")
	t.eq(d.st_kind, Enums.STKind.NORMAL_SPELL, "a NORMAL Spell")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION, "a CARD_ACTIVATION")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.is_true(e.targets, "it TARGETS")
	t.eq(e.target_count_min, 1, "exactly one target")
	t.eq(e.target_count_max, 1, "and no more than one")
	t.is_true(e.legal_targets.is_valid(), "it publishes a candidate list")
	t.is_true(e.condition.is_valid(), "it has an activation condition")
	t.is_false(e.pay_cost.is_valid(), "there is NO cost — nothing is paid at activation")
	t.is_false(e.can_pay_cost.is_valid(), "and no cost check")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"a Spell Speed 1 Spell is never legal in the Damage Step")
	t.eq(e.ruling_ref, "R41", "it cites the ruling that settled it")


# ---------------------------------------------------------------------------
# The main line
# ---------------------------------------------------------------------------

static func _test_destroys_the_target_and_burns_its_controller(t: TestCase) -> void:
	t.start("Stamping Destruction: destroys the targeted Spell/Trap and burns its controller "
		+ "for exactly 500")
	var d := _board(4101)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	var lp_before := engine.state.player(1).life_points
	var my_lp_before := engine.state.player(0).life_points

	t.is_true(_activate_at(engine, d["spell"], victim), "activated against their Set Trap")

	# The claimed route, not merely the destination: a card can reach a Graveyard without
	# having been destroyed.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 1,
		"exactly one CARD_DESTROYED event for the target")
	t.eq(victim.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"DESTROYED_BY_EFFECT, not RESOLVED_TO_GY")
	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "and it is in the Graveyard")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE,
		"its controller lost exactly 500 LP")
	t.eq(engine.state.player(0).life_points, my_lp_before,
		"and the activating player lost nothing")
	t.is_false(engine.state.is_duel_over(), "the Duel continues")
	# The Spell itself was not destroyed — it resolved.
	var spell: CardInstance = d["spell"]
	t.eq(spell.zone, Enums.Zone.GRAVEYARD, "the Normal Spell went to the Graveyard")
	t.eq(spell.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"as a RESOLVED Normal Spell, not as a destroyed one")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, spell.id), 0,
		"and no CARD_DESTROYED event was raised for the Spell itself")


static func _test_your_own_spell_trap_burns_YOU(t: TestCase) -> void:
	t.start("Stamping Destruction: 'its controller' is the target's controller, so targeting "
		+ "your OWN Set card burns you")
	var d := _board(4102)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("My Set Trap"))
	var my_lp_before := engine.state.player(0).life_points
	var their_lp_before := engine.state.player(1).life_points

	t.is_true(_activate_at(engine, d["spell"], mine),
		"a card you control is a legal target — the text says 'on the field'")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, mine.id), 1,
		"your own Set card really was destroyed")
	t.eq(engine.state.player(0).life_points, my_lp_before - DAMAGE,
		"and YOU took the 500 damage")
	t.eq(engine.state.player(1).life_points, their_lp_before,
		"the opponent lost nothing at all")


static func _test_a_face_down_set_card_is_a_legal_target(t: TestCase) -> void:
	t.start("Stamping Destruction: a face-down Set card is a legal target — the clause names "
		+ "no property a face-down card lacks")
	var d := _board(4103)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	t.is_true(victim.is_face_down(), "the target really is face-down")
	t.is_true(_candidates(engine, d["spell"]).has(victim.id),
		"and it is published as a candidate")
	t.is_true(_activate_at(engine, d["spell"], victim), "it can be targeted and destroyed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 1,
		"the face-down card was destroyed")


static func _test_a_field_spell_is_a_legal_target(t: TestCase) -> void:
	t.start("Stamping Destruction: a Field Spell in the Field Zone IS 'a Spell/Trap on the "
		+ "field' — R41 Part B, and the pool really has one")
	var d := _board(4117)
	var engine: DuelEngine = d["engine"]
	var field_spell := TestFixtures.give(engine, 1,
		TestFixtures.spell("Their Field Spell", Enums.STKind.FIELD_SPELL),
		Enums.Zone.FIELD_ZONE, Enums.Position.FACE_UP)
	var lp_before := engine.state.player(1).life_points

	t.eq(field_spell.zone, Enums.Zone.FIELD_ZONE, "it really sits in the Field Zone")
	t.eq(engine.state.player(1).spell_traps().size(), 1,
		"and it is NOT one of the five Spell & Trap Zones")
	t.is_true(_candidates(engine, d["spell"]).has(field_spell.id),
		"it is nonetheless published as a candidate")

	t.is_true(_activate_at(engine, d["spell"], field_spell), "and it can be targeted")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		field_spell.id), 1, "the Field Spell was destroyed")
	t.eq(field_spell.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"by this effect")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE,
		"and its controller took the 500 damage")


# ---------------------------------------------------------------------------
# The activation condition
# ---------------------------------------------------------------------------

static func _test_no_dragon_means_no_activation(t: TestCase) -> void:
	t.start("Stamping Destruction: with no Dragon it is not offered at all, and a non-Dragon "
		+ "monster does not satisfy the condition")
	var d := _duel(4104)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Their Set Trap"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"an empty field does not satisfy 'if you control a Dragon monster'")

	TestFixtures.give_monster_on_field(engine, 0, _not_a_dragon())
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"nor does a Beast-Warrior — the Type is what is asked, not the count")

	# The opponent's Dragon is not yours.
	TestFixtures.give_monster_on_field(engine, 1, _dragon("Their Dragon"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"nor does a Dragon your OPPONENT controls")

	TestFixtures.give_monster_on_field(engine, 0, _dragon())
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"your own Dragon does, and only then is it offered")


static func _test_a_face_down_dragon_does_not_count(t: TestCase) -> void:
	t.start("Stamping Destruction: a face-DOWN Dragon does not satisfy the condition — Type "
		+ "is a property a face-down monster does not present")
	var d := _duel(4105)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Their Set Trap"))
	var hidden := TestFixtures.give_monster_on_field(engine, 0, _dragon("Hidden Dragon"),
		Enums.Position.FACE_DOWN_DEFENSE)

	t.is_true(hidden.is_face_down(), "the Dragon is face-down")
	t.eq(hidden.current_race(), "Dragon", "it is really a Dragon underneath")
	t.eq(engine.state.player(0).monsters().size(), 1, "and it really is on the field")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"and the activation is still refused")
	# The same claim by an independent route: the clause's own condition, asked directly,
	# rather than only the action list that consults it among a dozen other gates.
	var e := _effect()
	t.not_null(e, "the clause is reachable")
	if e != null:
		var ctx := ActivationRules.make_context(engine.state, spell, e, 0, null)
		t.is_false(bool(e.condition.call(ctx)),
			"the condition itself answers NO for a face-down Dragon")

	engine.state.set_battle_position(hidden, Enums.Position.FACE_UP_ATTACK, true)
	if e != null:
		var ctx2 := ActivationRules.make_context(engine.state, spell, e, 0, null)
		t.is_true(bool(e.condition.call(ctx2)),
			"and YES for the very same monster once it is face-up")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"flipping the same monster face-up is what makes it count")


static func _test_the_dragon_is_NOT_rechecked_at_resolution(t: TestCase) -> void:
	t.start("Stamping Destruction: R41 Part A — the Dragon is NOT re-checked at resolution, "
		+ "so removing it in response changes nothing")
	var d := _board(4106)
	var engine: DuelEngine = d["engine"]
	var dragon: CardInstance = d["dragon"]
	var victim: CardInstance = d["victim"]
	var lp_before := engine.state.player(1).life_points
	# A Spell Speed 2 response that removes the Dragon between activation and resolution.
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", dragon, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["spell"].id)
	t.not_null(offered, "the activation is offered while the Dragon is there")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"it is activated as Chain Link 1")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.not_null(response, "a response window is open")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "the responder is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# The prerequisite for the claim: the Dragon really did leave first.
	t.eq(dragon.zone, Enums.Zone.GRAVEYARD,
		"Chain Link 2 removed the Dragon before Chain Link 1 resolved")
	t.eq(engine.state.player(0).face_up_monsters().size(), 0,
		"so no Dragon was controlled at resolution")
	# …and the effect applied in full anyway.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 1,
		"the target was destroyed anyway")
	t.eq(victim.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"by this effect, not by anything else")
	t.eq(engine.state.player(1).life_points, lp_before - DAMAGE,
		"and the 500 damage was inflicted anyway")


# ---------------------------------------------------------------------------
# "and if you do" — every route by which the destruction can fail
# ---------------------------------------------------------------------------

static func _test_a_target_that_left_the_field_destroys_nothing_and_burns_nobody(
		t: TestCase) -> void:
	t.start("Stamping Destruction: a target removed in response is dropped — nothing is "
		+ "destroyed and NO damage is inflicted")
	var d := _board(4107)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	var lp_before := engine.state.player(1).life_points
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", victim, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["spell"].id)
	t.not_null(offered, "the activation is offered")
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
		"it was SENT, not destroyed — so no destruction can be attributed to this card")
	# …so neither consequence happened.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"no CARD_DESTROYED event exists at all")
	t.eq(engine.state.player(1).life_points, lp_before,
		"and 'and if you do' means NO damage was inflicted")


static func _test_a_target_that_stopped_being_a_spell_trap_is_dropped(t: TestCase) -> void:
	t.start("Stamping Destruction: a Trap Monster that Summons itself in response is still "
		+ "ON the field but is no longer a Spell/Trap — it is dropped, and nobody is burned")
	var d := _duel(4108)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _dragon())
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	# A face-up Continuous Trap in their Spell & Trap Zone with a Quick Effect that turns it
	# into a monster. RULES_SPEC.md 5.8.
	var shifter := TestFixtures.give(engine, 1,
		TestFixtures.trap_monster("Apophis Stand-In", "Reptile", "EARTH", 4, 1600, 1800,
			true, false, Enums.Position.FACE_UP_ATTACK, false, Enums.Zone.SPELL_TRAP_ZONE),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	var lp_before := engine.state.player(1).life_points

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(offered.target_candidates.has(shifter.id),
		"a face-up Spell/Trap in a Spell & Trap Zone is a legal target")
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
	t.is_true(shifter.is_on_field(), "so it is STILL on the field — this is not a bounce")
	t.is_true(shifter.is_monster(), "and it is a monster now")
	# …and the card dropped it anyway, because "on the field" is not the whole test.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, shifter.id), 0,
		"it was NOT destroyed: it is no longer a Spell/Trap on the field")
	t.eq(engine.state.player(1).life_points, lp_before, "and no damage was inflicted")


static func _test_a_prevented_destruction_inflicts_no_damage(t: TestCase) -> void:
	t.start("Stamping Destruction: a target that cannot be destroyed inflicts NO damage — "
		+ "the destruction is the prerequisite, not the attempt")
	var d := _board(4109)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	TestFixtures.give_monster_on_field(engine, 1,
		_indestructible_guard("Warding Guard", victim))
	var lp_before := engine.state.player(1).life_points
	var my_lp_before := engine.state.player(0).life_points
	var lp_events_before := TestFixtures.count_events(engine, GameEvent.Kind.LP_CHANGED)

	t.is_true(_activate_at(engine, d["spell"], victim),
		"it is still a legal target — protection is not a targeting restriction")
	# The prerequisite really failed.
	t.eq(victim.zone, Enums.Zone.SPELL_TRAP_ZONE, "the target survived")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"no CARD_DESTROYED event was raised")
	# …so the consequence did not happen either. Asserted three independent ways, because
	# "and if you do" is the single most load-bearing word in this card: on the balances, on
	# the LP_CHANGED event stream, and on the fact that nobody at all was burned.
	t.eq(engine.state.player(1).life_points, lp_before,
		"and no damage was inflicted, because the destruction did not succeed")
	t.eq(engine.state.player(0).life_points, my_lp_before,
		"nor was anyone else burned instead")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.LP_CHANGED) - lp_events_before, 0,
		"and NO LP_CHANGED event was raised at all")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

static func _test_effect_negation_destroys_nothing_and_burns_nobody(t: TestCase) -> void:
	t.start("Stamping Destruction: a negated EFFECT destroys nothing and burns nobody, but "
		+ "the card was still activated")
	var d := _board(4110)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	var lp_before := engine.state.player(1).life_points
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Effect Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["spell"].id)
	t.not_null(offered, "the activation is offered")
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

	# The negation really happened — asserted on the state, not inferred from the outcome.
	t.eq(negator.zone, Enums.Zone.GRAVEYARD, "the negator resolved")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"nothing was destroyed")
	t.eq(victim.zone, Enums.Zone.SPELL_TRAP_ZONE, "the target is untouched")
	t.eq(engine.state.player(1).life_points, lp_before, "and no damage was inflicted")
	# The ACTIVATION still happened: a Normal Spell whose effect was negated still resolves
	# to the Graveyard as a resolved Spell.
	t.eq(d["spell"].zone, Enums.Zone.GRAVEYARD, "the Spell still left the field")


static func _test_activation_negation_destroys_nothing_and_burns_nobody(t: TestCase) -> void:
	t.start("Stamping Destruction: a negated ACTIVATION destroys nothing and burns nobody")
	var d := _board(4111)
	var engine: DuelEngine = d["engine"]
	var victim: CardInstance = d["victim"]
	var spell: CardInstance = d["spell"]
	var lp_before := engine.state.player(1).life_points
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Activation Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [victim.id]})),
		"activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the Counter Trap can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# The route: the SPELL was destroyed by the negation, and the target was not.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, spell.id), 1,
		"the negated Spell itself was destroyed")
	t.eq(spell.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"by the Counter Trap")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, victim.id), 0,
		"and the target was not destroyed")
	t.eq(victim.zone, Enums.Zone.SPELL_TRAP_ZONE, "it is still Set")
	t.eq(engine.state.player(1).life_points, lp_before, "no damage was inflicted")


# ---------------------------------------------------------------------------
# The candidate list
# ---------------------------------------------------------------------------

static func _test_it_is_not_among_its_own_legal_targets(t: TestCase) -> void:
	t.start("Stamping Destruction: R41 Part G — a SET copy is on the field when its own "
		+ "targets are chosen, and is still not among them")
	var d := _duel(4112)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _dragon())
	# A Set copy, activated from the field: this is the only route on which the card really
	# is "1 Spell/Trap on the field" at the moment its targets are computed.
	var spell := TestFixtures.give_set_spell_trap(engine, 0, _card(CARD_UNDER_TEST))
	var other := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Their Trap"))

	t.eq(spell.zone, Enums.Zone.SPELL_TRAP_ZONE, "the copy really is in a Spell & Trap Zone")
	var candidates := _candidates(engine, spell)
	t.is_false(candidates.is_empty(), "the activation is offered")
	t.is_false(candidates.has(spell.id), "it is NOT among its own candidates")
	t.is_true(candidates.has(other.id), "while the opponent's Set card is")
	t.eq(candidates.size(), 1, "exactly one candidate — the exclusion removed nothing else")

	# And a hand copy cannot reach itself either, for the different reason that it is not on
	# the field yet when targets are computed.
	var in_hand := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	t.is_false(_candidates(engine, in_hand).has(in_hand.id),
		"a copy in the hand is not on the field, so it is not a candidate either")


static func _test_monsters_are_never_targets(t: TestCase) -> void:
	t.start("Stamping Destruction: monsters are never candidates, and neither is a card in a "
		+ "Graveyard, a hand or a Deck")
	var d := _board(4113)
	var engine: DuelEngine = d["engine"]
	var dragon: CardInstance = d["dragon"]
	var their_monster := TestFixtures.give_monster_on_field(engine, 1, _not_a_dragon("Theirs"))
	var in_gy := TestFixtures.give(engine, 1, TestFixtures.trap("Dead Trap"),
		Enums.Zone.GRAVEYARD)
	var in_hand := TestFixtures.give_to_hand(engine, 1, TestFixtures.trap("Held Trap"))

	var candidates := _candidates(engine, d["spell"])
	t.is_true(candidates.has(d["victim"].id), "their Set Trap is a candidate")
	t.is_false(candidates.has(dragon.id), "your own monster is not")
	t.is_false(candidates.has(their_monster.id), "nor is theirs")
	t.is_false(candidates.has(in_gy.id), "nor is a Trap in a Graveyard")
	t.is_false(candidates.has(in_hand.id), "nor is a Trap in a hand")
	t.eq(candidates.size(), 1, "exactly one candidate on this board")


static func _test_no_spell_trap_on_the_field_means_no_activation(t: TestCase) -> void:
	t.start("Stamping Destruction: with a Dragon but no Spell/Trap anywhere on the field it "
		+ "is not offered — a targeting clause needs a legal target")
	var d := _duel(4114)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _dragon())
	TestFixtures.give_monster_on_field(engine, 1, _not_a_dragon("Theirs"))
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"no Spell/Trap on the field means no activation")

	var appeared := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Now One"))
	t.is_true(_candidates(engine, spell).has(appeared.id),
		"one Set card is enough to make it activatable")


static func _test_the_damage_can_end_the_duel(t: TestCase) -> void:
	t.start("Stamping Destruction: the 500 damage is real effect damage and can end the Duel")
	var d := _board(4115)
	var engine: DuelEngine = d["engine"]
	engine.state.player(1).life_points = DAMAGE

	t.is_true(_activate_at(engine, d["spell"], d["victim"]), "activated")
	t.eq(engine.state.player(1).life_points, 0, "their LP reached exactly 0")
	t.is_true(engine.state.is_duel_over(), "and the Duel is over")


# ---------------------------------------------------------------------------
# The real pool, and determinism
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Stamping Destruction: it is in deck 1, which really does hold Dragons and "
		+ "Spell/Trap cards for it to reach, and the pool has no Field Spell")
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the card database is readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	t.is_true(parsed is Dictionary and parsed.has("cards"), "and parses")
	if not (parsed is Dictionary and parsed.has("cards")):
		return

	var decks: Array = []
	var dragons_in_deck_1 := 0
	var spell_traps_in_deck_1 := 0
	var field_spells := 0
	for entry in parsed["cards"]:
		var name := str(entry.get("name", ""))
		var in_deck_1: bool = (entry.get("decks", []) as Array).has("Blue-Eyes Dragon Guard")
		if name == CARD_UNDER_TEST:
			decks = entry.get("decks", [])
		if str(entry.get("icon", "")) == "Field Spell":
			field_spells += 1
		if not in_deck_1:
			continue
		if str(entry.get("race", "")) == "Dragon":
			dragons_in_deck_1 += 1
		elif str(entry.get("category", "")) in ["Spell", "Trap"]:
			spell_traps_in_deck_1 += 1

	t.is_true(decks.has("Blue-Eyes Dragon Guard"), "it is in deck 1")
	t.is_true(dragons_in_deck_1 >= 5,
		"deck 1 really holds Dragons for the activation condition (%d)" % dragons_in_deck_1)
	t.is_true(spell_traps_in_deck_1 >= 5,
		"and Spell/Trap cards for it to target (%d)" % spell_traps_in_deck_1)
	# R41 Part B. This assertion is COUNTED rather than claimed in prose, and it is the
	# reason the first draft of R41 Part B was corrected: the pool DOES contain a Field
	# Spell — `Hidden Springs of the Far East` — so the Field Zone branch of "on the field"
	# is live and is exercised by `_test_a_field_spell_is_a_legal_target` below.
	t.eq(field_spells, 1,
		"the V1 pool contains exactly one Field Spell, so the Field Zone really can fill")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("Stamping Destruction: the same seed and the same actions produce the same result")
	var results: Array = []
	for _i in range(2):
		var d := _board(4116)
		var engine: DuelEngine = d["engine"]
		var victim: CardInstance = d["victim"]
		_activate_at(engine, d["spell"], victim)
		results.append({
			"lp0": engine.state.player(0).life_points,
			"lp1": engine.state.player(1).life_points,
			"victim_zone": victim.zone,
			"victim_reason": victim.last_move_reason,
			"destroyed": TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["lp1"], results[1]["lp1"], "the opponent's LP match")
	t.eq(results[0]["lp0"], results[1]["lp0"], "the controller's LP match")
	t.eq(results[0]["victim_zone"], results[1]["victim_zone"], "the target's zone matches")
	t.eq(results[0]["victim_reason"], results[1]["victim_reason"], "and its move reason")
	t.eq(results[0]["destroyed"], results[1]["destroyed"], "the destruction counts match")
	t.eq(results[0]["events"], results[1]["events"], "and the whole event stream matches")

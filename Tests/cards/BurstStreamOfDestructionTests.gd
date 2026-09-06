class_name BurstStreamOfDestructionTests
extends RefCounted

## Per-card suite for `Burst Stream of Destruction` — "If you control 'Blue-Eyes White
## Dragon': Destroy all monsters your opponent controls. 'Blue-Eyes White Dragon' you
## control cannot attack the turn you activate this card."
##
## The board wipe is the easy half. The suite is mostly about the second sentence, because
## `CARD_RULINGS.md` R41 Part C (cid 5979, 2024-09-07) says four things the printed English
## does not, three of which would otherwise have been silent bugs:
##
##   * it is ALSO an activation restriction — you cannot activate it on a turn in which a
##     `Blue-Eyes White Dragon` has already attacked;
##   * the ban covers EVERY copy, including one Summoned later that same turn;
##   * it attaches at ACTIVATION and therefore survives EFFECT negation;
##   * ACTIVATION negation lifts it.
##
## The generic mechanism underneath — the turn-scoped, name-keyed attack ban of
## RULES_SPEC.md 6.5 — has its own gate in `AttackRestrictionTests`, written before this card
## existed. What is asserted here is that this card drives it correctly.

const CARD_UNDER_TEST := "Burst Stream of Destruction"
const BLUE_EYES := "Blue-Eyes White Dragon"
const DESTROY_ID := "destroy_all_opponent_monsters"


static func run() -> TestCase:
	var t := TestCase.new("BurstStreamOfDestructionTests")
	_test_clause_shape(t)
	_test_destroys_every_monster_the_opponent_controls(t)
	_test_it_leaves_everything_else_alone(t)
	_test_the_blue_eyes_must_be_yours_and_face_up(t)
	_test_the_condition_is_not_rechecked_at_resolution(t)
	_test_the_attack_ban_applies_for_the_rest_of_the_turn(t)
	_test_the_ban_covers_a_blue_eyes_summoned_afterwards(t)
	_test_the_ban_expires_with_the_turn(t)
	_test_it_cannot_be_activated_after_a_blue_eyes_has_attacked(t)
	_test_that_restriction_survives_the_attacker_leaving_the_field(t)
	_test_another_monster_attacking_does_not_block_the_activation(t)
	_test_effect_negation_stops_the_wipe_but_NOT_the_ban(t)
	_test_activation_negation_stops_both(t)
	_test_real_pool(t)
	_test_deterministic_replay(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _clause(effect_id: String) -> EffectDef:
	var d := _card(CARD_UNDER_TEST)
	if d == null:
		return null
	for e in d.effects:
		if e.effect_id == effect_id:
			return e
	return null


## Turn 2, player 0 to move, sitting in Main Phase 1. `battle_duel()` gives player 1 the
## first turn so player 0 may conduct a Battle Phase from turn 2 [S1 p.37]; the board is
## built afterwards and back-dated by `give_monster_on_field()`.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["blue_eyes"] = TestFixtures.give_monster_on_field(engine, 0, _card(BLUE_EYES))
	d["spell"] = TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	d["theirs"] = [
		TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Their First", 4, 1200, 1000)),
		TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Their Second", 4, 1500, 1000),
			Enums.Position.FACE_DOWN_DEFENSE),
	]
	engine.continuous.recompute()
	return d


static func _offered(engine: DuelEngine, spell: CardInstance) -> bool:
	return TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)


static func _can_attack(engine: DuelEngine, monster: CardInstance) -> bool:
	return engine.battle.can_declare_attack(monster, monster.controller_id)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Burst Stream: TWO clauses — a Normal Spell activation and a lingering "
		+ "activation-condition clause, which is not a resolving effect at all")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.SPELL, "it is a Spell")
	t.eq(d.st_kind, Enums.STKind.NORMAL_SPELL, "a NORMAL Spell")
	t.eq(d.effects.size(), 2, "exactly two effect clauses")

	var wipe := _clause(DESTROY_ID)
	t.not_null(wipe, "the destruction clause exists")
	if wipe != null:
		t.eq(wipe.effect_type, Enums.EffectType.CARD_ACTIVATION, "it is a CARD_ACTIVATION")
		t.eq(wipe.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
		t.is_false(wipe.targets, "it does NOT target")
		t.is_false(wipe.pay_cost.is_valid(), "and has no cost")
		t.is_true(wipe.condition.is_valid(), "it has an activation condition")
		t.eq(wipe.ruling_ref, "R41", "citing the ruling that settled it")

	var lingering := _clause(ActivationRules.ACTIVATION_CONDITION_EFFECT_ID)
	t.not_null(lingering, "the lingering clause uses the activation-condition channel")
	if lingering != null:
		t.eq(lingering.effect_type, Enums.EffectType.CONTINUOUS, "it is CONTINUOUS")
		t.is_false(lingering.starts_chain, "it starts no Chain")
		t.is_true(lingering.condition.is_valid(),
			"it gates the ACTIVATION — the half the English text does not print")
		t.is_true(lingering.activation_confirmed.is_valid(),
			"and applies its consequence on a confirmed activation")
		t.is_false(lingering.resolve.is_valid(),
			"it never resolves: it is not an effect that goes on the Chain")
		t.is_false(lingering.apply_continuous.is_valid(),
			"and it is not a continuous modifier either")


# ---------------------------------------------------------------------------
# The board wipe
# ---------------------------------------------------------------------------

static func _test_destroys_every_monster_the_opponent_controls(t: TestCase) -> void:
	t.start("Burst Stream: destroys every monster the opponent controls, face-DOWN ones "
		+ "included")
	var d := _board(4301)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	t.is_true((theirs[1] as CardInstance).is_face_down(), "one of them is face-down")

	t.is_true(TestFixtures.activate_card(engine, 0, d["spell"]), "activated and resolved")
	for entry in theirs:
		var card: CardInstance = entry
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 1,
			"%s raised exactly one CARD_DESTROYED event" % card.card_name())
		t.eq(card.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
			"%s was DESTROYED_BY_EFFECT" % card.card_name())
	t.eq(engine.state.player(1).monsters().size(), 0, "their Monster Zones are empty")


static func _test_it_leaves_everything_else_alone(t: TestCase) -> void:
	t.start("Burst Stream: it touches only the opponent's MONSTERS — not their Spell/Traps, "
		+ "not their hand, and not your own board")
	var d := _board(4302)
	var engine: DuelEngine = d["engine"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Set Trap"))
	var their_hand := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Held Monster", 4, 1000, 1000))
	var my_other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Other", 4, 1000, 1000))

	t.is_true(TestFixtures.activate_card(engine, 0, d["spell"]), "activated and resolved")
	t.eq(their_trap.zone, Enums.Zone.SPELL_TRAP_ZONE, "their Set Trap is untouched")
	t.eq(their_hand.zone, Enums.Zone.HAND, "the monster in their hand is untouched")
	t.eq(blue_eyes.zone, Enums.Zone.MONSTER_ZONE, "your Blue-Eyes White Dragon survives")
	t.eq(my_other.zone, Enums.Zone.MONSTER_ZONE, "and so does your other monster")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		blue_eyes.id), 0, "no CARD_DESTROYED event for your own monster")


static func _test_the_blue_eyes_must_be_yours_and_face_up(t: TestCase) -> void:
	t.start("Burst Stream: the condition needs a FACE-UP `Blue-Eyes White Dragon` that YOU "
		+ "control — not a face-down one, not another Dragon, not theirs")
	var d := TestFixtures.new_duel(4303, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))

	t.is_false(_offered(engine, spell), "an empty field does not satisfy it")

	var other_dragon := TestFixtures.give_monster_on_field(engine, 0,
		_card("Alexandrite Dragon"))
	t.eq(other_dragon.current_race(), "Dragon", "a real Dragon from the pool")
	t.is_false(_offered(engine, spell), "another Dragon does not satisfy it — it is a NAME")

	TestFixtures.give_monster_on_field(engine, 1, _card(BLUE_EYES))
	t.is_false(_offered(engine, spell),
		"nor does a `Blue-Eyes White Dragon` your OPPONENT controls")

	var face_down := TestFixtures.give_monster_on_field(engine, 0, _card(BLUE_EYES),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_true(face_down.is_face_down(), "a face-down copy of your own")
	t.eq(face_down.card_name(), BLUE_EYES, "which really carries the name")
	t.eq(engine.state.player(0).monsters().size(), 2, "and really is in a Monster Zone")
	t.is_false(_offered(engine, spell), "still does not satisfy it — cid 5979 says face-up")
	# The same claim by an independent route: the clause's own condition, asked directly,
	# rather than only the action list that consults it among a dozen other gates.
	var wipe := _clause(DESTROY_ID)
	t.not_null(wipe, "the destruction clause is reachable")
	if wipe != null:
		var ctx := ActivationRules.make_context(engine.state, spell, wipe, 0, null)
		t.is_false(bool(wipe.condition.call(ctx)),
			"the condition itself answers NO for a face-down Blue-Eyes")

	engine.state.set_battle_position(face_down, Enums.Position.FACE_UP_ATTACK, true)
	if wipe != null:
		var ctx2 := ActivationRules.make_context(engine.state, spell, wipe, 0, null)
		t.is_true(bool(wipe.condition.call(ctx2)),
			"and YES for the very same monster once it is face-up")
	t.is_true(_offered(engine, spell),
		"flipping that very monster face-up is what turns the card on")

	# The supplement's Spell & Trap Zone case is unreachable in V1: nothing in the pool puts
	# a monster face-up in a Spell & Trap Zone. Asserted rather than branched on.
	var lib: Dictionary = CardRegistry.load_library()["cards"]
	var bewd: CardDef = lib.get(BLUE_EYES, null)
	t.not_null(bewd, "Blue-Eyes White Dragon is in the library")
	if bewd != null:
		t.eq(bewd.category, Enums.Category.MONSTER,
			"it is a Monster Card, so it can never occupy a Spell & Trap Zone")


static func _test_the_condition_is_not_rechecked_at_resolution(t: TestCase) -> void:
	t.start("Burst Stream: the condition is before the colon, so losing the Blue-Eyes in "
		+ "response does not stop the wipe")
	var d := _board(4304)
	var engine: DuelEngine = d["engine"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var theirs: Array = d["theirs"]
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", blue_eyes, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["spell"].id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.not_null(response, "a response window is open")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "Chain Link 2 removes the Blue-Eyes")
	TestFixtures.pass_until_open(engine)

	# The prerequisite for the claim.
	t.eq(blue_eyes.zone, Enums.Zone.GRAVEYARD, "the Blue-Eyes left before resolution")
	t.eq(engine.state.player(0).face_up_monsters().size(), 0,
		"so no Blue-Eyes was controlled at resolution")
	# …and the wipe happened anyway.
	for entry in theirs:
		var card: CardInstance = entry
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 1,
			"%s was destroyed anyway" % card.card_name())


# ---------------------------------------------------------------------------
# The lingering attack ban
# ---------------------------------------------------------------------------

static func _test_the_attack_ban_applies_for_the_rest_of_the_turn(t: TestCase) -> void:
	t.start("Burst Stream: after it is activated, `Blue-Eyes White Dragon` cannot attack "
		+ "this turn — and your other monsters still can")
	var d := _board(4305)
	var engine: DuelEngine = d["engine"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Other", 4, 1900, 1000))

	t.is_false(engine.state.player(0).attacks_banned_by_name(BLUE_EYES,
		engine.state.turn_number), "no ban exists before the activation")
	t.is_true(TestFixtures.activate_card(engine, 0, d["spell"]), "activated and resolved")
	# The claimed route: the ban really was recorded, on the right player and turn.
	t.is_true(engine.state.player(0).attacks_banned_by_name(BLUE_EYES,
		engine.state.turn_number), "the ban was recorded for this player and this turn")
	t.is_false(engine.state.player(1).attacks_banned_by_name(BLUE_EYES,
		engine.state.turn_number), "and NOT for the opponent")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_false(_can_attack(engine, blue_eyes), "the Blue-Eyes may not declare an attack")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, blue_eyes.id), "and is offered no declaration")
	t.is_true(_can_attack(engine, other), "your other monster may still attack")
	# It is PREVENTION, so nothing was spent.
	t.is_false(TestFixtures.attack(engine, blue_eyes, null), "the attack is refused")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 0,
		"no ATTACK_DECLARED event was emitted")
	t.is_false(blue_eyes.has_attacked_this_turn, "and it keeps its attack for the turn")


static func _test_the_ban_covers_a_blue_eyes_summoned_afterwards(t: TestCase) -> void:
	t.start("Burst Stream: a `Blue-Eyes White Dragon` that reaches the field AFTER the "
		+ "activation is banned too — cid 5979 says ALL copies")
	var d := _board(4306)
	var engine: DuelEngine = d["engine"]
	t.is_true(TestFixtures.activate_card(engine, 0, d["spell"]), "activated and resolved")

	var latecomer := TestFixtures.give_monster_on_field(engine, 0, _card(BLUE_EYES))
	engine.continuous.recompute()
	t.eq(latecomer.card_name(), BLUE_EYES, "a second copy arrives afterwards")
	t.ne(latecomer.id, (d["blue_eyes"] as CardInstance).id, "and it is a different instance")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_false(_can_attack(engine, latecomer),
		"it may not attack either — the ban is by NAME, not by instance")


static func _test_the_ban_expires_with_the_turn(t: TestCase) -> void:
	t.start("Burst Stream: the ban lasts exactly the turn it was acquired")
	var d := _board(4307)
	var engine: DuelEngine = d["engine"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var banned_turn := engine.state.turn_number
	t.is_true(TestFixtures.activate_card(engine, 0, d["spell"]), "activated and resolved")
	t.is_true(engine.state.player(0).attacks_banned_by_name(BLUE_EYES, banned_turn),
		"the ban applies this turn")

	t.is_true(TestFixtures.end_turn(engine), "player 1 takes a turn")
	t.is_true(TestFixtures.end_turn(engine), "and it comes back to player 0")
	t.ne(engine.state.turn_number, banned_turn, "a different turn number")
	t.is_false(engine.state.player(0).attacks_banned_by_name(BLUE_EYES,
		engine.state.turn_number), "the ban no longer applies")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(_can_attack(engine, blue_eyes), "and the Blue-Eyes may attack again")


# ---------------------------------------------------------------------------
# The activation restriction the printed English does not mention
# ---------------------------------------------------------------------------

static func _test_it_cannot_be_activated_after_a_blue_eyes_has_attacked(t: TestCase) -> void:
	t.start("Burst Stream: R41 Part C — it cannot be activated on a turn in which a "
		+ "`Blue-Eyes White Dragon` has already attacked")
	var d := _board(4308)
	var engine: DuelEngine = d["engine"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var spell: CardInstance = d["spell"]

	t.is_true(_offered(engine, spell), "before any attack it is offered")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, blue_eyes, d["theirs"][0]),
		"the Blue-Eyes attacks")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 1,
		"the attack really was declared")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"Main Phase 2 is reached, where a Normal Spell is legal again")

	t.is_false(_offered(engine, spell),
		"and the activation is now refused for the rest of the turn")
	var lingering := _clause(ActivationRules.ACTIVATION_CONDITION_EFFECT_ID)
	if lingering != null:
		var ctx := ActivationRules.make_context(engine.state, spell, lingering, 0, null)
		t.is_false(bool(lingering.condition.call(ctx)),
			"the lingering clause's own condition is what refuses it")
	var wipe := _clause(DESTROY_ID)
	if wipe != null:
		var ctx2 := ActivationRules.make_context(engine.state, spell, wipe, 0, null)
		t.is_true(bool(wipe.condition.call(ctx2)),
			"while the DESTRUCTION clause's own condition is still satisfied — so the "
			+ "refusal really comes from the lingering sentence")


static func _test_that_restriction_survives_the_attacker_leaving_the_field(t: TestCase) -> void:
	t.start("Burst Stream: the restriction still applies when the Blue-Eyes that attacked "
		+ "has since left the field — the instance flag would have forgotten")
	var d := _board(4309)
	var engine: DuelEngine = d["engine"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var spell: CardInstance = d["spell"]

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, blue_eyes, d["theirs"][0]),
		"the Blue-Eyes attacks and battles")
	t.is_true(engine.state.destroy(blue_eyes, Enums.MoveReason.DESTROYED_BY_EFFECT, -1),
		"then it is destroyed")
	t.is_false(blue_eyes.has_attacked_this_turn,
		"`on_leave_field()` cleared its instance flag — the trap being avoided")

	# A fresh copy restores the destruction clause's own condition, so the only thing that
	# can refuse the activation now is the attack history.
	var fresh := TestFixtures.give_monster_on_field(engine, 0, _card(BLUE_EYES))
	engine.continuous.recompute()
	t.eq(fresh.card_name(), BLUE_EYES, "a fresh Blue-Eyes is on the field")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"Main Phase 2 is reached")
	t.is_false(_offered(engine, spell),
		"and the activation is still refused, from the event log rather than the flag")


static func _test_another_monster_attacking_does_not_block_the_activation(t: TestCase) -> void:
	t.start("Burst Stream: only a `Blue-Eyes White Dragon` attacking blocks it — another "
		+ "monster's attack does not")
	var d := _board(4310)
	var engine: DuelEngine = d["engine"]
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Other", 4, 1900, 1000))

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, other, d["theirs"][0]),
		"a monster that is NOT a Blue-Eyes attacks")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 1,
		"the attack really was declared")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"Main Phase 2 is reached")
	t.is_true(_offered(engine, d["spell"]), "and the activation is still legal")


# ---------------------------------------------------------------------------
# Negation — the two kinds behave DIFFERENTLY here, which is the point
# ---------------------------------------------------------------------------

static func _test_effect_negation_stops_the_wipe_but_NOT_the_ban(t: TestCase) -> void:
	t.start("Burst Stream: a negated EFFECT destroys nothing, but the attack ban applies "
		+ "anyway — 'regardless of whether the effect was actually carried out'")
	var d := _board(4311)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Effect Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["spell"].id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the negator can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# The negation really happened.
	t.eq(negator.zone, Enums.Zone.GRAVEYARD, "the negator resolved")
	for entry in theirs:
		var card: CardInstance = entry
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 0,
			"%s was NOT destroyed" % card.card_name())
	t.eq(engine.state.player(1).monsters().size(), 2, "their monsters are all still there")
	# …and the ban applied anyway.
	t.is_true(engine.state.player(0).attacks_banned_by_name(BLUE_EYES,
		engine.state.turn_number), "the attack ban was applied anyway")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_false(_can_attack(engine, blue_eyes),
		"and the Blue-Eyes still may not attack this turn")


static func _test_activation_negation_stops_both(t: TestCase) -> void:
	t.start("Burst Stream: a negated ACTIVATION destroys nothing AND leaves no ban — "
		+ "cid 5979 says the Blue-Eyes goes back to being able to attack")
	var d := _board(4312)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	var blue_eyes: CardInstance = d["blue_eyes"]
	var spell: CardInstance = d["spell"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Activation Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the Counter Trap can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	# The route: the Spell itself was destroyed by the negation.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, spell.id), 1,
		"the negated Spell itself was destroyed")
	for entry in theirs:
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
			(entry as CardInstance).id), 0, "their monster was NOT destroyed")
	# …and NO ban was ever recorded.
	t.is_false(engine.state.player(0).attacks_banned_by_name(BLUE_EYES,
		engine.state.turn_number), "no attack ban was recorded")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(_can_attack(engine, blue_eyes), "and the Blue-Eyes may attack normally")


# ---------------------------------------------------------------------------
# The real pool, and determinism
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Burst Stream: deck 1 really holds a `Blue-Eyes White Dragon` and real ways to "
		+ "Summon another one mid-turn, which is what makes the ALL-copies ban matter")
	var lib: Dictionary = CardRegistry.load_library()["cards"]
	t.is_true(lib.has(BLUE_EYES), "Blue-Eyes White Dragon is implemented")
	t.is_true(lib.has("Kaibaman"),
		"Kaibaman is in the pool and Special Summons a Blue-Eyes from the hand")
	t.is_true(lib.has("Silver's Cry"),
		"Silver's Cry is in the pool and Special Summons a Dragon Normal Monster from the GY")

	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the card database is readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary and parsed.has("cards")):
		t.check(false, "the card database parses")
		return
	var decks: Array = []
	var bewd_decks: Array = []
	for entry in parsed["cards"]:
		var name := str(entry.get("name", ""))
		if name == CARD_UNDER_TEST:
			decks = entry.get("decks", [])
		elif name == BLUE_EYES:
			bewd_decks = entry.get("decks", [])
	t.is_true(decks.has("Blue-Eyes Dragon Guard"), "the Spell is in deck 1")
	t.is_true(bewd_decks.has("Blue-Eyes Dragon Guard"),
		"and so is the monster its condition names")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("Burst Stream: the same seed and the same actions produce the same result")
	var results: Array = []
	for _i in range(2):
		var d := _board(4313)
		var engine: DuelEngine = d["engine"]
		TestFixtures.activate_card(engine, 0, d["spell"])
		TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
		results.append({
			"their_monsters": engine.state.player(1).monsters().size(),
			"banned": engine.state.player(0).attacks_banned_by_name(BLUE_EYES,
				engine.state.turn_number),
			"can_attack": engine.battle.can_declare_attack(d["blue_eyes"], 0),
			"destroyed": TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["their_monsters"], 0, "the wipe really happened in both runs")
	t.is_true(bool(results[0]["banned"]), "and the ban really applied")
	t.is_false(bool(results[0]["can_attack"]), "and really prevented the attack")
	t.eq(results[1]["their_monsters"], results[0]["their_monsters"], "monster counts match")
	t.eq(results[1]["banned"], results[0]["banned"], "the ban reproduces")
	t.eq(results[1]["can_attack"], results[0]["can_attack"], "the prevention reproduces")
	t.eq(results[1]["destroyed"], results[0]["destroyed"], "the destruction counts match")
	t.eq(results[1]["events"], results[0]["events"], "and the whole event stream matches")

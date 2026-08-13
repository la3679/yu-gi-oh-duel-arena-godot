class_name CastleOfDragonSoulsTests
extends RefCounted

## Per-card suite for `Castle of Dragon Souls` — a CONTINUOUS TRAP, not an Equip Card.
##
##   "Once per turn: You can banish 1 Dragon monster from your GY, then target 1 monster
##    you control; it gains 700 ATK until the end of this turn (even if this card leaves
##    the field). When this face-up card on the field is sent to the GY: You can target 1
##    of your banished Dragon monsters; Special Summon that target. You can only control 1
##    'Castle of Dragon Souls'."
##
## Research/CARD_RULINGS.md R19.
##
## The three things this card needs that nothing in the library had before it:
##   * a BANISH used as a COST, distinct from banishing as an effect;
##   * an ATK gain that outlives its own source leaving the field;
##   * a "You can only control 1" on a Spell/Trap, which no route enforced.

const CARD_UNDER_TEST := "Castle of Dragon Souls"

const BOOST_ID := "banish_dragon_for_700_atk"
const RECOVER_ID := "special_summon_banished_dragon"


static func run() -> TestCase:
	var t := TestCase.new("CastleOfDragonSoulsTests")
	_test_clause_shape(t)
	_test_the_banish_is_a_cost(t)
	_test_the_cost_survives_negation(t)
	_test_the_cost_filter(t)
	_test_the_boost_survives_this_card_leaving_the_field(t)
	_test_the_boost_expires_at_the_end_of_the_turn(t)
	_test_once_per_turn(t)
	_test_the_target_filter(t)
	_test_sent_to_gy_recovers_a_banished_dragon(t)
	_test_banished_rather_than_sent_to_the_gy(t)
	_test_never_face_up_on_the_field(t)
	_test_declining_the_recovery(t)
	_test_the_control_limit(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A face-up Castle on the field, one Dragon in the Graveyard to pay with, and one monster
## on the field to boost.
static func _armed_board(seed_value: int) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var castle := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, castle)
	d["castle"] = castle
	d["dragon"] = TestFixtures.give(engine, 0, _card("Luster Dragon"), Enums.Zone.GRAVEYARD)
	d["monster"] = TestFixtures.give_monster_on_field(engine, 0, _card("Sabersaurus"))
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("four EffectDefs: the Trap's own activation plus the three printed clauses")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.CONTINUOUS_TRAP,
		"it is a CONTINUOUS TRAP — not an Equip Card, and it equips nothing")
	t.eq(def.effects.size(), 4, "activation + boost + recovery + control limit")

	var activation: EffectDef = def.effects[0]
	t.eq(activation.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"the Trap's own activation")
	t.eq(activation.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2")
	t.is_false(activation.targets, "the activation itself does not target")

	var boost: EffectDef = def.effects[1]
	t.eq(boost.effect_type, Enums.EffectType.IGNITION,
		"no '(Quick Effect)' and no 'During either player's turn': an Ignition Effect")
	t.eq(boost.spell_speed, Enums.SpellSpeed.SS1, "so Spell Speed 1")
	t.is_false(ActivationRules.is_fast_effect(boost),
		"and therefore never usable in a response window [S1 p.44]")
	t.eq(boost.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"its controller's own Main Phases")
	t.is_true(boost.once_per_turn_instance, "'Once per turn' on this copy")
	t.is_true(boost.targets, "'then TARGET 1 monster you control'")
	t.eq(boost.target_count_min, 1, "exactly one")
	t.is_true(boost.pay_cost.is_valid(), "the banish is a real COST, paid at activation")
	t.eq(boost.ruling_ref, "R19", "traced to the recorded ruling")

	var recover: EffectDef = def.effects[2]
	t.eq(recover.effect_type, Enums.EffectType.TRIGGER, "the second printed clause triggers")
	t.eq(recover.optionality, Enums.Optionality.OPTIONAL, "'You can target' — optional")
	t.eq(recover.trigger_events, [GameEvent.Kind.CARD_SENT_TO_GY],
		"keyed on being SENT TO THE GY, which a banish is not [S1 p.53]")
	t.eq(recover.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"by then the card is in the Graveyard, so that is where it activates from")
	t.eq(recover.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"this card can reach the Graveyard during the Damage Step [S1 p.41]")

	var limit: EffectDef = def.effects[3]
	t.eq(limit.effect_id, SummonRules.CONTROL_LIMIT_EFFECT_ID,
		"the control limit is found by effect id, never by reading card text")
	t.eq(limit.effect_type, Enums.EffectType.CONTINUOUS, "it is a continuous rules query")
	t.is_false(limit.starts_chain, "which never starts a Chain")
	t.is_false(limit.apply_continuous.is_valid(),
		"and applies nothing to the board — it only answers a question")


# ---------------------------------------------------------------------------
# The cost
# ---------------------------------------------------------------------------

static func _test_the_banish_is_a_cost(t: TestCase) -> void:
	t.start("the Dragon is BANISHED — not sent to the Graveyard — and the target gains "
		+ "700 ATK")
	var d := _armed_board(9101)
	var engine: DuelEngine = d["engine"]
	var castle: CardInstance = d["castle"]
	var dragon: CardInstance = d["dragon"]
	var monster: CardInstance = d["monster"]

	t.eq(castle.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Continuous Trap stays face-up on the field [S1 p.29-30]")
	t.eq(monster.current_atk(), 1900, "Sabersaurus starts at its printed 1900")

	var before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED)
	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"the effect is activated, targeting the monster")

	t.eq(dragon.zone, Enums.Zone.BANISHED, "the Dragon left the Graveyard for banishment")
	t.eq(dragon.last_move_reason, Enums.MoveReason.BANISHED, "with the BANISHED reason")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED), before + 1,
		"exactly one CARD_BANISHED event")
	t.is_false(Enums.is_sent_to_gy(Enums.MoveReason.BANISHED),
		"and banishing is NOT 'sent to the Graveyard' [S1 p.53]")

	t.eq(monster.current_atk(), 1900 + 700, "the target gained 700 ATK")
	t.eq(monster.original_atk(), 1900,
		"while its ORIGINAL ATK is untouched — a modifier, never a rewrite [S1 p.55]")
	t.eq(monster.definition.base_atk, 1900, "and the printed value even more so")


static func _test_the_cost_survives_negation(t: TestCase) -> void:
	t.start("the banish is paid at ACTIVATION, so it stays paid when the effect is negated")
	var d := _armed_board(9102)
	var engine: DuelEngine = d["engine"]
	var castle: CardInstance = d["castle"]
	var dragon: CardInstance = d["dragon"]
	var monster: CardInstance = d["monster"]

	# A Spell Speed 2 answer that removes the target before the boost resolves. The engine
	# resolves a whole Chain inside one submit_action() when nobody holds a response, so a
	# real fast effect is the only way to interfere between activation and resolution.
	var remover := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Banisher", monster, "banish"), 0)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [monster.id]})),
		"player 0 activates it")
	t.eq(dragon.zone, Enums.Zone.BANISHED,
		"the cost is ALREADY paid, before any response window opened")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "player 1 may respond with a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response),
		"and chains a card that banishes the target as Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(monster.zone, Enums.Zone.BANISHED, "the target left the field")
	t.eq(dragon.zone, Enums.Zone.BANISHED,
		"and the cost is not refunded — a cost is never given back")
	t.eq(monster.current_atk(), 1900,
		"the boost did not apply to a target that is no longer on the field")


static func _test_the_cost_filter(t: TestCase) -> void:
	t.start("'1 DRAGON monster from YOUR GY' — both halves, with a Wyrm as the near miss")
	var d := _main_phase_duel(9103)
	var engine: DuelEngine = d["engine"]
	var castle := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, castle)
	TestFixtures.give_monster_on_field(engine, 0, _card("Sabersaurus"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID),
		"an empty Graveyard cannot pay the cost")

	# A Level 7 "…Armed Dragon" that is a WYRM, not a Dragon.
	TestFixtures.give(engine, 0, _card("Metaphys Armed Dragon"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID),
		"a WYRM named '… Dragon' is not a Dragon monster")

	TestFixtures.give(engine, 1, _card("Blue-Eyes White Dragon"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID),
		"and a Dragon in the OPPONENT's Graveyard is out of reach")

	var mine := TestFixtures.give(engine, 0, _card("Luster Dragon"), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID),
		"a Dragon in your own Graveyard enables it — the positive control")
	t.eq(mine.zone, Enums.Zone.GRAVEYARD, "and it has not been paid yet, only counted")


# ---------------------------------------------------------------------------
# "even if this card leaves the field"
# ---------------------------------------------------------------------------

static func _test_the_boost_survives_this_card_leaving_the_field(t: TestCase) -> void:
	t.start("'(even if this card leaves the field)' — destroying Castle does NOT take the "
		+ "700 ATK with it")
	var d := _armed_board(9104)
	var engine: DuelEngine = d["engine"]
	var castle: CardInstance = d["castle"]
	var monster: CardInstance = d["monster"]

	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"the boost resolves")
	t.eq(monster.current_atk(), 2600, "the monster is at 1900 + 700")

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", castle, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Castle of Dragon Souls")

	t.eq(castle.zone, Enums.Zone.GRAVEYARD, "Castle left the field")
	t.eq(monster.current_atk(), 2600,
		"and the boost is STILL there — this is the parenthesis, and a continuous "
		+ "modifier would have vanished here")
	t.eq(monster.atk_modifiers.size(), 1, "exactly one modifier, not a duplicated one")
	t.eq(str(monster.atk_modifiers[0].get("until", "")), "end_of_turn",
		"carried by the turn-scoped duration rather than the continuous one")


static func _test_the_boost_expires_at_the_end_of_the_turn(t: TestCase) -> void:
	t.start("'until the end of this turn' — and it really does end there")
	var d := _armed_board(9105)
	var engine: DuelEngine = d["engine"]
	var castle: CardInstance = d["castle"]
	var monster: CardInstance = d["monster"]

	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"the boost resolves")
	t.eq(monster.current_atk(), 2600, "boosted")

	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	t.eq(monster.current_atk(), 1900, "the monster is back to its printed ATK")
	t.eq(monster.atk_modifiers.size(), 0, "with no stale modifier left behind")
	t.eq(castle.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"while Castle itself is untouched by the expiry")


static func _test_once_per_turn(t: TestCase) -> void:
	t.start("'Once per turn' is per COPY, and the use returns next turn")
	var d := _armed_board(9106)
	var engine: DuelEngine = d["engine"]
	var castle: CardInstance = d["castle"]
	var monster: CardInstance = d["monster"]
	# A second Dragon, so a second use would otherwise be payable.
	TestFixtures.give(engine, 0, _card("Alexandrite Dragon"), Enums.Zone.GRAVEYARD)

	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"the first use resolves")
	t.eq(monster.current_atk(), 2600, "+700")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID),
		"a second use in the same turn is not offered, even with a Dragon left to pay with")

	t.is_true(TestFixtures.end_turn(engine), "the opponent takes their turn")
	t.is_true(TestFixtures.end_turn(engine), "and play comes back")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"reaching Main Phase 1")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID),
		"the use has returned")


static func _test_the_target_filter(t: TestCase) -> void:
	t.start("'1 monster YOU CONTROL' — including a face-down one, excluding theirs")
	var d := _armed_board(9107)
	var engine: DuelEngine = d["engine"]
	var castle: CardInstance = d["castle"]
	var mine: CardInstance = d["monster"]

	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		_card("Luster Dragon"), Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _card("Sabersaurus"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, castle.id, BOOST_ID)
	t.not_null(action, "the effect is offered")
	t.is_true(action.target_candidates.has(mine.id), "your face-up monster is a target")
	t.is_true(action.target_candidates.has(face_down.id),
		"so is your FACE-DOWN one — the clause has no face-up qualifier")
	t.is_false(action.target_candidates.has(theirs.id),
		"but a monster the opponent controls is not")
	t.eq(action.target_candidates.size(), 2, "exactly the two monsters you control")

	# A hand-built action naming an illegal target is refused outright.
	t.is_false(engine.submit_action(action.with_choices({"target_ids": [theirs.id]})),
		"and a forged activation targeting theirs is rejected")


# ---------------------------------------------------------------------------
# The Graveyard clause
# ---------------------------------------------------------------------------

static func _test_sent_to_gy_recovers_a_banished_dragon(t: TestCase) -> void:
	t.start("'When this face-up card on the field is sent to the GY' — Special Summon a "
		+ "banished Dragon, including the very one this card banished")
	var d := _armed_board(9108)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var castle: CardInstance = d["castle"]
	var dragon: CardInstance = d["dragon"]
	var monster: CardInstance = d["monster"]
	controller.default_yes = true

	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"the boost banishes Luster Dragon as its cost")
	t.eq(dragon.zone, Enums.Zone.BANISHED, "the Dragon is banished")

	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", castle, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a card effect destroys Castle, sending it to the Graveyard")

	t.eq(castle.zone, Enums.Zone.GRAVEYARD, "Castle is in the Graveyard")
	t.eq(dragon.zone, Enums.Zone.MONSTER_ZONE,
		"and the Dragon it banished came back to the field")
	t.is_true(dragon.properly_special_summoned, "properly Special Summoned")
	t.eq(dragon.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.is_true(dragon.is_face_up(), "face-up — a Special Summon is face-up unless stated")
	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_POSITION), 1,
		"the card names no position, so the summoning player was asked exactly once")


static func _test_banished_rather_than_sent_to_the_gy(t: TestCase) -> void:
	t.start("a Castle that is BANISHED from the field never reaches the Graveyard, so the "
		+ "clause does not fire [S1 p.53]")
	var d := _armed_board(9109)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var castle: CardInstance = d["castle"]
	var monster: CardInstance = d["monster"]
	controller.default_yes = true

	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"a Dragon is banished as the cost, so a legal target exists")
	var asked_before := controller.request_count(Enums.DecisionKind.CHOOSE_POSITION)

	var banisher := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Banisher", castle, "banish"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, banisher), "a card effect banishes Castle")

	t.eq(castle.zone, Enums.Zone.BANISHED, "Castle is banished, not in the Graveyard")
	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_POSITION), asked_before,
		"nothing was Summoned and nobody was asked anything")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no Special Summon happened in the whole duel")


static func _test_never_face_up_on_the_field(t: TestCase) -> void:
	t.start("'this FACE-UP card ON THE FIELD' — a copy discarded from the hand does not "
		+ "fire the clause")
	var d := _main_phase_duel(9110)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	controller.default_yes = true

	var in_hand := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.give(engine, 0, _card("Luster Dragon"), Enums.Zone.BANISHED)

	# Straight from the hand to the Graveyard, through the timing machine so a trigger
	# would genuinely be collected if one were eligible.
	# NOT "destroy": `GameState.destroy()` correctly refuses a card that is not on the
	# field, so a card in the hand has to be SENT to the Graveyard instead.
	var sender := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Sender", in_hand, "send_to_gy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, sender),
		"the copy in hand is sent to the Graveyard")

	t.eq(in_hand.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.is_false(in_hand.last_move_was_face_up,
		"but it was never face-up on the field on the way there")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"so nothing was Special Summoned")
	t.eq(controller.request_count(Enums.DecisionKind.CHOOSE_POSITION), 0,
		"and the controller was never asked")

	# Positive control on the same board shape: a copy that WAS face-up on the field does
	# fire, so the negative above is about the location and not about the setup.
	var on_field := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, on_field)
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", on_field, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover),
		"a face-up copy on the field is destroyed instead")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"and that one DOES recover the banished Dragon")


static func _test_declining_the_recovery(t: TestCase) -> void:
	t.start("'You can target' — the controller is asked, and answering no Summons nothing")
	var d := _armed_board(9111)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var castle: CardInstance = d["castle"]
	var monster: CardInstance = d["monster"]
	var dragon: CardInstance = d["dragon"]
	controller.default_yes = false

	t.is_true(TestFixtures.activate_effect(engine, 0, castle, BOOST_ID, [monster.id]),
		"the cost banishes the Dragon")

	var asked_before := controller.request_count(Enums.DecisionKind.YES_NO)
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", castle, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover), "Castle is destroyed")

	t.is_true(controller.request_count(Enums.DecisionKind.YES_NO) > asked_before,
		"the controller was asked whether to use the optional trigger")
	t.eq(dragon.zone, Enums.Zone.BANISHED, "they said no, so the Dragon stays banished")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"nothing was Special Summoned")


# ---------------------------------------------------------------------------
# "You can only control 1"
# ---------------------------------------------------------------------------

static func _test_the_control_limit(t: TestCase) -> void:
	t.start("'You can only control 1' on a TRAP — the route no rule enforced until now")
	var d := _main_phase_duel(9112)
	var engine: DuelEngine = d["engine"]

	var first := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var second := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id),
		"while both are still Set, the second copy is activatable")
	t.is_true(TestFixtures.activate_card(engine, 0, first), "the first copy is activated")
	t.is_true(first.is_face_up(), "it is face-up on the field")

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id)
	t.is_null(offered, "the second copy is no longer offered")
	var forged := DuelAction.make(Enums.ActionKind.ACTIVATE_CARD, 0, second.id,
		"activate_castle_of_dragon_souls")
	t.is_false(engine.submit_action(forged), "and a hand-built activation is rejected")
	t.is_true(second.is_face_down(), "the second copy never turned face-up")

	# A copy the OPPONENT controls does not restrict you: the limit is per player.
	var theirs := TestFixtures.give_set_spell_trap(engine, 1, _def(), 0)
	t.is_true(SummonRules.control_limit_satisfied(engine.state, theirs, 1),
		"a copy YOU control does not restrict the opponent — the limit is per player")
	t.is_false(SummonRules.control_limit_satisfied(engine.state, second, 0),
		"while your own face-up copy does restrict you")

	# And once yours leaves the field the restriction lifts.
	var remover := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Test Remover", first, "destroy"), 0)
	t.is_true(TestFixtures.activate_card(engine, 0, remover), "the first copy is destroyed")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id),
		"the second copy becomes activatable again")

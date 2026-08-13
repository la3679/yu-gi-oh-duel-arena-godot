class_name AWingbeatOfGiantDragonTests
extends RefCounted

## `A Wingbeat of Giant Dragon` — "Return 1 Level 5 or higher Dragon-Type monster you
## control to the hand, and if you do, destroy all Spell and Trap Cards on the field."
##
## The card is a single clause with two halves joined by "and if you do", so the suite is
## organised around the join: the return, the destruction, and the cases where the first
## half does not happen and the second half must therefore not happen either.
##
## Rulings exercised here (CARD_RULINGS.md R27, R28): the return is the EFFECT and not a
## cost, the card does not target, and it does not destroy itself.

const CARD_UNDER_TEST := "A Wingbeat of Giant Dragon"


static func run() -> TestCase:
	var t := TestCase.new("AWingbeatOfGiantDragonTests")
	_test_the_clause_shape(t)
	_test_it_returns_a_dragon_and_wipes_the_backrow(t)
	_test_it_destroys_both_players_spell_traps_including_set_and_field(t)
	_test_it_does_not_destroy_itself(t)
	_test_it_cannot_be_activated_without_a_high_level_dragon(t)
	_test_a_low_level_or_non_dragon_is_not_a_candidate(t)
	_test_a_face_down_monster_is_not_a_candidate(t)
	_test_the_dragon_is_chosen_at_resolution_not_at_activation(t)
	_test_the_return_is_not_a_cost(t)
	_test_no_return_means_no_destruction(t)
	_test_the_return_is_not_a_destruction(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card_def(t: TestCase) -> CardDef:
	var lib := CardRegistry.new().load_library()
	t.eq(lib["errors"], [], "the card library loads with no errors")
	var cards: Dictionary = lib["cards"]
	t.is_true(cards.has(CARD_UNDER_TEST), "the registry knows the card")
	return cards[CARD_UNDER_TEST]


static func _dragon(name: String, level: int = 6) -> CardDef:
	var def := TestFixtures.monster(name, level, 2000, 1500, "LIGHT")
	def.race = "Dragon"
	return def


## Main Phase 1 with the card in player 0's hand.
static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["wingbeat"] = TestFixtures.give_to_hand(engine, 0, _card_def(t))
	return d


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal Spell card activation that does NOT target and has no "
		+ "cost (CARD_RULINGS.md R27)")
	var def := _card_def(t)
	t.eq(def.effects.size(), 1, "exactly one EffectDef for the card's one clause")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS1, "a Normal Spell is Spell Speed 1")
	t.is_false(clause.targets,
		"it does NOT target: the word 'target' does not appear in the official text")
	t.is_false(clause.pay_cost.is_valid(),
		"and it has no cost: the return happens at resolution, not at activation")
	t.is_true(clause.condition.is_valid(),
		"it does have an activation condition, for the Dragon it must be able to return")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Spell is activated from the hand or from a Set copy")
	t.is_true(clause.clause_text.contains("and if you do"),
		"the clause quotes the conditional join from the official text")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_it_returns_a_dragon_and_wipes_the_backrow(t: TestCase) -> void:
	t.start("it returns a Level 5 or higher Dragon to the hand and destroys the Spell and "
		+ "Trap Cards on the field")
	var d := _board(t, 7501)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var dragon := TestFixtures.give_monster_on_field(engine, 0, _dragon("Big Dragon", 6))
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))

	t.is_true(TestFixtures.activate_card(engine, 0, wingbeat), "the Spell is activated")
	t.eq(dragon.zone, Enums.Zone.HAND, "the Dragon is back in the hand")
	t.is_true(engine.state.player(0).hand.has(dragon), "its owner's hand")
	t.eq(dragon.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"as a return to the hand")
	t.eq(their_trap.zone, Enums.Zone.GRAVEYARD, "the opponent's Set Trap is destroyed")
	t.eq(their_trap.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"by a card effect")


static func _test_it_destroys_both_players_spell_traps_including_set_and_field(
		t: TestCase) -> void:
	t.start("'all Spell and Trap Cards ON THE FIELD' is both players', face-up and "
		+ "face-down alike, and includes the Field Zone")
	var d := _board(t, 7502)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var dragon := TestFixtures.give_monster_on_field(engine, 0, _dragon("Big Dragon", 7))
	var my_set := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("My Trap"))
	var my_face_up := TestFixtures.give(engine, 0,
		TestFixtures.spell("My Continuous", Enums.STKind.CONTINUOUS_SPELL),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	var their_set := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))
	var their_field := TestFixtures.give(engine, 1,
		TestFixtures.spell("Their Field", Enums.STKind.FIELD_SPELL),
		Enums.Zone.FIELD_ZONE, Enums.Position.FACE_UP)
	# A monster must survive: the card destroys Spell and Trap Cards only.
	var their_monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Survivor", 4, 1000, 1000))

	t.is_true(TestFixtures.activate_card(engine, 0, wingbeat), "the Spell is activated")
	t.eq(dragon.zone, Enums.Zone.HAND, "the Dragon was returned")
	t.eq(my_set.zone, Enums.Zone.GRAVEYARD, "the controller's own Set card is destroyed")
	t.eq(my_face_up.zone, Enums.Zone.GRAVEYARD, "so is their own face-up Continuous Spell")
	t.eq(their_set.zone, Enums.Zone.GRAVEYARD, "the opponent's Set card is destroyed")
	t.eq(their_field.zone, Enums.Zone.GRAVEYARD,
		"and the Field Spell, which is a Spell Card on the field")
	t.eq(their_monster.zone, Enums.Zone.MONSTER_ZONE, "monsters are not touched")
	t.eq(engine.state.player(1).monsters().size(), 1, "the opponent still has a monster")


static func _test_it_does_not_destroy_itself(t: TestCase) -> void:
	t.start("the resolving card is a Spell Card on the field, and is nonetheless NOT "
		+ "destroyed by its own effect (CARD_RULINGS.md R28)")
	var d := _board(t, 7503)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	TestFixtures.give_monster_on_field(engine, 0, _dragon("Big Dragon", 8))
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Their Trap"))

	t.is_true(TestFixtures.activate_card(engine, 0, wingbeat), "the Spell is activated")
	t.eq(wingbeat.zone, Enums.Zone.GRAVEYARD, "it ends up in the Graveyard, as any "
		+ "Normal Spell does")
	t.eq(wingbeat.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"but as a RESOLVED Spell, not as a card it destroyed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		wingbeat.id), 0, "no CARD_DESTROYED was emitted for it")


# ---------------------------------------------------------------------------
# Negatives
# ---------------------------------------------------------------------------

static func _test_it_cannot_be_activated_without_a_high_level_dragon(t: TestCase) -> void:
	t.start("with no Level 5 or higher Dragon to return, no part of the effect can be "
		+ "performed, so the card cannot be activated (CARD_RULINGS.md R27)")
	var d := _board(t, 7504)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Their Trap"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id),
		"the activation is not offered with an empty field")
	t.is_false(TestFixtures.activate_card(engine, 0, wingbeat),
		"and cannot be forced through the public API")
	t.eq(wingbeat.zone, Enums.Zone.HAND, "the card is still in the hand")

	# The positive control: one legal Dragon makes it activatable.
	TestFixtures.give_monster_on_field(engine, 0, _dragon("Big Dragon", 5))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id),
		"a Level 5 Dragon on the field is enough")


static func _test_a_low_level_or_non_dragon_is_not_a_candidate(t: TestCase) -> void:
	t.start("'Level 5 or higher DRAGON-Type monster YOU CONTROL' rejects a Level 4 Dragon, "
		+ "a high-Level non-Dragon, and the opponent's Dragon")
	var d := _board(t, 7505)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var low := TestFixtures.give_monster_on_field(engine, 0, _dragon("Small Dragon", 4))
	var wrong_type := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Warrior", 7, 2400, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dragon("Their Dragon", 8))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id),
		"none of the three qualifies, so the card cannot be activated")
	t.eq(low.definition.level, 4, "the Dragon on the field is Level 4")
	t.eq(wrong_type.definition.race, "Warrior", "the Level 7 monster is not a Dragon")
	t.eq(theirs.controller_id, 1, "and the Level 8 Dragon belongs to the opponent")

	# One legal Dragon appears; now it works and returns exactly that one.
	var legal := TestFixtures.give_monster_on_field(engine, 0, _dragon("Right Dragon", 5))
	t.is_true(TestFixtures.activate_card(engine, 0, wingbeat), "now it can be activated")
	t.eq(legal.zone, Enums.Zone.HAND, "the qualifying Dragon was the one returned")
	t.eq(low.zone, Enums.Zone.MONSTER_ZONE, "the Level 4 Dragon stayed")
	t.eq(wrong_type.zone, Enums.Zone.MONSTER_ZONE, "so did the Warrior")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "and so did the opponent's Dragon")


static func _test_a_face_down_monster_is_not_a_candidate(t: TestCase) -> void:
	t.start("a face-down monster presents neither a Level nor a Type, so it is not a "
		+ "'Level 5 or higher Dragon-Type monster you control'")
	var d := _board(t, 7506)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var hidden := TestFixtures.give_monster_on_field(engine, 0, _dragon("Set Dragon", 7),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id),
		"a face-down Level 7 Dragon does not enable the card")
	t.eq(hidden.zone, Enums.Zone.MONSTER_ZONE, "it is still on the field, face-down")

	engine.state.set_battle_position(hidden, Enums.Position.FACE_UP_ATTACK, true)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id),
		"turned face-up, the very same monster qualifies")


static func _test_the_dragon_is_chosen_at_resolution_not_at_activation(
		t: TestCase) -> void:
	t.start("the card does not target, so the Dragon is chosen at RESOLUTION and the "
		+ "choice is a logged decision")
	var d := _board(t, 7507)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var first := TestFixtures.give_monster_on_field(engine, 0, _dragon("Dragon One", 5))
	var second := TestFixtures.give_monster_on_field(engine, 0, _dragon("Dragon Two", 6))
	var p0: ScriptedController = d["p0"]
	# Two candidates, so a real prompt happens; pick the SECOND, which is not the default.
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [second.id])

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id)
	t.not_null(offered, "the activation is offered")
	var candidates: Array = offered.target_candidates
	t.eq(candidates.size(), 0,
		"and publishes NO target candidates, because the card does not target")

	t.is_true(TestFixtures.activate_card(engine, 0, wingbeat), "it resolves")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(second.zone, Enums.Zone.HAND, "the Dragon the player chose was returned")
	t.eq(first.zone, Enums.Zone.MONSTER_ZONE, "the other one stayed on the field")


static func _test_the_return_is_not_a_cost(t: TestCase) -> void:
	t.start("the return is the EFFECT, not a cost: nothing is paid at activation, so the "
		+ "Dragon is still on the field while the Chain is being built")
	var d := _board(t, 7508)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var dragon := TestFixtures.give_monster_on_field(engine, 0, _dragon("Big Dragon", 6))
	# A Spell Speed 2 response gives the Chain a second link, so the board can be observed
	# between activation and resolution.
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", dragon, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is activated as Chain Link 1")
	t.eq(dragon.zone, Enums.Zone.MONSTER_ZONE,
		"the Dragon is STILL on the field: no cost was paid at activation")
	t.eq(engine.state.chain.size(), 1, "and there is one Chain Link")

	# Chain Link 2 removes the Dragon, so the effect finds nothing to return.
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.not_null(response, "a response window is open")
	t.is_true(engine.submit_action(response), "the responder is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(dragon.zone, Enums.Zone.GRAVEYARD,
		"Chain Link 2 sent the Dragon to the Graveyard before Chain Link 1 resolved")


static func _test_no_return_means_no_destruction(t: TestCase) -> void:
	t.start("'and if you do' is strictly conditional: with the Dragon gone by resolution, "
		+ "nothing is returned and NOTHING is destroyed")
	var d := _board(t, 7509)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	var dragon := TestFixtures.give_monster_on_field(engine, 0, _dragon("Big Dragon", 6))
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", dragon, "send_to_gy"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, wingbeat.id)
	t.is_true(engine.submit_action(offered), "the Spell is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.is_true(engine.submit_action(response), "the removal is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(dragon.zone, Enums.Zone.GRAVEYARD, "the Dragon was removed first")
	t.eq(their_trap.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"so the opponent's Trap SURVIVES: no return means no destruction")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		their_trap.id), 0, "and no destruction event was emitted for it")
	t.eq(wingbeat.zone, Enums.Zone.GRAVEYARD, "the Spell still resolved and left the field")


static func _test_the_return_is_not_a_destruction(t: TestCase) -> void:
	t.start("the returned Dragon is not destroyed, so a Dragon with a 'destroyed and sent "
		+ "to the GY' clause does not fire from it [S1 p.52]")
	var d := _board(t, 7510)
	var engine: DuelEngine = d["engine"]
	var wingbeat: CardInstance = d["wingbeat"]
	# `Kaiser Glider` is a Level 6 Dragon in the same Deck whose second clause would be
	# loud if a return were mistaken for a destruction.
	var lib := CardRegistry.new().load_library()
	var cards: Dictionary = lib["cards"]
	var glider := TestFixtures.give_monster_on_field(engine, 0, cards["Kaiser Glider"])
	var bystander := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Bystander", 4, 1000, 1000))

	t.is_true(TestFixtures.activate_card(engine, 0, wingbeat),
		"the Spell returns Kaiser Glider to the hand")
	t.eq(glider.zone, Enums.Zone.HAND, "the Glider is in the hand")
	t.eq(bystander.zone, Enums.Zone.MONSTER_ZONE,
		"and the opponent's monster was NOT bounced, so the Glider's clause never fired")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, glider.id), 0,
		"no destruction event was emitted for the returned Dragon")

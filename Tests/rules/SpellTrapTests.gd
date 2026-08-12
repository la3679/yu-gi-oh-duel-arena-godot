class_name SpellTrapTests
extends RefCounted

## Spell and Trap framework: Setting, the Set-turn restrictions, who may activate what
## and when, and where a card goes after it resolves.
##
## Rules under test: RULES_SPEC.md 4.2, and Official Rulebook v10 p.28-31 (S1), quoted
## in ActivationRules.gd:
##   "You cannot activate a Trap in the same turn that you Set it" [S1 p.30]
##   "Spell Cards can be activated during the Main Phases even in the same turn that you
##    Set them (except for Quick-Play Spell Cards). Setting them does not allow you to
##    use them on your opponent's turn; they still can only be activated during your
##    Main Phase." [S1 p.31]


static func run() -> TestCase:
	var t := TestCase.new("SpellTrapTests")
	_test_trap_cannot_activate_the_turn_it_was_set(t)
	_test_set_spell_can_activate_the_same_turn(t)
	_test_quick_play_cannot_activate_the_turn_it_was_set(t)
	_test_who_may_respond_on_the_opponents_turn(t)
	_test_normal_spell_goes_to_the_graveyard_after_resolving(t)
	_test_continuous_spell_stays_on_the_field(t)
	_test_field_spell_replaces_the_previous_one(t)
	return t


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _activatable_card(name: String, kind: Enums.STKind, speed: int,
		order: Array, tag: String) -> CardDef:
	var def := TestFixtures.trap(name, kind) if Enums.is_trap(kind) \
		else TestFixtures.spell(name, kind)
	TestFixtures.with_effect(def,
		TestFixtures.card_activation("activate", speed, order, tag))
	return def


# --- [S1 p.30] ---
static func _test_trap_cannot_activate_the_turn_it_was_set(t: TestCase) -> void:
	t.start("a Trap cannot be activated the turn it was Set")
	var d := _main_phase_duel(301)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var def := _activatable_card("Slow Trap", Enums.STKind.NORMAL_TRAP,
		Enums.SpellSpeed.SS2, order, "trap")
	var card := TestFixtures.give_to_hand(engine, 0, def)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.SET_SPELL_TRAP, card.id))
	TestFixtures.pass_until_open(engine)
	t.eq(card.zone, Enums.Zone.SPELL_TRAP_ZONE, "the Trap was Set")
	t.eq(card.position, Enums.Position.FACE_DOWN, "face-down")
	t.eq(card.turn_set, engine.state.turn_number, "the Set turn was recorded")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id),
		"it cannot be activated on the turn it was Set [S1 p.30]")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id),
		"it becomes activatable from the next turn onward [S1 p.30]")


# --- [S1 p.31] ---
static func _test_set_spell_can_activate_the_same_turn(t: TestCase) -> void:
	t.start("a Set Spell that is not a Quick-Play can be activated the same turn")
	var d := _main_phase_duel(302)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var def := _activatable_card("Ordinary Spell", Enums.STKind.NORMAL_SPELL,
		Enums.SpellSpeed.SS1, order, "spell")
	var card := TestFixtures.give_to_hand(engine, 0, def)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.SET_SPELL_TRAP, card.id))
	TestFixtures.pass_until_open(engine)

	var act = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	t.not_null(act, "a Set Normal Spell may be activated the same turn [S1 p.31]")
	engine.submit_action(act)
	TestFixtures.pass_until_open(engine)
	t.eq(order, ["spell"], "it resolved")


static func _test_quick_play_cannot_activate_the_turn_it_was_set(t: TestCase) -> void:
	t.start("a Quick-Play Spell cannot be activated the turn it was Set")
	var d := _main_phase_duel(303)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var def := _activatable_card("Quick One", Enums.STKind.QUICK_PLAY_SPELL,
		Enums.SpellSpeed.SS2, order, "quick")
	var card := TestFixtures.give_to_hand(engine, 0, def)

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id),
		"a Quick-Play Spell can be activated from the hand on your own turn")

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.SET_SPELL_TRAP, card.id))
	TestFixtures.pass_until_open(engine)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id),
		"once Set it cannot be activated that same turn — the Quick-Play exception "
		+ "[S1 p.31]")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id),
		"and becomes activatable on a later turn")


# --- [S1 p.31, p.44] ---
static func _test_who_may_respond_on_the_opponents_turn(t: TestCase) -> void:
	t.start("only fast effects are available on the opponent's turn")
	var d := _main_phase_duel(304)
	var engine: DuelEngine = d["engine"]
	var order: Array = []

	# Player 1 has both a Set Quick-Play Spell and a Set Normal Spell from an earlier turn.
	var quick_def := _activatable_card("Their Quick-Play", Enums.STKind.QUICK_PLAY_SPELL,
		Enums.SpellSpeed.SS2, order, "quick")
	var slow_def := _activatable_card("Their Normal Spell", Enums.STKind.NORMAL_SPELL,
		Enums.SpellSpeed.SS1, order, "slow")
	var quick := TestFixtures.give_set_spell_trap(engine, 1, quick_def, 0)
	var slow := TestFixtures.give_set_spell_trap(engine, 1, slow_def, 0)

	# Player 0 does something that opens a window.
	var mon := TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Body"))
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.NORMAL_SUMMON, mon.id))

	t.eq(engine.waiting_player(), 1, "player 1 gets a response window")
	var responses := engine.get_legal_responses(1)
	t.is_true(TestFixtures.has_action(responses, Enums.ActionKind.ACTIVATE_CARD,
		quick.id), "a Set Quick-Play Spell may be activated on the opponent's turn")
	t.is_false(TestFixtures.has_action(responses, Enums.ActionKind.ACTIVATE_CARD,
		slow.id), "a Set Normal Spell may only be activated during its owner's Main "
		+ "Phase [S1 p.31]")

	TestFixtures.pass_until_open(engine)
	t.eq(engine.get_legal_actions(1).size(), 0,
		"the non-turn player has no open-game-state actions at all")


# --- [S1 p.28-30] ---
static func _test_normal_spell_goes_to_the_graveyard_after_resolving(t: TestCase) -> void:
	t.start("a Normal Spell is sent to the Graveyard after it resolves")
	var d := _main_phase_duel(305)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var def := _activatable_card("One Shot", Enums.STKind.NORMAL_SPELL,
		Enums.SpellSpeed.SS1, order, "one_shot")
	var card := TestFixtures.give_to_hand(engine, 0, def)

	var mark := engine.state.events.size()
	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, card.id))
	# Neither player holds a fast effect, so the engine correctly auto-passes both
	# response windows and the whole Chain resolves inside this one submit_action().
	# The intermediate placement is therefore asserted from the event log, not from
	# the live card, which has already moved on.
	var placed := -1
	var link_added := -1
	for i in range(mark, engine.state.events.size()):
		var e: GameEvent = engine.state.events[i]
		if placed == -1 and e.kind == GameEvent.Kind.CARD_MOVED \
				and int(e.data.get("card_id", -1)) == card.id \
				and e.data.get("to_zone") == Enums.Zone.SPELL_TRAP_ZONE:
			placed = i
		if link_added == -1 and e.kind == GameEvent.Kind.CHAIN_LINK_ADDED \
				and int(e.data.get("card_id", -1)) == card.id:
			link_added = i
	t.is_true(placed != -1,
		"activating from the hand places the card in a Spell & Trap Zone")
	t.is_true(placed != -1 and link_added != -1 and placed < link_added,
		"the card is placed before it becomes a Chain Link [S1 p.28]")

	t.eq(order, ["one_shot"], "the Spell resolved")
	t.eq(card.zone, Enums.Zone.GRAVEYARD,
		"a Normal Spell goes to the Graveyard afterwards [S1 p.28]")
	t.eq(engine.timing, DuelEngine.Timing.OPEN,
		"and the engine is back in an open game state")


static func _test_continuous_spell_stays_on_the_field(t: TestCase) -> void:
	t.start("a Continuous Spell remains on the field after resolving")
	var d := _main_phase_duel(306)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var def := _activatable_card("Standing Order", Enums.STKind.CONTINUOUS_SPELL,
		Enums.SpellSpeed.SS1, order, "continuous")
	var card := TestFixtures.give_to_hand(engine, 0, def)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, card.id))
	TestFixtures.pass_until_open(engine)

	t.eq(order, ["continuous"], "the activation resolved")
	t.eq(card.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"a Continuous Spell stays on the field [S1 p.28]")
	t.is_true(card.is_face_up(), "face-up, so its continuous effect can apply")


static func _test_field_spell_replaces_the_previous_one(t: TestCase) -> void:
	t.start("activating a Field Spell replaces the one already there")
	var d := _main_phase_duel(307)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var first_def := _activatable_card("Old Field", Enums.STKind.FIELD_SPELL,
		Enums.SpellSpeed.SS1, order, "old")
	var second_def := _activatable_card("New Field", Enums.STKind.FIELD_SPELL,
		Enums.SpellSpeed.SS1, order, "new")
	var first := TestFixtures.give_to_hand(engine, 0, first_def)
	var second := TestFixtures.give_to_hand(engine, 0, second_def)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, first.id))
	TestFixtures.pass_until_open(engine)
	t.eq(first.zone, Enums.Zone.FIELD_ZONE, "the first Field Spell occupies the Field Zone")
	t.eq(engine.state.player(0).field_zone, first, "and is the player's Field Spell")

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, second.id))
	TestFixtures.pass_until_open(engine)
	t.eq(second.zone, Enums.Zone.FIELD_ZONE, "the second Field Spell took the zone")
	t.eq(first.zone, Enums.Zone.GRAVEYARD,
		"the previous Field Spell went to the Graveyard [S1 p.29]")
	t.eq(order, ["old", "new"], "both activations resolved in order")

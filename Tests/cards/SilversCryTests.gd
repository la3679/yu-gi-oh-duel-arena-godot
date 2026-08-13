class_name SilversCryTests
extends RefCounted

## Per-card suite for `Silver's Cry` — "Target 1 Dragon Normal Monster in your GY;
## Special Summon that target. You can only activate 1 'Silver's Cry' per turn."
##
## Three things separate this card from `Monster Reborn` and each is tested on its own:
## it is a Quick-Play Spell (Spell Speed 2, with the Set-turn and whose-turn rules that
## come with that), its targets are restricted BOTH by race and by being Normal Monsters,
## and it carries a hard once-per-turn on the card NAME.

const CARD_UNDER_TEST := "Silver's Cry"

const EFFECT_ID := "revive_dragon_normal_monster"


static func run() -> TestCase:
	var t := TestCase.new("SilversCryTests")
	_test_clause_shape(t)
	_test_revives_a_dragon_normal_monster(t)
	_test_target_filter_is_race_and_normal_monster(t)
	_test_only_your_own_graveyard(t)
	_test_hard_once_per_turn(t)
	_test_cannot_be_activated_the_turn_it_was_set(t)
	_test_a_set_copy_works_on_the_opponents_turn(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _cry_def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _into_graveyard(engine: DuelEngine, pid: int, def: CardDef) -> CardInstance:
	return TestFixtures.give(engine, pid, def, Enums.Zone.GRAVEYARD)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("the clause is a Spell Speed 2 card activation, targeting, with a hard "
		+ "once-per-turn on the name")
	var def := _cry_def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.QUICK_PLAY_SPELL,
		"the card database says Quick-Play Spell")
	t.eq(def.effects.size(), 1, "one EffectDef per official clause, and this card has one")
	var effect: EffectDef = def.effects[0]

	t.eq(effect.effect_type, Enums.EffectType.CARD_ACTIVATION, "activating the card is it")
	t.eq(effect.spell_speed, Enums.SpellSpeed.SS2,
		"a Quick-Play Spell is Spell Speed 2 [S1 p.44]")
	t.is_true(ActivationRules.is_fast_effect(effect),
		"so it is usable in a Fast Effect window")
	t.is_true(effect.targets, "the official text says 'Target'")
	t.eq(effect.target_count_min, 1, "exactly one target")
	t.is_true(effect.once_per_turn_named_activation,
		"'You can only activate 1 \"Silver's Cry\" per turn' is a hard OPT on the name")
	t.is_false(effect.once_per_turn_instance,
		"it is not a per-copy restriction — a second copy is blocked too")
	t.is_true(effect.clause_text.contains("only activate 1"),
		"the once-per-turn sentence is part of the quoted official text")


# ---------------------------------------------------------------------------
# Positively
# ---------------------------------------------------------------------------

static func _test_revives_a_dragon_normal_monster(t: TestCase) -> void:
	t.start("a Dragon Normal Monster in your Graveyard is Special Summoned")
	var d := _main_phase_duel(9301)
	var engine: DuelEngine = d["engine"]

	var cry := TestFixtures.give_to_hand(engine, 0, _cry_def())
	var dragon := _into_graveyard(engine, 0, _card("Blue-Eyes White Dragon"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id)
	t.not_null(action, "Silver's Cry is offered from the hand on your own turn")
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [dragon.id]})),
		"and is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(dragon.zone, Enums.Zone.MONSTER_ZONE, "the Dragon left the Graveyard")
	t.eq(dragon.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.eq(dragon.current_atk(), 3000, "with its printed ATK intact")
	t.eq(cry.zone, Enums.Zone.GRAVEYARD,
		"a Quick-Play Spell does not stay on the field after resolving [S1 p.29]")


# ---------------------------------------------------------------------------
# Negatively — the target filter
# ---------------------------------------------------------------------------

static func _test_target_filter_is_race_and_normal_monster(t: TestCase) -> void:
	t.start("'Dragon Normal Monster' is both conditions: race Dragon AND a Normal Monster")
	var d := _main_phase_duel(9302)
	var engine: DuelEngine = d["engine"]

	var cry := TestFixtures.give_to_hand(engine, 0, _cry_def())
	var dragon_normal := _into_graveyard(engine, 0, _card("Luster Dragon"))
	var dragon_effect := _into_graveyard(engine, 0, _card("Mirage Dragon"))
	var wyrm_normal := _into_graveyard(engine, 0, _card("Metaphys Armed Dragon"))
	var other_normal := _into_graveyard(engine, 0, _card("Sabersaurus"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id)
	t.not_null(action, "Silver's Cry is offered")
	t.is_true(action.target_candidates.has(dragon_normal.id),
		"Luster Dragon — Dragon and Normal — is a legal target")
	t.is_false(action.target_candidates.has(dragon_effect.id),
		"Mirage Dragon is a Dragon but an EFFECT Monster, so it is not")
	t.is_false(action.target_candidates.has(wyrm_normal.id),
		"Metaphys Armed Dragon is a Normal Monster but a WYRM, so it is not")
	t.is_false(action.target_candidates.has(other_normal.id),
		"Sabersaurus is a Normal Monster but a Dinosaur, so it is not")
	t.eq(action.target_candidates.size(), 1, "exactly one legal target was offered")

	t.is_false(engine.submit_action(action.with_choices({"target_ids": [wyrm_normal.id]})),
		"and a hand-built activation targeting the Wyrm is rejected")


static func _test_only_your_own_graveyard(t: TestCase) -> void:
	t.start("'in your GY' does not reach the opponent's Graveyard")
	var d := _main_phase_duel(9303)
	var engine: DuelEngine = d["engine"]

	var cry := TestFixtures.give_to_hand(engine, 0, _cry_def())
	var theirs := _into_graveyard(engine, 1, _card("Blue-Eyes White Dragon"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id),
		"with a legal-looking Dragon only in the OPPONENT's Graveyard it is not offered")

	var mine := _into_graveyard(engine, 0, _card("Rabidragon"))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id)
	t.not_null(action, "adding one to your own Graveyard makes it activatable")
	t.is_true(action.target_candidates.has(mine.id), "your own copy is a candidate")
	t.is_false(action.target_candidates.has(theirs.id),
		"and the opponent's copy still is not")


static func _test_hard_once_per_turn(t: TestCase) -> void:
	t.start("'You can only activate 1 per turn' blocks a SECOND COPY, and lifts next turn")
	var d := _main_phase_duel(9304)
	var engine: DuelEngine = d["engine"]

	var first := TestFixtures.give_to_hand(engine, 0, _cry_def())
	var second := TestFixtures.give_to_hand(engine, 0, _cry_def())
	_into_graveyard(engine, 0, _card("Luster Dragon"))
	var spare := _into_graveyard(engine, 0, _card("Alexandrite Dragon"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, first.id)
	t.not_null(action, "the first copy is offered")
	t.is_true(engine.submit_action(
		action.with_choices({"target_ids": [action.target_candidates[0]]})),
		"and resolves")
	TestFixtures.pass_until_open(engine)

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id),
		"the second copy is not offered in the same turn, even with a legal target left")
	t.is_true(engine.state.player(0).was_named_activation_used(CARD_UNDER_TEST,
		engine.state.turn_number),
		"the restriction is recorded against the card NAME for this player")

	# Two turns later it is this player's turn again and the restriction has expired.
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn again")
	t.eq(spare.zone, Enums.Zone.GRAVEYARD, "and a legal target is still waiting")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id),
		"so the second copy is activatable again — the restriction is per turn")


# ---------------------------------------------------------------------------
# Negatively — the Quick-Play timing rules
# ---------------------------------------------------------------------------

static func _test_cannot_be_activated_the_turn_it_was_set(t: TestCase) -> void:
	t.start("a Quick-Play Spell cannot be activated in the turn it was Set [S1 p.31]")
	var d := _main_phase_duel(9305)
	var engine: DuelEngine = d["engine"]

	var cry := TestFixtures.give_to_hand(engine, 0, _cry_def())
	_into_graveyard(engine, 0, _card("Luster Dragon"))

	var set_action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.SET_SPELL_TRAP, cry.id)
	t.not_null(set_action, "it can be Set")
	t.is_true(engine.submit_action(set_action), "and is Set")
	TestFixtures.pass_until_open(engine)

	t.eq(cry.zone, Enums.Zone.SPELL_TRAP_ZONE, "it is face-down in a Spell & Trap Zone")
	t.eq(cry.turn_set, engine.state.turn_number, "Set this turn")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id),
		"so it is not activatable this turn — the Quick-Play exception to the Spell rule")


static func _test_a_set_copy_works_on_the_opponents_turn(t: TestCase) -> void:
	t.start("a Set copy from an earlier turn may be activated during the OPPONENT's turn")
	var d := TestFixtures.new_duel(9306, 1)
	var engine: DuelEngine = d["engine"]

	var cry := TestFixtures.give_set_spell_trap(engine, 0, _cry_def(), 0)
	_into_graveyard(engine, 0, _card("Blue-Eyes White Dragon"))
	t.eq(engine.state.turn_player_id, 1, "it is the opponent's turn")

	# Player 0 is not the turn player, so this is a response window, not an open action.
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var summoned := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Provoker", 4, 1000, 1000))
	var summon = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.NORMAL_SUMMON, summoned.id)
	t.not_null(summon, "the opponent Normal Summons, which opens a response window")
	t.is_true(engine.submit_action(summon), "the Summon is declared")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, cry.id)
	t.not_null(response,
		"the Set Quick-Play is offered to its controller during the opponent's turn")
	t.is_true(engine.submit_action(
		response.with_choices({"target_ids": [response.target_candidates[0]]})),
		"and is activated as a fast effect")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(0).monster_count(), 1,
		"the Dragon was Special Summoned on the opponent's turn")
	t.eq(engine.state.player(0).monsters()[0].card_name(), "Blue-Eyes White Dragon",
		"and it is the targeted monster")

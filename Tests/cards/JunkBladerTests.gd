class_name JunkBladerTests
extends RefCounted

## `Junk Blader` — EARTH / Warrior / Level 4 / 1800 ATK / 1000 DEF.
##
## Official text (verified, `Data/cards/cards.json`, cid 8735):
##
##   "You can banish 1 "Junk" monster from your Graveyard; this card gains 400 ATK until the
##    end of this turn."
##
## One clause, and the interesting parts are all boundaries: the banish is a COST rather than
## part of the effect, no once-per-turn is printed so none may be enforced, the gain is ATK
## only and expires at the end of the turn, and the cost is **never live in the V1 pool** —
## `Junk Blader` is the only "Junk" card in either deck and there is one copy, so the only
## card that could pay the cost is the very card that has to be face-up on the field to
## activate. Positive cases therefore use a SYNTHETIC second "Junk" monster, with a real-pool
## assertion at the end so the fact cannot rot silently (the R21/R23 treatment).


const CARD_UNDER_TEST := "Junk Blader"

const EFFECT_ID := "banish_junk_gain_atk"
const BASE_ATK := 1800
const BASE_DEF := 1000
const GAIN := 400


static func run() -> TestCase:
	var t := TestCase.new("JunkBladerTests")
	_test_the_card_declares_one_clause_with_no_once_per_turn(t)
	_test_it_is_not_offered_without_a_junk_monster_in_the_graveyard(t)
	_test_a_junk_monster_in_the_OPPONENTS_graveyard_does_not_qualify(t)
	_test_a_non_junk_monster_does_not_qualify(t)
	_test_the_banish_is_a_cost_and_the_atk_gain_resolves(t)
	_test_the_cost_banishes_rather_than_sending_to_the_graveyard(t)
	_test_def_is_untouched(t)
	_test_the_gain_stacks_because_no_once_per_turn_is_printed(t)
	_test_the_gain_expires_at_the_end_of_the_turn(t)
	_test_the_gain_is_used_in_damage_calculation(t)
	_test_a_negated_effect_grants_no_atk_but_keeps_the_cost_paid(t)
	_test_it_is_not_offered_while_face_down(t)
	_test_it_is_not_legal_in_the_damage_step(t)
	_test_the_cost_is_never_live_in_the_real_pool(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## A synthetic member of the archetype — nothing printed in either deck can be one.
static func _junk_monster(suffix: String = "Synchron") -> CardDef:
	return TestFixtures.monster("Junk %s" % suffix, 3, 1300, 500, "EARTH")


## Junk Blader face-up on player 0's field, with `fodder_count` "Junk" monsters in their GY.
static func _board(seed_value: int, fodder_count: int = 1) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["blader"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	var fodder: Array = []
	for i in range(fodder_count):
		fodder.append(TestFixtures.give(engine, 0, _junk_monster("Fodder %d" % i),
			Enums.Zone.GRAVEYARD))
	d["fodder"] = fodder
	return d


static func _atk_of(engine: DuelEngine, card: CardInstance) -> int:
	ContinuousEffects.new(engine.state).recompute()
	return card.current_atk()


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_one_clause_with_no_once_per_turn(t: TestCase) -> void:
	t.start("one EffectDef, an Ignition Effect from the field face-up, and NO once-per-turn "
		+ "of any kind — the card prints none")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	t.eq(card_def.effects.size(), 1, "exactly one official clause")
	t.eq(card_def.base_atk, BASE_ATK, "1800 ATK")
	t.eq(card_def.base_def, BASE_DEF, "1000 DEF")

	var effect: EffectDef = card_def.effects[0]
	t.eq(effect.effect_id, EFFECT_ID, "the clause is the ATK gain")
	t.eq(effect.effect_type, Enums.EffectType.IGNITION, "an Ignition Effect")
	t.is_true(effect.activation_locations.has(Enums.ActivationLocation.FIELD_FACE_UP),
		"activated from the field face-up")
	t.is_false(effect.targets, "it does not target — 'this card' is not a target")
	t.is_false(effect.once_per_turn_instance, "no once-per-turn on the instance")
	t.is_false(effect.once_per_turn_named_effect, "none on the name either")
	t.is_false(effect.once_per_turn_named_activation, "and none on the activation")
	t.eq(effect.uses_per_turn, 0, "and no bounded number of uses")
	t.is_true(effect.pay_cost.is_valid(), "the banish is wired as a COST")


# ---------------------------------------------------------------------------
# The cost, and what does not pay it
# ---------------------------------------------------------------------------

static func _test_it_is_not_offered_without_a_junk_monster_in_the_graveyard(
		t: TestCase) -> void:
	t.start("with an empty Graveyard the effect is not offered, and it becomes available "
		+ "the moment a 'Junk' monster is there")
	var d := _board(9901, 0)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"no cost can be paid, so it is not offered")

	TestFixtures.give(engine, 0, _junk_monster(), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"with one in the Graveyard it is offered")


static func _test_a_junk_monster_in_the_OPPONENTS_graveyard_does_not_qualify(
		t: TestCase) -> void:
	t.start("'from YOUR Graveyard' — a 'Junk' monster in the opponent's Graveyard cannot "
		+ "pay the cost")
	var d := _board(9902, 0)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	var theirs := TestFixtures.give(engine, 1, _junk_monster("Warrior"),
		Enums.Zone.GRAVEYARD)
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD, "it really is in their Graveyard")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"it is not offered — the cost reads the controller's Graveyard only")
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD, "and their card was not touched")


static func _test_a_non_junk_monster_does_not_qualify(t: TestCase) -> void:
	t.start("a monster in your Graveyard that is not a 'Junk' monster does not pay the "
		+ "cost, and neither does a 'Junk'-named Spell or Trap")
	var d := _board(9903, 0)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	TestFixtures.give(engine, 0, TestFixtures.monster("Plain Warrior"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"a non-'Junk' monster does not qualify")

	# "Junk" MONSTER: a Trap that happens to carry the name is not a monster.
	TestFixtures.give(engine, 0, TestFixtures.trap("Junk Barrage"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"and a 'Junk' Trap is not a 'Junk' MONSTER")

	TestFixtures.give(engine, 0, _junk_monster(), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"a real 'Junk' monster does qualify")


static func _test_the_banish_is_a_cost_and_the_atk_gain_resolves(t: TestCase) -> void:
	t.start("the cost banishes the chosen 'Junk' monster and this card gains exactly 400 ATK")
	var d := _board(9904)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	var fodder: CardInstance = (d["fodder"] as Array)[0]
	t.eq(_atk_of(engine, blader), BASE_ATK, "it starts at its printed ATK")

	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID),
		"the effect is activated")

	t.eq(fodder.zone, Enums.Zone.BANISHED, "the cost was banished")
	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN, "and this card gained 400 ATK")


static func _test_the_cost_banishes_rather_than_sending_to_the_graveyard(
		t: TestCase) -> void:
	t.start("the cost is a BANISH, not a send to the Graveyard — the distinction the batch-4 "
		+ "and batch-8 primitives exist to keep [S1 p.53]")
	var d := _board(9905)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	var fodder: CardInstance = (d["fodder"] as Array)[0]
	var destroyed_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED)
	var to_gy_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)

	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID), "activated")

	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_BANISHED, fodder.id), 1,
		"exactly one CARD_BANISHED for the cost")
	t.eq(fodder.last_move_reason, Enums.MoveReason.BANISHED, "recorded as a banishment")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), destroyed_before,
		"no destruction — banishing is not destroying")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY), to_gy_before,
		"and no send-to-GY either")
	t.eq(fodder.zone, Enums.Zone.BANISHED, "it is in the Banished zone")


static func _test_def_is_untouched(t: TestCase) -> void:
	t.start("the text says ATK, so DEF does not move")
	var d := _board(9906)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	ContinuousEffects.new(engine.state).recompute()
	var def_before: int = blader.current_def()

	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID), "activated")

	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN, "ATK rose")
	ContinuousEffects.new(engine.state).recompute()
	t.eq(blader.current_def(), def_before, "DEF did not")
	t.eq(blader.current_def(), BASE_DEF, "and is still the printed 1000")


static func _test_the_gain_stacks_because_no_once_per_turn_is_printed(t: TestCase) -> void:
	t.start("no once-per-turn is printed, so the effect may be used again in the same turn "
		+ "and the ATK gains stack")
	var d := _board(9907, 3)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	var fodder: Array = d["fodder"]

	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID), "first use")
	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN, "+400")
	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID), "second use")
	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN * 2, "+800")
	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID), "third use")
	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN * 3, "+1200")

	var banished := 0
	for entry in fodder:
		var card: CardInstance = entry
		if card.zone == Enums.Zone.BANISHED:
			banished += 1
	t.eq(banished, 3, "each use paid its own cost — three cards were banished")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"and with the Graveyard emptied it stops being offered — the limit is the COST, "
		+ "not a printed restriction")


static func _test_the_gain_expires_at_the_end_of_the_turn(t: TestCase) -> void:
	t.start("'until the end of THIS turn' — the ATK returns to 1800 once the turn ends, and "
		+ "the banished cost does not come back")
	var d := _board(9908)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	var fodder: CardInstance = (d["fodder"] as Array)[0]

	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID), "activated")
	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN, "the gain applied")

	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	t.eq(_atk_of(engine, blader), BASE_ATK,
		"and the ATK is back to its printed value on the opponent's turn")
	t.eq(fodder.zone, Enums.Zone.BANISHED,
		"the cost stays paid — a cost is not undone by the modifier expiring")


static func _test_the_gain_is_used_in_damage_calculation(t: TestCase) -> void:
	t.start("the ATK gain is real: it decides a battle this card would otherwise lose")
	var d := TestFixtures.battle_duel(9909)
	var engine: DuelEngine = d["engine"]
	var blader := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give(engine, 0, _junk_monster(), Enums.Zone.GRAVEYARD)
	# 2000 ATK beats 1800 and loses to 2200.
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wall", 4, 2000, 1000))

	t.is_true(TestFixtures.activate_effect(engine, 0, blader, EFFECT_ID),
		"the effect is used in Main Phase 1")
	t.eq(_atk_of(engine, blader), BASE_ATK + GAIN, "2200 ATK")

	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	t.is_true(TestFixtures.attack(engine, blader, defender), "it attacks the 2000 ATK wall")
	t.eq(defender.zone, Enums.Zone.GRAVEYARD, "the defender was destroyed by battle")
	t.eq(blader.zone, Enums.Zone.MONSTER_ZONE, "and this card survived")
	t.eq(engine.state.player(1).life_points, 8000 - 200,
		"200 battle damage — 2200 against 2000, so the gain really was counted")


static func _test_a_negated_effect_grants_no_atk_but_keeps_the_cost_paid(
		t: TestCase) -> void:
	t.start("a negated EFFECT grants no ATK, and the banished cost is NOT refunded")
	var d := _board(9910)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	var fodder: CardInstance = (d["fodder"] as Array)[0]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Silencer"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered), "it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	t.is_true(engine.submit_action(response), "the effect negator is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the effect really was negated — this is not a fallback path")
	t.eq(_atk_of(engine, blader), BASE_ATK, "no ATK was gained")
	t.eq(fodder.zone, Enums.Zone.BANISHED, "but the cost stays paid")


static func _test_it_is_not_offered_while_face_down(t: TestCase) -> void:
	t.start("'from the field face-up' — a Set Junk Blader may not activate it")
	var d := _board(9911)
	var engine: DuelEngine = d["engine"]
	var blader: CardInstance = d["blader"]
	engine.state.set_battle_position(blader, Enums.Position.FACE_DOWN_DEFENSE, true)
	t.is_true(blader.is_face_down(), "it is face-down")

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"the effect is not offered while face-down")

	engine.state.set_battle_position(blader, Enums.Position.FACE_UP_ATTACK, true)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, blader.id, EFFECT_ID),
		"and is offered again once it is face-up")


static func _test_it_is_not_legal_in_the_damage_step(t: TestCase) -> void:
	t.start("an Ignition Effect carries no Damage Step permission [RULES_SPEC.md 7.2]")
	var d := _board(9912)
	var engine: DuelEngine = d["engine"]
	var effect: EffectDef = _def().effects[0]
	t.eq(effect.damage_step_permission, Enums.DamageStepPermission.NONE,
		"no Damage Step permission is declared")

	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_false(ActivationRules.damage_step_ok(engine.state, effect),
		"and the rules layer refuses it inside the Damage Step")
	engine.state.battle_step = Enums.BattleStep.NONE
	t.is_true(ActivationRules.damage_step_ok(engine.state, effect),
		"while outside it the same question says yes")


static func _test_the_cost_is_never_live_in_the_real_pool(t: TestCase) -> void:
	t.start("Junk Blader is the only 'Junk' card in either deck and there is one copy, so "
		+ "the cost can never be paid in a real duel — asserted so it cannot rot silently")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")

	var members: Array = []
	for card_name in cards.keys():
		if str(card_name).contains("Junk"):
			members.append(str(card_name))
	t.eq(members.size(), 1, "exactly one 'Junk' card exists: %s" % str(members))
	t.eq(str(members[0]), CARD_UNDER_TEST, "and it is Junk Blader itself")
	# `CardDef` deliberately does not carry the copy count — it is a property of the DECKS,
	# not of the card — so this reads the verified card database directly.
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the verified card database is readable")
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	t.check(parsed is Dictionary, "and parses")
	var copies := -1
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if str(row.get("name", "")) == CARD_UNDER_TEST:
				copies = int(row.get("copies_total", -1))
	t.eq(copies, 1,
		"there is a single copy, so no second one can be in the Graveyard while this one "
		+ "is face-up on the field paying the cost")

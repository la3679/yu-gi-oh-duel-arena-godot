class_name KaiserGliderTests
extends RefCounted

## `Kaiser Glider` — LIGHT / Dragon / Level 6 / 2400 / 2200.
##
##   "Cannot be destroyed by battle with a monster that has the same ATK. If this card is
##    destroyed and sent to the GY: Target 1 monster on the field; return that target to
##    the hand."
##
## Two clauses that are answered at two different moments, so the suite is in two halves:
## the continuous prevention at damage calculation, and the Graveyard trigger afterwards.

const CARD_UNDER_TEST := "Kaiser Glider"


static func run() -> TestCase:
	var t := TestCase.new("KaiserGliderTests")
	_test_the_clause_shape(t)
	# Clause 1 — the conditional battle protection
	_test_equal_atk_does_not_destroy_it(t)
	_test_higher_atk_destroys_it(t)
	_test_lower_atk_leaves_it_alone_anyway(t)
	_test_the_protection_is_battle_only(t)
	_test_the_protection_covers_defense_position(t)
	# Clause 2 — the Graveyard trigger
	_test_destroyed_by_effect_bounces_a_monster(t)
	_test_destroyed_by_battle_bounces_a_monster(t)
	_test_a_tribute_or_a_bounce_does_not_fire_it(t)
	_test_it_cannot_fire_with_no_monster_on_the_field(t)
	_test_the_target_may_be_its_own_destroyer_or_its_controllers(t)
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


static func _main_phase(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A Battle Phase on turn 2 with player 0 as the turn player, `Kaiser Glider` face-up in
## Attack Position on player 0's field and one opposing monster of `their_atk` ATK.
static func _battle(t: TestCase, seed_value: int, their_atk: int) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["glider"] = TestFixtures.give_monster_on_field(engine, 0, _card_def(t),
		Enums.Position.FACE_UP_ATTACK)
	d["foe"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Rival", 6, their_atk, 1000), Enums.Position.FACE_UP_ATTACK)
	return d


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("two clauses: a continuous destruction PREVENTION and a Graveyard trigger")
	var def := _card_def(t)
	t.eq(def.effects.size(), 2, "exactly two EffectDefs, one per official clause")
	t.eq(def.level, 6, "Level 6")
	t.eq(def.base_atk, 2400, "2400 ATK")
	t.eq(def.attribute, "LIGHT", "LIGHT")
	t.eq(def.race, "Dragon", "Dragon")

	var protect: EffectDef = def.effects[0]
	t.eq(protect.effect_id, GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"the prevention is found by effect id, never by reading card text (dd 20)")
	t.eq(protect.effect_type, Enums.EffectType.CONTINUOUS, "it is CONTINUOUS")
	t.is_false(protect.starts_chain, "and a continuous clause starts no Chain")
	t.is_true(protect.condition.is_valid(), "it answers the rules query with a condition")
	t.eq(protect.uses_per_turn, 0, "it is uncounted, unlike Gagagashield's twice per turn")
	t.is_true(CardRegistry.RULES_QUERY_EFFECT_IDS.has(protect.effect_id),
		"and the id is one the registry recognises as a rules query")

	var bounce: EffectDef = def.effects[1]
	t.eq(bounce.effect_type, Enums.EffectType.TRIGGER, "the second clause is a Trigger")
	t.eq(bounce.optionality, Enums.Optionality.MANDATORY,
		"there is no 'You can', so it is MANDATORY")
	t.eq(bounce.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"it activates from the Graveyard, where the destruction just put it")
	t.eq(bounce.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"destroyed by battle, its window is inside the Damage Step [S1 p.41]")
	t.is_true(bounce.targets, "it TARGETS")
	t.eq(bounce.target_count_min, 1, "exactly one monster")


# ---------------------------------------------------------------------------
# Clause 1 — "Cannot be destroyed by battle with a monster that has the same ATK"
# ---------------------------------------------------------------------------

static func _test_equal_atk_does_not_destroy_it(t: TestCase) -> void:
	t.start("a monster with the SAME ATK does not destroy it by battle, though that "
		+ "monster is itself destroyed as normal")
	var d := _battle(t, 7401, 2400)
	var engine: DuelEngine = d["engine"]
	var glider: CardInstance = d["glider"]
	var foe: CardInstance = d["foe"]

	t.is_true(TestFixtures.attack(engine, glider, foe), "Kaiser Glider attacks")
	TestFixtures.pass_until_open(engine)
	t.eq(glider.zone, Enums.Zone.MONSTER_ZONE, "Kaiser Glider survives the battle")
	t.eq(foe.zone, Enums.Zone.GRAVEYARD,
		"the equal-ATK monster is destroyed as usual, this is one-way protection")
	t.eq(engine.state.player(0).life_points, 8000, "no damage either way at equal ATK")
	t.eq(engine.state.player(1).life_points, 8000, "for either player")


static func _test_higher_atk_destroys_it(t: TestCase) -> void:
	t.start("a monster with HIGHER ATK destroys it normally, the protection is exactly "
		+ "as narrow as its text")
	var d := _battle(t, 7402, 2500)
	var engine: DuelEngine = d["engine"]
	var glider: CardInstance = d["glider"]
	var foe: CardInstance = d["foe"]

	t.is_true(TestFixtures.attack(engine, glider, foe), "Kaiser Glider attacks into it")
	TestFixtures.pass_until_open(engine)
	t.eq(glider.zone, Enums.Zone.GRAVEYARD, "Kaiser Glider is destroyed")
	t.eq(glider.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE, "by battle")
	t.eq(engine.state.player(0).life_points, 8000 - 100, "and 100 battle damage is dealt")
	# The stronger monster survives the BATTLE, and is then the only monster left on the
	# field, so the Glider's mandatory Graveyard trigger has exactly one legal target and
	# bounces it. That is the card working, not the battle failing.
	t.eq(foe.zone, Enums.Zone.HAND,
		"it survives the battle and is then returned by the Glider's own second clause")
	t.eq(foe.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"returned to the hand, not destroyed by the battle it won")


static func _test_lower_atk_leaves_it_alone_anyway(t: TestCase) -> void:
	t.start("against LOWER ATK nothing about the protection is needed, and Kaiser Glider "
		+ "wins the battle on the numbers alone")
	var d := _battle(t, 7403, 1800)
	var engine: DuelEngine = d["engine"]
	var glider: CardInstance = d["glider"]
	var foe: CardInstance = d["foe"]

	t.is_true(TestFixtures.attack(engine, glider, foe), "Kaiser Glider attacks")
	TestFixtures.pass_until_open(engine)
	t.eq(glider.zone, Enums.Zone.MONSTER_ZONE, "it survives")
	t.eq(foe.zone, Enums.Zone.GRAVEYARD, "the weaker monster is destroyed")
	t.eq(engine.state.player(1).life_points, 8000 - 600, "600 battle damage is dealt")


static func _test_the_protection_is_battle_only(t: TestCase) -> void:
	t.start("'cannot be destroyed BY BATTLE' says nothing about a card effect, and an "
		+ "equal-ATK monster on the field does not extend it")
	var d := _main_phase(7404)
	var engine: DuelEngine = d["engine"]
	var glider := TestFixtures.give_monster_on_field(engine, 0, _card_def(t))
	# An equal-ATK monster exists, but no battle is happening.
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Twin", 6, 2400, 1000))
	t.is_false(engine.state.destruction_prevented(glider,
		Enums.MoveReason.DESTROYED_BY_EFFECT),
		"a destruction by card effect is not prevented")
	t.is_false(engine.state.destruction_prevented(glider,
		Enums.MoveReason.DESTROYED_BY_BATTLE),
		"and outside a battle there is no battling monster to compare against")

	t.is_true(engine.state.destroy(glider, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"so a card effect destroys it")
	t.eq(glider.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")


static func _test_the_protection_covers_defense_position(t: TestCase) -> void:
	t.start("the clause compares the other monster's ATK to THIS card's ATK, so it also "
		+ "saves a Kaiser Glider in Defense Position whose 2200 DEF would have lost")
	var d := TestFixtures.battle_duel(7405)
	var engine: DuelEngine = d["engine"]
	# Player 0 is the turn player and attacks; the Glider defends on player 1's field.
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Equal", 6, 2400, 1000), Enums.Position.FACE_UP_ATTACK)
	var glider := TestFixtures.give_monster_on_field(engine, 1, _card_def(t),
		Enums.Position.FACE_UP_DEFENSE)
	t.eq(glider.current_def(), 2200, "its DEF is lower than the attacker's ATK")
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, attacker, glider),
		"an equal-ATK monster attacks it in Defense Position")
	TestFixtures.pass_until_open(engine)
	t.eq(glider.zone, Enums.Zone.MONSTER_ZONE,
		"it survives: the comparison is ATK to ATK, not ATK to DEF")
	t.eq(engine.state.player(1).life_points, lp_before,
		"and a Defense-Position monster takes no battle damage without piercing")


# ---------------------------------------------------------------------------
# Clause 2 — "If this card is destroyed and sent to the GY"
# ---------------------------------------------------------------------------

static func _test_destroyed_by_effect_bounces_a_monster(t: TestCase) -> void:
	t.start("destroyed by a CARD EFFECT and sent to the GY, it targets 1 monster on the "
		+ "field and returns it to the owner's hand")
	var d := _main_phase(7407)
	var engine: DuelEngine = d["engine"]
	var glider := TestFixtures.give_monster_on_field(engine, 0, _card_def(t))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1500, 1000))
	# The destruction has to travel through the timing machine for the trigger to be
	# collected at all, so it comes from a real Spell Speed 2 card.
	var killer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Killer", glider, "destroy"))
	var p0: ScriptedController = d["p0"]
	p0.queue_for(Enums.DecisionKind.CHOOSE_TARGETS, [victim.id])

	t.is_true(TestFixtures.activate_card(engine, 0, killer),
		"the Glider is destroyed by a card effect")
	t.eq(glider.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(glider.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"destroyed by an effect")
	t.eq(victim.zone, Enums.Zone.HAND, "the targeted monster was returned to the hand")
	t.is_true(engine.state.player(1).hand.has(victim), "its owner's hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		victim.id), 1, "exactly one bounce")


static func _test_destroyed_by_battle_bounces_a_monster(t: TestCase) -> void:
	t.start("destroyed by BATTLE it fires too, from inside the Damage Step, and its "
		+ "destroyer is a legal target")
	var d := _battle(t, 7408, 2600)
	var engine: DuelEngine = d["engine"]
	var glider: CardInstance = d["glider"]
	var foe: CardInstance = d["foe"]

	t.is_true(TestFixtures.attack(engine, glider, foe),
		"Kaiser Glider attacks a stronger monster and dies")
	TestFixtures.pass_until_open(engine)
	t.eq(glider.zone, Enums.Zone.GRAVEYARD, "the Glider is in the Graveyard")
	t.eq(glider.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE, "by battle")
	# The destroyer was the only monster on the field once the Glider left, so the
	# mandatory trigger had exactly one legal target and needed no prompt.
	t.eq(foe.zone, Enums.Zone.HAND, "the monster that destroyed it was returned to hand")
	t.is_true(engine.state.player(1).hand.has(foe), "its owner's hand")


static func _test_a_tribute_or_a_bounce_does_not_fire_it(t: TestCase) -> void:
	t.start("'destroyed AND sent to the GY' is narrow: a Tribute, a bounce and a plain "
		+ "send to the Graveyard all fail it [S1 p.52-53]")
	for entry in [Enums.MoveReason.TRIBUTED, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
			Enums.MoveReason.RETURNED_TO_HAND]:
		var reason: Enums.MoveReason = entry
		var d := _main_phase(7409 + int(reason))
		var engine: DuelEngine = d["engine"]
		var glider := TestFixtures.give_monster_on_field(engine, 0, _card_def(t))
		var victim := TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Safe", 4, 1500, 1000))
		var to_zone := Enums.Zone.HAND if reason == Enums.MoveReason.RETURNED_TO_HAND \
			else Enums.Zone.GRAVEYARD
		engine.state.move_card(glider, to_zone, reason)
		TestFixtures.pass_until_open(engine)
		t.eq(victim.zone, Enums.Zone.MONSTER_ZONE,
			"the monster on the field was NOT bounced (reason %d)" % int(reason))
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
			victim.id), 0, "and no bounce event was emitted")


static func _test_it_cannot_fire_with_no_monster_on_the_field(t: TestCase) -> void:
	t.start("a MANDATORY trigger with no legal target does not activate at all, which is "
		+ "not the same as being optional")
	var d := _main_phase(7412)
	var engine: DuelEngine = d["engine"]
	var glider := TestFixtures.give_monster_on_field(engine, 0, _card_def(t))
	var killer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Killer", glider, "destroy"))

	t.is_true(TestFixtures.activate_card(engine, 0, killer), "the Glider is destroyed")
	t.eq(glider.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(engine.state.all_field_monsters().size(), 0,
		"and it was the only monster, so there is nothing to target")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND), 0,
		"nothing was returned to any hand")
	t.is_false(engine.is_duel_over(), "and the duel is unaffected")


static func _test_the_target_may_be_its_own_destroyer_or_its_controllers(
		t: TestCase) -> void:
	t.start("'1 monster on the field' is either side's, so its controller's own monster "
		+ "is a legal target and the choice is a logged decision")
	var d := _main_phase(7413)
	var engine: DuelEngine = d["engine"]
	var glider := TestFixtures.give_monster_on_field(engine, 0, _card_def(t))
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Other", 4, 1000, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their One", 4, 1000, 1000))
	var killer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Killer", glider, "destroy"))
	var p0: ScriptedController = d["p0"]
	# Two candidates, so the engine really asks; queue the player's OWN monster.
	p0.queue_for(Enums.DecisionKind.CHOOSE_TARGETS, [mine.id])

	t.is_true(TestFixtures.activate_card(engine, 0, killer), "the Glider is destroyed")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(mine.zone, Enums.Zone.HAND, "the controller's OWN monster was returned")
	t.is_true(engine.state.player(0).hand.has(mine), "to their own hand")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "the opponent's monster is untouched")

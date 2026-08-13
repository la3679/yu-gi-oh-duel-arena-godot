class_name RiderOfTheStormWindsTests
extends RefCounted

## Per-card suite for `Rider of the Storm Winds`. Research/CARD_RULINGS.md R9.
##
##   "You can target 1 Dragon Normal Monster you control; equip this monster from your
##    hand or field to that target. If a monster equipped with this card attacks a Defense
##    Position monster, inflict piercing battle damage to your opponent. If a monster
##    equipped with this card would be destroyed, destroy this card instead."
##
## This is the pool's only MONSTER that equips itself, so the assertions that matter most
## are that it really does become an Equip Card in a Spell & Trap Zone [S1 p.53], and that
## its third clause is a REPLACEMENT rather than a prevention — something is still
## destroyed.

const CARD_UNDER_TEST := "Rider of the Storm Winds"

const EQUIP_ID := "equip_self_to_a_dragon_normal_monster"


static func run() -> TestCase:
	var t := TestCase.new("RiderOfTheStormWindsTests")
	_test_clause_shape(t)
	_test_equips_itself_from_the_hand(t)
	_test_equips_itself_from_the_field(t)
	_test_the_target_filter(t)
	_test_no_free_spell_trap_zone(t)
	_test_it_grants_piercing(t)
	_test_destruction_replacement_by_card_effect(t)
	_test_destruction_replacement_in_battle(t)
	_test_the_host_leaving_the_field(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


## Main Phase 1 of player 0's SECOND turn, so player 0 may also reach a Battle Phase.
static func _second_turn_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	TestFixtures.end_turn(d["engine"])
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _equip_action(engine: DuelEngine, pid: int, rider: CardInstance):
	return TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.ACTIVATE_EFFECT, rider.id, EQUIP_ID)


## Player 0 controls `host` (a Dragon Normal Monster) with Rider equipped to it.
static func _equipped_board(seed_value: int, host_name := "Luster Dragon") -> Dictionary:
	var d := _second_turn_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 0, _card(host_name))
	var rider := TestFixtures.give_to_hand(engine, 0, _def())
	var action = _equip_action(engine, 0, rider)
	if action != null:
		engine.submit_action(action.with_choices({"target_ids": [host.id]}))
		TestFixtures.pass_until_open(engine)
	d["host"] = host
	d["rider"] = rider
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("three official clauses: an Ignition effect, a continuous grant and a "
		+ "destruction replacement")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "one EffectDef per official clause")

	var equip: EffectDef = def.effects[0]
	t.eq(equip.effect_type, Enums.EffectType.IGNITION,
		"'You can target …; equip …' is an Ignition effect")
	t.eq(equip.spell_speed, Enums.SpellSpeed.SS1,
		"an Ignition effect is Spell Speed 1 and never a fast effect [S1 p.44]")
	t.is_false(ActivationRules.is_fast_effect(equip),
		"so it is never offered in a response window")
	t.is_true(equip.targets, "'You can TARGET 1 Dragon Normal Monster you control'")
	t.eq(equip.activation_locations,
		[Enums.ActivationLocation.HAND, Enums.ActivationLocation.FIELD_FACE_UP],
		"'from your hand OR field' — both, and nowhere else")
	t.eq(equip.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"an Ignition effect is a Main Phase action [S1 p.10]")
	t.eq(equip.ruling_ref, "R9", "traced to the recorded ruling")

	var piercing: EffectDef = def.effects[1]
	t.eq(piercing.effect_type, Enums.EffectType.CONTINUOUS, "the piercing grant is continuous")
	t.is_false(piercing.starts_chain, "and starts no Chain")

	var replacement: EffectDef = def.effects[2]
	t.eq(replacement.effect_id, GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID,
		"the replacement uses the id the destruction gate looks for")
	t.is_true(replacement.destruction_substitute.is_valid(),
		"and it supplies a substitute rather than a yes/no")


# ---------------------------------------------------------------------------
# Equipping
# ---------------------------------------------------------------------------

static func _test_equips_itself_from_the_hand(t: TestCase) -> void:
	t.start("from the hand it becomes an Equip Card occupying a Spell & Trap Zone "
		+ "[S1 p.29, p.53]")
	var d := _equipped_board(7901)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var rider: CardInstance = d["rider"]

	t.eq(rider.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"'monsters equipped to other monsters' are Equip Cards and sit in a Spell & Trap "
		+ "Zone [S1 p.53]")
	t.is_true(rider.is_face_up(), "face-up")
	t.eq(rider.equipped_to_id, host.id, "equipped to the Dragon Normal Monster")
	t.eq(host.equipped_card_ids, [rider.id], "which knows about it")
	t.eq(engine.state.player(0).monster_count(), 1,
		"it does NOT occupy a Monster Zone — only the host is there")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 1,
		"exactly one CARD_EQUIPPED event")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"and it was never Summoned — equipping is not a Summon")

	t.is_false(engine.state.equip_to(rider, host),
		"'it remains equipped to that monster and cannot be moved' [S1 p.53]")


static func _test_equips_itself_from_the_field(t: TestCase) -> void:
	t.start("'from your hand OR FIELD' — a face-up copy on the field equips itself and "
		+ "vacates its Monster Zone")
	var d := _second_turn_duel(7902)
	var engine: DuelEngine = d["engine"]

	var host := TestFixtures.give_monster_on_field(engine, 0, _card("Alexandrite Dragon"))
	var rider := TestFixtures.give_monster_on_field(engine, 0, _def())
	t.eq(engine.state.player(0).monster_count(), 2, "both start in Monster Zones")

	var action = _equip_action(engine, 0, rider)
	t.not_null(action, "the effect is offered from a face-up field position")
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [host.id]})),
		"and activated")
	TestFixtures.pass_until_open(engine)

	t.eq(rider.zone, Enums.Zone.SPELL_TRAP_ZONE, "it moved to a Spell & Trap Zone")
	t.eq(rider.equipped_to_id, host.id, "equipped to the target")
	t.eq(engine.state.player(0).monster_count(), 1,
		"so its Monster Zone is free again")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), 0,
		"and nothing was destroyed on the way")


static func _test_the_target_filter(t: TestCase) -> void:
	t.start("'1 DRAGON NORMAL Monster YOU CONTROL' — both halves, your side, face-up")
	var d := _second_turn_duel(7903)
	var engine: DuelEngine = d["engine"]

	var rider := TestFixtures.give_to_hand(engine, 0, _def())
	var dragon_normal := TestFixtures.give_monster_on_field(engine, 0,
		_card("Luster Dragon"))
	var dragon_effect := TestFixtures.give_monster_on_field(engine, 0,
		_card("Mirage Dragon"))
	var normal_not_dragon := TestFixtures.give_monster_on_field(engine, 0,
		_card("Sabersaurus"))
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		_card("Alexandrite Dragon"), Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _card("Rabidragon"))

	var action = _equip_action(engine, 0, rider)
	t.not_null(action, "the effect is offered")
	t.is_true(action.target_candidates.has(dragon_normal.id),
		"a face-up Dragon Normal Monster you control is a candidate")
	t.is_false(action.target_candidates.has(dragon_effect.id),
		"a Dragon EFFECT Monster is not")
	t.is_false(action.target_candidates.has(normal_not_dragon.id),
		"a Normal Monster that is not a Dragon is not")
	t.is_false(action.target_candidates.has(face_down.id),
		"and neither is a face-down one")
	t.is_false(action.target_candidates.has(theirs.id),
		"nor one the OPPONENT controls")
	t.eq(action.target_candidates.size(), 1, "exactly one candidate")
	t.is_false(engine.submit_action(action.with_choices({"target_ids": [theirs.id]})),
		"a hand-built activation targeting the opponent's Dragon is rejected")


static func _test_no_free_spell_trap_zone(t: TestCase) -> void:
	t.start("an Equip Card needs a Spell & Trap Zone to occupy [S1 p.29]")
	var d := _second_turn_duel(7904)
	var engine: DuelEngine = d["engine"]

	var rider := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	t.not_null(_equip_action(engine, 0, rider), "offered while a zone is free")

	while engine.state.player(0).has_free_spell_trap_zone():
		TestFixtures.give(engine, 0, TestFixtures.spell("Filler %d"
			% engine.state.player(0).spell_traps().size(), Enums.STKind.CONTINUOUS_SPELL),
			Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.eq(engine.state.player(0).spell_traps().size(), 5, "all five zones are occupied")
	t.is_null(_equip_action(engine, 0, rider),
		"so the effect is no longer offered")
	t.is_false(engine.submit_action(DuelAction.make(Enums.ActionKind.ACTIVATE_EFFECT, 0,
		rider.id, EQUIP_ID)), "and a hand-built activation is rejected")
	t.eq(rider.zone, Enums.Zone.HAND, "it never left the hand")


# ---------------------------------------------------------------------------
# The granted effect
# ---------------------------------------------------------------------------

static func _test_it_grants_piercing(t: TestCase) -> void:
	t.start("'inflict piercing battle damage' to the EQUIPPED monster's opponent "
		+ "[S1 p.42, p.55]")
	var d := _equipped_board(7905)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]

	engine.continuous.recompute()
	t.is_true(bool(host.flags.get("piercing", false)),
		"the equipped monster has piercing")
	t.is_false(bool((d["rider"] as CardInstance).flags.get("piercing", false)),
		"the Equip Card itself does not — it is not the one attacking")

	var wall := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wall", 4, 0, 1000), Enums.Position.FACE_UP_DEFENSE)
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, host, wall),
		"Luster Dragon (1900 ATK) attacks a Defense Position monster")
	TestFixtures.pass_until_open(engine)

	t.eq(wall.zone, Enums.Zone.GRAVEYARD, "the defender was destroyed")
	t.eq(engine.state.player(1).life_points, 8000 - 900,
		"and 1900 - 1000 pierced through")


# ---------------------------------------------------------------------------
# The destruction replacement
# ---------------------------------------------------------------------------

static func _test_destruction_replacement_by_card_effect(t: TestCase) -> void:
	t.start("'destroy this card INSTEAD' — a replacement, not a prevention")
	var d := _equipped_board(7906)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var rider: CardInstance = d["rider"]
	var mark := engine.state.events.size()

	t.is_true(engine.state.destroy(host, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the destruction still happens — something is destroyed")
	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "but not the equipped monster")
	t.eq(rider.zone, Enums.Zone.GRAVEYARD, "Rider went instead")

	var destroyed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark)
	t.eq(destroyed.size(), 1, "exactly one card was destroyed")
	t.eq(int((destroyed[0] as GameEvent).data.get("card_id", -1)), rider.id,
		"and it was Rider")
	t.eq((destroyed[0] as GameEvent).data.get("reason", null),
		Enums.MoveReason.DESTROYED_BY_EFFECT,
		"carrying the ORIGINAL destruction's reason, not a rules destruction")
	t.eq(host.equipped_card_ids.size(), 0, "the relationship is gone")

	engine.continuous.recompute()
	t.is_false(bool(host.flags.get("piercing", false)),
		"and the piercing went with it")
	t.is_true(engine.state.destroy(host, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"with nothing left to substitute, the monster is destroyed normally")


static func _test_destruction_replacement_in_battle(t: TestCase) -> void:
	t.start("the replacement applies to BATTLE destruction too, and battle damage is "
		+ "unaffected")
	var d := _equipped_board(7907)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var rider: CardInstance = d["rider"]

	var bigger := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Bigger", 4, 2500, 1000))
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, host, bigger),
		"Luster Dragon (1900 ATK) attacks a 2500 ATK monster and loses")
	TestFixtures.pass_until_open(engine)

	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "the equipped monster survived")
	t.eq(rider.zone, Enums.Zone.GRAVEYARD, "because Rider was destroyed in its place")
	t.eq(bigger.zone, Enums.Zone.MONSTER_ZONE, "the defender is untouched")
	t.eq(engine.state.player(0).life_points, 8000 - 600,
		"and the battle damage of 2500 - 1900 was still inflicted [S1 p.42]")


static func _test_the_host_leaving_the_field(t: TestCase) -> void:
	t.start("if the host leaves the field without being destroyed, the replacement never "
		+ "applies and Rider is destroyed by the rules [S1 p.29, p.55]")
	var d := _equipped_board(7908)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var rider: CardInstance = d["rider"]
	var mark := engine.state.events.size()

	engine.state.move_card(host, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)

	t.eq(host.zone, Enums.Zone.BANISHED, "the host was banished, not destroyed")
	t.eq(rider.zone, Enums.Zone.GRAVEYARD, "Rider was destroyed all the same")
	var destroyed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark)
	t.eq(destroyed.size(), 1, "exactly one destruction")
	t.eq((destroyed[0] as GameEvent).data.get("reason", null),
		Enums.MoveReason.DESTROYED_BY_RULE,
		"by the game RULES — this is the Equip Card rule, not the replacement clause")

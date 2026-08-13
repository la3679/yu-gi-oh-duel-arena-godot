class_name GagagashieldTests
extends RefCounted

## Per-card suite for `Gagagashield`. Research/CARD_RULINGS.md R10.
##
##   "Target 1 Spellcaster monster you control; equip this card to that target. Twice per
##    turn, it cannot be destroyed by battle or card effects."
##
## The generic Equip subsystem is proved by `EquipTests`; this suite is about what is
## specific to this card: it is a NORMAL Trap that stays on the field because it equipped,
## its target filter is narrow, and its protection is COUNTED rather than unlimited.

const CARD_UNDER_TEST := "Gagagashield"


static func run() -> TestCase:
	var t := TestCase.new("GagagashieldTests")
	_test_clause_shape(t)
	_test_a_normal_trap_that_stays_on_the_field(t)
	_test_the_target_filter(t)
	_test_twice_per_turn_against_card_effects(t)
	_test_the_count_resets_next_turn(t)
	_test_protection_against_battle_destruction(t)
	_test_the_equipped_monster_leaving(t)
	_test_the_shield_leaving_ends_the_protection(t)
	_test_resolving_without_equipping(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _main_phase_duel(seed_value: int, first_player: int = 0) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, first_player)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Player 0 controls a Spellcaster with Gagagashield equipped to it.
static func _shielded_board(seed_value: int, first_player: int = 0) -> Dictionary:
	var d := _main_phase_duel(seed_value, first_player)
	var engine: DuelEngine = d["engine"]
	var caster := TestFixtures.give_monster_on_field(engine, 0, _card("Fairy Tail - Luna"))
	var shield := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	TestFixtures.activate_card(engine, 0, shield, [caster.id])
	d["caster"] = caster
	d["shield"] = shield
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("two official clauses: the equip activation and a COUNTED protection")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP,
		"it is a NORMAL Trap — 'Equipped Traps remain Trap Cards' [S1 p.53]")
	t.eq(def.effects.size(), 2, "one EffectDef per official clause")

	var equip: EffectDef = def.effects[0]
	t.eq(equip.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"activating the Trap itself is the effect")
	t.eq(equip.spell_speed, Enums.SpellSpeed.SS2, "a Trap is Spell Speed 2")
	t.is_true(equip.targets, "'Target 1 Spellcaster monster you control'")
	t.eq(equip.target_count_min, 1, "exactly one target")
	t.eq(equip.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"activated from a Set card on the field")

	var protection: EffectDef = def.effects[1]
	t.eq(protection.effect_id, GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"the protection uses the id the destruction gate looks for")
	t.eq(protection.effect_type, Enums.EffectType.CONTINUOUS,
		"it is continuous and is never activated")
	t.eq(protection.uses_per_turn, 2, "'TWICE per turn' is a real, counted limit")
	t.is_true(protection.condition.is_valid(), "and the query actually answers something")


# ---------------------------------------------------------------------------
# Equipping
# ---------------------------------------------------------------------------

static func _test_a_normal_trap_that_stays_on_the_field(t: TestCase) -> void:
	t.start("a Normal Trap normally goes to the Graveyard after resolving, but this one "
		+ "equipped, so it stays [S1 p.30, p.53]")
	var d := _shielded_board(7801)
	var engine: DuelEngine = d["engine"]
	var caster: CardInstance = d["caster"]
	var shield: CardInstance = d["shield"]

	t.eq(shield.zone, Enums.Zone.SPELL_TRAP_ZONE, "it is still in a Spell & Trap Zone")
	t.is_true(shield.is_face_up(), "face-up")
	t.eq(shield.equipped_to_id, caster.id, "equipped to the Spellcaster")
	t.eq(caster.equipped_card_ids, [shield.id], "and the Spellcaster knows about it")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 1,
		"exactly one CARD_EQUIPPED event")
	t.is_false(Enums.stays_on_field(Enums.STKind.NORMAL_TRAP),
		"the card KIND alone would have sent it to the Graveyard — it is the equip that "
		+ "keeps it here")


static func _test_the_target_filter(t: TestCase) -> void:
	t.start("'1 SPELLCASTER monster YOU CONTROL', face-up")
	var d := _main_phase_duel(7802)
	var engine: DuelEngine = d["engine"]

	var shield := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var caster := TestFixtures.give_monster_on_field(engine, 0, _card("Apprentice Magician"))
	var not_a_caster := TestFixtures.give_monster_on_field(engine, 0, _card("Luster Dragon"))
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		_card("Aussa the Earth Charmer"), Enums.Position.FACE_DOWN_DEFENSE)
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _card("Fairy Tail - Luna"))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, shield.id)
	t.not_null(action, "Gagagashield is offered")
	t.is_true(action.target_candidates.has(caster.id),
		"the face-up Spellcaster you control is a candidate")
	t.is_false(action.target_candidates.has(not_a_caster.id), "a Dragon is not")
	t.is_false(action.target_candidates.has(face_down.id),
		"and neither is a FACE-DOWN Spellcaster [S1 p.29]")
	t.is_false(action.target_candidates.has(theirs.id),
		"nor a Spellcaster the OPPONENT controls")
	t.eq(action.target_candidates.size(), 1, "exactly one candidate")

	t.is_false(engine.submit_action(action.with_choices({"target_ids": [theirs.id]})),
		"a hand-built activation targeting the opponent's Spellcaster is rejected")


# ---------------------------------------------------------------------------
# The counted protection
# ---------------------------------------------------------------------------

static func _test_twice_per_turn_against_card_effects(t: TestCase) -> void:
	t.start("'TWICE per turn, it cannot be destroyed' — the third destruction lands")
	var d := _shielded_board(7803)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var caster: CardInstance = d["caster"]
	var shield: CardInstance = d["shield"]
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Unprotected", 4, 1000, 1000))

	t.is_false(state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the first destruction is prevented")
	t.is_false(state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"and so is the second")
	t.eq(caster.zone, Enums.Zone.MONSTER_ZONE, "the Spellcaster is still on the field")
	t.is_true(state.destroy(other, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the protection is 'it', the equipped monster — nothing else is covered")

	t.is_true(state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the third destruction of the equipped monster goes through")
	t.eq(caster.zone, Enums.Zone.GRAVEYARD, "so it is destroyed")
	t.eq(shield.zone, Enums.Zone.GRAVEYARD,
		"and Gagagashield follows it, having lost its host [S1 p.29]")


static func _test_the_count_resets_next_turn(t: TestCase) -> void:
	t.start("'twice PER TURN' — the count comes back")
	var d := _shielded_board(7804)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var caster: CardInstance = d["caster"]

	t.is_false(state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT), "one")
	t.is_false(state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT), "two")
	t.is_true(state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"three would land…")
	# Re-arm the board on a later turn.
	var d2 := _shielded_board(7805)
	var engine2: DuelEngine = d2["engine"]
	var caster2: CardInstance = d2["caster"]
	t.is_false(engine2.state.destroy(caster2, Enums.MoveReason.DESTROYED_BY_EFFECT), "one")
	t.is_false(engine2.state.destroy(caster2, Enums.MoveReason.DESTROYED_BY_EFFECT), "two")
	TestFixtures.end_turn(engine2)
	TestFixtures.end_turn(engine2)
	t.is_false(engine2.state.destroy(caster2, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"…but on a later turn it protects again")
	t.eq(caster2.zone, Enums.Zone.MONSTER_ZONE, "so the monster survives")


static func _test_protection_against_battle_destruction(t: TestCase) -> void:
	t.start("'by battle OR card effects' — battle destruction is prevented too, while "
		+ "battle damage is still inflicted [S1 p.42]")
	# Player 0 goes first, so on turn 2 player 1 attacks player 0's shielded Spellcaster.
	var d := _shielded_board(7806)
	var engine: DuelEngine = d["engine"]
	var caster: CardInstance = d["caster"]
	var shield: CardInstance = d["shield"]

	TestFixtures.end_turn(engine)
	var attacker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Big Attacker", 4, 2500, 1000))
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the opponent reaches their Battle Phase")
	t.is_true(TestFixtures.attack(engine, attacker, caster),
		"and attacks the shielded Spellcaster (1850 ATK)")
	TestFixtures.pass_until_open(engine)

	t.eq(caster.zone, Enums.Zone.MONSTER_ZONE, "it was not destroyed by battle")
	t.eq(shield.zone, Enums.Zone.SPELL_TRAP_ZONE, "so Gagagashield is still equipped")
	t.eq(engine.state.player(0).life_points, 8000 - 650,
		"but battle damage was still inflicted: 2500 - 1850")
	t.is_true(engine.state.destruction_prevented(caster,
		Enums.MoveReason.DESTROYED_BY_EFFECT),
		"one of the two uses is left this turn")
	t.is_true(engine.state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"and once both are spent the next destruction lands")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

static func _test_the_equipped_monster_leaving(t: TestCase) -> void:
	t.start("the equipped monster leaving the field destroys this card by the RULES, "
		+ "not by a card effect [S1 p.29, p.55]")
	var d := _shielded_board(7807)
	var engine: DuelEngine = d["engine"]
	var caster: CardInstance = d["caster"]
	var shield: CardInstance = d["shield"]
	var mark := engine.state.events.size()

	# Banished rather than destroyed, so the protection is not even consulted.
	engine.state.move_card(caster, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)

	t.eq(caster.zone, Enums.Zone.BANISHED, "the Spellcaster left the field")
	t.eq(shield.zone, Enums.Zone.GRAVEYARD, "Gagagashield was destroyed with it")
	var destroyed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark)
	t.eq(destroyed.size(), 1, "exactly one destruction")
	t.eq((destroyed[0] as GameEvent).data.get("reason", null),
		Enums.MoveReason.DESTROYED_BY_RULE, "by the game rules")


static func _test_the_shield_leaving_ends_the_protection(t: TestCase) -> void:
	t.start("destroy the shield and the monster is on its own again")
	var d := _shielded_board(7808)
	var engine: DuelEngine = d["engine"]
	var caster: CardInstance = d["caster"]
	var shield: CardInstance = d["shield"]

	t.is_true(engine.state.destroy(shield, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"Gagagashield itself is not protected by its own clause")
	t.eq(shield.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(caster.zone, Enums.Zone.MONSTER_ZONE, "the Spellcaster is untouched")
	t.eq(caster.equipped_card_ids.size(), 0, "with no stale relationship left")
	t.is_true(engine.state.destroy(caster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"and it is now destroyed normally")


static func _test_resolving_without_equipping(t: TestCase) -> void:
	t.start("with the target gone at resolution nothing is equipped, and a Normal Trap "
		+ "that equipped nothing goes to the Graveyard [S1 p.30]")
	var d := _main_phase_duel(7809)
	var engine: DuelEngine = d["engine"]

	var caster := TestFixtures.give_monster_on_field(engine, 0, _card("Fairy Tail - Luna"))
	var shield := TestFixtures.give_set_spell_trap(engine, 0, _def(), 0)
	var thief := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Banisher", caster, "banish"), 0)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, shield.id)
	t.not_null(action, "Gagagashield is offered")
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [caster.id]})),
		"and activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent chains a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response), "as Chain Link 2, which resolves first")
	TestFixtures.pass_until_open(engine)

	t.eq(caster.zone, Enums.Zone.BANISHED, "the target is gone")
	t.eq(shield.equipped_to_id, -1, "nothing was equipped")
	t.eq(shield.zone, Enums.Zone.GRAVEYARD, "and the Normal Trap went to the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 0,
		"no CARD_EQUIPPED event was ever emitted")

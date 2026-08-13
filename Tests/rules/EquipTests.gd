class_name EquipTests
extends RefCounted

## The generic Equip Card subsystem. RULES_SPEC.md 16, 17 [S1 p.29, p.53, p.55].
##
## This suite exists because Equip mechanics had ZERO assertions before it, and three V1
## cards depend on them (`Gagagashield`, `Rider of the Storm Winds`, and later
## `Kunai with Chain` / `Fairy Tail - Rella`). It is a RULES suite, not a per-card suite:
## it uses synthetic cards on purpose, so what it proves is that the engine is right
## rather than that one printed card happens to work.
##
## The rules being exercised, quoted:
##
##   * "These cards give an extra effect to 1 face-up monster of your choice … The Equip
##      Spell Card affects only 1 monster (called the equipped monster), but still
##      occupies one of your Spell & Trap Zones. If the equipped monster is destroyed,
##      flipped face-down, or removed from the field, its Equip Cards are destroyed."
##      [S1 p.29]
##   * "The term 'Equip Card' includes all 3 kinds (standard Equip Spells, equipped Traps,
##      and monsters equipped to other monsters). If a Monster Card is equipped to another
##      monster, it remains equipped to that monster and cannot be moved to a different
##      target." [S1 p.53]
##   * "A monster that is equipped with an Equip Card is an 'equipped monster.' When this
##      monster is destroyed or flipped face-down, the equipped card loses its target, and
##      is destroyed and sent to the Graveyard." [S1 p.55]
##   * "The Original ATK (or DEF) is the number of ATK (or DEF) points printed on the
##      Monster Card. This does not include an increase from an Equip Spell Card."
##      [S1 p.55]

const ATK_BONUS := 700


static func run() -> TestCase:
	var t := TestCase.new("EquipTests")
	_test_equipping_attaches_to_one_face_up_monster(t)
	_test_only_a_legal_host_can_be_equipped(t)
	_test_the_granted_effect_follows_the_host(t)
	_test_the_host_leaving_the_field_destroys_the_equip(t)
	_test_the_host_flipped_face_down_destroys_the_equip(t)
	_test_the_equip_leaving_takes_its_effect_with_it(t)
	_test_battle_is_recalculated_from_the_equipped_atk(t)
	_test_an_equip_that_resolves_without_equipping(t)
	_test_a_target_that_became_illegal(t)
	_test_a_counted_destruction_prevention(t)
	_test_a_destruction_replacement(t)
	return t


# ---------------------------------------------------------------------------
# Synthetic cards
# ---------------------------------------------------------------------------

## An Equip Spell: "Target 1 monster you control; equip this card to it. It gains ATK."
static func _equip_spell_def(card_name: String = "Test Equip") -> CardDef:
	var d := TestFixtures.spell(card_name, Enums.STKind.EQUIP_SPELL)

	var equip := EffectDef.new("equip_to_target",
		"Test: target 1 monster you control; equip this card to that target.")
	equip.of_type(Enums.EffectType.CARD_ACTIVATION)
	equip.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	equip.targeting(1)
	equip.legal_targets = func(ctx: EffectContext) -> Array:
		return ctx.me().face_up_monsters()
	equip.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.equip_source_to_target(ctx)
	d = TestFixtures.with_effect(d, equip)

	var boost := EffectDef.new("equipped_monster_gains_atk",
		"Test: the equipped monster gains %d ATK." % ATK_BONUS)
	boost.of_type(Enums.EffectType.CONTINUOUS)
	boost.apply_continuous = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equipped_host(ctx)
		if host != null:
			ContinuousEffects.add_atk(ctx.source, host, ATK_BONUS)
	return TestFixtures.with_effect(d, boost)


## A Continuous Trap with a COUNTED destruction prevention — the `Gagagashield` mechanic
## in its generic form.
static func _aegis_def(uses: int) -> CardDef:
	var d := TestFixtures.trap("Test Aegis", Enums.STKind.CONTINUOUS_TRAP)
	var e := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"Test: %d times per turn, monsters you control cannot be destroyed." % uses)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.uses_per_turn = uses
	e.condition = func(ctx: EffectContext) -> bool:
		var victim = ctx.params.get("card", null)
		if victim == null:
			return false
		var card: CardInstance = victim
		return card.is_monster() and card.controller_id == ctx.controller_id
	return TestFixtures.with_effect(d, e)


## A Continuous Spell that substitutes ITSELF for the destruction of any monster its
## controller controls — the `Rider of the Storm Winds` mechanic in its generic form.
static func _substitute_def() -> CardDef:
	var d := TestFixtures.spell("Test Substitute", Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new(GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID,
		"Test: if a monster you control would be destroyed, destroy this card instead.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.destruction_substitute = func(ctx: EffectContext):
		var victim = ctx.params.get("card", null)
		if victim == null:
			return null
		var card: CardInstance = victim
		if card.is_monster() and card.controller_id == ctx.controller_id:
			return ctx.source
		return null
	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Activate an Equip Spell from `pid`'s hand at `target`, and let the Chain finish.
static func _activate_equip(engine: DuelEngine, pid: int, equip: CardInstance,
		target: CardInstance) -> bool:
	var action = TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.ACTIVATE_CARD, equip.id)
	if action == null:
		return false
	if not engine.submit_action(action.with_choices({"target_ids": [target.id]})):
		return false
	TestFixtures.pass_until_open(engine)
	return true


## An equipped board: player 0 controls `host` with an Equip Spell attached to it.
static func _equipped_board(seed_value: int) -> Dictionary:
	var d := _main_phase_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host Monster", 4, 1000, 1000))
	var equip := TestFixtures.give_to_hand(engine, 0, _equip_spell_def())
	_activate_equip(engine, 0, equip, host)
	d["host"] = host
	d["equip"] = equip
	return d


# ---------------------------------------------------------------------------
# The relationship
# ---------------------------------------------------------------------------

static func _test_equipping_attaches_to_one_face_up_monster(t: TestCase) -> void:
	t.start("equipping attaches the card to exactly one face-up monster and keeps it on "
		+ "the field in a Spell & Trap Zone")
	var d := _equipped_board(7101)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var equip: CardInstance = d["equip"]

	t.eq(equip.equipped_to_id, host.id, "the Equip Card points at the monster")
	t.eq(host.equipped_card_ids, [equip.id], "and the monster points back at it")
	t.eq(engine.state.equipped_cards(host).size(), 1,
		"the monster has exactly one Equip Card")
	t.eq(equip.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Equip Card 'still occupies one of your Spell & Trap Zones' [S1 p.29]")
	t.is_true(equip.is_face_up(), "and it is face-up there")
	t.ne(equip.zone_index, -1, "in a real, indexed zone rather than nowhere")
	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "the monster is untouched in its own zone")

	var equipped_events := TestFixtures.events_of(engine, GameEvent.Kind.CARD_EQUIPPED)
	t.eq(equipped_events.size(), 1, "exactly one CARD_EQUIPPED event was emitted")
	t.eq(int((equipped_events[0] as GameEvent).data.get("equipped_to_id", -1)), host.id,
		"and it names the monster that was equipped")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_UNEQUIPPED), 0,
		"and nothing was unequipped")


static func _test_only_a_legal_host_can_be_equipped(t: TestCase) -> void:
	t.start("an Equip Card attaches only to a face-up monster on the field, and once "
		+ "attached it cannot be moved [S1 p.29, p.53]")
	var d := _main_phase_duel(7102)
	var engine: DuelEngine = d["engine"]
	var state := engine.state

	var face_up := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face Up", 4, 1000, 1000))
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face Down", 4, 1000, 1000),
		Enums.Position.FACE_DOWN_DEFENSE)
	var in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("In Hand", 4, 1000, 1000))
	var equip := TestFixtures.give(engine, 0, _equip_spell_def(),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	t.is_false(state.equip_to(equip, face_down),
		"a FACE-DOWN monster is not 'a face-up monster of your choice' [S1 p.29]")
	t.is_false(state.equip_to(equip, in_hand),
		"a monster in the hand is not on the field")
	t.is_false(state.equip_to(equip, equip),
		"a card cannot be equipped to itself")
	t.eq(equip.equipped_to_id, -1, "none of those attached anything")

	t.is_true(state.equip_to(equip, face_up), "a face-up monster on the field is legal")
	t.is_false(state.equip_to(equip, face_down),
		"an already-equipped card 'cannot be moved to a different target' [S1 p.53]")
	t.eq(equip.equipped_to_id, face_up.id, "so it is still on the original monster")
	t.eq(face_down.equipped_card_ids.size(), 0,
		"and the rejected monster gained nothing")


# ---------------------------------------------------------------------------
# The granted effect
# ---------------------------------------------------------------------------

static func _test_the_granted_effect_follows_the_host(t: TestCase) -> void:
	t.start("the continuous effect an Equip Card grants applies to its host and leaves "
		+ "the printed values alone")
	var d := _equipped_board(7103)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]

	engine.continuous.recompute()
	t.eq(host.current_atk(), 1000 + ATK_BONUS, "the equipped monster gains the ATK")
	t.eq(host.base_atk(), 1000, "its PRINTED ATK is untouched")
	t.eq(host.original_atk(), 1000,
		"'Original ATK … does not include an increase from an Equip Spell' [S1 p.55]")
	t.eq(host.atk_modifiers.size(), 1, "exactly one modifier entry")

	for _i in range(5):
		engine.continuous.recompute()
	t.eq(host.current_atk(), 1000 + ATK_BONUS,
		"five recomputes give the same value as one — it is state-derived, not cumulative")
	t.eq(host.atk_modifiers.size(), 1, "and still exactly one modifier entry")

	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	engine.continuous.recompute()
	t.eq(other.current_atk(), 1000,
		"a monster that is not the equipped monster gains nothing")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

static func _test_the_host_leaving_the_field_destroys_the_equip(t: TestCase) -> void:
	t.start("'If the equipped monster is … removed from the field, its Equip Cards are "
		+ "destroyed' [S1 p.29] — and by the RULES, not by a card effect")
	var d := _equipped_board(7104)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var equip: CardInstance = d["equip"]
	var mark := engine.state.events.size()

	# Banished, not destroyed: what matters is that the monster left the field at all.
	engine.state.move_card(host, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
	TestFixtures.pass_until_open(engine)

	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "the Equip Card went to the Graveyard")
	t.eq(equip.equipped_to_id, -1, "and it is no longer equipped to anything")
	t.eq(host.equipped_card_ids.size(), 0, "the monster's list was cleared too")

	var unequipped := TestFixtures.events_of(engine, GameEvent.Kind.CARD_UNEQUIPPED, mark)
	t.eq(unequipped.size(), 1, "exactly one CARD_UNEQUIPPED event")
	t.is_true(bool((unequipped[0] as GameEvent).data.get("lost_host", false)),
		"and it records that the Equip Card lost its host")

	var destroyed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark)
	t.eq(destroyed.size(), 1, "the Equip Card was destroyed")
	t.eq((destroyed[0] as GameEvent).data.get("reason", null),
		Enums.MoveReason.DESTROYED_BY_RULE,
		"by the game RULES — a clause worded 'destroyed by card effect' must not see this")
	t.ne((destroyed[0] as GameEvent).data.get("reason", null),
		Enums.MoveReason.DESTROYED_BY_EFFECT,
		"specifically, it is not a card-effect destruction")


static func _test_the_host_flipped_face_down_destroys_the_equip(t: TestCase) -> void:
	t.start("'If the equipped monster is … flipped face-down, its Equip Cards are "
		+ "destroyed' [S1 p.29, p.55] — the monster stays on the field, so this is not a "
		+ "movement case at all")
	var d := _equipped_board(7105)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var equip: CardInstance = d["equip"]

	engine.state.set_battle_position(host, Enums.Position.FACE_DOWN_DEFENSE, true)
	engine.continuous.recompute()

	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "the monster is still on the field")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "but the Equip Card was destroyed")
	t.eq(equip.equipped_to_id, -1, "the relationship is gone")
	t.eq(host.equipped_card_ids.size(), 0, "from both sides")
	t.eq(host.current_atk(), 1000, "and the granted ATK went with it")


static func _test_the_equip_leaving_takes_its_effect_with_it(t: TestCase) -> void:
	t.start("when the EQUIP CARD leaves the field the monster survives and simply loses "
		+ "what it was granted")
	var d := _equipped_board(7106)
	var engine: DuelEngine = d["engine"]
	var host: CardInstance = d["host"]
	var equip: CardInstance = d["equip"]

	engine.continuous.recompute()
	t.eq(host.current_atk(), 1000 + ATK_BONUS, "the monster starts out boosted")

	engine.state.destroy(equip, Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()

	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "the monster is untouched")
	t.eq(host.current_atk(), 1000, "and back to its printed ATK")
	t.eq(host.atk_modifiers.size(), 0, "with no stale modifier left behind")
	t.eq(host.equipped_card_ids.size(), 0, "and no stale relationship")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "the Equip Card is in the Graveyard")


static func _test_battle_is_recalculated_from_the_equipped_atk(t: TestCase) -> void:
	t.start("damage calculation reads the EQUIPPED ATK: a losing attacker wins once it "
		+ "is equipped [S1 p.42]")
	# Player 1 takes the first turn so player 0 may conduct a Battle Phase on turn 2.
	var d := TestFixtures.new_duel(7107, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1000, 1000))
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Defender", 4, 1500, 1000))
	var equip := TestFixtures.give_to_hand(engine, 0, _equip_spell_def())

	t.is_true(_activate_equip(engine, 0, equip, attacker), "the Equip Spell resolves")
	engine.continuous.recompute()
	t.eq(attacker.current_atk(), 1700, "1000 + 700 beats the 1500 ATK defender")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, attacker, defender), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(defender.zone, Enums.Zone.GRAVEYARD, "the defender was destroyed by battle")
	t.eq(attacker.zone, Enums.Zone.MONSTER_ZONE, "and the attacker survived")
	t.eq(engine.state.player(1).life_points, 8000 - 200,
		"battle damage is 1700 - 1500, computed from the equipped ATK")


# ---------------------------------------------------------------------------
# Failing to equip
# ---------------------------------------------------------------------------

static func _test_an_equip_that_resolves_without_equipping(t: TestCase) -> void:
	t.start("an Equip Spell that resolves without equipping has no monster to affect and "
		+ "does not stay on the field [S1 p.29]")
	var d := _main_phase_duel(7108)
	var engine: DuelEngine = d["engine"]

	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host Monster", 4, 1000, 1000))
	var equip := TestFixtures.give_to_hand(engine, 0, _equip_spell_def())
	var interferer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Banisher", host, "banish"), 0)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, equip.id)
	t.not_null(action, "the Equip Spell is offered while a legal target exists")
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [host.id]})),
		"and it is activated as Chain Link 1")
	# Chain Link 2 removes the target, and resolves FIRST [S1 p.46-47].
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, interferer.id)
	t.not_null(response, "the opponent may respond with a Spell Speed 2 Trap")
	t.is_true(engine.submit_action(response), "and does so")
	TestFixtures.pass_until_open(engine)
	t.eq(host.zone, Enums.Zone.BANISHED, "the target left the field before resolution")

	t.eq(equip.equipped_to_id, -1, "nothing was equipped")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD,
		"so the Equip Spell went to the Graveyard rather than sitting on the field")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 0,
		"and no CARD_EQUIPPED event was ever emitted")


static func _test_a_target_that_became_illegal(t: TestCase) -> void:
	t.start("a target that is still on the field but no longer FACE-UP is not equipped to")
	var d := _main_phase_duel(7109)
	var engine: DuelEngine = d["engine"]

	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host Monster", 4, 1000, 1000))
	var equip := TestFixtures.give_to_hand(engine, 0, _equip_spell_def())
	var interferer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Test Flipper", host, "flip_face_down"), 0)

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, equip.id)
	t.not_null(action, "the Equip Spell is offered")
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [host.id]})),
		"and activated targeting the face-up monster")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, interferer.id)
	t.not_null(response, "the opponent chains a Trap that turns the target face-down")
	t.is_true(engine.submit_action(response), "as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "the target is still on the field")
	t.is_true(host.is_face_down(), "but face-down")
	t.eq(equip.equipped_to_id, -1, "so it was not equipped to")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "and the Equip Spell was sent to the Graveyard")


# ---------------------------------------------------------------------------
# Destruction prevention and replacement. RULES_SPEC.md 17.
# ---------------------------------------------------------------------------

static func _test_a_counted_destruction_prevention(t: TestCase) -> void:
	t.start("a COUNTED 'cannot be destroyed' stops exactly its number of destructions per "
		+ "turn, and the count comes back next turn")
	var d := _main_phase_duel(7110)
	var engine: DuelEngine = d["engine"]
	var state := engine.state

	TestFixtures.give(engine, 0, _aegis_def(2), Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	var a := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Protected A", 4, 1000, 1000))
	var b := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Protected B", 4, 1000, 1000))
	var c := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Protected C", 4, 1000, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Unprotected", 4, 1000, 1000))

	t.is_false(state.destroy(a, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the first destruction is prevented")
	t.is_false(state.destroy(b, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"and so is the second")
	t.is_true(state.destroy(c, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the third is not — the clause is spent for this turn")
	t.eq(a.zone, Enums.Zone.MONSTER_ZONE, "the first monster is still on the field")
	t.eq(b.zone, Enums.Zone.MONSTER_ZONE, "so is the second")
	t.eq(c.zone, Enums.Zone.GRAVEYARD, "the third one really was destroyed")
	t.is_true(state.destroy(theirs, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"a monster the clause does not cover was never protected in the first place")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.is_false(state.destroy(a, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"on a later turn the count has reset and it protects again")
	t.eq(a.zone, Enums.Zone.MONSTER_ZONE, "so the monster survives once more")


static func _test_a_destruction_replacement(t: TestCase) -> void:
	t.start("a destruction REPLACEMENT destroys the substitute instead — something is "
		+ "still destroyed, just not the original")
	var d := _main_phase_duel(7111)
	var engine: DuelEngine = d["engine"]
	var state := engine.state

	var substitute := TestFixtures.give(engine, 0, _substitute_def(),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	var monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Shielded", 4, 1000, 1000))
	var mark := state.events.size()

	t.is_true(state.destroy(monster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"the destruction still happens — a replacement is not a prevention")
	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "but not to the monster")
	t.eq(substitute.zone, Enums.Zone.GRAVEYARD, "the substitute went instead")

	var destroyed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark)
	t.eq(destroyed.size(), 1, "exactly one card was destroyed")
	t.eq(int((destroyed[0] as GameEvent).data.get("card_id", -1)), substitute.id,
		"and it was the substitute")

	# With the substitute gone the clause is gone with it, so the next attempt lands.
	t.is_true(state.destroy(monster, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"once the substitute has left the field nothing replaces the destruction")
	t.eq(monster.zone, Enums.Zone.GRAVEYARD, "so the monster is destroyed this time")

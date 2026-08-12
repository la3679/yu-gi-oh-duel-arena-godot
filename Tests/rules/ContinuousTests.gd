class_name ContinuousTests
extends RefCounted

## Continuous effects as state-derived modifiers.
##
## Rules under test: RULES_SPEC.md 4.2 / 8, master prompt 25. A Continuous Effect is not
## an activation, starts no Chain, and is recomputed from the authoritative board rather
## than accumulated — so it switches off by itself when its source stops applying instead
## of being undone by a cleanup step.
##
## That architecture decision is load-bearing and these tests pin it down: a modifier must
## never survive its source, and repeated recomputation must never stack.


static func run() -> TestCase:
	var t := TestCase.new("ContinuousTests")
	_test_atk_and_def_modifiers_apply(t)
	_test_recompute_rebuilds_rather_than_accumulates(t)
	_test_source_leaving_the_field_removes_the_effect(t)
	_test_source_flipped_face_down_stops_applying(t)
	_test_negated_source_stops_applying(t)
	_test_restriction_flags_are_owned_by_this_system(t)
	_test_multiple_simultaneous_modifiers(t)
	_test_counter_scaled_modifier_recomputes(t)
	_test_cannot_be_destroyed_by_battle_survives_damage_calculation(t)
	_test_continuous_effect_never_starts_a_chain(t)
	_test_effect_applies_once_its_source_is_on_the_field(t)
	_test_player_level_restrictions_round_trip(t)
	return t


# ---------------------------------------------------------------------------
# Synthetic continuous sources
# ---------------------------------------------------------------------------

## A face-up Continuous Spell that gives every monster its controller controls +`atk_up`
## ATK and +`def_up` DEF.
static func _team_buff(name: String, atk_up: int, def_up: int) -> CardDef:
	var def := TestFixtures.spell(name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new("buff", "Monsters you control gain ATK/DEF.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		for m in ctx.me().monsters():
			ContinuousEffects.add_atk(ctx.source, m, atk_up)
			ContinuousEffects.add_def(ctx.source, m, def_up)
	TestFixtures.with_effect(def, e)
	return def


## A monster whose own continuous effect protects every monster its controller controls
## from destruction by battle.
static func _battle_protector(name: String, atk: int, def_: int) -> CardDef:
	var d := TestFixtures.monster(name, 4, atk, def_)
	var e := EffectDef.new("protect",
		"Monsters you control cannot be destroyed by battle.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		for m in ctx.me().monsters():
			ContinuousEffects.restrict(m, "cannot_be_destroyed_by_battle")
	TestFixtures.with_effect(d, e)
	return d


## The `Wonder Balloons` shape: "Monsters your opponent controls lose 300 ATK for each
## Balloon Counter on this card." The modifier is a pure function of the counters, so it
## must follow them up AND down without any bookkeeping of its own.
static func _counter_scaled_debuff(name: String, counter: String,
		per_counter: int) -> CardDef:
	var def := TestFixtures.trap(name, Enums.STKind.CONTINUOUS_TRAP)
	var e := EffectDef.new("debuff",
		"Monsters your opponent controls lose ATK for each counter on this card.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		var n := ctx.source.counter_count(counter)
		if n <= 0:
			return
		for m in ctx.opponent().monsters():
			ContinuousEffects.add_atk(ctx.source, m, -per_counter * n)
	TestFixtures.with_effect(def, e)
	return def


# ---------------------------------------------------------------------------
# Applying and expiring
# ---------------------------------------------------------------------------

static func _test_atk_and_def_modifiers_apply(t: TestCase) -> void:
	t.start("a continuous effect modifies ATK and DEF while its source applies")
	var d := TestFixtures.battle_duel(801)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	t.eq(mon.current_atk(), 1200, "the printed ATK before anything applies")
	t.eq(mon.current_def(), 900, "the printed DEF before anything applies")

	TestFixtures.give(engine, 0, _team_buff("Banner", 500, 300),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()

	t.eq(mon.current_atk(), 1700, "the continuous ATK modifier applies")
	t.eq(mon.current_def(), 1200, "and the continuous DEF modifier")
	t.eq(mon.base_atk(), 1200, "the printed value on the definition is untouched")
	t.eq(mon.original_atk(), 1200,
		"'original ATK' still reports the printed value (master prompt 35)")


static func _test_recompute_rebuilds_rather_than_accumulates(t: TestCase) -> void:
	t.start("repeated recomputation rebuilds the modifiers instead of stacking them")
	var d := TestFixtures.battle_duel(802)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	TestFixtures.give(engine, 0, _team_buff("Banner", 500, 300),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	for i in range(5):
		engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700,
		"five recomputes give the same result as one — the modifier is rebuilt, "
		+ "not added again")
	t.eq(mon.atk_modifiers.size(), 1, "and exactly one modifier entry exists")

	# The engine recomputes at the top of every timing-machine iteration, so simply
	# playing on must not inflate the value either.
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)
	t.eq(mon.current_atk(), 1700, "driving the engine forward does not stack it")
	t.eq(mon.atk_modifiers.size(), 1, "still exactly one modifier entry")


static func _test_source_leaving_the_field_removes_the_effect(t: TestCase) -> void:
	t.start("a continuous effect stops the moment its source leaves the field")
	var d := TestFixtures.battle_duel(803)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	var source := TestFixtures.give(engine, 0, _team_buff("Banner", 500, 300),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "the boost applies while the source is on the field")

	engine.state.move_card(source, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1200, "and disappears with the source")
	t.eq(mon.current_def(), 900, "the DEF modifier went with it")
	t.eq(mon.atk_modifiers.size(), 0, "no stale modifier entry was left behind")


static func _test_source_flipped_face_down_stops_applying(t: TestCase) -> void:
	t.start("a source that is face-down applies nothing")
	var d := TestFixtures.battle_duel(804)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	var source := TestFixtures.give(engine, 0, _team_buff("Banner", 500, 300),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "applies while face-up")

	engine.state.set_battle_position(source, Enums.Position.FACE_DOWN, true)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1200, "a face-down card applies no continuous effect")

	engine.state.set_battle_position(source, Enums.Position.FACE_UP, true)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "and applies again once it is face-up")


static func _test_negated_source_stops_applying(t: TestCase) -> void:
	t.start("a source whose effects are negated applies nothing")
	var d := TestFixtures.battle_duel(805)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	var source := TestFixtures.give(engine, 0, _team_buff("Banner", 500, 300),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "applies before the negation")

	source.effects_negated = true
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1200, "a negated source applies no continuous effect")

	source.effects_negated = false
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "and resumes when the negation ends")


static func _test_restriction_flags_are_owned_by_this_system(t: TestCase) -> void:
	t.start("the restriction flags this system owns are wiped and rebuilt every time")
	var d := TestFixtures.battle_duel(806)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))

	# Something wrote a restriction flag without being a live continuous source. The
	# recompute must not preserve it, or a lifted restriction could linger forever.
	mon.flags["cannot_attack"] = true
	mon.flags["not_owned_by_continuous"] = true
	engine.continuous.recompute()
	t.is_false(bool(mon.flags.get("cannot_attack", false)),
		"a restriction with no live source does not survive a recompute")
	t.is_true(bool(mon.flags.get("not_owned_by_continuous", false)),
		"flags outside RESTRICTION_FLAGS are left alone")

	t.is_true(ContinuousEffects.RESTRICTION_FLAGS.has("cannot_attack")
		and ContinuousEffects.RESTRICTION_FLAGS.has("cannot_be_destroyed_by_battle"),
		"the owned flag list covers the battle restrictions the rules layer reads")
	t.is_false(ContinuousEffects.restrict(mon, "not_a_real_flag"),
		"an unknown restriction flag is rejected rather than silently written")


static func _test_multiple_simultaneous_modifiers(t: TestCase) -> void:
	t.start("several continuous sources apply together and each leaves independently")
	var d := TestFixtures.battle_duel(807)
	var engine: DuelEngine = d["engine"]
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1000, 1000))
	var a := TestFixtures.give(engine, 0, _team_buff("Banner A", 400, 0),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	var b := TestFixtures.give(engine, 0, _team_buff("Banner B", 300, 0),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "both modifiers apply at once")
	t.eq(mon.atk_modifiers.size(), 2, "as two separate entries, one per source")

	engine.state.move_card(a, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1300, "removing one source removes only its modifier")

	engine.state.move_card(b, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1000, "removing the last source restores the printed ATK")


static func _test_counter_scaled_modifier_recomputes(t: TestCase) -> void:
	t.start("a counter-scaled continuous modifier follows the counters up and down")
	var d := TestFixtures.battle_duel(808)
	var engine: DuelEngine = d["engine"]
	var victim := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Balloonable", 4, 1800, 1000))
	var balloons := TestFixtures.give(engine, 1,
		_counter_scaled_debuff("Wonder Balloons Shape", "Balloon Counter", 300),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	engine.continuous.recompute()
	t.eq(victim.current_atk(), 1800, "with no counters there is no modifier at all")

	engine.state.place_counters(balloons, "Balloon Counter", 2)
	engine.continuous.recompute()
	t.eq(victim.current_atk(), 1800 - 600, "two counters take off 600 ATK")

	engine.state.place_counters(balloons, "Balloon Counter", 1)
	engine.continuous.recompute()
	t.eq(victim.current_atk(), 1800 - 900, "a third counter takes off 300 more")

	engine.state.remove_counters(balloons, "Balloon Counter", 3)
	engine.continuous.recompute()
	t.eq(victim.current_atk(), 1800,
		"removing the counters restores the printed ATK exactly")
	t.eq(victim.atk_modifiers.size(), 0, "leaving no residue behind")

	# A modifier can reduce ATK to zero but never below it.
	engine.state.place_counters(balloons, "Balloon Counter", 10)
	engine.continuous.recompute()
	t.eq(victim.current_atk(), 0, "ATK is floored at 0, never negative")


static func _test_cannot_be_destroyed_by_battle_survives_damage_calculation(
		t: TestCase) -> void:
	t.start("a continuous 'cannot be destroyed by battle' restriction survives damage "
		+ "calculation while battle damage is still inflicted")
	var d := TestFixtures.battle_duel(809)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Aggressor", 4, 1800, 1000))
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Protected", 4, 1000, 1000))
	# The protector is itself the continuous source, and protects its whole side.
	var protector := TestFixtures.give_monster_on_field(engine, 1,
		_battle_protector("Aegis", 100, 100))

	TestFixtures.attack(engine, attacker, defender)
	TestFixtures.pass_until_open(engine)

	t.eq(defender.zone, Enums.Zone.MONSTER_ZONE,
		"the defender was not destroyed by battle")
	t.eq(engine.state.player(1).life_points, 8000 - 800,
		"but the battle damage was still inflicted [S1 p.42]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), 0,
		"and no destruction event was raised at all")

	# Remove the protection and the same battle now destroys the monster, so the test
	# above is about the restriction and not about some unrelated immunity.
	engine.state.move_card(protector, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	var second := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Second Aggressor", 4, 1800, 1000))
	TestFixtures.attack(engine, second, defender)
	TestFixtures.pass_until_open(engine)
	t.eq(defender.zone, Enums.Zone.GRAVEYARD,
		"without the source the very same battle destroys it")


static func _test_continuous_effect_never_starts_a_chain(t: TestCase) -> void:
	t.start("a continuous effect is never offered as an activation and starts no Chain")
	var d := TestFixtures.battle_duel(810)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	var buff_def := _team_buff("Banner", 500, 300)
	var source := TestFixtures.give(engine, 0, buff_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)

	var effect: EffectDef = buff_def.effects[0]
	t.is_false(effect.starts_chain,
		"a CONTINUOUS effect is declared as not starting a Chain")
	t.eq(effect.effect_type, Enums.EffectType.CONTINUOUS, "and is typed as continuous")
	t.is_false(effect.resolve.is_valid(),
		"it has no resolve(): it never resolves, it only applies")

	var mark := engine.state.events.size()
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, source.id),
		"it is not offered as an action in an open game state")
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.CHAIN_LINK_ADDED, mark).size(), 0,
		"and playing on never creates a Chain Link from it")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.EFFECT_ACTIVATED, mark).size(), 0,
		"nor an activation event")


static func _test_effect_applies_once_its_source_is_on_the_field(t: TestCase) -> void:
	t.start("a Continuous Spell activated from the hand is applying its effect once the "
		+ "activation has resolved")
	var d := TestFixtures.battle_duel(811)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))

	var buff_def := _team_buff("Banner", 500, 300)
	# The card activation clause, alongside the continuous clause it already carries.
	var activation := EffectDef.new("activate", "Activate this card.")
	activation.of_type(Enums.EffectType.CARD_ACTIVATION)
	activation.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	activation.resolve = func(_ctx: EffectContext) -> void:
		pass
	TestFixtures.with_effect(buff_def, activation)
	var card := TestFixtures.give_to_hand(engine, 0, buff_def)

	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1200,
		"a Continuous Spell still in the hand applies nothing")

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, card.id))
	TestFixtures.pass_until_open(engine)

	t.eq(card.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the Continuous Spell stayed on the field after resolving [S1 p.28]")
	t.eq(mon.current_atk(), 1700, "and its continuous effect is now applying")


static func _test_player_level_restrictions_round_trip(t: TestCase) -> void:
	t.start("player-level continuous restrictions are namespaced and cleared on "
		+ "recompute")
	var d := TestFixtures.battle_duel(812)
	var engine: DuelEngine = d["engine"]
	var continuous := engine.continuous

	continuous.restrict_player(0, "cannot_conduct_battle_phase")
	t.is_true(continuous.player_restricted(0, "cannot_conduct_battle_phase"),
		"a player-level restriction reads back")
	t.is_false(continuous.player_restricted(1, "cannot_conduct_battle_phase"),
		"and is per-player")
	t.is_true(engine.state.player(0).restrictions.has(
		ContinuousEffects.PLAYER_KEY_PREFIX + "cannot_conduct_battle_phase"),
		"it is stored under the continuous: namespace so recompute can find it again")

	engine.state.player(0).set_restriction("skip_battle_phase_this_turn", true)
	continuous.recompute()
	t.is_false(continuous.player_restricted(0, "cannot_conduct_battle_phase"),
		"a continuous player restriction with no live source is cleared")
	t.is_true(bool(engine.state.player(0).get_restriction(
		"skip_battle_phase_this_turn", false)),
		"restrictions outside that namespace are left alone")

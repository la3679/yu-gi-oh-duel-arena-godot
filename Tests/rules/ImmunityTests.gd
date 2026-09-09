class_name ImmunityTests
extends RefCounted

## "…unaffected by the effects of cards other than this card." — the generic gate.
##
## Rules under test: RULES_SPEC.md 18, CARD_RULINGS.md R12. Written BEFORE
## `The Monarchs Awaken` existed and from synthetic cards only, the way `EquipTests`,
## `ControlTests`, `MovementTests`, `DeckAccessTests` and `CostLegalityTests` were — so the
## card, when it arrives, consumes a subsystem that is already green.
##
## **Why this is its own suite and not part of `ContinuousTests`.** §8 asked for the
## operation to go where its subsystem already lives, and the verified ruling says this one
## does not live in the continuous layer. `unaffected_by_effects` is a per-instance field
## whose official duration is "as long as the monster is face-up in the Monster Zone", with
## no condition on the source at all — `The Monarchs Awaken` is a Normal Trap that is in the
## Graveyard before the state ever matters (R12 Part D). A `ContinuousEffects` restriction
## flag is wiped and rebuilt on every recompute and would switch off instantly. What the
## gate actually is, is a check consulted by `GameState`'s mutation entry points and by
## `CardInstance`'s stat modifiers, across the whole engine. That is not the continuous
## layer, so it gets its own file.
##
## The three things these tests must prove, in §8's words: that an immune monster is
## **untouched by each category of effect the ruling names**, that it is **still touched by
## everything the ruling does not name**, and that **the source's own effects still reach
## it**. The second is the half that is easy to skip and is where the real bugs would be:
## "unaffected" in English is far broader than the rule.
##
## **A note on sides.** Several tests have the immune monster's OWN controller try to affect
## it. That is not sloppiness: the immunity is relative to a card, not to a player. "Cards
## other than this card" includes your own, and a gate that keyed on the controller instead
## of on the source instance would pass a suite that only ever attacked from across the
## table. The cross-side cases are covered too, by handing the turn over first, because the
## engine only offers `get_legal_actions()` to the turn player.


static func run() -> TestCase:
	var t := TestCase.new("ImmunityTests")

	# --- the gate itself -------------------------------------------------
	_test_grant_requires_face_up_on_the_field(t)
	_test_the_predicate_is_relative_to_a_source(t)
	_test_the_rules_are_never_blocked(t)
	_test_exemption_is_per_instance_not_per_card_name(t)

	# --- what it blocks --------------------------------------------------
	_test_destruction_by_effect_is_blocked(t)
	_test_banish_by_effect_is_blocked(t)
	_test_bounce_by_effect_is_blocked(t)
	_test_send_to_gy_by_effect_is_blocked(t)
	_test_control_change_is_blocked(t)
	_test_stat_modifiers_are_blocked(t)
	_test_position_change_by_effect_is_blocked(t)
	_test_negation_by_another_card_is_blocked(t)
	_test_restrictions_from_another_card_are_blocked(t)
	_test_a_protection_from_another_card_is_refused_too(t)
	_test_counters_from_another_card_are_blocked(t)
	_test_a_counted_prevention_is_not_spent(t)
	_test_a_destruction_replacement_does_not_fire(t)

	# --- what it does NOT block ------------------------------------------
	_test_targeting_is_not_blocked(t)
	_test_the_effect_still_activates_and_resolves(t)
	_test_other_parts_of_the_same_effect_still_apply(t)
	_test_the_exempt_source_still_reaches_it(t)
	_test_battle_destruction_is_not_blocked(t)
	_test_a_tribute_cost_is_not_blocked(t)
	_test_an_effect_that_already_applied_is_not_undone(t)

	# --- lifetime --------------------------------------------------------
	_test_leaving_the_field_clears_it(t)
	_test_flipped_face_down_clears_it(t)
	_test_it_does_not_come_back_when_flipped_face_up_again(t)
	_test_it_survives_a_control_change(t)
	_test_it_survives_into_later_turns(t)

	# --- chain and replay ------------------------------------------------
	_test_chain_resolution_applies_only_the_unblocked_link(t)
	_test_the_gate_is_deterministic_under_replay(t)

	# --- "Tribute Summoned", R12 Part F ----------------------------------
	_test_tribute_summon_records_the_property(t)
	_test_tribute_set_records_it_while_still_face_down(t)
	_test_it_survives_face_down_and_back(t)
	_test_it_survives_a_temporary_banishment(t)
	_test_leaving_the_field_clears_the_tribute_property(t)
	_test_a_summon_without_tributes_does_not_record_it(t)

	return t


# ---------------------------------------------------------------------------
# Synthetic cards
# ---------------------------------------------------------------------------

## A Trap that grants the immunity to one named card, exempting itself. This is the shape
## `The Monarchs Awaken` will have, with none of its conditions — the gate must work before
## any of them exist.
static func _granter(card_name: String, victim: CardInstance) -> CardDef:
	var d := TestFixtures.trap(card_name)
	var e := EffectDef.new("grant_immunity", "Test: that card is unaffected by others.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		EffectImmunity.grant(victim, ctx.source)
	return TestFixtures.with_effect(d, e)


## A Trap that changes one named monster's ATK and DEF by `amount`.
static func _stat_changer(card_name: String, victim: CardInstance,
		amount: int) -> CardDef:
	var d := TestFixtures.trap(card_name)
	var e := EffectDef.new("stat", "Test: that monster gains/loses ATK and DEF.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		victim.add_atk_modifier(ctx.source.id, amount, "until_end_of_turn")
		victim.add_def_modifier(ctx.source.id, amount, "until_end_of_turn")
	return TestFixtures.with_effect(d, e)


## A Trap that puts `amount` counters of `kind` on one named card.
static func _counter_placer(card_name: String, victim: CardInstance, kind: String,
		amount: int) -> CardDef:
	var d := TestFixtures.trap(card_name)
	var e := EffectDef.new("counters", "Test: place counters on that card.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		ctx.state.place_counters(victim, kind, amount, ctx.source.id)
	return TestFixtures.with_effect(d, e)


## A Trap whose ONE effect does two things: it modifies the immune monster's ATK (blocked)
## and a bystander's ATK (not blocked). Official Q&A fid 13065's shape exactly — one effect,
## two sub-processes, opposite answers.
static func _two_part_effect(card_name: String, blocked: CardInstance,
		bystander: CardInstance, amount: int) -> CardDef:
	var d := TestFixtures.trap(card_name)
	var e := EffectDef.new("two_part", "Test: change ATK of two monsters.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		blocked.add_atk_modifier(ctx.source.id, amount, "until_end_of_turn")
		bystander.add_atk_modifier(ctx.source.id, amount, "until_end_of_turn")
	return TestFixtures.with_effect(d, e)


## A Trap that TARGETS 1 monster its controller's OPPONENT controls and destroys it. Proves
## that targeting an immune monster is legal even though the destruction will not apply.
static func _targeting_destroyer(card_name: String) -> CardDef:
	var d := TestFixtures.trap(card_name)
	var e := EffectDef.new("target_destroy", "Test: target 1 monster; destroy it.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.opponent_monsters(ctx)
	e.resolve = func(ctx: EffectContext) -> void:
		var target = ctx.first_target()
		if target != null:
			ctx.state.destroy(target, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)
	return TestFixtures.with_effect(d, e)


## A face-up Continuous Trap that negates the effects of, and locks down, every monster its
## controller's OPPONENT controls. The continuous layer is re-applied on every recompute,
## which is exactly why an immune monster must keep refusing it recompute after recompute.
static func _opposing_lockdown(card_name: String) -> CardDef:
	var d := TestFixtures.trap(card_name, Enums.STKind.CONTINUOUS_TRAP)
	var e := EffectDef.new("lockdown",
		"Test: opponent's monsters have their effects negated and cannot attack.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.negates_effects = true
	e.apply_continuous = func(ctx: EffectContext) -> void:
		for m in ctx.opponent().monsters():
			ContinuousEffects.negate_effects(m, ctx.source)
			ContinuousEffects.restrict(m, "cannot_attack", ctx.source)
	return TestFixtures.with_effect(d, e)


## A face-up Continuous Spell carrying a COUNTED destruction-prevention clause — the
## `Gagagashield` shape: "Twice per turn, it cannot be destroyed by battle or card effects."
##
## `uses_per_turn` is what makes it a probe rather than a protection: the rules layer spends
## a use whenever the clause actually answers "yes", so counting the uses afterwards says
## whether the destruction was ever put to it. R12 Part B — an immune monster is not
## *protected from* a destroying effect, the effect never applies to it at all, so nothing
## may be spent on its behalf.
static func _counted_protector(card_name: String, victim: CardInstance,
		uses: int) -> CardDef:
	var d := TestFixtures.spell(card_name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"Test: twice per turn, that monster cannot be destroyed.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.uses_per_turn = uses
	e.condition = func(ctx: EffectContext) -> bool:
		var target = ctx.params.get("card", null)
		return target != null and (target as CardInstance).id == victim.id
	return TestFixtures.with_effect(d, e)


## A face-up Continuous Spell that is destroyed INSTEAD of one named monster — the
## `Rider of the Storm Winds` shape. If it ever reaches the Graveyard, a destruction that
## should never have been attempted was attempted.
static func _destruction_substitute(card_name: String, victim: CardInstance) -> CardDef:
	var d := TestFixtures.spell(card_name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new(GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID,
		"Test: destroy this card instead of that monster.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.destruction_substitute = func(ctx: EffectContext):
		var target = ctx.params.get("card", null)
		if target == null or (target as CardInstance).id != victim.id:
			return null
		return ctx.source
	return TestFixtures.with_effect(d, e)


## A face-up Continuous Spell that PROTECTS every monster its controller's opponent
## controls from battle destruction. A benefit — and an immune monster must not get it.
## This is official Q&A fid 18199 in miniature.
static func _opposing_protector(card_name: String) -> CardDef:
	var d := TestFixtures.spell(card_name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new("protect_them",
		"Test: opponent's monsters cannot be destroyed by battle.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		for m in ctx.opponent().monsters():
			ContinuousEffects.restrict(m, "cannot_be_destroyed_by_battle", ctx.source)
	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Shared arrangement
# ---------------------------------------------------------------------------

## Player 0, in Main Phase 1 of their own turn, controls one monster; the Trap that will
## make it immune is Set for player 0. Returns {engine, monster, granter}.
static func _immune_board(seed_value: int, atk: int = 1800,
		def_: int = 1500) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Warded Monarch", 6, atk, def_))
	var granter := TestFixtures.give_set_spell_trap(engine, 0, _granter("Warding", mon))
	return {"engine": engine, "monster": mon, "granter": granter}


## The same, with the immunity already applied. Asserts the grant took, so no later test can
## pass vacuously against a monster that was never made immune.
static func _made_immune(t: TestCase, seed_value: int, atk: int = 1800,
		def_: int = 1500) -> Dictionary:
	var b := _immune_board(seed_value, atk, def_)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	t.is_true(TestFixtures.activate_card(engine, 0, b["granter"]),
		"the granting card resolves")
	t.is_true(mon.unaffected_by_effects,
		"and the monster really is immune — this arrangement is not vacuous")
	return b


## Hand the turn to player 1 and stop in their Main Phase 1, so they can act through
## `get_legal_actions()`. The engine only offers those to the turn player.
static func _give_turn_to_opponent(t: TestCase, engine: DuelEngine) -> void:
	t.is_true(TestFixtures.end_turn(engine), "the turn passes to the opponent")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"and reaches their Main Phase 1")
	t.eq(engine.state.turn_player_id, 1, "the opponent is now the turn player")


# ---------------------------------------------------------------------------
# The gate itself
# ---------------------------------------------------------------------------

static func _test_grant_requires_face_up_on_the_field(t: TestCase) -> void:
	t.start("the immunity is not applied to a card that is face-down, or not on the field")
	var d := TestFixtures.new_duel(9101, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give(engine, 0, TestFixtures.trap("Source"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Hidden", 4, 1000, 1000),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_false(EffectImmunity.grant(face_down, source),
		"a face-down monster is refused — the supplement's resolution-time gate")
	t.is_false(face_down.unaffected_by_effects, "and nothing was written")

	var in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("In Hand", 4, 1000, 1000))
	t.is_false(EffectImmunity.grant(in_hand, source), "a card in the hand is refused")
	t.is_false(in_hand.unaffected_by_effects, "and nothing was written")

	var face_up := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Open", 4, 1000, 1000))
	t.is_true(EffectImmunity.grant(face_up, source),
		"a face-up monster on the field is accepted")
	t.is_true(face_up.unaffected_by_effects, "and the state is written")


static func _test_the_predicate_is_relative_to_a_source(t: TestCase) -> void:
	t.start("the immunity is always relative to a SOURCE — the granting card is exempt")
	var b := _made_immune(t, 9102)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var granter: CardInstance = b["granter"]
	var stranger := TestFixtures.give(engine, 1, TestFixtures.trap("Stranger"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	t.is_true(mon.is_unaffected_by_effect_of(stranger.id),
		"another card's effects do not reach it")
	t.is_false(mon.is_unaffected_by_effect_of(granter.id),
		"the card that granted the immunity still does — 'other than THIS card'")
	t.eq(mon.unaffected_exempt_source_ids, [granter.id],
		"and the exemption is recorded as that one instance id")


static func _test_the_rules_are_never_blocked(t: TestCase) -> void:
	t.start("a source id of -1 means the game rules, which no immunity answers")
	var b := _made_immune(t, 9103)
	var mon: CardInstance = b["monster"]
	t.is_false(mon.is_unaffected_by_effect_of(-1),
		"the rules are not a card and are never blocked")
	t.is_false(EffectImmunity.blocks(mon, -1), "asked through the gate as well")


static func _test_exemption_is_per_instance_not_per_card_name(t: TestCase) -> void:
	t.start("the exemption names one INSTANCE, not a card name — a second copy of the "
		+ "same card is still blocked")
	var b := _made_immune(t, 9104)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var granter: CardInstance = b["granter"]

	# A second copy of the very same printed card, controlled by the opponent.
	var other_copy := TestFixtures.give(engine, 1, granter.definition,
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.ne(other_copy.id, granter.id, "it is a different instance")
	t.eq(other_copy.card_name(), granter.card_name(), "of the same printed card")
	t.is_false(mon.is_unaffected_by_effect_of(granter.id),
		"the instance that granted the state is exempt")
	t.is_true(mon.is_unaffected_by_effect_of(other_copy.id),
		"a different instance of the same card is NOT exempt")


# ---------------------------------------------------------------------------
# What it blocks
# ---------------------------------------------------------------------------

## Set an interferer for player 0 against their own immune monster and activate it. Player 0
## is the turn player throughout `_immune_board`, and the immunity is source-relative rather
## than side-relative, so this is a legitimate — and stricter — way to exercise the gate.
static func _own_side_interferer(t: TestCase, engine: DuelEngine, victim: CardInstance,
		mode: String) -> CardInstance:
	var card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Interferer", victim, mode))
	t.is_true(TestFixtures.activate_card(engine, 0, card),
		"the '%s' effect is activated and resolves" % mode)
	t.eq(card.zone, Enums.Zone.GRAVEYARD,
		"the interfering card was spent — it resolved rather than fizzling")
	return card


static func _test_destruction_by_effect_is_blocked(t: TestCase) -> void:
	t.start("an effect cannot DESTROY an immune monster")
	var b := _made_immune(t, 9110)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	_own_side_interferer(t, engine, mon, "destroy")

	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster is still on the field")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, mon.id), 0,
		"and no destruction event was raised for it")


static func _test_banish_by_effect_is_blocked(t: TestCase) -> void:
	t.start("an effect cannot BANISH an immune monster")
	var b := _made_immune(t, 9111)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	_own_side_interferer(t, engine, mon, "banish")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster did not go to the Banished zone")


static func _test_bounce_by_effect_is_blocked(t: TestCase) -> void:
	t.start("an effect cannot RETURN an immune monster to the hand")
	var b := _made_immune(t, 9112)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	_own_side_interferer(t, engine, mon, "bounce")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster is still on the field")


static func _test_send_to_gy_by_effect_is_blocked(t: TestCase) -> void:
	t.start("an effect cannot SEND an immune monster to the Graveyard")
	var b := _made_immune(t, 9113)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	_own_side_interferer(t, engine, mon, "send_to_gy")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster is still on the field")


static func _test_control_change_is_blocked(t: TestCase) -> void:
	t.start("an effect cannot take CONTROL of an immune monster")
	var b := _made_immune(t, 9114)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var thief := TestFixtures.give(engine, 1, TestFixtures.trap("Thief"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	t.is_false(engine.state.change_control(mon, 1, thief.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "the control change is refused")
	t.eq(mon.controller_id, 0, "control did not move")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CONTROL_CHANGED, mon.id), 0,
		"and no control-change event was raised")

	# The same call against an ordinary monster succeeds, so the refusal above is the
	# immunity and not a broken arrangement.
	var ordinary := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Ordinary", 4, 1000, 1000))
	t.is_true(engine.state.change_control(ordinary, 1, thief.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "an ordinary monster is taken")
	t.eq(ordinary.controller_id, 1, "and really changes side")


static func _test_stat_modifiers_are_blocked(t: TestCase) -> void:
	t.start("an effect cannot change an immune monster's ATK or DEF")
	var b := _made_immune(t, 9115, 1800, 1500)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var debuff := TestFixtures.give_set_spell_trap(engine, 0,
		_stat_changer("Weaken", mon, -1000))

	t.is_true(TestFixtures.activate_card(engine, 0, debuff), "the effect resolves")
	t.eq(mon.current_atk(), 1800, "ATK is untouched")
	t.eq(mon.current_def(), 1500, "DEF is untouched")
	t.eq(mon.atk_modifiers.size(), 0, "and no ATK modifier was recorded at all")
	t.eq(mon.def_modifiers.size(), 0, "nor a DEF one")


static func _test_position_change_by_effect_is_blocked(t: TestCase) -> void:
	t.start("an effect cannot change an immune monster's battle position")
	var b := _made_immune(t, 9116)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	_own_side_interferer(t, engine, mon, "flip_face_down")

	t.eq(mon.position, Enums.Position.FACE_UP_ATTACK, "the position is unchanged")
	t.is_true(mon.unaffected_by_effects,
		"and the immunity was not switched off by a flip that never happened")


static func _test_negation_by_another_card_is_blocked(t: TestCase) -> void:
	t.start("another card cannot NEGATE an immune monster's effects")
	var b := _made_immune(t, 9117)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]

	# A bystander with no immunity, to prove the lockdown really works on a normal monster.
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1200, 1200))
	TestFixtures.give(engine, 1, _opposing_lockdown("Lockdown"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()

	t.is_true(bystander.effects_are_negated(),
		"the lockdown negates an ordinary monster — the arrangement is live")
	t.is_true(bystander.flags.has("cannot_attack"), "and locks it down")
	t.is_false(mon.effects_are_negated(), "but the immune monster is not negated")
	t.is_false(mon.flags.has("cannot_attack"), "and the attack lock did not land either")


static func _test_restrictions_from_another_card_are_blocked(t: TestCase) -> void:
	t.start("another card cannot set a RESTRICTION flag on an immune monster, and it "
		+ "stays refused across repeated recomputes")
	var b := _made_immune(t, 9118)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	TestFixtures.give(engine, 1, _opposing_lockdown("Lockdown"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	for i in range(5):
		engine.continuous.recompute()
	t.is_false(mon.flags.has("cannot_attack"),
		"five recomputes do not sneak the flag on — the gate is asked every time")
	t.is_false(mon.effects_are_negated(), "and neither does the negation")


static func _test_a_protection_from_another_card_is_refused_too(t: TestCase) -> void:
	t.start("an immune monster refuses a BENEFIT as well — it is a shield, not a blessing")
	var b := _made_immune(t, 9119)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))

	TestFixtures.give(engine, 1, _opposing_protector("Kindness"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()

	t.is_true(bystander.flags.has("cannot_be_destroyed_by_battle"),
		"the ordinary monster receives the protection — the source really is applying")
	t.is_false(mon.flags.has("cannot_be_destroyed_by_battle"),
		"the immune monster does not receive it, though it would have helped")


static func _test_counters_from_another_card_are_blocked(t: TestCase) -> void:
	t.start("an effect cannot place COUNTERS on an immune monster")
	var b := _made_immune(t, 9120)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var placer := TestFixtures.give_set_spell_trap(engine, 0,
		_counter_placer("Placer", mon, "Test Counter", 2))

	t.is_true(TestFixtures.activate_card(engine, 0, placer), "the effect resolves")
	t.eq(mon.counter_count("Test Counter"), 0, "no counters were placed")


static func _test_a_counted_prevention_is_not_spent(t: TestCase) -> void:
	t.start("a COUNTED destruction-prevention effect is not spent on an immune monster — "
		+ "the destroying effect never applied, so there was nothing to prevent")
	var b := _made_immune(t, 9121)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var shield := TestFixtures.give(engine, 0, _counted_protector("Shield", mon, 2),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	var prevention_id := GameState.DESTRUCTION_PREVENTION_EFFECT_ID
	var turn := engine.state.turn_number
	t.eq(shield.uses_this_turn(prevention_id, turn), 0, "no uses spent yet")

	_own_side_interferer(t, engine, mon, "destroy")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster survived")
	t.eq(shield.uses_this_turn(prevention_id, turn), 0,
		"and the counted prevention was NOT spent — the immunity answered first")

	# The control: the very same shield IS spent for an ordinary monster, so the assertion
	# above is not passing because the probe never fires at all.
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	var guard := TestFixtures.give(engine, 0,
		_counted_protector("Shield B", bystander, 2),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	_own_side_interferer(t, engine, bystander, "destroy")
	t.eq(bystander.zone, Enums.Zone.MONSTER_ZONE, "the bystander was protected instead")
	t.eq(guard.uses_this_turn(prevention_id, engine.state.turn_number), 1,
		"and its prevention WAS spent — so the probe really does count")


static func _test_a_destruction_replacement_does_not_fire(t: TestCase) -> void:
	t.start("a destruction REPLACEMENT effect does not fire for an immune monster — no "
		+ "substitute is destroyed in place of a destruction that never applied")
	var b := _made_immune(t, 9122)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var substitute := TestFixtures.give(engine, 0, _destruction_substitute("Scapegoat", mon),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	_own_side_interferer(t, engine, mon, "destroy")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster survived")
	t.eq(substitute.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"and nothing was destroyed in its place")

	# The control: the same substitute IS consumed for an ordinary monster.
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	var scapegoat := TestFixtures.give(engine, 0,
		_destruction_substitute("Scapegoat B", bystander),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	_own_side_interferer(t, engine, bystander, "destroy")
	t.eq(bystander.zone, Enums.Zone.MONSTER_ZONE, "the bystander was substituted for")
	t.eq(scapegoat.zone, Enums.Zone.GRAVEYARD,
		"and the substitute really was destroyed — so the mechanism does fire")


# ---------------------------------------------------------------------------
# What it does NOT block — the half that is easy to get wrong
# ---------------------------------------------------------------------------

static func _test_targeting_is_not_blocked(t: TestCase) -> void:
	t.start("an immune monster can still be TARGETED — immunity is not targeting "
		+ "protection (official Q&A fid 13065)")
	var b := _made_immune(t, 9130)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	TestFixtures.give_set_spell_trap(engine, 1, _targeting_destroyer("Sniper"))
	_give_turn_to_opponent(t, engine)

	var action = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(action, "the targeting card can be activated")
	if action == null:
		return
	t.is_true(action.target_candidates.has(mon.id),
		"and the immune monster is offered as a legal target")
	t.eq(action.target_candidates.size(), 1,
		"it is the only monster on that side of the field, so the list is not a "
		+ "catch-all that would pass whatever the gate did")


static func _test_the_effect_still_activates_and_resolves(t: TestCase) -> void:
	t.start("the effect targeting an immune monster still activates and still RESOLVES — "
		+ "only the application to that monster is skipped")
	var b := _made_immune(t, 9131)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var sniper := TestFixtures.give_set_spell_trap(engine, 1,
		_targeting_destroyer("Sniper"))
	_give_turn_to_opponent(t, engine)

	var action = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, sniper.id)
	t.not_null(action, "the card is activatable")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"target_ids": [mon.id]})),
		"targeting the immune monster is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the monster was not destroyed")
	t.eq(sniper.zone, Enums.Zone.GRAVEYARD,
		"but the Trap was spent — it resolved, it did not fizzle")


static func _test_other_parts_of_the_same_effect_still_apply(t: TestCase) -> void:
	t.start("one effect, two sub-processes: the one aimed at the immune monster is "
		+ "skipped and the one aimed elsewhere still applies (fid 13065)")
	var b := _made_immune(t, 9132, 1800, 1500)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1200, 1200))
	var both := TestFixtures.give_set_spell_trap(engine, 0,
		_two_part_effect("Both", mon, bystander, -900))

	t.is_true(TestFixtures.activate_card(engine, 0, both), "the effect resolves")
	t.eq(mon.current_atk(), 1800, "the immune monster's ATK is untouched")
	t.eq(bystander.current_atk(), 300,
		"and the very same effect still hit the monster that is not immune")


static func _test_the_exempt_source_still_reaches_it(t: TestCase) -> void:
	t.start("the card that granted the immunity still affects the monster — including "
		+ "from the Graveyard, where a Normal Trap already is")
	var b := _made_immune(t, 9133, 1800, 1500)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var granter: CardInstance = b["granter"]
	t.eq(granter.zone, Enums.Zone.GRAVEYARD,
		"the Normal Trap resolved and is in the Graveyard")

	# Everything the gate blocks for a stranger, applied by the exempt source instead.
	mon.add_atk_modifier(granter.id, -500, "until_end_of_turn")
	t.eq(mon.current_atk(), 1300, "its ATK modifier applies")
	t.is_true(ContinuousEffects.negate_effects(mon, granter),
		"it can negate the monster's effects")
	t.is_true(engine.state.place_counters(mon, "Test Counter", 1, granter.id),
		"it can place counters on it")
	t.is_true(engine.state.destroy(mon, Enums.MoveReason.DESTROYED_BY_EFFECT, granter.id),
		"and it can destroy it")
	t.eq(mon.zone, Enums.Zone.GRAVEYARD, "which really happened")


static func _test_battle_destruction_is_not_blocked(t: TestCase) -> void:
	t.start("an immune monster is destroyed by BATTLE exactly as normal (fid 18199)")
	var d := TestFixtures.new_duel(9134, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var weak := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Warded Weakling", 4, 1000, 1000))
	var granter := TestFixtures.give_set_spell_trap(engine, 0, _granter("Warding", weak))
	t.is_true(TestFixtures.activate_card(engine, 0, granter), "the immunity is applied")
	t.is_true(weak.unaffected_by_effects, "and it took")

	var attacker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Attacker", 6, 2400, 2000))
	t.is_true(TestFixtures.end_turn(engine), "the turn passes to the opponent")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"who reaches their Battle Phase")
	t.is_true(TestFixtures.attack(engine, attacker, weak),
		"and attacks the immune monster")
	TestFixtures.pass_until_open(engine)

	t.eq(weak.zone, Enums.Zone.GRAVEYARD,
		"battle is not a card effect, so the immunity does not save it")
	t.eq(weak.last_move_reason, Enums.MoveReason.DESTROYED_BY_BATTLE,
		"recorded with the battle reason")


static func _test_a_tribute_cost_is_not_blocked(t: TestCase) -> void:
	t.start("an immune monster can still be TRIBUTED — a cost is not an effect applied "
		+ "to it (official Q&A fid 298)")
	var b := _made_immune(t, 9135)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Tribute Eater", 6, 2400, 2000))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, big.id)
	t.not_null(action, "a Tribute Summon over it is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [mon.id]})),
		"and Tributing the immune monster is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(mon.zone, Enums.Zone.GRAVEYARD, "it really was Tributed")
	t.eq(mon.last_move_reason, Enums.MoveReason.TRIBUTED,
		"as a Tribute, which is not a destruction and not an effect [S1 p.53]")


static func _test_an_effect_that_already_applied_is_not_undone(t: TestCase) -> void:
	t.start("an effect that had ALREADY applied before the immunity began is not undone "
		+ "by it (official Q&A fid 13085 / fid 16491)")
	var d := TestFixtures.new_duel(9136, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Warded", 4, 1000, 1000))

	# The debuff lands FIRST, while the monster is an ordinary monster.
	var debuff := TestFixtures.give_set_spell_trap(engine, 0,
		_stat_changer("Weaken", mon, -400))
	t.is_true(TestFixtures.activate_card(engine, 0, debuff), "the debuff resolves first")
	t.eq(mon.current_atk(), 600, "and applies")

	var granter := TestFixtures.give_set_spell_trap(engine, 0, _granter("Warding", mon))
	t.is_true(TestFixtures.activate_card(engine, 0, granter),
		"then the immunity is applied")
	t.is_true(mon.unaffected_by_effects, "and it took")

	t.eq(mon.current_atk(), 600,
		"the modifier that had already applied is still there — not retroactive")
	t.eq(mon.atk_modifiers.size(), 1, "and it was not silently dropped")


# ---------------------------------------------------------------------------
# Lifetime — "as long as it is face-up in the Monster Zone"
# ---------------------------------------------------------------------------

static func _test_leaving_the_field_clears_it(t: TestCase) -> void:
	t.start("the immunity ends when the monster leaves the Monster Zone")
	var b := _made_immune(t, 9140)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]

	# Through a route the immunity does not block: a Tribute.
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Tribute Eater", 6, 2400, 2000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, big.id)
	t.not_null(action, "a Tribute Summon is available")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [mon.id]})),
		"the immune monster is Tributed")
	TestFixtures.pass_until_open(engine)

	t.is_false(mon.unaffected_by_effects, "the immunity is gone")
	t.eq(mon.unaffected_exempt_source_ids, [], "and so is the exemption record")


static func _test_flipped_face_down_clears_it(t: TestCase) -> void:
	t.start("the immunity ends when the monster stops being face-up")
	var b := _made_immune(t, 9141)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	mon.effects_negated = true

	# The rules route, not an effect: an effect flip is blocked by the immunity itself.
	engine.state.set_battle_position(mon, Enums.Position.FACE_DOWN_DEFENSE, false)
	t.is_false(mon.unaffected_by_effects, "the immunity is gone")
	t.is_false(mon.effects_negated, "and so is the negation that came with it")
	t.eq(mon.unaffected_exempt_source_ids, [], "and the exemption record is cleared")


static func _test_it_does_not_come_back_when_flipped_face_up_again(t: TestCase) -> void:
	t.start("once an end condition is met the state is GONE — flipping the monster "
		+ "face-up again does not restore it")
	var b := _made_immune(t, 9142)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]

	engine.state.set_battle_position(mon, Enums.Position.FACE_DOWN_DEFENSE, false)
	t.is_false(mon.unaffected_by_effects, "gone while face-down")
	engine.state.set_battle_position(mon, Enums.Position.FACE_UP_ATTACK, false)
	t.is_true(mon.is_face_up(), "the monster is face-up again")
	t.is_false(mon.unaffected_by_effects, "and the immunity did NOT come back")

	# And it is genuinely vulnerable again, not merely flagged as such.
	var killer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Killer", mon, "destroy"))
	t.is_true(TestFixtures.activate_card(engine, 0, killer), "an effect destroys it")
	t.eq(mon.zone, Enums.Zone.GRAVEYARD, "which now works")


static func _test_it_survives_a_control_change(t: TestCase) -> void:
	t.start("a control change is NOT an end condition — the monster has not left the "
		+ "Monster Zone and has not stopped being face-up")
	var b := _made_immune(t, 9143)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var granter: CardInstance = b["granter"]

	# Moved by the EXEMPT source, which is the only card that can move it at all.
	t.is_true(engine.state.change_control(mon, 1, granter.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "the exempt source moves control")
	t.eq(mon.controller_id, 1, "control really moved")
	t.is_true(mon.unaffected_by_effects, "and the immunity survived the move")
	t.eq(mon.unaffected_exempt_source_ids, [granter.id],
		"the exemption still names the same instance")

	# Still immune to a stranger under its new controller.
	var stranger := TestFixtures.give(engine, 0, TestFixtures.trap("Stranger"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.is_false(engine.state.destroy(mon, Enums.MoveReason.DESTROYED_BY_EFFECT,
		stranger.id), "another card still cannot destroy it")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "and it is still on the field")


static func _test_it_survives_into_later_turns(t: TestCase) -> void:
	t.start("the immunity has no turn limit — it is still there two turns later")
	var b := _made_immune(t, 9144)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var killer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Killer", mon, "destroy"))

	_give_turn_to_opponent(t, engine)
	t.is_true(mon.unaffected_by_effects, "still immune on the opponent's turn")
	t.is_true(TestFixtures.activate_card(engine, 1, killer),
		"the opponent's effect is activated and resolves")
	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "and still cannot destroy it")

	t.is_true(TestFixtures.end_turn(engine), "the turn passes back")
	t.eq(engine.state.turn_player_id, 0, "to the immune monster's controller")
	t.is_true(mon.unaffected_by_effects, "and it is still immune a full turn later")


# ---------------------------------------------------------------------------
# Chain and replay
# ---------------------------------------------------------------------------

static func _test_chain_resolution_applies_only_the_unblocked_link(t: TestCase) -> void:
	t.start("on a Chain, the link aimed at the immune monster does nothing and the link "
		+ "aimed at a bystander still resolves normally")
	var b := _made_immune(t, 9150)
	var engine: DuelEngine = b["engine"]
	var mon: CardInstance = b["monster"]
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1200, 1200))

	# Chain Link 1 belongs to the turn player (the opponent, after the handover); Chain
	# Link 2 is player 0's response. Only the turn player is offered a free activation.
	var kill_immune := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Killer A", mon, "destroy"))
	var kill_bystander := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Killer B", bystander, "destroy"))
	_give_turn_to_opponent(t, engine)

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, kill_immune.id)
	t.not_null(a, "Chain Link 1 is available to the turn player")
	if a == null:
		return
	t.is_true(engine.submit_action(a), "Chain Link 1 is activated")

	var b2 = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, kill_bystander.id)
	t.not_null(b2, "Chain Link 2 is available in response")
	if b2 == null:
		return
	t.is_true(engine.submit_action(b2), "Chain Link 2 is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(mon.zone, Enums.Zone.MONSTER_ZONE, "the immune monster survived its link")
	t.eq(bystander.zone, Enums.Zone.GRAVEYARD, "the bystander did not survive its own")
	t.eq(kill_immune.zone, Enums.Zone.GRAVEYARD,
		"and the blocked link's card was still spent — it resolved")


static func _test_the_gate_is_deterministic_under_replay(t: TestCase) -> void:
	t.start("two duels from the same seed take the same actions and reach the same "
		+ "immunity state, event for event")
	var results: Array = []
	for run in range(2):
		var b := _immune_board(9160)
		var engine: DuelEngine = b["engine"]
		var mon: CardInstance = b["monster"]
		TestFixtures.activate_card(engine, 0, b["granter"])
		var killer := TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.interferer("Killer", mon, "destroy"))
		TestFixtures.activate_card(engine, 0, killer)
		results.append({
			"immune": mon.unaffected_by_effects,
			"zone": mon.zone,
			"exempt": mon.unaffected_exempt_source_ids.size(),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["immune"], results[1]["immune"], "the immunity state matches")
	t.eq(results[0]["zone"], results[1]["zone"], "the monster's zone matches")
	t.eq(results[0]["exempt"], results[1]["exempt"], "the exemption record matches")
	t.eq(results[0]["events"], results[1]["events"], "and the event count matches")
	t.is_true(bool(results[0]["immune"]),
		"and the run was not vacuous — the monster really was immune")
	t.eq(results[0]["zone"], Enums.Zone.MONSTER_ZONE,
		"and really did survive the destruction attempt")


# ---------------------------------------------------------------------------
# "Tribute Summoned" — CARD_RULINGS.md R12 Part F
# ---------------------------------------------------------------------------

static func _main_phase_duel(seed_value: int) -> DuelEngine:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	return engine


static func _tribute_summon(t: TestCase, engine: DuelEngine, pid: int,
		big: CardInstance, fodder: CardInstance) -> bool:
	var action = TestFixtures.find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.TRIBUTE_SUMMON, big.id)
	t.not_null(action, "the Tribute Summon is offered")
	if action == null:
		return false
	var ok: bool = engine.submit_action(action.with_choices({"tribute_ids": [fodder.id]}))
	TestFixtures.pass_until_open(engine)
	return ok


static func _test_tribute_summon_records_the_property(t: TestCase) -> void:
	t.start("a Tribute Summon records 'Tribute Summoned' on the monster")
	var engine := _main_phase_duel(9170)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	t.is_false(big.was_tribute_summoned(), "not while it is still in the hand")
	t.is_true(_tribute_summon(t, engine, 0, big, fodder), "and is accepted")
	t.is_true(big.was_tribute_summoned(), "the property is recorded")
	t.eq(big.summoned_by, Enums.SummonKind.TRIBUTE, "alongside the summon kind")


static func _test_tribute_set_records_it_while_still_face_down(t: TestCase) -> void:
	t.start("a Tribute SET counts as 'Tribute Summoned' immediately, while the monster is "
		+ "still face-down (official Q&A fid 20548 / fid 20533)")
	var engine := _main_phase_duel(9171)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SET, big.id)
	t.not_null(action, "a Tribute Set is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action.with_choices({"tribute_ids": [fodder.id]})),
		"and is accepted")
	TestFixtures.pass_until_open(engine)

	t.is_true(big.is_face_down(), "the monster is face-down")
	t.eq(big.summoned_by, Enums.SummonKind.TRIBUTE_SET, "recorded as a Tribute Set")
	t.is_true(big.was_tribute_summoned(),
		"and it already counts as Tribute Summoned — it does not wait for the flip")

	# And it still counts after the flip, where `summoned_by` becomes FLIP.
	t.is_true(TestFixtures.end_turn(engine), "the turn passes")
	t.is_true(TestFixtures.end_turn(engine), "and comes back")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"reaching Main Phase 1 again")
	var flip = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, big.id)
	t.not_null(flip, "it can be Flip Summoned on a later turn")
	if flip == null:
		return
	t.is_true(engine.submit_action(flip), "the Flip Summon is accepted")
	TestFixtures.pass_until_open(engine)
	t.eq(big.summoned_by, Enums.SummonKind.FLIP,
		"`summoned_by` is overwritten with FLIP, which is why it cannot carry this")
	t.is_true(big.was_tribute_summoned(), "but the property survives the overwrite")


static func _test_it_survives_face_down_and_back(t: TestCase) -> void:
	t.start("a Tribute Summoned monster turned face-down and back is still Tribute "
		+ "Summoned (official Q&A fid 11352)")
	var engine := _main_phase_duel(9172)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	t.is_true(_tribute_summon(t, engine, 0, big, fodder), "and is accepted")
	t.is_true(big.was_tribute_summoned(), "recorded")

	engine.state.set_battle_position(big, Enums.Position.FACE_DOWN_DEFENSE, false)
	t.is_true(big.was_tribute_summoned(), "still recorded while face-down")
	engine.state.set_battle_position(big, Enums.Position.FACE_UP_ATTACK, false)
	t.is_true(big.was_tribute_summoned(), "and still recorded after coming back face-up")


static func _test_it_survives_a_temporary_banishment(t: TestCase) -> void:
	t.start("a Tribute Summoned monster temporarily banished and returned is still "
		+ "Tribute Summoned (official Q&A fid 11352)")
	var engine := _main_phase_duel(9173)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	t.is_true(_tribute_summon(t, engine, 0, big, fodder), "and is accepted")

	var source := TestFixtures.give(engine, 0, TestFixtures.trap("Transporter"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.is_true(engine.state.banish_temporarily(big, source.id,
		Enums.BanishDuration.UNTIL_END_PHASE), "it is temporarily banished")
	t.eq(big.zone, Enums.Zone.BANISHED, "and is away")
	t.is_false(big.was_tribute_summoned(),
		"while it is away it is not on the field at all")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.END),
		"the End Phase arrives")
	t.eq(big.zone, Enums.Zone.MONSTER_ZONE, "and it comes back")
	t.is_true(big.was_tribute_summoned(),
		"still treated as Tribute Summoned, though it genuinely left the field (R30)")


static func _test_leaving_the_field_clears_the_tribute_property(t: TestCase) -> void:
	t.start("a monster that left the field PERMANENTLY is no longer Tribute Summoned")
	var engine := _main_phase_duel(9174)
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Monarch", 6, 2400, 1000))
	t.is_true(_tribute_summon(t, engine, 0, big, fodder), "and is accepted")
	t.is_true(big.was_tribute_summoned(), "recorded")

	var killer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Killer", big, "destroy"))
	t.is_true(TestFixtures.activate_card(engine, 0, killer), "an effect destroys it")
	t.eq(big.zone, Enums.Zone.GRAVEYARD, "it reached the Graveyard")
	t.is_false(big.was_tribute_summoned(), "and the property is gone")


static func _test_a_summon_without_tributes_does_not_record_it(t: TestCase) -> void:
	t.start("a Normal Summon and a Normal Set are not Tribute Summons")
	var engine := _main_phase_duel(9175)
	var small := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 1000))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, small.id)
	t.not_null(action, "a Normal Summon is offered")
	if action == null:
		return
	t.is_true(engine.submit_action(action), "and accepted")
	TestFixtures.pass_until_open(engine)
	t.is_false(small.was_tribute_summoned(),
		"a Normal Summon with no Tributes does not record the property")

	t.is_true(TestFixtures.end_turn(engine), "the turn passes")
	t.is_true(TestFixtures.end_turn(engine), "and comes back")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"reaching Main Phase 1 again")
	var other := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Recruit B", 4, 1200, 1000))
	var set_action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SET, other.id)
	t.not_null(set_action, "a Normal Set is offered")
	if set_action == null:
		return
	t.is_true(engine.submit_action(set_action), "and accepted")
	TestFixtures.pass_until_open(engine)
	t.is_false(other.was_tribute_summoned(), "and neither does a Normal Set")

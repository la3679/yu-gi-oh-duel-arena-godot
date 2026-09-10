class_name NegationImmunityTests
extends RefCounted

## The batch-18 unit B GATE. RULES_SPEC.md 19, CARD_RULINGS.md R14.
##
## "…cannot be negated", and "…cannot be targeted or destroyed by your opponent's card
## effects", applied to a PLAYER for the rest of a turn.
##
## Written and green BEFORE `Hidden Springs of the Far East` existed, and against synthetic
## cards throughout: nothing here names that card, and every function under test takes a
## player id rather than a source.
##
## **Every protection here is a VACUOUS-PATH HAZARD, and that shapes the whole suite.** A
## protection is only observable when something is actually trying to do the thing it
## prevents, so "the Summon succeeded" proves nothing on its own — it is also what an
## engine that never negates anything would report. **Every positive assertion in this file
## is therefore paired with a control proving the same action IS negated, targeted or
## destroyed without the protection.** Where a control is missing, the test is not
## measuring the gate.
##
## The three protections are tested separately because the official text separates them,
## because they are gated at three different entry points, and because each is false in
## cases where the others are true.


static func run() -> TestCase:
	var t := TestCase.new("NegationImmunityTests")
	# Bookkeeping
	_test_nothing_is_protected_by_default(t)
	_test_granting_sets_all_three_together(t)
	_test_protections_expire_at_the_end_of_the_turn(t)
	_test_a_continuous_recompute_does_not_wipe_them(t)
	# Protection 1 — Summon negation
	_test_a_normal_summon_cannot_be_negated(t)
	_test_a_tribute_summon_cannot_be_negated(t)
	_test_a_special_summon_cannot_be_negated(t)
	_test_a_FLIP_summon_is_NOT_protected(t)
	_test_only_the_protected_players_summons_are_covered(t)
	# Protection 2 — activation negation
	_test_a_special_summoning_activation_cannot_be_negated(t)
	_test_an_activation_without_a_special_summon_is_still_negatable(t)
	_test_EFFECT_negation_is_still_reachable(t)
	_test_only_the_protected_players_activations_are_covered(t)
	# Protection 3 — Set Spell/Trap targeting and destruction
	_test_a_set_spell_trap_cannot_be_targeted_by_the_opponent(t)
	_test_your_own_effects_may_still_target_your_set_cards(t)
	_test_a_face_up_spell_trap_is_NOT_protected(t)
	_test_a_monster_is_NOT_protected_by_this_clause(t)
	_test_a_set_spell_trap_cannot_be_destroyed_by_the_opponent(t)
	_test_your_own_effect_may_still_destroy_your_set_card(t)
	_test_rules_destruction_is_not_blocked(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A synthetic effect that declares whether it includes a Special Summon.
static func _activation(effect_id: String, includes_ss: bool, log: Array) -> EffectDef:
	var e := TestFixtures.card_activation(effect_id, Enums.SpellSpeed.SS1, log, effect_id)
	if includes_ss:
		e.includes_a_special_summon()
	return e


static func _spell_with(effect_id: String, includes_ss: bool, log: Array) -> CardDef:
	var d := TestFixtures.spell("Synthetic " + effect_id)
	return TestFixtures.with_effect(d, _activation(effect_id, includes_ss, log))


## Pass on behalf of whoever holds the open window until `pid` may activate `card`, then
## activate it. Returns true when the response really was submitted.
##
## Activating a card is an ACTION, not a decision, so a `ScriptedController` never does it
## on its own — `default_yes` answers prompts and nothing more. A negator that is merely
## Set and never activated would leave every "CONTROL: it IS negated" assertion false, and
## the protection would then look like it was working when nothing had been tried.
static func _respond_with(engine: DuelEngine, pid: int, card: CardInstance,
		effect_id: String) -> bool:
	var guard := 0
	while guard < 10 and engine.timing != DuelEngine.Timing.OPEN:
		guard += 1
		var found = TestFixtures.find_action(engine.get_legal_responses(pid),
			Enums.ActionKind.ACTIVATE_CARD, card.id, effect_id)
		if found != null:
			return engine.submit_action(found)
		var waiting := engine.waiting_player()
		if waiting == -1:
			return false
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting)):
			return false
	return false


# ---------------------------------------------------------------------------
# Bookkeeping
# ---------------------------------------------------------------------------

static func _test_nothing_is_protected_by_default(t: TestCase) -> void:
	t.start("no player is protected by default")
	var d := _duel(5001)
	var state: GameState = (d["engine"] as DuelEngine).state
	for pid in [0, 1]:
		for key in NegationImmunity.ALL_KEYS:
			t.is_false(NegationImmunity.has(state, pid, key),
				"player %d does not hold '%s' before anything grants it" % [pid, key])


static func _test_granting_sets_all_three_together(t: TestCase) -> void:
	t.start("granting sets all three protections together — 「これらは同時に行われます。」")
	var d := _duel(5002)
	var state: GameState = (d["engine"] as DuelEngine).state
	NegationImmunity.grant_all(state, 0)
	for key in NegationImmunity.ALL_KEYS:
		t.is_true(NegationImmunity.has(state, 0, key),
			"player 0 holds '%s'" % key)
		t.is_false(NegationImmunity.has(state, 1, key),
			"and player 1 does not — the grant names ONE player")


static func _test_protections_expire_at_the_end_of_the_turn(t: TestCase) -> void:
	t.start("the protections last 「このターン中」 and no longer")
	var d := _duel(5003)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	NegationImmunity.grant_all(state, 0)
	t.is_true(NegationImmunity.has(state, 0, NegationImmunity.KEY_SUMMONS),
		"protected during the turn it was granted")

	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	for key in NegationImmunity.ALL_KEYS:
		t.is_false(NegationImmunity.has(state, 0, key),
			"'%s' is gone after the turn ended" % key)


static func _test_a_continuous_recompute_does_not_wipe_them(t: TestCase) -> void:
	t.start("a ContinuousEffects recompute does NOT wipe the protections")
	var d := _duel(5004)
	var state: GameState = (d["engine"] as DuelEngine).state
	NegationImmunity.grant_all(state, 0)
	ContinuousEffects.new(state).recompute()
	for key in NegationImmunity.ALL_KEYS:
		t.is_true(NegationImmunity.has(state, 0, key),
			"'%s' survives a recompute — the keys are deliberately NOT namespaced with "
				% key + "PLAYER_KEY_PREFIX, and a state-derived flag would have blinked out")


# ---------------------------------------------------------------------------
# Protection 1 — "The Normal and Special Summons of their monsters cannot be negated."
# ---------------------------------------------------------------------------

## Player 0 declares a Summon; player 1 holds a Set Counter Trap that negates it.
## Returns whether the Summon was actually negated.
static func _summon_was_negated(seed_value: int, protect: bool,
		route: String) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var p1: ScriptedController = d["p1"]
	p1.default_yes = true
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.summon_negator("Test Summon Negator"))
	# The Trap was Set this turn; clear that so it may be activated.
	negator.turn_set = 0
	if protect:
		NegationImmunity.grant_all(state, 0)

	var monster: CardInstance = null
	var action = null
	match route:
		"normal":
			monster = TestFixtures.give_to_hand(engine, 0,
				TestFixtures.monster("Summoned One", 4, 1400, 1000))
			action = TestFixtures.find_action(engine.get_legal_actions(0),
				Enums.ActionKind.NORMAL_SUMMON, monster.id)
		"flip":
			monster = TestFixtures.give_monster_on_field(engine, 0,
				TestFixtures.monster("Flipped One", 4, 1400, 1000),
				Enums.Position.FACE_DOWN_DEFENSE)
			monster.turn_set = 0
			action = TestFixtures.find_action(engine.get_legal_actions(0),
				Enums.ActionKind.FLIP_SUMMON, monster.id)
	if action == null:
		return {"offered": false, "negated": false, "monster": monster,
			"responded": false}
	engine.submit_action(action)
	# The negator has to be ACTIVATED; nothing does that for us.
	var responded := _respond_with(engine, 1, negator, "negate_summon")
	TestFixtures.pass_until_open(engine)
	return {
		"offered": true,
		"responded": responded,
		"negated": TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED) > 0,
		"monster": monster,
		"engine": engine,
	}


static func _test_a_normal_summon_cannot_be_negated(t: TestCase) -> void:
	t.start("a protected player's NORMAL Summon cannot be negated")
	var control := _summon_was_negated(5010, false, "normal")
	t.is_true(control["offered"], "CONTROL: the Summon was offered")
	t.is_true(control["responded"],
		"CONTROL: and the negator really was activated — without this the next "
		+ "assertion would be measuring nothing")
	t.is_true(control["negated"],
		"CONTROL: without the protection the Summon IS negated — so the assertion below "
		+ "is not passing because nothing ever negates anything")

	var protected := _summon_was_negated(5011, true, "normal")
	t.is_true(protected["offered"], "the Summon was offered")
	t.is_true(protected["responded"],
		"the negator was still activated — the protection stops the negation, not the "
		+ "activation of the card attempting it")
	t.is_false(protected["negated"],
		"with the protection the Normal Summon is NOT negated")
	var m: CardInstance = protected["monster"]
	t.eq(m.zone, Enums.Zone.MONSTER_ZONE, "and the monster is on the field")


static func _test_a_tribute_summon_cannot_be_negated(t: TestCase) -> void:
	t.start("a protected player's TRIBUTE Summon cannot be negated")
	# Asserted against the gate directly: the routes share one entry point, and building a
	# Tribute Summon through the action layer would test the summon machinery instead.
	var d := _duel(5012)
	var state: GameState = (d["engine"] as DuelEngine).state
	t.is_false(NegationImmunity.summon_negation_blocked(state, 0,
		Enums.SummonKind.TRIBUTE),
		"CONTROL: unprotected, a Tribute Summon is negatable")
	NegationImmunity.grant_all(state, 0)
	t.is_true(NegationImmunity.summon_negation_blocked(state, 0,
		Enums.SummonKind.TRIBUTE),
		"protected, a Tribute Summon is not — an Advance Summon IS a Normal Summon")


static func _test_a_special_summon_cannot_be_negated(t: TestCase) -> void:
	t.start("a protected player's SPECIAL Summon cannot be negated")
	var d := _duel(5013)
	var state: GameState = (d["engine"] as DuelEngine).state
	t.is_false(NegationImmunity.summon_negation_blocked(state, 0,
		Enums.SummonKind.SPECIAL),
		"CONTROL: unprotected, a Special Summon is negatable")
	NegationImmunity.grant_all(state, 0)
	t.is_true(NegationImmunity.summon_negation_blocked(state, 0,
		Enums.SummonKind.SPECIAL),
		"protected, a Special Summon is not")


static func _test_a_FLIP_summon_is_NOT_protected(t: TestCase) -> void:
	t.start("a FLIP Summon is NOT protected — 「召喚・特殊召喚」 names two routes and the "
		+ "OCG treats 「反転召喚」 as a third")
	var d := _duel(5014)
	var state: GameState = (d["engine"] as DuelEngine).state
	NegationImmunity.grant_all(state, 0)
	t.is_false(NegationImmunity.summon_negation_blocked(state, 0, Enums.SummonKind.FLIP),
		"the gate does not cover a Flip Summon even for a protected player")
	t.is_true(NegationImmunity.summon_negation_blocked(state, 0, Enums.SummonKind.NORMAL),
		"CONTROL: the same player, the same grant, and a Normal Summon IS covered")

	# End to end, so the omission is real behaviour and not just a table lookup.
	var protected := _summon_was_negated(5015, true, "flip")
	t.is_true(protected["offered"], "the Flip Summon was offered")
	t.is_true(protected["responded"], "and the negator was activated")
	t.is_true(protected["negated"],
		"and it WAS negated despite the protection. This is an inference from omission, "
		+ "at MEDIUM confidence — the card has no Q&A entries — so it is asserted here "
		+ "to give a later correction exactly one place to land")


static func _test_only_the_protected_players_summons_are_covered(t: TestCase) -> void:
	t.start("the protection covers only the player it was granted to")
	var d := _duel(5016)
	var state: GameState = (d["engine"] as DuelEngine).state
	NegationImmunity.grant_all(state, 0)
	t.is_true(NegationImmunity.summon_negation_blocked(state, 0, Enums.SummonKind.NORMAL),
		"player 0 is protected")
	t.is_false(NegationImmunity.summon_negation_blocked(state, 1, Enums.SummonKind.NORMAL),
		"player 1 is not — the grant is per player, not global")


# ---------------------------------------------------------------------------
# Protection 2 — activation negation, only for an activation that INCLUDES a Special Summon
# ---------------------------------------------------------------------------

## Player 0 activates a Spell; player 1 negates its activation with a Counter Trap.
static func _activation_was_negated(seed_value: int, protect: bool,
		includes_ss: bool) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var p1: ScriptedController = d["p1"]
	p1.default_yes = true
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Test Activation Negator"))
	negator.turn_set = 0
	if protect:
		NegationImmunity.grant_all(state, 0)

	var log := []
	var spell := TestFixtures.give_to_hand(engine, 0,
		_spell_with("payload", includes_ss, log))
	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	if action == null:
		return {"offered": false, "responded": false}
	engine.submit_action(action)
	var responded := _respond_with(engine, 1, negator, "negate_activation")
	TestFixtures.pass_until_open(engine)
	return {
		"offered": true,
		"responded": responded,
		"negated": TestFixtures.count_events(engine,
			GameEvent.Kind.ACTIVATION_NEGATED) > 0,
		"resolved": log.has("payload"),
	}


static func _test_a_special_summoning_activation_cannot_be_negated(t: TestCase) -> void:
	t.start("an activation that INCLUDES a Special Summon cannot be negated")
	var control := _activation_was_negated(5020, false, true)
	t.is_true(control["offered"], "CONTROL: the Spell was offered")
	t.is_true(control["responded"],
		"CONTROL: and the negator really was activated")
	t.is_true(control["negated"],
		"CONTROL: without the protection the activation IS negated")
	t.is_false(control["resolved"], "CONTROL: and the Spell did not resolve")

	var protected := _activation_was_negated(5021, true, true)
	t.is_true(protected["offered"], "the Spell was offered")
	t.is_true(protected["responded"], "the negator was still activated")
	t.is_false(protected["negated"],
		"with the protection the activation is NOT negated")
	t.is_true(protected["resolved"], "and the Spell resolved normally")


static func _test_an_activation_without_a_special_summon_is_still_negatable(
		t: TestCase) -> void:
	t.start("an activation that does NOT include a Special Summon is still negatable, "
		+ "even for a protected player")
	var protected := _activation_was_negated(5022, true, false)
	t.is_true(protected["offered"], "the Spell was offered")
	t.is_true(protected["responded"], "the negator was activated")
	t.is_true(protected["negated"],
		"the same protected player, the same negator, and this activation IS negated — "
		+ "the protection is narrowed to 「モンスターを特殊召喚する効果を含む」 and means it")
	t.is_false(protected["resolved"], "and the Spell did not resolve")


static func _test_EFFECT_negation_is_still_reachable(t: TestCase) -> void:
	t.start("EFFECT negation is still reachable — the protection names the ACTIVATION")
	var d := _duel(5023)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	NegationImmunity.grant_all(state, 0)

	var log := []
	var cm := ChainManager.new(state)
	cm.engine = engine
	var spell_def := _spell_with("payload", true, log)
	var spell := TestFixtures.give(engine, 0, spell_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	cm.add_link(spell, spell_def.effects[0], 0)
	var negator := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Negator", 4, 1000, 1000))

	t.is_false(cm.negate_activation(1, negator),
		"negating the ACTIVATION is refused for the protected player")
	t.is_true(cm.negate_effect(1, negator),
		"but negating the EFFECT is NOT — a different operation, deliberately left "
		+ "reachable, and 「その発動は無効化されない」 says nothing about it")
	cm.resolve_chain()
	t.is_false(log.has("payload"),
		"and the effect really did not apply, so the effect negation was not a no-op")


static func _test_only_the_protected_players_activations_are_covered(
		t: TestCase) -> void:
	t.start("activation protection covers only the player it was granted to")
	var d := _duel(5024)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	NegationImmunity.grant_all(state, 0)

	var log := []
	var cm := ChainManager.new(state)
	cm.engine = engine
	var mine_def := _spell_with("mine", true, log)
	var theirs_def := _spell_with("theirs", true, log)
	var mine := TestFixtures.give(engine, 0, mine_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	var theirs := TestFixtures.give(engine, 1, theirs_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	cm.add_link(mine, mine_def.effects[0], 0)
	cm.add_link(theirs, theirs_def.effects[0], 1)
	var negator := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Negator", 4, 1000, 1000))

	t.is_false(cm.negate_activation(1, negator),
		"player 0's Special-Summoning activation is protected")
	t.is_true(cm.negate_activation(2, negator),
		"player 1's identical activation is not — the grant is per player")


# ---------------------------------------------------------------------------
# Protection 3 — "Their opponent cannot target Set Spells/Traps they control with card
# effects, also they cannot be destroyed by their opponent's card effects."
# ---------------------------------------------------------------------------

## An effect controlled by `by_player` that offers every Spell/Trap on the field as a
## target, run through the real `legal_targets()` gate.
static func _targets_offered_to(engine: DuelEngine, by_player: int) -> Array:
	var e := EffectDef.new("targets_any_spell_trap", "Test: target 1 Spell/Trap.")
	e.targeting(1)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for pid in [0, 1]:
			for entry in ctx.state.player(pid).spell_traps():
				out.append(entry)
		return out
	var probe := TestFixtures.give_monster_on_field(engine, by_player,
		TestFixtures.monster("Prober %d" % by_player, 4, 1000, 1000))
	var ctx := EffectContext.new(engine.state, probe, e)
	ctx.controller_id = by_player
	ctx.engine = engine
	return ActivationRules.legal_targets(ctx).map(func(c): return c.id)


static func _test_a_set_spell_trap_cannot_be_targeted_by_the_opponent(
		t: TestCase) -> void:
	t.start("a protected player's SET Spell/Trap cannot be targeted by the opponent")
	var d := _duel(5030)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var set_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Set Card"))

	t.is_true(_targets_offered_to(engine, 1).has(set_card.id),
		"CONTROL: unprotected, the opponent may target it")
	NegationImmunity.grant_all(state, 0)
	t.is_false(_targets_offered_to(engine, 1).has(set_card.id),
		"protected, the opponent may not")


static func _test_your_own_effects_may_still_target_your_set_cards(t: TestCase) -> void:
	t.start("your OWN effects may still target your Set cards — 「相手の効果の対象にならず」")
	var d := _duel(5031)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var set_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Set Card"))
	NegationImmunity.grant_all(state, 0)

	t.is_true(_targets_offered_to(engine, 0).has(set_card.id),
		"the protected player's own effect may target their own Set card")
	t.is_false(_targets_offered_to(engine, 1).has(set_card.id),
		"CONTROL: and the opponent's may not, on the same board")


static func _test_a_face_up_spell_trap_is_NOT_protected(t: TestCase) -> void:
	t.start("a FACE-UP Spell/Trap is not protected — 「セットされた」 means Set")
	var d := _duel(5032)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var set_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Set Card"))
	var face_up := TestFixtures.give(engine, 0,
		TestFixtures.spell("Face-Up Card", Enums.STKind.CONTINUOUS_SPELL),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	NegationImmunity.grant_all(state, 0)

	var offered := _targets_offered_to(engine, 1)
	t.is_false(offered.has(set_card.id), "the Set card is protected")
	t.is_true(offered.has(face_up.id),
		"the face-up card on the same field is NOT — which is also why the card granting "
		+ "this protection does not protect itself")


static func _test_a_monster_is_NOT_protected_by_this_clause(t: TestCase) -> void:
	t.start("a MONSTER is not protected by this clause — it names Spell/Trap cards")
	var d := _duel(5033)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var face_down_monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face-Down One", 4, 1000, 1000),
		Enums.Position.FACE_DOWN_DEFENSE)
	NegationImmunity.grant_all(state, 0)

	t.is_false(NegationImmunity.targeting_blocked(state, face_down_monster, 1),
		"a face-down MONSTER is not covered, even though it is face-down on a protected "
		+ "player's field")
	t.is_true(NegationImmunity.targeting_blocked(state,
		TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.spell("Set Card")), 1),
		"CONTROL: a Set Spell/Trap on the same field is")


static func _test_a_set_spell_trap_cannot_be_destroyed_by_the_opponent(
		t: TestCase) -> void:
	t.start("a protected player's SET Spell/Trap cannot be destroyed by the opponent's "
		+ "card effect")
	var d := _duel(5034)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var enemy := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Destroyer", 4, 1000, 1000))

	var control_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Control Set Card"))
	t.is_true(state.destroy(control_card, Enums.MoveReason.DESTROYED_BY_EFFECT, enemy.id),
		"CONTROL: unprotected, the opponent's effect destroys it")
	t.eq(control_card.zone, Enums.Zone.GRAVEYARD, "CONTROL: and it reached the Graveyard")

	NegationImmunity.grant_all(state, 0)
	var protected_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Protected Set Card"))
	t.is_false(state.destroy(protected_card, Enums.MoveReason.DESTROYED_BY_EFFECT,
		enemy.id), "protected, the opponent's effect does not destroy it")
	t.eq(protected_card.zone, Enums.Zone.SPELL_TRAP_ZONE, "and it is still on the field")


static func _test_your_own_effect_may_still_destroy_your_set_card(t: TestCase) -> void:
	t.start("your OWN effect may still destroy your own Set card")
	var d := _duel(5035)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Destroyer", 4, 1000, 1000))
	NegationImmunity.grant_all(state, 0)
	var set_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Set Card"))

	t.is_true(state.destroy(set_card, Enums.MoveReason.DESTROYED_BY_EFFECT, mine.id),
		"the protected player's own effect destroys their own Set card — 「相手の効果では"
		+ "破壊されない」 names the opponent and only the opponent")
	t.eq(set_card.zone, Enums.Zone.GRAVEYARD, "and it reached the Graveyard")


static func _test_rules_destruction_is_not_blocked(t: TestCase) -> void:
	t.start("rules destruction is not blocked — it is not a card effect")
	var d := _duel(5036)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	NegationImmunity.grant_all(state, 0)
	var set_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Set Card"))

	t.is_true(state.destroy(set_card, Enums.MoveReason.DESTROYED_BY_RULE, -1),
		"a RULES destruction reaches the protected Set card")
	t.eq(set_card.zone, Enums.Zone.GRAVEYARD, "and it reached the Graveyard")

	# CONTROL: the same board, the same card kind, destroyed by an OPPONENT'S EFFECT, is
	# refused — so the line above is not passing because the gate blocks nothing.
	var enemy := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Destroyer", 4, 1000, 1000))
	var second := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Second Set Card"))
	t.is_false(state.destroy(second, Enums.MoveReason.DESTROYED_BY_EFFECT, enemy.id),
		"CONTROL: the opponent's card effect is still refused on the same board")

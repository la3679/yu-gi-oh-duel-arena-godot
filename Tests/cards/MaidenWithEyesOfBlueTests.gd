class_name MaidenWithEyesOfBlueTests
extends RefCounted

## `Maiden with Eyes of Blue` — LIGHT / Spellcaster / Level 1 / Tuner, 0 ATK / 0 DEF.
## One copy, deck 1.
##
## Official text (verified, `Data/cards/cards.json`, cid 10588):
##
##   "When a card or effect is activated that targets this card (Quick Effect): You can
##    Special Summon 1 "Blue-Eyes White Dragon" from your hand, Deck, or GY. When this card
##    is targeted for an attack: You can negate the attack, and if you do, change the battle
##    position of this card, then you can Special Summon 1 "Blue-Eyes White Dragon" from your
##    hand, Deck, or GY. You can only use 1 "Maiden with Eyes of Blue" effect per turn, and
##    only once that turn."
##
## **Two effect clauses plus a restriction sentence that governs both.**
## `Research/CARD_RULINGS.md` **R3** — which this suite closes.
##
## The load-bearing claim is the **shared use**: the two clauses spend ONE allowance between
## them, so using either locks out the other for the turn. Both orderings are driven, because
## a shared key that only worked one way round would pass a one-directional test. The
## mechanism (`EffectDef.restriction_group` + `opt_named_effect()`) was proved generically in
## `AttackRestrictionTests` before this card existed; what is proved here is that the printed
## card is wired to it, and wired to the same key on both clauses.
##
## The card is genuinely live in this pool: `Blue-Eyes White Dragon` is in the same deck, so
## none of this needs the R21/R23 synthetic treatment. The Deck branch is exercised too,
## because the printed clause reaches three zones and a two-zone implementation would pass a
## hand-only test.

const CARD_UNDER_TEST := "Maiden with Eyes of Blue"
const SUMMONS := "Blue-Eyes White Dragon"

const TARGETED_EFFECT_ID := "summon_blue_eyes_when_targeted"
const ATTACKED_EFFECT_ID := "negate_attack_and_summon_blue_eyes"


static func run() -> TestCase:
	var t := TestCase.new("MaidenWithEyesOfBlueTests")

	# --- Shape ---
	_test_the_card_declares_two_clauses_of_two_different_kinds(t)
	_test_both_clauses_share_one_restriction_group_and_one_named_use(t)
	_test_neither_clause_targets(t)

	# --- Clause 1: the Quick Effect ---
	_test_it_is_offered_when_an_activation_targets_it(t)
	_test_it_is_not_offered_when_the_activation_targets_something_else(t)
	_test_it_is_not_offered_with_no_activation_at_all(t)
	_test_the_quick_effect_summons_blue_eyes_from_the_hand(t)
	_test_the_quick_effect_can_summon_from_the_deck(t)
	_test_the_quick_effect_can_summon_from_the_graveyard(t)
	_test_it_becomes_a_real_chain_link_above_the_activation_that_targeted_it(t)
	_test_it_is_not_offered_while_face_down(t)

	# --- Clause 2: the Trigger Effect ---
	_test_the_attack_is_negated_and_the_position_changes(t)
	_test_the_attack_really_was_declared_first(t)
	_test_a_direct_attack_does_not_trigger_it(t)
	_test_an_attack_on_a_different_monster_does_not_trigger_it(t)
	_test_the_summon_is_a_second_you_can_and_may_be_declined(t)
	_test_declining_the_summon_still_leaves_the_attack_negated(t)
	_test_nothing_happens_after_a_failed_negation(t)

	# --- R3: the shared use ---
	_test_using_the_quick_effect_locks_out_the_trigger_this_turn(t)
	_test_using_the_trigger_locks_out_the_quick_effect_this_turn(t)
	_test_the_shared_use_resets_next_turn(t)

	# --- The pool ---
	_test_the_real_pool_makes_both_clauses_live(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def(card_name: String = CARD_UNDER_TEST) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _effect_by_id(card_def: CardDef, effect_id: String):
	for effect in card_def.effects:
		if (effect as EffectDef).effect_id == effect_id:
			return effect
	return null


## A synthetic Spell that TARGETS one monster and does nothing to it. The point is the
## targeting, not the effect: it is what makes clause 1 eligible.
static func _targeting_spell(card_name: String, order_log: Array) -> CardDef:
	var e := EffectDef.new("targeting_activation",
		"Test: target 1 monster on the field; nothing happens to it.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS1)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)
	# Every monster on the field, face-up OR face-down: a real card may target a face-down
	# monster, and the face-down test below needs it to.
	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for p in ctx.state.players:
			out.append_array(p.monsters())
		return out
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append("targeted")
	return TestFixtures.with_effect(TestFixtures.spell(card_name), e)


## Player 0 controls a face-up Maiden in Main Phase 1 of their own turn, with one
## `Blue-Eyes White Dragon` placed in `where`.
## `where` is null when no Blue-Eyes is to be placed anywhere at all.
static func _board(seed_value: int, where = Enums.Zone.HAND,
		yes: bool = true) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = yes
	(d["p1"] as ScriptedController).default_yes = yes
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["maiden"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	if where != null:
		d["dragon"] = TestFixtures.give(engine, 0, _def(SUMMONS), where,
			Enums.Position.FACE_DOWN if where == Enums.Zone.HAND else null)
	return d


## The Battle Step of turn 2 with player 1 attacking into player 0's face-up Maiden.
## `where` is null when no Blue-Eyes is to be placed anywhere at all.
static func _attack_board(seed_value: int, yes: bool = true,
		where = Enums.Zone.HAND) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = yes
	(d["p1"] as ScriptedController).default_yes = yes
	TestFixtures.end_turn(engine)                       # player 0's first turn is over
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	d["maiden"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Attacking Knight", 4, 1900, 1000))
	if where != null:
		d["dragon"] = TestFixtures.give(engine, 0, _def(SUMMONS), where,
			Enums.Position.FACE_DOWN if where == Enums.Zone.HAND else null)
	engine.continuous.recompute()
	return d


## A Set Trap that its controller COULD respond with but never does. Without one the engine
## correctly auto-passes both response windows and resolves the whole Chain inside a single
## `submit_action()`, so a test that wanted to look at an unresolved Chain would be looking
## at an empty one and its assertions would be vacuous.
static func _spacer_trap(engine: DuelEngine, pid: int,
		card_name: String = "Chain Holder") -> CardInstance:
	var order_log: Array = []
	var e := TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	return TestFixtures.give_set_spell_trap(engine, pid,
		TestFixtures.with_effect(TestFixtures.trap(card_name), e))


static func _quick_offered(engine: DuelEngine, maiden: CardInstance) -> bool:
	return TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, maiden.id, TARGETED_EFFECT_ID)


static func _blue_eyes_on_field(engine: DuelEngine, pid: int) -> bool:
	for entry in engine.state.player(pid).monsters():
		if (entry as CardInstance).card_name() == SUMMONS:
			return true
	return false


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_two_clauses_of_two_different_kinds(
		t: TestCase) -> void:
	t.start("two EffectDefs: a QUICK effect (Spell Speed 2) and a TRIGGER effect (Spell "
		+ "Speed 1) — only the first prints '(Quick Effect)'")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	t.eq(card_def.effects.size(), 2, "exactly two effect clauses")
	t.eq(card_def.base_atk, 0, "0 ATK")
	t.eq(card_def.base_def, 0, "0 DEF")
	t.eq(card_def.level, 1, "Level 1")
	t.eq(card_def.attribute, "LIGHT", "LIGHT")
	t.eq(card_def.race, "Spellcaster", "Spellcaster")
	t.is_true(card_def.is_tuner, "and a Tuner")

	var quick: EffectDef = _effect_by_id(card_def, TARGETED_EFFECT_ID)
	t.not_null(quick, "the targeted clause exists")
	t.eq(quick.effect_type, Enums.EffectType.QUICK, "it is a QUICK effect")
	t.eq(quick.spell_speed, Enums.SpellSpeed.SS2, "so it is Spell Speed 2")
	t.is_true(quick.trigger_events.has(GameEvent.Kind.TARGET_SELECTED),
		"and it keys on TARGET_SELECTED")

	var trigger: EffectDef = _effect_by_id(card_def, ATTACKED_EFFECT_ID)
	t.not_null(trigger, "the attacked clause exists")
	t.eq(trigger.effect_type, Enums.EffectType.TRIGGER, "it is a TRIGGER effect")
	t.eq(trigger.spell_speed, Enums.SpellSpeed.SS1, "so it is Spell Speed 1")
	t.is_true(trigger.trigger_events.has(GameEvent.Kind.ATTACK_DECLARED),
		"and it keys on ATTACK_DECLARED")


static func _test_both_clauses_share_one_restriction_group_and_one_named_use(
		t: TestCase) -> void:
	t.start("R3: ONE allowance across both clauses — the same non-empty restriction_group "
		+ "and opt_named_effect() on each, so both resolve to the same named key")
	var card_def := _def()
	var quick: EffectDef = _effect_by_id(card_def, TARGETED_EFFECT_ID)
	var trigger: EffectDef = _effect_by_id(card_def, ATTACKED_EFFECT_ID)

	t.is_true(quick.once_per_turn_named_effect, "the Quick Effect is once per turn by name")
	t.is_true(trigger.once_per_turn_named_effect, "and so is the Trigger Effect")
	t.ne(quick.restriction_group, "", "the Quick Effect names a restriction group")
	t.eq(trigger.restriction_group, quick.restriction_group,
		"and the Trigger Effect names the SAME one")
	t.eq(trigger.named_key(), quick.named_key(),
		"so both spend the same named key — this is what makes the use shared")
	t.ne(quick.effect_id, trigger.effect_id,
		"while still being two distinct clauses with distinct ids")
	t.is_false(quick.once_per_turn_instance,
		"NOT opt_instance() — the restriction is on the NAME, not on this copy")
	t.is_false(trigger.once_per_turn_instance, "on neither clause")
	t.is_false(quick.once_per_turn_named_activation,
		"and not once-per-turn-per-ACTIVATION either — the text says 'use … effect'")


static func _test_neither_clause_targets(t: TestCase) -> void:
	t.start("neither clause prints 'target', so which Blue-Eyes is Summoned is chosen at "
		+ "RESOLUTION, not fixed at activation")
	var card_def := _def()
	t.is_false((_effect_by_id(card_def, TARGETED_EFFECT_ID) as EffectDef).targets,
		"the Quick Effect does not target")
	t.is_false((_effect_by_id(card_def, ATTACKED_EFFECT_ID) as EffectDef).targets,
		"nor does the Trigger Effect")
	for effect in card_def.effects:
		t.is_true((effect as EffectDef).activation_locations
			== [Enums.ActivationLocation.FIELD_FACE_UP],
			"and %s is activated only from the field face-up"
			% (effect as EffectDef).effect_id)


# ---------------------------------------------------------------------------
# Clause 1 — the Quick Effect
# ---------------------------------------------------------------------------

static func _test_it_is_offered_when_an_activation_targets_it(t: TestCase) -> void:
	t.start("the Quick Effect is offered in the response window an activation targeting "
		+ "the Maiden opened")
	var d := _board(9401)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1,
		_targeting_spell("Pointing Spell", order))
	TestFixtures.end_turn(engine)                       # -> player 1's turn, so they may act
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	t.is_false(_quick_offered(engine, maiden),
		"CONTROL: nothing has been activated, so it is not offered")
	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(a, "the opponent's targeting Spell is available")
	a.target_ids = [maiden.id]
	t.is_true(engine.submit_action(a), "and is activated, targeting the Maiden")
	t.eq(engine.chain.chain_size(), 1, "it is Chain Link 1 and unresolved")
	t.is_true(_quick_offered(engine, maiden),
		"and NOW the Maiden's Quick Effect is offered")


static func _test_it_is_not_offered_when_the_activation_targets_something_else(
		t: TestCase) -> void:
	t.start("'that targets THIS CARD' — an activation aimed at a different monster does "
		+ "not make it eligible")
	var d := _board(9403)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Someone Else", 4, 1400, 1000))
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1,
		_targeting_spell("Pointing Elsewhere", order))
	# Player 0 holds something else it could respond with, so the Chain stays open long
	# enough to look at. Without it the whole Chain resolves inside submit_action() and the
	# negative below would pass because there was no window at all.
	var spacer := _spacer_trap(engine, 0)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	a.target_ids = [other.id]
	t.is_true(engine.submit_action(a), "the Spell is activated, targeting the other monster")
	t.eq(engine.chain.chain_size(), 1, "one unresolved Chain Link")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, spacer.id),
		"CONTROL: player 0 really does have an open response window")
	t.is_false(_quick_offered(engine, maiden),
		"and the Maiden's Quick Effect is NOT offered in it")


static func _test_it_is_not_offered_with_no_activation_at_all(t: TestCase) -> void:
	t.start("with no Chain at all there is nothing that targets it, so it is not offered "
		+ "as a free-choice fast effect")
	var d := _board(9405)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.chain.chain_size(), 0, "no Chain exists")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, (d["maiden"] as CardInstance).id,
		TARGETED_EFFECT_ID),
		"the Quick Effect is not an open-game-state action")


## Drive: the opponent activates a Spell targeting the Maiden, the Maiden responds, and the
## whole Chain resolves. Returns whether the Maiden's effect really became a Chain Link.
static func _run_quick_effect(t: TestCase, d: Dictionary) -> bool:
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1,
		_targeting_spell("Pointing Spell", order))
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	if a == null:
		return false
	a.target_ids = [maiden.id]
	engine.submit_action(a)
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, maiden.id, TARGETED_EFFECT_ID)
	if response == null:
		return false
	var ok := engine.submit_action(response)
	TestFixtures.pass_until_open(engine)
	t.eq(order, ["targeted"], "the opponent's Spell resolved too")
	return ok


static func _test_the_quick_effect_summons_blue_eyes_from_the_hand(t: TestCase) -> void:
	t.start("it Special Summons Blue-Eyes White Dragon from the HAND")
	var d := _board(9407, Enums.Zone.HAND)
	var engine: DuelEngine = d["engine"]
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.HAND, "the Dragon starts in hand")

	t.is_true(_run_quick_effect(t, d), "the Quick Effect was activated")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"and the Dragon is on the field")
	t.is_true(_blue_eyes_on_field(engine, 0), "under its controller's control")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		(d["dragon"] as CardInstance).id), 1,
		"by a real Special Summon, through the engine's own route")


static func _test_the_quick_effect_can_summon_from_the_deck(t: TestCase) -> void:
	t.start("'from your hand, DECK, or GY' — the Deck branch works, which a hand-only "
		+ "implementation would fail")
	var d := _board(9409, Enums.Zone.DECK)
	var engine: DuelEngine = d["engine"]
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.DECK, "the Dragon starts in the Deck")

	t.is_true(_run_quick_effect(t, d), "the Quick Effect was activated")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"and it came out of the Deck onto the field")


static func _test_the_quick_effect_can_summon_from_the_graveyard(t: TestCase) -> void:
	t.start("'from your hand, Deck, or GY' — the Graveyard branch works too")
	var d := _board(9411, Enums.Zone.GRAVEYARD)
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"the Dragon starts in the Graveyard")

	t.is_true(_run_quick_effect(t, d), "the Quick Effect was activated")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"and it was revived onto the field")


static func _test_it_becomes_a_real_chain_link_above_the_activation_that_targeted_it(
		t: TestCase) -> void:
	t.start("it is a real Chain Link 2 responding to Chain Link 1 — a Quick Effect that "
		+ "quietly resolved outside the Chain would be a different card")
	var d := _board(9413)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1,
		_targeting_spell("Pointing Spell", order))
	# A spacer so the engine pauses after the Maiden's link instead of resolving the whole
	# Chain inside submit_action() - otherwise chain_size() would be 0 by the time we look.
	_spacer_trap(engine, 0)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	a.target_ids = [maiden.id]
	engine.submit_action(a)
	t.eq(engine.chain.chain_size(), 1, "the targeting Spell is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, maiden.id, TARGETED_EFFECT_ID)
	t.not_null(response, "the Maiden's response is offered")
	t.is_true(engine.submit_action(response), "and is submitted")
	t.eq(engine.chain.chain_size(), 2, "the Chain is now two links deep")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CHAIN_LINK_ADDED, maiden.id),
		1, "and exactly one of them belongs to the Maiden")
	var maiden_links := TestFixtures.events_of(engine, GameEvent.Kind.CHAIN_LINK_ADDED) \
		.filter(func(e): return int(e.data.get("card_id", -1)) == maiden.id)
	t.eq(int((maiden_links[0] as GameEvent).data.get("link_number", -1)), 2,
		"the Maiden's link really is Chain Link 2, above the activation that targeted it")
	TestFixtures.pass_until_open(engine)
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"and it resolved - Chain Link 2 first, so the Dragon is out")
	t.eq(order, ["targeted"], "and Chain Link 1 resolved afterwards")


static func _test_it_is_not_offered_while_face_down(t: TestCase) -> void:
	t.start("a face-down monster's effects do not apply, so a face-down Maiden is not "
		+ "offered even when something targets it")
	# CONTROL and negative on the SAME board shape: the identical Spell targets the identical
	# Maiden, and the only difference is which way up she is.
	var boards := [_board(9415), _board(9416)]
	var offered: Array = []
	for i in range(2):
		var d: Dictionary = boards[i]
		var engine: DuelEngine = d["engine"]
		var maiden: CardInstance = d["maiden"]
		if i == 1:
			engine.state.set_battle_position(maiden, Enums.Position.FACE_DOWN_DEFENSE, true)
			engine.continuous.recompute()
		var order: Array = []
		var spell := TestFixtures.give_to_hand(engine, 1,
			_targeting_spell("Pointing Spell", order))
		_spacer_trap(engine, 0)
		TestFixtures.end_turn(engine)
		TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
		var a = TestFixtures.find_action(engine.get_legal_actions(1),
			Enums.ActionKind.ACTIVATE_CARD, spell.id)
		t.not_null(a, "the Spell is available")
		a.target_ids = [maiden.id]
		t.is_true(engine.submit_action(a), "and is activated, targeting the Maiden")
		t.eq(engine.chain.chain_size(), 1, "one unresolved Chain Link")
		offered.append(_quick_offered(engine, maiden))

	t.is_true(bool(offered[0]),
		"CONTROL: face-up, the Quick Effect is offered - so the negative below is real")
	t.is_false(bool(offered[1]),
		"face-down, it is NOT: both clauses are activated only from the field face-up, so a "
		+ "face-down Maiden has no effects to use")
	t.is_true((boards[1]["maiden"] as CardInstance).is_face_down(),
		"and she really was face-down for that")


# ---------------------------------------------------------------------------
# Clause 2 — the Trigger Effect
# ---------------------------------------------------------------------------

static func _test_the_attack_is_negated_and_the_position_changes(t: TestCase) -> void:
	t.start("CONTROL vs NEGATED: the attack is negated, the Maiden's battle position "
		+ "changes, and Blue-Eyes is Special Summoned — in that order")
	var control := _attack_board(9417, false)
	var control_engine: DuelEngine = control["engine"]
	t.is_true(TestFixtures.attack(control_engine, control["attacker"], control["maiden"]),
		"CONTROL: the attack is declared")
	TestFixtures.pass_until_open(control_engine)
	t.eq(TestFixtures.count_events(control_engine, GameEvent.Kind.DAMAGE_CALCULATED), 1,
		"CONTROL: with the effect declined, damage really is calculated")
	t.eq((control["maiden"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"CONTROL: and the 0 ATK Maiden is destroyed — so the positive below is real")

	var d := _attack_board(9419, true)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	t.eq(maiden.position, Enums.Position.FACE_UP_ATTACK, "the Maiden starts in Attack")

	t.is_true(TestFixtures.attack(engine, d["attacker"], maiden), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 1,
		"the attack was negated")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.DAMAGE_CALCULATED), 0,
		"so damage calculation never happened")
	t.eq(maiden.zone, Enums.Zone.MONSTER_ZONE, "the Maiden survives")
	t.eq(maiden.position, Enums.Position.FACE_UP_DEFENSE,
		"and its battle position changed to Defence")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE,
		"and Blue-Eyes White Dragon was Special Summoned")


static func _test_the_attack_really_was_declared_first(t: TestCase) -> void:
	t.start("R34 part A: NEGATION, not prevention — ATTACK_DECLARED really happened and "
		+ "the attacker really has spent its attack for the turn")
	var d := _attack_board(9421, true)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["attacker"]

	t.is_true(TestFixtures.attack(engine, attacker, d["maiden"]), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 1,
		"exactly one ATTACK_DECLARED — the attack was real")
	t.is_true(attacker.has_attacked_this_turn,
		"and the attacker has used its attack, which prevention would not have done")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_REPLAY), 0,
		"and it is not a Replay — a Replay gives the choice back, a negation spends it")


static func _test_a_direct_attack_does_not_trigger_it(t: TestCase) -> void:
	t.start("'when THIS CARD is targeted for an attack' — a direct attack has no target, "
		+ "so the clause does not fire")
	var d := _attack_board(9423, true)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	# Take the Maiden off the field so the attack really can be direct.
	engine.state.move_card(maiden, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	engine.continuous.recompute()

	t.is_true(TestFixtures.attack(engine, d["attacker"], null), "a direct attack is declared")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 0,
		"nothing negated it")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.HAND,
		"and no Blue-Eyes was Summoned")


static func _test_an_attack_on_a_different_monster_does_not_trigger_it(
		t: TestCase) -> void:
	t.start("an attack aimed at a DIFFERENT monster leaves the Maiden's clause alone")
	var d := _attack_board(9425, true)
	var engine: DuelEngine = d["engine"]
	var decoy := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Decoy", 4, 1000, 1000))
	engine.continuous.recompute()

	t.is_true(TestFixtures.attack(engine, d["attacker"], decoy), "the attack targets the decoy")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 0,
		"the attack was not negated")
	t.eq(decoy.zone, Enums.Zone.GRAVEYARD, "the decoy really was destroyed")
	t.eq((d["maiden"] as CardInstance).position, Enums.Position.FACE_UP_ATTACK,
		"and the Maiden's position is untouched")


static func _test_the_summon_is_a_second_you_can_and_may_be_declined(t: TestCase) -> void:
	t.start("'…THEN YOU CAN Special Summon' is a second, separate 'you can', asked at "
		+ "resolution — declining it leaves everything before it done")
	var d := _attack_board(9427, true)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	# Answer the outer optional-trigger question yes and the inner Special Summon question
	# no. They are two separate YES_NO prompts, which is the whole point of the clause.
	p0.answers = [true, false]
	p0.default_yes = true

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["maiden"]), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 1,
		"the attack was still negated")
	t.eq((d["maiden"] as CardInstance).position, Enums.Position.FACE_UP_DEFENSE,
		"the position still changed")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.HAND,
		"but the declined Special Summon did not happen")
	t.is_true(p0.request_count(Enums.DecisionKind.YES_NO) >= 2,
		"and the controller really was asked twice")


static func _test_declining_the_summon_still_leaves_the_attack_negated(
		t: TestCase) -> void:
	t.start("with NO Blue-Eyes available anywhere the negation and the position change "
		+ "still happen — the summon is the last step, not a precondition")
	var d := _attack_board(9429, true, null)
	var engine: DuelEngine = d["engine"]
	t.is_false(d.has("dragon"), "no Blue-Eyes was placed anywhere")

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["maiden"]), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 1,
		"the attack was negated")
	t.eq((d["maiden"] as CardInstance).zone, Enums.Zone.MONSTER_ZONE, "the Maiden survives")
	t.eq((d["maiden"] as CardInstance).position, Enums.Position.FACE_UP_DEFENSE,
		"and its position changed anyway")


static func _test_nothing_happens_after_a_failed_negation(t: TestCase) -> void:
	t.start("'and IF YOU DO' — with the attack already negated by something else there is "
		+ "nothing left to negate, so no position change and no Special Summon")
	var d := _attack_board(9431, true)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	# A Set Trap of player 0's that negates the declared attack. The Maiden's trigger becomes
	# Chain Link 1; this Trap is put on top as Chain Link 2, so it resolves FIRST and the
	# attack is already gone by the time the Maiden's own link resolves. That is the only
	# honest way to make its negation fail - calling BattleRules.negate_attack() by hand
	# after the attack would race the Maiden's own trigger, which has already resolved.
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.attack_negator("Someone Else's Negation"))

	t.is_true(TestFixtures.attack(engine, d["attacker"], maiden), "the attack is declared")
	t.eq(engine.chain.chain_size(), 1, "the Maiden's trigger is Chain Link 1")
	var a = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(a, "and the other negation is offered in response")
	t.is_true(engine.submit_action(a), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 1,
		"exactly ONE negation happened - Chain Link 2 did it, and the Maiden's own attempt "
		+ "found nothing left to negate")
	t.eq(maiden.position, Enums.Position.FACE_UP_ATTACK,
		"so the battle position did NOT change")
	t.eq((d["dragon"] as CardInstance).zone, Enums.Zone.HAND,
		"and no Blue-Eyes was Special Summoned - 'and if you do' gates everything after it")
	t.eq(maiden.zone, Enums.Zone.MONSTER_ZONE,
		"while the Maiden still survives, because the attack was negated by the other card")


# ---------------------------------------------------------------------------
# R3 — the shared use
# ---------------------------------------------------------------------------

static func _test_using_the_quick_effect_locks_out_the_trigger_this_turn(
		t: TestCase) -> void:
	t.start("R3: using the QUICK effect spends the single allowance, so the TRIGGER clause "
		+ "may not be used in the same turn")
	var d := _board(9433)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var trigger: EffectDef = _effect_by_id(_def(), ATTACKED_EFFECT_ID)
	var quick: EffectDef = _effect_by_id(_def(), TARGETED_EFFECT_ID)

	t.is_true(ActivationRules.once_per_turn_ok(engine.state, maiden, trigger, 0),
		"CONTROL: the Trigger clause is available to begin with")
	t.is_true(_run_quick_effect(t, d), "the Quick Effect is used")

	t.is_false(ActivationRules.once_per_turn_ok(engine.state, maiden, quick, 0),
		"the Quick Effect itself is spent")
	t.is_false(ActivationRules.once_per_turn_ok(engine.state, maiden, trigger, 0),
		"and so is the OTHER clause — one allowance, shared")


static func _test_using_the_trigger_locks_out_the_quick_effect_this_turn(
		t: TestCase) -> void:
	t.start("R3, the other way round: using the TRIGGER clause spends the allowance, so "
		+ "the QUICK effect may not be used in the same turn")
	var d := _attack_board(9435, true)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var quick: EffectDef = _effect_by_id(_def(), TARGETED_EFFECT_ID)
	var trigger: EffectDef = _effect_by_id(_def(), ATTACKED_EFFECT_ID)

	t.is_true(ActivationRules.once_per_turn_ok(engine.state, maiden, quick, 0),
		"CONTROL: the Quick Effect is available to begin with")
	t.is_true(TestFixtures.attack(engine, d["attacker"], maiden), "the attack is declared")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 1,
		"the Trigger clause really was used")

	t.is_false(ActivationRules.once_per_turn_ok(engine.state, maiden, trigger, 0),
		"the Trigger clause is spent")
	t.is_false(ActivationRules.once_per_turn_ok(engine.state, maiden, quick, 0),
		"and so is the Quick Effect — the same single allowance")


static func _test_the_shared_use_resets_next_turn(t: TestCase) -> void:
	t.start("R3: 'per turn' — the shared allowance comes back on the following turn")
	var d := _attack_board(9437, true)
	var engine: DuelEngine = d["engine"]
	var maiden: CardInstance = d["maiden"]
	var quick: EffectDef = _effect_by_id(_def(), TARGETED_EFFECT_ID)

	t.is_true(TestFixtures.attack(engine, d["attacker"], maiden), "the attack is declared")
	TestFixtures.pass_until_open(engine)
	t.is_false(ActivationRules.once_per_turn_ok(engine.state, maiden, quick, 0),
		"the allowance is spent this turn")

	TestFixtures.end_turn(engine)
	t.is_true(ActivationRules.once_per_turn_ok(engine.state, maiden, quick, 0),
		"and it is back on the next turn")


# ---------------------------------------------------------------------------
# The pool
# ---------------------------------------------------------------------------

static func _test_the_real_pool_makes_both_clauses_live(t: TestCase) -> void:
	t.start("the real pool: one Maiden and one Blue-Eyes White Dragon, in the SAME deck, "
		+ "so neither clause needs the synthetic treatment")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")
	t.is_true(cards.has(CARD_UNDER_TEST), "it contains the Maiden")
	t.is_true(cards.has(SUMMONS), "and Blue-Eyes White Dragon")

	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the verified card database is readable")
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	t.check(parsed is Dictionary, "and parses")

	var maiden_decks: Array = []
	var dragon_decks: Array = []
	var cid := ""
	var text := ""
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if str(row.get("name", "")) == CARD_UNDER_TEST:
				maiden_decks = row.get("decks", [])
				cid = str(row.get("konami_cid", ""))
				text = str(row.get("text", ""))
			elif str(row.get("name", "")) == SUMMONS:
				dragon_decks = row.get("decks", [])
	t.eq(cid, "10588", "the verified Konami card id")
	t.eq(maiden_decks.size(), 1, "the Maiden is in one deck")
	t.eq(dragon_decks.size(), 1, "so is the Dragon")
	t.eq(str(maiden_decks[0]), str(dragon_decks[0]),
		"and it is the SAME deck — the Summon really can happen in a real duel")

	# The restriction sentence governs BOTH clauses, so it is carried on both clause texts
	# and the concatenation is deliberately not equal to the printed text. What must hold is
	# that every printed sentence appears verbatim somewhere in the implemented clauses, and
	# that the shared sentence appears on both.
	var quick: EffectDef = _effect_by_id(_def(), TARGETED_EFFECT_ID)
	var trigger: EffectDef = _effect_by_id(_def(), ATTACKED_EFFECT_ID)
	var restriction := "You can only use 1 \"Maiden with Eyes of Blue\" effect per turn, " \
		+ "and only once that turn."
	t.is_true(text.contains(restriction),
		"the printed restriction sentence is on the card")
	t.is_true(quick.clause_text.contains(restriction),
		"and it is carried on the Quick Effect clause")
	t.is_true(trigger.clause_text.contains(restriction),
		"and on the Trigger clause too - it governs both")
	for sentence in [
			"When a card or effect is activated that targets this card (Quick Effect): You " \
				+ "can Special Summon 1 \"Blue-Eyes White Dragon\" from your hand, Deck, or GY.",
			"When this card is targeted for an attack: You can negate the attack, and if you " \
				+ "do, change the battle position of this card, then you can Special Summon 1 " \
				+ "\"Blue-Eyes White Dragon\" from your hand, Deck, or GY."]:
		t.is_true(text.contains(sentence),
			"the sentence is in the verified official text")
		t.is_true(quick.clause_text.contains(sentence)
			or trigger.clause_text.contains(sentence),
			"and it is implemented verbatim by one of the two clauses")

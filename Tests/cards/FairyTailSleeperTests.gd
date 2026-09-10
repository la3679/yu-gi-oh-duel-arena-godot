class_name FairyTailSleeperTests
extends RefCounted

## Per-card suite for `Fairy Tail - Sleeper`. Research/CARD_RULINGS.md **R5**.
##
##   "FLIP: You can Special Summon 1 monster from your hand.
##    When your opponent activates a Normal Spell/Trap Card (Quick Effect): You can
##    Tribute 1 other monster; the activated effect becomes "Change 1 face-up monster your
##    opponent controls to face-down Defense Position". You can only use this effect of
##    "Fairy Tail - Sleeper" once per turn."
##
## The generic half — that a Chain Link's resolution text can be REPLACED without either
## negation, that the replacement resolves under the substituted card's own controller,
## that an in-effect restriction is replaced away while an activation restriction survives
## (official Q&A fid 8714 / fid 19695), and that every impossible substitution is refused
## loudly — is proved by the substitution section of `ChainTests`, which was written and
## green before this card existed. What is specific to this card, and what this suite is
## about, is:
##
##   * **the fact the printed English text does not carry, and it is a PERMISSION** (R5
##     Part A): clause (1) **CAN** be activated during the Damage Step. Seven previous
##     cards' supplements each carried a Damage Step *restriction* the English omitted;
##     this one carries the opposite, and taking the engine's default would be **wrong**.
##     Asserted at every sub-step, in both directions, next to clause (2) which is refused;
##   * **the counter-intuitive half of R5 Part B**: the replacement becomes the OPPONENT's
##     card's text, so its "your opponent" means **Sleeper's own controller**. Sleeper
##     flips a monster on its **own** side. Asserted in both directions, because an
##     implementation that resolved the replacement as *Sleeper's* effect would hit the
##     wrong side of the field and a careless test would still pass;
##   * that the substituted card is **not negated**: it still resolves, and a Normal Spell
##     still reaches the Graveyard as a resolved card;
##   * the **vacuous path** the supplement calls out (R5 Part B): with no face-up monster
##     on Sleeper's side the substitution **still happens** and the opponent's card does
##     nothing. An implementation that quietly did nothing at all would look identical from
##     the board, so the substitution is asserted to have OCCURRED separately from any
##     visible effect;
##   * that the answered card must be the opponent's, a **Normal** Spell/Trap, and
##     **directly** below on the Chain — three separate requirements, each with a negative;
##   * that "Tribute 1 **other** monster" excludes Sleeper itself;
##   * that the once-per-turn is the **named-effect** shape and is spent at activation.
##
## **Real pool cards are used where the pool has one.** Sleeper's own archetype gives it a
## board: it is one of the three 1850 ATK Spellcasters `Fairy Tail - Luna` searches, which
## is asserted here too so the two cards' shared fact cannot drift. The opponent's Normal
## Spell/Trap is synthetic, because what matters about it is only its **kind** and that its
## printed effect is observable — using a real pool Spell would test that Spell instead.

const CARD_UNDER_TEST := "Fairy Tail - Sleeper"
const EFFECT_FLIP := "flip_special_summon_from_hand"
const EFFECT_SUBSTITUTE := "substitute_opponent_normal_spell_trap_effect"
const REPLACEMENT_EFFECT_ID := "becomes_change_1_opponent_monster_face_down"

## The three Spellcaster monsters with exactly 1850 ATK in the V1 pool — all in deck 2.
## `FairyTailLunaTests` asserts the same list from the other side.
const QUALIFYING_1850 := ["Fairy Tail - Luna", "Fairy Tail - Rella", "Fairy Tail - Sleeper"]


static func run() -> TestCase:
	var t := TestCase.new("FairyTailSleeperTests")
	# Identity and declaration
	_test_the_card_is_registered_and_declared_correctly(t)
	_test_it_is_one_of_lunas_1850_spellcasters(t)
	# The Damage Step — the pattern break
	_test_clause_1_is_PERMITTED_in_the_damage_step(t)
	_test_clause_2_is_refused_in_the_damage_step(t)
	# Clause 1
	_test_flip_special_summons_from_the_hand(t)
	_test_flip_is_optional_and_may_be_declined(t)
	_test_flip_is_not_offered_with_nothing_to_summon(t)
	_test_flip_only_fires_for_this_copy(t)
	# Clause 2 — the substitution
	_test_the_opponents_normal_spell_resolves_the_replacement(t)
	_test_the_replacement_hits_SLEEPERS_OWN_side(t)
	_test_the_substituted_card_is_not_negated_and_reaches_the_gy(t)
	_test_sleeper_can_flip_itself_face_down(t)
	_test_the_vacuous_path_still_substitutes(t)
	_test_the_substitution_happens_even_when_it_changes_nothing(t)
	# Clause 2 — the three activation requirements, each with a negative
	_test_only_the_opponents_activation_qualifies(t)
	_test_only_a_NORMAL_spell_or_trap_qualifies(t)
	_test_it_must_chain_directly(t)
	# Clause 2 — cost and once-per-turn
	_test_the_tribute_must_be_another_monster(t)
	_test_it_is_not_offered_without_a_tribute(t)
	_test_the_once_per_turn_is_named_and_spent_at_activation(t)
	# Interaction with batch 16
	_test_an_unaffected_monster_is_not_flipped(t)
	# Replay
	_test_the_same_seed_and_script_replay_identically(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _effect(effect_id: String) -> EffectDef:
	var d := _def()
	if d == null:
		return null
	for entry in d.effects:
		var e: EffectDef = entry
		if e.effect_id == effect_id:
			return e
	return null


## Player 0, Main Phase 1 of their own turn.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A Normal Spell (or another kind) whose OWN printed effect appends "PRINTED" to `log`
## when it resolves — so a test can see whether the printed text or the replacement ran.
static func _opponent_spell(log: Array, name: String = "Opponent Normal Spell",
		kind: Enums.STKind = Enums.STKind.NORMAL_SPELL) -> CardDef:
	var d := TestFixtures.spell(name, kind) if Enums.is_spell(kind) \
		else TestFixtures.trap(name, kind)
	return TestFixtures.with_effect(d, TestFixtures.card_activation(
		"opponent_printed_effect", Enums.spell_speed_for_st(kind), log, "PRINTED"))


## Sleeper face-up on player 0's field, a spare monster of player 0's to Tribute, and a
## face-up monster for each player. Player 1 holds a Normal Spell in hand to activate.
##
## Sleeper is PLACED rather than Flip Summoned, so clause (1) never fires and cannot hide
## what a clause (2) test is measuring.
static func _substitution_board(seed_value: int, log: Array,
		spell_def: CardDef = null) -> Dictionary:
	var d := _board(seed_value)
	var engine: DuelEngine = d["engine"]
	d["sleeper"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	d["fodder"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Tribute Fodder", 4, 1200, 1000))
	d["mine"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Monster", 4, 1400, 1000))
	d["theirs"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1600, 1000))
	d["spell"] = TestFixtures.give_to_hand(engine, 1,
		spell_def if spell_def != null else _opponent_spell(log))
	return d


## Player 1 activates their Spell/Trap; player 0 answers with Sleeper's clause (2) if the
## engine offers it. Returns true when Sleeper's effect was actually activated.
##
## It is player 0's turn, so player 1 activating a Normal Spell from the hand is not
## legal — the board is therefore flipped to player 1's turn by the caller when needed.
static func _opponent_activates_and_sleeper_answers(engine: DuelEngine,
		spell: CardInstance, sleeper: CardInstance, tribute: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	if a == null:
		return false
	if not engine.submit_action(a):
		return false
	var answer = _sleeper_response(engine, sleeper)
	if answer == null:
		TestFixtures.pass_until_open(engine)
		return false
	if tribute != null:
		answer = answer.with_choices({"cost_ids": [tribute.id]})
	if not engine.submit_action(answer):
		TestFixtures.pass_until_open(engine)
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _sleeper_response(engine: DuelEngine, sleeper: CardInstance):
	var guard := 0
	while guard < 8 and engine.timing != DuelEngine.Timing.OPEN:
		guard += 1
		var found = TestFixtures.find_action(engine.get_legal_responses(0),
			Enums.ActionKind.ACTIVATE_EFFECT, sleeper.id, EFFECT_SUBSTITUTE)
		if found != null:
			return found
		var waiting := engine.waiting_player()
		if waiting == -1:
			return null
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting)):
			return null
	return null


## Move to player 1's turn, Main Phase 1, so player 1 may activate a Normal Spell.
static func _to_opponents_main_phase(engine: DuelEngine) -> bool:
	if not TestFixtures.end_turn(engine):
		return false
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	return engine.state.turn_player_id == 1


static func _substitution_events(engine: DuelEngine) -> Array:
	return TestFixtures.events_of(engine,
		GameEvent.Kind.CHAIN_LINK_EFFECT_SUBSTITUTED)


# ---------------------------------------------------------------------------
# Identity and declaration
# ---------------------------------------------------------------------------

static func _test_the_card_is_registered_and_declared_correctly(t: TestCase) -> void:
	t.start("the card is registered and both clauses are declared as the supplement says")
	var d := _def()
	t.not_null(d, "`Fairy Tail - Sleeper` is in the registry")
	if d == null:
		return
	t.eq(d.base_atk, 1850, "1850 ATK")
	t.eq(d.base_def, 1000, "1000 DEF")
	t.eq(d.level, 4, "Level 4")
	t.eq(d.effects.size(), 2, "two effect clauses, matching the two official clauses")

	var flip := _effect(EFFECT_FLIP)
	t.not_null(flip, "clause 1 is declared")
	if flip != null:
		t.eq(flip.effect_type, Enums.EffectType.FLIP, "clause 1 is a FLIP effect")
		t.eq(flip.optionality, Enums.Optionality.OPTIONAL,
			"\"You can\" — clause 1 is OPTIONAL, unlike the pool's other Flip monster")
		t.eq(flip.spell_speed, Enums.SpellSpeed.SS1, "clause 1 is Spell Speed 1")

	var sub := _effect(EFFECT_SUBSTITUTE)
	t.not_null(sub, "clause 2 is declared")
	if sub != null:
		t.eq(sub.effect_type, Enums.EffectType.QUICK, "clause 2 is a Quick Effect")
		t.eq(sub.spell_speed, Enums.SpellSpeed.SS2, "clause 2 is Spell Speed 2")
		t.is_true(sub.once_per_turn_named_effect,
			"\"this effect of 'Fairy Tail - Sleeper'\" is the NAMED-effect once-per-turn, "
			+ "not a per-instance one")
		t.is_false(sub.once_per_turn_instance,
			"and specifically NOT the per-instance shape")
		t.is_false(sub.targets,
			"clause 2 declares no target — and neither does its replacement (R5 Part C)")


static func _test_it_is_one_of_lunas_1850_spellcasters(t: TestCase) -> void:
	t.start("it is one of the three 1850 ATK Spellcasters `Fairy Tail - Luna` searches")
	var cards: Dictionary = _library()["cards"]
	var found: Array = []
	for name in cards.keys():
		var d: CardDef = cards[name]
		if d.category == Enums.Category.MONSTER and d.base_atk == 1850 \
				and d.race == "Spellcaster":
			found.append(name)
	found.sort()
	var expected := QUALIFYING_1850.duplicate()
	expected.sort()
	t.eq(found, expected,
		"the pool's 1850 ATK Spellcasters are exactly the three Fairy Tail monsters — "
		+ "the same fact `FairyTailLunaTests` asserts from the other side")


# ---------------------------------------------------------------------------
# The Damage Step. R5 Part A — the eight-batch pattern breaks, and inverts.
# ---------------------------------------------------------------------------

static func _test_clause_1_is_PERMITTED_in_the_damage_step(t: TestCase) -> void:
	t.start("clause 1 CAN be activated during the Damage Step — the supplement GRANTS "
		+ "permission the English text does not mention, inverting a seven-card pattern")
	var e := _effect(EFFECT_FLIP)
	t.not_null(e, "clause 1 exists")
	if e == null:
		return
	t.ne(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"clause 1 does NOT take the engine's default refusal — taking it would be wrong, "
		+ "which is the opposite of the last two batches")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"it is the trigger-collected Damage Step window a Flip effect turned face-up by "
		+ "an attacker occupies")

	var d := _board(4801)
	var state: GameState = (d["engine"] as DuelEngine).state
	t.is_true(ActivationRules.damage_step_ok(state, e),
		"outside the Damage Step it is allowed")
	state.battle_step = Enums.BattleStep.DAMAGE
	for substep in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		state.damage_substep = substep
		t.is_true(ActivationRules.damage_step_ok(state, e),
			"PERMITTED in Damage Step sub-step %d — 「ダメージステップ中に条件を満たした場合"
				% int(substep) + "でも発動できます。」")


static func _test_clause_2_is_refused_in_the_damage_step(t: TestCase) -> void:
	t.start("clause 2 cannot be activated during the Damage Step, at any sub-step")
	var e := _effect(EFFECT_SUBSTITUTE)
	t.not_null(e, "clause 2 exists")
	if e == null:
		return
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"the permission is NONE — 「ダメージステップ中には発動できません。」")

	var d := _board(4802)
	var state: GameState = (d["engine"] as DuelEngine).state
	t.is_true(ActivationRules.damage_step_ok(state, e),
		"outside the Damage Step the gate allows it")
	state.battle_step = Enums.BattleStep.DAMAGE
	for substep in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		state.damage_substep = substep
		t.is_false(ActivationRules.damage_step_ok(state, e),
			"refused in Damage Step sub-step %d" % int(substep))

	# The control that makes both tests above mean something: the SAME gate, the SAME
	# sub-step, and the two clauses of this ONE card disagree. Neither result can be the
	# gate refusing or allowing everything.
	state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	var flip := _effect(EFFECT_FLIP)
	if flip != null:
		t.is_true(ActivationRules.damage_step_ok(state, flip),
			"CONTROL: in the very same sub-step, clause 1 of the same card IS permitted")
		t.is_false(ActivationRules.damage_step_ok(state, e),
			"CONTROL: and clause 2 is not")


# ---------------------------------------------------------------------------
# Clause 1 — "FLIP: You can Special Summon 1 monster from your hand."
# ---------------------------------------------------------------------------

static func _test_flip_special_summons_from_the_hand(t: TestCase) -> void:
	t.start("clause 1 Special Summons a monster from the hand when the card is flipped")
	var d := _board(4810)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var sleeper := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	# Exactly ONE monster in hand, so the "which one?" choice has a single candidate and
	# the test measures the clause rather than the controller's default pick.
	for entry in engine.state.player(0).hand.duplicate():
		var c: CardInstance = entry
		engine.state.move_card(c, Enums.Zone.GRAVEYARD,
			Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})
	var in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Hand Monster", 4, 1300, 1000))

	p0.default_yes = true
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, sleeper.id)
	t.not_null(a, "the face-down Sleeper may be Flip Summoned")
	if a == null:
		return
	t.is_true(engine.submit_action(a), "the Flip Summon is accepted")
	TestFixtures.pass_until_open(engine)

	t.is_true(sleeper.is_face_up(), "Sleeper is now face-up")
	t.eq(in_hand.zone, Enums.Zone.MONSTER_ZONE,
		"the monster from the hand was Special Summoned to the field")
	t.eq(in_hand.controller_id, 0, "under its owner's control")


static func _test_flip_is_optional_and_may_be_declined(t: TestCase) -> void:
	t.start("clause 1 is optional — declining leaves the monster in the hand")
	var d := _board(4811)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var sleeper := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Hand Monster", 4, 1300, 1000))

	p0.default_yes = false
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, sleeper.id)
	if a != null:
		engine.submit_action(a)
		TestFixtures.pass_until_open(engine)
	t.is_true(sleeper.is_face_up(), "Sleeper was still flipped face-up")
	t.eq(in_hand.zone, Enums.Zone.HAND,
		"but the monster stayed in the hand — \"You can\" was declined")


static func _test_flip_is_not_offered_with_nothing_to_summon(t: TestCase) -> void:
	t.start("clause 1 is not activatable with an empty hand — a vacuous activation is "
		+ "refused rather than resolving to nothing")
	var d := _board(4812)
	var engine: DuelEngine = d["engine"]
	var sleeper := TestFixtures.give_monster_on_field(engine, 0, _def())
	var state := engine.state
	# Empty the hand so there is nothing that could be Special Summoned.
	for entry in state.player(0).hand.duplicate():
		var c: CardInstance = entry
		state.move_card(c, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})

	var e := _effect(EFFECT_FLIP)
	t.not_null(e, "clause 1 exists")
	if e == null:
		return
	var ctx := EffectContext.new(state, sleeper, e)
	ctx.controller_id = 0
	ctx.engine = engine
	ctx.trigger_event = GameEvent.new(GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		{"card_id": sleeper.id})
	t.is_false(bool(e.condition.call(ctx)),
		"with nothing in hand to Special Summon, the condition is false")

	# CONTROL: one legal monster in the hand and the same condition is true, so the
	# refusal above is about the hand and not about the probe being malformed.
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Late Arrival", 4, 1000, 1000))
	t.is_true(bool(e.condition.call(ctx)),
		"CONTROL: with a summonable monster in hand the condition is true")


static func _test_flip_only_fires_for_this_copy(t: TestCase) -> void:
	t.start("clause 1 fires only for THIS card being flipped, not for any other monster")
	var d := _board(4813)
	var engine: DuelEngine = d["engine"]
	var sleeper := TestFixtures.give_monster_on_field(engine, 0, _def())
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Somebody Else", 4, 1000, 1000))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Hand Monster", 4, 1300, 1000))

	var e := _effect(EFFECT_FLIP)
	if e == null:
		return
	var ctx := EffectContext.new(engine.state, sleeper, e)
	ctx.controller_id = 0
	ctx.engine = engine
	ctx.trigger_event = GameEvent.new(GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		{"card_id": other.id})
	t.is_false(bool(e.condition.call(ctx)),
		"another monster being flipped does not fire this copy's clause 1")
	ctx.trigger_event = GameEvent.new(GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		{"card_id": sleeper.id})
	t.is_true(bool(e.condition.call(ctx)),
		"CONTROL: this copy being flipped does")


# ---------------------------------------------------------------------------
# Clause 2 — the substitution
# ---------------------------------------------------------------------------

static func _test_the_opponents_normal_spell_resolves_the_replacement(
		t: TestCase) -> void:
	t.start("the opponent's Normal Spell resolves the REPLACEMENT text and not its own")
	var log := []
	var d := _substitution_board(4820, log)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is now the opponent's Main Phase")
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true

	t.is_true(_opponent_activates_and_sleeper_answers(engine, d["spell"], d["sleeper"],
		d["fodder"]), "the opponent activated a Normal Spell and Sleeper answered it")

	t.eq(_substitution_events(engine).size(), 1,
		"exactly one substitution happened")
	t.is_false(log.has("PRINTED"),
		"the opponent's Spell did NOT resolve its own printed effect")


static func _test_the_replacement_hits_SLEEPERS_OWN_side(t: TestCase) -> void:
	t.start("R5 Part B: the replacement flips a monster on SLEEPER'S OWN side of the "
		+ "field, because it became the OPPONENT's card's text")
	var log := []
	var d := _substitution_board(4821, log)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var p0: ScriptedController = d["p0"]
	var p1: ScriptedController = d["p1"]
	p0.default_yes = true
	p1.default_yes = true

	var mine: CardInstance = d["mine"]
	var theirs: CardInstance = d["theirs"]
	var sleeper: CardInstance = d["sleeper"]
	t.is_true(mine.is_face_up(), "player 0's monster starts face-up")
	t.is_true(theirs.is_face_up(), "player 1's monster starts face-up")

	# The choice belongs to the player resolving the replacement — player 1, the Spell's
	# controller — so it is scripted rather than left to a default pick. That the choice
	# is PUT TO player 1 at all is itself part of the ruling.
	p1.queue([mine.id])

	t.is_true(_opponent_activates_and_sleeper_answers(engine, d["spell"], sleeper,
		d["fodder"]), "the substitution was activated")

	t.is_true(theirs.is_face_up(),
		"the OPPONENT's monster was NOT flipped — the replacement is the opponent's own "
		+ "card's text, so its \"your opponent\" does not mean them")
	t.is_false(mine.is_face_up(),
		"a monster on SLEEPER'S OWN side was flipped face-down instead. This is the "
		+ "counter-intuitive half of R5 Part B, confirmed by 「自分フィールド」 in the "
		+ "supplement and by 「相手プレイヤーに…させる」 in Q&A fid 9677")
	t.eq(mine.position, Enums.Position.FACE_DOWN_DEFENSE,
		"and specifically to face-down DEFENSE Position")
	t.eq(p1.errors, [],
		"and player 1 was asked exactly the choice the script answered — the replacement "
		+ "is resolved BY the Spell's controller, not by Sleeper's")

	# Side-level restatement, independent of WHICH monster was picked: the ruling is about
	# the side of the field, so assert that directly too.
	var p0_face_down := 0
	for entry in engine.state.player(0).monsters():
		var c: CardInstance = entry
		if not c.is_face_up():
			p0_face_down += 1
	var p1_face_down := 0
	for entry in engine.state.player(1).monsters():
		var c: CardInstance = entry
		if not c.is_face_up():
			p1_face_down += 1
	t.eq(p0_face_down, 1, "exactly one monster on SLEEPER'S side ended face-down")
	t.eq(p1_face_down, 0, "and none at all on the opponent's side")


static func _test_the_substituted_card_is_not_negated_and_reaches_the_gy(
		t: TestCase) -> void:
	t.start("the substituted card is NOT negated: it resolves, and a Normal Spell reaches "
		+ "the Graveyard as a resolved card")
	var log := []
	var d := _substitution_board(4822, log)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true
	var spell: CardInstance = d["spell"]

	t.is_true(_opponent_activates_and_sleeper_answers(engine, spell, d["sleeper"],
		d["fodder"]), "the substitution was activated")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 0,
		"no activation was negated — substitution is not activation negation")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 0,
		"no effect was negated either — substitution is not effect negation")
	t.eq(spell.zone, Enums.Zone.GRAVEYARD,
		"the Normal Spell reached the Graveyard, as a card that resolved")


static func _test_sleeper_can_flip_itself_face_down(t: TestCase) -> void:
	t.start("Sleeper may flip ITSELF face-down, re-arming clause 1 — the design intent, "
		+ "and the reason R5 Part B's reading is not a drawback")
	var log := []
	var d := _substitution_board(4823, log)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var p0: ScriptedController = d["p0"]
	var sleeper: CardInstance = d["sleeper"]
	var state := engine.state
	# Leave Sleeper as the only face-up monster player 0 controls, so the replacement's
	# choice can only be Sleeper itself.
	for key in ["mine"]:
		var c: CardInstance = d[key]
		state.move_card(c, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})
	p0.default_yes = true

	t.is_true(sleeper.is_face_up(), "Sleeper starts face-up")
	t.is_true(_opponent_activates_and_sleeper_answers(engine, d["spell"], sleeper,
		d["fodder"]), "the substitution was activated")
	t.is_false(sleeper.is_face_up(),
		"Sleeper flipped ITSELF face-down — its own clause 1 is now armed again")
	t.eq(sleeper.position, Enums.Position.FACE_DOWN_DEFENSE,
		"in face-down Defense Position")


static func _test_the_vacuous_path_still_substitutes(t: TestCase) -> void:
	t.start("the VACUOUS path: with no face-up monster on Sleeper's side the "
		+ "substitution STILL happens and the opponent's card does nothing")
	var log := []
	var d := _substitution_board(4824, log)
	var engine: DuelEngine = d["engine"]
	var state := engine.state

	# Strip player 0's field entirely, so the replacement — resolved as PLAYER 1's effect
	# — has nothing at all to choose. This is exactly the board the supplement describes:
	# 「処理時に、自分フィールドに表側表示のモンスターが存在しない場合でも、この効果は適用され…」
	for entry in state.player(0).monsters():
		var c: CardInstance = entry
		state.move_card(c, Enums.Zone.GRAVEYARD,
			Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})
	t.eq(state.player(0).monsters().size(), 0,
		"player 0 controls no monster at all")

	var replacement := EffectPrimitives.become_change_opponent_monster_face_down(
		"Change 1 face-up monster your opponent controls to face-down Defense Position")
	var ctx := EffectContext.new(state, d["spell"], replacement)
	ctx.controller_id = 1
	ctx.engine = engine
	var before := TestFixtures.count_events(engine,
		GameEvent.Kind.BATTLE_POSITION_CHANGED)
	replacement.resolve.call(ctx)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_POSITION_CHANGED),
		before,
		"nothing was flipped — 「結果的に、発動した相手の通常魔法・通常罠カードの"
		+ "効果処理は何も行われなくなります。」")

	# CONTROL: the SAME replacement on a board where player 0 does control a face-up
	# monster DOES flip one. Without this, "nothing happened" would be indistinguishable
	# from a replacement that never does anything at all — which is precisely the vacuous
	# reading the supplement's wording invites.
	var late := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Late Arrival", 4, 1100, 1000))
	var ctx2 := EffectContext.new(state, d["spell"], replacement)
	ctx2.controller_id = 1
	ctx2.engine = engine
	replacement.resolve.call(ctx2)
	t.is_false(late.is_face_up(),
		"CONTROL: with a face-up monster on player 0's side, the same replacement DOES "
		+ "flip it — so the empty case above is a real branch and not a dead primitive")


## The substitution is asserted to have HAPPENED, separately from anything visible on the
## board — the whole point of R5 Part B's empty case is that the two come apart.
static func _test_the_substitution_happens_even_when_it_changes_nothing(
		t: TestCase) -> void:
	t.start("the substitution is recorded even when it changes nothing on the board")
	var log := []
	var d := _substitution_board(4825, log)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var p0: ScriptedController = d["p0"]
	var p1: ScriptedController = d["p1"]
	p0.default_yes = true
	p1.default_yes = true
	var state := engine.state
	var sleeper: CardInstance = d["sleeper"]

	# Player 0 keeps only Sleeper and the Tribute fodder. The fodder is consumed by the
	# cost, so at resolution Sleeper is the only face-up monster and IT is what gets
	# flipped — the board changes, but the opponent's Spell still did nothing of its own.
	state.move_card(d["mine"], Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})

	t.is_true(_opponent_activates_and_sleeper_answers(engine, d["spell"], sleeper,
		d["fodder"]), "the substitution was activated")
	t.eq(_substitution_events(engine).size(), 1,
		"the substitution was RECORDED as an event")
	t.is_false(log.has("PRINTED"),
		"and the opponent's Spell never resolved its own printed effect")


# ---------------------------------------------------------------------------
# Clause 2 — the three activation requirements, each with a negative
# ---------------------------------------------------------------------------

static func _test_only_the_opponents_activation_qualifies(t: TestCase) -> void:
	t.start("only the OPPONENT's activation qualifies — your own Normal Spell does not")
	var log := []
	var d := _substitution_board(4830, log)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var sleeper: CardInstance = d["sleeper"]
	# Player 0 — Sleeper's own controller — activates a Normal Spell instead.
	var mine := TestFixtures.give_to_hand(engine, 0, _opponent_spell(log, "My Own Spell"))
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, mine.id)
	t.not_null(a, "player 0 may activate their own Normal Spell")
	if a == null:
		return
	t.is_true(engine.submit_action(a), "and does")

	t.is_null(TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, sleeper.id, EFFECT_SUBSTITUTE),
		"Sleeper's clause 2 is NOT offered against its own controller's activation — "
		+ "「相手が…発動した時」")
	TestFixtures.pass_until_open(engine)
	t.is_true(log.has("PRINTED"),
		"CONTROL: and that Spell resolved its own printed effect normally")


static func _test_only_a_NORMAL_spell_or_trap_qualifies(t: TestCase) -> void:
	t.start("only a NORMAL Spell/Trap qualifies — a Quick-Play Spell does not")
	var log := []
	var quick_play := _opponent_spell(log, "Opponent Quick-Play",
		Enums.STKind.QUICK_PLAY_SPELL)
	var d := _substitution_board(4831, log, quick_play)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var sleeper: CardInstance = d["sleeper"]
	var spell: CardInstance = d["spell"]

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(a, "the opponent may activate their Quick-Play Spell")
	if a == null:
		return
	t.is_true(engine.submit_action(a), "and does")
	t.is_null(_sleeper_response(engine, sleeper),
		"Sleeper's clause 2 is NOT offered against a Quick-Play Spell — the text says "
		+ "NORMAL Spell/Trap and means it")
	TestFixtures.pass_until_open(engine)
	t.eq(_substitution_events(engine).size(), 0, "and nothing was substituted")

	# CONTROL: the identical board with a NORMAL Spell IS answered, so the refusal above
	# is about the card's kind and nothing else.
	var log2 := []
	var d2 := _substitution_board(4832, log2)
	var engine2: DuelEngine = d2["engine"]
	t.is_true(_to_opponents_main_phase(engine2), "control board is on the opponent's turn")
	var p0: ScriptedController = d2["p0"]
	p0.default_yes = true
	t.is_true(_opponent_activates_and_sleeper_answers(engine2, d2["spell"], d2["sleeper"],
		d2["fodder"]),
		"CONTROL: the same board with a NORMAL Spell is answered")


static func _test_it_must_chain_directly(t: TestCase) -> void:
	t.start("clause 2 must chain DIRECTLY to the activation it answers — "
		+ "「その発動に直接チェーンして発動できます。」")
	var log := []
	var d := _substitution_board(4833, log)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var sleeper: CardInstance = d["sleeper"]
	var e := _effect(EFFECT_SUBSTITUTE)
	if e == null:
		return

	# Chain Link 1 is the opponent's Normal Spell; Chain Link 2 is somebody else's. Asking
	# as Chain Link 3, the link DIRECTLY below is no longer the Spell.
	var cm := ChainManager.new(state)
	cm.engine = engine
	var spell_def := _opponent_spell(log)
	var spell := TestFixtures.give(engine, 1, spell_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	cm.add_link(spell, spell_def.effects[0], 1)

	var ctx_direct := EffectContext.new(state, sleeper, e)
	ctx_direct.controller_id = 0
	ctx_direct.engine = engine
	ctx_direct.link = cm.add_link(sleeper, e, 0)
	t.not_null(EffectPrimitives.opponent_normal_spell_trap_activation_below(ctx_direct),
		"as Chain Link 2, directly above the Spell, the activation is found")

	var filler_def := TestFixtures.spell("Filler", Enums.STKind.QUICK_PLAY_SPELL)
	TestFixtures.with_effect(filler_def,
		TestFixtures.card_activation("filler", Enums.SpellSpeed.SS2, log, "FILLER"))
	var filler := TestFixtures.give(engine, 1, filler_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)

	var state2 := engine.state
	var cm2 := ChainManager.new(state2)
	cm2.engine = engine
	cm2.add_link(spell, spell_def.effects[0], 1)
	cm2.add_link(filler, filler_def.effects[0], 1)
	var ctx_indirect := EffectContext.new(state2, sleeper, e)
	ctx_indirect.controller_id = 0
	ctx_indirect.engine = engine
	ctx_indirect.link = cm2.add_link(sleeper, e, 0)
	t.is_null(EffectPrimitives.opponent_normal_spell_trap_activation_below(ctx_indirect),
		"with another link in between, the Spell is NOT found — an intervening Chain "
		+ "Link means the timing was missed")


# ---------------------------------------------------------------------------
# Clause 2 — cost and once-per-turn
# ---------------------------------------------------------------------------

static func _test_the_tribute_must_be_another_monster(t: TestCase) -> void:
	t.start("\"Tribute 1 OTHER monster\" — Sleeper is never a legal Tribute for itself")
	var log := []
	var d := _substitution_board(4840, log)
	var engine: DuelEngine = d["engine"]
	var sleeper: CardInstance = d["sleeper"]
	var e := _effect(EFFECT_SUBSTITUTE)
	if e == null:
		return
	var ctx := EffectContext.new(engine.state, sleeper, e)
	ctx.controller_id = 0
	ctx.engine = engine

	var candidates := EffectPrimitives.tribute_cost_candidates(ctx,
		func(card: CardInstance) -> bool:
			return card.id != sleeper.id)
	var ids := candidates.map(func(c): return c.id)
	t.is_false(ids.has(sleeper.id),
		"Sleeper itself is excluded from its own Tribute candidates")
	t.is_true(ids.has((d["fodder"] as CardInstance).id),
		"CONTROL: another monster player 0 controls IS a candidate")
	t.is_false(ids.has((d["theirs"] as CardInstance).id),
		"and the opponent's monster is not — a Tribute comes from your own field")


static func _test_it_is_not_offered_without_a_tribute(t: TestCase) -> void:
	t.start("clause 2 is not offered when there is no OTHER monster to Tribute — a cost "
		+ "that cannot be paid makes the activation illegal, not merely ineffective")
	var log := []
	var d := _substitution_board(4841, log)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var sleeper: CardInstance = d["sleeper"]
	# Leave Sleeper alone on player 0's field.
	for key in ["fodder", "mine"]:
		var c: CardInstance = d[key]
		state.move_card(c, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, (d["spell"] as CardInstance).id)
	t.not_null(a, "the opponent activates their Normal Spell")
	if a == null:
		return
	engine.submit_action(a)
	t.is_null(_sleeper_response(engine, sleeper),
		"with no other monster to Tribute, clause 2 is not offered at all")
	TestFixtures.pass_until_open(engine)
	t.is_true(log.has("PRINTED"),
		"CONTROL: and the opponent's Spell resolved its own effect normally")


static func _test_the_once_per_turn_is_named_and_spent_at_activation(
		t: TestCase) -> void:
	t.start("the once-per-turn is the NAMED-effect shape and is spent at activation")
	var e := _effect(EFFECT_SUBSTITUTE)
	if e == null:
		return
	t.is_true(e.once_per_turn_named_effect,
		"\"You can only use this effect of 'Fairy Tail - Sleeper' once per turn\" is the "
		+ "named-effect restriction — a second COPY of the card could not use it either")
	t.is_false(e.once_per_turn_instance,
		"and not the per-instance shape, which a second copy would escape")

	var log := []
	var d := _substitution_board(4842, log)
	var engine: DuelEngine = d["engine"]
	t.is_true(_to_opponents_main_phase(engine), "it is the opponent's Main Phase")
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true
	var sleeper: CardInstance = d["sleeper"]

	t.is_true(_opponent_activates_and_sleeper_answers(engine, d["spell"], sleeper,
		d["fodder"]), "the first use is activated")
	t.eq(_substitution_events(engine).size(), 1, "and substituted once")

	# A second Normal Spell in the same turn.
	var second := TestFixtures.give_to_hand(engine, 1, _opponent_spell(log, "Second Spell"))
	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, second.id)
	if a != null:
		engine.submit_action(a)
		t.is_null(_sleeper_response(engine, sleeper),
			"clause 2 is not offered a second time in the same turn")
		TestFixtures.pass_until_open(engine)
	t.eq(_substitution_events(engine).size(), 1,
		"still exactly one substitution this turn")


# ---------------------------------------------------------------------------
# Interaction with batch 16's immunity gate
# ---------------------------------------------------------------------------

static func _test_an_unaffected_monster_is_not_flipped(t: TestCase) -> void:
	t.start("a monster that is unaffected by card effects is not flipped by the "
		+ "replacement — batch 16's immunity gate, seen from a third card")
	var d := _board(4850)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var immune := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Immune One", 4, 1500, 1000))
	var source := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("The Source", 4, 1000, 1000))

	var replacement := EffectPrimitives.become_change_opponent_monster_face_down(
		"Change 1 face-up monster your opponent controls to face-down Defense Position")
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true

	# CONTROL first: an ordinary monster IS flipped, so the refusal below is the gate and
	# not the replacement failing to do anything at all.
	var ctx := EffectContext.new(state, source, replacement)
	ctx.controller_id = 1
	ctx.engine = engine
	replacement.resolve.call(ctx)
	t.is_false(immune.is_face_up(),
		"CONTROL: without immunity the monster is flipped face-down")

	# Now with immunity.
	state.set_battle_position(immune, Enums.Position.FACE_UP_ATTACK, false)
	immune.unaffected_by_effects = true
	t.is_true(immune.is_face_up(), "the monster is face-up again")
	var ctx2 := EffectContext.new(state, source, replacement)
	ctx2.controller_id = 1
	ctx2.engine = engine
	replacement.resolve.call(ctx2)
	t.is_true(immune.is_face_up(),
		"an unaffected monster is NOT flipped — the gate inside set_battle_position() "
		+ "refuses the application, and this card adds no code for it")


# ---------------------------------------------------------------------------
# Deterministic replay
# ---------------------------------------------------------------------------

static func _test_the_same_seed_and_script_replay_identically(t: TestCase) -> void:
	t.start("the same seed and the same controller script replay identically")
	var runs := []
	for i in range(2):
		var log := []
		var d := _substitution_board(4860, log)
		var engine: DuelEngine = d["engine"]
		_to_opponents_main_phase(engine)
		var p0: ScriptedController = d["p0"]
		var p1: ScriptedController = d["p1"]
		p0.default_yes = true
		p1.default_yes = true
		_opponent_activates_and_sleeper_answers(engine, d["spell"], d["sleeper"],
			d["fodder"])
		var kinds := []
		for ev in engine.state.events:
			kinds.append(int(ev.kind))
		runs.append({
			"kinds": kinds,
			"printed": log.duplicate(),
			"substitutions": _substitution_events(engine).size(),
			"mine_face_up": (d["mine"] as CardInstance).is_face_up(),
			"theirs_face_up": (d["theirs"] as CardInstance).is_face_up(),
		})
	t.eq(runs[0]["kinds"], runs[1]["kinds"],
		"the same sequence of events, in the same order")
	t.eq(runs[0]["printed"], runs[1]["printed"], "the same printed-effect log")
	t.eq(runs[0]["substitutions"], runs[1]["substitutions"],
		"the same number of substitutions")
	t.eq(runs[0]["mine_face_up"], runs[1]["mine_face_up"],
		"the same monster ended face-down on Sleeper's side")
	t.eq(runs[0]["theirs_face_up"], runs[1]["theirs_face_up"],
		"and the opponent's monster was untouched in both runs")

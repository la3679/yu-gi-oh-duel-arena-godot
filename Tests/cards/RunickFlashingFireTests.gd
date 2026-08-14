class_name RunickFlashingFireTests
extends RefCounted

## `Runick Flashing Fire` — Quick-Play Spell, Spell Speed 2.
##
## Official text (verified, `Data/cards/cards.json`, cid 17374):
##
##   "Activate 1 of these effects, but skip your next Battle Phase after activation;
##    ●Target 1 Special Summoned monster your opponent controls; destroy it, then banish the
##    top 2 cards of your opponent's Deck.
##    ●Special Summon 1 "Runick" monster from your Extra Deck to the Extra Monster Zone.
##    You can only activate 1 "Runick Flashing Fire" per turn."
##
## `CARD_RULINGS.md` **R1** governs the card and **R32** the Battle Phase half.
##
## **Both bullets are tested, and the second can never be live in a real duel** — both decks
## have an EMPTY Extra Deck, so no "Runick" monster can ever be there. It is exercised against
## a SYNTHETIC Extra Deck monster and pinned by a real-pool assertion at the end, so the fact
## cannot rot silently.
##
## The two claims that get the most attention:
##
## **R1 — the Battle Phase is skipped ON ACTIVATION, even when the effect is negated.** That
## is the one thing about this card that cannot be inferred from the text alone, and it is
## asserted directly in both the activation-negated and effect-negated cases.
##
## **"destroy it, THEN banish" is conditional.** No destruction, no banishment — the top of
## the opponent's Deck is not touched at all. Asserted with a destruction that is prevented.


const CARD_UNDER_TEST := "Runick Flashing Fire"

const DESTROY_EFFECT_ID := "destroy_special_summoned_and_banish_top"
const SUMMON_EFFECT_ID := "special_summon_runick_from_extra_deck"
const BANISH_COUNT := 2


static func run() -> TestCase:
	var t := TestCase.new("RunickFlashingFireTests")
	# Shape
	_test_the_card_declares_two_bullets_and_one_activation_limit(t)
	# Bullet 1 — targeting
	_test_it_is_not_offered_without_a_special_summoned_opponent_monster(t)
	_test_a_normal_summoned_monster_is_not_a_legal_target(t)
	_test_your_own_special_summoned_monster_is_not_a_legal_target(t)
	# Bullet 1 — resolution
	_test_it_destroys_the_target_and_banishes_the_top_two(t)
	_test_the_banished_cards_are_the_top_two_in_order_and_are_the_opponents(t)
	_test_a_deck_shorter_than_two_banishes_what_is_there(t)
	_test_no_destruction_means_no_banishment(t)
	_test_a_target_that_left_the_field_does_nothing_at_all(t)
	_test_it_is_a_banish_and_not_an_excavate_draw_or_search(t)
	# The Battle Phase consequence — R1
	_test_activating_it_costs_this_turns_battle_phase(t)
	_test_the_skip_is_imposed_at_activation_not_at_resolution(t)
	_test_a_negated_ACTIVATION_still_costs_the_battle_phase(t)
	_test_a_negated_EFFECT_still_costs_the_battle_phase(t)
	_test_the_skip_is_turn_state_and_not_a_flag_on_the_card(t)
	# Once per turn
	_test_only_one_runick_flashing_fire_may_be_activated_per_turn(t)
	# Bullet 2
	_test_bullet_two_is_not_offered_with_an_empty_extra_deck(t)
	_test_bullet_two_is_not_offered_for_a_non_runick_extra_deck_monster(t)
	_test_bullet_two_summons_to_the_extra_monster_zone(t)
	_test_bullet_two_also_costs_the_battle_phase(t)
	# The pool
	_test_bullet_two_is_never_live_in_the_real_pool(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## Player 1 goes first, so player 0 has a real Battle Phase to lose from turn 2 onward.
## Runick is Set on player 0's field and it is their Main Phase 1.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["runick"] = TestFixtures.give_set_spell_trap(engine, 0, _def())
	return d


## Give player 1 a monster that really was SPECIAL Summoned.
static func _their_special_summoned(engine: DuelEngine,
		name: String = "Their Revived One") -> CardInstance:
	var m := TestFixtures.give_monster_on_field(engine, 1, TestFixtures.monster(name))
	m.summoned_by = Enums.SummonKind.SPECIAL
	m.properly_special_summoned = true
	return m


static func _can_battle(engine: DuelEngine, pid: int) -> bool:
	return engine.flow.can_enter_battle_phase(pid)


static func _top_of_deck_ids(engine: DuelEngine, pid: int, count: int) -> Array:
	var out: Array = []
	var deck: Array = engine.state.player(pid).deck
	for i in range(mini(count, deck.size())):
		var c: CardInstance = deck[i]
		out.append(c.id)
	return out


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_two_bullets_and_one_activation_limit(
		t: TestCase) -> void:
	t.start("a Quick-Play Spell at Spell Speed 2 with two bullets, both carrying the "
		+ "once-per-turn ACTIVATION limit on the name")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	if card_def == null:
		return
	t.eq(card_def.category, Enums.Category.SPELL, "it is a Spell Card")
	t.eq(card_def.st_kind, Enums.STKind.QUICK_PLAY_SPELL, "a Quick-Play Spell")
	t.eq(card_def.effects.size(), 2, "two bullets")

	for entry in card_def.effects:
		var e: EffectDef = entry
		t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION,
			"%s is a card activation" % e.effect_id)
		t.eq(e.spell_speed, Enums.SpellSpeed.SS2,
			"%s is Spell Speed 2" % e.effect_id)
		t.check(e.pay_cost.is_valid(),
			"%s applies something at activation time (the Battle Phase skip)" % e.effect_id)

	var destroy: EffectDef = card_def.effects[0]
	var summon: EffectDef = card_def.effects[1]
	t.eq(destroy.effect_id, DESTROY_EFFECT_ID, "bullet 1 is the destroy/banish one")
	t.eq(summon.effect_id, SUMMON_EFFECT_ID, "bullet 2 is the Extra Deck Summon")
	t.check(destroy.targets, "bullet 1 targets")
	t.eq(destroy.target_count_min, 1, "exactly 1")
	t.eq(destroy.target_count_max, 1, "no more than 1")
	t.check(not summon.targets, "bullet 2 does not target — its text never says 'target'")
	t.check(destroy.once_per_turn_named_activation,
		"bullet 1 carries the per-name ACTIVATION limit")
	t.check(summon.once_per_turn_named_activation,
		"and so does bullet 2 — one activation of the card spends the turn's allowance")


# ---------------------------------------------------------------------------
# Bullet 1 — targeting
# ---------------------------------------------------------------------------

static func _test_it_is_not_offered_without_a_special_summoned_opponent_monster(
		t: TestCase) -> void:
	t.start("with nothing Special Summoned on the other side, bullet 1 has no legal target")
	var d := _board(9601)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]

	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID),
		"bullet 1 is not offered")


static func _test_a_normal_summoned_monster_is_not_a_legal_target(t: TestCase) -> void:
	t.start("'1 SPECIAL SUMMONED monster' is narrower than '1 monster' — a Normal Summoned "
		+ "one is not a legal target")
	var d := _board(9602)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var normal := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Normal Summon"))
	normal.summoned_by = Enums.SummonKind.NORMAL
	var special := _their_special_summoned(engine)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID)
	t.not_null(offered, "bullet 1 is offered, because one legal target exists")
	if offered == null:
		return
	var candidates: Array = offered.target_candidates
	t.check(candidates.has(special.id), "the Special Summoned monster is a candidate")
	t.check(not candidates.has(normal.id), "the Normal Summoned one is not")
	t.eq(candidates.size(), 1, "exactly one legal target")


static func _test_your_own_special_summoned_monster_is_not_a_legal_target(
		t: TestCase) -> void:
	t.start("'your OPPONENT controls' — your own Special Summoned monster is not a candidate")
	var d := _board(9603)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Revived One"))
	mine.summoned_by = Enums.SummonKind.SPECIAL
	var theirs := _their_special_summoned(engine)

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID)
	t.not_null(offered, "bullet 1 is offered")
	if offered == null:
		return
	t.check(offered.target_candidates.has(theirs.id), "their monster is a candidate")
	t.check(not offered.target_candidates.has(mine.id), "yours is not")


# ---------------------------------------------------------------------------
# Bullet 1 — resolution
# ---------------------------------------------------------------------------

static func _test_it_destroys_the_target_and_banishes_the_top_two(t: TestCase) -> void:
	t.start("it destroys the targeted monster and banishes the top 2 of the opponent's Deck")
	var d := _board(9604)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	var deck_before: int = engine.state.player(1).deck.size()

	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]),
		"bullet 1 was activated on the Special Summoned monster")

	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the target was destroyed")
	t.eq(target.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"destroyed by a card effect")
	t.eq(engine.state.player(1).deck.size(), deck_before - BANISH_COUNT,
		"two cards left their Deck")
	t.eq(engine.state.player(1).banished.size(), BANISH_COUNT,
		"and both are in their banished zone")


static func _test_the_banished_cards_are_the_top_two_in_order_and_are_the_opponents(
		t: TestCase) -> void:
	t.start("the two cards are the TOP two, taken in order, and go to their OWNER's banished "
		+ "zone face-up")
	var d := _board(9605)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	var expected := _top_of_deck_ids(engine, 1, BANISH_COUNT)
	t.eq(expected.size(), BANISH_COUNT, "there really are two cards to take")

	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]), "activated")

	var actual: Array = []
	for entry in engine.state.player(1).banished:
		var c: CardInstance = entry
		actual.append(c.id)
	t.eq(str(actual), str(expected),
		"exactly the top two, in the order they sat in the Deck")
	for entry in engine.state.player(1).banished:
		var c: CardInstance = entry
		t.eq(c.owner_id, 1, "%s is banished under its owner" % c.card_name())
		t.check(c.is_face_up(), "%s is banished face-up [S1 p.53]" % c.card_name())
		t.eq(c.last_move_reason, Enums.MoveReason.BANISHED,
			"%s records a banishment" % c.card_name())


static func _test_a_deck_shorter_than_two_banishes_what_is_there(t: TestCase) -> void:
	t.start("with one card left in their Deck exactly one is banished, and the player is not "
		+ "decked out by it")
	var d := _board(9606)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	# Empty their Deck down to a single card.
	var deck: Array = engine.state.player(1).deck
	while deck.size() > 1:
		var c: CardInstance = deck[0]
		engine.state.move_card(c, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(engine.state.player(1).deck.size(), 1, "one card left in their Deck")
	var last_id: int = (engine.state.player(1).deck[0] as CardInstance).id

	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]), "activated")

	t.eq(engine.state.player(1).deck.size(), 0, "their Deck is now empty")
	t.eq(engine.state.player(1).banished.size(), 1, "exactly one card was banished")
	t.eq((engine.state.player(1).banished[0] as CardInstance).id, last_id,
		"and it is the one that was there")
	t.check(not engine.state.player(1).has_lost,
		"running the Deck out is not itself a loss — only failing to DRAW is [S1 p.35]")


static func _test_no_destruction_means_no_banishment(t: TestCase) -> void:
	t.start("'destroy it, THEN banish' is conditional: a target that is not destroyed leaves "
		+ "the opponent's Deck untouched")
	var d := _board(9607)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	# A destruction prevention covering one specific card, asked through the same rules-layer
	# query `Gagagashield` and `Kaiser Glider` use.
	var protector := TestFixtures.give_monster_on_field(engine, 1,
		_indestructible_guard("Guardian", target))
	ContinuousEffects.new(engine.state).recompute()
	var deck_before: int = engine.state.player(1).deck.size()

	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]), "activated")

	# Prove the prevention actually fired, rather than the effect having fizzled some other
	# way: the target must still be on the field.
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "the target really was not destroyed")
	t.eq(engine.state.player(1).deck.size(), deck_before,
		"so nothing was banished from their Deck")
	t.eq(engine.state.player(1).banished.size(), 0, "their banished zone is empty")
	t.eq(protector.zone, Enums.Zone.MONSTER_ZONE, "the protector is still there")


## A monster whose continuous clause prevents the destruction of one specific card.
static func _indestructible_guard(card_name: String,
		ward: CardInstance) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, 1000, 1000)
	var e := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"Test: that card cannot be destroyed.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	# The rules layer asks this about every card it is about to destroy, so the first
	# question is always "is this about the card I am warding?".
	e.condition = func(ctx: EffectContext) -> bool:
		var subject = ctx.params.get("card", null)
		return subject != null and (subject as CardInstance).id == ward.id
	return TestFixtures.with_effect(d, e)


static func _test_a_target_that_left_the_field_does_nothing_at_all(t: TestCase) -> void:
	t.start("a target removed in response is no longer a legal one: nothing is destroyed and "
		+ "nothing is banished")
	var d := _board(9608)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	var remover := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Get It Out", target, "bounce"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID)
	t.not_null(offered, "bullet 1 is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, remover.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.check(engine.submit_action(response), "the remover becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(target.zone, Enums.Zone.HAND, "the target really was returned to the hand")
	t.eq(engine.state.player(1).deck.size(), deck_before,
		"their Deck is untouched — a bounce goes to the hand, and the banish never ran")
	t.eq(engine.state.player(1).banished.size(), 0, "nothing was banished")


static func _test_it_is_a_banish_and_not_an_excavate_draw_or_search(t: TestCase) -> void:
	t.start("the top two are BANISHED — not excavated, not drawn, not added to a hand, and "
		+ "not revealed")
	var d := _board(9609)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	var excavated_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED)
	var drawn_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN)
	var added_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_ADDED_TO_HAND)
	var revealed_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_REVEALED)
	var banished_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED)

	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]), "activated")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED),
		banished_before + BANISH_COUNT, "two banishments")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED),
		excavated_before, "no excavation")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN),
		drawn_before, "no draw")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_ADDED_TO_HAND),
		added_before, "nothing added to a hand")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_REVEALED),
		revealed_before, "and nothing revealed")
	t.check(engine.state.player(1).excavated.is_empty(),
		"the excavation holding area was never used")


# ---------------------------------------------------------------------------
# The Battle Phase consequence — CARD_RULINGS.md R1 / R32.
# ---------------------------------------------------------------------------

static func _test_activating_it_costs_this_turns_battle_phase(t: TestCase) -> void:
	t.start("activated in your Main Phase 1, it costs the Battle Phase of that very turn")
	var d := _board(9610)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	t.check(_can_battle(engine, 0), "player 0 could battle before activating it")

	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]), "activated")

	t.check(not _can_battle(engine, 0), "and now cannot enter the Battle Phase")
	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ENTER_BATTLE_PHASE),
		"the Battle Phase is not even offered")


static func _test_the_skip_is_imposed_at_activation_not_at_resolution(
		t: TestCase) -> void:
	t.start("the obligation is taken on when the card is ACTIVATED, while the Chain is still "
		+ "building — not when it resolves")
	var d := _board(9611)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	# Something for the opponent to hold, so the window between activation and resolution
	# genuinely stays open instead of the engine auto-passing straight through it.
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Idle Responder"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID)
	t.not_null(offered, "bullet 1 is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"it becomes Chain Link 1")

	# The Chain has NOT resolved yet at this point.
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE,
		"the effect has not resolved — the target is still on the field")
	t.eq(engine.state.player(0).battle_phase_skips.size(), 1,
		"and the Battle Phase obligation is already owed")

	TestFixtures.pass_until_open(engine)
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the Chain then resolved normally")
	t.eq(engine.state.player(0).battle_phase_skips.size(), 1,
		"and resolving did not impose a second one")


static func _test_a_negated_ACTIVATION_still_costs_the_battle_phase(t: TestCase) -> void:
	t.start("R1: a negated ACTIVATION does nothing, but the Battle Phase is still skipped")
	var d := _board(9612)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Stop That"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID)
	t.not_null(offered, "bullet 1 is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.check(engine.submit_action(response), "the negator becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.check(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED) >= 1,
		"the activation really was negated — this is not a fallback path")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "nothing was destroyed")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and nothing was banished")
	t.check(not _can_battle(engine, 0),
		"but the Battle Phase is still gone — R1")


static func _test_a_negated_EFFECT_still_costs_the_battle_phase(t: TestCase) -> void:
	t.start("R1 again, for the case the ruling names explicitly: a negated EFFECT still "
		+ "costs the Battle Phase")
	var d := _board(9613)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Silence That"))
	var deck_before: int = engine.state.player(1).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, DESTROY_EFFECT_ID)
	t.not_null(offered, "bullet 1 is offered")
	if offered == null:
		return
	t.check(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	if response == null:
		return
	t.check(engine.submit_action(response), "the negator becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.check(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED) >= 1,
		"the effect really was negated")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "nothing was destroyed")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and nothing was banished")
	t.check(not _can_battle(engine, 0),
		"but the Battle Phase is still gone — this is exactly what R1 fixes")


static func _test_the_skip_is_turn_state_and_not_a_flag_on_the_card(t: TestCase) -> void:
	t.start("the restriction lives in the authoritative turn state and survives the card "
		+ "reaching the Graveyard — it is not a flag the card polls")
	var d := _board(9614)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var target := _their_special_summoned(engine)
	t.check(TestFixtures.activate_card(engine, 0, runick, [target.id]), "activated")

	t.eq(runick.zone, Enums.Zone.GRAVEYARD,
		"the Quick-Play Spell is already in the Graveyard")
	t.eq(engine.state.player(0).battle_phase_skips.size(), 1,
		"and the obligation is held on the PLAYER, not on the card")
	t.check(not _can_battle(engine, 0), "still barring the Battle Phase")

	# It is spent by the turn it costs, and the following one is free.
	TestFixtures.end_turn(engine)
	t.eq(engine.state.player(0).battle_phase_skips.size(), 0, "the turn spent it")
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "player 0's next turn")
	t.check(_can_battle(engine, 0), "whose Battle Phase is available again")


# ---------------------------------------------------------------------------
# Once per turn
# ---------------------------------------------------------------------------

static func _test_only_one_runick_flashing_fire_may_be_activated_per_turn(
		t: TestCase) -> void:
	t.start("'You can only activate 1 per turn' is on the NAME: a second copy cannot be "
		+ "activated the same turn, by either bullet")
	var d := _board(9615)
	var engine: DuelEngine = d["engine"]
	var first: CardInstance = d["runick"]
	var second := TestFixtures.give_set_spell_trap(engine, 0, _def())
	var target := _their_special_summoned(engine, "First Victim")
	_their_special_summoned(engine, "Second Victim")

	t.check(TestFixtures.activate_card(engine, 0, first, [target.id]),
		"the first copy was activated")

	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id, DESTROY_EFFECT_ID),
		"the second copy's bullet 1 is not offered this turn")
	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id, SUMMON_EFFECT_ID),
		"and neither is its bullet 2 — the limit is on activating the CARD")
	t.eq(second.zone, Enums.Zone.SPELL_TRAP_ZONE, "it is still Set")


# ---------------------------------------------------------------------------
# Bullet 2 — never live in the V1 pool (R1).
# ---------------------------------------------------------------------------

static func _test_bullet_two_is_not_offered_with_an_empty_extra_deck(t: TestCase) -> void:
	t.start("with an empty Extra Deck bullet 2 reports no legal choice — it is absent from "
		+ "the offered actions, not silently omitted from the card")
	var d := _board(9620)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	t.check(engine.state.player(0).extra_deck.is_empty(), "the Extra Deck really is empty")

	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, SUMMON_EFFECT_ID),
		"bullet 2 is not offered")
	# …but the clause exists on the card, which is the distinction R1 asks for.
	t.eq(_def().effects.size(), 2, "while the card still declares both bullets")


static func _test_bullet_two_is_not_offered_for_a_non_runick_extra_deck_monster(
		t: TestCase) -> void:
	t.start("the archetype is checked: a non-\"Runick\" Extra Deck monster does not enable it")
	var d := _board(9621)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	TestFixtures.give(engine, 0, TestFixtures.monster("Ordinary Fusion", 6, 2000, 1500),
		Enums.Zone.EXTRA_DECK)
	t.eq(engine.state.player(0).extra_deck.size(), 1, "there is a monster in the Extra Deck")

	t.check(not TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, runick.id, SUMMON_EFFECT_ID),
		"but it is not a \"Runick\" monster, so bullet 2 is still not offered")


static func _test_bullet_two_summons_to_the_extra_monster_zone(t: TestCase) -> void:
	t.start("given a synthetic \"Runick\" monster in the Extra Deck, bullet 2 Special Summons "
		+ "it to the EXTRA Monster Zone and it is a monster you control")
	var d := _board(9622)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	var fusion := TestFixtures.give(engine, 0,
		TestFixtures.monster("Runick Fountain Dragon", 6, 2200, 1800, "WATER"),
		Enums.Zone.EXTRA_DECK)

	t.check(TestFixtures.activate_card(engine, 0, runick),
		"bullet 2 was offered and activated")

	t.eq(fusion.zone, Enums.Zone.EXTRA_MONSTER_ZONE, "it is in the Extra Monster Zone")
	t.eq(engine.state.player(0).extra_monster_zone, fusion, "the zone really holds it")
	t.check(engine.state.player(0).monsters().has(fusion),
		"and it counts as a monster you control")
	t.eq(fusion.summoned_by, Enums.SummonKind.SPECIAL, "Special Summoned")
	t.check(fusion.is_face_up(), "face-up")
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, fusion.id), 1,
		"with exactly one successful Special Summon event")
	t.check(engine.state.player(0).extra_deck.is_empty(), "and it left the Extra Deck")


static func _test_bullet_two_also_costs_the_battle_phase(t: TestCase) -> void:
	t.start("the Battle Phase consequence belongs to the CARD, so bullet 2 costs it too")
	var d := _board(9623)
	var engine: DuelEngine = d["engine"]
	var runick: CardInstance = d["runick"]
	TestFixtures.give(engine, 0,
		TestFixtures.monster("Runick Fountain Dragon", 6, 2200, 1800, "WATER"),
		Enums.Zone.EXTRA_DECK)
	t.check(_can_battle(engine, 0), "player 0 could battle beforehand")

	t.check(TestFixtures.activate_card(engine, 0, runick), "bullet 2 was activated")

	t.eq(engine.state.player(0).battle_phase_skips.size(), 1, "one obligation is owed")
	t.check(not _can_battle(engine, 0), "and the Battle Phase is gone")


static func _test_bullet_two_is_never_live_in_the_real_pool(t: TestCase) -> void:
	t.start("R1: no \"Runick\" MONSTER exists in the pool and both Extra Decks are empty, so "
		+ "bullet 2 can never have a legal choice in a real duel")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")

	var runick_monsters: Array = []
	for card_name in cards.keys():
		if not str(card_name).contains("Runick"):
			continue
		var c: CardDef = cards[card_name]
		if c.is_monster():
			runick_monsters.append(str(card_name))
	t.eq(runick_monsters.size(), 0,
		"no \"Runick\" monster exists anywhere in the pool: %s" % str(runick_monsters))

	# And the decks themselves carry no Extra Deck at all.
	var d := TestFixtures.new_duel(9624, 0)
	var engine: DuelEngine = d["engine"]
	t.check(engine.state.player(0).extra_deck.is_empty(), "player 0's Extra Deck is empty")
	t.check(engine.state.player(1).extra_deck.is_empty(), "player 1's Extra Deck is empty")

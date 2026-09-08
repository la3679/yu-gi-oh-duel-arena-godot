class_name CostLegalityTests
extends RefCounted

## PAYING A COST IN A WAY THAT LEAVES THE EFFECT PERFORMABLE.
## Rules under test: `RULES_SPEC.md §10`, `§10.5`; `CARD_RULINGS.md` **R42 Part D**.
##
## This is the **cost-legality gate**, written the way `LifePointCostTests`, `EquipTests`,
## `ControlTests`, `MovementTests` and `BanishTests` were: a RULES suite built from
## SYNTHETIC cards, so what it proves is that the engine's rule is right rather than that
## one printed card happens to work. `One for One`'s correction is only trusted once this
## passes, and `OneForOneTests` is then the card-level evidence that the card consumes it.
##
## **The rule.** Official Konami supplemental information for `One for One`
## (cid 8197, 2020-03-20, `request_locale=ja`) states it as a general requirement of
## payment, not as a quirk of that card:
##
##   ■処理を行えるようにコストのモンスターを墓地へ送る必要があります。レベル１のモンスターが
##   自分のデッキに存在せず、自分の手札に１体のみ存在する状況では、そのモンスターを
##   コストにできません。
##
##   *You must send the cost monster to the Graveyard in such a way that the effect can be
##   carried out. Where no Level 1 monster is in your Deck and only one is in your hand,
##   that monster cannot be used as the cost.*
##
## **What it is NOT.** It is not the activation condition. The condition is evaluated over
## the pool as it stands BEFORE any payment, and this rule never widens or narrows it: an
## activation that is legal stays legal. What shrinks is the set of materials that may be
## SPENT. Only when that set shrinks to empty does the card stop being offered — and then it
## is `can_pay_cost` refusing, not the condition. Both halves are asserted separately, and
## the suite is deliberately built so that confusing the two fails a test.
##
## **Where it bites, and where it must not.** It bites only where the cost's material pool
## and the effect's candidate pool overlap in the DISABLING direction: the cost takes a card
## out of a zone the effect draws from and puts it somewhere the effect does not draw from.
## `overlap_spell()` below is that shape. `harmless_overlap_spell()` is the OTHER shape — the
## cost's destination is INSIDE the effect's pool, which is `Fairy Tail - Rella` (discard a
## Spell; equip an Equip Spell from your hand, Deck, **or GY**) — and it proves the rule does
## not over-apply. Getting that second case wrong would silently forbid legal plays, which
## is why it is a test and not a comment.

const COST_KIND := Enums.DecisionKind.CHOOSE_COST


static func run() -> TestCase:
	var t := TestCase.new("CostLegalityTests")
	_test_the_last_enabler_is_not_offered_as_cost(t)
	_test_a_second_enabler_makes_both_payable(t)
	_test_an_enabler_in_another_zone_keeps_the_hand_copy_payable(t)
	_test_no_payable_material_blocks_the_activation(t)
	_test_the_activation_condition_is_not_narrowed(t)
	_test_the_primitive_filters_exactly_and_nothing_more(t)
	_test_a_cost_whose_destination_is_in_the_pool_is_unrestricted(t)
	_test_a_multi_card_payment_is_refused_rather_than_approximated(t)
	return t


# ---------------------------------------------------------------------------
# The synthetic cards
# ---------------------------------------------------------------------------

## The Level the synthetic effect looks for. Deliberately NOT 1: nothing here may work
## because it accidentally matches `One for One`'s printed text.
const WANTED_LEVEL := 3


static func _wanted() -> Callable:
	return EffectPrimitives.monster_of_level(WANTED_LEVEL)


## "Send 1 monster from your hand to the GY; Special Summon 1 Level 3 monster from your
## hand or Deck." The DISABLING shape: the cost leaves the hand for the Graveyard, and the
## Graveyard is not one of the zones the effect draws from.
static func overlap_spell(card_name: String = "Overlap Spell") -> CardDef:
	var d := TestFixtures.spell(card_name)
	var e := EffectDef.new("send_monster_summon_wanted",
		"Test: send 1 monster from your hand to the GY; Special Summon 1 Level %d monster "
		% WANTED_LEVEL + "from your hand or Deck.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var any_monster := EffectPrimitives.monster_filter()
	var wanted := _wanted()

	var still_performable := func(ctx: EffectContext, spent: Array) -> bool:
		for entry in EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, wanted):
			if not spent.has(entry):
				return true
		return not EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, wanted).is_empty()

	var payable := func(ctx: EffectContext) -> Array:
		return EffectPrimitives.cost_candidates_keeping_effect_performable(ctx,
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, any_monster), 1,
			still_performable)

	e.condition = func(ctx: EffectContext) -> bool:
		return ctx.me().has_free_monster_zone() \
			and bool(still_performable.call(ctx, []))

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not (payable.call(ctx) as Array).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_send_to_gy_cost(ctx, payable.call(ctx), 1,
			"Send 1 monster from your hand to the GY")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, "sent", paid)
		return true

	e.resolve = func(ctx: EffectContext) -> void:
		var candidates := EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, wanted)
		candidates.append_array(
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.DECK, wanted))
		EffectPrimitives.special_summon_one_any_position(ctx, candidates,
			"Special Summon 1 Level %d monster" % WANTED_LEVEL)

	return TestFixtures.with_effect(d, e)


## The NON-disabling shape, and the control case. "Send 1 monster from your hand to the GY;
## Special Summon 1 Level 3 monster from your hand, Deck, **or GY**." The cost's destination
## is one of the effect's own source zones, so nothing may ever be filtered out — sending
## the last Level 3 monster puts it exactly where the effect can still reach it.
## `Fairy Tail - Rella` is the printed card of this shape.
static func harmless_overlap_spell(card_name: String = "Harmless Overlap") -> CardDef:
	var d := TestFixtures.spell(card_name)
	var e := EffectDef.new("send_monster_summon_wanted_from_three_zones",
		"Test: send 1 monster from your hand to the GY; Special Summon 1 Level %d monster "
		% WANTED_LEVEL + "from your hand, Deck, or GY.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]

	var any_monster := EffectPrimitives.monster_filter()
	var wanted := _wanted()
	var zones: Array = [Enums.Zone.HAND, Enums.Zone.DECK, Enums.Zone.GRAVEYARD]

	var pool := func(ctx: EffectContext, spent: Array) -> Array:
		var out: Array = []
		for zone in zones:
			for entry in EffectPrimitives.own_cards_in(ctx, zone, wanted):
				# A card spent as the cost is in the GY by resolution, so it is still a
				# candidate — which is the whole point of this control case.
				if zone == Enums.Zone.HAND and spent.has(entry):
					continue
				out.append(entry)
		return out

	var still_performable := func(ctx: EffectContext, spent: Array) -> bool:
		# Hypothetically spending from the hand does not remove the card from the pool:
		# it moves it to the GY, which this clause also reads.
		return not (pool.call(ctx, []) as Array).is_empty() or spent.size() > 0

	var payable := func(ctx: EffectContext) -> Array:
		return EffectPrimitives.cost_candidates_keeping_effect_performable(ctx,
			EffectPrimitives.own_cards_in(ctx, Enums.Zone.HAND, any_monster), 1,
			still_performable)

	e.condition = func(ctx: EffectContext) -> bool:
		return ctx.me().has_free_monster_zone() \
			and not (pool.call(ctx, []) as Array).is_empty()

	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not (payable.call(ctx) as Array).is_empty()

	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_send_to_gy_cost(ctx, payable.call(ctx), 1,
			"Send 1 monster from your hand to the GY")
		return not paid.is_empty()

	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.special_summon_one_any_position(ctx, pool.call(ctx, []),
			"Special Summon 1 Level %d monster" % WANTED_LEVEL)

	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A Main Phase 1 duel with player 0's hand EMPTIED, so every card in it is one a test put
## there and no opening-hand draw can make a negative pass for the wrong reason.
static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	for entry in engine.state.player(0).hand.duplicate():
		engine.state.move_card(entry, Enums.Zone.DECK, Enums.MoveReason.RULE)
	# The filler deck is 40 Level 4 vanillas, so it contains no Level 3 monster and the
	# cards just returned to it cannot become candidates either. Asserted by the tests
	# that need it rather than trusted here.
	return d


static func _wanted_monster(name: String) -> CardDef:
	return TestFixtures.monster(name, WANTED_LEVEL, 900, 900)


static func _other_monster(name: String) -> CardDef:
	return TestFixtures.monster(name, WANTED_LEVEL + 1, 1200, 1200)


## The option list the controller was actually offered for the cost decision, or [] if it
## was never asked. Reading the REQUEST rather than the outcome is what makes these tests
## about the candidate list instead of about which card happened to be picked.
static func _cost_options(controller: ScriptedController) -> Array:
	for entry in controller.seen_requests:
		var request: DecisionRequest = entry
		if request.kind == COST_KIND:
			return request.options
	return []


static func _activation(engine: DuelEngine, card: CardInstance):
	return TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, card.id)


# ---------------------------------------------------------------------------
# The rule
# ---------------------------------------------------------------------------

static func _test_the_last_enabler_is_not_offered_as_cost(t: TestCase) -> void:
	t.start("the only monster that can carry out the effect is not a legal cost")
	var d := _duel(42101)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var only_enabler := TestFixtures.give_to_hand(engine, 0, _wanted_monster("Sole Enabler"))
	# TWO spendable monsters, not one: with a single legal candidate `choose_n` asks no
	# question at all, and this test's evidence is the OPTION LIST it was offered.
	var fodder := TestFixtures.give_to_hand(engine, 0, _other_monster("Fodder A"))
	var spare := TestFixtures.give_to_hand(engine, 0, _other_monster("Fodder B"))
	t.is_true(EffectPrimitives.own_cards_in(
		ActivationRules.make_context(engine.state, spell, spell.definition.effects[0], 0),
		Enums.Zone.DECK, _wanted()).is_empty(),
		"precondition: the Deck holds no Level %d monster" % WANTED_LEVEL)
	controller.queue_for(COST_KIND, [fodder.id])

	var action = _activation(engine, spell)
	t.not_null(action, "the activation is STILL legal — the rule restricts the cost, "
		+ "not the condition")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	var options := _cost_options(controller)
	t.ne(options, [], "a cost decision really was asked (the branch is not vacuous)")
	t.is_false(options.has(only_enabler.id),
		"the last enabler was NOT offered as a cost")
	t.is_true(options.has(fodder.id) and options.has(spare.id),
		"and both spendable monsters were")
	t.eq(options.size(), 2, "exactly those two — nothing else was offered")

	t.eq(controller.errors, [], "no scripted answer mismatched its prompt")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the payable monster was the one sent")
	t.eq(spare.zone, Enums.Zone.HAND, "the unspent one stayed in the hand")
	t.eq(only_enabler.zone, Enums.Zone.MONSTER_ZONE,
		"and the enabler was Special Summoned instead of being spent")


static func _test_a_second_enabler_makes_both_payable(t: TestCase) -> void:
	t.start("with two enablers in hand, either may be spent — the other carries the effect")
	var d := _duel(42102)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var first := TestFixtures.give_to_hand(engine, 0, _wanted_monster("Enabler A"))
	var second := TestFixtures.give_to_hand(engine, 0, _wanted_monster("Enabler B"))
	controller.queue_for(COST_KIND, [first.id])

	var action = _activation(engine, spell)
	t.not_null(action, "the activation is offered")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	var options := _cost_options(controller)
	t.is_true(options.has(first.id) and options.has(second.id),
		"BOTH enablers were offered: spending one leaves the other")
	t.eq(controller.errors, [], "the scripted cost choice matched the prompt")
	t.eq(first.zone, Enums.Zone.GRAVEYARD, "the chosen enabler was spent")
	t.eq(second.zone, Enums.Zone.MONSTER_ZONE, "and the other one was Summoned")


static func _test_an_enabler_in_another_zone_keeps_the_hand_copy_payable(t: TestCase) -> void:
	t.start("a copy in the DECK makes the hand copy spendable again")
	var d := _duel(42103)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var in_hand := TestFixtures.give_to_hand(engine, 0, _wanted_monster("Hand Enabler"))
	# A spare monster so the cost is a real CHOICE and the option list can be read; the
	# claim under test is that `in_hand` is IN that list, which a forced single-candidate
	# payment could not show.
	TestFixtures.give_to_hand(engine, 0, _other_monster("Spare"))
	var in_deck := TestFixtures.give_to_deck(engine, 0, _wanted_monster("Deck Enabler"))
	controller.queue_for(COST_KIND, [in_hand.id])

	var action = _activation(engine, spell)
	t.not_null(action, "the activation is offered")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	t.is_true(_cost_options(controller).has(in_hand.id),
		"the hand copy IS a legal cost: the Deck copy can still carry out the effect")
	t.eq(controller.errors, [], "the scripted cost choice matched the prompt")
	t.eq(in_hand.zone, Enums.Zone.GRAVEYARD, "it was spent")
	t.eq(in_deck.zone, Enums.Zone.MONSTER_ZONE, "and the Deck copy was Summoned")


static func _test_no_payable_material_blocks_the_activation(t: TestCase) -> void:
	t.start("when the filter empties the candidate list the card is not offered at all")
	var d := _duel(42104)
	var engine: DuelEngine = d["engine"]

	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var only_enabler := TestFixtures.give_to_hand(engine, 0, _wanted_monster("Sole Enabler"))

	t.eq(engine.state.player(0).hand.size(), 2,
		"the hand is exactly the Spell and the one monster")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"not offered: the only monster in hand is the only enabler, so no cost is payable")

	# Mutation guard #1: a SECOND monster restores a payable cost, and nothing else changed.
	var fodder := TestFixtures.give_to_hand(engine, 0, _other_monster("Fodder"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"adding a spendable monster makes it activatable")
	t.eq(only_enabler.zone, Enums.Zone.HAND, "and the enabler never moved")

	# Mutation guard #2: removing the fodder again puts it back exactly as it was, so the
	# first assertion cannot have passed for some unrelated reason.
	engine.state.move_card(fodder, Enums.Zone.DECK, Enums.MoveReason.RULE)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"taking it away again blocks it again")

	# Mutation guard #3: an enabler in the DECK reaches the same result down the OTHER
	# path — the cost becomes payable because the effect no longer depends on the hand copy.
	TestFixtures.give_to_deck(engine, 0, _wanted_monster("Deck Enabler"))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"a Deck enabler makes the hand copy spendable, so the card is offered again")


static func _test_the_activation_condition_is_not_narrowed(t: TestCase) -> void:
	t.start("the rule restricts the COST only — the condition is unchanged")
	var d := _duel(42105)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var effect: EffectDef = spell.definition.effects[0]

	# Case 1 — no enabler anywhere. The CONDITION is what refuses.
	TestFixtures.give_to_hand(engine, 0, _other_monster("Fodder A"))
	TestFixtures.give_to_hand(engine, 0, _other_monster("Fodder B"))
	var ctx := ActivationRules.make_context(engine.state, spell, effect, 0)
	t.is_false(ActivationRules.condition_ok(ctx),
		"with no enabler at all the condition is false")

	# Case 2 — the two checks now disagree, which is the whole point of keeping them
	# separate. A hand of nothing but the Spell and its one enabler SATISFIES the
	# condition (there is a monster to Summon) and yet has NO payable cost (the only
	# monster in hand is that enabler). Anything that folded the rule into the condition
	# would report this the other way round.
	var d2 := _duel(42115)
	var engine2: DuelEngine = d2["engine"]
	var spell2 := TestFixtures.give_to_hand(engine2, 0, overlap_spell())
	var sole := TestFixtures.give_to_hand(engine2, 0, _wanted_monster("Sole Enabler"))
	var ctx2 := ActivationRules.make_context(engine2.state, spell2,
		spell2.definition.effects[0], 0)
	t.is_true(ActivationRules.condition_ok(ctx2),
		"the condition IS satisfied — there is a monster the effect could Summon")
	t.is_false(ActivationRules.cost_ok(ctx2),
		"but no cost is payable, so it is the COST check that refuses")
	t.eq(sole.zone, Enums.Zone.HAND, "and asking the question moved nothing")

	# Case 3 — one spare monster and both checks pass.
	TestFixtures.give_to_hand(engine2, 0, _other_monster("Spare"))
	var ctx3 := ActivationRules.make_context(engine2.state, spell2,
		spell2.definition.effects[0], 0)
	t.is_true(ActivationRules.condition_ok(ctx3), "the condition still holds")
	t.is_true(ActivationRules.cost_ok(ctx3), "and now a cost is payable too")


static func _test_the_primitive_filters_exactly_and_nothing_more(t: TestCase) -> void:
	t.start("the primitive itself keeps every candidate the predicate accepts")
	var d := _duel(42106)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var a := TestFixtures.give_to_hand(engine, 0, _other_monster("A"))
	var b := TestFixtures.give_to_hand(engine, 0, _other_monster("B"))
	var c := TestFixtures.give_to_hand(engine, 0, _other_monster("C"))
	var ctx := ActivationRules.make_context(engine.state, spell,
		spell.definition.effects[0], 0)

	var all_ok := func(_ctx: EffectContext, _spent: Array) -> bool: return true
	t.eq(EffectPrimitives.cost_candidates_keeping_effect_performable(
			ctx, [a, b, c], 1, all_ok).size(), 3,
		"a predicate that accepts everything removes nothing")

	var none_ok := func(_ctx: EffectContext, _spent: Array) -> bool: return false
	t.eq(EffectPrimitives.cost_candidates_keeping_effect_performable(
			ctx, [a, b, c], 1, none_ok), [],
		"a predicate that accepts nothing removes everything")

	# The predicate is handed the PROPOSED payment, not the whole candidate list — a filter
	# that passed all three at once would silently answer a different question.
	var seen: Array = []
	var record := func(_ctx: EffectContext, spent: Array) -> bool:
		seen.append(spent.duplicate())
		return spent[0] != b
	var kept := EffectPrimitives.cost_candidates_keeping_effect_performable(
		ctx, [a, b, c], 1, record)
	t.eq(kept, [a, c], "exactly the rejected candidate was dropped, order preserved")
	t.eq(seen.size(), 3, "the predicate was asked once per candidate")
	for entry in seen:
		t.eq((entry as Array).size(), 1, "and always about a payment of exactly one card")


static func _test_a_cost_whose_destination_is_in_the_pool_is_unrestricted(t: TestCase) -> void:
	t.start("no filtering when the cost lands INSIDE the effect's own pool (the Rella shape)")
	var d := _duel(42107)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]

	var spell := TestFixtures.give_to_hand(engine, 0, harmless_overlap_spell())
	var only_enabler := TestFixtures.give_to_hand(engine, 0, _wanted_monster("Sole Enabler"))

	t.eq(engine.state.player(0).hand.size(), 2,
		"the hand is exactly the Spell and the one monster")
	var action = _activation(engine, spell)
	t.not_null(action,
		"offered: spending the only enabler puts it in the GY, which this clause reads")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(controller.errors, [], "no scripted answer mismatched its prompt")
	t.eq(only_enabler.zone, Enums.Zone.MONSTER_ZONE,
		"the card paid as the cost was then Summoned back out of the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon happened — the branch is not vacuous")


static func _test_a_multi_card_payment_is_refused_rather_than_approximated(t: TestCase) -> void:
	t.start("a payment of more than one card is refused loudly, not answered per-card")
	var d := _duel(42108)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0, overlap_spell())
	var a := TestFixtures.give_to_hand(engine, 0, _other_monster("A"))
	var b := TestFixtures.give_to_hand(engine, 0, _other_monster("B"))
	var ctx := ActivationRules.make_context(engine.state, spell,
		spell.definition.effects[0], 0)
	var all_ok := func(_ctx: EffectContext, _spent: Array) -> bool: return true

	# A pair may be an illegal payment though neither card is illegal alone, so a per-card
	# filter would be WRONG here rather than merely incomplete. It fails loudly — this is
	# one of the run's deliberate `push_error` lines, and it is asserted so that a future
	# change which silently starts approximating the answer fails this test.
	# The predicate must not even be CONSULTED for a payment size the per-card filter
	# cannot answer, so a refusal can never be mistaken for a predicate that happened to
	# reject everything. One counting predicate serves both claims and costs no extra
	# `push_error` line beyond the refusals themselves.
	var asked: Array = []
	var counting := func(_ctx: EffectContext, spent: Array) -> bool:
		asked.append(spent.size())
		return true
	for bad_count in [0, 2, 3]:
		t.eq(EffectPrimitives.cost_candidates_keeping_effect_performable(
				ctx, [a, b], bad_count, counting), [],
			"count %d returns NO candidates rather than an approximate list" % bad_count)
	t.eq(asked, [], "and the predicate was never consulted for any of them")
	t.eq(a.zone, Enums.Zone.HAND, "a refused query moves nothing")
	t.eq(b.zone, Enums.Zone.HAND, "for either candidate")

	t.eq(EffectPrimitives.cost_candidates_keeping_effect_performable(
			ctx, [a, b], 1, all_ok).size(), 2,
		"and the same call at count 1 still answers normally")
	t.eq(asked.size(), 0, "the counting predicate was only ever offered illegal counts")

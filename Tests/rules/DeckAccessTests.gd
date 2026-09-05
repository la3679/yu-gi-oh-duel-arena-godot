class_name DeckAccessTests
extends RefCounted

## Generic gate for the DECK-ACCESS subsystem, written and green BEFORE any batch-10 card.
## RULES_SPEC.md 8.4, CARD_RULINGS.md R40.
##
## What is genuinely new is the DECK as a zone an effect may look THROUGH. §8.2 already
## separated DRAW / REVEAL / EXCAVATE and recorded that nothing implemented the fourth. This
## suite pins the fourth down and — just as importantly — pins down that it did not quietly
## become one of the other three.
##
## Every card here is synthetic. Nothing in this file knows a batch-10 card's name.
##
## Event counts are always read as a DELTA around the action under test: a duel has already
## drawn two opening hands before any of these tests start, so an absolute `count_events`
## on `CARD_DRAWN` would be measuring the setup rather than the primitive.

const SEED := 41000


# ---------------------------------------------------------------------------
# Synthetic cards, one per primitive under test
# ---------------------------------------------------------------------------

## "Draw N cards." `gated` adds the `can_draw` activation condition — R40 part D, from the
## official supplements for cid 7248 and cid 8656. Ungated is kept so the deck-out path
## stays reachable and can be asserted.
static func draw_spell(count: int = 2, gated: bool = true) -> CardDef:
	var e := EffectDef.new("draw_n", "Draw %d cards." % count)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	if gated:
		e.condition = func(ctx: EffectContext) -> bool:
			return EffectPrimitives.can_draw(ctx, ctx.controller_id, count)
	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.draw_cards(ctx, ctx.controller_id, count)
	return TestFixtures.with_effect(
		TestFixtures.spell("Draw %d%s" % [count, "" if gated else " ungated"]), e)


## "Add 1 monster of `race` from your Deck to your hand", gated on `can_search_deck` —
## the general [S1 p.53] activation restriction.
static func search_spell(race: String = "Dragon") -> CardDef:
	var pred := EffectPrimitives.monster_filter("", -1, -1, race)
	var e := EffectDef.new("search_to_hand",
		"Add 1 %s monster from your Deck to your hand." % race)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_search_deck(ctx, ctx.controller_id, pred)
	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.search_deck_to_hand(ctx, ctx.controller_id, pred, "Add 1 card")
	return TestFixtures.with_effect(TestFixtures.spell("Search %s" % race), e)


## "Send 1 monster of `race` from your Deck to the GY." A MILL, never a draw.
static func mill_spell(race: String = "Dragon") -> CardDef:
	var pred := EffectPrimitives.monster_filter("", -1, -1, race)
	var e := EffectDef.new("mill_to_gy",
		"Send 1 %s monster from your Deck to the GY." % race)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.send_from_deck_to_gy(ctx, ctx.controller_id, pred, "Send 1 card")
	return TestFixtures.with_effect(TestFixtures.spell("Mill %s" % race), e)


## "Discard 1 card; (nothing)." Exists so a hand card can reach the Graveyard through a real
## engine activation — the route `Cards of Consonance` will use on `The White Stone of
## Legend`. Firing a GY trigger off a hand-written `move_card` would not prove the engine
## opens the timing point.
static func discard_cost_spell() -> CardDef:
	var e := EffectDef.new("discard_one", "Discard 1 card.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.qualified_hand_cards(ctx,
			func(c: CardInstance) -> bool: return c.id != ctx.source.id).is_empty()
	e.pay_cost = func(ctx: EffectContext) -> bool:
		var candidates := EffectPrimitives.qualified_hand_cards(ctx,
			func(c: CardInstance) -> bool: return c.id != ctx.source.id)
		return EffectPrimitives.pay_discard_cost(ctx, candidates, 1, "Discard 1 card").size() == 1
	e.resolve = func(_ctx: EffectContext) -> void:
		pass
	return TestFixtures.with_effect(TestFixtures.spell("Discard engine"), e)


## A MANDATORY Graveyard trigger that searches, whose activation condition is NOT "I want to
## search". R40 part C: this shape activates even when the search can find nothing.
static func gy_trigger_searcher(wanted: String) -> CardDef:
	var pred := EffectPrimitives.monster_named(wanted)
	var e := EffectDef.new("gy_sent_search",
		"If this card is sent to the GY: Add 1 '%s' from your Deck to your hand." % wanted)
	e.of_type(Enums.EffectType.TRIGGER)
	e.mandatory()
	e.trigger_events = [GameEvent.Kind.CARD_SENT_TO_GY]
	e.activation_locations = [Enums.ActivationLocation.GRAVEYARD]
	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		return ev != null and int(ev.data.get("card_id", -1)) == ctx.source.id
	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.search_deck_to_hand(ctx, ctx.controller_id, pred,
			"Add the named card")
	return TestFixtures.with_effect(TestFixtures.monster("GY searcher", 1, 300, 250), e)


## A monster that really is an Effect Monster, for the non-Effect-Monster predicate.
static func effect_monster(name: String, level: int = 4, atk: int = 1000) -> CardDef:
	var e := EffectDef.new("inert", "Does nothing.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(_ctx: EffectContext) -> void:
		pass
	var d := TestFixtures.with_effect(TestFixtures.monster(name, level, atk), e)
	d.is_effect_monster = true
	return d


static func dragon(name: String, level: int = 4, atk: int = 1000,
		tuner: bool = false, normal: bool = true) -> CardDef:
	var d := TestFixtures.monster(name, level, atk)
	d.race = "Dragon"
	d.is_tuner = tuner
	d.is_normal_monster = normal
	d.is_effect_monster = not normal
	return d


# ---------------------------------------------------------------------------
# Board
# ---------------------------------------------------------------------------

## A duel whose Deck for `pid` is EXACTLY the definitions given, top first.
static func board(pid: int, deck_defs: Array, seed_value: int = SEED) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, pid)
	var e: DuelEngine = d.engine
	TestFixtures.advance_to_phase(e, Enums.Phase.MAIN_1)
	d.pid = pid
	TestFixtures.clear_deck(e, pid)
	var made: Array = []
	for entry in deck_defs:
		made.append(TestFixtures.give_to_deck(e, pid, entry))
	d.deck = made
	return d


static func run() -> TestCase:
	var t := TestCase.new("DeckAccessTests")

	# =======================================================================
	# 1. The four ways to reach a Deck stay four
	# =======================================================================
	for pid in [0, 1]:
		t.start("a DRAW is private, takes the TOP cards in order, and shuffles nothing (seat %d)"
			% pid)
		var d := board(pid, [dragon("Top"), dragon("Second"), dragon("Third")])
		var e: DuelEngine = d.engine
		var before_draws := TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN)
		var before_reveals := TestFixtures.count_events(e, GameEvent.Kind.CARD_REVEALED)
		var before_exc := TestFixtures.count_events(e, GameEvent.Kind.CARD_EXCAVATED)
		var spell := TestFixtures.give_to_hand(e, pid, draw_spell(2))
		t.is_true(TestFixtures.activate_card(e, pid, spell),
			"draw spell really activated and resolved")
		t.eq(d.deck[0].zone, Enums.Zone.HAND, "the TOP card was drawn first")
		t.eq(d.deck[1].zone, Enums.Zone.HAND, "the second card followed")
		t.eq(d.deck[2].zone, Enums.Zone.DECK, "the third stayed in the Deck")
		t.eq(e.state.player(pid).deck_count(), 1, "exactly two cards left the Deck")
		t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_DRAWN) - before_draws, 2,
			"two real draw events")
		t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_EXCAVATED) - before_exc, 0,
			"a draw is not an excavate")
		t.eq(TestFixtures.count_events(e, GameEvent.Kind.CARD_REVEALED) - before_reveals, 0,
			"a draw reveals nothing")
		t.eq(d.deck[0].revealed_to, [], "a drawn card is not public")
		t.eq(d.deck[2].revealed_to, [], "the rest of the Deck is untouched")
		var drawn_events := TestFixtures.events_of(e, GameEvent.Kind.CARD_DRAWN)
		var last_draw: GameEvent = drawn_events[drawn_events.size() - 1]
		t.eq(last_draw.data.get("private_to"), [pid], "the draw is private to the drawer")
		t.eq(last_draw.data.get("card_id"), d.deck[1].id, "and it named the second card")

	t.start("a SEARCH reveals the taken card, shuffles, and ends knowledge of the rest")
	var d0 := board(0, [dragon("Wanted"), TestFixtures.monster("Other A"),
		TestFixtures.monster("Other B"), TestFixtures.monster("Other C")])
	var e0: DuelEngine = d0.engine
	# Give a card still in the Deck a prior reveal, so the shuffle's effect on it is visible.
	e0.state.reveal(d0.deck[1], [0, 1], -1)
	t.eq(d0.deck[1].revealed_to, [0, 1], "a Deck card really was revealed beforehand")
	var b0_draw := TestFixtures.count_events(e0, GameEvent.Kind.CARD_DRAWN)
	var b0_rev := TestFixtures.count_events(e0, GameEvent.Kind.CARD_REVEALED)
	var b0_exc := TestFixtures.count_events(e0, GameEvent.Kind.CARD_EXCAVATED)
	var s0 := TestFixtures.give_to_hand(e0, 0, search_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(e0, 0, s0), "search spell activated and resolved")
	t.eq(d0.deck[0].zone, Enums.Zone.HAND, "the qualifying card was added to the hand")
	t.eq(d0.deck[0].last_move_reason, Enums.MoveReason.ADDED_TO_HAND,
		"ADDED_TO_HAND, never RETURNED_TO_HAND")
	t.eq(d0.deck[0].revealed_to, [0, 1],
		"the added card stays public: both players watched it leave the Deck")
	t.eq(d0.deck[1].revealed_to, [],
		"the tail shuffle ended knowledge of what is still in the Deck")
	t.eq(TestFixtures.count_events(e0, GameEvent.Kind.CARD_DRAWN) - b0_draw, 0,
		"a search is not a draw")
	t.eq(TestFixtures.count_events(e0, GameEvent.Kind.CARD_EXCAVATED) - b0_exc, 0,
		"a search is not an excavate")
	var rev_all := TestFixtures.events_of(e0, GameEvent.Kind.CARD_REVEALED)
	t.eq(rev_all.size() - b0_rev, 1, "exactly one reveal, and it was the search's")
	var search_reveal: GameEvent = rev_all[rev_all.size() - 1]
	t.eq(search_reveal.data.get("card_id"), d0.deck[0].id,
		"the reveal named the card that was added")
	t.is_false(search_reveal.data.has("private_to"), "a reveal to BOTH players is public")
	t.eq(e0.state.player(0).deck_count(), 3, "only the one card left the Deck")

	t.start("[S1 p.53] a Deck with nothing qualifying makes a search ILLEGAL, not a no-op")
	var d1 := board(0, [TestFixtures.monster("Warrior A"), TestFixtures.monster("Warrior B")])
	var e1: DuelEngine = d1.engine
	var s1 := TestFixtures.give_to_hand(e1, 0, search_spell("Dragon"))
	t.is_false(TestFixtures.has_action(e1.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, s1.id),
		"the activation is not offered at all")
	var probe1 := EffectContext.new(e1.state, s1, s1.definition.effects[0])
	t.is_false(EffectPrimitives.can_search_deck(probe1, 0,
		EffectPrimitives.monster_filter("", -1, -1, "Dragon")),
		"can_search_deck agrees with the engine")
	t.eq(EffectPrimitives.deck_search_candidates(probe1, 0,
		EffectPrimitives.monster_filter("", -1, -1, "Dragon")), [],
		"and the candidate list really is empty")
	# The SAME card becomes activatable the moment one qualifying card exists.
	var late := TestFixtures.give_to_deck(e1, 0, dragon("Now qualifying"))
	t.is_true(TestFixtures.has_action(e1.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, s1.id),
		"activation becomes legal once the Deck qualifies")
	t.is_true(TestFixtures.activate_card(e1, 0, s1), "and it resolves")
	t.eq(late.zone, Enums.Zone.HAND, "taking the one card that qualified")

	t.start("a MILL sends to the GY, is public on arrival, shuffles, and is not a draw")
	var d2 := board(0, [dragon("Milled"), TestFixtures.monster("Other A"),
		TestFixtures.monster("Other B")])
	var e2: DuelEngine = d2.engine
	e2.state.reveal(d2.deck[1], [0, 1], -1)
	var b2_draw := TestFixtures.count_events(e2, GameEvent.Kind.CARD_DRAWN)
	var b2_gy := TestFixtures.count_events(e2, GameEvent.Kind.CARD_SENT_TO_GY)
	var b2_destroy := TestFixtures.count_events(e2, GameEvent.Kind.CARD_DESTROYED)
	var m2 := TestFixtures.give_to_hand(e2, 0, mill_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(e2, 0, m2), "mill spell activated and resolved")
	t.eq(d2.deck[0].zone, Enums.Zone.GRAVEYARD, "the qualifying card reached the GY")
	t.eq(d2.deck[0].last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"sent by an effect: not discarded, not destroyed, not tributed")
	# TWO sends: the milled card, and the Normal Spell's own trip to the GY once it has
	# resolved [S1 p.28]. The one that matters is asserted by card id, not by count.
	t.eq(TestFixtures.count_events(e2, GameEvent.Kind.CARD_SENT_TO_GY) - b2_gy, 2,
		"the milled card AND the spent Normal Spell both reached the GY")
	t.eq(TestFixtures.count_events_for(e2, GameEvent.Kind.CARD_SENT_TO_GY, d2.deck[0].id), 1,
		"a real CARD_SENT_TO_GY for the MILLED card, so 'if this card is sent to the GY' sees it")
	t.eq(TestFixtures.count_events_for(e2, GameEvent.Kind.CARD_SENT_TO_GY, m2.id), 1,
		"and one for the spell itself, which is a different card")
	t.eq(TestFixtures.count_events(e2, GameEvent.Kind.CARD_DESTROYED) - b2_destroy, 0,
		"a mill is not a destruction")
	t.eq(TestFixtures.count_events(e2, GameEvent.Kind.CARD_DRAWN) - b2_draw, 0,
		"a mill is not a draw")
	t.eq(d2.deck[1].revealed_to, [],
		"a mill looks through the Deck too, so it shuffles too")
	t.eq(e2.state.player(0).deck_count(), 2, "one card left the Deck")
	t.is_true(e2.state.player(0).graveyard.has(d2.deck[0]), "it is in its OWNER's Graveyard")

	# =======================================================================
	# 2. Decking out: a DRAW can lose the Duel; a MILL and a SEARCH never can
	# =======================================================================
	t.start("an UNGATED draw 2 on a 1-card Deck draws 1 and LOSES the Duel [S1 p.35]")
	var d3 := board(0, [dragon("Only card")])
	var e3: DuelEngine = d3.engine
	var s3 := TestFixtures.give_to_hand(e3, 0, draw_spell(2, false))
	t.eq(e3.state.player(0).deck_count(), 1, "the Deck really holds exactly one card")
	t.is_true(TestFixtures.activate_card(e3, 0, s3), "the ungated spell was activatable")
	t.eq(d3.deck[0].zone, Enums.Zone.HAND, "the one available card WAS drawn")
	t.is_true(e3.state.is_duel_over(), "the failed second draw ended the Duel")
	t.eq(e3.state.end_reason, Enums.EndReason.DECK_OUT, "and ended it by DECK OUT")
	t.eq(e3.state.result, Enums.DuelResult.PLAYER_1_WINS, "the OTHER player won")

	t.start("R40 part D — the gated draw refuses to be activated on a short Deck")
	for n in [0, 1]:
		var d4 := board(0, [])
		var e4: DuelEngine = d4.engine
		for i in range(n):
			TestFixtures.give_to_deck(e4, 0, dragon("Card %d" % i))
		var s4 := TestFixtures.give_to_hand(e4, 0, draw_spell(2))
		t.eq(e4.state.player(0).deck_count(), n, "Deck holds exactly %d" % n)
		t.is_false(TestFixtures.has_action(e4.get_legal_actions(0),
			Enums.ActionKind.ACTIVATE_CARD, s4.id),
			"draw 2 is NOT activatable on a Deck of %d" % n)
		t.is_false(e4.state.is_duel_over(), "and refusing to activate is not a loss")
	var d5 := board(0, [dragon("A"), dragon("B")])
	var e5: DuelEngine = d5.engine
	var s5 := TestFixtures.give_to_hand(e5, 0, draw_spell(2))
	t.is_true(TestFixtures.has_action(e5.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, s5.id),
		"draw 2 IS activatable on a Deck of exactly 2")
	t.is_true(TestFixtures.activate_card(e5, 0, s5), "and it resolves")
	t.eq(e5.state.player(0).deck_count(), 0, "the Deck is now empty")
	t.is_false(e5.state.is_duel_over(),
		"emptying the Deck is not a loss: you lose when you MUST draw and CANNOT")

	t.start("a MILL and a SEARCH can empty a Deck without ending the Duel")
	var d6 := board(0, [dragon("Last dragon")])
	var e6: DuelEngine = d6.engine
	var m6 := TestFixtures.give_to_hand(e6, 0, mill_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(e6, 0, m6), "mill activated on a 1-card Deck")
	t.eq(e6.state.player(0).deck_count(), 0, "the Deck is now empty")
	t.is_false(e6.state.is_duel_over(), "a mill is not a draw, so it is not a loss")
	var d6b := board(0, [dragon("Last dragon")])
	var e6b: DuelEngine = d6b.engine
	var s6b := TestFixtures.give_to_hand(e6b, 0, search_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(e6b, 0, s6b), "search activated on a 1-card Deck")
	t.eq(e6b.state.player(0).deck_count(), 0, "the Deck is now empty")
	t.is_false(e6b.state.is_duel_over(), "a search is not a draw either")

	# =======================================================================
	# 3. R40 part C — the mandatory-trigger exception, both halves.
	#    The trigger is fired by a REAL engine activation paying a discard cost,
	#    which is the route Cards of Consonance will take on The White Stone of Legend.
	# =======================================================================
	for present in [true, false]:
		t.start("a MANDATORY GY trigger activates whether or not its search can find anything (%s)"
			% ("target present" if present else "target ABSENT"))
		var d7 := board(0, [])
		var e7: DuelEngine = d7.engine
		var wanted: CardInstance = null
		if present:
			wanted = TestFixtures.give_to_deck(e7, 0, dragon("Wanted card"))
		TestFixtures.give_to_deck(e7, 0, TestFixtures.monster("Padding"))
		var searcher := TestFixtures.give_to_hand(e7, 0, gy_trigger_searcher("Wanted card"))
		var engine_card := TestFixtures.give_to_hand(e7, 0, discard_cost_spell())
		var ctrl7: ScriptedController = d7.p0
		ctrl7.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [searcher.id])
		var hand_before := e7.state.player(0).hand.size()
		var b7_link := TestFixtures.count_events(e7, GameEvent.Kind.CHAIN_LINK_ADDED)
		var b7_gy := TestFixtures.count_events(e7, GameEvent.Kind.CARD_SENT_TO_GY)
		var b7_rev := TestFixtures.count_events(e7, GameEvent.Kind.CARD_REVEALED)
		t.is_true(TestFixtures.activate_card(e7, 0, engine_card),
			"the discard engine activated through the real action API")
		t.eq(ctrl7.errors, [], "the queued discard answer went to the prompt the test meant")
		t.eq(searcher.zone, Enums.Zone.GRAVEYARD, "the trigger source really reached the GY")
		t.eq(searcher.last_move_reason, Enums.MoveReason.DISCARDED,
			"and it got there by a DISCARD, not a destruction")
		t.eq(TestFixtures.count_events_for(e7, GameEvent.Kind.CARD_SENT_TO_GY, searcher.id), 1,
			"a discard IS a send to the GY, which is what the trigger keys on")
		t.eq(TestFixtures.count_events(e7, GameEvent.Kind.CARD_SENT_TO_GY) - b7_gy, 2,
			"and the spent Normal Spell reached the GY too - two different cards")
		# 2 links: the discard engine's own activation, and the trigger it caused.
		t.eq(TestFixtures.count_events(e7, GameEvent.Kind.CHAIN_LINK_ADDED) - b7_link, 2,
			"the mandatory trigger REALLY activated - a second Chain Link was made")
		# hand: -1 for the spell, -1 for the discard, +1 only if the search found something.
		var expected := hand_before - 2 + (1 if present else 0)
		t.eq(e7.state.player(0).hand.size(), expected,
			"the hand changed by exactly what the search did or did not add")
		if present:
			t.eq(wanted.zone, Enums.Zone.HAND, "the named card was added")
			t.eq(TestFixtures.count_events(e7, GameEvent.Kind.CARD_REVEALED) - b7_rev, 1,
				"and it was revealed on the way")
		else:
			t.eq(TestFixtures.count_events(e7, GameEvent.Kind.CARD_REVEALED) - b7_rev, 0,
				"nothing was added, so nothing was revealed")
		t.is_false(e7.state.is_duel_over(), "an empty search is never a loss")

	# =======================================================================
	# 4. Qualified cost candidate lists and the new predicates
	# =======================================================================
	t.start("qualified candidate lists filter the right zone by the right property")
	var d8 := board(0, [])
	var e8: DuelEngine = d8.engine
	var lv8 := TestFixtures.give_to_hand(e8, 0, TestFixtures.monster("Level eight", 8))
	var lv4 := TestFixtures.give_to_hand(e8, 0, TestFixtures.monster("Level four", 4))
	var dtuner := TestFixtures.give_to_hand(e8, 0, dragon("Dragon tuner", 1, 300, true))
	var big_dtuner := TestFixtures.give_to_hand(e8, 0, dragon("Big dragon tuner", 1, 1800, true))
	var warrior_tuner_def := TestFixtures.monster("Warrior tuner", 1, 100)
	warrior_tuner_def.is_tuner = true
	var warrior_tuner := TestFixtures.give_to_hand(e8, 0, warrior_tuner_def)
	var a_spell := TestFixtures.give_to_hand(e8, 0, mill_spell("Dragon"))
	var normal_field := TestFixtures.give_monster_on_field(e8, 0, TestFixtures.monster("Vanilla"))
	var effect_field := TestFixtures.give_monster_on_field(e8, 0, effect_monster("Has an effect"))
	var facedown := TestFixtures.give_monster_on_field(e8, 0, TestFixtures.monster("Face-down"),
		Enums.Position.FACE_DOWN_DEFENSE)
	var opp_normal := TestFixtures.give_monster_on_field(e8, 1, TestFixtures.monster("Theirs"))
	var probe := EffectContext.new(e8.state, a_spell, a_spell.definition.effects[0])

	t.eq(EffectPrimitives.qualified_hand_cards(probe, EffectPrimitives.monster_of_level(8)),
		[lv8], "'discard 1 Level 8 monster' sees exactly the Level 8 monster")
	t.eq(EffectPrimitives.qualified_hand_cards(probe,
		EffectPrimitives.monster_of_level_at_least(7)), [lv8],
		"'Level 7 or higher' is a FLOOR, not an exact match")
	t.is_false(EffectPrimitives.monster_of_level_at_least(7).call(lv4),
		"a Level 4 monster fails a floor of 7")
	t.is_true(EffectPrimitives.monster_of_level_at_least(4).call(lv4),
		"and passes a floor of 4 - the floor is inclusive")
	t.is_false(EffectPrimitives.monster_of_level_at_least(1).call(a_spell),
		"a Spell is never a monster of any Level")

	t.eq(EffectPrimitives.qualified_hand_cards(probe,
		EffectPrimitives.tuner_monster("Dragon", 1000)), [dtuner],
		"'Dragon Tuner with 1000 or less ATK' takes only the one that is all three")
	t.is_false(EffectPrimitives.tuner_monster("Dragon", 1000).call(big_dtuner),
		"the printed ATK cap is enforced")
	t.is_false(EffectPrimitives.tuner_monster("Dragon", 1000).call(warrior_tuner),
		"a Tuner of the wrong race is refused")
	t.is_false(EffectPrimitives.tuner_monster("Dragon", 1000).call(lv8),
		"a non-Tuner is refused")
	t.is_true(EffectPrimitives.tuner_monster("Dragon").call(big_dtuner),
		"no cap given means no cap applied")
	t.is_false(EffectPrimitives.tuner_monster().call(a_spell), "a Spell is not a Tuner")

	var sendable := EffectPrimitives.qualified_own_field_monsters(probe,
		EffectPrimitives.non_effect_monster())
	t.eq(sendable, [normal_field], "face-up own non-Effect Monsters only")
	t.is_false(sendable.has(effect_field), "an Effect Monster is excluded")
	t.is_false(sendable.has(facedown), "a face-down monster is excluded")
	t.is_false(sendable.has(opp_normal), "the opponent's monster is excluded")
	t.eq(EffectPrimitives.qualified_own_field_monsters(probe,
		EffectPrimitives.non_effect_monster(), false).size(), 2,
		"face_up_only=false reaches the face-down one too")
	t.is_false(EffectPrimitives.non_effect_monster().call(a_spell),
		"a Spell is not a non-Effect MONSTER - it is not a monster at all")
	t.is_true(EffectPrimitives.non_effect_monster().call(normal_field),
		"a vanilla monster qualifies")

	# =======================================================================
	# 5. Both seats, and replay determinism through the seeded Rng
	# =======================================================================
	t.start("the subsystem reads the ACTING player's Deck, from either seat")
	var d9 := board(1, [dragon("Theirs A"), TestFixtures.monster("Theirs B")])
	var e9: DuelEngine = d9.engine
	var opp_before := e9.state.player(0).deck_count()
	var s9 := TestFixtures.give_to_hand(e9, 1, search_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(e9, 1, s9), "seat 1 searched")
	t.eq(d9.deck[0].zone, Enums.Zone.HAND, "seat 1's own Deck was searched")
	t.eq(d9.deck[0].owner_id, 1, "and the card belongs to seat 1")
	t.is_true(e9.state.player(1).hand.has(d9.deck[0]), "it is in seat 1's hand")
	t.eq(e9.state.player(0).deck_count(), opp_before, "the OPPONENT's Deck was not touched")

	t.start("two duels with the same seed and the same inputs shuffle identically")
	var order_a: Array = []
	var order_b: Array = []
	for run_index in [0, 1]:
		var dd := board(0, [dragon("Wanted"), TestFixtures.monster("F1"),
			TestFixtures.monster("F2"), TestFixtures.monster("F3"),
			TestFixtures.monster("F4"), TestFixtures.monster("F5")], 77123)
		var ee: DuelEngine = dd.engine
		var ss := TestFixtures.give_to_hand(ee, 0, search_spell("Dragon"))
		var before_order: Array = []
		for entry in ee.state.player(0).deck:
			before_order.append(entry.card_name())
		t.is_true(TestFixtures.activate_card(ee, 0, ss), "search %d resolved" % run_index)
		var names: Array = []
		for entry in ee.state.player(0).deck:
			names.append(entry.card_name())
		# The tail shuffle really reordered the Deck, not merely removed one card from it.
		before_order.erase("Wanted")
		t.ne(names, before_order,
			"run %d: the search's tail shuffle actually reordered the Deck" % run_index)
		if run_index == 0:
			order_a = names
		else:
			order_b = names
	t.eq(order_a, order_b, "the tail shuffle is deterministic under a fixed seed")
	t.eq(order_a.size(), 5, "and the shuffle kept every remaining card")
	t.is_false(order_a.has("Wanted"), "the searched card is not still in the Deck")

	# =======================================================================
	# 6. The choice is real, and it is the controller's
	# =======================================================================
	t.start("a search with several qualifying cards really asks, and honours the answer")
	var da := board(0, [dragon("Dragon A"), dragon("Dragon B"), dragon("Dragon C")])
	var ea: DuelEngine = da.engine
	var ctrl: ScriptedController = da.p0
	ctrl.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [da.deck[2].id])
	var sa := TestFixtures.give_to_hand(ea, 0, search_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(ea, 0, sa), "search resolved")
	t.eq(ctrl.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(da.deck[2].zone, Enums.Zone.HAND, "the CHOSEN card was the one added")
	t.eq(da.deck[0].zone, Enums.Zone.DECK, "the first candidate stayed in the Deck")
	t.eq(da.deck[1].zone, Enums.Zone.DECK, "and so did the second")

	t.start("a mill with several qualifying cards asks too, and honours the answer")
	var db := board(0, [dragon("Dragon A"), dragon("Dragon B"), dragon("Dragon C")])
	var eb: DuelEngine = db.engine
	var ctrlb: ScriptedController = db.p0
	ctrlb.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [db.deck[1].id])
	var mb := TestFixtures.give_to_hand(eb, 0, mill_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(eb, 0, mb), "mill resolved")
	t.eq(ctrlb.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(db.deck[1].zone, Enums.Zone.GRAVEYARD, "the CHOSEN card was the one milled")
	t.eq(db.deck[0].zone, Enums.Zone.DECK, "the first candidate stayed in the Deck")
	t.eq(db.deck[2].zone, Enums.Zone.DECK, "and so did the third")

	t.start("with exactly one candidate nothing is asked - there is nothing to decide")
	var dc := board(0, [dragon("Only dragon"), TestFixtures.monster("Not a dragon")])
	var ec: DuelEngine = dc.engine
	var ctrlc: ScriptedController = dc.p0
	ctrlc.strict = true
	var sc := TestFixtures.give_to_hand(ec, 0, search_spell("Dragon"))
	t.is_true(TestFixtures.activate_card(ec, 0, sc), "search resolved with a single candidate")
	t.eq(ctrlc.errors, [], "a strict controller saw no unqueued prompt")
	t.eq(dc.deck[0].zone, Enums.Zone.HAND, "and the only candidate was taken anyway")

	return t

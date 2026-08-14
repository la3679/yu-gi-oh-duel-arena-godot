class_name MovementTests
extends RefCounted

## Card MOVEMENT and EXCAVATION. Rules under test: `RULES_SPEC.md §8`, `§8.2`, `§9`, `§12.1`
## [S1 p.5, p.28, p.52–53].
##
## This is the **movement gate**, written the way `EquipTests` and `ControlTests` were: a
## RULES suite built from synthetic cards, so what it proves is that the ENGINE is right
## rather than that one printed card happens to work. The batch-7 movement cards
## (`Compulsory Evacuation Device`, `Kaiser Glider`, `A Wingbeat of Giant Dragon`,
## `Phoenix Wing Wind Blast`, `Spiritual Wind Art - Miyabi`, `Chain Detonation`,
## `Chain Healing`, `Crystal Seer`) are only implemented once it passes.
##
## The load-bearing claim is that these are **not one operation with a destination
## argument**:
##
##   return to hand · add to hand · top of Deck · bottom of Deck · shuffle into Deck ·
##   send to GY · banish · excavate · reveal
##
## They differ in who the card belongs to afterwards, what the players are still allowed to
## know, whether anything is shuffled, and which triggers may see them. Every one of those
## differences is asserted below, in both directions.


static func run() -> TestCase:
	var t := TestCase.new("MovementTests")
	# The distinctions the subsystem exists for
	_test_the_move_reasons_are_not_interchangeable(t)
	_test_a_bounce_is_not_a_destruction_and_not_a_send_to_gy(t)
	_test_adding_to_hand_is_not_returning_to_hand(t)
	# Owner vs controller
	_test_a_card_returns_to_its_OWNERS_hand(t)
	_test_a_card_returns_to_its_OWNERS_deck(t)
	_test_movement_ends_a_control_lease(t)
	# Deck placement
	_test_top_and_bottom_are_exact_positions(t)
	_test_an_unshuffled_placement_leaves_the_rest_of_the_deck_alone(t)
	_test_a_shuffle_actually_shuffles_and_is_deterministic(t)
	# Hidden information
	_test_revealing_does_not_move_the_card(t)
	_test_a_shuffle_clears_revealed_to_and_a_placement_does_not(t)
	# What leaving the field resets and what survives
	_test_leaving_the_field_normalises_face_and_clears_state(t)
	_test_equip_relationships_are_cleaned_up_by_a_bounce(t)
	_test_card_memory_survives_a_move_and_flags_do_not(t)
	# Excavation
	_test_excavate_takes_from_the_top_and_reveals_to_both(t)
	_test_excavate_is_not_a_draw(t)
	_test_excavate_with_fewer_cards_than_asked(t)
	_test_excavated_cards_are_placed_in_a_stated_order(t)
	# Resolution-time target re-checks
	_test_a_surviving_field_target_spans_every_field_zone(t)
	_test_an_opponent_field_target_is_re_checked_for_control(t)
	# Resolution-time behaviour
	_test_a_target_that_left_the_field_before_resolution(t)
	_test_several_cards_move_in_sequence(t)
	_test_movement_inside_a_chain_resolution(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A bare EffectContext for driving an `EffectPrimitives` movement helper directly, the way
## `ControlTests` drives `GameState.change_control()` directly. No engine is attached: none
## of the movement primitives needs one, and proving that is part of the point.
static func _ctx(engine: DuelEngine, source: CardInstance, targets: Array = []) -> EffectContext:
	var effect := EffectDef.new("test_move", "Test: move a card.")
	var ctx := EffectContext.new(engine.state, source, effect)
	ctx.controller_id = source.controller_id
	for entry in targets:
		var card: CardInstance = entry
		ctx.chosen_target_ids.append(card.id)
	return ctx


# ---------------------------------------------------------------------------
# Resolution-time target re-checks. RULES_SPEC.md 10, CARD_RULINGS.md R29.
#
# `surviving_target()` asks about ONE named zone, which is what a clause worded "1 monster
# on the field" needs. A clause worded "1 CARD your opponent controls" needs two other
# questions instead, and both are asked here against synthetic cards so the answers are the
# ENGINE's rather than one printed card's.
# ---------------------------------------------------------------------------

static func _test_a_surviving_field_target_spans_every_field_zone(t: TestCase) -> void:
	t.start("surviving_field_target() accepts a target in ANY field zone, which the "
		+ "single-zone check cannot, and still drops one that left the field")
	var d := _duel(9401)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("A Monster", 4, 1000, 1000))
	var backrow := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("A Set Trap"))

	var on_monster := _ctx(engine, source, [monster])
	t.eq(EffectPrimitives.surviving_field_target(on_monster), monster,
		"a monster in the Monster Zone survives")
	var on_backrow := _ctx(engine, source, [backrow])
	t.eq(EffectPrimitives.surviving_field_target(on_backrow), backrow,
		"and so does a Set card in the Spell & Trap Zone")
	# The distinction this primitive exists for: the single-zone check would drop it.
	t.is_null(EffectPrimitives.surviving_target(on_backrow, Enums.Zone.MONSTER_ZONE),
		"which the MONSTER_ZONE-only check would have silently dropped")

	# A target that left the field is dropped, exactly as the single-zone check does.
	engine.state.move_card(backrow, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.is_null(EffectPrimitives.surviving_field_target(_ctx(engine, source, [backrow])),
		"a target that left the field is dropped, never chased into the Graveyard")
	# No target at all is not an error.
	t.is_null(EffectPrimitives.surviving_field_target(_ctx(engine, source)),
		"and an effect with no target at all gets null rather than a crash")


static func _test_an_opponent_field_target_is_re_checked_for_control(t: TestCase) -> void:
	t.start("surviving_opponent_field_target() re-checks CONTROL at resolution and never "
		+ "consults ownership (CARD_RULINGS.md R29)")
	var d := _duel(9402)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000))
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1000, 1000))

	t.eq(EffectPrimitives.surviving_opponent_field_target(_ctx(engine, source, [theirs])),
		theirs, "a card the opponent controls is a legal surviving target")
	t.is_null(EffectPrimitives.surviving_opponent_field_target(_ctx(engine, source, [mine])),
		"a card the effect's own controller controls is not")

	# Control changes to the effect's controller: no longer "a card your opponent controls".
	t.is_true(engine.state.change_control(theirs, 0, source.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "the effect's controller takes it")
	t.eq(theirs.controller_id, 0, "they now control it")
	t.eq(theirs.owner_id, 1, "while the opponent still OWNS it")
	t.is_null(EffectPrimitives.surviving_opponent_field_target(_ctx(engine, source, [theirs])),
		"so it is no longer a card the opponent controls, and the effect drops it")
	t.eq(EffectPrimitives.surviving_field_target(_ctx(engine, source, [theirs])), theirs,
		"even though it is still very much on the field — the two checks differ")

	# Ownership is never consulted: a card the effect's controller OWNS but the opponent
	# CONTROLS is a legal target, which is the mirror of the case above.
	var lent := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Lent Out", 4, 1200, 1200))
	t.is_true(engine.state.change_control(lent, 1, theirs.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "the opponent takes one of theirs")
	t.eq(lent.owner_id, 0, "the effect's controller still owns it")
	t.eq(lent.controller_id, 1, "but the opponent controls it")
	t.eq(EffectPrimitives.surviving_opponent_field_target(_ctx(engine, source, [lent])),
		lent, "and control is what the text names, so it IS a legal surviving target")


## The names of a player's Deck, top first. Deck order is engine state, never public — this
## reads it directly because a test is allowed to.
static func _deck_names(state: GameState, pid: int) -> Array:
	var out: Array = []
	for entry in state.player(pid).deck:
		var card: CardInstance = entry
		out.append(card.card_name())
	return out


# ---------------------------------------------------------------------------
# The distinctions the subsystem exists for
# ---------------------------------------------------------------------------

static func _test_the_move_reasons_are_not_interchangeable(t: TestCase) -> void:
	t.start("the five destinations are five different moves, each with its own reason, "
		+ "event and resulting zone [S1 p.52-53]")
	var d := _duel(701)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state

	var cases := [
		{"zone": Enums.Zone.HAND, "reason": Enums.MoveReason.RETURNED_TO_HAND,
			"event": GameEvent.Kind.CARD_RETURNED_TO_HAND},
		{"zone": Enums.Zone.HAND, "reason": Enums.MoveReason.ADDED_TO_HAND,
			"event": GameEvent.Kind.CARD_ADDED_TO_HAND},
		{"zone": Enums.Zone.DECK, "reason": Enums.MoveReason.RETURNED_TO_DECK_TOP,
			"event": GameEvent.Kind.CARD_RETURNED_TO_DECK},
		{"zone": Enums.Zone.DECK, "reason": Enums.MoveReason.RETURNED_TO_DECK_BOTTOM,
			"event": GameEvent.Kind.CARD_RETURNED_TO_DECK},
		{"zone": Enums.Zone.DECK, "reason": Enums.MoveReason.SHUFFLED_INTO_DECK,
			"event": GameEvent.Kind.CARD_RETURNED_TO_DECK},
		{"zone": Enums.Zone.GRAVEYARD, "reason": Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
			"event": GameEvent.Kind.CARD_SENT_TO_GY},
		{"zone": Enums.Zone.BANISHED, "reason": Enums.MoveReason.BANISHED,
			"event": GameEvent.Kind.CARD_BANISHED},
	]
	for entry in cases:
		var spec: Dictionary = entry
		var to_zone: Enums.Zone = spec["zone"]
		var reason: Enums.MoveReason = spec["reason"]
		var event_kind: GameEvent.Kind = spec["event"]
		var card := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Traveller %d" % int(reason), 4, 1000, 1000))
		var before := TestFixtures.count_events(engine, event_kind)
		t.is_true(state.move_card(card, to_zone, reason), "the move succeeds")
		t.eq(card.zone, to_zone, "it arrived in the zone the caller asked for")
		t.eq(card.last_move_reason, reason, "and recorded the reason it was moved for")
		t.eq(TestFixtures.count_events(engine, event_kind), before + 1,
			"exactly one semantic event for this reason")

	# Every one of them also emits the generic CARD_MOVED, which is what the log reads.
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_MOVED) >= cases.size(), true,
		"every move also emits CARD_MOVED")


static func _test_a_bounce_is_not_a_destruction_and_not_a_send_to_gy(t: TestCase) -> void:
	t.start("returning a card to the hand or the Deck is NOT a destruction and NOT a send "
		+ "to the Graveyard [S1 p.52]")
	var d := _duel(702)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var destroyed_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED)
	var to_gy_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)

	for entry in [Enums.MoveReason.RETURNED_TO_HAND, Enums.MoveReason.RETURNED_TO_DECK_TOP,
			Enums.MoveReason.RETURNED_TO_DECK_BOTTOM, Enums.MoveReason.SHUFFLED_INTO_DECK,
			Enums.MoveReason.ADDED_TO_HAND, Enums.MoveReason.EXCAVATED]:
		var reason: Enums.MoveReason = entry
		t.is_false(Enums.is_destruction(reason),
			"reason %d is not a destruction" % int(reason))
		t.is_false(Enums.is_sent_to_gy(reason),
			"reason %d is not a send to the Graveyard" % int(reason))

	var monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bounced", 4, 1200, 800))
	state.move_card(monster, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED), destroyed_before,
		"no CARD_DESTROYED was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY), to_gy_before,
		"no CARD_SENT_TO_GY was emitted")
	t.eq(state.player(0).graveyard.size(), 0, "and nothing reached the Graveyard")


static func _test_adding_to_hand_is_not_returning_to_hand(t: TestCase) -> void:
	t.start("'add to your hand' and 'return to the hand' are two reasons and two events, "
		+ "so a bounce trigger cannot see a search")
	var d := _duel(703)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state

	var from_deck: CardInstance = state.player(0).deck[0]
	t.is_true(state.move_card(from_deck, Enums.Zone.HAND, Enums.MoveReason.ADDED_TO_HAND),
		"a card is added to the hand from the Deck")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		from_deck.id), 0, "it did NOT emit CARD_RETURNED_TO_HAND")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_ADDED_TO_HAND,
		from_deck.id), 1, "it emitted CARD_ADDED_TO_HAND exactly once")

	var on_field := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Returner", 4, 1000, 1000))
	state.move_card(on_field, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_ADDED_TO_HAND,
		on_field.id), 0, "a bounce did NOT emit CARD_ADDED_TO_HAND")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		on_field.id), 1, "the bounce emitted CARD_RETURNED_TO_HAND exactly once")


# ---------------------------------------------------------------------------
# Owner vs controller [S1 p.52]
# ---------------------------------------------------------------------------

static func _test_a_card_returns_to_its_OWNERS_hand(t: TestCase) -> void:
	t.start("a card the OPPONENT controls returns to its OWNER's hand, not to the "
		+ "controller's [S1 p.52]")
	var d := _duel(704)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source", 3, 500, 500))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Loaned", 4, 1400, 1000))

	t.is_true(state.change_control(victim, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP), "player 0 takes control of it")
	t.eq(victim.controller_id, 0, "player 0 controls it")
	t.eq(victim.owner_id, 1, "player 1 still owns it")

	var ctx := _ctx(engine, source, [victim])
	t.not_null(EffectPrimitives.return_target_to_hand(ctx), "it is returned to the hand")
	t.eq(victim.zone, Enums.Zone.HAND, "it is in a hand")
	t.eq(victim.controller_id, 1, "the controller is now its OWNER")
	t.eq(state.player(1).hand.has(victim), true, "it is in PLAYER 1's hand")
	t.eq(state.player(0).hand.has(victim), false, "and not in player 0's")


static func _test_a_card_returns_to_its_OWNERS_deck(t: TestCase) -> void:
	t.start("the same is true of every Deck destination: the OWNER's Deck, top, bottom "
		+ "and shuffle alike")
	for entry in [Enums.MoveReason.RETURNED_TO_DECK_TOP,
			Enums.MoveReason.RETURNED_TO_DECK_BOTTOM, Enums.MoveReason.SHUFFLED_INTO_DECK]:
		var reason: Enums.MoveReason = entry
		var d := _duel(705 + int(reason))
		var engine: DuelEngine = d["engine"]
		var state: GameState = engine.state
		var source := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Source", 3, 500, 500))
		var victim := TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Loaned", 4, 1400, 1000))
		state.change_control(victim, 0, source.id,
			Enums.ControlDuration.WHILE_SOURCE_FACE_UP)
		var owner_deck_before: int = state.player(1).deck.size()
		var taker_deck_before: int = state.player(0).deck.size()

		t.is_true(state.move_card(victim, Enums.Zone.DECK, reason), "it goes to a Deck")
		t.eq(victim.zone, Enums.Zone.DECK, "it is in a Deck")
		t.eq(victim.controller_id, 1, "under its owner")
		t.eq(state.player(1).deck.size(), owner_deck_before + 1,
			"the OWNER's Deck grew by one")
		t.eq(state.player(0).deck.size(), taker_deck_before,
			"the controller's Deck is untouched")


static func _test_movement_ends_a_control_lease(t: TestCase) -> void:
	t.start("a monster under temporary control that is bounced takes its control lease "
		+ "with it — nothing may revert a card that is no longer on the field")
	var d := _duel(709)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source", 3, 500, 500))
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Loaned", 4, 1400, 1000))
	state.change_control(victim, 0, source.id, Enums.ControlDuration.UNTIL_END_PHASE)
	t.eq(state.control_leases_for(victim.id).size(), 1, "one lease is in force")

	state.move_card(victim, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	t.eq(state.control_leases_for(victim.id).size(), 0, "the lease is gone with the card")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"and no second CONTROL_CHANGED was emitted to 'hand it back'")

	# The lease must not resurrect the card's old controller if it comes back later.
	state.move_card(victim, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.SUMMONED,
		{"to_player": 1, "position": Enums.Position.FACE_UP_ATTACK})
	state.expire_control_leases(true)
	t.eq(victim.controller_id, 1, "a card that returns to the field is under its owner")


# ---------------------------------------------------------------------------
# Deck placement. RULES_SPEC.md 8.2.
# ---------------------------------------------------------------------------

static func _test_top_and_bottom_are_exact_positions(t: TestCase) -> void:
	t.start("'on the top of the Deck' and 'on the bottom of the Deck' are exact positions, "
		+ "taken from the MOVE REASON rather than from a separate option")
	var d := _duel(710)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var top_card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Goes On Top", 4, 1000, 1000))
	var bottom_card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Goes On Bottom", 4, 1000, 1000))

	# Deliberately NO deck_position option: the reason alone must decide.
	t.is_true(state.move_card(top_card, Enums.Zone.DECK,
		Enums.MoveReason.RETURNED_TO_DECK_TOP), "the top placement succeeds")
	t.eq(state.player(0).deck[0], top_card, "it is the very top card of the Deck")

	t.is_true(state.move_card(bottom_card, Enums.Zone.DECK,
		Enums.MoveReason.RETURNED_TO_DECK_BOTTOM), "the bottom placement succeeds")
	var deck: Array = state.player(0).deck
	t.eq(deck[deck.size() - 1], bottom_card, "it is the very bottom card of the Deck")
	t.eq(deck[0], top_card, "and the top card is still where it was put")

	# The next draw is the card that was placed on top — the observable consequence.
	var drawn := state.draw(0, 1)
	t.eq(drawn.size(), 1, "one card is drawn")
	t.eq(drawn[0], top_card, "the draw takes the card placed on TOP")


static func _test_an_unshuffled_placement_leaves_the_rest_of_the_deck_alone(
		t: TestCase) -> void:
	t.start("a top or bottom placement does NOT shuffle: it is not implemented as "
		+ "'put it in and shuffle', and the rest of the Deck keeps its order")
	var d := _duel(711)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var before := _deck_names(state, 0)
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Placed", 4, 1000, 1000))

	state.move_card(card, Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_TOP)
	var after := _deck_names(state, 0)
	t.eq(after.size(), before.size() + 1, "the Deck grew by exactly one card")
	t.eq(after[0], "Placed", "the placed card is on top")
	t.eq(after.slice(1), before, "and every other card is in exactly its old position")

	var bottom := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Placed Low", 4, 1000, 1000))
	state.move_card(bottom, Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_BOTTOM)
	var after2 := _deck_names(state, 0)
	t.eq(after2.slice(0, after2.size() - 1), after,
		"a bottom placement leaves the whole Deck above it in order")


static func _test_a_shuffle_actually_shuffles_and_is_deterministic(t: TestCase) -> void:
	t.start("'shuffle it into the Deck' actually shuffles the Deck, and does so through "
		+ "the seeded RNG so a replay reproduces it")
	var d := _duel(712)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var before := _deck_names(state, 0)
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Shuffled In", 4, 1000, 1000))

	t.is_true(state.move_card(card, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK),
		"the shuffle-in succeeds")
	var after := _deck_names(state, 0)
	t.eq(after.size(), before.size() + 1, "the Deck grew by exactly one card")
	t.is_true(after.has("Shuffled In"), "the card is somewhere in the Deck")
	t.ne(after[0], "Shuffled In",
		"it is NOT sitting deterministically on top — the Deck was really shuffled")
	t.ne(after.slice(1), before, "and the rest of the Deck was reordered")

	# Same seed, same actions, same resulting order. This is what replay depends on.
	var d2 := _duel(712)
	var engine2: DuelEngine = d2["engine"]
	var card2 := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.monster("Shuffled In", 4, 1000, 1000))
	engine2.state.move_card(card2, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.eq(_deck_names(engine2.state, 0), after,
		"the same seed produces the same shuffled order")


# ---------------------------------------------------------------------------
# Hidden information. RULES_SPEC.md 12.1, design decision 11.
# ---------------------------------------------------------------------------

static func _test_revealing_does_not_move_the_card(t: TestCase) -> void:
	t.start("revealing shows a card without moving it, and a reveal to one player is a "
		+ "PRIVATE event while a reveal to both is public")
	var d := _duel(713)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var card := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Shown", 4, 1000, 1000))
	var zone_before := card.zone
	var moves_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_MOVED)

	state.reveal(card, [1])
	t.eq(card.zone, zone_before, "the card did not move")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_MOVED), moves_before,
		"and no CARD_MOVED was emitted")
	t.is_true(1 in card.revealed_to, "player 1 has now legally seen it")
	var revealed := TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED)
	t.eq(revealed.size(), 1, "one CARD_REVEALED event")
	var ev: GameEvent = revealed[0]
	t.is_false(ev.is_public(), "a reveal to one player only is private")
	t.is_true(1 in ev.private_to(), "and is private TO that player")

	# The opponent's view of the hand honours it, which is the observable consequence.
	var view: Dictionary = state.get_visible_state(1)
	var hand: Array = view["players"][0]["hand"]
	var seen := false
	for entry in hand:
		var slot: Dictionary = entry
		if str(slot.get("name", "")) == "Shown":
			seen = true
	t.is_true(seen, "player 1 can see the revealed card in player 0's hand")

	state.reveal(card, [0])
	var revealed2 := TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED)
	var ev2: GameEvent = revealed2[revealed2.size() - 1]
	t.is_true(ev2.is_public(), "a reveal both players can see is a public event")


static func _test_a_shuffle_clears_revealed_to_and_a_placement_does_not(
		t: TestCase) -> void:
	t.start("a SHUFFLE ends what the players legally know; an unshuffled top or bottom "
		+ "placement does not [S1 p.5, p.28] — design decision 11")
	var d := _duel(714)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state

	for entry in [Enums.MoveReason.RETURNED_TO_DECK_TOP,
			Enums.MoveReason.RETURNED_TO_DECK_BOTTOM]:
		var reason: Enums.MoveReason = entry
		var kept := TestFixtures.give_to_hand(engine, 0,
			TestFixtures.monster("Known %d" % int(reason), 4, 1000, 1000))
		state.reveal(kept, [0, 1])
		state.move_card(kept, Enums.Zone.DECK, reason)
		t.is_true(1 in kept.revealed_to,
			"its position in the Deck is still known, so revealed_to survives")

	var lost := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Forgotten", 4, 1000, 1000))
	state.reveal(lost, [0, 1])
	state.move_card(lost, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.is_true(lost.revealed_to.is_empty(),
		"a card shuffled into the Deck stops being identifiable")

	# The shuffle also ends what was known about every OTHER card in that Deck, because the
	# shuffle is what moved them all.
	var bystander := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	state.reveal(bystander, [0, 1])
	state.move_card(bystander, Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_TOP)
	t.is_true(1 in bystander.revealed_to, "known while it sits on top unshuffled")
	var trigger := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Trigger", 4, 1000, 1000))
	state.move_card(trigger, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.is_true(bystander.revealed_to.is_empty(),
		"and unknown again once somebody shuffles that Deck")


# ---------------------------------------------------------------------------
# What leaving the field resets, and what survives. RULES_SPEC.md 15.
# ---------------------------------------------------------------------------

static func _test_leaving_the_field_normalises_face_and_clears_state(t: TestCase) -> void:
	t.start("a card returned to the hand or Deck is face-down there, and every scrap of "
		+ "per-instance field state is reset")
	var d := _duel(715)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Loaded", 4, 1000, 1000), Enums.Position.FACE_UP_ATTACK)
	card.add_atk_modifier(-1, 700, "permanent")
	card.add_counters("Balloon Counter", 3)
	card.flags["some_flag"] = true
	card.effects_negated = true
	card.has_attacked_this_turn = true
	card.turn_summoned = state.turn_number
	t.eq(card.current_atk(), 1700, "it is buffed while on the field")

	state.move_card(card, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	t.eq(card.position, Enums.Position.FACE_DOWN, "a card in the hand is face-down")
	t.eq(card.current_atk(), 1000, "the ATK modifier is gone")
	t.eq(card.counter_count("Balloon Counter"), 0, "the counters are gone")
	t.eq(card.flags.size(), 0, "the per-instance flags are gone")
	t.is_false(card.effects_are_negated(), "the negation is gone")
	t.is_false(card.has_attacked_this_turn, "the attack record is gone")
	t.eq(card.turn_summoned, -1, "and it is no longer a monster that was Summoned")

	# `last_move_*` is recorded AFTER on_leave_field(), so it survives it, and
	# `was_face_up` describes where the card CAME FROM. RULES_SPEC.md 15.
	t.eq(card.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"the last move reason survives the reset")
	t.eq(card.last_move_from_zone, Enums.Zone.MONSTER_ZONE, "as does where it came from")
	t.is_true(card.last_move_was_face_up,
		"and 'was it face-up?' answers about the ORIGIN, not about the hand")

	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Hidden", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	state.move_card(face_down, Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_BOTTOM)
	t.is_false(face_down.last_move_was_face_up,
		"a face-down monster returned to the Deck was not face-up")
	t.eq(face_down.position, Enums.Position.FACE_DOWN, "and is face-down in the Deck")


static func _test_equip_relationships_are_cleaned_up_by_a_bounce(t: TestCase) -> void:
	t.start("bouncing an equipped monster destroys its Equip Cards by the rules, and "
		+ "bouncing an Equip Card just unequips it [S1 p.29, p.55]")
	var d := _duel(716)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var host := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var equip := TestFixtures.give(engine, 0, TestFixtures.equip_spell("Clinger", 400),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	t.is_true(state.equip_to(equip, host), "the monster is equipped")

	state.move_card(host, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	t.eq(host.equipped_card_ids.size(), 0, "the host's equip list is empty")
	t.eq(equip.equipped_to_id, -1, "the Equip Card has no host")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "and it was destroyed by the rules")
	t.eq(equip.last_move_reason, Enums.MoveReason.DESTROYED_BY_RULE,
		"with the rules-destruction reason, not a card effect's")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_UNEQUIPPED, equip.id), 1,
		"exactly one CARD_UNEQUIPPED")

	# The other direction: the Equip Card itself is bounced.
	var host2 := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Host 2", 4, 1000, 1000))
	var equip2 := TestFixtures.give(engine, 0, TestFixtures.equip_spell("Clinger 2", 400),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	state.equip_to(equip2, host2)
	state.move_card(equip2, Enums.Zone.HAND, Enums.MoveReason.RETURNED_TO_HAND)
	t.eq(equip2.zone, Enums.Zone.HAND, "the Equip Card is in the hand")
	t.eq(host2.equipped_card_ids.size(), 0, "the host no longer lists it")
	t.eq(host2.zone, Enums.Zone.MONSTER_ZONE, "and the host is untouched on the field")


static func _test_card_memory_survives_a_move_and_flags_do_not(t: TestCase) -> void:
	t.start("GameState.card_memory outlives a card leaving the field; CardInstance.flags "
		+ "does not — the two facilities are not interchangeable (RULES_SPEC.md 15)")
	var d := _duel(717)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Remembered", 4, 1000, 1000))
	var partner := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Partner", 4, 1000, 1000))
	state.remember(card, "linked", partner.id)
	card.flags["ephemeral"] = true

	state.move_card(card, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.eq(state.recall_card(card, "linked"), partner,
		"card_memory still resolves the linked card after the move")
	t.is_false(card.flags.has("ephemeral"), "the per-instance flag did not survive")
	state.forget(card, "linked")
	t.is_null(state.recall_card(card, "linked"), "and memory can be dropped explicitly")


# ---------------------------------------------------------------------------
# Excavation. RULES_SPEC.md 8.2.
# ---------------------------------------------------------------------------

static func _test_excavate_takes_from_the_top_and_reveals_to_both(t: TestCase) -> void:
	t.start("excavating takes exactly N cards off the TOP in order and reveals them to "
		+ "BOTH players — that reveal is what separates it from a private look")
	var d := _duel(718)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var expected := _deck_names(state, 0).slice(0, 3)
	var deck_before: int = state.player(0).deck.size()

	var taken := state.excavate(0, 3)
	t.eq(taken.size(), 3, "three cards were excavated")
	t.eq(state.player(0).deck.size(), deck_before - 3, "and left the Deck")
	var names: Array = []
	for entry in taken:
		var card: CardInstance = entry
		names.append(card.card_name())
		t.eq(card.zone, Enums.Zone.EXCAVATED, "each sits in the excavation zone")
		t.eq(card.controller_id, 0, "held by its owner")
		t.is_true(0 in card.revealed_to and 1 in card.revealed_to,
			"and is revealed to both players")
	t.eq(names, expected, "they come off the top, in Deck order, top card first")
	t.eq(state.excavated_cards(0).size(), 3, "the state reports them as excavated")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), 4,
		"one CARD_EXCAVATED per card moved, plus one for the excavation as a whole")
	# An excavated card is NOT on the field, so nothing may destroy it there.
	var first: CardInstance = taken[0]
	t.is_false(state.destroy(first, Enums.MoveReason.DESTROYED_BY_EFFECT),
		"an excavated card cannot be destroyed — it is not on the field")

	# The opponent may see them, because they were revealed to both.
	var view: Dictionary = state.get_visible_state(1)
	var excavated: Array = view["players"][0]["excavated"]
	t.eq(excavated.size(), 3, "the opponent's view lists all three")
	t.eq(str((excavated[0] as Dictionary).get("name", "")), expected[0],
		"and can read their identities")


static func _test_excavate_is_not_a_draw(t: TestCase) -> void:
	t.start("excavating is not drawing: no CARD_DRAWN, nothing reaches the hand, and an "
		+ "empty Deck does not lose the Duel")
	var d := _duel(719)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var hand_before: int = state.player(0).hand.size()
	var draws_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN)

	state.excavate(0, 2)
	t.eq(state.player(0).hand.size(), hand_before, "nothing reached the hand")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN), draws_before,
		"and no CARD_DRAWN was emitted")

	# Empty the Deck and excavate again. A DRAW here would end the Duel.
	while not state.player(0).deck.is_empty():
		var card: CardInstance = state.player(0).deck[0]
		state.move_card(card, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
	var empty := state.excavate(0, 2)
	t.eq(empty.size(), 0, "an empty Deck excavates nothing")
	t.is_false(state.is_duel_over(), "and the Duel is NOT over — this is not a draw")
	t.is_false(state.player(0).has_lost, "the player has not lost")


static func _test_excavate_with_fewer_cards_than_asked(t: TestCase) -> void:
	t.start("excavating N with fewer than N cards left excavates what is there")
	var d := _duel(720)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	while state.player(0).deck.size() > 1:
		var card: CardInstance = state.player(0).deck[0]
		state.move_card(card, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
	var last_name: String = (state.player(0).deck[0] as CardInstance).card_name()

	var taken := state.excavate(0, 2)
	t.eq(taken.size(), 1, "only the one remaining card is excavated")
	t.eq((taken[0] as CardInstance).card_name(), last_name, "and it is that card")
	t.eq(state.player(0).deck.size(), 0, "the Deck is now empty")
	var events := TestFixtures.events_of(engine, GameEvent.Kind.CARD_EXCAVATED)
	var summary: GameEvent = events[events.size() - 1]
	t.eq(int(summary.data.get("requested", 0)), 2, "the event records what was asked for")
	t.eq(int(summary.data.get("count", 0)), 1, "and what was actually excavated")


static func _test_excavated_cards_are_placed_in_a_stated_order(t: TestCase) -> void:
	t.start("the order excavated cards go back in is stated by the card, not chosen by the "
		+ "engine, and every excavated card must be placed somewhere")
	var d := _duel(721)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Digger", 4, 1000, 1000))
	var ctx := _ctx(engine, source)

	var taken := EffectPrimitives.excavate(ctx, 3)
	t.eq(taken.size(), 3, "three cards excavated through the primitive")
	var first: CardInstance = taken[0]
	var rest: Array = taken.slice(1)

	t.is_true(EffectPrimitives.add_to_hand(ctx, first), "one is added to the hand")
	t.eq(first.zone, Enums.Zone.HAND, "it is in the hand")
	t.eq(first.last_move_reason, Enums.MoveReason.ADDED_TO_HAND,
		"as an ADD, not as a return")
	t.is_true(first.revealed_to.has(1),
		"and the opponent still knows it — the excavation revealed it")

	t.eq(EffectPrimitives.return_excavated(ctx, rest, true), 2,
		"the remainder goes back on the bottom")
	var deck: Array = state.player(0).deck
	t.eq(deck[deck.size() - 2], rest[0],
		"the first of the remainder is placed first, so it sits above the second")
	t.eq(deck[deck.size() - 1], rest[1], "and the second is the very bottom card")
	t.eq(state.excavated_cards(0).size(), 0, "nothing is left in the excavation zone")
	for entry in rest:
		var card: CardInstance = entry
		t.is_true(1 in card.revealed_to,
			"an unshuffled placement keeps what the players saw")

	# Top placement, same rule, opposite end.
	var d2 := _duel(722)
	var engine2: DuelEngine = d2["engine"]
	var source2 := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.monster("Digger", 4, 1000, 1000))
	var ctx2 := _ctx(engine2, source2)
	var taken2 := EffectPrimitives.excavate(ctx2, 2)
	EffectPrimitives.return_excavated(ctx2, taken2, false)
	var deck2: Array = engine2.state.player(0).deck
	t.eq(deck2[0], taken2[1],
		"placing on top one at a time reverses the order, as stacking them physically does")
	t.eq(deck2[1], taken2[0], "with the first-placed card beneath it")


# ---------------------------------------------------------------------------
# Resolution-time behaviour. Design decision 16, master prompt 44.
# ---------------------------------------------------------------------------

static func _test_a_target_that_left_the_field_before_resolution(t: TestCase) -> void:
	t.start("a movement effect re-checks its target at RESOLUTION: a target that left the "
		+ "field, or is in the wrong zone, is dropped rather than chased")
	var d := _duel(723)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source", 3, 500, 500))
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Gone", 4, 1000, 1000))
	var ctx := _ctx(engine, source, [target])

	# It leaves the field before the clause resolves.
	state.move_card(target, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	var gy_before: int = state.player(1).graveyard.size()
	t.is_null(EffectPrimitives.return_target_to_hand(ctx),
		"the bounce does nothing to a target that left the field")
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the card stays where it went")
	t.eq(state.player(1).graveyard.size(), gy_before, "and nothing else moved")

	t.is_null(EffectPrimitives.place_target_on_deck(ctx, true),
		"the same is true of a Deck placement")
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the target is still in the Graveyard")

	# A target that is on the field but in a zone this clause does not name is equally
	# illegal — `surviving_target` asks about the exact zone, not merely "on the field".
	var spell := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Set Trap"))
	var ctx2 := _ctx(engine, source, [spell])
	t.is_null(EffectPrimitives.return_target_to_hand(ctx2, Enums.Zone.MONSTER_ZONE),
		"a Spell/Trap is not a legal target for a clause that names the Monster Zone")
	t.eq(spell.zone, Enums.Zone.SPELL_TRAP_ZONE, "and it did not move")
	# Naming its real zone makes the same card legal, which proves the check is the zone
	# and not something else.
	t.not_null(EffectPrimitives.return_target_to_hand(ctx2, Enums.Zone.SPELL_TRAP_ZONE),
		"naming the Spell & Trap Zone makes it legal")
	t.eq(spell.zone, Enums.Zone.HAND, "and it is returned to its owner's hand")


static func _test_several_cards_move_in_sequence(t: TestCase) -> void:
	t.start("several cards moving in one resolution each get their own move, their own "
		+ "event and their own destination")
	var d := _duel(724)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var source := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Source", 3, 500, 500))
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1000, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000))
	var ctx := _ctx(engine, source)
	var bounces_before := TestFixtures.count_events(engine,
		GameEvent.Kind.CARD_RETURNED_TO_HAND)

	t.is_true(EffectPrimitives.return_to_hand(ctx, mine), "the first card is returned")
	t.is_true(EffectPrimitives.return_to_hand(ctx, theirs), "the second card is returned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND),
		bounces_before + 2, "two separate CARD_RETURNED_TO_HAND events")
	t.is_true(state.player(0).hand.has(mine), "one went to player 0's hand")
	t.is_true(state.player(1).hand.has(theirs), "the other to player 1's, by ownership")
	# Order is observable and must be the order the effect asked for.
	var events := TestFixtures.events_of(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND)
	t.eq(int((events[events.size() - 2] as GameEvent).data.get("card_id", -1)), mine.id,
		"the first move is logged first")
	t.eq(int((events[events.size() - 1] as GameEvent).data.get("card_id", -1)), theirs.id,
		"and the second second")


static func _test_movement_inside_a_chain_resolution(t: TestCase) -> void:
	t.start("a movement performed by a resolving Chain Link reaches the board and the log "
		+ "through the same single entry point as every other move")
	var d := _duel(725)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	var victim := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Chained Away", 4, 1300, 900))
	# The turn player holds the fast effect, because get_legal_actions() only offers
	# actions to the turn player.
	var bouncer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Bouncer", victim, "bounce"))

	t.is_true(TestFixtures.activate_card(engine, 0, bouncer),
		"the Trap is activated and its Chain resolves")
	t.eq(victim.zone, Enums.Zone.HAND, "the monster was returned to a hand")
	t.is_true(state.player(1).hand.has(victim), "its OWNER's hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		victim.id), 1, "exactly one bounce event was logged")
	t.eq(victim.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"with the bounce reason recorded on the card")
	# The Trap itself resolved and left the field; the bounce did not disturb that.
	t.eq(bouncer.zone, Enums.Zone.GRAVEYARD, "the Normal Trap went to the Graveyard")
	t.eq(bouncer.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"as a resolved Spell/Trap, which is a different reason again")

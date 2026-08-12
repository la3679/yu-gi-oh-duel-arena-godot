class_name CounterTests
extends RefCounted

## The generic counter engine: placing, removing, reading and clearing counters.
##
## Rules under test: RULES_SPEC.md 14 and the research finding that counters ARE required
## by the V1 pool — `Apprentice Magician` places a Spell Counter and `Wonder Balloons`
## accumulates Balloon Counters (Research/CARD_RULINGS.md).
##
## These are engine primitives, not card implementations. Phase 5 builds the two cards on
## top of what is proven here.

const SPELL_COUNTER := "Spell Counter"
const BALLOON_COUNTER := "Balloon Counter"


static func run() -> TestCase:
	var t := TestCase.new("CounterTests")
	_test_place_and_read_counters(t)
	_test_counters_are_tracked_per_kind_and_per_instance(t)
	_test_removal_is_all_or_nothing(t)
	_test_counters_never_go_negative(t)
	_test_counters_only_go_on_a_face_up_card_on_the_field(t)
	_test_counter_events_are_emitted(t)
	_test_counters_are_cleared_when_the_card_leaves_the_field(t)
	_test_counters_are_visible_to_both_players(t)
	return t


static func _duel() -> Dictionary:
	var d := TestFixtures.battle_duel(901)
	return d


# ---------------------------------------------------------------------------
# Placing and reading
# ---------------------------------------------------------------------------

static func _test_place_and_read_counters(t: TestCase) -> void:
	t.start("counters can be placed on and read from a face-up card on the field")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Apprentice Shape", 2, 400, 800))

	t.eq(card.counter_count(SPELL_COUNTER), 0, "a card starts with no counters")
	t.is_true(engine.state.place_counters(card, SPELL_COUNTER, 1),
		"placing a counter succeeds")
	t.eq(card.counter_count(SPELL_COUNTER), 1, "and the count reads back")
	t.eq(engine.state.total_counters(card, SPELL_COUNTER), 1,
		"the state-level query agrees")

	engine.state.place_counters(card, SPELL_COUNTER, 2)
	t.eq(card.counter_count(SPELL_COUNTER), 3, "further placements accumulate")
	t.is_false(engine.state.place_counters(card, SPELL_COUNTER, 0),
		"placing zero counters is not a placement")
	t.is_false(engine.state.place_counters(card, SPELL_COUNTER, -1),
		"and a negative placement is rejected outright")
	t.eq(card.counter_count(SPELL_COUNTER), 3, "neither changed the count")


static func _test_counters_are_tracked_per_kind_and_per_instance(t: TestCase) -> void:
	t.start("counters of different kinds and on different copies are independent")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var def := TestFixtures.monster("Twin", 4, 1000, 1000)
	var one := TestFixtures.give_monster_on_field(engine, 0, def)
	var two := TestFixtures.give_monster_on_field(engine, 0, def)

	engine.state.place_counters(one, SPELL_COUNTER, 2)
	engine.state.place_counters(one, BALLOON_COUNTER, 5)
	engine.state.place_counters(two, SPELL_COUNTER, 1)

	t.eq(one.counter_count(SPELL_COUNTER), 2, "kind A on the first copy")
	t.eq(one.counter_count(BALLOON_COUNTER), 5,
		"kind B on the same card is counted separately")
	t.eq(two.counter_count(SPELL_COUNTER), 1,
		"a second copy of the same card has its own counters")
	t.eq(two.counter_count(BALLOON_COUNTER), 0,
		"and none of a kind it was never given")
	t.ne(one.id, two.id, "the two copies really are distinct instances")


# ---------------------------------------------------------------------------
# Removing. Removal is used as a cost, so it must be all-or-nothing.
# ---------------------------------------------------------------------------

static func _test_removal_is_all_or_nothing(t: TestCase) -> void:
	t.start("removing more counters than are present removes none")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Charged", 4, 1000, 1000))
	engine.state.place_counters(card, SPELL_COUNTER, 2)

	t.is_false(engine.state.remove_counters(card, SPELL_COUNTER, 3),
		"removing 3 of 2 fails")
	t.eq(card.counter_count(SPELL_COUNTER), 2,
		"and takes nothing off — a partially paid cost must never happen")

	t.is_true(engine.state.remove_counters(card, SPELL_COUNTER, 2),
		"removing exactly the amount present succeeds")
	t.eq(card.counter_count(SPELL_COUNTER), 0, "leaving none")
	t.is_false(card.counters.has(SPELL_COUNTER),
		"and the empty entry is dropped rather than left at zero")

	t.is_false(engine.state.remove_counters(card, SPELL_COUNTER, 1),
		"removing from a card with no counters fails")
	t.is_false(engine.state.remove_counters(card, BALLOON_COUNTER, 1),
		"as does removing a kind that was never placed")


static func _test_counters_never_go_negative(t: TestCase) -> void:
	t.start("a counter count can never become negative")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Charged", 4, 1000, 1000))
	engine.state.place_counters(card, SPELL_COUNTER, 1)

	engine.state.remove_counters(card, SPELL_COUNTER, 5)
	engine.state.remove_counters(card, SPELL_COUNTER, 1)
	engine.state.remove_counters(card, SPELL_COUNTER, 1)
	t.eq(card.counter_count(SPELL_COUNTER), 0, "the count bottoms out at zero")
	t.is_true(card.counter_count(SPELL_COUNTER) >= 0, "and is never negative")

	t.is_false(engine.state.remove_counters(card, SPELL_COUNTER, 0),
		"removing zero is not a removal")


static func _test_counters_only_go_on_a_face_up_card_on_the_field(t: TestCase) -> void:
	t.start("counters may only be placed on a face-up card on the field")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("In Hand", 4, 1000, 1000))
	var face_down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Set", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	var in_gy := TestFixtures.give(engine, 0,
		TestFixtures.monster("Buried", 4, 1000, 1000), Enums.Zone.GRAVEYARD)
	var face_up := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Open", 4, 1000, 1000))

	t.is_false(engine.state.place_counters(in_hand, SPELL_COUNTER, 1),
		"not on a card in the hand")
	t.is_false(engine.state.place_counters(face_down, SPELL_COUNTER, 1),
		"not on a face-down card")
	t.is_false(engine.state.place_counters(in_gy, SPELL_COUNTER, 1),
		"not on a card in the Graveyard")
	t.is_true(engine.state.place_counters(face_up, SPELL_COUNTER, 1),
		"but yes on a face-up card on the field")

	# Flipping the card face-up makes it a legal host.
	engine.state.set_battle_position(face_down, Enums.Position.FACE_UP_DEFENSE, true)
	t.is_true(engine.state.place_counters(face_down, SPELL_COUNTER, 1),
		"a card flipped face-up becomes a legal host")


# ---------------------------------------------------------------------------
# Events. Effects and the presentation layer both subscribe to these.
# ---------------------------------------------------------------------------

static func _test_counter_events_are_emitted(t: TestCase) -> void:
	t.start("placing and removing counters emits the semantic events")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Charged", 4, 1000, 1000))
	var mark := engine.state.events.size()

	engine.state.place_counters(card, BALLOON_COUNTER, 2, card.id)
	var placed := TestFixtures.events_of(engine, GameEvent.Kind.COUNTER_PLACED, mark)
	t.eq(placed.size(), 1, "COUNTER_PLACED was emitted once")
	t.is_true(placed.size() == 1 and int(placed[0].data.get("card_id", -1)) == card.id,
		"naming the card it went on")
	t.is_true(placed.size() == 1 and str(placed[0].data.get("counter")) == BALLOON_COUNTER,
		"and which kind of counter")
	t.is_true(placed.size() == 1 and int(placed[0].data.get("amount", 0)) == 2
		and int(placed[0].data.get("total", 0)) == 2,
		"carrying both the amount placed and the resulting total")

	engine.state.remove_counters(card, BALLOON_COUNTER, 1)
	var removed := TestFixtures.events_of(engine, GameEvent.Kind.COUNTER_REMOVED, mark)
	t.eq(removed.size(), 1, "COUNTER_REMOVED was emitted once")
	t.is_true(removed.size() == 1 and int(removed[0].data.get("total", -1)) == 1,
		"reporting the total that remains")

	# A rejected removal must be silent: no effect may key off a cost that was not paid.
	var before := engine.state.events.size()
	engine.state.remove_counters(card, BALLOON_COUNTER, 9)
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.COUNTER_REMOVED, before).size(), 0,
		"a rejected removal emits nothing")


static func _test_counters_are_cleared_when_the_card_leaves_the_field(
		t: TestCase) -> void:
	t.start("counters are cleared when the card leaves the field")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Charged", 4, 1000, 1000))
	engine.state.place_counters(card, SPELL_COUNTER, 3)
	t.eq(card.counter_count(SPELL_COUNTER), 3, "the counters are on it")

	engine.state.move_card(card, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_BATTLE)
	t.eq(card.counter_count(SPELL_COUNTER), 0,
		"leaving the field clears them (master prompt 48)")
	t.is_true(card.counters.is_empty(), "no counter of any kind survives")

	# Coming back is a new start, not a restoration.
	engine.state.move_card(card, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.RULE,
		{"to_player": 0, "position": Enums.Position.FACE_UP_ATTACK})
	t.eq(card.counter_count(SPELL_COUNTER), 0,
		"and they do not come back when the card returns to the field")
	t.is_true(engine.state.place_counters(card, SPELL_COUNTER, 1),
		"it can of course be given new ones")


static func _test_counters_are_visible_to_both_players(t: TestCase) -> void:
	t.start("counters on a face-up card are public information")
	var d := _duel()
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wonder Balloons Shape", 4, 1000, 1000))
	engine.state.place_counters(card, BALLOON_COUNTER, 4)

	for viewer in [0, 1]:
		var view := engine.get_visible_state(viewer)
		var zones: Array = view["players"][1]["monster_zones"]
		var seen = null
		for z in zones:
			if z != null and int(z.get("id", -1)) == card.id:
				seen = z
		t.not_null(seen, "player %d can see the face-up card" % viewer)
		t.is_true(seen != null and int(seen["counters"].get(BALLOON_COUNTER, 0)) == 4,
			"and its counter count [S1 p.50]")

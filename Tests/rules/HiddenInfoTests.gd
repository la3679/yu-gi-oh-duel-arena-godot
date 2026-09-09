class_name HiddenInfoTests
extends RefCounted

## Hidden information filtering: what `get_visible_state(viewer_id)` and the filtered
## logs are allowed to tell each player.
##
## Rules under test: RULES_SPEC.md 12 [S1 p.50] and master prompt 40.
##
## | Public | Private |
## |---|---|
## | face-up cards on the field | contents of either hand |
## | both Graveyards | identity of face-down cards |
## | face-up banished cards | Deck order and contents |
## | hand counts, Deck counts, LP | — |
##
## The engine knows everything; this is the only view a player is ever given. Every leak
## test below is run from BOTH sides, because protection that only works one way is not
## protection.


static func run() -> TestCase:
	var t := TestCase.new("HiddenInfoTests")
	_test_hand_contents_are_private_to_their_owner(t)
	_test_face_down_card_identities_are_hidden(t)
	_test_deck_contents_and_order_are_never_exposed(t)
	_test_public_information_is_visible_to_both(t)
	_test_counts_are_public(t)
	_test_revealed_cards_become_visible_to_the_player_who_saw_them(t)
	_test_private_events_are_filtered_from_the_public_log(t)
	_test_chain_information_is_public(t)
	_test_owner_is_reported_separately_from_controller(t)
	_test_no_hidden_field_leaks_the_card_name(t)
	# The `look_at_hand` gate — batch 12 unit B, written before `Aoi`.
	_test_looking_at_a_hand_reveals_it_to_one_player_only(t)
	_test_looking_at_a_hand_moves_nothing(t)
	_test_looking_at_an_empty_hand_is_legal_and_sees_nothing(t)
	_test_the_knowledge_survives_the_look(t)
	_test_a_look_does_not_leak_into_the_public_log(t)
	_test_sending_from_a_hand_is_not_a_discard(t)
	# The random-choice gate — batch 15 unit A, written before `A Hero Emerges`.
	_test_a_random_pick_is_seeded_and_repeatable(t)
	_test_a_random_pick_consumes_the_duel_rng(t)
	_test_the_chooser_is_asked_nothing(t)
	_test_only_the_chosen_card_is_revealed(t)
	_test_a_random_pick_moves_nothing(t)
	_test_can_be_special_summoned_now(t)
	_test_the_control_limit_is_part_of_the_question(t)
	_test_the_summonable_hand_list(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _find_in_zones(view: Dictionary, owner: int, zone_key: String,
		card_id: int):
	for entry in view["players"][owner][zone_key]:
		if entry != null and int(entry.get("id", -1)) == card_id:
			return entry
	return null


## Every string that appears anywhere in a nested structure. Used to prove a name never
## leaks through some field nobody thought to check.
static func _collect_strings(value, out: Array) -> void:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(str(value))
		TYPE_DICTIONARY:
			for k in value.keys():
				_collect_strings(value[k], out)
		TYPE_ARRAY:
			for v in value:
				_collect_strings(v, out)
		_:
			pass


# ---------------------------------------------------------------------------
# Hands
# ---------------------------------------------------------------------------

static func _test_hand_contents_are_private_to_their_owner(t: TestCase) -> void:
	t.start("neither player can see the other's hand")
	var d := TestFixtures.new_duel(1001, 0)
	var engine: DuelEngine = d["engine"]
	var secret0 := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Player Zero Secret", 4, 1000, 1000))
	var secret1 := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Player One Secret", 4, 1000, 1000))

	var view0 := engine.get_visible_state(0)
	var view1 := engine.get_visible_state(1)

	var own0 = _find_in_zones(view0, 0, "hand", secret0.id)
	t.not_null(own0, "player 0 sees a card in their own hand")
	t.is_true(own0 != null and str(own0.get("name", "")) == "Player Zero Secret",
		"and knows what it is")

	var theirs0 = _find_in_zones(view0, 1, "hand", secret1.id)
	t.not_null(theirs0, "player 0 can see that the opponent HAS the card")
	t.is_true(theirs0 != null and theirs0.get("name") == null,
		"but not what it is [S1 p.50]")
	t.is_true(theirs0 != null and bool(theirs0.get("hidden", false)),
		"and it is explicitly marked hidden")

	# The same protection in the other direction.
	var theirs1 = _find_in_zones(view1, 0, "hand", secret0.id)
	t.is_true(theirs1 != null and theirs1.get("name") == null,
		"player 1 cannot see player 0's hand either")
	var own1 = _find_in_zones(view1, 1, "hand", secret1.id)
	t.is_true(own1 != null and str(own1.get("name", "")) == "Player One Secret",
		"but does see their own")


static func _test_face_down_card_identities_are_hidden(t: TestCase) -> void:
	t.start("the identity of a face-down card on the field is hidden from the opponent")
	var d := TestFixtures.new_duel(1002, 0)
	var engine: DuelEngine = d["engine"]
	var set_monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden Monster", 4, 1234, 4321),
		Enums.Position.FACE_DOWN_DEFENSE)
	var set_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Hidden Trap"), 0)

	var view0 := engine.get_visible_state(0)
	var monster_entry = view0["players"][1]["monster_zones"][set_monster.zone_index]
	t.not_null(monster_entry, "the opponent knows a monster occupies the zone")
	t.is_true(monster_entry != null and monster_entry.get("name") == null,
		"but not which monster it is [S1 p.50]")
	t.is_true(monster_entry != null
		and monster_entry.get("position") == Enums.Position.FACE_DOWN_DEFENSE,
		"the battle position of a Set card is public")
	t.is_false(monster_entry != null and monster_entry.has("atk"),
		"its ATK is not exposed")
	t.is_false(monster_entry != null and monster_entry.has("level"),
		"nor its Level")

	var trap_entry = view0["players"][1]["spell_trap_zones"][set_trap.zone_index]
	t.is_true(trap_entry != null and trap_entry.get("name") == null,
		"a Set Spell/Trap is hidden too")

	# Its controller of course sees both.
	var view1 := engine.get_visible_state(1)
	var own = view1["players"][1]["monster_zones"][set_monster.zone_index]
	t.is_true(own != null and str(own.get("name", "")) == "Hidden Monster",
		"the controller sees their own face-down monster")
	t.is_true(own != null and int(own.get("atk", -1)) == 1234,
		"including its stats")

	# Flipping it face-up makes it public.
	engine.state.set_battle_position(set_monster, Enums.Position.FACE_UP_DEFENSE, true)
	var after := engine.get_visible_state(0)
	var flipped = after["players"][1]["monster_zones"][set_monster.zone_index]
	t.is_true(flipped != null and str(flipped.get("name", "")) == "Hidden Monster",
		"once face-up it becomes public")


static func _test_deck_contents_and_order_are_never_exposed(t: TestCase) -> void:
	t.start("Deck contents and order are exposed to nobody, not even their owner")
	var d := TestFixtures.new_duel(1003, 0)
	var engine: DuelEngine = d["engine"]

	for viewer in [0, 1]:
		var view := engine.get_visible_state(viewer)
		for owner in [0, 1]:
			var p: Dictionary = view["players"][owner]
			t.is_false(p.has("deck"),
				"player %d is given no Deck list for player %d [S1 p.50]"
					% [viewer, owner])
			t.is_true(p.has("deck_count"),
				"only the Deck count, which is public")

	# Nothing in the whole view names a card that is sitting in a Deck.
	var deck_names := {}
	for card in engine.state.player(1).deck:
		deck_names[card.card_name()] = true
	var strings: Array = []
	_collect_strings(engine.get_visible_state(0), strings)
	var leaked := 0
	for s in strings:
		if deck_names.has(s):
			leaked += 1
	t.eq(leaked, 0, "no card name from the opponent's Deck appears anywhere in the view")


# ---------------------------------------------------------------------------
# Public information
# ---------------------------------------------------------------------------

static func _test_public_information_is_visible_to_both(t: TestCase) -> void:
	t.start("face-up field, Graveyards and face-up banished cards are public")
	var d := TestFixtures.new_duel(1004, 0)
	var engine: DuelEngine = d["engine"]
	var face_up := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Open Monster", 4, 1600, 1200))
	var buried := TestFixtures.give(engine, 1,
		TestFixtures.monster("Buried Monster", 4, 900, 900), Enums.Zone.GRAVEYARD)
	var banished := TestFixtures.give(engine, 1,
		TestFixtures.monster("Banished Monster", 4, 700, 700), Enums.Zone.BANISHED)

	for viewer in [0, 1]:
		var view := engine.get_visible_state(viewer)
		var on_field = view["players"][1]["monster_zones"][face_up.zone_index]
		t.is_true(on_field != null and str(on_field.get("name", "")) == "Open Monster",
			"player %d sees the face-up monster [S1 p.50]" % viewer)
		t.is_true(on_field != null and int(on_field.get("atk", -1)) == 1600,
			"including its current ATK")

		var gy = _find_in_zones(view, 1, "graveyard", buried.id)
		t.is_true(gy != null and str(gy.get("name", "")) == "Buried Monster",
			"player %d sees the Graveyard contents [S1 p.50]" % viewer)

		var out = _find_in_zones(view, 1, "banished", banished.id)
		t.is_true(out != null and str(out.get("name", "")) == "Banished Monster",
			"player %d sees face-up banished cards [S1 p.50]" % viewer)

		t.eq(int(view["players"][0]["life_points"]), 8000,
			"player %d sees player 0's Life Points" % viewer)
		t.eq(int(view["players"][1]["life_points"]), 8000,
			"player %d sees player 1's Life Points" % viewer)


static func _test_counts_are_public(t: TestCase) -> void:
	t.start("hand, Deck, Graveyard and banished counts are public")
	var d := TestFixtures.new_duel(1005, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_to_hand(engine, 1, TestFixtures.monster("Extra Card"))
	TestFixtures.give(engine, 1, TestFixtures.monster("Dead Card"), Enums.Zone.GRAVEYARD)

	var state := engine.state
	var view0 := engine.get_visible_state(0)
	var opponent: Dictionary = view0["players"][1]
	t.eq(int(opponent["hand_count"]), state.player(1).hand.size(),
		"the opponent's hand COUNT is public even though its contents are not")
	t.eq(int(opponent["deck_count"]), state.player(1).deck.size(),
		"as is their Deck count")
	t.eq(int(opponent["graveyard_count"]), state.player(1).graveyard.size(),
		"and their Graveyard count")
	t.eq(int(opponent["banished_count"]), state.player(1).banished.size(),
		"and their banished count")
	t.eq(int(opponent["normal_summons_used"]),
		state.player(1).normal_summons_used,
		"the Normal Summon allowance is public information too")

	# The count must reflect the hidden cards, or hiding them would be pointless.
	t.eq(view0["players"][1]["hand"].size(), state.player(1).hand.size(),
		"one hidden stub is present per card in the opponent's hand")


static func _test_revealed_cards_become_visible_to_the_player_who_saw_them(
		t: TestCase) -> void:
	t.start("a card revealed to a player stays visible to that player only")
	var d := TestFixtures.new_duel(1006, 0)
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Shown Card", 4, 1000, 1000))

	var before = _find_in_zones(engine.get_visible_state(0), 1, "hand", card.id)
	t.is_true(before != null and before.get("name") == null,
		"hidden before it is revealed")

	# The engine's record of who has legally seen this card.
	card.revealed_to.append(0)
	var after = _find_in_zones(engine.get_visible_state(0), 1, "hand", card.id)
	t.is_true(after != null and str(after.get("name", "")) == "Shown Card",
		"a player it was revealed to now sees it (master prompt 40)")

	# A second face-down card the same player was NOT shown stays hidden, so the
	# revelation is per card and not a blanket unlock of the zone.
	var other := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Still Secret", 4, 1000, 1000))
	var other_view = _find_in_zones(engine.get_visible_state(0), 1, "hand", other.id)
	t.is_true(other_view != null and other_view.get("name") == null,
		"revealing one card does not reveal the rest of the hand")


static func _test_private_events_are_filtered_from_the_public_log(t: TestCase) -> void:
	t.start("private events are kept out of the public log")
	var d := TestFixtures.new_duel(1007, 0)
	var engine: DuelEngine = d["engine"]

	var draws := TestFixtures.events_of(engine, GameEvent.Kind.CARD_DRAWN)
	t.is_true(draws.size() >= 10, "the opening hands were drawn")
	var private_draws := draws.filter(func(e): return not e.is_public())
	t.eq(private_draws.size(), draws.size(),
		"every draw is private: which card you drew is not public [S1 p.50]")

	var public_log := engine.get_public_log()
	var public_draws := public_log.filter(
		func(e): return e.kind == GameEvent.Kind.CARD_DRAWN)
	t.eq(public_draws.size(), 0, "no draw event appears in the public log")

	var log0 := engine.state.get_log_for(0)
	# A single-line lambda ends at the newline, so a wrapped body needs an explicit
	# line continuation.
	var own_draws := log0.filter(
		func(e): return e.kind == GameEvent.Kind.CARD_DRAWN \
			and int(e.data.get("player", -1)) == 0)
	t.is_true(own_draws.size() >= 5, "a player's own draws appear in their own log")
	var their_draws := log0.filter(
		func(e): return e.kind == GameEvent.Kind.CARD_DRAWN \
			and int(e.data.get("player", -1)) == 1)
	t.eq(their_draws.size(), 0, "but the opponent's draws do not")

	# The duel start itself is public, so the filter is not simply hiding everything.
	t.is_true(public_log.filter(
		func(e): return e.kind == GameEvent.Kind.DUEL_STARTED).size() == 1,
		"public events are still in the public log")


static func _test_chain_information_is_public(t: TestCase) -> void:
	t.start("a Chain being built is public information to both players")
	var d := TestFixtures.new_duel(1008, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var order: Array = []
	var spell_def := TestFixtures.spell("Public Spell", Enums.STKind.NORMAL_SPELL)
	TestFixtures.with_effect(spell_def, TestFixtures.card_activation("activate",
		Enums.SpellSpeed.SS1, order, "spell"))
	var spell := TestFixtures.give_to_hand(engine, 0, spell_def)

	# A Spell Speed 2 responder on the other side keeps the Chain open for inspection.
	var trap_def := TestFixtures.trap("Public Trap", Enums.STKind.NORMAL_TRAP)
	TestFixtures.with_effect(trap_def, TestFixtures.card_activation("activate",
		Enums.SpellSpeed.SS2, order, "trap"))
	TestFixtures.give_set_spell_trap(engine, 1, trap_def, 0)

	engine.submit_action(TestFixtures.find_action(
		engine.get_legal_actions(0), Enums.ActionKind.ACTIVATE_CARD, spell.id))
	t.eq(engine.waiting_player(), 1, "the opponent holds a response window")

	for viewer in [0, 1]:
		var chain: Array = engine.get_visible_state(viewer)["chain"]
		t.eq(chain.size(), 1, "player %d sees one Chain Link" % viewer)
		t.is_true(chain.size() == 1 and str(chain[0].get("card_name", "")) == "Public Spell",
			"and knows which card it is: an activated card is face-up [S1 p.28]")
		t.is_true(chain.size() == 1 and int(chain[0].get("link_number", -1)) == 1,
			"with its link number")

	TestFixtures.pass_until_open(engine)
	t.eq(engine.get_visible_state(1)["chain"].size(), 0,
		"and the Chain is empty again once it has resolved")


# ---------------------------------------------------------------------------
# Owner vs controller. RULES_SPEC.md 9 [S1 p.52]
# ---------------------------------------------------------------------------

static func _test_owner_is_reported_separately_from_controller(t: TestCase) -> void:
	t.start("owner and controller are reported as separate facts and never conflated")
	var d := TestFixtures.new_duel(1009, 0)
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Borrowable", 4, 1500, 1000))
	t.eq(card.owner_id, 1, "the card is owned by player 1")
	t.eq(card.controller_id, 1, "and controlled by player 1")

	# Control changes; ownership does not. [S1 p.52]
	engine.state.move_card(card, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.RULE,
		{"to_player": 0, "position": Enums.Position.FACE_UP_ATTACK})
	t.eq(card.controller_id, 0, "control passed to player 0")
	t.eq(card.owner_id, 1, "but the owner never changes [S1 p.52]")

	var entry = engine.get_visible_state(0)["players"][0]["monster_zones"][card.zone_index]
	t.not_null(entry, "the card now shows on player 0's side of the field")
	t.is_true(entry != null and int(entry.get("controller", -1)) == 0,
		"the view reports the controller")
	t.is_true(entry != null and int(entry.get("owner", -1)) == 1,
		"and the owner, as a separate field")

	# When it leaves the field it goes to its OWNER's Graveyard, not its controller's.
	engine.state.move_card(card, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_BATTLE)
	t.is_true(engine.state.player(1).graveyard.has(card),
		"it went to the owner's Graveyard [S1 p.52]")
	t.is_false(engine.state.player(0).graveyard.has(card),
		"and not to the controller's")
	t.eq(card.controller_id, 1,
		"control reverts to the owner once the card is in an owner-bound zone")


static func _test_no_hidden_field_leaks_the_card_name(t: TestCase) -> void:
	t.start("no field of a hidden card's stub carries its name")
	var d := TestFixtures.new_duel(1010, 0)
	var engine: DuelEngine = d["engine"]
	var in_hand := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.monster("Unique Hand Name", 4, 1000, 1000))
	var face_down := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Unique Field Name", 4, 1000, 1000),
		Enums.Position.FACE_DOWN_DEFENSE)

	var strings: Array = []
	_collect_strings(engine.get_visible_state(0), strings)
	t.is_false(strings.has("Unique Hand Name"),
		"the opponent's hand card name appears nowhere in the whole view")
	t.is_false(strings.has("Unique Field Name"),
		"nor does a face-down field card's name")

	# The same view from the controller's side proves the names exist to be leaked, so
	# the assertions above are not passing because the cards are simply missing.
	var own_strings: Array = []
	_collect_strings(engine.get_visible_state(1), own_strings)
	t.is_true(own_strings.has("Unique Hand Name"),
		"the controller does see their own hand card")
	t.is_true(own_strings.has("Unique Field Name"),
		"and their own face-down monster")
	t.eq(in_hand.owner_id, 1, "both cards belong to player 1")
	t.eq(face_down.owner_id, 1, "both cards belong to player 1")


# ---------------------------------------------------------------------------
# Looking at a hidden zone — the gate for `EffectPrimitives.look_at_hand()`.
# RULES_SPEC.md 12, CARD_RULINGS.md R42 Part B.
#
# Written and passing BEFORE `Spiritual Water Art - Aoi` existed, the way the batch-7
# movement gate and the batch-6 control gate were. These tests belong here rather than in
# a new suite because "look at a hand" is an OPERATION over the hidden-information
# subsystem this file already owns, not a subsystem of its own — the batch-11 attack ban
# went into `AttackRestrictionTests` for the same reason.
#
# The four things that make it a distinct operation, each asserted below:
#   1. it reveals to ONE player, not to both;
#   2. it moves nothing;
#   3. the knowledge SURVIVES, because §12.1 ends `revealed_to` only at a shuffle;
#   4. it is not a REVEAL that the opponent's own log gets to see.
# ---------------------------------------------------------------------------


## A minimal EffectContext for calling a primitive directly, with `pid` as the controller.
static func _ctx(engine: DuelEngine, pid: int, source: CardInstance) -> EffectContext:
	var ctx := EffectContext.new(engine.state, source)
	ctx.engine = engine
	ctx.controller_id = pid
	return ctx


static func _test_looking_at_a_hand_reveals_it_to_one_player_only(t: TestCase) -> void:
	t.start("look_at_hand(): every card in the target's hand becomes visible to the looker "
		+ "and to NOBODY else")
	var d := TestFixtures.new_duel(1011, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Looking Trap"))
	var theirs: Array = engine.state.player(1).hand.duplicate()
	t.is_true(theirs.size() >= 5, "the opponent has an opening hand to look at")

	# Before: the looker sees nothing of it.
	for entry in theirs:
		var card: CardInstance = entry
		t.is_false(card.revealed_to.has(0), "hidden from the looker before the look")

	var seen := EffectPrimitives.look_at_hand(_ctx(engine, 0, source), 1)
	t.eq(seen.size(), theirs.size(), "every card in the hand was looked at")

	for entry in theirs:
		var card: CardInstance = entry
		t.is_true(card.revealed_to.has(0), "the looker has now legally seen it")
		t.is_false(card.revealed_to.has(1),
			"and the reveal did not additionally reveal it to its own owner as a NEW fact")

	# The looker's filtered view really names them; the owner's view of the LOOKER's hand
	# is unchanged, so this is not a blanket unlock of both hands.
	var view0 := engine.get_visible_state(0)
	var named := 0
	for entry in view0["players"][1]["hand"]:
		if entry != null and entry.get("name") != null:
			named += 1
	t.eq(named, theirs.size(), "the looker's view names the whole opponent hand")

	var view1 := engine.get_visible_state(1)
	var leaked := 0
	for entry in view1["players"][0]["hand"]:
		if entry != null and entry.get("name") != null:
			leaked += 1
	t.eq(leaked, 0, "while the opponent still sees nothing of the LOOKER's hand")


static func _test_looking_at_a_hand_moves_nothing(t: TestCase) -> void:
	t.start("look_at_hand(): nothing leaves the hand, nothing is turned face-up, and no "
		+ "card moves at all")
	var d := TestFixtures.new_duel(1012, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Looking Trap"))
	var before_size: int = engine.state.player(1).hand.size()
	var before_gy: int = engine.state.player(1).graveyard.size()
	var sample: CardInstance = engine.state.player(1).hand[0]
	var before_position := sample.position

	EffectPrimitives.look_at_hand(_ctx(engine, 0, source), 1)

	t.eq(engine.state.player(1).hand.size(), before_size, "the hand is the same size")
	t.eq(engine.state.player(1).graveyard.size(), before_gy, "the Graveyard did not grow")
	t.eq(sample.zone, Enums.Zone.HAND, "the card is still in the hand")
	t.eq(sample.position, before_position, "and was not turned face-up")


static func _test_looking_at_an_empty_hand_is_legal_and_sees_nothing(t: TestCase) -> void:
	t.start("look_at_hand(): an EMPTY hand is a legal thing to look at — it returns nothing "
		+ "rather than failing, and the caller decides what that means")
	var d := TestFixtures.new_duel(1013, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Looking Trap"))
	engine.state.player(1).hand.clear()

	var seen := EffectPrimitives.look_at_hand(_ctx(engine, 0, source), 1)
	t.eq(seen.size(), 0, "nothing was seen")
	t.eq(engine.state.player(1).hand.size(), 0, "and the hand is still empty")


static func _test_the_knowledge_survives_the_look(t: TestCase) -> void:
	t.start("§12.1: knowledge gained by looking is ended only by a SHUFFLE, and a hand is "
		+ "never shuffled — so a card looked at and kept stays known")
	var d := TestFixtures.new_duel(1014, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Looking Trap"))
	var kept: CardInstance = engine.state.player(1).hand[0]

	EffectPrimitives.look_at_hand(_ctx(engine, 0, source), 1)
	t.is_true(kept.revealed_to.has(0), "it was seen")

	# Several turns' worth of unrelated engine work later, it is still known.
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.is_true(kept.revealed_to.has(0),
		"and it is still known two turns later — there is no `forget`, deliberately")
	t.eq(kept.zone, Enums.Zone.HAND, "with the card still in the hand")

	# The one thing that DOES end it, asserted as the control: a shuffle of the zone the
	# card is in. Moving it into the Deck and shuffling clears the record.
	engine.state.move_card(kept, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK,
		{"to_player": 1})
	t.is_false(kept.revealed_to.has(0),
		"a shuffle into the Deck is what ends the knowledge, and it does")


static func _test_a_look_does_not_leak_into_the_public_log(t: TestCase) -> void:
	t.start("a look at one player's hand is PRIVATE: the reveal events it raises are kept "
		+ "out of the public log and out of the looked-at player's own log")
	var d := TestFixtures.new_duel(1015, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Looking Trap"))
	var mark: int = engine.state.events.size()

	EffectPrimitives.look_at_hand(_ctx(engine, 0, source), 1)

	var reveals := TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED, mark)
	t.is_true(reveals.size() >= 5, "the look really raised reveal events")
	var public_reveals := reveals.filter(func(e): return e.is_public())
	t.eq(public_reveals.size(), 0,
		"not one of them is public — a look is not a reveal to the table")

	var public_log := engine.get_public_log()
	var public_after := public_log.filter(
		func(e): return e.kind == GameEvent.Kind.CARD_REVEALED)
	t.eq(public_after.size(), 0, "and none reaches the public log")

	var log0 := engine.state.get_log_for(0)
	var mine := log0.filter(func(e): return e.kind == GameEvent.Kind.CARD_REVEALED)
	t.is_true(mine.size() >= 5, "the LOOKER's own log carries what they were shown")


static func _test_sending_from_a_hand_is_not_a_discard(t: TestCase) -> void:
	t.start("send_from_hand_to_gy(): the opponent's card reaches the Graveyard as a SEND "
		+ "BY EFFECT, never as a discard [S1 p.52-53]")
	var d := TestFixtures.new_duel(1016, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Sending Trap"))
	var victim: CardInstance = engine.state.player(1).hand[0]
	var gy_before: int = engine.state.player(1).graveyard.size()

	t.is_true(EffectPrimitives.send_from_hand_to_gy(_ctx(engine, 0, source), victim),
		"the card is sent")
	t.eq(victim.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(engine.state.player(1).graveyard.size(), gy_before + 1,
		"and specifically in its OWNER's Graveyard")
	t.eq(victim.last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"with the SEND reason")
	t.ne(victim.last_move_reason, Enums.MoveReason.DISCARDED,
		"and emphatically not the DISCARD reason — the two are different things")

	# A card that is no longer in a hand is refused rather than chased into its new zone.
	t.is_false(EffectPrimitives.send_from_hand_to_gy(_ctx(engine, 0, source), victim),
		"sending the same card again does nothing")
	t.is_false(EffectPrimitives.send_from_hand_to_gy(_ctx(engine, 0, source), null),
		"and null is refused rather than crashing")



# ---------------------------------------------------------------------------
# A RANDOM choice made by the OTHER player, out of a hidden hand — the gate for
# `EffectPrimitives.random_hand_card_chosen_by()` and for the "can this be Special
# Summoned right now?" question that goes with it.
# RULES_SPEC.md 12.3, CARD_RULINGS.md R15.
#
# Written and passing BEFORE `A Hero Emerges` existed, the way the batch-12 `look_at_hand`
# gate above it, the batch-7 movement gate and the batch-6 control gate were. It belongs in
# this file for the same reason the look gate does: a random pick out of a hidden hand is an
# OPERATION over the hidden-information subsystem this file already owns, plus the seeded
# `Rng` that `ReplayTests` already owns. Neither is a new subsystem, and splitting one
# primitive's gate across two suites would leave both halves incomplete.
#
# The four things that make it a distinct operation, each asserted below:
#   1. the pick comes from the SEEDED `Rng` — same seed, same card, every time;
#   2. the chooser is asked NOTHING, so a hidden hand is never handed to them as options;
#   3. exactly ONE card is revealed, to BOTH players, and the rest of the hand stays hidden;
#   4. it moves nothing — the caller's own text decides where the chosen card goes.
# ---------------------------------------------------------------------------


## A hand of exactly `names` for player `pid`, replacing whatever was dealt.
static func _stack_hand(engine: DuelEngine, pid: int, names: Array) -> Array:
	engine.state.player(pid).hand.clear()
	var out: Array = []
	for n in names:
		out.append(TestFixtures.give_to_hand(engine, pid,
			TestFixtures.monster(str(n), 4, 1000, 1000)))
	return out


static func _test_a_random_pick_is_seeded_and_repeatable(t: TestCase) -> void:
	t.start("random_hand_card_chosen_by(): the SEEDED Rng decides, so the same seed and the "
		+ "same hand produce the same card every time — which is what makes it replayable")
	var picks: Array = []
	for run in range(3):
		var d := TestFixtures.new_duel(1021, 0)
		var engine: DuelEngine = d["engine"]
		var source := TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.trap("Picking Trap"))
		_stack_hand(engine, 1, ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])
		var chosen := EffectPrimitives.random_hand_card_chosen_by(_ctx(engine, 0, source),
			0, 1)
		t.not_null(chosen, "a card was chosen (run %d)" % run)
		picks.append("" if chosen == null else chosen.card_name())
	t.eq(picks[1], picks[0], "the second run picked the same card as the first")
	t.eq(picks[2], picks[0], "and so did the third")

	# A DIFFERENT seed must be able to reach a different card, or "deterministic" would be
	# indistinguishable from "always returns hand[0]" — which is the mutation this catches.
	var seen := {}
	for seed_value in range(2000, 2064):
		var d2 := TestFixtures.new_duel(seed_value, 0)
		var engine2: DuelEngine = d2["engine"]
		var src2 := TestFixtures.give_set_spell_trap(engine2, 0,
			TestFixtures.trap("Picking Trap"))
		_stack_hand(engine2, 1, ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])
		var c2 := EffectPrimitives.random_hand_card_chosen_by(_ctx(engine2, 0, src2), 0, 1)
		if c2 != null:
			seen[c2.card_name()] = true
	t.eq(seen.size(), 5,
		"across 64 seeds every one of the five hand cards is reachable — the pick is really "
		+ "uniform over the hand and not a fixed index")


static func _test_a_random_pick_consumes_the_duel_rng(t: TestCase) -> void:
	t.start("random_hand_card_chosen_by(): the draw goes through GameState.rng and is "
		+ "COUNTED, so a replay that diverges is visible in the call count")
	var d := TestFixtures.new_duel(1022, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Picking Trap"))
	_stack_hand(engine, 1, ["Alpha", "Beta", "Gamma"])
	var before: int = engine.state.rng.get_call_count()

	EffectPrimitives.random_hand_card_chosen_by(_ctx(engine, 0, source), 0, 1)
	t.eq(engine.state.rng.get_call_count(), before + 1,
		"exactly one value was drawn from the duel's own generator")

	# And an empty hand draws nothing at all, so a no-op cannot desynchronise a replay.
	engine.state.player(1).hand.clear()
	var after_empty: int = engine.state.rng.get_call_count()
	t.is_null(EffectPrimitives.random_hand_card_chosen_by(_ctx(engine, 0, source), 0, 1),
		"an empty hand yields no card")
	t.eq(engine.state.rng.get_call_count(), after_empty,
		"and consumes no random value")


static func _test_the_chooser_is_asked_nothing(t: TestCase) -> void:
	t.start("random_hand_card_chosen_by(): 'your opponent chooses' is agency WITHOUT "
		+ "information — the chooser's controller is asked no question at all")
	var d := TestFixtures.new_duel(1023, 0)
	var engine: DuelEngine = d["engine"]
	var chooser: ScriptedController = d["p0"]
	var owner: ScriptedController = d["p1"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Picking Trap"))
	_stack_hand(engine, 1, ["Alpha", "Beta", "Gamma"])
	var ctx := _ctx(engine, 0, source)
	ctx.decider = chooser

	var chosen := EffectPrimitives.random_hand_card_chosen_by(ctx, 0, 1)
	t.not_null(chosen, "a card was chosen")
	t.eq(chooser.seen_requests.size(), 0,
		"the chooser was never handed a decision — a SELECT request here would have listed "
		+ "the contents of a hidden hand")
	t.eq(owner.seen_requests.size(), 0, "and neither was the hand's owner")


static func _test_only_the_chosen_card_is_revealed(t: TestCase) -> void:
	t.start("random_hand_card_chosen_by(): exactly ONE card becomes known, to BOTH players; "
		+ "the rest of the hand is as hidden afterwards as it was before")
	var d := TestFixtures.new_duel(1024, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Picking Trap"))
	var hand := _stack_hand(engine, 1, ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])
	var mark: int = engine.state.events.size()

	var chosen := EffectPrimitives.random_hand_card_chosen_by(_ctx(engine, 0, source), 0, 1)
	t.not_null(chosen, "a card was chosen")
	t.is_true(chosen.revealed_to.has(0) and chosen.revealed_to.has(1),
		"the chosen card is known to both players")

	var unrevealed := 0
	for entry in hand:
		var card: CardInstance = entry
		if card == chosen:
			continue
		t.is_false(card.revealed_to.has(0),
			"%s was NOT shown to the chooser" % card.card_name())
		unrevealed += 1
	t.eq(unrevealed, hand.size() - 1, "four of the five cards stayed hidden")

	# One reveal event, and it is PUBLIC — the opposite of a look, which is private.
	var reveals := TestFixtures.events_of(engine, GameEvent.Kind.CARD_REVEALED, mark)
	t.eq(reveals.size(), 1, "exactly one reveal event was raised")
	t.is_true(reveals[0].is_public(),
		"and it is public — both players may see which card was chosen")

	# The filtered view is the real test of a leak: the chooser's own view must name the
	# chosen card and nothing else out of that hand.
	var view0 := engine.get_visible_state(0)
	var named: Array = []
	for entry in view0["players"][1]["hand"]:
		if entry != null and entry.get("name") != null:
			named.append(str(entry["name"]))
	t.eq(named, [chosen.card_name()],
		"the chooser's filtered view names the chosen card and no other hand card")


static func _test_a_random_pick_moves_nothing(t: TestCase) -> void:
	t.start("random_hand_card_chosen_by(): choosing is not moving — the card is still in "
		+ "the hand afterwards, and the caller's own text decides where it goes")
	var d := TestFixtures.new_duel(1025, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Picking Trap"))
	_stack_hand(engine, 1, ["Alpha", "Beta", "Gamma"])
	var before_hand: int = engine.state.player(1).hand.size()
	var before_gy: int = engine.state.player(1).graveyard.size()

	var chosen := EffectPrimitives.random_hand_card_chosen_by(_ctx(engine, 0, source), 0, 1)
	t.not_null(chosen, "a card was chosen")
	t.eq(chosen.zone, Enums.Zone.HAND, "it is still in the hand")
	t.eq(engine.state.player(1).hand.size(), before_hand, "the hand is the same size")
	t.eq(engine.state.player(1).graveyard.size(), before_gy, "and the Graveyard did not grow")


static func _test_can_be_special_summoned_now(t: TestCase) -> void:
	t.start("can_be_special_summoned_now(): 'a monster that can be Special Summoned' is a "
		+ "question about THIS moment, and it refuses for each of the reasons "
		+ "SummonRules.begin_special_summon() itself refuses")
	var d := TestFixtures.new_duel(1026, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Asking Trap"))
	var ctx := _ctx(engine, 0, source)

	var monster := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Ordinary Monster", 4, 1000, 1000))
	var spell := TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Ordinary Spell"))
	var trap_card := TestFixtures.give_to_hand(engine, 0, TestFixtures.trap("Ordinary Trap"))

	t.is_true(EffectPrimitives.can_be_special_summoned_now(ctx, monster),
		"an ordinary monster with room on the field can be")
	t.is_false(EffectPrimitives.can_be_special_summoned_now(ctx, spell),
		"a Spell cannot — it is not a monster")
	t.is_false(EffectPrimitives.can_be_special_summoned_now(ctx, trap_card),
		"and neither can a Trap")
	t.is_false(EffectPrimitives.can_be_special_summoned_now(ctx, null),
		"null is refused rather than crashing")

	# A FULL Monster Zone is the pool's live reason for the answer to flip.
	for i in range(PlayerState.MONSTER_ZONE_COUNT):
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Blocker %d" % i, 4, 100, 100))
	t.is_false(engine.state.player(0).has_free_monster_zone(), "the Monster Zone is full")
	t.is_false(EffectPrimitives.can_be_special_summoned_now(ctx, monster),
		"the same monster can no longer be Special Summoned — the question is about NOW")


static func _test_the_control_limit_is_part_of_the_question(t: TestCase) -> void:
	t.start("can_be_special_summoned_now(): 'You can only control 1 …' makes a monster "
		+ "unsummonable while a copy is already on the field, and summonable again after it "
		+ "leaves")
	var d := TestFixtures.new_duel(1027, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Asking Trap"))
	var ctx := _ctx(engine, 0, source)

	# "You can only control 1 …" as the rules layer really asks it: a CONTINUOUS clause
	# under `SummonRules.CONTROL_LIMIT_EFFECT_ID` that answers a question and applies
	# nothing — the same shape `Inari Fire` and `Castle of Dragon Souls` print.
	var limit_clause := EffectDef.new(SummonRules.CONTROL_LIMIT_EFFECT_ID,
		"Test: You can only control 1 \"Only One Of These\".")
	limit_clause.of_type(Enums.EffectType.CONTINUOUS)
	limit_clause.condition = func(c: EffectContext) -> bool:
		return EffectPrimitives.controls_no_other_copy(c)
	var limited := TestFixtures.with_effect(
		TestFixtures.monster("Only One Of These", 4, 1000, 1000), limit_clause)
	var in_hand := TestFixtures.give_to_hand(engine, 0, limited)
	t.is_true(EffectPrimitives.can_be_special_summoned_now(ctx, in_hand),
		"with no copy on the field it can be Special Summoned")

	var on_field := TestFixtures.give_monster_on_field(engine, 0, limited)
	t.is_false(EffectPrimitives.can_be_special_summoned_now(ctx, in_hand),
		"a copy on the field makes the hand copy unsummonable")

	engine.state.move_card(on_field, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {})
	t.is_true(EffectPrimitives.can_be_special_summoned_now(ctx, in_hand),
		"and it is summonable again once the copy has left the field")


static func _test_the_summonable_hand_list(t: TestCase) -> void:
	t.start("hand_monsters_that_could_be_special_summoned(): the list an activation "
		+ "requirement and a resolution-time re-check BOTH read, so the two cannot drift")
	var d := TestFixtures.new_duel(1028, 0)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("Asking Trap"))
	var ctx := _ctx(engine, 0, source)
	engine.state.player(0).hand.clear()

	t.eq(EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx, 0).size(), 0,
		"an empty hand offers nothing")

	TestFixtures.give_to_hand(engine, 0, TestFixtures.spell("Only A Spell"))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.trap("Only A Trap"))
	t.eq(EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx, 0).size(), 0,
		"a hand of Spells and Traps offers nothing either")

	var m := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("The One Monster", 4, 1000, 1000))
	var found := EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx, 0)
	t.eq(found.size(), 1, "one monster in the hand is one candidate")
	t.eq(found[0], m, "and it is that monster")

	# It reads the named player's hand, not the controller's, so a clause aimed at the
	# other side cannot silently answer about the wrong one.
	t.eq(EffectPrimitives.hand_monsters_that_could_be_special_summoned(ctx, 1).size(),
		engine.state.player(1).hand.size(),
		"asked about the opponent, it answers about the OPPONENT's hand")

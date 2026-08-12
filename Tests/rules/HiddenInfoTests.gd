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

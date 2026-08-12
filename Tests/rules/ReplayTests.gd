class_name ReplayTests
extends RefCounted

## The DuelLog replay payload. Master prompt 8 / 70.
##
## The claim `DuelLog` makes is specific: a duel is deterministic given
## (Decks, RNG seed, player inputs), so the payload is enough to reproduce it exactly.
## Until this suite existed that claim was untested, and it was false in two ways —
## the payload carried the Deck NAMES but not the Deck CONTENTS, and the only decision
## being recorded was target selection, so optional triggers, trigger ordering, the
## hand-size discard and mid-resolution choices were all lost.
##
## The test that matters here is the round trip: replay the payload into a fresh engine
## and require the resulting event stream to be identical, event for event.


## Answers a replayed duel from the decisions the payload recorded, in order.
## A wrong or missing answer is recorded as an error rather than silently defaulted —
## a replay that quietly diverges would defeat the point of the payload.
class ReplayController extends PlayerController:
	var queue: Array = []
	var errors: Array = []
	var answered: int = 0

	func _init(p_player_id: int, p_answers: Array) -> void:
		super(p_player_id, "Replay %d" % p_player_id)
		queue = p_answers.duplicate(true)

	func decide(request: DecisionRequest):
		while not queue.is_empty():
			var head: Dictionary = queue.pop_front()
			if int(head["request"].get("player", -1)) != player_id:
				continue
			answered += 1
			return head["answer"]
		errors.append("replay ran out of recorded decisions for player %d" % player_id)
		return null


static func run() -> TestCase:
	var t := TestCase.new("ReplayTests")
	_test_payload_records_the_inputs(t)
	_test_payload_carries_the_deck_contents(t)
	_test_every_decision_is_recorded(t)
	_test_replay_reproduces_the_duel(t)
	_test_replayed_actions_are_revalidated(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A short, deterministic duel that exercises several action kinds.
static func _play_a_short_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var hand: Array = engine.state.player(0).hand
	var first: CardInstance = hand[0]
	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, first.id))
	TestFixtures.pass_until_open(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	return d


## Rebuild the Deck CardDefs a payload names. The suite's decks are built from uniquely
## named filler monsters, so a name identifies a definition exactly.
static func _defs_from_names(names: Array, catalogue: Dictionary) -> Array:
	var out: Array = []
	for n in names:
		out.append(catalogue[str(n)])
	return out


static func _catalogue(decks: Array) -> Dictionary:
	var out := {}
	for deck in decks:
		for def in deck:
			var card_def: CardDef = def
			out[card_def.name] = card_def
	return out


## The event stream as comparable strings: kind, turn and phase, in order.
static func _event_signature(engine: DuelEngine) -> Array:
	var out: Array = []
	for ev in engine.state.events:
		out.append("%s@T%d/%d" % [GameEvent.kind_name(ev.kind), ev.turn, ev.phase])
	return out


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _test_payload_records_the_inputs(t: TestCase) -> void:
	t.start("the replay payload records the seed, the first player and every action")
	var d := _play_a_short_duel(7101)
	var engine: DuelEngine = d["engine"]
	var payload := engine.log.to_replay()

	t.eq(int(payload["seed"]), engine.state.rng.get_seed(),
		"the payload carries the RNG seed the duel actually used")
	t.eq(int(payload["first_player"]), 0, "and who went first")
	var actions: Array = payload["actions"]
	t.is_true(actions.size() > 0, "actions were recorded")
	t.eq(actions.size(), engine.log.actions.size(),
		"the payload holds every submitted action")

	var kinds: Array = []
	for entry in actions:
		var record: Dictionary = entry
		kinds.append(str(record["action"]["kind"]))
	t.is_true(kinds.has("NORMAL_SUMMON"),
		"the Normal Summon that was submitted is in the payload")
	var first_action: Dictionary = actions[0]
	t.is_true(first_action.has("turn") and first_action.has("phase"),
		"each action records when it was taken")
	# `seq` is one counter shared by actions, decisions and events on purpose: it is what
	# lets the three streams be interleaved back into the order they really happened, so
	# the first ACTION is not seq 0 — the setup events precede it.
	t.is_true(int(actions[0]["seq"]) > 0,
		"the first action's sequence number follows the setup events")
	var all_seqs := {}
	var collisions := 0
	for stream in [payload["actions"], payload["decisions"]]:
		for entry in stream:
			var record: Dictionary = entry
			if all_seqs.has(int(record["seq"])):
				collisions += 1
			all_seqs[int(record["seq"])] = true
	t.eq(collisions, 0,
		"actions and decisions never share a sequence number, so the two streams can be "
		+ "merged back into the order they really happened")
	var seqs_ascend := true
	for i in range(1, actions.size()):
		if int(actions[i]["seq"]) <= int(actions[i - 1]["seq"]):
			seqs_ascend = false
	t.is_true(seqs_ascend, "and the recorded order is strictly increasing")


static func _test_payload_carries_the_deck_contents(t: TestCase) -> void:
	t.start("the payload carries the Deck contents, not just the Deck names")
	var deck0 := TestFixtures.filler_deck("A")
	var deck1 := TestFixtures.filler_deck("B")
	var d := TestFixtures.new_duel(7102, 0, deck0, deck1)
	var engine: DuelEngine = d["engine"]
	var payload := engine.log.to_replay()

	t.is_true(payload.has("deck_lists"),
		"the payload has a deck_lists field — the seed alone only says how a KNOWN Deck "
		+ "is shuffled, so the Deck is an input too")
	var lists: Array = payload["deck_lists"]
	t.eq(lists.size(), 2, "one list per player")
	t.eq((lists[0] as Array).size(), TestFixtures.DECK_SIZE,
		"player 0's whole Deck is recorded")
	t.eq((lists[1] as Array).size(), TestFixtures.DECK_SIZE,
		"and player 1's")
	t.eq(str((lists[0] as Array)[0]), deck0[0].name,
		"recorded in the PRE-shuffle order the seed is applied to")
	t.eq(str((lists[0] as Array)[TestFixtures.DECK_SIZE - 1]),
		deck0[TestFixtures.DECK_SIZE - 1].name, "including the last card")


static func _test_every_decision_is_recorded(t: TestCase) -> void:
	t.start("every question the engine puts to a player is recorded as an input")
	var d := TestFixtures.new_duel(7103, 0)
	var engine: DuelEngine = d["engine"]
	var c0: ScriptedController = d["p0"]
	var c1: ScriptedController = d["p1"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	# An optional Trigger Effect: its controller is asked yes/no, and that answer is an
	# input the replay cannot reconstruct on its own.
	var order_log: Array = []
	var def := TestFixtures.monster("Watcher", 4, 1000, 1000)
	TestFixtures.with_effect(def, TestFixtures.trigger_effect("watch",
		[GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED], order_log, "watch"))
	TestFixtures.give_monster_on_field(engine, 0, def)

	var summoned := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Trigger Bait", 4, 1000, 1000))
	c0.default_yes = true
	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, summoned.id))
	TestFixtures.pass_until_open(engine)

	var asked := c0.seen_requests.size() + c1.seen_requests.size()
	t.is_true(asked > 0, "the engine did ask at least one question")
	t.eq(engine.log.decisions.size(), asked,
		"the log recorded exactly as many decisions as the players were asked")
	var yes_no_recorded := 0
	for entry in engine.log.decisions:
		var record: Dictionary = entry
		if str(record["request"].get("kind", "")) == "YES_NO":
			yes_no_recorded += 1
	t.is_true(yes_no_recorded > 0,
		"the optional-trigger consent is among them (it used to be lost entirely)")
	t.eq(order_log.size(), 1, "and the effect the player consented to did resolve")


static func _test_replay_reproduces_the_duel(t: TestCase) -> void:
	t.start("replaying the payload reproduces the duel event for event")
	var deck0 := TestFixtures.filler_deck("A")
	var deck1 := TestFixtures.filler_deck("B")
	var original := TestFixtures.new_duel(7104, 0, deck0, deck1)
	var engine: DuelEngine = original["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var summon_target: CardInstance = engine.state.player(0).hand[0]
	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, summon_target.id))
	TestFixtures.pass_until_open(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)

	var payload := engine.log.to_replay()
	var expected := _event_signature(engine)

	# Rebuild from the payload alone: seed, first player and Deck lists.
	var catalogue := _catalogue([deck0, deck1])
	var lists: Array = payload["deck_lists"]
	var r0 := ReplayController.new(0, payload["decisions"])
	var r1 := ReplayController.new(1, payload["decisions"])
	var replay := DuelEngine.new(int(payload["seed"]))
	replay.setup_duel(
		[_defs_from_names(lists[0], catalogue), _defs_from_names(lists[1], catalogue)],
		[r0, r1], int(payload["first_player"]), payload["deck_names"])

	var applied := 0
	for entry in payload["actions"]:
		var record: Dictionary = entry
		var action := DuelAction.from_dict(record["action"])
		if replay.submit_action(action):
			applied += 1
	t.eq(applied, (payload["actions"] as Array).size(),
		"every recorded action was accepted by the replayed engine")
	t.is_true(r0.errors.is_empty() and r1.errors.is_empty(),
		"the recorded decisions covered every question the replay asked")

	t.eq(_event_signature(replay), expected,
		"the replayed duel produced an identical event stream")
	t.eq(replay.state.player(0).life_points, engine.state.player(0).life_points,
		"player 0 ends on the same LP")
	t.eq(replay.state.player(1).life_points, engine.state.player(1).life_points,
		"player 1 ends on the same LP")
	t.eq(replay.state.player(0).hand.size(), engine.state.player(0).hand.size(),
		"with the same hand size")
	t.eq(replay.state.player(0).monster_count(),
		engine.state.player(0).monster_count(), "and the same board")
	t.eq(replay.state.turn_number, engine.state.turn_number,
		"having reached the same turn")
	var replay_deck_top: CardInstance = replay.state.player(0).deck[0]
	var original_deck_top: CardInstance = engine.state.player(0).deck[0]
	t.eq(replay_deck_top.card_name(), original_deck_top.card_name(),
		"the same seed shuffled the same Deck the same way")


static func _test_replayed_actions_are_revalidated(t: TestCase) -> void:
	t.start("a replayed action is re-validated, so a tampered payload cannot cheat")
	var d := TestFixtures.new_duel(7105, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var mon: CardInstance = engine.state.player(0).hand[0]
	var logged_before := engine.log.actions.size()

	# Fabricate an action the rules do not allow: the opponent Normal Summoning a card
	# out of the turn player's hand.
	var forged := DuelAction.from_dict({
		"kind": "NORMAL_SUMMON", "player": 1, "card_id": mon.id, "effect_id": "",
		"target_ids": [], "tribute_ids": [], "zone_index": -1,
		"position": Enums.Position.FACE_UP_ATTACK, "attack_target_id": -1, "params": {},
	})
	t.eq(forged.kind, Enums.ActionKind.NORMAL_SUMMON,
		"from_dict rebuilds the action kind by name")
	t.eq(forged.player_id, 1, "and the player")
	t.is_false(engine.submit_action(forged),
		"the engine rejects it — a replay goes through the same legality gate")
	t.eq(mon.zone, Enums.Zone.HAND, "and nothing moved")
	t.eq(engine.log.actions.size(), logged_before,
		"a rejected action is not written to the replay log")

class_name LifetimeTests
extends RefCounted

## Object lifetime of a whole duel. The post-card phase, unit 1 (PROJECT_STATE.md §8).
##
## A duel is a tree of RefCounted objects rooted at `DuelEngine`. Every subsystem holds the
## `GameState`, and `GameState` holds every card, both players and every event, so ONE
## strong reference from a subsystem back to the engine keeps the whole tree alive for the
## rest of the process. That is what the "~187 ObjectDB instances per duel" figure carried
## from batch 15 to batch 18 was: `ChainManager.engine` pointed back at its owner.
##
## Measured before the fix with a weakref probe: every tracked object of a dropped duel was
## still alive, and the ObjectDB count grew by 108 per real-deck duel (135 after four
## turns — the extra is the retained event log). Breaking that ONE edge freed every object
## and the growth went to exactly 0. These tests assert the fixed behaviour through the
## public construction path, so reintroducing any owning back-reference fails here.
##
## A weakref is only evidence if it was taken from a LIVE object; every capture below is
## asserted non-null before the duel is dropped, so a helper that captured nothing cannot
## pass.

const SUBSYSTEMS := ["engine", "state", "chain", "log", "triggers", "flow", "continuous",
	"summons", "battle", "rng", "player0", "player1", "p0", "p1", "deck_card", "hand_card"]


static func run() -> TestCase:
	var t := TestCase.new("LifetimeTests")
	_test_a_dropped_duel_frees_everything_it_owns(t)
	_test_a_played_duel_frees_everything_it_owns(t)
	_test_a_real_deck_duel_frees_everything_it_owns(t)
	_test_the_chain_manager_back_pointer_still_works(t)
	_test_repeated_construction_does_not_grow_objectdb(t)
	return t


# ---------------------------------------------------------------------------
# Helpers — each builds a duel in its OWN stack frame, so returning drops it.
# ---------------------------------------------------------------------------

static func _capture(d: Dictionary) -> Dictionary:
	var engine: DuelEngine = d["engine"]
	var s := engine.state
	return {
		"engine": weakref(engine), "state": weakref(s), "chain": weakref(engine.chain),
		"log": weakref(engine.log), "triggers": weakref(engine.triggers),
		"flow": weakref(engine.flow), "continuous": weakref(engine.continuous),
		"summons": weakref(engine.summons), "battle": weakref(engine.battle),
		"rng": weakref(s.rng), "player0": weakref(s.player(0)),
		"player1": weakref(s.player(1)), "p0": weakref(d["p0"]), "p1": weakref(d["p1"]),
		"deck_card": weakref(s.player(0).deck[0]), "hand_card": weakref(s.player(1).hand[0]),
	}


static func _live(refs: Dictionary) -> Array:
	var out: Array = []
	for k in SUBSYSTEMS:
		if refs.has(k) and refs[k].get_ref() != null:
			out.append(k)
	return out


## A filler duel, set up and left in its first open game state.
static func _fresh_duel() -> Dictionary:
	var d := TestFixtures.new_duel(8101, 0)
	var refs := _capture(d)
	return {"refs": refs, "live_before": _live(refs)}


## A filler duel that has resolved a Chain (so `ChainManager` built an `EffectContext`
## carrying the engine), Normal Summoned, attacked through the Damage Step and changed
## turn. Every path that hands the engine to something else has run.
static func _played_duel() -> Dictionary:
	var d := TestFixtures.battle_duel(8102)
	var engine: DuelEngine = d["engine"]
	var order_log: Array = []
	var e := TestFixtures.card_activation("lifetime_probe", Enums.SpellSpeed.SS2, order_log)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	var trap := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.with_effect(TestFixtures.trap("Lifetime Probe"), e))
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)
	var resolved := TestFixtures.activate_card(engine, 0, trap) and order_log.size() == 1
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	var attacker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Lifetime Attacker", 4, 1500, 1000))
	var attacked := TestFixtures.attack(engine, attacker, null)
	TestFixtures.pass_until_open(engine)
	var refs := _capture(d)
	return {"refs": refs, "live_before": _live(refs), "resolved": resolved,
		"attacked": attacked,
		"damage": TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_DAMAGE_INFLICTED)}


static func _real_duel() -> Dictionary:
	var d := TestFixtures.real_duel(8103, 0)
	var engine: DuelEngine = d["engine"]
	for i in range(4):
		TestFixtures.end_turn(engine)
	var refs := _capture(d)
	return {"refs": refs, "live_before": _live(refs), "turn": engine.state.turn_number,
		"instances": engine.state.all_instances().size()}


static func _object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


static func _build_and_drop(kind: String) -> void:
	match kind:
		"fresh":
			_fresh_duel()
		"played":
			_played_duel()
		"real":
			_real_duel()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _test_a_dropped_duel_frees_everything_it_owns(t: TestCase) -> void:
	t.start("a set-up duel, once its last outside reference is dropped, frees the engine, "
		+ "the state, every subsystem, both controllers and the cards")
	var r := _fresh_duel()
	t.eq((r["live_before"] as Array).size(), SUBSYSTEMS.size(),
		"non-vacuity: every tracked object was alive when it was captured")
	t.eq(_live(r["refs"]), [], "and after the drop not one of them survives")


static func _test_a_played_duel_frees_everything_it_owns(t: TestCase) -> void:
	t.start("a duel that resolved a Chain, attacked and changed turn is freed too — every "
		+ "path that hands the engine to an EffectContext has run")
	var r := _played_duel()
	t.eq((r["live_before"] as Array).size(), SUBSYSTEMS.size(),
		"non-vacuity: every tracked object was alive when it was captured")
	t.is_true(bool(r["resolved"]), "non-vacuity: a Chain Link really resolved")
	t.is_true(bool(r["attacked"]), "non-vacuity: an attack really was declared")
	t.eq(int(r["damage"]), 1, "non-vacuity: and it reached damage calculation")
	t.eq(_live(r["refs"]), [], "after the drop not one tracked object survives")


static func _test_a_real_deck_duel_frees_everything_it_owns(t: TestCase) -> void:
	t.start("a duel between the two REAL decks, four turns in, is freed too")
	var r := _real_duel()
	t.eq((r["live_before"] as Array).size(), SUBSYSTEMS.size(),
		"non-vacuity: every tracked object was alive when it was captured")
	t.eq(int(r["instances"]), 80, "non-vacuity: all 80 real deck slots were instantiated")
	t.eq(int(r["turn"]), 5, "non-vacuity: four turns really were played")
	t.eq(_live(r["refs"]), [], "after the drop not one tracked object survives")


static func _test_the_chain_manager_back_pointer_still_works(t: TestCase) -> void:
	t.start("the fix does not sever ChainManager from its engine: while the engine lives, "
		+ "chain.engine IS the engine")
	var d := TestFixtures.new_duel(8104, 0)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.chain.engine, engine,
		"the chain reaches the engine it belongs to — Champion's Vigilance needs this")
	var standalone := ChainManager.new(engine.state)
	t.is_null(standalone.engine, "a pure-chain ChainManager built without one still reads null")


static func _test_repeated_construction_does_not_grow_objectdb(t: TestCase) -> void:
	t.start("building and dropping many duels leaves the ObjectDB count where it started — "
		+ "no per-duel and no per-turn growth")
	for kind in ["fresh", "played", "real"]:
		# Warm-up: first use of a script can create lasting objects (static caches, the
		# real card library). Those are per-PROCESS, not per-duel.
		_build_and_drop(kind)
		_build_and_drop(kind)
		var before := _object_count()
		var n := 12
		for i in range(n):
			_build_and_drop(kind)
		var growth := _object_count() - before
		t.eq(growth, 0, "%d '%s' duels built and dropped: ObjectDB growth is 0 (it was ~108 "
			% [n, kind] + "per duel before the fix)")

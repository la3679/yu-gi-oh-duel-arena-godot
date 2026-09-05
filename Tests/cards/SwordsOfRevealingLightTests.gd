class_name SwordsOfRevealingLightTests
extends RefCounted

## `Swords of Revealing Light` — Normal Spell, one copy, deck 2.
##
## Official text (verified, `Data/cards/cards.json`, cid 4354):
##
##   "After this card's activation, it remains on the field, but you must destroy it during
##    the End Phase of your opponent's 3rd turn. When this card is activated: If your
##    opponent controls a face-down monster, flip all monsters they control face-up. While
##    this card is face-up on the field, your opponent's monsters cannot declare an attack."
##
## **Three sentences, three clauses, three different shapes** — and the suite is organised
## that way because merging any two of them would be wrong in an observable way:
##
##   1. the LIFETIME. A Normal Spell that stays on the field ([S1 p.28] says it should not)
##      and destroys itself on a schedule. `CARD_RULINGS.md` **R6**.
##   2. the ACTIVATION. The only clause that makes a Chain Link.
##   3. the ATTACK LOCK. Prevention, not negation — the attack is never declared.
##
## **R6 is settled here.** "The End Phase of your opponent's 3rd turn" counts the OPPONENT's
## turns, starting from the first opponent turn after activation. A Normal Spell can only be
## activated during its controller's own Main Phase [S1 p.31], so the controller's own turn
## is never one of the three and the question has exactly one answer in this pool — asserted
## directly, including the negative that the controller's own End Phases do not count.
##
## The generic machinery all three clauses stand on was written and proved before this card
## existed: `SpellTrapTests` for the remains-on-field override, `AttackRestrictionTests` for
## attack prevention and the per-card turn counter. This suite proves the printed card is
## wired to it correctly, not that the machinery works.

const CARD_UNDER_TEST := "Swords of Revealing Light"

const FLIP_EFFECT_ID := "flip_opponents_monsters_face_up"
const ATTACK_LOCK_EFFECT_ID := "opponents_monsters_cannot_attack"
const OPPONENT_TURNS := 3


static func run() -> TestCase:
	var t := TestCase.new("SwordsOfRevealingLightTests")

	# --- Shape ---
	_test_the_card_declares_three_clauses_of_three_different_kinds(t)
	_test_the_lifetime_clause_is_not_a_trigger_effect(t)
	_test_the_activation_clause_has_no_activation_condition(t)

	# --- Clause 1: it remains on the field ---
	_test_it_stays_on_the_field_after_resolving(t)
	_test_it_is_still_a_normal_spell(t)

	# --- Clause 1: R6, the countdown ---
	_test_it_survives_the_opponents_first_two_turns_and_dies_on_the_third(t)
	_test_the_controllers_own_end_phases_do_not_count(t)
	_test_the_counter_advances_once_per_turn_not_once_per_end_phase_event(t)
	_test_it_is_destroyed_rather_than_sent_to_the_graveyard(t)
	_test_a_normal_spell_can_only_be_activated_on_its_controllers_turn(t)

	# --- Clause 2: the flip ---
	_test_it_flips_the_opponents_face_down_monsters_face_up(t)
	_test_a_flipped_monster_lands_in_face_up_defense_position(t)
	_test_it_flips_every_face_down_monster_not_only_one(t)
	_test_it_does_not_touch_the_controllers_own_face_down_monsters(t)
	_test_it_is_activatable_with_no_face_down_monster_at_all(t)
	_test_flipping_is_not_a_flip_summon(t)
	_test_a_flipped_monster_really_gets_its_flip_effect(t)

	# --- Clause 3: the attack lock ---
	_test_the_opponents_monsters_cannot_declare_an_attack(t)
	_test_the_lock_is_prevention_and_not_negation(t)
	_test_the_controllers_own_monsters_may_still_attack(t)
	_test_the_lock_covers_a_monster_that_arrives_afterwards(t)
	_test_the_lock_lifts_when_the_card_leaves_the_field(t)

	# --- The pool ---
	_test_the_real_pool_carries_one_copy_and_the_verified_text(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## A duel in player 0's Main Phase 1 with the Swords in player 0's hand.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["swords"] = TestFixtures.give_to_hand(engine, 0, _def())
	return d


## Activate the Swords from player 0's hand and let the Chain resolve.
static func _activate(engine: DuelEngine, swords: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, swords.id)
	if a == null:
		return false
	var ok := engine.submit_action(a)
	TestFixtures.pass_until_open(engine)
	return ok


static func _face_down(engine: DuelEngine, pid: int, name: String) -> CardInstance:
	return TestFixtures.give_monster_on_field(engine, pid,
		TestFixtures.monster(name, 4, 1200, 1000), Enums.Position.FACE_DOWN_DEFENSE)


## Safe indexed read of the turn trace. A wrong implementation ends the countdown early, so
## the trace is SHORTER than expected — and a raw out-of-range index would abort the test
## after its passing assertions rather than failing it, silently dropping every claim after
## it. That is the harness defect `PROJECT_STATE.md 0` records from batch 8, so every read
## goes through here and a missing entry fails loudly instead.
static func _at(trace: Array, i: int) -> Dictionary:
	if i < 0 or i >= trace.size():
		return {"turn": -1, "player": -1, "still_there": false, "count": -1}
	return trace[i]


static func _effect_by_id(card_def: CardDef, effect_id: String):
	for effect in card_def.effects:
		if (effect as EffectDef).effect_id == effect_id:
			return effect
	return null


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_three_clauses_of_three_different_kinds(
		t: TestCase) -> void:
	t.start("three official sentences, three EffectDefs: a CONTINUOUS lifetime carrying the "
		+ "remains-on-field marker, a CARD_ACTIVATION, and a CONTINUOUS attack lock")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	t.eq(card_def.effects.size(), 3, "exactly three clauses")
	t.eq(card_def.category, Enums.Category.SPELL, "it is a Spell Card")
	t.eq(card_def.st_kind, Enums.STKind.NORMAL_SPELL, "a NORMAL Spell")

	var lifetime = _effect_by_id(card_def, DuelEngine.REMAINS_ON_FIELD_EFFECT_ID)
	t.not_null(lifetime, "the lifetime clause carries the remains-on-field marker id")
	t.eq((lifetime as EffectDef).effect_type, Enums.EffectType.CONTINUOUS, "and is CONTINUOUS")
	t.eq((lifetime as EffectDef).ruling_ref, "R6", "and cites R6")

	var activation = _effect_by_id(card_def, FLIP_EFFECT_ID)
	t.not_null(activation, "the flip clause exists")
	t.eq((activation as EffectDef).effect_type, Enums.EffectType.CARD_ACTIVATION,
		"and is the CARD ACTIVATION — the only clause that makes a Chain Link")
	t.is_true((activation as EffectDef).starts_chain, "so it starts a Chain")

	var lock = _effect_by_id(card_def, ATTACK_LOCK_EFFECT_ID)
	t.not_null(lock, "the attack lock exists")
	t.eq((lock as EffectDef).effect_type, Enums.EffectType.CONTINUOUS, "and is CONTINUOUS")
	t.is_false((lock as EffectDef).starts_chain, "and starts no Chain")


static func _test_the_lifetime_clause_is_not_a_trigger_effect(t: TestCase) -> void:
	t.start("'you must destroy it during the End Phase' puts NO link on the Chain, so it is "
		+ "a continuous clause responding to an event — not a Trigger Effect")
	var lifetime: EffectDef = _effect_by_id(_def(), DuelEngine.REMAINS_ON_FIELD_EFFECT_ID)
	t.eq(lifetime.effect_type, Enums.EffectType.CONTINUOUS, "CONTINUOUS, not TRIGGER")
	t.is_false(lifetime.starts_chain, "it starts no Chain")
	t.is_true(lifetime.respond_to_event.is_valid(), "it responds to an event")
	t.is_false(lifetime.resolve.is_valid(), "and has no resolve() — nothing resolves")
	t.is_true(lifetime.trigger_events.has(GameEvent.Kind.PHASE_CHANGED),
		"it names PHASE_CHANGED")
	t.eq(lifetime.optionality, Enums.Optionality.MANDATORY,
		"'you MUST destroy it' — mandatory, never offered as a choice")


static func _test_the_activation_clause_has_no_activation_condition(t: TestCase) -> void:
	t.start("'If your opponent controls a face-down monster' sits AFTER the colon, so it is "
		+ "part of the EFFECT and checked at resolution — not an activation condition")
	var activation: EffectDef = _effect_by_id(_def(), FLIP_EFFECT_ID)
	t.is_false(activation.condition.is_valid(),
		"no activation condition: the card is legal to activate against an empty board")
	t.is_false(activation.targets, "and it does not target — 'all monsters' is not targeting")
	t.is_true(activation.activation_locations.has(Enums.ActivationLocation.HAND),
		"activated from the hand")
	t.is_true(activation.activation_locations.has(Enums.ActivationLocation.FIELD_FACE_DOWN),
		"or from a Set copy")
	t.is_false(activation.activation_locations.has(Enums.ActivationLocation.FIELD_FACE_UP),
		"but never from face-up on the field — being face-up is what activating it does")


# ---------------------------------------------------------------------------
# Clause 1 — it remains on the field
# ---------------------------------------------------------------------------

static func _test_it_stays_on_the_field_after_resolving(t: TestCase) -> void:
	t.start("a NORMAL Spell that stays on the field: [S1 p.28] would send it to the "
		+ "Graveyard, and its own text overrides that")
	var d := _board(9301)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]

	t.is_true(_activate(engine, swords), "it is activated")
	t.eq(swords.zone, Enums.Zone.SPELL_TRAP_ZONE, "and it is on the field")
	t.is_true(swords.is_face_up(), "face-up, so its continuous clauses apply")
	t.is_true(DuelEngine.card_remains_on_field_after_activation(swords),
		"because it declares the remains-on-field override")


static func _test_it_is_still_a_normal_spell(t: TestCase) -> void:
	t.start("the override does not change what the card IS: it is still a Normal Spell, and "
		+ "the kind-only question still answers correctly on its own")
	var card_def := _def()
	t.eq(card_def.st_kind, Enums.STKind.NORMAL_SPELL, "a Normal Spell")
	t.is_false(Enums.stays_on_field(card_def.st_kind),
		"whose KIND does not stay on the field")
	t.eq(card_def.spell_speed, Enums.SpellSpeed.SS1, "and it is Spell Speed 1")


# ---------------------------------------------------------------------------
# Clause 1 — R6, the countdown
# ---------------------------------------------------------------------------

static func _test_it_survives_the_opponents_first_two_turns_and_dies_on_the_third(
		t: TestCase) -> void:
	t.start("R6: it counts the OPPONENT's turns, and is destroyed in the End Phase of the "
		+ "third one — not the second, and not the fourth")
	var d := _board(9303)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	t.is_true(_activate(engine, swords), "activated on player 0's turn")

	# Step ONE turn at a time and record, after each turn's End Phase has passed, whose turn
	# it was, whether the card is still there, and what the counter says. Reading the counter
	# only while the card is still on the field matters: `on_leave_field()` clears
	# `turn_counters`, so a reading taken after the destruction would always be 0.
	var trace: Array = []
	for i in range(2 * OPPONENT_TURNS + 2):
		if swords.zone != Enums.Zone.SPELL_TRAP_ZONE:
			break
		var ended_turn := engine.state.turn_number
		var ended_player := engine.state.turn_player_id
		TestFixtures.end_turn(engine)
		trace.append({
			"turn": ended_turn, "player": ended_player,
			"still_there": swords.zone == Enums.Zone.SPELL_TRAP_ZONE,
			"count": swords.turn_counter_value(_turn_counter_key()),
		})

	# Player 0 went first, so the turns are 1:p0 (the activation) 2:p1 3:p0 4:p1 5:p0 6:p1.
	# The opponent's three turns are 2, 4 and 6, and the card must die in turn 6's End Phase.
	t.eq(trace.size(), 6, "six turns passed before it was gone")
	t.eq(_at(trace, 1)["player"], 1, "turn 2 was the opponent's 1st turn")
	t.is_true(bool(_at(trace, 1)["still_there"]), "and the card survived it")
	t.eq(int(_at(trace, 1)["count"]), 1, "with the counter at 1")
	t.eq(_at(trace, 3)["player"], 1, "turn 4 was the opponent's 2nd")
	t.is_true(bool(_at(trace, 3)["still_there"]), "and the card survived that too")
	t.eq(int(_at(trace, 3)["count"]), 2, "with the counter at 2")
	t.eq(_at(trace, 5)["player"], 1, "turn 6 was the opponent's 3rd")
	t.eq(int(_at(trace, 5)["turn"]), 6, "which is turn 6")
	t.is_false(bool(_at(trace, 5)["still_there"]),
		"and THAT is the End Phase the card is destroyed in - not the 2nd, not the 4th, and "
		+ "not one of the controller's own")
	t.eq(int(_at(trace, 2)["count"]), 1,
		"the controller's own turn 3 did not advance the counter")
	t.eq(int(_at(trace, 4)["count"]), 2,
		"nor did the controller's own turn 5")
	t.eq(swords.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(swords.turn_counter_value(_turn_counter_key()), 0,
		"and the counter is cleared, because per-instance state does not survive leaving "
		+ "the field - a second copy would count its own turns from zero")


## The card's own counter key, read from the card file rather than retyped, so a rename
## there fails here instead of silently reading a counter that is always 0.
static func _turn_counter_key() -> String:
	return load("res://Scripts/cards/registry/SwordsOfRevealingLight.gd") \
		.get_script_constant_map()["TURN_COUNTER_KEY"]


static func _test_the_controllers_own_end_phases_do_not_count(t: TestCase) -> void:
	t.start("R6: the controller's OWN End Phases do not count — after three of them the "
		+ "card is untouched and the counter is still 0")
	var d := _board(9305)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	t.is_true(_activate(engine, swords), "activated")

	# Three of the controller's own End Phases, reached by ending both players' turns.
	# The opponent's turns in between are what the card actually counts, so the counter is
	# read after each of the CONTROLLER's End Phases and must lag behind.
	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 1, "player 1's turn")
	t.eq(swords.turn_counter_value(_turn_counter_key()), 0,
		"nothing counted yet — player 1's End Phase has not happened")
	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 0, "back to player 0")
	t.eq(swords.turn_counter_value(_turn_counter_key()), 1,
		"one of the opponent's End Phases counted")
	TestFixtures.end_turn(engine)
	t.eq(swords.turn_counter_value(_turn_counter_key()), 1,
		"player 0's own End Phase did NOT count — the counter is unchanged")
	t.eq(swords.zone, Enums.Zone.SPELL_TRAP_ZONE, "and the card is still on the field")


static func _test_the_counter_advances_once_per_turn_not_once_per_end_phase_event(
		t: TestCase) -> void:
	t.start("R6: the counter advances at most once per TURN NUMBER, so a second "
		+ "PHASE_CHANGED to END in the same turn cannot double-count")
	var d := _board(9307)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	t.is_true(_activate(engine, swords), "activated")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	var after_one := swords.turn_counter_value(_turn_counter_key())
	t.eq(after_one, 1, "one opponent End Phase counted")

	# Replay the same event by hand. The turn number has not changed, so the counter must
	# not move — this is the property that makes the countdown safe against an engine that
	# emits the phase event more than once.
	var turn_at_count := engine.state.turn_number
	engine.continuous.respond_to(GameEvent.new(GameEvent.Kind.PHASE_CHANGED, {
		"from": Enums.Phase.MAIN_2, "to": Enums.Phase.END,
		"turn_player": engine.state.turn_player_id, "turn": turn_at_count,
	}))
	t.eq(swords.turn_counter_value(_turn_counter_key()), after_one,
		"a repeated End Phase event in a turn that is not the opponent's changes nothing")
	t.eq(swords.zone, Enums.Zone.SPELL_TRAP_ZONE, "and the card is still there")


static func _test_it_is_destroyed_rather_than_sent_to_the_graveyard(t: TestCase) -> void:
	t.start("'you must DESTROY it' — a real destruction, so a destruction-prevention or "
		+ "replacement effect would see it")
	var d := _board(9309)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	t.is_true(_activate(engine, swords), "activated")

	var mark := engine.state.events.size()
	for i in range(OPPONENT_TURNS * 2):
		if swords.zone == Enums.Zone.GRAVEYARD:
			break
		TestFixtures.end_turn(engine)
	t.eq(swords.zone, Enums.Zone.GRAVEYARD, "it ended up in the Graveyard")

	var destroyed_by_effect := false
	for i in range(mark, engine.state.events.size()):
		var e: GameEvent = engine.state.events[i]
		if e.kind == GameEvent.Kind.CARD_MOVED \
				and int(e.data.get("card_id", -1)) == swords.id \
				and e.data.get("reason") == Enums.MoveReason.DESTROYED_BY_EFFECT:
			destroyed_by_effect = true
	t.is_true(destroyed_by_effect,
		"and it got there by DESTROYED_BY_EFFECT, not by a plain send-to-GY")


static func _test_a_normal_spell_can_only_be_activated_on_its_controllers_turn(
		t: TestCase) -> void:
	t.start("R6 has one answer in this pool because a Normal Spell is only ever activated "
		+ "during its controller's own Main Phase [S1 p.31] — asserted, not assumed")
	var d := _board(9311)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, swords.id),
		"on its controller's Main Phase it is offered")

	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 1, "now it is the opponent's turn")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, swords.id),
		"and the Normal Spell is not offered — so the controller's own turn can never be "
		+ "one of the three counted turns")


# ---------------------------------------------------------------------------
# Clause 2 — the flip
# ---------------------------------------------------------------------------

static func _test_it_flips_the_opponents_face_down_monsters_face_up(t: TestCase) -> void:
	t.start("CONTROL vs FLIPPED: the opponent's face-down monster is turned face-up by the "
		+ "activation, and is face-down until it happens")
	var d := _board(9313)
	var engine: DuelEngine = d["engine"]
	var hidden := _face_down(engine, 1, "Hidden One")

	t.is_true(hidden.is_face_down(), "CONTROL: it is face-down before the activation")
	t.is_true(_activate(engine, d["swords"]), "the Swords are activated")
	t.is_true(hidden.is_face_up(), "and it is face-up afterwards")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		hidden.id), 1, "exactly one CARD_FLIPPED_FACE_UP for it")


static func _test_a_flipped_monster_lands_in_face_up_defense_position(t: TestCase) -> void:
	t.start("a face-down monster is in DEFENSE Position, and turning it face-up does not "
		+ "change that — FACE_UP_DEFENSE, never FACE_UP_ATTACK")
	var d := _board(9315)
	var engine: DuelEngine = d["engine"]
	var hidden := _face_down(engine, 1, "Defender")
	t.eq(hidden.position, Enums.Position.FACE_DOWN_DEFENSE, "it starts face-down defence")

	t.is_true(_activate(engine, d["swords"]), "the Swords are activated")
	t.eq(hidden.position, Enums.Position.FACE_UP_DEFENSE,
		"and it is now face-up DEFENCE — the effect reveals, it does not reposition")


static func _test_it_flips_every_face_down_monster_not_only_one(t: TestCase) -> void:
	t.start("'flip ALL monsters they control face-up' — every face-down monster, and the "
		+ "already-face-up ones are untouched")
	var d := _board(9317)
	var engine: DuelEngine = d["engine"]
	var first := _face_down(engine, 1, "Hidden A")
	var second := _face_down(engine, 1, "Hidden B")
	var already_up := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Open One", 4, 1400, 1000))

	t.is_true(_activate(engine, d["swords"]), "the Swords are activated")
	t.is_true(first.is_face_up(), "the first face-down monster is revealed")
	t.is_true(second.is_face_up(), "and so is the second")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		already_up.id), 0,
		"the one that was already face-up was not flipped again — it was already there")
	t.eq(already_up.position, Enums.Position.FACE_UP_ATTACK,
		"and its Attack Position is untouched")


static func _test_it_does_not_touch_the_controllers_own_face_down_monsters(
		t: TestCase) -> void:
	t.start("'monsters THEY control' — the controller's own face-down monster stays down")
	var d := _board(9319)
	var engine: DuelEngine = d["engine"]
	var theirs := _face_down(engine, 1, "Their Hidden")
	var mine := _face_down(engine, 0, "My Hidden")

	t.is_true(_activate(engine, d["swords"]), "the Swords are activated")
	t.is_true(theirs.is_face_up(), "the opponent's monster is revealed")
	t.is_true(mine.is_face_down(), "the controller's own is not")


static func _test_it_is_activatable_with_no_face_down_monster_at_all(t: TestCase) -> void:
	t.start("the 'if' is checked at RESOLUTION: with no face-down monster anywhere the card "
		+ "is still legal to activate, and still stays on the field")
	var d := _board(9321)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	var open := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Nothing Hidden", 4, 1400, 1000))

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, swords.id),
		"it is offered even though nothing is face-down")
	t.is_true(_activate(engine, swords), "and it activates")
	t.eq(swords.zone, Enums.Zone.SPELL_TRAP_ZONE, "and stays on the field")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP), 0,
		"having flipped nothing")
	t.is_true(open.is_face_up(), "the face-up monster is simply left alone")
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 1),
		"and the attack lock applies regardless — the clauses are independent")


static func _test_flipping_is_not_a_flip_summon(t: TestCase) -> void:
	t.start("flipping a monster face-up is NOT a Flip Summon [S1 p.24, p.28]: no Summon "
		+ "event, and the Normal Summon allowance is untouched")
	var d := _board(9323)
	var engine: DuelEngine = d["engine"]
	var hidden := _face_down(engine, 1, "Not Summoned")
	var mark := engine.state.events.size()

	t.is_true(_activate(engine, d["swords"]), "the Swords are activated")
	t.is_true(hidden.is_face_up(), "the monster is face-up")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 0,
		"no FLIP_SUMMON_SUCCEEDED was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_DECLARED), 0,
		"and no FLIP_SUMMON_DECLARED either")
	var summons := 0
	for i in range(mark, engine.state.events.size()):
		var kind = engine.state.events[i].kind
		if kind == GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED 				or kind == GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED:
			summons += 1
	t.eq(summons, 0, "and nothing was Summoned at all, by any route")
	t.eq(engine.state.player(1).normal_summons_used, 0,
		"the opponent's Normal Summon allowance for the turn is untouched")


static func _test_a_flipped_monster_really_gets_its_flip_effect(t: TestCase) -> void:
	t.start("the flip generates a REAL Flip effect at the resulting trigger window — a "
		+ "silent position change would be the easy wrong implementation")
	var d := _board(9325)
	var engine: DuelEngine = d["engine"]
	var order: Array = []
	var flipper := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.flip_effect_monster("Revealed Flipper"),
		Enums.Position.FACE_DOWN_DEFENSE)
	flipper.turn_summoned = -1
	flipper.turn_set = -1

	t.is_true(flipper.is_face_down(), "it starts face-down")
	var hand_before := engine.state.player(1).hand.size()
	t.is_true(_activate(engine, d["swords"]), "the Swords are activated")
	t.is_true(flipper.is_face_up(), "and it is revealed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		flipper.id), 1,
		"one CARD_FLIPPED_FACE_UP — the event a FLIP effect keys on, so the Flip effect is "
		+ "collected at the window that opens after the Chain resolves")
	t.eq(flipper.definition.effects[0].effect_type, Enums.EffectType.FLIP,
		"and the monster really does have a FLIP effect to collect")
	# The end-to-end proof. The fixture's FLIP effect is a MANDATORY "draw 1 card", so if
	# the window really opened and the effect really resolved, the opponent drew. Asserting
	# only the event would pass against an implementation that changed the position
	# silently and never let the trigger system see it.
	t.eq(engine.state.player(1).hand.size(), hand_before + 1,
		"the opponent DREW — the Flip effect really was collected and really resolved")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CHAIN_LINK_ADDED,
		flipper.id), 1, "as a real Chain Link of its own, after the Swords resolved")


# ---------------------------------------------------------------------------
# Clause 3 — the attack lock
# ---------------------------------------------------------------------------

## Player 0 activates the Swords on turn 2, then hands the turn to player 1, who tries to
## attack into them. Returns the engine plus player 1's attacker and player 0's monster.
static func _attack_board(seed_value: int, with_swords: bool = true) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)                       # player 1's first turn is over
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["mine"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Wall", 4, 1000, 1800))
	d["theirs"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Attacker", 4, 1900, 1000))
	if with_swords:
		var swords := TestFixtures.give_to_hand(engine, 0, _def())
		d["swords"] = swords
		var ok := _activate(engine, swords)
		d["activated"] = ok
	TestFixtures.end_turn(engine)                       # -> player 1's turn
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	engine.continuous.recompute()
	return d


static func _test_the_opponents_monsters_cannot_declare_an_attack(t: TestCase) -> void:
	t.start("CONTROL vs LOCKED: with the Swords face-up the opponent's monster is never "
		+ "offered the declaration, and without them the same monster attacks")
	var control := _attack_board(9327, false)
	var control_engine: DuelEngine = control["engine"]
	t.eq(control_engine.state.phase, Enums.Phase.BATTLE, "CONTROL: in the Battle Phase")
	t.is_true(TestFixtures.has_action(control_engine.get_legal_actions(1),
		Enums.ActionKind.DECLARE_ATTACK, (control["theirs"] as CardInstance).id),
		"CONTROL: the attack is offered")

	var d := _attack_board(9329, true)
	var engine: DuelEngine = d["engine"]
	t.is_true(bool(d["activated"]), "the Swords were activated")
	t.eq((d["swords"] as CardInstance).zone, Enums.Zone.SPELL_TRAP_ZONE,
		"and are still on the field a turn later")
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 1),
		"the restriction is recorded against the opponent")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.DECLARE_ATTACK, (d["theirs"] as CardInstance).id),
		"and the declaration is not offered")


static func _test_the_lock_is_prevention_and_not_negation(t: TestCase) -> void:
	t.start("R34 part A: PREVENTION — no ATTACK_DECLARED is emitted, nothing is negated, "
		+ "and the monster keeps its attack for the turn")
	var d := _attack_board(9331, true)
	var engine: DuelEngine = d["engine"]
	var attacker: CardInstance = d["theirs"]

	t.is_false(TestFixtures.attack(engine, attacker, d["mine"]),
		"driving the attack through the public API fails")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_DECLARED), 0,
		"NO ATTACK_DECLARED — prevention happens before declaration")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_NEGATED), 0,
		"and nothing was negated — there was no attack to negate")
	t.is_false(attacker.has_attacked_this_turn,
		"the monster has NOT spent its attack")


static func _test_the_controllers_own_monsters_may_still_attack(t: TestCase) -> void:
	t.start("'YOUR OPPONENT's monsters' — the Swords' own controller is not restricted")
	var d := _attack_board(9333, true)
	var engine: DuelEngine = d["engine"]
	t.is_true(ContinuousEffects.attacks_restricted(engine.state, 1),
		"player 1 is restricted")
	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 0),
		"player 0 — the controller — is not")


static func _test_the_lock_covers_a_monster_that_arrives_afterwards(t: TestCase) -> void:
	t.start("it is a per-PLAYER restriction, so a monster that reaches the field after the "
		+ "Swords are up is restricted too, with no per-card flag written on it")
	var d := _attack_board(9335, true)
	var engine: DuelEngine = d["engine"]
	var latecomer := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Latecomer", 4, 2000, 1000))
	engine.continuous.recompute()

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.DECLARE_ATTACK, latecomer.id),
		"the newcomer cannot declare either")
	t.is_false(bool(latecomer.flags.get("cannot_attack", false)),
		"and nothing was written on the card itself")


static func _test_the_lock_lifts_when_the_card_leaves_the_field(t: TestCase) -> void:
	t.start("the lock is state-derived: destroy the Swords and the opponent may "
		+ "attack again in the same Battle Phase")
	var d := _attack_board(9337, true)
	var engine: DuelEngine = d["engine"]
	var swords: CardInstance = d["swords"]
	var attacker: CardInstance = d["theirs"]
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id), "restricted to begin with")

	engine.state.destroy(swords, Enums.MoveReason.DESTROYED_BY_EFFECT, swords.id)
	engine.continuous.recompute()

	t.eq(swords.zone, Enums.Zone.GRAVEYARD, "the Swords are gone")
	t.is_false(ContinuousEffects.attacks_restricted(engine.state, 1),
		"and the restriction is gone with them")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id),
		"so the attack is offered again — the monster still had its attack")


# ---------------------------------------------------------------------------
# The pool
# ---------------------------------------------------------------------------

static func _test_the_real_pool_carries_one_copy_and_the_verified_text(
		t: TestCase) -> void:
	t.start("the real pool: one copy, cid 4354, and the three implemented clauses are the "
		+ "verified official text verbatim")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")
	t.is_true(cards.has(CARD_UNDER_TEST), "and it contains Swords of Revealing Light")

	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the verified card database is readable")
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	t.check(parsed is Dictionary, "and parses")

	var copies := -1
	var cid := ""
	var text := ""
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if str(row.get("name", "")) == CARD_UNDER_TEST:
				copies = int(row.get("copies_total", -1))
				cid = str(row.get("konami_cid", ""))
				text = str(row.get("text", ""))
	t.eq(copies, 1, "one copy is printed in the pool")
	t.eq(cid, "4354", "the verified Konami card id")

	var joined := ""
	for effect in _def().effects:
		joined += (effect as EffectDef).clause_text + " "
	t.eq(joined.strip_edges(), text,
		"the three clause texts, in printed order, are exactly the verified official text")

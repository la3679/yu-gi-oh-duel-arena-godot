class_name AussaTheEarthCharmerTests
extends RefCounted

## Per-card suite for `Aussa the Earth Charmer`. Research/CARD_RULINGS.md §2.1.
##
##   "FLIP: Target 1 EARTH monster your opponent controls; take control of that monster
##    while this card is face-up on the field."
##
## This is the FULL enumeration for the Charmer clause. `Eria the Water Charmer` and
## `Wynn the Wind Charmer` carry the same text with a different Attribute and share the
## mechanics through `EffectPrimitives.charmer_take_control()`; their own suites cover their
## Attribute and re-prove the end-to-end behaviour on their own card rather than assuming it.
##
## The generic control subsystem this card is the first consumer of is proved separately and
## first, by `ControlTests` — the same way `EquipTests` came before `Gagagashield`.


const CARD_UNDER_TEST := "Aussa the Earth Charmer"

const EFFECT_ID := "charmer_take_control"


static func run() -> TestCase:
	var t := TestCase.new("AussaTheEarthCharmerTests")
	_test_clause_shape(t)
	_test_the_attribute_requirement(t)
	_test_only_the_opponents_monsters(t)
	_test_a_face_down_monster_is_not_a_target(t)
	_test_flip_summon_takes_control(t)
	_test_flipped_by_an_attack(t)
	_test_no_legal_target(t)
	_test_the_charmer_is_flipped_face_down(t)
	_test_the_charmer_leaves_the_field(t)
	_test_the_borrowed_monster_leaves_the_field(t)
	_test_the_target_became_illegal_before_resolution(t)
	_test_no_free_monster_zone(t)
	_test_it_targets_and_respects_targeting_protection(t)
	_test_a_negated_flip_summon_never_triggers_it(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _effect() -> EffectDef:
	for entry in _def().effects:
		var e: EffectDef = entry
		if e.effect_id == EFFECT_ID:
			return e
	return null


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Player 0 controls a face-down Aussa that is legal to Flip Summon; player 1 controls a
## face-up EARTH monster. Returns {"engine", "p0", "p1", "aussa", "prey"}.
static func _board(seed_value: int, prey_attribute: String = "EARTH") -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["aussa"] = TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	d["prey"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1200, 800, prey_attribute))
	return d


## Flip Summon `aussa` and let the resulting Chain resolve fully.
static func _flip_summon(engine: DuelEngine, aussa: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, aussa.id)
	if a == null:
		return false
	var ok := engine.submit_action(a)
	TestFixtures.pass_until_open(engine)
	return ok


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("one printed clause, one EffectDef: a MANDATORY, TARGETING Flip Effect")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.attribute, "EARTH", "Aussa is an EARTH monster herself")
	t.eq(def.level, 3, "Level 3")
	t.eq(def.race, "Spellcaster", "Spellcaster")
	t.is_true(def.is_effect_monster, "an Effect Monster")
	t.is_false(def.is_normal_monster, "and not a Normal Monster")
	t.eq(def.effects.size(), 1, "exactly one EffectDef for the one printed clause")

	var e := _effect()
	t.not_null(e, "the clause is present")
	t.eq(e.effect_type, Enums.EffectType.FLIP, "it is a FLIP effect")
	t.eq(e.optionality, Enums.Optionality.MANDATORY,
		"MANDATORY — the text has no \"you can\"")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1 [S1 p.44]")
	t.is_true(e.targets, "it TARGETS — the current official wording says \"Target\"")
	t.eq(e.target_count_min, 1, "exactly 1 target minimum")
	t.eq(e.target_count_max, 1, "and 1 maximum")
	t.is_true(e.trigger_events.has(GameEvent.Kind.CARD_FLIPPED_FACE_UP),
		"it triggers on being FLIPPED FACE-UP, not on a Flip Summon succeeding")
	t.is_false(e.trigger_events.has(GameEvent.Kind.FLIP_SUMMON_SUCCEEDED),
		"keying it on the Summon would lose the attack and card-effect flips")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"flipped by an attacker, it activates inside the Damage Step [S1 p.41]")
	t.is_true(e.clause_text.contains("while this card is face-up on the field"),
		"the duration is part of the quoted official text")


# ---------------------------------------------------------------------------
# Target legality
# ---------------------------------------------------------------------------

static func _test_the_attribute_requirement(t: TestCase) -> void:
	t.start("only EARTH monsters are legal targets — the Attribute is the whole filter")
	var d := _duel(401)
	var engine: DuelEngine = d["engine"]
	var aussa := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var earth := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Earthy", 4, 1200, 800, "EARTH"))
	var water := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Watery", 4, 1200, 800, "WATER"))
	var ctx := ActivationRules.make_context(engine.state, aussa, _effect(), 0, null)
	var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)

	t.is_true(legal.has(earth.id), "the EARTH monster is a candidate")
	t.is_false(legal.has(water.id), "the WATER monster is not")
	t.eq(legal.size(), 1, "exactly one candidate")

	# Positive control on the negative: the WATER monster is otherwise perfectly eligible,
	# so it is the ATTRIBUTE that excluded it and nothing else.
	t.is_true(water.is_face_up(), "the excluded monster is face-up")
	t.eq(water.controller_id, 1, "controlled by the opponent")
	t.eq(water.zone, Enums.Zone.MONSTER_ZONE, "and in a Monster Zone")


static func _test_only_the_opponents_monsters(t: TestCase) -> void:
	t.start("\"your opponent controls\" — your own EARTH monsters are never candidates")
	var d := _duel(402)
	var engine: DuelEngine = d["engine"]
	var aussa := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 1200, 800, "EARTH"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1200, 800, "EARTH"))
	var ctx := ActivationRules.make_context(engine.state, aussa, _effect(), 0, null)
	var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)

	t.is_false(legal.has(mine.id), "your own EARTH monster is not a candidate")
	t.is_true(legal.has(theirs.id), "the opponent's is")
	t.is_false(legal.has(aussa.id), "and Aussa cannot target herself")
	t.eq(legal.size(), 1, "exactly one candidate")


static func _test_a_face_down_monster_is_not_a_target(t: TestCase) -> void:
	t.start("a face-down monster is not a candidate: its Attribute is not a property either "
		+ "player may act on")
	var d := _duel(403)
	var engine: DuelEngine = d["engine"]
	var aussa := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden", 4, 1200, 800, "EARTH"),
		Enums.Position.FACE_DOWN_DEFENSE)
	var ctx := ActivationRules.make_context(engine.state, aussa, _effect(), 0, null)
	var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)
	t.is_false(legal.has(hidden.id), "the face-down EARTH monster is not offered")
	t.eq(legal.size(), 0, "there is no legal target at all")

	# Positive control: the very same monster face-up IS a candidate, so it is being
	# face-down that excluded it.
	engine.state.set_battle_position(hidden, Enums.Position.FACE_UP_ATTACK, true)
	var ctx2 := ActivationRules.make_context(engine.state, aussa, _effect(), 0, null)
	t.eq(ActivationRules.legal_targets(ctx2).size(), 1,
		"face-up, the same monster is a legal target")


# ---------------------------------------------------------------------------
# The effect working
# ---------------------------------------------------------------------------

static func _test_flip_summon_takes_control(t: TestCase) -> void:
	t.start("Flip Summoned, it takes control of the targeted EARTH monster — CONTROLLER "
		+ "changes, OWNER does not")
	var d := _board(404)
	var engine: DuelEngine = d["engine"]
	var aussa: CardInstance = d["aussa"]
	var prey: CardInstance = d["prey"]

	t.is_true(_flip_summon(engine, aussa), "Aussa is Flip Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 1,
		"the Flip Summon succeeded")
	t.is_true(aussa.is_face_up(), "Aussa is face-up")

	t.eq(prey.controller_id, 0, "player 0 now controls the EARTH monster")
	t.eq(prey.owner_id, 1, "player 1 still OWNS it")
	t.is_true(engine.state.player(0).monsters().has(prey),
		"it is in one of player 0's Monster Zones")
	t.is_false(engine.state.player(1).monsters().has(prey), "and none of player 1's")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"exactly one control change was announced")
	t.eq(engine.state.control_leases_for(prey.id).size(), 1, "and one lease is in force")
	var lease: Dictionary = engine.state.control_leases_for(prey.id)[0]
	t.eq(int(lease["source_id"]), aussa.id, "the lease hangs off Aussa")
	t.eq(lease["duration"], Enums.ControlDuration.WHILE_SOURCE_FACE_UP,
		"\"while this card is face-up on the field\"")


static func _test_flipped_by_an_attack(t: TestCase) -> void:
	t.start("flipped face-up by an ATTACK, the Flip effect still triggers — it keys on the "
		+ "flip, not on the Flip Summon [S1 p.41]")
	var d := TestFixtures.battle_duel(405)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.turn_player_id, 0, "player 0 is attacking")
	# Aussa sits face-down on the DEFENDING player's field and is attacked.
	var aussa := TestFixtures.give_monster_on_field(engine, 1, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1000, 1000, "EARTH"))
	# Aussa's controller (player 1) will take control of an EARTH monster player 0 controls.
	# The attacker itself is the only EARTH monster on player 0's field.
	t.is_true(TestFixtures.attack(engine, attacker, aussa),
		"the attack on the face-down Aussa is declared")
	TestFixtures.pass_until_open(engine)

	t.is_true(aussa.is_face_up() or aussa.zone == Enums.Zone.GRAVEYARD,
		"Aussa was flipped face-up by the attack")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		aussa.id), 1, "exactly one flip")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 0,
		"and it was NOT a Flip Summon")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"the Flip effect nevertheless activated and took control")
	t.eq(attacker.controller_id, 1,
		"the attacking EARTH monster is now controlled by Aussa's controller")
	t.eq(attacker.owner_id, 0, "and still owned by player 0")


static func _test_no_legal_target(t: TestCase) -> void:
	t.start("with no legal target the MANDATORY effect does not activate at all — which is "
		+ "not the same as being declined")
	var d := _duel(406)
	var engine: DuelEngine = d["engine"]
	var aussa := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Watery", 4, 1200, 800, "WATER"))
	var p0: ScriptedController = d["p0"]
	var asked_before := p0.seen_requests.size()

	t.is_true(_flip_summon(engine, aussa), "Aussa is Flip Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 1,
		"the Flip Summon itself still succeeds")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 0,
		"nothing changed control")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED), 0,
		"and the effect never became a Chain Link")
	t.eq(p0.seen_requests.size(), asked_before,
		"the controller was not asked a question with no possible answer")
	t.eq(engine.state.control_leases.size(), 0, "no lease exists")


# ---------------------------------------------------------------------------
# The duration: "while this card is face-up on the field"
# ---------------------------------------------------------------------------

static func _test_the_charmer_is_flipped_face_down(t: TestCase) -> void:
	t.start("control returns the moment Aussa is flipped FACE-DOWN — the duration is on "
		+ "Aussa, not on the borrowed monster")
	var d := _board(407)
	var engine: DuelEngine = d["engine"]
	var aussa: CardInstance = d["aussa"]
	var prey: CardInstance = d["prey"]
	# An interferer that can turn Aussa face-down mid-duel, driven by the opponent.
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Veil", aussa, "flip_face_down"), 0)

	t.is_true(_flip_summon(engine, aussa), "Aussa is Flip Summoned")
	t.eq(prey.controller_id, 0, "control was taken")

	var trap = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	if trap == null:
		TestFixtures.end_turn(engine)
		trap = TestFixtures.find_action(engine.get_legal_actions(1),
			Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(trap, "the opponent can act")
	t.is_true(engine.submit_action(trap), "and flips Aussa face-down")
	TestFixtures.pass_until_open(engine)

	t.is_false(aussa.is_face_up(), "Aussa is face-down")
	t.eq(prey.controller_id, 1, "so control has returned to its original controller")
	t.eq(prey.owner_id, 1, "the owner never changed at any point")
	t.is_true(engine.state.player(1).monsters().has(prey),
		"the monster is back in its own controller's Monster Zone")
	t.eq(engine.state.control_leases.size(), 0, "and the lease is over")


static func _test_the_charmer_leaves_the_field(t: TestCase) -> void:
	t.start("control returns when Aussa LEAVES the field, by any route")
	var d := _board(408)
	var engine: DuelEngine = d["engine"]
	var aussa: CardInstance = d["aussa"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Snipe", aussa, "destroy"), 0)

	t.is_true(_flip_summon(engine, aussa), "Aussa is Flip Summoned")
	t.eq(prey.controller_id, 0, "control was taken")

	var trap = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	if trap == null:
		TestFixtures.end_turn(engine)
		trap = TestFixtures.find_action(engine.get_legal_actions(1),
			Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(trap, "the opponent can act")
	t.is_true(engine.submit_action(trap), "and destroys Aussa")
	TestFixtures.pass_until_open(engine)

	t.eq(aussa.zone, Enums.Zone.GRAVEYARD, "Aussa is in the Graveyard")
	t.eq(prey.controller_id, 1, "so control has returned")
	t.is_true(engine.state.player(1).monsters().has(prey), "into its own Monster Zone")
	t.eq(engine.state.control_leases.size(), 0, "with no lease left behind")


static func _test_the_borrowed_monster_leaves_the_field(t: TestCase) -> void:
	t.start("the borrowed monster leaving the field ends the lease and sends it to its "
		+ "OWNER's Graveyard [S1 p.52]")
	var d := _board(409)
	var engine: DuelEngine = d["engine"]
	var aussa: CardInstance = d["aussa"]
	var prey: CardInstance = d["prey"]

	t.is_true(_flip_summon(engine, aussa), "Aussa is Flip Summoned")
	t.eq(prey.controller_id, 0, "control was taken")

	t.is_true(engine.state.destroy(prey, Enums.MoveReason.DESTROYED_BY_EFFECT, -1),
		"the borrowed monster is destroyed while player 0 controls it")
	t.is_true(engine.state.player(1).graveyard.has(prey),
		"it goes to player 1's Graveyard — the OWNER's")
	t.is_false(engine.state.player(0).graveyard.has(prey), "not the controller's")
	t.eq(engine.state.control_leases.size(), 0, "and the lease ended with it")
	t.is_true(aussa.is_face_up(), "Aussa is unaffected and stays on the field")


# ---------------------------------------------------------------------------
# Resolution-time re-checks
# ---------------------------------------------------------------------------

static func _test_the_target_became_illegal_before_resolution(t: TestCase) -> void:
	t.start("a target that left the field between activation and resolution is dropped: "
		+ "activation legality is never carried forward")
	# The opponent holds a Spell Speed 2 answer, so the window between the Flip effect
	# becoming Chain Link 1 and resolving is genuinely open. Without one the engine
	# auto-passes and resolves the whole Chain inside a single submit_action(), leaving no
	# moment at which the board could be changed.
	var d2 := _board(411)
	var engine2: DuelEngine = d2["engine"]
	var aussa2: CardInstance = d2["aussa"]
	var prey2: CardInstance = d2["prey"]
	TestFixtures.give_set_spell_trap(engine2, 1,
		TestFixtures.interferer("Escape", prey2, "banish"), 0)
	engine2.submit_action(TestFixtures.find_action(engine2.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, aussa2.id))
	# Walk the windows, answering with the interferer the moment it is offered.
	var guard := 0
	var interfered := false
	while guard < 16 and engine2.timing != DuelEngine.Timing.OPEN:
		guard += 1
		var resp = TestFixtures.find_action(engine2.get_legal_responses(1),
			Enums.ActionKind.ACTIVATE_CARD)
		if resp != null and not interfered:
			interfered = engine2.submit_action(resp)
			continue
		var waiting := engine2.waiting_player()
		if waiting == -1:
			break
		engine2.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting))
	t.is_true(interfered, "the opponent banished the target before the effect resolved")
	t.eq(prey2.zone, Enums.Zone.BANISHED, "the target is banished")
	t.eq(prey2.controller_id, 1, "and was never taken")
	t.eq(TestFixtures.count_events(engine2, GameEvent.Kind.CONTROL_CHANGED), 0,
		"no control change happened")
	t.eq(engine2.state.control_leases.size(), 0, "and no lease was created")
	t.is_true(aussa2.is_face_up(), "Aussa is still face-up, having simply done nothing")


static func _test_no_free_monster_zone(t: TestCase) -> void:
	t.start("with no free Monster Zone there is nowhere to take the monster to, so control "
		+ "does not change")
	var d := _duel(412)
	var engine: DuelEngine = d["engine"]
	var aussa := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	for i in range(PlayerState.MONSTER_ZONE_COUNT - 1):
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Filler %d" % i, 4, 100, 100))
	var prey := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1200, 800, "EARTH"))
	t.is_false(engine.state.player(0).has_free_monster_zone(),
		"player 0's field is full — Aussa herself occupies the fifth zone")

	t.is_true(_flip_summon(engine, aussa), "Aussa is Flip Summoned anyway")
	t.eq(prey.controller_id, 1, "but control does not change")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 0,
		"nothing was announced")
	t.eq(engine.state.control_leases.size(), 0, "and no lease was created")
	t.is_true(aussa.is_face_up(), "Aussa is face-up, having resolved without effect")


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

static func _test_it_targets_and_respects_targeting_protection(t: TestCase) -> void:
	t.start("because it TARGETS, a monster that cannot be targeted is not a candidate — "
		+ "the interaction the current wording creates")
	var d := _duel(413)
	var engine: DuelEngine = d["engine"]
	var aussa := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var open_prey := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Open", 4, 1200, 800, "EARTH"))
	var protected := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Shielded", 4, 1200, 800, "EARTH"))

	var ctx := ActivationRules.make_context(engine.state, aussa, _effect(), 0, null)
	var before := ActivationRules.legal_targets(ctx).map(func(c): return c.id)
	t.is_true(before.has(protected.id), "both EARTH monsters are candidates to begin with")
	t.eq(before.size(), 2, "two candidates")

	# `cannot_be_targeted` is owned by the continuous system, which is the only channel
	# allowed to write it. Batch 5 wired it into ActivationRules.legal_targets().
	var cont := ContinuousEffects.new(engine.state)
	cont.recompute()
	t.is_true(ContinuousEffects.restrict(protected, "cannot_be_targeted"),
		"the restriction is written through the system that owns it")
	var ctx2 := ActivationRules.make_context(engine.state, aussa, _effect(), 0, null)
	var after := ActivationRules.legal_targets(ctx2).map(func(c): return c.id)
	t.is_false(after.has(protected.id), "the protected monster is no longer a candidate")
	t.is_true(after.has(open_prey.id), "the unprotected one still is")
	t.eq(after.size(), 1, "exactly one candidate left")


static func _test_a_negated_flip_summon_never_triggers_it(t: TestCase) -> void:
	t.start("a NEGATED Flip Summon never flips Aussa face-up, so the Flip effect never "
		+ "triggers and no control is taken")
	var d := _board(414)
	var engine: DuelEngine = d["engine"]
	var aussa: CardInstance = d["aussa"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.summon_negator("Deny"), 0)

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, aussa.id))
	var counter = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(counter, "the opponent may negate the Flip Summon")
	t.is_true(engine.submit_action(counter), "and does")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SUMMON_NEGATED), 1,
		"the Flip Summon was negated")
	t.is_false(aussa.is_face_up(), "Aussa is still face-down")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		aussa.id), 0, "she was never flipped face-up")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 0,
		"so the Flip effect never fired")
	t.eq(prey.controller_id, 1, "and the opponent keeps their monster")
	t.eq(engine.state.control_leases.size(), 0, "no lease exists")

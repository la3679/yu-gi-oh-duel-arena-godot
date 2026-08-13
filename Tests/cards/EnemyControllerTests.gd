class_name EnemyControllerTests
extends RefCounted

## Per-card suite for `Enemy Controller`. Research/CARD_RULINGS.md R25.
##
##   "Activate 1 of these effects;
##    ● Target 1 face-up monster your opponent controls; change that target's battle
##      position.
##    ● Tribute 1 monster, then target 1 face-up monster your opponent controls; take
##      control of that target until the End Phase."
##
## Two bullets, two EffectDefs, tested separately and in full. The second bullet's duration
## is the one this suite exists to pin down: "until the End Phase" against an engine whose
## End Phase is TWO steps.


const CARD_UNDER_TEST := "Enemy Controller"

const POSITION := "change_battle_position"
const CONTROL := "tribute_and_take_control"


static func run() -> TestCase:
	var t := TestCase.new("EnemyControllerTests")
	_test_clause_shape(t)
	_test_target_legality(t)
	# --- bullet 1 ---
	_test_attack_to_defense(t)
	_test_defense_to_attack(t)
	_test_it_is_a_change_by_effect(t)
	_test_position_target_left_the_field(t)
	_test_position_target_flipped_face_down(t)
	# --- bullet 2 ---
	_test_the_tribute_is_a_cost(t)
	_test_no_legal_tribute(t)
	_test_takes_control(t)
	_test_control_expires_in_the_end_phase(t)
	_test_the_spell_leaving_the_field_does_not_end_it(t)
	_test_the_borrowed_monster_leaves_the_field(t)
	_test_control_target_left_the_field(t)
	_test_the_activation_is_negated_after_the_cost(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


static func _effect(effect_id: String) -> EffectDef:
	for entry in _def().effects:
		var e: EffectDef = entry
		if e.effect_id == effect_id:
			return e
	return null


## `turn_two` builds a duel in which player 0 is the turn player on turn TWO, which is the
## only way to reach the Battle Phase and therefore Main Phase 2: the Battle Phase is
## prohibited on turn 1 [S1 p.35], and without it `advance_to_phase(MAIN_2)` walks straight
## into the End Phase instead. Any test that cares WHEN in the turn something happens has to
## use it.
static func _duel(seed_value: int, turn_two: bool = false) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1 if turn_two else 0)
	if turn_two:
		TestFixtures.end_turn(d["engine"])
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Player 0 holds Enemy Controller in hand and controls one monster to Tribute; player 1
## controls one face-up monster. Returns {"engine", "p0", "p1", "ec", "fodder", "prey"}.
static func _board(seed_value: int,
		prey_position: Enums.Position = Enums.Position.FACE_UP_ATTACK,
		turn_two: bool = false) -> Dictionary:
	var d := _duel(seed_value, turn_two)
	var engine: DuelEngine = d["engine"]
	d["ec"] = TestFixtures.give_to_hand(engine, 0, _def())
	d["fodder"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 900, 900))
	d["prey"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1200, 800), prey_position)
	return d


static func _activate(engine: DuelEngine, ec: CardInstance, effect_id: String,
		target: CardInstance):
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ec.id, effect_id)
	if a == null:
		return null
	return a.with_choices({"target_ids": [target.id]})


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("\"Activate 1 of these effects\" — two bullets, two EffectDefs, and the player "
		+ "chooses between them at activation")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.st_kind, Enums.STKind.QUICK_PLAY_SPELL, "it is a Quick-Play Spell")
	t.eq(def.effects.size(), 2, "two EffectDefs, one per bullet")

	var pos := _effect(POSITION)
	var ctl := _effect(CONTROL)
	t.not_null(pos, "the battle-position bullet exists")
	t.not_null(ctl, "the take-control bullet exists")

	for entry in [pos, ctl]:
		var e: EffectDef = entry
		t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION,
			"%s is a card activation" % e.effect_id)
		t.eq(e.spell_speed, Enums.SpellSpeed.SS2,
			"%s is Spell Speed 2 — Quick-Play [S1 p.44]" % e.effect_id)
		t.is_true(e.targets, "%s targets" % e.effect_id)
		t.eq(e.target_count_min, 1, "%s targets exactly 1" % e.effect_id)
		t.eq(e.target_count_max, 1, "%s targets at most 1" % e.effect_id)
		t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
			"%s is NOT legal in the Damage Step: [S1 p.41] permits only Counter Traps, "
			% e.effect_id + "negation, and effects that directly change ATK/DEF")
		t.is_true(e.activation_locations.has(Enums.ActivationLocation.HAND),
			"%s is activatable from the hand" % e.effect_id)
		t.is_true(e.activation_locations.has(Enums.ActivationLocation.FIELD_FACE_DOWN),
			"%s is activatable from a Set copy" % e.effect_id)

	t.is_false(pos.pay_cost.is_valid(), "the first bullet has NO cost")
	t.is_true(ctl.pay_cost.is_valid(), "the second one does — \"Tribute 1 monster\"")
	t.is_true(ctl.clause_text.contains("until the End Phase"),
		"and its duration is part of the quoted official text")


static func _test_target_legality(t: TestCase) -> void:
	t.start("both bullets target a FACE-UP monster your OPPONENT controls, and nothing else")
	var d := _duel(501)
	var engine: DuelEngine = d["engine"]
	var ec := TestFixtures.give_to_hand(engine, 0, _def())
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Mine", 4, 900, 900))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1200, 800))
	var hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden", 4, 1200, 800), Enums.Position.FACE_DOWN_DEFENSE)

	for effect_id in [POSITION, CONTROL]:
		var ctx := ActivationRules.make_context(engine.state, ec, _effect(effect_id), 0, null)
		var legal := ActivationRules.legal_targets(ctx).map(func(c): return c.id)
		t.is_true(legal.has(theirs.id),
			"%s: the opponent's face-up monster is a candidate" % effect_id)
		t.is_false(legal.has(mine.id), "%s: your own monster is not" % effect_id)
		t.is_false(legal.has(hidden.id),
			"%s: the opponent's face-down monster is not" % effect_id)
		t.eq(legal.size(), 1, "%s: exactly one candidate" % effect_id)


# ---------------------------------------------------------------------------
# Bullet 1 — the battle position change
# ---------------------------------------------------------------------------

static func _test_attack_to_defense(t: TestCase) -> void:
	t.start("face-up Attack Position becomes face-up Defense Position")
	var d := _board(502, Enums.Position.FACE_UP_ATTACK)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]

	var a = _activate(engine, ec, POSITION, prey)
	t.not_null(a, "the battle-position bullet is offered")
	t.is_true(engine.submit_action(a), "and activated")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.position, Enums.Position.FACE_UP_DEFENSE, "the target is now in Defense")
	t.is_true(prey.is_face_up(), "still face-up — this is not a flip")
	t.eq(prey.controller_id, 1, "and its controller is unchanged: this bullet takes nothing")
	t.eq(engine.state.control_leases.size(), 0, "no control lease was created")
	t.eq(ec.zone, Enums.Zone.GRAVEYARD, "the resolved Quick-Play Spell went to the GY")


static func _test_defense_to_attack(t: TestCase) -> void:
	t.start("and face-up Defense Position becomes face-up Attack Position — \"change\" is "
		+ "the toggle, in both directions")
	var d := _board(503, Enums.Position.FACE_UP_DEFENSE)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]
	t.eq(prey.position, Enums.Position.FACE_UP_DEFENSE, "it starts in Defense")

	t.is_true(engine.submit_action(_activate(engine, ec, POSITION, prey)), "activated")
	TestFixtures.pass_until_open(engine)
	t.eq(prey.position, Enums.Position.FACE_UP_ATTACK, "it is now in Attack Position")


static func _test_it_is_a_change_by_effect(t: TestCase) -> void:
	t.start("the change is BY EFFECT: it does not spend the monster's once-per-turn manual "
		+ "position change, and is not blocked by the manual restrictions [S1 p.36]")
	var d := _board(504, Enums.Position.FACE_UP_ATTACK)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]
	t.is_false(prey.position_changed_this_turn, "no manual change has been made yet")

	t.is_true(engine.submit_action(_activate(engine, ec, POSITION, prey)), "activated")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.position, Enums.Position.FACE_UP_DEFENSE, "the position changed")
	t.is_false(prey.position_changed_this_turn,
		"but the manual once-per-turn allowance was NOT spent")
	var changes := TestFixtures.events_of(engine, GameEvent.Kind.BATTLE_POSITION_CHANGED)
	t.eq(changes.size(), 1, "one BATTLE_POSITION_CHANGED event")
	t.is_true(bool((changes[0] as GameEvent).data.get("by_effect", false)),
		"and it is flagged as by_effect, which is what makes the distinction real")
	t.eq(int((changes[0] as GameEvent).data.get("source_id", -1)), ec.id,
		"attributed to Enemy Controller")


static func _test_position_target_left_the_field(t: TestCase) -> void:
	t.start("a target that left the field before resolution: nothing happens, and the Spell "
		+ "still goes to the Graveyard")
	var d := _board(505)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]
	# The opponent holds a Spell Speed 2 answer, so a real window exists between Chain
	# Link 1 and its resolution.
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Escape", prey, "banish"), 0)

	t.is_true(engine.submit_action(_activate(engine, ec, POSITION, prey)),
		"Enemy Controller is Chain Link 1")
	var resp = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(resp, "the opponent may respond")
	t.is_true(engine.submit_action(resp), "and banishes the target")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.zone, Enums.Zone.BANISHED, "the target is gone")
	# Scoped to the target: activating the opponent's Set Trap flips that card face-up,
	# which is itself a BATTLE_POSITION_CHANGED and has nothing to do with this clause.
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.BATTLE_POSITION_CHANGED,
		prey.id), 0, "no position was changed on the target")
	t.eq(ec.zone, Enums.Zone.GRAVEYARD, "and the Spell still resolved and left the field")


static func _test_position_target_flipped_face_down(t: TestCase) -> void:
	t.start("a target flipped FACE-DOWN before resolution is no longer the thing the card "
		+ "named: nothing happens, and it is certainly not flipped back up")
	var d := _board(506)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Veil", prey, "flip_face_down"), 0)

	t.is_true(engine.submit_action(_activate(engine, ec, POSITION, prey)),
		"Enemy Controller is Chain Link 1")
	var resp = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(resp, "the opponent may respond")
	t.is_true(engine.submit_action(resp), "and turns the target face-down")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.position, Enums.Position.FACE_DOWN_DEFENSE, "the target is face-down")
	t.is_false(prey.is_face_up(), "and stayed that way")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP,
		prey.id), 0, "Enemy Controller did not flip it back up")


# ---------------------------------------------------------------------------
# Bullet 2 — Tribute, then take control until the End Phase
# ---------------------------------------------------------------------------

static func _test_the_tribute_is_a_cost(t: TestCase) -> void:
	t.start("\"Tribute 1 monster\" is a COST: paid at activation, from the monsters YOU "
		+ "control, and it reaches the Graveyard before the effect resolves")
	var d := _board(507)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var fodder: CardInstance = d["fodder"]
	var prey: CardInstance = d["prey"]

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ec.id, CONTROL)
	t.not_null(a, "the take-control bullet is offered")
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [prey.id]})),
		"and activated")

	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the Tribute was paid at activation, before resolution")
	t.eq(fodder.last_move_reason, Enums.MoveReason.TRIBUTED,
		"as a Tribute, which is not a destruction but IS sent to the GY [S1 p.53]")
	t.is_true(engine.state.player(0).graveyard.has(fodder),
		"into its own controller's Graveyard")
	TestFixtures.pass_until_open(engine)
	t.eq(prey.controller_id, 0, "and the effect then resolved")


static func _test_no_legal_tribute(t: TestCase) -> void:
	t.start("with no monster to Tribute the second bullet cannot be activated at all, while "
		+ "the first one still can — a cost that cannot be paid blocks the ACTIVATION")
	var d := _duel(508)
	var engine: DuelEngine = d["engine"]
	var ec := TestFixtures.give_to_hand(engine, 0, _def())
	var prey := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1200, 800))
	t.eq(engine.state.player(0).monsters().size(), 0, "player 0 controls no monster")

	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ec.id, CONTROL),
		"the take-control bullet is not offered")
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ec.id, POSITION),
		"but the battle-position bullet is — the two bullets are independent")

	# Positive control on the negative: give player 0 a monster and it appears.
	TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Fodder", 4, 900, 900))
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, ec.id, CONTROL),
		"with a monster to Tribute it IS offered, so it was the cost that blocked it")
	t.eq(prey.controller_id, 1, "and nothing has changed control along the way")


static func _test_takes_control(t: TestCase) -> void:
	t.start("it takes control of the target: CONTROLLER changes, OWNER does not")
	var d := _board(509)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]

	t.is_true(engine.submit_action(_activate(engine, ec, CONTROL, prey)), "activated")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.controller_id, 0, "player 0 controls it")
	t.eq(prey.owner_id, 1, "player 1 still OWNS it")
	t.is_true(engine.state.player(0).monsters().has(prey), "it is in player 0's zones")
	t.is_false(engine.state.player(1).monsters().has(prey), "and not in player 1's")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 1,
		"one control change was announced")
	var lease: Dictionary = engine.state.control_leases_for(prey.id)[0]
	t.eq(lease["duration"], Enums.ControlDuration.UNTIL_END_PHASE,
		"and its duration is UNTIL_END_PHASE, not the Charmers' \"while face-up\"")


static func _test_control_expires_in_the_end_phase(t: TestCase) -> void:
	t.start("control expires as the End Phase is ENTERED — before either step of this "
		+ "engine's two-step End Phase, and it stays expired afterwards")
	var d := _board(510, Enums.Position.FACE_UP_ATTACK, true)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]
	t.eq(engine.state.turn_number, 2, "turn 2, so the Battle Phase is available [S1 p.35]")

	t.is_true(engine.submit_action(_activate(engine, ec, CONTROL, prey)), "activated")
	TestFixtures.pass_until_open(engine)
	t.eq(prey.controller_id, 0, "control was taken in Main Phase 1")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the duel reaches the Battle Phase")
	t.eq(prey.controller_id, 0, "still controlled in the Battle Phase")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"and Main Phase 2")
	t.eq(prey.controller_id, 0, "and in Main Phase 2 — it lasts the whole turn")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(engine.state.phase, Enums.Phase.END, "the End Phase has been entered")
	t.eq(prey.controller_id, 1, "and control has ALREADY returned")
	t.is_true(engine.state.player(1).monsters().has(prey),
		"the monster is back in its own controller's Monster Zone")
	t.eq(engine.state.control_leases.size(), 0, "the lease is over")

	# The revert must precede the hand-size discard, which is the END of the End Phase.
	var revert_seq := -1
	var end_seq := -1
	for e in engine.state.events:
		if e.kind == GameEvent.Kind.CONTROL_CHANGED and bool(e.data.get("reverted", false)):
			revert_seq = e.sequence
		elif e.kind == GameEvent.Kind.PHASE_CHANGED and e.data.get("to") == Enums.Phase.END:
			end_seq = e.sequence
	t.is_true(end_seq >= 0, "the End Phase was announced")
	t.is_true(revert_seq > end_seq, "and the revert came after that announcement")

	TestFixtures.end_turn(engine)
	t.eq(prey.controller_id, 1, "control does not come back on the following turn")
	t.eq(prey.owner_id, 1, "and the owner was never touched at any point")


static func _test_the_spell_leaving_the_field_does_not_end_it(t: TestCase) -> void:
	t.start("the duration does not depend on Enemy Controller still being anywhere: a "
		+ "resolved Quick-Play Spell is in the Graveyard the whole time control lasts")
	var d := _board(511, Enums.Position.FACE_UP_ATTACK, true)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]

	t.is_true(engine.submit_action(_activate(engine, ec, CONTROL, prey)), "activated")
	TestFixtures.pass_until_open(engine)
	t.eq(ec.zone, Enums.Zone.GRAVEYARD,
		"Enemy Controller resolved and is already in the Graveyard")
	t.eq(prey.controller_id, 0, "yet control was taken and holds")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the duel reaches the Battle Phase")
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"and Main Phase 2")
	t.eq(prey.controller_id, 0,
		"and still holds later in the turn — this is not the Charmers' \"while this card "
		+ "is face-up on the field\" duration")
	t.eq(engine.state.control_leases.size(), 1, "the lease is still in force")


static func _test_the_borrowed_monster_leaves_the_field(t: TestCase) -> void:
	t.start("a borrowed monster destroyed or Tributed under this control still goes to its "
		+ "OWNER's Graveyard, and the lease simply ends [S1 p.52]")
	var d := _board(512)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var prey: CardInstance = d["prey"]

	t.is_true(engine.submit_action(_activate(engine, ec, CONTROL, prey)), "activated")
	TestFixtures.pass_until_open(engine)
	t.eq(prey.controller_id, 0, "control was taken")

	t.is_true(engine.state.destroy(prey, Enums.MoveReason.DESTROYED_BY_EFFECT, -1),
		"the borrowed monster is destroyed")
	t.is_true(engine.state.player(1).graveyard.has(prey),
		"it goes to player 1's Graveyard — the OWNER's")
	t.is_false(engine.state.player(0).graveyard.has(prey), "not the controller's")
	t.eq(engine.state.control_leases.size(), 0, "and the lease ended with it")

	# The End Phase must then be a no-op rather than trying to revert a card in the GY.
	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(prey.zone, Enums.Zone.GRAVEYARD, "it is still in the Graveyard in the End Phase")
	t.eq(prey.controller_id, 1, "reported as its owner's card")


static func _test_control_target_left_the_field(t: TestCase) -> void:
	t.start("a target that left the field before resolution takes nothing — and the "
		+ "Tribute is NOT refunded")
	var d := _board(513)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var fodder: CardInstance = d["fodder"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Escape", prey, "banish"), 0)

	t.is_true(engine.submit_action(_activate(engine, ec, CONTROL, prey)),
		"Enemy Controller is Chain Link 1")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the Tribute is already paid")
	var resp = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(resp, "the opponent may respond")
	t.is_true(engine.submit_action(resp), "and banishes the target")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.zone, Enums.Zone.BANISHED, "the target is gone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CONTROL_CHANGED), 0,
		"no control change happened")
	t.eq(engine.state.control_leases.size(), 0, "and no lease was created")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the Tribute stays paid — a cost is never refunded [RULES_SPEC.md §10]")


static func _test_the_activation_is_negated_after_the_cost(t: TestCase) -> void:
	t.start("the activation negated: no control is taken, and the Tribute is still gone")
	var d := _board(514)
	var engine: DuelEngine = d["engine"]
	var ec: CardInstance = d["ec"]
	var fodder: CardInstance = d["fodder"]
	var prey: CardInstance = d["prey"]
	TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Denied"), 0)

	t.is_true(engine.submit_action(_activate(engine, ec, CONTROL, prey)),
		"Enemy Controller is Chain Link 1")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the Tribute is paid at activation")
	var counter = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD)
	t.not_null(counter, "the opponent may negate the activation")
	t.is_true(engine.submit_action(counter), "and does")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"the activation was negated")
	t.eq(prey.controller_id, 1, "so no control was taken")
	t.eq(engine.state.control_leases.size(), 0, "and no lease exists")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the Tribute stays paid: costs are paid at activation and never refunded")
	t.eq(ec.zone, Enums.Zone.GRAVEYARD, "and Enemy Controller was destroyed by the negation")

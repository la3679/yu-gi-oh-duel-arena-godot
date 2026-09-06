class_name StraightFlushTests
extends RefCounted

## Per-card suite for `Straight Flush` — "If your opponent controls a card in each of their
## Spell & Trap Zones: Destroy all cards in their Spell & Trap Zones."
##
## The card asks one question twice — *what is a card in a Spell & Trap Zone?* — once as an
## activation condition and once as the set to destroy, and `CARD_RULINGS.md` R41 Part B
## settles the three cases that make the two answers non-obvious. All three are exercised
## against real mechanisms rather than asserted in prose:
##
##   * an **Equip Card** occupies one of the five, so it both fills a zone and is destroyed;
##   * a **Trap Monster** sitting in a Monster Zone does **not**, so it leaves a zone empty
##     and the card cannot be activated at all;
##   * the **Field Zone** is not one of the five, in either half — and the pool really does
##     contain a Field Spell, so that is a live distinction and not a hypothetical one.
##
## Every destruction claim is asserted on the `CARD_DESTROYED` event and the move reason, not
## on the destination: reaching a Graveyard is not the same as being destroyed [S1 p.52].

const CARD_UNDER_TEST := "Straight Flush"
const EFFECT_ID := "destroy_all_opponent_spell_trap_zones"


static func run() -> TestCase:
	var t := TestCase.new("StraightFlushTests")
	_test_clause_shape(t)
	_test_needs_all_five_zones_occupied(t)
	_test_destroys_all_five_and_nothing_else(t)
	_test_an_equip_card_fills_a_zone_and_is_destroyed(t)
	_test_a_trap_monster_empties_its_zone_and_forbids_activation(t)
	_test_the_field_zone_is_not_a_spell_trap_zone(t)
	_test_the_condition_is_not_rechecked_at_resolution(t)
	_test_a_prevented_destruction_leaves_the_others_destroyed(t)
	_test_effect_negation_destroys_nothing(t)
	_test_activation_negation_destroys_nothing(t)
	_test_it_never_touches_its_own_controllers_zones(t)
	_test_it_is_illegal_in_the_damage_step(t)
	_test_real_pool(t)
	_test_deterministic_replay(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _effect() -> EffectDef:
	var d := _card(CARD_UNDER_TEST)
	if d == null:
		return null
	for e in d.effects:
		if e.effect_id == EFFECT_ID:
			return e
	return null


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Fill `count` of `pid`'s five Spell & Trap Zones with plain Set Traps, and return them.
static func _fill_zones(engine: DuelEngine, pid: int, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		out.append(TestFixtures.give_set_spell_trap(engine, pid,
			TestFixtures.trap("Filler %d" % i)))
	return out


## Player 0 holds a Set `Straight Flush`; player 1 has `their_cards` of their five zones full.
static func _board(seed_value: int, their_cards: int = 5) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["flush"] = TestFixtures.give_set_spell_trap(engine, 0, _card(CARD_UNDER_TEST))
	d["theirs"] = _fill_zones(engine, 1, their_cards)
	return d


static func _offered(engine: DuelEngine, flush: CardInstance) -> bool:
	return TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, flush.id)


static func _indestructible_guard(card_name: String, ward: CardInstance) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, 1000, 1000)
	var e := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID,
		"Test: that card cannot be destroyed.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.condition = func(ctx: EffectContext) -> bool:
		var subject = ctx.params.get("card", null)
		return subject != null and (subject as CardInstance).id == ward.id
	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Straight Flush: one clause, a Normal Trap at Spell Speed 2, a condition, "
		+ "no target and no cost")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.TRAP, "it is a Trap")
	t.eq(d.st_kind, Enums.STKind.NORMAL_TRAP, "a NORMAL Trap")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION, "a CARD_ACTIVATION")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS2, "Spell Speed 2 — a Normal Trap")
	# cid 6911 states outright that it is not an effect that targets.
	t.is_false(e.targets, "officially it does NOT target")
	t.is_false(e.legal_targets.is_valid(), "so it publishes no candidate list")
	t.is_true(e.condition.is_valid(), "it has an activation condition")
	t.is_false(e.pay_cost.is_valid(), "and NO cost")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"activated from a Set Spell & Trap Zone only")
	t.eq(e.ruling_ref, "R41", "it cites the ruling that settled it")


# ---------------------------------------------------------------------------
# The condition
# ---------------------------------------------------------------------------

static func _test_needs_all_five_zones_occupied(t: TestCase) -> void:
	t.start("Straight Flush: 'a card in EACH of their Spell & Trap Zones' means all five — "
		+ "four is not enough, and the fifth is what turns it on")
	var d := _board(4201, 0)
	var engine: DuelEngine = d["engine"]
	var flush: CardInstance = d["flush"]

	for filled in range(0, PlayerState.SPELL_TRAP_ZONE_COUNT):
		t.is_false(_offered(engine, flush),
			"with %d of the opponent's five zones filled it is not offered" % filled)
		TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Filler %d" % filled))

	t.eq(engine.state.player(1).spell_traps().size(), PlayerState.SPELL_TRAP_ZONE_COUNT,
		"all five of their zones are now occupied")
	t.is_true(_offered(engine, flush), "and only now is it offered")


static func _test_destroys_all_five_and_nothing_else(t: TestCase) -> void:
	t.start("Straight Flush: destroys all five of the opponent's Spell & Trap Zone cards, "
		+ "and leaves their monsters and both hands alone")
	var d := _board(4202)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	var their_monster := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1800, 1000))
	var their_hand_card := TestFixtures.give_to_hand(engine, 1, TestFixtures.trap("Held"))

	t.is_true(TestFixtures.activate_card(engine, 0, d["flush"]), "activated and resolved")

	for entry in theirs:
		var card: CardInstance = entry
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 1,
			"%s raised exactly one CARD_DESTROYED event" % card.card_name())
		t.eq(card.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
			"%s was DESTROYED_BY_EFFECT" % card.card_name())
		t.eq(card.zone, Enums.Zone.GRAVEYARD, "%s is in the Graveyard" % card.card_name())
	t.eq(engine.state.player(1).spell_traps().size(), 0, "their zones are empty")
	t.eq(their_monster.zone, Enums.Zone.MONSTER_ZONE, "their monster is untouched")
	t.eq(their_hand_card.zone, Enums.Zone.HAND, "a Trap in their HAND is untouched")


# ---------------------------------------------------------------------------
# What counts as "a card in a Spell & Trap Zone" — R41 Part B
# ---------------------------------------------------------------------------

static func _test_an_equip_card_fills_a_zone_and_is_destroyed(t: TestCase) -> void:
	t.start("Straight Flush: an Equip Card equipped to a monster occupies a Spell & Trap "
		+ "Zone, so it fills the fifth AND is destroyed")
	var d := _board(4203, 4)
	var engine: DuelEngine = d["engine"]
	var flush: CardInstance = d["flush"]
	var host := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Equipped Host", 4, 1000, 1000))

	t.is_false(_offered(engine, flush), "four zones is not enough")

	# The Equip Card is placed by the ordinary equip route, not dropped into the zone.
	var equip := TestFixtures.give_to_hand(engine, 1,
		TestFixtures.equip_spell("Their Equip", 500))
	t.is_true(engine.state.equip_to(equip, host, -1), "it is equipped to their monster")
	t.eq(equip.zone, Enums.Zone.SPELL_TRAP_ZONE, "and it really sits in a Spell & Trap Zone")
	t.ne(equip.equipped_to_id, -1, "while genuinely being an Equip Card with a host")
	t.eq(engine.state.player(1).spell_traps().size(), 5, "so their five zones are full")

	t.is_true(_offered(engine, flush), "which is what makes the activation legal")
	t.is_true(TestFixtures.activate_card(engine, 0, flush), "activated and resolved")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, equip.id), 1,
		"the Equip Card was destroyed like any other card in those zones")
	t.eq(equip.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT,
		"DESTROYED_BY_EFFECT, not the DESTROYED_BY_RULE an Equip Card gets for losing a host")
	t.eq(host.zone, Enums.Zone.MONSTER_ZONE, "and its host monster is untouched")


static func _test_a_trap_monster_empties_its_zone_and_forbids_activation(t: TestCase) -> void:
	t.start("Straight Flush: a Trap Monster in a MONSTER Zone is not a card in a Spell & "
		+ "Trap Zone, so the fifth zone is empty and the card cannot be activated")
	var d := _board(4204, 4)
	var engine: DuelEngine = d["engine"]
	var flush: CardInstance = d["flush"]
	var shifter := TestFixtures.give(engine, 1,
		TestFixtures.trap_monster("Apophis Stand-In", "Reptile", "EARTH", 4, 1600, 1800,
			true, false, Enums.Position.FACE_UP_ATTACK, false, Enums.Zone.SPELL_TRAP_ZONE),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	# While it is still in its Spell & Trap Zone it fills the fifth like anything else.
	t.eq(engine.state.player(1).spell_traps().size(), 5, "five zones are occupied")
	t.is_true(_offered(engine, flush), "so the activation is offered")

	# Now it becomes a monster, vacating the zone. The Quick Effect belongs to the player who
	# is NOT the turn player, so it needs a real response window: an ordinary Chain Link 1
	# from the turn player opens one.
	var order: Array = []
	var bait := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.with_effect(
		TestFixtures.trap("Bait"),
		TestFixtures.card_activation("bait", Enums.SpellSpeed.SS2, order)))
	var opened = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, bait.id)
	t.not_null(opened, "the bait Trap can be activated")
	if opened == null:
		return
	t.is_true(engine.submit_action(opened), "it becomes Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_EFFECT, shifter.id, "summon_self_as_trap_monster")
	t.not_null(response, "the Trap Monster's Quick Effect can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it Special Summons itself as a monster")
	TestFixtures.pass_until_open(engine)
	t.eq(order, ["bait"], "and the whole Chain really resolved")
	t.eq(shifter.zone, Enums.Zone.MONSTER_ZONE, "it is in a Monster Zone now")
	t.is_true(shifter.is_monster(), "and answers as a monster")
	t.is_true(shifter.is_on_field(), "it is still a card the opponent controls…")
	t.eq(engine.state.player(1).spell_traps().size(), 4,
		"…but only FOUR of their Spell & Trap Zones are occupied")

	t.is_false(_offered(engine, flush),
		"so `Straight Flush` cannot be activated at all — cid 6911 says exactly this")
	# The same claim asked of the legality gate directly, so it cannot be satisfied by some
	# other reason the action list happened to drop it.
	var e := _effect()
	if e != null:
		t.is_false(ActivationRules.can_activate(engine.state, flush, e, 0),
			"and the legality gate itself refuses it")


static func _test_the_field_zone_is_not_a_spell_trap_zone(t: TestCase) -> void:
	t.start("Straight Flush: the Field Zone is neither counted by the condition nor "
		+ "destroyed by the resolution")
	var d := _board(4205, 4)
	var engine: DuelEngine = d["engine"]
	var flush: CardInstance = d["flush"]
	var field_spell := TestFixtures.give(engine, 1,
		TestFixtures.spell("Their Field Spell", Enums.STKind.FIELD_SPELL),
		Enums.Zone.FIELD_ZONE, Enums.Position.FACE_UP)

	t.eq(field_spell.zone, Enums.Zone.FIELD_ZONE, "it sits in the Field Zone")
	t.eq(engine.state.player(1).spell_traps().size(), 4,
		"which is NOT one of the five Spell & Trap Zones")
	t.is_false(_offered(engine, flush),
		"so a Field Spell does not fill the fifth zone and the card stays unactivatable")

	# Fill the real fifth zone, then check the Field Spell survives the resolution.
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("The Real Fifth"))
	t.is_true(TestFixtures.activate_card(engine, 0, flush), "now it activates and resolves")
	t.eq(engine.state.player(1).spell_traps().size(), 0, "the five zones were emptied")
	t.eq(field_spell.zone, Enums.Zone.FIELD_ZONE, "and the Field Spell was NOT destroyed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		field_spell.id), 0, "no CARD_DESTROYED event was raised for it")


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

static func _test_the_condition_is_not_rechecked_at_resolution(t: TestCase) -> void:
	t.start("Straight Flush: the condition is before the colon, so a card leaving one of "
		+ "those zones in response does NOT stop it — the remaining four are destroyed")
	var d := _board(4206)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	var escapee: CardInstance = theirs[0]
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", escapee, "bounce"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["flush"].id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.not_null(response, "a response window is open")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "Chain Link 2 returns one of them to the hand")
	TestFixtures.pass_until_open(engine)

	# The prerequisite: one really did leave, so the condition no longer holds.
	t.eq(escapee.zone, Enums.Zone.HAND, "it left the field before resolution")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, escapee.id), 0,
		"and it was NOT destroyed — it was not there to destroy")
	# …and the rest was destroyed anyway.
	for i in range(1, theirs.size()):
		var card: CardInstance = theirs[i]
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 1,
			"%s was destroyed anyway" % card.card_name())
	t.eq(engine.state.player(1).spell_traps().size(), 0, "their zones ended up empty")


static func _test_a_prevented_destruction_leaves_the_others_destroyed(t: TestCase) -> void:
	t.start("Straight Flush: one protected card survives and the other four are still "
		+ "destroyed — the destructions are independent")
	var d := _board(4207)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	var warded: CardInstance = theirs[2]
	TestFixtures.give_monster_on_field(engine, 1,
		_indestructible_guard("Warding Guard", warded))

	t.is_true(TestFixtures.activate_card(engine, 0, d["flush"]), "activated and resolved")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, warded.id), 0,
		"the protected card was not destroyed")
	t.eq(warded.zone, Enums.Zone.SPELL_TRAP_ZONE, "and is still in its zone")
	var destroyed := 0
	for entry in theirs:
		var card: CardInstance = entry
		if card != warded:
			t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
				card.id), 1, "%s was destroyed" % card.card_name())
			destroyed += 1
	t.eq(destroyed, 4, "exactly four of the five were destroyed")
	t.eq(engine.state.player(1).spell_traps().size(), 1, "one zone is still occupied")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

static func _test_effect_negation_destroys_nothing(t: TestCase) -> void:
	t.start("Straight Flush: a negated EFFECT destroys nothing at all")
	var d := _board(4208)
	var engine: DuelEngine = d["engine"]
	var theirs: Array = d["theirs"]
	# The opponent's own five zones are all full, so the negator belongs on the CONTROLLER's
	# side — which is fine, because negation does not care whose card it negates, and the
	# question here is only what the negated effect does.
	t.eq(engine.state.player(1).spell_traps().size(), PlayerState.SPELL_TRAP_ZONE_COUNT,
		"the opponent's five zones are full, which is why the negator goes on the other side")
	var real_negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.effect_negator("Effect Negator"))
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["flush"].id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, real_negator.id)
	t.not_null(response, "the negator can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(real_negator.zone, Enums.Zone.GRAVEYARD, "the negator resolved")
	t.eq(engine.state.player(1).spell_traps().size(), PlayerState.SPELL_TRAP_ZONE_COUNT,
		"all five of their cards are still there")
	for entry in theirs:
		var card: CardInstance = entry
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 0,
			"%s raised no CARD_DESTROYED event" % card.card_name())


static func _test_activation_negation_destroys_nothing(t: TestCase) -> void:
	t.start("Straight Flush: a negated ACTIVATION destroys nothing, and the Trap itself is "
		+ "destroyed by the Counter Trap")
	var d := _board(4209)
	var engine: DuelEngine = d["engine"]
	var flush: CardInstance = d["flush"]
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.activation_negator("Activation Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, flush.id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the Counter Trap can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, flush.id), 1,
		"the negated Trap itself was destroyed")
	t.eq(flush.last_move_reason, Enums.MoveReason.DESTROYED_BY_EFFECT, "by the Counter Trap")
	t.eq(engine.state.player(1).spell_traps().size(), PlayerState.SPELL_TRAP_ZONE_COUNT,
		"and the opponent's five cards are untouched")


# ---------------------------------------------------------------------------
# Scope, and the Damage Step
# ---------------------------------------------------------------------------

static func _test_it_never_touches_its_own_controllers_zones(t: TestCase) -> void:
	t.start("Straight Flush: 'their' Spell & Trap Zones means the OPPONENT's — the "
		+ "controller's own cards are never counted and never destroyed")
	var d := _duel(4210)
	var engine: DuelEngine = d["engine"]
	var flush := TestFixtures.give_set_spell_trap(engine, 0, _card(CARD_UNDER_TEST))
	# Player 0's own zones are as full as they can be; the opponent's are empty.
	var mine := _fill_zones(engine, 0, PlayerState.SPELL_TRAP_ZONE_COUNT - 1)
	t.eq(engine.state.player(0).spell_traps().size(), PlayerState.SPELL_TRAP_ZONE_COUNT,
		"the controller's own five zones are full, counting the Set Straight Flush")
	t.is_false(_offered(engine, flush),
		"which does not satisfy the condition — it names the OPPONENT's zones")

	# Now fill the opponent's five as well and resolve.
	var theirs := _fill_zones(engine, 1, PlayerState.SPELL_TRAP_ZONE_COUNT)
	t.is_true(TestFixtures.activate_card(engine, 0, flush), "now it activates and resolves")
	for entry in theirs:
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
			(entry as CardInstance).id), 1, "their card was destroyed")
	for entry in mine:
		var card: CardInstance = entry
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, card.id), 0,
			"%s — the controller's own card — was NOT destroyed" % card.card_name())
		t.eq(card.zone, Enums.Zone.SPELL_TRAP_ZONE, "and is still in its zone")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, flush.id), 0,
		"and it did not destroy itself")
	t.eq(flush.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"it left as a RESOLVED Normal Trap")


static func _test_it_is_illegal_in_the_damage_step(t: TestCase) -> void:
	t.start("Straight Flush: cid 6911 says it cannot be activated in the Damage Step, which "
		+ "is the engine default and is asserted at the rules layer")
	var d := _board(4211)
	var engine: DuelEngine = d["engine"]
	var e := _effect()
	t.not_null(e, "the clause is reachable")
	if e == null:
		return
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"no Damage Step permission is declared")
	# Asked of the rules layer at the sub-step, not by looking at what is offered mid-attack:
	# the window straight after an attack declaration is the BATTLE step, where a Spell Speed
	# 2 Trap is perfectly legal.
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_false(ActivationRules.damage_step_ok(engine.state, e),
		"the rules layer refuses it inside the Damage Step")
	engine.state.battle_step = Enums.BattleStep.NONE
	engine.state.damage_substep = Enums.DamageSubStep.NONE
	t.is_true(ActivationRules.damage_step_ok(engine.state, e),
		"while outside it the same question says yes")


# ---------------------------------------------------------------------------
# The real pool, and determinism
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Straight Flush: it is in deck 1, and the pool really contains the Equip Cards "
		+ "and the Trap Monster its two special cases depend on")
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the card database is readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	t.is_true(parsed is Dictionary and parsed.has("cards"), "and parses")
	if not (parsed is Dictionary and parsed.has("cards")):
		return
	var decks: Array = []
	var printed_equip_spells := 0
	for entry in parsed["cards"]:
		if str(entry.get("name", "")) == CARD_UNDER_TEST:
			decks = entry.get("decks", [])
		if str(entry.get("icon", "")) == "Equip Spell":
			printed_equip_spells += 1
	t.is_true(decks.has("Blue-Eyes Dragon Guard"), "it is in deck 1")

	# The two live special cases, asserted against the implemented library rather than prose.
	#
	# The pool contains NO printed Equip SPELL. Its Equip Cards are a Normal Trap, a
	# Continuous Spell and another Normal Trap that BECOME Equip Cards when they resolve —
	# which is exactly why the equipped-card case is asked of `equip_to()` and the zone, and
	# never of the printed icon.
	t.eq(printed_equip_spells, 0, "the pool contains no printed Equip Spell")
	var lib: Dictionary = CardRegistry.load_library()["cards"]
	for equipper in ["Gagagashield", "Kunai with Chain", "Castle of Dragon Souls"]:
		t.is_true(lib.has(equipper),
			"%s is in the pool and becomes an Equip Card, so the case is live" % equipper)
	t.is_true(lib.has("The Phantom Knights of Shadow Veil"),
		"and the pool's Trap Monster exists, so the vacated-zone case is live")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("Straight Flush: the same seed and the same actions produce the same result")
	var results: Array = []
	for _i in range(2):
		var d := _board(4212)
		var engine: DuelEngine = d["engine"]
		TestFixtures.activate_card(engine, 0, d["flush"])
		results.append({
			"their_zones": engine.state.player(1).spell_traps().size(),
			"my_zones": engine.state.player(0).spell_traps().size(),
			"destroyed": TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["their_zones"], results[1]["their_zones"], "their zone counts match")
	t.eq(results[0]["my_zones"], results[1]["my_zones"], "the controller's do too")
	t.eq(results[0]["destroyed"], results[1]["destroyed"], "the destruction counts match")
	t.eq(results[0]["events"], results[1]["events"], "and the whole event stream matches")

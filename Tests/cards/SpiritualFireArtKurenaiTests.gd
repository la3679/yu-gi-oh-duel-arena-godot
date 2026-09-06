class_name SpiritualFireArtKurenaiTests
extends RefCounted

## `Spiritual Fire Art - Kurenai` — "Tribute 1 FIRE monster; inflict damage to your
## opponent equal to that monster's original ATK."
##
## The sibling of `Spiritual Wind Art - Miyabi`: the same Tribute COST with a different
## Attribute, and a completely different second half. This suite asserts the shared half
## against Miyabi's shape and the differing half hardest of all —
##
##   * the damage is the **printed** ATK, never the runtime one (CARD_RULINGS R42 Part A);
##   * it is measured on the monster that was actually **Tributed**, not on whatever is
##     left on the board when the link resolves;
##   * a **0** printed ATK is a legal Tribute that inflicts **0** — the vacuous path is
##     asserted rather than guarded away.

const CARD_UNDER_TEST := "Spiritual Fire Art - Kurenai"
const BACK_UP_RIDER := "Back-Up Rider"

## `Inari Fire` is the one FIRE monster in this card's own deck. Both numbers are read from
## the printed card by `_printed_atk()` rather than trusted from here; the constant exists
## so a test can say what it expects.
const INARI_FIRE := "Inari Fire"
const INARI_FIRE_PRINTED_ATK := 1500

const BACK_UP_RIDER_GAIN := 1500


static func run() -> TestCase:
	var t := TestCase.new("SpiritualFireArtKurenaiTests")
	_test_the_clause_shape(t)
	_test_the_field_attribute_predicate_itself(t)
	_test_it_inflicts_the_tributed_monsters_printed_atk(t)
	_test_it_damages_the_opponent_and_never_its_controller(t)
	_test_the_damage_tracks_the_monster_actually_tributed(t)
	_test_a_boosted_atk_is_ignored_the_printed_value_is_used(t)
	_test_a_lowered_atk_is_ignored_too(t)
	_test_the_tribute_is_a_cost_paid_at_activation(t)
	_test_a_face_down_fire_monster_is_a_legal_tribute(t)
	_test_a_fire_trap_monster_is_a_legal_tribute_with_its_granted_atk(t)
	_test_zero_printed_atk_is_legal_and_inflicts_zero(t)
	_test_the_damage_can_end_the_duel(t)
	_test_it_cannot_be_activated_without_a_fire_monster(t)
	_test_a_non_fire_monster_is_not_a_legal_tribute(t)
	_test_an_opponents_fire_monster_is_not_a_legal_tribute(t)
	_test_the_cost_is_not_refunded_when_the_activation_is_negated(t)
	_test_the_cost_is_not_refunded_when_the_effect_is_negated(t)
	_test_the_tribute_is_not_a_destruction(t)
	_test_it_is_illegal_in_the_damage_step(t)
	_test_the_trap_leaves_as_a_resolved_normal_trap(t)
	_test_it_is_live_against_the_real_printed_pool(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.new().load_library()


static func _card_def(t: TestCase, card_name: String = CARD_UNDER_TEST) -> CardDef:
	var lib := _library()
	t.eq(lib["errors"], [], "the card library loads with no errors")
	var cards: Dictionary = lib["cards"]
	t.is_true(cards.has(card_name), "the registry knows %s" % card_name)
	return cards[card_name]


static func _effect(t: TestCase) -> EffectDef:
	var def := _card_def(t)
	return def.effects[0] if not def.effects.is_empty() else null


static func _fire(name: String, atk: int = 1200) -> CardDef:
	return TestFixtures.monster(name, 4, atk, 1000, "FIRE")


## A duel in Main Phase 1 with the Trap Set on player 0 and one FIRE monster to Tribute.
static func _board(t: TestCase, seed_value: int, atk: int = 1200) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["kurenai"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	d["fire"] = TestFixtures.give_monster_on_field(engine, 0, _fire("My Fire Monster", atk))
	return d


static func _printed_atk(t: TestCase, card_name: String) -> int:
	var def := _card_def(t, card_name)
	return def.base_atk


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal Trap card activation, Spell Speed 2, a Tribute COST, and "
		+ "NO targeting")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.TRAP, "it is a Trap")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP, "and specifically a NORMAL Trap")
	t.eq(def.effects.size(), 1, "exactly one EffectDef, for the card's one clause")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2")
	t.is_false(clause.targets,
		"it does NOT target — the word never appears in the official text")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Trap is activated from a Set position, never from the hand")
	t.eq(clause.damage_step_permission, Enums.DamageStepPermission.NONE,
		"cid 6441: it cannot be activated in the Damage Step")
	t.is_true(clause.can_pay_cost.is_valid(), "it declares a cost check")
	t.is_true(clause.pay_cost.is_valid(), "and a cost payment, so the Tribute is a COST")
	t.is_true(clause.clause_text.contains("Tribute 1 FIRE monster"),
		"the clause quotes the official cost")
	t.is_true(clause.clause_text.contains("original ATK"),
		"and quotes ORIGINAL ATK specifically, which is the whole trap in the card")


static func _test_the_field_attribute_predicate_itself(t: TestCase) -> void:
	t.start("`field_monster_of_attribute()` answers on BOTH halves of its name: it requires "
		+ "the Attribute AND requires the card to currently be a monster")
	var predicate := EffectPrimitives.field_monster_of_attribute("FIRE")
	var d := TestFixtures.new_duel(8120, 0)
	var engine: DuelEngine = d["engine"]

	var fire := TestFixtures.give_monster_on_field(engine, 0, _fire("Plain Fire", 1000))
	t.is_true(predicate.call(fire), "a FIRE monster on the field matches")

	var water := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Plain Water", 4, 1000, 1000, "WATER"))
	t.is_false(predicate.call(water), "a WATER monster does not")

	# The `is_monster()` half, which the Attribute half alone cannot cover. A Trap that
	# merely CARRIES an Attribute on its CardDef is still not a monster, and a predicate
	# that only compared Attributes would wrongly accept it. Nothing in the V1 pool is
	# shaped like this, which is exactly why it needs a fixture rather than a real card.
	var odd_trap := TestFixtures.trap("Fire-Flavoured Trap")
	odd_trap.attribute = "FIRE"
	var set_trap := TestFixtures.give_set_spell_trap(engine, 0, odd_trap)
	t.eq(set_trap.current_attribute(), "FIRE",
		"the Trap really does report a FIRE Attribute")
	t.is_false(set_trap.is_monster(), "but it is not a monster")
	t.is_false(predicate.call(set_trap),
		"so the predicate rejects it — both halves are load-bearing")

	# And the control: the same predicate with an empty Attribute is not what this card
	# uses, and would accept the WATER monster.
	var any_attribute := EffectPrimitives.field_monster_of_attribute("")
	t.is_false(any_attribute.call(water),
		"an empty Attribute matches nothing rather than everything — it compares equal to "
		+ "no real monster's Attribute")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_it_inflicts_the_tributed_monsters_printed_atk(t: TestCase) -> void:
	t.start("it inflicts damage equal to the Tributed monster's printed ATK")
	var d := _board(t, 8101, 1200)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	var before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]),
		"the Trap is activated with no target")
	t.eq(fire.zone, Enums.Zone.GRAVEYARD, "the FIRE monster was Tributed")
	t.eq(engine.state.player(1).life_points, before - 1200,
		"the opponent lost exactly the monster's 1200 printed ATK")


static func _test_it_damages_the_opponent_and_never_its_controller(t: TestCase) -> void:
	t.start("the damage goes to the OPPONENT; the controller's own Life Points do not move")
	var d := _board(t, 8102, 900)
	var engine: DuelEngine = d["engine"]
	var own_before: int = engine.state.player(0).life_points
	var their_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]), "activated")
	t.eq(engine.state.player(0).life_points, own_before,
		"the controller took nothing at all")
	t.eq(engine.state.player(1).life_points, their_before - 900,
		"and the opponent took 900")


static func _test_the_damage_tracks_the_monster_actually_tributed(t: TestCase) -> void:
	t.start("with two FIRE monsters of different ATK the player chooses, and the damage is "
		+ "the CHOSEN one's printed ATK — not the other's, and not a board-wide guess")
	var d := _board(t, 8103, 1200)
	var engine: DuelEngine = d["engine"]
	var weak: CardInstance = d["fire"]
	var strong := TestFixtures.give_monster_on_field(engine, 0, _fire("Stronger Fire", 2400))
	var p0: ScriptedController = d["p0"]
	var before: int = engine.state.player(1).life_points
	# Two candidates, so a real question is asked — `choose_n` asks nothing when the number
	# of candidates equals the number required.
	p0.queue_for(Enums.DecisionKind.CHOOSE_TRIBUTES, [strong.id])

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]), "activated")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(strong.zone, Enums.Zone.GRAVEYARD, "the CHOSEN monster was Tributed")
	t.eq(weak.zone, Enums.Zone.MONSTER_ZONE, "the other one is untouched on the field")
	t.eq(engine.state.player(1).life_points, before - 2400,
		"and the damage is 2400 — the Tributed monster's ATK, not the survivor's 1200")


static func _test_a_boosted_atk_is_ignored_the_printed_value_is_used(t: TestCase) -> void:
	t.start("CARD_RULINGS R42 Part A: a monster boosted by the real `Back-Up Rider` and "
		+ "then Tributed deals its PRINTED ATK, not the boosted figure")
	var d := _board(t, 8104, 1200)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	var rider := TestFixtures.give_to_hand(engine, 0, _card_def(t, BACK_UP_RIDER))
	var before: int = engine.state.player(1).life_points

	# The real card, activated through the real engine — this is an interaction test, not a
	# hand-rolled modifier.
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, rider.id)
	t.not_null(offered, "Back-Up Rider is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [fire.id]})),
		"and is activated on the FIRE monster")
	TestFixtures.pass_until_open(engine)
	t.eq(fire.current_atk(), 1200 + BACK_UP_RIDER_GAIN,
		"its RUNTIME ATK really is 2700 — the boost is genuinely applied")
	t.eq(fire.original_atk(), 1200, "while its ORIGINAL ATK is still 1200")

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]), "Kurenai is activated")
	t.eq(engine.state.player(1).life_points, before - 1200,
		"the damage is 1200, the PRINTED value")
	t.ne(engine.state.player(1).life_points, before - (1200 + BACK_UP_RIDER_GAIN),
		"and emphatically NOT 2700, which current_atk() would have produced")


static func _test_a_lowered_atk_is_ignored_too(t: TestCase) -> void:
	t.start("the reading is `original ATK`, not `the higher of the two`: a monster whose "
		+ "runtime ATK was LOWERED still deals its printed ATK")
	var d := _board(t, 8105, 1800)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	fire.add_atk_modifier(-1, -1000, "end_of_turn", "test_penalty")
	var before: int = engine.state.player(1).life_points
	t.eq(fire.current_atk(), 800, "its runtime ATK really is 800")

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]), "activated")
	t.eq(engine.state.player(1).life_points, before - 1800,
		"the damage is the printed 1800, not the lowered 800")


static func _test_the_tribute_is_a_cost_paid_at_activation(t: TestCase) -> void:
	t.start("the Tribute is a COST: it is paid at ACTIVATION, before the Chain Link "
		+ "resolves, and no damage happens until resolution")
	var d := _board(t, 8106, 1200)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	var before: int = engine.state.player(1).life_points
	var order_log: Array = []
	var spacer := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.with_effect(
		TestFixtures.trap("Spacer"),
		TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["kurenai"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is activated as Chain Link 1")

	t.eq(fire.zone, Enums.Zone.GRAVEYARD,
		"the Tributed monster is ALREADY in the Graveyard, before any resolution")
	t.eq(fire.last_move_reason, Enums.MoveReason.TRIBUTED,
		"with the TRIBUTED reason — a Tribute is a send to the GY, not a destruction "
		+ "[S1 p.53]")
	t.eq(engine.state.player(1).life_points, before,
		"while the opponent has taken NO damage yet — that is the effect, not the cost")

	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, spacer.id)
	t.not_null(response, "a response window is genuinely open")
	t.is_true(engine.submit_action(response), "the spacer is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(1).life_points, before - 1200,
		"and only then is the damage inflicted")


static func _test_a_face_down_fire_monster_is_a_legal_tribute(t: TestCase) -> void:
	t.start("cid 6441 (表示形式を問わず): a face-DOWN FIRE monster is a legal Tribute, and "
		+ "its printed ATK is still what is inflicted")
	var d := TestFixtures.new_duel(8107, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var kurenai := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var hidden := TestFixtures.give_monster_on_field(engine, 0, _fire("Set Fire", 1600),
		Enums.Position.FACE_DOWN_DEFENSE)
	var before: int = engine.state.player(1).life_points
	t.is_true(hidden.is_face_down(), "the monster really is face-down")

	t.is_true(TestFixtures.activate_card(engine, 0, kurenai),
		"the Trap is activated with only a face-down FIRE monster to pay with")
	t.eq(hidden.zone, Enums.Zone.GRAVEYARD, "the face-down monster was Tributed")
	t.eq(engine.state.player(1).life_points, before - 1600,
		"and the damage is its printed 1600 — being Set hides it from the opponent, not "
		+ "from its own controller")


static func _test_a_fire_trap_monster_is_a_legal_tribute_with_its_granted_atk(
		t: TestCase) -> void:
	t.start("a FIRE Trap Monster is a legal Tribute, and the damage is the ATK its granting "
		+ "text gave it — the two readers this card must not get wrong, in one test")
	var d := TestFixtures.new_duel(8119, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var kurenai := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	# ATK 800 rather than the fixture's default 0, so the number is distinguishable both
	# from "nothing happened" and from the Trap CardDef's printed 0.
	var veil := TestFixtures.give(engine, 0, TestFixtures.trap_monster("Fire Veil",
		"Pyro", "FIRE", 4, 800, 300), Enums.Zone.GRAVEYARD)
	var before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_effect(engine, 0, veil, "summon_self_as_trap_monster"),
		"the Trap Monster Summons itself out of the Graveyard")
	t.is_true(veil.is_monster(), "it is now a monster")
	t.eq(veil.current_attribute(), "FIRE",
		"whose Attribute lives in its RUNTIME identity — the printed CardDef has none")
	t.eq(veil.definition.attribute, "",
		"the printed CardDef really is blank, which is what makes this test bite")
	t.eq(veil.original_atk(), 800, "and its granted ATK is 800 while it is on the field")

	# Reader one: the candidate list must see a FIRE monster here at all.
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kurenai.id),
		"so it IS a legal Tribute for the FIRE cost")
	t.is_true(TestFixtures.activate_card(engine, 0, kurenai), "and the Trap is activated")

	# Reader two: the ATK must have been read while it was still a monster.
	t.eq(veil.zone, Enums.Zone.GRAVEYARD, "the Trap Monster was Tributed")
	t.is_false(veil.is_monster(), "and it is a plain Trap again in the Graveyard")
	t.eq(veil.original_atk(), 0,
		"its granted ATK is GONE now — reading it at resolution would have said 0")
	t.eq(engine.state.player(1).life_points, before - 800,
		"but the damage is 800, because the cost read it while it was still a monster")


# ---------------------------------------------------------------------------
# The vacuous path, asserted rather than guarded away
# ---------------------------------------------------------------------------

static func _test_zero_printed_atk_is_legal_and_inflicts_zero(t: TestCase) -> void:
	t.start("a FIRE monster with 0 printed ATK is a LEGAL Tribute and inflicts 0 damage — "
		+ "the card says `equal to`, not `if any`, so this must not become a no-op guard "
		+ "that silently swallows the whole clause")
	var d := _board(t, 8108, 0)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	var before: int = engine.state.player(1).life_points
	t.eq(fire.original_atk(), 0, "the monster really has 0 printed ATK")

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]),
		"the activation is legal — nothing forbids a 0-ATK Tribute")
	# The three things that separate "resolved for 0" from "did not happen at all":
	t.eq(fire.zone, Enums.Zone.GRAVEYARD, "the cost was really paid")
	t.eq(fire.last_move_reason, Enums.MoveReason.TRIBUTED, "as a Tribute")
	t.eq(d["kurenai"].zone, Enums.Zone.GRAVEYARD, "and the Trap really resolved and left")
	t.eq(engine.state.player(1).life_points, before,
		"while the opponent lost exactly nothing")
	t.eq(engine.state.player(0).life_points, 8000,
		"and so did the controller — 0 damage is 0 in both directions")


static func _test_the_damage_can_end_the_duel(t: TestCase) -> void:
	t.start("the damage is real effect damage and can win the Duel outright")
	var d := _board(t, 8109, 2000)
	var engine: DuelEngine = d["engine"]
	engine.state.player(1).life_points = 2000
	t.is_false(engine.state.is_duel_over(), "the Duel is running before the activation")

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]), "activated")
	t.eq(engine.state.player(1).life_points, 0, "the opponent is on exactly 0 LP")
	t.is_true(engine.state.is_duel_over(), "and the Duel is over")
	t.eq(engine.state.result, Enums.DuelResult.PLAYER_0_WINS,
		"won by the card's controller")
	t.eq(engine.state.end_reason, Enums.EndReason.LP_ZERO, "by Life Points reaching zero")


# ---------------------------------------------------------------------------
# Negative behaviour
# ---------------------------------------------------------------------------

static func _test_it_cannot_be_activated_without_a_fire_monster(t: TestCase) -> void:
	t.start("with no FIRE monster on your field the cost cannot be paid, so the card is "
		+ "not offered at all")
	var d := TestFixtures.new_duel(8110, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var kurenai := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kurenai.id),
		"an empty field offers no activation")
	t.eq(kurenai.zone, Enums.Zone.SPELL_TRAP_ZONE, "and the Trap is still Set")


static func _test_a_non_fire_monster_is_not_a_legal_tribute(t: TestCase) -> void:
	t.start("a WATER monster is not a legal Tribute for the FIRE cost — the Attribute is "
		+ "read, not merely the fact that a monster exists")
	var d := TestFixtures.new_duel(8111, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var kurenai := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var water := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Water Monster", 4, 1900, 1000, "WATER"))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kurenai.id),
		"a WATER monster does not enable the FIRE cost")
	t.eq(water.zone, Enums.Zone.MONSTER_ZONE, "and it is untouched")

	# The control: add a FIRE monster and the very same board becomes legal.
	TestFixtures.give_monster_on_field(engine, 0, _fire("Now A Fire Monster", 1000))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kurenai.id),
		"one FIRE monster later, the same Trap IS offered")


static func _test_an_opponents_fire_monster_is_not_a_legal_tribute(t: TestCase) -> void:
	t.start("a Tribute is always your OWN monster [S1 p.23]: an opponent's FIRE monster "
		+ "does not enable the cost")
	var d := TestFixtures.new_duel(8112, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var kurenai := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _fire("Their Fire", 2000))

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, kurenai.id),
		"the opponent's FIRE monster is not yours to Tribute")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "and it stays on their field")


# ---------------------------------------------------------------------------
# Negation — the cost stays paid either way
# ---------------------------------------------------------------------------

static func _test_the_cost_is_not_refunded_when_the_activation_is_negated(
		t: TestCase) -> void:
	t.start("the ACTIVATION negated: the Tribute is NOT refunded and no damage is dealt")
	var d := _board(t, 8113, 1200)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	var before: int = engine.state.player(1).life_points
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Test Counter"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["kurenai"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "and made")
	t.eq(fire.zone, Enums.Zone.GRAVEYARD, "the cost is paid at once")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and negates the activation")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).life_points, before, "no damage was inflicted")
	t.eq(fire.zone, Enums.Zone.GRAVEYARD,
		"and the Tributed monster stays in the Graveyard — a cost is never refunded")
	t.eq(engine.state.player(0).monsters().size(), 0, "the field is still empty")


static func _test_the_cost_is_not_refunded_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("the EFFECT negated: the activation happened, the Tribute stays spent, and "
		+ "again no damage is dealt")
	var d := _board(t, 8114, 1200)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]
	var before: int = engine.state.player(1).life_points
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Test Effect Negator"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["kurenai"].id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "and made")

	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may respond")
	t.is_true(engine.submit_action(response), "and negates the EFFECT")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(1).life_points, before, "no damage was inflicted")
	t.eq(fire.zone, Enums.Zone.GRAVEYARD, "the Tributed monster is still in the Graveyard")


static func _test_the_tribute_is_not_a_destruction(t: TestCase) -> void:
	t.start("a Tribute is not a destruction: no CARD_DESTROYED event names the Tributed "
		+ "monster")
	var d := _board(t, 8115, 1200)
	var engine: DuelEngine = d["engine"]
	var fire: CardInstance = d["fire"]

	t.is_true(TestFixtures.activate_card(engine, 0, d["kurenai"]), "activated")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, fire.id), 0,
		"the Tributed monster was never destroyed")
	t.eq(fire.last_move_reason, Enums.MoveReason.TRIBUTED,
		"it reached the Graveyard as a Tribute")


static func _test_it_is_illegal_in_the_damage_step(t: TestCase) -> void:
	t.start("cid 6441 (ダメージステップには発動できません): the rules layer refuses it "
		+ "inside the Damage Step, and allows it outside")
	var d := _board(t, 8116, 1200)
	var engine: DuelEngine = d["engine"]
	var e := _effect(t)
	t.not_null(e, "the clause is reachable")
	if e == null:
		return
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"no Damage Step permission is declared")
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_false(ActivationRules.damage_step_ok(engine.state, e),
		"the rules layer refuses it inside the Damage Step")
	engine.state.battle_step = Enums.BattleStep.NONE
	engine.state.damage_substep = Enums.DamageSubStep.NONE
	t.is_true(ActivationRules.damage_step_ok(engine.state, e),
		"while outside it the same question says yes")


static func _test_the_trap_leaves_as_a_resolved_normal_trap(t: TestCase) -> void:
	t.start("the Normal Trap goes to the Graveyard after resolving, as a resolution rather "
		+ "than as a destruction")
	var d := _board(t, 8117, 1200)
	var engine: DuelEngine = d["engine"]
	var kurenai: CardInstance = d["kurenai"]

	t.is_true(TestFixtures.activate_card(engine, 0, kurenai), "activated")
	t.eq(kurenai.zone, Enums.Zone.GRAVEYARD, "it is in the Graveyard")
	t.eq(kurenai.last_move_reason, Enums.MoveReason.RESOLVED_TO_GY,
		"it left as a RESOLVED Normal Trap, not as a destroyed one")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, kurenai.id), 0,
		"and nothing destroyed it")


# ---------------------------------------------------------------------------
# The real printed pool
# ---------------------------------------------------------------------------

static func _test_it_is_live_against_the_real_printed_pool(t: TestCase) -> void:
	t.start("live on real cards: `Inari Fire` is a FIRE monster in this card's own deck, "
		+ "and Tributing it deals its printed 1500")
	var inari_atk := _printed_atk(t, INARI_FIRE)
	t.eq(inari_atk, INARI_FIRE_PRINTED_ATK,
		"the printed card really has the ATK this test expects")

	var d := TestFixtures.new_duel(8118, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var kurenai := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var inari := TestFixtures.give_monster_on_field(engine, 0, _card_def(t, INARI_FIRE))
	var before: int = engine.state.player(1).life_points
	t.eq(inari.definition.attribute, "FIRE", "Inari Fire really is FIRE")

	t.is_true(TestFixtures.activate_card(engine, 0, kurenai),
		"the Trap is activated with a real printed FIRE monster to pay with")
	t.eq(inari.zone, Enums.Zone.GRAVEYARD, "Inari Fire was Tributed")
	t.eq(engine.state.player(1).life_points, before - inari_atk,
		"and the opponent lost exactly its printed ATK")

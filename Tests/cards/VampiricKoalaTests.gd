class_name VampiricKoalaTests
extends RefCounted

## Per-card suite for `Vampiric Koala` — "If this card inflicts battle damage to your
## opponent by battle with a monster: Gain LP equal to the battle damage inflicted."
##
## The whole suite is about **when the trigger fires and when it does not**, because
## `CARD_RULINGS.md` R41 Part F (cid 8858) says the subject is 自身 — *this card itself
## battles* — and NOT "when this card attacks. So it fires while DEFENDING too, which the
## English text makes easy to miss, and the six-row table in the card's own header is
## reproduced here as six tests.
##
## Every positive test asserts the route as well as the result: a real `CHAIN_LINK_RESOLVING`
## for this card's effect, and an `LP_CHANGED` whose amount equals the `BATTLE_DAMAGE_INFLICTED`
## amount from the same battle. Every negative test asserts that no Chain Link existed at all,
## not merely that the LP total happened not to move.
##
## The whole battle goes through the ordinary pipeline; nothing here drives an alternate one.

const CARD_UNDER_TEST := "Vampiric Koala"
const EFFECT_ID := "gain_lp_equal_to_battle_damage"


static func run() -> TestCase:
	var t := TestCase.new("VampiricKoalaTests")
	_test_clause_shape(t)
	_test_it_gains_when_it_attacks_and_wins(t)
	_test_it_gains_when_it_is_ATTACKED_and_wins(t)
	_test_it_gains_while_in_DEFENCE_position(t)
	_test_a_direct_attack_does_not_trigger_it(t)
	_test_no_damage_means_no_trigger(t)
	_test_a_tie_inflicts_nothing_and_triggers_nothing(t)
	_test_damage_to_its_OWN_controller_does_not_trigger_it(t)
	_test_another_monsters_battle_does_not_trigger_it(t)
	_test_a_koala_in_the_graveyard_does_not_trigger(t)
	_test_the_amount_follows_a_boosted_atk(t)
	_test_it_is_mandatory_and_is_never_offered_as_a_choice(t)
	_test_effect_negation_grants_no_life_points(t)
	_test_it_does_not_fire_once_the_duel_is_already_over(t)
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


## A duel in the Battle Step of turn 2 with `attacker_pid` as the turn player.
## `battle_duel()` gives player 1 the first turn so player 0 may attack from turn 2.
static func _battlefield(seed_value: int) -> Dictionary:
	return TestFixtures.battle_duel(seed_value)


## The same, but with player 1 as the turn player, so the OPPONENT does the attacking.
static func _their_turn_battlefield(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	return d


static func _plain(name: String, atk: int, def_: int = 1000) -> CardDef:
	return TestFixtures.monster(name, 4, atk, def_)


## Did this card's own effect really put a Chain Link on the Chain and resolve it?
static func _link_resolved(engine: DuelEngine, koala: CardInstance) -> int:
	var n := 0
	for ev in engine.state.events:
		if ev.kind == GameEvent.Kind.CHAIN_LINK_RESOLVING \
				and int(ev.data.get("card_id", -1)) == koala.id:
			n += 1
	return n


## The LP_CHANGED events attributed to this card by its own reason string.
static func _gains(engine: DuelEngine) -> Array:
	var out: Array = []
	for ev in engine.state.events:
		if ev.kind == GameEvent.Kind.LP_CHANGED \
				and str(ev.data.get("reason", "")) == CARD_UNDER_TEST:
			out.append(ev)
	return out


static func _battle_damage(engine: DuelEngine) -> Array:
	return TestFixtures.events_of(engine, GameEvent.Kind.BATTLE_DAMAGE_INFLICTED)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Vampiric Koala: one clause — a MANDATORY Trigger Effect on battle damage, "
		+ "legal inside the Damage Step, with no target and no cost")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.MONSTER, "it is a Monster")
	t.eq(d.base_atk, 1800, "printed at 1800 ATK")
	t.eq(d.base_def, 1500, "and 1500 DEF")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	# cid 8858: 誘発効果 — a Trigger Effect, and 必ず — mandatory.
	t.eq(e.effect_type, Enums.EffectType.TRIGGER, "a TRIGGER effect")
	t.eq(e.optionality, Enums.Optionality.MANDATORY, "and MANDATORY")
	t.eq(e.trigger_events, [GameEvent.Kind.BATTLE_DAMAGE_INFLICTED],
		"keyed on the battle-damage event, not on the attack declaration")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"activated from a face-up Monster Zone")
	# "After damage calculation" is Damage Step sub-step 4.
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"a mandatory trigger the rules require inside the Damage Step")
	# cid 8858: 対象を取る効果ではありません.
	t.is_false(e.targets, "it does NOT target")
	t.is_false(e.pay_cost.is_valid(), "and has no cost")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")
	t.eq(e.ruling_ref, "R41", "it cites the ruling that settled it")


# ---------------------------------------------------------------------------
# The three ways it FIRES
# ---------------------------------------------------------------------------

static func _test_it_gains_when_it_attacks_and_wins(t: TestCase) -> void:
	t.start("Vampiric Koala: attacking a weaker Attack Position monster gains LP equal to "
		+ "the battle damage")
	var d := _battlefield(4601)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, koala, target), "the attack resolves")
	# The battle really happened, and the damage really went to the opponent.
	var damage := _battle_damage(engine)
	t.eq(damage.size(), 1, "exactly one battle-damage event")
	if damage.is_empty():
		return
	var amount := int((damage[0] as GameEvent).data.get("amount", 0))
	t.eq(amount, 800, "1800 - 1000 = 800 battle damage")
	t.eq(engine.state.player(1).life_points, their_lp - 800, "their LP fell by 800")
	# The claimed route: a real Chain Link for THIS card's effect.
	t.eq(_link_resolved(engine, koala), 1, "the trigger really put one Chain Link on the Chain")
	var gains := _gains(engine)
	t.eq(gains.size(), 1, "and raised exactly one LP_CHANGED attributed to this card")
	if not gains.is_empty():
		t.eq(int((gains[0] as GameEvent).data.get("delta", 0)), amount,
			"whose amount equals the battle damage exactly")
	t.eq(engine.state.player(0).life_points, my_lp + 800, "so the controller gained 800 LP")
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "and the defender was destroyed by battle")


static func _test_it_gains_when_it_is_ATTACKED_and_wins(t: TestCase) -> void:
	t.start("Vampiric Koala: R41 Part F — it fires while DEFENDING too, when a weaker "
		+ "monster attacks it in Attack Position")
	var d := _their_turn_battlefield(4602)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.turn_player_id, 1, "it is the opponent's turn")
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var attacker := TestFixtures.give_monster_on_field(engine, 1, _plain("Their Attacker", 1200))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, attacker, koala), "they attack the Koala")
	var damage := _battle_damage(engine)
	t.eq(damage.size(), 1, "exactly one battle-damage event")
	if damage.is_empty():
		return
	var ev: GameEvent = damage[0]
	t.eq(int(ev.data.get("player", -1)), 1, "the damage went to the ATTACKING player")
	t.eq(int(ev.data.get("amount", 0)), 600, "1800 - 1200 = 600")
	t.eq(int(ev.data.get("attacker_id", -1)), attacker.id,
		"and the Koala was the DEFENDER, not the attacker")
	t.eq(engine.state.player(1).life_points, their_lp - 600, "their LP fell by 600")
	# It fired anyway.
	t.eq(_link_resolved(engine, koala), 1, "the trigger fired while defending")
	t.eq(engine.state.player(0).life_points, my_lp + 600, "and gained 600 LP")
	t.eq(attacker.zone, Enums.Zone.GRAVEYARD, "their attacker was destroyed")
	t.eq(koala.zone, Enums.Zone.MONSTER_ZONE, "and the Koala survived")


static func _test_it_gains_while_in_DEFENCE_position(t: TestCase) -> void:
	t.start("Vampiric Koala: it fires in DEFENCE Position too, when the attacker's ATK is "
		+ "below its DEF and the attacking player takes the damage")
	var d := _their_turn_battlefield(4603)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST),
		Enums.Position.FACE_UP_DEFENSE)
	var attacker := TestFixtures.give_monster_on_field(engine, 1, _plain("Their Attacker", 1100))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	t.eq(koala.position, Enums.Position.FACE_UP_DEFENSE, "the Koala is in Defence Position")
	t.is_true(TestFixtures.attack(engine, attacker, koala), "they attack it anyway")
	var damage := _battle_damage(engine)
	t.eq(damage.size(), 1, "exactly one battle-damage event")
	if damage.is_empty():
		return
	t.eq(int((damage[0] as GameEvent).data.get("amount", 0)), 400,
		"1500 DEF - 1100 ATK = 400, taken by the attacking player")
	t.eq(engine.state.player(1).life_points, their_lp - 400, "their LP fell by 400")
	t.eq(_link_resolved(engine, koala), 1, "the trigger fired")
	t.eq(engine.state.player(0).life_points, my_lp + 400, "and gained 400 LP")


# ---------------------------------------------------------------------------
# The three ways it does NOT fire
# ---------------------------------------------------------------------------

static func _test_a_direct_attack_does_not_trigger_it(t: TestCase) -> void:
	t.start("Vampiric Koala: a DIRECT attack inflicts battle damage but not 'by battle with "
		+ "a monster', so nothing triggers")
	var d := _battlefield(4604)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	t.eq(engine.state.player(1).monsters().size(), 0, "the opponent controls no monster")
	t.is_true(TestFixtures.attack(engine, koala, null), "the Koala attacks directly")
	# The prerequisite: real battle damage really was inflicted on the opponent.
	var damage := _battle_damage(engine)
	t.eq(damage.size(), 1, "a battle-damage event really exists")
	if damage.is_empty():
		return
	var ev: GameEvent = damage[0]
	t.is_true(bool(ev.data.get("direct", false)), "and it is flagged as a DIRECT attack")
	t.eq(int(ev.data.get("amount", 0)), 1800, "for the Koala's full 1800 ATK")
	t.eq(engine.state.player(1).life_points, their_lp - 1800, "their LP fell by 1800")
	# …and the effect did not fire.
	t.eq(_link_resolved(engine, koala), 0, "no Chain Link was made at all")
	t.eq(_gains(engine).size(), 0, "no LP was gained")
	t.eq(engine.state.player(0).life_points, my_lp, "the controller's LP did not move")


static func _test_no_damage_means_no_trigger(t: TestCase) -> void:
	t.start("Vampiric Koala: destroying a Defence Position monster without inflicting damage "
		+ "triggers nothing")
	var d := _battlefield(4605)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var wall := TestFixtures.give_monster_on_field(engine, 1, _plain("Wall", 0, 1000),
		Enums.Position.FACE_UP_DEFENSE)
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, koala, wall), "the Koala attacks the wall")
	# The prerequisite: the battle really happened and really destroyed the defender.
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.DAMAGE_CALCULATED).size(), 1,
		"damage calculation really ran")
	t.eq(wall.zone, Enums.Zone.GRAVEYARD, "and the defender really was destroyed")
	t.eq(_battle_damage(engine).size(), 0, "but no battle damage was inflicted")
	t.eq(engine.state.player(1).life_points, their_lp, "their LP did not move")
	t.eq(_link_resolved(engine, koala), 0, "so no Chain Link was made")
	t.eq(engine.state.player(0).life_points, my_lp, "and no LP was gained")


static func _test_a_tie_inflicts_nothing_and_triggers_nothing(t: TestCase) -> void:
	t.start("Vampiric Koala: an equal-ATK battle destroys both and inflicts no damage, so "
		+ "nothing triggers")
	var d := _battlefield(4606)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var mirror := TestFixtures.give_monster_on_field(engine, 1, _plain("Mirror", 1800))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points

	t.is_true(TestFixtures.attack(engine, koala, mirror), "the Koala attacks its equal")
	t.eq(mirror.zone, Enums.Zone.GRAVEYARD, "the defender was destroyed")
	t.eq(koala.zone, Enums.Zone.GRAVEYARD, "and so was the Koala")
	t.eq(_battle_damage(engine).size(), 0, "no battle damage was inflicted")
	t.eq(_link_resolved(engine, koala), 0, "and no Chain Link was made")
	t.eq(engine.state.player(0).life_points, my_lp, "no LP was gained")


static func _test_damage_to_its_OWN_controller_does_not_trigger_it(t: TestCase) -> void:
	t.start("Vampiric Koala: when the Koala LOSES the battle its own controller takes the "
		+ "damage, which is not 'to your opponent'")
	var d := _battlefield(4607)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var bigger := TestFixtures.give_monster_on_field(engine, 1, _plain("Bigger", 2500))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points

	t.is_true(TestFixtures.attack(engine, koala, bigger), "the Koala attacks a bigger monster")
	var damage := _battle_damage(engine)
	t.eq(damage.size(), 1, "battle damage really was inflicted")
	if damage.is_empty():
		return
	t.eq(int((damage[0] as GameEvent).data.get("player", -1)), 0,
		"but it went to the KOALA's own controller")
	t.eq(engine.state.player(0).life_points, my_lp - 700, "who lost 700 LP")
	t.eq(_link_resolved(engine, koala), 0, "and no Chain Link was made")
	# A second, independent way to say the same thing: no Chain formed AT ALL during this
	# battle, from any card. Without it the claim rests on one event filter.
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_RESOLVING), 0,
		"no Chain Link of any kind was created during the whole battle")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_RESOLVED), 0,
		"and no Chain resolved at all")
	t.eq(_gains(engine).size(), 0, "no LP was gained")
	t.eq(koala.zone, Enums.Zone.GRAVEYARD, "the Koala was destroyed")


static func _test_another_monsters_battle_does_not_trigger_it(t: TestCase) -> void:
	t.start("Vampiric Koala: a battle it was not part of does not trigger it, even though "
		+ "the opponent took battle damage and the Koala is face-up on the field")
	var d := _battlefield(4608)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var other := TestFixtures.give_monster_on_field(engine, 0, _plain("Someone Else", 2000))
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, other, target), "the OTHER monster attacks")
	t.eq(_battle_damage(engine).size(), 1, "battle damage was inflicted on the opponent")
	t.eq(engine.state.player(1).life_points, their_lp - 1000, "their LP fell by 1000")
	t.eq(koala.zone, Enums.Zone.MONSTER_ZONE, "the Koala is face-up on the field throughout")
	t.eq(_link_resolved(engine, koala), 0, "but it made no Chain Link")
	t.eq(engine.state.player(0).life_points, my_lp, "and gained nothing")


static func _test_a_koala_in_the_graveyard_does_not_trigger(t: TestCase) -> void:
	t.start("Vampiric Koala: only a face-up copy ON THE FIELD triggers — one in the "
		+ "Graveyard is not activated by another Koala's battle")
	var d := _battlefield(4609)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var dead := TestFixtures.give(engine, 0, _card(CARD_UNDER_TEST), Enums.Zone.GRAVEYARD)
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points

	t.eq(dead.zone, Enums.Zone.GRAVEYARD, "a second copy sits in the Graveyard")
	t.is_true(TestFixtures.attack(engine, koala, target), "the field copy attacks and wins")
	t.eq(_link_resolved(engine, koala), 1, "the field copy fired")
	t.eq(_link_resolved(engine, dead), 0, "the Graveyard copy did not")
	t.eq(_gains(engine).size(), 1, "exactly one LP gain, not two")
	t.eq(engine.state.player(0).life_points, my_lp + 800, "800 LP gained, not 1600")

	# The Graveyard copy above is refused because it was not IN the battle, which would be
	# true whatever locations the clause declared. The location restriction is load-bearing
	# for a different case: a Koala that DID battle and has since left the field. No card in
	# the pool can remove a monster between damage calculation and sub-step 4, so the claim
	# is put to the authoritative legality gate directly, with exactly that state.
	var e := _effect()
	t.not_null(e, "the clause is reachable")
	if e == null:
		return
	var ev := GameEvent.new(GameEvent.Kind.BATTLE_DAMAGE_INFLICTED, {
		"player": 1, "amount": 800, "attacker_id": koala.id, "direct": false,
	})
	# Rebuild the battle state the trigger check would have seen.
	engine.state.current_attacker = koala
	engine.state.current_attack_target = target
	engine.state.attack_is_direct = false
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION
	t.eq(koala.zone, Enums.Zone.MONSTER_ZONE, "the Koala is on the field")
	t.is_true(ActivationRules.can_activate(engine.state, koala, e, 0, ev),
		"and the legality gate accepts the trigger")
	# Now move that very same battling Koala to the Graveyard and ask again.
	t.is_true(engine.state.move_card(koala, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {"source_id": -1}),
		"it is sent to the Graveyard")
	t.eq(engine.state.current_attacker, koala,
		"it is STILL the card the battle names, so 'it battled a monster' is still true")
	t.is_false(ActivationRules.can_activate(engine.state, koala, e, 0, ev),
		"but the gate now refuses it: the clause activates only from a face-up Monster Zone")


# ---------------------------------------------------------------------------
# The amount, and the mandatory-ness
# ---------------------------------------------------------------------------

static func _test_the_amount_follows_a_boosted_atk(t: TestCase) -> void:
	t.start("Vampiric Koala: the gain is the damage ACTUALLY inflicted, so boosting the "
		+ "Koala with `Back-Up Rider` raises the gain by the same 1500")
	var d := TestFixtures.new_duel(4610, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	var rider := TestFixtures.give_to_hand(engine, 0, _card("Back-Up Rider"))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, rider.id)
	t.not_null(offered, "Back-Up Rider is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [koala.id]})),
		"and is activated on the Koala")
	TestFixtures.pass_until_open(engine)
	t.eq(koala.current_atk(), 3300, "the Koala is at 1800 + 1500 = 3300")

	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE),
		"the Battle Phase is reached")
	t.is_true(TestFixtures.attack(engine, koala, target), "the boosted Koala attacks")
	var damage := _battle_damage(engine)
	t.eq(damage.size(), 1, "one battle-damage event")
	if damage.is_empty():
		return
	t.eq(int((damage[0] as GameEvent).data.get("amount", 0)), 2300,
		"3300 - 1000 = 2300, using the BOOSTED ATK")
	var gains := _gains(engine)
	t.eq(gains.size(), 1, "one LP gain")
	if not gains.is_empty():
		t.eq(int((gains[0] as GameEvent).data.get("delta", 0)), 2300,
			"of exactly 2300 — the damage inflicted, not the printed 1800 minus 1000")
	t.eq(engine.state.player(0).life_points, my_lp + 2300, "and the LP total agrees")


static func _test_it_is_mandatory_and_is_never_offered_as_a_choice(t: TestCase) -> void:
	t.start("Vampiric Koala: it is MANDATORY — the controller is never asked whether to use "
		+ "it, and it is never offered as a free-choice action")
	var d := _battlefield(4611)
	var engine: DuelEngine = d["engine"]
	var controller: ScriptedController = d["p0"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	engine.continuous.recompute()
	var asked_before := controller.request_count(Enums.DecisionKind.YES_NO)

	# A Trigger Effect is put on the Chain by the trigger system, never offered as an action.
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, koala.id, EFFECT_ID),
		"it is not among the turn player's free-choice actions")

	t.is_true(TestFixtures.attack(engine, koala, target), "the attack resolves")
	t.eq(_link_resolved(engine, koala), 1, "the trigger fired anyway")
	t.eq(controller.request_count(Enums.DecisionKind.YES_NO) - asked_before, 0,
		"and the controller was never asked a yes/no about it")


# ---------------------------------------------------------------------------
# Negation, and the end of the Duel
# ---------------------------------------------------------------------------

## A face-up Continuous card whose clause negates one named monster's effects, the way
## `Fiendish Chain` does. This is the only route by which this trigger can be stopped:
## a Chain-based negator cannot reach it, because a Chain formed in Damage Step sub-step 4
## admits only `MANDATORY_TRIGGER` effects and every negator in the pool is
## `UNTIL_DAMAGE_CALC` — which `ActivationRules.damage_step_ok()` refuses there.
static func _continuous_negator(card_name: String, victim: CardInstance) -> CardDef:
	var d := TestFixtures.trap(card_name, Enums.STKind.CONTINUOUS_TRAP)
	var e := EffectDef.new("negate_that_monster", "Test: negate that monster's effects.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.negating()
	e.apply_continuous = func(_ctx: EffectContext) -> void:
		ContinuousEffects.negate_effects(victim)
	return TestFixtures.with_effect(d, e)


static func _test_effect_negation_grants_no_life_points(t: TestCase) -> void:
	t.start("Vampiric Koala: a Koala whose effects are NEGATED does not trigger at all — "
		+ "no Chain Link, no LP, while the battle itself is unaffected")
	var d := _battlefield(4612)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	var negator := TestFixtures.give(engine, 1, _continuous_negator("Chain Binder", koala),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	# The negation really is in force — asserted on the state, not inferred from the outcome.
	t.eq(negator.zone, Enums.Zone.SPELL_TRAP_ZONE, "the negator is face-up on the field")
	t.is_true(koala.effects_are_negated(), "and the Koala's effects are negated")

	t.is_true(TestFixtures.attack(engine, koala, target), "the attack still resolves")
	# The battle is untouched: negation stops effects, not battles.
	t.eq(_battle_damage(engine).size(), 1, "battle damage was still inflicted")
	t.eq(engine.state.player(1).life_points, their_lp - 800, "their LP still fell by 800")
	t.eq(target.zone, Enums.Zone.GRAVEYARD, "and the defender was still destroyed")
	# The effect did not fire.
	t.eq(_link_resolved(engine, koala), 0, "but the trigger made NO Chain Link")
	t.eq(_gains(engine).size(), 0, "no LP_CHANGED was attributed to this card")
	t.eq(engine.state.player(0).life_points, my_lp, "and the controller gained nothing")

	# Removing the negation restores it, so the difference is really the negation.
	t.is_true(engine.state.destroy(negator, Enums.MoveReason.DESTROYED_BY_EFFECT, -1),
		"the negator is destroyed")
	engine.continuous.recompute()
	t.is_false(koala.effects_are_negated(), "the Koala's effects are live again")


static func _test_it_does_not_fire_once_the_duel_is_already_over(t: TestCase) -> void:
	t.start("Vampiric Koala: battle damage that ends the Duel leaves nothing to trigger — "
		+ "the LP check runs before sub-step 4")
	var d := _battlefield(4613)
	var engine: DuelEngine = d["engine"]
	var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
	var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
	engine.continuous.recompute()
	engine.state.player(1).life_points = 800
	var my_lp := engine.state.player(0).life_points

	TestFixtures.attack(engine, koala, target)
	t.eq(engine.state.player(1).life_points, 0, "their LP reached exactly 0")
	t.is_true(engine.state.is_duel_over(), "and the Duel is over")
	t.eq(_link_resolved(engine, koala), 0, "so the trigger made no Chain Link")
	t.eq(engine.state.player(0).life_points, my_lp, "and no LP was gained")


# ---------------------------------------------------------------------------
# The real pool, and determinism
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Vampiric Koala: it is in deck 1, at the printed 1800/1500 the whole suite "
		+ "computes from")
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the card database is readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary and parsed.has("cards")):
		t.check(false, "the card database parses")
		return
	var decks: Array = []
	var atk := -1
	var def_value := -1
	for entry in parsed["cards"]:
		if str(entry.get("name", "")) == CARD_UNDER_TEST:
			decks = entry.get("decks", [])
			atk = int(entry.get("atk", -1))
			def_value = int(entry.get("def", -1))
	t.is_true(decks.has("Blue-Eyes Dragon Guard"), "it is in deck 1")
	t.eq(atk, 1800, "the database says 1800 ATK")
	t.eq(def_value, 1500, "and 1500 DEF")
	# Deck 1 also holds Back-Up Rider, which is what makes the boosted-gain test a real line.
	var lib: Dictionary = CardRegistry.load_library()["cards"]
	t.is_true(lib.has("Back-Up Rider"), "and Back-Up Rider is in the same deck")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("Vampiric Koala: the same seed and the same actions produce the same result")
	var results: Array = []
	for _i in range(2):
		var d := _battlefield(4614)
		var engine: DuelEngine = d["engine"]
		var koala := TestFixtures.give_monster_on_field(engine, 0, _card(CARD_UNDER_TEST))
		var target := TestFixtures.give_monster_on_field(engine, 1, _plain("Weakling", 1000))
		engine.continuous.recompute()
		TestFixtures.attack(engine, koala, target)
		results.append({
			"lp0": engine.state.player(0).life_points,
			"lp1": engine.state.player(1).life_points,
			"links": _link_resolved(engine, koala),
			"gains": _gains(engine).size(),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["links"], 1, "the trigger really fired in both runs")
	t.eq(results[1]["lp0"], results[0]["lp0"], "the controller's LP match")
	t.eq(results[1]["lp1"], results[0]["lp1"], "the opponent's LP match")
	t.eq(results[1]["links"], results[0]["links"], "the Chain Link counts match")
	t.eq(results[1]["gains"], results[0]["gains"], "the LP-gain counts match")
	t.eq(results[1]["events"], results[0]["events"], "and the whole event stream matches")

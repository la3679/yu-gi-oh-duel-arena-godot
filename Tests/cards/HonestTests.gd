class_name HonestTests
extends RefCounted

## Per-card suite for `Honest` — the pool's first **monster effect activated from the HAND**,
## and its first Quick Effect whose window is inside the **Damage Step**.
## `CARD_RULINGS.md` **R20**, `RULES_SPEC.md` **§7.1 / §7.2 / §10**.
##
## Official text (cid 7574), both clauses:
##
##   ① "During your Main Phase: You can return this face-up card from the field to the hand."
##   ② "During the Damage Step, when a LIGHT monster you control battles (Quick Effect): You
##      can send this card from your hand to the GY; that monster gains ATK equal to the ATK
##      of the opponent's monster it is battling, until the end of this turn."
##
## **The fact the printed English text does not carry** is the one this suite exists to pin
## down. The official supplement (2024-04-01) says
## 「攻撃力０のモンスターと戦闘を行う際には発動できません。」 — *it cannot be activated when
## battling a monster with 0 ATK*. That is an **activation restriction**, so the effect is
## never offered rather than offered and resolving for +0, and both directions are asserted.
##
## **No card-specific damage calculation was written, and this suite proves it.** The boost
## is an ordinary `add_atk_modifier` on the battling monster, so the battle outcome changes
## only because `current_atk()` changed and `BattleRules.step_damage_calculation()` read it
## as it always did. The tests therefore assert the ATK, the battle RESULT and the LP swing
## separately — a card that faked the outcome could pass one of those and not all three.
##
## Guarded against vacuity throughout: every "it was not offered" test is paired with a
## mutation that makes it offered again, and every resolution test asserts that the
## activation actually happened before asserting what it did.

const CARD_UNDER_TEST := "Honest"

const RETURN_EFFECT_ID := "return_this_card_to_hand"
const BOOST_EFFECT_ID := "send_from_hand_boost_battling_light_monster"


static func run() -> TestCase:
	var t := TestCase.new("HonestTests")
	_test_clause_shape(t)
	_test_printed_stats(t)
	# Clause ②, the Damage Step Quick Effect.
	_test_boosts_your_attacking_light_monster(t)
	_test_boosts_your_attacked_light_monster(t)
	_test_the_send_is_a_cost_not_a_discard(t)
	_test_the_boost_lasts_until_the_end_of_the_turn(t)
	_test_two_copies_stack(t)
	_test_not_offered_against_a_zero_atk_monster(t)
	_test_not_offered_for_a_non_light_monster(t)
	_test_not_offered_on_a_direct_attack(t)
	_test_not_offered_outside_the_damage_step(t)
	_test_the_main_phase_never_offers_it(t)
	_test_not_offered_after_damage_calculation(t)
	_test_not_offered_from_the_field_or_graveyard(t)
	_test_a_face_down_opponent_monster_defers_to_substep_two(t)
	_test_the_cost_is_not_refunded_when_the_effect_is_negated(t)
	# Clause ①, the Main Phase Ignition effect.
	_test_returns_itself_to_the_hand(t)
	_test_the_return_is_main_phase_only(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _card(card_name: String) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


static func _honest_def() -> CardDef:
	return _card(CARD_UNDER_TEST)


static func _effect(effect_id: String) -> EffectDef:
	for entry in _honest_def().effects:
		var e: EffectDef = entry
		if e.effect_id == effect_id:
			return e
	return null


## A LIGHT monster of arbitrary ATK, so a test states the number it depends on.
static func _light(name: String, atk: int, def_: int = 0) -> CardDef:
	return TestFixtures.monster(name, 4, atk, def_, "LIGHT")


static func _dark(name: String, atk: int, def_: int = 0) -> CardDef:
	return TestFixtures.monster(name, 4, atk, def_, "DARK")


## A duel sitting in PLAYER 0's Battle Phase on turn 2. `TestFixtures.battle_duel()` gives
## the first turn to player 1 on purpose — "the player who goes first cannot conduct a
## Battle Phase on their first turn" [S1 p.37] — which is why this is not `new_duel()`.
static func _battle_duel(seed_value: int) -> Dictionary:
	return TestFixtures.battle_duel(seed_value)


## The mirror image: PLAYER 1's Battle Phase, so player 0 is the one being attacked and the
## one holding Honest. Turn 3, one turn further on than `_battle_duel()`.
static func _opponent_battle_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	return d


## Walk the whole Damage Step, activating `card`'s `effect_id` at the FIRST window that
## offers it. Returns {"activated": bool, "ever_offered": bool, "substep": int} — the
## sub-step it was first offered in, so a test can assert WHERE the window was and not only
## that there was one.
static func _attack_and_use(engine: DuelEngine, pid: int, attacker: CardInstance, target,
		card: CardInstance, effect_id: String = BOOST_EFFECT_ID) -> Dictionary:
	var out := {"activated": false, "ever_offered": false,
		"substep": Enums.DamageSubStep.NONE, "declared": false}
	if not TestFixtures.attack(engine, attacker, target):
		return out
	out["declared"] = true
	for i in range(32):
		var offered = TestFixtures.find_action(engine.get_legal_responses(pid),
			Enums.ActionKind.ACTIVATE_EFFECT, card.id, effect_id)
		if offered != null:
			if not out["ever_offered"]:
				out["ever_offered"] = true
				out["substep"] = engine.state.damage_substep
			if not out["activated"] and engine.submit_action(offered):
				out["activated"] = true
				continue
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)
	return out


## The same walk WITHOUT activating anything: was it ever offered, and where?
static func _attack_and_watch(engine: DuelEngine, pid: int, attacker: CardInstance, target,
		card: CardInstance) -> Dictionary:
	var out := {"ever_offered": false, "substep": Enums.DamageSubStep.NONE,
		"substeps_seen": []}
	var mark := engine.state.events.size()
	if not TestFixtures.attack(engine, attacker, target):
		return out
	for i in range(32):
		if TestFixtures.find_action(engine.get_legal_responses(pid),
				Enums.ActionKind.ACTIVATE_EFFECT, card.id, BOOST_EFFECT_ID) != null:
			if not out["ever_offered"]:
				out["ever_offered"] = true
				out["substep"] = engine.state.damage_substep
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)
	# The sub-steps the battle actually went through, read from the EVENT LOG rather
	# than sampled inside the loop: the engine runs several sub-steps back to back
	# between two windows, so sampling under-reports and a "was never offered" test
	# could pass without the Damage Step having happened at all.
	for entry in TestFixtures.events_of(engine,
			GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED, mark):
		var ev: GameEvent = entry
		var sub = ev.data.get("substep")
		if not (out["substeps_seen"] as Array).has(sub):
			(out["substeps_seen"] as Array).append(sub)
	return out


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("two clauses: a Main Phase IGNITION effect on the field, and a Damage Step "
		+ "QUICK effect activated FROM THE HAND with a send cost")
	var def := _honest_def()
	t.not_null(def, "Honest is in the library")
	t.eq(def.effects.size(), 2, "exactly two EffectDefs, for the card's two clauses")

	var ret := _effect(RETURN_EFFECT_ID)
	t.not_null(ret, "clause 1 exists")
	t.eq(ret.effect_type, Enums.EffectType.IGNITION,
		"cid 7574 (モンスターゾーンで発動できる起動効果です): an IGNITION effect, not a Quick one")
	t.eq(ret.spell_speed, Enums.SpellSpeed.SS1, "so it is Spell Speed 1")
	t.eq(ret.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"activated in the Monster Zone, face-up")
	t.eq(ret.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"'During your Main Phase' — both Main Phases and no other")
	t.eq(ret.damage_step_permission, Enums.DamageStepPermission.NONE,
		"and it is NOT a Damage Step effect")
	t.is_false(ret.targets, "it names no target")

	var boost := _effect(BOOST_EFFECT_ID)
	t.not_null(boost, "clause 2 exists")
	t.eq(boost.effect_type, Enums.EffectType.QUICK,
		"cid 7574 (手札で発動できる誘発即時効果です): a QUICK Effect")
	t.eq(boost.spell_speed, Enums.SpellSpeed.SS2, "so it is Spell Speed 2")
	t.eq(boost.activation_locations, [Enums.ActivationLocation.HAND],
		"and it is activated IN THE HAND — the pool's first monster effect that is")
	t.eq(boost.damage_step_permission, Enums.DamageStepPermission.UNTIL_DAMAGE_CALC,
		"ダメージステップ開始時からダメージ計算前までに: sub-steps 1-2")
	t.ne(boost.damage_step_permission, Enums.DamageStepPermission.AFTER_DAMAGE_CALC,
		"emphatically NOT sub-step 4, where Damage Condenser lives")
	t.is_false(boost.targets, "neither text carries 対象 / 'target', so it does not target")
	t.is_true(boost.can_pay_cost.is_valid(), "it declares a cost check")
	t.is_true(boost.pay_cost.is_valid(), "and a cost payment, so the send is a COST")
	t.is_true(boost.condition.is_valid(),
		"and a condition, which carries the 0-ATK activation restriction")
	t.is_false(boost.once_per_turn_instance, "no once-per-turn wording anywhere in the text")
	t.is_false(boost.once_per_turn_named_effect, "nor a named-effect limit")
	t.is_false(boost.once_per_turn_named_activation, "nor a named-activation limit")
	t.eq(boost.trigger_events, [],
		"a Quick Effect offered in any legal fast window, not a Trigger keyed to an event")
	t.eq(boost.ruling_ref, "R20", "it cites its ruling")


static func _test_printed_stats(t: TestCase) -> void:
	t.start("Honest is itself a LIGHT monster, which is what makes it self-targeting bait")
	var def := _honest_def()
	t.eq(def.attribute, "LIGHT", "LIGHT")
	t.eq(def.level, 4, "Level 4")
	t.eq(def.base_atk, 1100, "1100 ATK")
	t.eq(def.base_def, 1900, "1900 DEF")
	t.eq(def.race, "Fairy", "Fairy")
	t.is_true(def.is_effect_monster, "an Effect Monster")


# ---------------------------------------------------------------------------
# Clause 2 — positive behaviour
# ---------------------------------------------------------------------------

static func _test_boosts_your_attacking_light_monster(t: TestCase) -> void:
	t.start("your ATTACKING LIGHT monster gains the defender's ATK and wins the battle")
	var d := _battle_duel(2001)
	var engine: DuelEngine = d["engine"]

	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 2400))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())
	var lp_before := engine.state.player(0).life_points
	var their_lp_before := engine.state.player(1).life_points

	var r := _attack_and_use(engine, 0, mine, theirs, honest)
	t.is_true(r["declared"], "the attack was declared")
	t.is_true(r["activated"], "Honest was offered and activated — the branch is not vacuous")
	t.eq(r["substep"], Enums.DamageSubStep.START_OF_DAMAGE_STEP,
		"first offered at the START of the Damage Step, the earliest of its two sub-steps")

	t.eq(honest.zone, Enums.Zone.GRAVEYARD, "Honest paid itself as the cost")
	t.eq(mine.current_atk(), 1000 + 2400,
		"the attacker gained exactly the defender's ATK: 1000 + 2400")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "and survived the battle")
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD, "while the defender was destroyed by battle")
	t.eq(engine.state.player(0).life_points, lp_before,
		"the attacking player took no damage")
	t.eq(engine.state.player(1).life_points, their_lp_before - (3400 - 2400),
		"and the defending player took 3400 - 2400 = 1000 battle damage")


static func _test_boosts_your_attacked_light_monster(t: TestCase) -> void:
	t.start("cid 7574: it works when your LIGHT monster is ATTACKED, not only when it attacks")
	var d := _opponent_battle_duel(2002)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.turn_player_id, 1, "player 1 is the turn player")

	# Player 1 is the turn player and attacks; player 0 holds Honest and defends.
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Raider", 2000))
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Guard", 900))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())
	var my_lp_before := engine.state.player(0).life_points

	var r := _attack_and_use(engine, 0, theirs, mine, honest)
	t.is_true(r["declared"], "the opponent declared the attack")
	t.is_true(r["activated"], "the DEFENDING player activated Honest from hand")
	t.eq(mine.current_atk(), 900 + 2000, "the attacked monster gained the attacker's ATK")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "it survived")
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD, "and the attacker was destroyed instead")
	t.eq(engine.state.player(0).life_points, my_lp_before,
		"the defending player took no damage at all")


static func _test_the_send_is_a_cost_not_a_discard(t: TestCase) -> void:
	t.start("the card leaves the hand as SENT_AS_COST, never as DISCARDED [S1 p.52-53]")
	var d := _battle_duel(2003)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1800))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())

	var mark := engine.state.events.size()
	var r := _attack_and_use(engine, 0, mine, theirs, honest)
	t.is_true(r["activated"], "Honest was activated")

	var reasons: Array = []
	for entry in TestFixtures.events_of(engine, GameEvent.Kind.CARD_SENT_TO_GY, mark):
		var ev: GameEvent = entry
		if int(ev.data.get("card_id", -1)) == honest.id:
			reasons.append(ev.data.get("reason"))
	t.eq(reasons, [Enums.MoveReason.SENT_AS_COST],
		"exactly one move of Honest to the GY, and its reason is SENT_AS_COST")
	t.is_false(reasons.has(Enums.MoveReason.DISCARDED),
		"a clause that triggers on a DISCARD must not see this")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY, honest.id), 1,
		"and it reached the Graveyard exactly once")


static func _test_the_boost_lasts_until_the_end_of_the_turn(t: TestCase) -> void:
	t.start("'until the end of this turn', not 'until the end of the Damage Step'")
	var d := _battle_duel(2004)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wall", 4, 1200, 2600))
	engine.state.set_battle_position(theirs, Enums.Position.FACE_UP_DEFENSE, true)

	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())
	var r := _attack_and_use(engine, 0, mine, theirs, honest)
	t.is_true(r["activated"], "Honest was activated")
	t.eq(mine.current_atk(), 1000 + 1200,
		"the boost is the opponent's ATK even when it is in DEFENCE position")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "the attacker survives")
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE,
		"and 2200 ATK still does not beat 2600 DEF, so nothing is destroyed")

	# The Damage Step is over and the boost is still there — that is the whole claim.
	t.ne(engine.state.battle_step, Enums.BattleStep.DAMAGE, "the Damage Step has ended")
	t.eq(mine.current_atk(), 2200, "and the monster is still at 2200 ATK")

	TestFixtures.end_turn(engine)
	t.eq(mine.current_atk(), 1000, "at the end of the turn the boost is gone")


static func _test_two_copies_stack(t: TestCase) -> void:
	t.start("nothing is once per turn, so two copies in one battle both apply and stack")
	var d := _battle_duel(2005)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 500))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1300))
	var first := TestFixtures.give_to_hand(engine, 0, _honest_def())
	var second := TestFixtures.give_to_hand(engine, 0, _honest_def())

	t.is_true(TestFixtures.attack(engine, mine, theirs), "the attack was declared")
	var used := 0
	for i in range(32):
		for entry in [first, second]:
			var copy: CardInstance = entry
			if copy.zone != Enums.Zone.HAND:
				continue
			var offered = TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_EFFECT, copy.id, BOOST_EFFECT_ID)
			if offered != null and engine.submit_action(offered):
				used += 1
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)

	t.eq(used, 2, "BOTH copies were offered and activated — no per-turn limit blocked the second")
	t.eq(first.zone, Enums.Zone.GRAVEYARD, "the first paid itself")
	t.eq(second.zone, Enums.Zone.GRAVEYARD, "and so did the second")
	t.eq(mine.current_atk(), 500 + 1300 + 1300,
		"the gains STACK: two separate additive modifiers, not one set-to-value")


# ---------------------------------------------------------------------------
# Clause 2 — the activation restrictions
# ---------------------------------------------------------------------------

static func _test_not_offered_against_a_zero_atk_monster(t: TestCase) -> void:
	t.start("cid 7574 (攻撃力０のモンスターと戦闘を行う際には発動できません): "
		+ "0 ATK blocks the ACTIVATION, it does not resolve for +0")
	var d := _battle_duel(2006)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Nothing", 0))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())

	# `_attack_and_use`, not `_attack_and_watch`: it ACTIVATES at the first window that
	# offers it, so a regression that made the effect legal here fails on the outcome as
	# well as on the offer, rather than on one assertion alone.
	var r := _attack_and_use(engine, 0, mine, theirs, honest)
	t.is_true(r["declared"], "the attack was declared")
	t.is_false(r["ever_offered"],
		"Honest was NOT offered at any point in the Damage Step")
	t.is_false(r["activated"], "so nothing was activated")
	t.eq(honest.zone, Enums.Zone.HAND, "and it is still in the hand")
	t.eq(mine.current_atk(), 1000, "the LIGHT monster gained nothing")
	t.eq(theirs.zone, Enums.Zone.GRAVEYARD,
		"the 0 ATK monster was destroyed by the unboosted 1000 ATK attacker")
	# And the battle really did go through the Damage Step, so "not offered" is a fact
	# about the restriction and not about a walk that never got there.
	var substeps: Array = []
	for entry in TestFixtures.events_of(engine, GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED):
		var ev: GameEvent = entry
		if not substeps.has(ev.data.get("substep")):
			substeps.append(ev.data.get("substep"))
	t.is_true(substeps.has(Enums.DamageSubStep.START_OF_DAMAGE_STEP),
		"sub-step 1 happened")
	t.is_true(substeps.has(Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION),
		"and so did sub-step 2 — both of Honest's windows were open and passed by")

	# Mutation guard: the SAME battle with a 1-ATK opponent offers it. Only the number moved.
	var d2 := _battle_duel(2016)
	var engine2: DuelEngine = d2["engine"]
	var mine2 := TestFixtures.give_monster_on_field(engine2, 0, _light("Shiner", 1000))
	var theirs2 := TestFixtures.give_monster_on_field(engine2, 1, _dark("Barely", 1))
	var honest2 := TestFixtures.give_to_hand(engine2, 0, _honest_def())
	var r2 := _attack_and_use(engine2, 0, mine2, theirs2, honest2)
	t.is_true(r2["activated"], "with 1 ATK instead of 0 it IS offered and activated")
	t.eq(mine2.current_atk(), 1001, "and the gain really is 1")


static func _test_not_offered_for_a_non_light_monster(t: TestCase) -> void:
	t.start("'a LIGHT monster you control' — a DARK monster of yours does not qualify")
	var d := _battle_duel(2007)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _dark("Shadow", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1800))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())

	var r := _attack_and_watch(engine, 0, mine, theirs, honest)
	t.is_false(r["ever_offered"], "not offered for a DARK monster you control")
	t.eq(honest.zone, Enums.Zone.HAND, "it stayed in the hand")

	# Mutation guard: the same battle with a LIGHT attacker offers it.
	var d2 := _battle_duel(2017)
	var engine2: DuelEngine = d2["engine"]
	var mine2 := TestFixtures.give_monster_on_field(engine2, 0, _light("Shiner", 1000))
	var theirs2 := TestFixtures.give_monster_on_field(engine2, 1, _dark("Bruiser", 1800))
	var honest2 := TestFixtures.give_to_hand(engine2, 0, _honest_def())
	t.is_true((_attack_and_use(engine2, 0, mine2, theirs2, honest2))["activated"],
		"the same battle with a LIGHT attacker DOES offer it")

	# And an opposing LIGHT monster is not "a LIGHT monster YOU control".
	var d3 := _battle_duel(2027)
	var engine3: DuelEngine = d3["engine"]
	var mine3 := TestFixtures.give_monster_on_field(engine3, 0, _dark("Shadow", 1000))
	var theirs3 := TestFixtures.give_monster_on_field(engine3, 1, _light("Their Shiner", 1800))
	var honest3 := TestFixtures.give_to_hand(engine3, 0, _honest_def())
	t.is_false((_attack_and_watch(engine3, 0, mine3, theirs3, honest3))["ever_offered"],
		"the OPPONENT's LIGHT monster does not make it activatable")


static func _test_not_offered_on_a_direct_attack(t: TestCase) -> void:
	t.start("'battles' means a battle with a MONSTER — a direct attack is not one")
	var d := _battle_duel(2008)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())
	t.eq(engine.state.player(1).monster_count(), 0, "the opponent controls no monsters")

	var r := _attack_and_watch(engine, 0, mine, null, honest)
	t.is_true((r["substeps_seen"] as Array).has(Enums.DamageSubStep.START_OF_DAMAGE_STEP),
		"the direct attack really did reach the Damage Step")
	t.is_false(r["ever_offered"], "Honest was not offered on a direct attack")
	t.eq(honest.zone, Enums.Zone.HAND, "it stayed in the hand")
	t.eq(engine.state.player(1).life_points, 8000 - 1000,
		"and the direct attack went through for the attacker's UNBOOSTED 1000 ATK")


static func _test_not_offered_outside_the_damage_step(t: TestCase) -> void:
	t.start("'During the Damage Step' — not in a Main Phase, not in the open Battle Phase, "
		+ "and not in the attack-declaration window")
	var d := _battle_duel(2009)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1800))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())
	var effect := _effect(BOOST_EFFECT_ID)

	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE,
		"the duel is sitting in the open Battle Step, before any attack")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, BOOST_EFFECT_ID),
		"not offered in the open Battle Phase with no battle happening")

	t.is_true(TestFixtures.attack(engine, mine, theirs), "an attack is declared")

	# The attack-declaration window is the BATTLE Step, and with no other response available
	# the engine has already carried the duel into the Damage Step by the time control comes
	# back here — so the window cannot be caught by sampling. It is asked of the rules layer
	# directly instead, with the battle step put back where the declaration window has it.
	# `ActivationRules.can_activate()` is the same funnel `get_legal_responses()` uses, so
	# this is the real gate and not a re-implementation of it.
	var restore := engine.state.battle_step
	var restore_sub := engine.state.damage_substep
	engine.state.battle_step = Enums.BattleStep.BATTLE
	engine.state.damage_substep = Enums.DamageSubStep.NONE
	t.is_false(ActivationRules.can_activate(engine.state, honest, effect, 0, null),
		"in the attack-declaration window — a live battle, but the BATTLE Step — it is "
		+ "not activatable")
	engine.state.battle_step = restore
	engine.state.damage_substep = restore_sub
	t.is_true(ActivationRules.can_activate(engine.state, honest, effect, 0, null),
		"and putting the Damage Step back makes it activatable again, so the check above "
		+ "turned on the step and on nothing else")

	# The invariant, over the whole rest of the battle: every window that offered it was
	# inside the Damage Step. Nothing here samples a single moment.
	var offered_steps: Array = []
	var offered_at_all := false
	for i in range(32):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_EFFECT, honest.id, BOOST_EFFECT_ID) != null:
			offered_at_all = true
			if not offered_steps.has(engine.state.battle_step):
				offered_steps.append(engine.state.battle_step)
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)
	t.is_true(offered_at_all,
		"it WAS offered somewhere, so the invariant below is not vacuously true")
	t.eq(offered_steps, [Enums.BattleStep.DAMAGE],
		"and every window that offered it was in the Damage Step and nowhere else")


static func _test_the_main_phase_never_offers_it(t: TestCase) -> void:
	t.start("clause 2 is not offered in a Main Phase even with a LIGHT monster on the field")
	var d := TestFixtures.new_duel(2019, 0)
	var engine: DuelEngine = d["engine"]
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"the duel reached Main Phase 1")
	TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1800))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, BOOST_EFFECT_ID),
		"no battle is happening, so there is nothing for it to answer")
	t.eq(engine.state.current_attacker, null, "and indeed no attack is in progress")


static func _test_not_offered_after_damage_calculation(t: TestCase) -> void:
	t.start("'until before damage calculation' — sub-steps 1-2 only, never sub-step 4")
	var d := _battle_duel(2010)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 800))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())

	t.is_true(TestFixtures.attack(engine, mine, theirs), "the attack was declared")
	var offered_in: Array = []
	for i in range(32):
		if engine.state.battle_step == Enums.BattleStep.DAMAGE \
				and TestFixtures.find_action(engine.get_legal_responses(0),
					Enums.ActionKind.ACTIVATE_EFFECT, honest.id, BOOST_EFFECT_ID) != null:
			if not offered_in.has(engine.state.damage_substep):
				offered_in.append(engine.state.damage_substep)
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)

	t.ne(offered_in, [], "it was offered somewhere in the Damage Step")
	t.is_true(offered_in.has(Enums.DamageSubStep.START_OF_DAMAGE_STEP),
		"in sub-step 1")
	t.is_false(offered_in.has(Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION),
		"and NEVER in sub-step 4, where Damage Condenser's window is")
	t.is_false(offered_in.has(Enums.DamageSubStep.END_OF_DAMAGE_STEP),
		"nor in sub-step 5")


static func _test_not_offered_from_the_field_or_graveyard(t: TestCase) -> void:
	t.start("clause 2 is activated IN THE HAND — a copy on the field or in the GY cannot")
	var d := _battle_duel(2011)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1800))
	var on_field := TestFixtures.give_monster_on_field(engine, 0, _honest_def())
	var in_gy := TestFixtures.give(engine, 0, _honest_def(), Enums.Zone.GRAVEYARD)

	t.eq(on_field.zone, Enums.Zone.MONSTER_ZONE, "one copy is face-up on the field")
	t.eq(in_gy.zone, Enums.Zone.GRAVEYARD, "and one is in the Graveyard")
	t.is_false((_attack_and_watch(engine, 0, mine, theirs, on_field))["ever_offered"],
		"the field copy is never offered clause 2")

	var d2 := _battle_duel(2021)
	var engine2: DuelEngine = d2["engine"]
	var mine2 := TestFixtures.give_monster_on_field(engine2, 0, _light("Shiner", 1000))
	var theirs2 := TestFixtures.give_monster_on_field(engine2, 1, _dark("Bruiser", 1800))
	var gy_copy := TestFixtures.give(engine2, 0, _honest_def(), Enums.Zone.GRAVEYARD)
	t.is_false((_attack_and_watch(engine2, 0, mine2, theirs2, gy_copy))["ever_offered"],
		"nor is the Graveyard copy")

	# Mutation guard: a HAND copy in the same battle IS offered.
	var d3 := _battle_duel(2031)
	var engine3: DuelEngine = d3["engine"]
	var mine3 := TestFixtures.give_monster_on_field(engine3, 0, _light("Shiner", 1000))
	var theirs3 := TestFixtures.give_monster_on_field(engine3, 1, _dark("Bruiser", 1800))
	var hand_copy := TestFixtures.give_to_hand(engine3, 0, _honest_def())
	t.is_true((_attack_and_use(engine3, 0, mine3, theirs3, hand_copy))["activated"],
		"the same card in the HAND is offered and works")


static func _test_a_face_down_opponent_monster_defers_to_substep_two(t: TestCase) -> void:
	t.start("against a Set monster the window opens in sub-step 2, after the rules flip it "
		+ "face-up — no legal play is lost")
	var d := _battle_duel(2012)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Set Wall", 4, 1600, 300), Enums.Position.FACE_DOWN_DEFENSE)
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())
	t.is_true(theirs.is_face_down(), "the defender starts face-down")

	var r := _attack_and_use(engine, 0, mine, theirs, honest)
	t.is_true(r["activated"], "Honest WAS usable — nothing was taken away")
	t.eq(r["substep"], Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
		"but only from sub-step 2, once the flip made the ATK legally knowable")
	t.ne(r["substep"], Enums.DamageSubStep.START_OF_DAMAGE_STEP,
		"it was NOT offered in sub-step 1 against a face-down monster")
	t.is_true(theirs.is_face_up() or theirs.zone == Enums.Zone.GRAVEYARD,
		"the defender was flipped face-up by the rules")
	t.eq(mine.current_atk(), 1000 + 1600,
		"and the boost used the flipped monster's ATK, not its DEF")


static func _test_the_cost_is_not_refunded_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("a cost is paid at activation and is never refunded (RULES_SPEC 10)")
	var d := _battle_duel(2013)
	var engine: DuelEngine = d["engine"]
	var mine := TestFixtures.give_monster_on_field(engine, 0, _light("Shiner", 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _dark("Bruiser", 1800))
	var honest := TestFixtures.give_to_hand(engine, 0, _honest_def())

	# A negator whose own window reaches into sub-steps 1-2, so what is under test stays
	# "is the cost refunded?" rather than "which cards may be activated in the Damage Step",
	# which DamageStepTests owns.
	# `any_effect_negator`, not `effect_negator`: the narrower fixture only reaches a
	# Spell/Trap activation, and Honest's clause 2 is a MONSTER effect.
	var negator_def := TestFixtures.any_effect_negator("Effect Negator")
	(negator_def.effects[0] as EffectDef).damage_step_permission = \
		Enums.DamageStepPermission.UNTIL_DAMAGE_CALC
	var negator := TestFixtures.give_set_spell_trap(engine, 1, negator_def)
	negator.turn_set = -1

	t.is_true(TestFixtures.attack(engine, mine, theirs), "the attack was declared")
	var used := false
	var negated := false
	for i in range(32):
		if not used:
			var offered = TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_EFFECT, honest.id, BOOST_EFFECT_ID)
			if offered != null and engine.submit_action(offered):
				used = true
				continue
		if used and not negated:
			var answer = TestFixtures.find_action(engine.get_legal_responses(1),
				Enums.ActionKind.ACTIVATE_CARD, negator.id)
			if answer != null:
				if engine.submit_action(answer):
					negated = true
					continue
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)

	t.is_true(used, "Honest was activated")
	t.is_true(negated, "and its effect was negated — the branch is not vacuous")
	t.eq(honest.zone, Enums.Zone.GRAVEYARD,
		"the cost is NOT refunded: Honest stays in the Graveyard")
	t.eq(mine.current_atk(), 1000, "and the monster gained nothing")
	t.eq(mine.zone, Enums.Zone.GRAVEYARD,
		"so it lost the battle it would otherwise have won")


# ---------------------------------------------------------------------------
# Clause 1 — the Main Phase Ignition effect
# ---------------------------------------------------------------------------

static func _test_returns_itself_to_the_hand(t: TestCase) -> void:
	t.start("clause 1 returns this face-up card from the field to the hand")
	var d := TestFixtures.new_duel(2014, 0)
	var engine: DuelEngine = d["engine"]
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1),
		"the duel reached Main Phase 1")
	var honest := TestFixtures.give_monster_on_field(engine, 0, _honest_def())

	var action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, RETURN_EFFECT_ID)
	t.not_null(action, "the Ignition effect is offered in Main Phase 1")
	t.is_true(engine.submit_action(action), "and it is activated")
	TestFixtures.pass_until_open(engine)

	t.eq(honest.zone, Enums.Zone.HAND, "Honest is back in the hand")
	t.eq(engine.state.player(0).monster_count(), 0, "and off the field")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		honest.id), 1, "exactly one return-to-hand event was raised for it")

	# And from the hand it can then do what it is in the deck to do.
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, RETURN_EFFECT_ID),
		"clause 1 is not offered again from the hand — it is a FIELD effect")


static func _test_the_return_is_main_phase_only(t: TestCase) -> void:
	t.start("'During your Main Phase' — not the Battle Phase, and not the opponent's turn")
	var d := _battle_duel(2015)
	var engine: DuelEngine = d["engine"]
	var honest := TestFixtures.give_monster_on_field(engine, 0, _honest_def())
	t.eq(engine.state.phase, Enums.Phase.BATTLE, "the duel is in the Battle Phase")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, RETURN_EFFECT_ID),
		"clause 1 is not offered in the Battle Phase")

	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, RETURN_EFFECT_ID),
		"but it IS offered in Main Phase 2 — both Main Phases count")

	TestFixtures.end_turn(engine)
	t.ne(engine.state.turn_player_id, 0, "it is now the opponent's turn")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, honest.id, RETURN_EFFECT_ID),
		"'YOUR Main Phase': it is not offered during the opponent's Main Phase")

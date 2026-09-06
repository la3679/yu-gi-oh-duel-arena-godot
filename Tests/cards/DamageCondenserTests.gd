class_name DamageCondenserTests
extends RefCounted

## `Damage Condenser` — "When you take battle damage: Discard 1 card; Special Summon 1
## monster from your Deck with ATK less than or equal to the battle damage you took, in
## Attack Position."
##
## The mirror of batch 11's `Vampiric Koala`: the same `BATTLE_DAMAGE_INFLICTED` event,
## keyed on the damage taken by its OWN controller rather than by the opponent. Each is a
## control on the other, and this suite asserts the direction in both.
##
## The three things this suite asserts hardest, because each is a fact CARD_RULINGS R42
## Part C established and the printed English text does not carry:
##
##   * the Deck requirement is an **activation restriction** — with no qualifying monster
##     the card is never offered, rather than resolving for nothing;
##   * the ATK compared is the **printed ATK in the Deck**, and the figure it is compared
##     against is **this battle's** damage;
##   * its window is Damage Step **sub-step 4**, which is the opposite of `Kurenai` and
##     `Aoi` in the same batch.

const CARD_UNDER_TEST := "Damage Condenser"


static func run() -> TestCase:
	var t := TestCase.new("DamageCondenserTests")
	_test_the_clause_shape(t)
	_test_it_summons_from_the_deck_in_attack_position(t)
	_test_the_atk_ceiling_is_the_battle_damage_taken(t)
	_test_the_atk_read_is_the_printed_one_in_the_deck(t)
	_test_an_over_ceiling_monster_is_not_even_a_candidate(t)
	_test_it_cannot_be_activated_with_no_qualifying_monster_in_the_deck(t)
	_test_the_restriction_tracks_the_damage_not_the_deck_alone(t)
	_test_it_does_not_fire_on_damage_taken_by_the_opponent(t)
	_test_it_does_not_fire_without_battle_damage(t)
	_test_damage_from_an_earlier_battle_does_not_carry_over(t)
	_test_a_later_battle_that_damages_the_opponent_does_not_reopen_it(t)
	_test_the_discard_is_a_cost_paid_at_activation(t)
	_test_it_cannot_be_activated_with_an_empty_hand(t)
	_test_it_cannot_be_activated_with_a_full_monster_zone(t)
	_test_the_deck_is_shuffled_afterwards(t)
	_test_its_window_is_substep_four(t)
	_test_the_cost_is_not_refunded_when_the_activation_is_negated(t)
	_test_the_cost_is_not_refunded_when_the_effect_is_negated(t)
	_test_the_summoned_monster_is_a_real_special_summon(t)
	_test_it_is_live_against_the_real_printed_deck(t)
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


## A duel in which player 0 — the Trap's controller — is about to TAKE exactly `damage`
## battle damage, with the Trap Set and an EXACT Deck of `deck_atks`.
##
## `TestFixtures.battle_duel()` puts PLAYER 0 in the Battle Phase as the turn player, so
## the only way to make player 0 take battle damage is for player 0 to attack into a
## bigger monster: the damage is the defender's ATK minus the attacker's. Attacking
## directly would damage the opponent, which is `Vampiric Koala`'s trigger and the exact
## thing this card must NOT answer.
const ATTACKER_ATK := 1000

static func _board(t: TestCase, seed_value: int, damage: int,
		deck_atks: Array = [1000], hand_size: int = 1) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["condenser"] = TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, ATTACKER_ATK, 1000))
	# Face-up ATTACK Position, so the difference in ATK is dealt to the attacking player.
	d["blocker"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Blocker", 4, ATTACKER_ATK + damage, 1000))

	TestFixtures.clear_deck(engine, 0)
	var deck: Array = []
	for i in range(deck_atks.size()):
		deck.append(TestFixtures.give_to_deck(engine, 0,
			TestFixtures.monster("Deck Monster %d" % (i + 1), 4, int(deck_atks[i]), 1000)))
	d["deck"] = deck

	engine.state.player(0).hand.clear()
	var hand: Array = []
	for i in range(hand_size):
		hand.append(TestFixtures.give_to_hand(engine, 0,
			TestFixtures.monster("Hand Card %d" % (i + 1), 4, 800, 800)))
	d["hand"] = hand
	return d


## Declare the direct attack and walk the Damage Step, activating the Trap at the first
## window that offers it. Returns whether it was actually activated.
static func _attack_and_activate(engine: DuelEngine, attacker: CardInstance,
		target, condenser: CardInstance) -> bool:
	if not TestFixtures.attack(engine, attacker, target):
		return false
	var activated := false
	for i in range(24):
		if not activated:
			var offered = TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id)
			if offered != null:
				if engine.submit_action(offered):
					activated = true
					continue
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)
	return activated


## The shared negator fixtures carry `UNTIL_DAMAGE_CALC` (the Counter Trap window) and
## `NONE`, so neither can legally respond in sub-step 4 — which is correct engine behaviour
## and not something to change for a test. This moves ONLY the window, so what is under
## test stays "is Damage Condenser's cost refunded when it is negated?" rather than "which
## cards may be activated in the Damage Step", which `DamageStepTests` already owns.
static func _negator_in_substep_4(def: CardDef) -> CardDef:
	(def.effects[0] as EffectDef).damage_step_permission = 		Enums.DamageStepPermission.AFTER_DAMAGE_CALC
	return def


## Was the Trap ever offered at all during the whole Damage Step? Used by the negative
## tests, which must distinguish "not offered" from "offered and declined".
static func _was_ever_offered(engine: DuelEngine, attacker: CardInstance,
		target, condenser: CardInstance) -> bool:
	if not TestFixtures.attack(engine, attacker, target):
		return false
	var offered := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	return offered


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a Normal Trap card activation, Spell Speed 2, triggered by battle "
		+ "damage, with a DISCARD cost, no targeting, and a sub-step 4 Damage Step window")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.TRAP, "it is a Trap")
	t.eq(def.st_kind, Enums.STKind.NORMAL_TRAP, "and specifically a NORMAL Trap")
	t.eq(def.effects.size(), 1, "exactly one EffectDef, for the card's one clause")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"it is the activation of the card itself, which is what sends it to the GY after")
	t.eq(clause.spell_speed, Enums.SpellSpeed.SS2, "a Normal Trap is Spell Speed 2")
	t.is_false(clause.targets,
		"cid 6582 (対象を取る効果ではありません): it does NOT target")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_DOWN],
		"a Normal Trap is activated from a Set position")
	t.eq(clause.trigger_events, [GameEvent.Kind.BATTLE_DAMAGE_INFLICTED],
		"its window is opened by battle damage")
	t.eq(clause.damage_step_permission, Enums.DamageStepPermission.AFTER_DAMAGE_CALC,
		"cid 6582 (ダメージ計算後に発動します): sub-step 4, the OPPOSITE of Kurenai and Aoi")
	t.ne(clause.damage_step_permission, Enums.DamageStepPermission.NONE,
		"it is emphatically not forbidden in the Damage Step — that is where it lives")
	t.is_true(clause.can_pay_cost.is_valid(), "it declares a cost check")
	t.is_true(clause.pay_cost.is_valid(), "and a cost payment, so the discard is a COST")
	t.is_true(clause.condition.is_valid(),
		"and a condition, which carries the official activation restriction")
	t.is_true(clause.clause_text.contains("Discard 1 card"),
		"the clause quotes the official cost")
	t.is_true(clause.clause_text.contains("in Attack Position"),
		"and quotes the fixed Attack Position")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_it_summons_from_the_deck_in_attack_position(t: TestCase) -> void:
	t.start("it Special Summons a monster out of the DECK, face-up in ATTACK Position")
	var d := _board(t, 8301, 1800, [1000])
	var engine: DuelEngine = d["engine"]
	var summonable: CardInstance = (d["deck"] as Array)[0]
	t.eq(summonable.zone, Enums.Zone.DECK, "the monster starts in the Deck")

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]),
		"the Trap was offered and activated after the battle damage")
	t.eq(summonable.zone, Enums.Zone.MONSTER_ZONE, "and the Deck monster is on the field")
	t.eq(summonable.controller_id, 0, "under its own controller")
	t.eq(summonable.position, Enums.Position.FACE_UP_ATTACK,
		"face-up in ATTACK Position, which the text names and the player never chooses")
	t.eq(d["condenser"].zone, Enums.Zone.GRAVEYARD, "the Normal Trap left after resolving")


static func _test_the_atk_ceiling_is_the_battle_damage_taken(t: TestCase) -> void:
	t.start("the ceiling is the battle damage: a monster at exactly the damage qualifies, "
		+ "one above it does not, and the choice is made from the qualifying set only")
	var d := _board(t, 8302, 1500, [1500, 1600])
	var engine: DuelEngine = d["engine"]
	var exactly: CardInstance = (d["deck"] as Array)[0]
	var too_big: CardInstance = (d["deck"] as Array)[1]

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]), "activated")
	t.eq(exactly.zone, Enums.Zone.MONSTER_ZONE,
		"the 1500 ATK monster was Summoned — `less than or equal to` includes equal")
	t.eq(too_big.zone, Enums.Zone.DECK,
		"and the 1600 ATK monster stayed in the Deck; it was never a candidate")


static func _test_the_atk_read_is_the_printed_one_in_the_deck(t: TestCase) -> void:
	t.start("R42 Part C: the ATK compared is the PRINTED ATK of the card in the Deck — a "
		+ "card in the Deck has no controller, no field and no modifiers")
	var d := _board(t, 8303, 1200, [1200])
	var engine: DuelEngine = d["engine"]
	var summonable: CardInstance = (d["deck"] as Array)[0]
	t.eq(summonable.definition.base_atk, 1200, "its printed ATK is 1200")
	t.eq(summonable.original_atk(), 1200, "and so is its original ATK, in the Deck")
	t.eq(summonable.atk_modifiers.size(), 0,
		"with no modifiers of any kind, because it is not on a field")

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]), "activated")
	t.eq(summonable.zone, Enums.Zone.MONSTER_ZONE, "it was Summoned at exactly the ceiling")


# ---------------------------------------------------------------------------
# The ACTIVATION restriction — the fact PROJECT_STATE §8 did not have
# ---------------------------------------------------------------------------

static func _test_it_cannot_be_activated_with_no_qualifying_monster_in_the_deck(
		t: TestCase) -> void:
	t.start("cid 6582: with NO monster in the Deck at or below the damage, the card cannot "
		+ "be activated at all — it is never offered, rather than resolving for nothing")
	var d := _board(t, 8304, 1000, [2000, 2500])
	var engine: DuelEngine = d["engine"]
	var condenser: CardInstance = d["condenser"]
	var hand_before: int = engine.state.player(0).hand.size()

	t.is_false(_was_ever_offered(engine, d["attacker"], d["blocker"], condenser),
		"it is never offered at any point in the Damage Step")
	t.eq(condenser.zone, Enums.Zone.SPELL_TRAP_ZONE, "the Trap is still Set")
	t.eq(engine.state.player(0).hand.size(), hand_before,
		"and no cost was paid — an unactivated card pays nothing")
	for entry in d["deck"]:
		t.eq((entry as CardInstance).zone, Enums.Zone.DECK,
			"every Deck monster is still in the Deck")


static func _test_the_restriction_tracks_the_damage_not_the_deck_alone(t: TestCase) -> void:
	t.start("the restriction is about the damage AND the Deck together: the same Deck that "
		+ "refuses a small hit admits a large one")
	# Identical Deck, different battle damage. Only the damage changes.
	var small := _board(t, 8305, 1000, [1500])
	t.is_false(_was_ever_offered(small["engine"], small["attacker"], small["blocker"], small["condenser"]),
		"1000 damage against a Deck whose only monster is 1500 ATK: not offered")

	var large := _board(t, 8306, 1500, [1500])
	t.is_true(_was_ever_offered(large["engine"], large["attacker"], large["blocker"], large["condenser"]),
		"1500 damage against the SAME Deck: offered")


static func _test_it_does_not_fire_on_damage_taken_by_the_opponent(t: TestCase) -> void:
	t.start("`when YOU take battle damage`: damage taken by the OPPONENT does not open the "
		+ "window — the mirror image of Vampiric Koala, and a control on it")
	var d := TestFixtures.battle_duel(8307)
	var engine: DuelEngine = d["engine"]
	# The Trap is on player 0, who attacks DIRECTLY. A BATTLE_DAMAGE_INFLICTED event is
	# genuinely raised — for player 1. Everything else about the board would allow the
	# activation, so the ONLY thing being tested is whose damage it was.
	var condenser := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, 1800, 1000))
	TestFixtures.clear_deck(engine, 0)
	var in_deck := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Deck Monster", 4, 1000, 1000))
	engine.state.player(0).hand.clear()
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Hand Card", 4, 800, 800))

	t.is_true(TestFixtures.attack(engine, attacker, null), "a direct attack is declared")
	var offered := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break

	t.is_true(engine.state.player(1).life_points < 8000,
		"the OPPONENT really did take battle damage, so an event WAS raised")
	t.eq(engine.state.player(0).life_points, 8000,
		"while the Trap's controller took none")
	t.is_false(offered,
		"so their Damage Condenser never opened - this is Vampiric Koala's trigger")
	t.eq(in_deck.zone, Enums.Zone.DECK, "and nothing was Summoned")


static func _test_it_does_not_fire_without_battle_damage(t: TestCase) -> void:
	t.start("a battle that inflicts NO damage opens no window: the trigger is the damage, "
		+ "not the battle")
	var d := TestFixtures.battle_duel(8308)
	var engine: DuelEngine = d["engine"]
	var condenser := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, 1500, 1000))
	# An equal-ATK blocker: both are destroyed and NOBODY takes battle damage.
	var blocker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Blocker", 4, 1500, 1000))
	TestFixtures.clear_deck(engine, 0)
	var in_deck := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Deck Monster", 4, 1000, 1000))
	engine.state.player(0).hand.clear()
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Hand Card", 4, 800, 800))

	t.is_true(TestFixtures.attack(engine, attacker, blocker), "the attack is declared")
	var offered := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break

	t.eq(engine.state.player(0).life_points, 8000, "the controller took no damage")
	t.is_false(offered, "so the Trap was never offered")
	t.eq(in_deck.zone, Enums.Zone.DECK, "and nothing was Summoned")


static func _test_an_over_ceiling_monster_is_not_even_a_candidate(t: TestCase) -> void:
	t.start("the ceiling filters the RESOLUTION candidate list too, not just the activation "
		+ "check: an over-ceiling monster cannot be chosen even when the player asks for it")
	# The too-big monster is FIRST in the Deck and the qualifying one second, and the
	# controller is primed to pick the too-big one. With the filter in place there is only
	# ONE candidate, so `choose_one` never asks and the queued answer is never used. With
	# the filter dropped there would be two, the question WOULD be asked, and the wrong
	# monster would arrive on the field.
	var d := _board(t, 8318, 1500, [1600, 1500])
	var engine: DuelEngine = d["engine"]
	var too_big: CardInstance = (d["deck"] as Array)[0]
	var exactly: CardInstance = (d["deck"] as Array)[1]
	var p0: ScriptedController = d["p0"]
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [too_big.id])

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]),
		"activated after 1500 battle damage")
	t.eq(too_big.zone, Enums.Zone.DECK,
		"the 1600 ATK monster is still in the Deck — it was never a candidate to choose")
	t.eq(exactly.zone, Enums.Zone.MONSTER_ZONE,
		"and the 1500 ATK one was Summoned, which is the only legal answer")
	# The attacker lost its battle and was destroyed at sub-step 5, after the Trap had
	# already resolved — so the Summoned monster is the only one left standing.
	t.eq(engine.state.player(0).monsters(), [exactly],
		"and it is the only monster on the field afterwards")


static func _test_damage_from_an_earlier_battle_does_not_carry_over(t: TestCase) -> void:
	t.start("the damage read is THIS battle's: after a first battle that DID damage the "
		+ "controller, a second battle in the same Battle Phase that damages nobody does "
		+ "not open the window")
	var d := TestFixtures.battle_duel(8319)
	var engine: DuelEngine = d["engine"]
	var condenser := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	# Battle 1: a weak attacker into a big blocker — the controller takes 1000 damage.
	var weak := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Weak Attacker", 4, 1000, 1000))
	var big := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Big Blocker", 4, 2000, 1000))
	# Battle 2: an equal-ATK trade — nobody takes any damage at all.
	var even := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Even Attacker", 4, 1500, 1000))
	var mirror := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Mirror Blocker", 4, 1500, 1000))
	TestFixtures.clear_deck(engine, 0)
	var in_deck := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Deck Monster", 4, 500, 500))
	engine.state.player(0).hand.clear()
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Hand Card", 4, 800, 800))

	# Battle 1 — the Trap IS offered here, and is deliberately DECLINED so it survives to
	# battle 2. Asserting that it was offered is what makes the second half meaningful.
	t.is_true(TestFixtures.attack(engine, weak, big), "the first attack is declared")
	var offered_first := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered_first = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)):
			if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
				break
	t.is_true(offered_first, "it WAS offered after the first battle's 1000 damage")
	t.eq(engine.state.player(0).life_points, 7000, "and that damage really happened")
	t.eq(condenser.zone, Enums.Zone.SPELL_TRAP_ZONE, "but it was declined and is still Set")

	# Battle 2 — no damage to anyone. The window must NOT reopen on battle 1's damage.
	t.is_true(TestFixtures.attack(engine, even, mirror), "the second attack is declared")
	var offered_second := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered_second = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)):
			if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
				break

	t.eq(engine.state.player(0).life_points, 7000,
		"the second battle damaged nobody")
	t.is_false(offered_second,
		"so the Trap was NOT offered again — the earlier battle's damage is not this "
		+ "battle's, and the reader stops at the attack declaration")
	t.eq(in_deck.zone, Enums.Zone.DECK, "and nothing was Summoned")


static func _test_a_later_battle_that_damages_the_opponent_does_not_reopen_it(
		t: TestCase) -> void:
	t.start("a second battle that damages the OPPONENT does not reopen the window on the "
		+ "FIRST battle's damage — the case where the trigger-event window alone is not "
		+ "enough, and only the reader's attack-declaration boundary can answer")
	var d := TestFixtures.battle_duel(8320)
	var engine: DuelEngine = d["engine"]
	var condenser := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	# Battle 1: the controller takes 1000.
	var weak := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Weak Attacker", 4, 1000, 1000))
	var big := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Big Blocker", 4, 2000, 1000))
	# Battle 2: the OPPONENT takes 2000. The window therefore DOES contain a
	# BATTLE_DAMAGE_INFLICTED event, so the trigger-event gate opens — and the condition is
	# the only thing left that can say no.
	var strong := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Strong Attacker", 4, 2500, 1000))
	var small := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Small Blocker", 4, 500, 500))
	TestFixtures.clear_deck(engine, 0)
	var in_deck := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Deck Monster", 4, 500, 500))
	engine.state.player(0).hand.clear()
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Hand Card", 4, 800, 800))

	t.is_true(TestFixtures.attack(engine, weak, big), "the first attack is declared")
	var offered_first := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered_first = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)):
			if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
				break
	t.is_true(offered_first, "it WAS offered after the first battle's 1000 damage")
	t.eq(engine.state.player(0).life_points, 7000, "which really happened")
	t.eq(condenser.zone, Enums.Zone.SPELL_TRAP_ZONE, "and was declined, so it is still Set")

	t.is_true(TestFixtures.attack(engine, strong, small), "the second attack is declared")
	var offered_second := false
	for i in range(24):
		if TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, condenser.id) != null:
			offered_second = true
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)):
			if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
				break

	t.eq(engine.state.player(1).life_points, 6000,
		"the second battle really did inflict 2000 on the OPPONENT, so the trigger-event "
		+ "window genuinely opened")
	t.eq(engine.state.player(0).life_points, 7000,
		"while the controller took nothing further")
	t.is_false(offered_second,
		"and the Trap was NOT offered: the reader stops at the second attack declaration "
		+ "rather than reaching back into the first battle")
	t.eq(in_deck.zone, Enums.Zone.DECK, "so nothing was Summoned")


# ---------------------------------------------------------------------------
# The cost
# ---------------------------------------------------------------------------

static func _test_the_discard_is_a_cost_paid_at_activation(t: TestCase) -> void:
	t.start("cid 6582 (コストとして、手札を1枚捨てます): the discard is a COST, and it "
		+ "reaches the Graveyard as a DISCARD rather than as a send")
	var d := _board(t, 8309, 1800, [1000], 1)
	var engine: DuelEngine = d["engine"]
	var hand_card: CardInstance = (d["hand"] as Array)[0]

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]), "activated")
	t.eq(hand_card.zone, Enums.Zone.GRAVEYARD, "the hand card was paid")
	t.eq(hand_card.last_move_reason, Enums.MoveReason.DISCARDED,
		"with the DISCARD reason, because the card says `Discard`")
	t.ne(hand_card.last_move_reason, Enums.MoveReason.SENT_AS_COST,
		"and not the generic send-as-cost reason [S1 p.52-53]")
	t.eq(engine.state.player(0).hand.size(), 0, "the hand is empty afterwards")


static func _test_it_cannot_be_activated_with_an_empty_hand(t: TestCase) -> void:
	t.start("with an empty hand the cost cannot be paid, so the card is not offered — even "
		+ "though the damage and the Deck would both allow it")
	var d := _board(t, 8310, 1800, [1000], 0)
	var engine: DuelEngine = d["engine"]
	t.eq(engine.state.player(0).hand.size(), 0, "the hand really is empty")

	t.is_false(_was_ever_offered(engine, d["attacker"], d["blocker"], d["condenser"]),
		"the Trap is never offered")
	t.eq((d["deck"] as Array)[0].zone, Enums.Zone.DECK, "and nothing was Summoned")


static func _test_it_cannot_be_activated_with_a_full_monster_zone(t: TestCase) -> void:
	t.start("with no free Monster Zone the Summon could not happen, so the card is not "
		+ "offered — the same general-rule check One for One makes")
	var d := _board(t, 8311, 1800, [1000], 1)
	var engine: DuelEngine = d["engine"]
	# `_board` already put the attacker in one zone, so four more fill the field.
	for i in range(4):
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Filler %d" % i, 4, 100, 100),
			Enums.Position.FACE_UP_DEFENSE)
	t.is_false(engine.state.player(0).has_free_monster_zone(),
		"the Monster Zones really are full")

	var condenser: CardInstance = d["condenser"]
	t.is_false(_was_ever_offered(engine, d["attacker"], d["blocker"], condenser),
		"the Trap is never offered")
	t.eq((d["deck"] as Array)[0].zone, Enums.Zone.DECK, "and nothing was Summoned")


# ---------------------------------------------------------------------------
# The shuffle, and the window
# ---------------------------------------------------------------------------

static func _test_the_deck_is_shuffled_afterwards(t: TestCase) -> void:
	t.start("[S1 p.5]: the Deck was looked through, so it is shuffled — which by §12.1 "
		+ "ends all legal knowledge of where anything in it is")
	var d := _board(t, 8312, 1800, [1000, 1200, 1400])
	var engine: DuelEngine = d["engine"]
	var deck: Array = d["deck"]
	# Someone had legally seen two of the Deck's cards before this resolved.
	var watched: CardInstance = deck[1]
	var also_watched: CardInstance = deck[2]
	engine.state.reveal(watched, [0, 1])
	engine.state.reveal(also_watched, [1])
	t.is_true(watched.revealed_to.has(0), "the first is known to player 0")
	t.is_true(also_watched.revealed_to.has(1), "and the second to player 1")

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]), "activated")

	t.eq(watched.zone, Enums.Zone.DECK, "the watched card is still in the Deck")
	t.eq(watched.revealed_to, [],
		"and nobody legally knows where it is any more — the Deck was shuffled")
	t.eq(also_watched.revealed_to, [], "for every card in that Deck, not just one")


static func _test_its_window_is_substep_four(t: TestCase) -> void:
	t.start("its window really is Damage Step sub-step 4, and the rules layer says so at "
		+ "every sub-step — the contrast with Kurenai and Aoi, which are NONE")
	var d := _board(t, 8313, 1800, [1000])
	var engine: DuelEngine = d["engine"]
	var e := _effect(t)
	t.not_null(e, "the clause is reachable")
	if e == null:
		return
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	var allowed: Array = []
	for sub in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		engine.state.damage_substep = sub
		if ActivationRules.damage_step_ok(engine.state, e):
			allowed.append(sub)
	t.eq(allowed, [Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION],
		"exactly one sub-step, and it is the one after damage calculation")

	# The two batch-12 siblings, asserted here so the contrast lives in one place.
	var kurenai: CardDef = _card_def(t, "Spiritual Fire Art - Kurenai")
	var aoi: CardDef = _card_def(t, "Spiritual Water Art - Aoi")
	t.eq((kurenai.effects[0] as EffectDef).damage_step_permission,
		Enums.DamageStepPermission.NONE, "Kurenai is forbidden in the Damage Step")
	t.eq((aoi.effects[0] as EffectDef).damage_step_permission,
		Enums.DamageStepPermission.NONE, "and so is Aoi")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

static func _test_the_cost_is_not_refunded_when_the_activation_is_negated(
		t: TestCase) -> void:
	t.start("the ACTIVATION negated: the discard is NOT refunded and nothing is Summoned")
	var d := _board(t, 8314, 1800, [1000], 1)
	var engine: DuelEngine = d["engine"]
	var hand_card: CardInstance = (d["hand"] as Array)[0]
	var in_deck: CardInstance = (d["deck"] as Array)[0]
	# A Counter Trap may be activated in the Damage Step up until damage calculation, but
	# it may also respond to a Chain built later; the negator is Set on the opponent.
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		_negator_in_substep_4(TestFixtures.activation_negator("Test Counter")))

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var activated := false
	var negated := false
	for i in range(24):
		if not activated:
			var offered = TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, d["condenser"].id)
			if offered != null and engine.submit_action(offered):
				activated = true
				continue
		if activated and not negated:
			var response = TestFixtures.find_action(engine.get_legal_responses(1),
				Enums.ActionKind.ACTIVATE_CARD, negator.id)
			if response != null and engine.submit_action(response):
				negated = true
				continue
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)

	t.is_true(activated, "the Trap was activated")
	t.is_true(negated, "and its activation was negated")
	t.eq(hand_card.zone, Enums.Zone.GRAVEYARD,
		"the discarded card stays in the Graveyard — a cost is never refunded")
	t.eq(in_deck.zone, Enums.Zone.DECK, "and nothing was Summoned")


static func _test_the_cost_is_not_refunded_when_the_effect_is_negated(t: TestCase) -> void:
	t.start("the EFFECT negated: the activation happened, the discard stays spent, and "
		+ "again nothing is Summoned")
	var d := _board(t, 8315, 1800, [1000], 1)
	var engine: DuelEngine = d["engine"]
	var hand_card: CardInstance = (d["hand"] as Array)[0]
	var in_deck: CardInstance = (d["deck"] as Array)[0]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		_negator_in_substep_4(TestFixtures.effect_negator("Test Effect Negator")))

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["blocker"]),
		"the attack is declared")
	var activated := false
	var negated := false
	for i in range(24):
		if not activated:
			var offered = TestFixtures.find_action(engine.get_legal_responses(0),
				Enums.ActionKind.ACTIVATE_CARD, d["condenser"].id)
			if offered != null and engine.submit_action(offered):
				activated = true
				continue
		if activated and not negated:
			var response = TestFixtures.find_action(engine.get_legal_responses(1),
				Enums.ActionKind.ACTIVATE_CARD, negator.id)
			if response != null and engine.submit_action(response):
				negated = true
				continue
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 0)) \
				and not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, 1)):
			break
	TestFixtures.pass_until_open(engine)

	t.is_true(activated, "the Trap was activated")
	t.is_true(negated, "and its effect was negated")
	t.eq(hand_card.zone, Enums.Zone.GRAVEYARD, "the discarded card is still spent")
	t.eq(in_deck.zone, Enums.Zone.DECK, "and nothing was Summoned")


static func _test_the_summoned_monster_is_a_real_special_summon(t: TestCase) -> void:
	t.start("it is a genuine Special Summon: the event is raised and the monster is a "
		+ "normal, attackable, tributable monster afterwards")
	var d := _board(t, 8316, 1800, [1000])
	var engine: DuelEngine = d["engine"]
	var summonable: CardInstance = (d["deck"] as Array)[0]

	t.is_true(_attack_and_activate(engine, d["attacker"], d["blocker"], d["condenser"]), "activated")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		summonable.id), 1, "exactly one Summon event names it")
	t.eq(summonable.zone, Enums.Zone.MONSTER_ZONE, "it is in a Monster Zone")
	t.is_true(summonable.is_face_up(), "face-up")
	t.is_true(engine.state.player(0).monsters().has(summonable),
		"and it is on its controller's field")


# ---------------------------------------------------------------------------
# The real printed pool
# ---------------------------------------------------------------------------

static func _test_it_is_live_against_the_real_printed_deck(t: TestCase) -> void:
	t.start("live on the real deck: `Damage Condenser` is in `Blue-Eyes Dragon Guard`, and "
		+ "a real printed monster from that deck is a legal Summon")
	var flamvell := _card_def(t, "Flamvell Guard")
	t.eq(flamvell.base_atk, 100, "Flamvell Guard's printed ATK is 100")

	var d := TestFixtures.battle_duel(8317)
	var engine: DuelEngine = d["engine"]
	var condenser := TestFixtures.give_set_spell_trap(engine, 0, _card_def(t))
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, 1000, 1000))
	var blocker := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Blocker", 4, 2800, 1000))
	TestFixtures.clear_deck(engine, 0)
	var real_card := TestFixtures.give_to_deck(engine, 0, flamvell)
	engine.state.player(0).hand.clear()
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Hand Card", 4, 800, 800))

	t.is_true(_attack_and_activate(engine, attacker, blocker, condenser),
		"the Trap is activated after 1800 battle damage")
	t.eq(real_card.zone, Enums.Zone.MONSTER_ZONE,
		"and the real printed Flamvell Guard is on the field")
	t.eq(real_card.position, Enums.Position.FACE_UP_ATTACK, "in Attack Position")

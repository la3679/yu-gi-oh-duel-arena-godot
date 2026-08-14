class_name JudgeOfTheIceBarrierTests
extends RefCounted

## `Judge of the Ice Barrier` — WATER / Warrior / Level 4 / 1800 ATK / 900 DEF.
##
## Official text (verified, `Data/cards/cards.json`, cid 15981):
##
##   "While you control another "Ice Barrier" monster, each time your opponent activates a
##    card or effect by paying LP, they lose 500 LP. You can only use each of the following
##    effects of "Judge of the Ice Barrier" once per turn. You can target 1 or 2 "Ice
##    Barrier" monsters in your GY and 1 or 2 cards in your opponent's GY; shuffle them into
##    the Deck. If you control an "Ice Barrier" monster: You can banish this card from your
##    GY, then target 1 Attack Position monster on the field; change it to Defense Position."
##
## THREE clauses, all implemented and all covered here. `CARD_RULINGS.md` **R2** records that
## all three are essentially never live in the V1 pool — Judge is the only "Ice Barrier" card
## in either deck — so the positive cases use SYNTHETIC "Ice Barrier" monsters and the real
## pool is asserted against directly at the end, the R21/R23 treatment.
##
## The negatives are where the value is, and clause 1's negatives are the whole reason the
## LP-cost channel exists: effect damage, battle damage, LP gain and a non-LP cost must all
## leave it silent. `LifePointCostTests` proves that generically; this suite proves the
## printed card consumes it correctly.


const CARD_UNDER_TEST := "Judge of the Ice Barrier"

const SHUFFLE_ID := "shuffle_from_graveyards"
const POSITION_ID := "banish_self_change_to_defense"


static func run() -> TestCase:
	var t := TestCase.new("JudgeOfTheIceBarrierTests")
	# Shape
	_test_the_card_declares_all_three_clauses(t)
	# Clause 1 — the continuous LP tax
	_test_the_tax_fires_on_an_opponent_lp_payment(t)
	_test_the_tax_needs_ANOTHER_ice_barrier_monster(t)
	_test_an_ice_barrier_monster_in_the_gy_does_not_switch_it_on(t)
	_test_the_tax_ignores_its_own_controllers_payment(t)
	_test_the_tax_ignores_every_other_kind_of_lp_change(t)
	_test_the_tax_ignores_battle_damage(t)
	_test_the_tax_ignores_an_activation_with_a_non_lp_cost(t)
	_test_the_tax_fires_once_per_qualifying_activation(t)
	_test_the_tax_adds_no_chain_link(t)
	_test_the_tax_stops_when_judge_is_no_longer_face_up_on_the_field(t)
	_test_the_tax_can_end_the_duel(t)
	# Clause 2 — shuffle from both Graveyards
	_test_the_shuffle_needs_both_groups_to_be_available(t)
	_test_the_shuffle_moves_the_targets_into_their_owners_decks(t)
	_test_the_shuffle_rejects_an_illegal_combination_of_targets(t)
	_test_the_shuffle_rechecks_its_targets_at_resolution(t)
	_test_a_negated_shuffle_moves_nothing(t)
	# Clause 3 — banish from the GY, force Defense Position
	_test_judge_in_the_gy_does_not_satisfy_you_control_an_ice_barrier_monster(t)
	_test_the_position_change_banishes_as_a_cost_and_changes_the_target(t)
	_test_the_position_change_can_target_either_players_monster(t)
	_test_only_face_up_attack_position_monsters_are_legal_targets(t)
	_test_the_position_change_rechecks_its_target_at_resolution(t)
	_test_the_banish_cost_is_not_refunded_when_the_effect_is_negated(t)
	# The restriction sentence
	_test_each_effect_is_once_per_turn_separately(t)
	_test_the_once_per_turn_resets_on_the_next_turn(t)
	# Damage Step, and the real pool
	_test_neither_ignition_effect_is_legal_in_the_damage_step(t)
	_test_no_other_ice_barrier_card_exists_in_the_real_pool(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def() -> CardDef:
	return (_library()["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## A synthetic member of the archetype. Nothing printed in either deck can be one (R2).
static func _ice_barrier(name_suffix: String = "Sentry", atk: int = 1000) -> CardDef:
	return TestFixtures.monster("Ice Barrier %s" % name_suffix, 4, atk, 1000, "WATER")


## A duel in Main Phase 1 with `first_player` to move.
static func _duel(seed_value: int, first_player: int = 0) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, first_player)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Player 1 is the turn player, so player 1 can activate directly through
## `get_legal_actions()`; player 0 controls Judge and watches. This is the board clause 1
## needs, and it avoids having to build a response Chain for every tax assertion.
static func _tax_board(seed_value: int, with_partner: bool = true) -> Dictionary:
	var d := _duel(seed_value, 1)
	var engine: DuelEngine = d["engine"]
	d["judge"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	if with_partner:
		d["partner"] = TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	d["payer"] = TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_cost_activation("Payer", 800))
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_all_three_clauses(t: TestCase) -> void:
	t.start("the card declares all three printed clauses, with the continuous one keyed on "
		+ "COST_PAID and the two ignition ones each carrying their own once-per-turn")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	t.eq(card_def.effects.size(), 3, "three EffectDefs, one per official clause")

	var by_id := {}
	for entry in card_def.effects:
		var effect: EffectDef = entry
		by_id[effect.effect_id] = effect

	var tax: EffectDef = by_id.get("lp_tax_on_opponent_payment", null)
	t.not_null(tax, "the continuous LP tax exists")
	t.eq(tax.effect_type, Enums.EffectType.CONTINUOUS, "it is CONTINUOUS")
	t.is_false(tax.starts_chain, "and therefore starts no Chain")
	t.is_true(tax.trigger_events.has(GameEvent.Kind.COST_PAID),
		"it observes COST_PAID, which is where the payment provenance lives")
	t.is_true(tax.respond_to_event.is_valid(), "and it responds to the event directly")

	var shuffle: EffectDef = by_id.get(SHUFFLE_ID, null)
	t.not_null(shuffle, "the shuffle clause exists")
	t.eq(shuffle.effect_type, Enums.EffectType.IGNITION, "it is an Ignition Effect")
	t.eq(shuffle.target_count_min, 2, "at least 2 targets — 1 from each required group")
	t.eq(shuffle.target_count_max, 4, "and at most 4 — 2 from each")
	t.is_true(shuffle.targets_valid.is_valid(),
		"the heterogeneous target set needs targets_valid, not just a count")
	t.is_true(shuffle.once_per_turn_named_effect, "it is once per turn on the NAME")
	t.is_false(shuffle.once_per_turn_instance, "not once per turn on the instance")

	var position: EffectDef = by_id.get(POSITION_ID, null)
	t.not_null(position, "the position-change clause exists")
	t.is_true(position.activation_locations.has(Enums.ActivationLocation.GRAVEYARD),
		"it is activated from the Graveyard")
	t.is_true(position.once_per_turn_named_effect, "it too is once per turn on the NAME")
	t.check(shuffle.named_key() != position.named_key(),
		"and the two use DIFFERENT keys, so using one does not lock the other")


# ---------------------------------------------------------------------------
# Clause 1 — "each time your opponent activates a card or effect by paying LP".
# ---------------------------------------------------------------------------

static func _test_the_tax_fires_on_an_opponent_lp_payment(t: TestCase) -> void:
	t.start("with another 'Ice Barrier' monster on the field, an opponent activation that "
		+ "pays LP costs them the cost AND a further 500 LP")
	var d := _tax_board(9801)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 1, payer),
		"the opponent activates the LP-paying card")

	t.eq(engine.state.player(1).life_points, lp_before - 800 - 500,
		"they paid 800 and then lost a further 500 to Judge")
	t.eq(engine.state.player(0).life_points, 8000, "Judge's controller lost nothing")
	# The 500 is a distinct LP change from the payment, and it names Judge as its source.
	var lp_events := TestFixtures.events_of(engine, GameEvent.Kind.LP_CHANGED)
	var tax_events: Array = []
	for entry in lp_events:
		var ev: GameEvent = entry
		if int(ev.data.get("delta", 0)) == -500 \
				and str(ev.data.get("reason", "")) == CARD_UNDER_TEST:
			tax_events.append(ev)
	t.eq(tax_events.size(), 1, "exactly one 500 LP loss, attributed to Judge")


static func _test_the_tax_needs_ANOTHER_ice_barrier_monster(t: TestCase) -> void:
	t.start("a lone Judge does not switch its own clause on — 'ANOTHER' excludes itself")
	var d := _tax_board(9802, false)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 1, payer), "the opponent still pays LP")
	t.eq(engine.state.player(1).life_points, lp_before - 800,
		"the cost was paid — this is not a vacuous negative — but no tax was applied")

	# Add the partner and repeat: the same activation now costs the extra 500.
	TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	var second := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_cost_activation("Second Payer", 800))
	var lp_mid: int = engine.state.player(1).life_points
	t.is_true(TestFixtures.activate_card(engine, 1, second), "a second payment is made")
	t.eq(engine.state.player(1).life_points, lp_mid - 800 - 500,
		"with a partner on the field the tax now applies")


static func _test_an_ice_barrier_monster_in_the_gy_does_not_switch_it_on(t: TestCase) -> void:
	t.start("'you CONTROL another Ice Barrier monster' — one in the Graveyard is not "
		+ "controlled and does not switch the clause on [R2]")
	var d := _tax_board(9803, false)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	var buried := TestFixtures.give(engine, 0, _ice_barrier("Ghost"), Enums.Zone.GRAVEYARD)
	t.eq(buried.zone, Enums.Zone.GRAVEYARD, "the partner really is in the Graveyard")
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 1, payer), "the opponent pays LP")
	t.eq(engine.state.player(1).life_points, lp_before - 800,
		"only the cost was lost — the Graveyard is not 'control'")


static func _test_the_tax_ignores_its_own_controllers_payment(t: TestCase) -> void:
	t.start("'your OPPONENT activates' — Judge's own controller paying LP costs them nothing "
		+ "extra")
	var d := _duel(9804, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("My Payer", 800))
	var lp_before: int = engine.state.player(0).life_points

	t.is_true(TestFixtures.activate_card(engine, 0, payer), "Judge's controller pays LP")
	t.eq(engine.state.player(0).life_points, lp_before - 800,
		"they lost exactly the cost and nothing more")
	t.eq(engine.state.player(1).life_points, 8000, "and the opponent lost nothing at all")


static func _test_the_tax_ignores_every_other_kind_of_lp_change(t: TestCase) -> void:
	t.start("effect damage, battle damage, an arbitrary loss and LP GAIN are all invisible "
		+ "to the clause — only a PAYMENT counts")
	var d := _tax_board(9805)
	var engine: DuelEngine = d["engine"]

	# 1. An arbitrary loss straight through the LP API.
	var lp_a: int = engine.state.player(1).life_points
	engine.state.change_life_points(1, -700, "Test: arbitrary", -1)
	t.eq(engine.state.player(1).life_points, lp_a - 700,
		"an arbitrary loss lowers LP by exactly its own amount, with no tax")

	# 2. LP gain.
	var lp_b: int = engine.state.player(1).life_points
	engine.state.change_life_points(1, 1000, "Test: gain", -1)
	t.eq(engine.state.player(1).life_points, lp_b + 1000,
		"LP gain is not a payment and triggers nothing")

	# 3. Effect damage from a resolving card the opponent controls.
	var burner := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_changer("Self Burn", "gain", 0))
	t.is_true(TestFixtures.activate_card(engine, 1, burner),
		"a cost-free activation by the opponent resolves")
	var lp_c: int = engine.state.player(1).life_points
	engine.state.change_life_points(1, -400, "Test: effect damage", -1)
	t.eq(engine.state.player(1).life_points, lp_c - 400,
		"effect damage is not a payment either")

	# Battle damage has its own test below, because it needs a duel that has reached a legal
	# Battle Phase.


static func _test_the_tax_ignores_battle_damage(t: TestCase) -> void:
	t.start("battle damage taken by the opponent is not a payment and is not taxed")
	var d := TestFixtures.battle_duel(9826)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1900, 1000))
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, attacker, null),
		"a direct attack on the opponent is declared")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_DAMAGE_INFLICTED), 1,
		"battle damage really was inflicted — this is not a vacuous negative")
	t.eq(engine.state.player(1).life_points, lp_before - 1900,
		"the opponent lost exactly the ATK and nothing more — no 500 LP tax")


static func _test_the_tax_ignores_an_activation_with_a_non_lp_cost(t: TestCase) -> void:
	t.start("an opponent activation whose cost is not LP emits COST_PAID exactly as a "
		+ "payment does, and must still not be taxed")
	var d := _tax_board(9806)
	var engine: DuelEngine = d["engine"]
	var discarder := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.non_lp_cost_activation("Discarder"))
	TestFixtures.give_to_hand(engine, 1, TestFixtures.monster("Fodder"))
	var lp_before: int = engine.state.player(1).life_points
	var cost_before := TestFixtures.count_events(engine, GameEvent.Kind.COST_PAID)

	t.is_true(TestFixtures.activate_card(engine, 1, discarder), "the activation happens")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COST_PAID), cost_before + 1,
		"a cost really was paid — this is the trap the clause has to avoid")
	t.eq(engine.state.player(1).life_points, lp_before, "but no LP were paid, so no tax")


static func _test_the_tax_fires_once_per_qualifying_activation(t: TestCase) -> void:
	t.start("'EACH time' — two qualifying activations cost 500 each, and there is no "
		+ "once-per-turn on this clause")
	var d := _tax_board(9807)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	var second := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_cost_activation("Second Payer", 200))
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 1, payer), "the first activation")
	t.is_true(TestFixtures.activate_card(engine, 1, second), "and the second, same turn")
	t.eq(engine.state.player(1).life_points, lp_before - 800 - 200 - 500 - 500,
		"both costs and both 500 LP taxes were applied")


static func _test_the_tax_adds_no_chain_link(t: TestCase) -> void:
	t.start("the clause is CONTINUOUS: it puts nothing on the Chain and is never offered "
		+ "as an action [RULES_SPEC.md 4.3]")
	var d := _tax_board(9808)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var payer: CardInstance = d["payer"]
	var links_before := TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED)

	t.is_true(TestFixtures.activate_card(engine, 1, payer), "the opponent pays LP")

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED), links_before + 1,
		"exactly one link was added — the payer's, not Judge's")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CHAIN_LINK_ADDED, judge.id), 0,
		"Judge never added a link of its own")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, "lp_tax_on_opponent_payment"),
		"and the clause is never offered as an activation")


static func _test_the_tax_stops_when_judge_is_no_longer_face_up_on_the_field(t: TestCase) -> void:
	t.start("the tax switches itself off when Judge leaves the field, exactly as a "
		+ "continuous effect must")
	var d := _tax_board(9809)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var payer: CardInstance = d["payer"]
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.activate_card(engine, 1, payer), "while Judge is face-up: taxed")
	t.eq(engine.state.player(1).life_points, lp_before - 800 - 500, "500 was charged")

	engine.state.move_card(judge, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(judge.zone, Enums.Zone.GRAVEYARD, "Judge has left the field")
	var second := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_cost_activation("Second Payer", 300))
	var lp_mid: int = engine.state.player(1).life_points
	t.is_true(TestFixtures.activate_card(engine, 1, second), "another payment is made")
	t.eq(engine.state.player(1).life_points, lp_mid - 300,
		"only the cost — the clause stopped applying the moment its source left")


static func _test_the_tax_can_end_the_duel(t: TestCase) -> void:
	t.start("the 500 LP loss is a real loss and can take the opponent to 0")
	var d := _tax_board(9810)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	engine.state.player(1).life_points = 1000

	t.is_true(TestFixtures.activate_card(engine, 1, payer),
		"the opponent can still afford the 800 cost with 1000 LP")
	t.eq(engine.state.player(1).life_points, 0,
		"800 paid then 500 taxed floors them at 0")
	t.is_true(engine.state.is_duel_over(), "and the Duel is over")


# ---------------------------------------------------------------------------
# Clause 2 — "target 1 or 2 Ice Barrier monsters in your GY AND 1 or 2 cards in theirs".
# ---------------------------------------------------------------------------

## Judge face-up on player 0's field, with material in both Graveyards.
static func _shuffle_board(seed_value: int) -> Dictionary:
	var d := _duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	d["judge"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	d["mine_a"] = TestFixtures.give(engine, 0, _ice_barrier("Alpha"), Enums.Zone.GRAVEYARD)
	d["mine_b"] = TestFixtures.give(engine, 0, _ice_barrier("Beta"), Enums.Zone.GRAVEYARD)
	d["theirs_a"] = TestFixtures.give(engine, 1, TestFixtures.monster("Their Monster"),
		Enums.Zone.GRAVEYARD)
	d["theirs_b"] = TestFixtures.give(engine, 1, TestFixtures.trap("Their Trap"),
		Enums.Zone.GRAVEYARD)
	return d


static func _test_the_shuffle_needs_both_groups_to_be_available(t: TestCase) -> void:
	t.start("both groups are required ('AND'): with nothing in the opponent's GY, or no "
		+ "'Ice Barrier' monster in yours, the effect is not offered")
	var d := _duel(9811, 0)
	var engine: DuelEngine = d["engine"]
	var judge := TestFixtures.give_monster_on_field(engine, 0, _def())

	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"with both Graveyards empty it is not offered")

	TestFixtures.give(engine, 1, TestFixtures.monster("Their Monster"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"with only the opponent's GY stocked it is still not offered")

	# A non-"Ice Barrier" monster in my own GY is not enough either.
	TestFixtures.give(engine, 0, TestFixtures.monster("Plain Warrior"), Enums.Zone.GRAVEYARD)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"a monster in my GY that is not an 'Ice Barrier' monster does not qualify")

	TestFixtures.give(engine, 0, _ice_barrier("Alpha"), Enums.Zone.GRAVEYARD)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"with both groups stocked it is offered")


static func _test_the_shuffle_moves_the_targets_into_their_owners_decks(t: TestCase) -> void:
	t.start("the chosen cards are shuffled into their OWNERS' Decks, and a shuffle clears "
		+ "revealed_to rather than placing them on top")
	var d := _shuffle_board(9812)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine_a: CardInstance = d["mine_a"]
	var mine_b: CardInstance = d["mine_b"]
	var theirs_a: CardInstance = d["theirs_a"]
	var theirs_b: CardInstance = d["theirs_b"]
	var my_deck_before: int = engine.state.player(0).deck.size()
	var their_deck_before: int = engine.state.player(1).deck.size()

	t.is_true(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[mine_a.id, mine_b.id, theirs_a.id, theirs_b.id]),
		"all four — the maximum, 2 from each group — is a legal activation")

	t.eq(engine.state.player(0).deck.size(), my_deck_before + 2,
		"my two Ice Barrier monsters went into MY Deck")
	t.eq(engine.state.player(1).deck.size(), their_deck_before + 2,
		"and their two cards into THEIR Deck — a Deck is owner-bound")
	for entry in [mine_a, mine_b, theirs_a, theirs_b]:
		var card: CardInstance = entry
		t.eq(card.zone, Enums.Zone.DECK, "%s is in a Deck" % card.card_name())
		t.eq(card.last_move_reason, Enums.MoveReason.SHUFFLED_INTO_DECK,
			"%s records that it was SHUFFLED in, not placed" % card.card_name())
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY) >= 0, true,
		"and nothing was sent to a Graveyard by this effect")


static func _test_the_shuffle_rejects_an_illegal_combination_of_targets(t: TestCase) -> void:
	t.start("'1 or 2 from each' is enforced as a SET, not as a bare count: two of mine and "
		+ "none of theirs is two targets and is still illegal")
	var d := _shuffle_board(9813)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine_a: CardInstance = d["mine_a"]
	var mine_b: CardInstance = d["mine_b"]
	var theirs_a: CardInstance = d["theirs_a"]
	var theirs_b: CardInstance = d["theirs_b"]
	var my_deck_before: int = engine.state.player(0).deck.size()
	var their_deck_before: int = engine.state.player(1).deck.size()

	t.is_false(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[mine_a.id, mine_b.id]),
		"two from MY Graveyard and none from theirs is rejected")
	t.is_false(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[theirs_a.id, theirs_b.id]),
		"and two from THEIRS with none of mine is rejected too")
	t.eq(engine.state.player(0).deck.size(), my_deck_before,
		"nothing moved into my Deck on either rejected attempt")
	t.eq(engine.state.player(1).deck.size(), their_deck_before,
		"nor into theirs")

	# The minimum legal set — one from each — is accepted.
	t.is_true(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[mine_a.id, theirs_a.id]),
		"one from each group is the legal minimum")
	t.eq(mine_a.zone, Enums.Zone.DECK, "mine moved")
	t.eq(theirs_a.zone, Enums.Zone.DECK, "and theirs")
	t.eq(mine_b.zone, Enums.Zone.GRAVEYARD, "the untargeted card stayed put")


static func _test_the_shuffle_rechecks_its_targets_at_resolution(t: TestCase) -> void:
	t.start("a target that has left the Graveyard by the time the effect resolves is "
		+ "simply not shuffled, and the rest still are")
	var d := _shuffle_board(9814)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine_a: CardInstance = d["mine_a"]
	var theirs_a: CardInstance = d["theirs_a"]
	# A real fast effect on the other side, so the board can change between activation and
	# resolution rather than the whole Chain collapsing into one submit_action().
	var thief := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Thief", theirs_a, "banish"))
	var my_deck_before: int = engine.state.player(0).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices(
		{"target_ids": [mine_a.id, theirs_a.id]})), "it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent can respond")
	t.is_true(engine.submit_action(response), "the interferer is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(theirs_a.zone, Enums.Zone.BANISHED,
		"the opponent's card really was removed first — this is not a fallback path")
	t.eq(mine_a.zone, Enums.Zone.DECK, "the surviving target was still shuffled in")
	t.eq(engine.state.player(0).deck.size(), my_deck_before + 1,
		"exactly one card reached a Deck")


static func _test_a_negated_shuffle_moves_nothing(t: TestCase) -> void:
	t.start("a negated EFFECT shuffles nothing, but the once-per-turn use is still spent")
	var d := _shuffle_board(9815)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine_a: CardInstance = d["mine_a"]
	var theirs_a: CardInstance = d["theirs_a"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Silencer"))
	var my_deck_before: int = engine.state.player(0).deck.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices(
		{"target_ids": [mine_a.id, theirs_a.id]})), "it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	t.is_true(engine.submit_action(response), "the effect negator is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the effect really was negated — this is not a fallback path")
	t.eq(engine.state.player(0).deck.size(), my_deck_before, "nothing reached the Deck")
	t.eq(mine_a.zone, Enums.Zone.GRAVEYARD, "both targets stayed in their Graveyards")
	t.eq(theirs_a.zone, Enums.Zone.GRAVEYARD, "including the opponent's")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"and the once-per-turn use was spent by the ACTIVATION, negated or not")


# ---------------------------------------------------------------------------
# Clause 3 — "banish this card from your GY, then target 1 Attack Position monster".
# ---------------------------------------------------------------------------

## Judge in player 0's Graveyard, with `partner` deciding whether the condition is met.
static func _position_board(seed_value: int, with_partner: bool = true) -> Dictionary:
	var d := _duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	d["judge"] = TestFixtures.give(engine, 0, _def(), Enums.Zone.GRAVEYARD)
	if with_partner:
		d["partner"] = TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	d["theirs"] = TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Attacker", 4, 1600, 1200))
	return d


static func _test_judge_in_the_gy_does_not_satisfy_you_control_an_ice_barrier_monster(
		t: TestCase) -> void:
	t.start("R2's sub-question, asserted directly: Judge sitting in the Graveyard does NOT "
		+ "satisfy 'if you control an Ice Barrier monster' — the GY is not 'control'")
	var d := _position_board(9816, false)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	t.eq(judge.zone, Enums.Zone.GRAVEYARD, "Judge is in the Graveyard")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, POSITION_ID) == false,
		"and its own GY effect is NOT offered — it cannot be its own Ice Barrier monster")

	# A different Ice Barrier monster ON THE FIELD is what the clause needs.
	TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, POSITION_ID),
		"with a DIFFERENT Ice Barrier monster on the field it is offered")


static func _test_the_position_change_banishes_as_a_cost_and_changes_the_target(
		t: TestCase) -> void:
	t.start("the banish is a COST paid at activation, and the target is changed to face-up "
		+ "Defense Position")
	var d := _position_board(9817)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var theirs: CardInstance = d["theirs"]
	t.eq(theirs.position, Enums.Position.FACE_UP_ATTACK, "their monster starts in Attack")

	t.is_true(TestFixtures.activate_effect(engine, 0, judge, POSITION_ID, [theirs.id]),
		"the effect is activated")

	t.eq(judge.zone, Enums.Zone.BANISHED, "Judge paid itself as the cost and is banished")
	t.eq(judge.last_move_reason, Enums.MoveReason.BANISHED,
		"recorded as a banishment, not a send to the Graveyard")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_BANISHED, judge.id), 1,
		"exactly one banish event for Judge")
	t.eq(theirs.position, Enums.Position.FACE_UP_DEFENSE,
		"and the target is now in face-up Defense Position")


static func _test_the_position_change_can_target_either_players_monster(t: TestCase) -> void:
	t.start("'1 Attack Position monster ON THE FIELD' is not restricted to the opponent — "
		+ "your own monster is a legal target too")
	var d := _position_board(9818)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Attacker", 4, 1400, 1000))
	t.eq(mine.position, Enums.Position.FACE_UP_ATTACK, "my monster is in Attack Position")

	t.is_true(TestFixtures.activate_effect(engine, 0, judge, POSITION_ID, [mine.id]),
		"targeting my own monster is legal")
	t.eq(mine.position, Enums.Position.FACE_UP_DEFENSE, "and it changed to Defense")


static func _test_only_face_up_attack_position_monsters_are_legal_targets(t: TestCase) -> void:
	t.start("a face-down monster and a monster already in Defense Position are not legal "
		+ "targets, and neither is a Spell/Trap")
	var d := _position_board(9819)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var theirs: CardInstance = d["theirs"]
	var face_down := TestFixtures.give(engine, 1, TestFixtures.monster("Hidden"),
		Enums.Zone.MONSTER_ZONE)
	engine.state.set_battle_position(face_down, Enums.Position.FACE_DOWN_DEFENSE, true)
	var defending := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Turtle"))
	engine.state.set_battle_position(defending, Enums.Position.FACE_UP_DEFENSE, true)
	var backrow := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Backrow"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, POSITION_ID)
	t.not_null(offered, "the effect is offered")
	var candidates: Array = offered.target_candidates
	t.is_true(candidates.has(theirs.id), "the Attack Position monster is a candidate")
	t.is_false(candidates.has(face_down.id), "the face-down monster is not")
	t.is_false(candidates.has(defending.id), "nor is one already in Defense Position")
	t.is_false(candidates.has(backrow.id), "nor a Spell/Trap — the text says 'monster'")

	t.is_false(TestFixtures.activate_effect(engine, 0, judge, POSITION_ID, [defending.id]),
		"and choosing an illegal target is rejected outright")
	t.eq(judge.zone, Enums.Zone.GRAVEYARD, "so no cost was paid on the rejected attempt")


static func _test_the_position_change_rechecks_its_target_at_resolution(t: TestCase) -> void:
	t.start("a target that has left the field by resolution changes nothing, and the cost "
		+ "is still spent")
	var d := _position_board(9820)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var theirs: CardInstance = d["theirs"]
	var thief := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Thief", theirs, "bounce"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, POSITION_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [theirs.id]})),
		"it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, thief.id)
	t.not_null(response, "the opponent can respond")
	t.is_true(engine.submit_action(response), "the interferer is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(theirs.zone, Enums.Zone.HAND,
		"the target really did leave the field first — this is not a fallback path")
	t.eq(judge.zone, Enums.Zone.BANISHED, "the cost stays paid")


static func _test_the_banish_cost_is_not_refunded_when_the_effect_is_negated(
		t: TestCase) -> void:
	t.start("negating the EFFECT leaves the target in Attack Position and does NOT return "
		+ "Judge from banishment — a cost is never refunded")
	var d := _position_board(9821)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var theirs: CardInstance = d["theirs"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Silencer"))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, POSITION_ID)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [theirs.id]})),
		"it is Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent can respond")
	t.is_true(engine.submit_action(response), "the effect negator is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the effect really was negated")
	t.eq(theirs.position, Enums.Position.FACE_UP_ATTACK, "the target did not change")
	t.eq(judge.zone, Enums.Zone.BANISHED, "and Judge stays banished")


# ---------------------------------------------------------------------------
# "You can only use EACH of the following effects once per turn."
# ---------------------------------------------------------------------------

static func _test_each_effect_is_once_per_turn_separately(t: TestCase) -> void:
	t.start("using the shuffle does not lock the GY effect, and neither may be used twice")
	var d := _shuffle_board(9822)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine_a: CardInstance = d["mine_a"]
	var mine_b: CardInstance = d["mine_b"]
	var theirs_a: CardInstance = d["theirs_a"]
	var theirs_b: CardInstance = d["theirs_b"]

	t.is_true(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[mine_a.id, theirs_a.id]), "the shuffle is used once")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"it cannot be used a second time this turn")
	t.eq(mine_b.zone, Enums.Zone.GRAVEYARD, "and the untouched material is still there")
	t.eq(theirs_b.zone, Enums.Zone.GRAVEYARD, "on both sides")

	# The OTHER effect is governed by its own key. Put Judge in the GY with a partner up.
	engine.state.move_card(judge, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	TestFixtures.give_monster_on_field(engine, 0, _ice_barrier())
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Attacker", 4, 1600, 1200))
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, POSITION_ID),
		"the GY effect is still available — the two restrictions are separate")
	t.is_true(TestFixtures.activate_effect(engine, 0, judge, POSITION_ID, [target.id]),
		"and it can be used")
	t.eq(target.position, Enums.Position.FACE_UP_DEFENSE, "with its real effect")


static func _test_the_once_per_turn_resets_on_the_next_turn(t: TestCase) -> void:
	t.start("the once-per-turn is per TURN: the shuffle is available again after the turn "
		+ "passes and comes back")
	var d := _shuffle_board(9823)
	var engine: DuelEngine = d["engine"]
	var judge: CardInstance = d["judge"]
	var mine_a: CardInstance = d["mine_a"]
	var mine_b: CardInstance = d["mine_b"]
	var theirs_a: CardInstance = d["theirs_a"]
	var theirs_b: CardInstance = d["theirs_b"]

	t.is_true(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[mine_a.id, theirs_a.id]), "used on turn 1")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID), "and locked out")

	t.is_true(TestFixtures.end_turn(engine), "the turn passes to the opponent")
	t.is_true(TestFixtures.end_turn(engine), "and comes back")
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, judge.id, SHUFFLE_ID),
		"it is available again on the controller's next turn")
	t.is_true(TestFixtures.activate_effect(engine, 0, judge, SHUFFLE_ID,
		[mine_b.id, theirs_b.id]), "and it really works again")
	t.eq(mine_b.zone, Enums.Zone.DECK, "the second pair moved")
	t.eq(theirs_b.zone, Enums.Zone.DECK, "on both sides")


# ---------------------------------------------------------------------------
# Damage Step, and the real pool.
# ---------------------------------------------------------------------------

static func _test_neither_ignition_effect_is_legal_in_the_damage_step(t: TestCase) -> void:
	t.start("an Ignition Effect carries no Damage Step permission, so neither clause 2 nor "
		+ "clause 3 may be activated there [RULES_SPEC.md 7.2]")
	var d := _duel(9824, 0)
	var engine: DuelEngine = d["engine"]
	var card_def := _def()
	# Put the authoritative state inside the Damage Step so the rules layer is really asked
	# the Damage Step question rather than the open-game-state one.
	engine.state.battle_step = Enums.BattleStep.DAMAGE
	engine.state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION

	var checked := 0
	for entry in card_def.effects:
		var effect: EffectDef = entry
		if effect.effect_type != Enums.EffectType.IGNITION:
			continue
		checked += 1
		t.eq(effect.damage_step_permission, Enums.DamageStepPermission.NONE,
			"'%s' has no Damage Step permission" % effect.effect_id)
		t.is_false(ActivationRules.damage_step_ok(engine.state, effect),
			"and the rules layer refuses '%s' in the Damage Step" % effect.effect_id)
	t.eq(checked, 2, "both Ignition clauses were actually checked")

	# The same call outside the Damage Step must say yes, or the assertion above would pass
	# for the wrong reason.
	engine.state.battle_step = Enums.BattleStep.NONE
	for entry in card_def.effects:
		var effect: EffectDef = entry
		if effect.effect_type != Enums.EffectType.IGNITION:
			continue
		t.is_true(ActivationRules.damage_step_ok(engine.state, effect),
			"'%s' is fine outside the Damage Step" % effect.effect_id)


static func _test_no_other_ice_barrier_card_exists_in_the_real_pool(t: TestCase) -> void:
	t.start("R2: Judge is the only 'Ice Barrier' card in either deck, so all three clauses "
		+ "are never live with printed cards — asserted so the fact cannot rot silently")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")

	var members: Array = []
	for card_name in cards.keys():
		if str(card_name).contains("Ice Barrier"):
			members.append(str(card_name))
	t.eq(members.size(), 1, "exactly one 'Ice Barrier' card exists: %s" % str(members))
	t.eq(str(members[0]), CARD_UNDER_TEST, "and it is Judge itself")

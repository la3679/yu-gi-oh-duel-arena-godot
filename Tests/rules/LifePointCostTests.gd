class_name LifePointCostTests
extends RefCounted

## PAYING LIFE POINTS AS AN ACTIVATION COST. Rules under test: `RULES_SPEC.md §10`, `§10.4`,
## `§4.3`, `§5.7`; `CARD_RULINGS.md` **R31**.
##
## This is the **LP-cost gate**, written the way `EquipTests`, `ControlTests`,
## `MovementTests` and `BanishTests` were: a RULES suite built from synthetic cards, so what
## it proves is that the ENGINE is right rather than that one printed card happens to work.
## `Judge of the Ice Barrier` is only implemented once it passes.
##
## **The one load-bearing claim: "paid LP" is a property of an ACTIVATION, never of an LP
## delta.** Life Points fall for many unrelated reasons, and a clause that keys on "activates
## a card or effect by paying LP" must see none of them. Every one of these is asserted to be
## invisible to a Judge-style watcher, in both directions:
##
##   effect damage · battle damage · an arbitrary LP loss written by a resolving effect ·
##   an LP reduction caused by some other card resolving · LP GAIN ·
##   an activation whose cost is not LP at all
##
## The provenance therefore rides the COST channel that already existed since batch 4:
## `EffectPrimitives.pay_life_points_cost()` writes `LP_COST_KEY` into `ctx.cost_payload`,
## which `DuelEngine._perform_activation()` copies into BOTH the `COST_PAID` event and the
## `ChainLink`. Per-link, so a Chain of several activations cannot attribute one player's
## payment to another link. No engine change was needed to carry it, which is the point.
##
## The second claim is about the SHAPE of the observer. "Each time your opponent activates a
## card or effect by paying LP, they lose 500 LP" is a CONTINUOUS effect: it applies the
## instant the event happens, it puts nothing on the Chain, and it is never offered as a
## choice. `RULES_SPEC.md §4.3` already records that paying a cost is not an activation and
## cannot be chained to, which is exactly why it cannot be a Trigger Effect. That is
## `EffectDef.respond_to_event` + `ContinuousEffects.respond_to()`, tested here generically.
##
## **No card in the V1 pool pays LP as a cost.** That is asserted against the real 77-card
## pool below so it cannot rot silently, and it is why every fixture here is synthetic — the
## same treatment R21 (`Apprentice Magician`) and R23 (`Fairy Tail - Rella`) established.


static func run() -> TestCase:
	var t := TestCase.new("LifePointCostTests")
	# Paying
	_test_lp_can_be_paid_as_an_activation_cost(t)
	_test_the_payment_happens_at_activation_not_at_resolution(t)
	_test_affordability_gates_the_activation(t)
	# The payment is never refunded
	_test_a_negated_activation_does_not_refund_the_lp(t)
	_test_a_negated_effect_does_not_refund_the_lp(t)
	# Provenance
	_test_the_activation_records_that_lp_was_paid(t)
	_test_a_watcher_identifies_the_correct_opponent_activation(t)
	_test_an_effect_activation_counts_not_just_a_card_activation(t)
	_test_the_watcher_ignores_its_own_controllers_payments(t)
	# Everything that is NOT a payment
	_test_effect_damage_does_not_count(t)
	_test_battle_damage_does_not_count(t)
	_test_an_arbitrary_lp_loss_does_not_count(t)
	_test_lp_gain_does_not_count(t)
	_test_an_activation_with_a_non_lp_cost_does_not_count(t)
	# Several activations at once
	_test_multiple_activations_each_keep_their_own_provenance(t)
	_test_chain_ordering_attributes_each_payment_to_its_own_link(t)
	# Determinism, and the real pool
	_test_the_whole_cycle_is_replay_deterministic(t)
	_test_no_card_in_the_real_pool_pays_lp_as_a_cost(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A board where player 0 controls a watcher for player 1's LP payments, and player 1 holds
## a Set Trap that costs `amount` LP to activate.
static func _watched_board(seed_value: int, amount: int = 800) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	d["seen"] = seen
	d["watcher"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.lp_cost_watcher("Watcher", 1, seen))
	d["payer"] = TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_cost_activation("Payer", amount))
	d["amount"] = amount
	return d


## The `COST_PAID` events emitted so far, newest last.
static func _cost_events(engine: DuelEngine) -> Array:
	return TestFixtures.events_of(engine, GameEvent.Kind.COST_PAID)


## Activate `card` as player `pid` in a RESPONSE window and let the Chain finish.
static func _respond_with(engine: DuelEngine, pid: int, card: CardInstance) -> bool:
	var response = TestFixtures.find_action(engine.get_legal_responses(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	if response == null:
		return false
	return engine.submit_action(response)


# ---------------------------------------------------------------------------
# Paying. RULES_SPEC.md 10 — costs are paid at ACTIVATION.
# ---------------------------------------------------------------------------

static func _test_lp_can_be_paid_as_an_activation_cost(t: TestCase) -> void:
	t.start("LP can be paid as an activation cost: the LP leave immediately, the activation "
		+ "records the amount, and the LP change is tagged as a cost rather than as damage")
	var d := _duel(9701)
	var engine: DuelEngine = d["engine"]
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer", 800))
	var lp_before: int = engine.state.player(0).life_points
	var cost_events_before: int = _cost_events(engine).size()

	t.is_true(TestFixtures.activate_card(engine, 0, payer), "the activation is offered")

	t.eq(engine.state.player(0).life_points, lp_before - 800,
		"the payer lost exactly the cost")
	t.eq(engine.state.player(1).life_points, 8000,
		"and the opponent's LP were untouched — a cost is paid by the activating player")
	var events := _cost_events(engine)
	t.eq(events.size(), cost_events_before + 1, "exactly one COST_PAID was emitted")
	var ev: GameEvent = events[events.size() - 1]
	t.eq(int(ev.data.get("player", -1)), 0, "attributed to the activating player")
	var payload: Dictionary = ev.data.get("payload", {})
	t.eq(EffectPrimitives.life_points_paid_in(payload), 800,
		"and the payload records the amount actually paid")
	t.is_true(EffectPrimitives.activation_paid_life_points(payload),
		"so the activation is identifiable as one that paid LP")

	# The LP_CHANGED event is tagged too, which is hygiene rather than the mechanism: a card
	# reads the COST channel above, never this string.
	var lp_events := TestFixtures.events_of(engine, GameEvent.Kind.LP_CHANGED)
	var last_lp: GameEvent = lp_events[lp_events.size() - 1]
	t.eq(str(last_lp.data.get("reason", "")), EffectPrimitives.LP_COST_REASON,
		"the LP change is tagged as an activation cost")
	t.eq(int(last_lp.data.get("delta", 0)), -800, "with the paid amount as a negative delta")


static func _test_the_payment_happens_at_activation_not_at_resolution(t: TestCase) -> void:
	t.start("the LP are gone as soon as the card is activated — before the Chain resolves, "
		+ "not when the effect resolves [RULES_SPEC.md 10]")
	var d := _duel(9702)
	var engine: DuelEngine = d["engine"]
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer", 700))
	# A responder on the other side keeps the window open, so the state between activation
	# and resolution is genuinely observable rather than collapsed into one submit_action().
	var spacer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_cost_activation("Spacer", 100))
	var lp_before: int = engine.state.player(0).life_points

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it becomes Chain Link 1")

	# The Chain is still BUILDING here: nothing has resolved.
	t.eq(engine.state.chain.size(), 1, "the Chain has exactly one link and has not resolved")
	var link: ChainLink = engine.state.chain[0]
	t.is_false(link.resolved, "Chain Link 1 has not resolved yet")
	t.eq(engine.state.player(0).life_points, lp_before - 700,
		"but the LP are ALREADY paid — a cost is not deferred to resolution")
	t.eq(EffectPrimitives.life_points_paid_in(link.cost_payload), 700,
		"and the Chain Link carries the payment from the moment it exists")

	t.is_true(_respond_with(engine, 1, spacer), "the opponent responds, so the Chain is real")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(0).life_points, lp_before - 700,
		"resolution does not charge the cost a second time")


static func _test_affordability_gates_the_activation(t: TestCase) -> void:
	t.start("an activation whose LP cost cannot be paid is never offered, and the engine "
		+ "requires the payer to be left with at least 1 LP [CARD_RULINGS.md R31]")
	var d := _duel(9703)
	var engine: DuelEngine = d["engine"]
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer", 800))

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id),
		"with 8000 LP the activation is offered")

	# Below the cost: not affordable.
	engine.state.player(0).life_points = 500
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id),
		"with less LP than the cost it is not offered at all")

	# Exactly the cost: R31's disputed edge. The TCG reading requires LP to remain, so this
	# is NOT payable. Nothing in the V1 pool can reach this, and the decision is isolated in
	# `EffectPrimitives.can_pay_life_points_cost()`.
	engine.state.player(0).life_points = 800
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id),
		"with LP exactly equal to the cost it is still not offered [R31]")

	engine.state.player(0).life_points = 801
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id),
		"one LP above the cost it is offered again")
	t.is_true(TestFixtures.activate_card(engine, 0, payer), "and it can actually be paid")
	t.eq(engine.state.player(0).life_points, 1,
		"leaving exactly 1 LP, so the payer did not lose the Duel to their own cost")
	t.is_false(engine.state.is_duel_over(), "the Duel is still going")


# ---------------------------------------------------------------------------
# A cost is never refunded. RULES_SPEC.md 10.
# ---------------------------------------------------------------------------

static func _test_a_negated_activation_does_not_refund_the_lp(t: TestCase) -> void:
	t.start("negating the ACTIVATION does not give the LP back — a cost is paid before "
		+ "anything can respond to it and is never undone")
	var d := _duel(9704)
	var engine: DuelEngine = d["engine"]
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer", 900))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Counter"))
	var lp_before: int = engine.state.player(0).life_points

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id)
	t.not_null(offered, "the activation is offered")
	t.is_true(engine.submit_action(offered), "it is Chain Link 1")
	t.is_true(_respond_with(engine, 1, negator), "the Counter Trap is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"the activation really was negated — this is not a fallback path")
	t.eq(engine.state.player(0).life_points, lp_before - 900,
		"and the 900 LP stay paid")


static func _test_a_negated_effect_does_not_refund_the_lp(t: TestCase) -> void:
	t.start("negating the EFFECT does not give the LP back either, and the activation is "
		+ "still recorded as one that paid LP")
	var d := _watched_board(9705, 600)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	var seen: Array = d["seen"]
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.effect_negator("Silencer"))
	var lp_before: int = engine.state.player(1).life_points

	# Player 1 must respond rather than act: only the turn player gets get_legal_actions().
	var opener := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_changer("Opener", "gain", 0))
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, opener.id)
	t.not_null(offered, "the turn player opens the Chain")
	t.is_true(engine.submit_action(offered), "Chain Link 1")
	t.is_true(_respond_with(engine, 1, payer), "the LP payer is Chain Link 2")
	t.is_true(_respond_with(engine, 0, negator), "the effect negator is Chain Link 3")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the effect really was negated — this is not a fallback path")
	t.eq(engine.state.player(1).life_points, lp_before - 600, "and the 600 LP stay paid")
	t.eq(seen.size(), 1,
		"the watcher still saw the activation: negating an effect does not un-activate it")
	t.eq(int((seen[0] as Dictionary).get("amount", 0)), 600, "with the right amount")


# ---------------------------------------------------------------------------
# Provenance — the whole point of the unit.
# ---------------------------------------------------------------------------

static func _test_the_activation_records_that_lp_was_paid(t: TestCase) -> void:
	t.start("the Chain Link — not the LP total — is what records that this activation paid "
		+ "LP, and a link that paid nothing records nothing")
	var d := _duel(9706)
	var engine: DuelEngine = d["engine"]
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer", 500))
	var free_card := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_changer("Free", "gain", 100))
	# A spare response on player 0's side keeps the window open after Chain Link 2. Without
	# it the engine correctly auto-passes and resolves the whole Chain inside one
	# submit_action(), and `state.chain` is already empty by the time it is read.
	TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.lp_changer("Spare", "gain", 0))

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, payer.id)
	t.is_true(engine.submit_action(offered), "the payer is Chain Link 1")
	t.is_true(_respond_with(engine, 1, free_card), "a cost-free card is Chain Link 2")
	t.eq(engine.state.chain.size(), 2, "the Chain really is two links deep")

	var link1: ChainLink = engine.state.chain[0]
	var link2: ChainLink = engine.state.chain[1]
	t.eq(link1.link_number, 1, "the payer is link 1")
	t.eq(link2.link_number, 2, "the cost-free card is link 2")
	t.is_true(EffectPrimitives.activation_paid_life_points(link1.cost_payload),
		"link 1 is recorded as having paid LP")
	t.is_false(EffectPrimitives.activation_paid_life_points(link2.cost_payload),
		"link 2 is not — and it is on the same Chain, in the same window")
	t.eq(EffectPrimitives.life_points_paid_in(link2.cost_payload), 0,
		"a link that paid no LP reads back as zero, not as an error")
	TestFixtures.pass_until_open(engine)


static func _test_a_watcher_identifies_the_correct_opponent_activation(t: TestCase) -> void:
	t.start("a Judge-style CONTINUOUS watcher fires once, immediately, for the opponent's "
		+ "LP-paying activation, and puts nothing on the Chain")
	var d := _watched_board(9707, 800)
	var engine: DuelEngine = d["engine"]
	var payer: CardInstance = d["payer"]
	var seen: Array = d["seen"]
	var chain_links_before := TestFixtures.count_events(engine,
		GameEvent.Kind.CHAIN_LINK_ADDED)

	# Player 1 responds to a Chain the turn player opens. The spare keeps the window open
	# after Chain Link 2 so the Chain can be inspected before it resolves.
	var opener := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_changer("Opener", "gain", 0))
	TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.lp_changer("Spare", "gain", 0))
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, opener.id)
	t.is_true(engine.submit_action(offered), "Chain Link 1")
	t.is_true(_respond_with(engine, 1, payer), "the LP payer is Chain Link 2")

	t.eq(seen.size(), 1, "the watcher fired exactly once")
	var record: Dictionary = seen[0]
	t.eq(str(record.get("card_name", "")), "Payer", "for the right card")
	t.eq(str(record.get("effect_id", "")), "lp_cost_activation", "and the right effect")
	t.eq(int(record.get("amount", 0)), 800, "reading the amount from the cost payload")
	# It is a continuous effect, so it adds no link of its own.
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED),
		chain_links_before + 2,
		"only the two real activations added links — the watcher added none")
	t.eq(engine.state.chain.size(), 2, "the Chain is exactly the two activated cards")
	TestFixtures.pass_until_open(engine)


static func _test_an_effect_activation_counts_not_just_a_card_activation(t: TestCase) -> void:
	t.start("'a card OR EFFECT' — an Ignition Effect activated from a monster already on "
		+ "the field counts exactly as a card activation does")
	var d := _duel(9708)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.lp_cost_watcher("Watcher", 0, seen))
	var user := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.lp_cost_ignition("Payer Monster", 400))
	var lp_before: int = engine.state.player(0).life_points

	t.is_true(TestFixtures.activate_effect(engine, 0, user, "lp_cost_ignition"),
		"the Ignition Effect is activated")
	t.eq(engine.state.player(0).life_points, lp_before - 400, "the LP were paid")
	t.eq(seen.size(), 1, "the watcher saw it")
	t.eq(str((seen[0] as Dictionary).get("effect_id", "")), "lp_cost_ignition",
		"and identified the EFFECT, not a card activation")


static func _test_the_watcher_ignores_its_own_controllers_payments(t: TestCase) -> void:
	t.start("'your OPPONENT activates' — the watcher does not fire for its own controller's "
		+ "LP payment")
	var d := _duel(9709)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	# The watcher belongs to player 0 and watches player 1; player 0 is the one who pays.
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.lp_cost_watcher("Watcher", 1, seen))
	var payer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer", 800))
	var lp_before: int = engine.state.player(0).life_points

	t.is_true(TestFixtures.activate_card(engine, 0, payer), "player 0 pays LP")
	t.eq(engine.state.player(0).life_points, lp_before - 800,
		"the payment really happened — this is not a vacuous negative")
	t.eq(seen.size(), 0, "but the watcher did not fire: it is not the watched player")


# ---------------------------------------------------------------------------
# Everything that is NOT a payment. RULES_SPEC.md 10.4.
# ---------------------------------------------------------------------------

static func _test_effect_damage_does_not_count(t: TestCase) -> void:
	t.start("effect damage is not a paid cost — the watched player's LP fall and the "
		+ "watcher does not fire")
	var d := _duel(9710)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.lp_cost_watcher("Watcher", 0, seen))
	# Player 1's card damages player 0, who is the watched player.
	var burner := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_changer("Burner", "damage", 500))
	var opener := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_changer("Opener", "gain", 0))
	var lp_before: int = engine.state.player(0).life_points

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, opener.id)
	t.is_true(engine.submit_action(offered), "Chain Link 1")
	t.is_true(_respond_with(engine, 1, burner), "the burner is Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(engine.state.player(0).life_points, lp_before - 500,
		"the watched player really did lose 500 LP")
	t.eq(seen.size(), 0, "but no payment was made, so the watcher did not fire")


static func _test_battle_damage_does_not_count(t: TestCase) -> void:
	t.start("battle damage is not a paid cost either")
	var d := TestFixtures.battle_duel(9711)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	# Player 0 is the turn player and will attack directly; player 1 takes the damage and is
	# the watched player.
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.lp_cost_watcher("Watcher", 1, seen))
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1700, 1000))
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	var lp_before: int = engine.state.player(1).life_points

	t.is_true(TestFixtures.attack(engine, attacker, null), "a direct attack is declared")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.BATTLE_DAMAGE_INFLICTED), 1,
		"battle damage really was inflicted — this is not a vacuous negative")
	t.eq(engine.state.player(1).life_points, lp_before - 1700, "and the LP fell by the ATK")
	t.eq(seen.size(), 0, "but the watcher did not fire: battle damage is not a payment")


static func _test_an_arbitrary_lp_loss_does_not_count(t: TestCase) -> void:
	t.start("an arbitrary LP loss written by a resolving effect is not a paid cost")
	var d := _duel(9712)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.lp_cost_watcher("Watcher", 0, seen))
	var lp_before: int = engine.state.player(0).life_points

	# The bluntest possible route: straight through the authoritative LP API, during no
	# activation at all.
	engine.state.change_life_points(0, -1200, "Test: arbitrary", -1)

	t.eq(engine.state.player(0).life_points, lp_before - 1200, "the LP really fell")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.LP_CHANGED) > 0, true,
		"and an LP_CHANGED event was emitted")
	t.eq(seen.size(), 0, "the watcher did not fire — an LP delta is not provenance")

	# And the same thing routed through a card that RESOLVES, which is the shape a real
	# "your opponent loses LP" effect has.
	var loser := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_changer("Drainer", "arbitrary_loss", 300))
	var opener := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_changer("Opener", "gain", 0))
	var lp_mid: int = engine.state.player(0).life_points
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, opener.id)
	t.is_true(engine.submit_action(offered), "Chain Link 1")
	t.is_true(_respond_with(engine, 1, loser), "the drainer is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	t.eq(engine.state.player(0).life_points, lp_mid - 300, "the resolving effect drained LP")
	t.eq(seen.size(), 0, "and still no payment was seen")


static func _test_lp_gain_does_not_count(t: TestCase) -> void:
	t.start("LP GAIN is not a payment — the watcher does not fire on a positive delta")
	var d := _duel(9713)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.lp_cost_watcher("Watcher", 0, seen))
	var healer := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_changer("Healer", "gain", 1000))
	var lp_before: int = engine.state.player(0).life_points

	t.is_true(TestFixtures.activate_card(engine, 0, healer), "the healer resolves")
	t.eq(engine.state.player(0).life_points, lp_before + 1000, "the watched player gained LP")
	t.eq(seen.size(), 0, "and the watcher did not fire")


static func _test_an_activation_with_a_non_lp_cost_does_not_count(t: TestCase) -> void:
	t.start("an activation whose cost is NOT Life Points emits COST_PAID exactly as an LP "
		+ "payment does, and the watcher must still not fire")
	var d := _duel(9714)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.lp_cost_watcher("Watcher", 0, seen))
	var discarder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.non_lp_cost_activation("Discarder"))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.monster("Fodder"))
	var lp_before: int = engine.state.player(0).life_points
	var cost_before := _cost_events(engine).size()

	t.is_true(TestFixtures.activate_card(engine, 0, discarder), "the activation happens")

	t.eq(_cost_events(engine).size(), cost_before + 1,
		"a COST_PAID event really was emitted — this is the whole trap this test guards")
	t.eq(engine.state.player(0).life_points, lp_before, "no LP were paid")
	t.eq(seen.size(), 0,
		"and the watcher did not fire: it keys on the PAYLOAD, not on the event kind")


# ---------------------------------------------------------------------------
# Several activations at once — provenance must not smear across links.
# ---------------------------------------------------------------------------

static func _test_multiple_activations_each_keep_their_own_provenance(t: TestCase) -> void:
	t.start("two LP-paying activations by the same player are recorded separately, each "
		+ "with its own amount")
	var d := _duel(9715)
	var engine: DuelEngine = d["engine"]
	var seen: Array = []
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.lp_cost_watcher("Watcher", 0, seen))
	var first := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("First Payer", 300))
	var second := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Second Payer", 900))
	var lp_before: int = engine.state.player(0).life_points

	t.is_true(TestFixtures.activate_card(engine, 0, first), "the first activation happens")
	t.is_true(TestFixtures.activate_card(engine, 0, second), "and then the second")

	t.eq(engine.state.player(0).life_points, lp_before - 1200, "both costs were paid")
	t.eq(seen.size(), 2, "the watcher fired twice — once per activation")
	t.eq(int((seen[0] as Dictionary).get("amount", 0)), 300, "the first amount is its own")
	t.eq(int((seen[1] as Dictionary).get("amount", 0)), 900, "and so is the second")
	t.eq(str((seen[0] as Dictionary).get("card_name", "")), "First Payer",
		"attributed to the first card")
	t.eq(str((seen[1] as Dictionary).get("card_name", "")), "Second Payer",
		"and to the second")


static func _test_chain_ordering_attributes_each_payment_to_its_own_link(t: TestCase) -> void:
	t.start("on one Chain carrying a paying link, a non-paying link and another paying "
		+ "link, each link carries only its own payment")
	var d := _duel(9716)
	var engine: DuelEngine = d["engine"]
	var paying_1 := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer One", 400))
	var free_link := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.lp_changer("Free", "gain", 0))
	var paying_2 := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.lp_cost_activation("Payer Two", 1100))
	# A spare on player 1's side keeps the window open after Chain Link 3.
	TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.lp_changer("Spare", "gain", 0))
	var lp_before: int = engine.state.player(0).life_points

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, paying_1.id)
	t.is_true(engine.submit_action(offered), "Chain Link 1 pays 400")
	t.is_true(_respond_with(engine, 1, free_link), "Chain Link 2 pays nothing")
	t.is_true(_respond_with(engine, 0, paying_2), "Chain Link 3 pays 1100")
	t.eq(engine.state.chain.size(), 3, "the Chain really is three links deep")

	var l1: ChainLink = engine.state.chain[0]
	var l2: ChainLink = engine.state.chain[1]
	var l3: ChainLink = engine.state.chain[2]
	t.eq(EffectPrimitives.life_points_paid_in(l1.cost_payload), 400, "link 1 carries 400")
	t.eq(EffectPrimitives.life_points_paid_in(l2.cost_payload), 0, "link 2 carries nothing")
	t.eq(EffectPrimitives.life_points_paid_in(l3.cost_payload), 1100, "link 3 carries 1100")
	t.eq(engine.state.player(0).life_points, lp_before - 1500,
		"and the payer's LP fell by exactly the sum of their own two payments")
	TestFixtures.pass_until_open(engine)


# ---------------------------------------------------------------------------
# Determinism, and the real pool.
# ---------------------------------------------------------------------------

static func _test_the_whole_cycle_is_replay_deterministic(t: TestCase) -> void:
	t.start("the same seed and the same actions produce the same LP totals, the same "
		+ "COST_PAID payloads and the same watcher records")
	var runs: Array = []
	for i in range(2):
		var d := _watched_board(9717, 700)
		var engine: DuelEngine = d["engine"]
		var payer: CardInstance = d["payer"]
		var seen: Array = d["seen"]
		var opener := TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.lp_changer("Opener", "gain", 200))
		var offered = TestFixtures.find_action(engine.get_legal_actions(0),
			Enums.ActionKind.ACTIVATE_CARD, opener.id)
		engine.submit_action(offered)
		_respond_with(engine, 1, payer)
		TestFixtures.pass_until_open(engine)
		var payloads: Array = []
		for entry in _cost_events(engine):
			var ev: GameEvent = entry
			payloads.append(EffectPrimitives.life_points_paid_in(ev.data.get("payload", {})))
		runs.append({
			"lp0": engine.state.player(0).life_points,
			"lp1": engine.state.player(1).life_points,
			"payloads": payloads,
			"seen": seen.duplicate(true),
		})

	var a: Dictionary = runs[0]
	var b: Dictionary = runs[1]
	t.eq(int(a["lp1"]), 8000 - 700, "the run actually paid the cost")
	t.eq((a["seen"] as Array).size(), 1, "and the watcher actually fired")
	t.eq(int(b["lp0"]), int(a["lp0"]), "player 0's LP are identical across runs")
	t.eq(int(b["lp1"]), int(a["lp1"]), "player 1's LP are identical across runs")
	t.eq(str(b["payloads"]), str(a["payloads"]), "the COST_PAID payloads are identical")
	t.eq(str(b["seen"]), str(a["seen"]), "and the watcher recorded exactly the same thing")


static func _test_no_card_in_the_real_pool_pays_lp_as_a_cost(t: TestCase) -> void:
	t.start("no card in the real 77-card pool pays LP as an activation cost, so every path "
		+ "above is exercised synthetically on purpose [R2, R31]")
	var library := CardRegistry.load_library()
	var cards: Dictionary = library["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")

	var payers: Array = []
	for card_name in cards.keys():
		var card_def: CardDef = cards[card_name]
		var text := str(card_def.text)
		# The PSCT for an LP cost: "Pay N LP" / "pay half your LP" before a semicolon.
		if text.contains("Pay ") and (text.contains(" LP") or text.contains("Life Point")):
			payers.append(card_name)
	t.eq(payers.size(), 0,
		"no printed card in either deck pays Life Points: %s" % str(payers))

	# And no registry file wires the primitive up either. A Callable cannot be introspected,
	# so this reads the sources — which is what would actually catch a future card adopting
	# the cost without this suite being revisited.
	var declared: Array = []
	var dir := DirAccess.open("res://Scripts/cards/registry")
	t.not_null(dir, "the registry directory is readable")
	if dir != null:
		var scanned := 0
		for file_name in dir.get_files():
			if not str(file_name).ends_with(".gd"):
				continue
			scanned += 1
			var f := FileAccess.open("res://Scripts/cards/registry/%s" % file_name,
				FileAccess.READ)
			if f == null:
				continue
			var source := f.get_as_text()
			f.close()
			if source.contains("pay_life_points_cost"):
				declared.append(str(file_name))
		t.check(scanned >= 30,
			"the scan actually read the registry (%d files), so this is not vacuous" % scanned)
	t.eq(declared.size(), 0,
		"and no registry file calls pay_life_points_cost(): %s" % str(declared))

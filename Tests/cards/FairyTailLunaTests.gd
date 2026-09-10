class_name FairyTailLunaTests
extends RefCounted

## Per-card suite for `Fairy Tail - Luna`. Research/CARD_RULINGS.md **R11**.
##
##   "When this card is Normal Summoned: You can add 1 Spellcaster monster with 1850 ATK
##    from your Deck to your hand. Once per turn (Quick Effect): You can target 1 face-up
##    monster your opponent controls; your opponent can send 1 card with that monster's name
##    from their Deck or Extra Deck to the GY to negate this effect, otherwise return both
##    this card and that monster to the hand."
##
## The generic half — that a decision put to the player who does NOT control the resolving
## link reaches the right person, is logged against them, is replayable, and never leaks the
## contents of their Deck — is proved by the opponent-decision section of `HiddenInfoTests`,
## which was written and green before this card existed. What is specific to this card, and
## what this suite is about, is:
##
##   * the fact the printed English text does not carry (R11 Part A): clause ② **cannot be
##     activated during the Damage Step**. Asserted directly against the permission gate,
##     with a control clause that IS permitted, because for this card the restriction is the
##     engine's DEFAULT and a default that happens to be right is indistinguishable from one
##     nobody checked;
##   * that clause ① fires on a **Tribute** Summon as well as a Summon without Tributes, and
##     on nothing else — not a Flip Summon, not a Special Summon, not a Set;
##   * the **both-or-nothing** resolution re-check (R11 Part E), which is the case
##     `RULES_SPEC.md` §10.6 does not cover and which the card's own supplement settles;
##   * that a **face-down** target is still returned but its controller is no longer offered
##     the negation (R11 Part D) — two separate facts that a naive "re-check the target is
##     still face-up" would get wrong in both directions;
##   * that a target whose **control changed** is still returned, so this card does **not**
##     inherit R29 (R11 Part E);
##   * that an **unaffected** target costs only itself and Luna still goes back (R11 Part G),
##     which is batch 16's immunity gate seen from a second card;
##   * that the once-per-turn allowance is spent at **activation** and stays spent when the
##     opponent negates the effect.
##
## **Real pool cards are used wherever the pool has one, and here that is almost everywhere.**
## §8 predicted that the negation branch would be *unreachable from the printed decks*
## because "deck 2 holds one copy of each card". **That prediction is wrong**, and the
## correction matters enough to state here: `Blue-Eyes Dragon Guard` runs **two**
## `Mirage Dragon` and `Fairy-Tail Tribute Guard` runs **two** `Metaphys Armed Dragon`, so a
## deck-2 `Fairy Tail - Luna` targeting a deck-1 `Mirage Dragon` faces an opponent who
## really can send the second copy. The negation is tested on exactly that board, and the
## duplicate counts are asserted against `Data/cards/cards.json` so the scenario cannot
## quietly become synthetic.
##
## The **Extra Deck** half is the only never-live branch: both V1 Extra Decks are empty
## (asserted), so it is exercised against a synthetic Extra Deck card — the R1 / R21 / R23
## treatment, said out loud rather than left to look like a real test.

const CARD_UNDER_TEST := "Fairy Tail - Luna"
const EFFECT_SEARCH := "luna_search_1850_spellcaster"
const EFFECT_BOUNCE := "luna_bounce_unless_opponent_negates"

## The three Spellcaster monsters with exactly 1850 ATK in the V1 pool — all in deck 2.
const QUALIFYING := ["Fairy Tail - Luna", "Fairy Tail - Rella", "Fairy Tail - Sleeper"]
## The real pool's duplicate, and the reason the negation branch is reachable at all.
const DUPLICATE := "Mirage Dragon"


static func run() -> TestCase:
	var t := TestCase.new("FairyTailLunaTests")
	# Shape and declarations
	_test_clause_shape(t)
	_test_the_official_text_is_the_verified_one(t)
	_test_the_damage_step_is_closed(t)
	# Clause 1 - the Normal Summon trigger
	_test_a_normal_summon_fires_it(t)
	_test_a_tribute_summon_also_fires_it(t)
	_test_a_special_summon_and_a_flip_summon_do_not(t)
	_test_a_normal_set_does_not(t)
	_test_it_fires_only_for_this_copy(t)
	_test_it_is_optional(t)
	# Clause 1 - the search itself
	_test_the_filter_is_spellcaster_and_exactly_1850(t)
	_test_the_real_pool_supplies_three_qualifying_spellcasters(t)
	_test_the_search_reveals_adds_and_shuffles(t)
	_test_no_qualifying_card_in_the_deck_forbids_the_activation(t)
	# Clause 2 - targeting and activation legality
	_test_it_targets_a_face_up_opponent_monster_and_nothing_else(t)
	_test_no_legal_target_means_no_activation(t)
	_test_once_per_turn_per_copy(t)
	_test_it_is_a_quick_effect_usable_on_the_opponents_turn(t)
	# Clause 2 - the opponent's decision during resolution
	_test_the_opponent_is_the_player_asked(t)
	_test_the_opponent_sends_a_real_pool_copy_and_negates_it(t)
	_test_declining_returns_both(t)
	_test_no_copy_in_their_deck_asks_nothing_and_returns_both(t)
	_test_the_deck_is_shuffled_whether_or_not_they_had_a_copy(t)
	_test_the_send_is_an_ordinary_send_to_the_gy(t)
	_test_a_copy_in_the_hand_or_gy_is_not_a_legal_payment(t)
	_test_the_extra_deck_half_is_never_live_in_the_pool(t)
	_test_the_once_per_turn_stays_spent_when_the_effect_is_negated(t)
	# Clause 2 - the return branch
	_test_both_return_to_their_owners_hands(t)
	_test_a_target_that_left_the_field_stops_everything(t)
	_test_this_card_leaving_the_field_stops_everything(t)
	_test_a_face_down_target_is_returned_but_is_not_offered_the_negation(t)
	_test_a_target_whose_control_changed_is_still_returned(t)
	_test_an_unaffected_target_costs_only_this_card(t)
	# Negation of Luna itself
	_test_effect_negation(t)
	_test_activation_negation(t)
	# Replay
	_test_the_same_seed_and_script_replay_identically(t)
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


static func _effect(effect_id: String) -> EffectDef:
	var d := _def()
	if d == null:
		return null
	for entry in d.effects:
		var e: EffectDef = entry
		if e.effect_id == effect_id:
			return e
	return null


## Player 0, Main Phase 1 of their own turn. Optional triggers DECLINE unless a test says
## otherwise, so a search never fires by accident and hides what a test meant to measure.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _normal_summon(engine: DuelEngine, card: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, card.id)
	if a == null:
		return false
	if not engine.submit_action(a):
		return false
	TestFixtures.pass_until_open(engine)
	return true


## Luna already on player 0's field (placed, not Summoned, so clause 1 never fires) with a
## face-up opponent monster to aim at. Returns {"engine","p0","p1","luna","target"}.
static func _bounce_board(seed_value: int, target_def: CardDef = null) -> Dictionary:
	var d := _board(seed_value)
	var engine: DuelEngine = d["engine"]
	d["luna"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	var td := target_def if target_def != null \
		else TestFixtures.monster("Prey", 4, 1500, 1000)
	d["target"] = TestFixtures.give_monster_on_field(engine, 1, td)
	return d


static func _activate_bounce(engine: DuelEngine, luna: CardInstance,
		target: CardInstance) -> bool:
	return TestFixtures.activate_effect(engine, 0, luna, EFFECT_BOUNCE, [target.id])


static func _bounce_offered(engine: DuelEngine, luna: CardInstance):
	return TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, luna.id, EFFECT_BOUNCE)


static func _bounce_targets(engine: DuelEngine, luna: CardInstance) -> Array:
	var a = _bounce_offered(engine, luna)
	return [] if a == null else a.target_candidates


## One row of the verified card database, by name.
## Submit `card`'s activation as a response on top of a Chain that is still building, for
## player `pid`. Passes for whoever is asked until the window reaches `pid`.
##
## `get_legal_responses(1)` alone is not enough when the responder is the TURN player: the
## non-turn player is offered the window first, and the turn player only gets to add a link
## after they have passed.
static func _respond_with(engine: DuelEngine, pid: int, card: CardInstance) -> bool:
	var guard := 0
	while guard < 8 and engine.timing != DuelEngine.Timing.OPEN \
			and not engine.is_duel_over():
		guard += 1
		var response = TestFixtures.find_action(engine.get_legal_responses(pid),
			Enums.ActionKind.ACTIVATE_CARD, card.id)
		if response != null:
			return engine.submit_action(response)
		var waiting := engine.waiting_player()
		if waiting == -1:
			return false
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting))
	return false


static func _pool_row(card_name: String) -> Dictionary:
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	for entry in (parsed as Dictionary).get("cards", []):
		var row: Dictionary = entry
		if str(row.get("name", "")) == card_name:
			return row
	return {}


# ---------------------------------------------------------------------------
# Shape and declarations
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("two printed clauses, two EffectDefs: a Trigger Effect on the Normal Summon "
		+ "and a Spell Speed 2 Quick Effect, both activated face-up in the Monster Zone")
	var d := _def()
	t.not_null(d, "the card is registered")
	if d == null:
		return
	t.eq(d.effects.size(), 2, "two clauses, two EffectDefs")

	var search := _effect(EFFECT_SEARCH)
	t.not_null(search, "clause 1 carries the expected effect id")
	if search != null:
		t.eq(search.effect_type, Enums.EffectType.TRIGGER,
			"clause 1 is a Trigger Effect — 「モンスターゾーンで発動できる誘発効果です」")
		t.eq(search.optionality, Enums.Optionality.OPTIONAL, "'You can add' is optional")
		t.eq(search.spell_speed, Enums.SpellSpeed.SS1, "a Trigger Effect is Spell Speed 1")
		t.eq(search.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
			"activated face-up on the field, which is where a freshly Summoned monster is")
		t.eq(search.trigger_events, [GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED],
			"and on the Normal Summon event ALONE")
		t.is_false(search.targets, "it does not target — the card is chosen at resolution")
		t.eq(search.ruling_ref, "R11", "carrying its ruling reference")

	var bounce := _effect(EFFECT_BOUNCE)
	t.not_null(bounce, "clause 2 carries the expected effect id")
	if bounce != null:
		t.eq(bounce.effect_type, Enums.EffectType.QUICK,
			"clause 2 is a Quick Effect — 「誘発即時効果です」")
		t.eq(bounce.spell_speed, Enums.SpellSpeed.SS2,
			"a Quick Effect is Spell Speed 2 [S1 p.44-45]")
		t.eq(bounce.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
			"activated face-up in the Monster Zone")
		t.is_true(bounce.targets, "it TARGETS — 「対象として発動できる」")
		t.eq(bounce.target_count_min, 1, "exactly one target, minimum")
		t.eq(bounce.target_count_max, 1, "and maximum")
		t.is_true(bounce.once_per_turn_instance,
			"「自分・相手ターンに１度」 with no 'you can only use this effect of \"Fairy Tail "
			+ "- Luna\" once per turn' is a SOFT once per turn on THIS COPY")
		t.is_false(bounce.once_per_turn_named_effect,
			"and it is NOT the per-name allowance — the card does not name itself")
		t.eq(bounce.ruling_ref, "R11", "carrying its ruling reference")


static func _test_the_official_text_is_the_verified_one(t: TestCase) -> void:
	t.start("the implemented clauses are the verified official text, verbatim — re-fetched "
		+ "live from cid 12952 for this batch and identical character for character")
	var row := _pool_row(CARD_UNDER_TEST)
	t.check(not row.is_empty(), "the card is in the verified database")
	if row.is_empty():
		return
	t.eq(str(row.get("konami_cid", "")), "12952", "the verified Konami card id")
	t.eq(int(row.get("copies_total", -1)), 1, "one copy is printed in the pool")
	var text := str(row.get("text", ""))
	t.eq(text.length(), 378, "the official text is 378 characters long")
	t.is_true(text.begins_with("When this card is Normal Summoned: You can add 1 "
		+ "Spellcaster monster with 1850 ATK from your Deck to your hand."),
		"clause 1, verbatim")
	t.is_true(text.contains("your opponent can send 1 card with that monster's name from "
		+ "their Deck or Extra Deck to the GY to negate this effect, otherwise return both "
		+ "this card and that monster to the hand."),
		"clause 2's resolution sentence, verbatim")
	# The printed English says nothing at all about the Damage Step. That is the whole
	# reason the next test exists.
	t.is_false(text.contains("Damage Step"),
		"and it carries NO Damage Step restriction — the one below comes from the official "
		+ "supplement and from nowhere else")


static func _test_the_damage_step_is_closed(t: TestCase) -> void:
	t.start("R11 Part A: 「ダメージステップ中には発動できません」 — the activation restriction "
		+ "the printed English text does not carry, seven batches running")
	var e := _effect(EFFECT_BOUNCE)
	if e == null:
		return
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"the permission is NONE")

	var d := _board(1721)
	var engine: DuelEngine = d["engine"]
	var state: GameState = engine.state
	t.is_true(ActivationRules.damage_step_ok(state, e),
		"outside the Damage Step the permission gate allows it")

	state.battle_step = Enums.BattleStep.DAMAGE
	for substep in [Enums.DamageSubStep.START_OF_DAMAGE_STEP,
			Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION,
			Enums.DamageSubStep.DURING_DAMAGE_CALCULATION,
			Enums.DamageSubStep.AFTER_DAMAGE_CALCULATION,
			Enums.DamageSubStep.END_OF_DAMAGE_STEP]:
		state.damage_substep = substep
		t.is_false(ActivationRules.damage_step_ok(state, e),
			"refused in Damage Step sub-step %d" % int(substep))

	# The control: a clause that DOES carry a permission is allowed in its own sub-step, so
	# the assertions above are not passing because the gate refuses everything.
	var permitted := EffectDef.new("permitted", "Test")
	permitted.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	state.damage_substep = Enums.DamageSubStep.BEFORE_DAMAGE_CALCULATION
	t.is_true(ActivationRules.damage_step_ok(state, permitted),
		"a clause that carries UNTIL_DAMAGE_CALC is allowed in the same sub-step")

	# Clause 1 is a Trigger Effect and carries no permission either, so a Normal Summon
	# conducted in the Damage Step could not fire it. Nothing in the pool Summons there,
	# but the declaration must still be what the supplement says.
	var search := _effect(EFFECT_SEARCH)
	if search != null:
		t.eq(search.damage_step_permission, Enums.DamageStepPermission.NONE,
			"clause 1 carries no Damage Step permission either")


# ---------------------------------------------------------------------------
# Clause 1 — the Normal Summon trigger
# ---------------------------------------------------------------------------

static func _test_a_normal_summon_fires_it(t: TestCase) -> void:
	t.start("clause 1 fires when this card is Normal Summoned without Tributes, and the "
		+ "search really adds a qualifying Spellcaster to the hand")
	var d := _board(1722)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true
	var rella := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	var luna := TestFixtures.give_to_hand(engine, 0, _def())
	var hand_before: int = engine.state.player(0).hand.size()

	t.is_true(_normal_summon(engine, luna), "the Normal Summon is offered and accepted")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "Luna is on the field")
	t.eq(rella.zone, Enums.Zone.HAND, "and the Spellcaster was added to the hand")
	t.eq(rella.controller_id, 0, "to its own player's hand")
	# Luna left the hand and Rella joined it, so the count is unchanged.
	t.eq(engine.state.player(0).hand.size(), hand_before,
		"one card left the hand and one arrived")


static func _test_a_tribute_summon_also_fires_it(t: TestCase) -> void:
	t.start("R11 Part H: an ADVANCE Summon IS a Normal Summon [S1 p.22-23], so a Luna "
		+ "Tribute Summoned fires clause 1 exactly as one Summoned without Tributes")
	# Luna is Level 4 and can never be Advance Summoned itself, so the fact is settled by
	# measuring the two halves it rests on rather than by poking a synthetic event into an
	# engine that is not in a trigger check — which would have proved nothing at all.
	#
	# Half one: a real Tribute Summon emits the very event clause 1 listens to.
	var d := _board(1723)
	var engine: DuelEngine = d["engine"]
	var fodder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Fodder", 4, 1000, 1000))
	var big := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Advance Stand-In", 6, 2400, 1000))
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, big.id)
	t.not_null(a, "the Tribute Summon is offered")
	if a == null:
		return
	t.is_true(engine.submit_action(a.with_choices({"tribute_ids": [fodder.id]})),
		"and accepted")
	TestFixtures.pass_until_open(engine)
	t.is_true(big.was_tribute_summoned(), "the monster counts as Tribute Summoned")

	var tribute_events := 0
	for entry in TestFixtures.events_of(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED):
		var ev: GameEvent = entry
		if int(ev.data.get("card_id", -1)) == big.id:
			tribute_events += 1
			t.eq(int(ev.data.get("summon_kind", -1)), int(Enums.SummonKind.TRIBUTE),
				"and the event says it was a TRIBUTE Summon")
	t.eq(tribute_events, 1,
		"a Tribute Summon emits NORMAL_SUMMON_SUCCEEDED — the same event clause 1 listens "
		+ "to, and NOT a separate one")

	# Half two: clause 1's own condition accepts that event. It is evaluated directly with a
	# TRIBUTE-flavoured trigger event, so a condition that started filtering on summon_kind
	# would fail here even though the event kind still matched.
	var e := _effect(EFFECT_SEARCH)
	if e == null:
		return
	TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	var luna := TestFixtures.give_monster_on_field(engine, 0, _def())
	for kind in [Enums.SummonKind.NORMAL, Enums.SummonKind.TRIBUTE]:
		var ev := GameEvent.new()
		ev.kind = GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED
		ev.data = {"card_id": luna.id, "card_name": luna.card_name(), "player": 0,
			"summon_kind": kind}
		var ctx := ActivationRules.make_context(engine.state, luna, e, 0, ev)
		t.is_true(bool(e.condition.call(ctx)),
			"clause 1's condition accepts summon_kind %d" % int(kind))

	# And the control, so the condition is not simply answering yes to everything: an event
	# about a DIFFERENT card is refused.
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Somebody Else", 4, 1200, 1000))
	var wrong := GameEvent.new()
	wrong.kind = GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED
	wrong.data = {"card_id": other.id, "card_name": other.card_name(), "player": 0,
		"summon_kind": Enums.SummonKind.TRIBUTE}
	t.is_false(bool(e.condition.call(
		ActivationRules.make_context(engine.state, luna, e, 0, wrong))),
		"but an event about another card is refused")


static func _test_a_special_summon_and_a_flip_summon_do_not(t: TestCase) -> void:
	t.start("clause 1 is 「召喚した時」 and nothing else: a Special Summon and a Flip Summon "
		+ "are both Summons [S1 p.24] but neither is a NORMAL Summon")
	var e := _effect(EFFECT_SEARCH)
	if e == null:
		return
	t.is_false(e.trigger_events.has(GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED),
		"a Special Summon is not listed")
	t.is_false(e.trigger_events.has(GameEvent.Kind.FLIP_SUMMON_SUCCEEDED),
		"and neither is a Flip Summon")

	var d := _board(1725)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	var rella := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	# Placed face-down and then Flip Summoned: the one route that emits FLIP_SUMMON_SUCCEEDED
	# for a card that is already on the field.
	var luna := TestFixtures.give_monster_on_field(engine, 0, _def(),
		Enums.Position.FACE_DOWN_DEFENSE)
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, luna.id)
	t.not_null(a, "the Flip Summon is offered")
	if a != null:
		t.is_true(engine.submit_action(a), "and accepted")
		TestFixtures.pass_until_open(engine)
	t.is_true(luna.is_face_up(), "Luna is now face-up")
	t.eq(rella.zone, Enums.Zone.DECK,
		"and nothing was searched — a Flip Summon does not fire clause 1")


static func _test_a_normal_set_does_not(t: TestCase) -> void:
	t.start("a Normal SET is not a Summon [S1 p.24], so Setting Luna searches nothing")
	var d := _board(1726)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	var rella := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	var luna := TestFixtures.give_to_hand(engine, 0, _def())

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SET, luna.id)
	t.not_null(a, "the Set is offered")
	if a != null:
		t.is_true(engine.submit_action(a), "and accepted")
		TestFixtures.pass_until_open(engine)
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "Luna is on the field")
	t.is_false(luna.is_face_up(), "face-down")
	t.eq(rella.zone, Enums.Zone.DECK, "and nothing was searched")


static func _test_it_fires_only_for_this_copy(t: TestCase) -> void:
	t.start("the trigger checks the event's card id: another monster's Normal Summon does "
		+ "not fire a Luna that is already on the field")
	var d := _board(1727)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true
	var rella := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	TestFixtures.give_monster_on_field(engine, 0, _def())
	var other := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Somebody Else", 4, 1200, 1000))

	t.is_true(_normal_summon(engine, other), "the OTHER monster is Normal Summoned")
	t.eq(rella.zone, Enums.Zone.DECK,
		"and the Luna already on the field searched nothing")

	# The control needs its OWN board: only one Normal Summon is legal per turn [S1 p.22],
	# so a second Summon in the duel above could never have been offered and the control
	# would have passed for the wrong reason.
	var d2 := _board(1728)
	var engine2: DuelEngine = d2["engine"]
	(d2["p0"] as ScriptedController).default_yes = true
	var rella2 := TestFixtures.give_to_deck(engine2, 0, _card("Fairy Tail - Rella"))
	var luna := TestFixtures.give_to_hand(engine2, 0, _def())
	t.is_true(_normal_summon(engine2, luna), "on its own board a Luna is Normal Summoned")
	t.eq(rella2.zone, Enums.Zone.HAND, "and it does search")


static func _test_it_is_optional(t: TestCase) -> void:
	t.start("'You can add' — declining the trigger adds nothing and is a legal outcome")
	var d := _board(1758)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	p0.default_yes = false            # the ScriptedController default, stated for clarity
	var rella := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	var luna := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_true(_normal_summon(engine, luna), "Luna is Normal Summoned")
	var asked := 0
	for entry in p0.seen_requests:
		var r: DecisionRequest = entry
		if r.kind == Enums.DecisionKind.YES_NO and r.source_card_id == luna.id:
			asked += 1
	t.eq(asked, 1, "the controller was asked, exactly once — never fired silently")
	t.eq(rella.zone, Enums.Zone.DECK, "and declining searched nothing")


# ---------------------------------------------------------------------------
# Clause 1 — the search itself
# ---------------------------------------------------------------------------

static func _test_the_filter_is_spellcaster_and_exactly_1850(t: TestCase) -> void:
	t.start("'1 Spellcaster monster with 1850 ATK' — an EXACT ATK and a race, so 1800 does "
		+ "not qualify, 1850 of another race does not, and a Spell does not")
	var pred := EffectPrimitives.monster_with_exact_atk(1850, "Spellcaster")
	var d := _board(1729)
	var engine: DuelEngine = d["engine"]

	var yes := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	var wrong_atk := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Nearly", 4, 1800, 1000, "LIGHT", "Spellcaster"))
	var over_atk := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Over", 4, 1900, 1000, "LIGHT", "Spellcaster"))
	var wrong_race := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Wrong Race", 4, 1850, 1000, "LIGHT", "Warrior"))
	var a_spell := TestFixtures.give_to_deck(engine, 0, TestFixtures.spell("A Spell"))

	t.is_true(pred.call(yes), "a Spellcaster with exactly 1850 ATK qualifies")
	t.is_false(pred.call(wrong_atk),
		"1800 does not — the clause is an exact figure, not a cap, which is why "
		+ "monster_filter()'s max_atk would have been wrong")
	t.is_false(pred.call(over_atk), "and neither does 1900")
	t.is_false(pred.call(wrong_race), "1850 ATK of the wrong race does not qualify")
	t.is_false(pred.call(a_spell), "and a Spell Card is not a monster at all")


static func _test_the_real_pool_supplies_three_qualifying_spellcasters(
		t: TestCase) -> void:
	t.start("clause 1 is LIVE on real pool cards: exactly three Spellcaster monsters with "
		+ "1850 ATK exist, all three in `Fairy-Tail Tribute Guard`")
	var lib := _library()
	var pred := EffectPrimitives.monster_with_exact_atk(1850, "Spellcaster")
	var found: Array = []
	for entry in (lib["cards"] as Dictionary).values():
		var def: CardDef = entry
		if not def.is_monster():
			continue
		if def.base_atk == 1850 and def.race == "Spellcaster":
			found.append(def.name)
	found.sort()
	t.eq(found, QUALIFYING,
		"and they are Luna, Rella and Sleeper — so the search is tested against the "
		+ "printed deck rather than against synthetic cards")

	# The predicate and the survey must agree; two ways of asking the same question that
	# disagree would mean the card is filtering on something else.
	for card_name in QUALIFYING:
		var inst := CardInstance.new(_card(card_name), 0)
		t.is_true(pred.call(inst), "%s satisfies the clause's own predicate" % card_name)


static func _test_the_search_reveals_adds_and_shuffles(t: TestCase) -> void:
	t.start("the search REVEALS the card to both players [S1 p.53], adds it with "
		+ "ADDED_TO_HAND, and shuffles the Deck afterwards so the rest stops being known")
	var d := _board(1730)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	var rella := TestFixtures.give_to_deck(engine, 0, _card("Fairy Tail - Rella"))
	var bystander := TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	# Deck knowledge that the search's tail shuffle must clear.
	engine.state.reveal(bystander, [0, 1], -1)
	t.is_true(bystander.revealed_to.has(0), "the bystander starts known")
	var luna := TestFixtures.give_to_hand(engine, 0, _def())
	var mark: int = engine.state.events.size()

	t.is_true(_normal_summon(engine, luna), "Luna is Normal Summoned")
	t.eq(rella.zone, Enums.Zone.HAND, "the searched card reached the hand")
	t.is_true(rella.revealed_to.has(0) and rella.revealed_to.has(1),
		"and BOTH players saw it go — it had to be shown to prove it qualified")

	var adds := TestFixtures.events_of(engine, GameEvent.Kind.CARD_ADDED_TO_HAND, mark)
	var mine := 0
	for entry in adds:
		if int((entry as GameEvent).data.get("card_id", -1)) == rella.id:
			mine += 1
	t.eq(mine, 1, "exactly one CARD_ADDED_TO_HAND for it")
	t.eq(rella.last_move_reason, Enums.MoveReason.ADDED_TO_HAND,
		"the reason is ADDED_TO_HAND, not RETURNED_TO_HAND — a search is not a bounce")
	t.is_false(bystander.revealed_to.has(0),
		"and the tail shuffle cleared what was known about the rest of the Deck")


static func _test_no_qualifying_card_in_the_deck_forbids_the_activation(
		t: TestCase) -> void:
	t.start("[S1 p.53] / R40 part B: an effect activated IN ORDER TO search cannot be "
		+ "activated when the Deck holds no qualifying card — the controller is not even "
		+ "asked")
	var d := _board(1731)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true
	TestFixtures.clear_deck(engine, 0)
	TestFixtures.give_to_deck(engine, 0,
		TestFixtures.monster("Not A Spellcaster", 4, 1850, 1000, "LIGHT", "Warrior"))
	var luna := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_true(_normal_summon(engine, luna), "Luna is Normal Summoned")
	var asked := 0
	for entry in p0.seen_requests:
		var r: DecisionRequest = entry
		if r.kind == Enums.DecisionKind.YES_NO and r.effect_id == EFFECT_SEARCH:
			asked += 1
	t.eq(asked, 0, "the optional trigger was never offered")
	t.eq(engine.state.player(0).deck_count(), 1, "and nothing left the Deck")

	# The control: add one qualifying card and the very same Summon does offer it.
	var d2 := _board(1732)
	var engine2: DuelEngine = d2["engine"]
	(d2["p0"] as ScriptedController).default_yes = true
	TestFixtures.clear_deck(engine2, 0)
	TestFixtures.give_to_deck(engine2, 0,
		TestFixtures.monster("Not A Spellcaster", 4, 1850, 1000, "LIGHT", "Warrior"))
	var sleeper := TestFixtures.give_to_deck(engine2, 0, _card("Fairy Tail - Sleeper"))
	var luna2 := TestFixtures.give_to_hand(engine2, 0, _def())
	t.is_true(_normal_summon(engine2, luna2), "Luna is Normal Summoned")
	t.eq(sleeper.zone, Enums.Zone.HAND, "and one qualifying card is enough to fire it")


# ---------------------------------------------------------------------------
# Clause 2 — targeting and activation legality
# ---------------------------------------------------------------------------

static func _test_it_targets_a_face_up_opponent_monster_and_nothing_else(
		t: TestCase) -> void:
	t.start("'1 FACE-UP monster YOUR OPPONENT controls' — not your own, not a face-down "
		+ "one, not a Spell/Trap")
	var d := _bounce_board(1733)
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var theirs: CardInstance = d["target"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Own", 4, 1000, 1000))
	var their_face_down := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Trap"))

	var candidates := _bounce_targets(engine, luna)
	t.is_true(candidates.has(theirs.id),
		"the opponent's face-up monster is a legal target")
	t.is_false(candidates.has(mine.id), "a monster this player controls is not")
	t.is_false(candidates.has(luna.id), "and neither is Luna itself")
	t.is_false(candidates.has(their_face_down.id),
		"a face-DOWN opponent monster is not — the clause says face-up")
	t.is_false(candidates.has(their_trap.id),
		"and a Set Trap is not a monster")
	t.eq(candidates.size(), 1, "exactly one legal target on this board")


static func _test_no_legal_target_means_no_activation(t: TestCase) -> void:
	t.start("with nothing legal to target the Quick Effect is not offered at all")
	var d := _board(1734)
	var engine: DuelEngine = d["engine"]
	var luna := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Hidden", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	t.is_null(_bounce_offered(engine, luna),
		"a face-down opponent monster is not a target, so nothing is offered")

	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1500, 1000))
	t.not_null(_bounce_offered(engine, luna),
		"one face-up opponent monster is enough for the activation to appear")


static func _test_once_per_turn_per_copy(t: TestCase) -> void:
	t.start("「自分・相手ターンに１度」 — ONE use per turn on THIS COPY, and the allowance "
		+ "comes back on the next turn")
	# The opponent negates the effect by sending their second copy, which is the one way
	# Luna is still on the field afterwards — otherwise it bounces itself to the hand and
	# the second question would be about its ABSENCE rather than about the allowance.
	var d := _bounce_board(1735, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var second_luna := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	p1.default_yes = false

	t.not_null(_bounce_offered(engine, luna), "the first copy may use it")
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, luna.id, EFFECT_BOUNCE)
	if offered == null:
		return
	# Queue the send so the effect is negated and Luna survives on the field.
	var copies: Array = EffectPrimitives.cards_in(
		ActivationRules.make_context(engine.state, luna, _effect(EFFECT_BOUNCE), 0),
		1, Enums.Zone.DECK, EffectPrimitives.has_name_of(target))
	t.eq(copies.size(), 1, "the opponent holds exactly one same-named copy")
	p1.queue([(copies[0] as CardInstance).id])
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and the activation is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE,
		"the effect was negated, so this copy is still on the field")
	t.is_null(_bounce_offered(engine, luna),
		"but it cannot use the effect a second time this turn")
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, second_luna.id, EFFECT_BOUNCE),
		"while a DIFFERENT copy still may — the allowance is per copy, not per name, "
		+ "because the card does not name itself")

	# Round the turn back to player 0 and the same copy may use it again.
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn again")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "and that copy is still on the field")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "with the target still there to aim at")
	t.not_null(_bounce_offered(engine, luna),
		"so the once-per-turn allowance has reset")


static func _test_it_is_a_quick_effect_usable_on_the_opponents_turn(t: TestCase) -> void:
	t.start("a Quick Effect is usable in a response window on the OPPONENT's turn — which "
		+ "is what 「自分・相手ターンに１度」 says out loud")
	var d := TestFixtures.new_duel(1736, 1)     # player 1 goes first
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var luna := TestFixtures.give_monster_on_field(engine, 0, _def())
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Prey", 4, 1500, 1000))
	t.eq(engine.state.turn_player_id, 1, "it is the opponent's turn")

	# Player 1 activates something so a response window opens for player 0.
	var spacer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.with_effect(TestFixtures.trap("Spacer"),
			TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, [])), -1)
	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spacer.id)
	if a != null:
		t.is_true(engine.submit_action(a), "the opponent activates a Spell Speed 2 card")
		var response = TestFixtures.find_action(engine.get_legal_responses(0),
			Enums.ActionKind.ACTIVATE_EFFECT, luna.id, EFFECT_BOUNCE)
		t.not_null(response,
			"and Luna's Quick Effect is offered in the response window, on the "
			+ "opponent's turn")
		if response != null:
			t.is_true(engine.submit_action(
				response.with_choices({"target_ids": [target.id]})),
				"and it is accepted as a Chain Link")
			TestFixtures.pass_until_open(engine)
			t.eq(target.zone, Enums.Zone.HAND, "resolving on the opponent's turn")


# ---------------------------------------------------------------------------
# Clause 2 — the opponent's decision during resolution
# ---------------------------------------------------------------------------

static func _test_the_opponent_is_the_player_asked(t: TestCase) -> void:
	t.start("「相手は…できる」 — the decision goes to the player who does NOT control the "
		+ "resolving link, and Luna's own controller is never asked about it")
	var d := _bounce_board(1737, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	p0.reset()
	p1.reset()

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")

	var offered_to_p1 := 0
	for entry in p1.seen_requests:
		var r: DecisionRequest = entry
		if r.kind == Enums.DecisionKind.SELECT_UP_TO and r.effect_id == EFFECT_BOUNCE:
			offered_to_p1 += 1
			t.eq(r.player_id, 1, "the request names player 1")
			t.eq(r.options, [copy.id], "and offers the copy in THEIR Deck")
	t.eq(offered_to_p1, 1, "the opponent was offered the negation exactly once")

	for entry in p0.seen_requests:
		var r: DecisionRequest = entry
		t.ne(r.kind, Enums.DecisionKind.SELECT_UP_TO,
			"Luna's controller was never handed the choice — it is not theirs to make, "
			+ "and the options are cards in the opponent's Deck")

	# And it is logged against the player who actually made it.
	var logged := 0
	for entry in engine.log.decisions:
		var row: Dictionary = entry
		var req: Dictionary = row["request"]
		if str(req.get("kind", "")) == "SELECT_UP_TO":
			logged += 1
			t.eq(int(req.get("player", -1)), 1, "and recorded against player 1")
	t.eq(logged, 1, "one such decision is in the replay payload")


static func _test_the_opponent_sends_a_real_pool_copy_and_negates_it(t: TestCase) -> void:
	t.start("R11 Part F, on the REAL pool: `Blue-Eyes Dragon Guard` runs two "
		+ "`Mirage Dragon`, so a deck-1 opponent really can send the second copy and "
		+ "negate the effect — both monsters then stay on the field")
	# The premise, asserted against the verified database so the scenario cannot quietly
	# become synthetic. Section 8 predicted this branch was unreachable from the printed
	# decks; it is not.
	t.eq(int(_pool_row(DUPLICATE).get("copies_total", -1)), 2,
		"two copies of %s are printed in the pool" % DUPLICATE)

	var d := _bounce_board(1738, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	var gy_before: int = engine.state.player(1).graveyard.size()
	p1.queue([copy.id])
	var mark: int = engine.state.events.size()

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	t.eq(copy.zone, Enums.Zone.GRAVEYARD, "the second copy was sent to the Graveyard")
	t.eq(engine.state.player(1).graveyard.size(), gy_before + 1,
		"to its own owner's Graveyard")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "Luna stays on the field")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "and so does the target")

	var negations := TestFixtures.events_of(engine, GameEvent.Kind.EFFECT_NEGATED, mark)
	t.eq(negations.size(), 1, "one EFFECT_NEGATED was emitted")
	if negations.size() == 1:
		var ev: GameEvent = negations[0]
		t.eq(int(ev.data.get("card_id", -1)), luna.id, "naming Luna's effect")
		t.eq(int(ev.data.get("by_player", -1)), 1, "and the opponent who negated it")
		t.eq(ev.data.get("during_resolution"), true,
			"and marking it as a negation made DURING resolution")


static func _test_declining_returns_both(t: TestCase) -> void:
	t.start("「墓地へ送らなかった場合」 — an opponent who COULD send and chooses not to gets "
		+ "the return anyway, and their copy stays in the Deck")
	var d := _bounce_board(1739, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	p1.queue([])                       # an explicit decline, not a default
	var mark: int = engine.state.events.size()

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	t.eq(copy.zone, Enums.Zone.DECK, "the copy they declined to send is still in the Deck")
	t.eq(luna.zone, Enums.Zone.HAND, "Luna went back to the hand")
	t.eq(target.zone, Enums.Zone.HAND, "and so did the target")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.EFFECT_NEGATED, mark).size(), 0,
		"nothing was negated")


static func _test_no_copy_in_their_deck_asks_nothing_and_returns_both(
		t: TestCase) -> void:
	t.start("an opponent with no same-named card is NOT asked — a zero-option prompt would "
		+ "announce that their Deck holds no copy — and the return happens")
	var d := _bounce_board(1740, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	TestFixtures.clear_deck(engine, 1)
	TestFixtures.give_to_deck(engine, 1,
		TestFixtures.monster("Something Else", 4, 1000, 1000))
	p1.reset()

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	for entry in p1.seen_requests:
		var r: DecisionRequest = entry
		t.ne(r.kind, Enums.DecisionKind.SELECT_UP_TO,
			"the opponent was never prompted about a payment they cannot make")
	for entry in engine.log.decisions:
		var req: Dictionary = (entry as Dictionary)["request"]
		t.ne(str(req.get("kind", "")), "SELECT_UP_TO",
			"and no 'declined' was written to the replay payload on their behalf")
	t.eq(luna.zone, Enums.Zone.HAND, "both cards go back: Luna")
	t.eq(target.zone, Enums.Zone.HAND, "and the target")


static func _test_the_deck_is_shuffled_whether_or_not_they_had_a_copy(
		t: TestCase) -> void:
	t.start("the opponent's Deck is shuffled EITHER WAY [S1 p.5] — a shuffle that happened "
		+ "only when they held a copy would leak the answer through a public event")
	# With a copy.
	var d := _bounce_board(1741, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	var known := TestFixtures.give_to_deck(engine, 1,
		TestFixtures.monster("Known Card", 4, 1000, 1000))
	engine.state.reveal(known, [0, 1], -1)
	(d["p1"] as ScriptedController).queue([])
	t.is_true(_activate_bounce(engine, luna, target), "the effect resolves")
	t.is_false(known.revealed_to.has(0),
		"their Deck was shuffled, so what was known about it is gone")

	# Without one — the same must be true, or the shuffle itself becomes the tell.
	var d2 := _bounce_board(1742, _card(DUPLICATE))
	var engine2: DuelEngine = d2["engine"]
	var luna2: CardInstance = d2["luna"]
	var target2: CardInstance = d2["target"]
	var known2 := TestFixtures.give_to_deck(engine2, 1,
		TestFixtures.monster("Known Card", 4, 1000, 1000))
	engine2.state.reveal(known2, [0, 1], -1)
	t.is_true(_activate_bounce(engine2, luna2, target2), "the effect resolves")
	t.is_false(known2.revealed_to.has(0),
		"and their Deck was shuffled even though they had nothing to send")


static func _test_the_send_is_an_ordinary_send_to_the_gy(t: TestCase) -> void:
	t.start("R11 Part F: the send is a step inside this effect's RESOLUTION, not a cost — "
		+ "it is an ordinary SENT_TO_GY_BY_EFFECT that a 'sent to the GY' trigger sees")
	var d := _bounce_board(1743, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	(d["p1"] as ScriptedController).queue([copy.id])
	var mark: int = engine.state.events.size()

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	t.eq(copy.last_move_reason, Enums.MoveReason.SENT_TO_GY_BY_EFFECT,
		"the reason is SENT_TO_GY_BY_EFFECT — not a discard, not a cost payment")
	var sends := TestFixtures.events_of(engine, GameEvent.Kind.CARD_SENT_TO_GY, mark)
	var mine := 0
	for entry in sends:
		if int((entry as GameEvent).data.get("card_id", -1)) == copy.id:
			mine += 1
	t.eq(mine, 1, "and a CARD_SENT_TO_GY was emitted for it, once")

	# It is emitted while the effect resolves, so it cannot have been a cost paid at
	# activation: a cost is paid before the Chain Link exists.
	var cost_events := TestFixtures.events_of(engine, GameEvent.Kind.COST_PAID, mark)
	for entry in cost_events:
		t.ne(int((entry as GameEvent).data.get("card_id", -1)), luna.id,
			"Luna's clause pays no cost at all")


static func _test_a_copy_in_the_hand_or_gy_is_not_a_legal_payment(t: TestCase) -> void:
	t.start("'from their Deck or Extra Deck' names two zones and only two: a copy in the "
		+ "hand or in the Graveyard cannot be sent, so the return happens")
	var d := _bounce_board(1744, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	TestFixtures.clear_deck(engine, 1)
	var in_hand := TestFixtures.give_to_hand(engine, 1, _card(DUPLICATE))
	var in_gy := TestFixtures.give(engine, 1, _card(DUPLICATE), Enums.Zone.GRAVEYARD)
	p1.reset()

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	for entry in p1.seen_requests:
		t.ne((entry as DecisionRequest).kind, Enums.DecisionKind.SELECT_UP_TO,
			"neither copy is a legal payment, so no prompt appeared")
	t.eq(in_hand.zone, Enums.Zone.HAND, "the copy in hand stayed there")
	t.eq(in_gy.zone, Enums.Zone.GRAVEYARD, "and so did the one in the Graveyard")
	t.eq(luna.zone, Enums.Zone.HAND, "the return happened: Luna")
	t.eq(target.zone, Enums.Zone.HAND, "and the target")


static func _test_the_extra_deck_half_is_never_live_in_the_pool(t: TestCase) -> void:
	t.start("R11 Part B: both V1 Extra Decks are EMPTY, so 'or Extra Deck' can never be "
		+ "live in a real duel — asserted as impossible, then exercised synthetically")
	for path in ["res://Data/decks/deck1.json", "res://Data/decks/deck2.json"]:
		var f := FileAccess.open(path, FileAccess.READ)
		t.not_null(f, "%s is readable" % path)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		t.check(parsed is Dictionary, "%s parses" % path)
		if parsed is Dictionary:
			t.eq((parsed as Dictionary).get("extra_deck", ["x"]).size(), 0,
				"%s has an EMPTY Extra Deck" % path)

	# The synthetic exercise, said out loud: this board cannot arise from the printed decks.
	var d := _bounce_board(1745, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	TestFixtures.clear_deck(engine, 1)
	var extra := TestFixtures.give(engine, 1, _card(DUPLICATE), Enums.Zone.EXTRA_DECK)
	t.eq(extra.zone, Enums.Zone.EXTRA_DECK, "a same-named card sits in the Extra Deck")
	(d["p1"] as ScriptedController).queue([extra.id])

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	t.eq(extra.zone, Enums.Zone.GRAVEYARD,
		"and the Extra Deck copy was a legal payment and was sent")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "so the effect was negated: Luna stays")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "and so does the target")


static func _test_the_once_per_turn_stays_spent_when_the_effect_is_negated(
		t: TestCase) -> void:
	t.start("'negate this EFFECT' is not 'negate the activation': the once-per-turn "
		+ "allowance was spent at activation and stays spent")
	var d := _bounce_board(1746, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Second Prey", 4, 1400, 1000))
	(d["p1"] as ScriptedController).queue([copy.id])

	t.is_true(_activate_bounce(engine, luna, target), "the effect is activated")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE,
		"it was negated, so Luna is still on the field and could otherwise try again")
	t.is_null(_bounce_offered(engine, luna),
		"but the allowance is gone — it is spent by ACTIVATING, not by resolving")


# ---------------------------------------------------------------------------
# Clause 2 — the return branch
# ---------------------------------------------------------------------------

static func _test_both_return_to_their_owners_hands(t: TestCase) -> void:
	t.start("「持ち主の手札に戻す」 — each card goes to its OWNER's hand, which the printed "
		+ "English ('to the hand') does not say")
	var d := _bounce_board(1747)
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var mark: int = engine.state.events.size()

	t.is_true(_activate_bounce(engine, luna, target), "the effect resolves")
	t.eq(luna.zone, Enums.Zone.HAND, "Luna is in a hand")
	t.eq(luna.controller_id, 0, "its owner's")
	t.eq(target.zone, Enums.Zone.HAND, "the target is in a hand")
	t.eq(target.controller_id, 1, "its owner's, not the effect controller's")
	t.eq(luna.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"the reason is RETURNED_TO_HAND — a bounce, not a search and not a destruction")
	t.eq(target.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND, "for both of them")
	t.eq(TestFixtures.events_of(engine, GameEvent.Kind.CARD_DESTROYED, mark).size(), 0,
		"nothing was destroyed")


static func _test_a_target_that_left_the_field_stops_everything(t: TestCase) -> void:
	t.start("R11 Part E: 「少なくとも片方がモンスターゾーンに存在しなくなった場合、処理は行われ "
		+ "ません」 — a target that has left costs the WHOLE effect, and Luna stays too")
	var d := _bounce_board(1748, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))

	# A Chain Link 2 the opponent activates in response destroys the target, so it is gone
	# by the time Luna's link resolves. Poking the board after submit_action() would test
	# nothing — the Chain has already finished by then.
	var killer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Destroyer", target, "destroy"), -1)
	var offered = _bounce_offered(engine, luna)
	t.not_null(offered, "the Quick Effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and activated as Chain Link 1")
	t.is_true(_respond_with(engine, 1, killer),
		"the opponent destroys the target as Chain Link 2, which resolves FIRST")
	TestFixtures.pass_until_open(engine)

	t.eq(target.zone, Enums.Zone.GRAVEYARD, "the target is gone by resolution")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE,
		"and Luna is NOT returned — 'both … and …' is one process and it is all or none")
	for entry in p1.seen_requests:
		t.ne((entry as DecisionRequest).kind, Enums.DecisionKind.SELECT_UP_TO,
			"the opponent was not even offered the negation — "
			+ "「相手は対象の同名カードを墓地へ送ることもできません」")


static func _test_this_card_leaving_the_field_stops_everything(t: TestCase) -> void:
	t.start("R11 Part E, the other half: a Luna that has left the Monster Zone by "
		+ "resolution costs the whole effect, and the target stays")
	var d := _bounce_board(1749, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))

	var killer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Destroyer", luna, "destroy"), -1)
	var offered = _bounce_offered(engine, luna)
	t.not_null(offered, "the Quick Effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and activated as Chain Link 1")
	t.is_true(_respond_with(engine, 1, killer),
		"the opponent destroys LUNA as Chain Link 2, which resolves FIRST")
	TestFixtures.pass_until_open(engine)

	t.eq(luna.zone, Enums.Zone.GRAVEYARD, "Luna is gone by resolution")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "so the target is not returned either")
	for entry in p1.seen_requests:
		t.ne((entry as DecisionRequest).kind, Enums.DecisionKind.SELECT_UP_TO,
			"and again nobody was offered the negation")


static func _test_a_face_down_target_is_returned_but_is_not_offered_the_negation(
		t: TestCase) -> void:
	t.start("R11 Part D: 「対象のモンスターが裏側守備表示になった場合、相手は…墓地へ送ることが "
		+ "できず、『…手札に戻す』処理を行います」 — the return still happens, the offer does not")
	var d := _bounce_board(1750, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))

	# The flip has to land on a real Chain Link 2, not on the board after the Chain has
	# already resolved — that is the vacuous-test shape batch 16's mutation M15 exposed.
	var flipper := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Flipper", target, "flip_face_down"), -1)
	var offered = _bounce_offered(engine, luna)
	t.not_null(offered, "the Quick Effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and activated as Chain Link 1")
	t.is_true(_respond_with(engine, 1, flipper),
		"the opponent flips the target face-down as Chain Link 2, which resolves FIRST")
	TestFixtures.pass_until_open(engine)

	for entry in p1.seen_requests:
		t.ne((entry as DecisionRequest).kind, Enums.DecisionKind.SELECT_UP_TO,
			"a face-down target loses its controller the chance to negate")
	t.eq(copy.zone, Enums.Zone.DECK, "so the copy stayed in the Deck")
	t.eq(luna.zone, Enums.Zone.HAND, "and the return happened all the same: Luna")
	t.eq(target.zone, Enums.Zone.HAND, "and the face-down target")


static func _test_a_target_whose_control_changed_is_still_returned(t: TestCase) -> void:
	t.start("R11 Part E: this card does NOT inherit R29 — its supplement re-checks only "
		+ "presence in a MONSTER ZONE, so a target whose control changed is still returned")
	var d := _bounce_board(1751)
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	t.eq(target.controller_id, 1, "the target starts under the opponent's control")

	# The control change has to land on a real Chain Link 2. Doing it by poking the board
	# after `submit_action()` would test nothing: the Chain has already fully resolved by
	# then, and `change_control()` would simply be refused. That is the vacuous shape batch
	# 16's mutation M15 exposed, and it is the shape this test had on its first draft.
	var thief := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Thief", target, "take_control"), -1)
	var offered = _bounce_offered(engine, luna)
	t.not_null(offered, "the Quick Effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and activated as Chain Link 1")
	t.is_true(_respond_with(engine, 0, thief),
		"control of the target is taken as Chain Link 2, which resolves FIRST")
	TestFixtures.pass_until_open(engine)

	t.eq(target.zone, Enums.Zone.HAND,
		"and it is STILL returned — the re-check names the Monster Zone, not control")
	t.eq(target.controller_id, 1,
		"to its OWNER's hand, because control ends when a card leaves the field")
	t.eq(luna.zone, Enums.Zone.HAND, "and Luna goes back too")

	# The other direction: a card the effect's controller OWNS but the opponent CONTROLS is
	# a legal target, and comes back to the effect controller's own hand.
	var d2 := _board(1752)
	var engine2: DuelEngine = d2["engine"]
	var luna2 := TestFixtures.give_monster_on_field(engine2, 0, _def())
	var borrowed := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.monster("Borrowed", 4, 1000, 1000))
	t.is_true(engine2.state.change_control(borrowed, 1, -1,
		Enums.ControlDuration.PERMANENT), "the opponent takes control of it")
	t.eq(borrowed.owner_id, 0, "it is still owned by player 0")
	t.is_true(_bounce_targets(engine2, luna2).has(borrowed.id),
		"control is what the text names, so it is a legal target")
	t.is_true(_activate_bounce(engine2, luna2, borrowed), "and the effect resolves")
	t.eq(borrowed.zone, Enums.Zone.HAND, "it returns to a hand")
	t.eq(borrowed.controller_id, 0, "its OWNER's — player 0's own")


static func _test_an_unaffected_target_costs_only_this_card(t: TestCase) -> void:
	t.start("R11 Part G: 「対象のカードがこの効果を受けない場合、このカードだけが手札に戻ります」 "
		+ "— batch 16's immunity gate, seen from a second card")
	var d := _bounce_board(1753)
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	# The immunity is granted the way `The Monarchs Awaken` grants it, through the gate,
	# with an exempt source that is NOT Luna.
	var ward := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Ward"))
	t.is_true(EffectImmunity.grant(target, ward), "the target becomes unaffected")
	t.is_true(target.is_unaffected_by_effect_of(luna.id),
		"including by Luna's effect, which is not the exempt source")

	t.is_true(_activate_bounce(engine, luna, target), "the effect resolves")
	t.eq(luna.zone, Enums.Zone.HAND, "Luna still goes back to the hand")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "the unaffected target does not")

	# The control: an identical board without the immunity returns both, so the assertion
	# above is about the immunity and not about the effect quietly failing.
	var d2 := _bounce_board(1754)
	var engine2: DuelEngine = d2["engine"]
	t.is_true(_activate_bounce(engine2, d2["luna"], d2["target"]), "the control resolves")
	t.eq((d2["target"] as CardInstance).zone, Enums.Zone.HAND,
		"an ordinary target IS returned")


# ---------------------------------------------------------------------------
# Negation of Luna's own effect
# ---------------------------------------------------------------------------

static func _test_effect_negation(t: TestCase) -> void:
	t.start("an effect-negating answer stops the whole clause: nothing returns, and the "
		+ "opponent is not offered the payment either")
	var d := _bounce_board(1755, _card(DUPLICATE))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Effect Negator"), -1)

	var offered = _bounce_offered(engine, luna)
	t.not_null(offered, "the Quick Effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and activated as Chain Link 1")
	t.is_true(_respond_with(engine, 1, negator),
		"the opponent negates the EFFECT as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "Luna stays on the field")
	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "and so does the target")
	t.eq(copy.zone, Enums.Zone.DECK, "the copy stayed in the Deck")
	for entry in p1.seen_requests:
		t.ne((entry as DecisionRequest).kind, Enums.DecisionKind.SELECT_UP_TO,
			"a negated effect never reaches the point of offering the payment")
	t.is_null(_bounce_offered(engine, luna),
		"and the once-per-turn allowance is still spent")


static func _test_activation_negation(t: TestCase) -> void:
	t.start("negating the ACTIVATION stops it too — a branch NO card in the V1 pool can "
		+ "reach, because nothing in the pool negates a monster effect's activation, so it "
		+ "is exercised against a synthetic negator and said out loud")
	# The never-live claim, asserted behaviourally rather than left in a comment. The pool's
	# one activation-negating card is `Champion's Vigilance`; it DOES listen to
	# `EFFECT_ACTIVATED`, so the trigger list settles nothing — its CONDITION is what
	# restricts it to a Spell/Trap card activation. So the question is asked the only way
	# that answers it: is it offered in response to Luna's monster effect?
	var d0 := _bounce_board(1755 + 100)
	var engine0: DuelEngine = d0["engine"]
	var luna0: CardInstance = d0["luna"]
	var target0: CardInstance = d0["target"]
	# The opponent holds everything `Champion's Vigilance` needs: a Level 7 or higher
	# Normal Monster on the field, and the Trap Set on an earlier turn.
	var big := TestFixtures.give_monster_on_field(engine0, 1,
		_card("Metaphys Armed Dragon"))
	t.eq(big.definition.level, 7, "the opponent controls a Level 7 Normal Monster")
	t.is_true(big.definition.is_normal_monster, "and it really is a Normal Monster")
	var vigilance := TestFixtures.give_set_spell_trap(engine0, 1,
		_card("Champion's Vigilance"), -1)
	var first = _bounce_offered(engine0, luna0)
	if first != null:
		t.is_true(engine0.submit_action(
			first.with_choices({"target_ids": [target0.id]})),
			"Luna's Quick Effect is activated")
		t.is_null(TestFixtures.find_action(engine0.get_legal_responses(1),
			Enums.ActionKind.ACTIVATE_CARD, vigilance.id),
			"and `Champion's Vigilance` is NOT offered — no card in the pool can negate a "
			+ "monster effect's activation, so this branch is unreachable in a real duel")
		TestFixtures.pass_until_open(engine0)

	var d := _bounce_board(1756)
	var engine: DuelEngine = d["engine"]
	var luna: CardInstance = d["luna"]
	var target: CardInstance = d["target"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_activation_negator("Activation Negator"), -1)

	var offered = _bounce_offered(engine, luna)
	t.not_null(offered, "the Quick Effect is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [target.id]})),
		"and activated as Chain Link 1")
	t.is_true(_respond_with(engine, 1, negator),
		"the opponent negates the ACTIVATION as Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(target.zone, Enums.Zone.MONSTER_ZONE, "the target is untouched")
	t.eq(luna.zone, Enums.Zone.MONSTER_ZONE, "and so is Luna")
	t.is_null(_bounce_offered(engine, luna),
		"and the once-per-turn allowance is still gone — it is spent by declaring the "
		+ "activation, which really happened")


# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

static func _test_the_same_seed_and_script_replay_identically(t: TestCase) -> void:
	t.start("the same seed and the same scripted answers — INCLUDING the opponent's "
		+ "mid-resolution decision — reproduce the same duel every time")
	var traces: Array = []
	var payloads: Array = []
	for run in range(3):
		var d := _bounce_board(1757, _card(DUPLICATE))
		var engine: DuelEngine = d["engine"]
		var luna: CardInstance = d["luna"]
		var target: CardInstance = d["target"]
		var copy := TestFixtures.give_to_deck(engine, 1, _card(DUPLICATE))
		# Run 0 and 2 pay; run 1 declines. Two different scripts must give two different
		# duels, or "deterministic" would be indistinguishable from "always the same".
		(d["p1"] as ScriptedController).queue([] if run == 1 else [copy.id])
		_activate_bounce(engine, luna, target)
		traces.append("%d/%d/%d" % [int(luna.zone), int(target.zone), int(copy.zone)])
		payloads.append(JSON.stringify(engine.log.to_replay()["decisions"]))
	t.eq(traces[2], traces[0], "the two identical scripts produced identical outcomes")
	t.eq(payloads[2], payloads[0], "and identical replay payloads")
	t.ne(traces[1], traces[0],
		"while the script that declined produced a DIFFERENT duel — the decision really "
		+ "drives the outcome")

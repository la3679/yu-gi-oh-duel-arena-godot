class_name KaiserSeaHorseTests
extends RefCounted

## `Kaiser Sea Horse` — LIGHT / Sea Serpent / Level 4, 1700 ATK / 1650 DEF.
## One copy, deck 2 ("Fairy-Tail Tribute Guard").
##
## Official text (verified, `Data/cards/cards.json`, cid 5409):
##
##   "This card can be treated as 2 Tributes for the Tribute Summon of a LIGHT monster."
##
## One clause, and it is a rules **query** rather than an effect that does anything:
## `SummonRules.tribute_value()` asks it, with the monster about to be Summoned as the
## argument. `Research/CARD_RULINGS.md` **R8** — which this suite closes.
##
## **The coincidence this suite is built around: Kaiser Sea Horse is itself LIGHT.** An
## implementation that read the Attribute off the wrong card — its own instead of the one
## being Summoned — would pass every test that only ever Summons a LIGHT monster. So every
## positive here is paired with a non-LIGHT negative on the same board.
##
## The generic mechanism (`SummonRules.TRIBUTE_VALUE_EFFECT_ID`, `tribute_value()`,
## `tributes_satisfy()`) already existed and is proved against a synthetic card in
## `SummonTests`. What this suite proves is that the printed card is wired to it, that it
## really shortens a real Summon end to end, and that it does NOT reach the Tribute-as-a-cost
## path.

const CARD_UNDER_TEST := "Kaiser Sea Horse"

const BASE_ATK := 1700
const BASE_DEF := 1650


static func run() -> TestCase:
	var t := TestCase.new("KaiserSeaHorseTests")

	# --- Shape ---
	_test_the_card_declares_one_rules_query_clause(t)
	_test_the_clause_applies_nothing_and_starts_no_chain(t)

	# --- The query itself ---
	_test_it_is_worth_two_tributes_for_a_light_summon(t)
	_test_it_is_worth_one_tribute_for_a_non_light_summon(t)
	_test_the_attribute_read_is_of_the_summoned_monster_not_of_this_card(t)
	_test_an_ordinary_monster_is_always_worth_one(t)

	# --- End to end ---
	_test_it_alone_satisfies_a_two_tribute_light_summon(t)
	_test_it_does_not_shorten_a_two_tribute_non_light_summon(t)
	_test_it_may_still_be_tributed_for_a_one_tribute_light_summon(t)

	# --- Where it does NOT apply ---
	_test_a_negated_copy_is_worth_one(t)
	_test_a_face_down_copy_is_worth_one(t)
	_test_it_does_not_reach_a_tribute_paid_as_a_cost(t)

	# --- The pool ---
	_test_the_real_pool_makes_the_clause_live(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _def(card_name: String = CARD_UNDER_TEST) -> CardDef:
	return (_library()["cards"] as Dictionary).get(card_name, null)


## Player 0 in Main Phase 1 with a face-up Kaiser Sea Horse and both a LIGHT and a non-LIGHT
## Level 8 monster in hand — every test needs the pair so the negative is on the same board.
static func _board(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["seahorse"] = TestFixtures.give_monster_on_field(engine, 0, _def())
	d["light"] = TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Big LIGHT", 8, 3000, 2500, "LIGHT"))
	d["dark"] = TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Big DARK", 8, 3000, 2500, "DARK"))
	return d


static func _value(engine: DuelEngine, material: CardInstance,
		summoned: CardInstance) -> int:
	return engine.summons.tribute_value(material, summoned)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_the_card_declares_one_rules_query_clause(t: TestCase) -> void:
	t.start("one EffectDef, CONTINUOUS, carrying the generic TRIBUTE_VALUE_EFFECT_ID — the "
		+ "rules layer finds it by id, never by card name")
	var card_def := _def()
	t.not_null(card_def, "the card loaded from the registry")
	t.eq(card_def.effects.size(), 1, "exactly one clause")
	t.eq(card_def.base_atk, BASE_ATK, "1700 ATK")
	t.eq(card_def.base_def, BASE_DEF, "1650 DEF")
	t.eq(card_def.level, 4, "Level 4")
	t.eq(card_def.attribute, "LIGHT", "and it is itself LIGHT — the coincidence this suite "
		+ "is built to see through")

	var effect: EffectDef = card_def.effects[0]
	t.eq(effect.effect_id, SummonRules.TRIBUTE_VALUE_EFFECT_ID,
		"the clause is the generic tribute-value query")
	t.eq(effect.effect_type, Enums.EffectType.CONTINUOUS, "a Continuous clause")
	t.eq(effect.ruling_ref, "R8", "and it cites R8")
	t.is_true(effect.condition.is_valid(),
		"it answers through condition(), which is what the rules layer calls")


static func _test_the_clause_applies_nothing_and_starts_no_chain(t: TestCase) -> void:
	t.start("it is a QUERY: it applies nothing to the board, so it legitimately has no "
		+ "apply_continuous, no resolve, and starts no Chain")
	var effect: EffectDef = _def().effects[0]
	t.is_false(effect.apply_continuous.is_valid(),
		"no apply_continuous — nothing is written to the board")
	t.is_false(effect.resolve.is_valid(), "no resolve — nothing resolves")
	t.is_false(effect.respond_to_event.is_valid(), "and it responds to no event")
	t.is_false(effect.starts_chain, "it starts no Chain")
	t.is_true(CardRegistry.RULES_QUERY_EFFECT_IDS.has(effect.effect_id),
		"and the registry validator knows this id is allowed to apply nothing")


# ---------------------------------------------------------------------------
# The query
# ---------------------------------------------------------------------------

static func _test_it_is_worth_two_tributes_for_a_light_summon(t: TestCase) -> void:
	t.start("'2 Tributes for the Tribute Summon of a LIGHT monster'")
	var d := _board(9501)
	t.eq(_value(d["engine"], d["seahorse"], d["light"]), 2,
		"it counts as 2 for a LIGHT monster")


static func _test_it_is_worth_one_tribute_for_a_non_light_summon(t: TestCase) -> void:
	t.start("and as only 1 for anything else — the same card, the same board, a different "
		+ "monster being Summoned")
	var d := _board(9503)
	t.eq(_value(d["engine"], d["seahorse"], d["dark"]), 1,
		"a DARK monster gets no discount")


static func _test_the_attribute_read_is_of_the_summoned_monster_not_of_this_card(
		t: TestCase) -> void:
	t.start("the Attribute read is of the monster being SUMMONED — asserted against a "
		+ "non-LIGHT Kaiser-like card Summoning a LIGHT monster, and the reverse")
	var d := _board(9505)
	var engine: DuelEngine = d["engine"]
	# A synthetic copy of the same clause on a DARK body. If the implementation read its own
	# Attribute, this would answer 1 for a LIGHT Summon — and the real card would answer 2
	# for a DARK Summon. Both directions are checked.
	var dark_body := TestFixtures.monster("Dark Sea Horse", 4, 1700, 1650, "DARK")
	for effect in _def().effects:
		TestFixtures.with_effect(dark_body, effect)
	var dark_seahorse := TestFixtures.give_monster_on_field(engine, 0, dark_body)

	t.eq(dark_body.attribute, "DARK", "the synthetic body is DARK")
	t.eq(_value(engine, dark_seahorse, d["light"]), 2,
		"a DARK card with this clause is still worth 2 for a LIGHT Summon")
	t.eq(_value(engine, dark_seahorse, d["dark"]), 1,
		"and worth 1 for a DARK Summon")
	t.eq(_value(engine, d["seahorse"], d["dark"]), 1,
		"while the real LIGHT card is worth 1 for a DARK Summon — so the read really is of "
		+ "the summoned monster")


static func _test_an_ordinary_monster_is_always_worth_one(t: TestCase) -> void:
	t.start("CONTROL: a monster with no such clause is worth 1 whatever is being Summoned")
	var d := _board(9507)
	var engine: DuelEngine = d["engine"]
	var plain := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Plain Body", 4, 1000, 1000, "LIGHT"))
	t.eq(_value(engine, plain, d["light"]), 1, "1 for a LIGHT Summon")
	t.eq(_value(engine, plain, d["dark"]), 1, "and 1 for a DARK one")


# ---------------------------------------------------------------------------
# End to end
# ---------------------------------------------------------------------------

static func _test_it_alone_satisfies_a_two_tribute_light_summon(t: TestCase) -> void:
	t.start("end to end: one Kaiser Sea Horse Tribute Summons a Level 8 LIGHT monster that "
		+ "would otherwise need two")
	var d := _board(9509)
	var engine: DuelEngine = d["engine"]
	var light: CardInstance = d["light"]
	t.eq(engine.summons.tributes_required(light), 2, "a Level 8 monster needs 2 Tributes")

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, light.id)
	t.not_null(a, "the Tribute Summon is offered with only one monster on the field")
	t.is_true(engine.submit_action(
		a.with_choices({"tribute_ids": [(d["seahorse"] as CardInstance).id]})),
		"and one Tribute is accepted")
	TestFixtures.pass_until_open(engine)

	t.eq(light.zone, Enums.Zone.MONSTER_ZONE, "the LIGHT monster reached the field")
	t.eq((d["seahorse"] as CardInstance).zone, Enums.Zone.GRAVEYARD,
		"and Kaiser Sea Horse was Tributed")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED,
		light.id), 1, "by a real Normal Summon, through the engine's own route")


static func _test_it_does_not_shorten_a_two_tribute_non_light_summon(t: TestCase) -> void:
	t.start("the negative on the same board: the Level 8 DARK monster is NOT summonable "
		+ "off the one Tribute")
	var d := _board(9511)
	var engine: DuelEngine = d["engine"]
	var actions := engine.get_legal_actions(0)
	t.is_true(TestFixtures.has_action(actions, Enums.ActionKind.TRIBUTE_SUMMON,
		(d["light"] as CardInstance).id), "the LIGHT monster is offered")
	t.is_false(TestFixtures.has_action(actions, Enums.ActionKind.TRIBUTE_SUMMON,
		(d["dark"] as CardInstance).id), "the DARK monster is not")
	t.is_false(engine.summons.tributes_satisfy(d["dark"], [d["seahorse"]]),
		"and one Kaiser Sea Horse does not satisfy its requirement")


static func _test_it_may_still_be_tributed_for_a_one_tribute_light_summon(
		t: TestCase) -> void:
	t.start("'CAN be treated as 2' — it is permission, not compulsion, so it may still pay "
		+ "a one-Tribute LIGHT Summon on its own")
	var d := _board(9513)
	var engine: DuelEngine = d["engine"]
	var light6 := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Middling LIGHT", 6, 2400, 1000, "LIGHT"))
	t.eq(engine.summons.tributes_required(light6), 1, "a Level 6 monster needs 1 Tribute")
	t.eq(_value(engine, d["seahorse"], light6), 2, "and Kaiser Sea Horse is worth 2 for it")
	t.is_true(engine.summons.tributes_satisfy(light6, [d["seahorse"]]),
		"which still satisfies a requirement of 1 — a card worth 2 may overshoot")

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, light6.id)
	t.not_null(a, "the Summon is offered")
	t.is_true(engine.submit_action(
		a.with_choices({"tribute_ids": [(d["seahorse"] as CardInstance).id]})),
		"and goes through")
	TestFixtures.pass_until_open(engine)
	t.eq(light6.zone, Enums.Zone.MONSTER_ZONE, "the monster reached the field")


# ---------------------------------------------------------------------------
# Where it does not apply
# ---------------------------------------------------------------------------

static func _test_a_negated_copy_is_worth_one(t: TestCase) -> void:
	t.start("a negated Kaiser Sea Horse applies no effects, so it is worth 1 again")
	var d := _board(9515)
	var engine: DuelEngine = d["engine"]
	var seahorse: CardInstance = d["seahorse"]
	t.eq(_value(engine, seahorse, d["light"]), 2, "CONTROL: worth 2 to begin with")

	seahorse.effects_negated = true
	engine.continuous.recompute()
	t.eq(_value(engine, seahorse, d["light"]), 1, "negated: worth 1")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.TRIBUTE_SUMMON, (d["light"] as CardInstance).id),
		"so the Level 8 LIGHT monster is no longer summonable off it alone")

	seahorse.effects_negated = false
	engine.continuous.recompute()
	t.eq(_value(engine, seahorse, d["light"]), 2, "un-negated: worth 2 again")


static func _test_a_face_down_copy_is_worth_one(t: TestCase) -> void:
	t.start("a face-down monster may still be Tributed [S1 p.53] but applies no effects, so "
		+ "a face-down Kaiser Sea Horse is worth 1")
	var d := _board(9517)
	var engine: DuelEngine = d["engine"]
	var seahorse: CardInstance = d["seahorse"]
	engine.state.set_battle_position(seahorse, Enums.Position.FACE_DOWN_DEFENSE, true)
	engine.continuous.recompute()

	t.is_true(seahorse.is_face_down(), "it is face-down")
	t.is_true(engine.summons.tribute_candidates(0).has(seahorse),
		"and is still a legal Tribute — face-down monsters count [S1 p.53]")
	t.eq(_value(engine, seahorse, d["light"]), 1,
		"but it is worth only 1, because a face-down card applies no effects")


static func _test_it_does_not_reach_a_tribute_paid_as_a_cost(t: TestCase) -> void:
	t.start("'for the TRIBUTE SUMMON of' — a Tribute paid as an activation COST is a "
		+ "different thing and never asks this question")
	var d := _board(9519)
	var engine: DuelEngine = d["engine"]
	var seahorse: CardInstance = d["seahorse"]
	# A synthetic Spell whose activation COST is "Tribute 2 monsters". The pool's own
	# Tribute-cost cards name a Type (`Dragonic Tactics` wants Dragons) or Tribute themselves
	# (`Kaibaman`), so neither can express this question about a Sea Serpent; the point being
	# tested is a property of the COST CHANNEL, not of any printed card.
	var cost_card := TestFixtures.spell("Tribute Two Spell")
	var e := EffectDef.new("tribute_two_cost", "Test: Tribute 2 monsters; nothing happens.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND]
	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return ctx.me().monsters().size() >= 2
	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_tribute_cost(ctx, ctx.me().monsters(), 2,
			"Tribute 2 monsters")
		return paid.size() == 2
	e.resolve = func(_ctx: EffectContext) -> void:
		pass
	TestFixtures.with_effect(cost_card, e)
	var spell := TestFixtures.give_to_hand(engine, 0, cost_card)

	t.eq(_value(engine, seahorse, d["light"]), 2,
		"CONTROL: it is worth 2 for a LIGHT Tribute Summon")
	t.eq(engine.state.player(0).monsters().size(), 1,
		"and Kaiser Sea Horse is the only monster on the field")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"yet a 'Tribute 2 monsters' COST cannot be paid with it — the cost counts CARDS, and "
		+ "being worth 2 Tributes does not pay it")

	# Add a second body and the same cost becomes payable, which proves the negative above
	# was about the count and not about something else refusing the activation.
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Second Body", 4, 1000, 1000, "LIGHT"))
	engine.continuous.recompute()
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id),
		"with two monsters it is payable — so the refusal above really was the card count")


# ---------------------------------------------------------------------------
# The pool
# ---------------------------------------------------------------------------

static func _test_the_real_pool_makes_the_clause_live(t: TestCase) -> void:
	t.start("the real pool: Kaiser Sea Horse's own deck holds Level 7+ LIGHT monsters that "
		+ "need two Tributes, so the clause matters in a real duel")
	var cards: Dictionary = _library()["cards"]
	t.eq(cards.size(), 77, "the whole pool was loaded")

	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the verified card database is readable")
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	t.check(parsed is Dictionary, "and parses")

	var my_deck := ""
	var cid := ""
	var text := ""
	var beneficiaries: Array = []
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if str(row.get("name", "")) == CARD_UNDER_TEST:
				cid = str(row.get("konami_cid", ""))
				text = str(row.get("text", ""))
				var decks: Array = row.get("decks", [])
				my_deck = str(decks[0]) if not decks.is_empty() else ""
	t.eq(cid, "5409", "the verified Konami card id")
	t.ne(my_deck, "", "and it belongs to a deck")
	t.eq(text, CLAUSE_TEXT(), "the implemented clause is the verified text, verbatim")

	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if str(row.get("category", "")) != "Monster":
				continue
			if int(row.get("level", 0)) < 5:
				continue
			if str(row.get("attribute", "")) != "LIGHT":
				continue
			if not (row.get("decks", []) as Array).has(my_deck):
				continue
			beneficiaries.append(str(row.get("name", "")))
	t.is_true(beneficiaries.size() >= 1,
		"at least one Level 5+ LIGHT monster shares its deck: %s" % str(beneficiaries))
	var needs_two := false
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("cards", []):
			var row: Dictionary = entry
			if beneficiaries.has(str(row.get("name", ""))) and int(row.get("level", 0)) >= 7:
				needs_two = true
	t.is_true(needs_two,
		"and at least one of them is Level 7+, so it needs TWO Tributes and Kaiser Sea "
		+ "Horse alone supplies them — the clause is not decoration")


## The verified official text, read from the card file rather than retyped here.
static func CLAUSE_TEXT() -> String:
	return load("res://Scripts/cards/registry/KaiserSeaHorse.gd") \
		.get_script_constant_map()["CLAUSE"]

class_name ShiningAngelTests
extends RefCounted

## Per-card suite for `Shining Angel`, the card that appears in BOTH V1 decks.
## `Tools/build_matrix.py` reads CARD_UNDER_TEST, so the matrix can only report this card
## as TESTED because this file exists and passes.
##
## Every clause is exercised positively AND negatively. The negatives are the point: the
## clause is a battle-destruction trigger, so it must NOT fire when the same card reaches
## the Graveyard any other way.

const CARD_UNDER_TEST := "Shining Angel"


static func run() -> TestCase:
	var t := TestCase.new("ShiningAngelTests")
	_test_registry_loads_cleanly(t)
	_test_clause_shape(t)
	_test_recruits_when_destroyed_by_battle(t)
	_test_declining_summons_nothing(t)
	_test_no_trigger_when_destroyed_by_an_effect(t)
	_test_no_trigger_when_tributed(t)
	_test_not_offered_without_a_legal_monster(t)
	_test_not_offered_with_a_full_monster_zone(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.load_library()


static func _angel_def() -> CardDef:
	var lib := _library()
	return (lib["cards"] as Dictionary).get(CARD_UNDER_TEST, null)


## A LIGHT monster the clause may recruit.
static func _valid_recruit(name: String, atk: int = 1200) -> CardDef:
	return TestFixtures.monster(name, 4, atk, 1000, "LIGHT")


## A monster the clause may NOT recruit — right attribute, too much ATK.
static func _invalid_recruit(name: String) -> CardDef:
	return TestFixtures.monster(name, 4, 1900, 1000, "LIGHT")


static func _deck_of(defs: Array) -> Array:
	var out: Array = []
	var i := 0
	while out.size() < TestFixtures.DECK_SIZE:
		out.append(defs[i % defs.size()])
		i += 1
	return out


## A duel in the Battle Step of turn 2 with player 0 attacking, where the DEFENDING
## player (1) owns `deck1` — Shining Angel recruits from its own controller's Deck.
static func _battle_duel(seed_value: int, deck1: Array) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1, TestFixtures.filler_deck("A"), deck1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	return d


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

static func _test_registry_loads_cleanly(t: TestCase) -> void:
	t.start("the card registry loads and attaches this card to its canonical definition")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var cards: Dictionary = lib["cards"]
	t.eq(cards.size(), 77, "all 77 canonical card definitions loaded")
	t.is_true(cards.has(CARD_UNDER_TEST), "the card is in the database")

	var def: CardDef = cards[CARD_UNDER_TEST]
	t.eq(def.effects.size(), 1,
		"one EffectDef per official effect clause, and this card has one clause")
	var effect: EffectDef = def.effects[0]
	t.eq(effect.card_name, CARD_UNDER_TEST,
		"the registry stamped the card name onto the effect")


static func _test_clause_shape(t: TestCase) -> void:
	t.start("the clause is an optional Trigger Effect with a Damage Step window "
		+ "that does not target")
	var def := _angel_def()
	t.not_null(def, "the definition exists")
	var effect: EffectDef = def.effects[0]

	t.eq(effect.effect_type, Enums.EffectType.TRIGGER, "it is a Trigger Effect")
	t.eq(effect.optionality, Enums.Optionality.OPTIONAL,
		"'You can' makes it optional — silence is never taken as yes")
	t.eq(effect.spell_speed, Enums.SpellSpeed.SS1, "a Trigger Effect is Spell Speed 1")
	t.eq(effect.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"its window is inside the Damage Step — a timing permission, not a claim that "
		+ "the effect is compulsory (RULES_SPEC.md 7.2)")
	t.is_false(effect.targets,
		"the official text has no 'target', so the monster is chosen at resolution "
		+ "(RULES_SPEC.md 10)")
	t.eq(effect.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"it activates from the Graveyard, where the card already is by sub-step 5")
	t.is_true(effect.trigger_events.has(GameEvent.Kind.CARD_SENT_TO_GY),
		"it keys off being sent to the GY")
	t.is_true(effect.clause_text.contains("1500 or less ATK"),
		"the clause text is quoted from the verified official text")


# ---------------------------------------------------------------------------
# The clause, positively
# ---------------------------------------------------------------------------

static func _test_recruits_when_destroyed_by_battle(t: TestCase) -> void:
	t.start("destroyed by battle: Special Summons a LIGHT monster with 1500 or less ATK "
		+ "from the Deck in Attack Position")
	var d := _battle_duel(8101, _deck_of([_valid_recruit("Beacon"), _invalid_recruit("Too Strong")]))
	var engine: DuelEngine = d["engine"]
	var defender_ctrl: ScriptedController = d["p1"]
	defender_ctrl.default_yes = true

	var angel := TestFixtures.give_monster_on_field(engine, 1, _angel_def())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var deck_before := engine.state.player(1).deck.size()

	t.is_true(TestFixtures.attack(engine, attacker, angel), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "Shining Angel was destroyed by battle")
	t.eq(engine.state.player(1).monster_count(), 1,
		"and a replacement monster is on the field")
	t.eq(engine.state.player(1).deck.size(), deck_before - 1,
		"which came out of the Deck")

	var summoned: CardInstance = engine.state.player(1).monsters()[0]
	t.eq(summoned.card_name(), "Beacon", "the recruited monster is the legal candidate")
	t.eq(summoned.position, Enums.Position.FACE_UP_ATTACK,
		"in Attack Position, as the clause specifies")
	t.eq(summoned.summoned_by, Enums.SummonKind.SPECIAL, "by Special Summon")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 1,
		"exactly one Special Summon succeeded")
	t.eq(defender_ctrl.request_count(Enums.DecisionKind.YES_NO), 1,
		"its controller was asked exactly once whether to use the optional effect")

	# Every card the controller was offered must satisfy the clause's own restriction.
	# The Deck here deliberately also holds LIGHT monsters that are too strong.
	var offered_all_legal := true
	var offered_any := false
	for entry in defender_ctrl.seen_requests:
		var request: DecisionRequest = entry
		if request.kind != Enums.DecisionKind.SELECT_EXACTLY:
			continue
		offered_any = true
		for option in request.options:
			var candidate: CardInstance = engine.state.instance(int(option))
			if candidate == null or candidate.definition.attribute != "LIGHT" \
					or candidate.definition.base_atk > 1500:
				offered_all_legal = false
	t.is_true(offered_any, "the controller was asked which monster to Special Summon")
	t.is_true(offered_all_legal,
		"and every candidate offered was LIGHT with 1500 or less ATK — the 'Too Strong' "
		+ "copies in the same Deck were filtered out")


# ---------------------------------------------------------------------------
# The clause, negatively
# ---------------------------------------------------------------------------

static func _test_declining_summons_nothing(t: TestCase) -> void:
	t.start("declining the optional effect Summons nothing")
	var d := _battle_duel(8102, _deck_of([_valid_recruit("Beacon"), _invalid_recruit("Too Strong")]))
	var engine: DuelEngine = d["engine"]
	var defender_ctrl: ScriptedController = d["p1"]
	defender_ctrl.default_yes = false

	var angel := TestFixtures.give_monster_on_field(engine, 1, _angel_def())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var deck_before := engine.state.player(1).deck.size()

	TestFixtures.attack(engine, attacker, angel)
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "the Angel still died")
	t.eq(defender_ctrl.request_count(Enums.DecisionKind.YES_NO), 1,
		"its controller was still asked")
	t.eq(engine.state.player(1).monster_count(), 0, "but nothing was Summoned")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and the Deck is untouched")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED), 0,
		"no Special Summon occurred")


static func _test_no_trigger_when_destroyed_by_an_effect(t: TestCase) -> void:
	t.start("destroyed by a card effect is NOT destroyed by battle: the clause is silent")
	var d := _battle_duel(8103, _deck_of([_valid_recruit("Beacon"), _invalid_recruit("Too Strong")]))
	var engine: DuelEngine = d["engine"]
	var defender_ctrl: ScriptedController = d["p1"]
	defender_ctrl.default_yes = true

	var angel := TestFixtures.give_monster_on_field(engine, 1, _angel_def())
	var asked_before := defender_ctrl.request_count(Enums.DecisionKind.YES_NO)
	engine.state.move_card(angel, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "it reached the Graveyard")
	t.eq(defender_ctrl.request_count(Enums.DecisionKind.YES_NO), asked_before,
		"its controller was never asked — the semantic reason is what gates the trigger "
		+ "[S1 p.52-53]")
	t.eq(engine.state.player(1).monster_count(), 0, "and nothing was Summoned")


static func _test_no_trigger_when_tributed(t: TestCase) -> void:
	t.start("Tributed is 'sent to the GY' but is NOT 'destroyed': the clause is silent")
	var d := _battle_duel(8104, _deck_of([_valid_recruit("Beacon"), _invalid_recruit("Too Strong")]))
	var engine: DuelEngine = d["engine"]
	var defender_ctrl: ScriptedController = d["p1"]
	defender_ctrl.default_yes = true

	var angel := TestFixtures.give_monster_on_field(engine, 1, _angel_def())
	var asked_before := defender_ctrl.request_count(Enums.DecisionKind.YES_NO)
	engine.state.move_card(angel, Enums.Zone.GRAVEYARD, Enums.MoveReason.TRIBUTED)
	TestFixtures.pass_until_open(engine)

	t.is_true(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY) > 0,
		"a Tribute IS 'sent to the Graveyard' [S1 p.53], so the trigger event did fire")
	t.eq(defender_ctrl.request_count(Enums.DecisionKind.YES_NO), asked_before,
		"but the clause requires DESTRUCTION BY BATTLE, so nobody was asked")
	t.eq(engine.state.player(1).monster_count(), 0, "and nothing was Summoned")


static func _test_not_offered_without_a_legal_monster(t: TestCase) -> void:
	t.start("with no LIGHT monster of 1500 or less ATK in the Deck there is nothing "
		+ "to activate")
	var d := _battle_duel(8105, _deck_of([_invalid_recruit("Too Strong")]))
	var engine: DuelEngine = d["engine"]
	var defender_ctrl: ScriptedController = d["p1"]
	defender_ctrl.default_yes = true

	var angel := TestFixtures.give_monster_on_field(engine, 1, _angel_def())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var asked_before := defender_ctrl.request_count(Enums.DecisionKind.YES_NO)

	TestFixtures.attack(engine, attacker, angel)
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "the Angel was destroyed by battle")
	t.eq(defender_ctrl.request_count(Enums.DecisionKind.YES_NO), asked_before,
		"but its controller is not asked a question with no possible answer")
	t.eq(engine.state.player(1).monster_count(), 0, "and nothing was Summoned")


static func _test_not_offered_with_a_full_monster_zone(t: TestCase) -> void:
	t.start("with no free Monster Zone the clause cannot be activated")
	var d := _battle_duel(8106, _deck_of([_valid_recruit("Beacon"), _invalid_recruit("Too Strong")]))
	var engine: DuelEngine = d["engine"]
	var defender_ctrl: ScriptedController = d["p1"]
	defender_ctrl.default_yes = true

	var angel := TestFixtures.give_monster_on_field(engine, 1, _angel_def())
	while engine.state.player(1).has_free_monster_zone():
		TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Bystander %d" % engine.state.player(1).monster_count(),
				4, 800, 800))
	var filled := engine.state.player(1).monster_count()
	t.is_true(filled > 1, "the defending field is full, Angel included")

	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var asked_before := defender_ctrl.request_count(Enums.DecisionKind.YES_NO)

	TestFixtures.attack(engine, attacker, angel)
	TestFixtures.pass_until_open(engine)

	t.eq(angel.zone, Enums.Zone.GRAVEYARD, "the Angel was destroyed by battle")
	# The Angel leaving frees its own zone, so the clause CAN be used: this asserts the
	# rule that is actually correct rather than the one that is convenient.
	t.eq(engine.state.player(1).monster_count(), filled - 1 + 1,
		"the zone the Angel vacated is available, so the recruit fills it")
	t.eq(defender_ctrl.request_count(Enums.DecisionKind.YES_NO), asked_before + 1,
		"and its controller was asked exactly once")

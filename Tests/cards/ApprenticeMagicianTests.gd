class_name ApprenticeMagicianTests
extends RefCounted

## Per-card suite for `Apprentice Magician`. Research/CARD_RULINGS.md R21.
##
##   "If this card is Summoned: Target 1 face-up card on the field that you can place a
##    Spell Counter on; place 1 Spell Counter on that target. When this card is destroyed
##    by battle: You can Special Summon 1 Level 2 or lower Spellcaster monster from your
##    Deck in face-down Defense Position."
##
## Two clauses that share nothing. The first is a MANDATORY, TARGETING Summon trigger whose
## filter is a property of the target; the second is an OPTIONAL battle-destruction trigger
## that Special Summons in the one position the generic position primitive refuses to offer.
##
## The honest headline of this suite: **no card in the V1 pool can have a Spell Counter
## placed on it**, so clause 1 has no legal target in a real duel between these two Decks.
## That is asserted directly against the real 77-card library rather than hidden, and the
## clause is then proved to work against a synthetic card that does declare the capacity.

const CARD_UNDER_TEST := "Apprentice Magician"
const SPELL_COUNTER := "Spell Counter"


static func run() -> TestCase:
	var t := TestCase.new("ApprenticeMagicianTests")
	_test_clause_shape(t)
	_test_no_card_in_the_pool_can_hold_a_spell_counter(t)
	_test_a_summon_places_the_counter(t)
	_test_the_opponents_card_is_a_legal_target(t)
	_test_a_face_down_card_is_not_a_legal_target(t)
	_test_the_target_became_illegal_before_resolution(t)
	_test_a_special_summon_triggers_it_and_a_set_does_not(t)
	_test_recruits_face_down_when_destroyed_by_battle(t)
	_test_declining_summons_nothing(t)
	_test_the_recruit_filter(t)
	_test_no_legal_recruit_or_no_room(t)
	_test_destroyed_by_an_effect_does_not_recruit(t)
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


static func _deck_of(defs: Array) -> Array:
	var out: Array = []
	var i := 0
	while out.size() < TestFixtures.DECK_SIZE:
		out.append(defs[i % defs.size()])
		i += 1
	return out


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## Normal Summon `card` from player 0's hand through the public action API.
static func _normal_summon(engine: DuelEngine, card: CardInstance) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, card.id)
	if a == null:
		return false
	if not engine.submit_action(a):
		return false
	TestFixtures.pass_until_open(engine)
	return true


## A duel in the Battle Step of turn 2, player 0 attacking, where the DEFENDER (player 1)
## owns `deck1` — the recruit comes from the Magician's own controller's Deck.
static func _battle_duel(seed_value: int, deck1: Array) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1, TestFixtures.filler_deck("A"), deck1)
	TestFixtures.end_turn(d["engine"])
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.BATTLE)
	return d


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("two official clauses: a MANDATORY targeting Summon trigger and an OPTIONAL "
		+ "battle-destruction recruit")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 2, "one EffectDef per official clause")
	t.eq(def.level, 2, "Level 2")
	t.eq(def.race, "Spellcaster", "Spellcaster")

	var counter: EffectDef = def.effects[0]
	t.eq(counter.effect_type, Enums.EffectType.TRIGGER, "clause 1 is a Trigger Effect")
	t.eq(counter.optionality, Enums.Optionality.MANDATORY,
		"there is no 'You can', so clause 1 is MANDATORY and its controller is never asked")
	t.eq(counter.spell_speed, Enums.SpellSpeed.SS1, "a Trigger Effect is Spell Speed 1")
	t.is_true(counter.targets, "'Target 1 face-up card on the field'")
	t.eq(counter.target_count_min, 1, "exactly one target")
	t.eq(counter.target_count_max, 1, "and no more")
	t.is_true(counter.trigger_events.has(GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED),
		"a Normal Summon is a Summon")
	t.is_true(counter.trigger_events.has(GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED),
		"so is a Special Summon")
	t.is_true(counter.trigger_events.has(GameEvent.Kind.FLIP_SUMMON_SUCCEEDED),
		"so is a Flip Summon [S1 p.24]")
	t.eq(counter.damage_step_permission, Enums.DamageStepPermission.NONE,
		"clause 1 has no Damage Step window")

	var recruit: EffectDef = def.effects[1]
	t.eq(recruit.effect_type, Enums.EffectType.TRIGGER, "clause 2 is a Trigger Effect")
	t.eq(recruit.optionality, Enums.Optionality.OPTIONAL,
		"'You can' makes clause 2 optional")
	t.is_false(recruit.targets,
		"clause 2 has no 'target', so the monster is chosen at resolution")
	t.eq(recruit.activation_locations, [Enums.ActivationLocation.GRAVEYARD],
		"clause 2 activates from the Graveyard, where the card already is by sub-step 5")
	t.eq(recruit.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"its window is inside the Damage Step — a timing permission, not optionality "
		+ "(RULES_SPEC.md 7.2)")
	t.is_true(recruit.clause_text.contains("face-down Defense Position"),
		"the clause text is quoted from the verified official text, face-down included")


# ---------------------------------------------------------------------------
# Clause 1 — the Spell Counter
# ---------------------------------------------------------------------------

static func _test_no_card_in_the_pool_can_hold_a_spell_counter(t: TestCase) -> void:
	t.start("NO card in the 77-card V1 pool declares Spell Counter capacity, so clause 1 "
		+ "has no legal target in a real duel — reported, not papered over")
	var cards: Dictionary = _library()["cards"]
	var holders: Array = []
	for card_name in cards.keys():
		var def: CardDef = cards[card_name]
		for entry in def.effects:
			var e: EffectDef = entry
			if e.effect_id == GameState.COUNTER_CAPACITY_EFFECT_ID:
				holders.append(card_name)
	t.eq(holders, [], "no card in the pool grants itself Spell Counter capacity")

	# And the consequence, live: summoning it with a full board of real cards places nothing
	# and the mandatory trigger is simply never activated.
	var d := _main_phase_duel(4401)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _card("Blue-Eyes White Dragon"))
	TestFixtures.give_monster_on_field(engine, 1, _card("Sabersaurus"))
	var mage := TestFixtures.give_to_hand(engine, 0, _def())
	t.is_true(_normal_summon(engine, mage), "the Magician is Normal Summoned")
	t.eq(mage.zone, Enums.Zone.MONSTER_ZONE, "and reaches a Monster Zone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COUNTER_PLACED), 0,
		"no Spell Counter was placed — a Blue-Eyes is NOT a card you can place one on")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_ACTIVATED), 0,
		"and the mandatory clause was never activated, because it had no legal target")


static func _test_a_summon_places_the_counter(t: TestCase) -> void:
	t.start("with a card that CAN hold Spell Counters on the field, a Normal Summon places "
		+ "exactly one, and nobody is asked whether to")
	var d := _main_phase_duel(4402)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var holder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.counter_holder("Spell Counter Tower", SPELL_COUNTER))
	var mage := TestFixtures.give_to_hand(engine, 0, _def())

	t.is_true(engine.state.can_place_counter(holder, SPELL_COUNTER),
		"the rules layer agrees the holder can receive a Spell Counter")
	t.is_false(engine.state.can_place_counter(holder, "Balloon Counter"),
		"and only the kind it declared — capacity is per counter kind")

	var yes_no_before := p0.request_count(Enums.DecisionKind.YES_NO)
	t.is_true(_normal_summon(engine, mage), "the Magician is Normal Summoned")
	t.eq(engine.state.total_counters(holder, SPELL_COUNTER), 1,
		"exactly one Spell Counter is on the holder")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COUNTER_PLACED), 1,
		"exactly one COUNTER_PLACED event")
	t.eq(p0.request_count(Enums.DecisionKind.YES_NO), yes_no_before,
		"a MANDATORY trigger is never offered as a yes/no choice")
	t.eq(p0.errors, [], "and no scripted answer went to the wrong prompt")


static func _test_the_opponents_card_is_a_legal_target(t: TestCase) -> void:
	t.start("'1 face-up card on the FIELD' is either player's field, and the target is "
		+ "chosen from exactly the cards that can receive the counter")
	var d := _main_phase_duel(4403)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.counter_holder("My Tower", SPELL_COUNTER))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.counter_holder("Their Tower", SPELL_COUNTER))
	# A third face-up card that cannot hold one, to prove the filter is doing work.
	var plain := TestFixtures.give_monster_on_field(engine, 1, _card("Sabersaurus"))
	var mage := TestFixtures.give_to_hand(engine, 0, _def())

	p0.queue_for(Enums.DecisionKind.CHOOSE_TARGETS, [theirs.id])
	t.is_true(_normal_summon(engine, mage), "the Magician is Normal Summoned")
	t.eq(p0.errors, [], "the queued answer went to the target prompt")
	t.eq(engine.state.total_counters(theirs, SPELL_COUNTER), 1,
		"the opponent's card received the Spell Counter")
	t.eq(engine.state.total_counters(mine, SPELL_COUNTER), 0,
		"and the controller's own holder did not")
	t.eq(engine.state.total_counters(plain, SPELL_COUNTER), 0,
		"nor did the card with no capacity")

	var offered: Array = []
	for req in p0.seen_requests:
		if req.kind == Enums.DecisionKind.CHOOSE_TARGETS:
			offered = req.options
	t.eq(offered.size(), 2, "exactly the two holders were offered as targets")
	t.is_true(offered.has(mine.id) and offered.has(theirs.id),
		"both sides of the field, and only the cards that can receive a counter")


static func _test_a_face_down_card_is_not_a_legal_target(t: TestCase) -> void:
	t.start("'1 FACE-UP card on the field' excludes a face-down one, and flipping it "
		+ "face-up makes it legal again")
	var d := _main_phase_duel(4404)
	var engine: DuelEngine = d["engine"]
	var holder := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.counter_holder("Hidden Tower", SPELL_COUNTER),
		Enums.Position.FACE_DOWN_DEFENSE)
	t.is_false(engine.state.can_place_counter(holder, SPELL_COUNTER),
		"a face-down card is not a legal recipient")

	var mage := TestFixtures.give_to_hand(engine, 0, _def())
	t.is_true(_normal_summon(engine, mage), "the Magician is still Normal Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COUNTER_PLACED), 0,
		"but no counter was placed and no target existed")

	engine.state.set_battle_position(holder, Enums.Position.FACE_UP_ATTACK, true)
	t.is_true(engine.state.can_place_counter(holder, SPELL_COUNTER),
		"face-up, the same card IS a legal recipient — the negative was not vacuous")


static func _test_the_target_became_illegal_before_resolution(t: TestCase) -> void:
	t.start("a target that left the field between activation and resolution receives "
		+ "nothing, and the clause still resolves (master prompt 44)")
	var d := _main_phase_duel(4405)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var holder := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.counter_holder("Doomed Tower", SPELL_COUNTER))
	# Player 1 holds a Spell Speed 2 answer, so the window between Chain Link 1 and its
	# resolution genuinely opens.
	var bomb := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Remove It", holder, "destroy"), 0)
	var mage := TestFixtures.give_to_hand(engine, 0, _def())

	p0.queue_for(Enums.DecisionKind.CHOOSE_TARGETS, [holder.id])
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SUMMON, mage.id)
	t.not_null(a, "the Normal Summon is offered")
	t.is_true(engine.submit_action(a), "and accepted")

	# The Summon declaration window comes first and nobody wants it; the trigger becomes
	# Chain Link 1 only once that window closes and the Summon completes.
	var response = null
	var guard := 0
	while response == null and guard < 8 and engine.timing != DuelEngine.Timing.OPEN:
		guard += 1
		var pid := engine.waiting_player()
		if pid == -1:
			break
		response = TestFixtures.find_action(engine.get_legal_responses(1),
			Enums.ActionKind.ACTIVATE_CARD, bomb.id)
		if response != null:
			break
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, pid))
	t.not_null(response, "the opponent may chain a Spell Speed 2 Trap to the trigger")
	t.is_true(engine.submit_action(response),
		"destroying the target as Chain Link 2, which resolves first")
	TestFixtures.pass_until_open(engine)

	t.eq(holder.zone, Enums.Zone.GRAVEYARD, "the target was destroyed in response")
	t.eq(engine.state.total_counters(holder, SPELL_COUNTER), 0, "so it holds no counter")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COUNTER_PLACED), 0,
		"and nothing was placed anywhere")
	t.eq(mage.zone, Enums.Zone.MONSTER_ZONE,
		"the Magician itself is unaffected and stays on the field")


static func _test_a_special_summon_triggers_it_and_a_set_does_not(t: TestCase) -> void:
	t.start("'Summoned' covers a Special Summon; a Normal SET is not a Summon [S1 p.24]")
	# Set first: no Summon event, so nothing triggers.
	var d := _main_phase_duel(4406)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.counter_holder("Set Witness", SPELL_COUNTER))
	var mage := TestFixtures.give_to_hand(engine, 0, _def())
	var set_action = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.NORMAL_SET, mage.id)
	t.not_null(set_action, "the Magician may be Set")
	t.is_true(engine.submit_action(set_action), "and the Set is accepted")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.COUNTER_PLACED), 0,
		"a Normal Set placed no Spell Counter — a Set is not a Summon")

	# Special Summon by Monster Reborn from the Graveyard.
	var d2 := _main_phase_duel(4407)
	var engine2: DuelEngine = d2["engine"]
	var holder := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.counter_holder("Reborn Witness", SPELL_COUNTER))
	var mage2 := TestFixtures.give(engine2, 0, _def(), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine2, 0, _card("Monster Reborn"))
	t.is_true(TestFixtures.activate_card(engine2, 0, reborn, [mage2.id]),
		"Monster Reborn revives the Magician")
	t.eq(mage2.zone, Enums.Zone.MONSTER_ZONE, "it is on the field")
	t.eq(engine2.state.total_counters(holder, SPELL_COUNTER), 1,
		"and a Special Summon triggered the clause exactly once")


# ---------------------------------------------------------------------------
# Clause 2 — the face-down Defense Position recruit
# ---------------------------------------------------------------------------

static func _test_recruits_face_down_when_destroyed_by_battle(t: TestCase) -> void:
	t.start("destroyed by battle: Special Summons a Level 2 or lower Spellcaster from the "
		+ "Deck in FACE-DOWN Defense Position, and nobody is asked which position")
	var d := _battle_duel(4408, _deck_of([_card("Crystal Seer"), _card("Sabersaurus")]))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	p1.default_yes = true

	var mage := TestFixtures.give_monster_on_field(engine, 1, _def())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var deck_before := engine.state.player(1).deck.size()

	t.is_true(TestFixtures.attack(engine, attacker, mage), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(mage.zone, Enums.Zone.GRAVEYARD, "the Magician was destroyed by battle")
	t.eq(engine.state.player(1).deck.size(), deck_before - 1, "the Deck lost exactly one card")

	var recruited: CardInstance = null
	for entry in engine.state.player(1).monsters():
		var c: CardInstance = entry
		if c != null:
			recruited = c
	t.not_null(recruited, "a monster arrived from the Deck")
	t.eq(recruited.card_name(), "Crystal Seer",
		"the Level 1 Spellcaster, not the Level 4 Dinosaur")
	t.eq(recruited.position, Enums.Position.FACE_DOWN_DEFENSE,
		"in FACE-DOWN Defense Position, exactly as the card says")
	t.is_true(recruited.is_face_down(), "so it is face-down")
	t.is_true(recruited.properly_special_summoned,
		"it was properly Special Summoned all the same")
	t.eq(recruited.summoned_by, Enums.SummonKind.SPECIAL, "by a Special Summon")
	t.eq(p1.request_count(Enums.DecisionKind.CHOOSE_POSITION), 0,
		"the position is FIXED by the card, so the player is never asked for one")

	# Hidden information: the opponent must not learn what it is. RULES_SPEC.md 9.
	var view := engine.state.get_visible_state(0)
	var leaked := JSON.stringify(view).contains("Crystal Seer")
	t.is_false(leaked, "and the opponent cannot see what was Summoned face-down")


static func _test_declining_summons_nothing(t: TestCase) -> void:
	t.start("'You can' — asked exactly once, and answering no Summons nothing")
	var d := _battle_duel(4409, _deck_of([_card("Crystal Seer")]))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	p1.default_yes = false

	var mage := TestFixtures.give_monster_on_field(engine, 1, _def())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var deck_before := engine.state.player(1).deck.size()

	t.is_true(TestFixtures.attack(engine, attacker, mage), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(p1.request_count(Enums.DecisionKind.YES_NO), 1,
		"the controller was asked exactly once")
	t.eq(engine.state.player(1).deck.size(), deck_before, "the Deck is untouched")
	t.eq(engine.state.player(1).monsters().size(), 0, "and nothing was Summoned")


static func _test_the_recruit_filter(t: TestCase) -> void:
	t.start("'Level 2 or lower Spellcaster' is both halves: a Level 3 Spellcaster and a "
		+ "Level 1 non-Spellcaster are both rejected")
	var d := _battle_duel(4410,
		_deck_of([_card("Aussa the Earth Charmer"),
			TestFixtures.monster("Tiny Warrior", 1, 100, 100)]))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	p1.default_yes = true

	var mage := TestFixtures.give_monster_on_field(engine, 1, _def())
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var deck_before := engine.state.player(1).deck.size()

	t.is_true(TestFixtures.attack(engine, attacker, mage), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(p1.request_count(Enums.DecisionKind.YES_NO), 0,
		"with no legal candidate the controller is never asked")
	t.eq(engine.state.player(1).deck.size(), deck_before, "and the Deck is untouched")
	t.eq(engine.state.player(1).monsters().size(), 0, "nothing was Summoned")

	# Positive control on the same shape: a Level 2 Spellcaster in the Deck enables it.
	var d2 := _battle_duel(4411, _deck_of([_card("Apprentice Magician")]))
	var engine2: DuelEngine = d2["engine"]
	var p1b: ScriptedController = d2["p1"]
	p1b.default_yes = true
	var mage2 := TestFixtures.give_monster_on_field(engine2, 1, _def())
	var attacker2 := TestFixtures.give_monster_on_field(engine2, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	t.is_true(TestFixtures.attack(engine2, attacker2, mage2), "the attack is declared")
	TestFixtures.pass_until_open(engine2)
	t.eq(engine2.state.player(1).monsters().size(), 1,
		"a Level 2 Spellcaster in the Deck IS recruited, so the negative was not vacuous")


static func _test_no_legal_recruit_or_no_room(t: TestCase) -> void:
	t.start("an otherwise full Monster Zone: the zone the Magician itself vacated is the "
		+ "one the recruit legitimately fills")
	var d := _battle_duel(4412, _deck_of([_card("Crystal Seer")]))
	var engine: DuelEngine = d["engine"]
	var p1: ScriptedController = d["p1"]
	p1.default_yes = true

	var mage := TestFixtures.give_monster_on_field(engine, 1, _def(),
		Enums.Position.FACE_UP_ATTACK, 0)
	# Fill the defender's remaining four zones, so nothing but the Magician's own slot is
	# free by the time the trigger resolves.
	for i in range(1, 5):
		TestFixtures.give_monster_on_field(engine, 1,
			TestFixtures.monster("Wall %d" % i, 4, 100, 2500), Enums.Position.FACE_UP_DEFENSE, i)
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Big Attacker", 4, 2000, 1000))
	var deck_before := engine.state.player(1).deck.size()
	t.is_false(engine.state.player(1).has_free_monster_zone(),
		"before the battle the defender's field is genuinely full")

	t.is_true(TestFixtures.attack(engine, attacker, mage), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(mage.zone, Enums.Zone.GRAVEYARD, "the Magician was destroyed by battle")
	t.eq(engine.state.player(1).monsters().size(), 5,
		"five monsters: the four walls plus the recruit")
	t.eq(engine.state.player(1).deck.size(), deck_before - 1,
		"the recruit came out of the Deck")
	var slot = engine.state.player(1).monster_zones[0]
	t.not_null(slot, "the zone the Magician vacated is occupied again")
	t.eq((slot as CardInstance).card_name(), "Crystal Seer",
		"by the recruit — the room is real, not a leftover reference")
	t.eq((slot as CardInstance).position, Enums.Position.FACE_DOWN_DEFENSE,
		"still face-down, on a board where every other zone was taken")


static func _test_destroyed_by_an_effect_does_not_recruit(t: TestCase) -> void:
	t.start("destroyed by a card EFFECT is not 'destroyed by battle', so nobody is asked "
		+ "[S1 p.52-53]")
	var d := _main_phase_duel(4413)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	p0.default_yes = true

	var mage := TestFixtures.give_monster_on_field(engine, 0, _def())
	# The destruction has to travel through the timing machine for a trigger to be checked.
	var bomb := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Blow It Up", mage, "destroy"), 0)
	var deck_before := engine.state.player(0).deck.size()

	t.is_true(TestFixtures.activate_card(engine, 0, bomb), "the interferer resolves")
	t.eq(mage.zone, Enums.Zone.GRAVEYARD, "the Magician is in the Graveyard")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED) > 0, true,
		"it WAS destroyed")
	t.eq(p0.request_count(Enums.DecisionKind.YES_NO), 0,
		"but not by battle, so the optional recruit was never offered")
	t.eq(engine.state.player(0).deck.size(), deck_before, "and the Deck is untouched")

class_name FairyTailRellaTests
extends RefCounted

## Per-card suite for `Fairy Tail - Rella`. Research/CARD_RULINGS.md R23.
##
##   "Neither player can target monsters on the field with Spell Cards or effects, except
##    this one. Once per turn: You can discard 1 Spell; equip 1 Equip Spell from your hand,
##    Deck, or GY to this card, but return that Equip Spell to the hand during the End
##    Phase."
##
## The interesting work is NOT the equipping — `EquipTests` (83) already proves that
## subsystem. It is the continuous targeting restriction, which was previously written down
## in the batch plan as "targeting protection / **redirect**". The verified official text
## contains no redirect at all, so none is implemented, and this suite asserts the actual
## printed behaviour: neither player may target monsters on the field, **except Rella**.
##
## Second honest headline: **the V1 card pool contains no Equip Spells whatsoever**, so
## clause 2 can never be activated in a real duel between these two Decks. That is asserted
## against the real library and the clause is then exercised against synthetic Equip Spells.

const CARD_UNDER_TEST := "Fairy Tail - Rella"

const PROTECT := "no_targeting_except_this_one"
const EQUIP := "equip_an_equip_spell_to_this_card"
const RETURN_IT := "return_the_equip_spell_in_the_end_phase"


static func run() -> TestCase:
	var t := TestCase.new("FairyTailRellaTests")
	_test_clause_shape(t)
	_test_the_pool_has_no_equip_spells(t)
	_test_neither_player_can_target_other_monsters(t)
	_test_rella_itself_stays_targetable(t)
	_test_the_restriction_does_not_reach_off_the_field(t)
	_test_attacks_are_not_targeting(t)
	_test_the_restriction_lifts_with_its_source(t)
	_test_equips_from_the_hand(t)
	_test_equips_from_the_deck_and_the_graveyard(t)
	_test_the_discarded_spell_can_be_the_one_equipped(t)
	_test_the_cost_is_a_discard_and_is_never_refunded(t)
	_test_once_per_turn(t)
	_test_not_activatable_without_a_spell_or_an_equip_spell(t)
	_test_returned_to_the_hand_in_the_end_phase(t)
	_test_the_equip_leaving_early(t)
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
	for entry in _def().effects:
		var e: EffectDef = entry
		if e.effect_id == effect_id:
			return e
	return null


static func _main_phase_duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _deck_of(defs: Array) -> Array:
	var out: Array = []
	var i := 0
	while out.size() < TestFixtures.DECK_SIZE:
		out.append(defs[i % defs.size()])
		i += 1
	return out


## Recompute the continuous layer the way the engine does at every timing point. A board
## arranged directly with `give_*` has not had one yet.
static func _recompute(engine: DuelEngine) -> void:
	ContinuousEffects.new(engine.state).recompute()


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("two printed clauses, three EffectDefs — the delayed End Phase return has its "
		+ "own timing and so must be its own clause")
	var lib := _library()
	t.eq(lib["errors"], [], "the registry reported no load errors")
	var def := _def()
	t.not_null(def, "the definition exists")
	t.eq(def.effects.size(), 3, "protection, the equip effect, and the delayed return")
	t.eq(def.base_atk, 1850, "1850 ATK")
	t.eq(def.race, "Spellcaster", "Spellcaster")

	var protect := _effect(PROTECT)
	t.not_null(protect, "the targeting restriction is a clause")
	t.eq(protect.effect_type, Enums.EffectType.CONTINUOUS,
		"it is continuous — it is never activated")
	t.is_false(protect.starts_chain, "and starts no Chain")
	t.is_true(protect.apply_continuous.is_valid(), "it applies something")
	t.is_false(protect.clause_text.to_lower().contains("instead"),
		"the official text has no REDIRECT — the earlier plan's wording is superseded (R23)")
	t.is_true(protect.clause_text.contains("except this one"),
		"and it does carry the exception, quoted from the official text")

	var equip := _effect(EQUIP)
	t.not_null(equip, "the equip effect is a clause")
	t.eq(equip.effect_type, Enums.EffectType.IGNITION,
		"an Ignition Effect: its controller uses it in an open game state on their turn")
	t.eq(equip.spell_speed, Enums.SpellSpeed.SS1, "so it is Spell Speed 1, never a fast effect")
	t.is_true(equip.once_per_turn_instance,
		"'Once per turn:' with no name clause is a SOFT once per turn on this copy")
	t.is_false(equip.once_per_turn_named_effect,
		"and specifically NOT the hard 'only 1 effect of this card' restriction")
	t.is_false(equip.targets, "there is no 'target', so the Equip Spell is chosen at resolution")
	t.is_true(equip.can_pay_cost.is_valid(), "'discard 1 Spell' is a real cost check")
	t.is_true(equip.pay_cost.is_valid(), "paid at activation")
	t.eq(equip.legal_phases, [Enums.Phase.MAIN_1, Enums.Phase.MAIN_2],
		"an Ignition Effect belongs to the Main Phases [S1 p.10]")

	var ret := _effect(RETURN_IT)
	t.not_null(ret, "the delayed return is a clause")
	t.eq(ret.effect_type, Enums.EffectType.TRIGGER, "it is a Trigger Effect")
	t.eq(ret.optionality, Enums.Optionality.MANDATORY,
		"'but return …' is not optional — nobody is asked")
	t.eq(ret.trigger_events, [GameEvent.Kind.PHASE_CHANGED], "keyed on the phase change")


static func _test_the_pool_has_no_equip_spells(t: TestCase) -> void:
	t.start("the V1 pool contains NO Equip Spells, so clause 2 can never be used in a real "
		+ "duel between these two Decks — reported, not hidden")
	var cards: Dictionary = _library()["cards"]
	var equip_spells: Array = []
	for card_name in cards.keys():
		var def: CardDef = cards[card_name]
		if def.st_kind == Enums.STKind.EQUIP_SPELL:
			equip_spells.append(card_name)
	t.eq(equip_spells, [], "no Equip Spell exists in the 77-card pool")

	# Live consequence: with only real cards available the effect is never offered.
	var d := _main_phase_duel(6601)
	var engine: DuelEngine = d["engine"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP),
		"a Spell in hand is not enough — there is no Equip Spell to fetch")


# ---------------------------------------------------------------------------
# Clause 1 — the targeting restriction
# ---------------------------------------------------------------------------

static func _test_neither_player_can_target_other_monsters(t: TestCase) -> void:
	t.start("'NEITHER player' — the restriction applies to Rella's own controller as well "
		+ "as to the opponent")
	var d := _main_phase_duel(6602)
	var engine: DuelEngine = d["engine"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var mine := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Other Monster", 4, 1000, 1000))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1000, 1000))
	_recompute(engine)

	t.is_true(mine.cannot_be_targeted(), "the controller's own other monster is protected")
	t.is_true(theirs.cannot_be_targeted(), "so is the opponent's")
	t.is_false(rella.cannot_be_targeted(), "and Rella is not — 'except this one'")

	# Live, through a real targeting card: Fiendish Chain targets 1 face-up Effect Monster.
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _card("Fiendish Chain"), 0)
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, chain.id)
	t.not_null(offered, "Fiendish Chain is offered — Rella herself is a legal target")
	t.eq(offered.target_candidates, [rella.id],
		"and Rella is the ONLY candidate: the other face-up Effect Monsters are protected")
	t.is_false(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"a hand-built activation naming a protected monster is rejected")


static func _test_rella_itself_stays_targetable(t: TestCase) -> void:
	t.start("'except this one' is a real exception: Rella can be targeted and the effect "
		+ "resolves against it normally")
	var d := _main_phase_duel(6603)
	var engine: DuelEngine = d["engine"]
	var rella := TestFixtures.give_monster_on_field(engine, 1, _def())
	var chain := TestFixtures.give_set_spell_trap(engine, 0, _card("Fiendish Chain"), 0)
	_recompute(engine)

	t.is_true(TestFixtures.activate_card(engine, 0, chain, [rella.id]),
		"the opponent targets Rella and resolves")
	t.is_true(rella.effects_are_negated(), "Rella's effects are negated by Fiendish Chain")
	_recompute(engine)
	# With Rella negated the protection is gone, which is the continuous system working.
	var other := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Now Exposed", 4, 1000, 1000))
	_recompute(engine)
	t.is_false(other.cannot_be_targeted(),
		"a negated Rella protects nothing — the restriction is her effect")


static func _test_the_restriction_does_not_reach_off_the_field(t: TestCase) -> void:
	t.start("'monsters ON THE FIELD' — a monster in a Graveyard is still a legal target")
	var d := _main_phase_duel(6604)
	var engine: DuelEngine = d["engine"]
	TestFixtures.give_monster_on_field(engine, 0, _def())
	var buried := TestFixtures.give(engine, 0, _card("Sabersaurus"), Enums.Zone.GRAVEYARD)
	var reborn := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	_recompute(engine)

	t.is_false(buried.cannot_be_targeted(), "a monster in the Graveyard is not protected")
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, reborn.id)
	t.not_null(offered, "Monster Reborn is offered")
	t.is_true(offered.target_candidates.has(buried.id),
		"'target 1 monster in either GY' is untouched by a field-only restriction")
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [buried.id]})),
		"and it resolves")
	TestFixtures.pass_until_open(engine)
	t.eq(buried.zone, Enums.Zone.MONSTER_ZONE, "the monster was revived")
	_recompute(engine)
	t.is_true(buried.cannot_be_targeted(),
		"and only NOW, on the field, is it protected")


static func _test_attacks_are_not_targeting(t: TestCase) -> void:
	t.start("an attack is neither a Spell Card nor an effect, so the restriction does not "
		+ "touch attack target selection [S1 p.38]")
	var d := TestFixtures.new_duel(6605, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	TestFixtures.give_monster_on_field(engine, 1, _def())
	var wall := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Protected Wall", 4, 1000, 1000))
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	_recompute(engine)

	t.is_true(wall.cannot_be_targeted(), "the wall cannot be TARGETED by cards")
	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	t.not_null(a, "an attack is still offered")
	t.is_true(a.attack_target_candidates.has(wall.id),
		"and the protected monster is still a legal ATTACK target")
	t.is_true(TestFixtures.attack(engine, attacker, wall), "the attack is declared")
	TestFixtures.pass_until_open(engine)
	t.eq(wall.zone, Enums.Zone.GRAVEYARD, "and it is destroyed by battle as normal")


static func _test_the_restriction_lifts_with_its_source(t: TestCase) -> void:
	t.start("the flag is owned by the continuous system: it survives repeated recomputes "
		+ "and disappears the moment Rella does")
	var d := _main_phase_duel(6606)
	var engine: DuelEngine = d["engine"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var other := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Other", 4, 1000, 1000))
	for i in range(5):
		_recompute(engine)
	t.is_true(other.cannot_be_targeted(), "five recomputes give the same answer as one")

	engine.state.set_battle_position(rella, Enums.Position.FACE_DOWN_DEFENSE, true)
	_recompute(engine)
	t.is_false(other.cannot_be_targeted(), "a face-down Rella applies nothing")

	engine.state.set_battle_position(rella, Enums.Position.FACE_UP_ATTACK, true)
	_recompute(engine)
	t.is_true(other.cannot_be_targeted(), "and it applies again when she is face-up")

	engine.state.move_card(rella, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT)
	_recompute(engine)
	t.is_false(other.cannot_be_targeted(), "with Rella gone the restriction is gone")


# ---------------------------------------------------------------------------
# Clause 2 — the Equip Spell
# ---------------------------------------------------------------------------

static func _test_equips_from_the_hand(t: TestCase) -> void:
	t.start("discard 1 Spell; equip 1 Equip Spell from the hand to this card")
	var d := _main_phase_duel(6607)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var gear := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.equip_spell("Test Gear", 700))

	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [fodder.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, rella, EQUIP),
		"the effect is offered and resolves")
	t.eq(p0.errors, [], "the queued answer went to the discard prompt")

	t.eq(fodder.zone, Enums.Zone.GRAVEYARD, "the cost Spell is in the Graveyard")
	t.eq(fodder.last_move_reason, Enums.MoveReason.DISCARDED,
		"and it was DISCARDED, not 'sent from the hand to the GY' [S1 p.52-53]")
	t.eq(gear.zone, Enums.Zone.SPELL_TRAP_ZONE, "the Equip Spell is in a Spell & Trap Zone")
	t.eq(gear.equipped_to_id, rella.id, "equipped to Rella")
	t.eq(rella.equipped_card_ids, [gear.id], "and Rella knows about it")
	t.eq(rella.current_atk(), 1850 + 700, "its continuous effect applies to Rella")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EQUIPPED), 1,
		"exactly one CARD_EQUIPPED event")


static func _test_equips_from_the_deck_and_the_graveyard(t: TestCase) -> void:
	t.start("'from your hand, DECK, or GY' is three zones, and all three are offered")
	var gear_def := TestFixtures.equip_spell("Deck Gear", 300)
	var d := TestFixtures.new_duel(6608, 0, _deck_of([gear_def]), TestFixtures.filler_deck("B"))
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var buried := TestFixtures.give(engine, 0,
		TestFixtures.equip_spell("GY Gear", 100), Enums.Zone.GRAVEYARD)
	var deck_before := engine.state.player(0).deck.size()

	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [engine.state.player(0).hand[0].id])
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [buried.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, rella, EQUIP), "the effect resolves")
	t.eq(p0.errors, [], "both queued answers matched their prompts")

	var offered: Array = []
	for req in p0.seen_requests:
		if req.kind == Enums.DecisionKind.SELECT_EXACTLY:
			offered = req.options
	t.is_true(offered.size() > 1, "more than one Equip Spell was offered")
	t.is_true(offered.has(buried.id), "the Graveyard copy is a candidate")
	t.eq(buried.zone, Enums.Zone.SPELL_TRAP_ZONE, "the Graveyard copy is the one equipped")
	t.eq(buried.equipped_to_id, rella.id, "and it is attached to Rella")
	t.eq(rella.current_atk(), 1850 + 100, "with its own ATK bonus, not the Deck copy's")
	t.eq(engine.state.player(0).deck.size(), deck_before,
		"nothing left the Deck — a Deck candidate that is not chosen stays there")


static func _test_the_discarded_spell_can_be_the_one_equipped(t: TestCase) -> void:
	t.start("an Equip Spell discarded to pay the cost lands in the GY and is a legal "
		+ "candidate for the effect it paid for")
	var d := _main_phase_duel(6609)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	# The ONLY Spell in hand is the Equip Spell itself.
	var gear := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.equip_spell("Only Gear", 400))

	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP),
		"the effect is offered: there is a Spell to discard and an Equip Spell to fetch")
	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [gear.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, rella, EQUIP), "and it resolves")
	t.eq(p0.errors, [], "the discard prompt got the queued answer")

	t.eq(gear.equipped_to_id, rella.id,
		"the discarded Equip Spell came back out of the Graveyard and equipped")
	t.eq(gear.zone, Enums.Zone.SPELL_TRAP_ZONE, "into a Spell & Trap Zone")
	t.eq(rella.current_atk(), 1850 + 400, "and its bonus applies")


static func _test_the_cost_is_a_discard_and_is_never_refunded(t: TestCase) -> void:
	t.start("the discard happens at ACTIVATION and stays paid when the effect is negated")
	var d := _main_phase_duel(6610)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var gear := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.equip_spell("Test Gear", 700))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.activation_negator("Test Counter"), 0)

	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [fodder.id])
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP)
	t.not_null(offered, "the effect is offered")
	t.is_true(engine.submit_action(offered), "and activated as Chain Link 1")
	t.eq(fodder.zone, Enums.Zone.GRAVEYARD,
		"the cost is ALREADY paid, before any response window opened")

	# The Counter Trap answers a monster's activated EFFECT, not a Spell/Trap card
	# activation, so it correctly finds nothing to negate — which is itself the assertion.
	var counter = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.is_null(counter,
		"'a Spell/Trap Card is activated' does not cover a MONSTER's Ignition Effect")
	TestFixtures.pass_until_open(engine)
	t.eq(gear.equipped_to_id, rella.id, "so the effect resolved and equipped normally")


static func _test_once_per_turn(t: TestCase) -> void:
	t.start("'Once per turn' is a real limit on this copy, and it returns next turn")
	var d := _main_phase_duel(6611)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	TestFixtures.give_to_hand(engine, 0, _card("Dragon Shrine"))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.equip_spell("Gear A", 100))
	TestFixtures.give_to_hand(engine, 0, TestFixtures.equip_spell("Gear B", 200))

	t.is_true(TestFixtures.activate_effect(engine, 0, rella, EQUIP), "the first use resolves")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP),
		"a second use in the same turn is not offered")
	t.eq(p0.errors, [], "and no scripted answer went to the wrong prompt")

	# Round-trip two turns so it is this player's turn again.
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn again")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP),
		"and the once-per-turn use has returned")


static func _test_not_activatable_without_a_spell_or_an_equip_spell(t: TestCase) -> void:
	t.start("both halves are required: a Spell to discard AND an Equip Spell to fetch")
	# No Spell in hand.
	var d := _main_phase_duel(6612)
	var engine: DuelEngine = d["engine"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var gear := TestFixtures.give_to_hand(engine, 0, TestFixtures.equip_spell("Gear", 100))
	# Clear the opening hand of anything that happens to be a Spell.
	for entry in engine.state.player(0).hand.duplicate():
		var c: CardInstance = entry
		if c != gear and c.definition.category == Enums.Category.SPELL:
			engine.state.move_card(c, Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE)
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP),
		"the Equip Spell in hand is itself a Spell, so the cost IS payable")

	# Now remove the Equip Spell too: no Spell at all.
	engine.state.move_card(gear, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella.id, EQUIP),
		"with no Spell in hand and no Equip Spell anywhere, it is not offered")

	# A Spell in hand but no Equip Spell in any of the three zones.
	var d2 := _main_phase_duel(6613)
	var engine2: DuelEngine = d2["engine"]
	var rella2 := TestFixtures.give_monster_on_field(engine2, 0, _def())
	TestFixtures.give_to_hand(engine2, 0, _card("Monster Reborn"))
	t.is_false(TestFixtures.has_action(engine2.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella2.id, EQUIP),
		"a payable cost is not enough when the effect has nothing to fetch")
	TestFixtures.give_to_hand(engine2, 0, TestFixtures.equip_spell("Now Available", 100))
	t.is_true(TestFixtures.has_action(engine2.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella2.id, EQUIP),
		"adding one enables it — the negative was not vacuous")

	# No free Spell & Trap Zone: an Equip Card needs one [S1 p.29].
	var d3 := _main_phase_duel(6614)
	var engine3: DuelEngine = d3["engine"]
	var rella3 := TestFixtures.give_monster_on_field(engine3, 0, _def())
	TestFixtures.give_to_hand(engine3, 0, _card("Monster Reborn"))
	TestFixtures.give_to_hand(engine3, 0, TestFixtures.equip_spell("Gear", 100))
	for i in range(5):
		TestFixtures.give_set_spell_trap(engine3, 0,
			TestFixtures.trap("Filler %d" % i), 0)
	t.is_false(engine3.state.player(0).has_free_spell_trap_zone(),
		"the Spell & Trap Zones are full")
	t.is_false(TestFixtures.has_action(engine3.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, rella3.id, EQUIP),
		"so the effect is not offered — the Equip Card would have nowhere to go")


static func _test_returned_to_the_hand_in_the_end_phase(t: TestCase) -> void:
	t.start("'but return that Equip Spell to the hand during the End Phase' — the same "
		+ "turn, to its OWNER's hand, and nothing else is dragged along")
	var d := _main_phase_duel(6615)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var gear := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.equip_spell("Test Gear", 700))
	# A second Equip Card attached by other means must NOT be returned.
	var other_gear := TestFixtures.give(engine, 0,
		TestFixtures.equip_spell("Other Gear", 200), Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)
	t.is_true(engine.state.equip_to(other_gear, rella), "a second Equip Card is attached")

	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [fodder.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, rella, EQUIP), "Rella equips one")
	t.eq(gear.equipped_to_id, rella.id, "the fetched Equip Spell is attached")
	t.eq(rella.current_atk(), 1850 + 700 + 200, "both Equip Cards apply")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	TestFixtures.pass_until_open(engine)

	t.eq(gear.zone, Enums.Zone.HAND, "the fetched Equip Spell went back to the hand")
	t.eq(gear.controller_id, 0, "its owner's hand")
	t.eq(gear.equipped_to_id, -1, "and it is no longer equipped")
	t.eq(other_gear.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"the other Equip Card is untouched — only the one this effect attached returns")
	t.eq(other_gear.equipped_to_id, rella.id, "and is still attached")
	t.eq(rella.current_atk(), 1850 + 200, "so only the returned card's bonus is gone")

	# And it does not fire again on a later End Phase.
	var returns_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND)
	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND),
		returns_before, "the clause does not fire again on a later End Phase")


static func _test_the_equip_leaving_early(t: TestCase) -> void:
	t.start("if the Equip Spell is already gone by the End Phase the clause does nothing, "
		+ "and Rella leaving the field takes her Equip Cards with her [S1 p.29]")
	var d := _main_phase_duel(6616)
	var engine: DuelEngine = d["engine"]
	var p0: ScriptedController = d["p0"]
	var rella := TestFixtures.give_monster_on_field(engine, 0, _def())
	var fodder := TestFixtures.give_to_hand(engine, 0, _card("Monster Reborn"))
	var gear := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.equip_spell("Test Gear", 700))

	p0.queue_for(Enums.DecisionKind.CHOOSE_DISCARD, [fodder.id])
	t.is_true(TestFixtures.activate_effect(engine, 0, rella, EQUIP), "Rella equips it")
	t.eq(gear.equipped_to_id, rella.id, "attached")

	# Rella is destroyed, which destroys her Equip Cards by the game rules.
	engine.state.destroy(rella, Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.eq(rella.zone, Enums.Zone.GRAVEYARD, "Rella is destroyed")
	t.eq(gear.zone, Enums.Zone.GRAVEYARD,
		"and the Equip Card was destroyed with her, not returned to the hand")
	t.eq(gear.last_move_reason, Enums.MoveReason.DESTROYED_BY_RULE,
		"by the game RULES, not by a card effect [S1 p.29, p.55]")

	var returns_before := TestFixtures.count_events(engine,
		GameEvent.Kind.CARD_RETURNED_TO_HAND)
	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND),
		returns_before,
		"the End Phase clause has no source on the field, so nothing is returned")

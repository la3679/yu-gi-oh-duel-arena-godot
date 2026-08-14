class_name CrystalSeerTests
extends RefCounted

## `Crystal Seer` — "FLIP: Excavate the top 2 cards of your Deck, then add 1 of them to your
## hand, then place the other on the bottom of your Deck."
##
## The first card in the V1 pool to use the excavation layer. The generic behaviour belongs
## to `MovementTests`; this suite proves that THIS card reaches it — that the effect is a
## FLIP effect and fires on all three ways of being turned face-up, that an excavate is
## neither a draw nor a search, that the remaining card keeps `revealed_to` because nothing
## is shuffled, and that a short Deck does not deck the player out.

const CARD_UNDER_TEST := "Crystal Seer"

const EXCAVATE_COUNT := 2


static func run() -> TestCase:
	var t := TestCase.new("CrystalSeerTests")
	_test_the_clause_shape(t)
	_test_the_printed_stats(t)
	_test_a_flip_summon_excavates_two_and_places_one(t)
	_test_the_player_chooses_which_card_goes_to_the_hand(t)
	_test_it_is_not_a_draw(t)
	_test_it_is_not_a_search_and_nothing_is_shuffled(t)
	_test_both_players_see_the_excavated_cards(t)
	_test_it_leaves_nothing_excavated(t)
	_test_a_one_card_deck_excavates_one(t)
	_test_an_empty_deck_does_nothing_and_does_not_deck_out(t)
	_test_it_fires_when_flipped_by_a_card_effect(t)
	_test_it_fires_when_flipped_by_an_attack(t)
	_test_it_does_not_fire_while_face_down(t)
	_test_a_negated_effect_excavates_nothing(t)
	_test_a_negated_flip_summon_does_not_fire_it(t)
	_test_it_uses_its_own_controllers_deck(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _library() -> Dictionary:
	return CardRegistry.new().load_library()


static func _card_def(t: TestCase) -> CardDef:
	var lib := _library()
	t.eq(lib["errors"], [], "the card library loads with no errors")
	var cards: Dictionary = lib["cards"]
	t.is_true(cards.has(CARD_UNDER_TEST), "the registry knows the card")
	return cards[CARD_UNDER_TEST]


## A duel in Main Phase 1 with Crystal Seer Set face-down in player 0's Monster Zone on an
## earlier turn, so it can be Flip Summoned this turn.
static func _board(t: TestCase, seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var seer := TestFixtures.give_monster_on_field(engine, 0, _card_def(t),
		Enums.Position.FACE_DOWN_DEFENSE)
	d["seer"] = seer
	return d


static func _flip_summon(t: TestCase, engine: DuelEngine, seer: CardInstance) -> bool:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, seer.id)
	t.not_null(offered, "the Flip Summon is offered")
	if offered == null:
		return false
	if not engine.submit_action(offered):
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _deck_ids(engine: DuelEngine, pid: int) -> Array:
	var out: Array = []
	for entry in engine.state.player(pid).deck:
		out.append((entry as CardInstance).id)
	return out


static func _bottom_of(engine: DuelEngine, pid: int) -> CardInstance:
	var deck: Array = engine.state.player(pid).deck
	return deck[deck.size() - 1] if not deck.is_empty() else null


## How many `CARD_EXCAVATED` events an excavation of `n` cards produces.
##
## `GameState.excavate()` emits one per card, through `move_card()`, plus one batch event
## describing the whole excavation — the same shape a draw of several cards has. That is
## existing generic behaviour covered by `MovementTests`, not something this card chooses,
## so the arithmetic lives here once instead of being a magic number in six tests.
static func _excavation_events(n: int) -> int:
	return n + 1 if n > 0 else 0


## A Spell Speed 2 Trap that negates the EFFECT of the Chain Link directly below it,
## whatever kind of card that link came from.
##
## `TestFixtures.effect_negator()` deliberately only answers a Spell/Trap CARD activation
## (that is what "a Spell/Trap Card is activated" means), and Crystal Seer's clause is a
## MONSTER effect, so this suite needs its own. Without a real responder the window never
## opens at all: the engine auto-passes and resolves the whole Chain inside one
## `submit_action()`.
static func _monster_effect_negator(card_name: String) -> CardDef:
	var d := TestFixtures.trap(card_name)
	var e := EffectDef.new("negate_link_below", "Test: negate the effect below.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	e.condition = func(ctx: EffectContext) -> bool:
		return not ctx.state.chain.is_empty()
	e.resolve = func(ctx: EffectContext) -> void:
		var own: int = ctx.link.link_number if ctx.link != null else 0
		var below := own - 1
		if below < 1 or ctx.engine == null or ctx.engine.chain == null:
			return
		ctx.engine.chain.negate_effect(below, ctx.source)
	return TestFixtures.with_effect(d, e)


# ---------------------------------------------------------------------------
# Clause enumeration
# ---------------------------------------------------------------------------

static func _test_the_clause_shape(t: TestCase) -> void:
	t.start("one clause: a MANDATORY FLIP effect that keys on being turned face-up, not on "
		+ "being Flip Summoned")
	var def := _card_def(t)
	t.eq(def.effects.size(), 1, "exactly one EffectDef, for the card's one clause")
	var clause: EffectDef = def.effects[0]
	t.eq(clause.effect_type, Enums.EffectType.FLIP, "it is a FLIP effect")
	t.eq(clause.optionality, Enums.Optionality.MANDATORY,
		"it is MANDATORY — the text has no 'You can'")
	t.eq(clause.trigger_events, [GameEvent.Kind.CARD_FLIPPED_FACE_UP],
		"it keys on the FLIP itself, so an attack or a card effect triggers it too")
	t.eq(clause.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"it activates from the field, face-up")
	t.eq(clause.damage_step_permission, Enums.DamageStepPermission.MANDATORY_TRIGGER,
		"a Flip effect triggered by an attacker becomes a Chain Link inside the Damage Step")
	t.is_false(clause.targets, "it does not target — the word does not appear")
	t.is_false(clause.can_pay_cost.is_valid(), "and it has no cost")
	t.is_true(clause.clause_text.contains("Excavate the top 2 cards"),
		"the clause quotes the excavation")
	t.is_true(clause.clause_text.contains("on the bottom of your Deck"),
		"and the BOTTOM placement of the leftover")


static func _test_the_printed_stats(t: TestCase) -> void:
	t.start("the canonical definition matches the official database entry")
	var def := _card_def(t)
	t.eq(def.category, Enums.Category.MONSTER, "it is a monster")
	t.eq(def.attribute, "WATER", "WATER")
	t.eq(def.race, "Spellcaster", "Spellcaster")
	t.eq(def.level, 1, "Level 1")
	t.eq(def.base_atk, 100, "100 ATK")
	t.eq(def.base_def, 100, "100 DEF")
	t.is_false(def.is_normal_monster, "it is an Effect Monster, not a vanilla")


# ---------------------------------------------------------------------------
# Positive behaviour
# ---------------------------------------------------------------------------

static func _test_a_flip_summon_excavates_two_and_places_one(t: TestCase) -> void:
	t.start("a Flip Summon excavates the top 2, adds 1 to the hand and places the other on "
		+ "the BOTTOM of the Deck")
	var d := _board(t, 7801)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var deck_before: int = engine.state.player(0).deck.size()
	var hand_before: int = engine.state.player(0).hand.size()
	var top_two: Array = [engine.state.player(0).deck[0], engine.state.player(0).deck[1]]
	var third: CardInstance = engine.state.player(0).deck[2]

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.is_true(seer.is_face_up(), "and is face-up")
	t.eq(engine.state.player(0).hand.size(), hand_before + 1,
		"exactly one card was added to the hand")
	t.eq(engine.state.player(0).deck.size(), deck_before - 1,
		"and the Deck is exactly one card smaller: 2 left, 1 came back")

	var added: CardInstance = top_two[0] if top_two[0].zone == Enums.Zone.HAND else top_two[1]
	var placed: CardInstance = top_two[1] if top_two[0].zone == Enums.Zone.HAND else top_two[0]
	t.eq(added.zone, Enums.Zone.HAND, "one of the two excavated cards is in the hand")
	t.is_true(engine.state.player(0).hand.has(added), "the controller's own hand")
	t.eq(added.last_move_reason, Enums.MoveReason.ADDED_TO_HAND,
		"as an ADD to the hand, not a draw and not a return")
	t.eq(placed.zone, Enums.Zone.DECK, "the other is back in the Deck")
	t.eq(_bottom_of(engine, 0), placed, "on the BOTTOM of it")
	t.eq(placed.last_move_reason, Enums.MoveReason.RETURNED_TO_DECK_BOTTOM,
		"with the bottom-of-Deck reason")
	t.eq(engine.state.player(0).deck[0], third,
		"and what used to be the third card is now on top")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED),
		_excavation_events(EXCAVATE_COUNT),
		"exactly one excavation happened: one event per card plus the batch event")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_EXCAVATED, added.id), 1,
		"with one per-card excavation event for the card added to hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_EXCAVATED, placed.id), 1,
		"and one for the card placed back")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_ADDED_TO_HAND,
		added.id), 1, "and exactly one add-to-hand event, for that card")


static func _test_the_player_chooses_which_card_goes_to_the_hand(t: TestCase) -> void:
	t.start("'add 1 OF THEM' is a real choice made by the controller at resolution, and it "
		+ "is logged like every other duel input (design decision 17)")
	var d := _board(t, 7802)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var p0: ScriptedController = d["p0"]
	var first: CardInstance = engine.state.player(0).deck[0]
	var second: CardInstance = engine.state.player(0).deck[1]
	# Deliberately choose the SECOND card, which is not what a default "first option"
	# answer would pick.
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [second.id])
	var decisions_before: int = engine.log.decisions.size()

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(p0.errors, [], "the queued answer went to the prompt the test meant")
	t.eq(second.zone, Enums.Zone.HAND, "the CHOSEN card went to the hand")
	t.eq(first.zone, Enums.Zone.DECK, "the other went back to the Deck")
	t.eq(_bottom_of(engine, 0), first, "on the bottom")
	t.is_true(engine.log.decisions.size() > decisions_before,
		"and the choice was recorded in the duel log, so a replay can reproduce it")


static func _test_it_is_not_a_draw(t: TestCase) -> void:
	t.start("an excavate is NOT a draw: no CARD_DRAWN event, and nothing keyed on a draw "
		+ "may fire (RULES_SPEC.md 8.2)")
	var d := _board(t, 7803)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var draws_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN)

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN), draws_before,
		"no card was drawn")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED),
		_excavation_events(EXCAVATE_COUNT), "the cards were EXCAVATED instead")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_ADDED_TO_HAND), 1,
		"and reached the hand as an ADD, which is a third distinct thing")


static func _test_it_is_not_a_search_and_nothing_is_shuffled(t: TestCase) -> void:
	t.start("an excavate is not a search either: the Deck is not shuffled, so the card left "
		+ "on the bottom KEEPS revealed_to (design decision 11)")
	var d := _board(t, 7804)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var order_before := _deck_ids(engine, 0)
	var first: CardInstance = engine.state.player(0).deck[0]
	var second: CardInstance = engine.state.player(0).deck[1]
	var p0: ScriptedController = d["p0"]
	p0.queue_for(Enums.DecisionKind.SELECT_EXACTLY, [first.id])

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(second.zone, Enums.Zone.DECK, "the leftover card is on the Deck")
	t.eq(_bottom_of(engine, 0), second, "on the bottom")
	t.is_true(second.revealed_to.has(0),
		"and both players still legally know it is there: nothing was shuffled")
	t.is_true(second.revealed_to.has(1), "including the opponent")
	# The rest of the Deck is untouched: everything from index 2 onwards kept its order.
	var expected := order_before.slice(2)
	expected.append(second.id)
	t.eq(_deck_ids(engine, 0), expected,
		"the Deck order is exactly 'the rest, then the leftover on the bottom'")


static func _test_both_players_see_the_excavated_cards(t: TestCase) -> void:
	t.start("excavated cards are revealed to BOTH players — that is what separates an "
		+ "excavate from a private look at the top of the Deck")
	var d := _board(t, 7805)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var first: CardInstance = engine.state.player(0).deck[0]
	var second: CardInstance = engine.state.player(0).deck[1]
	t.eq(first.revealed_to.size(), 0, "neither card is known before the flip")
	t.eq(second.revealed_to.size(), 0, "neither of them")

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_REVEALED), EXCAVATE_COUNT,
		"one reveal event per excavated card")
	# The card that went to the hand is now private again in the ordinary way, but the one
	# left on the Deck must still carry the knowledge both players legally gained.
	var placed: CardInstance = second if second.zone == Enums.Zone.DECK else first
	t.eq(placed.revealed_to.size(), 2, "the card left on the Deck is known to both players")


static func _test_it_leaves_nothing_excavated(t: TestCase) -> void:
	t.start("an excavate leaves nothing in limbo: the EXCAVATED zone is empty afterwards")
	var d := _board(t, 7806)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(engine.state.excavated_cards(0).size(), 0,
		"the controller has nothing left excavated")
	t.eq(engine.state.excavated_cards(1).size(), 0, "and neither does the opponent")


# ---------------------------------------------------------------------------
# Short and empty Decks
# ---------------------------------------------------------------------------

static func _test_a_one_card_deck_excavates_one(t: TestCase) -> void:
	t.start("with only 1 card left it excavates 1, adds it to the hand and has nothing to "
		+ "place — and the player does NOT lose")
	var d := _board(t, 7807)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	# Reduce the Deck to a single known card.
	var deck: Array = engine.state.player(0).deck
	var only: CardInstance = deck[0]
	while engine.state.player(0).deck.size() > 1:
		var last := _bottom_of(engine, 0)
		engine.state.move_card(last, Enums.Zone.GRAVEYARD,
			Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(engine.state.player(0).deck.size(), 1, "exactly one card is left in the Deck")
	var hand_before: int = engine.state.player(0).hand.size()

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(only.zone, Enums.Zone.HAND, "the single card was added to the hand")
	t.eq(engine.state.player(0).hand.size(), hand_before + 1, "the hand grew by exactly 1")
	t.eq(engine.state.player(0).deck.size(), 0, "the Deck is now empty")
	t.eq(engine.state.excavated_cards(0).size(), 0, "nothing was left excavated")
	t.is_false(engine.is_duel_over(),
		"and the Duel is NOT over: an excavate is not a draw, so an empty Deck is not a loss")


static func _test_an_empty_deck_does_nothing_and_does_not_deck_out(t: TestCase) -> void:
	t.start("with an empty Deck the effect resolves and does nothing at all — it is a legal "
		+ "resolution of nothing, not a deck-out [S1 p.35 is about drawing]")
	var d := _board(t, 7808)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	while not engine.state.player(0).deck.is_empty():
		engine.state.move_card(engine.state.player(0).deck[0], Enums.Zone.GRAVEYARD,
			Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(engine.state.player(0).deck.size(), 0, "the Deck is empty")
	var hand_before: int = engine.state.player(0).hand.size()

	t.is_true(_flip_summon(t, engine, seer), "the monster is still Flip Summoned")
	t.eq(engine.state.player(0).hand.size(), hand_before, "nothing was added to the hand")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), 0,
		"and no excavation event was emitted at all")
	t.is_false(engine.is_duel_over(), "the Duel is not over")
	t.is_false(engine.state.player(0).has_lost, "and the player has not lost")


# ---------------------------------------------------------------------------
# The three ways of being turned face-up
# ---------------------------------------------------------------------------

static func _test_it_fires_when_flipped_by_a_card_effect(t: TestCase) -> void:
	t.start("a FLIP effect fires when a CARD EFFECT turns the monster face-up, not only on "
		+ "a Flip Summon")
	var d := _board(t, 7809)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var hand_before: int = engine.state.player(0).hand.size()
	# A Spell Speed 2 Trap that flips the Seer face-up, so the flip travels through the
	# timing machine and the trigger can actually be collected.
	var flipper_def := TestFixtures.trap("Flipper")
	var flip := EffectDef.new("flip_it", "Test: turn one named card face-up.")
	flip.of_type(Enums.EffectType.CARD_ACTIVATION)
	flip.with_spell_speed(Enums.SpellSpeed.SS2)
	flip.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	flip.resolve = func(ctx: EffectContext) -> void:
		ctx.state.set_battle_position(seer, Enums.Position.FACE_UP_DEFENSE, true,
			ctx.source.id)
	TestFixtures.with_effect(flipper_def, flip)
	var flipper := TestFixtures.give_set_spell_trap(engine, 0, flipper_def)

	t.is_true(TestFixtures.activate_card(engine, 0, flipper), "the flipper is activated")
	t.is_true(seer.is_face_up(), "the Seer is face-up")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED),
		_excavation_events(EXCAVATE_COUNT),
		"and its FLIP effect fired: an excavation happened")
	t.eq(engine.state.player(0).hand.size(), hand_before + 1,
		"exactly one card reached the hand")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED), 0,
		"with no Flip Summon anywhere in sight")


static func _test_it_fires_when_flipped_by_an_attack(t: TestCase) -> void:
	t.start("a FLIP effect fires when an ATTACK turns the monster face-up, inside the "
		+ "Damage Step (RULES_SPEC.md 7.2)")
	var d := TestFixtures.battle_duel(7810)
	var engine: DuelEngine = d["engine"]
	var seer := TestFixtures.give_monster_on_field(engine, 1, _card_def(t),
		Enums.Position.FACE_DOWN_DEFENSE)
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1800, 1000))
	var hand_before: int = engine.state.player(1).hand.size()

	t.is_true(TestFixtures.attack(engine, attacker, seer), "the attack is declared")
	TestFixtures.pass_until_open(engine)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED),
		_excavation_events(EXCAVATE_COUNT), "the flipped monster's FLIP effect fired")
	t.eq(engine.state.player(1).hand.size(), hand_before + 1,
		"and its CONTROLLER — the defending player — is who added a card to hand")


static func _test_it_does_not_fire_while_face_down(t: TestCase) -> void:
	t.start("the effect does nothing while the card sits face-down, and it fires exactly "
		+ "once when it is finally flipped")
	var d := _board(t, 7811)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	t.is_false(seer.is_face_up(), "the Seer starts face-down")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), 0,
		"nothing has been excavated")

	# Pass a whole turn with the card sitting face-down.
	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), 0,
		"still nothing, a turn later")
	t.is_true(TestFixtures.end_turn(engine), "and back round to the controller")
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.is_true(_flip_summon(t, engine, seer), "now it is Flip Summoned")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED),
		_excavation_events(EXCAVATE_COUNT), "and the effect fired exactly once")


# ---------------------------------------------------------------------------
# Negation
# ---------------------------------------------------------------------------

static func _test_a_negated_effect_excavates_nothing(t: TestCase) -> void:
	t.start("a negated EFFECT excavates nothing and adds nothing — the Deck is untouched")
	var d := _board(t, 7812)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	# The FLIP effect is a MONSTER effect, so the shared Spell/Trap-activation negator does
	# not answer it; this suite carries its own. It must be Set before anything starts,
	# because the engine does not pause when nobody holds a legal response.
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		_monster_effect_negator("Silencer"))
	var deck_before := _deck_ids(engine, 0)
	var hand_before: int = engine.state.player(0).hand.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, seer.id)
	t.not_null(offered, "the Flip Summon is offered")
	t.is_true(engine.submit_action(offered), "it is declared")
	# The negator's condition is "there is a Chain", so it is not offered during the SUMMON
	# declaration window — only once the FLIP effect itself is on the Chain as Chain Link 1.
	t.is_false(engine.state.chain.is_empty(),
		"the mandatory FLIP effect became a Chain Link of its own")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may answer that Chain Link")
	t.is_true(engine.submit_action(response), "they negate its effect")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"the FLIP effect was negated")
	t.eq(negator.zone, Enums.Zone.GRAVEYARD, "their Trap resolved and left the field")
	t.is_true(seer.is_face_up(), "the Flip Summon itself still succeeded")
	t.eq(_deck_ids(engine, 0), deck_before, "the Deck is completely untouched")
	t.eq(engine.state.player(0).hand.size(), hand_before, "nothing was added to the hand")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), 0,
		"and nothing was excavated")
	t.eq(engine.state.excavated_cards(0).size(), 0, "with nothing left in limbo")


static func _test_a_negated_flip_summon_does_not_fire_it(t: TestCase) -> void:
	t.start("a NEGATED Flip Summon leaves the monster face-down, so its FLIP effect never "
		+ "triggers at all")
	var d := _board(t, 7813)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.summon_negator("Denier"))
	var deck_before := _deck_ids(engine, 0)
	var hand_before: int = engine.state.player(0).hand.size()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.FLIP_SUMMON, seer.id)
	t.not_null(offered, "the Flip Summon is offered")
	t.is_true(engine.submit_action(offered), "it is declared")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the opponent may answer the declaration")
	t.is_true(engine.submit_action(response), "the Summon negator is activated")
	TestFixtures.pass_until_open(engine)

	t.is_false(seer.is_face_up(), "the Seer is still face-down [RULES_SPEC.md 5.4]")
	t.eq(seer.zone, Enums.Zone.MONSTER_ZONE, "and still in its Monster Zone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), 0,
		"nothing was excavated")
	t.eq(_deck_ids(engine, 0), deck_before, "the Deck is untouched")
	t.eq(engine.state.player(0).hand.size(), hand_before, "and the hand did not grow")


# ---------------------------------------------------------------------------
# Whose Deck
# ---------------------------------------------------------------------------

static func _test_it_uses_its_own_controllers_deck(t: TestCase) -> void:
	t.start("'YOUR Deck' and 'YOUR hand' are the Seer's controller's, and the opponent's "
		+ "Deck and hand are not touched at all")
	var d := _board(t, 7814)
	var engine: DuelEngine = d["engine"]
	var seer: CardInstance = d["seer"]
	var their_deck_before := _deck_ids(engine, 1)
	var their_hand_before: int = engine.state.player(1).hand.size()

	t.is_true(_flip_summon(t, engine, seer), "the monster is Flip Summoned")
	t.eq(_deck_ids(engine, 1), their_deck_before, "the opponent's Deck is untouched")
	t.eq(engine.state.player(1).hand.size(), their_hand_before,
		"and their hand did not change")
	t.eq(engine.state.excavated_cards(1).size(), 0, "they excavated nothing")

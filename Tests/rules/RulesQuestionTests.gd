class_name RulesQuestionTests
extends RefCounted

## The four questions Phase 4b left open and recorded rather than guessed. Each is now
## decided against an official source and pinned down here so the answer cannot drift.
##
##   1. When a Continuous Spell/Trap's continuous effect begins applying.
##      DECIDED: only once its own activation RESOLVES. [S1 p.17, p.18 with p.46-47]
##   2. Whether `revealed_to` survives a card being shuffled into the Deck.
##      DECIDED: no — but a card placed on top/bottom WITHOUT a shuffle keeps it.
##      [S1 p.5, p.28]
##   3. Player-level continuous restrictions were stored but consumed by no rules path.
##      DECIDED: `TurnFlow.can_enter_battle_phase()` honours the continuous restriction
##      AND the separate turn-scoped one, because they have different lifetimes.
##   4. Piercing battle damage had never executed. It is NOT unexercised after all —
##      `Rider of the Storm Winds` grants it to the V1 pool — so the branch is tested.


static func run() -> TestCase:
	var t := TestCase.new("RulesQuestionTests")
	_test_continuous_effect_waits_for_its_activation_to_resolve(t)
	_test_continuous_effect_applies_once_the_activation_resolved(t)
	_test_shuffling_into_the_deck_clears_revealed_to(t)
	_test_placing_on_the_deck_without_a_shuffle_keeps_revealed_to(t)
	_test_continuous_player_restriction_blocks_the_battle_phase(t)
	_test_turn_scoped_battle_phase_restriction_still_works(t)
	_test_piercing_battle_damage(t)
	_test_no_piercing_without_the_flag(t)
	return t


# ---------------------------------------------------------------------------
# Synthetic cards
# ---------------------------------------------------------------------------

## A Continuous Trap that is ACTIVATED (so it has a Chain Link of its own) and whose
## continuous clause buffs its controller's monsters.
static func _activatable_buff(name: String, atk_up: int) -> CardDef:
	var d := TestFixtures.trap(name, Enums.STKind.CONTINUOUS_TRAP)
	var activation := EffectDef.new("activate", "Activate this card.")
	activation.of_type(Enums.EffectType.CARD_ACTIVATION)
	activation.spell_speed = Enums.SpellSpeed.SS2  # a Trap is Spell Speed 2 [S1 p.44]
	activation.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	activation.resolve = func(_ctx: EffectContext) -> void:
		pass
	TestFixtures.with_effect(d, activation)

	var cont := EffectDef.new("buff", "Monsters you control gain ATK.")
	cont.of_type(Enums.EffectType.CONTINUOUS)
	cont.apply_continuous = func(ctx: EffectContext) -> void:
		for m in ctx.me().monsters():
			ContinuousEffects.add_atk(ctx.source, m, atk_up)
	TestFixtures.with_effect(d, cont)
	return d


## A Quick-Play Spell whose only job is to give its controller something to hold, so a
## response window genuinely opens instead of the engine auto-passing through it.
static func _idle_quick_play(name: String) -> CardDef:
	var d := TestFixtures.spell(name, Enums.STKind.QUICK_PLAY_SPELL)
	var e := EffectDef.new("nothing", "Do nothing.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN,
		Enums.ActivationLocation.FIELD_FACE_UP]
	e.resolve = func(_ctx: EffectContext) -> void:
		pass
	TestFixtures.with_effect(d, e)
	return d


## A continuous source that stops its controller conducting a Battle Phase.
static func _battle_phase_lock(name: String) -> CardDef:
	var d := TestFixtures.spell(name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new("lock", "You cannot conduct your Battle Phase.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		ctx.continuous.restrict_player(ctx.controller_id,
			"cannot_conduct_battle_phase")
	TestFixtures.with_effect(d, e)
	return d


## The `Rider of the Storm Winds` shape: a continuous source that grants piercing.
static func _piercing_granter(name: String) -> CardDef:
	var d := TestFixtures.spell(name, Enums.STKind.CONTINUOUS_SPELL)
	var e := EffectDef.new("piercing",
		"If a monster you control attacks a Defense Position monster, "
		+ "inflict piercing battle damage.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		for m in ctx.me().monsters():
			ContinuousEffects.restrict(m, "piercing")
	TestFixtures.with_effect(d, e)
	return d


# ---------------------------------------------------------------------------
# 1. When a Continuous Spell/Trap's continuous effect starts applying
# ---------------------------------------------------------------------------

static func _test_continuous_effect_waits_for_its_activation_to_resolve(
		t: TestCase) -> void:
	t.start("a Continuous Trap's continuous effect does not apply while its own "
		+ "activation is still an unresolved Chain Link")
	var d := TestFixtures.new_duel(7201, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	var buff := TestFixtures.give_set_spell_trap(engine, 0,
		_activatable_buff("Slow Banner", 500), 0)
	# The opponent holds a fast effect, so the Chain stays open and the state can be
	# observed between activation and resolution.
	TestFixtures.give_set_spell_trap(engine, 1, _idle_quick_play("Held Response"), 0)

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, buff.id))

	t.eq(buff.zone, Enums.Zone.SPELL_TRAP_ZONE,
		"activating the Trap already placed it face-up on the field [S1 p.30]")
	t.is_true(buff.is_face_up(), "and it is face-up")
	t.eq(engine.chain.chain_size(), 1, "its activation is Chain Link 1, still unresolved")
	t.is_true(engine.continuous.activation_unresolved(buff),
		"the engine sees its activation as unresolved")
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1200,
		"so the continuous effect is NOT applying yet: an activation has no effect "
		+ "until its Chain Link resolves [S1 p.46-47]")

	TestFixtures.pass_until_open(engine)
	t.eq(engine.chain.chain_size(), 0, "the Chain has resolved")
	t.is_false(engine.continuous.activation_unresolved(buff),
		"and the activation is no longer pending")
	t.eq(mon.current_atk(), 1700,
		"only now does the continuous effect apply [S1 p.17, p.18]")


static func _test_continuous_effect_applies_once_the_activation_resolved(
		t: TestCase) -> void:
	t.start("the same Continuous Trap keeps applying for as long as it stays face-up")
	var d := TestFixtures.new_duel(7202, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var mon := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Recruit", 4, 1200, 900))
	var buff := TestFixtures.give_set_spell_trap(engine, 0,
		_activatable_buff("Banner", 500), 0)

	engine.submit_action(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, buff.id))
	TestFixtures.pass_until_open(engine)
	t.eq(mon.current_atk(), 1700, "the effect applies after the activation resolved")

	for i in range(3):
		engine.continuous.recompute()
	t.eq(mon.current_atk(), 1700, "repeated recomputes do not stack it")

	engine.state.move_card(buff, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()
	t.eq(mon.current_atk(), 1200,
		"and it stops the moment the card leaves the field")


# ---------------------------------------------------------------------------
# 2. revealed_to and the Deck
# ---------------------------------------------------------------------------

static func _test_shuffling_into_the_deck_clears_revealed_to(t: TestCase) -> void:
	t.start("a revealed card shuffled into the Deck stops being known to anyone")
	var d := TestFixtures.new_duel(7203, 0)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = engine.state.player(0).hand[0]
	card.revealed_to = [1]
	t.is_true(1 in card.revealed_to, "the opponent legally saw it while it was in hand")

	engine.state.move_card(card, Enums.Zone.DECK, Enums.MoveReason.SHUFFLED_INTO_DECK)
	t.eq(card.zone, Enums.Zone.DECK, "it went back to the Deck")
	t.is_true(card.revealed_to.is_empty(),
		"the shuffle ended that knowledge: the Deck is never public information "
		+ "[S1 p.5, p.28]")

	# A shuffle of the whole Deck clears it too, whatever put the card there.
	var other: CardInstance = engine.state.player(0).deck[0]
	other.revealed_to = [1]
	engine.state.shuffle_deck(0)
	t.is_true(other.revealed_to.is_empty(),
		"shuffling the Deck clears revealed_to for every card in it [S1 p.5]")


static func _test_placing_on_the_deck_without_a_shuffle_keeps_revealed_to(
		t: TestCase) -> void:
	t.start("a card placed on top of the Deck without a shuffle keeps what was seen")
	var d := TestFixtures.new_duel(7204, 0)
	var engine: DuelEngine = d["engine"]
	var card: CardInstance = engine.state.player(0).hand[0]
	card.revealed_to = [1]

	engine.state.move_card(card, Enums.Zone.DECK, Enums.MoveReason.RETURNED_TO_DECK_TOP)
	t.eq(card.zone, Enums.Zone.DECK, "it is on the Deck")
	t.is_true(1 in card.revealed_to,
		"its position is still known, so the knowledge is not destroyed — the rule is "
		+ "keyed on the shuffle, not on the Deck")
	t.eq(engine.state.player(0).deck[0], card, "and it really is the top card")


# ---------------------------------------------------------------------------
# 3. Player-level continuous restrictions are consumed by a rules path
# ---------------------------------------------------------------------------

static func _test_continuous_player_restriction_blocks_the_battle_phase(
		t: TestCase) -> void:
	t.start("a continuous player restriction actually prevents the Battle Phase")
	var d := TestFixtures.new_duel(7205, 1)
	var engine: DuelEngine = d["engine"]
	# Player 1 goes first, so player 0 may conduct a Battle Phase from turn 2 [S1 p.37].
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "it is player 0's turn")
	t.is_true(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ENTER_BATTLE_PHASE),
		"the Battle Phase is available before any restriction")

	var lock := TestFixtures.give(engine, 0, _battle_phase_lock("No Battle"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.is_true(engine.continuous.player_restricted(0, "cannot_conduct_battle_phase"),
		"the restriction is stored under the continuous namespace")
	t.is_false(engine.flow.can_enter_battle_phase(0),
		"TurnFlow consumes it — this was the path that used to be missing")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ENTER_BATTLE_PHASE),
		"so the Battle Phase is not offered as a legal action")

	engine.state.move_card(lock, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	engine.continuous.recompute()
	t.is_true(engine.flow.can_enter_battle_phase(0),
		"and the restriction lifts with its source, like every continuous effect")


static func _test_turn_scoped_battle_phase_restriction_still_works(t: TestCase) -> void:
	t.start("the turn-scoped Battle Phase restriction survives a continuous recompute")
	var d := TestFixtures.new_duel(7206, 1)
	var engine: DuelEngine = d["engine"]
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	# The `Runick Flashing Fire` shape: "skip your next Battle Phase after activation".
	# It is written by a resolving effect, not derived from a face-up source, so it must
	# NOT be namespaced and must NOT be wiped by a recompute.
	engine.state.player(0).set_restriction("skip_battle_phase_this_turn", true)
	engine.continuous.recompute()
	t.is_true(bool(engine.state.player(0).get_restriction(
		"skip_battle_phase_this_turn", false)),
		"a recompute leaves the turn-scoped restriction alone")
	t.is_false(engine.flow.can_enter_battle_phase(0),
		"and it blocks the Battle Phase just as the continuous one does")
	t.is_false(engine.continuous.player_restricted(0, "cannot_conduct_battle_phase"),
		"the two are stored separately and neither implies the other")

	TestFixtures.end_turn(engine)
	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 0, "back to player 0")
	t.is_false(bool(engine.state.player(0).get_restriction(
		"skip_battle_phase_this_turn", false)),
		"the turn-scoped restriction expired at the end of the turn")


# ---------------------------------------------------------------------------
# 4. Piercing battle damage — required after all by Rider of the Storm Winds
# ---------------------------------------------------------------------------

static func _test_piercing_battle_damage(t: TestCase) -> void:
	t.start("piercing inflicts ATK minus DEF when a Defense Position monster is destroyed")
	var d := TestFixtures.battle_duel(7207)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Piercer", 4, 1800, 1000))
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wall", 4, 1000, 1200), Enums.Position.FACE_UP_DEFENSE)
	TestFixtures.give(engine, 0, _piercing_granter("Storm Rider-like"),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.is_true(bool(attacker.flags.get("piercing", false)),
		"the continuous source granted the piercing flag")

	var lp_before := engine.state.player(1).life_points
	t.is_true(TestFixtures.attack(engine, attacker, defender), "the attack is declared")
	TestFixtures.pass_until_open(engine)

	t.eq(defender.zone, Enums.Zone.GRAVEYARD,
		"1800 ATK beats 1200 DEF, so the defender is destroyed [S1 p.42]")
	t.eq(engine.state.player(1).life_points, lp_before - 600,
		"and the difference (1800 - 1200) is inflicted as piercing battle damage")
	t.eq(engine.state.player(0).life_points, 8000,
		"the attacking player takes nothing")


static func _test_no_piercing_without_the_flag(t: TestCase) -> void:
	t.start("without piercing, beating a Defense Position monster inflicts no damage")
	var d := TestFixtures.battle_duel(7208)
	var engine: DuelEngine = d["engine"]
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Plain", 4, 1800, 1000))
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Wall", 4, 1000, 1200), Enums.Position.FACE_UP_DEFENSE)
	t.is_false(bool(attacker.flags.get("piercing", false)),
		"no source grants piercing here")

	var lp_before := engine.state.player(1).life_points
	TestFixtures.attack(engine, attacker, defender)
	TestFixtures.pass_until_open(engine)

	t.eq(defender.zone, Enums.Zone.GRAVEYARD, "the defender is still destroyed")
	t.eq(engine.state.player(1).life_points, lp_before,
		"but no battle damage is inflicted — piercing is never the default [S1 p.42]")

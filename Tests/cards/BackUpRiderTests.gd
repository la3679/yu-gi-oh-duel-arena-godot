class_name BackUpRiderTests
extends RefCounted

## Per-card suite for `Back-Up Rider` — "Target 1 face-up monster on the field; it gains
## 1500 ATK until the end of this turn."
##
## The card is small; what has to be proved is that the gain is **authoritative runtime
## state** and not a display value, so the suite asserts it at three levels every time it
## matters:
##
##   * `CardInstance.current_atk()` — the runtime answer;
##   * the printed value is untouched — `base_atk()` / `original_atk()` still read 1800,
##     and the shared `CardDef` is unchanged for every other copy of that card;
##   * the DAMAGE CALCULATION uses it — a battle the boosted monster would have lost is won,
##     with the real `DAMAGE_CALCULATED` payload and the real LP change to prove it.
##
## `CARD_RULINGS.md` R41 Part E (cid 11848) supplies the three facts the English text leaves
## open: the target may be either player's, the gain is not original ATK, and two copies on
## one monster stack to +3000.

const CARD_UNDER_TEST := "Back-Up Rider"
const EFFECT_ID := "target_monster_gains_1500_atk"
const ATK_GAIN := 1500


static func run() -> TestCase:
	var t := TestCase.new("BackUpRiderTests")
	_test_clause_shape(t)
	_test_it_raises_the_authoritative_runtime_atk(t)
	_test_it_does_not_touch_the_printed_value_or_the_shared_definition(t)
	_test_damage_calculation_uses_the_boosted_atk(t)
	_test_it_may_target_the_opponents_monster(t)
	_test_face_down_monsters_are_never_candidates(t)
	_test_only_monsters_on_the_field_are_candidates(t)
	_test_no_face_up_monster_means_no_activation(t)
	_test_it_expires_at_the_end_of_the_turn(t)
	_test_two_copies_stack_to_3000(t)
	_test_it_stacks_with_a_continuous_modifier(t)
	_test_a_target_that_left_the_field_gains_nothing(t)
	_test_a_target_flipped_face_down_gains_nothing(t)
	_test_a_target_whose_control_changed_still_gains(t)
	_test_effect_negation_grants_nothing(t)
	_test_real_pool(t)
	_test_deterministic_replay(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _card(card_name: String) -> CardDef:
	return (CardRegistry.load_library()["cards"] as Dictionary).get(card_name, null)


static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


static func _board(seed_value: int, base_atk: int = 1000) -> Dictionary:
	var d := _duel(seed_value)
	var engine: DuelEngine = d["engine"]
	d["mine"] = TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Monster", 4, base_atk, 1000))
	d["spell"] = TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	engine.continuous.recompute()
	return d


static func _activate_at(engine: DuelEngine, spell: CardInstance,
		target: CardInstance) -> bool:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	if offered == null:
		return false
	if not offered.target_candidates.has(target.id):
		return false
	if not engine.submit_action(offered.with_choices({"target_ids": [target.id]})):
		return false
	TestFixtures.pass_until_open(engine)
	return true


static func _candidates(engine: DuelEngine, spell: CardInstance) -> Array:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	return [] if offered == null else offered.target_candidates


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_clause_shape(t: TestCase) -> void:
	t.start("Back-Up Rider: one clause, a Normal Spell, a target, no cost and no condition")
	var d := _card(CARD_UNDER_TEST)
	t.not_null(d, "the card is in the library")
	if d == null:
		return
	t.eq(d.category, Enums.Category.SPELL, "it is a Spell")
	t.eq(d.st_kind, Enums.STKind.NORMAL_SPELL, "a NORMAL Spell")
	t.eq(d.effects.size(), 1, "exactly one effect clause")
	var e: EffectDef = d.effects[0]
	t.eq(e.effect_id, EFFECT_ID, "the expected effect id")
	t.eq(e.effect_type, Enums.EffectType.CARD_ACTIVATION, "a CARD_ACTIVATION")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "Spell Speed 1")
	t.is_true(e.targets, "it TARGETS")
	t.eq(e.target_count_min, 1, "exactly one target")
	t.eq(e.target_count_max, 1, "and no more than one")
	t.is_false(e.pay_cost.is_valid(), "no cost is paid at activation")
	t.is_false(e.condition.is_valid(),
		"and there is no activation condition — a legal target is the whole requirement")
	t.is_false(e.once_per_turn_instance, "no once-per-turn is printed")
	t.eq(e.ruling_ref, "R41", "it cites the ruling that settled it")


# ---------------------------------------------------------------------------
# The gain is authoritative runtime state
# ---------------------------------------------------------------------------

static func _test_it_raises_the_authoritative_runtime_atk(t: TestCase) -> void:
	t.start("Back-Up Rider: the target's runtime ATK really rises by exactly 1500, and its "
		+ "DEF does not move")
	var d := _board(4501, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	t.eq(mine.current_atk(), 1000, "it starts at 1000 ATK")
	t.eq(mine.current_def(), 1000, "and 1000 DEF")

	t.is_true(_activate_at(engine, d["spell"], mine), "activated and resolved")
	t.eq(mine.current_atk(), 1000 + ATK_GAIN, "its runtime ATK is now 2500")
	t.eq(mine.current_def(), 1000, "and its DEF is untouched — the card says ATK only")
	t.eq(mine.atk_modifiers.size(), 1, "exactly one ATK modifier was added")
	t.eq(str((mine.atk_modifiers[0] as Dictionary).get("until", "")), "end_of_turn",
		"and it carries the turn-scoped duration, not a continuous one")
	t.eq(mine.def_modifiers.size(), 0, "no DEF modifier was added at all")


static func _test_it_does_not_touch_the_printed_value_or_the_shared_definition(
		t: TestCase) -> void:
	t.start("Back-Up Rider: R41 Part E — the gain is NOT the original ATK, and the shared "
		+ "CardDef is untouched, so a second copy of that card is unaffected")
	var d := _duel(4502)
	var engine: DuelEngine = d["engine"]
	# TWO instances of the SAME CardDef, which is what a shared-definition mutation would
	# corrupt. The pool's real Blue-Eyes White Dragon, so this is not a synthetic-only claim.
	var bewd_def := _card("Blue-Eyes White Dragon")
	var first := TestFixtures.give_monster_on_field(engine, 0, bewd_def)
	var second := TestFixtures.give_monster_on_field(engine, 0, bewd_def)
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	engine.continuous.recompute()
	var printed := first.base_atk()
	t.eq(printed, 3000, "Blue-Eyes White Dragon is printed at 3000 ATK")

	t.is_true(_activate_at(engine, spell, first), "activated on the first copy")
	t.eq(first.current_atk(), printed + ATK_GAIN, "its runtime ATK rose")
	# The printed value, by all three of the readers that must not see the gain.
	t.eq(first.base_atk(), printed, "but its base ATK did not")
	t.eq(first.original_atk(), printed, "nor its ORIGINAL ATK — cid 11848 says so outright")
	t.eq(bewd_def.base_atk, printed, "and the shared CardDef was not rewritten")
	# The other copy of the same definition is untouched.
	t.eq(second.current_atk(), printed, "the second copy's runtime ATK is unchanged")
	t.eq(second.atk_modifiers.size(), 0, "and it carries no modifier of its own")


static func _test_damage_calculation_uses_the_boosted_atk(t: TestCase) -> void:
	t.start("Back-Up Rider: the boost is what damage calculation reads — a battle that "
		+ "would have been lost is won, with the real DAMAGE_CALCULATED payload")
	var d := TestFixtures.battle_duel(4503)
	var engine: DuelEngine = d["engine"]
	# 1000 ATK against 2000 ATK: without the boost the attacker dies and its controller
	# takes 1000. With it, 2500 against 2000 destroys the defender for 500.
	var attacker := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Attacker", 4, 1000, 1000))
	var defender := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Defender", 4, 2000, 1000))
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	engine.continuous.recompute()
	var my_lp := engine.state.player(0).life_points
	var their_lp := engine.state.player(1).life_points

	# A Normal Spell is Spell Speed 1, so it is activated in a Main Phase, not mid-battle.
	# `battle_duel()` leaves the duel in the Battle Step, so back out to Main Phase 2.
	t.is_true(TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2),
		"Main Phase 2 is reached")
	t.is_true(_activate_at(engine, spell, attacker), "the attacker is boosted")
	t.eq(attacker.current_atk(), 2500, "its runtime ATK is 2500")

	# Main Phase 2 is after the Battle Phase, so the battle itself has to happen next turn —
	# but the boost expires at the end of THIS turn, which is the point of the next test.
	# Here the battle is driven directly from the boosted state instead.
	engine.state.phase = Enums.Phase.BATTLE
	engine.state.battle_step = Enums.BattleStep.BATTLE
	t.is_true(TestFixtures.attack(engine, attacker, defender), "it attacks the 2000 ATK monster")

	var calcs := TestFixtures.events_of(engine, GameEvent.Kind.DAMAGE_CALCULATED)
	t.eq(calcs.size(), 1, "exactly one damage calculation happened")
	if calcs.is_empty():
		return
	var payload: Dictionary = (calcs[0] as GameEvent).data
	t.eq(int(payload.get("attacker_atk", -1)), 2500,
		"damage calculation used the BOOSTED ATK, not the printed 1000")
	t.is_true((payload.get("destroyed", []) as Array).has(defender.id),
		"the defender was determined destroyed")
	t.is_false((payload.get("destroyed", []) as Array).has(attacker.id),
		"and the attacker was not")
	t.eq(int(payload.get("damage_to", -1)), 1, "the damage went to the opponent")
	t.eq(int(payload.get("damage", -1)), 500, "and it was 2500 - 2000 = 500")
	t.eq(engine.state.player(1).life_points, their_lp - 500, "their LP fell by 500")
	t.eq(engine.state.player(0).life_points, my_lp, "and yours did not move at all")


# ---------------------------------------------------------------------------
# The candidate list
# ---------------------------------------------------------------------------

static func _test_it_may_target_the_opponents_monster(t: TestCase) -> void:
	t.start("Back-Up Rider: R41 Part E — 'on the field' is either player's, so the "
		+ "opponent's monster is a legal target and really is boosted")
	var d := _board(4504)
	var engine: DuelEngine = d["engine"]
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster", 4, 1200, 1000))
	engine.continuous.recompute()

	var candidates := _candidates(engine, d["spell"])
	t.is_true(candidates.has(d["mine"].id), "your own monster is a candidate")
	t.is_true(candidates.has(theirs.id), "and so is the opponent's")
	t.eq(candidates.size(), 2, "exactly the two face-up monsters on the field")

	t.is_true(_activate_at(engine, d["spell"], theirs), "the opponent's monster is targeted")
	t.eq(theirs.current_atk(), 1200 + ATK_GAIN, "and really gains 1500 ATK")
	t.eq((d["mine"] as CardInstance).current_atk(), 1000, "yours is untouched")


static func _test_face_down_monsters_are_never_candidates(t: TestCase) -> void:
	t.start("Back-Up Rider: a face-DOWN monster is not a candidate, on either side")
	var d := _board(4505)
	var engine: DuelEngine = d["engine"]
	var my_hidden := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("My Hidden", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	var their_hidden := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Hidden", 4, 1000, 1000), Enums.Position.FACE_DOWN_DEFENSE)
	engine.continuous.recompute()

	var candidates := _candidates(engine, d["spell"])
	t.is_true(my_hidden.is_face_down(), "your face-down monster really is face-down")
	t.is_false(candidates.has(my_hidden.id), "and is not a candidate")
	t.is_false(candidates.has(their_hidden.id), "nor is theirs")
	t.eq(candidates.size(), 1, "only the one face-up monster is")

	engine.state.set_battle_position(my_hidden, Enums.Position.FACE_UP_ATTACK, true)
	t.is_true(_candidates(engine, d["spell"]).has(my_hidden.id),
		"flipping it face-up is what makes it a candidate")


static func _test_only_monsters_on_the_field_are_candidates(t: TestCase) -> void:
	t.start("Back-Up Rider: 'on the field' is the Monster Zones — not a Spell/Trap, not a "
		+ "monster in a hand, a Deck or a Graveyard")
	var d := _board(4506)
	var engine: DuelEngine = d["engine"]
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1, TestFixtures.trap("Theirs"))
	var in_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("Held", 4, 1000, 1000))
	var in_gy := TestFixtures.give(engine, 0, TestFixtures.monster("Dead", 4, 1000, 1000),
		Enums.Zone.GRAVEYARD)
	var field_spell := TestFixtures.give(engine, 1,
		TestFixtures.spell("Their Field Spell", Enums.STKind.FIELD_SPELL),
		Enums.Zone.FIELD_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()

	var candidates := _candidates(engine, d["spell"])
	t.is_true(candidates.has(d["mine"].id), "the face-up monster is a candidate")
	t.is_false(candidates.has(their_trap.id), "a Set Spell/Trap is not")
	t.is_false(candidates.has(field_spell.id), "nor is a face-up Field Spell")
	t.is_false(candidates.has(in_hand.id), "nor is a monster in a hand")
	t.is_false(candidates.has(in_gy.id), "nor one in a Graveyard")
	t.eq(candidates.size(), 1, "exactly one candidate on this board")


static func _test_no_face_up_monster_means_no_activation(t: TestCase) -> void:
	t.start("Back-Up Rider: with no face-up monster anywhere it is not offered")
	var d := _duel(4507)
	var engine: DuelEngine = d["engine"]
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id), "an empty field means no activation")

	var appeared := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Theirs", 4, 1000, 1000))
	engine.continuous.recompute()
	t.is_true(_candidates(engine, spell).has(appeared.id),
		"one face-up monster — even the opponent's — is enough")


# ---------------------------------------------------------------------------
# Duration and stacking
# ---------------------------------------------------------------------------

static func _test_it_expires_at_the_end_of_the_turn(t: TestCase) -> void:
	t.start("Back-Up Rider: the gain lasts exactly this turn and then goes away by itself")
	var d := _board(4508, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	t.is_true(_activate_at(engine, d["spell"], mine), "activated and resolved")
	t.eq(mine.current_atk(), 2500, "boosted this turn")

	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	t.eq(mine.current_atk(), 1000, "and the ATK is back to its printed value")
	t.eq(mine.atk_modifiers.size(), 0, "the modifier was removed, not merely ignored")


static func _test_two_copies_stack_to_3000(t: TestCase) -> void:
	t.start("Back-Up Rider: R41 Part E — two copies targeting the same monster in the same "
		+ "turn stack to +3000, which proves the modifier ADDS rather than sets")
	var d := _board(4509, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	var second := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))

	t.is_true(_activate_at(engine, d["spell"], mine), "the first copy resolves")
	t.eq(mine.current_atk(), 2500, "+1500")
	t.is_true(_activate_at(engine, second, mine), "the second copy resolves on the same one")
	t.eq(mine.current_atk(), 4000, "+3000 in total — cid 11848 says exactly this")
	t.eq(mine.atk_modifiers.size(), 2, "two separate modifiers, not one overwritten")
	# Both expire together.
	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	t.eq(mine.current_atk(), 1000, "and both are gone")


static func _test_it_stacks_with_a_continuous_modifier(t: TestCase) -> void:
	t.start("Back-Up Rider: it adds to a CONTINUOUS modifier rather than replacing it, and "
		+ "removing the continuous source leaves this gain in place")
	var d := _board(4510, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	# A face-up Continuous Spell that gives every monster its controller has +800 ATK.
	var buff_def := TestFixtures.spell("Team Buff", Enums.STKind.CONTINUOUS_SPELL)
	var buff_effect := EffectDef.new("team_buff", "Test: your monsters gain 800 ATK.")
	buff_effect.of_type(Enums.EffectType.CONTINUOUS)
	buff_effect.apply_continuous = func(ctx: EffectContext) -> void:
		for entry in ctx.me().face_up_monsters():
			ContinuousEffects.add_atk(ctx.source, entry as CardInstance, 800)
	var buff := TestFixtures.give(engine, 0, TestFixtures.with_effect(buff_def, buff_effect),
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)
	engine.continuous.recompute()
	t.eq(mine.current_atk(), 1800, "the continuous modifier alone gives 1800")

	t.is_true(_activate_at(engine, d["spell"], mine), "activated and resolved")
	t.eq(mine.current_atk(), 3300, "1000 + 800 + 1500 — the two modifiers add up")

	# Removing the continuous source drops only its own share.
	t.is_true(engine.state.destroy(buff, Enums.MoveReason.DESTROYED_BY_EFFECT, -1),
		"the Continuous Spell is destroyed")
	engine.continuous.recompute()
	t.eq(mine.current_atk(), 2500,
		"only the continuous 800 went away; this card's 1500 is not tied to any source")


# ---------------------------------------------------------------------------
# Every route by which the target can stop being legal
# ---------------------------------------------------------------------------

## Activate against `target` as Chain Link 1, let `responder` interfere as Chain Link 2,
## then resolve. Returns false when either step could not be driven.
static func _activate_then_interfere(t: TestCase, engine: DuelEngine, spell: CardInstance,
		target: CardInstance, responder: CardInstance) -> bool:
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return false
	if not engine.submit_action(offered.with_choices({"target_ids": [target.id]})):
		t.check(false, "it is activated as Chain Link 1")
		return false
	var response = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, responder.id)
	t.not_null(response, "a response window is open")
	if response == null:
		return false
	t.is_true(engine.submit_action(response), "the responder is Chain Link 2")
	TestFixtures.pass_until_open(engine)
	return true


static func _test_a_target_that_left_the_field_gains_nothing(t: TestCase) -> void:
	t.start("Back-Up Rider: a target removed in response gains nothing, and nothing else "
		+ "is boosted in its place")
	var d := _board(4511, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	var bystander := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Bystander", 4, 1000, 1000))
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", mine, "bounce"))
	engine.continuous.recompute()

	if not _activate_then_interfere(t, engine, d["spell"], mine, responder):
		return
	t.eq(mine.zone, Enums.Zone.HAND, "the target left the field before resolution")
	t.eq(mine.atk_modifiers.size(), 0, "it carries no modifier")
	t.eq(bystander.current_atk(), 1000, "and no other monster was boosted instead")
	t.eq(bystander.atk_modifiers.size(), 0, "nor does one carry a modifier")


static func _test_a_target_flipped_face_down_gains_nothing(t: TestCase) -> void:
	t.start("Back-Up Rider: a target flipped FACE-DOWN in response gains nothing, even "
		+ "though it never left its Monster Zone")
	var d := _board(4512, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.interferer("Watcher", mine, "flip_face_down"))
	engine.continuous.recompute()

	if not _activate_then_interfere(t, engine, d["spell"], mine, responder):
		return
	# The prerequisite for the claim: it is still there, but no longer face-up.
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "it never left its Monster Zone")
	t.is_true(mine.is_face_down(), "but it is face-down now")
	t.eq(mine.atk_modifiers.size(), 0, "and it gained nothing")
	t.eq(mine.current_atk(), 1000, "its ATK is unchanged")


static func _test_a_target_whose_control_changed_still_gains(t: TestCase) -> void:
	t.start("Back-Up Rider: control is NOT part of what made the target legal — the clause "
		+ "says 'on the field', so a target that changed hands is still boosted")
	var d := _board(4513, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	# A responder that hands the target to the opponent mid-Chain.
	var thief_def := TestFixtures.trap("Thief")
	var thief_effect := EffectDef.new("steal", "Test: take control of that monster.")
	thief_effect.of_type(Enums.EffectType.CARD_ACTIVATION)
	thief_effect.with_spell_speed(Enums.SpellSpeed.SS2)
	thief_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	thief_effect.resolve = func(ctx: EffectContext) -> void:
		ctx.state.change_control(mine, 1, ctx.source.id, Enums.ControlDuration.PERMANENT)
	var responder := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.with_effect(thief_def, thief_effect))
	engine.continuous.recompute()

	if not _activate_then_interfere(t, engine, d["spell"], mine, responder):
		return
	t.eq(mine.controller_id, 1, "the target really changed hands")
	t.eq(mine.zone, Enums.Zone.MONSTER_ZONE, "and is still a face-up monster on the field")
	t.is_true(mine.is_face_up(), "still face-up")
	t.eq(mine.current_atk(), 1000 + ATK_GAIN,
		"so it is boosted anyway — the clause names no controller")


static func _test_effect_negation_grants_nothing(t: TestCase) -> void:
	t.start("Back-Up Rider: a negated EFFECT grants no ATK at all")
	var d := _board(4514, 1000)
	var engine: DuelEngine = d["engine"]
	var mine: CardInstance = d["mine"]
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.effect_negator("Effect Negator"))
	engine.continuous.recompute()

	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, d["spell"].id)
	t.not_null(offered, "the activation is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered.with_choices({"target_ids": [mine.id]})),
		"activated as Chain Link 1")
	var response = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(response, "the negator can respond")
	if response == null:
		return
	t.is_true(engine.submit_action(response), "it becomes Chain Link 2")
	TestFixtures.pass_until_open(engine)

	t.eq(negator.zone, Enums.Zone.GRAVEYARD, "the negator resolved")
	t.eq(mine.current_atk(), 1000, "the target's ATK never moved")
	t.eq(mine.atk_modifiers.size(), 0, "and no modifier was added")


# ---------------------------------------------------------------------------
# The real pool, and determinism
# ---------------------------------------------------------------------------

static func _test_real_pool(t: TestCase) -> void:
	t.start("Back-Up Rider: it is in deck 1, and boosting the deck's own Blue-Eyes White "
		+ "Dragon really produces 4500 authoritative ATK")
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	t.not_null(f, "the card database is readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary and parsed.has("cards")):
		t.check(false, "the card database parses")
		return
	var decks: Array = []
	for entry in parsed["cards"]:
		if str(entry.get("name", "")) == CARD_UNDER_TEST:
			decks = entry.get("decks", [])
	t.is_true(decks.has("Blue-Eyes Dragon Guard"), "it is in deck 1")

	var d := _duel(4515)
	var engine: DuelEngine = d["engine"]
	var bewd := TestFixtures.give_monster_on_field(engine, 0, _card("Blue-Eyes White Dragon"))
	var spell := TestFixtures.give_to_hand(engine, 0, _card(CARD_UNDER_TEST))
	engine.continuous.recompute()
	t.is_true(_activate_at(engine, spell, bewd), "activated on the real Blue-Eyes")
	t.eq(bewd.current_atk(), 4500, "3000 + 1500 = 4500")
	t.eq(bewd.original_atk(), 3000, "while its original ATK is still 3000")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("Back-Up Rider: the same seed and the same actions produce the same result")
	var results: Array = []
	for _i in range(2):
		var d := _board(4516, 1000)
		var engine: DuelEngine = d["engine"]
		var mine: CardInstance = d["mine"]
		_activate_at(engine, d["spell"], mine)
		results.append({
			"atk": mine.current_atk(),
			"mods": mine.atk_modifiers.size(),
			"events": engine.state.events.size(),
		})
	t.eq(results[0]["atk"], 2500, "the boost really applied in both runs")
	t.eq(results[1]["atk"], results[0]["atk"], "the ATK matches")
	t.eq(results[1]["mods"], results[0]["mods"], "the modifier count matches")
	t.eq(results[1]["events"], results[0]["events"], "and the whole event stream matches")

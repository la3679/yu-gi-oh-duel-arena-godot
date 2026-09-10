class_name HiddenSpringsOfTheFarEastTests
extends RefCounted

## Per-card suite for `Hidden Springs of the Far East`. Research/CARD_RULINGS.md **R14**.
##
##   "Once per turn, during the Main Phase 2: The turn player can activate this effect;
##    they gain 500 LP, and until the end of this turn apply these effects.
##    ●The Normal and Special Summons of their monsters cannot be negated.
##    ●If they activate a Spell/Trap Card, or monster effect, that includes an effect that
##     Special Summons a monster, that activation cannot be negated.
##    ●Their opponent cannot target Set Spells/Traps they control with card effects, also
##     they cannot be destroyed by their opponent's card effects.
##    You can only activate 1 "Hidden Springs of the Far East" per turn."
##
## The generic half — what the three protections mean, every narrowing they carry, and the
## paired controls proving each one is observable at all — is proved by
## `NegationImmunityTests`, which was written and green before this card existed. What is
## specific to this card, and what this suite is about, is:
##
##   * **the headline of R14 Part A**: the effect is activated by the **TURN PLAYER**, and
##     that may be the **opponent of this card's controller** — who then gets the LP and all
##     three protections. Asserted from the opponent's side, which is the only way to tell
##     this apart from an ordinary controller-activated effect;
##   * that 「自分」 throughout the clause means **the player who activated it**, never the
##     player who controls the Field Spell. The LP and each protection are checked against
##     the activator;
##   * that the two once-per-turn clauses are **different restrictions**: a hard one on
##     activating the CARD, and a per-player one on the EFFECT, so each player gets a use
##     and neither can consume the other's;
##   * that it **creates a Chain Block** and can therefore be responded to and negated —
##     and that its own second bullet does **not** protect it, because ① includes no
##     Special Summon;
##   * that the protections are 「このターン中」 and are gone on the next turn, so the card
##     sitting on the field grants nothing by itself;
##   * **the cross-card interaction with `Fairy Tail - Sleeper`**, which is the reason unit B
##     came second: Hidden Springs protects an activation from being **negated**, and
##     Sleeper does not negate — it **substitutes**. So Sleeper still works through the
##     protection, and that is asserted next to a control showing a real activation
##     negation IS stopped on the same board.
##
## **This card has NO official Q&A entries**, so the supplement is the entire authority.
## Where a reading is an inference rather than a statement — the Flip Summon omission, and
## "includes a Special Summon" being judged on the printed text — the test says so.

const CARD_UNDER_TEST := "Hidden Springs of the Far East"
const EFFECT_ACTIVATE := "activate_hidden_springs"
const EFFECT_MAIN := "turn_player_gains_lp_and_protections"
const LP_GAIN := 500


static func run() -> TestCase:
	var t := TestCase.new("HiddenSpringsOfTheFarEastTests")
	# Identity and declaration
	_test_the_card_is_registered_and_declared_correctly(t)
	_test_it_is_the_pools_only_field_spell(t)
	# The card activation
	_test_activating_it_puts_it_in_the_field_zone(t)
	_test_only_one_may_be_activated_per_turn(t)
	# The effect — when, and by whom
	_test_the_effect_is_main_phase_2_only(t)
	_test_the_controller_may_activate_it_in_their_main_phase_2(t)
	_test_the_OPPONENT_of_the_controller_may_activate_it(t)
	_test_each_player_gets_their_own_use_per_turn(t)
	_test_an_ORDINARY_effect_on_a_foreign_card_is_NOT_offered(t)
	_test_the_first_player_has_no_main_phase_2_on_turn_1(t)
	# The effect — what it does, and to whom
	_test_the_lp_and_protections_go_to_the_ACTIVATOR(t)
	_test_the_protections_are_gone_next_turn(t)
	# The effect — its own vulnerability
	_test_it_creates_a_chain_block_and_can_be_negated(t)
	_test_it_does_not_protect_its_own_activation(t)
	_test_the_card_itself_is_not_protected_because_it_is_face_up(t)
	# The cross-card interaction that needed both units
	_test_it_does_not_stop_fairy_tail_sleeper(t)
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


## Player 0, Main Phase 1 of **turn 2**.
##
## Turn 2 rather than turn 1, and player 1 goes first, both on purpose. "The player who
## goes first cannot conduct a Battle Phase on their first turn" [S1 p.37] — and **Main
## Phase 2 is only reachable through the Battle Phase**, so on turn 1 the first player has
## no Main Phase 2 at all and this card's only effect could never be activated. That is a
## real rules fact about the card, not a quirk of the harness, and it is asserted in its
## own test rather than merely worked around here.
static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 1)
	TestFixtures.end_turn(d["engine"])
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## The card face-up in `pid`'s Field Zone, placed rather than activated so the hard
## once-per-turn is untouched and a test can measure the EFFECT on its own.
static func _springs_on_field(engine: DuelEngine, pid: int) -> CardInstance:
	return TestFixtures.give(engine, pid, _def(), Enums.Zone.FIELD_ZONE,
		Enums.Position.FACE_UP)


static func _activate_the_effect(engine: DuelEngine, pid: int,
		card: CardInstance) -> bool:
	return TestFixtures.activate_effect(engine, pid, card, EFFECT_MAIN)


## Advance to Main Phase 2 of the CURRENT turn.
##
## Main Phase 2 is reached only THROUGH the Battle Phase — `TurnFlow` goes
## MAIN_1 -> BATTLE -> MAIN_2, and ending Main Phase 1 without entering the Battle Phase
## goes straight to the End Phase. So this enters the Battle Phase and then ends it;
## `advance_to_phase(MAIN_2)` alone cannot get there from Main Phase 1.
static func _to_main_2(engine: DuelEngine) -> bool:
	if engine.state.phase == Enums.Phase.MAIN_2:
		return true
	if not TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE):
		return false
	return TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_2)


## End the current turn and advance the new turn player to their Main Phase 2.
static func _to_opponents_main_2(engine: DuelEngine) -> bool:
	if not TestFixtures.end_turn(engine):
		return false
	return _to_main_2(engine)



## Deck membership, read from the card database. `CardDef` does not carry it.
static func _decks_of(card_name: String) -> Array:
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary and parsed.has("cards")):
		return []
	for entry in parsed["cards"]:
		if str(entry.get("name", "")) == card_name:
			return entry.get("decks", [])
	return []

# ---------------------------------------------------------------------------
# Identity and declaration
# ---------------------------------------------------------------------------

static func _test_the_card_is_registered_and_declared_correctly(t: TestCase) -> void:
	t.start("the card is registered and both clauses are declared as the supplement says")
	var d := _def()
	t.not_null(d, "`Hidden Springs of the Far East` is in the registry")
	if d == null:
		return
	t.eq(d.category, Enums.Category.SPELL, "it is a Spell")
	t.eq(d.st_kind, Enums.STKind.FIELD_SPELL, "and specifically a Field Spell")
	t.eq(d.effects.size(), 2, "two effect clauses: the card activation and clause 1")

	var act := _effect(EFFECT_ACTIVATE)
	t.not_null(act, "the card activation is declared")
	if act != null:
		t.eq(act.effect_type, Enums.EffectType.CARD_ACTIVATION,
			"it is a CARD_ACTIVATION")
		t.is_true(act.once_per_turn_named_activation,
			"\"You can only activate 1 ... per turn\" is the HARD named-activation "
			+ "once-per-turn")

	var e := _effect(EFFECT_MAIN)
	t.not_null(e, "clause 1 is declared")
	if e == null:
		return
	t.eq(e.effect_type, Enums.EffectType.IGNITION, "clause 1 is an Ignition Effect")
	t.is_true(e.activated_by_turn_player,
		"and it is activated by the TURN PLAYER rather than by the controller — "
		+ "「お互いのプレイヤーは、自身のメインフェイズ２にこの効果を発動できます。」")
	t.eq(e.legal_phases, [Enums.Phase.MAIN_2], "Main Phase 2 and no other phase")
	t.is_true(e.once_per_turn_named_effect,
		"「お互いのプレイヤーは１ターンに１度」 is the per-PLAYER once-per-turn on the effect")
	t.is_false(e.once_per_turn_instance,
		"and not the per-instance shape, which would give the two players one use between "
		+ "them instead of one each")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"no Damage Step permission — an Ignition Effect in Main Phase 2 never needs one, "
		+ "and the default is asserted rather than assumed")
	t.is_false(e.includes_special_summon,
		"clause 1 does NOT include a Special Summon, which is why its own second bullet "
		+ "cannot protect its own activation")
	t.is_true(e.starts_chain,
		"「フィールドで発動できるチェーンブロックの作られる効果です。」 — it starts a Chain")


static func _test_it_is_the_pools_only_field_spell(t: TestCase) -> void:
	t.start("it is the V1 pool's only Field Spell")
	var cards: Dictionary = _library()["cards"]
	var found: Array = []
	for name in cards.keys():
		var d: CardDef = cards[name]
		if d.st_kind == Enums.STKind.FIELD_SPELL:
			found.append(name)
	t.eq(found, [CARD_UNDER_TEST],
		"exactly one Field Spell in the pool — so the Field Zone behaviour this card "
		+ "depends on has no second card to keep it honest, and is asserted here")


# ---------------------------------------------------------------------------
# The card activation
# ---------------------------------------------------------------------------

static func _test_activating_it_puts_it_in_the_field_zone(t: TestCase) -> void:
	t.start("activating the card puts it face-up in the FIELD Zone")
	var d := _duel(6001)
	var engine: DuelEngine = d["engine"]
	var card := TestFixtures.give_to_hand(engine, 0, _def())
	t.is_true(TestFixtures.activate_card(engine, 0, card),
		"the Field Spell is activated from the hand")
	t.eq(card.zone, Enums.Zone.FIELD_ZONE, "it is in the Field Zone")
	t.is_true(card.is_face_up(), "and face-up")
	t.eq(engine.state.player(0).field_zone, card,
		"and it is the player's Field Zone card")


static func _test_only_one_may_be_activated_per_turn(t: TestCase) -> void:
	t.start("\"You can only activate 1 ... per turn\" — a HARD once-per-turn")
	var d := _duel(6002)
	var engine: DuelEngine = d["engine"]
	var first := TestFixtures.give_to_hand(engine, 0, _def())
	var second := TestFixtures.give_to_hand(engine, 0, _def())
	t.is_true(TestFixtures.activate_card(engine, 0, first),
		"the first copy is activated")
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, second.id),
		"a second copy may not be activated in the same turn")


# ---------------------------------------------------------------------------
# The effect — when, and by whom. R14 Part A.
# ---------------------------------------------------------------------------

static func _test_the_effect_is_main_phase_2_only(t: TestCase) -> void:
	t.start("clause 1 is Main Phase 2 only — not Main Phase 1")
	var d := _duel(6010)
	var engine: DuelEngine = d["engine"]
	var springs := _springs_on_field(engine, 0)
	t.eq(engine.state.phase, Enums.Phase.MAIN_1, "the duel is in Main Phase 1")
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN),
		"clause 1 is NOT offered in Main Phase 1")

	t.is_true(_to_main_2(engine), "the duel reaches Main Phase 2")
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN),
		"CONTROL: and it IS offered there — so the refusal above is about the phase")


static func _test_the_controller_may_activate_it_in_their_main_phase_2(
		t: TestCase) -> void:
	t.start("the controller may activate clause 1 in their own Main Phase 2")
	var d := _duel(6011)
	var engine: DuelEngine = d["engine"]
	var springs := _springs_on_field(engine, 0)
	var before := engine.state.player(0).life_points
	t.is_true(_to_main_2(engine), "Main Phase 2")
	t.is_true(_activate_the_effect(engine, 0, springs), "clause 1 is activated")
	t.eq(engine.state.player(0).life_points, before + LP_GAIN,
		"the controller gained %d LP" % LP_GAIN)


static func _test_the_OPPONENT_of_the_controller_may_activate_it(t: TestCase) -> void:
	t.start("R14 Part A: the OPPONENT of this card's controller may activate clause 1 in "
		+ "THEIR own Main Phase 2, and gets everything")
	var d := _duel(6012)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	# Player 0 controls the Field Spell.
	var springs := _springs_on_field(engine, 0)
	t.eq(springs.controller_id, 0, "player 0 controls the card")

	# Turn passes to player 1, who is now the turn player.
	t.is_true(_to_opponents_main_2(engine), "it is player 1's Main Phase 2")
	t.eq(state.turn_player_id, 1, "player 1 is the turn player")

	var offered = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN)
	t.not_null(offered,
		"clause 1 is offered to player 1 — a card they do NOT control. Every other "
		+ "effect in the library is offered to its controller and to nobody else")

	var before1 := state.player(1).life_points
	var before0 := state.player(0).life_points
	t.is_true(_activate_the_effect(engine, 1, springs),
		"and player 1 activates it")

	t.eq(state.player(1).life_points, before1 + LP_GAIN,
		"PLAYER 1 gained the LP — 「自分」 means the player who activated it")
	t.eq(state.player(0).life_points, before0,
		"and player 0, who controls the card, gained nothing")
	for key in NegationImmunity.ALL_KEYS:
		t.is_true(NegationImmunity.has(state, 1, key),
			"player 1 holds '%s'" % key)
		t.is_false(NegationImmunity.has(state, 0, key),
			"and player 0 does not hold '%s', despite controlling the card" % key)


static func _test_each_player_gets_their_own_use_per_turn(t: TestCase) -> void:
	t.start("each player gets their OWN once-per-turn use of clause 1 — and why the "
		+ "per-player keying is NOT observable in the V1 pool")
	var d := _duel(6013)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var springs := _springs_on_field(engine, 0)

	t.is_true(_to_main_2(engine), "player 0's Main Phase 2")
	t.is_true(_activate_the_effect(engine, 0, springs), "player 0 uses it")
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN),
		"player 0 may not use it twice in one turn")

	t.is_true(_to_opponents_main_2(engine), "player 1's Main Phase 2")
	var before := state.player(1).life_points
	t.is_true(_activate_the_effect(engine, 1, springs),
		"player 1 has their own use on their own turn")
	t.eq(state.player(1).life_points, before + LP_GAIN, "and gained the LP")

	# **Said out loud rather than left to look like a proof.** The declaration is
	# `opt_named_effect()` (per player + name + effect) and NOT `opt_instance()` (per
	# card), and that is what the official 「お互いのプレイヤーは１ターンに１度」 says. But the
	# two are **behaviourally indistinguishable for this card in the V1 pool**: both reset
	# every turn, and only the TURN PLAYER has a Main Phase 2, so no single turn ever
	# offers the effect to both players. The sequence above would pass under either
	# declaration.
	#
	# So the per-player keying is asserted where it IS observable — on the declaration —
	# and the behavioural claim is limited to what was actually shown. This is the
	# R1 / R21 / R23 treatment: a branch that cannot be reached from the printed pool is
	# recorded as such rather than dressed up as a real test.
	var e := _effect(EFFECT_MAIN)
	if e != null:
		t.is_true(e.once_per_turn_named_effect,
			"the per-PLAYER keying is asserted on the declaration, because the pool "
			+ "cannot distinguish it behaviourally: only the turn player has a Main "
			+ "Phase 2, so one turn never offers this effect to both players")



## The negative control for the turn-player route, and it is NOT optional.
##
## Added because the batch-18 unit B mutation pass found it missing: removing the
## `activated_by_turn_player` check from `DuelEngine._activation_actions()` left the whole
## suite green (mutation M15 SURVIVED). Without this test, an engine that offered the turn
## player EVERY effect on their opponent's cards would have passed — which is a far worse
## bug than the one the marker was added to fix.
static func _test_an_ORDINARY_effect_on_a_foreign_card_is_NOT_offered(
		t: TestCase) -> void:
	t.start("the turn player is NOT offered an ordinary effect on a card their opponent "
		+ "controls — only one marked `activated_by_turn_player`")
	var d := _duel(6015)
	var engine: DuelEngine = d["engine"]

	# Player 0 controls the Field Spell AND an ordinary Ignition-effect card, both of
	# which are face-up on their field.
	var springs := _springs_on_field(engine, 0)
	var ordinary_def := TestFixtures.spell("Ordinary Continuous",
		Enums.STKind.CONTINUOUS_SPELL)
	var log := []
	var ordinary_effect := TestFixtures.logging_effect("ordinary_ignition", "ORDINARY",
		log)
	ordinary_effect.of_type(Enums.EffectType.IGNITION)
	ordinary_effect.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	ordinary_effect.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	TestFixtures.with_effect(ordinary_def, ordinary_effect)
	var ordinary := TestFixtures.give(engine, 0, ordinary_def,
		Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_UP)

	# Player 1 becomes the turn player.
	t.is_true(_to_opponents_main_2(engine), "it is player 1's Main Phase 2")

	t.not_null(TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN),
		"CONTROL: the MARKED effect on player 0's card IS offered to player 1")
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, ordinary.id, "ordinary_ignition"),
		"but the ORDINARY effect on another of player 0's cards is NOT — the "
		+ "turn-player route is opened by the marker and by nothing else")

	# And it is still offered to its own controller on their own turn.
	t.is_true(TestFixtures.end_turn(engine), "the turn passes back to player 0")
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, ordinary.id, "ordinary_ignition"),
		"CONTROL: and its own controller may still activate it normally, so the refusal "
		+ "above is about WHO asked and not about the card being unusable")

static func _test_the_first_player_has_no_main_phase_2_on_turn_1(t: TestCase) -> void:
	t.start("on turn 1 the first player has NO Main Phase 2, so this card's only effect "
		+ "cannot be activated at all that turn")
	var d := TestFixtures.new_duel(6014, 0)
	var engine: DuelEngine = d["engine"]
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_number, 1, "it is turn 1")
	t.eq(engine.state.turn_player_id, 0, "and player 0 went first")
	var springs := _springs_on_field(engine, 0)

	t.is_false(_to_main_2(engine),
		"Main Phase 2 cannot be reached — \"the player who goes first cannot conduct a "
		+ "Battle Phase on their first turn\" [S1 p.37], and Main Phase 2 is only "
		+ "reachable through the Battle Phase")
	t.is_null(TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN),
		"so clause 1 is never offered on that turn")

	# CONTROL: the very next turn, the other player CAN reach it.
	t.is_true(_to_opponents_main_2(engine), "CONTROL: player 1 reaches Main Phase 2")
	t.not_null(TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN),
		"CONTROL: and clause 1 is offered to them")


# ---------------------------------------------------------------------------
# The effect — what it does, and to whom
# ---------------------------------------------------------------------------

static func _test_the_lp_and_protections_go_to_the_ACTIVATOR(t: TestCase) -> void:
	t.start("the LP and all three protections are applied together, to the activator")
	var d := _duel(6020)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var springs := _springs_on_field(engine, 0)
	t.is_true(_to_main_2(engine), "Main Phase 2")

	for key in NegationImmunity.ALL_KEYS:
		t.is_false(NegationImmunity.has(state, 0, key),
			"before activation player 0 holds nothing")
	var before := state.player(0).life_points
	t.is_true(_activate_the_effect(engine, 0, springs), "clause 1 resolves")
	t.eq(state.player(0).life_points, before + LP_GAIN, "the LP was gained")
	for key in NegationImmunity.ALL_KEYS:
		t.is_true(NegationImmunity.has(state, 0, key),
			"and '%s' applies — 「これらは同時に行われます。」" % key)


static func _test_the_protections_are_gone_next_turn(t: TestCase) -> void:
	t.start("the protections are 「このターン中」 — the card sitting on the field grants "
		+ "nothing by itself on a later turn")
	var d := _duel(6021)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var springs := _springs_on_field(engine, 0)
	t.is_true(_to_main_2(engine), "Main Phase 2")
	t.is_true(_activate_the_effect(engine, 0, springs), "clause 1 resolves")
	t.is_true(NegationImmunity.has(state, 0, NegationImmunity.KEY_SUMMONS),
		"protected this turn")

	t.is_true(TestFixtures.end_turn(engine), "the turn ends")
	for key in NegationImmunity.ALL_KEYS:
		t.is_false(NegationImmunity.has(state, 0, key),
			"'%s' is gone, although the card is still face-up in the Field Zone" % key)
	t.eq(springs.zone, Enums.Zone.FIELD_ZONE, "the card really is still there")


# ---------------------------------------------------------------------------
# The effect's own vulnerability
# ---------------------------------------------------------------------------

static func _test_it_creates_a_chain_block_and_can_be_negated(t: TestCase) -> void:
	t.start("clause 1 creates a Chain Block, so its activation can be negated")
	var d := _duel(6030)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var springs := _springs_on_field(engine, 0)
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_activation_negator("Test Any Negator"))
	negator.turn_set = 0
	var p1: ScriptedController = d["p1"]
	p1.default_yes = true

	t.is_true(_to_main_2(engine), "Main Phase 2")
	var before := state.player(0).life_points
	var offered = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, springs.id, EFFECT_MAIN)
	t.not_null(offered, "clause 1 is offered")
	if offered == null:
		return
	t.is_true(engine.submit_action(offered), "and activated")

	# Player 1 answers it.
	var guard := 0
	var responded := false
	while guard < 10 and engine.timing != DuelEngine.Timing.OPEN:
		guard += 1
		var found = TestFixtures.find_action(engine.get_legal_responses(1),
			Enums.ActionKind.ACTIVATE_CARD, negator.id, "negate_any_activation")
		if found != null:
			responded = engine.submit_action(found)
			break
		var waiting := engine.waiting_player()
		if waiting == -1:
			break
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting))
	TestFixtures.pass_until_open(engine)

	t.is_true(responded, "the negator was activated in response — so clause 1 really did "
		+ "put a link on the Chain that could be answered")
	t.eq(state.player(0).life_points, before,
		"the activation was negated, so no LP was gained")
	t.is_false(NegationImmunity.has(state, 0, NegationImmunity.KEY_SUMMONS),
		"and no protection was granted")


static func _test_it_does_not_protect_its_own_activation(t: TestCase) -> void:
	t.start("clause 1's own second bullet cannot protect clause 1: it includes no "
		+ "Special Summon")
	var d := _duel(6031)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var springs := _springs_on_field(engine, 0)
	# Grant the protections up front, as though a previous activation had resolved, and
	# then check the gate's verdict on clause 1's own link.
	NegationImmunity.grant_all(state, 0)

	var cm := ChainManager.new(state)
	cm.engine = engine
	var e := _effect(EFFECT_MAIN)
	if e == null:
		return
	var link := cm.add_link(springs, e, 0)
	t.is_false(NegationImmunity.activation_negation_blocked(state, link),
		"the protection does NOT cover clause 1's own activation")

	# CONTROL: an otherwise identical link whose effect DOES include a Special Summon IS
	# covered, so the refusal above is about this effect and not about the gate being off.
	var ss := EffectDef.new("synthetic_ss", "Test: Special Summon something.")
	ss.of_type(Enums.EffectType.CARD_ACTIVATION)
	ss.includes_a_special_summon()
	ss.resolve = func(_ctx: EffectContext) -> void: pass
	var link2 := cm.add_link(springs, ss, 0)
	t.is_true(NegationImmunity.activation_negation_blocked(state, link2),
		"CONTROL: a link that DOES include a Special Summon is covered on the same board")


static func _test_the_card_itself_is_not_protected_because_it_is_face_up(
		t: TestCase) -> void:
	t.start("the card granting the protection does not protect ITSELF — it is face-up, "
		+ "and the third bullet names SET Spell/Traps")
	var d := _duel(6032)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var springs := _springs_on_field(engine, 0)
	var enemy := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Destroyer", 4, 1000, 1000))
	NegationImmunity.grant_all(state, 0)

	t.is_false(NegationImmunity.targeting_blocked(state, springs, 1),
		"the opponent may target the face-up Field Spell")
	t.is_true(state.destroy(springs, Enums.MoveReason.DESTROYED_BY_EFFECT, enemy.id),
		"and destroy it")
	t.eq(springs.zone, Enums.Zone.GRAVEYARD, "it reached the Graveyard")

	# CONTROL: a SET card of the same player, on the same board, IS protected.
	var set_card := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.spell("Set Card"))
	t.is_true(NegationImmunity.targeting_blocked(state, set_card, 1),
		"CONTROL: a SET Spell/Trap of the same player is protected")


# ---------------------------------------------------------------------------
# The cross-card interaction — the reason unit B came second
# ---------------------------------------------------------------------------

static func _test_it_does_not_stop_fairy_tail_sleeper(t: TestCase) -> void:
	t.start("Hidden Springs does NOT stop `Fairy Tail - Sleeper`: Sleeper SUBSTITUTES "
		+ "rather than negates, and the protection names negation")
	var d := _duel(6040)
	var engine: DuelEngine = d["engine"]
	var state := engine.state

	# Player 1 is protected, and activates a Normal Spell that includes a Special Summon.
	NegationImmunity.grant_all(state, 1)
	var log := []
	var spell_def := TestFixtures.spell("Protected Normal Spell")
	var spell_effect := TestFixtures.card_activation("printed",
		Enums.SpellSpeed.SS1, log, "PRINTED")
	spell_effect.includes_a_special_summon()
	TestFixtures.with_effect(spell_def, spell_effect)
	var spell := TestFixtures.give(engine, 1, spell_def, Enums.Zone.SPELL_TRAP_ZONE,
		Enums.Position.FACE_UP)

	var cm := ChainManager.new(state)
	cm.engine = engine
	var link := cm.add_link(spell, spell_effect, 1)

	# The control first: a real ACTIVATION negation IS stopped on this board.
	var negator := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Would-Be Negator", 4, 1000, 1000))
	t.is_false(cm.negate_activation(link.link_number, negator),
		"CONTROL: an activation negation IS stopped — the protection is really on")

	# And now the substitution, which is a different operation entirely.
	var replacement := EffectPrimitives.become_change_opponent_monster_face_down(
		"Change 1 face-up monster your opponent controls to face-down Defense Position")
	t.is_true(cm.substitute_link_effect(link.link_number, replacement, negator),
		"but the SUBSTITUTION goes through — Hidden Springs protects an activation from "
		+ "being NEGATED, and `Fairy Tail - Sleeper` does not negate it. Official Q&A "
		+ "fid 24272 confirms Sleeper's effect is classified by what it does rather than "
		+ "by the replacement text")
	t.is_true(link.is_substituted(), "the link carries the replacement")
	t.is_false(link.is_negated(), "and is not negated in either sense")

	cm.resolve_chain()
	t.is_false(log.has("PRINTED"),
		"the protected Spell resolved the REPLACEMENT and not its own printed effect")

	# Both cards are in the SAME printed deck, so this interaction is live rather than
	# hypothetical. Read from the card database, which is where deck membership lives —
	# `CardDef` does not carry it.
	t.not_null(_card("Fairy Tail - Sleeper"), "`Fairy Tail - Sleeper` is in the pool")
	var sleeper_decks := _decks_of("Fairy Tail - Sleeper")
	var springs_decks := _decks_of(CARD_UNDER_TEST)
	t.is_false(sleeper_decks.is_empty(), "the database lists Sleeper's decks")
	t.eq(sleeper_decks, springs_decks,
		"and both cards are in the same deck (%s), so this is a real interaction on the "
			% ", ".join(PackedStringArray(springs_decks))
		+ "printed decks rather than a synthetic one")


# ---------------------------------------------------------------------------
# Deterministic replay
# ---------------------------------------------------------------------------

static func _test_the_same_seed_and_script_replay_identically(t: TestCase) -> void:
	t.start("the same seed and the same controller script replay identically")
	var runs := []
	for i in range(2):
		var d := _duel(6050)
		var engine: DuelEngine = d["engine"]
		var p0: ScriptedController = d["p0"]
		var p1: ScriptedController = d["p1"]
		p0.default_yes = true
		p1.default_yes = true
		var springs := _springs_on_field(engine, 0)
		_to_main_2(engine)
		_activate_the_effect(engine, 0, springs)
		_to_opponents_main_2(engine)
		_activate_the_effect(engine, 1, springs)
		var kinds := []
		for ev in engine.state.events:
			kinds.append(int(ev.kind))
		runs.append({
			"kinds": kinds,
			"lp0": engine.state.player(0).life_points,
			"lp1": engine.state.player(1).life_points,
			"p0_protected": NegationImmunity.has(engine.state, 0,
				NegationImmunity.KEY_SUMMONS),
			"p1_protected": NegationImmunity.has(engine.state, 1,
				NegationImmunity.KEY_SUMMONS),
		})
	t.eq(runs[0]["kinds"], runs[1]["kinds"],
		"the same sequence of events, in the same order")
	t.eq(runs[0]["lp0"], runs[1]["lp0"], "the same LP for player 0")
	t.eq(runs[0]["lp1"], runs[1]["lp1"], "the same LP for player 1")
	t.eq(runs[0]["p0_protected"], runs[1]["p0_protected"],
		"the same protection state for player 0")
	t.eq(runs[0]["p1_protected"], runs[1]["p1_protected"],
		"the same protection state for player 1")

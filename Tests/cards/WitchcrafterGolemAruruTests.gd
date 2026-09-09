class_name WitchcrafterGolemAruruTests
extends RefCounted

## `Witchcrafter Golem Aruru` — LIGHT / Spellcaster / Level 8 / 2800 ATK / 0 DEF.
## One copy, deck 2 ("Fairy-Tail Tribute Guard").
##
## Official English text (verified, `Data/cards/cards.json`, cid 14483, re-fetched from the
## live database on 2026-09-08 and diffed character for character before anything was written):
##
##   "When your opponent activates a card or effect that targets a Spellcaster monster(s) you
##    control, or targets it for an attack (Quick Effect): You can target 1 card your opponent
##    controls, or 1 "Witchcrafter" Spell in your GY; Special Summon this card from your hand,
##    and if you do, return that targeted card to the hand. You can only use this effect of
##    "Witchcrafter Golem Aruru" once per turn. Once per turn, during your opponent's Standby
##    Phase: Return this card to the hand."
##
## `Research/CARD_RULINGS.md` **R13** — which this suite closes. The four facts the printed
## English text does not carry, each with its own assertions here:
##
##   * **A — it cannot be activated during the Damage Step.** The default
##     `DamageStepPermission.NONE` already produces this, which is exactly why it is asserted
##     in both directions rather than assumed.
##   * **C — the trigger is narrower than the English.** Face-up, in your MONSTER ZONE, and
##     targeted by the **opponent's** activation. Each narrowing has a negative that is driven
##     through a real response window rather than read off the declaration.
##   * **D — a multi-target opponent effect qualifies when ONE target is yours** (Q&A fid 22558).
##   * **E — a dead target costs the BOUNCE, not the Special Summon.** This inverts the
##     ordinary reading of a single-target effect and is the load-bearing assertion of the
##     whole suite.
##
## Aruru and `Maiden with Eyes of Blue` look alike and are wired differently on purpose:
## Maiden is a Quick Effect **plus** a Spell Speed 1 Trigger sharing one allowance (R37);
## Aruru is **one** Quick Effect with two trigger windows and no shared group. Both shapes are
## asserted here against Maiden's own declaration so the two can never be quietly merged.
##
## Vacuity: the pool makes this live. Aruru's deck holds eight other Spellcasters and the
## opposing deck holds real cards that target a monster their opponent controls, so the
## targeting branch is driven once with the real `Compulsory Evacuation Device` as well as with
## fixtures. The GY branch is **never** live (no "Witchcrafter" Spell is printed in either
## deck) and gets the R21/R23 synthetic treatment with a real-pool assertion in the other
## direction.

const CARD_UNDER_TEST := "Witchcrafter Golem Aruru"
const ARCHETYPE := "Witchcrafter"

const QUICK_EFFECT_ID := "summon_from_hand_and_bounce_when_a_spellcaster_is_targeted"
const STANDBY_EFFECT_ID := "return_this_card_to_hand_in_opponent_standby_phase"


static func run() -> TestCase:
	var t := TestCase.new("WitchcrafterGolemAruruTests")

	# --- Shape ---
	_test_printed_stats(t)
	_test_clause_one_shape(t)
	_test_clause_two_shape(t)
	_test_the_two_clauses_do_not_share_an_allowance(t)

	# --- Clause 1: the targeting window ---
	_test_offered_when_the_opponent_targets_your_spellcaster(t)
	_test_offered_against_a_real_pool_card(t)
	_test_not_offered_when_the_opponent_targets_a_non_spellcaster(t)
	_test_not_offered_with_no_activation_at_all(t)
	_test_not_offered_when_the_spellcaster_is_face_down(t)
	_test_not_offered_for_a_spellcaster_outside_the_monster_zone(t)
	_test_not_offered_when_the_targeting_activation_is_your_own(t)
	_test_offered_when_one_of_several_targets_is_your_spellcaster(t)
	_test_not_offered_once_the_targeting_activation_is_negated(t)
	_test_an_aruru_already_on_the_field_does_not_answer(t)

	# --- Clause 1: the attack window ---
	_test_offered_when_your_spellcaster_is_attacked(t)
	_test_not_offered_on_a_direct_attack(t)
	_test_not_offered_when_a_non_spellcaster_is_attacked(t)
	_test_your_spellcaster_attacking_does_not_open_the_window(t)
	_test_never_offered_during_the_damage_step(t)

	# --- Clause 1: targeting ---
	_test_it_targets_exactly_one_card_from_a_union_of_two_pools(t)
	_test_it_is_not_offered_with_no_legal_target(t)
	_test_a_set_spell_trap_is_a_legal_target(t)

	# --- Clause 1: resolution ---
	_test_it_summons_itself_and_bounces_the_target(t)
	_test_the_summon_still_happens_when_the_target_is_gone(t)
	_test_the_summon_still_happens_when_the_target_changed_control(t)
	_test_no_bounce_when_the_summon_fails(t)
	_test_nothing_happens_when_it_left_the_hand(t)
	_test_the_bounce_reaches_the_owner_not_the_controller(t)
	_test_the_bounce_is_not_a_destruction(t)
	_test_the_summon_and_the_bounce_are_one_uninterrupted_resolution(t)

	# --- Clause 1: the "Witchcrafter" Spell branch (never live in the pool) ---
	_test_a_witchcrafter_spell_in_your_gy_is_a_legal_target(t)
	_test_the_gy_branch_is_a_spell_in_your_own_gy_and_nothing_else(t)
	_test_no_printed_card_can_satisfy_the_gy_branch(t)

	# --- Clause 1: once per turn, and negation ---
	_test_the_once_per_turn_is_per_name_and_locks_a_second_copy(t)
	_test_the_once_per_turn_resets_next_turn(t)
	_test_activation_negation_leaves_nothing_and_still_spends_the_use(t)
	_test_effect_negation_leaves_nothing_and_still_spends_the_use(t)

	# --- Clause 2 ---
	_test_it_returns_itself_in_the_opponents_standby_phase(t)
	_test_it_does_not_return_in_your_own_standby_phase(t)
	_test_it_is_mandatory(t)
	_test_it_does_not_fire_while_face_down(t)
	_test_it_does_not_fire_from_the_hand(t)
	_test_clause_two_rechecks_the_field_at_resolution(t)
	_test_it_fires_once_per_opponent_standby_phase(t)

	# --- The pool, and determinism ---
	_test_the_pool_makes_the_spellcaster_condition_live(t)
	_test_deterministic_replay(t)
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


## Deck membership, read straight from the canonical card database. `CardDef` deliberately
## does not carry it — the same reason `TradeInTests` reads the JSON for this question.
static func _deck_names(card_name: String) -> Array:
	var f := FileAccess.open("res://Data/cards/cards.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("cards"):
		return []
	for entry in parsed["cards"]:
		if str(entry.get("name", "")) == card_name:
			return entry.get("decks", [])
	return []


## A synthetic Spellcaster. `TestFixtures.monster()` builds a Warrior, and the Race is the
## whole point of Aruru's trigger, so every test states it rather than inheriting it.
static func _spellcaster(card_name: String, atk: int = 1500) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, atk, 1000, "LIGHT")
	d.race = "Spellcaster"
	return d


static func _warrior(card_name: String, atk: int = 1500) -> CardDef:
	var d := TestFixtures.monster(card_name, 4, atk, 1000, "DARK")
	d.race = "Warrior"
	return d


## A Normal Spell that TARGETS `count` cards and does nothing to them. The targeting is the
## point, not the effect. `pool` is:
##   "field"      — every monster on either field, face-up or face-down;
##   "everywhere" — every card player 0 owns, in any zone, so a test can aim an opponent's
##                  effect at a Spellcaster that is NOT in a Monster Zone.
static func _targeting_spell(card_name: String, order_log: Array, count: int = 1,
		pool: String = "field") -> CardDef:
	var e := EffectDef.new("targeting_activation",
		"Test: target %d card(s); nothing happens to them." % count)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS1)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(count)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		if pool == "everywhere":
			var p := ctx.state.player(0)
			out.append_array(p.monsters())
			out.append_array(p.hand)
			out.append_array(p.graveyard)
		else:
			for player in ctx.state.players:
				out.append_array((player as PlayerState).monsters())
		return out
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append("targeted")
	return TestFixtures.with_effect(TestFixtures.spell(card_name), e)


## The Trap twin of `_targeting_spell()`: Spell Speed 2, activated from a Set position, so its
## controller can use it inside a response window on the OPPONENT's turn. A Set Normal Spell
## cannot — `ActivationRules.card_activation_timing_ok()` confines it to its controller's own
## Main Phase — so the two really are different fixtures and not a convenience.
static func _targeting_trap(card_name: String, order_log: Array) -> CardDef:
	var e := EffectDef.new("targeting_activation",
		"Test: target 1 monster; nothing happens to it.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for player in ctx.state.players:
			out.append_array((player as PlayerState).monsters())
		return out
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append("targeted")
	return TestFixtures.with_effect(TestFixtures.trap(card_name), e)


## A Set Trap its controller could respond with but never does, so a response window really
## opens and a "not offered" assertion is not vacuous. The `Maiden with Eyes of Blue` device.
static func _spacer_trap(engine: DuelEngine, pid: int,
		card_name: String = "Chain Holder") -> CardInstance:
	var order_log: Array = []
	var e := TestFixtures.card_activation("spacer", Enums.SpellSpeed.SS2, order_log, "spacer")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	return TestFixtures.give_set_spell_trap(engine, pid,
		TestFixtures.with_effect(TestFixtures.trap(card_name), e))


## A Set Trap that its controller may activate INSIDE the Damage Step, so a Damage Step window
## really opens for them. The plain `_spacer_trap()` cannot: `DamageStepPermission.NONE` makes
## it illegal there, the engine correctly auto-passes, and a "never offered in the Damage Step"
## walk would then step through a Damage Step in which nobody was ever asked anything.
static func _damage_step_spacer(engine: DuelEngine, pid: int,
		permission: Enums.DamageStepPermission, card_name: String) -> CardInstance:
	var order_log: Array = []
	var e := TestFixtures.card_activation("ds_spacer", Enums.SpellSpeed.SS2, order_log, "ds")
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.damage_step(permission)
	return TestFixtures.give_set_spell_trap(engine, pid,
		TestFixtures.with_effect(TestFixtures.trap(card_name), e))


## A MONSTER whose Quick Effect is activated in the hand and targets one monster on the field,
## doing nothing to it. The only way to build "the opponent has a live targeting activation and
## controls no card at all": a Spell or Trap activated from the hand is placed face-up in a
## Spell & Trap Zone and would itself be a legal Aruru target. `Honest` is the printed card
## that proves a monster effect activated from the hand behaves this way.
static func _hand_targeting_monster(card_name: String, order_log: Array) -> CardDef:
	var e := EffectDef.new("hand_quick_targeting",
		"Test: from the hand, target 1 monster; nothing happens to it.")
	e.of_type(Enums.EffectType.QUICK)
	e.from_locations([Enums.ActivationLocation.HAND])
	e.targeting(1)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for player in ctx.state.players:
			out.append_array((player as PlayerState).monsters())
		return out
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append("targeted")
	return TestFixtures.with_effect(_warrior(card_name), e)


## A Set Trap that takes PERMANENT control of one targeted monster the opponent controls.
## Used to move control of Aruru's target while Aruru's own Chain Link is still waiting, which
## is the exact state R29 decides and which cannot be reached by writing the field directly:
## the Chain resolves inside `submit_action()` the moment nobody holds a response.
static func _control_stealer(card_name: String, order_log: Array) -> CardDef:
	var e := EffectDef.new("steal_control", "Test: take control of 1 opposing monster.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)
	e.legal_targets = func(ctx: EffectContext) -> Array:
		return EffectPrimitives.opponent_monsters(ctx)
	e.resolve = func(ctx: EffectContext) -> void:
		if EffectPrimitives.take_control_of_target(ctx, Enums.ControlDuration.PERMANENT):
			order_log.append("stolen")
	return TestFixtures.with_effect(TestFixtures.trap(card_name), e)


## A Counter Trap that negates the ACTIVATION of whatever Chain Link is directly below it,
## including a monster's effect. `TestFixtures.activation_negator()` cannot reach a monster
## effect — `spell_trap_activation_below()` deliberately answers only the Spell/Trap question
## — and Aruru's clause 1 is a monster effect activated in the hand, so the counterpart of
## `TestFixtures.any_effect_negator()` is needed and does not otherwise exist.
static func _any_activation_negator(card_name: String) -> CardDef:
	var d := TestFixtures.trap(card_name, Enums.STKind.COUNTER_TRAP)
	var e := EffectDef.new("negate_any_activation",
		"Test: negate the activation of whatever is below.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS3)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.chain_link_below(ctx) != null
	e.resolve = func(ctx: EffectContext) -> void:
		var link_number: int = ctx.link.link_number if ctx.link != null else 0
		var below := EffectPrimitives.chain_link_below(ctx, link_number)
		if below == null or ctx.engine == null or ctx.engine.chain == null:
			return
		ctx.engine.chain.negate_activation(below.link_number, ctx.source)
	return TestFixtures.with_effect(d, e)


## Player 1's Main Phase 1. Player 0 holds Aruru in hand, controls one face-up Spellcaster,
## and player 1 controls one monster to be a legal target. Player 1 is the turn player, which
## is what lets THEM activate the card that targets.
static func _board(seed_value: int, yes: bool = true) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = yes
	(d["p1"] as ScriptedController).default_yes = yes
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["caster"] = TestFixtures.give_monster_on_field(engine, 0, _spellcaster("Court Mage"))
	d["aruru"] = TestFixtures.give_to_hand(engine, 0, _def())
	d["prey"] = TestFixtures.give_monster_on_field(engine, 1, _warrior("Opposing Ogre"))
	engine.continuous.recompute()
	return d


static func _quick_offered(engine: DuelEngine, aruru: CardInstance) -> bool:
	return TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, aruru.id, QUICK_EFFECT_ID)


static func _quick_action(engine: DuelEngine, aruru: CardInstance):
	return TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, aruru.id, QUICK_EFFECT_ID)


## Player 1 activates `spell` from hand at `target_ids`. Returns whether it was accepted.
static func _opponent_activates(engine: DuelEngine, spell: CardInstance,
		target_ids: Array) -> bool:
	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, spell.id)
	if a == null:
		return false
	a.target_ids = target_ids
	return engine.submit_action(a)


## The whole line in one call: player 1 activates a targeting Spell at player 0's Spellcaster,
## player 0 responds with Aruru aimed at `target`. Returns {"offered", "activated"}.
static func _run_targeting_line(engine: DuelEngine, d: Dictionary,
		target: CardInstance) -> Dictionary:
	var out := {"offered": false, "activated": false}
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	if not _opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]):
		return out
	var a = _quick_action(engine, d["aruru"])
	if a == null:
		return out
	out["offered"] = true
	out["activated"] = engine.submit_action(a.with_choices({"target_ids": [target.id]}))
	TestFixtures.pass_until_open(engine)
	return out


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

static func _test_printed_stats(t: TestCase) -> void:
	t.start("the printed card: LIGHT / Spellcaster / Level 8 / 2800 / 0, an Effect Monster "
		+ "with exactly two clauses")
	var def := _def()
	t.not_null(def, "Aruru is in the library")
	t.eq(def.effects.size(), 2, "exactly two EffectDefs, for the card's two clauses")
	t.eq(def.attribute, "LIGHT", "LIGHT")
	t.eq(def.race, "Spellcaster", "Spellcaster — it is its own clause's Race")
	t.eq(def.level, 8, "Level 8")
	t.eq(def.base_atk, 2800, "2800 ATK")
	t.eq(def.base_def, 0, "0 DEF")
	t.is_true(def.is_effect_monster, "an Effect Monster")
	t.is_false(def.is_normal_monster, "not a Normal Monster")


static func _test_clause_one_shape(t: TestCase) -> void:
	t.start("clause 1 (cid 14483, 手札で発動できる誘発即時効果です): ONE Quick Effect activated "
		+ "IN THE HAND with TWO trigger windows, targeting exactly 1 card, and NO Damage "
		+ "Step permission")
	var e := _effect(QUICK_EFFECT_ID)
	t.not_null(e, "clause 1 exists")
	t.eq(e.effect_type, Enums.EffectType.QUICK, "it is a QUICK effect")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS2, "so it is Spell Speed 2")
	t.eq(e.activation_locations, [Enums.ActivationLocation.HAND],
		"activated in the HAND and nowhere else")
	t.is_true(e.trigger_events.has(GameEvent.Kind.TARGET_SELECTED),
		"it keys on TARGET_SELECTED — the opponent's targeting activation")
	t.is_true(e.trigger_events.has(GameEvent.Kind.ATTACK_TARGET_SELECTED),
		"and on ATTACK_TARGET_SELECTED — 'or targets it for an attack'")
	t.eq(e.trigger_events.size(), 2, "two windows, one clause — not two clauses")
	t.is_true(e.targets, "it targets")
	t.eq(e.target_count_min, 1, "exactly 1 target")
	t.eq(e.target_count_max, 1, "no more than 1")
	t.is_false(e.targets_valid.is_valid(),
		"one target out of a union needs no set-level check (contrast Kunai with Chain)")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"R13 Part A (ダメージステップ中には発動できません): NO Damage Step permission at all")
	t.is_true(e.once_per_turn_named_effect,
		"'You can only use this effect of ... once per turn' is a NAMED-effect limit")
	t.is_false(e.once_per_turn_instance, "not per copy")
	t.is_false(e.once_per_turn_named_activation, "and not per named ACTIVATION")
	t.eq(e.legal_phases, [], "no phase restriction — a Quick Effect answers whenever it can")
	t.eq(e.ruling_ref, "R13", "it cites its ruling")


static func _test_clause_two_shape(t: TestCase) -> void:
	t.start("clause 2 (cid 14483, モンスターゾーンで発動する誘発効果です / 必ず発動します): a "
		+ "MANDATORY Trigger Effect in the Monster Zone, Standby Phase only, once per copy "
		+ "per turn, and it does not target")
	var e := _effect(STANDBY_EFFECT_ID)
	t.not_null(e, "clause 2 exists")
	t.eq(e.effect_type, Enums.EffectType.TRIGGER, "a TRIGGER effect, not a Quick one")
	t.eq(e.spell_speed, Enums.SpellSpeed.SS1, "so it is Spell Speed 1")
	t.eq(e.optionality, Enums.Optionality.MANDATORY, "必ず発動します — MANDATORY")
	t.eq(e.activation_locations, [Enums.ActivationLocation.FIELD_FACE_UP],
		"activated in the Monster Zone, face-up")
	t.eq(e.legal_phases, [Enums.Phase.STANDBY], "the Standby Phase and no other")
	t.is_true(e.trigger_events.has(GameEvent.Kind.PHASE_CHANGED),
		"keyed on the phase change")
	t.is_true(e.once_per_turn_instance, "'Once per turn' on this copy")
	t.is_false(e.targets, "it names no target — it returns itself")
	t.eq(e.damage_step_permission, Enums.DamageStepPermission.NONE,
		"and it is not a Damage Step effect either")
	t.eq(e.ruling_ref, "R13", "it cites its ruling")


static func _test_the_two_clauses_do_not_share_an_allowance(t: TestCase) -> void:
	t.start("R13 Part B: the printed limit governs clause 1 ALONE (このカード名の①の効果は), so "
		+ "Aruru declares NO restriction group — the opposite of Maiden with Eyes of Blue, "
		+ "asserted against Maiden's own declaration so the two cannot be merged")
	var quick := _effect(QUICK_EFFECT_ID)
	var standby := _effect(STANDBY_EFFECT_ID)
	t.eq(quick.restriction_group, "", "clause 1 names no shared group")
	t.eq(standby.restriction_group, "", "and neither does clause 2")
	t.ne(quick.named_key(), standby.named_key(),
		"so the two clauses cannot spend one another's allowance")
	t.is_false(standby.once_per_turn_named_effect,
		"clause 2's limit is per COPY, not per name")

	var maiden := _card("Maiden with Eyes of Blue")
	t.not_null(maiden, "Maiden with Eyes of Blue is in the library")
	var maiden_groups: Array = []
	for entry in maiden.effects:
		maiden_groups.append((entry as EffectDef).restriction_group)
	t.eq(maiden_groups.size(), 2, "Maiden has two clauses")
	t.ne(maiden_groups[0], "", "and Maiden DOES name a shared group")
	t.eq(maiden_groups[0], maiden_groups[1],
		"the same one on both — which is exactly what Aruru must not have")


# ---------------------------------------------------------------------------
# Clause 1 — the targeting window
# ---------------------------------------------------------------------------

static func _test_offered_when_the_opponent_targets_your_spellcaster(t: TestCase) -> void:
	t.start("offered in the response window an OPPONENT's targeting activation opened, and "
		+ "not before it")
	var d := _board(14001)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))

	t.is_false(_quick_offered(engine, aruru),
		"CONTROL: nothing has been activated, so it is not offered")
	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"the opponent activates it targeting the Spellcaster")
	t.eq(engine.chain.chain_size(), 1, "it is Chain Link 1 and unresolved")
	t.is_true(_quick_offered(engine, aruru),
		"and NOW Aruru's Quick Effect is offered — from the HAND")
	t.eq(aruru.zone, Enums.Zone.HAND, "while it is still in the hand")


static func _test_offered_against_a_real_pool_card(t: TestCase) -> void:
	t.start("R13 Part H: driven with a REAL opposing card — Compulsory Evacuation Device "
		+ "targeting a REAL Spellcaster from Aruru's own deck")
	var d := _board(14002)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var real_caster := TestFixtures.give_monster_on_field(engine, 0,
		_card("Apprentice Magician"))
	t.eq(real_caster.current_race(), "Spellcaster",
		"Apprentice Magician really is a Spellcaster")
	var ced := TestFixtures.give_set_spell_trap(engine, 1,
		_card("Compulsory Evacuation Device"), 0)
	engine.continuous.recompute()

	var a = TestFixtures.find_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, ced.id)
	t.not_null(a, "the opponent's Compulsory Evacuation Device is available")
	a.target_ids = [real_caster.id]
	t.is_true(engine.submit_action(a), "and is activated targeting the Spellcaster")
	t.is_true(_quick_offered(engine, aruru),
		"Aruru answers a printed card, not only a fixture")


static func _test_not_offered_when_the_opponent_targets_a_non_spellcaster(
		t: TestCase) -> void:
	t.start("'a SPELLCASTER monster(s) you control' — an activation aimed at your Warrior "
		+ "does not make it eligible")
	var d := _board(14003)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var warrior := TestFixtures.give_monster_on_field(engine, 0, _warrior("Plain Guard"))
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [warrior.id]),
		"the opponent targets the Warrior instead")
	t.eq(engine.chain.chain_size(), 1, "the Chain Link is live and unresolved")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD),
		"player 0 really has a response window — the negative below is not vacuous")
	t.is_false(_quick_offered(engine, aruru), "but Aruru is NOT among the responses")


static func _test_not_offered_with_no_activation_at_all(t: TestCase) -> void:
	t.start("a Quick Effect in the hand is not a free action: with no live activation and no "
		+ "attack, Aruru is offered nowhere")
	var d := _board(14004)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	t.is_false(_quick_offered(engine, aruru), "not in the response list")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_EFFECT, aruru.id, QUICK_EFFECT_ID),
		"and not in the open action list either")
	t.is_false(TestFixtures.has_action(engine.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, aruru.id, QUICK_EFFECT_ID),
		"nor offered to the opponent, who does not control it")


static func _test_not_offered_when_the_spellcaster_is_face_down(t: TestCase) -> void:
	t.start("R13 Part C (表側表示の): a FACE-DOWN Spellcaster does not qualify — its Race is "
		+ "not a property either player may act on")
	var d := _board(14005)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var hidden := TestFixtures.give_monster_on_field(engine, 0, _spellcaster("Hidden Mage"),
		Enums.Position.FACE_DOWN_DEFENSE)
	# The face-up Spellcaster the board fixture places would satisfy the trigger on its own,
	# so it is removed: this test must fail for the face-down monster's sake alone.
	engine.state.move_card(d["caster"], Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE, {})
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	t.is_true(hidden.is_face_down(), "the only Spellcaster on player 0's field is face-down")
	t.is_true(_opponent_activates(engine, spell, [hidden.id]),
		"the opponent targets it anyway, which is legal")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD),
		"player 0 has a response window")
	t.is_false(_quick_offered(engine, aruru), "but Aruru is not offered")

	# The positive control on the same board: turn it face-up and the answer flips.
	engine.state.set_battle_position(hidden, Enums.Position.FACE_UP_DEFENSE, true, -1)
	engine.continuous.recompute()
	t.is_true(_quick_offered(engine, aruru),
		"face-up, the SAME target makes it eligible — so the negative was about face-down")

	# The same narrowing in the ATTACK window, which is a different code path through the
	# same condition: a face-down Spellcaster that is attacked does not open it either.
	var d2 := _attack_board(14006)
	var engine2: DuelEngine = d2["engine"]
	engine2.state.set_battle_position(d2["caster"], Enums.Position.FACE_DOWN_DEFENSE,
		true, -1)
	_spacer_trap(engine2, 0)
	engine2.continuous.recompute()
	t.is_true((d2["caster"] as CardInstance).is_face_down(),
		"the attacked Spellcaster is face-down")
	t.is_true(TestFixtures.attack(engine2, d2["attacker"], d2["caster"]),
		"the opponent attacks it")
	t.is_true(TestFixtures.has_action(engine2.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD), "player 0 has a response window")
	t.is_false(_quick_offered(engine2, d2["aruru"]),
		"and Aruru is not offered for a face-down attack target either")


static func _test_not_offered_for_a_spellcaster_outside_the_monster_zone(
		t: TestCase) -> void:
	t.start("R13 Part C (モンスターゾーンの): a Spellcaster in the HAND or the GRAVEYARD is not "
		+ "'a Spellcaster monster you control', even when the opponent targets it")
	for where in [Enums.Zone.HAND, Enums.Zone.GRAVEYARD]:
		var d := _board(14006 + int(where))
		var engine: DuelEngine = d["engine"]
		var aruru: CardInstance = d["aruru"]
		var elsewhere := TestFixtures.give(engine, 0, _spellcaster("Offstage Mage"), where,
			Enums.Position.FACE_DOWN if where == Enums.Zone.HAND else null)
		engine.state.move_card(d["caster"], Enums.Zone.BANISHED, Enums.MoveReason.RULE, {})
		var order: Array = []
		var spell := TestFixtures.give_to_hand(engine, 1,
			_targeting_spell("Pointing Spell", order, 1, "everywhere"))
		_spacer_trap(engine, 0)
		engine.continuous.recompute()

		t.eq(elsewhere.zone, where, "the Spellcaster is in the %s" % Enums.Zone.keys()[where])
		t.is_true(_opponent_activates(engine, spell, [elsewhere.id]),
			"the opponent's effect targets it there")
		t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
			Enums.ActionKind.ACTIVATE_CARD), "player 0 has a response window")
		t.is_false(_quick_offered(engine, aruru),
			"Aruru is not offered — the clause reads the Monster Zone, not 'anywhere'")


static func _test_not_offered_when_the_targeting_activation_is_your_own(
		t: TestCase) -> void:
	t.start("R13 Part C (相手が効果を発動した時): YOUR OWN effect targeting your own Spellcaster "
		+ "does not open Aruru's window — the narrowing Maiden's primitive does not make")
	var d := TestFixtures.new_duel(14010, 0)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	(d["p1"] as ScriptedController).default_yes = true
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	var caster := TestFixtures.give_monster_on_field(engine, 0, _spellcaster("Court Mage"))
	var aruru := TestFixtures.give_to_hand(engine, 0, _def())
	TestFixtures.give_monster_on_field(engine, 1, _warrior("Opposing Ogre"))
	var order: Array = []
	var mine := TestFixtures.give_to_hand(engine, 0, _targeting_spell("My Own Spell", order))
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	var a = TestFixtures.find_action(engine.get_legal_actions(0),
		Enums.ActionKind.ACTIVATE_CARD, mine.id)
	t.not_null(a, "player 0 can activate their own targeting Spell")
	a.target_ids = [caster.id]
	t.is_true(engine.submit_action(a), "and does, targeting their OWN Spellcaster")
	t.eq(engine.chain.chain_size(), 1, "the link is live and unresolved")

	# The response window goes to the opponent first, who holds nothing, so step until it is
	# player 0's turn to answer. Without this the assertion below would be about a window
	# player 0 was never offered, which is the vacuous shape this suite exists to avoid.
	var responses: Array = []
	for i in range(4):
		responses = engine.get_legal_responses(0)
		if not responses.is_empty():
			break
		var waiting := engine.waiting_player()
		if waiting == -1 or waiting == 0 or engine.timing == DuelEngine.Timing.OPEN:
			break
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting))
	t.is_true(TestFixtures.has_action(responses, Enums.ActionKind.ACTIVATE_CARD),
		"player 0 really is being asked, with their spacer Trap available")
	t.is_false(TestFixtures.has_action(responses, Enums.ActionKind.ACTIVATE_EFFECT,
		aruru.id, QUICK_EFFECT_ID),
		"but Aruru is NOT offered — 相手が効果を発動した時 means the OPPONENT's activation")
	TestFixtures.pass_until_open(engine)
	t.eq(aruru.zone, Enums.Zone.HAND, "and it is still sitting in the hand")

	# The controlled positive: the identical board with the OPPONENT holding the same Spell.
	var d2 := _board(14013)
	var engine2: DuelEngine = d2["engine"]
	var order2: Array = []
	var theirs := TestFixtures.give_to_hand(engine2, 1,
		_targeting_spell("Their Own Spell", order2))
	engine2.continuous.recompute()
	t.is_true(_opponent_activates(engine2, theirs, [(d2["caster"] as CardInstance).id]),
		"the opponent activates the same Spell at the same kind of Spellcaster")
	t.is_true(_quick_offered(engine2, d2["aruru"]),
		"and THEN Aruru is offered — the only difference is who activated")

	# The same narrowing again on the OPPONENT's turn, where a Set Trap of your own is the
	# thing that targets. Two independent timings, so one weak catch cannot carry the rule.
	var d3 := _board(14014)
	var engine3: DuelEngine = d3["engine"]
	var order3: Array = []
	var my_trap := TestFixtures.give_set_spell_trap(engine3, 0,
		_targeting_trap("My Own Trap", order3), 0)
	# A player who is not the turn player only acts inside a response window, so the opponent
	# opens one with a card of their own that targets nothing at all.
	var opener := _spacer_trap(engine3, 1, "Opening Move")
	_spacer_trap(engine3, 0, "Player 0 Holder")
	engine3.continuous.recompute()
	var oa = TestFixtures.find_action(engine3.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, opener.id)
	t.not_null(oa, "the opponent has a non-targeting card to open a window with")
	t.is_true(engine3.submit_action(oa), "they activate it, targeting nothing")
	var ta = TestFixtures.find_action(engine3.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, my_trap.id)
	t.not_null(ta, "player 0 may now respond with their own targeting Trap")
	if ta != null:
		t.is_true(engine3.submit_action(ta.with_choices(
			{"target_ids": [(d3["caster"] as CardInstance).id]})),
			"and does, targeting their OWN Spellcaster")
		var live := false
		for entry in engine3.state.chain:
			if (entry as ChainLink).target_ids.has((d3["caster"] as CardInstance).id):
				live = true
		t.is_true(live, "a live Chain Link really targets the Spellcaster")
		t.is_false(_quick_offered(engine3, d3["aruru"]),
			"Aruru is still not offered — it is the ACTIVATING player that matters")


static func _test_offered_when_one_of_several_targets_is_your_spellcaster(
		t: TestCase) -> void:
	t.start("R13 Part D (official Q&A fid 22558): an opponent effect targeting TWO cards is "
		+ "enough when ONE of them is your face-up Monster-Zone Spellcaster")
	var d := _board(14011)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1,
		_targeting_spell("Two-Handed Spell", order, 2))
	engine.continuous.recompute()

	# The opponent's own monster first, so the Spellcaster is NOT the first target either —
	# an implementation reading only `target_ids[0]` would fail here and pass everywhere else.
	t.is_true(_opponent_activates(engine, spell,
		[(d["prey"] as CardInstance).id, (d["caster"] as CardInstance).id]),
		"the opponent targets their own monster AND your Spellcaster, in that order")
	var link := engine.chain.link_at(1)
	t.eq(link.target_ids.size(), 2, "the Chain Link really carries two targets")
	t.ne(link.target_ids[0], (d["caster"] as CardInstance).id,
		"and your Spellcaster is the SECOND of them")
	t.is_true(_quick_offered(engine, aruru), "Aruru is offered anyway")


static func _test_not_offered_once_the_targeting_activation_is_negated(
		t: TestCase) -> void:
	t.start("a link whose ACTIVATION was negated no longer targets anything, so it does not "
		+ "keep Aruru's window open")
	var d := _board(14012)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	var negator := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.activation_negator("Counter Answer"), 0)
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"the opponent's Spell is Chain Link 1")
	t.is_true(_quick_offered(engine, aruru), "CONTROL: Aruru is offered at this point")
	var n = TestFixtures.find_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(n, "player 0's Counter Trap is also offered")
	t.is_true(engine.submit_action(n), "and is used instead, negating the activation")
	t.is_false(_quick_offered(engine, aruru),
		"with the activation negated, Aruru's window is gone")
	t.eq(aruru.zone, Enums.Zone.HAND, "Aruru stayed in the hand")


# ---------------------------------------------------------------------------
# Clause 1 — the attack window
# ---------------------------------------------------------------------------

## Player 1's Battle Phase on turn 3. Player 0 controls one face-up Spellcaster and holds
## Aruru; player 1 controls the attacker and one more monster to be a legal Aruru target.
static func _attack_board(seed_value: int, caster_def: CardDef = null) -> Dictionary:
	var d := TestFixtures.battle_duel(seed_value)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	(d["p1"] as ScriptedController).default_yes = true
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.BATTLE)
	d["caster"] = TestFixtures.give_monster_on_field(engine, 0,
		caster_def if caster_def != null else _spellcaster("Court Mage", 900))
	d["attacker"] = TestFixtures.give_monster_on_field(engine, 1, _warrior("Raider", 2000))
	d["prey"] = TestFixtures.give_monster_on_field(engine, 1, _warrior("Bystander", 800))
	d["aruru"] = TestFixtures.give_to_hand(engine, 0, _def())
	engine.continuous.recompute()
	return d


static func _test_offered_when_your_spellcaster_is_attacked(t: TestCase) -> void:
	t.start("'or targets it for an attack': offered in the Battle Step window an attack "
		+ "declaration against your Spellcaster opened")
	var d := _attack_board(14020)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	t.is_false(_quick_offered(engine, aruru), "CONTROL: no attack has been declared yet")
	t.is_true(TestFixtures.attack(engine, d["attacker"], d["caster"]),
		"the opponent attacks the Spellcaster")
	t.eq(engine.state.battle_step, Enums.BattleStep.BATTLE,
		"the window is the BATTLE STEP, before the Damage Step")
	t.is_true(_quick_offered(engine, aruru), "and Aruru is offered")

	var a = _quick_action(engine, aruru)
	t.is_true(engine.submit_action(a.with_choices(
		{"target_ids": [(d["attacker"] as CardInstance).id]})),
		"it is activated, targeting the attacking monster")
	TestFixtures.pass_until_open(engine)
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "Aruru Special Summoned itself from the hand")
	t.eq((d["attacker"] as CardInstance).zone, Enums.Zone.HAND,
		"and the attacker was returned to the hand")


static func _test_not_offered_on_a_direct_attack(t: TestCase) -> void:
	t.start("a DIRECT attack selects no attack target, so ATTACK_TARGET_SELECTED is never "
		+ "emitted and the window never opens")
	var d := _attack_board(14021)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	# Player 0's only monster has to go, or the attack cannot be direct. A Set Trap keeps a
	# response window open afterwards — without one the whole battle resolves inside
	# `submit_action()` and "not offered" would be true only because nobody was ever asked.
	engine.state.move_card(d["caster"], Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE, {})
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	t.eq(engine.state.player(0).monsters().size(), 0, "player 0 controls no monster")
	t.is_true(TestFixtures.attack(engine, d["attacker"], null), "the attack is direct")
	var declared := TestFixtures.events_of(engine, GameEvent.Kind.ATTACK_DECLARED)
	t.eq(declared.size(), 1, "one attack was declared")
	t.is_true(bool((declared[0] as GameEvent).data.get("direct", false)),
		"and the engine recorded it as DIRECT")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ATTACK_TARGET_SELECTED), 0,
		"no ATTACK_TARGET_SELECTED was emitted at all")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD),
		"player 0 really has a response window — the negative is not vacuous")
	t.is_false(_quick_offered(engine, aruru), "so Aruru is not offered")


static func _test_not_offered_when_a_non_spellcaster_is_attacked(t: TestCase) -> void:
	t.start("an attack aimed at your WARRIOR does not open the window, even though a "
		+ "Spellcaster of yours is on the field")
	var d := _attack_board(14022)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var warrior := TestFixtures.give_monster_on_field(engine, 0, _warrior("Plain Guard", 500))
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	t.is_true(TestFixtures.attack(engine, d["attacker"], warrior),
		"the opponent attacks the Warrior")
	t.eq(engine.state.current_attack_target, warrior, "the Warrior is the attack target")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD),
		"player 0 has a response window — the negative is not vacuous")
	t.is_false(_quick_offered(engine, aruru), "but Aruru is not in it")


static func _test_your_spellcaster_attacking_does_not_open_the_window(t: TestCase) -> void:
	t.start("'or targets IT for an attack' — your Spellcaster must be the attack TARGET. A "
		+ "Spellcaster of yours that is doing the ATTACKING opens nothing")
	var d := TestFixtures.battle_duel(14024)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	(d["p1"] as ScriptedController).default_yes = true
	t.eq(engine.state.turn_player_id, 0, "it is player 0's own Battle Phase")
	var caster := TestFixtures.give_monster_on_field(engine, 0, _spellcaster("Court Mage",
		1800))
	var theirs := TestFixtures.give_monster_on_field(engine, 1, _warrior("Their Guard", 800))
	var aruru := TestFixtures.give_to_hand(engine, 0, _def())
	_spacer_trap(engine, 0)
	engine.continuous.recompute()

	t.is_true(TestFixtures.attack(engine, caster, theirs),
		"player 0's own Spellcaster declares the attack")
	t.eq(engine.state.current_attacker, caster, "it is the ATTACKER")
	t.ne(engine.state.current_attack_target, caster, "and not the attack target")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD),
		"player 0 has a response window — the negative is not vacuous")
	t.is_false(_quick_offered(engine, aruru),
		"and Aruru is not offered: there is an attack, but not one aimed at the Spellcaster")


static func _test_never_offered_during_the_damage_step(t: TestCase) -> void:
	t.start("R13 Part A (ダメージステップ中には発動できません): offered in the Battle Step and in "
		+ "NO Damage Step sub-step, on the same board and the same live attack")
	var d := _attack_board(14023)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	# Two Set Traps for PLAYER 0 that are themselves legal inside the Damage Step — one for
	# sub-steps 1-2 and one for sub-step 4 — so player 0 is really asked in there. Nothing is
	# given to player 1: the turn player is offered each window first, and a player 1 holding
	# a response would stop the walk before player 0 was ever asked.
	_damage_step_spacer(engine, 0, Enums.DamageStepPermission.UNTIL_DAMAGE_CALC, "Holder A")
	_damage_step_spacer(engine, 0, Enums.DamageStepPermission.AFTER_DAMAGE_CALC, "Holder B")
	engine.continuous.recompute()

	t.is_true(TestFixtures.attack(engine, d["attacker"], d["caster"]),
		"the attack is declared against the Spellcaster")
	t.is_true(_quick_offered(engine, aruru),
		"offered in the Battle Step — the positive half of this assertion")

	var offered_in_damage_step := false
	var windows_seen := 0
	var substeps_seen: Array = []
	var mark := engine.state.events.size()
	for i in range(64):
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if engine.state.battle_step == Enums.BattleStep.DAMAGE:
			# Counted only when player 0 is REALLY being offered something here. Counting
			# every loop iteration instead would make "0 windows" impossible and the
			# negative below would pass without player 0 having been asked at all.
			var here := engine.get_legal_responses(0)
			if not here.is_empty():
				windows_seen += 1
				if TestFixtures.has_action(here, Enums.ActionKind.ACTIVATE_EFFECT,
						aruru.id, QUICK_EFFECT_ID):
					offered_in_damage_step = true
		var pid := engine.waiting_player()
		if pid == -1:
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, pid)):
			break
	for entry in TestFixtures.events_of(engine, GameEvent.Kind.DAMAGE_SUBSTEP_CHANGED, mark):
		var sub = (entry as GameEvent).data.get("substep")
		if not substeps_seen.has(sub):
			substeps_seen.append(sub)

	t.is_true(substeps_seen.size() >= 3,
		"the battle really went through the Damage Step (%d sub-steps seen)"
			% substeps_seen.size())
	t.is_true(windows_seen > 0,
		"and player 0 really was asked inside it (%d windows)" % windows_seen)
	t.is_false(offered_in_damage_step,
		"Aruru was offered in NONE of them — the restriction the English text omits")
	t.eq(aruru.zone, Enums.Zone.HAND, "it never left the hand")

	_test_the_damage_step_bar_bites_a_targeting_activation(t)


## The half of R13 Part A that the walk above cannot reach on its own.
##
## Aruru's clause declares `trigger_events`, and `DuelEngine._activation_actions()` only offers
## such an effect in a window whose events match — so an ordinary Damage Step sub-step window
## carries neither `TARGET_SELECTED` nor `ATTACK_TARGET_SELECTED` and Aruru would be absent
## from it even with a Damage Step permission. The restriction is therefore only OBSERVABLE
## where the opponent's own targeting activation happens INSIDE the Damage Step, which is
## exactly the case the supplement exists to forbid. Without this, only the declaration
## assertion in `_test_clause_one_shape` guards the ruling.
static func _test_the_damage_step_bar_bites_a_targeting_activation(t: TestCase) -> void:
	t.start("R13 Part A, the reachable case: an OPPONENT activation that targets your "
		+ "Spellcaster INSIDE the Damage Step does not open Aruru's window, and the same "
		+ "activation outside one does")
	var d := _attack_board(14025)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var warrior := TestFixtures.give_monster_on_field(engine, 0, _warrior("Plain Guard", 300))
	var order: Array = []
	# The opponent's Trap targets, and is itself legal in Damage Step sub-steps 1-2.
	var pointer_def := _targeting_trap("Damage Step Pointer", order)
	(pointer_def.effects[0] as EffectDef).damage_step(
		Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	var pointer := TestFixtures.give_set_spell_trap(engine, 1, pointer_def, 0)
	# Player 0 needs something of their own that is legal there, or the chain-build window
	# after the opponent's activation closes without player 0 ever being asked.
	_damage_step_spacer(engine, 0, Enums.DamageStepPermission.UNTIL_DAMAGE_CALC, "Holder A")
	engine.continuous.recompute()

	# The attack is aimed at the WARRIOR, so the attack branch is not what is being measured.
	t.is_true(TestFixtures.attack(engine, d["attacker"], warrior),
		"the opponent attacks the Warrior")
	var used := false
	var offered_after := false
	var checked := 0
	for i in range(64):
		if engine.timing == DuelEngine.Timing.OPEN or engine.is_duel_over():
			break
		if not used and engine.state.battle_step == Enums.BattleStep.DAMAGE:
			var p = TestFixtures.find_action(engine.get_legal_responses(1),
				Enums.ActionKind.ACTIVATE_CARD, pointer.id)
			if p != null and engine.submit_action(p.with_choices(
					{"target_ids": [(d["caster"] as CardInstance).id]})):
				used = true
				continue
		if used and engine.state.battle_step == Enums.BattleStep.DAMAGE:
			var here := engine.get_legal_responses(0)
			if not here.is_empty():
				checked += 1
				if TestFixtures.has_action(here, Enums.ActionKind.ACTIVATE_EFFECT,
						aruru.id, QUICK_EFFECT_ID):
					offered_after = true
		var pid := engine.waiting_player()
		if pid == -1:
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, pid)):
			break
	t.is_true(used, "the opponent really activated a targeting card inside the Damage Step")
	t.is_true(checked > 0,
		"and player 0 was really asked afterwards (%d windows)" % checked)
	t.is_false(offered_after,
		"Aruru was still not offered — ダメージステップ中には発動できません")

	# The controlled positive: the SAME card, the SAME target, outside the Damage Step.
	var d2 := _attack_board(14026)
	var engine2: DuelEngine = d2["engine"]
	var pointer_def2 := _targeting_trap("Damage Step Pointer", [])
	(pointer_def2.effects[0] as EffectDef).damage_step(
		Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	var pointer2 := TestFixtures.give_set_spell_trap(engine2, 1, pointer_def2, 0)
	engine2.continuous.recompute()
	var p2 = TestFixtures.find_action(engine2.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_CARD, pointer2.id)
	t.not_null(p2, "the same Trap is available in the open Battle Phase")
	t.is_true(engine2.submit_action(p2.with_choices(
		{"target_ids": [(d2["caster"] as CardInstance).id]})),
		"and is activated at the same Spellcaster, outside the Damage Step")
	t.is_true(_quick_offered(engine2, d2["aruru"]),
		"there, Aruru IS offered — the only difference is the Damage Step")


static func _test_an_aruru_already_on_the_field_does_not_answer(t: TestCase) -> void:
	t.start("clause 1 is activated 手札で — IN THE HAND. An Aruru that is already face-up on "
		+ "the field is a perfectly good Spellcaster for the trigger and still cannot use it")
	var d := _board(14015)
	var engine: DuelEngine = d["engine"]
	var on_field := TestFixtures.give_monster_on_field(engine, 0, _def())
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	engine.continuous.recompute()
	t.eq(on_field.current_race(), "Spellcaster", "Aruru is itself a Spellcaster")

	t.is_true(_opponent_activates(engine, spell, [on_field.id]),
		"the opponent targets the Aruru on the field")
	t.is_true(_quick_offered(engine, d["aruru"]),
		"CONTROL: the copy IN THE HAND is offered — the trigger really is satisfied")
	t.is_false(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_EFFECT, on_field.id, QUICK_EFFECT_ID),
		"but the copy on the FIELD is not offered its own clause 1")


# ---------------------------------------------------------------------------
# Clause 1 — targeting
# ---------------------------------------------------------------------------

static func _test_it_targets_exactly_one_card_from_a_union_of_two_pools(
		t: TestCase) -> void:
	t.start("'1 card your opponent controls' means CARD, not monster: every card the "
		+ "opponent controls is offered, and nothing of yours is")
	var d := _board(14030)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Set Trap"), 0)
	var my_trap := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.trap("My Set Trap"), 0)
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"the opponent's targeting Spell is on the Chain")
	var a = _quick_action(engine, aruru)
	t.not_null(a, "Aruru is offered")
	t.eq(a.target_min, 1, "exactly one target is chosen")
	t.eq(a.target_max, 1, "and no more")
	t.is_true(a.target_candidates.has((d["prey"] as CardInstance).id),
		"the opponent's monster is a candidate")
	t.is_true(a.target_candidates.has(their_trap.id),
		"and so is their face-down Set Trap — '1 CARD your opponent controls'")
	t.is_true(a.target_candidates.has(spell.id),
		"and the Spell they just activated, which is now face-up in their zone")
	t.is_false(a.target_candidates.has(my_trap.id), "your own Set Trap is not a candidate")
	t.is_false(a.target_candidates.has((d["caster"] as CardInstance).id),
		"and neither is your own Spellcaster")
	t.is_false(a.target_candidates.has(aruru.id), "nor Aruru itself, which is in the hand")


static func _test_it_is_not_offered_with_no_legal_target(t: TestCase) -> void:
	t.start("with an empty opposing field and no 'Witchcrafter' Spell in your GY there is no "
		+ "legal target, so the activation is refused rather than resolving into nothing")
	var d := _board(14031)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var order: Array = []
	var spell := TestFixtures.give_set_spell_trap(engine, 1,
		_targeting_spell("Pointing Trap", order), 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"the opponent's Set card is activated from their own zone")
	t.is_true(_quick_offered(engine, aruru),
		"CONTROL: with the opponent controlling cards, Aruru IS offered")

	# Same shape, but the opponent controls nothing at all. Their targeting activation has to
	# be a MONSTER effect activated in the hand: a Spell or Trap activated from the hand is
	# placed face-up in a Spell & Trap Zone and would itself be a legal Aruru target.
	var d2 := _board(14032)
	var engine2: DuelEngine = d2["engine"]
	var aruru2: CardInstance = d2["aruru"]
	engine2.state.move_card(d2["prey"], Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE, {})
	var order2: Array = []
	var pointer := TestFixtures.give_to_hand(engine2, 1,
		_hand_targeting_monster("Pointing Hand Monster", order2))
	_spacer_trap(engine2, 0)
	engine2.continuous.recompute()
	var pa = TestFixtures.find_action(engine2.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, pointer.id, "hand_quick_targeting")
	t.not_null(pa, "the opponent can activate a monster effect from their hand")
	t.is_true(engine2.submit_action(pa.with_choices(
		{"target_ids": [(d2["caster"] as CardInstance).id]})),
		"they do, targeting the Spellcaster, leaving their field empty")
	t.eq(engine2.state.player(1).controlled_cards().size(), 0,
		"the opponent controls no card at all")
	t.eq(engine2.state.player(0).graveyard.filter(
		func(c): return EffectPrimitives.name_matches_archetype(c, ARCHETYPE)).size(), 0,
		"and your GY holds no 'Witchcrafter' card")
	t.is_true(TestFixtures.has_action(engine2.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD), "player 0 has a response window")
	t.is_false(_quick_offered(engine2, aruru2), "but Aruru cannot be activated")


static func _test_a_set_spell_trap_is_a_legal_target(t: TestCase) -> void:
	t.start("a face-down Set card the opponent controls is returned to the hand like any "
		+ "other card, and is not destroyed on the way")
	var d := _board(14033)
	var engine: DuelEngine = d["engine"]
	var their_trap := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.trap("Their Set Trap"), 0)
	engine.continuous.recompute()

	var r := _run_targeting_line(engine, d, their_trap)
	t.is_true(r["activated"], "Aruru resolved with the Set Trap as its target")
	t.eq(their_trap.zone, Enums.Zone.HAND, "the Set Trap is back in its owner's hand")
	t.eq(their_trap.controller_id, 1, "which is the opponent's hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED,
		their_trap.id), 0, "it was not destroyed")


# ---------------------------------------------------------------------------
# Clause 1 — resolution
# ---------------------------------------------------------------------------

static func _test_it_summons_itself_and_bounces_the_target(t: TestCase) -> void:
	t.start("the whole clause: Aruru Special Summons itself from the hand and the targeted "
		+ "card goes back to its owner's hand")
	var d := _board(14040)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]

	var r := _run_targeting_line(engine, d, prey)
	t.is_true(r["offered"], "it was offered")
	t.is_true(r["activated"], "and activated — this branch is not vacuous")
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "Aruru is on the field")
	t.eq(aruru.controller_id, 0, "under its own controller")
	t.is_true(aruru.is_face_up(), "face-up")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		aruru.id), 1, "exactly one Special Summon happened")
	t.eq(prey.zone, Enums.Zone.HAND, "and the target is in the hand")
	t.eq(prey.controller_id, 1, "its owner's hand")


static func _test_the_summon_still_happens_when_the_target_is_gone(t: TestCase) -> void:
	t.start("R13 Part E (対象のカードがフィールドに存在しない場合、このカードを特殊召喚する処理のみを"
		+ "行います): a target that left the field costs the BOUNCE and NOT the Special Summon "
		+ "— this is the assertion the whole ruling was fetched for")
	var d := _board(14041)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	# The opponent's own answer, which banishes the card Aruru is about to target. It is
	# activated ABOVE Aruru, so it resolves FIRST and the target is gone by the time Aruru
	# resolves.
	var yank := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Yank", prey, "banish"), 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"Chain Link 1: the opponent's targeting Spell")
	var a = _quick_action(engine, aruru)
	t.not_null(a, "Aruru is offered")
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [prey.id]})),
		"Chain Link 2: Aruru, targeting the opponent's monster")
	var y = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, yank.id)
	t.not_null(y, "the opponent can answer")
	t.is_true(engine.submit_action(y), "Chain Link 3: they banish their own monster")
	TestFixtures.pass_until_open(engine)

	t.eq(prey.zone, Enums.Zone.BANISHED, "the target really left the field")
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE,
		"and Aruru was Special Summoned ANYWAY — the effect did not fizzle")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		aruru.id), 1, "exactly once")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		prey.id), 0, "and nothing was returned to any hand")


static func _test_the_summon_still_happens_when_the_target_changed_control(
		t: TestCase) -> void:
	t.start("R13 Part F, inheriting R29: a target that changed control is no longer '1 card "
		+ "your opponent controls', so the bounce is lost — but the Special Summon is not")
	var d := _board(14042)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	# Player 0's own answer, activated ABOVE Aruru so it resolves FIRST and moves control of
	# the target while Aruru's Chain Link is still waiting. Writing `controller_id` directly
	# cannot reach this state: the Chain resolves inside `submit_action()` the instant nobody
	# holds a response.
	var steal_log: Array = []
	var stealer := TestFixtures.give_set_spell_trap(engine, 0,
		_control_stealer("Requisition", steal_log), 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"Chain Link 1: the opponent's targeting Spell")
	var a = _quick_action(engine, aruru)
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [prey.id]})),
		"Chain Link 2: Aruru, targeting the opponent's monster")
	# Hand the window back to player 0. The opponent may already have been auto-passed inside
	# `submit_action()`, so this steps only while somebody else is the one being asked.
	var s = null
	for i in range(4):
		s = TestFixtures.find_action(engine.get_legal_responses(0),
			Enums.ActionKind.ACTIVATE_CARD, stealer.id)
		if s != null:
			break
		var waiting := engine.waiting_player()
		if waiting == -1 or waiting == 0 or engine.timing == DuelEngine.Timing.OPEN:
			break
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, waiting))
	t.not_null(s, "player 0 can still respond")
	if s == null:
		return
	t.is_true(engine.submit_action(s.with_choices({"target_ids": [prey.id]})),
		"Chain Link 3 takes control of the target, so it resolves before Aruru")
	TestFixtures.pass_until_open(engine)
	t.eq(steal_log, ["stolen"], "the control change really happened")

	t.eq(prey.controller_id, 0, "player 0 now controls it")
	t.eq(prey.zone, Enums.Zone.MONSTER_ZONE, "it is still on the field and was NOT returned")
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "while Aruru was Special Summoned anyway")


static func _test_no_bounce_when_the_summon_fails(t: TestCase) -> void:
	t.start("'Special Summon this card from your hand, AND IF YOU DO' — with every Monster "
		+ "Zone full there is no Summon, and therefore no bounce at all")
	var d := _board(14043)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	for i in range(6):
		if engine.state.player(0).free_monster_zone_index() == -1:
			break
		TestFixtures.give_monster_on_field(engine, 0, _warrior("Filler %d" % i, 100))
	engine.continuous.recompute()
	t.eq(engine.state.player(0).free_monster_zone_index(), -1,
		"player 0 has no free Monster Zone")

	var r := _run_targeting_line(engine, d, prey)
	t.is_true(r["activated"], "Aruru was still activated — the activation is legal")
	t.eq(aruru.zone, Enums.Zone.HAND, "but it could not be Summoned")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		aruru.id), 0, "no Special Summon happened")
	t.eq(prey.zone, Enums.Zone.MONSTER_ZONE,
		"and the target was NOT returned — 'and if you do' gates the bounce")


static func _test_nothing_happens_when_it_left_the_hand(t: TestCase) -> void:
	t.start("an Aruru that is no longer in the hand at resolution Summons nothing and "
		+ "bounces nothing")
	var d := _board(14044)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	var yank := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Hand Rip", aruru, "send_to_gy"), 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"Chain Link 1")
	var a = _quick_action(engine, aruru)
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [prey.id]})),
		"Chain Link 2: Aruru")
	var y = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, yank.id)
	t.not_null(y, "the opponent can answer")
	t.is_true(engine.submit_action(y), "Chain Link 3 sends Aruru from the hand to the GY")
	TestFixtures.pass_until_open(engine)

	t.eq(aruru.zone, Enums.Zone.GRAVEYARD, "Aruru is in the Graveyard, not the hand")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED,
		aruru.id), 0, "it was not Special Summoned from anywhere")
	t.eq(prey.zone, Enums.Zone.MONSTER_ZONE, "and nothing was returned to the hand")


static func _test_the_bounce_reaches_the_owner_not_the_controller(t: TestCase) -> void:
	t.start("R13 Part F: ownership is never consulted when choosing the target, and the "
		+ "bounce goes to the target's OWNER — so a card you own that the opponent controls "
		+ "is a legal target and comes back to YOUR hand")
	var d := _board(14045)
	var engine: DuelEngine = d["engine"]
	var borrowed := TestFixtures.give_monster_on_field(engine, 0, _warrior("Lent Knight"))
	t.is_true(engine.state.change_control(borrowed, 1, -1, Enums.ControlDuration.PERMANENT),
		"the opponent takes control of a card player 0 OWNS")
	engine.continuous.recompute()
	t.eq(borrowed.owner_id, 0, "player 0 still owns it")
	t.eq(borrowed.controller_id, 1, "while player 1 controls it")

	var r := _run_targeting_line(engine, d, borrowed)
	t.is_true(r["activated"], "it was a legal target — control is what the text names")
	t.eq(borrowed.zone, Enums.Zone.HAND, "and it was returned to a hand")
	t.eq(borrowed.controller_id, 0, "its OWNER's hand, not its controller's")
	t.is_true(engine.state.player(0).hand.has(borrowed),
		"it is really in player 0's hand list")


static func _test_the_bounce_is_not_a_destruction(t: TestCase) -> void:
	t.start("'return to the hand' is not a destruction and not a send to the GY [S1 p.52], "
		+ "so nothing keyed on either may fire")
	var d := _board(14046)
	var engine: DuelEngine = d["engine"]
	var prey: CardInstance = d["prey"]

	var r := _run_targeting_line(engine, d, prey)
	t.is_true(r["activated"], "Aruru resolved")
	t.eq(prey.zone, Enums.Zone.HAND, "the target is in the hand")
	t.eq(prey.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"and the reason recorded is RETURNED_TO_HAND")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, prey.id), 0,
		"no destruction event for it")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_SENT_TO_GY,
		prey.id), 0, "and it never reached the Graveyard")


static func _test_the_summon_and_the_bounce_are_one_uninterrupted_resolution(
		t: TestCase) -> void:
	t.start("R13 Part E (同時に行われたものとして扱います): nothing gets between the Summon and "
		+ "the bounce — no Chain Link forms inside the resolution and both are visible after it")
	var d := _board(14047)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	var links_before := TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED)

	var r := _run_targeting_line(engine, d, prey)
	t.is_true(r["activated"], "Aruru resolved")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CHAIN_LINK_ADDED) - links_before, 2,
		"exactly two Chain Links were ever added: the opponent's and Aruru's")

	# The two halves in the event log, with nothing between them that started a Chain.
	var summon_at := TestFixtures.first_event_index(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED)
	var bounce_at := TestFixtures.first_event_index(engine,
		GameEvent.Kind.CARD_RETURNED_TO_HAND)
	t.is_true(summon_at != -1, "the Summon is in the log")
	t.is_true(bounce_at != -1, "so is the bounce")
	t.is_true(summon_at < bounce_at, "and the Summon comes FIRST, as the supplement says")
	var links_between := 0
	for i in range(summon_at, bounce_at):
		if engine.state.events[i].kind == GameEvent.Kind.CHAIN_LINK_ADDED:
			links_between += 1
	t.eq(links_between, 0, "with no Chain Link created between them")
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "both halves happened: the Summon")
	t.eq(prey.zone, Enums.Zone.HAND, "and the bounce")


# ---------------------------------------------------------------------------
# Clause 1 — the "Witchcrafter" Spell branch (R13 Part G — never live in the pool)
# ---------------------------------------------------------------------------

## A synthetic "Witchcrafter" card. The V1 pool contains no "Witchcrafter" Spell at all, so
## this branch can only be exercised against one — the R21 / R23 treatment.
static func _witchcrafter(card_name: String, category: String = "spell") -> CardDef:
	if category == "trap":
		return TestFixtures.trap(card_name)
	return TestFixtures.spell(card_name)


static func _test_a_witchcrafter_spell_in_your_gy_is_a_legal_target(t: TestCase) -> void:
	t.start("R13 Part G: the second pool — a synthetic 'Witchcrafter' Spell in YOUR GY is a "
		+ "legal target and is added back to your hand")
	var d := _board(14050)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var relic := TestFixtures.give(engine, 0, _witchcrafter("Witchcrafter Bystial Scroll"),
		Enums.Zone.GRAVEYARD)
	engine.continuous.recompute()
	t.eq(relic.zone, Enums.Zone.GRAVEYARD, "it is in player 0's Graveyard")

	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"the opponent's targeting Spell opens the window")
	var a = _quick_action(engine, aruru)
	t.not_null(a, "Aruru is offered")
	t.is_true(a.target_candidates.has(relic.id),
		"and the 'Witchcrafter' Spell in the GY is among its candidates")
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [relic.id]})),
		"it is activated targeting the GY card")
	TestFixtures.pass_until_open(engine)
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "Aruru Special Summoned itself")
	t.eq(relic.zone, Enums.Zone.HAND, "and the 'Witchcrafter' Spell is in the hand")
	t.eq(relic.controller_id, 0, "player 0's own hand")


static func _test_the_gy_branch_is_a_spell_in_your_own_gy_and_nothing_else(
		t: TestCase) -> void:
	t.start("'1 \"Witchcrafter\" SPELL in YOUR GY': a same-archetype TRAP, a non-archetype "
		+ "Spell and the OPPONENT's copy are all refused")
	var d := _board(14051)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var wc_trap := TestFixtures.give(engine, 0,
		_witchcrafter("Witchcrafter Confusion", "trap"), Enums.Zone.GRAVEYARD)
	var plain := TestFixtures.give(engine, 0, TestFixtures.spell("Ordinary Spell"),
		Enums.Zone.GRAVEYARD)
	var theirs := TestFixtures.give(engine, 1, _witchcrafter("Witchcrafter Scroll"),
		Enums.Zone.GRAVEYARD)
	# One legal target has to exist or the activation would be refused for the wrong reason.
	var mine := TestFixtures.give(engine, 0, _witchcrafter("Witchcrafter Creation"),
		Enums.Zone.GRAVEYARD)
	engine.continuous.recompute()

	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"the window is open")
	var a = _quick_action(engine, aruru)
	t.not_null(a, "Aruru is offered")
	t.is_true(a.target_candidates.has(mine.id),
		"CONTROL: your own 'Witchcrafter' Spell IS a candidate")
	t.is_false(a.target_candidates.has(wc_trap.id),
		"a 'Witchcrafter' TRAP is not — the text says Spell (魔法カード)")
	t.is_false(a.target_candidates.has(plain.id),
		"a Spell that is not 'Witchcrafter' is not")
	t.is_false(a.target_candidates.has(theirs.id),
		"and the OPPONENT's 'Witchcrafter' Spell is not — it says YOUR GY")

	# The same three refusals again, this time as the difference between "offered" and "not
	# offered": with an EMPTY opposing field the GY pool is the only source of targets, so a
	# card that must not be a candidate makes the whole activation illegal. The opponent's
	# targeting activation is a monster effect in their hand, because a Spell or Trap
	# activated from the hand would sit face-up in their zone and be a target itself.
	var d2 := _board(14052)
	var engine2: DuelEngine = d2["engine"]
	engine2.state.move_card(d2["prey"], Enums.Zone.GRAVEYARD, Enums.MoveReason.RULE, {})
	TestFixtures.give(engine2, 0, _witchcrafter("Witchcrafter Confusion", "trap"),
		Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine2, 0, TestFixtures.spell("Ordinary Spell"),
		Enums.Zone.GRAVEYARD)
	TestFixtures.give(engine2, 1, _witchcrafter("Witchcrafter Scroll"),
		Enums.Zone.GRAVEYARD)
	var order2: Array = []
	var pointer := TestFixtures.give_to_hand(engine2, 1,
		_hand_targeting_monster("Pointing Hand Monster", order2))
	_spacer_trap(engine2, 0)
	engine2.continuous.recompute()
	var pa = TestFixtures.find_action(engine2.get_legal_actions(1),
		Enums.ActionKind.ACTIVATE_EFFECT, pointer.id, "hand_quick_targeting")
	t.not_null(pa, "the opponent can point from their hand, controlling nothing")
	t.is_true(engine2.submit_action(pa.with_choices(
		{"target_ids": [(d2["caster"] as CardInstance).id]})),
		"and does, at the Spellcaster")
	t.eq(engine2.state.player(1).controlled_cards().size(), 0,
		"the opponent controls no card, so only the GY pool can supply a target")
	t.is_true(TestFixtures.has_action(engine2.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD), "player 0 has a response window")
	t.is_false(_quick_offered(engine2, d2["aruru"]),
		"and Aruru is NOT offered: none of those three GY cards is a legal target")

	# The mirror, so the negative above cannot be passing for some unrelated reason.
	TestFixtures.give(engine2, 0, _witchcrafter("Witchcrafter Creation"),
		Enums.Zone.GRAVEYARD)
	engine2.continuous.recompute()
	t.is_true(_quick_offered(engine2, d2["aruru"]),
		"adding ONE 'Witchcrafter' Spell to your own GY makes it offered again")


static func _test_no_printed_card_can_satisfy_the_gy_branch(t: TestCase) -> void:
	t.start("R13 Part G, the other direction: NO printed card in either deck is a "
		+ "'Witchcrafter' Spell, so this branch is never live in the V1 pool")
	var cards: Dictionary = _library()["cards"]
	var archetype_cards: Array = []
	var archetype_spells: Array = []
	for card_name in cards.keys():
		if not str(card_name).contains(ARCHETYPE):
			continue
		archetype_cards.append(str(card_name))
		if (cards[card_name] as CardDef).category == Enums.Category.SPELL:
			archetype_spells.append(str(card_name))
	t.eq(archetype_cards, [CARD_UNDER_TEST],
		"Aruru is the only 'Witchcrafter' card printed in either deck")
	t.eq(archetype_spells, [], "and no 'Witchcrafter' Spell exists at all")
	t.eq(_def().category, Enums.Category.MONSTER, "Aruru itself is a Monster, not a Spell")


# ---------------------------------------------------------------------------
# Clause 1 — once per turn, and negation
# ---------------------------------------------------------------------------

static func _test_the_once_per_turn_is_per_name_and_locks_a_second_copy(
		t: TestCase) -> void:
	t.start("'You can only use this effect of \"Witchcrafter Golem Aruru\" once per turn' is "
		+ "per NAME: a second copy in the hand cannot use it either")
	var d := _board(14060)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var second := TestFixtures.give_to_hand(engine, 0, _def())
	var extra := TestFixtures.give_monster_on_field(engine, 1, _warrior("Second Ogre"))
	engine.continuous.recompute()

	var r := _run_targeting_line(engine, d, d["prey"])
	t.is_true(r["activated"], "the first copy used the effect")
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "and is on the field")

	# A fresh window on the same turn: the opponent targets the Spellcaster again.
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Second Spell", order))
	_spacer_trap(engine, 0)
	engine.continuous.recompute()
	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"a second targeting activation opens a second window")
	t.is_true(TestFixtures.has_action(engine.get_legal_responses(0),
		Enums.ActionKind.ACTIVATE_CARD), "player 0 has a response window")
	t.is_false(_quick_offered(engine, second),
		"but the SECOND copy is refused — the limit is on the name")
	t.eq(extra.zone, Enums.Zone.MONSTER_ZONE, "so nothing else was bounced")
	t.eq(second.zone, Enums.Zone.HAND, "and the second copy stayed in the hand")


static func _test_the_once_per_turn_resets_next_turn(t: TestCase) -> void:
	t.start("the allowance is per TURN: a new turn restores it")
	var d := _board(14061)
	var engine: DuelEngine = d["engine"]
	var r := _run_targeting_line(engine, d, d["prey"])
	t.is_true(r["activated"], "used on this turn")

	var used_key := (_effect(QUICK_EFFECT_ID) as EffectDef).named_key()
	t.is_true(engine.state.player(0).was_named_effect_used(CARD_UNDER_TEST, used_key,
		engine.state.turn_number), "and the use is recorded for this turn")
	TestFixtures.end_turn(engine)
	t.is_false(engine.state.player(0).was_named_effect_used(CARD_UNDER_TEST, used_key,
		engine.state.turn_number), "on the next turn the allowance is back")


static func _test_activation_negation_leaves_nothing_and_still_spends_the_use(
		t: TestCase) -> void:
	t.start("the ACTIVATION negated: no Summon, no bounce — and the once-per-turn use is "
		+ "still spent, because it is marked at activation")
	var d := _board(14062)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		_any_activation_negator("Counter Answer"), 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"Chain Link 1")
	var a = _quick_action(engine, aruru)
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [prey.id]})),
		"Chain Link 2: Aruru")
	var n = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(n, "the opponent's Counter Trap answers")
	t.is_true(engine.submit_action(n), "Chain Link 3 negates Aruru's activation")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 1,
		"one activation was negated")
	t.eq(aruru.zone, Enums.Zone.HAND, "Aruru was not Summoned")
	t.eq(prey.zone, Enums.Zone.MONSTER_ZONE, "and nothing was returned")
	t.is_true(engine.state.player(0).was_named_effect_used(CARD_UNDER_TEST,
		(_effect(QUICK_EFFECT_ID) as EffectDef).named_key(), engine.state.turn_number),
		"the use is spent anyway — mark_used runs when the link is created")


static func _test_effect_negation_leaves_nothing_and_still_spends_the_use(
		t: TestCase) -> void:
	t.start("the EFFECT negated: the activation happened, and nothing the effect would do "
		+ "happens — the counterpart of the assertion above [master prompt 18]")
	var d := _board(14063)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	var prey: CardInstance = d["prey"]
	var order: Array = []
	var spell := TestFixtures.give_to_hand(engine, 1, _targeting_spell("Pointing Spell", order))
	var negator := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.any_effect_negator("Effect Answer"), 0)
	engine.continuous.recompute()

	t.is_true(_opponent_activates(engine, spell, [(d["caster"] as CardInstance).id]),
		"Chain Link 1")
	var a = _quick_action(engine, aruru)
	t.is_true(engine.submit_action(a.with_choices({"target_ids": [prey.id]})),
		"Chain Link 2: Aruru")
	var n = TestFixtures.find_action(engine.get_legal_responses(1),
		Enums.ActionKind.ACTIVATE_CARD, negator.id)
	t.not_null(n, "the opponent's Trap answers")
	t.is_true(engine.submit_action(n), "Chain Link 3 negates Aruru's EFFECT")
	TestFixtures.pass_until_open(engine)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.EFFECT_NEGATED), 1,
		"one effect was negated")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.ACTIVATION_NEGATED), 0,
		"and no ACTIVATION was — the two are different")
	t.eq(aruru.zone, Enums.Zone.HAND, "Aruru was not Summoned")
	t.eq(prey.zone, Enums.Zone.MONSTER_ZONE, "and nothing was returned")


# ---------------------------------------------------------------------------
# Clause 2 — the mandatory return in the opponent's Standby Phase
# ---------------------------------------------------------------------------

## Player 0 controls a face-up Aruru at the end of their own turn, so the NEXT Standby Phase
## is the opponent's. `position` and `owner` let the negatives use the same road.
static func _standby_board(seed_value: int, yes: bool = true,
		position: Enums.Position = Enums.Position.FACE_UP_ATTACK) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = yes
	(d["p1"] as ScriptedController).default_yes = yes
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	d["aruru"] = TestFixtures.give_monster_on_field(engine, 0, _def(), position)
	engine.continuous.recompute()
	return d


static func _test_it_returns_itself_in_the_opponents_standby_phase(t: TestCase) -> void:
	t.start("clause 2: during the OPPONENT's Standby Phase, Aruru returns itself to the hand")
	var d := _standby_board(14070)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "it starts on the field")
	TestFixtures.end_turn(engine)
	t.eq(engine.state.turn_player_id, 1, "it is now the opponent's turn")
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	t.eq(aruru.zone, Enums.Zone.HAND, "and Aruru is back in the hand")
	t.eq(aruru.controller_id, 0, "its owner's hand")
	t.eq(aruru.last_move_reason, Enums.MoveReason.RETURNED_TO_HAND,
		"returned, not destroyed and not sent to the GY")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, aruru.id), 0,
		"no destruction happened")


static func _test_it_does_not_return_in_your_own_standby_phase(t: TestCase) -> void:
	t.start("'during your OPPONENT's Standby Phase' — a face-up Aruru survives its own "
		+ "controller's Standby Phase untouched, and returns on the next opponent one")
	# Aruru reaches the field during the OPPONENT's Main Phase, so the very next Standby
	# Phase is player 0's OWN. Placing it on player 0's turn would put the opponent's Standby
	# Phase first and the negative could never be observed.
	var d := TestFixtures.new_duel(14071, 0)
	var engine: DuelEngine = d["engine"]
	(d["p0"] as ScriptedController).default_yes = true
	(d["p1"] as ScriptedController).default_yes = true
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	TestFixtures.end_turn(engine)                              # -> the opponent's turn
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)  # their Standby Phase is past
	var aruru := TestFixtures.give_monster_on_field(engine, 0, _def())
	engine.continuous.recompute()
	t.eq(engine.state.turn_player_id, 1, "it is the opponent's Main Phase")

	TestFixtures.end_turn(engine)                              # -> player 0's OWN turn
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(engine.state.turn_player_id, 0, "player 0's own Standby Phase has now passed")
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "and Aruru is still on the field")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		aruru.id), 0, "nothing returned it")

	# The positive control on the same board: the very next Standby Phase is the opponent's.
	TestFixtures.end_turn(engine)                              # -> the opponent's turn
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(aruru.zone, Enums.Zone.HAND, "and THAT Standby Phase returns it")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		aruru.id), 1, "exactly once")


static func _test_it_is_mandatory(t: TestCase) -> void:
	t.start("必ず発動します: the return happens even when its controller answers NO to every "
		+ "optional question")
	var d := _standby_board(14073, false)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	t.is_false((d["p0"] as ScriptedController).default_yes,
		"player 0 declines everything optional")
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(aruru.zone, Enums.Zone.HAND, "and Aruru still returned itself")


static func _test_it_does_not_fire_while_face_down(t: TestCase) -> void:
	t.start("a FACE-DOWN Aruru has no active effects, so clause 2 does not fire")
	var d := _standby_board(14074, true, Enums.Position.FACE_DOWN_DEFENSE)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	t.is_true(aruru.is_face_down(), "it is Set face-down")
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "it is still on the field")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		aruru.id), 0, "and nothing returned it")


static func _test_it_does_not_fire_from_the_hand(t: TestCase) -> void:
	t.start("'フィールドのこのカード' — an Aruru in the HAND or the GRAVEYARD is not on the "
		+ "field, so clause 2 has nothing to return")
	for where in [Enums.Zone.HAND, Enums.Zone.GRAVEYARD]:
		var d := TestFixtures.new_duel(14075 + int(where), 0)
		var engine: DuelEngine = d["engine"]
		(d["p0"] as ScriptedController).default_yes = true
		TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
		var aruru := TestFixtures.give(engine, 0, _def(), where,
			Enums.Position.FACE_DOWN if where == Enums.Zone.HAND else null)
		engine.continuous.recompute()
		var before := TestFixtures.count_events_for(engine,
			GameEvent.Kind.CARD_RETURNED_TO_HAND, aruru.id)
		TestFixtures.end_turn(engine)
		TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
		t.eq(aruru.zone, where, "it stayed in the %s" % Enums.Zone.keys()[where])
		t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
			aruru.id), before, "and clause 2 never fired")


static func _test_clause_two_rechecks_the_field_at_resolution(t: TestCase) -> void:
	t.start("'フィールドのこのカード': an Aruru destroyed in response to its own Standby Phase "
		+ "trigger returns NOTHING — the clause must not drag it out of the Graveyard")
	var d := _standby_board(14079)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	# The opponent's answer, activated ABOVE the mandatory trigger so it resolves first.
	var killer := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.interferer("Standby Answer", aruru, "destroy"), 0)
	engine.continuous.recompute()

	TestFixtures.end_turn(engine)                              # -> the opponent's turn
	t.eq(engine.state.turn_player_id, 1, "it is the opponent's turn")
	var used := false
	for i in range(48):
		if engine.state.phase == Enums.Phase.MAIN_1 or engine.is_duel_over():
			break
		if not used:
			var r = TestFixtures.find_action(engine.get_legal_responses(1),
				Enums.ActionKind.ACTIVATE_CARD, killer.id)
			if r != null and engine.submit_action(r):
				used = true
				continue
		if engine.timing == DuelEngine.Timing.OPEN:
			var a = TestFixtures.find_action(engine.get_legal_actions(1),
				Enums.ActionKind.END_PHASE)
			if a == null or not engine.submit_action(a):
				break
			continue
		var pid := engine.waiting_player()
		if pid == -1:
			break
		if not engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, pid)):
			break

	t.is_true(used, "the opponent really chained to the Standby Phase trigger")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_DESTROYED, aruru.id), 1,
		"Aruru was destroyed while its own trigger was still waiting")
	t.eq(aruru.zone, Enums.Zone.GRAVEYARD,
		"so it is in the GRAVEYARD when the trigger resolves")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		aruru.id), 0, "and the clause returned nothing — it does not reach into the GY")


static func _test_it_fires_once_per_opponent_standby_phase(t: TestCase) -> void:
	t.start("相手のスタンバイフェイズごとに１度: once per opponent Standby Phase — it returns "
		+ "again on the NEXT one after being put back on the field")
	var d := _standby_board(14078)
	var engine: DuelEngine = d["engine"]
	var aruru: CardInstance = d["aruru"]
	TestFixtures.end_turn(engine)                              # -> opponent's turn
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(aruru.zone, Enums.Zone.HAND, "returned in the first opponent Standby Phase")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		aruru.id), 1, "exactly once")

	TestFixtures.end_turn(engine)                              # -> player 0's turn
	engine.state.move_card(aruru, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.RULE,
		{"to_player": 0, "position": Enums.Position.FACE_UP_ATTACK})
	aruru.turn_summoned = -1
	engine.continuous.recompute()
	t.eq(aruru.zone, Enums.Zone.MONSTER_ZONE, "it is back on the field")
	TestFixtures.end_turn(engine)                              # -> opponent's turn again
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)
	t.eq(aruru.zone, Enums.Zone.HAND, "and it returned again on the next opponent Standby")
	t.eq(TestFixtures.count_events_for(engine, GameEvent.Kind.CARD_RETURNED_TO_HAND,
		aruru.id), 2, "twice in total, one per opponent Standby Phase")


# ---------------------------------------------------------------------------
# The pool, and determinism
# ---------------------------------------------------------------------------

static func _test_the_pool_makes_the_spellcaster_condition_live(t: TestCase) -> void:
	t.start("R13 Part H: Aruru's own deck holds other Spellcasters and the opposing deck "
		+ "holds cards that target a monster their opponent controls — none of this suite "
		+ "tests an unreachable clause")
	var cards: Dictionary = _library()["cards"]
	var my_decks := _deck_names(CARD_UNDER_TEST)
	t.eq(my_decks.size(), 1, "Aruru belongs to exactly one deck")
	var my_deck: String = str(my_decks[0])

	var other_casters: Array = []
	for card_name in cards.keys():
		var def: CardDef = cards[card_name]
		if str(card_name) == CARD_UNDER_TEST:
			continue
		if def.race == "Spellcaster" and _deck_names(str(card_name)).has(my_deck):
			other_casters.append(str(card_name))
	other_casters.sort()
	t.eq(other_casters.size(), 8,
		"eight other printed Spellcasters share Aruru's deck: %s" % str(other_casters))
	t.is_true(other_casters.has("Apprentice Magician"),
		"including Apprentice Magician, which this suite drives")

	var ced: CardDef = cards.get("Compulsory Evacuation Device", null)
	t.not_null(ced, "Compulsory Evacuation Device is printed")
	t.is_false(_deck_names("Compulsory Evacuation Device").has(my_deck),
		"and it is in the OTHER deck, so it is genuinely an opponent's card")
	t.is_true(ced.text.contains("Target 1 monster on the field"),
		"its printed text really targets a monster on the field")


static func _test_deterministic_replay(t: TestCase) -> void:
	t.start("the whole line replays from the recorded actions to an identical event log — "
		+ "no hidden randomness in either clause")
	var original := _board(14090)
	var engine: DuelEngine = original["engine"]
	var r := _run_targeting_line(engine, original, original["prey"])
	t.is_true(r["activated"], "the original line ran")
	TestFixtures.end_turn(engine)
	TestFixtures.advance_to_phase(engine, Enums.Phase.MAIN_1)

	var replay := _board(14090)
	var replay_engine: DuelEngine = replay["engine"]
	# The board fixture places the same cards in the same order from the same seed, so the
	# recorded actions from the point the two duels diverge are replayable verbatim.
	TestFixtures.give_to_hand(replay_engine, 1,
		_targeting_spell("Pointing Spell", []))
	var initial: int = replay_engine.log.actions.size()
	var replayed := 0
	for record in engine.log.actions.slice(initial):
		if replay_engine.submit_action(DuelAction.from_dict(record.action)):
			replayed += 1
	t.is_true(replayed > 0, "at least one recorded action was replayed")
	t.eq(replay_engine.log.entries.size(), engine.log.entries.size(),
		"the replayed duel produced the same number of log entries")
	t.eq(replay_engine.log.entries, engine.log.entries,
		"and an identical event log")

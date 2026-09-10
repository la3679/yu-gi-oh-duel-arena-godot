class_name ChainTests
extends RefCounted

## Chain construction / Spell Speed / resolution-order tests.
## Rules under test: RULES_SPEC.md 4 (from Official Rulebook v10 p.44-47, p.51).

const RESOLUTION_ORDER_KEY := "resolution_order"


static func run() -> TestCase:
	var t := TestCase.new("ChainTests")
	_test_spell_speed_response_legality(t)
	_test_chain_link_numbering(t)
	_test_reverse_resolution_order(t)
	_test_negate_activation_vs_effect(t)
	_test_counter_trap_only_answered_by_counter_trap(t)
	_test_chain_link_number_visible_at_resolution(t)
	_test_unimplemented_effect_fails_loudly(t)
	# --- effect SUBSTITUTION. RULES_SPEC.md 10.11, CARD_RULINGS.md R5. ---
	# This is the batch-18 unit A GATE, and it is deliberately here rather than in a suite
	# of its own: substitution is an operation on a Chain Link, and the Chain subsystem
	# already lives in this file. Written and green BEFORE `Fairy Tail - Sleeper` existed.
	_test_substitution_resolves_the_new_text(t)
	_test_substitution_is_neither_negation(t)
	_test_substitution_keeps_the_original_effect_on_record(t)
	_test_substituted_effect_resolves_under_the_substituted_cards_controller(t)
	_test_substitution_does_not_inherit_the_originals_targets(t)
	_test_substitution_keeps_resolution_order_and_position(t)
	_test_restriction_inside_the_effect_is_replaced_away(t)
	_test_restriction_that_is_not_a_card_effect_survives(t)
	_test_substitution_is_visible_to_a_replay(t)
	_test_substitution_refuses_impossible_cases(t)
	_test_activation_negated_link_is_substitutable_but_never_resolves(t)
	return t


static func _mk_state() -> GameState:
	var s := GameState.new(4242)
	s.turn_number = 1
	s.turn_player_id = 0
	s.phase = Enums.Phase.MAIN_1
	return s


static func _mk_card(s: GameState, name: String, owner: int) -> CardInstance:
	var d := CardDef.new()
	d.name = name
	d.category = Enums.Category.SPELL
	var c := CardInstance.new(d, owner)
	s.register_instance(c)
	return c


## An effect whose resolve() appends its label to a shared order log.
static func _mk_effect(id: String, spell_speed: int, order_log: Array) -> EffectDef:
	var e := EffectDef.new(id, "test clause for " + id)
	e.spell_speed = spell_speed
	e.resolve = func(ctx: EffectContext) -> void:
		order_log.append(id)
	return e


# --- RULES_SPEC.md 4.1: response requires SS >= 2 and >= previous link's SS ---
static func _test_spell_speed_response_legality(t: TestCase) -> void:
	t.start("spell speed response legality")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var log := []

	# Empty chain: anything may start it, including Spell Speed 1.
	t.is_true(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS1),
		"Spell Speed 1 may be Chain Link 1")

	var c1 := _mk_card(s, "Normal Spell", 0)
	cm.add_link(c1, _mk_effect("ss1", Enums.SpellSpeed.SS1, log), 0)

	# Against a Spell Speed 1 link.
	t.is_false(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS1),
		"Spell Speed 1 cannot respond to an existing link [S1 p.44]")
	t.is_true(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS2),
		"Spell Speed 2 may respond to Spell Speed 1")
	t.is_true(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS3),
		"Spell Speed 3 may respond to Spell Speed 1")

	# Against a Spell Speed 2 link.
	var c2 := _mk_card(s, "Normal Trap", 1)
	cm.add_link(c2, _mk_effect("ss2", Enums.SpellSpeed.SS2, log), 1)
	t.is_false(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS1),
		"Spell Speed 1 cannot respond to Spell Speed 2")
	t.is_true(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS2),
		"Spell Speed 2 may respond to Spell Speed 2")
	t.is_true(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS3),
		"Spell Speed 3 may respond to Spell Speed 2")


# --- RULES_SPEC.md 4.1: link numbering ---
static func _test_chain_link_numbering(t: TestCase) -> void:
	t.start("chain link numbering")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var log := []
	var a := cm.add_link(_mk_card(s, "A", 0), _mk_effect("a", 1, log), 0)
	var b := cm.add_link(_mk_card(s, "B", 1), _mk_effect("b", 2, log), 1)
	var c := cm.add_link(_mk_card(s, "C", 0), _mk_effect("c", 3, log), 0)
	t.eq(a.link_number, 1, "first activation is Chain Link 1")
	t.eq(b.link_number, 2, "second activation is Chain Link 2")
	t.eq(c.link_number, 3, "third activation is Chain Link 3")
	t.eq(cm.chain_size(), 3, "chain holds 3 links")


# --- RULES_SPEC.md 4.1 / [S1 p.46-47]: resolve highest link first ---
static func _test_reverse_resolution_order(t: TestCase) -> void:
	t.start("reverse chain resolution")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	cm.add_link(_mk_card(s, "Heavy", 0), _mk_effect("CL1", 1, order), 0)
	cm.add_link(_mk_card(s, "Roar", 1), _mk_effect("CL2", 2, order), 1)
	cm.add_link(_mk_card(s, "SevenTools", 0), _mk_effect("CL3", 3, order), 0)

	cm.resolve_chain()

	t.eq(order, ["CL3", "CL2", "CL1"],
		"chain resolves in reverse order, highest link first [S1 p.46-47]")
	t.eq(cm.chain_size(), 0, "chain is cleared after resolution")
	t.is_false(s.chain_is_resolving, "resolving flag cleared")


# --- Master prompt 18: negate activation vs negate effect are distinct ---
static func _test_negate_activation_vs_effect(t: TestCase) -> void:
	t.start("negate activation vs negate effect")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var negator := _mk_card(s, "Negator", 1)

	cm.add_link(_mk_card(s, "Target1", 0), _mk_effect("L1", 1, order), 0)
	cm.add_link(_mk_card(s, "Target2", 0), _mk_effect("L2", 2, order), 0)

	t.is_true(cm.negate_activation(1, negator), "activation negation applies to link 1")
	var l1 := cm.link_at(1)
	t.is_true(l1.activation_negated, "link 1 marked activation-negated")
	t.is_false(l1.effect_negated, "activation negation is not effect negation")
	t.is_false(l1.should_resolve(), "activation-negated link must not resolve")

	cm.resolve_chain()
	t.eq(order, ["L2"], "only the non-negated link resolved")

	# effect negation
	var s2 := _mk_state()
	var cm2 := ChainManager.new(s2)
	var order2 := []
	cm2.add_link(_mk_card(s2, "X", 0), _mk_effect("X1", 1, order2), 0)
	cm2.negate_effect(1, _mk_card(s2, "N", 1))
	var lx := cm2.link_at(1)
	t.is_true(lx.effect_negated, "link marked effect-negated")
	t.is_false(lx.activation_negated, "effect negation is not activation negation")
	cm2.resolve_chain()
	t.eq(order2, [], "effect-negated link did not resolve")


# --- [S1 p.45]: only Spell Speed 3 may respond to Spell Speed 3 ---
static func _test_counter_trap_only_answered_by_counter_trap(t: TestCase) -> void:
	t.start("counter trap response restriction")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var log := []
	cm.add_link(_mk_card(s, "Counter Trap", 0),
		_mk_effect("counter", Enums.SpellSpeed.SS3, log), 0)
	t.is_false(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS1),
		"Spell Speed 1 cannot answer a Counter Trap")
	t.is_false(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS2),
		"Spell Speed 2 cannot answer a Counter Trap [S1 p.45]")
	t.is_true(cm.can_respond_with_spell_speed(Enums.SpellSpeed.SS3),
		"only Spell Speed 3 may answer a Counter Trap")


# --- CARD_RULINGS.md R4: Chain Detonation / Chain Healing read their link number ---
static func _test_chain_link_number_visible_at_resolution(t: TestCase) -> void:
	t.start("chain link number readable at resolution")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var seen := []
	var e := EffectDef.new("reads_link", "If this card was activated as Chain Link 2 or 3...")
	e.spell_speed = Enums.SpellSpeed.SS2
	e.resolve = func(ctx: EffectContext) -> void:
		seen.append(ctx.link.link_number)

	var filler := EffectDef.new("filler", "filler")
	filler.spell_speed = Enums.SpellSpeed.SS1
	filler.resolve = func(_ctx: EffectContext) -> void: pass

	cm.add_link(_mk_card(s, "First", 0), filler, 0)
	cm.add_link(_mk_card(s, "Chain Detonation", 1), e, 1)
	cm.resolve_chain()

	t.eq(seen, [2], "effect saw its own Chain Link number (2) at resolution")


# --- Master prompt 67: an unimplemented effect must fail loudly, never be skipped ---
static func _test_unimplemented_effect_fails_loudly(t: TestCase) -> void:
	t.start("unimplemented effect fails loudly")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var e := EffectDef.new("no_resolve", "clause with no implementation")
	e.spell_speed = Enums.SpellSpeed.SS1
	# deliberately no resolve callable
	cm.add_link(_mk_card(s, "Broken", 0), e, 0)
	cm.resolve_chain()

	var flagged := false
	for ev in s.events:
		if ev.kind == GameEvent.Kind.CHAIN_LINK_RESOLVED and ev.data.get("error", false):
			flagged = true
	t.is_true(flagged,
		"missing resolve() must emit an error event, not be silently ignored")


# ===========================================================================
# Effect SUBSTITUTION — "the activated effect BECOMES '…'".
# RULES_SPEC.md 10.11, CARD_RULINGS.md R5. The batch-18 unit A gate.
# ===========================================================================
#
# Substitution is a THIRD operation beside the two negations above, and every test here
# exists because collapsing it into one of them gets an official ruling wrong. The two
# survival tests are the pair fid 8714 / fid 19695 and they must both stay: an
# implementation that gets one right and the other wrong is the expected failure mode.


## A Normal Spell whose CARD ACTIVATION effect appends to `order_log` when it resolves.
## `CARD_ACTIVATION` matters: `_resolve_link()` gates the activation-condition pass on it.
static func _mk_normal_spell_activation(s: GameState, name: String, owner: int,
		order_log: Array, label: String) -> Array:
	var d := CardDef.new()
	d.name = name
	d.category = Enums.Category.SPELL
	d.st_kind = Enums.STKind.NORMAL_SPELL
	var e := EffectDef.new("activate_" + label, "printed text of " + name)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append(label)
	d.effects = [e]
	var c := CardInstance.new(d, owner)
	s.register_instance(c)
	return [c, e]


## The replacement text a substituting card installs.
static func _mk_replacement(label: String, log: Array,
		controller_log: Array = []) -> EffectDef:
	var r := EffectDef.new("becomes_" + label, "the activated effect becomes " + label)
	r.of_type(Enums.EffectType.TRIGGER)
	r.mandatory()
	r.resolve = func(ctx: EffectContext) -> void:
		log.append(label)
		controller_log.append(ctx.controller_id)
	return r


# --- the new text resolves, and the old one does not ---
static func _test_substitution_resolves_the_new_text(t: TestCase) -> void:
	t.start("substitution resolves the NEW text")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "Opponent Normal Spell", 1, order, "PRINTED")
	var spell: CardInstance = pair[0]
	cm.add_link(spell, pair[1], 1)
	var substituter := _mk_card(s, "Substituter", 0)

	t.is_true(cm.substitute_link_effect(1, _mk_replacement("REPLACED", order),
		substituter), "the substitution is accepted")
	cm.resolve_chain()

	t.eq(order, ["REPLACED"],
		"the link resolved the REPLACEMENT text — and only it")
	t.is_false(order.has("PRINTED"),
		"the card's own printed effect did not resolve")


# --- it is neither negation, and the card still counts as having resolved ---
static func _test_substitution_is_neither_negation(t: TestCase) -> void:
	t.start("substitution is NEITHER negation")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "Normal Spell", 1, order, "PRINTED")
	cm.add_link(pair[0], pair[1], 1)
	cm.substitute_link_effect(1, _mk_replacement("REPLACED", order),
		_mk_card(s, "Substituter", 0))

	var link := cm.link_at(1)
	t.is_true(link.is_substituted(), "the link reports itself substituted")
	t.is_false(link.activation_negated,
		"substitution does NOT negate the activation — the card was still activated")
	t.is_false(link.effect_negated,
		"substitution does NOT negate the effect — an effect still applies")
	t.is_false(link.is_negated(), "the link is not negated in either sense")
	t.is_true(link.should_resolve(),
		"a substituted link resolves as normally as any other")

	cm.resolve_chain()
	t.is_true(link.resolved, "the link resolved")

	# The control that makes the four assertions above mean something: a link that IS
	# negated behaves differently, so "not negated" is not passing vacuously.
	var s2 := _mk_state()
	var cm2 := ChainManager.new(s2)
	var order2 := []
	var pair2 := _mk_normal_spell_activation(s2, "Normal Spell", 1, order2, "PRINTED")
	cm2.add_link(pair2[0], pair2[1], 1)
	cm2.negate_effect(1, _mk_card(s2, "Negator", 0))
	t.is_false(cm2.link_at(1).should_resolve(),
		"CONTROL: an effect-negated link does not resolve")


# --- `link.effect` is the record of what ACTIVATED and must survive ---
static func _test_substitution_keeps_the_original_effect_on_record(t: TestCase) -> void:
	t.start("substitution keeps the ORIGINAL effect on record")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "Normal Spell", 1, order, "PRINTED")
	var printed: EffectDef = pair[1]
	cm.add_link(pair[0], printed, 1)
	var replacement := _mk_replacement("REPLACED", order)
	cm.substitute_link_effect(1, replacement, _mk_card(s, "Substituter", 0))

	var link := cm.link_at(1)
	t.eq(link.effect.effect_id, printed.effect_id,
		"`effect` still names what the card activated")
	t.eq(link.substituted_effect.effect_id, replacement.effect_id,
		"`substituted_effect` names what it will resolve")
	t.eq(link.resolving_effect().effect_id, replacement.effect_id,
		"`resolving_effect()` is the replacement")
	t.eq(link.effect.effect_type, Enums.EffectType.CARD_ACTIVATION,
		"the recorded activation is still a CARD_ACTIVATION — which is what the "
		+ "activation-condition pass gates on")


# --- R5 Part B: the replacement is the SUBSTITUTED card's effect ---
static func _test_substituted_effect_resolves_under_the_substituted_cards_controller(
		t: TestCase) -> void:
	t.start("the replacement resolves under the SUBSTITUTED card's controller")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var controllers := []
	# Player 1 activated the Normal Spell; player 0 substitutes it.
	var pair := _mk_normal_spell_activation(s, "Opponent Normal Spell", 1, order, "PRINTED")
	cm.add_link(pair[0], pair[1], 1)
	cm.substitute_link_effect(1, _mk_replacement("REPLACED", order, controllers),
		_mk_card(s, "Substituter", 0))
	cm.resolve_chain()

	t.eq(controllers, [1],
		"the replacement resolved as PLAYER 1's effect — the controller of the card that "
		+ "was substituted, NOT the player who substituted it. This is R5 Part B and it "
		+ "is why `Fairy Tail - Sleeper`'s replacement hits Sleeper's OWN side.")


# --- targets belong to the effect that declared them ---
static func _test_substitution_does_not_inherit_the_originals_targets(
		t: TestCase) -> void:
	t.start("the replacement does not inherit the original's targets")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var seen_targets := []
	var victim := _mk_card(s, "Some Target", 1)
	var pair := _mk_normal_spell_activation(s, "Targeting Spell", 1, order, "PRINTED")
	cm.add_link(pair[0], pair[1], 1, [victim.id])

	var r := EffectDef.new("becomes_untargeted", "the replacement targets nothing")
	r.of_type(Enums.EffectType.TRIGGER)
	r.mandatory()
	r.resolve = func(ctx: EffectContext) -> void:
		seen_targets.append(ctx.chosen_target_ids.duplicate())
	cm.substitute_link_effect(1, r, _mk_card(s, "Substituter", 0))

	t.eq(cm.link_at(1).target_ids, [victim.id],
		"the ACTIVATION record still says what was targeted")
	cm.resolve_chain()
	t.eq(seen_targets, [[]],
		"the replacement resolved with NO targets — R5 Part C: it chooses at resolution "
		+ "and targets nothing, so it must never see a card its own text never named")


# --- the link keeps its place on the Chain ---
static func _test_substitution_keeps_resolution_order_and_position(
		t: TestCase) -> void:
	t.start("a substituted link keeps its Chain position")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "CL1 Spell", 1, order, "CL1_PRINTED")
	cm.add_link(pair[0], pair[1], 1)
	cm.add_link(_mk_card(s, "CL2", 0), _mk_effect("CL2", Enums.SpellSpeed.SS2, order), 0)
	cm.add_link(_mk_card(s, "CL3", 1), _mk_effect("CL3", Enums.SpellSpeed.SS2, order), 1)
	cm.substitute_link_effect(1, _mk_replacement("CL1_REPLACED", order),
		_mk_card(s, "Substituter", 0))
	cm.resolve_chain()

	t.eq(order, ["CL3", "CL2", "CL1_REPLACED"],
		"the substituted link still resolved LAST, in its own Chain Link 1 position, "
		+ "with the replacement text")


# --- fid 8714: a restriction INSIDE the resolving effect is replaced away ---
static func _test_restriction_inside_the_effect_is_replaced_away(t: TestCase) -> void:
	t.start("fid 8714: a restriction INSIDE the effect is replaced away")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var applied := []
	# The shape of 「埋葬されし生け贄」: the restriction is applied by the effect's own
	# `resolve`, so it is part of what resolves.
	var d := CardDef.new()
	d.name = "Restriction In Effect"
	d.category = Enums.Category.SPELL
	d.st_kind = Enums.STKind.NORMAL_SPELL
	var e := EffectDef.new("activate_with_inner_restriction", "… and you cannot Special "
		+ "Summon for the rest of this turn")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.resolve = func(_ctx: EffectContext) -> void:
		applied.append("RESTRICTION")
	d.effects = [e]
	var card := CardInstance.new(d, 1)
	s.register_instance(card)

	# CONTROL: without substitution the restriction IS applied.
	var cm_control := ChainManager.new(s)
	cm_control.add_link(card, e, 1)
	cm_control.resolve_chain()
	t.eq(applied, ["RESTRICTION"],
		"CONTROL: unsubstituted, the in-effect restriction is applied")

	applied.clear()
	var s2 := _mk_state()
	var cm2 := ChainManager.new(s2)
	var card2 := CardInstance.new(d, 1)
	s2.register_instance(card2)
	cm2.add_link(card2, e, 1)
	cm2.substitute_link_effect(1, _mk_replacement("REPLACED", []),
		_mk_card(s2, "Substituter", 0))
	cm2.resolve_chain()

	t.eq(applied, [],
		"substituted, the in-effect restriction was REPLACED AWAY and never applied "
		+ "— official Q&A fid 8714")
	# `cm` is used only to keep the local from being flagged unused by a future reader.
	t.eq(cm.chain_size(), 0, "the unused manager holds no links")


# --- fid 19695: a restriction that is NOT a card effect survives ---
static func _test_restriction_that_is_not_a_card_effect_survives(t: TestCase) -> void:
	t.start("fid 19695: a restriction that is NOT a card effect SURVIVES")
	var s := _mk_state()
	var applied := []
	# The shape of 「強欲で謙虚な壺」: the restriction is an ACTIVATION CONDITION clause with
	# an `activation_confirmed` callable, applied because the card was ACTIVATED. It is
	# 「カードの効果の扱いではありません」 and so is not part of what resolves.
	var d := CardDef.new()
	d.name = "Restriction On Activation"
	d.category = Enums.Category.SPELL
	d.st_kind = Enums.STKind.NORMAL_SPELL
	var main := EffectDef.new("activate_main", "draw …")
	main.of_type(Enums.EffectType.CARD_ACTIVATION)
	main.resolve = func(_ctx: EffectContext) -> void:
		applied.append("MAIN")
	var cond := EffectDef.new(ActivationRules.ACTIVATION_CONDITION_EFFECT_ID,
		"the turn you activate this card you cannot Special Summon")
	cond.activation_confirmed = func(_ctx: EffectContext) -> void:
		applied.append("RESTRICTION")
	d.effects = [main, cond]

	# CONTROL: unsubstituted, both fire.
	var card := CardInstance.new(d, 1)
	s.register_instance(card)
	var cm := ChainManager.new(s)
	cm.add_link(card, main, 1)
	cm.resolve_chain()
	t.eq(applied, ["RESTRICTION", "MAIN"],
		"CONTROL: unsubstituted, the activation restriction and the effect both apply")

	applied.clear()
	var s2 := _mk_state()
	var card2 := CardInstance.new(d, 1)
	s2.register_instance(card2)
	var cm2 := ChainManager.new(s2)
	cm2.add_link(card2, main, 1)
	cm2.substitute_link_effect(1, _mk_replacement("REPLACED", applied),
		_mk_card(s2, "Substituter", 0))
	cm2.resolve_chain()

	t.is_true(applied.has("RESTRICTION"),
		"the ACTIVATION restriction still applied through the substitution — official "
		+ "Q&A fid 19695: 「カードの効果の扱いではありません」")
	t.is_false(applied.has("MAIN"),
		"but the card's own resolving effect did not")
	t.is_true(applied.has("REPLACED"),
		"and the replacement resolved in its place")
	t.eq(applied, ["RESTRICTION", "REPLACED"],
		"the restriction runs BEFORE the replacement resolves, exactly as it runs before "
		+ "an unsubstituted effect")


# --- a replay must be able to see it ---
static func _test_substitution_is_visible_to_a_replay(t: TestCase) -> void:
	t.start("substitution is visible to a replay")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "Normal Spell", 1, order, "PRINTED")
	var printed: EffectDef = pair[1]
	cm.add_link(pair[0], printed, 1)
	var substituter := _mk_card(s, "Substituter", 0)
	var replacement := _mk_replacement("REPLACED", order)
	cm.substitute_link_effect(1, replacement, substituter)

	var ev: GameEvent = null
	for e in s.events:
		if e.kind == GameEvent.Kind.CHAIN_LINK_EFFECT_SUBSTITUTED:
			ev = e
	t.is_true(ev != null, "a CHAIN_LINK_EFFECT_SUBSTITUTED event was emitted")
	if ev != null:
		t.eq(int(ev.data.get("link_number", -1)), 1, "the event names the link")
		t.eq(str(ev.data.get("from_effect_id", "")), printed.effect_id,
			"the event records what the card was going to resolve")
		t.eq(str(ev.data.get("to_effect_id", "")), replacement.effect_id,
			"the event records what it will resolve instead")
		t.eq(int(ev.data.get("by_card_id", -1)), substituter.id,
			"the event records which card did it")

	var vis := cm.link_at(1).to_visible_dict(0)
	t.is_true(bool(vis.get("substituted", false)),
		"the Chain projection says the link is substituted")
	t.eq(str(vis.get("substituted_effect_id", "")), replacement.effect_id,
		"the Chain projection names the replacement")

	cm.resolve_chain()
	var resolved_ev: GameEvent = null
	for e in s.events:
		if e.kind == GameEvent.Kind.CHAIN_LINK_RESOLVED:
			resolved_ev = e
	t.is_true(resolved_ev != null, "the link emitted CHAIN_LINK_RESOLVED")
	if resolved_ev != null:
		t.is_true(bool(resolved_ev.data.get("resolved", false)),
			"the card RESOLVED — substitution is not negation")
		t.is_true(bool(resolved_ev.data.get("substituted", false)),
			"and the resolution event says it resolved something else")
		t.eq(str(resolved_ev.data.get("resolved_effect_id", "")), replacement.effect_id,
			"naming exactly what it resolved")


# --- every impossible case is refused loudly ---
static func _test_substitution_refuses_impossible_cases(t: TestCase) -> void:
	t.start("substitution refuses impossible cases")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "Normal Spell", 1, order, "PRINTED")
	cm.add_link(pair[0], pair[1], 1)
	var by := _mk_card(s, "Substituter", 0)

	t.is_false(cm.substitute_link_effect(99, _mk_replacement("X", order), by),
		"a link that is not on the Chain is refused")
	t.is_false(cm.substitute_link_effect(1, null, by),
		"a null replacement is refused")

	t.is_true(cm.substitute_link_effect(1, _mk_replacement("FIRST", order), by),
		"the first substitution is accepted")
	t.is_false(cm.substitute_link_effect(1, _mk_replacement("SECOND", order), by),
		"a SECOND substitution of the same link is refused rather than silently "
		+ "overwriting the first")

	cm.resolve_chain()
	t.eq(order, ["FIRST"], "the first substitution is the one that resolved")

	# A link that has already resolved.
	var s2 := _mk_state()
	var cm2 := ChainManager.new(s2)
	var order2 := []
	var pair2 := _mk_normal_spell_activation(s2, "Normal Spell", 1, order2, "PRINTED")
	var link2 := cm2.add_link(pair2[0], pair2[1], 1)
	link2.resolved = true
	t.is_false(cm2.substitute_link_effect(1, _mk_replacement("TOO_LATE", order2),
		_mk_card(s2, "Substituter", 0)),
		"a link that has already resolved is refused")


# --- an activation-negated link may still be substituted, and still never resolves ---
static func _test_activation_negated_link_is_substitutable_but_never_resolves(
		t: TestCase) -> void:
	t.start("an activation-negated link is substitutable but never resolves")
	var s := _mk_state()
	var cm := ChainManager.new(s)
	var order := []
	var pair := _mk_normal_spell_activation(s, "Normal Spell", 1, order, "PRINTED")
	cm.add_link(pair[0], pair[1], 1)
	cm.negate_activation(1, _mk_card(s, "Negator", 0))

	t.is_true(cm.substitute_link_effect(1, _mk_replacement("REPLACED", order),
		_mk_card(s, "Substituter", 0)),
		"substituting a link whose ACTIVATION was negated is accepted — it is not the "
		+ "substitution's business to know, and refusing would hide the ordering")
	cm.resolve_chain()
	t.eq(order, [],
		"but nothing resolved: the activation negation still wins, so neither the "
		+ "printed text nor the replacement ran")

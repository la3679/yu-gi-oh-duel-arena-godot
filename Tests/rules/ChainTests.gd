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

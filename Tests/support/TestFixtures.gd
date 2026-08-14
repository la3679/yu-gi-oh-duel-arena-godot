class_name TestFixtures
extends RefCounted

## Shared builders for the headless rules tests. Master prompt 64.
##
## Tests build synthetic cards on purpose: a rules test must prove that the ENGINE is
## right, not that one particular printed card happens to work. The real 77 cards are
## exercised separately by the per-card suites in Phase 5.

const DECK_SIZE := 40


# ---------------------------------------------------------------------------
# Card definitions
# ---------------------------------------------------------------------------

static func monster(name: String, level: int = 4, atk: int = 1000, def_: int = 1000,
		attribute: String = "LIGHT") -> CardDef:
	var d := CardDef.new()
	d.name = name
	d.official_name = name
	d.category = Enums.Category.MONSTER
	d.level = level
	d.base_atk = atk
	d.base_def = def_
	d.attribute = attribute
	d.race = "Warrior"
	d.is_normal_monster = true
	d.text = "Test monster."
	return d


static func spell(name: String, kind: Enums.STKind = Enums.STKind.NORMAL_SPELL) -> CardDef:
	var d := CardDef.new()
	d.name = name
	d.official_name = name
	d.category = Enums.Category.SPELL
	d.st_kind = kind
	d.spell_speed = Enums.spell_speed_for_st(kind)
	d.text = "Test spell."
	return d


static func trap(name: String, kind: Enums.STKind = Enums.STKind.NORMAL_TRAP) -> CardDef:
	var d := CardDef.new()
	d.name = name
	d.official_name = name
	d.category = Enums.Category.TRAP
	d.st_kind = kind
	d.spell_speed = Enums.spell_speed_for_st(kind)
	d.text = "Test trap."
	return d


## Attach an effect to a definition, wiring the back-reference the registry normally sets.
static func with_effect(d: CardDef, e: EffectDef) -> CardDef:
	e.card_name = d.name
	d.effects.append(e)
	if d.category == Enums.Category.MONSTER:
		d.is_normal_monster = false
		d.is_effect_monster = true
	return d


## An effect that appends `tag` to `order_log` when it resolves. Used to observe the
## order in which links actually resolved.
static func logging_effect(effect_id: String, tag: String, order_log: Array) -> EffectDef:
	var e := EffectDef.new(effect_id, "test clause " + effect_id)
	e.resolve = func(_ctx: EffectContext) -> void:
		order_log.append(tag)
	return e


## The activation of a Spell/Trap card itself.
static func card_activation(effect_id: String, spell_speed: int,
		order_log: Array, tag: String = "") -> EffectDef:
	var e := logging_effect(effect_id, tag if tag != "" else effect_id, order_log)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = spell_speed
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN, Enums.ActivationLocation.FIELD_FACE_UP]
	return e


## A Trigger Effect that fires off `events`.
static func trigger_effect(effect_id: String, events: Array, order_log: Array,
		tag: String = "", mandatory: bool = false) -> EffectDef:
	var e := logging_effect(effect_id, tag if tag != "" else effect_id, order_log)
	e.of_type(Enums.EffectType.TRIGGER)
	e.trigger_events = events
	if mandatory:
		e.mandatory()
	return e


## A Spell Speed 2 Trap that does exactly one thing to one named card when it resolves.
##
## Tests need this more often than it looks. The engine does not pause when nobody holds a
## legal response — it auto-passes and resolves a whole Chain inside one `submit_action()`
## — so a real fast effect is the only way to change the board BETWEEN an activation and
## its resolution. It is also the only way to make a destruction travel through the timing
## machine, which is what a trigger effect needs in order to be collected at all: a test
## that calls `GameState.destroy()` directly changes the board without ever reaching a
## trigger check.
##
## `mode` is "destroy" | "banish" | "bounce" | "flip_face_down" | "send_to_gy".
##
## "send_to_gy" exists because `GameState.destroy()` correctly refuses a card that is not on
## the field, so it cannot move a card out of the HAND. A clause keyed on "this face-up card
## ON THE FIELD is sent to the GY" needs a card reaching the Graveyard from somewhere else
## in order to be tested negatively.
static func interferer(card_name: String, victim: CardInstance, mode: String) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("interfere", "Test: %s one specific card." % mode)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.spell_speed = Enums.SpellSpeed.SS2
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		match mode:
			"destroy":
				ctx.state.destroy(victim, Enums.MoveReason.DESTROYED_BY_EFFECT,
					ctx.source.id)
			"banish":
				ctx.state.move_card(victim, Enums.Zone.BANISHED,
					Enums.MoveReason.BANISHED, {"source_id": ctx.source.id})
			"bounce":
				ctx.state.move_card(victim, Enums.Zone.HAND,
					Enums.MoveReason.RETURNED_TO_HAND, {"source_id": ctx.source.id})
			"send_to_gy":
				ctx.state.move_card(victim, Enums.Zone.GRAVEYARD,
					Enums.MoveReason.SENT_TO_GY_BY_EFFECT, {"source_id": ctx.source.id})
			"flip_face_down":
				ctx.state.set_battle_position(victim, Enums.Position.FACE_DOWN_DEFENSE,
					true, ctx.source.id)
			_:
				push_error("TestFixtures.interferer: unknown mode '%s'" % mode)
	return with_effect(d, e)


## A monster whose FLIP effect draws 1 card when it is turned face-up.
##
## The draw is the observable: a test can assert on the owner's hand size to tell "the Flip
## effect fired" from "the Flip effect did not fire", which is exactly the question a
## negated Flip Summon raises. A FLIP effect keys on `CARD_FLIPPED_FACE_UP` rather than on
## `FLIP_SUMMON_SUCCEEDED`, because being flipped by an attack or by a card effect triggers
## it too. RULES_SPEC.md 5.4 [S1 p.28].
static func flip_effect_monster(card_name: String, level: int = 4, atk: int = 1000,
		def_: int = 1000) -> CardDef:
	var d := monster(card_name, level, atk, def_)
	var e := EffectDef.new("test_flip", "FLIP: Draw 1 card.")
	e.of_type(Enums.EffectType.FLIP)
	# MANDATORY, so the draw is a deterministic signal rather than a consent question the
	# ScriptedController would answer "no" to by default. The V1 pool's real FLIP effects
	# (the three Charmers) are mandatory too — none of them says "you can".
	e.mandatory()
	e.trigger_events = [GameEvent.Kind.CARD_FLIPPED_FACE_UP]
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# A FLIP effect triggered by an attack becomes a Chain Link inside the Damage Step.
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER
	e.condition = func(ctx: EffectContext) -> bool:
		# It is THIS card being flipped that matters, not any card being flipped.
		var ev: GameEvent = ctx.trigger_event
		return ev != null and int(ev.data.get("card_id", -1)) == ctx.source.id
	e.resolve = func(ctx: EffectContext) -> void:
		ctx.state.draw(ctx.source.controller_id, 1)
	return with_effect(d, e)


## A monster that declares it can hold `kind` counters — the `COUNTER_CAPACITY_EFFECT_ID`
## rules query `GameState.can_place_counter()` asks.
##
## Synthetic on purpose: **no card in the V1 pool declares Spell Counter capacity**, so a
## test that proves `Apprentice Magician`'s first clause works at all needs a card that does.
## The negative direction is proved against the real pool instead.
static func counter_holder(card_name: String, kind: String,
		level: int = 4, atk: int = 1000) -> CardDef:
	var d := monster(card_name, level, atk, 1000)
	var e := EffectDef.new(GameState.COUNTER_CAPACITY_EFFECT_ID,
		"Test: this card can have %s placed on it." % kind)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.condition = func(ctx: EffectContext) -> bool:
		return str(ctx.params.get("counter", "")) == kind
	return with_effect(d, e)


## An Equip Spell that gives its equipped monster `atk_bonus` ATK. The V1 pool contains
## **no Equip Spells at all**, so `Fairy Tail - Rella`'s second clause can only be exercised
## against a synthetic one.
static func equip_spell(card_name: String, atk_bonus: int = 0) -> CardDef:
	var d := spell(card_name, Enums.STKind.EQUIP_SPELL)
	if atk_bonus == 0:
		return d
	var e := EffectDef.new("equip_atk_bonus",
		"Test: the equipped monster gains %d ATK." % atk_bonus)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equipped_host(ctx)
		if host != null:
			ContinuousEffects.add_atk(ctx.source, host, atk_bonus)
	return with_effect(d, e)


## A synthetic Spell Speed 3 Counter Trap that negates the activation of the Chain Link
## directly below it and destroys that card — the `Champion's Vigilance` shape, without the
## dependency. A per-card suite that needs "and then it was negated" uses this so it tests
## its own card rather than another one.
static func activation_negator(card_name: String) -> CardDef:
	var d := trap(card_name, Enums.STKind.COUNTER_TRAP)
	var e := EffectDef.new("negate_activation", "Test: negate that activation and destroy it.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS3)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.damage_step(Enums.DamageStepPermission.UNTIL_DAMAGE_CALC)
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.spell_trap_activation_below(ctx) != null
	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.negate_activation_and_destroy(ctx)
	return with_effect(d, e)


## A synthetic Spell Speed 2 Trap that negates the EFFECT — not the activation — of the
## Chain Link directly below it, and destroys nothing.
##
## Deliberately the counterpart of `activation_negator()`, because the two are genuinely
## different and a card must be tested against both [master prompt 18]:
##
##   * negating the ACTIVATION means the card was not successfully activated;
##   * negating the EFFECT means the activation happened — the cost stays paid and anything
##     that watched the activation still saw it — but nothing the effect would do happens.
##
## A card whose cost is paid at activation must survive BOTH with the cost still spent, and
## a card that reads its own Chain Link position must still have been activated at that
## position. Neither could be asserted before this fixture existed.
static func effect_negator(card_name: String) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("negate_effect", "Test: negate that effect.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.spell_trap_activation_below(ctx) != null
	e.resolve = func(ctx: EffectContext) -> void:
		var link_number: int = ctx.link.link_number if ctx.link != null else 0
		var below := EffectPrimitives.spell_trap_activation_below(ctx, link_number)
		if below == null or ctx.engine == null or ctx.engine.chain == null:
			return
		ctx.engine.chain.negate_effect(below.link_number, ctx.source)
	return with_effect(d, e)


## The same as `effect_negator()`, but able to negate ANY Chain Link below it — including a
## monster's Ignition or Trigger Effect, which `effect_negator()` cannot reach because
## `spell_trap_activation_below()` deliberately answers only the narrower Spell/Trap
## question. `Judge of the Ice Barrier`'s two Ignition Effects are the first clauses in the
## pool that need it.
static func any_effect_negator(card_name: String) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("negate_any_effect", "Test: negate whatever is below.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.chain_link_below(ctx) != null
	e.resolve = func(ctx: EffectContext) -> void:
		var link_number: int = ctx.link.link_number if ctx.link != null else 0
		var below := EffectPrimitives.chain_link_below(ctx, link_number)
		if below == null or ctx.engine == null or ctx.engine.chain == null:
			return
		ctx.engine.chain.negate_effect(below.link_number, ctx.source)
	return with_effect(d, e)


## A Counter Trap that negates a pending Summon and does NOT destroy the monster.
##
## Deliberately weaker than `Champion's Vigilance`: "Negate the Summon" on its own is what
## the RULES do, and "and if you do, destroy that card" is an extra the card adds. Keeping a
## fixture without the destruction is what lets a test see where a negated monster ENDS UP
## — back where it came from for a Normal/Special Summon, and still face-down in its Monster
## Zone for a Flip Summon. RULES_SPEC.md 5.4.
static func summon_negator(card_name: String) -> CardDef:
	var d := trap(card_name, Enums.STKind.COUNTER_TRAP)
	var e := EffectDef.new("negate_summon", "Test: negate that Summon.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS3)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.trigger_events = [
		GameEvent.Kind.NORMAL_SUMMON_DECLARED,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED,
		GameEvent.Kind.FLIP_SUMMON_DECLARED,
	]
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.summon_is_pending(ctx) != null
	e.resolve = func(ctx: EffectContext) -> void:
		if ctx.engine != null:
			ctx.engine.negate_pending_summon(ctx.source.id)
	return with_effect(d, e)


# ---------------------------------------------------------------------------
# Attack restriction / attack negation. RULES_SPEC.md 6.1, 6.3.
# ---------------------------------------------------------------------------

## A face-up MONSTER whose continuous clause forbids one player from declaring attacks —
## the `Swords of Revealing Light` restriction without the Spell's activation and lifetime.
##
## A monster rather than a Spell on purpose: the gate has to watch the restriction switch off
## when its source is flipped face-down, negated, leaves the field or changes control, and a
## monster can be put into every one of those states directly. Swords' own lifetime is Swords'
## business and is tested in its own suite.
##
## `whose` is "opponent" or "self" so the gate can prove the restriction is AIMED. A fixture
## that always hit the other side would pass against an implementation that ignored the
## player id entirely.
static func attack_lock_monster(card_name: String, whose: String = "opponent",
		atk: int = 1000) -> CardDef:
	var d := monster(card_name, 4, atk, 1000)
	var e := EffectDef.new("attack_lock",
		"Test: your %s's monsters cannot declare an attack." % whose)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		if whose == "self":
			EffectPrimitives.restrict_attacks_of(ctx, ctx.controller_id)
		else:
			EffectPrimitives.restrict_opponent_attacks(ctx)
	return with_effect(d, e)


## A face-up MONSTER whose continuous clause forbids one player from activating a CATEGORY of
## card during a PHASE — the `Mirage Dragon` restriction, parameterised.
##
## Every part is an argument for the same reason `trap_monster()` parameterises its type
## line: a fixture hard-wired to "Traps, Battle Phase, opponent" would pass against an
## implementation that ignored all three. `phase` may be null, meaning every phase.
static func activation_lock_monster(card_name: String,
		category: Enums.Category = Enums.Category.TRAP,
		phase = Enums.Phase.BATTLE, whose: String = "opponent") -> CardDef:
	var d := monster(card_name, 4, 1600, 600)
	var e := EffectDef.new("activation_lock",
		"Test: your %s cannot activate cards of category %d." % [whose, int(category)])
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.apply_continuous = func(ctx: EffectContext) -> void:
		var pid: int = ctx.controller_id if whose == "self" else ctx.opponent_id()
		EffectPrimitives.forbid_card_activation(ctx, pid, category, phase)
	return with_effect(d, e)


## A Set Trap that NEGATES a declared attack, offered in the response window the declaration
## opens. The `Maiden with Eyes of Blue` mechanism without the card.
##
## Deliberately a Spell/Trap CARD activation rather than a monster Trigger Effect: it is
## driven from `get_legal_responses()` and so the test can choose whether to use it, which is
## what lets the same board be run with and without the negation as a controlled pair.
##
## `only_when_targeting` restricts it to an attack aimed at a specific monster, so the gate
## can build the "the attack was declared against ME" shape without a real card.
static func attack_negator(card_name: String, only_when_targeting: Array = []) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("negate_attack", "Test: negate that attack.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.trigger_events = [GameEvent.Kind.ATTACK_DECLARED]
	e.condition = func(ctx: EffectContext) -> bool:
		if ctx.state.current_attacker == null:
			return false
		if only_when_targeting.is_empty():
			return true
		var wanted = only_when_targeting[0]
		return EffectPrimitives.is_current_attack_target(ctx, wanted)
	e.resolve = func(ctx: EffectContext) -> void:
		EffectPrimitives.negate_declared_attack(ctx)
	return with_effect(d, e)


## A face-up card that counts one player's turns and destroys itself when the count reaches
## `limit`, during that player's End Phase — the `Swords of Revealing Light` lifetime, with
## the count and the counted player as arguments.
##
## A CONTINUOUS clause with `respond_to_event`, not a Trigger Effect, and that is the point:
## "you must destroy it during the End Phase of your opponent's 3rd turn" puts no link on the
## Chain and is never offered as a choice. `counted` is "opponent" or "self".
static func turn_counting_card(card_name: String, limit: int = 3,
		counted: String = "opponent",
		kind: Enums.STKind = Enums.STKind.NORMAL_SPELL) -> CardDef:
	var d := spell(card_name, kind)
	var e := EffectDef.new("turn_countdown",
		"Test: destroy this card during the End Phase of the %s's %d turn(s)."
		% [counted, limit])
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.trigger_events = [GameEvent.Kind.PHASE_CHANGED]
	e.condition = func(ctx: EffectContext) -> bool:
		var ev := ctx.trigger_event
		if ev == null or int(ev.data.get("to", -1)) != int(Enums.Phase.END):
			return false
		var counted_pid: int = ctx.controller_id if counted == "self" else ctx.opponent_id()
		return ctx.state.turn_player_id == counted_pid
	e.respond_to_event = func(ctx: EffectContext) -> void:
		var counted_pid: int = ctx.controller_id if counted == "self" else ctx.opponent_id()
		var n := EffectPrimitives.count_turn_for(ctx, "turn_countdown", counted_pid)
		if n >= limit:
			ctx.state.destroy(ctx.source, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)
	return with_effect(d, e)


# ---------------------------------------------------------------------------
# Trap Monsters. RULES_SPEC.md 5.8.
# ---------------------------------------------------------------------------

## A synthetic Trap Card that Special Summons ITSELF from the Graveyard as a monster.
##
## Deliberately an IGNITION effect rather than the printed card's direct-attack trigger: the
## gate is about what a Trap Monster IS, not about when one particular card is allowed to
## become one, and an Ignition can be driven straight from an open game state. The trigger
## timing is `The Phantom Knights of Shadow Veil`'s own business and is tested in its suite.
##
## Every part of the type line is a parameter because the gate has to prove the runtime
## identity is really carried rather than hard-coded — a fixture that could only ever be
## Warrior/DARK/Level 4 would pass against an implementation that ignored its arguments.
static func trap_monster(card_name: String, race: String = "Warrior",
		attribute: String = "DARK", level: int = 4, atk: int = 0, def_: int = 300,
		is_normal: bool = true, treated_as_original_type: bool = false,
		position: Enums.Position = Enums.Position.FACE_UP_DEFENSE,
		banish_when_leaving: bool = false) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("summon_self_as_trap_monster",
		"Test: Special Summon this card as a monster (%s/%s/Level %d/ATK %d/DEF %d)."
		% [race, attribute, level, atk, def_])
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.GRAVEYARD])

	e.condition = func(ctx: EffectContext) -> bool:
		return ctx.source.zone == Enums.Zone.GRAVEYARD and ctx.me().has_free_monster_zone()

	e.resolve = func(ctx: EffectContext) -> void:
		var identity := EffectPrimitives.trap_monster_identity(race, attribute, level,
			atk, def_, is_normal, "summon_self_as_trap_monster", treated_as_original_type)
		if not EffectPrimitives.special_summon_self_as_trap_monster(ctx,
				Enums.Zone.GRAVEYARD, identity, position):
			return
		if banish_when_leaving:
			EffectPrimitives.banish_when_it_leaves_the_field(ctx, ctx.source)

	return with_effect(d, e)


# ---------------------------------------------------------------------------
# Paying LIFE POINTS as an activation cost. RULES_SPEC.md 10.4.
# ---------------------------------------------------------------------------
#
# No card in the V1 pool pays LP as a cost, so every fixture below is synthetic — the same
# treatment R21 (`Apprentice Magician`'s Spell Counter) and R23 (`Fairy Tail - Rella`'s
# Equip clause) established. `LifePointCostTests` asserts against the real pool that none
# of the 77 cards pays LP, so the fact cannot rot silently.

## A Spell/Trap whose CARD ACTIVATION costs `amount` LP.
static func lp_cost_activation(card_name: String, amount: int,
		kind: Enums.STKind = Enums.STKind.NORMAL_TRAP) -> CardDef:
	var d := trap(card_name, kind) if kind == Enums.STKind.NORMAL_TRAP \
		else spell(card_name, kind)
	var e := EffectDef.new("lp_cost_activation",
		"Test: pay %d LP; this card does nothing." % amount)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_pay_life_points_cost(ctx, amount)
	e.pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.pay_life_points_cost(ctx, amount)
	e.resolve = func(ctx: EffectContext) -> void:
		ctx.log_note("resolved having paid %d LP" % amount)
	return with_effect(d, e)


## A monster with an IGNITION EFFECT that costs `amount` LP. Judge's clause says "a card
## OR EFFECT", so the two must be exercised separately.
static func lp_cost_ignition(card_name: String, amount: int) -> CardDef:
	var d := monster(card_name, 4, 1000, 1000)
	var e := EffectDef.new("lp_cost_ignition",
		"Test: pay %d LP; this effect does nothing." % amount)
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.FIELD_FACE_UP])
	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.can_pay_life_points_cost(ctx, amount)
	e.pay_cost = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.pay_life_points_cost(ctx, amount)
	e.resolve = func(ctx: EffectContext) -> void:
		ctx.log_note("resolved having paid %d LP" % amount)
	return with_effect(d, e)


## A Spell/Trap whose activation has a cost that is NOT Life Points. The control case for
## every "…did NOT pay LP" assertion: it emits `COST_PAID` exactly as an LP payment does,
## so a watcher that keys on the EVENT rather than on the payload would wrongly fire.
static func non_lp_cost_activation(card_name: String) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("non_lp_cost_activation",
		"Test: discard 1 card; this card does nothing.")
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.can_pay_cost = func(ctx: EffectContext) -> bool:
		return not ctx.me().hand.is_empty()
	e.pay_cost = func(ctx: EffectContext) -> bool:
		var paid := EffectPrimitives.pay_discard_cost(ctx, ctx.me().hand.duplicate(), 1,
			"Discard 1 card")
		if paid.is_empty():
			return false
		EffectPrimitives.record_cost(ctx, EffectPrimitives.COST_CARDS_KEY, paid)
		return true
	e.resolve = func(_ctx: EffectContext) -> void:
		pass
	return with_effect(d, e)


## A Spell/Trap that changes Life Points at RESOLUTION by a route that is not a cost.
## `mode` is "damage" (effect damage to the opponent) | "gain" (the controller gains) |
## "arbitrary_loss" (the opponent simply loses LP). None of these is a payment, and the
## generic gate asserts that a Judge-style watcher sees none of them.
static func lp_changer(card_name: String, mode: String, amount: int) -> CardDef:
	var d := trap(card_name)
	var e := EffectDef.new("lp_change", "Test: %s %d LP at resolution." % [mode, amount])
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.resolve = func(ctx: EffectContext) -> void:
		match mode:
			"damage":
				ctx.state.change_life_points(ctx.opponent_id(), -amount,
					card_name, ctx.source.id)
				ctx.state.check_life_point_loss()
			"gain":
				ctx.state.change_life_points(ctx.controller_id, amount,
					card_name, ctx.source.id)
			"arbitrary_loss":
				ctx.state.change_life_points(ctx.opponent_id(), -amount,
					card_name, ctx.source.id)
				ctx.state.check_life_point_loss()
			_:
				push_error("TestFixtures.lp_changer: unknown mode '%s'" % mode)
	return with_effect(d, e)


## A monster carrying the GENERIC shape of `Judge of the Ice Barrier`'s first clause: a
## CONTINUOUS clause that responds to an event immediately, without a Chain Link.
##
## Every activation by `watch_player` that paid LP appends a Dictionary to `seen`:
## {"card_name", "effect_id", "amount"}. Tests read `seen` rather than an LP total, so a
## coincidental LP change can never be mistaken for the clause having fired.
static func lp_cost_watcher(card_name: String, watch_player: int, seen: Array) -> CardDef:
	var d := monster(card_name, 4, 1800, 900, "WATER")
	var e := EffectDef.new("watch_lp_cost",
		"Test: each time that player activates a card or effect by paying LP, record it.")
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.on_events([GameEvent.Kind.COST_PAID])
	e.condition = func(ctx: EffectContext) -> bool:
		return EffectPrimitives.cost_event_paid_life_points(ctx.trigger_event, watch_player)
	e.respond_to_event = func(ctx: EffectContext) -> void:
		var ev: GameEvent = ctx.trigger_event
		var payload: Dictionary = ev.data.get("payload", {})
		seen.append({
			"card_name": str(ev.data.get("card_name", "")),
			"effect_id": str(ev.data.get("effect_id", "")),
			"amount": EffectPrimitives.life_points_paid_in(payload),
		})
	return with_effect(d, e)


# ---------------------------------------------------------------------------
# Decks and engines
# ---------------------------------------------------------------------------

## A legal 40-card deck of distinguishable vanilla monsters.
static func filler_deck(prefix: String) -> Array:
	var out: Array = []
	for i in range(DECK_SIZE):
		out.append(monster("%s Filler %02d" % [prefix, i], 4, 1000, 1000))
	return out


## A duel that has been set up and is sitting in its first open game state.
## Returns {"engine": DuelEngine, "p0": ScriptedController, "p1": ScriptedController}.
static func new_duel(seed_value: int = 1234, first_player: int = 0,
		deck0: Array = [], deck1: Array = []) -> Dictionary:
	var c0 := ScriptedController.new(0, "Player 1")
	var c1 := ScriptedController.new(1, "Player 2")
	var engine := DuelEngine.new(seed_value)
	engine.setup_duel(
		[deck0 if not deck0.is_empty() else filler_deck("A"),
		 deck1 if not deck1.is_empty() else filler_deck("B")],
		[c0, c1], first_player, ["Test Deck A", "Test Deck B"])
	return {"engine": engine, "p0": c0, "p1": c1}


# ---------------------------------------------------------------------------
# Direct placement, for arranging a board state a test needs
# ---------------------------------------------------------------------------

## Create a fresh instance of `def` for `pid` and put it straight into `zone`.
## Goes through the public movement API, so nothing bypasses GameState.
static func give(engine: DuelEngine, pid: int, def: CardDef, zone: Enums.Zone,
		position = null, index: int = -1) -> CardInstance:
	var state := engine.state
	var inst := CardInstance.new(def, pid)
	state.register_instance(inst)
	inst.zone = Enums.Zone.DECK
	state.player(pid).deck.append(inst)
	var opts := {"to_player": pid, "index": index}
	if position != null:
		opts["position"] = position
	state.move_card(inst, zone, Enums.MoveReason.RULE, opts)
	return inst


static func give_to_hand(engine: DuelEngine, pid: int, def: CardDef) -> CardInstance:
	return give(engine, pid, def, Enums.Zone.HAND, Enums.Position.FACE_DOWN)


static func give_monster_on_field(engine: DuelEngine, pid: int, def: CardDef,
		position: Enums.Position = Enums.Position.FACE_UP_ATTACK,
		index: int = -1) -> CardInstance:
	var c := give(engine, pid, def, Enums.Zone.MONSTER_ZONE, position, index)
	# A monster placed for a test scenario is treated as having been on the field since
	# before this turn, so it is not blocked by "played onto the field this turn" rules.
	c.turn_summoned = -1
	c.turn_set = -1
	return c


## A Set Spell/Trap that was Set on an earlier turn, so it is legal to activate.
static func give_set_spell_trap(engine: DuelEngine, pid: int, def: CardDef,
		set_on_turn: int = 0) -> CardInstance:
	var c := give(engine, pid, def, Enums.Zone.SPELL_TRAP_ZONE, Enums.Position.FACE_DOWN)
	c.turn_set = set_on_turn
	return c


# ---------------------------------------------------------------------------
# Driving the engine
# ---------------------------------------------------------------------------

## Find the offered action of a kind (optionally for a specific card), or null.
static func find_action(actions: Array, kind: Enums.ActionKind, card_id: int = -1,
		effect_id: String = ""):
	for a in actions:
		if a.kind != kind:
			continue
		if card_id != -1 and a.card_id != card_id:
			continue
		if effect_id != "" and a.effect_id != effect_id:
			continue
		return a
	return null


static func has_action(actions: Array, kind: Enums.ActionKind, card_id: int = -1,
		effect_id: String = "") -> bool:
	return find_action(actions, kind, card_id, effect_id) != null


## Activate a card through the public legal-action API and let the whole Chain finish.
## Returns false when the activation was not offered or was rejected.
static func activate_card(engine: DuelEngine, pid: int, card: CardInstance,
		target_ids: Array = []) -> bool:
	var offered = find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.ACTIVATE_CARD, card.id)
	if offered == null:
		return false
	var action = offered
	if not target_ids.is_empty():
		action = offered.with_choices({"target_ids": target_ids})
	if not engine.submit_action(action):
		return false
	pass_until_open(engine)
	return true


## Activate one EFFECT of a card already on the field (an Ignition or Quick Effect), as
## opposed to activating the card itself. `Castle of Dragon Souls`, `Sealing Ceremony of
## Suiton` and `Wonder Balloons` all sit face-up on the field and then activate an effect,
## which is an `ACTIVATE_EFFECT` action rather than `ACTIVATE_CARD`.
## Returns false when the activation was not offered or was rejected.
static func activate_effect(engine: DuelEngine, pid: int, card: CardInstance,
		effect_id: String, target_ids: Array = []) -> bool:
	var offered = find_action(engine.get_legal_actions(pid),
		Enums.ActionKind.ACTIVATE_EFFECT, card.id, effect_id)
	if offered == null:
		return false
	var action = offered
	if not target_ids.is_empty():
		action = offered.with_choices({"target_ids": target_ids})
	if not engine.submit_action(action):
		return false
	pass_until_open(engine)
	return true


## Put exactly `count` no-op Spell Speed 2 Trap links on the Chain and leave it BUILDING, so
## the next card activated in the open response window becomes Chain Link `count + 1`.
##
## Shared by `ChainDetonationTests` and `ChainHealingTests`, which are the only two cards in
## the V1 pool whose behaviour depends on the Chain Link position they were activated at
## (CARD_RULINGS.md R4). Building that state by hand in each suite would be the ad-hoc
## Chain-number bookkeeping the cards themselves deliberately avoid.
##
## Two constraints this encodes:
##
##   * every spacer is Set BEFORE the first activation, because placing a card while the
##     timing machine is mid-window would inject events into a window that is already open;
##   * sides alternate starting with the TURN PLAYER, because `get_legal_actions()` only
##     offers an action to the turn player in an open game state, so Chain Link 1 must be
##     theirs; every later link goes through `get_legal_responses()`.
##
## Returns the spacers actually activated, or [] if the Chain could not be built that deep.
static func build_chain_to_depth(engine: DuelEngine, count: int) -> Array:
	if count <= 0:
		return []
	var order_log: Array = []
	var tp := engine.state.turn_player_id
	var op := engine.state.opponent_id(tp)
	var spacers: Array = []
	for i in range(count):
		var pid: int = tp if i % 2 == 0 else op
		var e := card_activation("chain_spacer_%d" % i, Enums.SpellSpeed.SS2, order_log,
			"spacer%d" % i)
		# `card_activation()` allows FIELD_FACE_UP, which a real Normal Trap does not: an
		# already-activated spacer would then be offered again from its own face-up position,
		# the engine would never auto-pass that side, and the Chain would stall one link
		# short of the requested depth.
		e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
		spacers.append(give_set_spell_trap(engine, pid, with_effect(
			trap("Chain Spacer %d" % i), e)))
	var activated: Array = []
	for i in range(count):
		var spacer: CardInstance = spacers[i]
		var actions: Array = engine.get_legal_actions(spacer.controller_id) if i == 0 \
			else engine.get_legal_responses(spacer.controller_id)
		var a = find_action(actions, Enums.ActionKind.ACTIVATE_CARD, spacer.id)
		if a == null or not engine.submit_action(a):
			return []
		activated.append(spacer)
	return activated


## Everyone who is asked to respond passes, until the engine leaves the response windows.
## Returns the number of passes submitted.
static func pass_until_open(engine: DuelEngine, limit: int = 32) -> int:
	var n := 0
	while n < limit and not engine.is_duel_over() \
			and engine.timing != DuelEngine.Timing.OPEN:
		var pid := engine.waiting_player()
		if pid == -1:
			break
		engine.submit_action(DuelAction.make(Enums.ActionKind.PASS, pid))
		n += 1
	return n


## Advance to the given phase of the current turn by repeatedly finishing phases.
## Everyone passes in every response window.
static func advance_to_phase(engine: DuelEngine, phase: Enums.Phase,
		limit: int = 24) -> bool:
	var guard := 0
	while guard < limit and not engine.is_duel_over() and engine.state.phase != phase:
		guard += 1
		if engine.timing != DuelEngine.Timing.OPEN:
			pass_until_open(engine)
			continue
		var pid := engine.state.turn_player_id
		var actions := engine.get_legal_actions(pid)
		var kind := Enums.ActionKind.END_PHASE
		if phase == Enums.Phase.BATTLE and engine.state.phase == Enums.Phase.MAIN_1:
			kind = Enums.ActionKind.ENTER_BATTLE_PHASE
		elif engine.state.phase == Enums.Phase.BATTLE:
			# The Battle Phase offers END_BATTLE_PHASE rather than END_PHASE, so a duel
			# that is already in it cannot be advanced with END_PHASE.
			kind = Enums.ActionKind.END_BATTLE_PHASE
		var a = find_action(actions, kind)
		if a == null:
			return false
		engine.submit_action(a)
		pass_until_open(engine)
	return engine.state.phase == phase


## Finish the current turn so play passes to the other player.
static func end_turn(engine: DuelEngine, limit: int = 24) -> bool:
	var start_turn := engine.state.turn_number
	var guard := 0
	while guard < limit and not engine.is_duel_over() \
			and engine.state.turn_number == start_turn:
		guard += 1
		if engine.timing != DuelEngine.Timing.OPEN:
			pass_until_open(engine)
			continue
		var actions := engine.get_legal_actions(engine.state.turn_player_id)
		# The Battle Phase offers END_BATTLE_PHASE instead of END_PHASE, so a turn that
		# reached it cannot be finished with END_PHASE alone.
		var a = find_action(actions, Enums.ActionKind.END_PHASE)
		if a == null:
			a = find_action(actions, Enums.ActionKind.END_BATTLE_PHASE)
		if a == null:
			return false
		engine.submit_action(a)
	return engine.state.turn_number != start_turn


## A duel sitting in the Battle Step of turn 2, with player 0 as the turn player.
##
## Player 1 is given the first turn on purpose: "the player who goes first cannot conduct
## a Battle Phase on their first turn" [S1 p.37], so making player 0 the SECOND player
## lets the battle suite use player 0 as the attacker from turn 2 onward.
static func battle_duel(seed_value: int = 1234) -> Dictionary:
	var d := new_duel(seed_value, 1)
	end_turn(d["engine"])
	advance_to_phase(d["engine"], Enums.Phase.BATTLE)
	return d


## Every event of `kind`, in order.
static func events_of(engine: DuelEngine, kind: GameEvent.Kind, from: int = 0) -> Array:
	var out: Array = []
	for i in range(from, engine.state.events.size()):
		if engine.state.events[i].kind == kind:
			out.append(engine.state.events[i])
	return out


## Declare an attack through the public API. `target` is null for a direct attack.
## Returns whether the engine accepted the declaration.
static func attack(engine: DuelEngine, attacker: CardInstance, target) -> bool:
	var a = find_action(engine.get_legal_actions(attacker.controller_id),
		Enums.ActionKind.DECLARE_ATTACK, attacker.id)
	if a == null:
		return false
	a.attack_target_id = -1 if target == null else target.id
	return engine.submit_action(a)


## Index of the first event of `kind` in the state's event list, or -1.
static func first_event_index(engine: DuelEngine, kind: GameEvent.Kind,
		from: int = 0) -> int:
	for i in range(from, engine.state.events.size()):
		if engine.state.events[i].kind == kind:
			return i
	return -1


static func count_events(engine: DuelEngine, kind: GameEvent.Kind) -> int:
	var n := 0
	for e in engine.state.events:
		if e.kind == kind:
			n += 1
	return n


## The same count, restricted to one card. Needed whenever the event kind is raised by more
## than the card under test: activating a Set Spell/Trap emits `CARD_FLIPPED_FACE_UP` too,
## so a bare `count_events()` cannot answer "was this MONSTER flipped face-up?".
static func count_events_for(engine: DuelEngine, kind: GameEvent.Kind, card_id: int) -> int:
	var n := 0
	for e in engine.state.events:
		if e.kind == kind and int(e.data.get("card_id", -1)) == card_id:
			n += 1
	return n

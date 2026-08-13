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

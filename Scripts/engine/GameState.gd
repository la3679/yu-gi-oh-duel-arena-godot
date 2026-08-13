class_name GameState
extends RefCounted

## Authoritative duel state. Master prompt 7A.
##
## This is the single source of truth. The UI never decides legality and never mutates
## state directly — it submits actions to DuelEngine, which validates and calls in here.
##
## Card movement always goes through move_card() with an explicit Enums.MoveReason so that
## trigger effects can distinguish destroyed / Tributed / discarded / banished / returned
## (RULES_SPEC.md 8, master prompt 19). There is deliberately no untyped move helper.

signal event_emitted(event: GameEvent)

const PLAYER_COUNT := 2

## Effect id convention for a counted destruction PREVENTION clause, e.g. `Gagagashield`'s
## "Twice per turn, it cannot be destroyed by battle or card effects". The clause is a
## CONTINUOUS EffectDef whose `condition` is a PURE query — it is called with
## `ctx.params = {"card": <would-be-destroyed card>, "reason": <MoveReason>}` and returns
## whether it prevents that destruction. `EffectDef.uses_per_turn` bounds how often it may
## apply; the rules layer, not the card, spends the use.
const DESTRUCTION_PREVENTION_EFFECT_ID := "destruction_prevention"

## Effect id convention for a destruction REPLACEMENT clause, e.g. `Rider of the Storm
## Winds`'s "If a monster equipped with this card would be destroyed, destroy this card
## instead". The clause is a CONTINUOUS EffectDef whose `destruction_substitute` callable
## receives the same params and returns the card to destroy instead, or null.
const DESTRUCTION_REPLACEMENT_EFFECT_ID := "destruction_replacement"

## Guard against a replacement chain that never terminates (A replaces B replaces A).
const MAX_DESTRUCTION_REPLACEMENTS := 8

var players: Array = []          # [PlayerState, PlayerState]
var rng: Rng = null

var turn_number: int = 0
var turn_player_id: int = 0
var first_player_id: int = 0
var phase: Enums.Phase = Enums.Phase.DRAW
var battle_step: Enums.BattleStep = Enums.BattleStep.NONE
var damage_substep: Enums.DamageSubStep = Enums.DamageSubStep.NONE

## Whether the current turn conducted a Battle Phase (gates Main Phase 2). [S1 p.40]
var battle_phase_conducted_this_turn: bool = false

var result: Enums.DuelResult = Enums.DuelResult.ONGOING
var end_reason: Enums.EndReason = Enums.EndReason.NONE

# --- Chain state. RULES_SPEC.md 4. Owned by ChainManager, stored here. ---
var chain: Array = []                 # Array[ChainLink]
var chain_is_resolving: bool = false
## Events raised while a Chain is resolving; processed only after it fully resolves.
## Master prompt 45.
var deferred_trigger_events: Array = []

# --- Battle state ---
var current_attacker = null           # CardInstance
var current_attack_target = null      # CardInstance or null for a direct attack
var attack_is_direct: bool = false

# --- Instance registry ---
var _next_instance_id: int = 1
var _instances: Dictionary = {}       # id -> CardInstance

## Per-card facts that must OUTLIVE the card leaving the field, keyed "<key>::<card_id>".
##
## `CardInstance.flags` cannot express this: on_leave_field() clears it during the very
## move that makes the fact relevant. `Birthright` and `Call of the Haunted` both need to
## know which monster they Summoned at the moment they *leave* the field, which is exactly
## when `flags` is already gone. RULES_SPEC.md 15.
var card_memory: Dictionary = {}

# --- Event log ---
var events: Array = []
var _next_sequence: int = 0


func _init(seed_value: int = 0) -> void:
	rng = Rng.new(seed_value)
	players = [PlayerState.new(0, "Player 1"), PlayerState.new(1, "Player 2")]


# ---------------------------------------------------------------------------
# Basic accessors
# ---------------------------------------------------------------------------

func player(pid: int) -> PlayerState:
	return players[pid]


func turn_player() -> PlayerState:
	return players[turn_player_id]


func opponent_id(pid: int) -> int:
	return 1 - pid


func opponent_of(pid: int) -> PlayerState:
	return players[1 - pid]


func instance(iid: int):
	return _instances.get(iid)


func register_instance(card: CardInstance) -> CardInstance:
	card.id = _next_instance_id
	_next_instance_id += 1
	_instances[card.id] = card
	return card


func all_instances() -> Array:
	return _instances.values()


## Every card currently on the field, both players.
func all_field_cards() -> Array:
	var out := []
	for p in players:
		out.append_array(p.controlled_cards())
	return out


func all_field_monsters() -> Array:
	var out := []
	for p in players:
		out.append_array(p.monsters())
	return out


func is_duel_over() -> bool:
	return result != Enums.DuelResult.ONGOING


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func emit(kind: GameEvent.Kind, data: Dictionary = {}) -> GameEvent:
	var ev := GameEvent.new(kind, data)
	ev.sequence = _next_sequence
	_next_sequence += 1
	ev.turn = turn_number
	ev.phase = phase
	events.append(ev)
	event_emitted.emit(ev)
	return ev


# ---------------------------------------------------------------------------
# Zone plumbing
# ---------------------------------------------------------------------------

## Returns the backing array for an unordered zone, or null for ordered/field zones.
func _unordered_zone_array(pid: int, zone: Enums.Zone):
	var p := player(pid)
	match zone:
		Enums.Zone.DECK: return p.deck
		Enums.Zone.HAND: return p.hand
		Enums.Zone.GRAVEYARD: return p.graveyard
		Enums.Zone.BANISHED: return p.banished
		Enums.Zone.EXTRA_DECK: return p.extra_deck
		Enums.Zone.IN_TRANSIT: return p.in_transit
		_: return null


## Detach a card from wherever it currently is. Does not emit events.
func _detach(card: CardInstance) -> void:
	var p := player(card.controller_id)
	match card.zone:
		Enums.Zone.MONSTER_ZONE:
			if card.zone_index >= 0 and p.monster_zones[card.zone_index] == card:
				p.monster_zones[card.zone_index] = null
		Enums.Zone.SPELL_TRAP_ZONE:
			if card.zone_index >= 0 and p.spell_trap_zones[card.zone_index] == card:
				p.spell_trap_zones[card.zone_index] = null
		Enums.Zone.FIELD_ZONE:
			if p.field_zone == card:
				p.field_zone = null
		Enums.Zone.EXTRA_MONSTER_ZONE:
			if p.extra_monster_zone == card:
				p.extra_monster_zone = null
		_:
			var arr = _unordered_zone_array(card.controller_id, card.zone)
			if arr != null:
				arr.erase(card)
			else:
				# Card may be owned-but-not-controlled in an unordered zone; unordered
				# zones always belong to the OWNER, so fall back to the owner's arrays.
				var owner_arr = _unordered_zone_array(card.owner_id, card.zone)
				if owner_arr != null:
					owner_arr.erase(card)
	card.zone_index = -1


## Attach a card into a destination zone. Does not emit events.
## `index` selects a Monster / Spell&Trap slot; -1 picks the first free one.
## `deck_position` is "top" | "bottom" for Deck destinations.
func _attach(card: CardInstance, pid: int, zone: Enums.Zone, index: int,
		deck_position: String) -> bool:
	var p := player(pid)
	match zone:
		Enums.Zone.MONSTER_ZONE:
			var i := index if index >= 0 else p.free_monster_zone_index()
			if i < 0 or i >= PlayerState.MONSTER_ZONE_COUNT or p.monster_zones[i] != null:
				return false
			p.monster_zones[i] = card
			card.zone_index = i
		Enums.Zone.SPELL_TRAP_ZONE:
			var j := index if index >= 0 else p.free_spell_trap_zone_index()
			if j < 0 or j >= PlayerState.SPELL_TRAP_ZONE_COUNT or p.spell_trap_zones[j] != null:
				return false
			p.spell_trap_zones[j] = card
			card.zone_index = j
		Enums.Zone.FIELD_ZONE:
			if p.field_zone != null:
				return false
			p.field_zone = card
		Enums.Zone.EXTRA_MONSTER_ZONE:
			if p.extra_monster_zone != null:
				return false
			p.extra_monster_zone = card
		Enums.Zone.DECK:
			if deck_position == "bottom":
				p.deck.append(card)
			else:
				p.deck.push_front(card)
		Enums.Zone.HAND:
			p.hand.append(card)
		Enums.Zone.GRAVEYARD:
			p.graveyard.append(card)
		Enums.Zone.BANISHED:
			p.banished.append(card)
		Enums.Zone.EXTRA_DECK:
			p.extra_deck.append(card)
		Enums.Zone.IN_TRANSIT:
			p.in_transit.append(card)
		_:
			return false
	card.zone = zone
	return true


# ---------------------------------------------------------------------------
# The single card-movement API. Master prompt 19.
# ---------------------------------------------------------------------------

## Move a card, recording the semantic reason. Returns true on success.
##
## Cards sent to the GY / hand / Deck / banished always go to their OWNER's zone,
## never the controller's [S1 p.52].
##
## `to_player` is ignored for owner-bound zones. `position` sets the resulting
## face/battle position where meaningful.
func move_card(card: CardInstance, to_zone: Enums.Zone, reason: Enums.MoveReason,
		opts: Dictionary = {}) -> bool:
	if card == null:
		return false

	var to_player: int = int(opts.get("to_player", card.controller_id))
	var index: int = int(opts.get("index", -1))
	var deck_position: String = str(opts.get("deck_position", "top"))
	var new_position = opts.get("position", null)
	var source_id: int = int(opts.get("source_id", -1))

	# Owner-bound zones. [S1 p.52]
	if to_zone in [Enums.Zone.GRAVEYARD, Enums.Zone.HAND, Enums.Zone.DECK,
			Enums.Zone.BANISHED, Enums.Zone.EXTRA_DECK]:
		to_player = card.owner_id

	var from_zone := card.zone
	var from_player := card.controller_id
	var was_on_field := card.is_on_field()
	# Captured BEFORE the move: `_attach` and the position handling below overwrite
	# `card.position` (a card sent to the GY becomes FACE_UP, one returned to the hand
	# becomes FACE_DOWN), so asking afterwards answers about the destination rather than
	# about where the card came from. RULES_SPEC.md 15.
	var was_face_up := card.is_face_up()

	_detach(card)

	card.prior_zone = from_zone
	card.prior_controller_id = from_player
	card.controller_id = to_player

	if not _attach(card, to_player, to_zone, index, deck_position):
		# Re-attach where it was so state is never corrupted by a failed move.
		_attach(card, from_player, from_zone, -1, "top")
		card.controller_id = from_player
		return false

	# Position handling
	if new_position != null:
		card.position = new_position
	elif to_zone in [Enums.Zone.GRAVEYARD, Enums.Zone.BANISHED]:
		card.position = Enums.Position.FACE_UP
	elif to_zone in [Enums.Zone.DECK, Enums.Zone.EXTRA_DECK, Enums.Zone.HAND]:
		card.position = Enums.Position.FACE_DOWN

	# A card SHUFFLED into the Deck stops being identifiable [S1 p.5, p.28]. This is keyed
	# on the shuffle rather than on the Deck on purpose: a card placed on top of or on the
	# bottom of the Deck without a shuffle keeps what the players legally saw, because its
	# position is still known. RULES_SPEC.md 9.3.
	if to_zone == Enums.Zone.DECK and reason == Enums.MoveReason.SHUFFLED_INTO_DECK:
		card.revealed_to.clear()

	# Leaving the field resets per-instance effect state. Master prompt 48.
	# The Equip Cards that lose their host are collected FIRST — on_leave_field() clears
	# `equipped_card_ids` — but destroyed only after this card's own events are emitted,
	# so the log reads in causal order: the monster left, therefore its Equip Cards died.
	var orphaned_equips: Array = []
	if was_on_field and not card.is_on_field():
		orphaned_equips = _detach_equips(card)
		card.on_leave_field()

	# Recorded after on_leave_field() precisely so it survives it. RULES_SPEC.md 15.
	card.last_move_reason = reason
	card.last_move_from_zone = from_zone
	card.last_move_was_face_up = was_face_up
	card.last_move_turn = turn_number
	card.last_move_turn_player_id = turn_player_id

	var payload := {
		"card_id": card.id,
		"card_name": card.card_name(),
		"from_zone": from_zone,
		"to_zone": to_zone,
		"from_player": from_player,
		"to_player": to_player,
		"reason": reason,
		"source_id": source_id,
	}
	emit(GameEvent.Kind.CARD_MOVED, payload)

	# Specific semantic events so presentation can use distinct animations
	# (master prompt 60) and triggers can subscribe precisely.
	match reason:
		Enums.MoveReason.DESTROYED_BY_BATTLE, Enums.MoveReason.DESTROYED_BY_EFFECT, \
		Enums.MoveReason.DESTROYED_BY_RULE:
			# All three ARE destructions [S1 p.52]; which one it was stays in the payload,
			# so a clause worded "destroyed by battle or card effect" can still tell them
			# apart while a clause worded "is destroyed" sees all of them.
			emit(GameEvent.Kind.CARD_DESTROYED, payload)
		Enums.MoveReason.BANISHED:
			emit(GameEvent.Kind.CARD_BANISHED, payload)
		Enums.MoveReason.RETURNED_TO_HAND:
			emit(GameEvent.Kind.CARD_RETURNED_TO_HAND, payload)
		Enums.MoveReason.RETURNED_TO_DECK_TOP, Enums.MoveReason.RETURNED_TO_DECK_BOTTOM, \
		Enums.MoveReason.SHUFFLED_INTO_DECK:
			emit(GameEvent.Kind.CARD_RETURNED_TO_DECK, payload)
		Enums.MoveReason.TRIBUTED:
			emit(GameEvent.Kind.CARD_TRIBUTED, payload)

	# "Sent to the Graveyard" is a distinct concept from "destroyed" [S1 p.53].
	# A banished card later moved to the GY is NOT "sent to the GY".
	if to_zone == Enums.Zone.GRAVEYARD \
			and Enums.is_sent_to_gy(reason) \
			and from_zone != Enums.Zone.BANISHED:
		emit(GameEvent.Kind.CARD_SENT_TO_GY, payload)

	# "If the equipped monster is destroyed, flipped face-down, or removed from the field,
	# its Equip Cards are destroyed." [S1 p.29, p.55] This is a RULES destruction, not a
	# card effect, which is why it carries its own MoveReason.
	for entry in orphaned_equips:
		var orphan: CardInstance = entry
		if orphan.is_on_field():
			move_card(orphan, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_RULE,
				{"source_id": card.id})

	return true


# ---------------------------------------------------------------------------
# Equip Cards. RULES_SPEC.md 16 [S1 p.29, p.53, p.55]
#
# "The term 'Equip Card' includes all 3 kinds (standard Equip Spells, equipped Traps, and
# monsters equipped to other monsters)" [S1 p.53], so this subsystem is deliberately not
# written in terms of Equip Spells: the V1 pool's only two equippers are a Trap
# (`Gagagashield`) and a monster that equips itself (`Rider of the Storm Winds`).
# ---------------------------------------------------------------------------

## Equip `equip` to `host`. Returns false and changes nothing when the equip is illegal.
##
## The Equip Card "affects only 1 monster (called the equipped monster), but still occupies
## one of your Spell & Trap Zones" [S1 p.29], so a card equipping from anywhere other than
## the Spell & Trap Zone needs a free one. The host must be a FACE-UP monster on the
## field — an Equip Card gives its effect to "1 face-up monster of your choice" [S1 p.29].
func equip_to(equip: CardInstance, host: CardInstance, source_id: int = -1) -> bool:
	if equip == null or host == null or equip == host:
		return false
	if host.zone != Enums.Zone.MONSTER_ZONE or not host.is_face_up():
		return false
	if equip.equipped_to_id != -1:
		# A card is equipped to exactly one monster and cannot be moved. [S1 p.53]
		return false

	var pid := equip.controller_id
	if equip.zone != Enums.Zone.SPELL_TRAP_ZONE:
		if not player(pid).has_free_spell_trap_zone():
			return false
		if not move_card(equip, Enums.Zone.SPELL_TRAP_ZONE, Enums.MoveReason.RULE,
				{"to_player": pid, "position": Enums.Position.FACE_UP}):
			return false
	else:
		equip.position = Enums.Position.FACE_UP

	equip.equipped_to_id = host.id
	if not host.equipped_card_ids.has(equip.id):
		host.equipped_card_ids.append(equip.id)
	emit(GameEvent.Kind.CARD_EQUIPPED, {
		"card_id": equip.id, "card_name": equip.card_name(),
		"equipped_to_id": host.id, "equipped_to_name": host.card_name(),
		"player": pid, "source_id": source_id,
	})
	return true


## Every Equip Card currently equipped to `host`, in the order they were equipped.
func equipped_cards(host: CardInstance) -> Array:
	var out: Array = []
	if host == null:
		return out
	for eid in host.equipped_card_ids:
		var equip = instance(int(eid))
		if equip != null:
			out.append(equip)
	return out


## Break every equip relationship `card` takes part in and announce it. Returns the Equip
## Cards that have just lost their host and are therefore now destroyed by the rules —
## the caller decides when that destruction happens, because ordering matters.
func _detach_equips(card: CardInstance) -> Array:
	var orphaned: Array = []
	for eid in card.equipped_card_ids.duplicate():
		var equip = instance(int(eid))
		if equip == null:
			continue
		equip.equipped_to_id = -1
		emit(GameEvent.Kind.CARD_UNEQUIPPED, {
			"card_id": equip.id, "card_name": equip.card_name(),
			"equipped_to_id": card.id, "equipped_to_name": card.card_name(),
			"player": equip.controller_id, "lost_host": true,
		})
		if equip.is_on_field():
			orphaned.append(equip)
	card.equipped_card_ids.clear()

	if card.equipped_to_id != -1:
		var host = instance(card.equipped_to_id)
		if host != null:
			host.equipped_card_ids.erase(card.id)
		emit(GameEvent.Kind.CARD_UNEQUIPPED, {
			"card_id": card.id, "card_name": card.card_name(),
			"equipped_to_id": card.equipped_to_id,
			"equipped_to_name": host.card_name() if host != null else "",
			"player": card.controller_id, "lost_host": false,
		})
		card.equipped_to_id = -1
	return orphaned


# ---------------------------------------------------------------------------
# Destruction. RULES_SPEC.md 17.
#
# One entry point, so a "cannot be destroyed" and a "destroy this card instead" are
# honoured no matter who asked for the destruction. Both are found through the effect-id
# conventions declared at the top of this file, never by reading card text.
# ---------------------------------------------------------------------------

## Face-up, un-negated cards on the field that declare `effect_id` as a rules query.
func _query_sources(effect_id: String) -> Array:
	var out: Array = []
	for p in players:
		for card in p.controlled_cards():
			if card == null or card.definition == null:
				continue
			if not card.is_face_up() or card.effects_negated:
				continue
			for effect in card.definition.effects:
				if effect.effect_id == effect_id:
					out.append({"card": card, "effect": effect})
	return out


## Would this destruction be PREVENTED? A counted prevention spends one of its uses here,
## because the use is spent by the destruction it stops, not by anything the player does.
func destruction_prevented(card: CardInstance, reason: Enums.MoveReason) -> bool:
	if card == null:
		return false
	# The uncounted continuous flags, owned by ContinuousEffects and rebuilt every recompute.
	if reason == Enums.MoveReason.DESTROYED_BY_BATTLE \
			and bool(card.flags.get("cannot_be_destroyed_by_battle", false)):
		return true
	if reason != Enums.MoveReason.DESTROYED_BY_BATTLE \
			and bool(card.flags.get("cannot_be_destroyed_by_effect", false)):
		return true

	for entry in _query_sources(DESTRUCTION_PREVENTION_EFFECT_ID):
		var source: CardInstance = entry["card"]
		var effect: EffectDef = entry["effect"]
		if not effect.condition.is_valid():
			continue
		if effect.uses_per_turn > 0 \
				and source.uses_this_turn(effect.effect_id, turn_number) >= effect.uses_per_turn:
			continue
		var ctx := EffectContext.new(self, source, effect)
		ctx.controller_id = source.controller_id
		ctx.params = {"card": card, "reason": reason}
		if not bool(effect.condition.call(ctx)):
			continue
		if effect.uses_per_turn > 0:
			source.record_use_this_turn(effect.effect_id, turn_number)
		return true
	return false


## Carry out a destruction whose prevention check has already been made, applying any
## REPLACEMENT effect. Returns true when SOMETHING was destroyed (possibly the substitute).
func carry_out_destruction(card: CardInstance, reason: Enums.MoveReason,
		source_id: int = -1, depth: int = 0) -> bool:
	if card == null or not card.is_on_field():
		return false
	if depth < MAX_DESTRUCTION_REPLACEMENTS:
		for entry in _query_sources(DESTRUCTION_REPLACEMENT_EFFECT_ID):
			var replacer: CardInstance = entry["card"]
			var effect: EffectDef = entry["effect"]
			if not effect.destruction_substitute.is_valid():
				continue
			var ctx := EffectContext.new(self, replacer, effect)
			ctx.controller_id = replacer.controller_id
			ctx.params = {"card": card, "reason": reason}
			var substitute = effect.destruction_substitute.call(ctx)
			if substitute == null or substitute == card:
				continue
			# The substitute is destroyed in the original card's place, and it gets its
			# own prevention/replacement check — it is a real destruction.
			return destroy(substitute, reason, source_id, depth + 1)
	return move_card(card, Enums.Zone.GRAVEYARD, reason, {"source_id": source_id})


## Destroy `card`. The single entry point every card effect and the battle rules use.
## Returns true when the card (or a substitute) was actually destroyed.
func destroy(card: CardInstance, reason: Enums.MoveReason = Enums.MoveReason.DESTROYED_BY_EFFECT,
		source_id: int = -1, depth: int = 0) -> bool:
	if card == null or not card.is_on_field():
		return false
	if destruction_prevented(card, reason):
		return false
	return carry_out_destruction(card, reason, source_id, depth)


# ---------------------------------------------------------------------------
# Per-card memory that outlives the field. RULES_SPEC.md 15.
# ---------------------------------------------------------------------------

func _memory_key(card: CardInstance, key: String) -> String:
	return "%s::%d" % [key, card.id]


func remember(card: CardInstance, key: String, value) -> void:
	if card == null:
		return
	card_memory[_memory_key(card, key)] = value


func recall(card: CardInstance, key: String, fallback = null):
	if card == null:
		return fallback
	return card_memory.get(_memory_key(card, key), fallback)


func forget(card: CardInstance, key: String) -> void:
	if card == null:
		return
	card_memory.erase(_memory_key(card, key))


## The card `card` remembers under `key` as an instance id, or null.
func recall_card(card: CardInstance, key: String):
	var value = recall(card, key, null)
	if value == null:
		return null
	return instance(int(value))


# ---------------------------------------------------------------------------
# Counters. Required by the V1 pool: Apprentice Magician places a Spell Counter,
# Wonder Balloons accumulates Balloon Counters (CARD_RULINGS.md; RULES_SPEC.md 14).
# ---------------------------------------------------------------------------

## Counters may only be placed on a card that is face-up on the field, unless a card
## says otherwise. Returns false when the placement is not legal.
func place_counters(card: CardInstance, kind: String, amount: int,
		source_id: int = -1) -> bool:
	if card == null or amount <= 0:
		return false
	if not card.is_on_field() or not card.is_face_up():
		return false
	card.add_counters(kind, amount)
	emit(GameEvent.Kind.COUNTER_PLACED, {
		"card_id": card.id, "card_name": card.card_name(),
		"counter": kind, "amount": amount,
		"total": card.counter_count(kind), "source_id": source_id,
	})
	return true


## Removing counters is frequently a cost, so a partial removal must never happen:
## either the full amount comes off or nothing does.
func remove_counters(card: CardInstance, kind: String, amount: int,
		source_id: int = -1) -> bool:
	if card == null or amount <= 0:
		return false
	if not card.remove_counters(kind, amount):
		return false
	emit(GameEvent.Kind.COUNTER_REMOVED, {
		"card_id": card.id, "card_name": card.card_name(),
		"counter": kind, "amount": amount,
		"total": card.counter_count(kind), "source_id": source_id,
	})
	return true


func total_counters(card: CardInstance, kind: String) -> int:
	return card.counter_count(kind) if card != null else 0


# ---------------------------------------------------------------------------
# Battle position / face orientation
# ---------------------------------------------------------------------------

## Change a card's battle position and emit the semantic event. `by_effect` records
## whether this was a manual change (which consumes the once-per-turn allowance) or an
## effect-driven one (which does not). RULES_SPEC.md 5.3.
func set_battle_position(card: CardInstance, new_position: Enums.Position,
		by_effect: bool, source_id: int = -1) -> void:
	if card == null or card.position == new_position:
		return
	var was_face_up := card.is_face_up()
	var old := card.position
	card.position = new_position
	if not by_effect:
		card.position_changed_this_turn = true
	emit(GameEvent.Kind.BATTLE_POSITION_CHANGED, {
		"card_id": card.id, "card_name": card.card_name(),
		"from": old, "to": new_position,
		"by_effect": by_effect, "source_id": source_id,
	})
	if was_face_up and not card.is_face_up():
		# Flipping face-down resets per-instance effect state. Master prompt 48.
		card.on_flipped_face_down()
		# "If the equipped monster is destroyed, FLIPPED FACE-DOWN, or removed from the
		# field, its Equip Cards are destroyed." [S1 p.29, p.55] The monster is still on
		# the field, so move_card() never sees this case — it has to be handled here.
		for orphan in _detach_equips(card):
			var equip: CardInstance = orphan
			if equip.is_on_field():
				move_card(equip, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_RULE,
					{"source_id": card.id})
	elif not was_face_up and card.is_face_up():
		card.turn_flipped = turn_number
		emit(GameEvent.Kind.CARD_FLIPPED_FACE_UP, {
			"card_id": card.id, "card_name": card.card_name(),
			"position": new_position, "source_id": source_id,
		})


# ---------------------------------------------------------------------------
# Life Points
# ---------------------------------------------------------------------------

func change_life_points(pid: int, delta: int, reason: String, source_id: int = -1) -> void:
	var p := player(pid)
	var applied := p.change_life_points(delta)
	emit(GameEvent.Kind.LP_CHANGED, {
		"player": pid, "delta": applied, "life_points": p.life_points,
		"reason": reason, "source_id": source_id,
	})


# ---------------------------------------------------------------------------
# Drawing. RULES_SPEC.md 2.1 — a player who must draw and cannot loses.
# ---------------------------------------------------------------------------

## Returns the drawn cards. If the Deck is empty the draw fails and the player loses;
## the caller must check `is_duel_over()`.
func draw(pid: int, count: int) -> Array:
	var p := player(pid)
	var drawn := []
	for i in range(count):
		if p.deck.is_empty():
			p.has_lost = true
			_declare_winner(opponent_id(pid), Enums.EndReason.DECK_OUT)
			return drawn
		var card: CardInstance = p.deck[0]
		p.deck.remove_at(0)
		card.prior_zone = Enums.Zone.DECK
		card.zone = Enums.Zone.HAND
		card.position = Enums.Position.FACE_DOWN
		p.hand.append(card)
		drawn.append(card)
		emit(GameEvent.Kind.CARD_DRAWN, {
			"player": pid, "card_id": card.id,
			# The identity of a drawn card is private to the drawing player.
			"private_to": [pid], "card_name": card.card_name(),
		})
	return drawn


## Shuffling ends any legal knowledge of a revealed card's whereabouts, so `revealed_to`
## does not survive it. The Deck is never public information: only the NUMBER of cards in
## it is [S1 p.5, p.28], and the rulebook requires a shuffle precisely after a card effect
## reveals cards from the Deck or looks through it [S1 p.5]. RULES_SPEC.md 9.3.
func shuffle_deck(pid: int) -> void:
	for card in player(pid).deck:
		card.revealed_to.clear()
	rng.shuffle(player(pid).deck)


# ---------------------------------------------------------------------------
# Duel end. RULES_SPEC.md 13.
# ---------------------------------------------------------------------------

func check_life_point_loss() -> void:
	if is_duel_over():
		return
	var p0_out: bool = players[0].life_points <= 0
	var p1_out: bool = players[1].life_points <= 0
	if p0_out and p1_out:
		result = Enums.DuelResult.DRAW
		end_reason = Enums.EndReason.SIMULTANEOUS_LP_ZERO
		emit(GameEvent.Kind.DUEL_ENDED, {"result": result, "reason": end_reason})
	elif p0_out:
		_declare_winner(1, Enums.EndReason.LP_ZERO)
	elif p1_out:
		_declare_winner(0, Enums.EndReason.LP_ZERO)


func _declare_winner(winner_id: int, reason: Enums.EndReason) -> void:
	if is_duel_over():
		return
	result = Enums.DuelResult.PLAYER_0_WINS if winner_id == 0 \
		else Enums.DuelResult.PLAYER_1_WINS
	end_reason = reason
	emit(GameEvent.Kind.PLAYER_DEFEATED, {"player": opponent_id(winner_id), "reason": reason})
	emit(GameEvent.Kind.DUEL_ENDED, {"result": result, "reason": reason, "winner": winner_id})


func surrender(pid: int) -> void:
	_declare_winner(opponent_id(pid), Enums.EndReason.SURRENDER)


# ---------------------------------------------------------------------------
# Hidden information filtering. Master prompt 40, RULES_SPEC.md 12.
# ---------------------------------------------------------------------------

## A viewer-filtered snapshot. The engine knows everything; this is what a player may see.
func get_visible_state(viewer_id: int) -> Dictionary:
	var out := {
		"viewer": viewer_id,
		"turn": turn_number,
		"turn_player": turn_player_id,
		"phase": phase,
		"battle_step": battle_step,
		"damage_substep": damage_substep,
		"result": result,
		"chain": _visible_chain(viewer_id),
		"players": [],
	}
	for p in players:
		out["players"].append(_visible_player(p, viewer_id))
	return out


func _visible_player(p: PlayerState, viewer_id: int) -> Dictionary:
	var is_self := p.id == viewer_id
	var d := {
		"id": p.id,
		"name": p.display_name,
		"deck_name": p.deck_name,
		"life_points": p.life_points,
		# Counts are public knowledge. [S1 p.50]
		"deck_count": p.deck.size(),
		"hand_count": p.hand.size(),
		"graveyard_count": p.graveyard.size(),
		"banished_count": p.banished.size(),
		"normal_summons_used": p.normal_summons_used,
		"normal_summons_allowed": p.normal_summons_allowed,
		# Graveyards are public. [S1 p.50]
		"graveyard": p.graveyard.map(func(c): return _visible_card(c, viewer_id, true)),
		"banished": p.banished.map(func(c): return _visible_card(c, viewer_id, true)),
		"monster_zones": p.monster_zones.map(
			func(c): return null if c == null else _visible_card(c, viewer_id, false)),
		"spell_trap_zones": p.spell_trap_zones.map(
			func(c): return null if c == null else _visible_card(c, viewer_id, false)),
		"field_zone": null if p.field_zone == null \
			else _visible_card(p.field_zone, viewer_id, false),
	}
	# Only the owner sees their own hand contents. Deck order is never exposed.
	#
	# The opponent's hand goes through _visible_card rather than straight to a stub, so a
	# card that was legally revealed to this viewer stays visible to them. _visible_card
	# already returns a stub otherwise: a hand card is face-down and controlled by
	# someone else, so nothing else in that function can make it visible.
	if is_self:
		d["hand"] = p.hand.map(func(c): return _visible_card(c, viewer_id, true))
	else:
		d["hand"] = p.hand.map(func(c): return _visible_card(c, viewer_id, false))
	return d


func _visible_card(card: CardInstance, viewer_id: int, force_visible: bool) -> Dictionary:
	var visible := force_visible \
		or card.is_face_up() \
		or card.controller_id == viewer_id \
		or viewer_id in card.revealed_to
	if not visible:
		return _hidden_card_stub(card)
	var d := {
		"id": card.id,
		"name": card.card_name(),
		"controller": card.controller_id,
		"owner": card.owner_id,
		"zone": card.zone,
		"zone_index": card.zone_index,
		"position": card.position,
		"face_up": card.is_face_up(),
		"hidden": false,
		"counters": card.counters.duplicate(),
		"effects_negated": card.effects_negated,
		"equipped_to": card.equipped_to_id,
		"equipped_cards": card.equipped_card_ids.duplicate(),
	}
	if card.is_monster():
		d["atk"] = card.current_atk()
		d["def"] = card.current_def()
		d["original_atk"] = card.original_atk()
		d["original_def"] = card.original_def()
		d["level"] = card.definition.level
		d["attribute"] = card.definition.attribute
		d["race"] = card.definition.race
	return d


func _hidden_card_stub(card: CardInstance) -> Dictionary:
	# Position/zone are public for a Set card; identity is not.
	return {
		"id": card.id,
		"name": null,
		"hidden": true,
		"controller": card.controller_id,
		"zone": card.zone,
		"zone_index": card.zone_index,
		"position": card.position,
		"face_up": false,
	}


func _visible_chain(viewer_id: int) -> Array:
	var out := []
	for link in chain:
		out.append(link.to_visible_dict(viewer_id))
	return out


## Public event log, with private events filtered out. Master prompt 68.
func get_public_log() -> Array:
	return events.filter(func(e): return e.is_public())


func get_log_for(viewer_id: int) -> Array:
	return events.filter(
		func(e): return e.is_public() or viewer_id in e.private_to())

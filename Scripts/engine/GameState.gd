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

	# Leaving the field resets per-instance effect state. Master prompt 48.
	if was_on_field and not card.is_on_field():
		_unequip_all(card)
		card.on_leave_field()

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
		Enums.MoveReason.DESTROYED_BY_BATTLE, Enums.MoveReason.DESTROYED_BY_EFFECT:
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

	return true


func _unequip_all(card: CardInstance) -> void:
	# Equip Cards are destroyed when the equipped monster leaves the field. [S1 p.28]
	for eid in card.equipped_card_ids.duplicate():
		var equip = instance(eid)
		if equip != null and equip.is_on_field():
			equip.equipped_to_id = -1
			move_card(equip, Enums.Zone.GRAVEYARD, Enums.MoveReason.DESTROYED_BY_EFFECT,
				{"source_id": card.id})
	card.equipped_card_ids.clear()
	if card.equipped_to_id != -1:
		var host = instance(card.equipped_to_id)
		if host != null:
			host.equipped_card_ids.erase(card.id)
		card.equipped_to_id = -1


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


func shuffle_deck(pid: int) -> void:
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

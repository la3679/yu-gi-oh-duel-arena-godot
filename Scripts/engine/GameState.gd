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

## Card-memory key for "banish this card when it leaves the field"
## [`The Phantom Knights of Shadow Veil`]. Held in `card_memory` rather than in
## `CardInstance.flags` for the reason RULES_SPEC.md 15 gives: `on_leave_field()` clears the
## flags during the very move that has to honour the obligation. Read once, in `move_card()`.
const BANISH_WHEN_LEAVING_FIELD_KEY := "banish_when_leaving_field"

## Effect id convention for a COUNTER CAPACITY clause: "this card can have Spell Counters
## placed on it". `Apprentice Magician` reads it — "Target 1 face-up card on the field **that
## you can place a Spell Counter on**" is a filter on a property of the TARGET, and a card
## only has that property because some card text grants it. The clause is a CONTINUOUS
## EffectDef whose `condition` is a PURE query, called with
## `ctx.params = {"counter": <counter kind>}`.
##
## This is deliberately NOT enforced by `place_counters()`. A clause that places a counter on
## a specific named card does so on its own authority — `Wonder Balloons`' "place 1 Balloon
## Counter on this card" is exactly that, and needs no capacity declaration. The capacity
## query exists only for clauses that SEARCH for a card able to receive a counter.
const COUNTER_CAPACITY_EFFECT_ID := "counter_capacity"

## Guard against a replacement chain that never terminates (A replaces B replaces A).
const MAX_DESTRUCTION_REPLACEMENTS := 8

# Turn-scoped future material choices. RULES_SPEC.md 5.9 / R39.
var choice_constraints: Array = []

func require_choice_this_turn(pid: int, scope: String, target: CardInstance,
		source_id: int = -1) -> void:
	if target == null or not target.is_monster() or not target.is_on_field():
		return
	choice_constraints.append({"player": pid, "scope": scope, "target_id": target.id,
		"controller": target.controller_id, "zone": target.zone,
		"source_id": source_id, "turn": turn_number})

func required_choice_ids(pid: int, scope: String) -> Array:
	var out: Array = []
	for c in choice_constraints:
		var target: CardInstance = instance(int(c["target_id"]))
		if int(c["turn"]) != turn_number or int(c["player"]) != pid or c["scope"] != scope:
			continue
		if target == null or target.zone != c["zone"] or target.controller_id != c["controller"]:
			continue
		if not out.has(target.id):
			out.append(target.id)
	return out

func choice_selection_ok(pid: int, scope: String, selected_ids: Array) -> bool:
	for required in required_choice_ids(pid, scope):
		if not selected_ids.has(required):
			return false
	return true

func clear_choice_constraints_for(card: CardInstance) -> void:
	choice_constraints = choice_constraints.filter(func(c): return c["target_id"] != card.id)

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

# --- Summon declaration state. RULES_SPEC.md 5.4 [S1 p.24]. ---
## The monster of a Summon that has been DECLARED and has not yet completed or been negated,
## i.e. a monster that "would be Summoned". Written by `SummonRules.begin_*_summon()` and
## cleared by `complete_summon()` / `abort_summon()`.
##
## This lives in the authoritative state rather than only in `DuelEngine._pending_summon`
## because a card's activation CONDITION is also evaluated on pure-legality paths where no
## engine is attached, and because a **Flip Summon**'s monster never leaves its Monster Zone:
## "is a monster in IN_TRANSIT?" answers the question for the Normal and Special routes only.
var pending_summon_card_id: int = -1

# --- Control leases. RULES_SPEC.md 5.6. ---
## Every change of CONTROL currently in force, oldest first, as a STACK per card.
##
## Each entry is `{"card_id", "source_id", "from_controller", "to_controller", "duration"}`.
## `from_controller` is who controlled the card immediately BEFORE this lease, which is where
## control returns when the lease ends — not necessarily the owner.
##
## Control is state, not presentation: `CardInstance.controller_id` and the Monster Zone
## arrays are the truth, and `owner_id` is never touched by any of this. RULES_SPEC.md 5.6
## [S1 p.52].
var control_leases: Array = []

## TEMPORARY banishments awaiting their stated return timing. RULES_SPEC.md 8.3.
##
## Deliberately the same shape as `control_leases`: a card banished "until the End Phase" is
## a LEASE with an explicit end condition, not a special case bolted onto one card. Each
## entry records where the card must come back to, in what position, and what banished it,
## because none of that is recoverable from the Banished zone afterwards.
var banish_leases: Array = []

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
		Enums.Zone.EXCAVATED: return p.excavated
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
		Enums.Zone.EXCAVATED:
			# Order matters: "place the other on the bottom" and "return them in any order"
			# are both statements about the excavated SEQUENCE, so it is kept as excavated.
			p.excavated.append(card)
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
	# The end of the Deck comes from the REASON, never from a separate option that could
	# disagree with it. `deck_position` remains accepted only for a move whose reason does
	# not itself name an end (a RULE-driven placement). RULES_SPEC.md 8.2.
	var deck_position: String = str(opts.get("deck_position", "top"))
	if Enums.is_return_to_deck(reason):
		deck_position = Enums.deck_position_for(reason)
	var new_position = opts.get("position", null)
	var source_id: int = int(opts.get("source_id", -1))

	# Owner-bound zones. [S1 p.52] A card is only ever excavated from its own Deck, so the
	# excavation holding area is owner-bound for the same reason the Deck is.
	if to_zone in [Enums.Zone.GRAVEYARD, Enums.Zone.HAND, Enums.Zone.DECK,
			Enums.Zone.BANISHED, Enums.Zone.EXTRA_DECK, Enums.Zone.EXCAVATED]:
		to_player = card.owner_id

	var from_zone := card.zone
	var from_player := card.controller_id
	var was_on_field := card.is_on_field()
	# Captured BEFORE the move: `_attach` and the position handling below overwrite
	# `card.position` (a card sent to the GY becomes FACE_UP, one returned to the hand
	# becomes FACE_DOWN), so asking afterwards answers about the destination rather than
	# about where the card came from. RULES_SPEC.md 15.
	var was_face_up := card.is_face_up()

	# "If Summoned this way, banish this card when it leaves the field."
	# [`The Phantom Knights of Shadow Veil`]
	#
	# A DESTINATION replacement, and a different thing from the destruction replacement below:
	# that one swaps WHICH CARD is destroyed, this one swaps WHERE THIS CARD ends up, and it
	# applies to every departure the clause names — destroyed, tributed, returned to the hand,
	# sent to the Graveyard — not to destruction alone. It has to be decided here, before
	# `_detach()`, because after the move the destination is already fixed.
	#
	# Only the DESTINATION is redirected; the REASON is left exactly as it was. That
	# distinction is load-bearing. The card really was destroyed / tributed / returned — it
	# simply does not arrive where that normally sends it — so a clause worded "when this card
	# is destroyed" must still see a destruction. Rewriting the reason to BANISHED would
	# silently delete the destruction event and every trigger keyed on it.
	var redirected_to_banishment := false
	if was_on_field and not Enums.is_on_field_zone(to_zone) \
			and to_zone != Enums.Zone.BANISHED and to_zone != Enums.Zone.IN_TRANSIT \
			and bool(recall(card, BANISH_WHEN_LEAVING_FIELD_KEY, false)):
		to_zone = Enums.Zone.BANISHED
		to_player = card.owner_id
		redirected_to_banishment = true
		# Consumed the moment it fires: the obligation was about THIS stay on the field, and a
		# card that somehow returns later has not been "Summoned this way" again.
		forget(card, BANISH_WHEN_LEAVING_FIELD_KEY)

	_detach(card)

	card.prior_zone = from_zone
	card.prior_controller_id = from_player
	card.controller_id = to_player

	if not _attach(card, to_player, to_zone, index, deck_position):
		# Re-attach where it was so state is never corrupted by a failed move.
		_attach(card, from_player, from_zone, -1, "top")
		card.controller_id = from_player
		return false

	# A new stay in a zone cannot inherit an old material permission. R39.
	if from_zone in [Enums.Zone.MONSTER_ZONE, Enums.Zone.EXTRA_MONSTER_ZONE] and (from_zone != to_zone or from_player != to_player):
		clear_choice_constraints_for(card)

	# Position handling
	if new_position != null:
		card.position = new_position
	elif to_zone in [Enums.Zone.GRAVEYARD, Enums.Zone.BANISHED]:
		card.position = Enums.Position.FACE_UP
	elif to_zone in [Enums.Zone.DECK, Enums.Zone.EXTRA_DECK, Enums.Zone.HAND,
			Enums.Zone.EXCAVATED]:
		card.position = Enums.Position.FACE_DOWN

	# "Shuffle it into the Deck" is one instruction, so the shuffle happens HERE rather than
	# being left to the caller to remember. Before this, a card moved with
	# `SHUFFLED_INTO_DECK` was placed deterministically on top and the Deck was never
	# shuffled — the reason said one thing and the state did another.
	#
	# A card SHUFFLED into the Deck also stops being identifiable [S1 p.5, p.28]. That is
	# keyed on the shuffle rather than on the Deck on purpose: a card placed on top of or on
	# the bottom of the Deck WITHOUT a shuffle keeps what the players legally saw, because
	# its position is still known. RULES_SPEC.md 12.1, design decision 11.
	if to_zone == Enums.Zone.DECK and reason == Enums.MoveReason.SHUFFLED_INTO_DECK:
		shuffle_deck(to_player)

	# Leaving the field resets per-instance effect state. Master prompt 48.
	# The Equip Cards that lose their host are collected FIRST — on_leave_field() clears
	# `equipped_card_ids` — but destroyed only after this card's own events are emitted,
	# so the log reads in causal order: the monster left, therefore its Equip Cards died.
	var orphaned_equips: Array = []
	if was_on_field and not card.is_on_field():
		orphaned_equips = _detach_equips(card)
		card.on_leave_field()
		# A monster that left the field is no longer under anyone's temporary control.
		# It has already gone to its OWNER's zone (forced above), so there is nothing to
		# hand back — the lease is simply over. RULES_SPEC.md 5.6.
		drop_control_leases_for(card)

	# A Trap Monster is a monster ONLY while it occupies a Monster Zone. The instant it goes
	# anywhere else — Graveyard, banished, hand, Deck, or back to where it came from because
	# its Summon was negated — the runtime monster identity is revoked and the card is an
	# ordinary Trap again. RULES_SPEC.md 5.8.
	#
	# This is deliberately NOT folded into `on_leave_field()`, which is the reason it is a
	# separate block: `on_leave_field()` runs only when the card was on the field, and the
	# negated-Summon path never gets there. A monster whose Summon is negated sits in
	# `IN_TRANSIT` and is then put back where it came from, so leaving the identity to
	# `on_leave_field()` would strand a Trap in the Graveyard still answering `is_monster()`.
	# `IN_TRANSIT` itself keeps the identity because that is mid-Summon: the card has to still
	# be a monster for the Summon it is halfway through to be a monster's Summon at all, and
	# for the response window to see one.
	if to_zone != Enums.Zone.MONSTER_ZONE and to_zone != Enums.Zone.EXTRA_MONSTER_ZONE \
			and to_zone != Enums.Zone.IN_TRANSIT:
		card.clear_monster_identity()

	# A card that was TEMPORARILY banished and has now gone somewhere else — another effect
	# moved it to the Graveyard, the hand, the Deck — is never coming back at its scheduled
	# timing: the lease is over the moment the card stops being where the lease describes.
	# Dropped here rather than checked at expiry so a card cannot be returned twice, and so a
	# card that later re-enters the Banished zone by some other route is not caught by a stale
	# lease. RULES_SPEC.md 8.3.
	if from_zone == Enums.Zone.BANISHED and to_zone != Enums.Zone.BANISHED \
			and reason != Enums.MoveReason.RETURNED_FROM_BANISHMENT:
		drop_banish_leases_for(card)

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
		Enums.MoveReason.ADDED_TO_HAND:
			# "Add to your hand" is not "return to the hand" and must not fire a bounce
			# trigger. RULES_SPEC.md 8.
			emit(GameEvent.Kind.CARD_ADDED_TO_HAND, payload)
		Enums.MoveReason.EXCAVATED:
			emit(GameEvent.Kind.CARD_EXCAVATED, payload)
		Enums.MoveReason.RETURNED_TO_DECK_TOP, Enums.MoveReason.RETURNED_TO_DECK_BOTTOM, \
		Enums.MoveReason.SHUFFLED_INTO_DECK:
			emit(GameEvent.Kind.CARD_RETURNED_TO_DECK, payload)
		Enums.MoveReason.TRIBUTED:
			emit(GameEvent.Kind.CARD_TRIBUTED, payload)

	# A departure redirected into banishment IS a banishment as well as whatever it already
	# was, so the banish event fires too. Guarded against double-emitting when the move was a
	# banishment to begin with — that case cannot reach the redirect, but the guard keeps the
	# two emitters from ever disagreeing.
	if redirected_to_banishment and reason != Enums.MoveReason.BANISHED:
		emit(GameEvent.Kind.CARD_BANISHED, payload)

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
# Control. RULES_SPEC.md 5.6 [S1 p.52]
#
# OWNER and CONTROLLER are different things and this subsystem exists to keep them that way.
# Taking control of a monster moves it between the two players' Monster Zone arrays and
# rewrites `CardInstance.controller_id`; it NEVER touches `owner_id`, which is what sends the
# card to its owner's Graveyard, hand or Deck when it later leaves the field — `move_card()`
# already forces `to_player = card.owner_id` for every owner-bound zone.
#
# A control change is deliberately NOT expressed as a `move_card()`. The card does not leave
# the field, so nothing that keys on leaving the field may fire: `on_leave_field()` must not
# run, Equip Cards must not be destroyed, and `last_move_*` must not be rewritten to describe
# a move that did not happen.
#
# Every control change is a LEASE with an explicit end condition (`Enums.ControlDuration`).
# Leases stack per card, oldest first, so two effects taking control of the same monster
# unwind in the right order.
# ---------------------------------------------------------------------------

## Can `new_controller` take control of `card` right now?
##
## The zone requirement is real: a monster can only be controlled from a Monster Zone, so an
## effect that would take control with the taker's field already full simply does nothing.
func can_change_control(card: CardInstance, new_controller: int) -> bool:
	if card == null or not card.is_monster():
		return false
	if card.zone != Enums.Zone.MONSTER_ZONE:
		return false
	if card.controller_id == new_controller:
		return false
	if not player(new_controller).has_free_monster_zone():
		return false
	return true


## Take control of `card`. Returns false if it could not be done, in which case nothing moved.
func change_control(card: CardInstance, new_controller: int, source_id: int,
		duration: Enums.ControlDuration) -> bool:
	if not can_change_control(card, new_controller):
		return false
	var from_controller := card.controller_id
	if not _transfer_control(card, new_controller):
		return false
	control_leases.append({
		"card_id": card.id, "source_id": source_id,
		"from_controller": from_controller, "to_controller": new_controller,
		"duration": duration,
	})
	emit(GameEvent.Kind.CONTROL_CHANGED, {
		"card_id": card.id, "card_name": card.card_name(),
		"from_player": from_controller, "to_player": new_controller,
		"owner": card.owner_id, "source_id": source_id, "duration": duration,
		"reverted": false,
	})
	return true


## Move the card between the two players' Monster Zone arrays. No events, no lease.
func _transfer_control(card: CardInstance, new_controller: int) -> bool:
	var from_controller := card.controller_id
	_detach(card)
	card.controller_id = new_controller
	if not _attach(card, new_controller, Enums.Zone.MONSTER_ZONE, -1, "top"):
		# Never leave the board corrupted: put it back exactly where it was.
		card.controller_id = from_controller
		_attach(card, from_controller, Enums.Zone.MONSTER_ZONE, -1, "top")
		return false
	clear_choice_constraints_for(card)
	return true


## The leases currently in force for one card, oldest first.
func control_leases_for(card_id: int) -> Array:
	return control_leases.filter(func(l): return int(l["card_id"]) == card_id)


## End one lease.
##
## Only the NEWEST lease on a card actually governs where it sits, so ending an older one
## does not move the card — it hands its `from_controller` down to the lease that follows it,
## so that when the newest one eventually ends the card still returns all the way to the
## player who controlled it before any of this started.
func end_control_lease(lease: Dictionary) -> void:
	var idx := control_leases.find(lease)
	if idx == -1:
		return
	var card_id := int(lease["card_id"])
	var later := control_leases_for(card_id)
	var is_newest: bool = later.is_empty() or later[later.size() - 1] == lease
	control_leases.remove_at(idx)

	if not is_newest:
		for entry in control_leases_for(card_id):
			var l: Dictionary = entry
			if int(l["from_controller"]) == int(lease["to_controller"]):
				l["from_controller"] = int(lease["from_controller"])
				break
		return

	var card = instance(card_id)
	if card == null or card.zone != Enums.Zone.MONSTER_ZONE:
		# The card left the field; there is nothing to hand back. It is already in its
		# OWNER's zone, because move_card() sends it there regardless of who controlled it.
		return
	var back_to := int(lease["from_controller"])
	if card.controller_id == back_to:
		return
	# Explicitly typed: `instance()` returns Variant and `:=` cannot infer through one.
	var from_controller: int = card.controller_id
	if not _transfer_control(card, back_to):
		# The original controller's field is full. Control does not revert; recorded rather
		# than papered over, and the lease is still gone so this is not retried forever.
		emit(GameEvent.Kind.CONTROL_CHANGED, {
			"card_id": card.id, "card_name": card.card_name(),
			"from_player": from_controller, "to_player": from_controller,
			"owner": card.owner_id, "source_id": int(lease["source_id"]),
			"duration": lease["duration"], "reverted": true, "no_free_zone": true,
		})
		return
	emit(GameEvent.Kind.CONTROL_CHANGED, {
		"card_id": card.id, "card_name": card.card_name(),
		"from_player": from_controller, "to_player": back_to,
		"owner": card.owner_id, "source_id": int(lease["source_id"]),
		"duration": lease["duration"], "reverted": true,
	})


## End every lease whose card has left the field. There is nothing to hand back — the card is
## already in its owner's zone — so this only stops a stale lease from reverting a card that
## later returns to the field under someone else's effect.
func drop_control_leases_for(card: CardInstance) -> void:
	if card == null:
		return
	for entry in control_leases_for(card.id):
		control_leases.erase(entry)


## Expire the leases whose end condition has been met. Called by `DuelEngine._advance()` at
## every timing point, at the same cadence as the continuous recompute, and by
## `TurnFlow.enter_phase()` when the End Phase begins.
##
## `end_phase_reached` is passed separately rather than read from `state.phase` so that the
## End Phase expiry happens exactly once, as the phase is ENTERED, rather than repeatedly
## for every timing point inside a two-step End Phase.
func expire_control_leases(end_phase_reached: bool = false) -> void:
	# Newest first: ending the newest lease is the only one that moves the card, and
	# unwinding in that order lets each hand back to the one below it.
	var snapshot := control_leases.duplicate()
	snapshot.reverse()
	for entry in snapshot:
		var lease: Dictionary = entry
		if not control_leases.has(lease):
			continue
		match lease["duration"]:
			Enums.ControlDuration.WHILE_SOURCE_FACE_UP:
				var source = instance(int(lease["source_id"]))
				if source == null or not source.is_on_field() or not source.is_face_up():
					end_control_lease(lease)
			Enums.ControlDuration.UNTIL_END_PHASE:
				if end_phase_reached:
					end_control_lease(lease)
			_:
				pass


# ---------------------------------------------------------------------------
# TEMPORARY banishment. RULES_SPEC.md 8.3, CARD_RULINGS.md R30 [S1 p.53].
#
# Banishing is normally permanent and needs nothing here: `EffectPrimitives.pay_banish_cost()`
# and `banish_target()` are plain `move_card()` calls and create no lease. What this subsystem
# exists for is a card whose own text states a RETURN TIMING — in the V1 pool exactly one,
# `Interdimensional Matter Transporter`, "banish that target until the End Phase".
#
# It is deliberately built as a LEASE, the same shape as `control_leases`, and NOT as a field
# on the card or a hook inside one card's script:
#
#   * the authoritative GameState is the only thing that knows a card is due back, so a replay
#     of the state reproduces the return without the card's script being consulted;
#   * the lease records the return destination, the return position and the source, because a
#     card sitting in the Banished zone has already been normalised and cannot be asked;
#   * the expiry hook runs at the same two cadences the control leases use, so the two cannot
#     drift apart about when "the End Phase" is (CARD_RULINGS.md R25);
#   * a card that leaves the Banished zone by any other route drops its lease inside
#     `move_card()`, so a return can never happen twice and never happens to the wrong card.
#
# The return is NOT a Summon. RULES_SPEC.md 8.3 and CARD_RULINGS.md R30 record the three
# consequences that follow and are asserted in `BanishTests`: no Summon event is emitted, no
# successful-Summon trigger may see it, and a Summon-negating card has nothing to answer.
# ---------------------------------------------------------------------------

## Can `card` be banished temporarily right now?
##
## Only a card ON THE FIELD can be, in this pool: the return destination is a field zone, and
## a "banish until the End Phase" clause with nothing to return the card to is not a thing any
## card in the pool prints. Asked separately so a card effect can report "no legal target"
## rather than half-performing.
func can_banish_temporarily(card: CardInstance) -> bool:
	if card == null:
		return false
	if not card.is_on_field():
		return false
	if card.zone == Enums.Zone.IN_TRANSIT:
		return false
	return true


## Banish `card` with a stated return timing. Returns false if it could not be done, in which
## case nothing moved and no lease exists.
##
## `face_up` is the state of the card WHILE BANISHED [S1 p.53, RULES_SPEC.md 12]: a face-up
## banished card is public information and a face-down banished one is not. It is a parameter
## rather than a constant because the two are genuinely different and the distinction must not
## be lost — the V1 pool only ever banishes face-up.
func banish_temporarily(card: CardInstance, source_id: int,
		duration: Enums.BanishDuration, face_up: bool = true) -> bool:
	if not can_banish_temporarily(card):
		return false
	if duration == Enums.BanishDuration.PERMANENT:
		# A permanent banishment is just a move; it must not create a lease that would later
		# hand the card back. Routed through the same call so a caller cannot accidentally
		# get a lease by asking for the wrong duration — and it still honours `face_up`,
		# which is a statement about the banishment itself and has nothing to do with how
		# long it lasts.
		return move_card(card, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED,
			{"source_id": source_id,
			 "position": Enums.Position.FACE_UP if face_up else Enums.Position.FACE_DOWN})

	# Captured BEFORE the move: `move_card()` normalises a banished card's position, so
	# afterwards there is no way to ask what it was. The battle position the monster returns
	# in is the one it left in. CARD_RULINGS.md R30.
	var return_zone := card.zone
	var return_position = card.position
	# The Monster Zone INDEX is deliberately NOT recorded. Nothing in the rules reserves the
	# slot a banished monster left, and another monster may legally be sitting in it by the
	# time this one comes back, so the card returns to the first free zone — deterministic,
	# and the only answer that is always available. Recording an index nothing may act on
	# would be state with no reader, which is the shape of two engine defects already in §4.
	# The card returns under its OWNER's control, not under whoever controlled it at the
	# moment it was banished. This is not a special rule for banishing: leaving the field
	# already ends every control lease on the card (`drop_control_leases_for()` inside
	# `move_card()`), and the Banished zone is owner-bound, so there is nothing left that
	# says anyone else controls it. CARD_RULINGS.md R30, MEDIUM confidence, reasoned.
	var return_controller := card.owner_id

	if not move_card(card, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED,
			{"source_id": source_id,
			 "position": Enums.Position.FACE_UP if face_up else Enums.Position.FACE_DOWN}):
		return false

	banish_leases.append({
		"card_id": card.id, "source_id": source_id, "duration": duration,
		"return_zone": return_zone, "return_position": return_position,
		"return_controller": return_controller, "face_up": face_up,
	})
	return true


## The temporary-banish leases currently in force for one card, oldest first.
func banish_leases_for(card_id: int) -> Array:
	return banish_leases.filter(func(l): return int(l["card_id"]) == card_id)


## Is this card banished with a scheduled return?
func is_temporarily_banished(card_id: int) -> bool:
	return not banish_leases_for(card_id).is_empty()


## End one lease, returning the card if it still can be returned.
##
## The lease is removed FIRST and unconditionally, so no path through this function can leave
## a card scheduled to return twice — including the failure paths.
func end_banish_lease(lease: Dictionary) -> bool:
	var idx := banish_leases.find(lease)
	if idx == -1:
		return false
	banish_leases.remove_at(idx)

	var card = instance(int(lease["card_id"]))
	if card == null or card.zone != Enums.Zone.BANISHED:
		# Another effect moved it out of the Banished zone. `move_card()` normally drops the
		# lease at that moment; this is the belt-and-braces branch and it returns nothing.
		return false

	var to_player := int(lease["return_controller"])
	var to_zone: Enums.Zone = lease["return_zone"]
	# Explicitly typed: `lease[...]` is a Variant and `:=` cannot infer through one.
	var to_position = lease["return_position"]

	if not move_card(card, to_zone, Enums.MoveReason.RETURNED_FROM_BANISHMENT,
			{"to_player": to_player, "position": to_position,
			 "source_id": int(lease["source_id"])}):
		# The return destination is full — the owner's Monster Zones filled up while the card
		# was away. The card cannot return, so it simply stays banished. Recorded as an event
		# rather than papered over, and the lease is already gone so it is not retried
		# forever. Exactly the shape `end_control_lease()` uses for the same situation.
		emit(GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT, {
			"card_id": card.id, "card_name": card.card_name(),
			"to_player": to_player, "owner": card.owner_id,
			"source_id": int(lease["source_id"]), "returned": false, "no_free_zone": true,
		})
		return false

	emit(GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT, {
		"card_id": card.id, "card_name": card.card_name(),
		"to_player": to_player, "owner": card.owner_id,
		"to_zone": to_zone, "position": to_position,
		"source_id": int(lease["source_id"]), "returned": true,
	})
	return true


## Drop every temporary-banish lease on a card without returning it.
func drop_banish_leases_for(card: CardInstance) -> void:
	if card == null:
		return
	for entry in banish_leases_for(card.id):
		banish_leases.erase(entry)


## Expire the temporary banishments whose return timing has arrived.
##
## Called at exactly the two places `expire_control_leases()` is called from — every
## `DuelEngine._advance()` timing point, and `TurnFlow.enter_phase()` as the End Phase is
## entered — so "until the End Phase" cannot come to mean two different moments for control
## and for banishment. CARD_RULINGS.md R25 fixes that moment as the ENTRY to the End Phase,
## before the hand-size discard, which this engine's two-step End Phase makes explicit.
func expire_banish_leases(end_phase_reached: bool = false) -> void:
	# Oldest first: unlike control, these leases do not stack on one card (a card can only be
	# banished once at a time), so the order only fixes the event sequence when several
	# different cards come back at the same moment. It is fixed on purpose — replay
	# determinism depends on it.
	var snapshot := banish_leases.duplicate()
	for entry in snapshot:
		var lease: Dictionary = entry
		if not banish_leases.has(lease):
			continue
		match lease["duration"]:
			Enums.BanishDuration.UNTIL_END_PHASE:
				if end_phase_reached:
					end_banish_lease(lease)
			_:
				pass


# ---------------------------------------------------------------------------
# "Skip your next Battle Phase". RULES_SPEC.md 2.4, CARD_RULINGS.md R1 / R32.
#
# Authoritative turn state, held on PlayerState and asked by
# `TurnFlow.can_enter_battle_phase()`. It is deliberately not a continuous restriction and
# not a card-local flag: no card polls it, and nothing in the presentation layer owns it.
# ---------------------------------------------------------------------------

## "…but skip your next Battle Phase after activation."
##
## **Which** Battle Phase is decided here, once, at the moment the obligation is taken on —
## not later by guesswork. It is THIS turn's when the acquiring player is the turn player and
## their Battle Phase is still ahead of them, and from the next turn onward otherwise.
##
## `battle_phase_conducted_this_turn` is what makes the second case right for a Quick-Play
## Spell activated DURING the Battle Phase: that player is already conducting the Battle
## Phase they are in, so the "next" one is a later turn's. Using `turn_number + 1` for that
## case is safe even though the acquirer's own next turn is two away — the turn in between is
## the opponent's, and this is only ever asked of the turn player.
func impose_battle_phase_skip(pid: int, source_id: int = -1,
		source_name: String = "") -> void:
	var applies_from := turn_number + 1
	if turn_player_id == pid and not battle_phase_conducted_this_turn:
		applies_from = turn_number
	player(pid).battle_phase_skips.append({
		"applies_from_turn": applies_from,
		"source_id": source_id,
		"source_name": source_name,
	})
	emit(GameEvent.Kind.BATTLE_PHASE_SKIP_IMPOSED, {
		"player": pid, "applies_from_turn": applies_from,
		"source_id": source_id, "source_name": source_name,
		"pending": player(pid).battle_phase_skips.size(),
	})


## Is this player currently barred from conducting a Battle Phase by an outstanding skip?
## An obligation acquired for a later turn does not bar the current one.
func has_pending_battle_phase_skip(pid: int) -> bool:
	for entry in player(pid).battle_phase_skips:
		if int((entry as Dictionary).get("applies_from_turn", 0)) <= turn_number:
			return true
	return false


## Spend exactly ONE outstanding obligation — the oldest applicable one, so the order is
## fixed and a replay reproduces it. Returns false when there was nothing to spend.
##
## Called once per turn, from `TurnFlow._end_of_turn_cleanup()`, and only for a turn in which
## the player could otherwise have conducted a Battle Phase. Two obligations therefore cost
## two Battle Phases rather than collapsing into one.
func consume_battle_phase_skip(pid: int) -> bool:
	var p := player(pid)
	for i in range(p.battle_phase_skips.size()):
		var lease: Dictionary = p.battle_phase_skips[i]
		if int(lease.get("applies_from_turn", 0)) > turn_number:
			continue
		p.battle_phase_skips.remove_at(i)
		emit(GameEvent.Kind.BATTLE_PHASE_SKIPPED, {
			"player": pid, "turn": turn_number,
			"source_id": int(lease.get("source_id", -1)),
			"source_name": str(lease.get("source_name", "")),
			"remaining": p.battle_phase_skips.size(),
		})
		return true
	return false


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
			if not card.is_face_up() or card.effects_are_negated():
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


## Can `kind` counters be placed on this card at all?
##
## Two separate requirements. The first is the generic placement rule `place_counters()`
## already enforces: counters go on a face-up card on the field. The second is that some card
## text has to GRANT the card the ability to hold this kind of counter, declared as a
## `COUNTER_CAPACITY_EFFECT_ID` clause. A card with no such clause cannot receive one, which
## is why `Apprentice Magician`'s first clause has no legal target in a pool where nothing
## declares Spell Counter capacity. RULES_SPEC.md 14.
func can_place_counter(card: CardInstance, kind: String) -> bool:
	if card == null or not card.is_on_field() or not card.is_face_up():
		return false
	if card.effects_are_negated():
		return false
	for entry in _query_sources(COUNTER_CAPACITY_EFFECT_ID):
		if entry["card"] != card:
			continue
		var effect: EffectDef = entry["effect"]
		if not effect.condition.is_valid():
			continue
		var ctx := EffectContext.new(self, card, effect)
		ctx.controller_id = card.controller_id
		ctx.params = {"counter": kind}
		if bool(effect.condition.call(ctx)):
			return true
	return false


## Every face-up card on the field, either side, that `kind` counters may be placed on.
func cards_that_can_receive_counter(kind: String) -> Array:
	var out: Array = []
	for p in players:
		for card in p.controlled_cards():
			if can_place_counter(card, kind):
				out.append(card)
	return out


## A card the destruction gate may act on. Normally that means "on the field", with one
## deliberate exception: a monster whose Summon has just been negated waits in
## `Zone.IN_TRANSIT`, and `Champion's Vigilance`'s "and if you do, destroy that card" refers
## to exactly that monster. Routing it through the same entry point is what keeps design
## decision 19 ("there is ONE destruction entry point") true.
static func _is_destroyable_zone(card: CardInstance) -> bool:
	return card != null \
		and (card.is_on_field() or card.zone == Enums.Zone.IN_TRANSIT)


## Carry out a destruction whose prevention check has already been made, applying any
## REPLACEMENT effect. Returns true when SOMETHING was destroyed (possibly the substitute).
func carry_out_destruction(card: CardInstance, reason: Enums.MoveReason,
		source_id: int = -1, depth: int = 0) -> bool:
	if not _is_destroyable_zone(card):
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
	if not _is_destroyable_zone(card):
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
		clear_choice_constraints_for(card)
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
# Revealing and excavating. RULES_SPEC.md 8.2, 12.1.
#
# These are four different things and the engine keeps them four different things:
#
#   * DRAW      — Deck -> hand, private, and a failed draw loses the Duel.
#   * REVEAL    — a hidden card is SHOWN to somebody; it does not move.
#   * EXCAVATE  — cards come OFF the Deck into a holding area and are revealed to both
#                 players; they are not in the Deck, not in the hand and not on the field,
#                 and where each of them goes next is stated by the card that excavated.
#   * SEARCH    — looking THROUGH the Deck for a card, which is private and ends in a
#                 shuffle [S1 p.5]. Nothing here does that; `shuffle_deck()` is its tail.
#
# Collapsing any pair of them would be wrong in an observable way: an excavate that used
# `draw()` would deck a player out and would leak nothing to the opponent, and one that
# used a private peek would hide information both players are entitled to.
# ---------------------------------------------------------------------------

## Show a hidden card's identity to `viewers`. The card does not move.
##
## `revealed_to` is additive: a card seen by a player stays seen until something ends that
## knowledge, which in this engine is exactly a shuffle. RULES_SPEC.md 12.1.
func reveal(card: CardInstance, viewers: Array, source_id: int = -1) -> void:
	if card == null or viewers.is_empty():
		return
	for entry in viewers:
		var pid := int(entry)
		if not card.revealed_to.has(pid):
			card.revealed_to.append(pid)
	var payload := {
		"card_id": card.id, "card_name": card.card_name(),
		"zone": card.zone, "owner": card.owner_id,
		"to": card.revealed_to.duplicate(), "source_id": source_id,
	}
	# An event that names a card only one player may see is private to that player, exactly
	# like CARD_DRAWN. A reveal to BOTH players is public.
	if card.revealed_to.size() < PLAYER_COUNT:
		payload["private_to"] = card.revealed_to.duplicate()
	emit(GameEvent.Kind.CARD_REVEALED, payload)


## The cards `pid` currently has excavated, top of the Deck first.
func excavated_cards(pid: int) -> Array:
	return player(pid).excavated.duplicate()


## "Excavate the top N cards of your Deck." Returns the cards actually taken, in Deck order
## (the card that was on top first).
##
## Takes as many as are there when the Deck holds fewer than N — an excavate is not a draw,
## so a Deck that runs out does NOT lose the Duel [S1 p.35 applies to drawing only]. The
## caller sees the short array and follows its own card's text.
func excavate(pid: int, count: int, source_id: int = -1) -> Array:
	var taken: Array = []
	if count <= 0:
		return taken
	var p := player(pid)
	var n: int = mini(count, p.deck.size())
	for i in range(n):
		var card: CardInstance = p.deck[0]
		if not move_card(card, Enums.Zone.EXCAVATED, Enums.MoveReason.EXCAVATED,
				{"source_id": source_id}):
			break
		taken.append(card)
	if taken.is_empty():
		return taken
	# Excavated cards are revealed to both players, which is what separates an excavate from
	# a private look at the top of the Deck. CARD_RULINGS.md R27.
	var names: Array = []
	for entry in taken:
		var card: CardInstance = entry
		reveal(card, [0, 1], source_id)
		names.append(card.card_name())
	emit(GameEvent.Kind.CARD_EXCAVATED, {
		"player": pid, "count": taken.size(),
		"card_ids": taken.map(func(c: CardInstance) -> int: return c.id),
		"card_names": names, "requested": count, "source_id": source_id,
	})
	return taken


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
		# Excavated cards go through the same `revealed_to` gate as everything else, so an
		# excavate that revealed to both players is visible to both and nothing else is.
		"excavated": p.excavated.map(func(c): return _visible_card(c, viewer_id, false)),
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
		"effects_negated": card.effects_are_negated(),
		"equipped_to": card.equipped_to_id,
		"equipped_cards": card.equipped_card_ids.duplicate(),
	}
	if card.is_monster():
		d["atk"] = card.current_atk()
		d["def"] = card.current_def()
		d["original_atk"] = card.original_atk()
		d["original_def"] = card.original_def()
		# Through the CardInstance accessors, not `definition`: a Trap Monster's Level,
		# Attribute and Type come from the effect that summoned it and the printed Trap
		# carries none of them. RULES_SPEC.md 5.8.
		d["level"] = card.current_level()
		d["attribute"] = card.current_attribute()
		d["race"] = card.current_race()
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

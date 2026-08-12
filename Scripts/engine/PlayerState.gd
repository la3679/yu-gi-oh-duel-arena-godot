class_name PlayerState
extends RefCounted

## Per-player authoritative state. Master prompt 7A.
##
## Zones hold CardInstance references. Ordered zones (Monster, Spell/Trap) are fixed-size
## arrays with null for empty slots, so a card's zone_index is stable and meaningful.

const MONSTER_ZONE_COUNT := 5
const SPELL_TRAP_ZONE_COUNT := 5
const HAND_SIZE_LIMIT := 6  # [S1 p.40]

var id: int = 0
var display_name: String = "Player"
var deck_name: String = ""

var life_points: int = 8000  # [S1 p.32]

# --- Zones ---
var deck: Array = []          # ordered, index 0 == top of Deck
var hand: Array = []
var graveyard: Array = []     # ordered, most recent last [S1 p.4]
var banished: Array = []
var extra_deck: Array = []    # unused by the V1 pool, modelled for later

var monster_zones: Array = []       # size 5, null == empty
var spell_trap_zones: Array = []    # size 5, null == empty
var field_zone = null               # single CardInstance or null
var extra_monster_zone = null       # unused in V1

# --- Per-turn allowances. RULES_SPEC.md 5.1 ---
## One Normal Summon OR Normal Set per turn. [S1 p.24]
var normal_summons_used: int = 0
var normal_summons_allowed: int = 1

# --- Named hard once-per-turn tracking. RULES_SPEC.md 11 ---
## "You can only use this effect of [name] once per turn" -> {"<name>::<effect_id>": turn}
var named_effect_usage: Dictionary = {}
## "You can only activate 1 [name] per turn" -> {"<name>": turn}
var named_activation_usage: Dictionary = {}

# --- Lingering per-player restrictions ---
## e.g. {"skip_next_battle_phase": true, "no_battle_phase_this_turn": true}
var restrictions: Dictionary = {}

var has_lost: bool = false


func _init(p_id: int = 0, p_name: String = "Player") -> void:
	id = p_id
	display_name = p_name
	monster_zones.resize(MONSTER_ZONE_COUNT)
	spell_trap_zones.resize(SPELL_TRAP_ZONE_COUNT)
	for i in range(MONSTER_ZONE_COUNT):
		monster_zones[i] = null
	for i in range(SPELL_TRAP_ZONE_COUNT):
		spell_trap_zones[i] = null


# ---------------------------------------------------------------------------
# Zone queries
# ---------------------------------------------------------------------------

## Face-up and face-down monsters this player controls.
func monsters() -> Array:
	return monster_zones.filter(func(c): return c != null)


func face_up_monsters() -> Array:
	return monsters().filter(func(c): return c.is_face_up())


func spell_traps() -> Array:
	return spell_trap_zones.filter(func(c): return c != null)


## Every card this player currently controls, including the Field Zone.
func controlled_cards() -> Array:
	var out := monsters()
	out.append_array(spell_traps())
	if field_zone != null:
		out.append(field_zone)
	return out


func free_monster_zone_index() -> int:
	for i in range(MONSTER_ZONE_COUNT):
		if monster_zones[i] == null:
			return i
	return -1


func free_spell_trap_zone_index() -> int:
	for i in range(SPELL_TRAP_ZONE_COUNT):
		if spell_trap_zones[i] == null:
			return i
	return -1


func has_free_monster_zone() -> bool:
	return free_monster_zone_index() != -1


func has_free_spell_trap_zone() -> bool:
	return free_spell_trap_zone_index() != -1


func monster_count() -> int:
	return monsters().size()


func deck_count() -> int:
	return deck.size()


func hand_count() -> int:
	return hand.size()


## True when all five Spell & Trap Zones are occupied — the activation condition
## for Straight Flush (official current text).
func all_spell_trap_zones_occupied() -> bool:
	for c in spell_trap_zones:
		if c == null:
			return false
	return true


func count_continuous_spell_traps_controlled() -> int:
	var n := 0
	for c in spell_traps():
		if c.is_face_up() and c.definition != null:
			if c.definition.st_kind == Enums.STKind.CONTINUOUS_SPELL \
					or c.definition.st_kind == Enums.STKind.CONTINUOUS_TRAP:
				n += 1
	if field_zone != null and field_zone.is_face_up() and field_zone.definition != null:
		if field_zone.definition.st_kind == Enums.STKind.CONTINUOUS_SPELL:
			n += 1
	return n


func count_continuous_spell_traps_in_gy() -> int:
	var n := 0
	for c in graveyard:
		if c.definition != null and (c.definition.st_kind == Enums.STKind.CONTINUOUS_SPELL
				or c.definition.st_kind == Enums.STKind.CONTINUOUS_TRAP):
			n += 1
	return n


# ---------------------------------------------------------------------------
# Life Points. RULES_SPEC.md 13.
# ---------------------------------------------------------------------------

## Applies an LP change and returns the actual delta applied (LP never goes below 0).
func change_life_points(delta: int) -> int:
	var before := life_points
	life_points = maxi(0, life_points + delta)
	return life_points - before


func can_pay_life_points(amount: int) -> bool:
	# Paying LP as a cost requires having more than the amount is a common
	# misconception; the rule is you may pay down to exactly 0 only if a card
	# says so. The engine's default is that you must be able to pay the full
	# amount and remain at 1 or more, unless a card overrides it.
	return life_points > amount


# ---------------------------------------------------------------------------
# Per-turn / named usage. RULES_SPEC.md 11.
# ---------------------------------------------------------------------------

func can_normal_summon() -> bool:
	return normal_summons_used < normal_summons_allowed


func consume_normal_summon() -> void:
	normal_summons_used += 1


func mark_named_effect_used(card_name: String, effect_id: String, turn: int) -> void:
	named_effect_usage["%s::%s" % [card_name, effect_id]] = turn


func was_named_effect_used(card_name: String, effect_id: String, turn: int) -> bool:
	return named_effect_usage.get("%s::%s" % [card_name, effect_id], -1) == turn


func mark_named_activation_used(card_name: String, turn: int) -> void:
	named_activation_usage[card_name] = turn


func was_named_activation_used(card_name: String, turn: int) -> bool:
	return named_activation_usage.get(card_name, -1) == turn


func set_restriction(key: String, value) -> void:
	restrictions[key] = value


func get_restriction(key: String, fallback = false):
	return restrictions.get(key, fallback)


func clear_restriction(key: String) -> void:
	restrictions.erase(key)


## Called at the start of this player's turn.
func begin_turn() -> void:
	normal_summons_used = 0
	normal_summons_allowed = 1
	for c in controlled_cards():
		c.reset_turn_state()


## Called at the end of every turn (both players), clearing per-turn usage keyed to
## the turn number. Named usage dictionaries are keyed by turn so they self-expire,
## but stale entries are pruned to keep the state small.
func end_turn(turn: int) -> void:
	for key in named_effect_usage.keys():
		if int(named_effect_usage[key]) < turn:
			named_effect_usage.erase(key)
	for key in named_activation_usage.keys():
		if int(named_activation_usage[key]) < turn:
			named_activation_usage.erase(key)


func _to_string() -> String:
	return "PlayerState(%d '%s' LP=%d)" % [id, display_name, life_points]

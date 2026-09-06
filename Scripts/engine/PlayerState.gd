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
## Holding area for a card that is mid-Summon or mid-activation and is therefore not
## yet on the field. A monster whose Summon is negated never reaches a Monster Zone,
## so it needs somewhere real to live while the response window is open.
var in_transit: Array = []
## Cards currently taken off the top of this player's Deck by an EXCAVATE and not yet
## placed. Held separately from `in_transit` so that "mid-Summon" and "excavated" stay
## different states — see `Enums.Zone.EXCAVATED`. Empty outside a resolving excavation.
var excavated: Array = []

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
## e.g. {"skip_battle_phase_this_turn": true}
var restrictions: Dictionary = {}

## Turn-scoped attack bans keyed by card NAME. RULES_SPEC.md 6.5, CARD_RULINGS.md R41 Part C.
##
## "'Blue-Eyes White Dragon' you control cannot attack the turn you activate this card"
## (`Burst Stream of Destruction`). Deliberately **not** in `restrictions` and **not** either
## of the two continuous prevention channels of 6.4, because it is neither:
##
##   * `CardInstance.flags["cannot_attack"]` names one monster and is rebuilt from the board
##     by `ContinuousEffects.recompute()`. This ban must cover a monster of that name Summoned
##     **after** the activation, and it must survive its source — a Normal Spell that is in
##     the Graveyard before the first attack it forbids could be declared.
##   * `ContinuousEffects.ATTACK_LOCK_KEY` names a player and would ban EVERY monster they
##     control, not the named one.
##
## `card name -> the turn number the ban applies to`, so it **self-expires** at the turn
## boundary exactly the way `named_effect_usage` does and no cleanup hook has to remember it.
var attack_bans_by_name: Dictionary = {}

## Outstanding "skip your NEXT Battle Phase" obligations. RULES_SPEC.md 2.4, CARD_RULINGS.md
## R1/R32.
##
## Deliberately NOT in `restrictions`. Everything in that dictionary is either turn-scoped
## (wiped by `TurnFlow._end_of_turn_cleanup()`) or continuous (rebuilt from the board by
## `ContinuousEffects.recompute()`), and this obligation is neither: it is acquired at one
## moment, belongs to a specific FUTURE turn, survives every turn boundary in between, and is
## CONSUMED by the Battle Phase it costs. A turn-scoped flag would evaporate before the turn
## it applies to; a continuous one would lift the moment its source left the field, and its
## source is a Quick-Play Spell that is in the Graveyard immediately.
##
## An ARRAY rather than a bool, because two obligations are two Battle Phases. Each entry:
##   {"applies_from_turn": int, "source_id": int, "source_name": String}
## `applies_from_turn` is what makes "your NEXT Battle Phase" mean the right one: it is this
## turn when the acquiring player is the turn player and their Battle Phase is still ahead of
## them, and the following turn otherwise.
var battle_phase_skips: Array = []

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
##
## The Extra Monster Zone counts. It is unused by the V1 pool's two decks — both Extra Decks
## are empty — but `Runick Flashing Fire`'s second bullet Summons there by name, so a monster
## sitting in it must be a monster this player controls for every rules question that follows:
## being attacked, being targeted, being Tributed, the control limit. Leaving it out would
## make a monster that is on the field invisible to the rules. [S1 p.6]
func monsters() -> Array:
	var out := monster_zones.filter(func(c): return c != null)
	if extra_monster_zone != null:
		out.append(extra_monster_zone)
	return out


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


## "'<name>' you control cannot attack the turn you activate this card." RULES_SPEC.md 6.5.
##
## Records the ban for `turn` only. Re-applying it in the same turn is idempotent, and
## applying it in a later turn simply overwrites the stale entry, which is why nothing has to
## clear it between turns.
func ban_attacks_by_name(name: String, turn: int) -> void:
	attack_bans_by_name[name] = turn


## Is a monster of this name forbidden to declare an attack for this player, this turn?
func attacks_banned_by_name(name: String, turn: int) -> bool:
	return int(attack_bans_by_name.get(name, -1)) == turn


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
	# Keyed by turn like the two above, so this prune is housekeeping and never the thing
	# that makes the ban expire. `attacks_banned_by_name()` compares turn numbers.
	for key in attack_bans_by_name.keys():
		if int(attack_bans_by_name[key]) < turn:
			attack_bans_by_name.erase(key)


func _to_string() -> String:
	return "PlayerState(%d '%s' LP=%d)" % [id, display_name, life_points]

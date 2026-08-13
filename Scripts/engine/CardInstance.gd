class_name CardInstance
extends RefCounted

## A single runtime copy of a card. Master prompt 9.
##
## Two copies of the same card are distinct instances with distinct ids. Nothing in the
## engine identifies a runtime card by name alone.
##
## Modified stats live here; CardDef keeps the printed values untouched.

## Unique runtime id, assigned by GameState. Stable for the whole duel.
var id: int = -1

var definition: CardDef = null

## Owner never changes. Controller may. [S1 p.52]
var owner_id: int = 0
var controller_id: int = 0

var zone: Enums.Zone = Enums.Zone.DECK
## Index within the zone for Monster / Spell&Trap zones (0..4). -1 for unordered zones.
var zone_index: int = -1

var prior_zone: Enums.Zone = Enums.Zone.DECK
var prior_controller_id: int = 0

var position: Enums.Position = Enums.Position.FACE_DOWN

# --- Stat modification. Master prompt 35. ---
## Permanent-until-removed additive modifiers, e.g. {"source_id": 12, "atk": 700, "def": 0,
## "until": "end_of_turn"|"while_source_on_field"|"permanent", "id": <unique>}
var atk_modifiers: Array = []
var def_modifiers: Array = []
## Set by effects that overwrite the value outright ("make its ATK/DEF 0"). -1 = unset.
var atk_override: int = -1
var def_override: int = -1

# --- Counters. Required by Apprentice Magician / Wonder Balloons. ---
## {"Spell Counter": 2, "Balloon Counter": 3}
var counters: Dictionary = {}

# --- Equip relationships ---
## Instance id of the monster this card is equipped to, or -1.
var equipped_to_id: int = -1
## Instance ids of cards equipped to this monster.
var equipped_card_ids: Array = []

# --- Per-instance history / flags ---
var turn_summoned: int = -1
var turn_set: int = -1
var turn_flipped: int = -1
var summoned_by: Enums.SummonKind = Enums.SummonKind.NORMAL
## True once the monster has been properly Special Summoned (Extra Deck rule; unused in V1
## but modelled so it can be enforced later).
var properly_special_summoned: bool = false
## The effect_id of the SUMMON_PROCEDURE this monster Special Summoned ITSELF with, or "".
## PSCT distinguishes "Special Summoned **this way**" from "Special Summoned" — a
## `Hieratic Dragon of Tefnuit` revived by `Monster Reborn` is not restricted, one that
## used its own procedure is. Written by SummonRules.complete_summon() and cleared by
## on_leave_field(), because a monster that left and came back was not Summoned this way.
var summoned_by_procedure_id: String = ""

# --- The last completed zone change of this card ---
## Recorded AFTER on_leave_field() so it survives the card leaving the field. Clauses like
## `Inari Fire`'s "after this face-up card on the field was destroyed by card effect and
## sent to the GY" need exactly this and cannot use `flags`, which the very move that
## makes the clause relevant has already cleared.
var last_move_reason: Enums.MoveReason = Enums.MoveReason.RULE
var last_move_from_zone: Enums.Zone = Enums.Zone.DECK
var last_move_was_face_up: bool = false
var last_move_turn: int = -1
var last_move_turn_player_id: int = -1

var has_attacked_this_turn: bool = false
var attacks_declared_this_turn: int = 0
var position_changed_this_turn: bool = false
var battled_this_turn: bool = false

## Per-instance once-per-turn usage: {effect_id: turn_number}
var effect_usage: Dictionary = {}
## Per-instance COUNTED per-turn usage, for clauses that allow more than one use in a
## turn: `Gagagashield`'s "Twice per turn, it cannot be destroyed by battle or card
## effects". {effect_id: {"turn": n, "count": k}}
var effect_use_counts: Dictionary = {}
## Free-form per-instance temporary flags, cleared on zone change unless whitelisted.
var flags: Dictionary = {}

## True when the card's effects are currently negated (e.g. by Fiendish Chain).
var effects_negated: bool = false
## True when the card is unaffected by other cards' effects (The Monarchs Awaken).
var unaffected_by_effects: bool = false

## Which players have seen this card's identity while it was hidden.
## Used by hidden-information filtering (master prompt 40) for revealed cards.
var revealed_to: Array = []


func _init(def: CardDef = null, p_owner: int = 0) -> void:
	definition = def
	owner_id = p_owner
	controller_id = p_owner


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

func card_name() -> String:
	return definition.name if definition else "<none>"


func is_monster() -> bool:
	return definition != null and definition.is_monster()


func is_spell() -> bool:
	return definition != null and definition.is_spell()


func is_trap() -> bool:
	return definition != null and definition.is_trap()


## Are this card's effects negated right now?
##
## Two independent channels feed this and they must not be collapsed into one variable:
##
##   * `effects_negated` is a one-shot negation written by whatever caused it and cleared
##     when the card leaves the field or is flipped face-down;
##   * `ContinuousEffects.NEGATION_FLAG` is written by a CONTINUOUS clause that negates
##     ("negate the effects of that face-up monster while it is on the field" —
##     `Fiendish Chain`). It is owned by the continuous system, wiped on every recompute
##     and rebuilt from the board, so it switches off by itself the moment its source
##     stops applying. Nothing outside `ContinuousEffects` may write it.
##
## Every rules-layer question about negation goes through this method, never through the
## raw variable, so a continuously negated card is negated everywhere.
func effects_are_negated() -> bool:
	return effects_negated or bool(flags.get(ContinuousEffects.NEGATION_FLAG, false))


## "Neither player can target monsters on the field with Spell Cards or effects, except this
## one." [`Fairy Tail - Rella`] The flag is owned by `ContinuousEffects` and rebuilt on every
## recompute, so it lifts by itself with its source. It is asked once, in
## `ActivationRules.legal_targets()`, which every candidate list passes through.
##
## It deliberately does NOT cover attack target selection: an attack is not a Spell Card and
## not an effect, and `BattleRules` builds its own target list [S1 p.38].
func cannot_be_targeted() -> bool:
	return bool(flags.get("cannot_be_targeted", false))


func is_face_up() -> bool:
	return Enums.is_face_up(position)


func is_face_down() -> bool:
	return not is_face_up()


func is_on_field() -> bool:
	return Enums.is_on_field_zone(zone)


func is_in_attack_position() -> bool:
	return position == Enums.Position.FACE_UP_ATTACK


func is_in_defense_position() -> bool:
	return Enums.is_defense(position)


# ---------------------------------------------------------------------------
# Stats. Master prompt 35 — never bake modified values into CardDef.
# ---------------------------------------------------------------------------

func base_atk() -> int:
	return definition.base_atk if definition else 0


func base_def() -> int:
	return definition.base_def if definition else 0


## Original ATK, i.e. the printed value. Used by effects that reference "original ATK"
## such as Spiritual Fire Art - Kurenai.
func original_atk() -> int:
	return base_atk()


func original_def() -> int:
	return base_def()


func current_atk() -> int:
	var value := atk_override if atk_override >= 0 else base_atk()
	for m in atk_modifiers:
		value += int(m.get("atk", 0))
	return maxi(0, value)


func current_def() -> int:
	var value := def_override if def_override >= 0 else base_def()
	for m in def_modifiers:
		value += int(m.get("def", 0))
	return maxi(0, value)


func add_atk_modifier(source_id: int, amount: int, duration: String, mod_id: String = "") -> void:
	atk_modifiers.append({
		"source_id": source_id, "atk": amount, "until": duration, "id": mod_id,
	})


func add_def_modifier(source_id: int, amount: int, duration: String, mod_id: String = "") -> void:
	def_modifiers.append({
		"source_id": source_id, "def": amount, "until": duration, "id": mod_id,
	})


func remove_modifiers_from_source(source_id: int) -> void:
	atk_modifiers = atk_modifiers.filter(
		func(m): return int(m.get("source_id", -1)) != source_id)
	def_modifiers = def_modifiers.filter(
		func(m): return int(m.get("source_id", -1)) != source_id)


func remove_modifiers_with_duration(duration: String) -> void:
	atk_modifiers = atk_modifiers.filter(
		func(m): return str(m.get("until", "")) != duration)
	def_modifiers = def_modifiers.filter(
		func(m): return str(m.get("until", "")) != duration)


# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------

func counter_count(kind: String) -> int:
	return int(counters.get(kind, 0))


func add_counters(kind: String, amount: int) -> void:
	counters[kind] = counter_count(kind) + amount


func remove_counters(kind: String, amount: int) -> bool:
	var have := counter_count(kind)
	if have < amount:
		return false
	counters[kind] = have - amount
	if counters[kind] <= 0:
		counters.erase(kind)
	return true


func clear_counters() -> void:
	counters.clear()


# ---------------------------------------------------------------------------
# Once-per-turn usage. Master prompt 47, RULES_SPEC.md 11.
# ---------------------------------------------------------------------------

func mark_effect_used(effect_id: String, turn: int) -> void:
	effect_usage[effect_id] = turn


func was_effect_used_this_turn(effect_id: String, turn: int) -> bool:
	return effect_usage.get(effect_id, -1) == turn


## How many times this clause has already been used THIS turn. A record from an earlier
## turn reads as 0, so the count self-expires without a separate reset pass.
func uses_this_turn(effect_id: String, turn: int) -> int:
	var record = effect_use_counts.get(effect_id, null)
	if record == null or int((record as Dictionary).get("turn", -1)) != turn:
		return 0
	return int((record as Dictionary).get("count", 0))


func record_use_this_turn(effect_id: String, turn: int) -> void:
	effect_use_counts[effect_id] = {
		"turn": turn, "count": uses_this_turn(effect_id, turn) + 1,
	}


func reset_turn_state() -> void:
	has_attacked_this_turn = false
	attacks_declared_this_turn = 0
	position_changed_this_turn = false
	battled_this_turn = false
	remove_modifiers_with_duration("end_of_turn")


## Called when the card changes zone. Per-instance effect state does not survive
## movement unless the specific card text says otherwise. Master prompt 48.
func on_leave_field() -> void:
	effect_usage.clear()
	effect_use_counts.clear()
	summoned_by_procedure_id = ""
	atk_modifiers.clear()
	def_modifiers.clear()
	atk_override = -1
	def_override = -1
	counters.clear()
	flags.clear()
	effects_negated = false
	unaffected_by_effects = false
	equipped_to_id = -1
	equipped_card_ids.clear()
	has_attacked_this_turn = false
	attacks_declared_this_turn = 0
	position_changed_this_turn = false
	battled_this_turn = false
	properly_special_summoned = false
	turn_summoned = -1
	turn_set = -1
	turn_flipped = -1


## Flipping face-down also resets per-instance effect state. Master prompt 48.
func on_flipped_face_down() -> void:
	effect_usage.clear()
	effect_use_counts.clear()
	effects_negated = false
	unaffected_by_effects = false


func _to_string() -> String:
	return "CardInstance#%d(%s)" % [id, card_name()]

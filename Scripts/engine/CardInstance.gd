class_name CardInstance
extends RefCounted

## Identity of this stay on the field; targeting must not chase a returned card. R39.
var field_revision: int = 0

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
## True while this monster counts as having been **Tribute Summoned**, for card text that
## says "Tribute Summoned monster" (`The Monarchs Awaken`). CARD_RULINGS.md R12 Part F.
##
## Deliberately NOT derived from `summoned_by`, which cannot answer the question:
##
##   * a monster Tribute **Set** face-down IS "Tribute Summoned" — official Q&A fid 20548
##     and fid 20533 — but `summoned_by` records `TRIBUTE_SET`, a different value;
##   * a Tribute Summoned monster flipped face-down and Flip Summoned again is STILL
##     "Tribute Summoned" — fid 11352 — but `_complete_flip_summon()` overwrites
##     `summoned_by` with `FLIP`, destroying the record;
##   * a monster **temporarily** banished and returned to the Monster Zone is STILL
##     "Tribute Summoned" — fid 11352 — even though it genuinely left the field (R30).
##
## Written by `SummonRules` on both Tribute routes, carried across a temporary banishment by
## the `banish_leases` record, NOT cleared by `on_flipped_face_down()`, and cleared by
## `on_leave_field()` — a monster that left the field permanently and came back was not
## Tribute Summoned unless it is Tribute Summoned again.
var tribute_summoned: bool = false
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
##
## Read through `is_unaffected_by_effect_of()`, never directly, because the immunity is
## always relative to a SOURCE: the printed wording is "unaffected by the effects of cards
## other than **this card**", so the card that granted it stays able to affect the monster.
## `unaffected_exempt_source_ids` carries that exemption. CARD_RULINGS.md R12 Part D.
##
## Deliberately a plain per-instance field and NOT a `ContinuousEffects` restriction flag:
## `The Monarchs Awaken` is a Normal Trap that is in the Graveyard by the time the state
## matters, and the official duration is "as long as the monster is face-up in the Monster
## Zone" with no condition on the Trap at all (R12 Part D/E). A continuous flag would be
## wiped by the next recompute, which would be wrong.
var unaffected_by_effects: bool = false
## Instance ids exempt from `unaffected_by_effects` — "cards other than **this card**".
## Written only by `EffectImmunity.grant()`, and cleared wherever the immunity is cleared.
var unaffected_exempt_source_ids: Array = []

## Which players have seen this card's identity while it was hidden.
## Used by hidden-information filtering (master prompt 40) for revealed cards.
var revealed_to: Array = []

# --- Trap Monsters. RULES_SPEC.md 5.8 [S1 p.53] ---
## A runtime MONSTER identity for a card whose printed `CardDef` is not a monster.
##
## `The Phantom Knights of Shadow Veil` is a Normal Trap that Special Summons ITSELF "as a
## Normal Monster (Warrior/DARK/Level 4/ATK 0/DEF 300)". While it sits in a Monster Zone it
## really is a monster — it can be attacked, tributed, targeted by "1 monster on the field"
## and destroyed by battle — and in every other zone it is an ordinary Trap Card again.
##
## Two things this deliberately does NOT do:
##
##   * it does not touch `definition`. A `CardDef` is the immutable printed identity and is
##     SHARED by every copy of that card, so writing a temporary type line into it would
##     rewrite the card for the whole duel and for every other copy. Master prompt 9.
##   * it does not pretend the card is an ordinary monster. The printed card is still a Trap,
##     which is why `original_card_category()` keeps answering TRAP and why the card returns
##     to being a plain Trap the moment it leaves the Monster Zone.
##
## Empty on every ordinary card, which is the whole pool bar one. Keys:
##   `race`, `attribute`, `level`, `atk`, `def`, `is_normal_monster`,
##   `treated_as_original_type` (Phantom Knights prints "(This card is NOT treated as a
##   Trap.)", but most Trap Monsters stay Traps, so the text has to say which), and
##   `source_effect_id` for the clause that granted it.
##
## Written only through `become_monster()` and cleared only through
## `clear_monster_identity()`, which `GameState.move_card()` calls on every departure from a
## Monster Zone. Nothing else may write it.
var monster_identity: Dictionary = {}


func _init(def: CardDef = null, p_owner: int = 0) -> void:
	definition = def
	owner_id = p_owner
	controller_id = p_owner


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

func card_name() -> String:
	return definition.name if definition else "<none>"


## Is this card CURRENTLY a monster? A Trap Monster answers yes while it holds a runtime
## monster identity and no everywhere else, which is exactly what the rules ask.
func is_monster() -> bool:
	if not monster_identity.is_empty():
		return true
	return definition != null and definition.is_monster()


func is_spell() -> bool:
	if not monster_identity.is_empty():
		# A card being treated as a monster is a Spell only if its own text says it is still
		# also its printed type. Phantom Knights says it is not.
		return definition != null and definition.is_spell() and _treated_as_original_type()
	return definition != null and definition.is_spell()


func is_trap() -> bool:
	if not monster_identity.is_empty():
		return definition != null and definition.is_trap() and _treated_as_original_type()
	return definition != null and definition.is_trap()


# ---------------------------------------------------------------------------
# Trap Monsters. RULES_SPEC.md 5.8
# ---------------------------------------------------------------------------

func has_monster_identity() -> bool:
	return not monster_identity.is_empty()


func _treated_as_original_type() -> bool:
	return bool(monster_identity.get("treated_as_original_type", false))


## The PRINTED category, which a runtime monster identity never changes. A Trap Monster in a
## Monster Zone is a monster, but the card it is printed on is still a Trap — which is what
## decides where it goes when it leaves, and what it is again once it gets there.
func original_card_category() -> Enums.Category:
	return definition.category if definition else Enums.Category.MONSTER


## Grant this card a runtime monster identity. Called only from the summoning path, and only
## for a card whose own text says it becomes a monster.
func become_monster(identity: Dictionary) -> void:
	monster_identity = identity.duplicate(true)


func clear_monster_identity() -> void:
	monster_identity.clear()


## Current Level / Attribute / Type. These are the readers every rules-layer and card-layer
## question must use, because for a Trap Monster the printed `CardDef` carries none of them —
## `definition.level` is 0 on a Trap and would silently make it a Level 0 monster.
func current_level() -> int:
	if not monster_identity.is_empty():
		return int(monster_identity.get("level", 0))
	return definition.level if definition else 0


func current_attribute() -> String:
	if not monster_identity.is_empty():
		return str(monster_identity.get("attribute", ""))
	return definition.attribute if definition else ""


func current_race() -> String:
	if not monster_identity.is_empty():
		return str(monster_identity.get("race", ""))
	return definition.race if definition else ""


## Is this card currently a NORMAL Monster? Phantom Knights is summoned "as a Normal
## Monster", which matters to any clause that names one.
func is_normal_monster() -> bool:
	if not monster_identity.is_empty():
		return bool(monster_identity.get("is_normal_monster", false))
	return definition != null and definition.is_normal_monster


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


## "…it is unaffected by the effects of cards other than this card." [`The Monarchs Awaken`]
##
## Is an effect whose SOURCE is instance `source_id` prevented from APPLYING to this card?
##
## Three things this deliberately does NOT answer, all three settled from official Konami
## Q&A and all three easy to get wrong (CARD_RULINGS.md R12 Part B):
##
##   * it does not stop the card being **targeted** or otherwise chosen — that is the
##     separate `cannot_be_targeted()` flag, and conflating the two is the single most
##     common misreading of "unaffected";
##   * it does not stop the effect **activating** or **resolving**, and it does not stop the
##     parts of that same effect that apply to some OTHER card;
##   * it does not stop a **cost**, a **Tribute**, or **battle**. None of those is an effect
##     being applied to this card.
##
## `source_id` of -1 means "no card source" — a rules-driven action — and is never blocked.
func is_unaffected_by_effect_of(source_id: int) -> bool:
	if not unaffected_by_effects:
		return false
	if source_id == -1:
		return false
	return not unaffected_exempt_source_ids.has(source_id)


## Does this monster count as "Tribute Summoned" for card text? CARD_RULINGS.md R12 Part F.
func was_tribute_summoned() -> bool:
	return tribute_summoned


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

## The base ATK/DEF this card currently has. For a Trap Monster the granting text states
## them ("ATK 0/DEF 300") and they ARE its printed values while it is a monster — a Trap has
## no printed ATK at all, so there is nothing else they could be. `original_atk()` therefore
## reads them too, which is right: a clause asking for this monster's original ATK while it
## is on the field must get 0, not the 0 that a Trap's empty stat block coincidentally shares.
func base_atk() -> int:
	if not monster_identity.is_empty():
		return int(monster_identity.get("atk", 0))
	return definition.base_atk if definition else 0


func base_def() -> int:
	if not monster_identity.is_empty():
		return int(monster_identity.get("def", 0))
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


## A stat modifier is an effect applied to this card, so an immune card does not receive one
## — whether it would have helped or hurt. RULES_SPEC.md 18, CARD_RULINGS.md R12 Part B;
## official Q&A fid 13065 names "that monster's ATK becomes 0" as blocked, and fid 18199
## makes the point that a BENEFIT is refused just the same.
func add_atk_modifier(source_id: int, amount: int, duration: String, mod_id: String = "") -> void:
	if is_unaffected_by_effect_of(source_id):
		return
	atk_modifiers.append({
		"source_id": source_id, "atk": amount, "until": duration, "id": mod_id,
	})


func add_def_modifier(source_id: int, amount: int, duration: String, mod_id: String = "") -> void:
	if is_unaffected_by_effect_of(source_id):
		return
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


# ---------------------------------------------------------------------------
# Per-card TURN COUNTERS. RULES_SPEC.md 11.
# ---------------------------------------------------------------------------
#
# "You must destroy it during the End Phase of your opponent's 3rd turn"
# (`Swords of Revealing Light`, CARD_RULINGS.md R6) needs a card to count TURNS, which is a
# different thing from every counter already modelled here and must not be folded into one
# of them:
#
#   * `counters` holds GAME counters — Spell Counters, Balloon Counters. Those are placed
#     and removed by card effects and other cards can read and require them. A turn tally is
#     none of those things and putting it there would make it visible to `Wonder Balloons`.
#   * `effect_usage` / `effect_use_counts` answer "has this clause been used this turn?".
#     They self-expire by comparing against the CURRENT turn number, which is exactly wrong
#     for a tally that must survive every turn boundary until it reaches its limit.
#
# The counter is keyed by a card-chosen string and records the last turn it advanced on, so
# advancing twice inside one turn — a phase re-entered, a recompute repeated — cannot
# double-count. It is per INSTANCE and is cleared with the rest of the per-instance state
# when the card leaves the field, because a card that left and came back starts over.

## key -> {"count": int, "last_turn": int}
var turn_counters: Dictionary = {}


## Advance the counter named `key` if it has not already advanced during `turn`.
## Returns the value AFTER this call, whether or not it changed.
func advance_turn_counter(key: String, turn: int) -> int:
	var record = turn_counters.get(key, null)
	if record != null and int((record as Dictionary).get("last_turn", -1)) == turn:
		return int((record as Dictionary).get("count", 0))
	var next := turn_counter_value(key) + 1
	turn_counters[key] = {"count": next, "last_turn": turn}
	return next


func turn_counter_value(key: String) -> int:
	var record = turn_counters.get(key, null)
	if record == null:
		return 0
	return int((record as Dictionary).get("count", 0))


## Has this counter already advanced during `turn`? Lets a clause tell "I counted this turn
## already" apart from "this turn does not count", which are different answers.
func turn_counter_advanced_on(key: String, turn: int) -> bool:
	var record = turn_counters.get(key, null)
	if record == null:
		return false
	return int((record as Dictionary).get("last_turn", -1)) == turn


func reset_turn_counter(key: String) -> void:
	turn_counters.erase(key)


func reset_turn_state() -> void:
	has_attacked_this_turn = false
	attacks_declared_this_turn = 0
	position_changed_this_turn = false
	battled_this_turn = false
	remove_modifiers_with_duration("end_of_turn")


## Called when the card changes zone. Per-instance effect state does not survive
## movement unless the specific card text says otherwise. Master prompt 48.
func on_leave_field() -> void:
	field_revision += 1
	effect_usage.clear()
	effect_use_counts.clear()
	turn_counters.clear()
	summoned_by_procedure_id = ""
	atk_modifiers.clear()
	def_modifiers.clear()
	atk_override = -1
	def_override = -1
	counters.clear()
	flags.clear()
	effects_negated = false
	unaffected_by_effects = false
	unaffected_exempt_source_ids.clear()
	# A monster that LEFT the field was not Tribute Summoned any more. A **temporary**
	# banishment is the documented exception (R12 Part F case 4) and is restored by
	# `GameState.end_banish_lease()` from the lease, not excepted here — this function must
	# stay the single honest "it left" reset.
	tribute_summoned = false
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
##
## `tribute_summoned` is deliberately NOT reset here: official Q&A fid 11352 states that a
## Tribute Summoned monster turned face-down "continues to be treated as a Tribute Summoned
## monster", and fid 20533 states the property holds for a Tribute **Set** monster that has
## never been face-up at all. CARD_RULINGS.md R12 Part F.
func on_flipped_face_down() -> void:
	effect_usage.clear()
	effect_use_counts.clear()
	turn_counters.clear()
	effects_negated = false
	unaffected_by_effects = false
	unaffected_exempt_source_ids.clear()


func _to_string() -> String:
	return "CardInstance#%d(%s)" % [id, card_name()]

class_name SummonRules
extends RefCounted

## Normal Summon / Set / Tribute Summon / Flip Summon / Special Summon, and manual
## battle position changes. RULES_SPEC.md 5, master prompt 21/22/23/30/31.
##
## A Summon is a two-stage process here, because the V1 card pool contains
## `Champion's Vigilance` — "when a monster(s) would be Summoned: Negate the Summon".
## The monster therefore cannot simply appear in a Monster Zone:
##
##   begin_*()      pays the Tributes, puts the card in Zone.IN_TRANSIT and emits
##                  *_SUMMON_DECLARED. DuelEngine then opens a response window.
##   complete()     places the card and emits *_SUMMON_SUCCEEDED.
##   abort()        the Summon was negated; the card never reached the field.
##
## A Normal Set is NOT a Summon [S1 p.24] and so has no declaration window.

## Effect id convention for a card that is worth more than one Tribute.
## `Kaiser Sea Horse`: "This card can be treated as 2 Tributes for the Tribute Summon of
## a LIGHT monster." The card declares a CONTINUOUS EffectDef with this id whose
## `condition` is called with ctx.params["summoning_card"] set, and returns true when the
## card counts as 2 Tributes for that specific Summon.
const TRIBUTE_VALUE_EFFECT_ID := "counts_as_two_tributes"

## Effect id convention for a card-count limit on the field: "You can only control 1
## '<name>'" (`Inari Fire`, `Ranryu`, `Nefarious Archfiend Eater of Nefariousness`).
##
## The card declares a CONTINUOUS EffectDef with this id whose `condition` is a PURE
## query, called with `ctx.params["summoning_card"]` set to the copy that is about to
## reach the field, and returning whether that is allowed. It is checked on EVERY route
## onto the field — Normal Summon, Set, summoning procedure and Special Summon — because
## the limit is on what you may CONTROL [S1 p.53], not on how the copy got there.
const CONTROL_LIMIT_EFFECT_ID := "only_control_one"

var state: GameState = null


func _init(p_state: GameState) -> void:
	state = p_state


# ---------------------------------------------------------------------------
# Tribute requirements. RULES_SPEC.md 5.2 [S1 p.24-25]
# ---------------------------------------------------------------------------

## Level 1-4: 0, Level 5-6: 1, Level 7+: 2.
func tributes_required(card: CardInstance) -> int:
	if card == null or card.definition == null:
		return 0
	return card.definition.base_tributes_required()


## How many Tributes `material` counts as when Tributed for the Summon of `summoned`.
## Defaults to 1; a card may declare itself worth 2 (see TRIBUTE_VALUE_EFFECT_ID).
func tribute_value(material: CardInstance, summoned: CardInstance) -> int:
	if material == null or material.definition == null:
		return 1
	if material.effects_are_negated():
		return 1
	for effect in material.definition.effects:
		if effect.effect_id != TRIBUTE_VALUE_EFFECT_ID:
			continue
		if not effect.condition.is_valid():
			continue
		var ctx := EffectContext.new(state, material, effect)
		ctx.controller_id = material.controller_id
		ctx.params = {"summoning_card": summoned}
		if bool(effect.condition.call(ctx)):
			return 2
	return 1


## May `card` reach `controller_id`'s field at all, given its own control limit?
##
## Returns true for every card that declares no limit, which is all but three of the V1
## pool. A negated card applies no effects, so its limit does not apply either.
## Static so the legality gate in ActivationRules can ask the same question without
## needing a SummonRules instance. There is deliberately only one implementation.
static func control_limit_satisfied(p_state: GameState, card: CardInstance,
		controller_id: int) -> bool:
	if card == null or card.definition == null or card.effects_are_negated():
		return true
	for effect in card.definition.effects:
		if effect.effect_id != CONTROL_LIMIT_EFFECT_ID:
			continue
		if not effect.condition.is_valid():
			continue
		var ctx := EffectContext.new(p_state, card, effect)
		ctx.controller_id = controller_id
		ctx.params = {"summoning_card": card}
		if not bool(effect.condition.call(ctx)):
			return false
	return true


func control_limit_ok(card: CardInstance, controller_id: int) -> bool:
	return control_limit_satisfied(state, card, controller_id)


## Monsters this player may Tribute. Face-up and face-down both count [S1 p.53].
func tribute_candidates(controller_id: int) -> Array:
	return state.player(controller_id).monsters()


## Do the chosen Tributes satisfy the requirement for this Summon?
func tributes_satisfy(summoned: CardInstance, materials: Array) -> bool:
	var need := tributes_required(summoned)
	if need == 0:
		return materials.is_empty()
	var total := 0
	for m in materials:
		total += tribute_value(m, summoned)
	# A card worth 2 Tributes may overshoot a 1-Tribute requirement, which is why this
	# is >= rather than ==; but no MORE cards may be Tributed than the requirement needs.
	if total < need:
		return false
	for m in materials:
		var without := 0
		for other in materials:
			if other != m:
				without += tribute_value(other, summoned)
		if without >= need:
			# `m` was not needed — the player Tributed more monsters than required.
			return false
	return true


# ---------------------------------------------------------------------------
# Legality. RULES_SPEC.md 5.1
# ---------------------------------------------------------------------------

## Can this card be Normal Summoned or Normal Set from the hand right now, ignoring
## which specific Tributes are chosen?
func can_normal_summon_or_set(card: CardInstance, controller_id: int) -> bool:
	if state.is_duel_over():
		return false
	if card == null or not card.is_monster():
		return false
	if card.zone != Enums.Zone.HAND or card.controller_id != controller_id:
		return false
	if state.turn_player_id != controller_id:
		return false
	if state.phase != Enums.Phase.MAIN_1 and state.phase != Enums.Phase.MAIN_2:
		return false
	var p := state.player(controller_id)
	if not p.can_normal_summon():
		return false
	if not control_limit_ok(card, controller_id):
		return false

	var need := tributes_required(card)
	var candidates := tribute_candidates(controller_id)
	if need > 0:
		# Enough Tribute material must exist, counting cards worth 2.
		var best := 0
		for m in candidates:
			best += tribute_value(m, card)
		if best < need:
			return false
		# Tributing frees a zone, so a full field is only a problem at 0 Tributes.
		return true
	return p.has_free_monster_zone()


## Flip Summon: face-down Defense -> face-up Attack only, and never the turn the
## monster was Set. [S1 p.24, p.28]
func can_flip_summon(card: CardInstance, controller_id: int) -> bool:
	if state.is_duel_over():
		return false
	if card == null or not card.is_monster():
		return false
	if card.zone != Enums.Zone.MONSTER_ZONE or card.controller_id != controller_id:
		return false
	if state.turn_player_id != controller_id:
		return false
	if state.phase != Enums.Phase.MAIN_1 and state.phase != Enums.Phase.MAIN_2:
		return false
	if card.position != Enums.Position.FACE_DOWN_DEFENSE:
		return false
	if card.turn_set == state.turn_number:
		return false
	return true


## Manual battle position change. RULES_SPEC.md 5.3 [S1 p.36].
## Illegal when: the monster was played onto the field this turn; it is Main Phase 2 and
## the monster attacked this turn; or its position was already changed this turn.
func can_change_position(card: CardInstance, controller_id: int) -> bool:
	if state.is_duel_over():
		return false
	if card == null or not card.is_monster():
		return false
	if card.zone != Enums.Zone.MONSTER_ZONE or card.controller_id != controller_id:
		return false
	if state.turn_player_id != controller_id:
		return false
	if state.phase != Enums.Phase.MAIN_1 and state.phase != Enums.Phase.MAIN_2:
		return false
	if not card.is_face_up():
		# A face-down monster changes position by Flip Summon, not by a manual change.
		return false
	if card.turn_summoned == state.turn_number or card.turn_set == state.turn_number:
		return false
	if state.phase == Enums.Phase.MAIN_2 and card.has_attacked_this_turn:
		return false
	if card.position_changed_this_turn:
		return false
	return true


func opposite_face_up_position(card: CardInstance) -> Enums.Position:
	return Enums.Position.FACE_UP_DEFENSE if card.position == Enums.Position.FACE_UP_ATTACK \
		else Enums.Position.FACE_UP_ATTACK


# ---------------------------------------------------------------------------
# Normal Summon / Tribute Summon — declaration stage
# ---------------------------------------------------------------------------

## Pays the Tributes, moves the card out of the hand into IN_TRANSIT and announces the
## Summon. Returns a pending-summon record, or null if the Summon was not legal.
##
## The Normal Summon allowance is consumed here: the attempt uses it up even if the
## Summon is subsequently negated.
func begin_normal_summon(card: CardInstance, controller_id: int, tributes: Array,
		zone_index: int = -1) -> Dictionary:
	if not can_normal_summon_or_set(card, controller_id):
		return {}
	if not tributes_satisfy(card, tributes):
		return {}
	for m in tributes:
		if m == null or m.controller_id != controller_id or m.zone != Enums.Zone.MONSTER_ZONE:
			return {}

	var kind: Enums.SummonKind = Enums.SummonKind.TRIBUTE if not tributes.is_empty() \
		else Enums.SummonKind.NORMAL

	state.player(controller_id).consume_normal_summon()
	_pay_tributes(card, tributes, controller_id)

	if not state.player(controller_id).has_free_monster_zone():
		# Should be unreachable: 0-Tribute Summons check for a zone up front and
		# Tributing always frees one. Fail loudly rather than half-summoning.
		push_error("SummonRules: no free Monster Zone after Tributes for %s"
			% card.card_name())
		return {}

	var from_zone := card.zone
	state.move_card(card, Enums.Zone.IN_TRANSIT, Enums.MoveReason.RULE)
	state.pending_summon_card_id = card.id
	state.emit(GameEvent.Kind.NORMAL_SUMMON_DECLARED, {
		"card_id": card.id, "card_name": card.card_name(),
		"player": controller_id, "summon_kind": kind,
		"tribute_ids": tributes.map(func(m): return m.id),
	})
	return {
		"card": card, "controller": controller_id, "kind": kind,
		"zone_index": zone_index, "position": Enums.Position.FACE_UP_ATTACK,
		"origin_zone": from_zone, "negated": false, "source_id": -1,
	}


## Tribute Set. Not a Summon [S1 p.24], so there is no declaration window and no
## SUMMON_SUCCEEDED event — it is completed immediately.
func normal_set_monster(card: CardInstance, controller_id: int, tributes: Array,
		zone_index: int = -1) -> bool:
	if not can_normal_summon_or_set(card, controller_id):
		return false
	if not tributes_satisfy(card, tributes):
		return false
	for m in tributes:
		if m == null or m.controller_id != controller_id or m.zone != Enums.Zone.MONSTER_ZONE:
			return false

	state.player(controller_id).consume_normal_summon()
	_pay_tributes(card, tributes, controller_id)

	if not state.move_card(card, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.SET, {
			"index": zone_index, "to_player": controller_id,
			"position": Enums.Position.FACE_DOWN_DEFENSE}):
		return false
	card.turn_set = state.turn_number
	card.summoned_by = Enums.SummonKind.TRIBUTE_SET if not tributes.is_empty() \
		else Enums.SummonKind.NORMAL_SET
	state.emit(GameEvent.Kind.CARD_SET, {
		"card_id": card.id, "card_name": card.card_name(), "player": controller_id,
		"is_monster": true, "private_to": [controller_id],
	})
	return true


func _pay_tributes(summoned: CardInstance, tributes: Array, controller_id: int) -> void:
	if tributes.is_empty():
		return
	state.emit(GameEvent.Kind.TRIBUTE_SELECTED, {
		"player": controller_id,
		"for_card_id": summoned.id,
		"tribute_ids": tributes.map(func(m): return m.id),
	})
	for m in tributes:
		# Tributing is NOT destruction, but it IS "sent to the Graveyard". [S1 p.52-53]
		state.move_card(m, Enums.Zone.GRAVEYARD, Enums.MoveReason.TRIBUTED,
			{"source_id": summoned.id})


# ---------------------------------------------------------------------------
# Special Summon — declaration stage
# ---------------------------------------------------------------------------

## `position` must be a face-up position unless the summoning card says otherwise;
## `Apprentice Magician` Special Summons in face-down Defense Position, so face-down is
## permitted when the caller explicitly asks for it.
func begin_special_summon(card: CardInstance, controller_id: int,
		position: Enums.Position, source_id: int = -1, zone_index: int = -1) -> Dictionary:
	if state.is_duel_over() or card == null or not card.is_monster():
		return {}
	if not state.player(controller_id).has_free_monster_zone():
		return {}
	# "You can only control 1 …" applies to a Special Summon just as much as to a Normal
	# Summon: the limit is on what you CONTROL, not on how the copy arrived.
	if not control_limit_ok(card, controller_id):
		return {}
	var from_zone := card.zone
	state.move_card(card, Enums.Zone.IN_TRANSIT, Enums.MoveReason.RULE,
		{"to_player": controller_id})
	state.pending_summon_card_id = card.id
	state.emit(GameEvent.Kind.SPECIAL_SUMMON_DECLARED, {
		"card_id": card.id, "card_name": card.card_name(),
		"player": controller_id, "position": position,
		"from_zone": from_zone, "source_id": source_id,
	})
	return {
		"card": card, "controller": controller_id, "kind": Enums.SummonKind.SPECIAL,
		"zone_index": zone_index, "position": position,
		"origin_zone": from_zone, "negated": false, "source_id": source_id,
	}


# ---------------------------------------------------------------------------
# Completion / abort
# ---------------------------------------------------------------------------

## Place the monster and announce success. Returns false if it could no longer be placed.
func complete_summon(pending: Dictionary) -> bool:
	if pending.is_empty():
		return false
	var card: CardInstance = pending["card"]
	var controller_id: int = int(pending["controller"])
	var kind: Enums.SummonKind = pending["kind"]
	var position: Enums.Position = pending["position"]
	state.pending_summon_card_id = -1

	if kind == Enums.SummonKind.FLIP:
		return _complete_flip_summon(card, controller_id)

	if not state.move_card(card, Enums.Zone.MONSTER_ZONE, Enums.MoveReason.SUMMONED, {
			"index": int(pending["zone_index"]), "to_player": controller_id,
			"position": position, "source_id": int(pending.get("source_id", -1))}):
		return false

	card.turn_summoned = state.turn_number
	card.summoned_by = kind
	if kind == Enums.SummonKind.SPECIAL:
		card.properly_special_summoned = true
	# "Special Summoned THIS WAY" — recorded only for a summoning PROCEDURE, i.e. a monster
	# that Special Summoned itself. A monster revived by `Monster Reborn` was Special
	# Summoned, but not "this way", and `Hieratic Dragon of Tefnuit`'s attack restriction
	# depends on the difference (CARD_RULINGS.md §2.1).
	card.summoned_by_procedure_id = str(pending.get("procedure_effect_id", ""))

	var payload := {
		"card_id": card.id, "card_name": card.card_name(),
		"player": controller_id, "summon_kind": kind, "position": position,
		"source_id": int(pending.get("source_id", -1)),
	}
	if kind == Enums.SummonKind.SPECIAL:
		state.emit(GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED, payload)
	else:
		state.emit(GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED, payload)
	return true


## The Summon was negated. The monster never reached the field.
##
## If the negating card also destroys it (`Champion's Vigilance` does), that card's
## effect has already moved it to the Graveyard and there is nothing left in transit.
## Otherwise it returns to where it came from — a negated Summon does not by itself
## destroy the monster.
##
## A negated FLIP Summon is the same rule seen from the other side: the monster never left
## its Monster Zone, so there is nothing to send back and the guard below skips it. It stays
## **face-down** in Defense Position, because the position change was the Summon and the
## Summon did not happen.
## A Flip Summon's monster is already in its Monster Zone, so completing one is a POSITION
## change rather than a move. `complete_summon()` must not be reused unchanged for it.
##
## The turn restrictions are re-tested here rather than trusted from declaration time: the
## response window may have destroyed the monster, banished it, or flipped it face-up by an
## effect. In any of those cases the Flip Summon does not succeed and — critically — no
## `FLIP_SUMMON_SUCCEEDED` event is emitted, so no successful-summon trigger is collected.
func _complete_flip_summon(card: CardInstance, controller_id: int) -> bool:
	if card.zone != Enums.Zone.MONSTER_ZONE or card.controller_id != controller_id:
		return false
	if card.position != Enums.Position.FACE_DOWN_DEFENSE:
		return false
	# Face-down Defense -> face-up ATTACK only. [S1 p.24]
	state.set_battle_position(card, Enums.Position.FACE_UP_ATTACK, false)
	# A Flip Summon is not a manual battle position change, so it does not spend the
	# once-per-turn manual change. RULES_SPEC.md 5.3 [S1 p.36].
	card.position_changed_this_turn = false
	card.turn_summoned = state.turn_number
	card.summoned_by = Enums.SummonKind.FLIP
	# A Flip Summon uses no summoning PROCEDURE, so "Special Summoned this way" is empty.
	card.summoned_by_procedure_id = ""
	state.emit(GameEvent.Kind.FLIP_SUMMON_SUCCEEDED, {
		"card_id": card.id, "card_name": card.card_name(), "player": controller_id,
		"summon_kind": Enums.SummonKind.FLIP,
		"position": Enums.Position.FACE_UP_ATTACK,
	})
	return true


func abort_summon(pending: Dictionary, negated_by_id: int = -1) -> void:
	if pending.is_empty():
		return
	var card: CardInstance = pending["card"]
	state.pending_summon_card_id = -1
	state.emit(GameEvent.Kind.SUMMON_NEGATED, {
		"card_id": card.id, "card_name": card.card_name(),
		"player": int(pending["controller"]), "by_card_id": negated_by_id,
	})
	if card.zone == Enums.Zone.IN_TRANSIT:
		state.move_card(card, pending["origin_zone"], Enums.MoveReason.RULE,
			{"to_player": card.owner_id})


# ---------------------------------------------------------------------------
# Flip Summon / position change
# ---------------------------------------------------------------------------

## Flip Summon — declaration stage. A Flip Summon **is a Summon** [S1 p.24], so it declares
## first and completes only once the response window closes, exactly like the Normal and
## Special routes. That is what lets `Champion's Vigilance` ("when a monster(s) would be
## Summoned") answer one.
##
## What it deliberately does NOT share with the other two routes:
##
##   * **The monster does not move.** It is already in its Monster Zone and stays there,
##     face-down, for the whole window. Parking it in `Zone.IN_TRANSIT` would be a departure
##     from the field, which destroys its Equip Cards and clears its per-instance state —
##     none of which a Flip Summon does.
##   * **It spends no Normal Summon allowance.** A Flip Summon is not a Normal Summon
##     [S1 p.24]; nothing is consumed here.
##   * **Nothing is flipped face-up yet.** The flip IS the Summon, so a negated Flip Summon
##     leaves the monster face-down and no Flip effect ever triggers.
##
## Returns a pending-summon record for `complete_summon()` / `abort_summon()`, or {} if the
## Flip Summon was not legal.
func begin_flip_summon(card: CardInstance, controller_id: int) -> Dictionary:
	if not can_flip_summon(card, controller_id):
		return {}
	state.pending_summon_card_id = card.id
	state.emit(GameEvent.Kind.FLIP_SUMMON_DECLARED, {
		"card_id": card.id, "card_name": card.card_name(),
		"player": controller_id, "summon_kind": Enums.SummonKind.FLIP,
	})
	return {
		"card": card, "controller": controller_id, "kind": Enums.SummonKind.FLIP,
		"zone_index": -1, "position": Enums.Position.FACE_UP_ATTACK,
		"origin_zone": Enums.Zone.MONSTER_ZONE, "negated": false, "source_id": -1,
	}


func change_position(card: CardInstance, controller_id: int) -> bool:
	if not can_change_position(card, controller_id):
		return false
	state.set_battle_position(card, opposite_face_up_position(card), false)
	return true

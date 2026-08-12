class_name DuelAction
extends RefCounted

## One structured, engine-validated action. Master prompt 68/87.
##
## The UI never decides legality: it asks DuelEngine.get_legal_actions() /
## get_legal_responses(), renders what comes back, and submits one of these.
## DuelEngine re-validates on submit, so a hand-built action can never bypass the rules.
##
## Choices that must be made AT ACTIVATION (targets, Tributes, the summon position,
## the zone) are fields of the action rather than mid-action prompts. That keeps the
## whole engine synchronous and deterministic, and matches RULES_SPEC.md 10: targets and
## costs are fixed when the Chain Link is created, not while it resolves.

var kind: Enums.ActionKind = Enums.ActionKind.PASS
var player_id: int = 0

## The card being summoned / set / activated.
var card_id: int = -1
## Which EffectDef of that card. Empty for actions that are not effect activations.
var effect_id: String = ""

var target_ids: Array = []
var tribute_ids: Array = []

## Destination Monster / Spell&Trap zone slot. -1 = first free slot.
var zone_index: int = -1
var position: Enums.Position = Enums.Position.FACE_UP_ATTACK

## Attack declaration: the defending monster, or -1 for a direct attack.
var attack_target_id: int = -1

## Free-form activation data an effect wants carried from activation to resolution.
var params: Dictionary = {}

# ---------------------------------------------------------------------------
# Enumeration metadata.
# Filled in by get_legal_actions()/get_legal_responses() so a caller knows what it
# still has to choose. Ignored when an action is submitted.
# ---------------------------------------------------------------------------

var label: String = ""
var target_candidates: Array = []
var target_min: int = 0
var target_max: int = 0
var tribute_candidates: Array = []
var tributes_required: int = 0
var attack_target_candidates: Array = []
var allows_direct_attack: bool = false
var legal_positions: Array = []
var clause_text: String = ""


func _init(p_kind: Enums.ActionKind = Enums.ActionKind.PASS, p_player: int = 0) -> void:
	kind = p_kind
	player_id = p_player


static func make(p_kind: Enums.ActionKind, p_player: int, p_card_id: int = -1,
		p_effect_id: String = "") -> DuelAction:
	var a := DuelAction.new(p_kind, p_player)
	a.card_id = p_card_id
	a.effect_id = p_effect_id
	return a


## A copy carrying the caller's chosen parameters, leaving the enumerated
## template untouched.
func with_choices(opts: Dictionary) -> DuelAction:
	var a := DuelAction.new(kind, player_id)
	a.card_id = card_id
	a.effect_id = effect_id
	a.target_ids = opts.get("target_ids", target_ids).duplicate()
	a.tribute_ids = opts.get("tribute_ids", tribute_ids).duplicate()
	a.zone_index = int(opts.get("zone_index", zone_index))
	a.position = opts.get("position", position)
	a.attack_target_id = int(opts.get("attack_target_id", attack_target_id))
	a.params = opts.get("params", params).duplicate()
	a.label = label
	a.clause_text = clause_text
	return a


func is_activation() -> bool:
	return kind == Enums.ActionKind.ACTIVATE_CARD \
		or kind == Enums.ActionKind.ACTIVATE_EFFECT


static func kind_name(k: Enums.ActionKind) -> String:
	return Enums.ActionKind.keys()[k]


func to_dict() -> Dictionary:
	return {
		"kind": kind_name(kind),
		"player": player_id,
		"card_id": card_id,
		"effect_id": effect_id,
		"target_ids": target_ids.duplicate(),
		"tribute_ids": tribute_ids.duplicate(),
		"zone_index": zone_index,
		"position": position,
		"attack_target_id": attack_target_id,
		"params": params.duplicate(),
	}


func _to_string() -> String:
	var s := "%s(p%d" % [kind_name(kind), player_id]
	if card_id != -1:
		s += " card#%d" % card_id
	if effect_id != "":
		s += " '%s'" % effect_id
	if not target_ids.is_empty():
		s += " targets=%s" % str(target_ids)
	if not tribute_ids.is_empty():
		s += " tributes=%s" % str(tribute_ids)
	return s + ")"

class_name ChainLink
extends RefCounted

var target_field_revisions: Dictionary = {}

## One link of a Chain. RULES_SPEC.md 4.1, master prompt 12.
##
## Targets and costs are fixed at ACTIVATION time and stored here. Resolution reads
## them back and re-checks target legality against current state (master prompt 44).

## 1-based position in the Chain. Chain Detonation / Chain Healing read this at
## resolution (CARD_RULINGS.md R4), so it is authoritative state, not a display value.
var link_number: int = 0

var source_card: CardInstance = null
var effect: EffectDef = null
var controller_id: int = 0

## Instance ids chosen as targets at activation. RULES_SPEC.md 10.
var target_ids: Array = []
## Snapshot of anything the cost consumed, for logging and for effects that
## reference what was paid.
var cost_payload: Dictionary = {}
## Free-form per-activation data an effect wants to carry from activation to resolution.
var params: Dictionary = {}

## Negation state. RULES_SPEC.md, master prompt 18 — these are distinct.
## activation_negated: the activation itself was negated (the card does not resolve,
## and for a Spell/Trap it is generally treated as not having been activated).
var activation_negated: bool = false
## effect_negated: the activation happened but the effect does not apply.
var effect_negated: bool = false

## Set once the link has resolved (or been skipped due to negation).
var resolved: bool = false
## Recorded outcome for the duel log / UI.
var resolution_note: String = ""


func _init(p_source: CardInstance = null, p_effect: EffectDef = null,
		p_controller: int = 0) -> void:
	source_card = p_source
	effect = p_effect
	controller_id = p_controller


func spell_speed() -> int:
	return effect.spell_speed if effect != null else Enums.SpellSpeed.SS1


func card_name() -> String:
	return source_card.card_name() if source_card != null else "<none>"


func is_negated() -> bool:
	return activation_negated or effect_negated


## Whether this link should actually resolve.
func should_resolve() -> bool:
	return not activation_negated and not effect_negated


func add_target(card: CardInstance) -> void:
	if card != null and not target_ids.has(card.id):
		target_ids.append(card.id)


func targets(state: GameState) -> Array:
	var out := []
	for tid in target_ids:
		var c = state.instance(tid)
		if c != null:
			out.append(c)
	return out


## Chain UI / log projection, respecting hidden information.
## A face-down card that has been activated is public — activating a card reveals it.
func to_visible_dict(viewer_id: int) -> Dictionary:
	return {
		"link_number": link_number,
		"card_id": source_card.id if source_card != null else -1,
		"card_name": card_name(),
		"controller": controller_id,
		"effect_id": effect.effect_id if effect != null else "",
		"clause_text": effect.clause_text if effect != null else "",
		"spell_speed": spell_speed(),
		# Targets on the field are public; the UI resolves ids to cards it can see.
		"target_ids": target_ids.duplicate(),
		"activation_negated": activation_negated,
		"effect_negated": effect_negated,
		"resolved": resolved,
		"resolution_note": resolution_note,
	}


func _to_string() -> String:
	return "CL%d %s (%s) SS%d%s" % [
		link_number, card_name(),
		effect.effect_id if effect != null else "?",
		spell_speed(),
		" NEGATED" if is_negated() else "",
	]

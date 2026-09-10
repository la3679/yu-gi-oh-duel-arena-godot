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

# --- Effect SUBSTITUTION. RULES_SPEC.md 10.11, CARD_RULINGS.md R5. ---
## An effect that has replaced what this link RESOLVES — "the activated effect becomes
## '…'" (`Fairy Tail - Sleeper`).
##
## This is a THIRD thing, distinct from both negations above, and the distinction is the
## whole ruling. The activation stands, the card is still the card that activated, the
## link stays on the Chain in its own position, and the card still resolves and is still
## treated as having resolved. Only the TEXT it resolves is different.
##
## `effect` is deliberately LEFT INTACT rather than overwritten. Two things read it that
## must keep seeing the ORIGINAL card's own effect:
##
##   * `ChainManager._resolve_link()` runs the card's `activation_confirmed` clauses when
##     `effect.effect_type == CARD_ACTIVATION`. Overwriting `effect` with a monster's
##     replacement would change that type and silently skip them — and those clauses are
##     exactly the inherent activation restrictions that official Q&A fid 19695 says
##     SURVIVE the substitution;
##   * the duel log and replay, which must be able to say what the card was and what it
##     became.
var substituted_effect: EffectDef = null
## Instance id of the card whose effect performed the substitution, for the log/replay.
var substituted_by_card_id: int = -1


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
##
## Substitution deliberately does NOT appear here. A substituted link resolves exactly as
## normally as an unsubstituted one; what changed is only WHICH effect runs.
func should_resolve() -> bool:
	return not activation_negated and not effect_negated


func is_substituted() -> bool:
	return substituted_effect != null


## The effect this link will actually RESOLVE — the replacement if one was installed,
## otherwise the card's own. Every read that asks "what runs?" must go through this;
## every read that asks "what card activated, and what did it activate?" must keep using
## `effect`. RULES_SPEC.md 10.11.
func resolving_effect() -> EffectDef:
	return substituted_effect if substituted_effect != null else effect


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
		# What the link will actually resolve, when that is no longer what it activated.
		# Public: the substitution happens on the Chain in front of both players.
		"substituted": is_substituted(),
		"substituted_effect_id": substituted_effect.effect_id if substituted_effect != null else "",
		"substituted_clause_text": substituted_effect.clause_text if substituted_effect != null else "",
		"substituted_by_card_id": substituted_by_card_id,
		"resolved": resolved,
		"resolution_note": resolution_note,
	}


func _to_string() -> String:
	return "CL%d %s (%s) SS%d%s%s" % [
		link_number, card_name(),
		effect.effect_id if effect != null else "?",
		spell_speed(),
		" NEGATED" if is_negated() else "",
		" SUBSTITUTED->%s" % substituted_effect.effect_id if is_substituted() else "",
	]

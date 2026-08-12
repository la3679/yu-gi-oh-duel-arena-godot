class_name DecisionRequest
extends RefCounted

## A structured question the engine asks a player. Master prompt 42/61.
##
## The engine produces these; a PlayerController answers them; the engine validates the
## answer. Only legal choices are ever offered, and a controller that answers illegally
## is a hard error rather than a silently accepted move.
##
## Two kinds of question exist in this engine and both use this type:
##   * timing-window questions the engine asks between actions (activate this optional
##     Trigger Effect? in what order do these simultaneous triggers go?);
##   * choices a card effect needs while it resolves (which card in your GY? how many?).

var kind: Enums.DecisionKind = Enums.DecisionKind.YES_NO
var player_id: int = 0
var prompt: String = ""

## The card/effect the question comes from, for the UI's "why am I being asked this".
var source_card_id: int = -1
var source_card_name: String = ""
var effect_id: String = ""
var clause_text: String = ""

## Candidates. For selection kinds these are CardInstance ids; for CHOOSE_EFFECT and
## ORDER_TRIGGERS they are opaque option dictionaries produced by the caller.
var options: Array = []

var min_count: int = 1
var max_count: int = 1

## Extra caller-defined context (e.g. which trigger group is being ordered).
var context: Dictionary = {}


func _init(p_kind: Enums.DecisionKind = Enums.DecisionKind.YES_NO, p_player: int = 0,
		p_prompt: String = "") -> void:
	kind = p_kind
	player_id = p_player
	prompt = p_prompt


static func yes_no(player: int, prompt: String, source: CardInstance = null,
		effect: EffectDef = null) -> DecisionRequest:
	var r := DecisionRequest.new(Enums.DecisionKind.YES_NO, player, prompt)
	r._attach_source(source, effect)
	return r


static func select(kind: Enums.DecisionKind, player: int, prompt: String,
		options: Array, min_count: int, max_count: int,
		source: CardInstance = null, effect: EffectDef = null) -> DecisionRequest:
	var r := DecisionRequest.new(kind, player, prompt)
	r.options = options.duplicate()
	r.min_count = min_count
	r.max_count = max_count
	r._attach_source(source, effect)
	return r


static func order(player: int, prompt: String, options: Array,
		context: Dictionary = {}) -> DecisionRequest:
	var r := DecisionRequest.new(Enums.DecisionKind.ORDER_TRIGGERS, player, prompt)
	r.options = options.duplicate()
	r.min_count = options.size()
	r.max_count = options.size()
	r.context = context.duplicate()
	return r


func _attach_source(source: CardInstance, effect: EffectDef) -> void:
	if source != null:
		source_card_id = source.id
		source_card_name = source.card_name()
	if effect != null:
		effect_id = effect.effect_id
		clause_text = effect.clause_text


static func kind_name(k: Enums.DecisionKind) -> String:
	return Enums.DecisionKind.keys()[k]


## Is `answer` a structurally valid response to this request?
## The engine calls this before acting on any controller's answer.
func validate(answer) -> bool:
	match kind:
		Enums.DecisionKind.YES_NO:
			return typeof(answer) == TYPE_BOOL
		Enums.DecisionKind.ORDER_TRIGGERS:
			if typeof(answer) != TYPE_ARRAY:
				return false
			if answer.size() != options.size():
				return false
			# Must be a permutation of the offered indices.
			var seen := {}
			for i in answer:
				if typeof(i) != TYPE_INT or i < 0 or i >= options.size() or seen.has(i):
					return false
				seen[i] = true
			return true
		_:
			if typeof(answer) != TYPE_ARRAY:
				return false
			if answer.size() < min_count or answer.size() > max_count:
				return false
			var chosen := {}
			for v in answer:
				if not options.has(v) or chosen.has(v):
					return false
				chosen[v] = true
			return true


func to_dict() -> Dictionary:
	return {
		"kind": kind_name(kind),
		"player": player_id,
		"prompt": prompt,
		"source_card_id": source_card_id,
		"source_card_name": source_card_name,
		"effect_id": effect_id,
		"clause_text": clause_text,
		"options": options.duplicate(),
		"min_count": min_count,
		"max_count": max_count,
		"context": context.duplicate(),
	}


func _to_string() -> String:
	return "DecisionRequest(%s p%d '%s' %d option(s))" % [
		kind_name(kind), player_id, prompt, options.size()]

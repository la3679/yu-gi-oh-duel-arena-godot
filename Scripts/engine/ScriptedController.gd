class_name ScriptedController
extends PlayerController

## Deterministic controller used by the headless test suite. Master prompt 64.
##
## Answers come from an explicit queue, so a test states exactly what a player chooses
## and the run is reproducible. When the queue is empty a documented default policy
## applies, which keeps tests that do not care about a particular prompt short without
## making the outcome arbitrary.
##
## Default policy (used only when `answers` is empty):
##   YES_NO          -> `default_yes`
##   ORDER_TRIGGERS  -> the order the engine offered (identity permutation)
##   selection kinds -> the first `min_count` options
##
## `strict = true` turns an unqueued prompt into a recorded error instead, for tests
## that must prove the engine asked exactly the questions expected.

## FIFO of answers. Each entry is either a bare value, or
## {"kind": Enums.DecisionKind, "answer": <value>} to assert which prompt it belongs to.
var answers: Array = []
var default_yes: bool = false
var strict: bool = false

## Every request seen, in order — tests assert on what the engine asked.
var seen_requests: Array = []
## Populated when a scripted answer was wrong or missing under `strict`.
var errors: Array = []


func _init(p_player_id: int = 0, p_name: String = "Scripted") -> void:
	super(p_player_id, p_name)


func queue(answer) -> ScriptedController:
	answers.append(answer)
	return self


func queue_for(kind: Enums.DecisionKind, answer) -> ScriptedController:
	answers.append({"kind": kind, "answer": answer})
	return self


func decide(request: DecisionRequest):
	seen_requests.append(request)

	if not answers.is_empty():
		var head = answers.pop_front()
		var value = head
		if typeof(head) == TYPE_DICTIONARY and head.has("kind") and head.has("answer"):
			if head["kind"] != request.kind:
				errors.append("expected a %s prompt, engine asked %s ('%s')" % [
					DecisionRequest.kind_name(head["kind"]),
					DecisionRequest.kind_name(request.kind), request.prompt])
			value = head["answer"]
		if not request.validate(value):
			errors.append("scripted answer %s is not valid for '%s'" % [
				str(value), request.prompt])
			return _default_answer(request)
		return value

	if strict:
		errors.append("unqueued prompt: %s '%s'" % [
			DecisionRequest.kind_name(request.kind), request.prompt])
	return _default_answer(request)


func _default_answer(request: DecisionRequest):
	match request.kind:
		Enums.DecisionKind.YES_NO:
			return default_yes
		Enums.DecisionKind.ORDER_TRIGGERS:
			return range(request.options.size())
		_:
			var out := []
			for i in range(mini(request.min_count, request.options.size())):
				out.append(request.options[i])
			return out


func request_count(kind: Enums.DecisionKind) -> int:
	var n := 0
	for r in seen_requests:
		if r.kind == kind:
			n += 1
	return n


func reset() -> void:
	answers.clear()
	seen_requests.clear()
	errors.clear()

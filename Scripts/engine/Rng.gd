class_name Rng
extends RefCounted

## Deterministic seeded RNG. Master prompt 8.
##
## The same seed plus the same sequence of calls always produces the same results,
## which is what makes duels reproducible from the action log. Godot's RandomNumberGenerator
## is explicitly seeded and never reseeded from the system clock.
##
## Every draw from this generator is counted so the log can record how many random
## values a duel consumed, making divergence between a replay and the original obvious.

var _rng := RandomNumberGenerator.new()
var _seed: int = 0
var _calls: int = 0


func _init(initial_seed: int = 0) -> void:
	set_seed(initial_seed)


func set_seed(value: int) -> void:
	_seed = value
	_rng.seed = value
	_rng.state = value
	_calls = 0


func get_seed() -> int:
	return _seed


func get_call_count() -> int:
	return _calls


## Integer in [0, bound). Returns 0 when bound <= 0.
func next_int(bound: int) -> int:
	if bound <= 0:
		return 0
	_calls += 1
	return _rng.randi() % bound


## Integer in [low, high] inclusive.
func range_int(low: int, high: int) -> int:
	if high <= low:
		return low
	return low + next_int(high - low + 1)


## Uniformly random element of an array. Returns null for an empty array.
func pick(items: Array):
	if items.is_empty():
		return null
	return items[next_int(items.size())]


## Fisher-Yates shuffle, in place. Deterministic for a given seed and array size.
## Godot's Array.shuffle() uses the global RNG and is therefore never used here.
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := next_int(i + 1)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


## Returns a shuffled copy, leaving the input untouched.
func shuffled(items: Array) -> Array:
	var copy := items.duplicate()
	shuffle(copy)
	return copy


## Coin flip. true == heads.
func coin_flip() -> bool:
	return next_int(2) == 0


## Standard six-sided die, 1..6.
func die_roll() -> int:
	return next_int(6) + 1


## Snapshot for the duel log / replay verification.
func snapshot() -> Dictionary:
	return {"seed": _seed, "calls": _calls, "state": _rng.state}

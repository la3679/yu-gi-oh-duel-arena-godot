class_name TestCase
extends RefCounted

## Minimal deterministic assertion harness. Master prompt 64.
##
## No third-party test plugin: the engine is headless-testable by design, so a tiny
## in-repo harness keeps the dependency surface at zero and runs under
## `godot --headless --script`.

var suite_name: String = ""
var failures: Array[String] = []
var passed: int = 0
var failed: int = 0
var _current: String = ""

## test name -> assertions executed, in declaration order. Reports/TEST_RESULTS.md quotes
## per-test counts, so they are measured here rather than counted by hand from source —
## a loop over the 9 vanilla Normal Monsters runs far more assertions than it has `t.`
## call sites. Purely observational; nothing in the harness branches on it.
var test_counts: Dictionary = {}
var test_order: Array[String] = []


func _init(p_suite_name: String = "") -> void:
	suite_name = p_suite_name


func start(test_name: String) -> void:
	_current = test_name
	if not test_counts.has(test_name):
		test_counts[test_name] = 0
		test_order.append(test_name)


func _record() -> void:
	if _current != "":
		test_counts[_current] = int(test_counts.get(_current, 0)) + 1


func _fail(msg: String) -> void:
	failed += 1
	_record()
	failures.append("%s :: %s — %s" % [suite_name, _current, msg])


func _ok() -> void:
	passed += 1
	_record()


func check(condition: bool, msg: String) -> bool:
	if condition:
		_ok()
		return true
	_fail(msg)
	return false


func eq(actual, expected, msg: String) -> bool:
	if actual == expected:
		_ok()
		return true
	_fail("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])
	return false


func ne(actual, unexpected, msg: String) -> bool:
	if actual != unexpected:
		_ok()
		return true
	_fail("%s (should not equal %s)" % [msg, str(unexpected)])
	return false


func is_true(v: bool, msg: String) -> bool:
	return check(v, msg)


func is_false(v: bool, msg: String) -> bool:
	return check(not v, msg)


func is_null(v, msg: String) -> bool:
	return check(v == null, msg)


func not_null(v, msg: String) -> bool:
	return check(v != null, msg)


func total() -> int:
	return passed + failed


func report() -> String:
	var head := "%s: %d/%d passed" % [suite_name, passed, total()]
	if failures.is_empty():
		return head
	var lines := [head]
	for f in failures:
		lines.append("    FAIL " + f)
	return "\n".join(lines)

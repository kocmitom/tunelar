extends RefCounted
## Base class for headless tests. Every method starting with `test_` is run by run_all().

var tree: SceneTree
var failures: int = 0
var _current: String = ""


func run_all() -> int:
	for method in get_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		_current = method_name
		var before := failures
		call(method_name)
		print("  [%s] %s" % ["ok" if failures == before else "FAIL", method_name])
	return failures


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("    %s: assertion failed: %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (expected %s +- %s, got %s)" % [message, expected, tolerance, actual])

extends SceneTree
## Headless unit tests: godot --headless --path . --script res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_loom_state.gd",
	"res://tests/test_undo.gd",
	"res://tests/test_solver.gd",
	"res://tests/test_levels.gd",
	"res://tests/test_save.gd",
]


func _initialize() -> void:
	var failures: Array[String] = []
	var checks := 0
	for path in SUITES:
		var suite = load(path).new()
		for method in suite.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			suite.current = name
			var before: int = suite.failures.size()
			suite.call(name)
			var ok: bool = suite.failures.size() == before
			print("%s %s :: %s" % ["PASS" if ok else "FAIL", path.get_file(), name])
		checks += suite.checks
		failures.append_array(suite.failures)
	for f in failures:
		printerr("  FAILED ", f)
	print("%d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

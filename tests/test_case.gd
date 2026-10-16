extends RefCounted
## Minimal assertions for the headless test runner.

var failures: Array[String] = []
var checks := 0
var current := ""


func check(cond: bool, msg := "") -> bool:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])
	return cond


func eq(actual, expected, msg := "") -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


static func world_files() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 3:
		out.append(LevelLoader.load_world("res://levels/world_%d.json" % (i + 1)))
	return out


static func all_levels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in world_files():
		for lv in w.levels:
			out.append(lv)
	return out

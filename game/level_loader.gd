class_name LevelLoader
extends RefCounted
## Reads world JSON files into plain dictionaries with int arrays.
##
## A level stores warp and weft colours, the given parts (via its mode) and one
## known solution. The target is rebuilt from the solution at load, so it can
## never drift out of sync.

const MODES := ["lifting", "threading", "full"]


static func load_world(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Level file missing or empty: %s" % path)
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Level file is not a JSON object: %s" % path)
		return {}
	return normalize_world(data)


static func normalize_world(data: Dictionary) -> Dictionary:
	var world := {
		"world": int(data.get("world", 1)),
		"name": str(data.get("name", "")),
		"mode": str(data.get("mode", "lifting")),
		"palette": PackedStringArray(data.get("palette", [])),
		"levels": [],
	}
	for raw in data.get("levels", []):
		world.levels.append(normalize_level(raw, world))
	return world


static func normalize_level(raw: Dictionary, world: Dictionary) -> Dictionary:
	var sol: Dictionary = raw.get("solution", {})
	var level := {
		"id": str(raw.get("id", "")),
		"name": str(raw.get("name", "")),
		"mode": str(raw.get("mode", world.mode)),
		"shafts": int(raw.get("shafts", 2)),
		"warp": _ints(raw.get("warp", [])),
		"weft": _ints(raw.get("weft", [])),
		"solution": {
			"threading": _ints(sol.get("threading", [])),
			"lifts": _ints(sol.get("lifts", [])),
		},
		"treadles": int(raw.get("treadles", 0)),
		"tutorial": str(raw.get("tutorial", "")),
		"kind": str(raw.get("kind", "normal")),
		"world": world.world,
	}
	if level.treadles > 0:
		level.solution.treadling = _ints(sol.get("treadling", []))
		level.solution.tieup = _ints(sol.get("tieup", []))
	if raw.has("start"):
		var start := {}
		for key in raw.start:
			start[key] = _ints(raw.start[key])
		level.start = start
	return level


static func _ints(a: Array) -> Array[int]:
	var out: Array[int] = []
	for v in a:
		out.append(int(v))
	return out


## Returns a list of problems with a level; empty when it is well formed.
static func validate(level: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var w: int = level.warp.size()
	var h: int = level.weft.size()
	if w < 1 or h < 1:
		errors.append("empty loom")
	if not MODES.has(level.mode):
		errors.append("unknown mode %s" % level.mode)
	if level.shafts < 2 or level.shafts > LoomState.MAX_SHAFTS:
		errors.append("bad shaft count %d" % level.shafts)
	if level.solution.threading.size() != w:
		errors.append("threading length %d != %d" % [level.solution.threading.size(), w])
	if level.solution.lifts.size() != h:
		errors.append("lifts length %d != %d" % [level.solution.lifts.size(), h])
	for s in level.solution.threading:
		if s < LoomState.UNTIED or s >= level.shafts:
			errors.append("threading uses shaft %d" % s)
	for m in level.solution.lifts:
		if m < 0 or m >= (1 << level.shafts):
			errors.append("lift mask %d out of range" % m)
	var t: int = level.get("treadles", 0)
	if t > 0:
		if level.mode != "lifting":
			errors.append("treadles need a lifting level")
		var sol: Dictionary = level.solution
		if sol.get("treadling", []).size() != h or sol.get("tieup", []).size() != t:
			errors.append("treadle solution has the wrong size")
		else:
			for r in h:
				if sol.treadling[r] < 0 or sol.treadling[r] >= t:
					errors.append("row %d uses treadle %d" % [r, sol.treadling[r]])
				elif sol.tieup[sol.treadling[r]] != sol.lifts[r]:
					errors.append("row %d lifts do not match its treadle" % r)
	return errors

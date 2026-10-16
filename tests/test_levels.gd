extends "res://tests/test_case.gd"


func test_world_layout() -> void:
	var worlds := world_files()
	eq(worlds.size(), 3, "three worlds")
	var modes := ["lifting", "threading", "full"]
	var ids := {}
	for i in worlds.size():
		var w: Dictionary = worlds[i]
		current = "world %d" % (i + 1)
		eq(w.levels.size(), 20, "20 levels")
		eq(w.mode, modes[i], "world mode")
		check(w.palette.size() >= 5, "palette")
		for j in w.levels.size():
			var lv: Dictionary = w.levels[j]
			check(not ids.has(lv.id), "unique id %s" % lv.id)
			ids[lv.id] = true
			eq(lv.id, "%d-%d" % [i + 1, j + 1], "id order")
			if i > 0 or j >= 5:
				eq(lv.mode, modes[i], "%s mode" % lv.id)
	eq(ids.size(), 60, "60 levels")


func test_level_limits() -> void:
	for lv in all_levels():
		current = lv.id
		check(lv.warp.size() <= 8 and lv.weft.size() <= 8, "at most 8 x 8")
		check(lv.shafts >= 2 and lv.shafts <= 3, "2 to 3 shafts")
		check(lv.name.length() > 0, "has a name")
		var errors := LevelGenerator.check(lv)
		check(errors.is_empty(), ", ".join(errors))


func test_tutorial_comes_first() -> void:
	var levels := all_levels()
	for i in 5:
		current = levels[i].id
		eq(levels[i].kind, "tutorial", "tutorial level")
		check(not levels[i].tutorial.is_empty(), "has a tutorial step")
	eq(levels[0].weft.size(), 1, "first level is one row")
	eq(levels[4].mode, "threading", "fifth level teaches one drag")
	check(levels[5].tutorial.is_empty(), "tutorial ends after five")


func test_breathers_and_showpieces() -> void:
	for w in world_files():
		current = "world %d" % w.world
		for j in w.levels.size():
			var lv: Dictionary = w.levels[j]
			if (j + 1) % 10 == 0:
				eq(lv.kind, "showpiece", "%s is a showpiece" % lv.id)
			elif (j + 1) % 5 == 0 and lv.kind != "tutorial":
				eq(lv.kind, "breather", "%s is a breather" % lv.id)


func test_committed_levels_match_generator() -> void:
	current = "generator"
	var gen := LevelGenerator.new()
	var worlds := gen.generate()
	for i in worlds.size():
		var fresh := LevelLoader.normalize_world(JSON.parse_string(JSON.stringify(worlds[i])))
		var saved := world_files()[i]
		eq(JSON.stringify(fresh), JSON.stringify(saved),
				"levels/world_%d.json is stale: run tools/generate_levels.gd" % (i + 1))

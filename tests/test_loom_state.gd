extends "res://tests/test_case.gd"


func _level(mode := "lifting") -> Dictionary:
	return LevelLoader.normalize_level({
		"id": "t", "mode": mode, "shafts": 2,
		"warp": [1, 1, 2, 2], "weft": [0, 3],
		"solution": {"threading": [0, 1, 0, 1], "lifts": [1, 2]},
	}, {"world": 1, "mode": mode})


func test_target_built_from_solution() -> void:
	var s := LoomState.from_level(_level())
	# Row 0 lifts A: warps 0 and 2 show. Row 1 lifts B: warps 1 and 3 show.
	eq(s.target, PackedInt32Array([1, 0, 2, 0, 3, 1, 3, 2]), "target")


func test_given_parts_per_mode() -> void:
	var lifting := LoomState.from_level(_level("lifting"))
	check(lifting.given_threading and not lifting.given_lifts, "lifting gives threading")
	eq(lifting.threading, PackedInt32Array([0, 1, 0, 1]), "threading given")
	eq(lifting.lifts, PackedInt32Array([0, 0]), "lifts start down")
	var threading := LoomState.from_level(_level("threading"))
	check(threading.given_lifts and not threading.given_threading, "threading gives lifts")
	eq(threading.threading, PackedInt32Array([-1, -1, -1, -1]), "warps start untied")
	var full := LoomState.from_level(_level("full"))
	check(not full.given_lifts and not full.given_threading, "full gives nothing")


func test_cell_color_rule() -> void:
	var s := LoomState.from_level(_level())
	eq(s.cell_color(0, 0), 0, "nothing lifted shows weft")
	s.toggle_lift(0, 0)
	eq(s.cell_color(0, 0), 1, "lifted shaft shows warp")
	eq(s.cell_color(1, 0), 0, "other shaft still weft")
	s.set_threading(1, LoomState.UNTIED)
	s.toggle_lift(0, 1)
	eq(s.cell_color(1, 0), 0, "untied warp never lifts")


func test_matches_after_solution() -> void:
	var s := LoomState.from_level(_level())
	check(not s.matches_target(), "start does not match")
	s.set_row_lifts(0, 1)
	check(s.row_matches(0) and not s.row_matches(1), "row 0 matches alone")
	s.set_row_lifts(1, 2)
	check(s.matches_target(), "solution matches")


func test_signals() -> void:
	var s := LoomState.from_level(_level())
	var rows := []
	var cols := []
	s.row_changed.connect(func(r, old): rows.append([r, old]))
	s.column_changed.connect(func(c, old): cols.append([c, old]))
	s.toggle_lift(1, 1)
	s.set_row_lifts(1, 2) # no change: no signal
	s.set_threading(2, 1)
	eq(rows, [[1, 0]], "row signal")
	eq(cols, [[2, 0]], "column signal")


func test_copy_is_independent() -> void:
	var s := LoomState.from_level(_level())
	var c := s.copy()
	c.toggle_lift(0, 0)
	eq(s.lifts[0], 0, "original untouched")

extends "res://tests/test_case.gd"

var rng := RandomNumberGenerator.new()


func _apply(state: LoomState, sol: Dictionary) -> void:
	state.load_setup(sol.threading, sol.lifts)


## Applies hints until solved; returns the number of hints, or -1 if stuck.
func _hint_until_solved(state: LoomState, limit: int) -> int:
	for i in limit:
		if state.matches_target():
			return i
		var h := LoomSolver.hint(state)
		if h.is_empty():
			return -1
		LoomCommands.from_hint(state, h).do()
	return limit if state.matches_target() else -1


func _scramble(state: LoomState) -> void:
	if not state.given_threading:
		for c in state.width:
			state.threading[c] = rng.randi_range(-1, state.shafts - 1)
	if not state.given_lifts:
		for r in state.height:
			state.lifts[r] = rng.randi() % (1 << state.shafts)


func test_every_level_has_a_solution() -> void:
	for lv in all_levels():
		current = "solution " + lv.id
		var s := LoomState.from_level(lv)
		check(not s.matches_target(), "starts unsolved")
		var sol := LoomSolver.find_solution(s)
		if check(not sol.is_empty(), "solver finds a solution"):
			_apply(s, sol)
			check(s.matches_target(), "solver solution weaves the target")
		var known := LoomState.from_level(lv)
		_apply(known, lv.solution)
		check(known.matches_target(), "stored solution weaves the target")


func test_hints_solve_every_level_from_start() -> void:
	for lv in all_levels():
		current = "hints " + lv.id
		var s := LoomState.from_level(lv)
		var used := _hint_until_solved(s, s.width + s.height + 2)
		check(used > 0, "hints reach the target (got %d)" % used)


func test_hints_recover_from_scrambled_setups() -> void:
	rng.seed = 7
	for lv in all_levels():
		current = "scrambled " + lv.id
		for trial in 4:
			var s := LoomState.from_level(lv)
			_scramble(s)
			var used := _hint_until_solved(s, 2 * (s.width + s.height) + 2)
			check(used >= 0, "trial %d recovers" % trial)


func test_tutorial_moves_are_single_actions() -> void:
	for lv in all_levels():
		current = "next_move " + lv.id
		var s := LoomState.from_level(lv)
		var steps := 0
		while not s.matches_target() and steps < 200:
			var m := LoomSolver.next_move(s)
			if not check(not m.is_empty(), "a move exists at step %d" % steps):
				break
			if m.kind == "lift":
				s.toggle_lift(m.row, m.shaft)
			else:
				s.set_threading(m.col, m.shaft)
			steps += 1
		check(s.matches_target(), "moves reach the target")


func test_hint_respects_given_parts() -> void:
	for lv in all_levels():
		current = "given " + lv.id
		var s := LoomState.from_level(lv)
		var h := LoomSolver.hint(s)
		if s.given_threading:
			eq(h.kind, "row", "lifting hints set rows")
		elif s.given_lifts:
			eq(h.kind, "warp", "threading hints set warps")


func test_lifting_hint_keeps_free_switches() -> void:
	# Shaft B's only warp shows the same colour either way, so B is free.
	var lv := LevelLoader.normalize_level({
		"id": "t", "mode": "lifting", "shafts": 2,
		"warp": [1, 0], "weft": [0],
		"solution": {"threading": [0, 1], "lifts": [1]},
	}, {"world": 1, "mode": "lifting"})
	var s := LoomState.from_level(lv)
	s.lifts[0] = 2
	var h := LoomSolver.hint(s)
	eq(h.get("lifts"), 3, "keeps the player's free B switch")


func test_unsolvable_target_is_detected() -> void:
	var lv := LevelLoader.normalize_level({
		"id": "t", "mode": "full", "shafts": 2,
		"warp": [1, 2], "weft": [0],
		"solution": {"threading": [0, 1], "lifts": [3]},
	}, {"world": 3, "mode": "full"})
	var s := LoomState.from_level(lv)
	s.target[0] = 4 # a colour no thread has
	check(not LoomSolver.is_solvable(s), "unsolvable")
	check(LoomSolver.hint(s).is_empty(), "no hint for unsolvable")


func test_full_loom_needs_grouping() -> void:
	# Columns 0 and 2 behave alike, as do 1 and 3: two shafts suffice, one does not.
	var lv := LevelLoader.normalize_level({
		"id": "t", "mode": "full", "shafts": 2,
		"warp": [1, 1, 1, 1], "weft": [0, 0],
		"solution": {"threading": [0, 1, 0, 1], "lifts": [1, 2]},
	}, {"world": 3, "mode": "full"})
	var s := LoomState.from_level(lv)
	var empty := PackedInt32Array()
	check(not LoomSolver.solve_full(s, empty, empty, 2).is_empty(), "two shafts")
	check(LoomSolver.solve_full(s, empty, empty, 1).is_empty(), "one shaft is not enough")

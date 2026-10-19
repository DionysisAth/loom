extends "res://tests/test_case.gd"
## Prototype lab rules: weaving (A) and threading (B).


func test_weave_levels_can_be_woven() -> void:
	for i in WeaveLevels.LEVELS.size():
		var lv: Dictionary = WeaveLevels.LEVELS[i]
		current = "weave " + lv.name
		var loom := WeaveLoom.from_level(lv)
		if loom.editable:
			for p in lv.solution.tieup.size():
				for s in loom.shafts:
					if (lv.solution.tieup[p] >> s) & 1:
						loom.toggle_tie(p, s)
		while loom.next_row() < loom.height():
			var p := loom.right_pedal()
			if not check(p >= 0, "a pedal weaves row %d" % loom.next_row()):
				break
			check(loom.weave(p), "row %d is right" % (loom.next_row() - 1))
		check(loom.complete(), "the cloth is complete")
		eq(loom.mistakes_made, 0, "no mistakes")


func test_weave_mistakes_and_unpick() -> void:
	var loom := WeaveLoom.from_level(WeaveLevels.LEVELS[0])
	var wrong := 1 - loom.right_pedal()
	check(not loom.weave(wrong), "the wrong pedal weaves a wrong row")
	eq(loom.mistakes_made, 1, "counted")
	check(not loom.complete(), "not complete with a wrong row")
	check(loom.unpick(), "unpick")
	eq(loom.next_row(), 0, "back to the first row")
	check(loom.weave(loom.right_pedal()), "the right pedal weaves it right")


func test_untied_pedals_lift_nothing() -> void:
	var loom := WeaveLoom.from_level(WeaveLevels.LEVELS[2])
	eq(loom.pedals, PackedInt32Array([0, 0]), "editable pedals start untied")
	eq(loom.right_pedal(), -1, "no pedal fits before tying")
	loom.toggle_tie(0, 0)
	eq(loom.right_pedal(), 0, "tying A makes pedal 1 fit the first row")


func _lay(p: ThreadPuzzle, color: int, cells: Array) -> bool:
	var first := Vector2i(cells[0][0], cells[0][1])
	if p.begin(first) != color:
		return false
	for i in range(1, cells.size()):
		if not p.extend(color, Vector2i(cells[i][0], cells[i][1])):
			return false
	return true


func test_thread_levels_have_their_solution() -> void:
	for lv in ThreadLevels.LEVELS:
		current = "thread " + lv.name
		var p := ThreadPuzzle.from_level(lv)
		for color in lv.solution:
			check(_lay(p, color, lv.solution[color]), "thread %d can be laid" % color)
		for pg in p.pegs:
			check(p.connected(pg.color), "thread %d connected" % pg.color)
		eq(p.filled(), p.width * p.height, "every cell filled")
		check(p.complete(), "woven")


func test_thread_rules() -> void:
	var p := ThreadPuzzle.from_level(ThreadLevels.LEVELS[1])
	# Red runs across row 2 through the crossing at (2, 2).
	check(_lay(p, 0, [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]]), "red reaches the crossing")
	check(not p.extend(0, Vector2i(2, 3)), "no turning inside a crossing")
	check(p.extend(0, Vector2i(3, 2)), "straight on through the crossing")
	# Blue crosses red straight through the crossing.
	check(_lay(p, 1, [[1, 1], [1, 0], [2, 0], [3, 0], [3, 1], [2, 1], [2, 2]]), "blue enters the crossing")
	eq(p.occupants(Vector2i(2, 2)).size(), 2, "two threads share the crossing")
	check(p.extend(1, Vector2i(2, 3)), "blue goes on down")
	# Drawing over a thread outside a crossing pulls that thread back.
	var q := ThreadPuzzle.from_level(ThreadLevels.LEVELS[0])
	_lay(q, 0, [[0, 0], [1, 0], [2, 0]])
	q.begin(Vector2i(0, 2))
	q.extend(1, Vector2i(1, 2))
	q.extend(1, Vector2i(1, 1))
	check(q.extend(1, Vector2i(1, 0)), "blue can cut through red")
	eq(q.path(0).size(), 1, "red is pulled back to before the cut")
	check(not q.extend(1, Vector2i(0, 0)), "blue cannot end on red's knot")
	# Backing up shortens the thread.
	check(q.extend(1, Vector2i(1, 1)), "back up")
	eq(q.path(1).size(), 3, "shorter")

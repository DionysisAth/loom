extends "res://tests/test_case.gd"


func _state() -> LoomState:
	return LoomState.from_level(LevelLoader.normalize_level({
		"id": "t", "mode": "full", "shafts": 3,
		"warp": [1, 1, 1], "weft": [0, 0],
		"solution": {"threading": [0, 1, 2], "lifts": [1, 6]},
	}, {"world": 3, "mode": "full"}))


func test_toggle_and_undo() -> void:
	var s := _state()
	var stack := UndoStack.new()
	stack.push(LoomCommands.ToggleLift.new(s, 0, 2))
	stack.push(LoomCommands.ToggleLift.new(s, 1, 0))
	eq(s.lifts, PackedInt32Array([4, 1]), "after toggles")
	eq(stack.size(), 2, "two commands")
	stack.undo()
	eq(s.lifts, PackedInt32Array([4, 0]), "undo one")
	stack.undo()
	eq(s.lifts, PackedInt32Array([0, 0]), "undo both")
	check(not stack.can_undo(), "empty")
	check(stack.undo() == null, "undo on empty is safe")


func test_threading_undo_restores_previous_shaft() -> void:
	var s := _state()
	var stack := UndoStack.new()
	stack.push(LoomCommands.SetThreading.new(s, 1, 2))
	stack.push(LoomCommands.SetThreading.new(s, 1, 0))
	eq(s.threading[1], 0, "moved twice")
	stack.undo()
	eq(s.threading[1], 2, "back to first move")
	stack.undo()
	eq(s.threading[1], LoomState.UNTIED, "back to untied")


func test_hint_commands_are_marked() -> void:
	var s := _state()
	var cmd := LoomCommands.from_hint(s, {"kind": "row", "row": 1, "lifts": 6})
	check(cmd.is_hint, "hint flag")
	var stack := UndoStack.new()
	stack.push(cmd)
	eq(s.lifts[1], 6, "hint applied")
	stack.undo()
	eq(s.lifts[1], 0, "hint undone")
	check(LoomCommands.from_hint(s, {}) == null, "empty hint gives no command")

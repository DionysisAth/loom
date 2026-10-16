class_name LoomCommands
extends RefCounted
## Every player action on the loom, wrapped as an undoable command.


## Tap a row's shaft switch: flips every crossing in that row on that shaft.
class ToggleLift extends Command:
	var state: LoomState
	var row: int
	var shaft: int

	func _init(s: LoomState, r: int, sh: int) -> void:
		state = s
		row = r
		shaft = sh

	func do() -> void:
		state.toggle_lift(row, shaft)

	func undo() -> void:
		state.toggle_lift(row, shaft)


## Set a whole row's lifts at once (used by hints).
class SetRowLifts extends Command:
	var state: LoomState
	var row: int
	var mask: int
	var _old := 0

	func _init(s: LoomState, r: int, m: int, hint := false) -> void:
		state = s
		row = r
		mask = m
		is_hint = hint

	func do() -> void:
		_old = state.lifts[row]
		state.set_row_lifts(row, mask)

	func undo() -> void:
		state.set_row_lifts(row, _old)


## Tie a warp thread onto a shaft.
class SetThreading extends Command:
	var state: LoomState
	var col: int
	var shaft: int
	var _old := LoomState.UNTIED

	func _init(s: LoomState, c: int, sh: int, hint := false) -> void:
		state = s
		col = c
		shaft = sh
		is_hint = hint

	func do() -> void:
		_old = state.threading[col]
		state.set_threading(col, shaft)

	func undo() -> void:
		state.set_threading(col, _old)


## Builds the command for a hint returned by LoomSolver.hint().
static func from_hint(state: LoomState, h: Dictionary) -> Command:
	if h.is_empty():
		return null
	if h.kind == "row":
		return SetRowLifts.new(state, h.row, h.lifts, true)
	return SetThreading.new(state, h.col, h.shaft, true)

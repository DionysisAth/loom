class_name UndoStack
extends RefCounted
## Unlimited, free undo. Only commands pushed here may change the game state,
## so every move can be taken back.

signal changed

var _done: Array[Command] = []


func push(cmd: Command) -> void:
	cmd.do()
	_done.append(cmd)
	changed.emit()


func undo() -> Command:
	if _done.is_empty():
		return null
	var cmd: Command = _done.pop_back()
	cmd.undo()
	changed.emit()
	return cmd


func can_undo() -> bool:
	return not _done.is_empty()


func size() -> int:
	return _done.size()


func clear() -> void:
	_done.clear()
	changed.emit()

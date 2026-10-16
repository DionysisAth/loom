class_name Command
extends RefCounted
## One undoable player action. Subclasses change the game state in do()
## and restore it exactly in undo().

## True when the command came from the hint button (affects stars).
var is_hint := false


func do() -> void:
	pass


func undo() -> void:
	pass

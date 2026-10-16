class_name StarIcon
extends Control
## A star, gold when earned.

var filled := false:
	set(v):
		filled = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if filled:
		Icons.draw(self, "star", r, LoomTheme.GOLD)
	else:
		Icons.draw(self, "star_empty", r, LoomTheme.INK_SOFT.lerp(LoomTheme.BG, 0.3))

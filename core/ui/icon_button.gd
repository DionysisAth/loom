class_name IconButton
extends BaseButton
## A round button that draws one of the Icons.

@export var icon_name := "back"
@export var tint := LoomTheme.INK
@export var fill := LoomTheme.BG_DEEP

var _press := 0.0


func _init(icon := "back", size_px := 84.0) -> void:
	icon_name = icon
	custom_minimum_size = Vector2(size_px, size_px)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	button_down.connect(func(): _press = 1.0; queue_redraw())
	button_up.connect(func(): _press = 0.0; queue_redraw())
	pressed.connect(func(): Audio.play("tap", 0.05, -6.0))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var col := fill.darkened(0.08 * _press)
	var a := 0.35 if disabled else 1.0
	draw_circle(r.get_center(), minf(size.x, size.y) * 0.5, Color(col, a), true, -1.0, true)
	var inner := r.grow(-minf(size.x, size.y) * 0.18)
	Icons.draw(self, icon_name, inner, Color(tint, a))


func set_disabled_state(value: bool) -> void:
	disabled = value
	queue_redraw()

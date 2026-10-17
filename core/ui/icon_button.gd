class_name IconButton
extends BaseButton
## A round, chunky button (white face on a coloured lip) that draws one of
## the Icons in its colour.

@export var icon_name := "back"
@export var tint := LoomTheme.INK

var _down := false


func _init(icon := "back", color := LoomTheme.INK, size_px := 88.0) -> void:
	icon_name = icon
	tint = color
	custom_minimum_size = Vector2(size_px, size_px)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	button_down.connect(func(): _down = true; queue_redraw())
	button_up.connect(func(): _down = false; queue_redraw())
	pressed.connect(func(): Audio.play("tap", 0.05, -6.0))


func _draw() -> void:
	var d := minf(size.x, size.y)
	var lip := d * 0.07
	var rad := (d - lip) * 0.5
	var c := Vector2(size.x * 0.5, rad)
	var a := 0.4 if disabled else 1.0
	var push := lip * 0.7 if _down else 0.0
	draw_circle(c + Vector2(0, lip + 2), rad, Color(0.6, 0.2, 0.4, 0.12 * a), true, -1.0, true)
	draw_circle(c + Vector2(0, lip), rad, Color(tint.lerp(Color.WHITE, 0.55), a), true, -1.0, true)
	draw_circle(c + Vector2(0, push), rad, Color(Color.WHITE, a), true, -1.0, true)
	var inner := Rect2(c + Vector2(0, push) - Vector2(rad, rad), Vector2(rad, rad) * 2.0).grow(-rad * 0.42)
	Icons.draw(self, icon_name, inner, Color(tint, a))


func set_disabled_state(value: bool) -> void:
	disabled = value
	queue_redraw()

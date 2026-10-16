class_name LiftSwitches
extends Control
## One lift switch per shaft on every row. Tapping a switch asks to flip that
## row's crossings on that shaft; the game turns it into an undoable command.

signal toggled(row: int, shaft: int)

var state: LoomState
var cell := 48.0
var locked := false
var _pressed := -1
var _box_cache := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(s: LoomState) -> void:
	state = s
	locked = s.given_lifts
	s.row_changed.connect(func(_r, _o): queue_redraw())
	s.reset.connect(queue_redraw)
	queue_redraw()


func grid_size() -> Vector2:
	return Vector2(state.shafts, state.height) * cell


func switch_rect(r: int, s: int) -> Rect2:
	return Rect2(Vector2(s, r) * cell, Vector2(cell, cell))


func _draw() -> void:
	if state == null:
		return
	for r in state.height:
		for s in state.shafts:
			var rect := switch_rect(r, s).grow(-cell * (0.14 if not locked else 0.22))
			if _pressed == r * state.shafts + s:
				rect = rect.grow(-cell * 0.04)
			var col := LoomTheme.shaft_color(s)
			if state.is_lifted(r, s):
				draw_style_box(_box(col if not locked else col.lerp(LoomTheme.BG, 0.35), true), rect)
				# A raised heddle: a light notch at the top of the switch.
				var notch := Rect2(rect.position + Vector2(rect.size.x * 0.3, rect.size.y * 0.16),
						Vector2(rect.size.x * 0.4, rect.size.y * 0.14))
				draw_rect(notch, Color(1, 1, 1, 0.55))
			else:
				draw_style_box(_box(col.lerp(LoomTheme.BG, 0.55 if not locked else 0.75), false), rect)


func _box(col: Color, filled: bool) -> StyleBoxFlat:
	var key := "%s%s%d" % [col.to_html(), filled, int(cell)]
	if _box_cache.has(key):
		return _box_cache[key]
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(int(cell * 0.18))
	b.anti_aliasing = true
	if filled:
		b.bg_color = col
		b.shadow_color = Color(0, 0, 0, 0.25)
		b.shadow_size = 3
		b.shadow_offset = Vector2(0, 2)
	else:
		b.bg_color = Color(col, 0.35)
		b.border_color = col
		b.set_border_width_all(maxi(2, int(cell * 0.05)))
	_box_cache[key] = b
	return b


func _gui_input(event: InputEvent) -> void:
	if locked or state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var s := int(event.position.x / cell)
		var r := int(event.position.y / cell)
		var inside := s >= 0 and s < state.shafts and r >= 0 and r < state.height
		if event.pressed and inside:
			_pressed = r * state.shafts + s
			queue_redraw()
			accept_event()
		elif not event.pressed:
			if inside and _pressed == r * state.shafts + s:
				toggled.emit(r, s)
			_pressed = -1
			queue_redraw()
			accept_event()

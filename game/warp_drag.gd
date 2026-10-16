class_name ThreadingDraft
extends Control
## The threading: one row per shaft, one column per warp. Each warp's heddle
## sits on its shaft; drag it (or tap a slot) to tie the warp onto another
## shaft. The game turns the drop into an undoable command.

signal threaded(col: int, shaft: int)

var state: LoomState
var palette := PackedColorArray()
var cell := 48.0
var locked := false
var _drag_col := -1
var _drag_y := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(s: LoomState, pal: PackedColorArray) -> void:
	state = s
	palette = pal
	locked = s.given_threading
	s.column_changed.connect(func(_c, _o): queue_redraw())
	s.reset.connect(queue_redraw)
	queue_redraw()


func grid_size() -> Vector2:
	return Vector2(state.width, state.shafts) * cell


func slot_rect(c: int, s: int) -> Rect2:
	return Rect2(Vector2(c, s) * cell, Vector2(cell, cell))


func _draw() -> void:
	if state == null:
		return
	# Shaft rails.
	for s in state.shafts:
		var y := (s + 0.5) * cell
		var col := LoomTheme.shaft_color(s)
		draw_line(Vector2(0, y), Vector2(state.width * cell, y),
				Color(col, 0.35 if not locked else 0.2), maxf(2.0, cell * 0.08), true)
	for c in state.width:
		var warp := palette[state.warp_colors[c]]
		var x := (c + 0.5) * cell
		var shaft := state.threading[c]
		var dragging := c == _drag_col
		var hy := _drag_y if dragging else (shaft + 0.5) * cell
		# The warp thread runs down from the cloth to its heddle.
		var thread_end := hy if (shaft >= 0 or dragging) else cell * 0.25
		draw_line(Vector2(x, 0), Vector2(x, thread_end), warp.darkened(0.15), maxf(3.0, cell * 0.16), true)
		if shaft < 0 and not dragging:
			# Loose thread: a frayed end waiting to be tied.
			draw_circle(Vector2(x, cell * 0.25), cell * 0.12, warp, true, -1.0, true)
			continue
		if dragging:
			var target := clampi(int(_drag_y / cell), 0, state.shafts - 1)
			draw_rect(slot_rect(c, target).grow(-cell * 0.12), Color(LoomTheme.shaft_color(target), 0.25))
		var hs := shaft if not dragging else clampi(int(_drag_y / cell), 0, state.shafts - 1)
		var col := LoomTheme.shaft_color(hs)
		var hsize := cell * (0.62 if not dragging else 0.74)
		var rect := Rect2(Vector2(x, hy) - Vector2(hsize, hsize) * 0.5, Vector2(hsize, hsize))
		if locked:
			col = col.lerp(LoomTheme.BG, 0.35)
		var b := StyleBoxFlat.new()
		b.bg_color = col
		b.set_corner_radius_all(int(hsize * 0.3))
		b.anti_aliasing = true
		b.shadow_color = Color(0, 0, 0, 0.3 if dragging else 0.18)
		b.shadow_size = 6 if dragging else 2
		draw_style_box(b, rect)
		# Heddle eye with the warp passing through.
		draw_rect(Rect2(Vector2(x, hy) - Vector2(hsize * 0.14, hsize * 0.28), Vector2(hsize * 0.28, hsize * 0.56)),
				warp)


func _gui_input(event: InputEvent) -> void:
	if locked or state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var c := int(event.position.x / cell)
			if c >= 0 and c < state.width and event.position.y >= 0 and event.position.y < size.y:
				_drag_col = c
				_drag_y = clampf(event.position.y, 0.0, state.shafts * cell - 1.0)
				queue_redraw()
				accept_event()
		elif _drag_col >= 0:
			var c := _drag_col
			_drag_col = -1
			var y: float = event.position.y
			if y > -cell * 0.6 and y < (state.shafts + 0.6) * cell:
				var s := clampi(int(y / cell), 0, state.shafts - 1)
				if s != state.threading[c]:
					threaded.emit(c, s)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _drag_col >= 0:
		_drag_y = clampf(event.position.y, 0.0, state.shafts * cell - 1.0)
		queue_redraw()
		accept_event()

class_name ThreadingDraft
extends Control
## The threading: one rail per shaft, one column per warp. Each warp's heddle
## sits on its shaft; drag it (or tap a slot) to tie the warp onto another
## shaft. The game turns the drop into an undoable command.

signal threaded(col: int, shaft: int)

const FLASH := 0.9

var state: LoomState
var palette := PackedColorArray()
var cell := 48.0
var locked := false
var _drag_col := -1
var _drag_y := 0.0
var _flash_col := -1
var _flash_t := -10.0
var _clock := 0.0
var _boxes := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


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


## Briefly highlight a column (e.g. a loose thread the player tapped on the cloth).
func flash(c: int) -> void:
	_flash_col = c
	_flash_t = _clock
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _clock - _flash_t > FLASH:
		set_process(false)


func _box(col: Color, radius: int) -> StyleBoxFlat:
	var key := "%s|%d" % [col.to_html(), radius]
	if _boxes.has(key):
		return _boxes[key]
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	_boxes[key] = b
	return b


func _draw() -> void:
	if state == null:
		return
	var ft := (_clock - _flash_t) / FLASH
	if ft >= 0.0 and ft < 1.0 and _flash_col >= 0:
		draw_style_box(_box(Color(LoomTheme.GOLD, 0.5 * (1.0 - ft)), int(cell * 0.3)),
				Rect2(_flash_col * cell, 0, cell, state.shafts * cell))
	# Shaft rails.
	for s in state.shafts:
		var col := LoomTheme.shaft_color(s)
		var rail := Rect2(0, (s + 0.5) * cell - cell * 0.09, state.width * cell, cell * 0.18)
		draw_style_box(_box(Color(col, 0.28 if not locked else 0.16), int(cell * 0.09)), rail)
	for c in state.width:
		var warp := palette[state.warp_colors[c]]
		var x := (c + 0.5) * cell
		var shaft := state.threading[c]
		var dragging := c == _drag_col
		var hy := _drag_y if dragging else (shaft + 0.5) * cell
		# The warp thread runs down from the cloth to its heddle.
		var thread_end := hy if (shaft >= 0 or dragging) else cell * 0.3
		var tw := maxf(4.0, cell * 0.2)
		ThreadTextures.draw_thread(self, Rect2(x - tw * 0.5, 0, tw, thread_end), warp, true)
		if shaft < 0 and not dragging:
			# Loose thread: a frayed end waiting to be tied.
			draw_circle(Vector2(x, cell * 0.32), cell * 0.15, warp.darkened(0.15), true, -1.0, true)
			draw_circle(Vector2(x, cell * 0.3), cell * 0.12, warp, true, -1.0, true)
			continue
		var hs := shaft if not dragging else clampi(int(_drag_y / cell), 0, state.shafts - 1)
		if dragging:
			draw_style_box(_box(Color(LoomTheme.shaft_color(hs), 0.25), int(cell * 0.25)),
					slot_rect(c, hs).grow(-cell * 0.08))
		var col := LoomTheme.shaft_color(hs)
		if locked:
			col = col.lerp(Color.WHITE, 0.3)
		var hsize := cell * (0.66 if not dragging else 0.78)
		var rect := Rect2(Vector2(x, hy) - Vector2(hsize, hsize) * 0.5, Vector2(hsize, hsize))
		var lip := 0.0 if locked else maxf(2.0, cell * 0.07)
		draw_style_box(_box(col.darkened(0.25), int(hsize * 0.3)), Rect2(rect.position + Vector2(0, lip), rect.size))
		draw_style_box(_box(col, int(hsize * 0.3)), rect)
		draw_style_box(_box(Color(1, 1, 1, 0.3), int(hsize * 0.12)),
				Rect2(rect.position + Vector2(hsize * 0.18, hsize * 0.1), Vector2(hsize * 0.64, hsize * 0.2)))
		# Heddle eye with the warp passing through.
		var eye := Rect2(Vector2(x, hy) - Vector2(hsize * 0.15, hsize * 0.26), Vector2(hsize * 0.3, hsize * 0.52))
		draw_style_box(_box(Color.WHITE, int(hsize * 0.15)), eye.grow(2))
		draw_style_box(_box(warp, int(hsize * 0.12)), eye)


func _gui_input(event: InputEvent) -> void:
	if locked or state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var c := int(event.position.x / cell)
			if c >= 0 and c < state.width and event.position.x >= 0 and event.position.y >= 0 \
					and event.position.y < size.y:
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

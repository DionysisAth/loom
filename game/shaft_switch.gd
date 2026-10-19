class_name LiftSwitches
extends Control
## One lift switch per shaft on every row. Tapping a switch asks to flip that
## row's crossings on that shaft; the game turns it into an undoable command.
## A lifted switch is a raised, filled pill in its shaft colour.

signal toggled(row: int, shaft: int)

var state: LoomState
var cell := 48.0
var locked := false
var _pressed := -1
var _boxes := {}
var _pulse := {}
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func setup(s: LoomState) -> void:
	state = s
	locked = s.given_lifts
	s.row_changed.connect(_on_row_changed)
	s.reset.connect(queue_redraw)
	queue_redraw()


func grid_size() -> Vector2:
	return Vector2(state.shafts, state.height) * cell


func switch_rect(r: int, s: int) -> Rect2:
	return Rect2(Vector2(s, r) * cell, Vector2(cell, cell))


func _on_row_changed(r: int, old: int) -> void:
	var diff := old ^ state.lifts[r]
	for s in state.shafts:
		if diff & (1 << s):
			_pulse[r * state.shafts + s] = _clock
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	var busy := false
	for k in _pulse:
		if _clock - _pulse[k] < 0.3:
			busy = true
	if not busy:
		_pulse.clear()
		set_process(false)


func _draw() -> void:
	if state == null or cell < 4.0:
		return
	var font := LoomTheme.font(650)
	for r in state.height:
		for s in state.shafts:
			var key := r * state.shafts + s
			var base := switch_rect(r, s).grow(-cell * (0.1 if not locked else 0.18))
			var pop := 0.0
			if _pulse.has(key):
				pop = sin(clampf((_clock - _pulse[key]) / 0.3, 0.0, 1.0) * PI) * 0.08
			var rect := base.grow(base.size.x * pop)
			var col := LoomTheme.shaft_color(s)
			var lifted := state.is_lifted(r, s)
			var lip := maxf(3.0, cell * 0.09)
			var down := _pressed == key
			if locked:
				col = col.lerp(Color.WHITE, 0.3)
				lip = 0.0
			var letter: String = LoomTheme.SHAFT_LETTERS[s]
			var face: Rect2
			if lifted:
				var push := lip * (0.7 if down else 0.0)
				var lip_rect := Rect2(rect.position + Vector2(0, lip), rect.size - Vector2(0, lip))
				draw_style_box(_box(col.darkened(0.25), 0), lip_rect)
				face = Rect2(rect.position + Vector2(0, push), rect.size - Vector2(0, lip))
				draw_style_box(_box(col, 0), face)
				# Gloss.
				var g := Rect2(face.position + Vector2(face.size.x * 0.18, face.size.y * 0.1),
						Vector2(face.size.x * 0.64, face.size.y * 0.22))
				draw_style_box(_box(Color(1, 1, 1, 0.2), 0, 0.5), g)
				_letter(font, face, letter, Color.WHITE)
			else:
				var push := lip * (0.7 if down else 0.0)
				if lip > 0.0:
					draw_style_box(_box(col.lerp(Color.WHITE, 0.45), 0),
							Rect2(rect.position + Vector2(0, lip), rect.size - Vector2(0, lip)))
				face = Rect2(rect.position + Vector2(0, push), rect.size - Vector2(0, lip))
				draw_style_box(_box(Color.WHITE.lerp(col, 0.1), maxi(2, int(cell * 0.06)), 1.0,
						col.lerp(Color.WHITE, 0.25)), face)
				_letter(font, face, letter, Color(col, 0.75))


func _letter(font: Font, face: Rect2, letter: String, color: Color) -> void:
	var fs := int(cell * 0.4)
	var y := face.position.y + face.size.y * 0.5 + fs * 0.36
	draw_string(font, Vector2(face.position.x, y), letter, HORIZONTAL_ALIGNMENT_CENTER, face.size.x,
			fs, color)


func _box(col: Color, border: int, radius_scale := 1.0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var key := "%s|%d|%.2f|%s|%d" % [col.to_html(), border, radius_scale, border_col.to_html(), int(cell)]
	if _boxes.has(key):
		return _boxes[key]
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(int(cell * 0.24 * radius_scale))
	b.anti_aliasing = true
	if border > 0:
		b.set_border_width_all(border)
		b.border_color = border_col
	_boxes[key] = b
	return b


func _gui_input(event: InputEvent) -> void:
	if locked or state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var s := int(event.position.x / cell)
		var r := int(event.position.y / cell)
		var inside: bool = s >= 0 and s < state.shafts and r >= 0 and r < state.height \
				and event.position.x >= 0 and event.position.y >= 0
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

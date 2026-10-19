class_name ThreadBoard
extends Control
## Prototype B's frame: drag from a knot to lay its thread cell by cell.
## Threads are drawn as thick yarn; at crossings the thread on top casts a
## shadow over the one beneath.

signal thread_laid(color: int, length: int)
signal thread_connected(color: int)
signal finished

var puzzle: ThreadPuzzle
var palette := PackedColorArray()
var cell := 64.0
var _origin := Vector2.ZERO
var _active := -1
var _was_connected := {}
var _pop := {}
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p: ThreadPuzzle, pal: PackedColorArray) -> void:
	puzzle = p
	palette = pal
	p.changed.connect(queue_redraw)
	resized.connect(_layout)
	set_process(false)
	_layout()


func _layout() -> void:
	if puzzle == null:
		return
	cell = floorf(minf(120.0, minf(size.x / (puzzle.width + 0.7), size.y / (puzzle.height + 0.7))))
	var dims := Vector2(puzzle.width, puzzle.height) * cell
	_origin = ((size - dims) * Vector2(0.5, 0.35)).floor()
	queue_redraw()


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_at(pos: Vector2) -> Vector2i:
	var p := (pos - _origin) / cell
	return Vector2i(int(floorf(p.x)), int(floorf(p.y)))


## Global rect of a cell, for the tutorial pointer.
func global_cell_rect(c: Vector2i) -> Rect2:
	return Rect2(global_position + _origin + Vector2(c) * cell, Vector2(cell, cell))


# --- Input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if puzzle == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var c := cell_at(event.position)
			if not puzzle.inside(c):
				return
			_active = puzzle.begin(c)
			if _active >= 0:
				_remember_connections()
				Audio.play_at("pluck", 0.9, -8.0)
				Haptics.tap()
			accept_event()
		else:
			_active = -1
			accept_event()
			if puzzle.complete():
				finished.emit()
	elif event is InputEventMouseMotion and _active >= 0:
		_drag_to(cell_at(event.position))
		accept_event()


func _drag_to(target: Vector2i) -> void:
	var steps := 0
	while steps < 12:
		steps += 1
		var p := puzzle.path(_active)
		if p.is_empty():
			return
		var last: Vector2i = p[-1]
		if last == target:
			return
		var d := target - last
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		var before := p.size()
		if not puzzle.extend(_active, last + step):
			# Try the other axis before giving up (diagonal drags).
			var alt := Vector2i(0, signi(d.y)) if step.y == 0 else Vector2i(signi(d.x), 0)
			if alt == Vector2i.ZERO or not puzzle.extend(_active, last + alt):
				return
		var now := puzzle.path(_active).size()
		if now > before:
			Audio.play_at("pluck", 1.0 + now * 0.045, -10.0)
			Haptics.tap()
			thread_laid.emit(_active, now)
		_check_connections()


func _remember_connections() -> void:
	for pg in puzzle.pegs:
		_was_connected[pg.color] = puzzle.connected(pg.color)


func _check_connections() -> void:
	for pg in puzzle.pegs:
		var now := puzzle.connected(pg.color)
		if now and not _was_connected.get(pg.color, false):
			_pop[pg.color] = _clock
			set_process(true)
			thread_connected.emit(pg.color)
		_was_connected[pg.color] = now


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _pop.values().all(func(t): return _clock - t > 0.5):
		_pop.clear()
		set_process(false)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	if puzzle == null or cell < 4.0:
		return
	var dims := Vector2(puzzle.width, puzzle.height) * cell
	var frame := Rect2(_origin, dims)
	ThreadTextures.draw_frame(self, frame, cell * 0.14)
	draw_rect(frame, Color("#f6efe4"))
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(int(cell * 0.16))
	b.anti_aliasing = true
	for y in puzzle.height:
		for x in puzzle.width:
			var c := Vector2i(x, y)
			var r := Rect2(_origin + Vector2(c) * cell, Vector2(cell, cell)).grow(-cell * 0.05)
			b.bg_color = Color("#efe5d6") if (x + y) % 2 == 0 else Color("#ebe0cf")
			draw_style_box(b, r)
			if puzzle.is_crossing(c):
				_crossing_mark(cell_center(c))
	for color in puzzle.paths:
		_draw_path(color, puzzle.path(color))
	# At crossings, redraw the top thread across the cell over the one beneath.
	for c in puzzle.crossings:
		var occ := puzzle.occupants(c)
		if occ.size() < 2:
			continue
		var h_top := puzzle.horizontal_on_top(c)
		for color in occ:
			var axis = puzzle.axis_through(color, c)
			if axis != null and axis == h_top:
				var half := Vector2(cell * 0.5, 0) if h_top else Vector2(0, cell * 0.5)
				var ctr := cell_center(c)
				var w := _thick(color)
				draw_line(ctr - half, ctr + half + Vector2(0, 3), Color(0.2, 0.1, 0.1, 0.25), w + 8.0, true)
				_yarn(ctr - half, ctr + half, palette[color], w)
	for pg in puzzle.pegs:
		_draw_knot(pg.a, pg.color)
		_draw_knot(pg.b, pg.color)


func _thick(color: int) -> float:
	return cell * (0.4 if color != _active else 0.44)


func _yarn(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col.darkened(0.22), w + 4.0, true)
	draw_line(a, b, col, w, true)
	var n := (b - a).orthogonal().normalized() * w * 0.2
	draw_line(a - n, b - n, Color(1, 1, 1, 0.3), w * 0.18, true)


func _draw_path(color: int, p: Array) -> void:
	if p.is_empty():
		return
	var col := palette[color]
	var w := _thick(color)
	for i in range(1, p.size()):
		_yarn(cell_center(p[i - 1]), cell_center(p[i]), col, w)
	for i in p.size():
		var ctr := cell_center(p[i])
		draw_circle(ctr, w * 0.5 + 2.0, col.darkened(0.22), true, -1.0, true)
		draw_circle(ctr, w * 0.5, col, true, -1.0, true)


func _draw_knot(c: Vector2i, color: int) -> void:
	var ctr := cell_center(c)
	var col := palette[color]
	var pop := 0.0
	if _pop.has(color):
		pop = sin(clampf((_clock - _pop[color]) / 0.5, 0.0, 1.0) * PI) * 0.18
	var r := cell * (0.34 + pop)
	draw_circle(ctr + Vector2(0, 3), r, Color(0.2, 0.1, 0.1, 0.2), true, -1.0, true)
	draw_circle(ctr, r, Color.WHITE, true, -1.0, true)
	draw_circle(ctr, r - 4.0, col, true, -1.0, true)
	if puzzle.connected(color):
		Icons.draw(self, "check", Rect2(ctr - Vector2.ONE * r * 0.6, Vector2.ONE * r * 1.2), Color.WHITE)
	else:
		draw_circle(ctr, r * 0.28, Color(1, 1, 1, 0.7), true, -1.0, true)


func _crossing_mark(ctr: Vector2) -> void:
	var d := cell * 0.16
	var col := Color("#b9a68b")
	for k in [-1, 1]:
		draw_line(ctr + Vector2(-d, k * d * 0.5), ctr + Vector2(d, k * d * 0.5), col, 2.5, true)
		draw_line(ctr + Vector2(k * d * 0.5, -d), ctr + Vector2(k * d * 0.5, d), col, 2.5, true)

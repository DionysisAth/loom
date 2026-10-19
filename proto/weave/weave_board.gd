class_name WeaveBoard
extends Control
## Prototype A's loom, seen from the weaver's seat:
##
##   back beam ─────────────────
##   heddles    ● ● ● ● ● ●      (lifted shafts rise)
##   warps      │ │ │ │ │ │
##   shed       ░ next row ░  ◀ shuttle
##   cloth      ▓▓▓▓▓▓▓▓▓▓▓      (grows upward, row by row)
##   breast beam ───────────────
##   pedals     [ A ] [ B C ]
##
## Press a pedal to lift its shafts, then drag the shuttle across the shed.
## The weft passes under the lifted warps and over the rest; release past the
## far side and the beater packs the row into the cloth.

signal pedal_pressed(pedal: int)
signal tie_toggled(pedal: int, shaft: int)
signal row_woven(row: int, correct: bool)
## The shuttle hit a closed shed (no pedal pressed).
signal bumped

const COMMIT := 0.72
const FLICK_SPEED := 1400.0

var loom: WeaveLoom
var palette := PackedColorArray()
var pressed := -1
var cell := 48.0
## Which side the shuttle rests on: -1 left, 1 right.
var side := -1
var _lift := PackedFloat32Array()
var _shuttle_t := 0.0
var _dragging := false
var _drag_start_x := 0.0
var _velocity := 0.0
var _last_x := 0.0
var _last_time := 0.0
var _flying := false
var _beat := -1.0
var _clock := 0.0
var _flash := {}
var _origin := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(l: WeaveLoom, pal: PackedColorArray) -> void:
	loom = l
	palette = pal
	_lift.resize(l.width)
	_lift.fill(0.0)
	l.changed.connect(queue_redraw)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if loom == null:
		return
	var cols := loom.width + 2.4
	var rows := loom.height() + 6.2
	cell = floorf(minf(110.0, minf(size.x / cols, size.y / rows)))
	_origin = Vector2((size.x - cols * cell) * 0.5, (size.y - rows * cell) * 0.4).floor()
	queue_redraw()


# --- Geometry ---------------------------------------------------------------

func _warp_x(c: int) -> float:
	return _origin.x + (1.2 + c + 0.5) * cell


func _left() -> float:
	return _origin.x + 1.2 * cell


func _right() -> float:
	return _left() + loom.width * cell


func _back_beam_y() -> float:
	return _origin.y + 0.2 * cell


func _heddle_y() -> float:
	return _origin.y + 1.25 * cell


func _cloth_bottom() -> float:
	return _origin.y + (3.4 + loom.height()) * cell


func _fell_y() -> float:
	return _cloth_bottom() - loom.woven.size() * cell


func _row_rect(r: int) -> Rect2:
	return Rect2(_left(), _cloth_bottom() - (r + 1) * cell, loom.width * cell, cell)


## Where the next row goes: the shed the shuttle travels through.
func _shed_rect() -> Rect2:
	return _row_rect(loom.woven.size())


func _rest_x(s: int) -> float:
	return _left() - 0.62 * cell if s < 0 else _right() + 0.62 * cell


func _shuttle_x() -> float:
	return lerpf(_rest_x(side), _rest_x(-side), _shuttle_t)


func pedal_rect(p: int) -> Rect2:
	var n := loom.pedals.size()
	var top := _cloth_bottom() + 0.75 * cell
	var total := loom.width * cell + 1.0 * cell
	var gap := cell * 0.3
	var w := (total - gap * (n - 1)) / n
	return Rect2(_left() - 0.5 * cell + p * (w + gap), top, w, 1.6 * cell)


func knob_rect(p: int, s: int) -> Rect2:
	var pr := pedal_rect(p)
	var d := minf(cell * 0.62, (pr.size.x - cell * 0.3) / loom.shafts)
	var start := pr.get_center().x - d * loom.shafts * 0.5
	return Rect2(Vector2(start + s * d, pr.position.y + cell * 0.18), Vector2(d, d)).grow(-d * 0.08)


## Global rects, for the tutorial pointer.
func global_pedal_rect(p: int) -> Rect2:
	var r := pedal_rect(p)
	return Rect2(global_position + r.position, r.size)


func global_shuttle_rect() -> Rect2:
	var c := Vector2(_shuttle_x(), _shed_rect().get_center().y)
	return Rect2(global_position + c - Vector2(cell, cell) * 0.5, Vector2(cell, cell))


func global_far_side_rect() -> Rect2:
	var c := Vector2(_rest_x(-side), _shed_rect().get_center().y)
	return Rect2(global_position + c - Vector2(cell, cell) * 0.5, Vector2(cell, cell))


# --- State ------------------------------------------------------------------

func press_pedal(p: int) -> void:
	pressed = -1 if pressed == p else p
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	var busy := false
	for c in loom.width:
		var want := 0.0
		if pressed >= 0 and loom.lifted(c, loom.pedals[pressed]):
			want = 1.0
		var v := move_toward(_lift[c], want, delta * 7.0)
		if v != _lift[c]:
			busy = true
		_lift[c] = v
	if _flying:
		busy = true
		_shuttle_t = move_toward(_shuttle_t, 1.0, delta * 4.5)
		if _shuttle_t >= 1.0:
			_flying = false
			_commit()
	if _beat >= 0.0:
		busy = true
		_beat += delta / 0.28
		if _beat >= 1.0:
			_beat = -1.0
	for k in _flash.keys():
		if _clock - _flash[k] > 1.2:
			_flash.erase(k)
		else:
			busy = true
	queue_redraw()
	if not busy and not _dragging:
		set_process(false)


func _commit() -> void:
	var row := loom.woven.size()
	var ok := loom.weave(pressed)
	side = -side
	_shuttle_t = 0.0
	_beat = 0.0
	_flash[row] = _clock
	pressed = -1
	set_process(true)
	row_woven.emit(row, ok)


# --- Input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if loom == null or loom.woven.size() >= loom.height():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_on_drag(event.position)


func _on_press(pos: Vector2) -> void:
	if _flying:
		return
	for p in loom.pedals.size():
		if loom.editable:
			for s in loom.shafts:
				if knob_rect(p, s).grow(cell * 0.05).has_point(pos):
					tie_toggled.emit(p, s)
					accept_event()
					return
		if pedal_rect(p).has_point(pos):
			press_pedal(p)
			pedal_pressed.emit(pressed)
			accept_event()
			return
	var sc := Vector2(_shuttle_x(), _shed_rect().get_center().y)
	if pos.distance_to(sc) < cell * 1.1:
		_dragging = true
		_drag_start_x = pos.x
		_last_x = pos.x
		_last_time = _clock
		_velocity = 0.0
		set_process(true)
		accept_event()


func _on_drag(pos: Vector2) -> void:
	var span := _rest_x(-side) - _rest_x(side)
	var t := clampf((pos.x - _rest_x(side)) / span, 0.0, 1.0)
	if pressed < 0 and t > 0.06:
		# The shed is closed: the shuttle bumps into the warps.
		_dragging = false
		_shuttle_t = 0.0
		bumped.emit()
		queue_redraw()
		return
	var dt := maxf(0.001, _clock - _last_time)
	_velocity = (pos.x - _last_x) / dt * signf(span)
	_last_x = pos.x
	_last_time = _clock
	_shuttle_t = t
	queue_redraw()


func _on_release(_pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	if pressed >= 0 and (_shuttle_t > COMMIT or (_shuttle_t > 0.25 and _velocity > FLICK_SPEED)):
		_flying = true
	else:
		_shuttle_t = 0.0
	set_process(true)
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _wood(r: Rect2, col := LoomTheme.WOOD) -> void:
	var lip := StyleBoxFlat.new()
	lip.bg_color = col.darkened(0.18)
	lip.set_corner_radius_all(int(minf(r.size.x, r.size.y) * 0.4))
	lip.anti_aliasing = true
	draw_style_box(lip, Rect2(r.position + Vector2(0, cell * 0.06), r.size))
	var face := StyleBoxFlat.new()
	face.bg_color = col
	face.set_corner_radius_all(int(minf(r.size.x, r.size.y) * 0.4))
	face.anti_aliasing = true
	face.border_color = col.lightened(0.25)
	face.border_width_top = maxi(2, int(cell * 0.05))
	draw_style_box(face, r)


func _draw() -> void:
	if loom == null or cell < 4.0:
		return
	var h := loom.height()
	var left := _left()
	var right := _right()
	# Frame posts and beams.
	_wood(Rect2(left - 1.05 * cell, _back_beam_y(), 0.3 * cell, _cloth_bottom() + 0.5 * cell - _back_beam_y()))
	_wood(Rect2(right + 0.75 * cell, _back_beam_y(), 0.3 * cell, _cloth_bottom() + 0.5 * cell - _back_beam_y()))
	_wood(Rect2(left - 0.9 * cell, _back_beam_y(), right - left + 1.8 * cell, 0.45 * cell))
	# Woven cloth.
	var fell := _fell_y()
	var n := loom.woven.size()
	for r in n:
		var beat_off := 0.0
		if r == n - 1 and _beat >= 0.0:
			beat_off = -sin(_beat * PI) * cell * 0.25
		for c in loom.width:
			var top := loom.lifted(c, loom.woven[r])
			var a: bool
			var b: bool
			if top:
				a = r < n - 1 and not loom.lifted(c, loom.woven[r + 1])
				b = r > 0 and not loom.lifted(c, loom.woven[r - 1])
			else:
				a = c > 0 and loom.lifted(c - 1, loom.woven[r])
				b = c < loom.width - 1 and loom.lifted(c + 1, loom.woven[r])
			var rect := Rect2(Vector2(left + c * cell, _cloth_bottom() - (r + 1) * cell + beat_off), Vector2(cell, cell))
			ThreadTextures.draw_crossing(self, rect, top, palette[loom.warp_colors[c]],
					palette[loom.weft_colors[r]], 1.0, false, 0, 0, a, b)
			if not loom.cell_correct(c, r):
				draw_rect(rect.grow(-cell * 0.08), Color(LoomTheme.ACCENT, 0.9), false, maxf(3.0, cell * 0.07), true)
		_row_mark(r)
	var shed := _shed_rect()
	var open := 0.0
	for v in _lift:
		open = maxf(open, v)
	if n < h:
		# The next row as a faint guide in the shed.
		for c in loom.width:
			var col := palette[loom.target_color(c, n)]
			var gr := Rect2(Vector2(left + c * cell, shed.position.y), Vector2(cell, cell)).grow(-cell * 0.12)
			draw_rect(gr, Color(col, 0.35))
		# Shadow of the open shed.
		draw_rect(Rect2(shed.position.x - 0.2 * cell, shed.position.y + cell * 0.1, shed.size.x + 0.4 * cell,
				cell * 0.8), Color(0.2, 0.1, 0.15, 0.22 * open))
	# Warps: lowered ones first (behind the weft), lifted ones in front.
	for pass_lifted in [false, true]:
		for c in loom.width:
			var up := _lift[c]
			if (up > 0.5) != pass_lifted:
				continue
			_draw_warp(c, up, fell)
		if not pass_lifted and n < h:
			_draw_weft_trail(shed)
	# Shuttle, beater and pedals.
	if n < h:
		_draw_shuttle(Vector2(_shuttle_x(), shed.get_center().y))
	if _beat >= 0.0:
		var by := lerpf(_heddle_y() + cell * 0.6, fell - cell * 0.15, sin(_beat * PI))
		_wood(Rect2(left - 0.6 * cell, by, right - left + 1.2 * cell, 0.22 * cell), LoomTheme.WOOD_DARK)
	_wood(Rect2(left - 0.9 * cell, _cloth_bottom() + 0.05 * cell, right - left + 1.8 * cell, 0.45 * cell))
	for p in loom.pedals.size():
		_draw_pedal(p)


func _draw_warp(c: int, up: float, fell: float) -> void:
	var x := _warp_x(c)
	var col := palette[loom.warp_colors[c]]
	var hy := _heddle_y() - up * cell * 0.35
	# With a pedal down, lifted warps come forward (wide, bright) and the
	# others sink back (thin, dim), so the open shed is easy to see.
	var open := pressed >= 0
	var w := cell * ((0.3 + up * 0.24) if open else 0.4)
	var shade := col.darkened(0.42 * (1.0 - up)) if open else col
	ThreadTextures.draw_thread(self, Rect2(x - w * 0.5, _back_beam_y() + 0.3 * cell, w, fell - _back_beam_y() - 0.3 * cell),
			shade, true)
	if up > 0.0:
		draw_rect(Rect2(x - w * 0.5 - cell * 0.03, hy + cell * 0.3, cell * 0.03, fell - hy - cell * 0.3),
				Color(0, 0, 0, 0.12 * up))
	# Heddle eye in the shaft's colour.
	var s := loom.threading[c]
	draw_circle(Vector2(x, hy), cell * 0.17, LoomTheme.shaft_color(s), true, -1.0, true)
	draw_circle(Vector2(x, hy), cell * 0.07, Color.WHITE, true, -1.0, true)


func _draw_weft_trail(shed: Rect2) -> void:
	if _shuttle_t <= 0.0:
		return
	var from := _rest_x(side)
	var to := _shuttle_x()
	var y := shed.get_center().y
	var col := palette[loom.weft_colors[loom.woven.size()]]
	var th := cell * 0.42
	var r := Rect2(minf(from, to), y - th * 0.5, absf(to - from), th)
	ThreadTextures.draw_thread(self, r, col, false)


func _draw_shuttle(c: Vector2) -> void:
	var blen := cell * 1.5
	var hgt := cell * 0.62
	var pts := PackedVector2Array([c + Vector2(-blen * 0.5, 0), c + Vector2(-blen * 0.3, -hgt * 0.5),
		c + Vector2(blen * 0.3, -hgt * 0.5), c + Vector2(blen * 0.5, 0), c + Vector2(blen * 0.3, hgt * 0.5),
		c + Vector2(-blen * 0.3, hgt * 0.5)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, cell * 0.08))
	draw_colored_polygon(shadow, Color(0.2, 0.1, 0.1, 0.2))
	draw_colored_polygon(pts, LoomTheme.WOOD_DARK)
	var weft := palette[loom.weft_colors[mini(loom.woven.size(), loom.height() - 1)]]
	draw_rect(Rect2(c - Vector2(blen * 0.22, hgt * 0.26), Vector2(blen * 0.44, hgt * 0.52)), weft)
	draw_line(c + Vector2(-blen * 0.22, 0), c + Vector2(blen * 0.22, 0), weft.darkened(0.2), 2.0, true)


func _draw_pedal(p: int) -> void:
	var r := pedal_rect(p)
	var down := p == pressed
	var face := Rect2(r.position + Vector2(0, cell * 0.14 if down else 0.0), r.size)
	var col := LoomTheme.WOOD.darkened(0.08) if down else LoomTheme.WOOD
	_wood(face, col)
	var font := LoomTheme.font(650)
	var fs := int(cell * 0.32)
	for s in loom.shafts:
		var k := knob_rect(p, s)
		k.position.y += face.position.y - r.position.y
		var on := (loom.pedals[p] >> s) & 1 == 1
		var sc := LoomTheme.shaft_color(s)
		draw_circle(k.get_center(), k.size.x * 0.5, sc if on else Color(sc, 0.18), true, -1.0, true)
		if not on:
			draw_arc(k.get_center(), k.size.x * 0.5 - 1.5, 0, TAU, 24, Color(sc, 0.7), 2.0, true)
		draw_string(font, Vector2(k.position.x, k.get_center().y + fs * 0.36), LoomTheme.SHAFT_LETTERS[s],
				HORIZONTAL_ALIGNMENT_CENTER, k.size.x, fs, Color.WHITE if on else sc)
	draw_string(font, Vector2(face.position.x, face.end.y - cell * 0.22), "pedal %d" % (p + 1),
			HORIZONTAL_ALIGNMENT_CENTER, face.size.x, int(cell * 0.26), LoomTheme.WOOD_DARK.darkened(0.3))


func _row_mark(r: int) -> void:
	var rect := _row_rect(r)
	var center := Vector2(rect.end.x + 0.62 * cell, rect.get_center().y)
	var t := _clock - float(_flash.get(r, -10.0))
	var pop := 1.0 + (sin(clampf(t / 0.4, 0.0, 1.0) * PI) * 0.4 if t < 0.4 else 0.0)
	if loom.row_correct(r):
		draw_circle(center, cell * 0.2 * pop, LoomTheme.MINT, true, -1.0, true)
		Icons.draw(self, "check", Rect2(center - Vector2.ONE * cell * 0.18, Vector2.ONE * cell * 0.36), Color.WHITE)
	else:
		draw_circle(center, cell * 0.2 * pop, LoomTheme.ACCENT, true, -1.0, true)
		var d := cell * 0.09
		draw_line(center - Vector2(d, d), center + Vector2(d, d), Color.WHITE, 3.0, true)
		draw_line(center + Vector2(-d, d), center + Vector2(d, -d), Color.WHITE, 3.0, true)

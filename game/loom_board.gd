class_name LoomBoard
extends Control
## Lays out the loom on a white card, showing only what the level needs:
##
##   lifting:    [pegs] [weft] [ cloth ] [tick]      + shaft tags under the cloth
##   threading:         [weft] [ cloth ] [lifts] [tick] + threading draft below
##   full loom:         [weft] [ cloth ] [lifts] [tick] + threading draft below
##
## Pegs appear only on treadle levels: each row's peg shows its treadle, and
## tapping it moves the row to the next treadle.

signal lift_toggled(row: int, shaft: int)
signal warp_threaded(col: int, shaft: int)
## The player tapped a row's peg (treadle levels).
signal peg_tapped(row: int)

const MAX_CELL := 112.0
const PAD := 0.35
const PEG_W := 0.85
const WEFT_W := 0.7
const TICK_W := 0.7
const ENDS_H := 0.75
const TAGS_H := 0.75
const TREADLE_COLORS: Array[Color] = [Color("#e7a03c"), Color("#5b8def"), Color("#b77fd0")]

var state: LoomState
var palette := PackedColorArray()
var colorblind := false
var cell := 48.0
var view := LoomView.new()
var switches := LiftSwitches.new()
var draft := ThreadingDraft.new()
var show_switches := false
var show_draft := false
var _origin := Vector2.ZERO
var _used := Vector2.ZERO
var _peg_down := -1
var _peg_pop := {}
var _clock := 0.0


func setup(s: LoomState, pal: PackedColorArray, cb: bool) -> void:
	state = s
	palette = pal
	colorblind = cb
	view.colorblind = cb
	show_switches = not s.given_threading
	show_draft = not s.given_threading
	add_child(view)
	add_child(switches)
	add_child(draft)
	switches.visible = show_switches
	draft.visible = show_draft
	view.setup(s, pal)
	switches.setup(s)
	draft.setup(s, pal)
	switches.toggled.connect(func(r, sh): lift_toggled.emit(r, sh))
	draft.threaded.connect(func(c, sh): warp_threaded.emit(c, sh))
	view.lift_requested.connect(func(r, sh): lift_toggled.emit(r, sh))
	view.cycle_requested.connect(_cycle)
	# A loose warp on a full-loom level: tapping it ties it to shaft A.
	view.untied_tapped.connect(func(c): warp_threaded.emit(c, 0))
	s.row_changed.connect(func(_r, _o): queue_redraw())
	s.column_changed.connect(func(_c, _o): queue_redraw())
	s.treadle_changed.connect(_on_treadle_changed)
	s.reset.connect(queue_redraw)
	resized.connect(_layout)
	set_process(false)
	_layout()


## Tap on a column in a threading level: move the warp to the next shaft.
func _cycle(c: int) -> void:
	var s := state.threading[c]
	warp_threaded.emit(c, 0 if s < 0 else (s + 1) % state.shafts)


func _on_treadle_changed(r: int, _old: int) -> void:
	_peg_pop[r] = _clock
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _peg_pop.values().all(func(t): return _clock - t > 0.3):
		_peg_pop.clear()
		set_process(false)


func set_colorblind(on: bool) -> void:
	colorblind = on
	view.colorblind = on
	view.queue_redraw()
	queue_redraw()


func _left_w() -> float:
	return PAD + (PEG_W if state.has_treadles() else 0.0) + WEFT_W


func _layout() -> void:
	if state == null:
		return
	var cols := _left_w() + state.width + TICK_W + PAD
	if show_switches:
		cols += 0.35 + state.shafts
	var rows := PAD + ENDS_H + state.height + PAD
	rows += (0.35 + state.shafts) if show_draft else TAGS_H
	cell = floorf(minf(MAX_CELL, minf(size.x / cols, size.y / rows)))
	_used = Vector2(cols, rows) * cell
	# Centred across, sitting a little high so the cloth is near the target.
	_origin = Vector2((size.x - _used.x) * 0.5, (size.y - _used.y) * 0.25).floor()
	view.cell = cell
	switches.cell = cell
	draft.cell = cell
	var cloth := cloth_origin()
	view.position = cloth
	view.size = view.cloth_size()
	switches.position = cloth + Vector2((state.width + 0.35) * cell, 0)
	switches.size = switches.grid_size()
	draft.position = cloth + Vector2(0, (state.height + 0.35) * cell)
	draft.size = draft.grid_size()
	view.queue_redraw()
	switches.queue_redraw()
	draft.queue_redraw()
	queue_redraw()


func cloth_origin() -> Vector2:
	return _origin + Vector2(_left_w(), PAD + ENDS_H) * cell


func _peg_rect_local(r: int) -> Rect2:
	var cloth := cloth_origin()
	return Rect2(Vector2(_origin.x + PAD * cell, cloth.y + (r + 0.1) * cell),
			Vector2(PEG_W * cell - cell * 0.12, cell * 0.8))


## Global rect of a lift switch (for the tutorial pointer).
func lift_rect(r: int, s: int) -> Rect2:
	var rect := switches.switch_rect(r, s)
	return Rect2(switches.global_position + rect.position, rect.size)


## Global rect of a threading slot (for the tutorial pointer).
func slot_rect(c: int, s: int) -> Rect2:
	var rect := draft.slot_rect(c, s)
	return Rect2(draft.global_position + rect.position, rect.size)


## Global rect of a crossing on the cloth (for the tutorial pointer).
func crossing_rect(c: int, r: int) -> Rect2:
	var rect := view.cell_rect(c, r)
	return Rect2(view.global_position + rect.position, rect.size)


## Global rect of a row's treadle peg.
func peg_rect(r: int) -> Rect2:
	var rect := _peg_rect_local(r)
	return Rect2(global_position + rect.position, rect.size)


func _gui_input(event: InputEvent) -> void:
	if state == null or not state.has_treadles():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := -1
		for r in state.height:
			if _peg_rect_local(r).grow(cell * 0.08).has_point(event.position):
				hit = r
		if event.pressed:
			_peg_down = hit
			if hit >= 0:
				accept_event()
				queue_redraw()
		else:
			if hit >= 0 and hit == _peg_down:
				peg_tapped.emit(hit)
				accept_event()
			_peg_down = -1
			queue_redraw()


func _draw() -> void:
	if state == null or cell < 4.0:
		return
	draw_style_box(LoomTheme.card(int(cell * 0.4), 0), Rect2(_origin, _used))
	var cloth := cloth_origin()
	var font := LoomTheme.font(650)
	var fsize := int(cell * 0.38)
	ThreadTextures.draw_frame(self, Rect2(cloth, view.cloth_size()), cell * 0.12)
	# Warp ends above the cloth.
	for c in state.width:
		var col := palette[state.warp_colors[c]]
		var tw := cell * ThreadTextures.THREAD_IN_CLOTH
		var r := Rect2(cloth + Vector2(c * cell + (cell - tw) * 0.5, -0.66 * cell), Vector2(tw, 0.54 * cell))
		ThreadTextures.draw_thread(self, r, col, true, colorblind, state.warp_colors[c])
	# Weft ends, pegs and ticks per row.
	for r in state.height:
		var col := palette[state.weft_colors[r]]
		var th := cell * ThreadTextures.THREAD_IN_CLOTH
		var rect := Rect2(cloth + Vector2(-0.6 * cell, r * cell + (cell - th) * 0.5), Vector2(0.5 * cell, th))
		ThreadTextures.draw_thread(self, rect, col, false, colorblind, state.weft_colors[r])
		if state.has_treadles():
			_draw_peg(r, font, fsize)
		if state.row_matches(r):
			var x := cloth.x + state.width * cell + 0.42 * cell
			if show_switches:
				x += (0.35 + state.shafts) * cell
			var center := Vector2(x, cloth.y + (r + 0.5) * cell)
			draw_circle(center, cell * 0.2, LoomTheme.MINT, true, -1.0, true)
			Icons.draw(self, "check", Rect2(center - Vector2.ONE * cell * 0.18, Vector2.ONE * cell * 0.36),
					Color.WHITE)
	if show_switches:
		for s in state.shafts:
			var top := switches.position + Vector2((s + 0.5) * cell, -0.4 * cell)
			_letter_disc(top, s, font, fsize)
	if show_draft:
		for s in state.shafts:
			_letter_disc(draft.position + Vector2(-0.4 * cell, (s + 0.5) * cell), s, font, fsize)
	else:
		# Shaft tags under each column, so players see which threads lift together.
		for c in state.width:
			var s := state.threading[c]
			if s < 0:
				continue
			_letter_disc(cloth + Vector2((c + 0.5) * cell, (state.height + 0.45) * cell), s, font,
					int(fsize * 0.85), 0.19)


func _letter_disc(center: Vector2, s: int, font: Font, fsize: int, radius := 0.22) -> void:
	draw_circle(center, cell * radius, LoomTheme.shaft_color(s), true, -1.0, true)
	draw_string(font, center + Vector2(-cell * 0.5, fsize * 0.36), LoomTheme.SHAFT_LETTERS[s],
			HORIZONTAL_ALIGNMENT_CENTER, cell, fsize, Color.WHITE)


func _draw_peg(r: int, font: Font, fsize: int) -> void:
	var t := state.treadling[r]
	var col := TREADLE_COLORS[t % TREADLE_COLORS.size()]
	var rect := _peg_rect_local(r)
	if _peg_pop.has(r):
		var k := clampf((_clock - _peg_pop[r]) / 0.3, 0.0, 1.0)
		rect = rect.grow(sin(k * PI) * cell * 0.06)
	var lip := cell * 0.07
	var down := _peg_down == r
	var radius := int(cell * 0.22)
	draw_style_box(LoomTheme.box(col.darkened(0.2), radius, 0), Rect2(rect.position + Vector2(0, lip), rect.size))
	var face := Rect2(rect.position + Vector2(0, lip * 0.7 if down else 0.0), rect.size)
	draw_style_box(LoomTheme.box(col, radius, 0), face)
	draw_string(font, Vector2(face.position.x, face.get_center().y + fsize * 0.36), str(t + 1),
			HORIZONTAL_ALIGNMENT_CENTER, face.size.x, fsize, Color.WHITE)

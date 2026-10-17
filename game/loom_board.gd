class_name LoomBoard
extends Control
## Lays out the loom on a white card: warp ends on top, the cloth in a honey
## frame with each row's weft at its left, lift switches to the right and the
## threading draft below, all on one cell grid so everything lines up.
##
##            [warp ends]   [A B C]
##   [weft]   [ cloth   ]   [lifts]  [tick]
##   [A B C]  [threading]

signal lift_toggled(row: int, shaft: int)
signal warp_threaded(col: int, shaft: int)
## The player tapped a loose warp on the cloth (it must be tied first).
signal untied_tapped(col: int)

const MAX_CELL := 96.0
## Extra cells around the grids: card padding, weft column, gaps, tick column.
const PAD_X := 0.35 + 0.85 + 0.35 + 0.65 + 0.35
const PAD_Y := 0.35 + 0.85 + 0.35 + 0.35

var state: LoomState
var palette := PackedColorArray()
var colorblind := false
var cell := 48.0
var view := LoomView.new()
var switches := LiftSwitches.new()
var draft := ThreadingDraft.new()
var _origin := Vector2.ZERO
var _used := Vector2.ZERO


func setup(s: LoomState, pal: PackedColorArray, cb: bool) -> void:
	state = s
	palette = pal
	colorblind = cb
	view.colorblind = cb
	add_child(view)
	add_child(switches)
	add_child(draft)
	view.setup(s, pal)
	switches.setup(s)
	draft.setup(s, pal)
	switches.toggled.connect(func(r, sh): lift_toggled.emit(r, sh))
	draft.threaded.connect(func(c, sh): warp_threaded.emit(c, sh))
	view.lift_requested.connect(func(r, sh): lift_toggled.emit(r, sh))
	view.cycle_requested.connect(_cycle)
	view.untied_tapped.connect(func(c): draft.flash(c); untied_tapped.emit(c))
	s.row_changed.connect(func(_r, _o): queue_redraw())
	s.column_changed.connect(func(_c, _o): queue_redraw())
	s.reset.connect(queue_redraw)
	resized.connect(_layout)
	_layout()


## Tap on a column in a threading level: move the warp to the next shaft.
func _cycle(c: int) -> void:
	var s := state.threading[c]
	warp_threaded.emit(c, 0 if s < 0 else (s + 1) % state.shafts)


func set_colorblind(on: bool) -> void:
	colorblind = on
	view.colorblind = on
	view.queue_redraw()
	queue_redraw()


func _layout() -> void:
	if state == null:
		return
	var cols := state.width + state.shafts + PAD_X
	var rows := state.height + state.shafts + PAD_Y
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
	return _origin + Vector2(0.35 + 0.85, 0.35 + 0.85) * cell


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


func _draw() -> void:
	if state == null or cell < 4.0:
		return
	draw_style_box(LoomTheme.card(int(cell * 0.45), 0), Rect2(_origin, _used))
	var cloth := cloth_origin()
	var font := LoomTheme.font(650)
	var fsize := int(cell * 0.4)
	ThreadTextures.draw_frame(self, Rect2(cloth, view.cloth_size()), cell * 0.16)
	# Warp ends above the cloth.
	for c in state.width:
		var col := palette[state.warp_colors[c]]
		var r := Rect2(cloth + Vector2(c * cell + cell * 0.07, -0.78 * cell),
				Vector2(cell * ThreadTextures.THREAD, 0.62 * cell))
		ThreadTextures.draw_thread(self, r, col, true, colorblind, state.warp_colors[c])
		draw_circle(Vector2(r.get_center().x, r.position.y), cell * 0.12, col.darkened(0.12), true, -1.0, true)
	# Weft bobbins at the left of each row.
	for r in state.height:
		var col := palette[state.weft_colors[r]]
		var rect := Rect2(cloth + Vector2(-0.78 * cell, r * cell + cell * 0.07),
				Vector2(0.62 * cell, cell * ThreadTextures.THREAD))
		ThreadTextures.draw_thread(self, rect, col, false, colorblind, state.weft_colors[r])
		draw_circle(Vector2(rect.position.x, rect.get_center().y), cell * 0.12, col.darkened(0.12), true, -1.0, true)
		# Tick when the row matches the target.
		if state.row_matches(r):
			var center := switches.position + Vector2((state.shafts + 0.3) * cell, (r + 0.5) * cell)
			draw_circle(center, cell * 0.22, LoomTheme.MINT, true, -1.0, true)
			Icons.draw(self, "check", Rect2(center - Vector2.ONE * cell * 0.2, Vector2.ONE * cell * 0.4),
					Color.WHITE)
	# Shaft letters above the switches and left of the threading.
	for s in state.shafts:
		var col := LoomTheme.shaft_color(s)
		var letter: String = LoomTheme.SHAFT_LETTERS[s]
		var top := switches.position + Vector2((s + 0.5) * cell, -0.45 * cell)
		draw_circle(top, cell * 0.24, col, true, -1.0, true)
		draw_string(font, top + Vector2(-cell * 0.5, fsize * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER,
				cell, fsize, Color.WHITE)
		var left := draft.position + Vector2(-0.5 * cell, (s + 0.5) * cell)
		draw_circle(left, cell * 0.24, col, true, -1.0, true)
		draw_string(font, left + Vector2(-cell * 0.5, fsize * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER,
				cell, fsize, Color.WHITE)

class_name LoomBoard
extends Control
## Lays out the loom: warp ends on top, the cloth with each row's weft at its
## left, lift switches to the right of the cloth and the threading draft
## below it, all on one cell grid so everything lines up.
##
##            [warp ends]   [A B C]
##   [weft]   [ cloth   ]   [lifts]  [tick]
##   [A B C]  [threading]

signal lift_toggled(row: int, shaft: int)
signal warp_threaded(col: int, shaft: int)

const MAX_CELL := 92.0
## Extra cells around the grids: weft column, gaps, tick column, warp row.
const PAD_X := 0.8 + 0.3 + 0.6
const PAD_Y := 0.8 + 0.3

var state: LoomState
var palette := PackedColorArray()
var colorblind := false
var cell := 48.0
var view := LoomView.new()
var switches := LiftSwitches.new()
var draft := ThreadingDraft.new()
var _origin := Vector2.ZERO


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
	s.row_changed.connect(func(_r, _o): queue_redraw())
	s.column_changed.connect(func(_c, _o): queue_redraw())
	s.reset.connect(queue_redraw)
	resized.connect(_layout)
	_layout()


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
	var used := Vector2(cols, rows) * cell
	# Centred across, sitting a little high so the cloth is near the target.
	_origin = Vector2((size.x - used.x) * 0.5, (size.y - used.y) * 0.3).floor()
	view.cell = cell
	switches.cell = cell
	draft.cell = cell
	var cloth := cloth_origin()
	view.position = cloth
	view.size = view.cloth_size()
	switches.position = cloth + Vector2((state.width + 0.3) * cell, 0)
	switches.size = switches.grid_size()
	draft.position = cloth + Vector2(0, (state.height + 0.3) * cell)
	draft.size = draft.grid_size()
	view.queue_redraw()
	switches.queue_redraw()
	draft.queue_redraw()
	queue_redraw()


func cloth_origin() -> Vector2:
	return _origin + Vector2(0.8, 0.8) * cell


## Global rect of a lift switch (for the tutorial pointer).
func lift_rect(r: int, s: int) -> Rect2:
	var rect := switches.switch_rect(r, s)
	return Rect2(switches.global_position + rect.position, rect.size)


## Global rect of a threading slot (for the tutorial pointer).
func slot_rect(c: int, s: int) -> Rect2:
	var rect := draft.slot_rect(c, s)
	return Rect2(draft.global_position + rect.position, rect.size)


func _draw() -> void:
	if state == null or cell < 4.0:
		return
	var cloth := cloth_origin()
	var font := get_theme_default_font()
	var fsize := int(cell * 0.42)
	# Loom frame behind the cloth.
	var frame := Rect2(cloth - Vector2(cell * 0.12, cell * 0.12),
			view.cloth_size() + Vector2(cell * 0.24, cell * 0.24))
	draw_rect(frame, LoomTheme.WOOD_DARK)
	# Warp ends above the cloth.
	for c in state.width:
		var col := palette[state.warp_colors[c]]
		var r := Rect2(cloth + Vector2(c * cell + cell * 0.08, -0.7 * cell),
				Vector2(cell * ThreadTextures.THREAD, 0.58 * cell))
		draw_texture_rect(ThreadTextures.vertical(), r, false, col)
		ThreadTextures.draw_pattern(self, r, state.warp_colors[c], col, colorblind, 1.0)
	# Weft bobbins at the left of each row.
	for r in state.height:
		var col := palette[state.weft_colors[r]]
		var rect := Rect2(cloth + Vector2(-0.72 * cell, r * cell + cell * 0.08),
				Vector2(0.58 * cell, cell * ThreadTextures.THREAD))
		draw_texture_rect(ThreadTextures.horizontal(), rect, false, col)
		ThreadTextures.draw_pattern(self, rect, state.weft_colors[r], col, colorblind, 1.0)
		# Tick when the row matches the target.
		if state.row_matches(r):
			var tick := Rect2(switches.position + Vector2(state.shafts * cell, r * cell),
					Vector2(cell * 0.6, cell))
			Icons.draw(self, "check", tick.grow(-cell * 0.08), LoomTheme.ACCENT)
	# Shaft letters above the switches and left of the threading.
	for s in state.shafts:
		var col := LoomTheme.shaft_color(s)
		var letter: String = LoomTheme.SHAFT_LETTERS[s]
		var top := switches.position + Vector2(s * cell, -0.7 * cell)
		draw_string(font, top + Vector2(0, fsize), letter, HORIZONTAL_ALIGNMENT_CENTER, cell,
				fsize, col)
		var left := draft.position + Vector2(-0.8 * cell, s * cell + cell * 0.5 + fsize * 0.35)
		draw_string(font, left, letter, HORIZONTAL_ALIGNMENT_CENTER, cell * 0.7, fsize, col)

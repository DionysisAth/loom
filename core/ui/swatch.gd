class_name Swatch
extends Control
## A small picture of a level's cloth: flat cells for reading the target, or
## woven threads for finished pieces (win panel, level select, quilt).

var level := {}
var palette := PackedColorArray()
var woven := false
var colorblind := false
var frame := true
var _state: LoomState


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_level(lv: Dictionary, pal: PackedColorArray, is_woven := false) -> void:
	level = lv
	palette = pal
	woven = is_woven
	_state = LoomState.from_level(lv)
	# Show the solved cloth.
	_state.threading = PackedInt32Array(lv.solution.threading)
	_state.lifts = PackedInt32Array(lv.solution.lifts)
	queue_redraw()


## Width / height of the cloth, for sizing containers.
func aspect() -> float:
	if _state == null:
		return 1.0
	return float(_state.width) / float(_state.height)


func _draw() -> void:
	if _state == null:
		return
	var w := _state.width
	var h := _state.height
	var cell := floorf(minf(size.x / w, size.y / h))
	var dims := Vector2(w, h) * cell
	var origin := ((size - dims) * 0.5).floor()
	var rect := Rect2(origin, dims)
	if frame:
		draw_rect(rect.grow(maxf(2.0, cell * 0.12)), LoomTheme.WOOD_DARK)
	if woven:
		ThreadTextures.draw_cloth(self, rect, w, h, _state.warp_on_top,
				_state.warp_colors, _state.weft_colors, palette, colorblind)
		return
	var gap := maxf(1.0, cell * 0.06)
	draw_rect(rect, ThreadTextures.GAP_COLOR)
	for r in h:
		for c in w:
			var id := _state.target_color(c, r)
			var col := palette[id]
			var cr := Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)).grow(-gap * 0.5)
			draw_rect(cr, col)
			if colorblind:
				ThreadTextures.draw_pattern(self, cr, id, col, true, 1.0)

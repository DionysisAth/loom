class_name Swatch
extends Control
## A small picture of a level's cloth: flat rounded cells for reading the
## target, or woven threads for finished pieces (win panel, level select,
## quilt). With `holdable`, pressing and holding it emits hold_changed so the
## game can lay the target over the cloth.

signal hold_changed(held: bool)

var level := {}
var palette := PackedColorArray()
var woven := false
var colorblind := false
var frame := true
var holdable := false:
	set(v):
		holdable = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
var _state: LoomState
var _held := false


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


func _gui_input(event: InputEvent) -> void:
	if not holdable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_held(event.pressed)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _held:
		_set_held(false)


func _set_held(v: bool) -> void:
	if v == _held:
		return
	_held = v
	queue_redraw()
	hold_changed.emit(v)


func _draw() -> void:
	if _state == null:
		return
	var w := _state.width
	var h := _state.height
	var pad := 0.0
	if frame:
		pad = minf(size.x, size.y) * (0.06 if woven else 0.05)
	var inner := Vector2(size.x - pad * 2.0, size.y - pad * 2.0)
	var cell := floorf(minf(inner.x / w, inner.y / h))
	var dims := Vector2(w, h) * cell
	var origin := ((size - dims) * 0.5).floor()
	var rect := Rect2(origin, dims)
	if woven:
		if frame:
			ThreadTextures.draw_frame(self, rect, maxf(3.0, pad * 0.8))
		ThreadTextures.draw_cloth(self, rect, w, h, _state.warp_on_top,
				_state.warp_colors, _state.weft_colors, palette, colorblind)
		return
	if frame:
		var card := LoomTheme.card(int(pad * 1.6), 0)
		if _held:
			card.bg_color = LoomTheme.SUN.lerp(Color.WHITE, 0.6)
		draw_style_box(card, rect.grow(pad))
	var gap := maxf(2.0, cell * 0.08)
	var radius := int(maxf(2.0, cell * 0.22))
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	for r in h:
		for c in w:
			var id := _state.target_color(c, r)
			var col := palette[id]
			var cr := Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)).grow(-gap * 0.5)
			b.bg_color = col.darkened(0.12)
			draw_style_box(b, Rect2(cr.position + Vector2(0, gap * 0.4), cr.size))
			b.bg_color = col
			draw_style_box(b, cr)
			if colorblind:
				ThreadTextures.draw_pattern(self, cr, id, col, true, 1.0)

class_name QuiltPatchwork
extends Control
## One world's quilt: a grid of patches, woven where the level is solved and
## plain linen with a stitched outline where it is not.

var _world := {}
var _columns := 5
var _patches: Array[Swatch] = []
var _empty: Array[bool] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(world: Dictionary, columns: int) -> void:
	_world = world
	_columns = columns
	for j in world.levels.size():
		var lv: Dictionary = world.levels[j]
		var s := Swatch.new()
		s.frame = false
		var done := Save.is_completed(lv.id)
		if done:
			s.show_level(lv, Levels.palette(world.first + j), true)
			s.colorblind = Save.get_setting("colorblind")
		add_child(s)
		_patches.append(s)
		_empty.append(not done)
	resized.connect(_layout)


func _rows() -> int:
	return ceili(float(_patches.size()) / _columns)


func _patch() -> float:
	return floorf((size.x - 24.0) / _columns)


func _layout() -> void:
	var p := _patch()
	custom_minimum_size.y = p * _rows() + 24.0
	for i in _patches.size():
		var s := _patches[i]
		s.position = Vector2(12 + (i % _columns) * p, 12 + (i / _columns) * p) + Vector2(4, 4)
		s.size = Vector2(p - 8, p - 8)
	queue_redraw()


func _draw() -> void:
	var p := _patch()
	var rect := Rect2(Vector2.ZERO, Vector2(p * _columns + 24.0, p * _rows() + 24.0))
	draw_style_box(LoomTheme.box(LoomTheme.WOOD, 14), rect)
	for i in _patches.size():
		var cell := Rect2(Vector2(12 + (i % _columns) * p, 12 + (i / _columns) * p), Vector2(p, p))
		draw_rect(cell.grow(-2), LoomTheme.BG_DEEP if _empty[i] else ThreadTextures.GAP_COLOR)
		if _empty[i]:
			_stitches(cell.grow(-10))


func _stitches(r: Rect2) -> void:
	var col := LoomTheme.INK_SOFT.lerp(LoomTheme.BG_DEEP, 0.4)
	var dash := 8.0
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var n := int(a.distance_to(b) / (dash * 2.0))
		for j in n:
			var t0 := float(j * 2) / (n * 2)
			var t1 := float(j * 2 + 1) / (n * 2)
			draw_line(a.lerp(b, t0), a.lerp(b, t1), col, 2.0)

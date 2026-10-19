class_name WeaveDraft
extends Control
## The pattern card: the whole target cloth as flat tiles (first row at the
## bottom, like the cloth), with the next row to weave marked.

var loom: WeaveLoom
var palette := PackedColorArray()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(l: WeaveLoom, pal: PackedColorArray) -> void:
	loom = l
	palette = pal
	l.changed.connect(queue_redraw)


func _draw() -> void:
	if loom == null:
		return
	var w := loom.width
	var h := loom.height()
	var pad := 12.0
	var cs := floorf(minf((size.x - pad * 2 - 20) / w, (size.y - pad * 2) / h))
	var dims := Vector2(w, h) * cs
	var origin := ((size - dims) * 0.5).floor()
	draw_style_box(LoomTheme.card(18, 0), Rect2(origin, dims).grow(pad))
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(int(cs * 0.2))
	b.anti_aliasing = true
	var gap := maxf(1.5, cs * 0.08)
	for r in h:
		var y := origin.y + (h - 1 - r) * cs
		var done := r < loom.woven.size()
		for c in w:
			var col := palette[loom.target_color(c, r)]
			b.bg_color = col if not done else col.lerp(Color.WHITE, 0.45)
			draw_style_box(b, Rect2(Vector2(origin.x + c * cs, y), Vector2(cs, cs)).grow(-gap * 0.5))
		if r == loom.woven.size():
			var mark := Rect2(Vector2(origin.x, y), Vector2(w * cs, cs)).grow(3)
			draw_rect(mark, LoomTheme.ACCENT, false, 3.0, true)
			var tip := Vector2(origin.x + w * cs + 8, y + cs * 0.5)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(12, -8), tip + Vector2(12, 8)]),
					LoomTheme.ACCENT)

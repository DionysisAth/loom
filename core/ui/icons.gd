class_name Icons
extends RefCounted
## Simple vector icons drawn with CanvasItem calls, so no font glyphs or image
## files are needed. `r` is the icon's square; `w` the stroke width.


static func draw(ci: CanvasItem, icon: String, r: Rect2, color: Color) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	var w := maxf(2.0, s * 0.1)
	match icon:
		"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.12, -s * 0.3),
				c + Vector2(-s * 0.18, 0), c + Vector2(s * 0.12, s * 0.3)]), color, w, true)
		"menu":
			for i in 3:
				var y := (i - 1) * s * 0.24
				ci.draw_line(c + Vector2(-s * 0.3, y), c + Vector2(s * 0.3, y), color, w, true)
		"undo":
			ci.draw_arc(c + Vector2(s * 0.04, s * 0.06), s * 0.26, -PI * 0.95, PI * 0.55, 24, color, w, true)
			var tip := c + Vector2(s * 0.04, s * 0.06) + Vector2.from_angle(-PI * 0.95) * s * 0.26
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.16, -s * 0.02),
				tip + Vector2(s * 0.1, -s * 0.06), tip + Vector2(-s * 0.02, s * 0.2)]), color)
		"restart":
			ci.draw_arc(c, s * 0.27, -PI * 0.35, PI * 1.35, 28, color, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.35) * s * 0.27
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.04, -s * 0.18),
				tip + Vector2(s * 0.16, s * 0.04), tip + Vector2(-s * 0.14, s * 0.08)]), color)
		"hint":
			ci.draw_circle(c + Vector2(0, -s * 0.08), s * 0.22, color, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, s * 0.12), Vector2(s * 0.2, s * 0.1)), color)
			ci.draw_line(c + Vector2(-s * 0.08, s * 0.3), c + Vector2(s * 0.08, s * 0.3), color, w * 0.8, true)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.28),
				c + Vector2(s * 0.28, 0), c + Vector2(-s * 0.18, s * 0.28)]), color)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.06), s * 0.16, PI, TAU, 16, color, w * 0.8, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.06), Vector2(s * 0.48, s * 0.36)), color)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.28, 0), c + Vector2(-s * 0.08, s * 0.2),
				c + Vector2(s * 0.3, -s * 0.22)]), color, w, true)
		"star":
			ci.draw_colored_polygon(star_points(c, s * 0.42), color)
		"star_empty":
			var pts := star_points(c, s * 0.42)
			pts.append(pts[0])
			ci.draw_polyline(pts, color, maxf(1.5, w * 0.5), true)
		"quilt":
			var q := s * 0.24
			for i in 4:
				var o := Vector2((i % 2) * q * 1.15, (i / 2) * q * 1.15) - Vector2(q * 1.07, q * 1.07)
				ci.draw_rect(Rect2(c + o, Vector2(q, q)), color)
		"settings":
			for i in 3:
				var y := (i - 1) * s * 0.24
				ci.draw_line(c + Vector2(-s * 0.3, y), c + Vector2(s * 0.3, y), color, w * 0.6, true)
				ci.draw_circle(c + Vector2([-0.12, 0.14, -0.02][i] * s, y), s * 0.08, color, true, -1.0, true)


static func star_points(c: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (radius if i % 2 == 0 else radius * 0.45))
	return pts

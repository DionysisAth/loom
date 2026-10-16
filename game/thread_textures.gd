class_name ThreadTextures
extends RefCounted
## Procedural thread sprites and the shared crossing renderer.
##
## Each crossing is one short thread segment: vertical when the warp is on top,
## horizontal when the weft is, tinted to the thread colour, with a soft shadow
## on the thread underneath. Segments darken at an end only where the thread
## dives under its neighbour, so floats read as one continuous thread.

const SEG_W := 48
const SEG_L := 96
## Thread width as a share of the cell.
const THREAD := 0.84
const UNDER_SHADE := 0.68
const GAP_COLOR := Color(0.16, 0.11, 0.08)

static var _vertical: Texture2D
static var _horizontal: Texture2D
static var _end_shade: Texture2D
static var _patterns: Array[Texture2D] = []


static func vertical() -> Texture2D:
	if _vertical == null:
		_build()
	return _vertical


static func horizontal() -> Texture2D:
	if _horizontal == null:
		_build()
	return _horizontal


## Colourblind thread texture for a colour id (null for the plain one).
static func pattern(color_id: int) -> Texture2D:
	if _patterns.is_empty():
		_build()
	return _patterns[color_id % _patterns.size()]


static func _build() -> void:
	var img := Image.create(SEG_W, SEG_L, false, Image.FORMAT_RGBA8)
	for y in SEG_L:
		for x in SEG_W:
			var u := (x + 0.5) / SEG_W
			var profile := sin(PI * u)
			var b := 0.52 + 0.48 * pow(profile, 0.6)
			# Yarn twist: faint diagonal ridges.
			b += 0.07 * sin((x * 0.55 + y * 0.85) * 1.3) * profile
			b = clampf(b, 0.0, 1.0)
			var a := clampf(profile * 7.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(b, b, b, a))
	_vertical = ImageTexture.create_from_image(img)
	var h := img.duplicate()
	h.rotate_90(CLOCKWISE)
	_horizontal = ImageTexture.create_from_image(h)

	var shade := Image.create(SEG_W, SEG_W, false, Image.FORMAT_RGBA8)
	for y in SEG_W:
		for x in SEG_W:
			var t := 1.0 - float(y) / SEG_W
			shade.set_pixel(x, y, Color(0, 0, 0, 0.55 * t * t))
	_end_shade = ImageTexture.create_from_image(shade)

	_patterns.clear()
	for id in 6:
		_patterns.append(_make_pattern(id))


static func _make_pattern(id: int) -> Texture2D:
	if id == 0:
		return null
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var on := false
			match id:
				1: # diagonal stripes
					on = (x + y) % 12 < 4
				2: # dots
					var dx := (x % 11) - 5
					var dy := (y % 11) - 5
					on = dx * dx + dy * dy <= 6
				3: # cross-hatch
					on = (x + y) % 12 < 3 or (x - y + 64) % 12 < 3
				4: # bars across
					on = y % 10 < 3
				5: # chevrons
					on = (absi((x % 16) - 8) + y) % 10 < 3
			img.set_pixel(x, y, Color(1, 1, 1, 0.75 if on else 0.0))
	return ImageTexture.create_from_image(img)


static func pattern_tint(base: Color) -> Color:
	return Color(0, 0, 0, 0.42) if base.get_luminance() > 0.45 else Color(1, 1, 1, 0.45)


## Draws one crossing into `rect`.
## `squash` (0..1) narrows the top thread during a flip.
## `dive_*` say whether the top thread goes under at that end (draws shade).
static func draw_crossing(ci: CanvasItem, rect: Rect2, warp_top: bool, warp: Color,
		weft: Color, squash := 1.0, colorblind := false, warp_id := 0, weft_id := 0,
		dive_a := true, dive_b := true) -> void:
	var cell := rect.size.x
	var tw := cell * THREAD
	var inset := (cell - tw) * 0.5
	var top := warp if warp_top else weft
	var under := weft if warp_top else warp
	var top_id := warp_id if warp_top else weft_id
	var under_id := weft_id if warp_top else warp_id
	if warp_top:
		var u := Rect2(rect.position.x, rect.position.y + inset, cell, tw)
		ci.draw_texture_rect(horizontal(), u, false, under.darkened(1.0 - UNDER_SHADE))
		draw_pattern(ci, u, under_id, under, colorblind, 0.6)
		var w := tw * squash
		var shadow := Rect2(rect.get_center().x - w * 0.5 - cell * 0.05, rect.position.y,
				w + cell * 0.1, cell)
		ci.draw_rect(shadow, Color(0, 0, 0, 0.22 * squash))
		var o := Rect2(rect.get_center().x - w * 0.5, rect.position.y, w, cell)
		ci.draw_texture_rect(vertical(), o, false, top)
		draw_pattern(ci, o, top_id, top, colorblind, 1.0)
		_dives(ci, o, true, dive_a, dive_b)
	else:
		var u := Rect2(rect.position.x + inset, rect.position.y, tw, cell)
		ci.draw_texture_rect(vertical(), u, false, under.darkened(1.0 - UNDER_SHADE))
		draw_pattern(ci, u, under_id, under, colorblind, 0.6)
		var hgt := tw * squash
		var shadow := Rect2(rect.position.x, rect.get_center().y - hgt * 0.5 - cell * 0.05,
				cell, hgt + cell * 0.1)
		ci.draw_rect(shadow, Color(0, 0, 0, 0.22 * squash))
		var o := Rect2(rect.position.x, rect.get_center().y - hgt * 0.5, cell, hgt)
		ci.draw_texture_rect(horizontal(), o, false, top)
		draw_pattern(ci, o, top_id, top, colorblind, 1.0)
		_dives(ci, o, false, dive_a, dive_b)


static func draw_pattern(ci: CanvasItem, r: Rect2, id: int, base: Color, on: bool, alpha: float) -> void:
	if not on:
		return
	var tex := pattern(id)
	if tex == null:
		return
	var tint := pattern_tint(base)
	tint.a *= alpha
	ci.draw_texture_rect(tex, r, false, tint)


## Shade the ends of a top thread that dives under the next crossing.
static func _dives(ci: CanvasItem, o: Rect2, is_vertical: bool, a: bool, b: bool) -> void:
	if _end_shade == null:
		_build()
	var shade_len := (o.size.y if is_vertical else o.size.x) * 0.28
	if is_vertical:
		if a:
			ci.draw_texture_rect(_end_shade, Rect2(o.position.x, o.position.y, o.size.x, shade_len), false)
		if b:
			ci.draw_set_transform(Vector2(o.position.x, o.end.y), 0.0, Vector2(1, -1))
			ci.draw_texture_rect(_end_shade, Rect2(0, 0, o.size.x, shade_len), false)
			ci.draw_set_transform(Vector2.ZERO)
	else:
		if a:
			ci.draw_set_transform(Vector2(o.position.x, o.end.y), -PI * 0.5, Vector2.ONE)
			ci.draw_texture_rect(_end_shade, Rect2(0, 0, o.size.y, shade_len), false)
			ci.draw_set_transform(Vector2.ZERO)
		if b:
			ci.draw_set_transform(Vector2(o.end.x, o.position.y), PI * 0.5, Vector2.ONE)
			ci.draw_texture_rect(_end_shade, Rect2(0, 0, o.size.y, shade_len), false)
			ci.draw_set_transform(Vector2.ZERO)


## Draws a whole finished cloth (no animation) for swatches and the quilt.
static func draw_cloth(ci: CanvasItem, rect: Rect2, width: int, height: int,
		warp_top: Callable, warp_ids: PackedInt32Array, weft_ids: PackedInt32Array,
		palette: PackedColorArray, colorblind := false) -> void:
	var cell := minf(rect.size.x / width, rect.size.y / height)
	var origin := rect.position + (rect.size - Vector2(cell * width, cell * height)) * 0.5
	ci.draw_rect(Rect2(origin, Vector2(cell * width, cell * height)), GAP_COLOR)
	for r in height:
		for c in width:
			var top: bool = warp_top.call(c, r)
			var a: bool
			var b: bool
			if top:
				a = r > 0 and not warp_top.call(c, r - 1)
				b = r < height - 1 and not warp_top.call(c, r + 1)
			else:
				a = c > 0 and warp_top.call(c - 1, r)
				b = c < width - 1 and warp_top.call(c + 1, r)
			draw_crossing(ci, Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)), top,
					palette[warp_ids[c]], palette[weft_ids[r]], 1.0, colorblind,
					warp_ids[c], weft_ids[r], a, b)

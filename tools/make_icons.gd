extends SceneTree
## Draws the launcher icons (a small woven cloth on dark wood) into art/.
## Usage: godot --headless --path . --script res://tools/make_icons.gd

const WOOD := Color("#ff5d73")
const GAP := Color("#8c5c45")
const WARP := Color("#3a86ff")
const WEFT := Color("#fff4dc")
const ACCENT := Color("#ffbe0b")


func _initialize() -> void:
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	_cloth(fg, Rect2i(108, 108, 216, 216))
	fg.save_png("res://art/icon_foreground_432.png")

	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(WOOD)
	bg.save_png("res://art/icon_background_432.png")

	var main := Image.create(192, 192, false, Image.FORMAT_RGBA8)
	main.fill(Color(0, 0, 0, 0))
	_rounded(main, 36, WOOD)
	_cloth(main, Rect2i(30, 30, 132, 132))
	main.save_png("res://art/icon_192.png")
	print("icons written to res://art/")
	quit()


func _rounded(img: Image, radius: int, color: Color) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var dx := maxi(maxi(radius - x, x - (s - 1 - radius)), 0)
			var dy := maxi(maxi(radius - y, y - (s - 1 - radius)), 0)
			var d := sqrt(dx * dx + dy * dy)
			if d <= radius:
				img.set_pixel(x, y, Color(color, clampf(radius - d + 0.5, 0.0, 1.0)))


## A 4 x 4 plain weave with one madder row, shaded like round threads.
func _cloth(img: Image, r: Rect2i) -> void:
	var n := 4
	var cell := r.size.x / n
	for y in r.size.y:
		for x in r.size.x:
			img.set_pixel(r.position.x + x, r.position.y + y, GAP)
	for row in n:
		for col in n:
			var warp_top := (row + col) % 2 == 0
			var weft := ACCENT if row == 1 else WEFT
			var o := Vector2i(r.position.x + col * cell, r.position.y + row * cell)
			for y in cell:
				for x in cell:
					var u := (x + 0.5) / cell
					var v := (y + 0.5) / cell
					var across := absf(u - 0.5) * 2.0
					var down := absf(v - 0.5) * 2.0
					var c := GAP
					# The under thread first, then the top thread over it.
					var under_d := across if not warp_top else down
					var top_d := across if warp_top else down
					if under_d < 0.84:
						var base := weft if warp_top else WARP
						c = base.darkened(0.35) * (0.55 + 0.45 * sqrt(1.0 - under_d / 0.84))
					if top_d < 0.84:
						var base := WARP if warp_top else weft
						c = base * (0.55 + 0.45 * sqrt(1.0 - top_d / 0.84))
					c.a = 1.0
					img.set_pixel(o.x + x, o.y + y, c)

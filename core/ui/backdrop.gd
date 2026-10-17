class_name Backdrop
extends Control
## The screen background: a warm vertical gradient with a few big soft
## bubbles and loose threads drifting slowly behind everything.

const BUBBLES := [
	[Vector2(0.12, 0.10), 0.34, Color("#ffb3c6")],
	[Vector2(0.92, 0.22), 0.28, Color("#ffd27a")],
	[Vector2(0.08, 0.62), 0.30, Color("#b9a4ff")],
	[Vector2(0.95, 0.80), 0.36, Color("#8de3cf")],
	[Vector2(0.50, 1.02), 0.30, Color("#ffc2a1")],
]
const THREADS := [
	[0.18, Color("#ff8fa3"), 0.0],
	[0.47, Color("#ffcc5c"), 1.7],
	[0.78, Color("#9fb8ff"), 3.1],
]

static var _gradient: GradientTexture2D

var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	if _gradient == null:
		var g := Gradient.new()
		g.set_color(0, LoomTheme.BG_TOP)
		g.set_color(1, LoomTheme.BG_BOTTOM)
		_gradient = GradientTexture2D.new()
		_gradient.gradient = g
		_gradient.fill_from = Vector2(0, 0)
		_gradient.fill_to = Vector2(0, 1)
		_gradient.width = 4
		_gradient.height = 256


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_texture_rect(_gradient, Rect2(Vector2.ZERO, s), false)
	var unit := minf(s.x, s.y)
	for i in BUBBLES.size():
		var b: Array = BUBBLES[i]
		var drift := Vector2(sin(_t * 0.21 + i * 1.3), cos(_t * 0.17 + i * 0.7)) * unit * 0.03
		var c: Vector2 = Vector2(b[0].x * s.x, b[0].y * s.y) + drift
		var radius: float = b[1] * unit
		var col: Color = b[2]
		draw_circle(c, radius, Color(col, 0.18), true, -1.0, true)
		draw_circle(c, radius * 0.72, Color(col, 0.14), true, -1.0, true)
	# Loose threads waving across the screen.
	for th in THREADS:
		var y0: float = th[0] * s.y
		var col: Color = th[1]
		var phase: float = th[2]
		var pts := PackedVector2Array()
		for k in 25:
			var x := s.x * (k / 24.0) * 1.1 - s.x * 0.05
			var y := y0 + sin(k * 0.45 + _t * 0.4 + phase) * unit * 0.03
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(col, 0.28), 6.0, true)

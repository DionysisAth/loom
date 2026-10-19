class_name Backdrop
extends Control
## The screen background: a soft, still, warm gradient. Kept calm on purpose
## so the cloth is the only thing that draws the eye.

static var _gradient: GradientTexture2D


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


func _draw() -> void:
	draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size), false)

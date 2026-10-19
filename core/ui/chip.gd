class_name Chip
extends PanelContainer
## A small rounded label in a colour, e.g. "1-3 · Lifting".

var _label: Label


func set_text(text: String) -> void:
	_label.text = text


func _init(text := "", color := LoomTheme.ACCENT, font_size := 22) -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(20)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	b.anti_aliasing = true
	add_theme_stylebox_override("panel", b)
	_label = Label.new()
	var l := _label
	l.text = text
	l.add_theme_font_override("font", LoomTheme.font(600))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	add_child(l)

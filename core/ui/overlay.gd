class_name Overlay
extends Control
## A dimmed full-screen layer with a centred white card that pops in.

var card := PanelContainer.new()
var body := VBoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.1, 0.25, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card.custom_minimum_size = Vector2(580, 0)
	center.add_child(card)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 20)
	card.add_child(body)


func show_card() -> void:
	visible = true
	modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32)


func close() -> void:
	visible = false


func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func add_button(text: String, variation := &"") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 100)
	if variation != &"":
		b.theme_type_variation = variation
	b.pressed.connect(func(): Audio.play("tap", 0.05, -6.0))
	body.add_child(b)
	return b


func add_label(text: String, variation := &"") -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		l.theme_type_variation = variation
	body.add_child(l)
	return l

class_name Screen
extends Control
## Base for full-screen menus: linen background, shared theme, a padded
## content column and the Android back button / Escape mapped to go_back().

const MARGIN := 28

var content: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = LoomTheme.get_theme()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = LoomTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	content = VBoxContainer.new()
	margin.add_child(content)
	build()


## Subclasses add their widgets to `content` here.
func build() -> void:
	pass


## Android back / Escape.
func go_back() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


## A row with a back button and a title.
func add_header(title: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	var back := IconButton.new("back")
	back.pressed.connect(go_back)
	bar.add_child(back)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"TitleLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	content.add_child(bar)
	return bar


static func goto(path: String) -> void:
	(Engine.get_main_loop() as SceneTree).change_scene_to_file(path)


static func stars_row(count: int, total := 3, star_size := 40.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for i in total:
		var star := StarIcon.new()
		star.filled = i < count
		star.custom_minimum_size = Vector2(star_size, star_size)
		row.add_child(star)
	return row
